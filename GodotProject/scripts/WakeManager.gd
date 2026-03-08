extends MultiMeshInstance3D

var particles: Array[Dictionary] = []
var player: Node3D = null

const MAX_PARTICLES = 400 # Optimized for realistic bow waves
var particle_index = 0
var spawn_timer = 0.0

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
	# On cherche tous les navires (joueur et ennemis)
	var ships = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies")
	
	# Fallback robuste : si les groupes sont vides (ex: chargement), on cherche par nom
	if ships.is_empty():
		var scene_root = get_tree().current_scene
		if scene_root:
			for child in scene_root.get_children():
				if child.has_method("take_damage"): # Signature d'un navire
					ships.append(child)
	
	for ship in ships:
		if not is_instance_valid(ship): continue
		
		# On autorise l'écume dès qu'on s'approche de la surface (-10m au lieu de -5m)
		# Cela permet d'avoir les particules déjà présentes PILE au moment où on sort
		var depth = ship.get("current_dive_depth")
		if depth != null and depth < -10.0: 
			continue
		
		var speed = ship.get("ship_speed")
		if speed != null and speed > 5.0:
			# Calcul du nombre de particules à spawn selon la vitesse
			var spawn_rate = int((speed / 100.0) * 8.0) + 1
			for i in range(spawn_rate):
				var p = particles[particle_index]
				
				# Direction du navire
				var ship_basis = ship.global_transform.basis
				var forward = ship_basis.z.normalized()
				var right = ship_basis.x.normalized()
				
				# Position à l'avant (bow)
				var bow_pos = ship.global_position + Vector3(0, 0.4, 0) + (forward * 5.0)
				var side = 1.0 if (particle_index % 2 == 0) else -1.0
				
				# Initialisation de la particule
				p.pos = bow_pos + (right * side * 1.5)
				p.life = 1.5 + randf_range(0.0, 1.0)
				p.max_life = p.life
				p.scale = randf_range(0.5, 2.0)
				
				# Vélocité : un peu vers l'avant et pas mal sur les côtés
				p.vel = (forward * speed * 0.15) + (right * side * randf_range(6.0, 12.0))
				p.vel.y = randf_range(0.5, 2.0)
				
				particle_index = (particle_index + 1) % MAX_PARTICLES

	# Update all particles
	for i in range(MAX_PARTICLES):
		var p = particles[i]
		if p.life > 0:
			p.life -= delta
			p.pos += p.vel * delta
			p.vel *= 0.98 # Friction, particles slow down quickly in water
			p.vel.y -= 5.0 * delta # Gravity
			
			var progress = p.life / p.max_life
			var current_scale = p.scale * (1.5 - progress * 0.5) # Expand slightly as it dissipates
			var alpha = progress * progress * 0.25 # Extremely gentle quadratic fade-out
			
			# Massively flatten the sphere on the Y axis so it looks like a 2D puddle/foam patch
			var basis = Basis().scaled(Vector3(current_scale, current_scale * 0.1, current_scale))
			multimesh.set_instance_transform(i, Transform3D(basis, p.pos))
			multimesh.set_instance_color(i, Color(0.8, 0.9, 1.0, max(0.0, alpha)))
		else:
			# Hide dead particles
			multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))
