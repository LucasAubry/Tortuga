class_name Ship
extends CharacterBody3D

enum ShipClass { SLOOP, BRIGANTINE, GALLEON }
enum Faction { PLAYER, NAVY, PIRATE, MERCHANT }

var is_player: bool = true
@export var ship_type: ShipClass = ShipClass.SLOOP
@export var ship_color: Color = Color.WHITE
@export var faction: Faction = Faction.PLAYER

var hp: float
var max_hp: float
var ship_speed: float
var max_speed: float
@export var acceleration: float = 50.0
@export var turn_speed: float = 2.0
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

# --- LIMITES DU MONDE ---
const MAP_WIDTH: float = 2400.0
const MAP_HEIGHT: float = 3600.0
var _is_falling: bool = false
var _falling_timer: float = 0.0

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

# Status Effects (Knockback & CC)
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_decay: float = 3.5
var immobilization_timer: float = 0.0
var _immobilized_icon: Node3D = null

# Naufrage
var is_sinking: bool = false

# Camera variables
@export var mouse_sensitivity: float = 0.002
@export var min_zoom: float = 150.0
@export var max_zoom: float = 5000.0
@export var zoom_speed: float = 150.0

# Sail Visual Tweakables (Visible in Godot Inspector)
@export_group("Sail Visuals")
@export var sail_inflation_left: float = 2.5
@export var sail_offset_left: float = 0.0
@export var sail_inflation_right: float = 2.5
@export var sail_offset_right: float = 0.3
@export var sail_lerp_speed: float = 1.2
@export var mast_lerp_speed: float = 0.7

var gimbal_node: Node3D
var spring_arm: SpringArm3D
var _cam_base_pos: Vector3 = Vector3.ZERO # Stocke la position propre sans les tremblements
var _cel_shader_mesh: MeshInstance3D = null

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
	add_to_group("player")
	faction = Faction.PLAYER
	_setup_damage_smoke()



	_setup_immobilized_icon()

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
		
	# Find camera nodes
	gimbal_node = get_node_or_null("CameraGimbal")
	if gimbal_node:
		spring_arm = gimbal_node.get_node_or_null("SpringArm3D")
		if spring_arm:
			_cam_base_pos = spring_arm.position # On mémorise la position de base
		# Make the gimbal independent of the Ship's rotation hierarchy
		gimbal_node.set_as_top_level(true)
		
		# --- BORDERLANDS CEL-SHADER (POST PROCESSING) ---
		var cam = spring_arm.get_node_or_null("Camera3D")
		if cam and is_player: # Only render shader for the active player's screen
			_cel_shader_mesh = MeshInstance3D.new()
			_cel_shader_mesh.name = "CelShaderMesh"
			var quad = QuadMesh.new()
			quad.size = Vector2(2, 2)
			_cel_shader_mesh.mesh = quad
			_cel_shader_mesh.custom_aabb = AABB(Vector3(-10000, -10000, -10000), Vector3(20000, 20000, 20000))
			_cel_shader_mesh.ignore_occlusion_culling = true
			
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = load("res://scripts/cel_shader.gdshader")
			_cel_shader_mesh.material_override = shader_mat
			cam.add_child(_cel_shader_mesh)
			_cel_shader_mesh.visible = GameConfig.enable_cel_shader
			GameConfig.cel_shader_toggled.connect(func(enabled): if is_instance_valid(_cel_shader_mesh): _cel_shader_mesh.visible = enabled)
			
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
	# 1. GESTION DES TIMERS (uniquement si on ne coule pas)
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
	var water_h = _get_water_height(global_position, Time.get_ticks_msec() / 1000.0)
	
	if water_h < -500.0:
		_is_falling = true
		_falling_timer += delta
		velocity.y -= 40.0 * delta # Gravité de chute
		
		# Si on tombe depuis trop longtemps (3s), on meurt
		if _falling_timer > 3.0:
			take_damage(2000.0, null)
	else:
		_is_falling = false
		_falling_timer = 0.0
		# Rectification immédiate de la hauteur si on est sur l'eau
		if not is_sinking:
			global_position.y = lerp(global_position.y, water_h, delta * 5.0)
			velocity.y = 0

	# 3. MOUVEMENT ET COLLISIONS
	if _falling_timer < 0.5: # On autorise les contrôles un court instant au début de la chute
		if not is_sinking:
			_handle_player_input(delta)
				
			# Logic modulaire des compétences (certaines modifient velocity)
			for slot in weapon_slots:
				if slot and slot.has_method("process_tick"):
					slot.process_tick(self, delta)
			
			# Knockback physique
			if knockback_velocity.length_squared() > 1.0:
				velocity += knockback_velocity
				knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * knockback_decay)
		
		move_and_slide()
	else:
		# Mode "Chute libre" : Pas de collisions move_and_slide, juste la gravité
		global_position += velocity * delta
	
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

func _handle_player_input(delta):
	_handle_camera_and_weapons(delta)
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Mouvement (Physique et Vent)
	var steer = input_dir.x
	var throttle = -input_dir.y # Inversé car -1 sur l'axe Y Godot est "Haut"
	
	_apply_movement_physics(delta, steer, throttle)
	_apply_visuals(delta, steer)

func _unhandled_input(event: InputEvent):
	
	if _is_map_open():
		return
	
	# --- ZOOM MAC PAD / TRACKPAD / MOUSE WHEEL ---
	if spring_arm:
		if event.is_class("InputEventMagnificationGesture"):
			var zoom_amount = (event.get("factor") - 1.0) * zoom_speed * 10.0
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_amount, min_zoom, max_zoom)
		elif event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)

func _is_map_open() -> bool:
	var map_nodes = get_tree().get_nodes_in_group("map_ui")
	for m in map_nodes:
		if m.visible:
			return true
	return false

func _handle_camera_and_weapons(delta):
	var map_open = _is_map_open()
	
	# Handle Zoom (Actions clavier/boutons)
	if spring_arm and not map_open:
		if Input.is_action_just_pressed("zoom_in"):
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif Input.is_action_just_pressed("zoom_out"):
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	
	# Weapon Selection
	if Input.is_key_pressed(KEY_1): active_weapon_index = 0
	elif Input.is_key_pressed(KEY_2): active_weapon_index = 1
	elif Input.is_key_pressed(KEY_3): active_weapon_index = 2
	elif Input.is_key_pressed(KEY_4): active_weapon_index = 3
	elif Input.is_key_pressed(KEY_5): active_weapon_index = 4

	var current_action = weapon_slots[active_weapon_index]
	var can_afford = current_action == null or ammo >= current_action.ammo_cost
	
	if Input.is_action_just_pressed("ui_fire") and weapon_cooldowns[active_weapon_index] <= 0 and can_afford:
		shoot_cannons()

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

	
	# Force the gimbal to stay at a fixed rotation (e.g. isometric/top-down perspective)
	# but follow the ship's position. We do this by setting it as top-level so 
	# it ignores the ship's rotation, then manually updating its position.
	if gimbal_node:
		gimbal_node.global_position = global_position
		# The gimbal's rotation was set in the editor/scene, and we just preserve it.

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

	# Camera shake - Intensivement réduit (1.5 au lieu de 18.0) pour éviter de clip dans le mesh
	if spring_arm:
		_camera_shake(0.35, 1.5)

func apply_immobilization(duration: float):
	# Applique un root/immobilisation pour la durée spécifiée
	immobilization_timer = max(immobilization_timer, duration)
	print("⚓ " + name + " est immobilisé pour " + str(duration) + " secondes !")

func _camera_shake(duration: float, intensity: float):
	if not spring_arm: return
	
	var tween = create_tween()
	# Le tremblement se fait relativement à _cam_base_pos pour éviter toute dérive
	tween.tween_method(func(t: float):
		var decay = 1.0 - (t / duration)
		spring_arm.position = _cam_base_pos + Vector3(
			randf_range(-1, 1) * intensity * decay,
			randf_range(-1, 1) * intensity * 0.3 * decay,
			randf_range(-1, 1) * intensity * 0.1 * decay
		)
	, 0.0, duration, duration)
	tween.tween_callback(func(): spring_arm.position = _cam_base_pos)

var is_flashing: bool = false
var flash_mat: StandardMaterial3D = null

func _flash_hit():
	if is_flashing or is_sinking: return
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
	
	# Utilisation d'un tween pour le reset (plus propre que await Timer)
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
		# Affiche l'écran de mort après le naufrage
		get_tree().call_group("hud", "show_death_screen")
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
	# On le met au niveau de l'eau (Y=0) pour qu'il puisse toucher les barils (qui sont à Y=0)
	global_position = Vector3(0, 0, 0)
	global_rotation = Vector3.ZERO
	
	# Réinitialise les visuels (qui étaient tordus par le naufrage)
	var mesh = get_node_or_null("sloup")
	if mesh:
		mesh.rotation = Vector3.ZERO
		mesh.position = Vector3(0, 0, 0) # Remet d'aplomb
	
	# Réinitialise la caméra si besoin
	if spring_arm:
		spring_arm.position = _cam_base_pos
	
	print("⚓ ", name, " a réapparu sur la carte !")

func _get_water_height(pos: Vector3, _time_val: float) -> float:
	# Vérification des limites du rectangle
	if abs(pos.x) > MAP_WIDTH * 0.5 or abs(pos.z) > MAP_HEIGHT * 0.5:
		return -1000.0 # Indique une chute
	return 0.0

func switch_ship(new_type: ShipClass, scene_path: String):
	ship_type = new_type
	
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
	
	# Réinitialisation des stats et des composants visuels
	_init_stats()
	_init_components()
	_setup_damage_smoke()
	_setup_immobilized_icon()
	
	print("⚓ Navire changé pour un : ", ship_type)
