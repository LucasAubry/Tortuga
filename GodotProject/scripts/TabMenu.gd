class_name TabMenu
extends CanvasLayer

@onready var label_speed = $ColorRect/MarginContainer/VBox/HBox/StatsPanel/LabelSpeed
@onready var label_damage = $ColorRect/MarginContainer/VBox/HBox/StatsPanel/LabelDamage
@onready var label_reload = $ColorRect/MarginContainer/VBox/HBox/StatsPanel/LabelReload
@onready var label_upgrades = $ColorRect/MarginContainer/VBox/HBox/StatsPanel/LabelUpgrades

func _ready():
	visible = false
	add_to_group("tab_menu")
	_scale_fonts(self, 26)

func _apply_font_recursive(node: Node, font: Font):
	if node is Label:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if visible:
				hide_menu()
			else:
				show_menu()
		elif visible and event.keycode == KEY_ESCAPE:
			hide_menu()

func show_menu():
	visible = true
	_update_stats()

func hide_menu():
	visible = false

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

func _scale_fonts(node: Node, font_size: int):
	if node is Label or node is Button:
		node.add_theme_font_size_override("font_size", font_size)
	for child in node.get_children():
		_scale_fonts(child, font_size)
