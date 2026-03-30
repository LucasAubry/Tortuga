extends Node3D
class_name GrapplingHookSystem

# --- SIGNALS ---
signal pull_started(target_pos: Vector3)
signal pull_ended()

# --- CONFIG ---
@export var rope_radius: float = 0.6
@export var aim_zone_width: float = 25.0
@export var aim_zone_length: float = 600.0
@export var min_distance: float = 50.0

# --- INTERNAL STATE ---
var is_active: bool = false
var is_launching: bool = false
var is_pulling: bool = false
var pull_duration: float = 0.0

var target_node: Node3D = null
var local_offset: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO

var current_launch_dist: float = 0.0
var current_sag: float = 0.0

# --- NODES ---
var _aim_pivot: Node3D
var _aim_mesh: MeshInstance3D
var _shape_cast: ShapeCast3D
var _rope_mesh: MeshInstance3D

func setup(parent_ship: Ship):
	# --- VISUAL AIMING ---
	_aim_pivot = Node3D.new()
	add_child(_aim_pivot)
	_aim_pivot.visible = false
	
	_aim_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(aim_zone_width, 1.5, aim_zone_length)
	_aim_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.7, 1.0, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mesh.material_override = mat
	_aim_pivot.add_child(_aim_mesh)
	_aim_mesh.position = Vector3(0, 0, -aim_zone_length / 2.0)
	
	# --- PHYSICS SHAPE ---
	_shape_cast = ShapeCast3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(aim_zone_width, 1.5, aim_zone_length)
	_shape_cast.shape = box_shape
	_shape_cast.target_position = Vector3(0, 0, 0)
	_shape_cast.enabled = true
	_shape_cast.add_exception(parent_ship)
	_aim_pivot.add_child(_shape_cast)
	_shape_cast.position = Vector3(0, 0, -aim_zone_length / 2.0)
	
	# --- ROPE VISUAL ---
	_rope_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = rope_radius
	cylinder.bottom_radius = rope_radius
	_rope_mesh.mesh = cylinder
	var l_mat = StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.3, 0.15, 0.05) # Dark Brown
	l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope_mesh.material_override = l_mat
	
	# Absolute root parenting for stability
	get_tree().root.add_child.call_deferred(_rope_mesh)
	_rope_mesh.visible = false

func update_aiming(ship_pos: Vector3, mouse_intersection: Vector3):
	_aim_pivot.visible = true
	_aim_pivot.global_position = ship_pos + Vector3.UP * 3.0
	
	var dir = (mouse_intersection - ship_pos)
	dir.y = 0
	if dir.length() > 5.0:
		var target_look = ship_pos + dir.normalized() * 1000.0
		_aim_pivot.look_at(target_look, Vector3.UP)
	
	_shape_cast.force_shapecast_update()

func hide_aiming():
	_aim_pivot.visible = false

func fire():
	if is_pulling or is_launching: return false
	
	# Default miss target
	var forward = -_aim_pivot.global_transform.basis.z
	var final_pos = _aim_pivot.global_position + (forward * aim_zone_length)
	var final_dist = aim_zone_length
	var will_hit = false
	
	if _shape_cast.is_colliding():
		var col = _shape_cast.get_collider(0)
		var is_valid = col.is_in_group("ship") or col.is_in_group("island") or (col is PhysicsBody3D and col.name != "OceanFloor")
		if not is_valid and col.get_parent():
			var p = col.get_parent()
			is_valid = p.is_in_group("ship") or p.is_in_group("island")
			
		if is_valid:
			var hit = _shape_cast.get_collision_point(0)
			var d = (hit - _aim_pivot.global_position).length()
			if d > min_distance:
				final_pos = hit
				final_dist = d
				will_hit = true
				target_node = col
				local_offset = col.global_transform.affine_inverse() * hit
	
	_initiate_launch(final_pos, final_dist, will_hit)
	return true # Consumed action

func _initiate_launch(pos: Vector3, dist: float, will_hit: bool):
	is_launching = true
	is_pulling = false
	target_pos = pos
	current_launch_dist = 0.0
	current_sag = 2.0
	_rope_mesh.visible = true
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_launch_dist", dist, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if will_hit:
		tween.chain().tween_callback(func(): 
			is_launching = false
			is_pulling = true
			pull_duration = 2.5
			pull_started.emit(target_pos)
		)
		tween.chain().tween_property(self, "current_sag", 0.0, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		tween.chain().tween_property(self, "current_sag", 4.0, 0.3)
		tween.chain().tween_callback(func(): 
			is_launching = false
			_rope_mesh.visible = false
		)

func cancel():
	is_pulling = false
	is_launching = false
	_rope_mesh.visible = false
	pull_ended.emit()

func process_and_get_pull_force(delta: float, current_pos: Vector3, boat_velocity: Vector3) -> Vector3:
	if not is_pulling and not is_launching: 
		_rope_mesh.visible = false
		return Vector3.ZERO
		
	# TRACKING
	if is_instance_valid(target_node):
		target_pos = target_node.global_transform * local_offset
	
	# VISUAL UPDATE
	_update_visual_line(current_pos)
	
	# PHYSICS
	if is_pulling:
		pull_duration -= delta
		var to_target = target_pos - current_pos
		var dist = to_target.length()
		
		if dist < 40.0 or pull_duration <= 0:
			cancel()
			return Vector3.ZERO
			
		var pull_dir = to_target.normalized()
		var force = pull_dir * 30.0 # Pull Force
		
		# Damping
		var vel_along = boat_velocity.dot(pull_dir)
		if vel_along < 0:
			force += pull_dir * (-vel_along * 0.2)
			
		return force
		
	return Vector3.ZERO

func _update_visual_line(ship_pos: Vector3):
	var start = ship_pos + Vector3.UP * 2.0 # Deck Anchor
	var full_vec = (target_pos - start)
	var end = start + full_vec.normalized() * current_launch_dist if is_launching else target_pos
	
	var vec = (end - start)
	var d = vec.length()
	if d < 0.1: return
	
	_rope_mesh.global_position = start + vec / 2.0
	if not is_pulling: _rope_mesh.global_position.y -= current_sag
	
	if _rope_mesh.mesh is CylinderMesh:
		_rope_mesh.mesh.height = d
		
	_rope_mesh.look_at(end, Vector3.UP)
	_rope_mesh.rotate_object_local(Vector3.RIGHT, PI/2.0)
	_rope_mesh.visible = true
