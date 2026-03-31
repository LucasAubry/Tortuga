class_name TabMenu
extends CanvasLayer

@onready var label_speed = $BurntMap/LabelSpeed
@onready var label_damage = $BurntMap/LabelDamage
@onready var label_reload = $BurntMap/LabelReload
@onready var label_upgrades = $BurntMap/LabelUpgrades
@onready var close_btn = $BurntMap/CloseBtn

var inventory_grid: GridContainer

func _ready():
	visible = false
	add_to_group("tab_menu")
	if close_btn:
		close_btn.pressed.connect(hide_menu)
	
	_setup_inventory_ui()

func _setup_inventory_ui():
	# Création de la section Inventaire
	var section_label = Label.new()
	section_label.text = "── Inventaire ──"
	section_label.add_theme_font_size_override("font_size", 26)
	section_label.add_theme_color_override("font_color", Color(0.25, 0.12, 0.05, 1))
	section_label.position = Vector2(135, 540)
	$BurntMap.add_child(section_label)
	
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.set_deferred("theme_override_constants/h_separation", 15)
	inventory_grid.set_deferred("theme_override_constants/v_separation", 15)
	inventory_grid.position = Vector2(135, 590)
	$BurntMap.add_child(inventory_grid)
	
	# Création des 12 cases vides
	for i in range(12):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(60, 60)
		# Style parchemin/bois pour les cases
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.1)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.1, 0.05, 0.5)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		slot.add_theme_stylebox_override("panel", style)
		
		# Overlay pour l'icône
		var icon = Label.new()
		icon.name = "Icon"
		icon.text = ""
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.add_theme_font_size_override("font_size", 32)
		slot.add_child(icon)
		
		inventory_grid.add_child(slot)

func _unhandled_input(event):
	if event.is_action_pressed("toggle_tab"):
		if visible:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()
		get_viewport().set_input_as_handled()

func show_menu():
	visible = true
	_update_stats()
	_update_inventory()

func hide_menu():
	visible = false

func _update_inventory():
	var p = _find_player()
	if not p or not inventory_grid: return
	
	var items = p.inventory
	var children = inventory_grid.get_children()
	
	for i in range(children.size()):
		var slot = children[i]
		var icon_label = slot.get_node("Icon")
		if i < items.size():
			var item = items[i]
			if item == "Poisson":
				icon_label.text = "🐟"
			else:
				icon_label.text = "📦"
		else:
			icon_label.text = ""

func _update_stats():
	var p = _find_player()
	if not p: return
	
	label_speed.text = "Vitesse Max: %.1f kts" % (p.max_speed * 10.0)
	label_damage.text = "Dégâts Canons: %d" % p.damage
	label_reload.text = "Temps de recharge: %.1fs" % p.max_cooldown
	label_upgrades.text = "Améliorations (Cadence): %d" % p.fire_rate_level

func _find_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player: return node
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res: return res
	return null
