class_name MapUI
extends CanvasLayer

@onready var map_container = $ColorRect/MarginContainer/VBoxContainer/MapContainer
@onready var player_marker = $ColorRect/MarginContainer/VBoxContainer/MapContainer/PlayerIcon
@onready var label_coords = $ColorRect/MarginContainer/VBoxContainer/LabelCoords

var map_scale: float = 0.45
var map_offset: Vector2 = Vector2.ZERO
var island_markers: Array[Control] = []
var enemy_markers: Dictionary = {}
var fleet_markers: Array[Node2D] = []

func _ready():
	visible = false
	label_coords.visible = false
	if player_marker: player_marker.visible = false
	add_to_group("map_ui")
	
	# Force map container to draw our grid via Control._draw()
	map_container.draw.connect(_on_map_draw)

func _on_map_draw():
	# Draw World Boundary Zone
	var w = 3600.0 * map_scale 
	var h = 2400.0 * map_scale
	var rect_pos = map_offset - Vector2(w/2.0, h/2.0)
	
	# Neon blue map boundary
	map_container.draw_rect(Rect2(rect_pos, Vector2(w, h)), Color(0.2, 0.6, 1.0, 0.4), false, 4.0)
	# Sublte background for the playable zone
	map_container.draw_rect(Rect2(rect_pos, Vector2(w, h)), Color(0.2, 0.6, 1.0, 0.05), true)

func _process(delta):
	if visible:
		_update_map()

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_map") and not event.echo:
		if visible:
			hide_map()
		else:
			show_map()
		get_viewport().set_input_as_handled()
		return
	
	# INTERACTIONS SUR LA MAP
	if visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				map_scale = clamp(map_scale + 0.02, 0.01, 1.5)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				map_scale = clamp(map_scale - 0.02, 0.01, 1.5)
				get_viewport().set_input_as_handled()
		
		elif event.is_class("InputEventMagnificationGesture"):
			# Pinch Mac sur la map
			map_scale = clamp(map_scale * event.get("factor"), 0.01, 1.5)
			get_viewport().set_input_as_handled()


func show_map():
	visible = true
	_populate_islands()
	
func hide_map():
	visible = false
	for marker in island_markers:
		marker.queue_free()
	island_markers.clear()
	
	for enemy in enemy_markers:
		enemy_markers[enemy].queue_free()
	enemy_markers.clear()
	
	for marker in fleet_markers:
		marker.queue_free()
	fleet_markers.clear()

func _populate_islands():
	# Always do a recursive scan to ensure markers bind reliably to our generic Ile.gd definitions
	_find_islands_recursive(get_tree().get_root())

func _find_islands_recursive(node: Node, tracked: Array = []):
	var is_island = false
	if node is Ile:
		is_island = true
	elif node.scene_file_path != "" and node.scene_file_path.find("iles.tscn") != -1:
		is_island = true
	elif "IleMesh" in node.name:
		is_island = true
		
	if is_island:
		var duplicate = false
		for t in tracked:
			if is_instance_valid(t) and "global_position" in t and "global_position" in node:
				if node.global_position.distance_to(t.global_position) < 25.0:
					duplicate = true
					break
		if not duplicate:
			_create_ile_marker(node)
			tracked.append(node)
			
	for child in node.get_children():
		_find_islands_recursive(child, tracked)

func _create_ile_marker(ile: Node):
	var marker_container = Control.new()
	map_container.add_child(marker_container)
	island_markers.append(marker_container)
	marker_container.set_meta("island", ile)

	# 1. Le logo de l'île
	var icon = TextureRect.new()
	icon.texture = load("res://assets/hud/ille_map.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var size = 45.0 # Agrandissement de l'icône (Double de la taille précédente)
	icon.custom_minimum_size = Vector2(size, size)
	icon.size = Vector2(size, size)
	icon.position = Vector2(-size/2, -size/2)
	marker_container.add_child(icon)
	
	# 2. L'étiquette de texte
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13) # Un peu plus grand
	label.add_theme_color_override("font_outline_color", Color(0,0,0,1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-60, 25) # Positionné SOUS l'icône (qui fait 45px)
	label.custom_minimum_size = Vector2(120, 25)
	marker_container.add_child(label)

	# On essaye de récupérer un nom propre si le noeud est nommé spécifiquement
	var display_name = ile.name
	if display_name.contains("Zone") or display_name.contains("Ile"):
		display_name = "" # On ignore les noms de nodes génériques
	
	# Configuration selon le type d'île
	if ile is Ile:
		match ile.ile_type:
			0: # CITY
				icon.modulate = Color(0.2, 0.8, 0.2)
				label.text = display_name if display_name != "" else "VILLE"
			1: # MERCHANT
				icon.modulate = Color(1.0, 0.9, 0.2)
				label.text = display_name if display_name != "" else "MARCHAND"
			2: # SHIPWRIGHT
				icon.modulate = Color(0.2, 0.4, 1.0)
				label.text = display_name if display_name != "" else "CHANTIER"
			3: # FISHERMAN
				icon.modulate = Color(1.0, 0.2, 0.2)
				label.text = display_name if display_name != "" else "PECHERIE"
			4: # KRAKEN_FARMER
				icon.modulate = Color(0.8, 0.2, 1.0)
				label.text = display_name if display_name != "" else "KRAKEN"
			5: # HEADQUARTERS
				icon.modulate = Color(1.0, 1.0, 1.0)
				label.text = display_name if display_name != "" else "QG"
			6: # SHIP_MERCHANT
				icon.modulate = Color(0.2, 0.8, 1.0)
				label.text = display_name if display_name != "" else "NAVY"
			_:
				icon.modulate = Color(0.8, 0.7, 0.5)
				label.text = display_name if display_name != "" else "ILE"
	else:
		if is_instance_valid(icon):
			icon.modulate = Color(0.5, 0.5, 0.5)
		label.text = "ZONE"

func _update_map():
	# Calculate offset based on UI container size so (0,0) is center
	map_offset = map_container.size / 2.0
	
	# Update Island positions
	for marker in island_markers:
		if is_instance_valid(marker) and marker.has_meta("island"):
			var ile = marker.get_meta("island")
			if is_instance_valid(ile):
				# Retour en Horizontal (Z sur X)
				var pos = Vector2(ile.global_position.z, ile.global_position.x)
				marker.position = map_offset + (pos * map_scale)
				
	# Update Enemy positions
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# Stealth check for diving enemies
		if enemy.get("current_dive_depth") != null and enemy.current_dive_depth < -15.0:
			if enemy_markers.has(enemy):
				enemy_markers[enemy].visible = false
			continue
			
		if not enemy_markers.has(enemy):
			_create_enemy_marker_map(enemy)
		
		var marker = enemy_markers[enemy]
		var pos = Vector2(enemy.global_position.z, enemy.global_position.x)
		marker.position = map_offset + (pos * map_scale) - (marker.size / 2.0)
		marker.rotation = enemy.rotation.y
		marker.visible = true
		
	# Cleanup dead enemies on map
	for enemy in enemy_markers.keys():
		if not is_instance_valid(enemy):
			enemy_markers[enemy].queue_free()
			enemy_markers.erase(enemy)

	# Update Fleet positions
	_update_fleet_markers()

func _update_fleet_markers():
	var fleet = FleetManager.ships
	var active_idx = FleetManager.active_index
	
	# Match marker count to fleet size (excluding nulls)
	var active_ships = []
	for s in fleet:
		if s and is_instance_valid(s):
			active_ships.append(s)
			
	while fleet_markers.size() < active_ships.size():
		var m = _create_fleet_marker()
		fleet_markers.append(m)
	while fleet_markers.size() > active_ships.size():
		var m = fleet_markers.pop_back()
		m.queue_free()
		
	for i in range(active_ships.size()):
		var ship = active_ships[i]
		var marker = fleet_markers[i]
		var pos = Vector2(ship.global_position.z, ship.global_position.x)
		marker.position = map_offset + (pos * map_scale)
		marker.rotation = ship.rotation.y
		
		# Highlight active ship
		var is_active = (ship == FleetManager.get_active_ship())
		marker.self_modulate = Color(0, 1, 0) if is_active else Color(0.6, 0.8, 1.0)
		marker.scale = Vector2(0.12, 0.12) if is_active else Vector2(0.06, 0.06)

func _create_fleet_marker() -> Sprite2D:
	var sprite = Sprite2D.new()
	# Use the same texture as player_marker or a triangle
	sprite.texture = player_marker.texture
	sprite.scale = Vector2(0.1, 0.1)
	map_container.add_child(sprite)
	return sprite

func _create_enemy_marker_map(enemy: Node3D):
	var marker = ColorRect.new()
	marker.custom_minimum_size = Vector2(8, 8)
	marker.size = Vector2(8, 8)
	marker.color = Color(1.0, 0.1, 0.1) # Rouge vif pour les ennemis
	marker.pivot_offset = marker.size / 2.0 # Centrer la rotation
	map_container.add_child(marker)
	enemy_markers[enemy] = marker

func _find_player() -> Ship:
	# Now just return active ship from fleet manager
	return FleetManager.get_active_ship()

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player:
		return node as Ship
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result: return result
	return null
