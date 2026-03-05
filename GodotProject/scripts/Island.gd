class_name Island
extends StaticBody3D

enum IslandType { CITY, MERCHANT, SHIPWRIGHT, FISHERMAN }
@export var island_type: IslandType = IslandType.CITY

@export var inner_radius: float = 50.0
@export var is_giant: bool = false
@export var is_merchant: bool = false
@export var is_shipwright: bool = false
@export var is_fisherman: bool = false
@export var is_capital_platform: bool = false
@export var is_solid_capital_island: bool = false

# Enable picking for clicks
func _ready():
	input_ray_pickable = true
	
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh and mesh.mesh is CylinderMesh:
		var mat = StandardMaterial3D.new()
		if island_type == IslandType.CITY:
			mat.albedo_color = Color.GRAY
		elif island_type == IslandType.FISHERMAN:
			mat.albedo_color = Color.CYAN
		mesh.mesh.surface_set_material(0, mat)
		
	var port_area = get_node_or_null("PortArea")
	if port_area:
		port_area.body_entered.connect(_on_port_area_body_entered)
		port_area.body_exited.connect(_on_port_area_body_exited)

func _on_port_area_body_entered(body: Node3D):
	if body is Ship and body.is_player:
		GameManager.parked_island = self
		if island_type == IslandType.MERCHANT:
			print("Player entered MERCHANT port at ", global_position, " - Press 'E' to trade!")
		else:
			print("Player entered port at ", global_position)

func _on_port_area_body_exited(body: Node3D):
	if body is Ship and body.is_player:
		if GameManager.parked_island == self:
			GameManager.parked_island = null
		print("Player left port.")

func _input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var player = null
		var world = get_tree().current_scene
		if world:
			player = world.get_node_or_null("Ship")
			
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < 1500.0: # Close enough to interact
				GameManager.parked_island = self
				
				# Open corresponding interface based on island type
				var world_node = get_tree().current_scene
				if island_type == IslandType.MERCHANT or island_type == IslandType.FISHERMAN or island_type == IslandType.CITY:
					GameManager.state = GameManager.GameState.TOWN_MENU
					var qmenu = world_node.get_node_or_null("QuestMenu")
					if qmenu and qmenu.has_method("show_menu"):
						qmenu.show_menu()
				elif island_type == IslandType.SHIPWRIGHT:
					GameManager.state = GameManager.GameState.SHIPWRIGHT_MENU
					var tmenu = world_node.get_node_or_null("TabMenu")
					if tmenu and tmenu.has_method("show_menu"):
						tmenu.show_menu()
					
				print("Opened interface for island type: ", island_type)
			else:
				print("Too far to interact with island!")
