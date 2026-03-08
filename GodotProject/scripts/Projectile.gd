class_name Projectile
extends Area3D

var velocity: Vector3
var life_time: float = 0.0
var max_life_time: float = 5.0
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
	# Kill completely when sinking below the water or timing out fully
	if position.y < -5.0 or life_time >= max_life_time:
		queue_free()

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
