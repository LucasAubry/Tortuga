class_name WindControl
extends WeaponData

func _init():
	type = ActionType.WIND_CONTROL
	weapon_name = "Contrôle du Vent"
	skill_duration = 8.0 # Dure un peu plus longtemps

# --- ACTIVATION ---
func activate(ship: Node3D):
	if "is_wind_boost_active" in ship:
		ship.is_wind_boost_active = true
		ship.wind_boost_timer = skill_duration
		print("<<< Skill Wind Control Activated! >>>")

# Optional: Add visual feedback logic in process_tick if needed
func process_tick(ship: Node3D, delta: float):
	pass
