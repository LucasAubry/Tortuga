extends Node3D

enum FishingState { IDLE, WAITING, BITING }
var current_state = FishingState.IDLE
var player_ship: Ship = null

var wait_timer: float = 0.0
var window_timer: float = 0.0
var hook_visual: MeshInstance3D = null

func _ready():
	var area = get_node_or_null("Area3D")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	
	# Création du visuel de l'hameçon (caché par défaut)
	_setup_hook_visual()

func _setup_hook_visual():
	hook_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 3.5 # Plus gros
	sphere.height = 7.0
	hook_visual.mesh = sphere
	
	# Création d'un matériau rayé rouge et noir (Float style)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	# On peut simuler le noir avec une texture ou juste rester sur le rouge pour l'instant
	# ou ajouter un petit mesh enfant pour le noir
	hook_visual.material_override = mat
	
	var black_part = MeshInstance3D.new()
	var b_sphere = SphereMesh.new()
	b_sphere.radius = 3.6
	b_sphere.height = 2.5
	black_part.mesh = b_sphere
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color.BLACK
	black_part.material_override = b_mat
	black_part.position.y = -1.5
	hook_visual.add_child(black_part)
	
	add_child(hook_visual)
	hook_visual.visible = false

func _on_body_entered(body):
	if body is Ship and body.is_player:
		player_ship = body
		get_tree().call_group("hud", "show_interaction_prompt", "[G] Pêcher")

func _on_body_exited(body):
	if body == player_ship:
		_cancel_fishing()
		player_ship = null
		get_tree().call_group("hud", "hide_interaction_prompt")

func _process(delta):
	if player_ship == null: return
	
	if current_state == FishingState.IDLE:
		if Input.is_action_just_pressed("interact"):
			_start_fishing()
			
	elif current_state == FishingState.WAITING:
		wait_timer -= delta
		
		# SI on réappuie sur G avant que ça morde, on annule
		if Input.is_action_just_pressed("interact"):
			_cancel_fishing()
			return

		if wait_timer <= 0:
			_fish_biting()
			
	elif current_state == FishingState.BITING:
		window_timer -= delta
		if Input.is_action_just_pressed("interact"):
			_catch_fish()
		elif window_timer <= 0:
			_fail_fishing()

func _start_fishing():
	current_state = FishingState.WAITING
	wait_timer = randf_range(1.0, 7.0)
	
	# Positionne l'hameçon à une direction aléatoire autour du bateau, un peu plus près (30.0)
	var random_angle = randf_range(0, 2 * PI)
	var spawn_dir = Vector3(cos(random_angle), 0, sin(random_angle))
	
	hook_visual.global_position = player_ship.global_position + (spawn_dir * 30.0)
	hook_visual.global_position.y = 0 # Surface de l'eau
	hook_visual.visible = true
	
	get_tree().call_group("hud", "show_interaction_prompt", "Attente d'un poisson...")

func _fish_biting():
	current_state = FishingState.BITING
	window_timer = 1.5 # 1.5 secondes pour réagir
	
	# Animation visuelle : l'hameçon plonge
	var tween = create_tween()
	tween.tween_property(hook_visual, "position:y", -5.0, 0.2)
	
	get_tree().call_group("hud", "show_interaction_prompt", "!!! [G] FERRE ! !!!")

func _catch_fish():
	if player_ship:
		player_ship.fish += 1
		print("Poisson pêché ! Total : ", player_ship.fish)
	
	_reset_to_idle("Poisson attrapé !")

func _fail_fishing():
	_reset_to_idle("Le poisson s'est échappé...")

func _cancel_fishing():
	_reset_to_idle("[G] Pêcher")

func _reset_to_idle(msg: String):
	current_state = FishingState.IDLE
	hook_visual.visible = false
	hook_visual.position.y = 0
	
	if player_ship:
		get_tree().call_group("hud", "show_interaction_prompt", msg)
		# Après 2 secondes, on remet le prompt de base si on est toujours là
		await get_tree().create_timer(2.0).timeout
		if player_ship and current_state == FishingState.IDLE:
			get_tree().call_group("hud", "show_interaction_prompt", "[G] Pêcher")
