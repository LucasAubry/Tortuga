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

var cooldown_timer: float = 0.0
const ProjectileScene = preload("res://scenes/Projectile.tscn")
const LootScene = preload("res://scenes/Loot.tscn")

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

# Camera variables
@export var mouse_sensitivity: float = 0.002
@export var min_zoom: float = 50.0
@export var max_zoom: float = 5000.0
@export var zoom_speed: float = 150.0
var gimbal_node: Node3D
var spring_arm: SpringArm3D

func _ready():
	_init_stats()
	
	if is_player:
		add_to_group("player")
	else:
		add_to_group("enemies")
		
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
	if cooldown_timer > 0:
		cooldown_timer -= delta
		
	if is_player:
		_handle_player_input(delta)
	else:
		_handle_ai(delta)
		

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
	
	if Input.is_action_just_pressed("ui_fire") and cooldown_timer <= 0 and ammo > 0:
		shoot_cannons()
	
	if input_dir.y < 0: # Forward (up arrow)
		ship_speed = move_toward(ship_speed, max_speed, acceleration * delta)
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
	
	# Ultra-optimized generic animation (No Topography Sampling)
	global_position.y = 0.0
	
	var mesh_node = get_node_or_null("sloup")
	if mesh_node:
		var t = Time.get_ticks_msec() / 1000.0
		# Pure mathematical sine loops to emulate ship swaying without physics logic
		mesh_node.position.y = sin(t * 2.0) * 0.5
		mesh_node.rotation.x = sin(t * 1.5) * 0.10
		mesh_node.rotation.z = cos(t * 1.0) * 0.08
	
	# Force the gimbal to stay at a fixed rotation (e.g. isometric/top-down perspective)
	# but follow the ship's position. We do this by setting it as top-level so 
	# it ignores the ship's rotation, then manually updating its position.
	if gimbal_node:
		gimbal_node.global_position = global_position
		# The gimbal's rotation was set in the editor/scene, and we just preserve it.

func shoot_cannons():
	cooldown_timer = max_cooldown
	ammo -= 2 # 1 left, 1 right
	
	var projectile_speed = 200.0
	
	# Port (Left)
	var port_marker = get_node_or_null("Cannons/PortCannon1")
	if port_marker:
		_fire_projectile(port_marker, -global_transform.basis.x, projectile_speed)
	
	# Starboard (Right)
	var starboard_marker = get_node_or_null("Cannons/StarboardCannon1")
	if starboard_marker:
		_fire_projectile(starboard_marker, global_transform.basis.x, projectile_speed)

func _fire_projectile(marker: Marker3D, direction: Vector3, speed: float):
	var proj = ProjectileScene.instantiate() as Projectile
	get_tree().get_root().add_child(proj)
	proj.global_position = marker.global_position
	
	# Increase the visibility of cannonballs reasonably
	proj.scale = Vector3(2.2, 2.2, 2.2)
	
	# Combine velocity and give them a lighter upward arc thrust 
	proj.velocity = velocity + (direction.normalized() * speed)
	proj.velocity.y += 12.0
	
	proj.damage = damage
	proj.is_player_owned = is_player
	proj.owner_ship = get_path()

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
