class_name Ile
extends StaticBody3D

enum IleType { CITY, MERCHANT, SHIPWRIGHT, FISHERMAN }
@export var ile_type: IleType = IleType.CITY

@export var inner_radius: float = 50.0
@export var is_giant: bool = false
@export var is_merchant: bool = false
@export var is_shipwright: bool = false
@export var is_fisherman: bool = false
@export var is_capital_platform: bool = false
@export var is_solid_capital_island: bool = false

# Enable picking for clicks
func _ready():
	# Disable picking for the huge legacy Godot island cylinders! 
	# Only the modular interaction box will receive clicks now.
	input_ray_pickable = false
	# (Defunct large cylinders removed)
	# Build a floating interaction zone marker (a small square with text above)
	# This anticipates using the script generically over imported Blender environments!
	var marker_base = Node3D.new()
	
	# 1. The Small Square (Visual Indicator)
	var square = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(10.0, 10.0, 10.0)
	var box_mat = StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.4, 0.25, 0.1) # Brown interaction cube
	box.material = box_mat
	square.mesh = box
	marker_base.add_child(square)
	
	# Add an isolated StaticBody so ONLY the 10x10 cube is clickable!
	var click_body = StaticBody3D.new()
	click_body.input_ray_pickable = true
	var click_col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = box.size
	click_col.shape = box_shape
	click_body.add_child(click_col)
	click_body.input_event.connect(_on_marker_clicked)
	
	square.add_child(click_body)
	
	# 2. The Small Text Above It
	var icon = Label3D.new()
	if ile_type == IleType.CITY:
		icon.text = "[ VILLE ]"
	elif ile_type == IleType.MERCHANT:
		icon.text = "[ MARCHAND ]"
	elif ile_type == IleType.SHIPWRIGHT:
		icon.text = "[ CHANTIER ]"
	elif ile_type == IleType.FISHERMAN:
		icon.text = "[ PECHEUR ]"
		
	icon.pixel_size = 0.5
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.outline_render_priority = 1
	icon.outline_size = 3
	icon.font_size = 24
	icon.position = Vector3(0, 10.0, 0) # Just above the square
	marker_base.add_child(icon)
	
	# Place the marker group floating globally
	marker_base.position = Vector3(0, 30.0, 0)
	
	# Continuous slow rotation via a child script component or we can just animate it in process.
	# But we'll leave it static for now for max performance
	add_child(marker_base)
		
	var port_area = get_node_or_null("PortArea")
	if port_area:
		port_area.body_entered.connect(_on_port_area_body_entered)
		port_area.body_exited.connect(_on_port_area_body_exited)

func _on_port_area_body_entered(body: Node3D):
	if body is Ship and body.is_player:
		GameManager.parked_island = self
		if ile_type == IleType.MERCHANT:
			print("Player entered MERCHANT port at ", global_position, " - Press 'E' to trade!")
		else:
			print("Player entered port at ", global_position)

func _on_port_area_body_exited(body: Node3D):
	if body is Ship and body.is_player:
		if GameManager.parked_island == self:
			GameManager.parked_island = null
		print("Player left port.")

func _on_marker_clicked(camera, event, position, normal, shape_idx):
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
				if ile_type == IleType.MERCHANT or ile_type == IleType.FISHERMAN or ile_type == IleType.CITY:
					GameManager.state = GameManager.GameState.TOWN_MENU
					var qmenu = world_node.get_node_or_null("QuestMenu")
					if qmenu and qmenu.has_method("show_menu"):
						qmenu.show_menu()
				elif ile_type == IleType.SHIPWRIGHT:
					GameManager.state = GameManager.GameState.SHIPWRIGHT_MENU
					var tmenu = world_node.get_node_or_null("TabMenu")
					if tmenu and tmenu.has_method("show_menu"):
						tmenu.show_menu()
					
				print("Opened interface for island type: ", ile_type)
			else:
				print("Too far to interact with island!")
