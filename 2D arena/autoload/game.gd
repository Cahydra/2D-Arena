extends Node

const MAIN_MENU = preload("res://2D arena/scenes/Main Menu.tscn")

var spawns: Array[Node2D]

var spawn_menu: Control

##Keep track of world.
var main_scene: Node

##Handle rejection by going back to the main menu.
func _ready() -> void:
	server.rejected.connect(
		func(reason: String = ""):
			if reason != "cancel" and reason != "timeout":##If you did not cancel connection attempt then open main menu.
				##Clean up after getting rejected.
				if main_scene != null: main_scene.queue_free()##Delete old world to make room for main menu. (we manually delete the world since we are no longer connected to a server)
				spawns.clear()##Clear spawns that are all null now.
				get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
				OS.alert("Lost connection! reason= "+reason)
	)
