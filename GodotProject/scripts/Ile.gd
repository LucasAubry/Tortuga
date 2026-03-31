class_name Ile
extends Node3D

enum IleType { CITY, MERCHANT, SHIPWRIGHT, FISHERMAN, KRAKEN_FARMER, HEADQUARTERS, SHIP_MERCHANT }
@export var ile_type: IleType = IleType.CITY
@export_enum("PLAYER", "NAVY", "PIRATE", "MERCHANT") var faction: int = 0 # 0=PLAYER, 1=NAVY, 2=PIRATE, 3=MERCHANT

@onready var port_area = get_node_or_null("PortArea")

var _lbl: Label3D = null
var _indicator: MeshInstance3D = null

func _ready():
	_lbl = find_child("Label3D", true, false)
	_indicator = find_child("FactionIndicator", true, false)
	if not _indicator:
		_indicator = find_child("MeshInstance3D", true, false)
	
	_update_visuals()
	
	if port_area:
		port_area.body_entered.connect(_on_port_area_body_entered)
		port_area.body_exited.connect(_on_port_area_body_exited)

func _update_visuals():
	if _lbl:
		var faction_name = ""
		match faction:
			Ship.Faction.NAVY: faction_name = " [MARINE]"
			Ship.Faction.PIRATE: faction_name = " [PIRATE]"
			
		var type_name = ""
		match ile_type:
			IleType.CITY: type_name = "VILLE"
			IleType.MERCHANT: type_name = "MARCHAND"
			IleType.SHIPWRIGHT: type_name = "CHARPENTIER"
			IleType.FISHERMAN: type_name = "PÊCHEUR"
			IleType.KRAKEN_FARMER: type_name = "ÉLEVEUR DE KRAKEN"
			IleType.HEADQUARTERS: type_name = "QUARTIER GÉNÉRAL"
			IleType.SHIP_MERCHANT: type_name = "VENDEUR DE NAVIRES"
		
		_lbl.text = "[ %s ]%s" % [type_name, faction_name]

	if _indicator:
		var mat = StandardMaterial3D.new()
		match faction:
			Ship.Faction.PLAYER: mat.albedo_color = Color(0.1, 0.7, 0.1) # Vert
			Ship.Faction.NAVY: mat.albedo_color = Color(0.1, 0.2, 0.9) # Bleu
			Ship.Faction.PIRATE: mat.albedo_color = Color(0.9, 0.1, 0.1) # Rouge
			_: mat.albedo_color = Color(0.5, 0.5, 0.5)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_indicator.set_surface_override_material(0, mat)

func _on_port_area_body_entered(body: Node3D):
	if body is Ship and body.is_player:
		body.is_in_port_zone = true
		GameManager.parked_island = self
		
		if faction != Ship.Faction.PLAYER and faction != Ship.Faction.MERCHANT and faction != body.faction:
			get_tree().call_group("hud", "show_interaction_prompt", "[X] Territoire Ennemi — Interdit")
			return

		var txt = "[G] Accoster"
		get_tree().call_group("hud", "show_interaction_prompt", txt)

func _on_port_area_body_exited(body: Node3D):
	if body is Ship and body.is_player:
		body.is_in_port_zone = false
		if GameManager.parked_island == self:
			GameManager.parked_island = null
		get_tree().call_group("hud", "hide_interaction_prompt")

func _process(_delta):
	if GameManager.parked_island == self:
		var is_menu_open = GameManager.state != GameManager.GameState.PLAYING
		
		if is_menu_open:
			get_tree().call_group("hud", "hide_interaction_prompt")
		elif Input.is_action_just_pressed("interact"):
			# On vérifie qu'on a bien un bateau à nous dans la zone
			if port_area:
				for body in port_area.get_overlapping_bodies():
					if body is Ship and body.is_player:
						interact()
						break

func interact():
	var world_node = get_tree().current_scene
	
	match ile_type:
		IleType.SHIPWRIGHT:
			GameManager.state = GameManager.GameState.SHIPWRIGHT_MENU
			var menu = get_tree().get_first_node_in_group("shipwright_menu")
			if not menu:
				var scene = load("res://scenes/menu/ShipwrightMenu.tscn")
				if scene:
					menu = scene.instantiate()
					world_node.add_child(menu)
			if menu and menu.has_method("show_menu"):
				menu.show_menu()
				
		IleType.KRAKEN_FARMER:
			GameManager.state = GameManager.GameState.KRAKEN_MENU
			var menu = get_tree().get_first_node_in_group("kraken_menu")
			if not menu:
				var scene = load("res://scenes/menu/KrakenMenu.tscn")
				if scene:
					menu = scene.instantiate()
					world_node.add_child(menu)
			if menu and menu.has_method("show_menu"):
				menu.show_menu()
				
		IleType.HEADQUARTERS:
			GameManager.state = GameManager.GameState.HQ_MENU
			var menu = get_tree().get_first_node_in_group("hq_menu")
			if not menu:
				var scene = load("res://scenes/menu/HQMenu.tscn")
				if scene:
					menu = scene.instantiate()
					world_node.add_child(menu)
			if menu and menu.has_method("show_menu"):
				menu.show_menu()

		IleType.SHIP_MERCHANT:
			GameManager.state = GameManager.GameState.SHIP_MERCHANT_MENU
			var menu = get_tree().get_first_node_in_group("ship_merchant_menu")
			if not menu:
				var scene = load("res://scenes/menu/ShipMerchantMenu.tscn")
				if scene:
					menu = scene.instantiate()
					world_node.add_child(menu)
			if menu and menu.has_method("show_menu"):
				menu.show_menu()

		IleType.FISHERMAN, IleType.MERCHANT, IleType.CITY:
			GameManager.state = GameManager.GameState.TOWN_MENU
			var menu = get_tree().get_first_node_in_group("quest_menu")
			if not menu:
				var scene = load("res://scenes/menu/QuestMenu.tscn")
				if scene:
					menu = scene.instantiate()
					world_node.add_child(menu)
			if menu and menu.has_method("show_menu"):
				menu.show_menu()
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _find_player() -> Ship:
	return get_tree().get_first_node_in_group("player") as Ship
