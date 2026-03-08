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
@export var icon: Texture2D

@export_group("Grapple Specific")
@export var pull_force: float = 50.0

@export_group("Skill Specific")
@export var skill_duration: float = 5.0
@export var speed_buff: float = 2.0

# --- LOGIQUE MODULAIRE ---
# Appelé quand on appuie sur le bouton de tir
func activate(ship: Node3D):
	pass

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
