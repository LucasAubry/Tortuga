class_name SettingsMenu
extends CanvasLayer

@onready var slider_vol = $ColorRect/MarginContainer/VBox/HBoxControls/AudioCol/HSliderVol
@onready var option_lang = $ColorRect/MarginContainer/VBox/HBoxControls/AudioCol/OptionLang
@onready var option_preset = $ColorRect/MarginContainer/VBox/HBoxControls/GraphicsCol/OptionPreset
@onready var close_btn = $ColorRect/MarginContainer/VBox/CloseBtn

func _ready():
	visible = false
	
	# Connect UI Signals
	close_btn.pressed.connect(hide_menu)
	slider_vol.value_changed.connect(_on_vol_changed)
	option_lang.item_selected.connect(_on_lang_changed)
	option_preset.item_selected.connect(_on_preset_changed)
	
	# Font assignment removed

func _apply_font_recursive(node: Node, font: Font):
	if node is Label or node is Button:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
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

func hide_menu():
	visible = false
	get_tree().paused = false

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
