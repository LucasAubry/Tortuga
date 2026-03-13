class_name KrakenSkill
extends WeaponData

const TENTACLE_SCENE = preload("res://scenes/tentacule_kraken.tscn")

func _init():
	pass


func activate(ship: Node3D):
	var forward = -ship.global_transform.basis.z
	var ship_pos = ship.global_position
	
	var circle_center = ship_pos
	var radius = 80.0 # Cercle autour du bateau (espacement élargi)
	var tentacle_count = 5
	
	for i in range(tentacle_count):
		var tentacle = TENTACLE_SCENE.instantiate()
		
		tentacle.duration = skill_duration
		tentacle.scale = Vector3(500, 500, 500)
		tentacle.rotation.y = randf_range(0, TAU) # Rotation aléatoire
		
		ship.get_parent().add_child(tentacle)
		
		# Calcul de la position : formation en cercle autour d'un point devant
		var angle = (float(i) / tentacle_count) * TAU
		var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		
		var spawn_pos = circle_center + offset
		spawn_pos.y = -25.0
		
		tentacle.global_position = spawn_pos
		tentacle.set_meta("caster", ship) # Indique qui a invoqué le kraken
	
	print("<<< Kraken Skill Activated! >>>")
