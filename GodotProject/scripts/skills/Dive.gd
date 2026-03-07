class_name Dive
extends WeaponData

# On garde les constantes ici
const DIVE_DEPTH: float = -60.0
const SURFACING_THRESHOLD: float = -2.0

func _init():
	type = ActionType.DIVE

# --- ACTIVATION ---
func activate(ship: Node3D):
	# On évite le casting "as Ship" qui peut bugger pendant les renommages
	if "is_diving" in ship:
		ship.is_diving = !ship.is_diving
		ship.dive_delay_timer = 0.2
		print("<<< Skill Dive Toggle: ", ship.is_diving, " >>>")

# --- LOGIQUE PAR FRAME ---
func process_tick(ship: Node3D, delta: float):
	# On évite que l'IA ne fasse n'importe quoi (si besoin)
	if not ship.get("is_player"): return
	
	var target_depth = DIVE_DEPTH if ship.is_diving else 0.0
	
	# Transition de la profondeur (Basée sur l'inclinaison pour le réalisme)
	# Plus le bateau est incliné, plus il plonge/remonte vite (effet d'inertie)
	var anim_factor = clamp(abs(ship.current_dive_tilt) / 0.65, 0.05, 1.0)
	var lerp_speed = anim_factor * 1.5
	
	ship.current_dive_depth = lerp(ship.current_dive_depth, target_depth, delta * lerp_speed)
	
	# VERROUILLAGE : Toujours appliquer la profondeur calculée
	ship.global_position.y = ship.current_dive_depth
	
	# --- GESTION DE L'INDICATEUR ---
	var indicator = ship.get_node_or_null("SurfaceIndicator")
	if not indicator:
		_create_indicator(ship)
		indicator = ship.get_node_or_null("SurfaceIndicator")
	
	if indicator:
		indicator.global_position.y = 0.5
		indicator.global_position.x = ship.global_position.x
		indicator.global_position.z = ship.global_position.z
		indicator.visible = ship.current_dive_depth < SURFACING_THRESHOLD

	# --- CORRECTION CAMERA ---
	var spring_arm = ship.get_node_or_null("CameraGimbal/SpringArm3D")
	if spring_arm:
		spring_arm.collision_mask = 0 if ship.current_dive_depth < SURFACING_THRESHOLD else 1

	# --- CALCUL DE L'INCLINAISON ---
	var depth_diff = target_depth - ship.current_dive_depth
	var target_tilt = clamp(-depth_diff * 0.025, -0.65, 0.65)
	ship.current_dive_tilt = lerp(ship.current_dive_tilt, target_tilt, delta * 2.5)

# --- BLOCAGE D'ACTIONS ---
func is_action_blocked(ship: Node3D) -> bool:
	var s = ship as Ship
	if not s: return false
	return s.current_dive_depth < SURFACING_THRESHOLD

# --- OUTILS ---
func _create_indicator(ship: Node3D):
	var indicator = MeshInstance3D.new()
	indicator.name = "SurfaceIndicator"
	var quad = QuadMesh.new()
	quad.size = Vector2(100.0, 100.0)
	indicator.mesh = quad
	indicator.rotation_degrees.x = -90
	
	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode blend_mix, unshaded, cull_disabled;
		void fragment() {
			float dist = distance(UV, vec2(0.5));
			float alpha = pow(smoothstep(0.5, 0.0, dist), 2.5);
			ALBEDO = vec3(0.002, 0.01, 0.05);
			ALPHA = alpha * 0.4;
		}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	indicator.material_override = mat
	ship.add_child(indicator)
