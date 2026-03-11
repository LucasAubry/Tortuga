class_name ExplosiveBarrelItem
extends WeaponData

const BarrelScene = preload("res://scenes/baril_explosif.tscn")

func _init():
	type = ActionType.CANNON
	weapon_name = "Baril Explosif"
	cooldown = 8.0 # Refroidissement avant de pouvoir en larguer un autre
	damage = 85.0
	ammo_cost = 10

func activate(ship: Node3D):
	# On cherche si on a assez de munitions
	var ammo_val = ship.get("ammo")
	if ammo_val == null or ammo_val < ammo_cost:
		print("⚠️ Pas assez de munitions pour larguer un baril (Coût: 10)")
		# On annule le cooldown si on n'a pas pu tirer
		var idx = _get_my_slot_index(ship)
		if idx != -1: ship.weapon_cooldowns[idx] = 0.0
		return
	
	# Consommation des boulets
	ship.ammo -= ammo_cost
	
	# Création du baril
	var barrel = BarrelScene.instantiate()
	ship.get_parent().add_child(barrel)
	
	# Positionnement derrière le bateau
	var fwd = ship.global_transform.basis.z.normalized()
	# On le place à 12 unités derrière (proche du gouvernail)
	barrel.global_position = ship.global_position - fwd * 12.0
	barrel.global_position.y = 0 # Niveau d'eau
	
	# On lui définit son créateur (optionnel)
	if "creator" in barrel:
		barrel.creator = ship
		
	print("💣 Baril explosif largué !")

func _get_my_slot_index(ship: Node3D) -> int:
	if "weapon_slots" in ship:
		for i in range(ship.weapon_slots.size()):
			if ship.weapon_slots[i] == self: return i
	return -1
