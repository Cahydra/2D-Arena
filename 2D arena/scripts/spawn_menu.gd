extends Control

@onready var name_field: TextEdit = $"panel container/MarginContainer/VBoxContainer/name_field"
@onready var spawn_button: Button = $"panel container/MarginContainer/VBoxContainer/spawn_button"


func _ready() -> void:
	spawn_button.pressed.connect(send_spawn_request)


func send_spawn_request():
	hide()
	spawn_button.release_focus()
	
	##Echo request_spawn request to server
	server.echo(game.main_scene.request_spawn.bind(multiplayer.get_unique_id(), name_field.text), 1)
