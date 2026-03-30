extends Node3D

@onready var world_env = $WorldEnvironment
@onready var player_ship = $Ship

var base_fog_color = Color(0.4, 0.6, 0.75)
var kraken_fog_color = Color(0.1, 0.15, 0.25)
var current_fog_color = Color(0.4, 0.6, 0.75)

func _ready():
	GameManager.state = GameManager.GameState.PLAYING
	# Ensure HUD is connected correctly
	get_tree().call_group("hud", "_on_active_ship_changed", 0)

func _process(_delta):
	pass
