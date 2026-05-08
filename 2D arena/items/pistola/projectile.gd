extends RigidBody2D

@onready var stream: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var damage: float = 10.0
@export var speed: float = 1000.0
var direction: Vector2 = Vector2.ZERO
var ignore: Array = []


##Fire from position in direction
func fire(pos: Vector2, new_direction: Vector2, new_damage: float, new_speed: float, new_ignore):
	global_position = pos
	direction = new_direction
	speed = new_speed
	ignore = new_ignore
	damage = new_damage
	
	global_rotation = get_angle_to(pos+ direction)
	
	
	body_entered.connect(hit)
	#server.delete_soon(self, 5.0)##If no hit then delete after 5 seconds


func _physics_process(delta: float) -> void:
	global_position += direction* speed* delta


func hit(body):
	##print(server.role+" Hit!= ",body," | ",ignore)
	if ignore.has(body): return
	
	if body.has_method("damage"):
		stream.play()
		if multiplayer.is_server():##Only registers damage server side.
			##print(server.role+" damage body= ",body,damage)
			server.echo(body.damage.bind(damage))
	queue_free()
