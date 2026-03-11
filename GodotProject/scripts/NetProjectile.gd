extends Area3D

var velocity: Vector3
var life_time: float = 0.0
var max_life_time: float = 3.0
var snare_duration: float = 4.0
var is_player_owned: bool = false
var owner_ship: NodePath

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	# Pas de gravité, le filet vole tout droit
	position += velocity * delta
	
	# Fait tourner le filet sur lui-même (plus vite pour le visuel)
	rotation_degrees.x += 480.0 * delta
	rotation_degrees.y += 240.0 * delta
	
	life_time += delta
	if life_time >= max_life_time:
		queue_free()

func _on_body_entered(body: Node3D):
	_handle_collision(body)

func _on_area_entered(area: Area3D):
	_handle_collision(area)

func _handle_collision(node: Node3D):
	# Supporte la hitbox tentacule
	if node.has_meta("tentacle_root"):
		var tentacle = node.get_meta("tentacle_root")
		if is_instance_valid(tentacle) and tentacle.has_method("apply_immobilization"):
			tentacle.call("apply_immobilization", snare_duration)
			_spawn_hit_fx()
			queue_free()
			return

	if node.has_method("apply_immobilization"):
		# Vérifie qu'on n'attrape pas son propre bateau
		var node_is_player = node.get("is_player") if "is_player" in node else false
		if node_is_player == is_player_owned:
			return
			
		node.call("apply_immobilization", snare_duration)
		_spawn_hit_fx()
		queue_free()

func _spawn_hit_fx():
	var splash = CPUParticles3D.new()
	get_tree().get_root().add_child(splash)
	splash.global_position = global_position
	
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 30
	splash.lifetime = 0.8
	
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 180.0
	splash.initial_velocity_min = 2.0
	splash.initial_velocity_max = 8.0
	splash.gravity = Vector3(0, -5, 0)
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.5, 0.3) # Couleur marron/corde
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	splash.mesh = mesh
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(splash.queue_free)
