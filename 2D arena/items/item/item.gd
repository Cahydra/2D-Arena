extends RigidBody2D
class_name Item2D
##NOTE Item acts as a puppet inside players.

@export var icon: Texture = preload("res://2D arena/textures/MissingTexture.png")

@export_multiline var description: String = ""

@export var can_equip: bool = true

@warning_ignore("unused_signal")
signal activate()
@warning_ignore("unused_signal")
signal action()
