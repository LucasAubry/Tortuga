class_name ExplosiveBarrelItem
extends WeaponData

const BarrelScene = preload("res://scenes/baril_explosif.tscn")

func _init():
	type = ActionType.CANNON
	weapon_name = "Baril Explosif"

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
	
	# Ajout à la racine du monde (Map) pour qu'il soit indépendant des autres nœuds
	ship.get_tree().current_scene.add_child(barrel)
	
	# Positionnement derrière le bateau
	var fwd = ship.global_transform.basis.z.normalized()
	# On le place à 12 unités derrière (proche du gouvernail)
	barrel.global_position = ship.global_position - fwd * 12.0
	
	# ROTATION : Perpendiculaire au bateau
	barrel.global_rotation = ship.global_rotation
	barrel.rotate_x(deg_to_rad(90))
	
	# DÉGÂTS : Source unique depuis la ressource .tres
	if "damage" in barrel:
		barrel.damage = damage
	
	# On lui définit son créateur (optionnel)
	if "creator" in barrel:
		barrel.creator = ship
		
	print("💣 Baril explosif largué !")

func _get_my_slot_index(ship: Node3D) -> int:
	if "weapon_slots" in ship:
		for i in range(ship.weapon_slots.size()):
			if ship.weapon_slots[i] == self: return i
	return -1
