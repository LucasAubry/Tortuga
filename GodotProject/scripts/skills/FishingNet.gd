class_name FishingNet
extends WeaponData

@export var snare_duration: float = 4.0

func _init():
	type = ActionType.SKILL
	weapon_name = "Filet de Pêche"
	# On peut utiliser projectile_speed pour la vitesse du filet
	projectile_speed = 100.0
	skill_duration = 0.0
	cooldown = 10.0

func activate(ship: Node3D):
	# Instanciation du projectile filet
	var NetProjectileScene = load("res://scenes/NetProjectile.tscn")
	if not NetProjectileScene:
		push_error("Missing NetProjectile.tscn")
		return
		
	var proj = NetProjectileScene.instantiate()
	ship.get_tree().get_root().add_child(proj)
	
	# Spawn à l'avant
	var forward = ship.transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	proj.global_position = ship.global_position + Vector3(0, 5, 0) + forward * 8.0
	proj.velocity = forward * projectile_speed
	proj.snare_duration = snare_duration
	proj.owner_ship = ship.get_path()
	proj.is_player_owned = ship.get("is_player") if "is_player" in ship else false
	
	print("<<< Filet de Pêche Lancé ! >>>")
