extends Area3D

@export var damage: float = 80.0
@export var knockback_force: float = 60.0
@export var explosion_radius: float = 35.0
@export var visual_explosion_scale: float = 1.0

var _exploded: bool = false
var _armed_time: float = 0.0
var creator: Node3D = null

func _ready():
	var start_y = position.y
	
	# Animation visuelle de flottaison (Haut/Bas + Tangage)
	var vertical_tween = create_tween().set_loops()
	vertical_tween.tween_property(self, "position:y", start_y + 0.8, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vertical_tween.tween_property(self, "position:y", start_y - 0.2, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var rand_angle = randf_range(5.0, 8.0)
	var rotation_tween = create_tween().set_loops()
	rotation_tween.tween_property(self, "rotation:z", deg_to_rad(rand_angle), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rotation_tween.tween_property(self, "rotation:z", deg_to_rad(-rand_angle), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _physics_process(delta):
	if _exploded: return
	
	# Compteur sécurisé indépendant des timers du SceneTree (qui peuvent bugger au respawn)
	_armed_time += delta
	if _armed_time < 0.8: # Armement après 0.8s (un poil plus réactif)
		return
	
	# Dès qu'il est armé, il explose INSTANTANÉMENT si n'importe quel bateau (allié ou ennemi) le touche.
	for body in get_overlapping_bodies():
		if body.is_in_group("ship"):
			explode()
			return

func explode():
	if _exploded: return
	_exploded = true
	
	# On capture la position AVANT de commencer à masquer le baril
	var explosion_pos = global_position
	_spawn_visual_explosion(explosion_pos)
	
	# Dégâts de zone
	var world = get_tree().current_scene
	for ship in get_tree().get_nodes_in_group("ship"):
		if not is_instance_valid(ship): continue
		
		var dist = explosion_pos.distance_to(ship.global_position)
		if dist <= explosion_radius:
			# Dégâts
			if ship.has_method("take_damage"):
				ship.take_damage(damage, creator)
			
			# Knockback (Appliqué à knockback_velocity du bateau)
			if "knockback_velocity" in ship:
				var dir = (ship.global_position - explosion_pos).normalized()
				dir.y = 0
				ship.knockback_velocity += dir * knockback_force
	
	# Shake camera (Valeurs originales)
	var player = world.get_node_or_null("Ship")
	if player and player.has_method("_camera_shake"):
		var dist = explosion_pos.distance_to(player.global_position)
		if dist < 180.0: # Rayon de secousse un peu plus grand
			player._camera_shake(0.8, 8.0)
	
	# Suppression
	visible = false
	await get_tree().create_timer(4.0).timeout # On attend un peu plus pour laisser les particules finir
	queue_free()

func _spawn_visual_explosion(pos: Vector3):
	var parent = get_parent()
	var s = visual_explosion_scale
	
	# 1. Flash de lumière (proportionnel à l'échelle)
	var light = OmniLight3D.new()
	parent.add_child(light)
	light.global_position = pos + Vector3(0, 4 * s, 0)
	light.light_color = Color(1, 0.7, 0.3)
	light.light_energy = 25.0 * s
	light.omni_range = 60.0 * s
	var lt = create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.5)
	lt.finished.connect(light.queue_free)

	# 2. Boule de feu (Adaptée à s)
	var fire = _create_particles(int(100 * s), 1.2, true)
	parent.add_child(fire)
	fire.global_position = pos
	fire.mesh.material.albedo_color = Color(1, 0.4, 0)
	fire.mesh.material.emission_enabled = true
	fire.mesh.material.emission = Color(1, 0.5, 0)
	fire.initial_velocity_min = 15.0 * s
	fire.initial_velocity_max = 35.0 * s
	fire.scale_amount_min = 4.0 * s
	fire.scale_amount_max = 10.0 * s
	var f_grad = Gradient.new()
	f_grad.set_color(0, Color(1, 1, 0.6, 1))
	f_grad.set_color(0.2, Color(1, 0.5, 0, 1))
	f_grad.set_color(1, Color(0.3, 0, 0, 0))
	fire.color_ramp = f_grad
	fire.emitting = true

	# 3. Fumée noire (Adaptée à s)
	var smoke = _create_particles(int(80 * s), 4.0, false)
	parent.add_child(smoke)
	smoke.global_position = pos
	smoke.mesh.material.albedo_color = Color(0.05, 0.05, 0.05, 0.9)
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 60.0
	smoke.initial_velocity_min = 8.0 * s
	smoke.initial_velocity_max = 20.0 * s
	smoke.gravity = Vector3(0, 3 * s, 0)
	smoke.scale_amount_min = 6.0 * s
	smoke.scale_amount_max = 15.0 * s
	var s_grad = Gradient.new()
	s_grad.set_color(0, Color(0.1, 0.1, 0.1, 0.8))
	s_grad.set_color(1, Color(0, 0, 0, 0))
	smoke.color_ramp = s_grad
	smoke.emitting = true

	# 4. Éclaboussure d'eau (Adaptée à s)
	var splash = _create_particles(int(120 * s), 2.0, false)
	parent.add_child(splash)
	splash.global_position = pos
	splash.mesh.material.albedo_color = Color(0.9, 0.95, 1.0, 0.8)
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 90.0
	splash.initial_velocity_min = 25.0 * s
	splash.initial_velocity_max = 45.0 * s
	splash.scale_amount_min = 1.0 * s
	splash.scale_amount_max = 3.5 * s
	var w_grad = Gradient.new()
	w_grad.set_color(0, Color(1, 1, 1, 1))
	w_grad.set_color(1, Color(1, 1, 1, 0))
	splash.color_ramp = w_grad
	splash.emitting = true

func _create_particles(amount: int, life: float, sphere: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false # SURTOUT PAS ENCORE : On attend d'être à la bonne position
	
	var m = SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	p.mesh = m
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED if sphere else StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	
	get_tree().create_timer(life + 1.0).timeout.connect(p.queue_free)
	return p
