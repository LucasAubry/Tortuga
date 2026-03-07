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

var weapon_slot_panels: Array[PanelContainer] = []
var weapon_slot_icons: Array[TextureRect] = []
var weapon_slot_cooldowns: Array[TextureProgressBar] = []
var player_ship: Ship
var enemy_hp_bars: Dictionary = {}

func _ready():
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
			
			# Détectier si l'action est bloquée (Canon/Grappin en plongée)
			var is_blocked = player_ship.is_diving and weapon and (weapon.type == WeaponData.ActionType.CANNON or weapon.type == WeaponData.ActionType.GRAPPLE)
			
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
	var local_wind = {"direction": Vector2(1,0), "speed": 1.0}
	if is_instance_valid(player_ship):
		local_wind = GameConfig.get_wind_at(player_ship.global_position)
		
	var wind_dir = local_wind["direction"]
	var wind_speed_val = local_wind["speed"]
	
	# Align the UI arrow exactly with the 3D wind vector
	var wind_2d = Vector2(wind_dir.x, wind_dir.y)
	arrow_pivot.rotation = wind_2d.angle() + (PI / 2.0)
	
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
