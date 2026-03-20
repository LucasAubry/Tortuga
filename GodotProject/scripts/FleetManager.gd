extends Node

signal fleet_updated
signal active_ship_changed(index: int)

var ships: Array[Ship] = [null, null, null, null, null, null, null, null, null, null]
var gold: int = 0
var active_index: int = 0

var selected_ships: Array[Ship] = []

# RTS Selection box
var _is_selecting: bool = false
var _selection_start: Vector2 = Vector2.ZERO
var _selection_rect: ColorRect = null
var _rts_marker: Node3D = null

enum Formation { NONE, ATTACK, DEFENSE, TRAVEL }
var current_formation: Formation = Formation.NONE
var _formation_ui: HBoxContainer = null
var _formation_indicators: Array[ColorRect] = []

var _sword_cursor = preload("res://assets/ui/icons/sword_cursor.png")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Setup selection box visual
	_selection_rect = ColorRect.new()
	_selection_rect.color = Color(0, 1, 0, 0.2)
	_selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_rect.visible = false
	# We need a CanvasLayer to draw the box over the game
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # S'assurer qu'il est au dessus de tout
	add_child(canvas)
	canvas.add_child(_selection_rect)
	
	_setup_rts_marker()
	_setup_formation_ui(canvas)
	
	get_tree().process_frame.connect(_find_initial_ship, CONNECT_ONE_SHOT)

func _find_initial_ship():
	var player = get_tree().get_first_node_in_group("player")
	if player and player is Ship:
		ships[0] = player
		gold = player.gold # Initialize shared gold from starting ship
		player.set_controlled(true)
		_update_ship_numbers()
		fleet_updated.emit()

func _update_ship_numbers():
	for i in range(ships.size()):
		if ships[i] and is_instance_valid(ships[i]):
			if ships[i].has_method("set_fleet_number"):
				ships[i].set_fleet_number(i + 1)

func cycle_ungrouped_ships():
	var ungrouped = []
	for s in ships:
		if s and is_instance_valid(s) and not s.is_sinking and s.group_id == 0:
			ungrouped.append(s)
	
	if ungrouped.size() == 0: return
	
	# Trouver l'index du bateau actuel dans la liste des non-groupés
	var current_ship = get_active_ship()
	var next_index = 0
	for i in range(ungrouped.size()):
		if ungrouped[i] == current_ship:
			next_index = (i + 1) % ungrouped.size()
			break
	
	# Faire le switch
	var target = ungrouped[next_index]
	for i in range(ships.size()):
		if ships[i] == target:
			switch_to_ship(i)
			break

func _input(event):
	# On autorise le clic pour le debug, même en état MENU (0) s'il n'y a pas d'UI bloquante
	if event is InputEventMouseButton and event.pressed:
		print("🖱️ Clic dans FleetManager: bouton ", event.button_index, " (Etat actuel: ", GameManager.state, ")")
	
	# Si on est vraiment dans un menu (ex: Town, Upgrade), on bloque. 
	var blocking_states = [
		GameManager.GameState.TOWN_MENU, 
		GameManager.GameState.UPGRADE_MENU,
		GameManager.GameState.SHIPWRIGHT_MENU,
		GameManager.GameState.HQ_MENU,
		GameManager.GameState.KRAKEN_MENU,
		GameManager.GameState.SHIP_MERCHANT_MENU,
		GameManager.GameState.SETTINGS
	]
	
	if GameManager.state in blocking_states:
		return

	# --- CYCLE UNGROUPED (Touche GRAS / ` ) ---
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT: # Touche `
			cycle_ungrouped_ships()
			get_viewport().set_input_as_handled()
			return

	# --- INPUTS CLAVIER (Groupes et Commandes RTS) ---
	if event is InputEventKey and event.pressed and not event.echo:
		# 1. Gestion des Groupes (1-9, 0)
		var num = -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			num = event.keycode - KEY_0 
		elif event.keycode == KEY_0:
			num = 10
			
		if num != -1:
			if event.shift_pressed:
				# ASSIGNER AU GROUPE
				var targets = _get_current_targets()
				for s in targets: if is_instance_valid(s): s.group_id = num
				print("⚓ ", targets.size(), " navire(s) assigné(s) au groupe ", num)
				get_tree().call_group("hud", "update_groups_ui")
				get_tree().call_group("hud", "_on_fleet_updated")
			elif event.ctrl_pressed or event.meta_pressed:
				# SELECTIONNER UN NAVIRE SPECIFIQUE DANS LE GROUPE ACTUEL
				var active = get_active_ship()
				if is_instance_valid(active) and active.group_id > 0:
					var grp_id = active.group_id
					var group_members = []
					for s in ships:
						if is_instance_valid(s) and s.group_id == grp_id and not s.is_sinking:
							group_members.append(s)
					var idx = num - 1 if num < 10 else 9
					if idx >= 0 and idx < group_members.size():
						for i in range(ships.size()):
							if ships[i] == group_members[idx]:
								switch_to_ship(i)
								break
			else:
				# SELECTIONNER LE GROUPE
				_select_group(num)
			get_viewport().set_input_as_handled()
			return

		# 2. Commandes RTS
		var rts_targets = _get_current_targets()
		match event.keycode:
			KEY_X:
				for s in rts_targets: if is_instance_valid(s): s.stop()
				get_viewport().set_input_as_handled()
			KEY_C:
				_toggle_formation(Formation.ATTACK)
				get_viewport().set_input_as_handled()
			KEY_V:
				_toggle_formation(Formation.DEFENSE)
				get_viewport().set_input_as_handled()
			KEY_B:
				_toggle_formation(Formation.TRAVEL)
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE, KEY_DELETE:
				if event.shift_pressed:
					var ship = get_active_ship()
					if is_instance_valid(ship) and ship.group_id > 0:
						print("❌ Navire retiré du groupe ", ship.group_id)
						ship.group_id = 0
						get_tree().call_group("hud", "update_groups_ui")
						get_tree().call_group("hud", "_on_fleet_updated")
					get_viewport().set_input_as_handled()

# --- RTS SELECTION & MOVEMENTS (Unhandled pour laisser passer les Shop clicks) ---
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. Check if clicking on enemy (Single Shot Priority)
				var hit_ship = _raycast_for_ship(event.position)
				if hit_ship and hit_ship.faction != Ship.Faction.PLAYER:
					var active = get_active_ship()
					if is_instance_valid(active):
						active.single_fire_at(hit_ship)
						return # Block selection behavior
						
				# 2. Start selection box
				_is_selecting = true
				_selection_start = event.position
				_selection_rect.position = _selection_start
				_selection_rect.size = Vector2.ZERO
			else:
				if _is_selecting:
					_is_selecting = false
					var was_drag = _selection_rect.visible and _selection_rect.size.length() > 10
					_selection_rect.visible = false
					_finish_selection(was_drag, Input.is_key_pressed(KEY_SHIFT))
				
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_rts_move_command(event.position)
				
	if event is InputEventMouseMotion and _is_selecting:
		var current_pos = event.position
		if _selection_start.distance_to(current_pos) > 5:
			_selection_rect.visible = true
			_selection_rect.position = Vector2(min(_selection_start.x, current_pos.x), min(_selection_start.y, current_pos.y))
			_selection_rect.size = (current_pos - _selection_start).abs()

func _finish_selection(was_drag: bool, shift_pressed: bool):
	var rect = _selection_rect.get_global_rect()
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	# Si on ne maintient pas Shift, on vide la sélection précédente
	if not shift_pressed:
		for s in selected_ships:
			if is_instance_valid(s): s.set_selected(false)
		selected_ships.clear()
	
	# SI C'EST UN CLIC SIMPLE
	if not was_drag:
		var mouse_pos = get_viewport().get_mouse_position()
		var closest = null
		var min_dist = 60.0 # Pixels de tolérance un peu plus large
		
		for s in ships:
			if s and is_instance_valid(s) and not s.is_sinking:
				var screen_pos = camera.unproject_position(s.global_position)
				var dist = screen_pos.distance_to(mouse_pos)
				if dist < min_dist:
					min_dist = dist
					closest = s
		
		if closest:
			if not closest in selected_ships:
				selected_ships.append(closest)
				closest.set_selected(true)
				# On donne le focus d'action contextuelle à ce navire
				for i in range(ships.size()):
					if ships[i] == closest:
						switch_to_ship(i)
						break
		return

	# SI C'EST UNE SÉLECTION PAR RECTANGLE
	for s in ships:
		if s and is_instance_valid(s) and not s.is_sinking:
			var screen_pos = camera.unproject_position(s.global_position)
			if rect.has_point(screen_pos):
				if not s in selected_ships:
					selected_ships.append(s)
					s.set_selected(true)
	
	if selected_ships.size() > 0:
		print("📦 Navires sélectionnés : ", selected_ships.size())
		# On switch sur le premier de la sélection par défaut pour donner le focus
		for i in range(ships.size()):
			if ships[i] == selected_ships[0]:
				switch_to_ship(i)
				break

func _select_group(id: int):
	# Clear previous
	for s in selected_ships:
		if is_instance_valid(s): s.set_selected(false)
		
	var group_members: Array[Ship] = []
	for s in ships:
		if s and is_instance_valid(s) and s.group_id == id:
			group_members.append(s)
			s.set_selected(true)
	
	if group_members.size() > 0:
		selected_ships = group_members
		# Switch sur le premier membre
		for i in range(ships.size()):
			if ships[i] == group_members[0]:
				switch_to_ship(i)
				break
		print("👥 Groupe ", id, " sélectionné (", group_members.size(), " membres)")
	else:
		# Fallback : Comportement original (slot 1-10) si pas de groupe
		var slot = id - 1
		if slot < ships.size() and ships[slot] and is_instance_valid(ships[slot]):
			switch_to_ship(slot)

func add_ship(ship: Ship, slot: int = -1) -> bool:
	if slot == -1:
		for i in range(ships.size()):
			if ships[i] == null:
				slot = i
				break
	
	if slot != -1 and slot < ships.size():
		ships[slot] = ship
		ship.is_player = true
		ship.faction = 0 # Faction.PLAYER
		ship.set_controlled(false)
		_update_ship_numbers()
		fleet_updated.emit()
		return true
	return false

func switch_to_ship(index: int):
	if index < 0 or index >= ships.size(): return
	if ships[index] == null or not is_instance_valid(ships[index]): return
	if ships[index].is_sinking: return

	# Deactivate current
	if ships[active_index] and is_instance_valid(ships[active_index]):
		ships[active_index].set_controlled(false)
	
	# Activate new
	active_index = index
	ships[active_index].set_controlled(true)
	active_ship_changed.emit(active_index)
	
	# Update HUD/UI if needed
	get_tree().call_group("hud", "_on_active_ship_changed", active_index)
	
	print("⚓ Caméra et contrôles transférés au navire #", active_index + 1)

func get_active_ship() -> Ship:
	return ships[active_index]

func remove_ship(ship: Ship):
	for i in range(ships.size()):
		if ships[i] == ship:
			ships[i] = null
			_update_ship_numbers()
			fleet_updated.emit()
			
			# If we just removed the active ship and no other is alive
			if i == active_index:
				var switched = find_and_switch_to_next_ship()
				if not switched:
					# Game Over: No more ships!
					get_tree().call_group("hud", "show_death_screen")
			break

func find_and_switch_to_next_ship() -> bool:
	for i in range(ships.size()):
		if ships[i] and is_instance_valid(ships[i]) and not ships[i].is_sinking:
			switch_to_ship(i)
			return true
	return false

func _process(_delta):
	# Cursor Logic disabled for macOS compatibility with raw png
	# var is_hovering_enemy = false
	# var hit_ship = _raycast_for_ship(mouse_pos)
	# if hit_ship and hit_ship.faction != Ship.Faction.PLAYER:
	# 	is_hovering_enemy = true
	# 	
	# if is_hovering_enemy:
	# 	Input.set_custom_mouse_cursor(_sword_cursor)
	# else:
	# 	Input.set_custom_mouse_cursor(null) # Default cursor
	
	var mouse_pos = get_viewport().get_mouse_position()
		
	# 2. Continuous Right Click Move
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_handle_rts_move_command(mouse_pos, false)
		
	# Auto-switch if active ship sinks
	var current = ships[active_index]
	if current != null:
		if not is_instance_valid(current) or current.is_sinking:
			var switched = find_and_switch_to_next_ship()
			if not switched:
				var any_alive = false
				for s in ships:
					if s and is_instance_valid(s) and not s.is_sinking:
						any_alive = true
						break
				if not any_alive:
					pass

func _raycast_for_ship(mouse_pos: Vector2) -> Node3D:
	var camera = get_viewport().get_camera_3d()
	if not camera: return null
	
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	var world = get_viewport().get_world_3d()
	if not world: return null
	var space_state = world.direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 10000.0)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	
	if result and not result.is_empty():
		var hit_obj = result.collider
		var curr = hit_obj
		while curr and curr != get_tree().root:
			if curr.has_method("get_hp"): # Simple check to see if it's a ship
				if "faction" in curr:
					return curr
			curr = curr.get_parent()
	return null

func _handle_rts_move_command(mouse_pos: Vector2, show_marker: bool = true):
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	# Priority 1: Check for Enemy Click (Physics Raycast)
	var world = get_viewport().get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 10000.0)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	
	var targets = _get_current_targets()
	
	if result and not result.is_empty():
		var hit_obj = result.collider
		var hit_ship: Ship = null
		
		# On remonte prudemment pour trouver le navire parent
		var curr = hit_obj
		while curr and curr != get_tree().root:
			if curr is Ship:
				hit_ship = curr
				break
			curr = curr.get_parent()
			
		if hit_ship and hit_ship.faction != Ship.Faction.PLAYER:
			print("⚔️ Attaque de groupe sur : ", hit_ship.name)
			for s in targets:
				if is_instance_valid(s): s.attack_order(hit_ship)
			if show_marker: _show_rts_marker(result.position) 
			return

	# Priority 2: Move to Sea (Plane Raycast)
	var sea_plane = Plane(Vector3.UP, 0.0)
	var target_pos = sea_plane.intersects_ray(from, dir)
	
	if target_pos != null:
		move_fleet_to_world_pos(target_pos, show_marker)

func move_fleet_to_world_pos(target_pos: Vector3, show_marker: bool = true):
	var targets = _get_current_targets()
	target_pos.y = 0
	print("🚢 FleetManager: Mouvement ordonné vers ", target_pos, " pour ", targets.size(), " navire(s)")
	
	if show_marker: _show_rts_marker(target_pos)
	
	# Reset offsets pour recalculer la formation si active
	_update_formation_offsets(targets)
	
	for s in targets:
		if is_instance_valid(s):
			var final_pos = target_pos if current_formation == Formation.NONE else target_pos + s.formation_offset
			s.move_to_rts(final_pos)



func _setup_rts_marker():
	_rts_marker = Node3D.new()
	_rts_marker.visible = false
	_rts_marker.top_level = true
	add_child(_rts_marker)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.0, 1.0) # Jaune LoL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	for i in range(3):
		var dot = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 1.5
		cyl.bottom_radius = 1.5
		cyl.height = 1.0
		dot.mesh = cyl
		dot.set_surface_override_material(0, mat)
		
		# Disposer en cercle (120 degrés d'écart) - Très rapprochés (presque touchants)
		var angle = deg_to_rad(i * 120.0)
		var radius = 3.0
		dot.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_rts_marker.add_child(dot)

func _show_rts_marker(pos: Vector3):
	if not _rts_marker: return
	_rts_marker.global_position = pos + Vector3(0, 1.5, 0)
	_rts_marker.visible = true
	_rts_marker.scale = Vector3(0.1, 0.1, 0.1)
	
	var mat = (_rts_marker.get_child(0) as MeshInstance3D).get_surface_override_material(0)
	mat.albedo_color.a = 1.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	# Pulsation de taille et convergence
	tw.tween_property(_rts_marker, "scale", Vector3(1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2).set_delay(0.15)
	
	tw.chain().tween_callback(func(): _rts_marker.visible = false)

func _get_current_targets() -> Array[Ship]:
	var valid_targets: Array[Ship] = []
	if selected_ships.size() > 0:
		for s in selected_ships:
			if is_instance_valid(s) and not s.is_sinking:
				valid_targets.append(s)
	
	if valid_targets.is_empty():
		var active = get_active_ship()
		if is_instance_valid(active) and not active.is_sinking:
			valid_targets.append(active)
			
	return valid_targets

func _setup_formation_ui(canvas: CanvasLayer):
	var ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	
	# Un fond sombre pour le bloc de formations
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.custom_minimum_size = Vector2(300, 70)
	ui_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	
	_formation_ui = HBoxContainer.new()
	_formation_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_formation_ui)
	_formation_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_formation_ui.add_theme_constant_override("separation", 15)
	
	var names = ["Attaque", "Défense", "Voyage"]
	var keys = ["C", "V", "B"]
	
	for i in range(3):
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(90, 50)
		rect.color = Color(0.15, 0.15, 0.15, 0.9)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_formation_ui.add_child(rect)
		_formation_indicators.append(rect)
		
		var label = Label.new()
		label.text = "[ " + keys[i] + " ]\n" + names[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		rect.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _toggle_formation(f: Formation):
	var prev_formation = current_formation
	if current_formation == f:
		current_formation = Formation.NONE
	else:
		current_formation = f
	
	# Update UI
	for i in range(3):
		_formation_indicators[i].color = Color(1, 0.9, 0, 1) if (current_formation == i + 1) else Color(0.2, 0.2, 0.2, 0.8)
	
	# Si on était en mouvement, on met à jour les destinations immédiatement
	var targets = _get_current_targets()
	_update_formation_offsets(targets)
	
	# Recalculer la destination basée sur le centre ou le navire actif s'il y a un mouvement en cours
	var any_moving = false
	var leader_target = Vector3.ZERO
	for s in targets:
		if s.is_moving_to_target:
			any_moving = true
			# On tente de retrouver le point central de l'ordre original
			leader_target = s.rts_target_pos - s.formation_offset
			break
			
	if any_moving:
		for s in targets:
			s.move_to_rts(leader_target + s.formation_offset)

func _update_formation_offsets(targets: Array[Ship]):
	if current_formation == Formation.NONE:
		# Même sans formation, on applique un léger espacement par défaut
		if targets.size() > 1:
			for i in range(targets.size()):
				var row = i / 3
				var col = i % 3
				targets[i].formation_offset = Vector3(col * 160.0 - 160.0, 0, -row * 180.0)
		else:
			for s in targets: s.formation_offset = Vector3.ZERO
		return
		
	var warships = []
	var merchants = []
	for s in targets:
		# On considère comme marchand soit la faction Merchant, soit les navires de commerce spécifiques
		if s.faction == Ship.Faction.MERCHANT or s.ship_type == Ship.ShipClass.SLOOP: # SLOOP = petit marchand pour cet exemple
			merchants.append(s)
		else:
			warships.append(s)
		
	match current_formation:
		Formation.ATTACK:
			# Warships in front line, Merchants behind
			var total_w = warships.size()
			for i in range(total_w):
				var offset_x = (i - (total_w - 1) / 2.0) * 180.0
				warships[i].formation_offset = Vector3(offset_x, 0, 0)
			
			var total_m = merchants.size()
			for i in range(total_m):
				var offset_x = (i - (total_m - 1) / 2.0) * 180.0
				merchants[i].formation_offset = Vector3(offset_x, 0, -200.0)
				
		Formation.DEFENSE:
			# Merchants in center, warships in circle
			for s in merchants: s.formation_offset = Vector3.ZERO
			var total_w = warships.size()
			for i in range(total_w):
				var angle = deg_to_rad(i * (360.0 / max(1, total_w)))
				warships[i].formation_offset = Vector3(cos(angle) * 350.0, 0, sin(angle) * 350.0)
				
		Formation.TRAVEL:
			# Spaced out grid for safety
			for i in range(targets.size()):
				var row = i / 3
				var col = i % 3
				targets[i].formation_offset = Vector3(col * 300.0 - 300.0, 0, -row * 350.0)
