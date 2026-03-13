class_name MapUI
extends CanvasLayer

@onready var map_container = $ColorRect/MarginContainer/VBoxContainer/MapContainer
@onready var player_marker = $ColorRect/MarginContainer/VBoxContainer/MapContainer/PlayerIcon
@onready var label_coords = $ColorRect/MarginContainer/VBoxContainer/LabelCoords

var map_scale: float = 0.05
var map_offset: Vector2 = Vector2.ZERO
var island_markers: Array[Control] = []
var enemy_markers: Dictionary = {}

func _ready():
	visible = false
	label_coords.visible = false
	add_to_group("map_ui")
	
	# Force map container to draw our grid via Control._draw()
	map_container.draw.connect(_on_map_draw)

func _on_map_draw():
	# Use standard map_scale and size to draw a generic grid
	var cols = ["A", "B", "C", "D", "E"]
	var rows = ["1", "2", "3", "4", "5"]
	
	var w = map_container.size.x
	var h = map_container.size.y
	
	var col_step = w / cols.size()
	var row_step = h / rows.size()
	
	var ttf = ThemeDB.fallback_font
	
	# Draw lines
	for i in range(1, cols.size()):
		var x = i * col_step
		map_container.draw_line(Vector2(x, 0), Vector2(x, h), Color(0, 0, 0, 0.15), 2.0)
	for j in range(1, rows.size()):
		var y = j * row_step
		map_container.draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.15), 2.0)
		
	# Draw labels
	for i in range(cols.size()):
		for j in range(rows.size()):
			var center = Vector2(i * col_step + col_step/2.0, j * row_step + row_step/2.0)
			# Draw letter number (A1, B2)
			var text = cols[i] + rows[j]
			map_container.draw_string(ttf, center - Vector2(10, -5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(0,0,0,0.1))

func _process(delta):
	if visible:
		_update_map()

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_M:
			if visible:
				hide_map()
			else:
				show_map()
	
	# ZOOM SUR LA MAP
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

	# 1. Le point coloré (plus petit)
	var dot = ColorRect.new()
	var size = 10.0
	dot.custom_minimum_size = Vector2(size, size)
	dot.size = Vector2(size, size)
	dot.position = Vector2(-size/2, -size/2)
	marker_container.add_child(dot)
	
	# 2. L'étiquette de texte
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-60, 8)
	label.custom_minimum_size = Vector2(120, 20)
	marker_container.add_child(label)
	
	# Configuration selon le type d'île
	if ile is Ile:
		match ile.ile_type:
			0: # CITY
				dot.color = Color(0.2, 0.8, 0.2)
				label.text = "VILLE"
			1: # MERCHANT
				dot.color = Color(1.0, 0.9, 0.2)
				label.text = "MARCHAND"
			2: # SHIPWRIGHT
				dot.color = Color(0.2, 0.4, 1.0)
				label.text = "CHANTIER"
			3: # FISHERMAN
				dot.color = Color(1.0, 0.2, 0.2)
				label.text = "PECHERIE"
			5: # HEADQUARTERS
				dot.color = Color(1.0, 0.6, 0.0) # Orange
				label.text = "QUARTIER GENERALE"
			_:
				dot.color = Color(0.8, 0.7, 0.5)
				label.text = "ILE"
	else:
		dot.color = Color(0.5, 0.5, 0.5)
		label.text = "ZONE"

func _update_map():
	# Calculate offset based on UI container size so (0,0) is center
	map_offset = map_container.size / 2.0
	
	# Update Island positions
	for marker in island_markers:
		if is_instance_valid(marker) and marker.has_meta("island"):
			var ile = marker.get_meta("island")
			if is_instance_valid(ile):
				var pos = Vector2(ile.global_position.x, ile.global_position.z)
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
		var pos = Vector2(enemy.global_position.x, enemy.global_position.z)
		marker.position = map_offset + (pos * map_scale) - (marker.size / 2.0)
		marker.visible = true
		
	# Cleanup dead enemies on map
	for enemy in enemy_markers.keys():
		if not is_instance_valid(enemy):
			enemy_markers[enemy].queue_free()
			enemy_markers.erase(enemy)

	# Update Player position
	var player = _find_player()
	if player:
		var pos = Vector2(player.global_position.x, player.global_position.z)
		var target_pos = map_offset + (pos * map_scale) - (player_marker.size / 2.0)
		player_marker.position = target_pos
		# Rotation of the player icon
		player_marker.rotation = -player.rotation.y + PI/2.0
		# No longer outputting string coords per task list

func _create_enemy_marker_map(enemy: Node3D):
	var marker = ColorRect.new()
	marker.custom_minimum_size = Vector2(8, 8)
	marker.size = Vector2(8, 8)
	marker.color = Color(1.0, 0.1, 0.1) # Rouge vif pour les ennemis
	map_container.add_child(marker)
	enemy_markers[enemy] = marker

func _find_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player:
		return node as Ship
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result: return result
	return null
