class_name HUD
extends CanvasLayer

# Éléments d'origine (restaurés)
@onready var hp_bar = %ProgressBar
@onready var label_hp = %LabelHP
@onready var label_fps = %LabelFPS
@onready var label_ammo = get_node_or_null("MarginContainer/TopLeft/LabelAmmo")
@onready var label_gold = get_node_or_null("MarginContainer/TopLeft/LabelGold")
@onready var label_wood = get_node_or_null("MarginContainer/TopLeft/LabelWood")
@onready var label_food = get_node_or_null("MarginContainer/TopLeft/LabelFood")
@onready var label_water = get_node_or_null("MarginContainer/TopLeft/LabelWater")
@onready var label_fish = get_node_or_null("MarginContainer/TopLeft/LabelFish")
@onready var wind_speed_label = $WindBox/WindSpeedLabel
@onready var arrow_pivot = $WindBox/ArrowPivot
@onready var settings_btn = $MarginContainer/BottomRight/SettingsBtn
@onready var kraken_xp_bar = %KrakenXPBar
@onready var label_kraken_lvl = %LabelKrakenLvl

# Système d'armes (restauré)
var weapon_slot_panels: Array[PanelContainer] = []
var weapon_slot_icons: Array[TextureRect] = []
var weapon_slot_cooldowns: Array[TextureProgressBar] = []

# Système de Flotte
var fleet_slots: Array[PanelContainer] = []
var fleet_labels: Array[Label] = []
@onready var _fleet_container = %FleetGrid
@onready var _follow_menu = %FollowMenu
@onready var _defense_menu = %DefenseMenu

# Divers
var player_ship: Node3D
@onready var interaction_label = %InteractionLabel
@onready var status_label = get_node_or_null("MarginContainer/TopLeft/StatusLabel")
var enemy_hp_bars: Dictionary = {}

func _ready():
	add_to_group("hud")
	_scale_fonts(self, 24)
	
	player_ship = FleetManager.get_active_ship()
	
	_setup_weapon_ui()
	_setup_fleet_ui()
	_setup_menu_signals()
	
	# Signaux globaux
	if FleetManager:
		FleetManager.fleet_updated.connect(_on_fleet_updated)
		FleetManager.active_ship_changed.connect(_on_active_ship_changed)
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)

func _setup_menu_signals():
	if _follow_menu:
		var v = _follow_menu.get_node_or_null("VBox")
		if v:
			var cancel = v.get_node_or_null("CancelBtn")
			var close = v.get_node_or_null("CloseBtn")
			if cancel: cancel.pressed.connect(_on_follow_cancel_pressed)
			if close: close.pressed.connect(_on_follow_close_pressed)
	
	if _defense_menu:
		var v = _defense_menu.get_node_or_null("VBox")
		if v:
			var close = v.get_node_or_null("CloseBtn")
			if close: close.pressed.connect(_on_defense_close_pressed)

func _on_follow_cancel_pressed():
	var active = FleetManager.get_active_ship()
	if active:
		active.follow_target = null
		active.is_auto_cruising = false
		active.is_defending = false
	_follow_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_follow_close_pressed():
	_follow_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_defense_close_pressed():
	_defense_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_interaction_prompt(text: String):
	if interaction_label:
		interaction_label.text = text
		interaction_label.show()

func hide_interaction_prompt():
	if interaction_label:
		interaction_label.hide()

func _setup_weapon_ui():
	weapon_slot_panels = [%Slot1, %Slot2, %Slot3, %Slot4, %Slot5]
	var weapon_keys = ["1", "2", "3", "4", "5"]
	for i in range(weapon_slot_panels.size()):
		var panel = weapon_slot_panels[i]
		if not panel: continue
		var tex_rect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(50, 50)
		panel.add_child(tex_rect)
		weapon_slot_icons.append(tex_rect)
		var progress = TextureProgressBar.new()
		progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		progress.set_anchors_preset(Control.PRESET_FULL_RECT)
		progress.texture_progress = load("res://assets/ui/white_rect.png")
		progress.step = 0.01
		progress.modulate = Color(1, 1, 1, 0.4)
		progress.nine_patch_stretch = true
		panel.add_child(progress)
		weapon_slot_cooldowns.append(progress)
		var k_lbl = Label.new()
		k_lbl.text = weapon_keys[i]
		k_lbl.add_theme_font_size_override("font_size", 10)
		k_lbl.modulate = Color(1,1,1,0.5)
		panel.add_child(k_lbl)

func _setup_fleet_ui():
	if not _fleet_container: return
	# Purge if already built (safeguard)
	for c in _fleet_container.get_children(): c.queue_free()
	fleet_slots.clear()
	fleet_labels.clear()

	for i in range(5):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(100, 60)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.4)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.1)
		sb.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", sb)
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		var num_lbl = Label.new()
		num_lbl.text = "SHIFT + %d" % (i + 1)
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(num_lbl)
		var ship_lbl = Label.new()
		ship_lbl.text = "---"
		ship_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ship_lbl)
		_fleet_container.add_child(panel)
		fleet_slots.append(panel)
		fleet_labels.append(ship_lbl)

func show_defense_menu():
	if not _defense_menu: return
	_defense_menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var grid = %DefenseGrid
	if not grid: return
	
	for child in grid.get_children(): child.queue_free()
	
	var active = FleetManager.get_active_ship()
	for i in range(5):
		var weapon = active.weapon_slots[i] if active and i < active.weapon_slots.size() else null
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 40)
		grid.add_child(btn)
		if weapon:
			btn.text = "SLOT %d: %s" % [i+1, weapon.resource_name if weapon.resource_name != "" else "Arme"]
			btn.pressed.connect(func(): _on_defense_selected(i))
		else:
			btn.text = "SLOT %d: VIDE" % (i+1)
			btn.disabled = true

func _on_defense_selected(index: int):
	var active = FleetManager.get_active_ship()
	if active:
		active.is_defending = true
		active.is_auto_cruising = false
		active.follow_target = null
		active.defense_skill_index = index
	_defense_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_follow_menu():
	if not _follow_menu: return
	_follow_menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var grid = %FollowGrid
	if not grid: return
	
	for child in grid.get_children(): child.queue_free()
	
	var active = FleetManager.get_active_ship()
	for i in range(5):
		var ship = FleetManager.ships[i] if i < FleetManager.ships.size() else null
		if ship and ship != active:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(180, 45)
			btn.text = "NAV %d" % (i + 1)
			btn.pressed.connect(_on_follow_selected.bind(ship))
			grid.add_child(btn)

func _on_follow_selected(target: Ship):
	var active = FleetManager.get_active_ship()
	if active and target and FleetManager.can_follow(active, target):
		active.follow_target = target
		active.is_auto_cruising = false
	_follow_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_fleet_updated():
	for i in range(5):
		var ship = FleetManager.ships[i] if i < FleetManager.ships.size() else null
		var lbl = fleet_labels[i]
		if ship: 
			match ship.ship_type:
				Ship.ShipClass.SLOOP: lbl.text = "Chaloupe"
				Ship.ShipClass.BRIGANTINE: lbl.text = "Brigantin"
				Ship.ShipClass.GALLEON: lbl.text = "Galion"
		else: lbl.text = "---"
	_update_fleet_active_visuals()

func _update_fleet_active_visuals():
	for i in range(5):
		var panel = fleet_slots[i]
		var sb = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if i == FleetManager.active_index:
			sb.border_color = Color(1, 0.8, 0, 1)
			sb.shadow_size = 6
		else:
			sb.border_color = Color(1, 1, 1, 0.1)
			sb.shadow_size = 0

func _input(event):
	if GameManager.state != GameManager.GameState.PLAYING: return
	
	if event.is_action_pressed("ui_cancel"): # ECHAP
		if _follow_menu and _follow_menu.visible:
			_follow_menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _defense_menu and _defense_menu.visible:
			_defense_menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R: # Croisière
			var active = FleetManager.get_active_ship()
			if active: active.is_auto_cruising = !active.is_auto_cruising
			
		if event.keycode == KEY_F: # Menu F
			if _follow_menu and _follow_menu.visible:
				_follow_menu.hide()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				show_follow_menu()
				
		if event.keycode == KEY_C: # Menu C
			if _defense_menu and _defense_menu.visible:
				_defense_menu.hide()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				show_defense_menu()

func _on_active_ship_changed(index: int):
	player_ship = FleetManager.get_active_ship()
	_update_fleet_active_visuals()

func _on_settings_pressed():
	var settings = get_tree().get_first_node_in_group("settings_menu")
	if settings and settings.has_method("_toggle_menu"):
		settings._toggle_menu()

var _hud_tick: int = 0

func _process(delta):
	_hud_tick += 1
	
	# RECHERCHE OPTIMISÉE (Toutes les 4 frames)
	if _hud_tick % 4 == 0:
		if not is_instance_valid(player_ship):
			player_ship = FleetManager.get_active_ship()
			
	if not is_instance_valid(player_ship): return

	# STATS ÉCO (Toutes les 2 frames)
	if _hud_tick % 2 == 0:
		if hp_bar: hp_bar.value = player_ship.hp
		if label_gold: label_gold.text = "OR: %d" % FleetManager.gold
		if label_ammo: label_ammo.text = "BOULETS: %d" % player_ship.ammo
		if label_wood: label_wood.text = "BOIS: %d" % player_ship.wood
		if label_food: label_food.text = "NOURRITURE: %d" % player_ship.food
		if label_water: label_water.text = "EAU: %d" % player_ship.water
		if label_fish: label_fish.text = "POISSONS: %d" % player_ship.fish
		
		if label_fps and label_fps.visible:
			label_fps.text = "FPS: %d" % Engine.get_frames_per_second()
		if label_hp: label_hp.text = "PV: %d/%d" % [player_ship.hp, player_ship.max_hp]
		
		# Update Status
		if status_label:
			var status_text = "MANUEL"
			if player_ship.is_sinking:
				status_text = "NAUFRAGE..."
			elif player_ship.follow_target and is_instance_valid(player_ship.follow_target):
				status_text = "SUIVI (Bateau %d)" % (FleetManager.ships.find(player_ship.follow_target) + 1)
			elif player_ship.is_auto_cruising:
				status_text = "CROISIÈRE"
			elif player_ship.is_defending:
				status_text = "DÉFENSE"
			status_label.text = "ORDRE: " + status_text + " | VITESSE: %d kt" % (abs(player_ship.ship_speed) * 0.5)
		
		# Update Kraken XP (Global)
		if kraken_xp_bar:
			kraken_xp_bar.max_value = GameConfig.get_kraken_xp_for_level(GameConfig.kraken_level)
			kraken_xp_bar.value = GameConfig.kraken_xp
		if label_kraken_lvl:
			label_kraken_lvl.text = "LVL %d" % GameConfig.kraken_level
		
		# Update cooldowns et icônes (Uniquement 1-5)
		for i in range(weapon_slot_panels.size()):
			var weapon = player_ship.weapon_slots[i] if i < player_ship.weapon_slots.size() else null
			var icon_rect = weapon_slot_icons[i]
			var cooldown_rect = weapon_slot_cooldowns[i]
			
			if weapon and weapon.icon:
				icon_rect.texture = weapon.icon
				icon_rect.modulate = Color.WHITE
			else:
				icon_rect.texture = null
				icon_rect.modulate = Color(1, 1, 1, 0.2)
				
			if weapon and player_ship.weapon_cooldowns[i] > 0:
				cooldown_rect.visible = true
				cooldown_rect.value = (player_ship.weapon_cooldowns[i] / weapon.cooldown) * 100.0
			else:
				cooldown_rect.visible = false
			
			# Visuel de sélection (bordure jaune pour l'arme active)
			var sb = weapon_slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
			if i == player_ship.active_weapon_index:
				sb.border_color = Color.YELLOW
				sb.set_border_width_all(3)
			else:
				sb.border_color = Color(1, 1, 1, 0.2)
				sb.set_border_width_all(1)

	# VENT (Optionnel: chaque frame pour l'aiguille, ou 2 frames)
	if _hud_tick % 2 != 0:
		var wv = player_ship.current_wind_vec_phys
		arrow_pivot.rotation = Vector2(wv.x, wv.z).angle() + (PI / 2.0)
		wind_speed_label.text = "%.0f km/h" % (wv.length() * 25.0)

	# ENNEMIS (Toutes les 5 frames - Gros gain FPS)
	if _hud_tick % 5 == 0:
		_update_enemy_bars()

func _update_enemy_bars():
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	# NETTOYAGE DES BARS MORTES (Très important pour le lag !)
	var to_remove = []
	for e in enemy_hp_bars.keys():
		if not is_instance_valid(e) or e.hp <= 0:
			if is_instance_valid(enemy_hp_bars[e]):
				enemy_hp_bars[e].queue_free()
			to_remove.append(e)
	for e in to_remove:
		enemy_hp_bars.erase(e)
	
	# MISE À JOUR DES BARS ACTUIVES
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Ship and enemy.hp > 0 and not enemy.is_player:
			if not enemy_hp_bars.has(enemy):
				var bar = ProgressBar.new()
				bar.custom_minimum_size = Vector2(60, 6)
				bar.show_percentage = false
				# On applique un style léger
				var sb = StyleBoxFlat.new()
				sb.bg_color = Color.RED
				bar.add_theme_stylebox_override("fill", sb)
				add_child(bar)
				enemy_hp_bars[enemy] = bar
				
			var bar = enemy_hp_bars[enemy]
			bar.max_value = enemy.max_hp
			bar.value = enemy.hp
			
			var pos_2d = camera.unproject_position(enemy.global_position + Vector3(0, 30, 0))
			bar.position = pos_2d - (bar.size / 2.0)
			bar.visible = not camera.is_position_behind(enemy.global_position)

func _scale_fonts(node: Node, size: int):
	if node is Label or node is Button: node.add_theme_font_size_override("font_size", size)
	for child in node.get_children(): _scale_fonts(child, size)
