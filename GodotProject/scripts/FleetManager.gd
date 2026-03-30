extends Node

signal fleet_updated
signal active_ship_changed(index: int)
signal selection_changed

var ships: Array[Ship] = [null]
var gold: int = 0
var active_index: int = 0
var selected_ships: Array[Ship] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().process_frame.connect(_find_initial_ship, CONNECT_ONE_SHOT)

func _find_initial_ship():
	var player = get_tree().get_first_node_in_group("player")
	if player and player is Ship:
		ships[0] = player
		gold = player.gold
		player.set_controlled(true)
		player.is_player = true
		fleet_updated.emit()

func get_active_ship() -> Ship:
	return ships[0]

func switch_to_ship(index: int):
	pass

func add_ship(ship: Ship, slot: int = -1) -> bool:
	return false

func remove_ship(ship: Ship):
	if ships[0] == ship:
		ships[0] = null
		get_tree().call_group("hud", "show_death_screen")
