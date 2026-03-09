class_name HUD
extends CanvasLayer

@onready var hp_bar = %ProgressBar
@onready var label_hp = %LabelHP
@onready var label_ammo = $MarginContainer/TopLeft/LabelAmmo
@onready var wind_speed_label = $WindBox/WindSpeedLabel
@onready var arrow_pivot = $WindBox/ArrowPivot
@onready var settings_btn = $MarginContainer/BottomRight/SettingsBtn
@onready var label_gold = $MarginContainer/TopLeft/LabelGold
@onready var label_wood = $MarginContainer/TopLeft/LabelWood
@onready var label_food = $MarginContainer/TopLeft/LabelFood
@onready var label_water = $MarginContainer/TopLeft/LabelWater
@onready var weapon_slots_container = $WeaponSlots
@onready var kraken_xp_bar = %KrakenXPBar
@onready var label_kraken_lvl = %LabelKrakenLvl

var weapon_slot_panels: Array[PanelContainer] = []
var weapon_slot_icons: Array[TextureRect] = []
var weapon_slot_cooldowns: Array[TextureProgressBar] = []
var player_ship: Ship
var enemy_hp_bars: Dictionary = {}

func _ready():
	add_to_group("hud")
	_scale_fonts(self, 24)
	player_ship = _find_player_ship(get_tree().get_root())
	
	_setup_weapon_ui()
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)

func _setup_weapon_ui():
	# On récupère les 5 slots créés dans l'éditeur
	weapon_slot_panels = [
		%Slot1, %Slot2, %Slot3, %Slot4, %Slot5
	]
	
	for panel in weapon_slot_panels:
		if not panel: continue
		
		# Ajout d'un TextureRect pour l'icône de l'arme
		var tex_rect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(50, 50)
		panel.add_child(tex_rect)
		weapon_slot_icons.append(tex_rect)
		
		# Overlay de Cooldown (Horloge blanche)
		var progress = TextureProgressBar.new()
		progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		progress.set_anchors_preset(Control.PRESET_FULL_RECT) # Utilise l'entier du slot
		progress.texture_progress = load("res://assets/ui/white_rect.png")
		progress.step = 0.01
		progress.value = 0
		progress.modulate = Color(1, 1, 1, 0.4) # Blanc transparent
		progress.nine_patch_stretch = true # Pour bien remplir le carré
		panel.add_child(progress)
		weapon_slot_cooldowns.append(progress)
		
		# Style Transparent avec bordure
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.2)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6
		
		sb.shadow_color = Color(1, 0.8, 0, 0)
		sb.shadow_size = 0
		
		panel.add_theme_stylebox_override("panel", sb)
		

func _on_settings_pressed():
	var settings = get_tree().get_first_node_in_group("settings_menu")
	if settings and settings.has_method("_toggle_menu"):
		settings._toggle_menu()

func _apply_font_recursive(node: Node, font: Font):
	if node is Label:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)

func _process(delta):
	# If we haven't found the player yet, keep looking occasionally
	if not is_instance_valid(player_ship):
		player_ship = _find_player_ship(get_tree().get_root())
		if not is_instance_valid(player_ship):
			return
			
	# Update UI elements
	if is_instance_valid(player_ship):
		if is_instance_valid(hp_bar):
			hp_bar.max_value = player_ship.max_hp
			hp_bar.value = player_ship.hp
		
		if is_instance_valid(label_hp):
			label_hp.text = "VIE: %d / %d" % [player_ship.hp, player_ship.max_hp]
			
		if is_instance_valid(label_ammo):
			label_ammo.text = "BOULETS: %d / %d" % [player_ship.ammo, player_ship.max_ammo]
			
		if is_instance_valid(label_gold):
			label_gold.text = "OR: %d" % player_ship.gold
			
		if is_instance_valid(label_wood):
			label_wood.text = "BOIS: %d" % player_ship.wood
			
		if is_instance_valid(label_food):
			label_food.text = "VIVRES: %d" % player_ship.food
			
		if is_instance_valid(label_water):
			label_water.text = "EAU: %d" % player_ship.water
			
		# Mise à jour XP Kraken
		if is_instance_valid(kraken_xp_bar):
			kraken_xp_bar.max_value = GameConfig.get_kraken_xp_for_level(GameConfig.kraken_level)
			kraken_xp_bar.value = GameConfig.kraken_xp
		if is_instance_valid(label_kraken_lvl):
			label_kraken_lvl.text = "LVL %d" % GameConfig.kraken_level
			
		# Update weapons UI (Glow and Icons)
		for i in range(weapon_slot_panels.size()):
			var panel = weapon_slot_panels[i]
			if not is_instance_valid(panel): continue
			
			var weapon = player_ship.weapon_slots[i] if i < player_ship.weapon_slots.size() else null
			var icon_rect = weapon_slot_icons[i] if i < weapon_slot_icons.size() else null
			
			if icon_rect:
				if weapon and weapon.icon:
					icon_rect.texture = weapon.icon
					icon_rect.modulate = Color(1, 1, 1, 1)
				else:
					icon_rect.texture = null
					icon_rect.modulate = Color(1, 1, 1, 0.3) # S'il n'y a pas d'arme
			
			# Update Cooldown Display
			var cooldown_rect = weapon_slot_cooldowns[i] if i < weapon_slot_cooldowns.size() else null
			if cooldown_rect:
				if weapon and player_ship.weapon_cooldowns[i] > 0:
					cooldown_rect.visible = true
					# On affiche le reste du temps sous forme d'horloge
					cooldown_rect.value = (player_ship.weapon_cooldowns[i] / weapon.cooldown) * 100.0
				else:
					cooldown_rect.visible = false
			
			var sb = panel.get_theme_stylebox("panel") as StyleBoxFlat
			
			# Détection si l'action est bloquée (Canon/Grappin/Vent en plongée)
			# Le Kraken est utilisable même sous l'eau
			var is_blocked = player_ship.is_diving and weapon and (
				weapon.type == WeaponData.ActionType.CANNON or 
				weapon.type == WeaponData.ActionType.GRAPPLE or
				weapon.type == WeaponData.ActionType.WIND_CONTROL
			)
			
			if i == player_ship.active_weapon_index:
				# Bordure Dorée (Actif)
				if is_blocked:
					sb.border_color = Color(1, 0, 0, 1) # Rouge si bloqué
				else:
					sb.border_color = Color(1, 0.84, 0, 1) # Gold si utilisable
					
				sb.set_border_width_all(3)
				sb.shadow_color = Color(1, 0.8, 0, 0.4) if not is_blocked else Color(1, 0, 0, 0.4)
				sb.shadow_size = 12
				if icon_rect: icon_rect.modulate = Color(1, 1, 1, 1) if not is_blocked else Color(1, 0.4, 0.4, 1)
			else:
				# Normal / Inactif
				sb.border_color = Color(1, 1, 1, 0.2)
				sb.set_border_width_all(1)
				sb.shadow_size = 0
				if icon_rect and weapon: icon_rect.modulate = Color(0.7, 0.7, 0.7, 0.8)
	
	# Wind UI Update based on Player location
	var wind_dir = Vector2(1, 0)
	var wind_speed_val = 1.0
	
	if is_instance_valid(player_ship):
		# On lit le vent PHYSIQUE calculé par le vaisseau (prend en compte le boost progressif)
		var wv3 = player_ship.current_wind_vec_phys
		if wv3.length_squared() > 0.001:
			var wv2 = Vector2(wv3.x, wv3.z)
			wind_speed_val = wv2.length()
			wind_dir = wv2.normalized()
		else:
			var local_wind = GameConfig.get_wind_at(player_ship.global_position)
			wind_dir = local_wind["direction"]
			wind_speed_val = local_wind["speed"]
		
	# Align the UI arrow exactly with the 3D wind vector
	arrow_pivot.rotation = wind_dir.angle() + (PI / 2.0)
	
	wind_speed_label.text = "%.0f km/h" % (wind_speed_val * 25.0)
	
	_update_enemy_bars()
	

func _update_enemy_bars():
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# Clean up dead enemies
	var to_remove = []
	for ship in enemy_hp_bars.keys():
		if not is_instance_valid(ship) or ship.hp <= 0:
			if is_instance_valid(enemy_hp_bars[ship]):
				enemy_hp_bars[ship].queue_free()
			to_remove.append(ship)
	for ship in to_remove:
		enemy_hp_bars.erase(ship)
		
	# Update active enemies
	for enemy in enemies:
		if enemy is Ship and not enemy.is_player and enemy.hp > 0:
			if not enemy_hp_bars.has(enemy):
				# Create a new bar
				var bar = ProgressBar.new()
				bar.custom_minimum_size = Vector2(80, 10)
				bar.show_percentage = false
				
				# Style it simple red/green
				var sb_bg = StyleBoxFlat.new()
				sb_bg.bg_color = Color(0.8, 0.1, 0.1)
				var sb_fill = StyleBoxFlat.new()
				sb_fill.bg_color = Color(0.2, 0.8, 0.2)
				bar.add_theme_stylebox_override("background", sb_bg)
				bar.add_theme_stylebox_override("fill", sb_fill)
				
				add_child(bar)
				enemy_hp_bars[enemy] = bar
				
			var bar = enemy_hp_bars[enemy]
			bar.max_value = enemy.max_hp
			bar.value = enemy.hp
			
			# Project to 2D
			var pos_3d = enemy.global_position + Vector3(0, 40, 0) # Floating high above the model
			if camera.is_position_behind(pos_3d):
				bar.visible = false
			else:
				var pos_2d = camera.unproject_position(pos_3d)
				bar.position = pos_2d - (bar.size / 2.0)
				bar.visible = true

func _find_player_ship(node: Node) -> Ship:
	if node is Ship and node.is_player:
		return node as Ship
	for child in node.get_children():
		var result = _find_player_ship(child)
		if result: return result
	return null

func _scale_fonts(node: Node, font_size: int):
	if node is Label or node is Button:
		node.add_theme_font_size_override("font_size", font_size)
	for child in node.get_children():
		_scale_fonts(child, font_size)

# ─────────────────────────────────────────────
# ÉCRAN DE MORT
# ─────────────────────────────────────────────
func show_death_screen():
	# Éviter le double affichage
	if get_node_or_null("DeathScreen"): return

	# Overlay sombre semi-transparent
	var overlay = ColorRect.new()
	overlay.name = "DeathScreen"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0, 0, 0.82)
	add_child(overlay)

	# Conteneur centré
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(420, 280)
	vbox.position = Vector2(-210, -140)  # centrage manuel
	overlay.add_child(vbox)

	# Titre « NAUFRAGE »
	var title = Label.new()
	title.text = "☠  NAUFRAGE  ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.18, 0.18))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	# Espace
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Sous-titre
	var sub = Label.new()
	sub.text = "Votre navire a coulé..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6))
	vbox.add_child(sub)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer2)

	# Bouton REJOUER
	var btn = Button.new()
	btn.text = "⚓  REJOUER"
	btn.custom_minimum_size = Vector2(260, 60)
	btn.add_theme_font_size_override("font_size", 30)

	# Style du bouton
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.7, 0.1, 0.1)
	sb_normal.corner_radius_top_left = 10
	sb_normal.corner_radius_top_right = 10
	sb_normal.corner_radius_bottom_left = 10
	sb_normal.corner_radius_bottom_right = 10
	sb_normal.set_border_width_all(2)
	sb_normal.border_color = Color(1, 0.4, 0.4)

	var sb_hover = sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.9, 0.15, 0.15)
	sb_hover.shadow_color = Color(1, 0.2, 0.2, 0.5)
	sb_hover.shadow_size = 12

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_normal)
	btn.add_theme_color_override("font_color", Color.WHITE)

	vbox.add_child(btn)

	# Centrage du vbox à l'écran
	await get_tree().process_frame
	vbox.position = (get_viewport().get_visible_rect().size / 2.0) - (vbox.size / 2.0)

	# Action du bouton : recharge la scène
	btn.pressed.connect(func():
		get_tree().reload_current_scene()
	)
