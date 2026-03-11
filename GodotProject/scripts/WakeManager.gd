extends MultiMeshInstance3D

var particles: Array[Dictionary] = []
var player: Node3D = null

const MAX_PARTICLES = 1000 
var particle_index = 0
var _ships_cache: Array = []
var _cache_timer: float = 0.0

func _ready():
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = MAX_PARTICLES
	
	custom_aabb = AABB(Vector3(-100000, -1000, -100000), Vector3(200000, 2000, 200000))
	
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1) # Modulated by vertex color
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.9, 1.0, 1)
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	multimesh.mesh = mesh
	
	for i in range(MAX_PARTICLES):
		particles.append({
			"pos": Vector3(0, -1000, 0), # Hidden initially
			"life": 0.0,
			"max_life": 2.0,
			"vel": Vector3.ZERO,
			"scale": 1.0
		})
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))
		multimesh.set_instance_color(i, Color(1, 1, 1, 0))

func _process(delta):
	# Update ships list every 0.1s to save CPU
	_cache_timer -= delta
	if _cache_timer <= 0:
		_cache_timer = 0.1
		_ships_cache = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies")
	
	for ship in _ships_cache:
		if not is_instance_valid(ship): continue
		
		# Skip if underwater
		if "current_dive_depth" in ship and ship.current_dive_depth < -8.0: 
			continue
		
		var speed = 0.0
		if "ship_speed" in ship: speed = ship.ship_speed
		
		if speed > 5.0:
			var spawn_rate = int((speed / 100.0) * 8.0) + 1
			for i in range(spawn_rate):
				var p = particles[particle_index]
				var ship_basis = ship.global_transform.basis
				var forward = ship_basis.z.normalized()
				var right = ship_basis.x.normalized()
				
				# Alternance Bow (avant) et Stern (arrière) pour recréer le sillage complet
				var is_bow = (particle_index % 3 != 0) 
				var side = 1.0 if (particle_index % 2 == 0) else -1.0
				
				if is_bow:
					p.pos = ship.global_position + Vector3(0, 0.2, 0) + (forward * 5.0) + (right * side * 1.5)
					p.vel = (forward * speed * 0.12) + (right * side * randf_range(5.0, 10.0))
				else:
					# Sillage arrière (trail)
					p.pos = ship.global_position + Vector3(0, 0.1, 0) - (forward * 8.0) + (right * side * 2.0)
					p.vel = (-forward * speed * 0.05) + (right * side * randf_range(1.0, 3.0))
				
				p.life = 1.0 + randf_range(0.0, 1.2)
				p.max_life = p.life
				p.scale = randf_range(0.4, 2.5) if is_bow else randf_range(1.0, 4.0)
				p.vel.y = randf_range(0.3, 1.5)
				
				particle_index = (particle_index + 1) % MAX_PARTICLES

	# Update active particles
	for i in range(MAX_PARTICLES):
		var p = particles[i]
		if p.life > 0:
			p.life -= delta
			p.pos += p.vel * delta
			p.vel *= 0.96 
			p.vel.y -= 7.0 * delta # Gravity
			
			var progress = p.life / p.max_life
			var current_scale = p.scale * (1.1 + (1.0 - progress) * 0.5)
			var alpha = progress * 0.4
			
			var basis = Basis().scaled(Vector3(current_scale, current_scale * 0.5, current_scale))
			multimesh.set_instance_transform(i, Transform3D(basis, p.pos))
			multimesh.set_instance_color(i, Color(0.8, 0.9, 1.0, alpha))
		elif multimesh.get_instance_transform(i).origin.y > -500:
			multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))
