class_name EnemyShip
extends CharacterBody3D

enum ShipClass { SLOOP, BRIGANTINE, GALLEON }
enum Faction { PLAYER, NAVY, PIRATE, MERCHANT }

var is_player: bool = false
@export var ship_type: ShipClass = ShipClass.SLOOP
@export var ship_color: Color = Color.WHITE
@export var faction: Faction = Faction.NAVY

var hp: float
var max_hp: float
var ship_speed: float
var max_speed: float
@export var acceleration: float = 50.0
@export var turn_speed: float = 2.0
var cooldown: float
var max_cooldown: float
var damage: float = 25.0

var ammo: int = 50
var max_ammo: int = 100

signal weapon_blocked(index: int)


var weapon_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
const ProjectileScene = preload("res://scenes/Projectile.tscn")
const LootScene = preload("res://scenes/Loot.tscn")
const SmokeScene = preload("res://scenes/SmokeEffect.tscn")

# Inventory
var gold: int = 0
var wood: int = 0
var food: int = 0
var water: int = 0
var fish: int = 0

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

@export_group("Diving Status (ReadOnly)")
@export var is_diving: bool = false
@export var current_dive_depth: float = 0.0
@export var current_dive_tilt: float = 0.0
@export var dive_delay_timer: float = 0.0
@export var is_wind_boost_active: bool = false
@export var wind_boost_timer: float = 0.0
var current_wind_vec_phys: Vector3 = Vector3.ZERO
var wind_boost_intensity: float = 0.0
var is_underwater: bool = false
var _hit_smoke_particles: CPUParticles3D = null
var _hp_bar_mesh: MeshInstance3D = null # La barre de vie optimisée en 3D

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
	_init_stats()
	_init_components()
	
	add_to_group("ship")
	add_to_group("enemies")
	# Auto-equip weapons for AI
	if weapon_slots[0] == null:
		var cannon = WeaponData.new()
		cannon.type = WeaponData.ActionType.CANNON
		cannon.weapon_name = "Standard Cannon"
		cannon.damage = 18.0 # Un peu plus de punch
		cannon.cooldown = 2.2 # Tir un peu plus régulier
		cannon.projectile_speed = 220.0
		weapon_slots[0] = cannon
		
	if weapon_slots[1] == null:
		var mg = WeaponData.new()
		mg.type = WeaponData.ActionType.CANNON
		mg.weapon_name = "Close Range MG"
		mg.damage = 4.0
		mg.cooldown = 0.5
		mg.projectile_speed = 180.0
		mg.projectile_count = 6
		mg.projectile_scale = 0.8
		mg.projectile_spread = deg_to_rad(15)
		weapon_slots[1] = mg
	
	_apply_faction_visuals()
		
	_setup_damage_smoke()



	_setup_immobilized_icon()
	_setup_hp_bar()

func _setup_hp_bar():
	# Barre de vie ultra-minimale et visible de très loin
	_hp_bar_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(25.0, 2.2) # Encore plus fine et élégante
	_hp_bar_mesh.mesh = quad
	
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled; // depth_test_disabled est le mode correct en Godot 4
uniform float ratio : hint_range(0.0, 1.0);
void vertex() {
	// Billboard : fait face à la caméra
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float mask = step(UV.x, ratio);
	vec3 color = mix(vec3(0.6, 0.1, 0.1), vec3(0.2, 0.8, 0.3), mask);
	// Bordure noire très fine
	if (UV.y < 0.15 || UV.y > 0.85 || UV.x < 0.005 || UV.x > 0.995) color = vec3(0,0,0);
	ALBEDO = color;
	ALPHA = 1.0;
}
"""
	_hp_bar_mesh.material_override = mat
	# Pour garantir la visibilité au loin sans erreur de compilation
	_hp_bar_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hp_bar_mesh)
	
	# Positionnement : Bien au dessus du mât (+55 au lieu de +60)
	var zone = get_node_or_null("StatusEffectsZone")
	if zone:
		_hp_bar_mesh.position = zone.position + Vector3(0, 55, 0)
	else:
		_hp_bar_mesh.position = Vector3(0, 255, 0)

var _last_hp_ratio: float = -1.0
func _update_hp_bar():
	if _hp_bar_mesh and _hp_bar_mesh.material_override:
		var r = clamp(hp / max_hp, 0.0, 1.0)
		if abs(r - _last_hp_ratio) < 0.001: return
		_last_hp_ratio = r
		_hp_bar_mesh.material_override.set_shader_parameter("ratio", r)
		# Toujours visible dès qu'il manque de la vie, même de loin
		_hp_bar_mesh.visible = r > 0.0 and r < 1.0

func _setup_immobilized_icon():
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
	_hit_smoke_particles = CPUParticles3D.new()
	add_child(_hit_smoke_particles)
	_hit_smoke_particles.name = "HealthSmoke"
	
	_hit_smoke_particles.emitting = false
	_hit_smoke_particles.amount = 40 # Reduced from 700 for performance and visibility
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
	gradient.set_color(1, Color(0.2, 0.2, 0.2, 0.3)) # Plus sombre et transparent
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

func _find_child_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		# Using match/find case insensitively
		if child.name.to_lower().find(target_name.to_lower()) != -1:
			return child
		var res = _find_child_recursive(child, target_name)
		if res: return res
	return null

func _init_stats():
	match ship_type:
		ShipClass.SLOOP:
			max_hp = GameConfig.SloopHP
			max_speed = GameConfig.SloopSpeed
			max_cooldown = GameConfig.SloopCooldown
		ShipClass.BRIGANTINE:
			max_hp = GameConfig.BrigantineHP
			max_speed = GameConfig.BrigantineSpeed
			max_cooldown = GameConfig.BrigantineCooldown
		ShipClass.GALLEON:
			max_hp = GameConfig.GalleonHP
			max_speed = GameConfig.GalleonSpeed
			max_cooldown = GameConfig.GalleonCooldown
	hp = max_hp

func _physics_process(delta):
	# Update HUD/Visuals only once per frame
	_update_hp_bar()
	if is_sinking: return  # Physique arrêtée pendant le naufrage
	
	# Gestion des temps de recharge
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
		
	# Mouvement physique de base
	_handle_ai(delta)
		
	# LOGIQUE MODULAIRE (Exécutée après le mouvement de base pour modifier velocity/visuel)
	for slot in weapon_slots:
		if slot and slot.has_method("process_tick"):
			slot.process_tick(self, delta)
	
	# --- KNOCKBACK PHYSIQUE (tentacule, collision) --- Appliqué après tous les skills
	if knockback_velocity.length_squared() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * knockback_decay)
	else:
		knockback_velocity = Vector3.ZERO
	
	# move_and_slide FINAL (après que tous les skills aient modifié velocity)
	move_and_slide()
	
	# Toujours maintenir le navire ennemi à la hauteur de l'eau
	global_position.y = _get_water_height(global_position, Time.get_ticks_msec() / 1000.0)
	
	_update_damage_visuals(delta)

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


func _apply_movement_physics(delta, steer, throttle):
	# Si le bateau est immobilisé (ex: par un filet de pêche), on bloque les commandes
	if immobilization_timer > 0:
		steer = 0.0
		throttle = 0.0
		
	# Rotation de base
	if steer != 0:
		rotation.y -= steer * turn_speed * delta
	
	var max_reverse_speed = max_speed * 0.15
	
	if throttle > 0: # Accélérer
		ship_speed = move_toward(ship_speed, max_speed * current_speed_buff, acceleration * current_speed_buff * delta)
	elif throttle < 0: # Reculer
		ship_speed = move_toward(ship_speed, -max_reverse_speed, acceleration * 0.8 * delta)
	else: # Freinage naturel
		ship_speed = move_toward(ship_speed, 0, acceleration * 0.6 * delta)
		
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
		var speed_modifier = 1.0 + (wind_push * 0.4) if not is_underwater else 1.0
		
		velocity = forward * min(ship_speed * speed_modifier, 1200.0)
		velocity.y = 0
		
		if ship_speed > 0 and not is_underwater:
			var drift = current_wind_vec_phys - (forward * wind_push)
			velocity += drift * 0.1
			velocity.y = 0

	

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
	
	var heeling_rot = (cos(t * 1.0) * 0.08) + target_heeling
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

	


func shoot_cannons():
	var action = weapon_slots[active_weapon_index]
	if not action: return
	
	# Check if the action is allowed underwater (Diving state or actual Depth)
	var underwater = is_diving or is_underwater
	if underwater and action.get("can_be_used_underwater") == false:
		weapon_blocked.emit(active_weapon_index)
		return

	
	if action.has_method("is_action_blocked") and action.is_action_blocked(self):
		weapon_blocked.emit(active_weapon_index)
		return

	
	weapon_cooldowns[active_weapon_index] = action.cooldown

	
	# LOGIQUE D'EXÉCUTION
	match action.type:
		WeaponData.ActionType.CANNON:
			_fire_cannons(action)
		WeaponData.ActionType.GRAPPLE:
			_use_grapple(action)
		WeaponData.ActionType.DIVE, WeaponData.ActionType.SKILL, WeaponData.ActionType.WIND_CONTROL, WeaponData.ActionType.KRAKEN:
			if action.has_method("activate"):
				action.activate(self)
			else:
				_use_skill(action)


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

func _use_grapple(action: WeaponData):
	print("Utilisation du Grappin: ", action.weapon_name)
	_fire_cannons(action)

func _use_skill(action: WeaponData):
	print("Utilisation Compétence: ", action.weapon_name)
	skill_timer = action.skill_duration
	current_speed_buff = action.speed_buff

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

var ai_state_timer: float = 0.0
var ai_target_pos: Vector3
var ai_target_ship: Node3D = null
var ai_think_timer: float = 0.0

func _handle_ai(delta):
	# 1. SCAN FOR TARGETS (periodiquement)
	ai_think_timer -= delta
	if ai_think_timer <= 0:
		ai_think_timer = randf_range(1.5, 3.0)
		_ai_find_target()

	# 2. DECISION LOGIC
	var steer = 0.0
	var throttle = 0.5
	
	if is_instance_valid(ai_target_ship) and ai_target_ship.hp > 0 and not ai_target_ship.is_sinking:

		# COMBAT AI
		var to_target = ai_target_ship.global_position - global_position
		var dist = to_target.length()
		var dir_to_target = to_target.normalized()
		var forward = transform.basis.z
		
		# Angle towards target
		var angle_to = forward.signed_angle_to(dir_to_target, Vector3.UP)
		
		if dist > 250.0:
			# Chase
			steer = clamp(-angle_to * 2.0, -1.0, 1.0)
			throttle = 0.8
		elif dist < 100.0:
			# Too close, steer away
			steer = clamp(angle_to * 2.0, -1.0, 1.0)
			throttle = 0.4
		else:
			# Broadside positioning (entre 100 et 250)
			var side_angle = PI/2.0 if angle_to > 0 else -PI/2.0
			var attack_angle = wrapf(angle_to - side_angle, -PI, PI)
			steer = clamp(-attack_angle * 3.0, -1.0, 1.0)
			throttle = 0.6
			
			# Shooting logic : if target is on our side
			if abs(angle_to) > deg_to_rad(65) and abs(angle_to) < deg_to_rad(115):
				_ai_try_shoot()
	else:
		# WANDER AI
		ai_state_timer -= delta
		if ai_state_timer <= 0:
			ai_state_timer = randf_range(6.0, 15.0)
			var rand_x = randf_range(-800, 800)
			var rand_z = randf_range(-800, 800)
			ai_target_pos = global_position + Vector3(rand_x, 0, rand_z)
		
		var direction = (ai_target_pos - global_position).normalized()
		var forward = transform.basis.z
		var angle_to = forward.signed_angle_to(direction, Vector3.UP)
		steer = clamp(-angle_to * 2.0, -1.0, 1.0)
		throttle = 0.4
		
	# 3. APPLY
	_apply_movement_physics(delta, steer, throttle)
	_apply_visuals(delta, steer)

func _ai_find_target():
	var ships = get_tree().get_nodes_in_group("ship")
	var closest_dist = 800.0 # Detection range
	var found_target = null
	
	for s in ships:
		if s == self: continue
		if s.faction == faction: continue # Same faction
		if s.hp <= 0 or s.is_sinking: continue
		
		# DETECTION SOUS-MARINE : On ne détecte pas ce qui est trop profond
		if "current_dive_depth" in s and s.current_dive_depth < -15.0:
			continue
		
		var d = global_position.distance_to(s.global_position)
		if d < closest_dist:
			closest_dist = d
			found_target = s
			
	ai_target_ship = found_target

func _ai_try_shoot():
	var to_target = ai_target_ship.global_position - global_position
	var dist = to_target.length()
	
	# Sélection de l'arme selon la distance
	# Mitrailleuse (slot 1) si très proche, Canon Standard (slot 0) pour le reste
	var target_index = 0
	if dist < 150.0:
		target_index = 1
	
	var w = weapon_slots[target_index]
	if w and weapon_cooldowns[target_index] <= 0:
		active_weapon_index = target_index
		shoot_cannons()


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
	if is_flashing: return
	is_flashing = true
	
	if not flash_mat:
		flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(0.8, 0.1, 0.1, 1)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(0.6, 0.05, 0.05)
		flash_mat.emission_energy_multiplier = 0.5
	
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
		
	# Utilisation d'un tween pour le reset (plus propre et sécurisé)
	var tw = create_tween()
	tw.tween_interval(0.15)
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
	hp -= amount
	_flash_hit()
	_update_hp_bar()
	
	# Riposte IA : Si on est attaqué, on cible l'agresseur
	if is_instance_valid(attacker) and attacker != self:
		if not is_instance_valid(ai_target_ship) or randf() < 0.4:
			ai_target_ship = attacker
	
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
	# Ennemi : dépose du loot
	var drop_count = randi() % 3 + 1
	var spread = 15.0
	for i in range(drop_count):
		var loot = LootScene.instantiate() as Loot
		get_tree().get_root().add_child(loot)
		var offset_x = (randf() * 2.0 - 1.0) * spread
		var offset_z = (randf() * 2.0 - 1.0) * spread
		loot.global_position = global_position + Vector3(offset_x, 5.0, offset_z)
		var loot_type = randi() % 5
		var amount = 10 + (randi() % 20)
		if loot_type == 0: amount *= 5
		loot.setup(loot_type, amount)
	queue_free()

func _apply_faction_visuals():
	var target_color = Color.WHITE
	match faction:
		Faction.NAVY: target_color = Color(0.1, 0.4, 0.9) # Blue
		Faction.PIRATE: target_color = Color(0.1, 0.1, 0.1) # Black
		Faction.MERCHANT: target_color = Color(0.9, 0.8, 0.2) # Yellow
	
	ship_color = target_color
	
	# Color the sails to identify factions
	var mesh_node = get_node_or_null("sloup")
	if mesh_node:
		var sails = _find_child_recursive(mesh_node, "Sails")
		if sails and sails is MeshInstance3D:
			var mat = sails.get_active_material(0)
			if mat:
				var new_mat = mat.duplicate()
				new_mat.albedo_color = target_color
				sails.set_surface_override_material(0, new_mat)



func _get_water_height(pos: Vector3, time_val: float) -> float:
	var wave_speed = 0.8
	var wave_freq = 0.03
	var wave_amp = 3.0
	
	var t = time_val * wave_speed
	var w1 = sin(pos.x * wave_freq + t) * wave_amp
	var w2 = cos(pos.z * wave_freq * 1.5 + t * 1.2) * wave_amp * 0.8
	
	return w1 + w2
