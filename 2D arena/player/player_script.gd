extends RigidBody2D
class_name Player

const OWIE = preload("res://2D arena/audio/owie.wav")

@onready var player_image: TextureRect = $"Player image"

@onready var stream: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var hold_pos: Marker2D = $"Hold position"


@onready var hinge: Node2D = $hinge
@onready var health_bar: ProgressBar = $hinge/HealthBar
@onready var name_label: Label = $hinge/NameLabel


@export var player_name: String = "player"
@export var max_health: float = 100
@export var health: float = 100:
	set(new_health):
		health = clampf(new_health, 0.0, max_health)#Clamp new_health between 0 & max_health.
		
		##Display health.
		if health_bar != null:
			var rest: float = health/ max_health
			
			health_bar.value = rest* 100.0
			health_bar.modulate = Color.RED.lerp(Color.GREEN, rest)
@export var regen: float = 7.0##Regen health per second
var dead: bool = false

@export var move_speed: float = 250.0
var move_direction: Vector2

var item_corepath: Dictionary
var item: Node2D

@export var dash_strength: float = 150.0
@export var dash_cooldown_time: float = 0.5
var dash_cooldown_timer: Timer = Timer.new()


func _ready() -> void:
	##print(server.role," Player ready!= ",player_name)
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)
	
	##Set Name Label
	name_label.text = player_name
	
	if !is_multiplayer_authority(): return
	body_entered.connect(collided_with_body)


func _input(_event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	if dead: return
	move_direction = Input.get_vector("a","d","w","s")
	
	#if dash_cooldown_timer.is_stopped():
		#if Input.is_action_just_pressed("dash"):
			#dash_cooldown_timer.start(dash_cooldown_time)
			#global_position += move_direction* dash_strength
	
	if item:
		if Input.is_action_pressed("activate"):
			item.activate.emit()
		
		if Input.is_action_just_pressed("action"):
			item.action.emit()
		
		if Input.is_action_just_pressed("drop"):
			server.echo(drop)


func _physics_process(delta: float) -> void:
	if dead: return
	
	if health < max_health:
		health += regen* delta
	
	##Rotate player to mouse position
	hinge.look_at(global_position+ Vector2(1.0, 0.0))
	
	
	if !is_multiplayer_authority(): return
	move_and_collide(move_direction* move_speed* delta)##Move
	look_at(get_viewport().get_mouse_position())##Look at mouse


func equip(new_item_corepath: Dictionary, authority: int):
	##print("\n"+server.role," equip | item corepath= ",new_item_corepath," | authority= ",authority)
	if dead: return##If not dead
	
	item_corepath = new_item_corepath
	item = server.get_corenode(item_corepath)
	
	if !is_instance_valid(item): 
		push_warning("Equipped invalid item!= ",item_corepath)
		return
	
	if !item is Item2D:
		push_warning("Tried to equip a non-item node!")
		return
	
	
	item.set_multiplayer_authority(authority)
	item.get_child(0).disabled = true
	item.can_equip = false
	
	
	item.reparent(self)##Reparent item to self
	item.transform = hold_pos.transform##Move to hold position


func drop():
	var item_to_drop: Node = server.get_corenode(item_corepath)##Get item path so newly joined peers dont get confused.
	##print("\n"+server.role+" dropping!= ",item_to_drop)
	if item_to_drop == null: return##Cant drop nothing
	
	item_to_drop.set_multiplayer_authority(1)
	item_to_drop.reparent(game.main_scene)
	item_to_drop.global_transform = hold_pos.global_transform##Move to held position
	
	item_to_drop.get_child(0).disabled = false
	item_to_drop.can_equip = true
	item = null
	item_corepath.clear()


func damage(dmg: float = 0.0):
	if dead or dmg <= 0.0: return
	health -= dmg
	stream.play()
	
	##Make server decide if player died or not.
	if multiplayer.is_server():
		if health <= 0.0:
			server.echo(died)##Kill player
			#server.kick_peer(get_multiplayer_authority(), "killed!")##Kick player


func died():
	#print("\n\n"+server.role+" ",self," died!\n\n")
	dead = true
	
	##Play died noise
	stream.stream = OWIE
	stream.play()
	
	##Show spawn menu for authority
	if is_multiplayer_authority():
		game.spawn_menu.show()
	
	##Delete player
	await server.wait(1.0)
	queue_free()


func collided_with_body(body: Node):
	if body is Item2D and item_corepath.is_empty():##Body is Item2D & not holding an item.
		##print(server.role," | item= ",body)
		##Echo 'equip' with binded arguments of core-path to body.
		server.echo(equip.bind(server.get_corepath(body), multiplayer.get_unique_id()))##Equip item
