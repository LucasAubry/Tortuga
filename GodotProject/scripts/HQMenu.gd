extends CanvasLayer

@onready var ship_list = $BurntMap/MarginContainer/VBox/ShipList
@onready var gold_label = $BurntMap/MarginContainer/VBox/GoldLabel

func _ready():
	visible = false

func show_menu():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_list()

func _refresh_list():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		gold_label.text = "OR ACTUEL : " + str(player.gold)
	
	# Clear previous list (except templates if any)
	for child in ship_list.get_children():
		child.queue_free()
	
	for i in range(GameConfig.available_ships.size()):
		var ship_data = GameConfig.available_ships[i]
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = ship_data.name + " (" + str(ship_data.price) + " Or)"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
		
		var btn = Button.new()
		btn.text = "ACHETER"
		if player and player.ship_type == ship_data.type:
			btn.text = "ACTUEL"
			btn.disabled = true
		elif player and player.gold < ship_data.price:
			btn.disabled = true
			btn.text = "TROP CHER"
		
		btn.pressed.connect(_on_ship_bought.bind(i))
		
		hbox.add_child(label)
		hbox.add_child(btn)
		ship_list.add_child(hbox)

func _on_ship_bought(index: int):
	var player = get_tree().get_first_node_in_group("player")
	var ship_data = GameConfig.available_ships[index]
	
	if player and player.gold >= ship_data.price:
		player.gold -= ship_data.price
		player.switch_ship(ship_data.type, ship_data.scene_path)
		_on_close_pressed()

func _on_close_pressed():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.state = GameManager.GameState.PLAYING
