class_name ShipwrightMenu
extends CanvasLayer

# Chemins mis à jour pour le nouveau design "Burnt Map"
@onready var grid: VBoxContainer = find_child("ShipList", true, false)
@onready var gold_label: Label = find_child("GoldLabel", true, false)
@onready var close_btn: Button = find_child("CloseBtn", true, false)

var _player: CharacterBody3D = null

func _ready():
	visible = false
	add_to_group("shipwright_menu")
	if close_btn:
		close_btn.pressed.connect(hide_menu)

func show_menu():
	_player = FleetManager.get_active_ship()
	if not _player:
		push_error("ShipwrightMenu: Aucun navire actif trouvé")
		return
	visible = true
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu():
	visible = false
	GameManager.state = GameManager.GameState.PLAYING
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if visible and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_G):
		hide_menu()

func _build_ui():
	if not grid: return
	
	for child in grid.get_children():
		child.queue_free()
	
	if gold_label:
		gold_label.text = "OR ACTUEL : %d" % FleetManager.gold

	# Offres de navires
	grid.add_child(_make_ship_panel("Chaloupe", "Petit, agile, idéal pour débuter.", 300, Ship.ShipClass.SLOOP))
	grid.add_child(_make_ship_panel("Brigantin", "Navire de commerce équilibré.", 800, Ship.ShipClass.BRIGANTINE))
	grid.add_child(_make_ship_panel("Galion", "Le seigneur des mers.", 2000, Ship.ShipClass.GALLEON))

func _make_ship_panel(ship_name: String, desc: String, cost: int, type: Ship.ShipClass) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	# Design assorti à la carte parchemin
	sb.bg_color = Color(0.2, 0.1, 0.05, 0.3)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.15, 0.05, 0.4)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(0, 100)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info)
	
	var n_lbl = Label.new()
	n_lbl.text = ship_name
	n_lbl.add_theme_font_size_override("font_size", 22)
	n_lbl.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02)) # Texte sombre sur parchemin
	info.add_child(n_lbl)
	
	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15))
	info.add_child(d_lbl)
	
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 45)
	var can_afford = FleetManager.gold >= cost and FleetManager.ships.size() < 5
	
	if FleetManager.ships.size() >= 5:
		buy_btn.text = "FLOTTE PLEINE"
		buy_btn.disabled = true
	else:
		buy_btn.text = "🔨 %d Or" % cost
		buy_btn.disabled = not can_afford
		
	var sb_btn = StyleBoxFlat.new()
	sb_btn.bg_color = Color(0.3, 0.15, 0.05, 1.0) if can_afford else Color(0.4, 0.4, 0.4, 0.5)
	sb_btn.set_corner_radius_all(5)
	buy_btn.add_theme_stylebox_override("normal", sb_btn)
	buy_btn.add_theme_color_override("font_color", Color.WHITE)
	
	buy_btn.pressed.connect(_on_buy_ship.bind(type, cost))
	hbox.add_child(buy_btn)
	
	return panel

func _on_buy_ship(type: Ship.ShipClass, cost: int):
	if FleetManager.gold < cost: return
	
	if FleetManager.add_ship(type):
		FleetManager.gold -= cost
		_build_ui()
