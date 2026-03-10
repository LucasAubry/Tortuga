class_name Projectile
extends Area3D

var velocity: Vector3
var life_time: float = 0.0
var max_life_time: float = 0.5
var damage: float = 25.0
var is_player_owned: bool = false
var owner_ship: NodePath

func _ready():
	body_entered.connect(_on_body_entered)

var gravity_force: float = 25.0

func _physics_process(delta):
	# Apply dropping physics to the projectile
	velocity.y -= gravity_force * delta
	position += velocity * delta
	
	life_time += delta
	
	# DETECTION Eclaboussure (Eau à y=0)
	if position.y <= 0.0:
		_spawn_splash()
		queue_free()
		return

	# Si le temps est écoulé (0.5s), fait tomber le boulet dans l'eau
	if life_time >= max_life_time:
		_spawn_splash()
		queue_free()

func _spawn_splash():
	var splash = CPUParticles3D.new()
	get_parent().add_child(splash)
	splash.global_position = Vector3(global_position.x, 0, global_position.z)
	
	# Config optimisée
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 40 # Plus de gouttelettes
	splash.lifetime = 1.2
	
	# Physique de l'eau
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 60.0 # Plus large
	splash.initial_velocity_min = 8.0
	splash.initial_velocity_max = 15.0
	splash.gravity = Vector3(0, -25, 0) # Retombe avec force
	
	# Look réaliste
	var mesh = SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	mesh.radial_segments = 4
	mesh.rings = 4
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.8) 
	mesh.material = mat
	splash.mesh = mesh
	
	# Courbe de taille (rétrécit en tombant)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	splash.scale_amount_curve = curve
	
	# Dégradé de transparence
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	splash.color_ramp = grad
	
	# Nettoyage auto
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(splash.queue_free)

func _on_body_entered(body: Node3D):
	# Supporte les hitbox de tentacules (metadata tentacle_root)
	if body.has_meta("tentacle_root"):
		var tentacle = body.get_meta("tentacle_root")
		if is_instance_valid(tentacle) and tentacle.has_method("take_damage"):
			tentacle.call("take_damage", damage, get_node(owner_ship) if not owner_ship.is_empty() else null)
			queue_free()
			return

	# On évite le body is Ship pour casser la dépendance circulaire
	if body.has_method("take_damage"):
		# On utilise .get() pour plus de sécurité lors du lancement
		var is_player = body.get("is_player") if "is_player" in body else false
		if is_player == is_player_owned:
			return
			
		body.call("take_damage", damage, get_node(owner_ship) if not owner_ship.is_empty() else null)
		queue_free()
	elif body is Ile:
		queue_free()
