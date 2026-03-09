extends Node3D

@onready var anim_player = $AnimationPlayer

# ─── Paramètres exportés (modifiables dans l'inspecteur) ───────────────────
@export var duration:          float = 30.0   # Durée de vie totale
@export var max_health:        int   = 2      # Boulets pour détruire
@export var attack_damage:     float = 30.0   # Dégâts infligés
@export var attack_cooldown:   float = 1.5    # Secondes entre attaques
@export var detection_radius:  float = 60.0   # Rayon de détection (world-space)
@export var attack_range:      float = 40.0   # Rayon dans lequel les dégâts sont appliqués
@export var knockback_force:   float = 350.0  # Force du knockback en unités/s

# ─── État interne ───────────────────────────────────────────────────────────
var timer:          float  = 0.0
var attack_timer:   float  = 0.0
var state:          String = "rising"
var health:         int
var is_attacking:   bool   = false
var skeleton_ref:   Skeleton3D = null  # référence cachée vers le squelette

var rise_anim  = "TentacleRig|Rise1"
var idle_anim  = "TentacleRig|Idle1"
var attack_anims = [
	"TentacleRig|Slam",
	"TentacleRig|SlapL1",
	"TentacleRig|SlapL2",
	"TentacleRig|SlapR1",
	"TentacleRig|SlapR2",
	"TentacleRig|Stab"
]

# ─── _ready ─────────────────────────────────────────────────────────────────
func _ready():
	# Bonus basés sur l'équipement actif (voir GameConfig.gd)
	max_health += GameConfig.get_kraken_armor_hp_bonus()
	attack_damage += GameConfig.get_kraken_spike_damage_bonus()
		
	health = max_health
	print("🐙 Tentacule apparue — PV: ", health, " Dégâts: ", attack_damage)

	# Empêcher la caméra de passer à travers la tentacule
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var spring_arm = player.find_child("SpringArm3D", true)
		if spring_arm is SpringArm3D:
			spring_arm.add_excluded_object($PhysicalHitbox.get_rid())

	# Randomise les animations
	if randf() > 0.5: rise_anim = "TentacleRig|Rise2"
	if randf() > 0.5: idle_anim = "TentacleRig|Idle2"

	# Méta pour les boulets de canon
	$PhysicalHitbox.set_meta("tentacle_root", self)

	# Cache la référence au squelette (pour la position de la pointe)
	skeleton_ref = _find_skeleton(self)

	# Lance l'animation d'émergence
	if anim_player.has_animation(rise_anim):
		anim_player.play(rise_anim)
		anim_player.animation_finished.connect(_on_animation_finished)
	else:
		state = "idle"
	
	# Appliquer la personnalisation du Kraken
	apply_visual_config()

func apply_visual_config():
	# Mapping: skill ID → nom du MeshInstance3D dans la scène
	var id_to_mesh = {
		"TentacleV1": "ventouse",
		"TentacleV2": "piquant",
		"TentacleV3": "lisse",
		"TentacleV4": "vertèbre",
		"TentacleV5": "plante",
		"ArmorV1": "écailles dorsale",
		"ArmorV2": "armure dorsale",
		"ArmorV3": "armure longue dorsale",
		"TipSpike": "dart",
		"SpikesBack1": "pique dorsale",
		"SpikesBack2": "double pique dorsale",
		"SpikesSides": "pique latérale",
		"SpikesFront1": "pique intérieur",
		"SpikesFront2": "double pique intérieur",
		"Thorns": "pique profond",
	}
	
	var skeleton = _find_skeleton(self)
	if not skeleton: return
	
	var config = GameConfig.kraken_tentacle_parts
	for skill_id in config.keys():
		var mesh_name = id_to_mesh.get(skill_id, skill_id)
		var mesh_node = skeleton.find_child(mesh_name, true, false)
		if mesh_node and mesh_node is MeshInstance3D:
			mesh_node.visible = config[skill_id]

# ─── _process ───────────────────────────────────────────────────────────────
func _process(delta):
	if state == "dead" or state == "retreating":
		return

	if state == "idle":
		timer += delta
		if timer >= duration:
			_start_retreat()
			return

		# Cherche une cible toutes les attack_cooldown secondes
		if not is_attacking:
			attack_timer += delta
			if attack_timer >= attack_cooldown:
				attack_timer = 0.0
				_try_attack()

# Distance horizontale XZ uniquement (ignore la hauteur Y de la tentacule)
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Cherche récursivement le premier Skeleton3D dans la hiérarchie
func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result: return result
	return null

# Retourne la position world-space du dernier os (la POINTE de la tentacule)
# Si pas de skeleton, retourne la base
func _get_tip_position() -> Vector3:
	if skeleton_ref and is_instance_valid(skeleton_ref):
		var bone_count = skeleton_ref.get_bone_count()
		if bone_count > 0:
			# Le dernier os est la pointe
			var tip_local = skeleton_ref.get_bone_global_pose(bone_count - 1).origin
			return skeleton_ref.global_transform * tip_local
	return global_position

# ─── Détection de cible par distance ────────────────────────────────────────
func _try_attack():
	var best: Node3D = null
	var best_dist: float = detection_radius

	# Joueur
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var d = _flat_dist(global_position, player.global_position)
		if d <= detection_radius:
			best      = player
			best_dist = d

	# Ennemis
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		var d = _flat_dist(global_position, enemy.global_position)
		if d < best_dist:
			best_dist = d
			best      = enemy

	if best != null:
		_perform_attack(best)

# ─── Attaque ────────────────────────────────────────────────────────────────
func _perform_attack(target: Node3D):
	if is_attacking or state != "idle":
		return

	is_attacking = true
	var anim = attack_anims[randi() % attack_anims.size()]
	print("🐙 Attaque avec: ", anim, " → cible: ", target.name)

	if not anim_player.has_animation(anim):
		is_attacking = false
		return

	anim_player.play(anim)

	# Récupère la durée réelle de l'animation
	var anim_length = anim_player.get_animation(anim).length

	# ── Moment de l'impact : 35% de l'animation ─────────────────────────────
	var impact_delay = anim_length * 0.35
	var t = create_tween()
	t.tween_interval(impact_delay)
	t.tween_callback(func():
		if state == "dead" or state == "retreating":
			return
		_apply_impact(target)
	)

# ─── Impact physique réaliste ────────────────────────────────────────────────
func _apply_impact(target: Node3D):
	if not is_instance_valid(target):
		return

	# Distance depuis la BASE et depuis la POINTE de la tentacule
	# On prend le minimum : si le joueur est touché par le bout (Slam/Stab)
	# ça compte aussi, même si la base est loin
	var dist_base = _flat_dist(global_position, target.global_position)
	var tip_pos   = _get_tip_position()
	var dist_tip  = _flat_dist(tip_pos, target.global_position)
	var flat_d    = min(dist_base, dist_tip)
	print("🐙 Impact — dist base: ", snappedf(dist_base, 0.1),
		"  dist pointe: ", snappedf(dist_tip, 0.1),
		"  → min: ", snappedf(flat_d, 0.1), " / range: ", attack_range)

	if flat_d > attack_range:
		print("🐙 Trop loin, pas d'impact.")
		return

	print("🐙 💥 IMPACT sur ", target.name)

	# 1. Dégâts
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, null)

	# 2. Knockback physique — direction horizontale depuis la tentacule
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", global_position, knockback_force)

	# 3. Flash rouge sur la tentacule
	_flash_hit()

# ─── Fin d'animation ─────────────────────────────────────────────────────────
func _on_animation_finished(anim_name: String):
	if state == "dead":
		return

	if anim_name.find("Rise") != -1 and state == "rising":
		state = "idle"
		timer = 0.0
		if anim_player.has_animation(idle_anim):
			anim_player.play(idle_anim)

	elif anim_name.find("Retreat") != -1:
		queue_free()

	elif _is_attack_anim(anim_name):
		is_attacking = false
		if state == "idle" and anim_player.has_animation(idle_anim):
			anim_player.play(idle_anim)

func _is_attack_anim(anim_name: String) -> bool:
	return (anim_name.find("Slam") != -1
		or anim_name.find("Slap") != -1
		or anim_name.find("Stab") != -1)

# ─── Dégâts reçus (boulets de canon) ─────────────────────────────────────────
func take_damage(amount: float, _attacker = null):
	if state == "dead" or state == "retreating":
		return
	health -= 1
	print("🐙 Tentacule touchée ! Santé: ", health, "/", max_health)
	if health <= 0:
		_die()
	else:
		_flash_hit()

# ─── Feedback visuel — flash rouge bref ──────────────────────────────────────
func _flash_hit():
	var meshes: Array = []
	_collect_visible_meshes(self, meshes)
	for mi in meshes:
		var orig = mi.get_surface_override_material(0)
		if orig == null:
			orig = mi.mesh.surface_get_material(0) if mi.mesh else null
		var mat = StandardMaterial3D.new()
		mat.albedo_color           = Color(0.95, 0.3, 0.3, 1)
		mat.emission_enabled       = true
		mat.emission               = Color(1.0, 0.1, 0.1)
		mat.emission_energy_multiplier = 1.2
		mi.set_surface_override_material(0, mat)
		var tw = create_tween()
		tw.tween_interval(0.18)
		tw.tween_callback(func(): mi.set_surface_override_material(0, orig))

func _collect_visible_meshes(node: Node, result: Array):
	if node is MeshInstance3D and node.visible:
		result.append(node)
	for child in node.get_children():
		_collect_visible_meshes(child, result)

# ─── Mort / retraite ─────────────────────────────────────────────────────────
func _die():
	if state == "dead": return
	state        = "dead"
	is_attacking = false
	print("🐙 Tentacule DÉTRUITE !")
	_start_retreat()

func _start_retreat():
	if anim_player.is_playing() and anim_player.current_animation == "TentacleRig|Retreat":
		return
	state        = "retreating"
	is_attacking = false
	if anim_player.has_animation("TentacleRig|Retreat"):
		anim_player.play("TentacleRig|Retreat")
	else:
		queue_free()
