class_name Ile
extends Node3D

enum IleType { CITY, MERCHANT, SHIPWRIGHT, FISHERMAN, KRAKEN_FARMER, HEADQUARTERS, SHIP_MERCHANT }
@export var ile_type: IleType = IleType.CITY

@export var inner_radius: float = 400.0
@export var is_giant: bool = false
@export var is_merchant: bool = false
@export var is_shipwright: bool = false
@export var is_fisherman: bool = false
@export var is_kraken_farmer: bool = false
@export var is_capital_platform: bool = false
@export var is_solid_capital_island: bool = false

@onready var port_area = get_node_or_null("PortArea")

# Enable picking for clicks
func _ready():
	# Disable picking if this is a physics object (legacy island compatibility)
	if "input_ray_pickable" in self:
		set("input_ray_pickable", false)
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
	# click_body.input_event.connect(_on_marker_clicked)
	
	square.add_child(click_body)
	
	# 2. The Small Text Above It
	var icon = Label3D.new()
	if ile_type == IleType.CITY:
		icon.text = "[ VILLE ]"
	elif ile_type == IleType.MERCHANT:
		icon.text = "[ MARCHAND ]"
	elif ile_type == IleType.SHIPWRIGHT:
		icon.text = "[ CHARPENTIER ]"
	elif ile_type == IleType.FISHERMAN:
		icon.text = "[ PÊCHEUR ]"
	elif ile_type == IleType.KRAKEN_FARMER:
		icon.text = "[ ÉLEVEUR DE KRAKEN ]"
	elif ile_type == IleType.HEADQUARTERS:
		icon.text = "[ QUARTIER GÉNÉRAL ]"
	elif ile_type == IleType.SHIP_MERCHANT:
		icon.text = "[ VENDEUR DE NAVIRES ]"
		icon.modulate = Color(0.2, 0.8, 1.0)
		
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
		
	# Ajuster la taille de la zone de port par rapport à l'island
	if port_area:
		# Suppression de l'écrasement du rayon par le code.
		# L'utilisateur gère maintenant la taille directement dans la scène Godot.
		
		port_area.body_entered.connect(_on_port_area_body_entered)
		port_area.body_exited.connect(_on_port_area_body_exited)

func _on_port_area_body_entered(body: Node3D):
	if body is Ship and body.is_player:
		body.is_in_port_zone = true
		print("DEBUG: Player entered zone of ", name, " (Type: ", ile_type, ")")
		# Toujours permettre de se garer, même au QG
		GameManager.parked_island = self
		
		# Build specific text
		var txt = "[G] Accoster"
		if ile_type == IleType.KRAKEN_FARMER:
			txt = "[G] Interagir avec le Kraken"
		elif ile_type == IleType.MERCHANT:
			txt = "[G] Marchand"
		elif ile_type == IleType.SHIPWRIGHT:
			txt = "[G] Charpentier — Améliorer le Navire"
		elif ile_type == IleType.FISHERMAN:
			txt = "[G] Pêcheur — Vendre tes poissons"
		
		get_tree().call_group("hud", "show_interaction_prompt", txt)

func _on_port_area_body_exited(body: Node3D):
	if body is Ship and body.is_player:
		body.is_in_port_zone = false
		if GameManager.parked_island == self:
			GameManager.parked_island = null
		get_tree().call_group("hud", "hide_interaction_prompt")

func _process(_delta):
	# Si on est dans la zone et que l'on n'est pas déjà dans un menu, on s'assure que le HUD l'affiche
	if GameManager.parked_island == self:
		# On définit précisément quels états sont des menus
		var is_menu_open = GameManager.state in [
			GameManager.GameState.TOWN_MENU,
			GameManager.GameState.SHIPWRIGHT_MENU,
			GameManager.GameState.KRAKEN_MENU,
			GameManager.GameState.HQ_MENU,
			GameManager.GameState.SHIP_MERCHANT_MENU
		]
		
		if is_menu_open:
			get_tree().call_group("hud", "hide_interaction_prompt")
		else:
			# On redonne le texte à afficher
			var txt = "[G] Accoster"
			if ile_type == IleType.KRAKEN_FARMER:
				txt = "[G] Interagir avec le Kraken"
			elif ile_type == IleType.MERCHANT:
				txt = "[G] Marchand"
			
			get_tree().call_group("hud", "show_interaction_prompt", txt)
			
		# Interaction via touche 'G'
		if Input.is_action_just_pressed("interact") and not is_menu_open:
			# Double vérification que le joueur est bien dans la zone
			var p = _find_player()
			if p and p.is_in_port_zone:
				interact()

func interact():
	var world_node = get_tree().current_scene
	
	# Le HUD sera masqué via _process dès que l'état changera
	
	if ile_type == IleType.MERCHANT or ile_type == IleType.FISHERMAN or ile_type == IleType.CITY:
		GameManager.state = GameManager.GameState.TOWN_MENU
		var qmenu = world_node.get_node_or_null("QuestMenu")
		if qmenu and qmenu.has_method("show_menu"):
			qmenu.show_menu()
	elif ile_type == IleType.SHIPWRIGHT:
		GameManager.state = GameManager.GameState.SHIPWRIGHT_MENU
		# Chercher ou créer le ShipwrightMenu
		var swmenu = get_tree().get_first_node_in_group("shipwright_menu")
		if not swmenu:
			swmenu = ShipwrightMenu.new()
			world_node.add_child(swmenu)
		if swmenu and swmenu.has_method("show_menu"):
			swmenu.show_menu()
	elif ile_type == IleType.KRAKEN_FARMER:
		GameManager.state = GameManager.GameState.KRAKEN_MENU
		var kmenu = world_node.get_node_or_null("KrakenMenu")
		if kmenu and kmenu.has_method("show_menu"):
			kmenu.show_menu()
	elif ile_type == IleType.HEADQUARTERS:
		GameManager.state = GameManager.GameState.HQ_MENU
		var hqmenu = world_node.get_node_or_null("HQMenu")
		if hqmenu and hqmenu.has_method("show_menu"):
			hqmenu.show_menu()
	elif ile_type == IleType.SHIP_MERCHANT:
		GameManager.state = GameManager.GameState.SHIP_MERCHANT_MENU
		var smmenu = world_node.get_node_or_null("ShipMerchantMenu")
		if smmenu and smmenu.has_method("show_menu"):
			smmenu.show_menu()

	# Libère la souris pour cliquer dans les menus
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _find_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player: return node
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res: return res
	return null
