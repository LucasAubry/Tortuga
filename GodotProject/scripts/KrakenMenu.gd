class_name KrakenMenu
extends CanvasLayer

@onready var grid = $BurntMap/PartsContainer/PartsGrid
@onready var close_btn_node = $BurntMap/CloseBtn

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	close_btn_node.pressed.connect(hide_menu)
	
	# Style du bouton fermer
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.35, 0.18, 0.08, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.border_color = Color(0.2, 0.1, 0.05, 1.0)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.45, 0.22, 0.1, 1.0)
	hover_style.shadow_color = Color(0, 0, 0, 0.3)
	hover_style.shadow_size = 8
	
	close_btn_node.add_theme_stylebox_override("normal", normal_style)
	close_btn_node.add_theme_stylebox_override("hover", hover_style)
	close_btn_node.add_theme_stylebox_override("pressed", normal_style)

func refresh_checkboxes():
	if not grid: return
	for child in grid.get_children():
		child.queue_free()
	
	var config = GameConfig.kraken_tentacle_parts
	for part_name in config.keys():
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl = Label.new()
		lbl.text = part_name.replace("Tentacle", "Tronçon ").replace("Armor", "Armure ").replace("Spikes", "Pointes ")
		lbl.add_theme_color_override("font_color", Color(0.25, 0.12, 0.05, 1.0))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
		
		var cb = CheckBox.new()
		cb.button_pressed = config[part_name]
		cb.toggled.connect(func(pressed): 
			config[part_name] = pressed
		)
		cb.add_theme_color_override("font_color", Color(0.25, 0.12, 0.05, 1.0))
		hbox.add_child(cb)
		
		grid.add_child(hbox)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and visible:
			hide_menu()

func _process(_delta):
	if Input.is_action_just_pressed("act"):
		if not visible:
			if GameManager.parked_island != null:
				var island = GameManager.parked_island
				if island is Ile and island.ile_type == Ile.IleType.KRAKEN_FARMER:
					show_menu()
		else:
			hide_menu()

func show_menu():
	refresh_checkboxes()
	visible = true
	get_tree().paused = true
	GameManager.state = GameManager.GameState.KRAKEN_MENU

func hide_menu():
	visible = false
	get_tree().paused = false
	GameManager.state = GameManager.GameState.PLAYING
