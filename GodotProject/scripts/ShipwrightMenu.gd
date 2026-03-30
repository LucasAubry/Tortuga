class_name ShipwrightMenu
extends CanvasLayer

# --- Définition des améliorations disponibles ---
const UPGRADES = [
	{
		"id": "max_hp",
		"name": "⚓ Coque Renforcée",
		"desc": "+50 Points de Vie",
		"max_level": 5,
		"base_cost": 150,
		"cost_scaling": 1.5,
	},
	{
		"id": "damage",
		"name": "💥 Canons Lourds",
		"desc": "+10 Dégâts de Canons",
		"max_level": 5,
		"base_cost": 200,
		"cost_scaling": 1.6,
	},
	{
		"id": "max_speed",
		"name": "💨 Voiles Améliorées",
		"desc": "+15 Vitesse Max",
		"max_level": 4,
		"base_cost": 180,
		"cost_scaling": 1.5,
	},
	{
		"id": "max_ammo",
		"name": "🔧 Soute à Boulets",
		"desc": "+20 Munitions Max",
		"max_level": 4,
		"base_cost": 100,
		"cost_scaling": 1.4,
	},
	{
		"id": "armor",
		"name": "🛡 Blindage Naval",
		"desc": "-15% Dégâts reçus",
		"max_level": 3,
		"base_cost": 300,
		"cost_scaling": 2.0,
	},
]

var _player: Ship = null
var _panels: Array = []
var _upgrade_levels: Dictionary = {}

func _ready():
	visible = false
	add_to_group("shipwright_menu")

func show_menu():
	_player = _find_player()
	if not _player:
		push_error("ShipwrightMenu: Joueur introuvable")
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
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()

func _find_player() -> Ship:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Ship and node.is_player:
			return node
	return null

func _get_upgrade_cost(upgrade: Dictionary) -> int:
	var level = _upgrade_levels.get(upgrade["id"], 0)
	return int(upgrade["base_cost"] * pow(upgrade["cost_scaling"], level))

func _build_ui():
	# Nettoyer l'ancienne UI
	for child in get_children():
		child.queue_free()
	_panels.clear()
	await get_tree().process_frame  # Attendre la suppression

	# Overlay sombre
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.02, 0.88)
	add_child(bg)

	# Conteneur principal centré
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER)
	margin.custom_minimum_size = Vector2(820, 600)
	margin.position = get_viewport().get_visible_rect().size / 2.0 - Vector2(410, 300)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Titre
	var title = Label.new()
	title.text = "⚒  CHARPENTIER NAVAL  ⚒"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	# Ligne d'OR actuel
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_refresh_gold_label(gold_label)
	vbox.add_child(gold_label)

	# Grille d'améliorations
	var grid = GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for upgrade in UPGRADES:
		var panel = _make_upgrade_panel(upgrade, gold_label)
		grid.add_child(panel)

	# Bouton Fermer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "✕  Quitter le Charpentier"
	close_btn.custom_minimum_size = Vector2(300, 52)
	close_btn.add_theme_font_size_override("font_size", 20)
	var sb_c = StyleBoxFlat.new()
	sb_c.bg_color = Color(0.6, 0.15, 0.1)
	sb_c.corner_radius_top_left = 8
	sb_c.corner_radius_top_right = 8
	sb_c.corner_radius_bottom_left = 8
	sb_c.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", sb_c)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.pressed.connect(hide_menu)
	vbox.add_child(close_btn)

func _make_upgrade_panel(upgrade: Dictionary, gold_label: Label) -> PanelContainer:
	var level = _upgrade_levels.get(upgrade["id"], 0)
	var max_level = upgrade["max_level"]
	var cost = _get_upgrade_cost(upgrade)
	var maxed = level >= max_level

	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.1, 0.05, 0.9)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.5, 0.35, 0.1, 0.8)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# Info texte
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl = Label.new()
	name_lbl.text = upgrade["name"]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	info.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = upgrade["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(desc_lbl)

	# Niveau - étoiles
	var level_lbl = Label.new()
	var stars = "★".repeat(level) + "☆".repeat(max_level - level)
	level_lbl.text = "Niveau %d / %d   %s" % [level, max_level, stars]
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if level > 0 else Color(0.5, 0.5, 0.5))
	info.add_child(level_lbl)

	# Bouton Acheter
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 52)
	buy_btn.add_theme_font_size_override("font_size", 17)

	if maxed:
		buy_btn.text = "MAXIMAL ✓"
		buy_btn.disabled = true
		var sb_max = StyleBoxFlat.new()
		sb_max.bg_color = Color(0.15, 0.5, 0.15)
		sb_max.corner_radius_top_left = 6
		sb_max.corner_radius_top_right = 6
		sb_max.corner_radius_bottom_left = 6
		sb_max.corner_radius_bottom_right = 6
		buy_btn.add_theme_stylebox_override("normal", sb_max)
		buy_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	else:
		buy_btn.text = "🪙 %d Or" % cost
		var can_afford = _player and _player.gold >= cost
		var sb_buy = StyleBoxFlat.new()
		sb_buy.bg_color = Color(0.25, 0.6, 0.25) if can_afford else Color(0.4, 0.2, 0.1)
		sb_buy.corner_radius_top_left = 6
		sb_buy.corner_radius_top_right = 6
		sb_buy.corner_radius_bottom_left = 6
		sb_buy.corner_radius_bottom_right = 6
		buy_btn.add_theme_stylebox_override("normal", sb_buy)
		buy_btn.add_theme_color_override("font_color", Color.WHITE)
		buy_btn.disabled = not can_afford
		buy_btn.pressed.connect(_on_buy.bind(upgrade, gold_label))

	hbox.add_child(buy_btn)
	return panel

func _on_buy(upgrade: Dictionary, gold_label: Label):
	if not _player: return
	var cost = _get_upgrade_cost(upgrade)
	if _player.gold < cost: return

	_player.gold -= cost
	var level = _upgrade_levels.get(upgrade["id"], 0)
	_upgrade_levels[upgrade["id"]] = level + 1

	# Appliquer l'amélioration
	match upgrade["id"]:
		"max_hp":
			_player.max_hp += 50
			_player.hp = min(_player.hp + 50, _player.max_hp)
		"damage":
			_player.damage += 10
		"max_speed":
			_player.max_speed += 15
		"max_ammo":
			_player.max_ammo += 20
			_player.ammo = min(_player.ammo + 20, _player.max_ammo)
		"armor":
			if not "armor_reduction" in _player:
				_player.set_meta("armor_reduction", 0.0)
			var current_armor = _player.get_meta("armor_reduction", 0.0)
			_player.set_meta("armor_reduction", current_armor + 0.15)

	_refresh_gold_label(gold_label)
	# Reconstruire la UI pour mettre à jour les boutons
	_build_ui()

func _refresh_gold_label(lbl: Label):
	if _player:
		lbl.text = "🪙  Or disponible : %d" % _player.gold
