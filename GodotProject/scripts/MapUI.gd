class_name MapUI
extends CanvasLayer

@onready var map_container = $ColorRect/MarginContainer/VBoxContainer/MapContainer
@onready var player_marker = $ColorRect/MarginContainer/VBoxContainer/MapContainer/PlayerMarker
@onready var label_coords = $ColorRect/MarginContainer/VBoxContainer/LabelCoords

var map_scale: float = 0.05
var map_offset: Vector2 = Vector2.ZERO
var island_markers: Array[ColorRect] = []

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
		map_container.draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.2), 2.0)
	for j in range(1, rows.size()):
		var y = j * row_step
		map_container.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.2), 2.0)
		
	# Draw labels
	for i in range(cols.size()):
		for j in range(rows.size()):
			var center = Vector2(i * col_step + col_step/2.0, j * row_step + row_step/2.0)
			# Draw letter number (A1, B2)
			var text = cols[i] + rows[j]
			map_container.draw_string(ttf, center - Vector2(10, -5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1,1,1,0.15))

func _process(delta):
	if visible:
		_update_map()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_M:
			if visible:
				hide_map()
			else:
				show_map()

func show_map():
	visible = true
	_populate_islands()
	
func hide_map():
	visible = false
	for marker in island_markers:
		marker.queue_free()
	island_markers.clear()

func _populate_islands():
	# Find all islands in the tree
	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty(): # Fallback if groups aren't setup
		_find_islands_recursive(get_tree().get_root())

func _find_islands_recursive(node: Node):
	if node is Island:
		_create_island_marker(node)
	for child in node.get_children():
		_find_islands_recursive(child)

func _create_island_marker(island: Island):
	var marker = ColorRect.new()
	marker.color = Color(0.8, 0.7, 0.5, 1.0)
	
	# Size based on Island logic
	var size = 20.0
	marker.custom_minimum_size = Vector2(size, size)
	marker.size = Vector2(size, size)
	
	map_container.add_child(marker)
	island_markers.append(marker)
	
	# Store the island reference as meta data for positioning
	marker.set_meta("island", island)

func _update_map():
	# Calculate offset based on UI container size so (0,0) is center
	map_offset = map_container.size / 2.0
	
	# Update Island positions
	for marker in island_markers:
		if is_instance_valid(marker) and marker.has_meta("island"):
			var island = marker.get_meta("island") as Island
			if is_instance_valid(island):
				var pos = Vector2(island.global_position.x, island.global_position.z)
				marker.position = map_offset + (pos * map_scale) - (marker.size / 2.0)
				
	# Update Player position
	var player = _find_player()
	if player:
		var pos = Vector2(player.global_position.x, player.global_position.z)
		player_marker.position = map_offset + (pos * map_scale) - (player_marker.size / 2.0)
		# No longer outputting string coords per task list

func _find_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player:
		return node as Ship
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result: return result
	return null
