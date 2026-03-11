class_name Flamethrower
extends WeaponData

@export_group("Flamethrower Geometry")
@export var flame_range: float = 60.0       # Longueur du jet/hitbox
@export var flame_angle_degrees: float = 35.0 # Largeur du cône (35 deg total)
@export var particles_amount: int = 500     # Densité du feu

@export_group("Flamethrower Mechanics")
@export var ammo_usage_per_sec: float = 5.0  # Consommation (5 boulets/sec)
@export var cooldown_duration: float = 10.0  # Durée du carré blanc qui tourne

var _last_toggle_frame: int = -1

func _init():
	type = ActionType.SKILL
	weapon_name = "Lance-flammes"
	damage = 60.0
	ammo_cost = 0
	# Valeur par défaut pour le HUD au démarrage
	cooldown = 10.0 

func activate(ship: Node3D):
	# On neutralise immédiatement le cooldown automatique que Ship.gd vient de mettre
	var idx = _get_my_slot_index(ship)
	if idx != -1:
		ship.weapon_cooldowns[idx] = 0.0
	
	# Appel du toggle (bypass_cooldown = true pour autoriser l'allumage immédiat)
	_toggle_flamethrower(ship, true)

func _toggle_flamethrower(ship: Node3D, bypass_cooldown: bool = false):
	var current_frame = Engine.get_frames_drawn()
	if _last_toggle_frame == current_frame: return
	_last_toggle_frame = current_frame

	var is_firing = ship.has_meta("flamethrower_active") and ship.get_meta("flamethrower_active")
	
	if is_firing:
		_stop_firing(ship)
	else:
		# Munitions
		var ammo_val = ship.get("ammo")
		if ammo_val == null or ammo_val < 1:
			print("⚠️ Pas assez de munitions !")
			return
		
		# Sécurité eau/plongée
		if ship.get("is_diving") == true or ship.get("is_underwater") == true:
			print("🌊 Impossible d'allumer le feu sous l'eau !")
			return
		
		# VÉRIFICATION COOLDOWN : On bloque si le carré blanc tourne déjà
		var idx = _get_my_slot_index(ship)
		if not bypass_cooldown and idx != -1 and ship.weapon_cooldowns[idx] > 0.1:
			print("⌛ Recharge en cours...")
			return

		ship.set_meta("flamethrower_active", true)
		_start_visuals(ship)
		print("🔥 Lance-flammes: ON")

func _stop_firing(ship: Node3D):
	ship.set_meta("flamethrower_active", false)
	var p = ship.get_meta("flamethrower_particles") if ship.has_meta("flamethrower_particles") else null
	if is_instance_valid(p):
		p.emitting = false
	
	# LANCEMENT DU TEMPS DE RECHARGE (Le carré blanc démarre ICI)
	var idx = _get_my_slot_index(ship)
	if idx != -1:
		ship.weapon_cooldowns[idx] = cooldown_duration
		# On synchronise le diviseur du HUD
		cooldown = cooldown_duration
	
	print("🔥 Lance-flammes: OFF - Cooldown commencé")

func process_tick(ship: Node3D, delta: float):
	# PROTECTION CONSTANTE DU HUD : On verrouille le diviseur à 10s (ou cooldown_duration)
	cooldown = cooldown_duration

	var idx = _get_my_slot_index(ship)
	var is_firing = ship.has_meta("flamethrower_active") and ship.get_meta("flamethrower_active")

	# Gestion touche Espace
	if ship.get("is_player") == true:
		var is_selected = false
		if "active_weapon_index" in ship and "weapon_slots" in ship:
			if ship.active_weapon_index == idx: is_selected = true
		
		if is_selected and Input.is_action_just_pressed("ui_select"):
			_toggle_flamethrower(ship, false)

	if is_firing:
		# On maintien le chrono à 0 tant qu'on tire pour NE PAS griser l'icône
		if idx != -1: ship.weapon_cooldowns[idx] = 0.0

		# Sécurité sous-marine
		if ship.get("is_diving") == true or ship.get("is_underwater") == true:
			_stop_firing(ship)
			return

		# Munitions (5 par seconde)
		var accum = ship.get_meta("flamethrower_accum", 0.0)
		accum += ammo_usage_per_sec * delta 
		if accum >= 1.0:
			var cost = int(floor(accum))
			if "ammo" in ship:
				ship.ammo -= cost
				accum -= float(cost)
				if ship.ammo <= 0: _stop_firing(ship)
		ship.set_meta("flamethrower_accum", accum)
		
		_hit_scan_fire(ship, delta)

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
	if ship.has_method("_camera_shake"): ship.call("_camera_shake", 0.3, 2.0)

func _setup_particles(p: CPUParticles3D, ship: Node3D):
	p.amount = particles_amount
	p.lifetime = 0.5
	p.randomness = 0.3
	p.local_coords = true
	p.direction = Vector3(0, 0, 1)
	p.spread = flame_angle_degrees / 2.0
	p.gravity = Vector3(0, 0.8, 0) # Le feu monte un peu
	
	p.initial_velocity_min = flame_range * 2.8
	p.initial_velocity_max = flame_range * 4.2
	
	var mesh = SphereMesh.new()
	mesh.radius = 6.0 
	mesh.height = 12.0
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# COULEUR RÉALISTE : Orange chaud (adieu le blanc électrique)
	mat.albedo_color = Color(1, 0.5, 0.05, 0.75) 
	mesh.material = mat
	p.mesh = mesh
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 10.0))
	p.scale_amount_curve = curve
	
	var gradient = Gradient.new()
	# DÉGRADÉ DE COMBUSTION NATUREL (Jaune -> Orange -> Rouge)
	gradient.add_point(0.0, Color(1, 0.8, 0, 1.0))   # Jaune orangé intense
	gradient.add_point(0.4, Color(1, 0.45, 0, 0.9))  # Orange feu
	gradient.add_point(0.8, Color(0.8, 0.1, 0, 0.7)) # Rouge sang
	gradient.add_point(1.0, Color(0.1, 0, 0, 0.0))   # Noirceur/Fumée
	p.color_ramp = gradient

func _hit_scan_fire(ship: Node3D, delta: float):
	var zone = ship.get_node_or_null("FlamethrowerZone")
	var r = flame_range
	# Calcul automatique du cône de dégâts selon tes degrés (35°)
	var angle_threshold = cos(deg_to_rad(flame_angle_degrees / 2.0))
	if zone: r *= zone.scale.z
	var fwd = ship.global_transform.basis.z.normalized()
	for other in ship.get_tree().get_nodes_in_group("ship"):
		if other == ship or not is_instance_valid(other): continue
		var to = other.global_position - ship.global_position
		if to.length() < r:
			if fwd.dot(to.normalized()) > angle_threshold:
				if other.has_method("take_damage"): other.take_damage(damage * delta, ship)

func _get_my_slot_index(ship: Node3D) -> int:
	if "weapon_slots" in ship:
		for i in range(ship.weapon_slots.size()):
			if ship.weapon_slots[i] == self: return i
	return -1
