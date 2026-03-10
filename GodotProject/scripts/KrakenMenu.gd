class_name KrakenMenu
extends CanvasLayer

@onready var scroll = $BurntMap/PartsContainer
@onready var close_btn_node = $BurntMap/CloseBtn
@onready var subtitle = $BurntMap/SousTitre

const ICON_TENTACLE = preload("res://assets/ui/icons/icon_tentacle.png")
const ICON_ARMURE = preload("res://assets/ui/icons/icon_armure.png")
const ICON_PIQUE = preload("res://assets/ui/icons/icon_pique.png")

enum KrakenTab { TENTACLES, PROTECTION, ATTACK }
var current_tab = KrakenTab.TENTACLES
var tab_buttons = {}
var tree_canvas: Control = null  # Free-form container for skill nodes
var skill_positions = {}  # id -> Vector2 center position (for drawing lines)

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if close_btn_node:
		close_btn_node.pressed.connect(hide_menu)
	
	_setup_tabs()
	subtitle.text = "Points de compétence: 0"

func _setup_tabs():
	var tabs_container = HBoxContainer.new()
	tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_container.name = "TabsContainer"
	tabs_container.custom_minimum_size = Vector2(600, 50)
	tabs_container.position = Vector2(150, 240)
	$BurntMap.add_child(tabs_container)
	
	var labels = {
		KrakenTab.TENTACLES: "COMPÉTENCES",
		KrakenTab.PROTECTION: "VIE (ARMURES)",
		KrakenTab.ATTACK: "DÉGÂTS (PIQUES)"
	}
	
	for tab_id in labels.keys():
		var btn = Button.new()
		btn.text = labels[tab_id]
		btn.custom_minimum_size = Vector2(180, 40)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.15, 0.05, 0.3)
		style.set_border_width_all(2)
		style.border_color = Color(0.2, 0.1, 0.05, 0.6)
		btn.add_theme_stylebox_override("normal", style)
		
		btn.pressed.connect(func():
			current_tab = tab_id
			_update_tab_visuals()
			refresh_skill_tree()
		)
		tabs_container.add_child(btn)
		tab_buttons[tab_id] = btn
	
	_update_tab_visuals()

func _update_tab_visuals():
	for tab_id in tab_buttons.keys():
		var btn = tab_buttons[tab_id]
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if tab_id == current_tab:
			style.bg_color = Color(0.4, 0.2, 0.1, 0.8)
			style.border_color = Color(1.0, 0.8, 0.0, 1.0)
			btn.add_theme_color_override("font_color", Color(1, 1, 0.8))
		else:
			style.bg_color = Color(0.3, 0.15, 0.05, 0.3)
			style.border_color = Color(0.2, 0.1, 0.05, 0.6)
			btn.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 0.8))

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
	refresh_skill_tree()
	visible = true
	get_tree().paused = true
	GameManager.state = GameManager.GameState.KRAKEN_MENU

func hide_menu():
	visible = false
	get_tree().paused = false
	GameManager.state = GameManager.GameState.PLAYING

func refresh_skill_tree():
	# Remove old canvas
	if tree_canvas and is_instance_valid(tree_canvas):
		tree_canvas.queue_free()
	
	skill_positions.clear()
	
	subtitle.text = "Points: %d  ─  Niveau %d" % [GameConfig.kraken_skill_points, GameConfig.kraken_level]
	
	# Create a free-form Control as the canvas
	tree_canvas = Control.new()
	tree_canvas.custom_minimum_size = Vector2(700, 900)
	scroll.add_child(tree_canvas)
	
	# Define positions and connections per tab
	var skills = []  # [id, texture, label, dependency, pos_x, pos_y]
	var visual_lines = []  # Extra visual-only lines: [from_id, to_id]
	
	match current_tab:
		KrakenTab.TENTACLES:
			skills = [
				["TentacleV1", ICON_TENTACLE, "ventouse", "", 170, 10],
				["TentacleV2", ICON_TENTACLE, "piquant", "TentacleV1", 430, 60],
				["TentacleV3", ICON_TENTACLE, "lisse", "TentacleV2", 120, 230],
				["TentacleV4", ICON_TENTACLE, "vertèbre", "TentacleV3", 400, 280],
				["TentacleV5", ICON_TENTACLE, "plante", "TentacleV4", 250, 460],
			]
			
		KrakenTab.PROTECTION:
			skills = [
				["ArmorV1", ICON_ARMURE, "écailles dorsale", "", 140, 40],
				["ArmorV2", ICON_ARMURE, "armure dorsale", "", 420, 40],
				["ArmorV3", ICON_ARMURE, "armure longue dorsale", "", 280, 260],
			]
			
		KrakenTab.ATTACK:
			skills = [
				["TipSpike", ICON_PIQUE, "dart", "", 280, 0],
				["SpikesBack1", ICON_PIQUE, "pique dorsale", "TipSpike", 80, 210],
				["SpikesBack2", ICON_PIQUE, "double pique dorsale", "TipSpike", 480, 210],
				["SpikesSides", ICON_PIQUE, "pique latérale", "SpikesBack1", 30, 430],
				["SpikesFront1", ICON_PIQUE, "pique intérieur", "SpikesBack2", 420, 430],
				["SpikesFront2", ICON_PIQUE, "double pique intérieur", "SpikesFront1", 150, 640],
				["Thorns", ICON_PIQUE, "pique profond", "SpikesFront2", 470, 640],
			]
	
	# First pass: record center positions for line drawing
	var icon_size = 110
	for s in skills:
		var cx = s[4] + icon_size / 2.0
		var cy = s[5] + icon_size / 2.0
		skill_positions[s[0]] = Vector2(cx, cy)
	
	# Draw dependency connection lines (behind icons)
	for s in skills:
		var dep = s[3]
		if dep != "" and skill_positions.has(dep):
			_draw_line(dep, s[0])
	
	# Draw visual-only lines (for tentacles tab)
	for vl in visual_lines:
		if skill_positions.has(vl[0]) and skill_positions.has(vl[1]):
			_draw_line(vl[0], vl[1])
	
	# Second pass: place skill icons
	for s in skills:
		_place_skill(s[0], s[1], s[2], s[3], s[4], s[5])

func _draw_line(from_id: String, to_id: String):
	var from_pos = skill_positions[from_id]
	var to_pos = skill_positions[to_id]
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 3
	var from_unlocked = GameConfig.kraken_unlocked_skills.get(from_id, false)
	var to_unlocked = GameConfig.kraken_unlocked_skills.get(to_id, false)
	if to_unlocked:
		line.default_color = Color(0.8, 0.65, 0.0, 0.8)
	elif from_unlocked:
		line.default_color = Color(0.5, 0.3, 0.1, 0.6)
	else:
		line.default_color = Color(0.2, 0.1, 0.05, 0.3)
	tree_canvas.add_child(line)

func _place_skill(id: String, texture: Texture, label_txt: String, dependency: String, px: float, py: float):
	var unlocked = GameConfig.kraken_unlocked_skills.get(id, false)
	var active = GameConfig.kraken_tentacle_parts.get(id, false)
	var can_unlock = GameConfig.kraken_skill_points > 0
	
	if dependency != "" and not GameConfig.kraken_unlocked_skills.get(dependency, false):
		can_unlock = false
	
	# Main container positioned freely
	var container = VBoxContainer.new()
	container.position = Vector2(px, py)
	container.custom_minimum_size = Vector2(160, 200)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.clip_contents = false
	
	# Icon frame
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(110, 110)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.13, 0.06, 1.0)
	sb.set_corner_radius_all(10)
	if active:
		sb.border_color = Color(1.0, 0.85, 0.0, 1.0)
		sb.set_border_width_all(4)
		sb.shadow_color = Color(1, 0.8, 0, 0.4)
		sb.shadow_size = 10
	elif unlocked:
		sb.border_color = Color(0.5, 0.35, 0.15, 1.0)
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(0.3, 0.15, 0.08, 0.6)
		sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	
	var btn = TextureButton.new()
	btn.texture_normal = texture
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(100, 100)
	
	# Tooltip — affiche les vrais dégâts/PV depuis GameConfig
	var effect = ""
	match id:
		"ArmorV1": effect = "+%d PV" % GameConfig.ARMOR_V1_HP_BONUS
		"ArmorV2": effect = "+%d PV" % GameConfig.ARMOR_V2_HP_BONUS
		"ArmorV3": effect = "+%d PV" % GameConfig.ARMOR_V3_HP_BONUS
		"TipSpike": effect = "+%.0f Dégâts" % GameConfig.SPIKE_TipSpike_DMG
		"SpikesBack1": effect = "+%.0f Dégâts" % GameConfig.SPIKE_SpikesBack1_DMG
		"SpikesBack2": effect = "+%.0f Dégâts" % GameConfig.SPIKE_SpikesBack2_DMG
		"SpikesSides": effect = "+%.0f Dégâts" % GameConfig.SPIKE_SpikesSides_DMG
		"SpikesFront1": effect = "+%.0f Dégâts" % GameConfig.SPIKE_SpikesFront1_DMG
		"SpikesFront2": effect = "+%.0f Dégâts" % GameConfig.SPIKE_SpikesFront2_DMG
		"Thorns": effect = "+%.0f Dégâts" % GameConfig.SPIKE_Thorns_DMG
		_: effect = ""
	btn.tooltip_text = "%s\n%s" % [label_txt, effect] if effect != "" else label_txt
	
	if not unlocked:
		btn.modulate = Color(0.3, 0.3, 0.3, 0.9)
	
	btn.pressed.connect(func():
		if unlocked:
			# Mutual exclusion for tentacles and armors
			if id.begins_with("Tentacle"):
				for k in GameConfig.kraken_tentacle_parts.keys():
					if k.begins_with("Tentacle"): GameConfig.kraken_tentacle_parts[k] = false
			if id.begins_with("Armor"):
				for k in GameConfig.kraken_tentacle_parts.keys():
					if k.begins_with("Armor"): GameConfig.kraken_tentacle_parts[k] = false
			GameConfig.kraken_tentacle_parts[id] = not GameConfig.kraken_tentacle_parts[id]
			refresh_skill_tree()
		elif can_unlock:
			GameConfig.kraken_skill_points -= 1
			GameConfig.kraken_unlocked_skills[id] = true
			if id.begins_with("Tentacle"):
				for k in GameConfig.kraken_tentacle_parts.keys():
					if k.begins_with("Tentacle"): GameConfig.kraken_tentacle_parts[k] = false
			if id.begins_with("Armor"):
				for k in GameConfig.kraken_tentacle_parts.keys():
					if k.begins_with("Armor"): GameConfig.kraken_tentacle_parts[k] = false
			GameConfig.kraken_tentacle_parts[id] = true
			refresh_skill_tree()
	)
	
	# Nom de la compétence
	var name_lbl = Label.new()
	name_lbl.text = label_txt
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(160, 0)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(0.15, 0.08, 0.03, 1) if unlocked else Color(0.2, 0.1, 0.05, 0.4))
	
	# Effet de la compétence (dégâts/PV)
	var effect_lbl = Label.new()
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_lbl.add_theme_font_size_override("font_size", 19)
	if effect != "":
		effect_lbl.text = effect
		effect_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.0, 1))
	
	# Statut
	var status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 17)
	if unlocked:
		status_lbl.text = "⚓ ÉQUIPÉ" if active else "DISPONIBLE"
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.0) if active else Color(0.3, 0.4, 0.3))
	else:
		status_lbl.text = "🔒 BLOQUÉ"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))

	frame.add_child(btn)
	container.add_child(frame)
	container.add_child(name_lbl)
	if effect != "":
		container.add_child(effect_lbl)
	container.add_child(status_lbl)
	tree_canvas.add_child(container)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and visible:
			hide_menu()
