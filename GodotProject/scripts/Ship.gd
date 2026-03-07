class_name Ship
extends CharacterBody3D

enum ShipClass { SLOOP, BRIGANTINE, GALLEON }

@export var is_player: bool = false
@export var ship_type: ShipClass = ShipClass.SLOOP
@export var ship_color: Color = Color.WHITE

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

# Camera variables
@export var mouse_sensitivity: float = 0.002
@export var min_zoom: float = 50.0
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
	_init_weapons()
	
	if is_player:
		add_to_group("player")
	else:
		add_to_group("enemies")

func _init_weapons():
	# On ne fait plus d'initialisation automatique par code.
	# Le joueur (vous) configure le tableau directement dans l'inspecteur de Godot.
	# Si un slot est vide (null), le tir ne fera rien ou utilisera les stats de base.
	pass
		
	# Find camera nodes
	gimbal_node = get_node_or_null("CameraGimbal")
	if gimbal_node:
		spring_arm = gimbal_node.get_node_or_null("SpringArm3D")
		# Make the gimbal independent of the Ship's rotation hierarchy
		gimbal_node.set_as_top_level(true)
		
		# --- BORDERLANDS CEL-SHADER (POST PROCESSING) ---
		var cam = spring_arm.get_node_or_null("Camera3D")
		if cam and is_player: # Only render shader for the active player's screen
			var cel_mesh = MeshInstance3D.new()
			var quad = QuadMesh.new()
			quad.size = Vector2(2, 2)
			cel_mesh.mesh = quad
			cel_mesh.custom_aabb = AABB(Vector3(-10000, -10000, -10000), Vector3(20000, 20000, 20000))
			cel_mesh.ignore_occlusion_culling = true
			
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = load("res://scripts/cel_shader.gdshader")
			cel_mesh.material_override = shader_mat
			cam.add_child(cel_mesh)
			
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

func _unhandled_input(event):
	pass

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
	# Gestion des temps de recharge
	for i in range(weapon_cooldowns.size()):
		if weapon_cooldowns[i] > 0:
			weapon_cooldowns[i] -= delta
		
	if skill_timer > 0:
		skill_timer -= delta
		if skill_timer <= 0:
			current_speed_buff = 1.0
		
	# Mouvement physique de base
	if is_player:
		_handle_player_input(delta)
	else:
		_handle_ai(delta)
		
	# LOGIQUE MODULAIRE (Exécutée à la fin pour appliquer les modifications de position/visuel)
	for i in range(weapon_slots.size()):
		if weapon_slots[i] and weapon_slots[i].has_method("process_tick"):
			weapon_slots[i].process_tick(self, delta)

func _handle_player_input(delta):
	# Handle Zoom
	if spring_arm:
		if Input.is_action_just_pressed("zoom_in"):
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif Input.is_action_just_pressed("zoom_out"):
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Rotation
	if input_dir.x != 0:
		rotation.y -= input_dir.x * turn_speed * delta
	
	# Acceleration & Reversing
	var max_reverse_speed = max_speed * 0.15 # Reverse is only 15% of max forward speed
	
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
	
	if input_dir.y < 0: # Forward (up arrow)
		ship_speed = move_toward(ship_speed, max_speed * current_speed_buff, acceleration * current_speed_buff * delta)
	elif input_dir.y > 0: # Reverse (down arrow)
		ship_speed = move_toward(ship_speed, -max_reverse_speed, acceleration * 0.8 * delta) # Brakes quickly to slow reverse
	else: # Braking naturally when no input
		ship_speed = move_toward(ship_speed, 0, acceleration * 0.6 * delta) # Much stronger natural drag
		
	var forward = transform.basis.z # Vector oriented forward relative to model
	forward.y = 0 # Strip any downward angle so the ship never drives into the water
	forward = forward.normalized()
	
	# Wind Physics influence based on local position
	var local_wind = GameConfig.get_wind_at(global_position)
	var wind_dir = local_wind["direction"]
	var wind_speed = local_wind["speed"]
	var wind_vec = Vector3(wind_dir.x, 0, wind_dir.y) * wind_speed
	
	var wind_push = forward.dot(wind_vec) # Faster if wind is behind us
	
	# Massive speed multiplier based on wind: e.g. from 0.2x (against) to 1.8x (with wind)
	var speed_modifier = 1.0 + (wind_push * 0.4)
	var current_max = max(max_speed * speed_modifier, max_speed * 0.25)
	
	# Apply modifier to actual driving velocity
	var effective_speed = ship_speed * speed_modifier
	velocity = forward * min(effective_speed, current_max)
	# Absolutely no gravity or vertical drift
	velocity.y = 0 
	
	# Add slight sideways drift from wind if not moving backwards
	if ship_speed > 0:
		var drift = wind_vec - (forward * wind_push)
		velocity += drift * 0.1
		velocity.y = 0
	
	move_and_slide()
	

	var mesh_node = get_node_or_null("sloup")
	var t = Time.get_ticks_msec() / 1000.0
	
	# Wind Data for animations
	var wind_vec3 = Vector3(wind_dir.x, 0, wind_dir.y) 
	
	if mesh_node:
		# --- REALISTIC HEELING (La Gîte) ---
		var side_pressure = forward.cross(wind_vec3).y * wind_speed
		var target_heeling = side_pressure * 0.08 
		
		var heeling_rot = (cos(t * 1.0) * 0.08) + target_heeling
		# Combinaison : Plongée (X) + Mouvement Vagues (X) + Gîte (Z)
		var pitch_wave = sin(t * 1.2) * 0.08
		mesh_node.rotation = Vector3(pitch_wave + current_dive_tilt, mesh_node.rotation.y, heeling_rot)
		# Flottaison légère
		mesh_node.position = Vector3(mesh_node.position.x, sin(t * 2.0) * 0.4, mesh_node.position.z)
	
	# Visual Steering for Mast and Wheel
	var target_steer = input_dir.x
	current_steer_angle = lerp(current_steer_angle, target_steer, delta * 3.0)
	
	if visual_wheel:
		visual_wheel.transform.basis = Basis.from_euler(base_wheel_rot)
		# Dans un vrai bateau, on tourne beaucoup la barre pour un petit virage
		visual_wheel.rotate_object_local(Vector3(0, 0, 1), -current_steer_angle * 8.0)
	
	if visual_mast:
		visual_mast.transform.basis = Basis.from_euler(base_mast_rot)
		
		# Mast & Sail Logic: Sur un vrai sloop, tout le mât pivote pour orienter la voile
		
		# Calcul du vent relatif par rapport au bateau
		var wind_world_angle = atan2(wind_vec3.x, wind_vec3.z)
		var ship_world_angle = global_rotation.y
		var relative_wind_angle = wrapf(wind_world_angle - (ship_world_angle + PI), -PI, PI)
		
		# On oriente le mât entier vers 1/2 de l'angle du vent pour garder la prise
		var target_mast_angle = clamp(relative_wind_angle * 0.45, -deg_to_rad(70), deg_to_rad(70))
		
		# On ajoute un léger tremblement si le vent est fort ou change (plus vivant)
		var flutter = 0.0
		if abs(relative_wind_angle) > PI * 0.8: # Vent de face (virements)
			flutter = sin(Time.get_ticks_msec() * 0.01) * 0.02
		
		# Interpolation très fluide pour donner du poids au mât
		current_sail_angle = lerp_angle(current_sail_angle, target_mast_angle + flutter, delta * mast_lerp_speed)
		
		# Appliquer la rotation locale au mât (en remplaçant toute la rotation pour éviter l'accumulation)
		visual_mast.rotation = base_mast_rot
		visual_mast.rotate_object_local(Vector3(0, 1, 0), current_sail_angle)
		
		# --- DYNAMIC SAIL BOMBAGE (Inversion selon le vent) ---
		if visual_sails:
			# On garde la rotation de base sans écraser l'échelle (scale)
			visual_sails.rotation = base_sails_rot
			
			# Détecter de quel côté le vent frappe le mât (dans son espace local)
			# On prend le vecteur vent dans le monde et on l'amène dans le repère du mât
			var mast_basis = visual_mast.global_transform.basis
			var mast_local_wind = mast_basis.inverse() * wind_vec3
			
			# side_sign : détermine si la voile bombe à gauche (1) ou à droite (-1)
			# Nouvel ajustement de l'inversion
			var side_sign = -1.0
			if mast_local_wind.x < 0:
				side_sign = 1.0
			
			# Paramètres différents selon le côté du bombage
			var target_inflation = 1.0
			var target_offset = 0.0
			
			if side_sign > 0:
				# Côté Gauche (Positif)
				target_inflation = sail_inflation_left
				target_offset = sail_offset_left
			else:
				# Côté Droit (Négatif)
				target_inflation = sail_inflation_right
				target_offset = sail_offset_right
			
			# Appliquer le bombage via l'échelle (scale.x)
			var target_scale = base_sails_scale
			target_scale = Vector3(base_sails_scale.x * target_inflation * side_sign, base_sails_scale.y, base_sails_scale.z)
			
			# Calcul du décalage spécifique au côté
			var target_pos = base_sails_pos
			target_pos = Vector3(base_sails_pos.x + target_offset, base_sails_pos.y, base_sails_pos.z)
				
			# Interpolation avec vitesse ajustable
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
	
	# LOGIQUE MODULAIRE : On ne bloque QUE les armes offensives sous l'eau
	if action.type == WeaponData.ActionType.CANNON or action.type == WeaponData.ActionType.GRAPPLE:
		if is_diving or (action.has_method("is_action_blocked") and action.is_action_blocked(self)):
			return
	
	weapon_cooldowns[active_weapon_index] = action.cooldown
	ammo -= action.ammo_cost
	
	# LOGIQUE D'EXÉCUTION
	match action.type:
		WeaponData.ActionType.CANNON:
			_fire_cannons(action)
		WeaponData.ActionType.GRAPPLE:
			_use_grapple(action)
		WeaponData.ActionType.DIVE, WeaponData.ActionType.SKILL:
			if action.has_method("activate"):
				action.activate(self)
			else:
				_use_skill(action)


func _fire_cannons(weapon: WeaponData):
	var projectile_speed = weapon.projectile_speed
	
	# Port (Left)
	var port_marker = get_node_or_null("Cannons/PortCannon1")
	if port_marker:
		_fire_projectile(port_marker, -global_transform.basis.x, projectile_speed, weapon)
	
	# Starboard (Right)
	var starboard_marker = get_node_or_null("Cannons/StarboardCannon1")
	if starboard_marker:
		_fire_projectile(starboard_marker, global_transform.basis.x, projectile_speed, weapon)

func _use_grapple(action: WeaponData):
	print("Utilisation du Grappin: ", action.weapon_name)
	# Ici on pourrait tirer un projectile spécial "Grappin"
	_fire_cannons(action) # Pour l'instant on tire juste pour le visuel

func _use_skill(action: WeaponData):
	print("Utilisation Compétence: ", action.weapon_name)
	skill_timer = action.skill_duration
	current_speed_buff = action.speed_buff

func _fire_projectile(marker: Marker3D, direction: Vector3, speed: float, weapon: WeaponData = null):
	var proj = ProjectileScene.instantiate() as Projectile
	get_tree().get_root().add_child(proj)
	proj.global_position = marker.global_position
	
	# Increase the visibility of cannonballs reasonably
	proj.scale = Vector3(2.2, 2.2, 2.2)
	
	# Combine velocity and give them a lighter upward arc thrust 
	proj.velocity = velocity + (direction.normalized() * speed)
	proj.velocity.y += 12.0
	
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
	
	# Smoke Effect - Attached, directed outwards
	var smoke = SmokeScene.instantiate() as Node3D
	marker.add_child(smoke)
	# Start at muzzle
	smoke.position = Vector3.ZERO
	# look_at needs to be correctly directed outwards from the ship
	smoke.look_at(smoke.global_position + direction.normalized(), Vector3.UP)

var ai_state_timer: float = 0.0
var ai_target_pos: Vector3

func _handle_ai(delta):
	ai_state_timer -= delta
	if ai_state_timer <= 0:
		# Pick a new random direction to wander
		ai_state_timer = randf_range(3.0, 8.0)
		var rand_x = randf_range(-1000, 1000)
		var rand_z = randf_range(-1000, 1000)
		ai_target_pos = Vector3(rand_x, global_position.y, rand_z)
	
	# Steer towards target position
	var direction = (ai_target_pos - global_position).normalized()
	var forward = transform.basis.z
	
	# Calculate angle to target
	var angle_to = forward.signed_angle_to(direction, Vector3.UP)
	
	# Turn towards target
	if abs(angle_to) > 0.1:
		rotation.y += sign(angle_to) * turn_speed * 0.5 * delta
		
	# Move forward
	ship_speed = move_toward(ship_speed, max_speed * 0.5, acceleration * delta)
	velocity = forward * ship_speed
	move_and_slide()
	
	if gimbal_node:
		gimbal_node.global_position = global_position

func take_damage(amount: float, attacker: Ship):
	hp -= amount
	if hp <= 0:
		die()

func heal(amount: float):
	hp = min(hp + amount, max_hp)

func die():
	var drop_count = randi() % 3 + 1
	var spread = 15.0
	
	for i in range(drop_count):
		var loot = LootScene.instantiate() as Loot
		get_tree().get_root().add_child(loot)
		
		# Random position around shipwreck
		var offset_x = (randf() * 2.0 - 1.0) * spread
		var offset_z = (randf() * 2.0 - 1.0) * spread
		loot.global_position = global_position + Vector3(offset_x, 5.0, offset_z)
		
		# Random type and amount
		var loot_type = randi() % 5 
		var amount = 10 + (randi() % 20)
		if loot_type == 0: amount *= 5 # More gold
		
		loot.setup(loot_type, amount)
	
	queue_free()

func _get_water_height(pos: Vector3, time_val: float) -> float:
	var wave_speed = 0.8
	var wave_freq = 0.03
	var wave_amp = 3.0
	
	var t = time_val * wave_speed
	var w1 = sin(pos.x * wave_freq + t) * wave_amp
	var w2 = cos(pos.z * wave_freq * 1.5 + t * 1.2) * wave_amp * 0.8
	
	return w1 + w2
