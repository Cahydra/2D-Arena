extends Sprite2D

@onready var stream: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var audios: Array[AudioStreamWAV]

var velocity: Vector2 = Vector2.ONE
var spin: float = 1.0
@export var drag: float = 0.99


func _physics_process(delta: float) -> void:
	global_position += velocity* delta
	global_rotation += spin* delta
	
	spin *= drag
	velocity *= drag


func throw_casing(new_texture: Texture2D, pos: Vector2, new_vel: Vector2, new_spin: float, life: float):
	texture = new_texture
	global_position = pos
	velocity = new_vel
	spin = new_spin
	
	await server.wait(randf_range(0.1, 0.9))
	stream.stream = audios[randi_range(0, audios.size()-1)]
	stream.play()
	
	await server.wait(life)
	queue_free()
