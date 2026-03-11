class_name Flamethrower
extends WeaponData

var _last_toggle_frame: int = -1

func _init():
	type = ActionType.SKILL
	weapon_name = "Lance-flammes"
	cooldown = 0.0 # On commence à 0 pour éviter le chargement automatique
	damage = 45.0
	ammo_cost = 0

func activate(ship: Node3D):
	# Appelé par le clic (ui_fire)
	_toggle_flamethrower(ship)

func _toggle_flamethrower(ship: Node3D):
	# Sécurité anti-double toggle dans la même frame
	var current_frame = Engine.get_frames_drawn()
	if _last_toggle_frame == current_frame:
		return
	_last_toggle_frame = current_frame

	var is_firing = ship.has_meta("flamethrower_active") and ship.get_meta("flamethrower_active")
	
	if is_firing:
		_stop_firing(ship)
	else:
		# Vérification munitions
		var ammo_val = ship.get("ammo")
		if ammo_val == null or ammo_val < 1:
			print("⚠️ Pas assez de munitions !")
			return
		
		# Vérification cooldown (on cherche notre propre slot)
		var idx = _get_my_slot_index(ship)
		if idx != -1 and ship.weapon_cooldowns[idx] > 0:
			print("⌛ Recharge en cours...")
			return

		ship.set_meta("flamethrower_active", true)
		_start_visuals(ship)
		
		# On s'assure que le cooldown est à 0 pour que l'icône reste claire
		cooldown = 0.0 
		if idx != -1: ship.weapon_cooldowns[idx] = 0.0
		
		print("🔥 Lance-flammes: ON")

func _stop_firing(ship: Node3D):
	ship.set_meta("flamethrower_active", false)
	var p = ship.get_meta("flamethrower_particles") if ship.has_meta("flamethrower_particles") else null
	if is_instance_valid(p):
		p.emitting = false
	
	# --- ACTIVATION DU COOLDOWN POUR LE HUD ---
	# On force la ressource à 10.0 pour que le HUD puisse dessiner le cercle
	cooldown = 10.0 
	var idx = _get_my_slot_index(ship)
	if idx != -1:
		ship.weapon_cooldowns[idx] = 10.0
	
	print("🔥 Lance-flammes: OFF - Cooldown lancé")

func process_tick(ship: Node3D, delta: float):
	var idx = _get_my_slot_index(ship)
	var is_firing = ship.has_meta("flamethrower_active") and ship.get_meta("flamethrower_active")

	# Gestion de la touche Espace pour le joueur
	if ship.get("is_player") == true:
		var is_selected = false
		if "active_weapon_index" in ship and "weapon_slots" in ship:
			if ship.active_weapon_index == idx:
				is_selected = true
		
		# On ne réagit à Espace que si sélectionné
		if is_selected and Input.is_action_just_pressed("ui_select"):
			_toggle_flamethrower(ship)

	if is_firing:
		# Triple sécurité : pas de cooldown pendant le tir
		cooldown = 0.0
		if idx != -1: ship.weapon_cooldowns[idx] = 0.0

		# Munitions (3 par seconde)
		var accum = ship.get_meta("flamethrower_accum") if ship.has_meta("flamethrower_accum") else 0.0
		accum += 3.0 * delta
		if accum >= 1.0:
			var cost = int(floor(accum))
			if "ammo" in ship:
				ship.ammo -= cost
				accum -= float(cost)
				if ship.ammo <= 0: _stop_firing(ship)
		ship.set_meta("flamethrower_accum", accum)
		_hit_scan_fire(ship, delta)
	else:
		# Si on ne tire pas, on maintient cooldown = 10.0 tant que ship.weapon_cooldowns > 0
		# Cela permet au HUD de continuer à calculer le pourcentage
		if idx != -1:
			if ship.weapon_cooldowns[idx] > 0:
				cooldown = 10.0
			else:
				cooldown = 0.0

func _start_visuals(ship: Node3D):
	var p = ship.get_meta("flamethrower_particles") if ship.has_meta("flamethrower_particles") else null
	if not is_instance_valid(p):
		var zone = ship.get_node_or_null("FlamethrowerZone")
		p = CPUParticles3D.new()
		if zone: zone.add_child(p)
		else: ship.add_child(p)
		_setup_particles(p, ship)
		ship.set_meta("flamethrower_particles", p)
	p.emitting = true
	if ship.has_method("_camera_shake"): ship.call("_camera_shake", 0.4, 3.0)

func _setup_particles(p: CPUParticles3D, ship: Node3D):
	p.amount = 1200
	p.lifetime = 0.5
	p.randomness = 0.1
	p.local_coords = true
	p.direction = Vector3(0, 0, 1)
	p.spread = 55.0
	p.gravity = Vector3(0, 0, 0)
	var zone = ship.get_node_or_null("FlamethrowerZone")
	var r = 65.0
	if zone: r = zone.scale.z * 65.0
	p.initial_velocity_min = r * 2.0
	p.initial_velocity_max = r * 3.2
	var mesh = SphereMesh.new()
	mesh.radius = 10.0
	mesh.height = 20.0
	mesh.radial_segments = 4
	mesh.rings = 4
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.6)
	mesh.material = mat
	p.mesh = mesh
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 15.0))
	p.scale_amount_curve = curve
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.9, 0.3, 0.9))
	gradient.set_color(0.4, Color(1, 0.4, 0.1, 0.7))
	gradient.set_color(1, Color(0.1, 0.1, 0.1, 0.0))
	p.color_ramp = gradient

func _hit_scan_fire(ship: Node3D, delta: float):
	var zone = ship.get_node_or_null("FlamethrowerZone")
	var r = 65.0
	var angle = 0.45
	if zone:
		r = zone.scale.z * 65.0
		angle = clamp(0.7 - (zone.scale.x * 0.5), 0.2, 0.9)
	var fwd = ship.global_transform.basis.z.normalized()
	for other in ship.get_tree().get_nodes_in_group("ship"):
		if other == ship or not is_instance_valid(other): continue
		var to = other.global_position - ship.global_position
		if to.length() < r:
			if fwd.dot(to.normalized()) > angle:
				if other.has_method("take_damage"): other.take_damage(damage * delta, ship)

func _get_my_slot_index(ship: Node3D) -> int:
	if "weapon_slots" in ship:
		for i in range(ship.weapon_slots.size()):
			if ship.weapon_slots[i] == self: return i
	return -1
