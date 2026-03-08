extends Control

@onready var island_container = $ClippingContainer/IslandContainer
@onready var player_marker = $ClippingContainer/PlayerIcon

var minimap_scale: float = 0.5 # Zoom level
var island_markers: Dictionary = {}
var enemy_markers: Dictionary = {}

func _ready():
	# Initial scan for islands
	_populate_islands()


func _process(_delta):
	var player = _find_player()
	if not player:
		return
		
	var player_pos = Vector2(player.global_position.x, player.global_position.z)
	
	# Update island markers relative to player
	for node in island_markers.keys():
		_update_marker_pos(node, island_markers[node], player_pos)
	
	# Update/Create enemy markers
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# Skip enemies that are diving too deep (stealth)
		if enemy.get("current_dive_depth") != null and enemy.current_dive_depth < -10.0:
			if enemy_markers.has(enemy):
				enemy_markers[enemy].visible = false
			continue
			
		if not enemy_markers.has(enemy):
			_create_enemy_marker(enemy)
		
		_update_marker_pos(enemy, enemy_markers[enemy], player_pos)
		
	# Cleanup dead enemies
	for enemy in enemy_markers.keys():
		if not is_instance_valid(enemy):
			enemy_markers[enemy].queue_free()
			enemy_markers.erase(enemy)

	# Rotation of the player icon
	if player_marker:
		player_marker.rotation = -player.rotation.y + PI/2.0

func _update_marker_pos(node: Node3D, marker: Control, player_pos: Vector2):
	if is_instance_valid(node):
		var node_pos = Vector2(node.global_position.x, node.global_position.z)
		var relative_pos = (node_pos - player_pos) * minimap_scale
		marker.position = relative_pos - (marker.size / 2.0)
		
		# Circular clipping: hide if outside the 200px radius of the radar
		marker.visible = relative_pos.length() < 200.0
	else:
		# Cleanup processed in main loops
		pass

func _create_enemy_marker(enemy: Node3D):
	var marker = ColorRect.new()
	marker.custom_minimum_size = Vector2(12, 12)
	marker.size = Vector2(12, 12)
	marker.color = Color(1.0, 0.0, 0.0) # Ennemis en rouge
	island_container.add_child(marker)
	enemy_markers[enemy] = marker

func _populate_islands():
	_find_islands_recursive(get_tree().get_root())

func _find_islands_recursive(node: Node):
	var is_island = false
	if node is Ile:
		is_island = true
	elif node.scene_file_path != "" and node.scene_file_path.find("iles.tscn") != -1:
		is_island = true
	elif "IleMesh" in node.name:
		is_island = true
		
	if is_island:
		# Check for duplicates like in MapUI
		var duplicate = false
		for tracked_node in island_markers.keys():
			if is_instance_valid(tracked_node) and tracked_node.global_position.distance_to(node.global_position) < 30.0:
				duplicate = true
				break
		
		if not duplicate:
			_create_marker(node)
			
	for child in node.get_children():
		_find_islands_recursive(child)

func _create_marker(node: Node):
	var marker = ColorRect.new()
	marker.custom_minimum_size = Vector2(10, 10)
	marker.size = Vector2(10, 10)
	
	# Color based on island type if available
	if node is Ile:
		match node.ile_type:
			0: marker.color = Color(0.2, 0.8, 0.2) # City
			1: marker.color = Color(0.8, 0.8, 0.2) # Merchant
			2: marker.color = Color(0.2, 0.2, 0.8) # Shipwright
			3: marker.color = Color(0.8, 0.2, 0.2) # Fisherman
			_: marker.color = Color(0.8, 0.7, 0.5)
	else:
		marker.color = Color(0.5, 0.5, 0.5) # Generic mesh
		
	island_container.add_child(marker)
	island_markers[node] = marker

func _find_player() -> Node3D:
	# Try to find the ship marked as player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]
	
	# Fallback recursive search (similar to MapUI)
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Node3D:
	if node.has_method("is_player") and node.is_player:
		return node
	# Generic check for Ship
	if node.name.find("Ship") != -1 or node.name.find("ship") != -1:
		if "is_player" in node and node.is_player:
			return node
			
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res: return res
	return null
