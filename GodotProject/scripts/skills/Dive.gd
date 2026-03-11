class_name Dive
extends WeaponData

# On garde les constantes ici
const DIVE_DEPTH: float = -60.0
const SURFACING_THRESHOLD: float = -2.0

func _init():
	type = ActionType.DIVE
	can_be_used_underwater = true

# --- ACTIVATION ---
func activate(ship: Node3D):
	# On évite le casting "as Ship" qui peut bugger pendant les renommages
	if "is_diving" in ship:
		ship.is_diving = !ship.is_diving
		ship.dive_delay_timer = 0.2
		print("<<< Skill Dive Toggle: ", ship.is_diving, " >>>")

# --- LOGIQUE PAR FRAME ---
var _underwater_tint: ColorRect = null

func process_tick(ship: Node3D, delta: float):
	if not ship.get("is_player"): return
	
	var target_depth = DIVE_DEPTH if ship.is_diving else 0.0
	var anim_factor = clamp(abs(ship.current_dive_tilt) / 0.65, 0.05, 1.0)
	var lerp_speed = anim_factor * 0.8
	
	# Calcul de la profondeur cible (la position sera appliquée dans post_physics_tick)
	ship.current_dive_depth = lerp(ship.current_dive_depth, target_depth, delta * lerp_speed)
	
	# --- GESTION DES EFFETS VISUELS ---
	_update_vfx(ship, delta)
	
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

# --- APPLICATION DE LA POSITION (après move_and_slide pour ne pas être écrasé) ---
func post_physics_tick(ship: Node3D, delta: float):
	if not ship.get("is_player"): return
	ship.global_position.y = ship.current_dive_depth

# --- SYSTÈME D'EFFETS (VFX) ---
func _update_vfx(ship: Node3D, delta: float):
	# Désactivation si on est à la surface
	if ship.current_dive_depth >= -1.0:
		if _underwater_tint: _underwater_tint.color.a = 0.0
		return

	# 1. Overlay Bleu Simple (ColorRect)
	if _underwater_tint == null:
		var canvas = CanvasLayer.new()
		canvas.layer = 10
		
		_underwater_tint = ColorRect.new()
		_underwater_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_underwater_tint.color = Color(0.05, 0.2, 0.4, 0.0) # Bleu marin doux
		_underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(_underwater_tint)
		ship.add_child(canvas)
	
	# Intensité TRÈS DOUCE (max 0.25 d'alpha pour ne pas boucher la vue)
	var target_alpha = clamp(abs(ship.current_dive_depth) / 60.0, 0.0, 0.25)
	_underwater_tint.color.a = lerp(_underwater_tint.color.a, target_alpha, delta * 2.0)

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
