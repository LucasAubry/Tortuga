extends Node3D

func _ready():
	if has_node("CPUParticles3D"):
		$CPUParticles3D.emitting = true
	
	# Auto-destroy faster
	await get_tree().create_timer(1.0).timeout
	queue_free()
