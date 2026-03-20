class_name ShieldSkill
extends WeaponData

@export var shield_strength: float = 100.0

func _init():
	type = ActionType.SHIELD
	weapon_name = "Bouclier"
	cooldown = 15.0
	ammo_cost = 5

func activate(ship: Node3D):
	if ship.has_method("activate_shield"):
		ship.activate_shield(shield_strength, skill_duration)
		print("<<< Shield Skill Activated (Strength: ", shield_strength, ") >>>")
