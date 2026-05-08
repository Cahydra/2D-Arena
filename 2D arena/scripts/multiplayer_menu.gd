extends Node

@onready var version: Label = $"CanvasLayer/Multiplayer Menu/version"

@onready var host: CheckBox = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Host_Join/host"
@onready var play_button: Button = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Host_Join/play_button"
@onready var cancel_button: Button = $"CanvasLayer/Multiplayer Menu/MainMenu/Connecting_menu/VBox/Cancel/cancel_button"

@onready var condition_label: Label = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Conditions/condition_label"
@onready var address: LineEdit = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Conditions/address"
@onready var server_size: LineEdit = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Conditions/size"

@onready var port: LineEdit = $"CanvasLayer/Multiplayer Menu/MainMenu/menu/VBox/Port/port"

@onready var menu: MarginContainer = $"CanvasLayer/Multiplayer Menu/MainMenu/menu"
@onready var connecting_menu: MarginContainer = $"CanvasLayer/Multiplayer Menu/MainMenu/Connecting_menu"

##Hide/show menu options depending on is_server status.
var is_server: bool:
	set(value):
		is_server = value
		host.button_pressed = value
		
		condition_label.text = "Size" if value else "Address"
		address.visible = !value
		server_size.visible = value
		
		play_button.text = "HOST" if value else "JOIN"
	get():
		return host.button_pressed


func _ready():
	version.text = server.version
	
	##Link check box buttons to do stuff.
	host.pressed.connect(func(): is_server = host.button_pressed)
	
	##Ready game when multiplayer goes alive.
	if server.is_alive: ready_game()
	server.accepted.connect(ready_game)
	
	##Hide multiplayer menu & show player menu.
	server.rejected.connect(func(_r): show_main_menu(true))


##Starts multiplayer with arguments when play gets pressed.
func play_pressed():
	if is_server:
		server.start_multiplayer(is_server, server_size.text, int(port.text))
	else:
		server.start_multiplayer(is_server, address.text, int(port.text))
		show_main_menu(false)


##Cancel multiplayer when cancel gets pressed.
func cancel_pressed() -> void:
	server.handle_rejection("cancel")##Cancel multiplayer with FAILED
	show_main_menu(true)


##Load Arena.
func ready_game():
	#print("ready game!= ",server.is_alive)
	if !server.is_alive: return
	if multiplayer.is_server():##Load Arena on server side.
		##Sync add Arena to clients.
		server.add(preload("res://2D arena/scenes/Arena.tscn").instantiate(), get_tree().root)
	
	##Remove main menu scene from both client & server.
	queue_free()


func show_main_menu(state: bool = false) -> void:
	menu.visible = state
	connecting_menu.visible = !state
