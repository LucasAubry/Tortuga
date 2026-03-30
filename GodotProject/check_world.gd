@tool
extends SceneTree

func _init():
    var world = load("res://scenes/World.tscn")
    if world:
        print("World loaded successfully.")
    else:
        print("Failed to load World.")
    quit()
