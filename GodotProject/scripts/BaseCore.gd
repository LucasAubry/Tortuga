extends StaticBody3D

@export var max_hp: float = 10000.0
var hp: float = 10000.0
var is_player = false # Pour ne pas planter les checks éventuels
var is_dead = false

@onready var mesh = $MeshInstance3D

func _ready():
	add_to_group("enemies") # Pour que le HUD affiche la barre de vie
	add_to_group("base_core")
	hp = max_hp
	
	# Matériau de surbrillance pour les dégâts
	var hit_mat = StandardMaterial3D.new()
	hit_mat.albedo_color = Color(1, 1, 1, 0)
	hit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_mat.emission_enabled = true
	hit_mat.emission = Color.BLACK
	mesh.material_overlay = hit_mat

func is_base_core() -> bool:
	return true

func take_damage(amount: float, attacker = null):
	if is_dead: return
	hp -= amount
	
	# Flash de dégât
	if is_instance_valid(mesh) and mesh.material_overlay:
		var mat = mesh.material_overlay as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
		mat.emission = Color(1.0, 0.2, 0.2)
		
		var tween = create_tween()
		tween.tween_property(mat, "albedo_color", Color(1, 1, 1, 0), 0.2)
		tween.parallel().tween_property(mat, "emission", Color.BLACK, 0.2)
		
	if hp <= 0:
		hp = 0
		die()

func die():
	is_dead = true
	print("Base Core détruit ! Défaite / Victoire adverse")
	
	# Effet d'explosion
	if ResourceLoader.exists("res://scenes/effects/Explosion.tscn"):
		var explosion_scene = load("res://scenes/effects/Explosion.tscn")
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		explosion.scale = Vector3(5, 5, 5) # Grosse explosion
		get_parent().add_child(explosion)
		
	if ResourceLoader.exists("res://scenes/effects/WaterSplash.tscn"):
		var explosion_scene2 = load("res://scenes/effects/WaterSplash.tscn")
		var explosion = explosion_scene2.instantiate()
		explosion.global_position = global_position
		explosion.scale = Vector3(5, 5, 5)
		get_parent().add_child(explosion)
		
	# Afficher un écran de fin de partie via le HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_death_screen"):
		hud.show_death_screen("🏆  DÉFAITE  🏆", "Votre base a été détruite !")
		
	queue_free()
