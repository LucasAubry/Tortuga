extends MultiMeshInstance3D

var particles: Array[Dictionary] = []
var player: Node3D = null

func _ready():
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = 500
	
	custom_aabb = AABB(Vector3(-100000, -1000, -100000), Vector3(200000, 2000, 200000))
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 30.0) # Thinner, more discreet streaks
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1) # Modulated by vertex color in MultiMesh
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1, 1)
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	multimesh.mesh = mesh
	
	for i in range(500):
		var pos = Vector3(randf_range(-20000, 20000), 50.0, randf_range(-20000, 20000))
		var life = randf_range(0.0, 1.0)
		particles.append({"pos": pos, "life": life})
		
		multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		multimesh.set_instance_color(i, Color(1, 1, 1, life * life * 0.2))

func _process(delta):
	if not player:
		# Locate player ship dynamically
		var world = get_tree().current_scene
		if world:
			var ship = world.get_node_or_null("Ship")
			if ship and ship.get("is_player"):
				player = ship

	# Get wind based on player position (similar to global wind in Raylib)
	var wind_dir = Vector2.ZERO
	var wind_strength = 1.0
	
	if player and player.get("is_wind_boost_active"):
		var forward = player.global_transform.basis.z
		wind_dir = Vector2(forward.x, forward.z).normalized()
		wind_strength = 8.0 # Très rapide visuellement
	else:
		var wind = GameConfig.get_wind_at(player.global_position if player else Vector3.ZERO)
		wind_dir = wind["direction"]
		wind_strength = wind["speed"]
	
	var wind_vec3 = Vector3(wind_dir.x, 0, wind_dir.y)
	var basis: Basis
	if wind_vec3.length_squared() > 0.001:
		basis = Basis.looking_at(wind_vec3, Vector3.UP)
	else:
		basis = Basis()
		
	for i in range(500):
		var p = particles[i]
		
		# Exactly matching Raylib Update logic:
		p.pos.x += wind_dir.x * (wind_strength * 200.0) * delta
		p.pos.z += wind_dir.y * (wind_strength * 200.0) * delta
		p.life -= delta * 0.1
		
		if p.life <= 0:
			p.life = 0.5 + randf_range(0.0, 0.5)
			if player:
				# Spawn uniformly around player so they never fall behind
				p.pos.x = player.global_position.x + randf_range(-2500, 2500)
				p.pos.z = player.global_position.z + randf_range(-2500, 2500)
				p.pos.y = 50.0
		
		# DrawLine3D in C++ draws from A to B. BoxMesh is centered.
		# Offset by half-length to perfectly replicate the visual starting point.
		var center_pos = p.pos + (wind_vec3 * 20.0)
		
		multimesh.set_instance_transform(i, Transform3D(basis, center_pos))
		
		# Very soft exponential fade so they disappear gently without popping
		var alpha = p.life * p.life * 0.2
		multimesh.set_instance_color(i, Color(1, 1, 1, alpha))
