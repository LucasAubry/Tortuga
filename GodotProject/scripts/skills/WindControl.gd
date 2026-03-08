class_name WindControl
extends WeaponData

# --- PARAMÈTRES DU BOOST (Ajuster ici pour changer le comportement) ---
## Force du vent arrière pendant le boost (plus haut = plus rapide)
@export var boost_wind_force: float = 3.0
## Bonus de vitesse max (0.8 = +80%, 0.4 = +40%)
@export var boost_speed_multiplier: float = 0.8
## Vitesse de montée/descente du boost (plus bas = plus progressif)
@export var boost_ramp_speed: float = 0.8
## Vitesse de transition du vecteur vent physique (évite les saccades)
@export var wind_lerp_speed: float = 1.5

func _init():
	type = ActionType.WIND_CONTROL
	weapon_name = "Contrôle du Vent"
	skill_duration = 8.0

# --- ACTIVATION ---
func activate(ship: Node3D):
	if "is_wind_boost_active" in ship:
		ship.is_wind_boost_active = true
		ship.wind_boost_timer = skill_duration
		print("<<< Skill Wind Control Activated! >>>")

# --- LOGIQUE PAR FRAME (Toute la physique du vent boost est ici) ---
func process_tick(ship: Node3D, delta: float):
	# Calcul de l'intensité cible (1.0 si actif, 0.0 sinon)
	var target_intensity = 1.0 if ship.get("is_wind_boost_active") else 0.0
	
	# Lerp progressif de l'intensité
	ship.wind_boost_intensity = lerp(ship.wind_boost_intensity, target_intensity, delta * boost_ramp_speed)
	
	# Récupère le vent normal du monde
	var local_wind = GameConfig.get_wind_at(ship.global_position)
	var wind_dir = local_wind["direction"]
	var effective_wind_speed = local_wind["speed"]
	
	# Vecteur vent normal
	var target_wind_vec = Vector3(wind_dir.x, 0, wind_dir.y) * effective_wind_speed
	
	# Vecteur vent de boost (pousse le bateau vers l'avant)
	var forward = ship.transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var boost_wind_vec = forward * boost_wind_force
	
	# Mélange entre vent normal et vent de boost selon l'intensité
	var blended_wind_vec = target_wind_vec.lerp(boost_wind_vec, ship.wind_boost_intensity)
	
	# Transition finale du vecteur pour éviter les saccades physiques
	if ship.current_wind_vec_phys == Vector3.ZERO:
		ship.current_wind_vec_phys = blended_wind_vec
	ship.current_wind_vec_phys = ship.current_wind_vec_phys.lerp(blended_wind_vec, delta * wind_lerp_speed)
	
	# Calcul de l'influence du vent sur la vitesse
	var is_underwater = ship.current_dive_depth < -5.0
	var wind_push = forward.dot(ship.current_wind_vec_phys) if not is_underwater else 0.0
	var speed_modifier = 1.0 + (wind_push * 0.4) if not is_underwater else 1.0
	
	# Boost de vitesse max progressif
	var boost_max_multiplier = 1.0 + (ship.wind_boost_intensity * boost_speed_multiplier)
	
	# Applique la vitesse finale
	var base_effective_speed = ship.ship_speed * speed_modifier
	var effective_speed = base_effective_speed * boost_max_multiplier
	
	ship.velocity = forward * min(effective_speed, 1200.0)
	ship.velocity.y = 0
	
	# Dérive latérale du vent (seulement en surface et en mouvement)
	if ship.ship_speed > 0 and not is_underwater:
		var drift = ship.current_wind_vec_phys - (forward * wind_push)
		ship.velocity += drift * 0.1
		ship.velocity.y = 0
