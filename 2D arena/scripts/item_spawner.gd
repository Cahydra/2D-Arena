extends Node2D

@export var active: bool = true
@export var spawn_frequency: float = 1.0
@export var kill_frequency: float = 10.0
@export var items_to_spawn: Array = [
	"res://2D arena/items/rifle/rifle_scene.tscn",
	"res://2D arena/items/pistola/pistola_scene.tscn",
]


func _ready() -> void:
	if !active: return
	if items_to_spawn.size() != 0:
		##If server is alive and is a server then start spawning items.
		if server.is_alive && multiplayer.is_server(): start_loop()


##Server side item spawn loop
func start_loop() -> void:
	#print_debug("Started item spawn loop!")
	while true:
		await server.wait(spawn_frequency)
		var random_item_path: String = items_to_spawn[randi_range(0, items_to_spawn.size()-1)]
		
		var new_item: Node2D = spawn_item(random_item_path)
		
		
		await server.wait(kill_frequency)
		if is_instance_valid(new_item):##Make sure item is still valid.
			##If item is still a child of spawner then destroy
			if new_item.get_parent() == self:
				new_item.queue_free()


##Spawn item at path
func spawn_item(item_path: String) -> Node2D:
	#print(server.role+" "+name+" Spawned item= ",item_name)
	var new_item: RigidBody2D = load(item_path).instantiate()
	
	server.add(new_item, self)
	
	return new_item
