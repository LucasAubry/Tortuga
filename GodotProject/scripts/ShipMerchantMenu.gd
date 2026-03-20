extends CanvasLayer

@onready var ship_list = $BurntMap/MarginContainer/VBox/ShipList
@onready var gold_label = $BurntMap/MarginContainer/VBox/GoldLabel

func _ready():
	visible = false
	add_to_group("ship_merchant_menu")

func show_menu():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_list()

func _refresh_list():
	var active_ship = FleetManager.get_active_ship()
	if active_ship:
		gold_label.text = "OR ACTUEL : " + str(active_ship.gold)
	
	# Clear previous list
	for child in ship_list.get_children():
		child.queue_free()
	
	for i in range(GameConfig.merchant_fleet_ships.size()):
		var ship_data = GameConfig.merchant_fleet_ships[i]
		var hbox = HBoxContainer.new()
		
		var icon = Label.new()
		icon.text = ship_data.icon_text
		icon.add_theme_font_size_override("font_size", 30)
		
		var details = VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_lbl = Label.new()
		name_lbl.text = ship_data.name + " (" + str(ship_data.price) + " Or)"
		name_lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
		
		var stats_lbl = Label.new()
		stats_lbl.text = "💪 PV: %d  💨 Vit: %d  ⚔️ Dm: %d" % [ship_data.hp, ship_data.speed, ship_data.damage]
		stats_lbl.add_theme_font_size_override("font_size", 16)
		stats_lbl.add_theme_color_override("font_color", Color(0.4, 0.2, 0.1))
		
		details.add_child(name_lbl)
		details.add_child(stats_lbl)
		
		var btn = Button.new()
		btn.text = "ACHETER"
		
		# Check if fleet is full
		var free_slot = -1
		for s in range(FleetManager.ships.size()):
			if FleetManager.ships[s] == null:
				free_slot = s
				break
		
		if free_slot == -1:
			btn.disabled = true
			btn.text = "FLOTTE PLEINE"
		elif active_ship and active_ship.gold < ship_data.price:
			btn.disabled = true
			btn.text = "TROP CHER"
		
		btn.pressed.connect(_on_ship_bought.bind(i))
		
		hbox.add_child(icon)
		hbox.add_child(details)
		hbox.add_child(btn)
		ship_list.add_child(hbox)

func _on_ship_bought(index: int):
	var active_ship = FleetManager.get_active_ship()
	var ship_data = GameConfig.merchant_fleet_ships[index]
	
	if active_ship and active_ship.gold >= ship_data.price:
		active_ship.gold -= ship_data.price
		
		# Spawn new ship
		var ship_scene = load("res://scenes/Ship.tscn")
		var new_ship = ship_scene.instantiate() as Ship
		
		# Set root scale to 0.2 (Matches player ship in World.tscn)
		new_ship.scale = Vector3(0.2, 0.2, 0.2)
		
		# Add to tree FIRST so global_position (transform) is valid
		get_tree().current_scene.add_child(new_ship)
		
		# Position it safely away from the player with slight randomness to avoid stacking
		var rand_variation = Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
		var offset = (active_ship.global_basis.x * 280.0) + (active_ship.global_basis.z * 180.0)
		new_ship.global_position = active_ship.global_position + offset + rand_variation
		
		# Apply ship class and mesh visuals
		new_ship.switch_ship(ship_data.type, ship_data.scene_path)
		
		# Apply stats from GameConfig
		new_ship.max_hp = ship_data.hp
		new_ship.hp = ship_data.hp
		new_ship.max_speed = ship_data.speed
		new_ship.damage = ship_data.damage
		new_ship.max_cooldown = ship_data.cooldown
		new_ship.icon_text = ship_data.icon_text
		
		new_ship.ammo = 100 if "Guerre" in ship_data.name else 40
		new_ship.max_ammo = new_ship.ammo
		
		# Map skills/weapon slots
		for s in range(new_ship.weapon_slots.size()):
			if s < ship_data.skills.size():
				var skill_res = load(ship_data.skills[s])
				new_ship.weapon_slots[s] = skill_res
			else:
				new_ship.weapon_slots[s] = null
		
		# Refresh internal components (Gimbal, Smoke, etc.)
		new_ship._init_components()
		new_ship._setup_damage_smoke()
		new_ship._setup_immobilized_icon()
		
		# Add to fleet
		FleetManager.add_ship(new_ship)
		
		_on_close_pressed()

func _on_close_pressed():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.state = GameManager.GameState.PLAYING
