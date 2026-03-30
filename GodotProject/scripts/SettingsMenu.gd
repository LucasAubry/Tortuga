class_name SettingsMenu
extends CanvasLayer

@onready var slider_vol = $ColorRect/MarginContainer/VBox/HBoxControls/AudioCol/HSliderVol
@onready var option_lang = $ColorRect/MarginContainer/VBox/HBoxControls/AudioCol/OptionLang
@onready var option_preset = $ColorRect/MarginContainer/VBox/HBoxControls/GraphicsCol/OptionPreset
@onready var close_btn = $ColorRect/MarginContainer/VBox/CloseBtn

var _is_rebinding: bool = false
var _rebind_action: String = ""
var _rebind_button: Button = null

func _ready():
	visible = false
	
	# Connect UI Signals
	close_btn.pressed.connect(hide_menu)
	slider_vol.value_changed.connect(_on_vol_changed)
	option_lang.item_selected.connect(_on_lang_changed)
	option_preset.item_selected.connect(_on_preset_changed)
	
	# --- ADD CEL SHADER ET FPS SETTINGS ---
	var graphics_box = $ColorRect/MarginContainer/VBox/HBoxControls/GraphicsCol
	if graphics_box:
		var check_fps = CheckButton.new()
		check_fps.text = "Show FPS"
		check_fps.button_pressed = GameConfig.show_fps
		check_fps.toggled.connect(_on_fps_toggled)
		graphics_box.add_child(check_fps)
		
		var label_cap = Label.new()
		label_cap.text = "Limiteur FPS"
		graphics_box.add_child(label_cap)
		
		var option_fps_cap = OptionButton.new()
		option_fps_cap.add_item("Illimité (VSync)")
		option_fps_cap.add_item("60 FPS")
		option_fps_cap.add_item("30 FPS")
		option_fps_cap.selected = GameConfig.fps_limit_index
		option_fps_cap.item_selected.connect(_on_fps_cap_changed)
		graphics_box.add_child(option_fps_cap)
	
	# --- ADD KEYBINDINGS ---
	_setup_keybindings_ui()

func _setup_keybindings_ui():
	var hbox = $ColorRect/MarginContainer/VBox/HBoxControls
	if not hbox: return
	
	# Create a new column for controls if it doesn't exist
	var controls_col = VBoxContainer.new()
	controls_col.name = "ControlsCol"
	controls_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(controls_col)
	
	var label_title = Label.new()
	label_title.text = "CONTRÔLES"
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_col.add_child(label_title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	controls_col.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	var actions_friendly_names = {
		"move_forward": "Avancer",
		"move_backward": "Reculer",
		"move_left": "Tourner Gauche",
		"move_right": "Tourner Droite",
		"skill_1": "Compétence 1",
		"skill_2": "Compétence 2",
		"skill_3": "Compétence 3",
		"skill_4": "Compétence 4",
		"skill_5": "Compétence 5",
		"toggle_map": "Ouvrir Carte",
		"toggle_tab": "Menu Tab"
	}
	
	for action in GameConfig.key_bindings.keys():
		var row = HBoxContainer.new()
		list.add_child(row)
		
		var label = Label.new()
		label.text = actions_friendly_names.get(action, action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		
		var btn = Button.new()
		btn.text = OS.get_keycode_string(GameConfig.key_bindings[action])
		btn.custom_minimum_size = Vector2(120, 0)
		btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
		row.add_child(btn)

func _on_rebind_pressed(action: String, btn: Button):
	if _is_rebinding: return
	
	_is_rebinding = true
	_rebind_action = action
	_rebind_button = btn
	btn.text = "???"

func _input(event):
	if _is_rebinding and event is InputEventKey and event.pressed:
		_finish_rebind(event.physical_keycode)
		get_viewport().set_input_as_handled()

func _finish_rebind(new_key: int):
	GameConfig.key_bindings[_rebind_action] = new_key
	_rebind_button.text = OS.get_keycode_string(new_key)
	
	_is_rebinding = false
	_rebind_action = ""
	_rebind_button = null
	
	GameConfig.save_config()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _is_rebinding:
				_is_rebinding = false
				_setup_keybindings_ui() # Refresh to cancel
				return
				
			if visible:
				hide_menu()
			else:
				# Don't toggle settings if map or tab is open
				var map = get_tree().get_first_node_in_group("map_ui")
				var tab = get_tree().get_first_node_in_group("tab_menu")
				if (map and map.visible) or (tab and tab.visible):
					return
				show_menu()

func show_menu():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu():
	visible = false
	get_tree().paused = false
	# On ne force plus le mode souris ici, car le jeu peut vouloir le garder capturé
	# Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_vol_changed(value: float):
	GameManager.master_volume = value
	# Logically hook into Godot AudioServer if desired
	print("Volume set to: ", value)

func _on_lang_changed(idx: int):
	# 0 = English, 1 = Francais
	if idx == 0:
		print("Language: English")
	elif idx == 1:
		print("Language: Francais")

func _on_preset_changed(idx: int):
	# 0 = Low, 1 = Med, 2 = High
	print("Graphics set to: ", idx)
	# Here you would toggle WorldEnvironment glow, shadows, or MSAA


func _on_fps_toggled(enabled: bool):
	GameConfig.show_fps = enabled
	GameConfig.fps_toggled.emit(enabled)
	print("FPS Toggled: ", enabled)

func _on_fps_cap_changed(idx: int):
	GameConfig.fps_limit_index = idx
	match idx:
		0:
			Engine.max_fps = 0 # Illimité (Dépend du VSync du projet)
		1:
			Engine.max_fps = 60
		2:
			Engine.max_fps = 30
	print("FPS Limit changed to index: ", idx, " (Max FPS: ", Engine.max_fps, ")")
