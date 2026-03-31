extends Node

signal fleet_updated
signal active_ship_changed(index: int)

var ships: Array = []
var gold: int = 0:
	set(value):
		gold = value
		emit_signal("fleet_updated")
var active_index: int = 0

# Variables de transition optimisées
var _is_transitioning: bool = false
var _trans_cam: Camera3D = null
var _target_ship: Node3D = null
var _trans_progress: float = 0.0

# Suivi du premier switch
var _visited_ships: Dictionary = {} # ship_instance -> bool

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_trans_cam = Camera3D.new()
	_trans_cam.name = "FleetTransitionCamera"
	get_viewport().add_child.call_deferred(_trans_cam)
	get_tree().process_frame.connect(_find_initial_ship, CONNECT_ONE_SHOT)

func _find_initial_ship():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_register_ship(player)
		_visited_ships[player] = true # Le premier est forcément visité
		gold = player.gold
		player.set_controlled(true)
		if player.has_method("snap_camera"): player.call("snap_camera")
		emit_signal("fleet_updated")
		emit_signal("active_ship_changed", 0)

func _register_ship(ship: Node3D):
	if not ships.has(ship):
		ships.append(ship)
		ship.is_player = true
		ship.faction = Ship.Faction.PLAYER

func _input(event):
	if _is_transitioning: return
	if event is InputEventKey and event.pressed and Input.is_key_pressed(KEY_SHIFT):
		var num = -1
		match event.keycode:
			KEY_1: num = 0
			KEY_2: num = 1
			KEY_3: num = 2
			KEY_4: num = 3
			KEY_5: num = 4
		if num != -1 and num < ships.size():
			switch_to_ship(num)

func get_active_ship() -> Ship:
	if active_index < ships.size(): return ships[active_index]
	return null

func switch_to_ship(index: int):
	if index == active_index or index >= ships.size() or _is_transitioning: return
	var old_ship = get_active_ship()
	var new_ship = ships[index]
	if not old_ship or not new_ship: return
	
	# SI 1er SWITCH : Instantané
	if not _visited_ships.get(new_ship, false):
		_visited_ships[new_ship] = true
		_complete_switch(old_ship, new_ship, index)
		if new_ship.has_method("snap_camera"): new_ship.call("snap_camera")
		return

	_start_camera_transition(old_ship, new_ship, index)

func _start_camera_transition(old_ship: Ship, new_ship: Ship, new_index: int):
	_is_transitioning = true
	_target_ship = new_ship
	_trans_progress = 0.0
	
	if old_ship.has_method("snap_camera"): old_ship.call("snap_camera")
	if new_ship.has_method("snap_camera"): new_ship.call("snap_camera")
	
	var old_cam = old_ship.find_child("Camera3D", true, false) as Camera3D
	var target_cam = new_ship.find_child("Camera3D", true, false) as Camera3D
	
	if not old_cam or not target_cam or not _trans_cam:
		_complete_switch(old_ship, new_ship, new_index)
		_is_transitioning = false
		return

	old_ship.set_controlled(false)
	_trans_cam.global_transform = old_cam.global_transform
	_trans_cam.fov = old_cam.fov
	_trans_cam.make_current()
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_trans_progress", 1.0, 0.45)
	tween.chain().tween_callback(func():
		_complete_switch(null, _target_ship, new_index)
		_is_transitioning = false
		_target_ship = null
	)

func _process(_delta):
	if _is_transitioning and _target_ship and _trans_cam:
		var target_cam = _target_ship.find_child("Camera3D", true, false) as Camera3D
		if target_cam:
			_trans_cam.global_transform = _trans_cam.global_transform.interpolate_with(target_cam.global_transform, 0.25)

func _complete_switch(old_ship: Ship, new_ship: Ship, new_index: int):
	if old_ship: old_ship.set_controlled(false)
	active_index = new_index
	new_ship.set_controlled(true)
	emit_signal("active_ship_changed", active_index)

func add_ship(type: Ship.ShipClass) -> bool:
	if ships.size() >= 5: return false
	var active = get_active_ship()
	if not active: return false
	var ship_scene = load("res://scenes/Ship.tscn")
	var new_ship = ship_scene.instantiate() as Ship
	var spawn_pos = _find_safe_spawn_pos(active)
	active.get_parent().add_child(new_ship)
	new_ship.global_position = spawn_pos
	new_ship.rotation = active.rotation
	new_ship.ship_type = type
	_register_ship(new_ship)
	new_ship.set_controlled(false)
	if new_ship.has_method("_init_stats"): new_ship.call("_init_stats")
	emit_signal("fleet_updated")
	return true

func _find_safe_spawn_pos(active: Ship) -> Vector3:
	var base_pos = active.global_position
	var right = active.global_transform.basis.x
	for i in range(1, 10): 
		var candidate = base_pos + (right * (60.0 + i * 30.0))
		var is_safe = true
		for s in ships:
			if s and s.global_position.distance_to(candidate) < 35.0:
				is_safe = false
				break
		if is_safe: return candidate
	return base_pos + right * 120.0

func remove_ship(ship: Ship):
	var idx = ships.find(ship)
	if idx != -1:
		ships.remove_at(idx)
		if active_index >= ships.size(): active_index = max(0, ships.size() - 1)
		if ships.is_empty(): get_tree().call_group("hud", "show_death_screen")
		else: _complete_switch(null, ships[active_index], active_index)
		emit_signal("fleet_updated")

# VÉRIFICATION DE DÉPENDANCE CIRCULAIRE
func can_follow(follower: Ship, target: Ship) -> bool:
	if follower == target: return false
	
	var current = target
	while current and current.follow_target:
		if current.follow_target == follower:
			return false # On a trouvé une boucle !
		current = current.follow_target
	return true
