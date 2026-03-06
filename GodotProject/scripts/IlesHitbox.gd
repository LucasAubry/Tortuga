extends Node3D

func _ready():
	# Automatically generate perfect trimesh physics for the island model
	for child in get_children():
		if child is MeshInstance3D:
			child.create_trimesh_collision()
