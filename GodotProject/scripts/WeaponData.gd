class_name WeaponData
extends Resource

enum ActionType { CANNON, GRAPPLE, SKILL, DIVE, WIND_CONTROL, KRAKEN }

@export var type: ActionType = ActionType.CANNON
@export var weapon_name: String = "Standard"
@export var damage: float = 25.0
@export var cooldown: float = 1.0
@export var ammo_cost: int = 2
@export var projectile_speed: float = 200.0
@export var projectile_color: Color = Color.WHITE
@export var projectile_count: int = 1       # Nombre de boulets par tir (1 = normal, 5+ = mitraille)
@export var projectile_scale: float = 2.2   # Taille des boulets (plus petit = petit boulet)
@export var projectile_spread: float = 0.0  # Dispersion en radians (0 = aucune)
@export var icon: Texture2D

@export_group("Activation Settings")
@export var can_be_used_underwater: bool = false


@export_group("Grapple Specific")
@export var pull_force: float = 50.0

@export_group("Skill Specific")
@export var skill_duration: float = 5.0
@export var speed_buff: float = 2.0

# --- LOGIQUE MODULAIRE ---
# Appelé quand on appuie sur le bouton de tir
func activate(ship: Node3D):
	# Si c'est un tir de canon standard et que la méthode n'est pas surchargée
	if type == ActionType.CANNON or type == ActionType.GRAPPLE:
		if ship.has_method("_fire_cannons"):
			ship._fire_cannons(self)

# Appelé à chaque frame de physique (optionnel)
# S'exécute AVANT move_and_slide — idéal pour modifier velocity (ex: WindControl)
func process_tick(ship: Node3D, delta: float):
	pass

# Appelé APRÈS move_and_slide — idéal pour modifier la position directement (ex: Dive)
func post_physics_tick(ship: Node3D, delta: float):
	pass

# Retourne TRUE si l'arme peut tirer (permet de bloquer selon l'état du bateau)
func is_action_blocked(ship: Node3D) -> bool:
	return false

func _get_my_slot_index(ship: Node3D) -> int:
	if "weapon_slots" in ship:
		for i in range(ship.weapon_slots.size()):
			if ship.weapon_slots[i] == self:
				return i
	return -1
