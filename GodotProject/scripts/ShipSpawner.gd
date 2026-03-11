extends Node3D

@export var spawn_interval: float = 15.0
@export var max_ships: int = 8
@export var spawn_radius: float = 2500.0

const EnemyShipScene = preload("res://scenes/EnemyShip.tscn")
const TentacleScene = preload("res://scenes/tentacule_kraken.tscn")
const ProjectileScene = preload("res://scenes/Projectile.tscn")

var _timer: float = 15.0 # Après le premier spawn massif, on attend 15s

func _ready():
	_cache_shaders()
	# Fais spawn dès la première frame
	for i in range(max_ships):
		call_deferred("_spawn_if_needed")

func _cache_shaders():
	# Caching simplifié sans accès aux positions world pour éviter les erreurs
	if TentacleScene:
		var tentacle = TentacleScene.instantiate()
		tentacle.visible = false
		add_child(tentacle)
		tentacle.queue_free()
		
	if ProjectileScene:
		var proj = ProjectileScene.instantiate()
		proj.visible = false
		add_child(proj)
		proj.queue_free()

func _process(delta):
	_timer -= delta
	if _timer <= 0:
		_timer = spawn_interval
		_spawn_if_needed()

func _spawn_if_needed():
	var ships = get_tree().get_nodes_in_group("ship")
	if ships.size() >= max_ships:
		return
		
	if not EnemyShipScene: return

	var ship = EnemyShipScene.instantiate()
	# Ajoute comme enfant de la scène principale pour de meilleures performances/gestion de scène
	get_tree().current_scene.add_child(ship)
	
	var spawn_center = global_position
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		spawn_center = players[0].global_position
		
	# Position aléatoire autour du joueur
	var angle = randf() * TAU
	var dist = randf_range(500.0, 900.0) # Un peu plus proche pour l'action
	var spawn_pos = spawn_center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	ship.global_position = spawn_pos
	
	# Faction aléatoire (NAVY=1, PIRATE=2, MERCHANT=3)
	var factions = [EnemyShip.Faction.NAVY, EnemyShip.Faction.PIRATE, EnemyShip.Faction.MERCHANT]
	ship.faction = factions[randi() % factions.size()]
	ship.is_player = false
	
	# Type de bateau aléatoire
	ship.ship_type = randi() % 3
	
	print("Spawner: Nouveau navire ", EnemyShip.Faction.keys()[ship.faction], " apparu en ", spawn_pos)
