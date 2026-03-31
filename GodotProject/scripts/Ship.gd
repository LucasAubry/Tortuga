class_name Ship
extends CharacterBody3D

enum ShipClass { SLOOP, BRIGANTINE, GALLEON }
enum Faction { PLAYER, NAVY, PIRATE, MERCHANT }

var is_player: bool = true
var is_auto_cruising: bool = false
var follow_target = null # Instance de Ship
var is_defending: bool = false
var defense_skill_index: int = -1
@export var ship_type: ShipClass = ShipClass.SLOOP
@export var ship_color: Color = Color.WHITE
@export var faction: Faction = Faction.PLAYER
@export var is_controlled: bool = true
var is_in_port_zone: bool = false
var icon_text: String = "⚓"

var hp: float = 1000.0
var max_hp: float = 1000.0
var ship_speed: float
@export_group("Physics & Speed")
@export var max_speed: float = 35.0
@export var acceleration: float = 50.0
@export var turn_speed: float = 0.5
@export var wind_influence_with: float = 0.15
@export var wind_influence_against: float = -1.2
var cooldown: float
var max_cooldown: float
var damage: float = 25.0

@export var ammo: int = 50
@export var max_ammo: int = 100

signal weapon_blocked(index: int)


var weapon_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
const ProjectileScene = preload("res://scenes/Projectile.tscn")
const LootScene = preload("res://scenes/Loot.tscn")
const SmokeScene = preload("res://scenes/SmokeEffect.tscn")
const BasicCannonResource = preload("res://resources/weapons/boulet_faible.tres")

var basic_cannon_cooldown: float = 0.0

# Inventory
@export_group("Inventory")
@export var gold: int:
	get:
		if is_player: return FleetManager.gold
		return _gold
	set(value):
		if is_player: FleetManager.gold = value
		else: _gold = value
var _gold: int = 0
@export var wood: int = 0
@export var food: int = 0
@export var water: int = 0
@export var fish: int = 0

# Upgrades
var speed_level: int = 0
var fire_rate_level: int = 0
var extra_cannons: int = 0
var upgrades_purchased: int = 0

# Weapons System
@export var weapon_slots: Array[WeaponData] = [null, null, null, null, null]
var active_weapon_index: int = 0
var skill_timer: float = 0.0
var current_speed_buff: float = 1.0

# --- LIMITES DU MONDE ---
var _is_falling: bool = false
var _falling_timer: float = 0.0

@export_group("Diving Status (ReadOnly)")
@export var is_diving: bool = false
@export var is_underwater: bool = false
@export var current_dive_depth: float = 0.0
@export var current_dive_tilt: float = 0.0
@export var dive_delay_timer: float = 0.0
@export var is_wind_boost_active: bool = false
@export var wind_boost_timer: float = 0.0
var current_wind_vec_phys: Vector3 = Vector3.ZERO
var wind_boost_intensity: float = 0.0
var current_shield: float = 0.0

# --- INVENTAIRE ---
signal inventory_changed
var inventory: Array[String] = []
var inventory_max_slots: int = 12 # 2 lignes de 6 par exemple

func add_to_inventory(item_name: String) -> bool:
	if inventory.size() < inventory_max_slots:
		inventory.append(item_name)
		inventory_changed.emit()
		return true
	return false

func remove_from_inventory(item_name: String) -> bool:
	var idx = inventory.find(item_name)
	if idx != -1:
		inventory.remove_at(idx)
		inventory_changed.emit()
		return true
	return false
var purchase_price: int = 0
var _shield_visual: MeshInstance3D = null
var _hit_smoke_particles: CPUParticles3D = null
var _camera_target_yaw: float = 0.0
var _camera_target_pitch: float = -0.4
var _camera_target_dist: float = 1500.0
var _camera_auto_align_timer: float = 0.0
var _flag_label: Label3D = null
var _fleet_num: int = -1 # Mémorise le numéro de flotte

# --- GRAPPIN MODULAIRE ---
var _grapple: GrapplingHookSystem = null

# Status Effects (Knockback & CC)
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_decay: float = 3.5
var immobilization_timer: float = 0.0
var _immobilized_icon: Node3D = null

# Naufrage
var is_sinking: bool = false

# Sail Visual Tweakables (Visible in Godot Inspector)
@export_group("Sail Visuals")
@export var sail_inflation_left: float = 2.5
@export var sail_offset_left: float = 0.0
@export var sail_inflation_right: float = 2.5
@export var sail_offset_right: float = 0.3
@export var sail_lerp_speed: float = 1.2
@export var mast_lerp_speed: float = 0.7

@export_group("Professional Camera")
@export var camera_distance: float = 150.0
@export var camera_height: float = 50.0
@export var camera_sensitivity: float = 0.003
@export var camera_smoothing: float = 8.0 # Lissage fluide

var _cam_yaw: float = 0.0
var _cam_yaw_smooth: float = 0.0
var _cam_pitch: float = -0.3
var _cam_node: Camera3D
var _cam_tilt_target: float = 0.0
var _cam_tilt_smooth: float = 0.0

# Visual Steering
var visual_mast: Node3D
var visual_wheel: Node3D
var visual_sails: Node3D
var base_wheel_rot: Vector3
var base_mast_rot: Vector3
var base_sails_rot: Vector3
var base_sails_scale: Vector3
var base_sails_pos: Vector3
var current_steer_angle: float = 0.0
var current_sail_angle: float = 0.0

func _ready():
	# Disable picking if this is a CollisionObject3D
	if self is CollisionObject3D:
		set("input_ray_pickable", false)
	_init_stats()
	_init_components()
	
	add_to_group("ship")
	add_to_group("player")
	faction = Faction.PLAYER
	_setup_damage_smoke()
	_setup_immobilized_icon()
	_setup_camera_wind_waker()
	# Grappin modulaire
	_grapple = GrapplingHookSystem.new()
	add_child(_grapple)
	_grapple.setup(self)



func _setup_immobilized_icon():
	if is_instance_valid(_immobilized_icon):
		_immobilized_icon.queue_free()
		
	var net_scene = load("res://assets/skills/fishing-net.glb")
	if net_scene:
		_immobilized_icon = net_scene.instantiate()
		add_child(_immobilized_icon)
		_immobilized_icon.name = "ImmobilizedNet3D"
		_immobilized_icon.scale = Vector3(6.0, 6.0, 6.0) # Beaucoup plus gros pour être bien visible de loin
		
		var zone_node = get_node_or_null("StatusEffectsZone")
		if zone_node:
			_immobilized_icon.position = zone_node.position
		else:
			_immobilized_icon.position = Vector3(0, 48, 0)
		
		_immobilized_icon.visible = false

func _setup_damage_smoke():
	if is_instance_valid(_hit_smoke_particles):
		_hit_smoke_particles.queue_free()
		
	_hit_smoke_particles = CPUParticles3D.new()
	add_child(_hit_smoke_particles)
	_hit_smoke_particles.name = "HealthSmoke"
	
	_hit_smoke_particles.emitting = false
	_hit_smoke_particles.amount = 40 # Reduced for performance
	_hit_smoke_particles.lifetime = 2.5
	_hit_smoke_particles.randomness = 0.8
	
	# Emission based on DamageSmokeZone
	_hit_smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	
	var zone_node = get_node_or_null("DamageSmokeZone")
	if zone_node:
		_hit_smoke_particles.position = zone_node.position
		_hit_smoke_particles.emission_box_extents = zone_node.scale
	else:
		_hit_smoke_particles.position = Vector3(0, 4, 0)
		_hit_smoke_particles.emission_box_extents = Vector3(5, 1, 15) 
	
	_hit_smoke_particles.direction = Vector3(0, 1, 0)
	_hit_smoke_particles.spread = 10.0 
	_hit_smoke_particles.gravity = Vector3(0, 3, 0)
	_hit_smoke_particles.initial_velocity_min = 1.0
	_hit_smoke_particles.initial_velocity_max = 4.0
	_hit_smoke_particles.angle_max = 360.0
	_hit_smoke_particles.local_coords = true
	
	# Mesh plus petit et optimisé
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = 1.2
	sphere.height = 2.4
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	_hit_smoke_particles.mesh = sphere
	
	# Expansion progressive et douce
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.7)) # Commence plus gros
	curve.add_point(Vector2(1, 6.0))
	_hit_smoke_particles.scale_amount_curve = curve
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.4, 0.4, 0.4, 0.0))    
	gradient.set_color(1, Color(0.2, 0.2, 0.2, 0.3)) # Sombre et discret
	_hit_smoke_particles.color_ramp = gradient
	
	# (La position est déjà gérée plus haut via zone_node)

func _init_components():
		
	var mesh_node = get_node_or_null("sloup")
	if mesh_node:
		visual_mast = _find_child_recursive(mesh_node, "Mast")
		visual_wheel = _find_child_recursive(mesh_node, "ShipWheel")
		visual_sails = _find_child_recursive(mesh_node, "Sails")
		
		# Fallbacks if names differ
		if not visual_wheel: visual_wheel = _find_child_recursive(mesh_node, "wheel")
		if not visual_mast: visual_mast = _find_child_recursive(mesh_node, "mat")
		
		if visual_mast: base_mast_rot = visual_mast.rotation
		if visual_sails: 
			base_sails_rot = visual_sails.rotation
			base_sails_scale = visual_sails.scale
			base_sails_pos = visual_sails.position
		if visual_wheel: base_wheel_rot = visual_wheel.rotation
	
	_apply_sail_color()
	_setup_shield_visual()
	_setup_flag_label()






func _setup_flag_label():
	# 1. Priorité à un noeud placé manuellement par le joueur dans l'éditeur
	# On cherche un noeud nommé "FlagLabel" (doit être un Label3D)
	_flag_label = find_child("FlagLabel", true, false)
	
	if _flag_label:
		print("ID Label trouvé manuellement dans l'éditeur !")
		_flag_label.render_priority = 10
		_flag_label.no_depth_test = true
	else:
		# 2. Fallback automatique sur le mesh du drapeau
		var mesh_node = get_node_or_null("sloup")
		if mesh_node:
			var flag_node = _find_child_recursive(mesh_node, "Flag")
			if not flag_node:
				flag_node = _find_node_with_partial_name(mesh_node, "Flag")
			
			if flag_node:
				_flag_label = Label3D.new()
				flag_node.add_child(_flag_label)
				_flag_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				_flag_label.render_priority = 10
				_flag_label.no_depth_test = true
				_flag_label.pixel_size = 0.1
				_flag_label.font_size = 120
				_flag_label.outline_size = 30
				_flag_label.modulate = Color(0, 0, 0)
				_flag_label.position = Vector3(0, 1.0, 0) 
				_flag_label.rotation_degrees = Vector3(0, 90, 0)

	# 3. Application du numéro (si déjà connu)
	if _flag_label and _fleet_num != -1:
		set_fleet_number(_fleet_num)

func _find_node_with_partial_name(root: Node, p_name: String) -> Node:
	if root.name.find(p_name) != -1:
		return root
	for child in root.get_children():
		var res = _find_node_with_partial_name(child, p_name)
		if res: return res
	return null

func set_fleet_number(num: int):
	_fleet_num = num # Mémorisation
	if _flag_label:
		if num == 1:
			_flag_label.text = "👑"
			_flag_label.modulate = Color(0, 0, 0) # Noir
		elif num > 1:
			_flag_label.text = str(num)
			_flag_label.modulate = Color(0, 0, 0) # Noir
		else:
			_flag_label.text = ""

func _setup_shield_visual():
	_shield_visual = MeshInstance3D.new()
	add_child(_shield_visual)
	_shield_visual.name = "ShieldVisual"
	
	var sphere = SphereMesh.new()
	sphere.radius = 100.0
	sphere.height = 200.0
	_shield_visual.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.14, 0.45, 0.8, 0.2) # Bleu translucide
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 1.0
	mat.roughness = 0.1
	
	_shield_visual.material_override = mat
	_shield_visual.visible = false

func activate_shield(strength: float, duration: float):
	current_shield = strength
	if _shield_visual:
		_shield_visual.visible = true
		var tween = create_tween()
		tween.tween_property(_shield_visual, "scale", Vector3(1.1, 1.1, 1.1), 0.2).from(Vector3(0.5, 0.5, 0.5))
	
	# Le bouclier expire après la durée si pas détruit avant
	var t = get_tree().create_timer(duration)
	t.timeout.connect(func():
		if is_instance_valid(self) and current_shield > 0:
			current_shield = 0
			_hide_shield()
	)

func _hide_shield():
	if _shield_visual:
		var tween = create_tween()
		tween.tween_property(_shield_visual, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
		tween.tween_callback(func(): _shield_visual.visible = false)

func _apply_sail_color():
	if not visual_sails: return
	_set_sail_material_recursive(visual_sails)

func _set_sail_material_recursive(node: Node):
	if node is MeshInstance3D:
		var mat = node.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			node.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			# Sky Blue for all player fleet ships
			mat.albedo_color = Color(0.5, 0.8, 1.0)
			mat.roughness = 0.8
	for child in node.get_children():
		_set_sail_material_recursive(child)

func _find_child_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		# Using match/find case insensitively
		if child.name.to_lower().find(target_name.to_lower()) != -1:
			return child
		var res = _find_child_recursive(child, target_name)
		if res: return res
	return null

func _init_stats():
	# Si max_speed est à son défaut, on utilise la config globale. 
	# Sinon on garde la valeur d'Inspecteur
	var use_config = (max_speed == 35.0 or max_speed == 0.0)
	
	match ship_type:
		ShipClass.SLOOP:
			max_hp = GameConfig.SloopHP
			if use_config: max_speed = GameConfig.SloopSpeed
			max_cooldown = GameConfig.SloopCooldown
		ShipClass.BRIGANTINE:
			max_hp = GameConfig.BrigantineHP
			if use_config: max_speed = GameConfig.BrigantineSpeed
			max_cooldown = GameConfig.BrigantineCooldown
		ShipClass.GALLEON:
			max_hp = GameConfig.GalleonHP
			if use_config: max_speed = GameConfig.GalleonSpeed
			max_cooldown = GameConfig.GalleonCooldown
	hp = max_hp
func _physics_process(delta):
	# 1. GESTION DES TIMERS (pour tous les navires)
	if not is_sinking:
		for i in range(weapon_cooldowns.size()):
			if weapon_cooldowns[i] > 0:
				weapon_cooldowns[i] -= delta
			
		if skill_timer > 0:
			skill_timer -= delta
			if skill_timer <= 0:
				current_speed_buff = 1.0

		if wind_boost_timer > 0:
			wind_boost_timer -= delta
			if wind_boost_timer <= 0:
				is_wind_boost_active = false
				
		if immobilization_timer > 0:
			immobilization_timer -= delta

	# 2. VÉRIFICATION DE LA CHUTE DU NAVIRE (Sortie de carte)
	# PERFORMANCE: Fixed water height (0.0) instead of wave calculation
	# On garde le calcul complet uniquement pour le bateau contrôlé par le joueur pour l'immersion
	var water_h = 0.0
	if is_controlled and not is_underwater:
		water_h = _get_water_height(global_position, Time.get_ticks_msec() / 1000.0)
	elif is_underwater:
		water_h = current_dive_depth
	
	# 2. GESTION DES LIMITES DU MONDE (Chute libre)
	_handle_map_limits(delta)
	
	if _is_falling:
		velocity.y -= 40.0 * delta # Gravité de chute
		_falling_timer += delta
		if _falling_timer > 3.0 and not is_sinking:
			take_damage(2000.0, null)
	else:
		_falling_timer = 0.0
		# Rectification immédiate de la hauteur si on est sur l'eau
		if not is_sinking:
			global_position.y = lerp(global_position.y, water_h, delta * 5.0)
			velocity.y = 0

	# 3. MOUVEMENT ET COLLISIONS
	if not is_sinking:
		if is_controlled:
			_handle_weapons(delta)
		
		_handle_movement_logic(delta)
		
		# Logic modulaire des compétences (certaines modifient velocity)
		for slot in weapon_slots:
			if slot and slot.has_method("process_tick"):
				slot.process_tick(self, delta)
		
		# Knockback physique
		if knockback_velocity.length_squared() > 1.0:
			velocity += knockback_velocity
			knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * knockback_decay)
			
		if _falling_timer < 0.5:
			move_and_slide()
		else:
			# Mode "Chute libre"
			global_position += velocity * delta
	else:
		# En train de couler (tween)
		pass
	
	_update_damage_visuals(delta)
	_update_professional_camera(delta)

func _update_damage_visuals(delta):
	if not _hit_smoke_particles: return
	
	var hp_ratio = hp / max_hp
	
	# Fume uniquement si HP <= 35%
	if (hp <= 35.0 or hp_ratio < 0.35) and not is_sinking and not is_underwater:
		if not _hit_smoke_particles.emitting:
			_hit_smoke_particles.emitting = true
		
		# Couleur fixe : Gris foncé / Noir sobre
		var grad = _hit_smoke_particles.color_ramp as Gradient
		grad.set_color(1, Color(0.1, 0.1, 0.1, 0.5)) # Gris foncé vaporeux
	else:
		if _hit_smoke_particles.emitting:
			_hit_smoke_particles.emitting = false
	
	# Gestion de l'icône d'immobilisation (Maintenant un filet 3D)
	if _immobilized_icon:
		if immobilization_timer > 0:
			_immobilized_icon.visible = true
			# Animation de flotte et rotation
			var t = float(Time.get_ticks_msec()) / 1000.0
			
			var base_y = 48.0
			var zone_node = get_node_or_null("StatusEffectsZone")
			if zone_node:
				base_y = zone_node.position.y
				_immobilized_icon.position.x = zone_node.position.x
				_immobilized_icon.position.z = zone_node.position.z
			
			_immobilized_icon.position.y = base_y
			# Rotation lente pour montrer la 3D
			_immobilized_icon.rotation.y += delta * 2.0
		else:
			_immobilized_icon.visible = false
	
	# POST-PHYSIQUE (exécuté après move_and_slide pour les skills qui modifient la position)
	for slot in weapon_slots:
		if slot and slot.has_method("post_physics_tick"):
			slot.post_physics_tick(self, delta)

func _handle_movement_logic(delta):
	var steer = 0.0
	var throttle = 0.0
	
	if is_controlled:
		var move_f = Input.is_action_pressed("move_forward")
		var move_b = Input.is_action_pressed("move_backward")
		var move_l = Input.is_action_pressed("move_left")
		var move_r = Input.is_action_pressed("move_right")
		
		if move_f or move_b or move_l or move_r:
			if is_auto_cruising or follow_target or is_defending:
				is_auto_cruising = false
				follow_target = null
				is_defending = false
			
			if move_l: steer = 1.0
			elif move_r: steer = -1.0
			if move_f: throttle = 1.0
			elif move_b: throttle = -1.0
		else:
			_process_autonomous_behavior(delta)
			return
	else:
		_process_autonomous_behavior(delta)
		return

	_apply_movement_physics(delta, steer, throttle)
	_apply_visuals(delta, steer)

func _process_autonomous_behavior(delta):
	var steer = 0.0
	var throttle = 0.0
	
	if is_defending:
		_handle_defense_mode(delta)
		_apply_movement_physics(delta, 0.0, 0.0)
		_apply_visuals(delta, 0.0)
		return

	if follow_target and is_instance_valid(follow_target):
		var to_target = follow_target.global_position - global_position
		var dist = to_target.length()
		var target_yaw = atan2(to_target.x, to_target.z)
		var angle_diff = wrapf(target_yaw - global_rotation.y, -PI, PI)
		
		if abs(angle_diff) > 0.1:
			steer = clamp(angle_diff * 2.0, -1.0, 1.0)
		
		if dist > 200.0: throttle = 1.0
		elif dist > 120.0: throttle = 0.5
		elif dist < 80.0: throttle = -0.3
		
		_apply_movement_physics(delta, steer, throttle)
		_apply_visuals(delta, steer)
		return

	if is_auto_cruising:
		_apply_movement_physics(delta, 0.0, 0.8)
		_apply_visuals(delta, 0.0)
		return
	
	_apply_movement_physics(delta, 0.0, 0.0)
	_apply_visuals(delta, 0.0)

func _handle_defense_mode(delta):
	if defense_skill_index != -1:
		var skill = weapon_slots[defense_skill_index]
		# IA de défense simplifiée : tire sur l'ennemi le plus proche si possible
		# Cela sera géré par les scripts d'armes s'ils ont une logique autonome
		pass

func _unhandled_input(event: InputEvent):
	if _is_map_open():
		return
		
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# Caméra à la souris
	if is_controlled:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().set_input_as_handled()
			
		if event is InputEventMouseMotion:
			# Rotation de la caméra (Uniquement au Clic Droit pour le confort)
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_cam_yaw -= event.relative.x * camera_sensitivity
				# Pitch bloqué selon la demande utilisateur
				get_viewport().set_input_as_handled()

	# Re-capture la souris en cliquant dans le jeu
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# On n'empêche plus le clic gauche de servir à l'UI. Le clic doit passer !
		pass
		
func _is_map_open() -> bool:
	var map_nodes = get_tree().get_nodes_in_group("map_ui")
	for m in map_nodes:
		if m.visible:
			return true
	return false

func _handle_weapons(delta):
	# Mise à jour des cooldowns
	if basic_cannon_cooldown > 0:
		basic_cannon_cooldown -= delta
	for i in range(weapon_cooldowns.size()):
		if weapon_cooldowns[i] > 0:
			weapon_cooldowns[i] -= delta

	if _is_map_open():
		if _grapple: _grapple.hide_aiming()
		return

	# Mise à jour de la visée grappin
	var current_weapon = weapon_slots[active_weapon_index] if active_weapon_index < weapon_slots.size() else null
	if _grapple and current_weapon and current_weapon.type == WeaponData.ActionType.GRAPPLE and not _grapple.is_pulling:
		var mouse_pos = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_3d()
		if camera:
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * 10000.0
			var intersection = Plane(Vector3.UP, global_position.y).intersects_ray(from, to)
			if intersection:
				_grapple.update_aiming(global_position, intersection)
	elif _grapple and not _grapple.is_pulling:
		_grapple.hide_aiming()

	# 1. Touche 1-5 : sélection / annulation
	for i in range(5):
		var action_name = "skill_" + str(i+1)
		if Input.is_action_just_pressed(action_name) and i < weapon_slots.size():
			var action = weapon_slots[i]
			if active_weapon_index == i or (action and action.type == WeaponData.ActionType.GRAPPLE and _grapple and (_grapple.is_pulling or _grapple.is_launching)):
				active_weapon_index = -1
				if _grapple: _grapple.cancel()
			else:
				active_weapon_index = i
				if action and action.type != WeaponData.ActionType.GRAPPLE:
					shoot_cannons(i)
					active_weapon_index = -1

	# 2. Clic gauche : tir du grappin
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var cur = weapon_slots[active_weapon_index] if active_weapon_index < weapon_slots.size() else null
		if cur and cur.type == WeaponData.ActionType.GRAPPLE and is_controlled and _grapple and not _grapple.is_pulling:
			if (is_diving or is_underwater):
				return # Bloqué sous l'eau
			if weapon_cooldowns[active_weapon_index] <= 0 and ammo >= cur.ammo_cost:
				_grapple.fire()
				weapon_cooldowns[active_weapon_index] = cur.cooldown
				ammo -= cur.ammo_cost
				active_weapon_index = -1


func _fire_simple_cannon():
	if not BasicCannonResource: return
	
	if ammo < BasicCannonResource.ammo_cost:
		weapon_blocked.emit(-1)
		return
		
	basic_cannon_cooldown = BasicCannonResource.cooldown
	ammo -= BasicCannonResource.ammo_cost
	_fire_cannons(BasicCannonResource)
	

	
func _apply_movement_physics(delta, steer, throttle, sync_group = false):
	# --- GRAPPIN : Rotation douce si en cours de pull ---
	if _grapple and _grapple.is_pulling:
		var pull_dir = (_grapple.target_pos - global_position).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(pull_dir.x, pull_dir.z), delta * 2.0)


	# Si le bateau est immobilisé (ex: par un filet de pêche), on bloque les commandes
	if immobilization_timer > 0:
		steer = 0.0
		throttle = 0.0
		
	# Application de la rotation (Correction du sens : += pour tourner vers la cible)
	if steer != 0:
		rotation.y += steer * turn_speed * delta
	
	var max_reverse_speed = max_speed * 0.15
	
	if throttle > 0: # Accélérer
		ship_speed = move_toward(ship_speed, max_speed * current_speed_buff, acceleration * current_speed_buff * delta)
	elif throttle < 0: # Reculer
		ship_speed = move_toward(ship_speed, -max_reverse_speed, acceleration * 0.8 * delta)
	else: # Freinage naturel
		var friction = 0.6
		if is_in_port_zone:
			friction = 2.5 # On garde un freinage puissant si on lâche les gaz au port pour aider à accoster
		ship_speed = move_toward(ship_speed, 0, acceleration * friction * delta)
		
	var forward = transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	# --- VENT DE BASE (Fallback si aucun WindControl n'est équipé) ---
	# Si un WindControl est dans les slots, c'est LUI qui calcule velocity via process_tick.
	# Sinon, on applique le vent normal ici.
	var has_wind_skill = false
	for slot in weapon_slots:
		if slot and slot.type == WeaponData.ActionType.WIND_CONTROL:
			has_wind_skill = true
			break
	
	if not has_wind_skill:
		var local_wind = GameConfig.get_wind_at(global_position)
		var wind_dir = local_wind["direction"]
		var effective_wind_speed = local_wind["speed"]
		
		var target_wind_vec = Vector3(wind_dir.x, 0, wind_dir.y) * effective_wind_speed
		
		if current_wind_vec_phys == Vector3.ZERO:
			current_wind_vec_phys = target_wind_vec
		current_wind_vec_phys = current_wind_vec_phys.lerp(target_wind_vec, delta * 1.5)
		
		is_underwater = current_dive_depth < -5.0
		var wind_push = forward.dot(current_wind_vec_phys) if not is_underwater else 0.0
		
		# TWEAK: Balanced speed relative to wind using exported variables
		var wind_influence = wind_influence_with
		if wind_push < 0:
			wind_influence = wind_influence_against
		
		var speed_modifier = 1.0 + (wind_push * wind_influence) if not is_underwater else 1.0
		if is_in_port_zone:
			speed_modifier = 1.0 # Le vent ne pousse pas au port
		
		velocity = forward * min(ship_speed * speed_modifier, 1200.0)
		velocity.y = 0
		
		if ship_speed > 0 and not is_underwater:
			var drift = current_wind_vec_phys - (forward * wind_push)
			if is_in_port_zone: drift *= 0.05 # Quasiment plus de dérive au port
			velocity += drift * 0.1
			velocity.y = 0
	
	_apply_separation(delta)
	
	# --- FORCE DU GRAPPIN ---
	if _grapple:
		var gforce = _grapple.process_and_get_pull_force(delta, global_position, velocity)
		velocity += gforce * delta
		# Limitation de vitesse pendant le pull
		if _grapple.is_pulling and velocity.length() > 60.0:
			velocity = velocity.lerp(velocity.normalized() * 45.0, delta * 2.0)

func _apply_separation(delta):
	var push = Vector3.ZERO
	var comfort_zone = 130.0 # Distance minimum souhaitée
	var my_group = get_tree().get_nodes_in_group("player")
	
	for other in my_group:
		if other == self or not is_instance_valid(other) or other.is_sinking: continue
		
		var to_me = global_position - other.global_position
		to_me.y = 0
		var dist = to_me.length()
		
		if dist < comfort_zone and dist > 0.5:
			# Plus on est proche, plus la poussée est forte
			var strength = (comfort_zone - dist) / comfort_zone
			push += to_me.normalized() * strength * 400.0 * delta
	
	velocity += push

	

func _apply_visuals(delta, steer):
	if is_sinking: return  # Le tween de naufrage gère les visuels
	var mesh_node = get_node_or_null("sloup")
	if not mesh_node: return
	
	var t = Time.get_ticks_msec() / 1000.0
	var forward = transform.basis.z
	
	var wind_vec3 = Vector3(0, 0, 0)
	var wind_speed_val = 0.0
	
	# Récupère le vent physique actuel (déjà interpolé dans _physics_process)
	if "current_wind_vec_phys" in self:
		wind_vec3 = get("current_wind_vec_phys")
		wind_speed_val = wind_vec3.length()
	else:
		var local_wind = GameConfig.get_wind_at(global_position)
		wind_vec3 = Vector3(local_wind["direction"].x, 0, local_wind["direction"].y) * local_wind["speed"]
		wind_speed_val = local_wind["speed"]
	
	# --- REALISTIC HEELING (La Gîte) ---
	var side_pressure = forward.cross(wind_vec3).y * wind_speed_val
	var target_heeling = side_pressure * 0.08 
	
	var heeling_rot = (cos(t * 1.0) * 0.08) + target_heeling + (current_steer_angle * 0.08)
	var pitch_wave = sin(t * 1.2) * 0.08
	mesh_node.rotation = Vector3(pitch_wave + current_dive_tilt, mesh_node.rotation.y, heeling_rot)
	mesh_node.position = Vector3(mesh_node.position.x, sin(t * 2.0) * 0.4, mesh_node.position.z)
	
	# Visual Steering for Mast and Wheel
	current_steer_angle = lerp(current_steer_angle, steer, delta * 3.0)
	
	if visual_wheel:
		visual_wheel.transform.basis = Basis.from_euler(base_wheel_rot)
		visual_wheel.rotate_object_local(Vector3(0, 0, 1), -current_steer_angle * 8.0)
	
	if visual_mast:
		visual_mast.transform.basis = Basis.from_euler(base_mast_rot)
		
		var wind_world_angle = atan2(wind_vec3.x, wind_vec3.z)
		var ship_world_angle = global_rotation.y
		var relative_wind_angle = wrapf(wind_world_angle - (ship_world_angle + PI), -PI, PI)
		
		var target_mast_angle = clamp(relative_wind_angle * 0.45, -deg_to_rad(70), deg_to_rad(70))
		var flutter = 0.0
		if abs(relative_wind_angle) > PI * 0.8:
			flutter = sin(Time.get_ticks_msec() * 0.01) * 0.02
		
		current_sail_angle = lerp_angle(current_sail_angle, target_mast_angle + flutter, delta * mast_lerp_speed)
		visual_mast.rotation = base_mast_rot
		visual_mast.rotate_object_local(Vector3(0, 1, 0), current_sail_angle)
		
		if visual_sails:
			visual_sails.rotation = base_sails_rot
			var mast_basis = visual_mast.global_transform.basis
			var mast_local_wind = mast_basis.inverse() * wind_vec3
			
			var side_sign = 1.0 if mast_local_wind.x < 0 else -1.0
			var target_inflation = sail_inflation_left if side_sign > 0 else sail_inflation_right
			var target_offset = sail_offset_left if side_sign > 0 else sail_offset_right
			
			var target_scale = Vector3(base_sails_scale.x * target_inflation * side_sign, base_sails_scale.y, base_sails_scale.z)
			var target_pos = Vector3(base_sails_pos.x + target_offset, base_sails_pos.y, base_sails_pos.z)
				
			visual_sails.scale = lerp(visual_sails.scale, target_scale, delta * sail_lerp_speed)
			visual_sails.position = lerp(visual_sails.position, target_pos, delta * sail_lerp_speed)

	
	# Visual Stealth/Underwater check
	is_underwater = current_dive_depth < -5.0

func shoot_cannons(slot_index: int = -1):
	var index = slot_index if slot_index != -1 else active_weapon_index
	if index < 0 or index >= weapon_slots.size(): return
	
	var action = weapon_slots[index]
	if not action: return
	
	if weapon_cooldowns[index] > 0: return # Déjà en recharge
	

	# Le grappin est géré directement dans _handle_weapons via GrapplingHookSystem
	if action.type == WeaponData.ActionType.GRAPPLE:
		return

	# Check munition
	if ammo < action.ammo_cost:
		weapon_blocked.emit(index)
		return
	# Check if the action is allowed underwater (Diving state or actual Depth)
	var underwater = is_diving or is_underwater
	if underwater and action.get("can_be_used_underwater") == false:
		weapon_blocked.emit(active_weapon_index)
		return

	
	if action.has_method("is_action_blocked") and action.is_action_blocked(self):
		weapon_blocked.emit(active_weapon_index)
		return

	
	weapon_cooldowns[index] = action.cooldown
	ammo -= action.ammo_cost

	# LOGIQUE D'EXÉCUTION MODULAIRE : Chaque ressource sait ce qu'elle doit faire
	action.activate(self)


func _fire_cannons(weapon: WeaponData):
	var projectile_speed = weapon.projectile_speed
	var count = weapon.projectile_count if weapon.projectile_count > 0 else 1
	var spread = weapon.projectile_spread
	
	# Port (Left)
	var port_marker = get_node_or_null("Cannons/PortCannon1")
	if port_marker:
		for i in range(count):
			var dir = -global_transform.basis.x
			if spread > 0 and count > 1:
				var angle_offset = randf_range(-spread, spread)
				dir = dir.rotated(Vector3.UP, angle_offset)
			_fire_projectile(port_marker, dir, projectile_speed, weapon)
	
	# Starboard (Right)
	var starboard_marker = get_node_or_null("Cannons/StarboardCannon1")
	if starboard_marker:
		for i in range(count):
			var dir = global_transform.basis.x
			if spread > 0 and count > 1:
				var angle_offset = randf_range(-spread, spread)
				dir = dir.rotated(Vector3.UP, angle_offset)
			_fire_projectile(starboard_marker, dir, projectile_speed, weapon)

# Removed _use_grapple and _use_skill as they are now handled by WeaponData.activate()

func _fire_projectile(marker: Marker3D, direction: Vector3, speed: float, weapon: WeaponData = null):
	var proj = ProjectileScene.instantiate() as Projectile
	get_tree().get_root().add_child(proj)
	proj.global_position = marker.global_position
	
	# Taille du boulet (petit pour mitraille, normal sinon)
	var s = weapon.projectile_scale if weapon else 2.2
	proj.scale = Vector3(s, s, s)
	
	# Velocity avec léger arc vers le haut + variation pour mitraille
	proj.velocity = velocity + (direction.normalized() * speed)
	proj.velocity.y += 12.0
	if weapon and weapon.projectile_count > 1:
		proj.velocity.y += randf_range(-4.0, 8.0) # Variation verticale
		proj.velocity += Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		proj.max_life_time = 0.3 # Disparaît vite comme demandé (Mitraille)
	
	proj.damage = weapon.damage if weapon else damage
	proj.is_player_owned = is_player
	proj.owner_ship = get_path()
	
	# Color the projectile if weapon has a color
	if weapon and proj.has_node("MeshInstance3D"):
		var mesh = proj.get_node("MeshInstance3D") as MeshInstance3D
		var mat = StandardMaterial3D.new()
		mat.albedo_color = weapon.projectile_color
		mat.metallic = 0.8
		mat.roughness = 0.2
		mesh.material_override = mat
	
	# Smoke Effect
	var smoke = SmokeScene.instantiate() as Node3D
	marker.add_child(smoke)
	smoke.position = Vector3.ZERO
	smoke.look_at(smoke.global_position + direction.normalized(), Vector3.UP)

func apply_knockback(from_pos: Vector3, force: float):
	# Direction du knockback : s'éloigner de la tentacule, horizontalement
	var dir = (global_position - from_pos)
	dir.y = 0
	if dir.length_squared() < 0.001:
		dir = -transform.basis.z  # fallback : repousser vers l'avant
	dir = dir.normalized()

	knockback_velocity = dir * force

func apply_immobilization(duration: float):
	# Applique un root/immobilisation pour la durée spécifiée
	immobilization_timer = max(immobilization_timer, duration)
	print("⚓ " + name + " est immobilisé pour " + str(duration) + " secondes !")

var is_flashing: bool = false
var flash_mat: StandardMaterial3D = null

func _flash_hit():
	if is_flashing or is_sinking: return
	is_flashing = true
	
	if not flash_mat:
		flash_mat = StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		flash_mat.albedo_color = Color(0.8, 0, 0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0, 0)
		flash_mat.emission_energy_multiplier = 4.0
	
	var meshes: Array = []
	var sloup_node = get_node_or_null("sloup")
	if sloup_node:
		_collect_visible_meshes(sloup_node, meshes)
		
	var orig_mats = []
	var edited_meshes = []
	
	for mi in meshes:
		if not is_instance_valid(mi) or not mi.mesh: continue
		orig_mats.append(mi.get_surface_override_material(0))
		edited_meshes.append(mi)
		mi.set_surface_override_material(0, flash_mat)
	
	# Utilisation d'un tween pour le reset (plus propre que await Timer)
	var tw = create_tween()
	tw.tween_interval(0.08) # Plus court
	tw.set_parallel(false)
	tw.tween_callback(func():
		for i in range(edited_meshes.size()):
			var mi = edited_meshes[i]
			if is_instance_valid(mi):
				mi.set_surface_override_material(0, orig_mats[i])
		is_flashing = false
	)

func _collect_visible_meshes(node: Node, result: Array):
	if node is MeshInstance3D and node.visible:
		result.append(node)
	for child in node.get_children():
		_collect_visible_meshes(child, result)

func take_damage(amount: float, attacker: Node3D):
	if is_sinking: return  # Ignore les dégâts pendant le naufrage
	
	if current_shield > 0:
		var absorbed = min(current_shield, amount)
		current_shield -= absorbed
		amount -= absorbed
		print("🛡️ Bouclier absorbe ", absorbed, " dégâts. Reste: ", current_shield)
		
		# Feedback visuel impact bouclier
		if _shield_visual:
			var mat = _shield_visual.material_override
			if mat is StandardMaterial3D:
				var tw = create_tween()
				tw.tween_property(mat, "emission_energy_multiplier", 15.0, 0.05)
				tw.tween_property(mat, "emission_energy_multiplier", 1.0, 0.2)
			
		if current_shield <= 0:
			_hide_shield()
			
	if amount <= 0: return

	hp -= amount
	_flash_hit()
	if hp <= 0:
		_start_sinking()



func heal(amount: float):
	hp = min(hp + amount, max_hp)

func _start_sinking():
	if is_sinking: return
	is_sinking = true
	set_physics_process(false)
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO

	print("🌊 Naufrage de ", name, "...")

	var mesh = get_node_or_null("sloup")
	if not mesh:
		_on_sink_complete()
		return

	# Repart d'une rotation propre pour éviter les conflits avec _apply_visuals
	mesh.rotation = Vector3.ZERO

	var tilt_dir = 1.0 if randf() > 0.5 else -1.0
	var duration = 4.0

	var tw = create_tween()
	tw.set_parallel(true)

	# 1. Chavirement latéral progressif (80°)
	tw.tween_property(mesh, "rotation:z",
		deg_to_rad(80.0) * tilt_dir, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 2. Inclinaison avant (proue plonge en premier)
	tw.tween_property(mesh, "rotation:x",
		deg_to_rad(22.0), duration * 0.70
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 3. Descente dans l'eau (accélère au fur et à mesure)
	tw.tween_property(mesh, "position:y",
		-90.0, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 4. Fin : death screen ou loot
	tw.chain().tween_callback(_on_sink_complete)

func _on_sink_complete():
	if is_player:
		# Laisse le FleetManager gérer si on doit switch ou Game Over
		FleetManager.remove_ship(self)
	else:
		queue_free()

func respawn():
	# Restaure l'état du bateau pour qu'il revive sur la carte
	hp = max_hp
	is_sinking = false
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	ship_speed = 0.0
	
	# Réactive la physique
	set_physics_process(true)
	
	# Replace le bateau à une position de spawn (par défaut proche du centre pour l'instant)
	# On le met au niveau de l'eau (Y=0) pour qu'il puisse toucher les barils (qui	# Réinitialise la position
	global_position = Vector3(0, 0, 0)
	global_rotation = Vector3.ZERO
	
	# Réinitialise les visuels (qui étaient tordus par le naufrage)
	var mesh = get_node_or_null("sloup")
	if mesh:
		mesh.rotation = Vector3.ZERO
		mesh.position = Vector3(0, 0, 0) # Remet d'aplomb
	
	print("⚓ ", name, " a réapparu sur la carte !")

func _setup_camera_wind_waker():
	if not is_controlled: return
	
	_cam_node = find_child("Camera3D", true, false)
	if not _cam_node:
		_cam_node = Camera3D.new()
		add_child(_cam_node)
		_cam_node.name = "Camera3D"
	
	_cam_node.set_as_top_level(true) # On le détache pour un suivi ultra-fluide
	_cam_node.make_current() 
	_cam_node.far = 10000.0 
	
	# Initialisation derrière le bateau
	_cam_yaw = global_rotation.y + PI

func _update_professional_camera(delta):
	if not is_controlled or not _cam_node: return
	
	# 1. AUTO-ALIGNEMENT : DÉSACTIVÉ selon la demande utilisateur
	# La caméra ne tourne plus seule quand le bateau tourne.
	
	# Banking (Inclinaison)
	var steer_v = 0.0
	if Input.is_action_pressed("move_left"): steer_v = 1.0
	elif Input.is_action_pressed("move_right"): steer_v = -1.0
	_cam_tilt_target = lerp(_cam_tilt_target, steer_v * 0.1, delta * 2.0)
	
	# 2. LISSAGE DES ANGLES (Au lieu de la position)
	# Cela évite que la caméra ne se rapproche du bateau lors d'une rotation rapide
	_cam_yaw_smooth = lerp_angle(_cam_yaw_smooth, _cam_yaw, delta * camera_smoothing)
	_cam_tilt_smooth = lerp(_cam_tilt_smooth, _cam_tilt_target, delta * 2.0)
	
	# 3. CALCUL DE LA POSITION (Orbitale stricte)
	var rot_quat = Quaternion.from_euler(Vector3(_cam_pitch, _cam_yaw_smooth, _cam_tilt_smooth))
	var offset = rot_quat * Vector3(0, 0, camera_distance)
	var target_pos = global_position + Vector3(0, camera_height, 0) + offset
	
	# La caméra reste sur un cercle parfait, fini l'effet de rapprochement
	_cam_node.global_position = target_pos
	_cam_node.look_at(global_position + Vector3(0, camera_height * 0.4, 0), Vector3.UP)

func _get_water_height(pos: Vector3, _time_val: float) -> float:
	return 0.0

func _handle_map_limits(delta: float):
	var limit_x = GameConfig.MAP_WIDTH * 0.5
	var limit_z = GameConfig.MAP_HEIGHT * 0.5
	
	var pos = global_position
	if abs(pos.x) > limit_x or abs(pos.z) > limit_z:
		_is_falling = true
	else:
		_is_falling = false

func switch_ship(new_type: ShipClass, scene_path: String):
	ship_type = new_type
	
	# Sauvegarde du FlagLabel s'il est MANUEL pour le remettre sur le nouveau mesh
	# (Les labels auto sont supprimés et recréés pour s'adapter au nouveau modèle)
	var preserved_label = _flag_label
	var is_manual = preserved_label and preserved_label.name == "FlagLabel"
	
	if is_instance_valid(preserved_label) and is_manual and preserved_label.get_parent():
		preserved_label.reparent(self)

	# Suppression de l'ancien mesh
	var old_mesh = get_node_or_null("sloup")
	if old_mesh:
		old_mesh.name = "OLD_MESH"
		old_mesh.queue_free()
	
	# Chargement du nouveau mesh
	var new_scene = load(scene_path)
	if new_scene:
		var new_mesh = new_scene.instantiate()
		new_mesh.name = "sloup"
		add_child(new_mesh)
		
		# Remettre le label manuel sur le nouveau mesh
		if is_instance_valid(preserved_label) and is_manual:
			preserved_label.reparent(new_mesh)
	
	# Réinitialisation des stats et des composants visuels
	_init_stats()
	_init_components()
	_setup_immobilized_icon()
	_setup_camera_wind_waker()
	
	print("⚓ Navire changé pour un : ", ship_type)

func set_controlled(active: bool):
	is_controlled = active
	
	# Active la caméra enfant si elle existe
	var cam = find_child("Camera3D", true, false)
	if cam and cam is Camera3D:
		cam.current = active
	
	if active:
		add_to_group("player")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Souris libre par défaut pour V Rising
	else:
		if is_in_group("player"):
			remove_from_group("player")

func sell_ship():
	# On ne peut pas vendre le bateau principal (index 0 dans la flotte)
	if FleetManager.ships[0] == self:
		print("Impossible de vendre le navire amiral !")
		return
		
	# Calcul du prix de revente (70% du prix d'achat, ou 150 si prix inconnu)
	var resale_value = int(purchase_price * 0.7) if purchase_price > 0 else 150
	FleetManager.gold += resale_value
	print("💰 Navire vendu pour ", resale_value, " Or")
	
	# Le stuff tombe dans l'eau
	_drop_loot_on_sale()
	
	# Suppression de la flotte et destruction
	# find_and_switch_to_next_ship sera appelé par FleetManager.remove_ship
	FleetManager.remove_ship(self)
	queue_free()

func _drop_loot_on_sale():
	# On fait tomber le bois, la nourriture, etc.
	var resources = {
		"wood": Loot.LootType.WOOD,
		"food": Loot.LootType.FOOD,
		"water": Loot.LootType.WATER,
		"fish": Loot.LootType.FOOD # On recycle le poisson en food
	}
	
	var inventory = {
		"wood": wood,
		"food": food,
		"water": water,
		"fish": fish
	}
	
	for res_name in inventory:
		var amount_to_drop = inventory[res_name]
		if amount_to_drop > 0:
			var loot = LootScene.instantiate()
			get_tree().current_scene.add_child(loot)
			loot.global_position = global_position + Vector3(randf_range(-15, 15), 5.0, randf_range(-15, 15))
			if loot.has_method("setup"):
				loot.setup(resources[res_name], amount_to_drop)
