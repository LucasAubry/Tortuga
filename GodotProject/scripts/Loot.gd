class_name Loot
extends Area3D

enum LootType { GOLD, WOOD, FOOD, WATER, AMMO }
var type: LootType = LootType.GOLD
var amount: int = 10

func _ready():
	body_entered.connect(_on_body_entered)
	_apply_color()

func setup(loot_type: int, loot_amount: int):
	type = loot_type as LootType
	amount = loot_amount
	_apply_color()

func _apply_color():
	var mesh_node = get_node_or_null("MeshInstance3D")
	if not mesh_node or not mesh_node.mesh: return
	
	var mat = StandardMaterial3D.new()
	match type:
		LootType.GOLD: mat.albedo_color = Color(1.0, 0.84, 0.0) # Yellow
		LootType.WOOD: mat.albedo_color = Color(0.55, 0.27, 0.07) # Brown
		LootType.FOOD: mat.albedo_color = Color(0.8, 0.2, 0.2) # Red
		LootType.WATER: mat.albedo_color = Color(0.2, 0.6, 1.0) # Blue
		LootType.AMMO: mat.albedo_color = Color(0.4, 0.4, 0.4) # Dark Gray
		
	mesh_node.mesh.surface_set_material(0, mat)

func _process(delta):
	# Bobbing and rotating
	position.y = 5.0 + sin(Time.get_ticks_msec() / 500.0) * 1.5
	rotate_y(delta)

func _on_body_entered(body: Node3D):
	if body is Ship and body.is_player:
		match type:
			LootType.GOLD: body.gold += amount
			LootType.WOOD: body.wood += amount
			LootType.FOOD: body.food += amount
			LootType.WATER: body.water += amount
			LootType.AMMO: 
				body.ammo += amount
				if body.ammo > body.max_ammo: body.ammo = body.max_ammo
		
		# Play a pickup sound here ideally
		print("Picked up loot: ", type, " x", amount)
		queue_free()
