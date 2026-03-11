class_name Projectile
extends Area3D

var velocity: Vector3
var life_time: float = 0.0
var max_life_time: float = 3.0
var damage: float = 25.0
var is_player_owned: bool = false
var owner_ship: NodePath
var gravity_force: float = 25.0
var caster_node: Node3D = null # Pour le Kraken

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# PREVENTION DU PASSAGE A TRAVERS LES CIBLES (Raycast continu)
	# Si le boulet va vite, il peut rater une hitbox. On trace un trait entre l'ancienne et la nouvelle position.
	var next_pos = global_position + velocity * delta
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, next_pos)
	
	var exclude_list = [get_rid()]
	if not owner_ship.is_empty():
		var ship_owner = get_node_or_null(owner_ship)
		if ship_owner: exclude_list.append(ship_owner.get_rid())
	
	query.exclude = exclude_list
	
	var result = space_state.intersect_ray(query)
	if result:
		# On a touché quelque chose entre deux images !
		_on_body_entered(result.collider)
		if not is_inside_tree(): # Si le boulet a explosé (queue_free)
			return
		# Sinon on continue la trajectoire (ex: allié traversé)

	# Temps de vie
	life_time += delta
	
	# DETECTION Eclaboussure (Eau à y=0)
	if global_position.y <= 0.0:
		_spawn_splash()
		queue_free()
		return

	# Si le temps est écoulé (max_life_time), fait tomber le boulet
	if life_time >= max_life_time:
		_spawn_splash()
		queue_free()
		return

	# Apply dropping physics to the projectile
	velocity.y -= gravity_force * delta
	global_position += velocity * delta

static var _splash_mesh: SphereMesh = null
static var _splash_mat: StandardMaterial3D = null

func _spawn_splash():
	if not _splash_mesh:
		_splash_mesh = SphereMesh.new()
		_splash_mesh.radius = 0.4
		_splash_mesh.height = 0.8
		_splash_mesh.radial_segments = 4
		_splash_mesh.rings = 4
		
		_splash_mat = StandardMaterial3D.new()
		_splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_splash_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
		_splash_mesh.material = _splash_mat

	var splash = CPUParticles3D.new()
	get_parent().add_child(splash)
	splash.global_position = Vector3(global_position.x, 0, global_position.z)
	
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 25 # Reduced for performance
	splash.lifetime = 1.0
	
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 45.0
	splash.initial_velocity_min = 6.0
	splash.initial_velocity_max = 12.0
	splash.gravity = Vector3(0, -20, 0)
	
	splash.mesh = _splash_mesh
	
	# Auto-clean
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(splash.queue_free)
	
	# Courbe de taille (rétrécit en tombant)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	splash.scale_amount_curve = curve
	
	# Dégradé de transparence
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.7))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	splash.color_ramp = grad

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
		var ship_owner = get_node_or_null(owner_ship)
		
		# On ne se blesse pas soi-même
		if body == ship_owner:
			return
			
		# Pas de friendly fire (ennemis entre eux / alliés entre eux)
		if is_instance_valid(ship_owner) and "faction" in ship_owner and "faction" in body:
			var owner_is_player = (ship_owner.faction == EnemyShip.Faction.PLAYER)
			var body_is_player = (body.faction == EnemyShip.Faction.PLAYER)
			
			if owner_is_player != body_is_player:
				pass # Player vs Ennemi ou Ennemi vs Player : on autorise
			elif ship_owner.faction == body.faction:
				return # Ennemis de même faction : on bloque
				
				
		body.call("take_damage", damage, ship_owner)
		queue_free()
	elif body is Ile:
		queue_free()
