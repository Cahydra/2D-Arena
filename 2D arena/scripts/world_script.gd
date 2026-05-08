extends Node2D

const PLAYER = preload("res://2D arena/player/player.tscn")

@export var visuals: Node2D

var test: Dictionary[Node,PackedStringArray]

func _ready() -> void:
	game.spawn_menu = $CanvasLayer/spawn_menu
	game.main_scene = self
	
	##Server side
	if multiplayer.is_server():
		server.allow_echo(request_spawn)
		multiplayer.peer_disconnected.connect(remove_player)


func request_spawn(authority: int, text: String) -> void:
	##print(authority," requested spawn= ",text)
	#var sender_id_authority: int = multiplayer.get_remote_sender_id()
	spawn_player(authority, text)


func spawn_player(authority: int, player_name: String) -> void:
	#print("\n"+server.role+" spawn_player | authority= ",authority," | player_name= ",player_name)
	##Create new player for requesting peer.
	var new_PLAYER: Player = PLAYER.instantiate()
	
	
	##Random spawn position for player.
	var random_spawn_position: Vector2 = game.spawns[randi_range(0, game.spawns.size()-1)].global_position
	
	
	##Add player to sync and give it custom properties.
	server.add(new_PLAYER, game.main_scene, authority, {"player_name": player_name, "health": 100.0, "position": random_spawn_position, "item_corepath": {}})
	
	
	##Sets player data on server.
	if multiplayer.is_server():
		server.peers[authority]["player"] = new_PLAYER


func remove_player(peer_id: int) -> void:
	##print(server.role," remove player= ",peer_id)
	if server.peers[peer_id].has("player"):
		var player: Node = server.peers[peer_id]["player"]
		if is_instance_valid(player):##Make sure peers player is valid
			player.queue_free()##Delete player.
