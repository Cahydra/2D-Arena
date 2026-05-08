extends Item2D
class_name Rifle2D

const CASING = preload("res://2D arena/items/pistola/casing.tscn")
const PROJECTILE = preload("res://2D arena/items/pistola/projectile.tscn")

const RIFLE_CASING_TEXTURE = preload("res://2D arena/items/rifle/rifle_casing.png")

const RIFLE_RELOADA_SFX = preload("res://2D arena/items/rifle/rifle_reloada.wav")
const GUN_SHOT_SOUND_SFX = preload("res://2D arena/items/rifle/gun_shot_sound.wav")

@onready var stream: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var muzzle_flash: Node2D = $muzzle_flash
@onready var barrel: Node2D = $barrel


@export var damage: float = 36.0

@export var bullets: int = 31##Current amount in magazine
@export var capacity: int = 31##Full magazine

@export var reload_time: float = 1.85
@export var shoot_wait_time: float = 0.098

var cool_down: bool = false


func _ready() -> void:
	activate.connect(server.echo.bind(shoot))
	action.connect(server.echo.bind(reload))


func shoot():
	if bullets <= 0: return
	if cool_down: return
	
	cool_down = true
	bullets -= 1
	
	stream.stream = GUN_SHOT_SOUND_SFX
	stream.play()
	
	flash()
	
	var new_projectile = PROJECTILE.instantiate()
	game.main_scene.add_child(new_projectile)
	new_projectile.fire(barrel.global_position, Vector2.from_angle(global_rotation), damage, 2000.0, [self.get_parent()])
	
	var new_casing = CASING.instantiate()
	game.main_scene.visuals.add_child(new_casing)##Add casing to visuals
	new_casing.throw_casing(RIFLE_CASING_TEXTURE, global_position, Vector2(randf_range(-1, 1), randf_range(-1, 1))* 200.0, randf_range(-1, 1)* 40.0, 5.0)
	
	
	await server.wait(shoot_wait_time)##This can desync cool_down
	cool_down = false



func flash():
	muzzle_flash.visible = true
	await server.wait(0.07)
	muzzle_flash.visible = false


func reload():
	if cool_down: return
	cool_down = true
	stream.stream = RIFLE_RELOADA_SFX
	stream.play()
	
	await server.wait(reload_time)##This can desync values so make sure to sync values afterwards.
	
	##Sync bullets and cool_down from server side to everyone.
	if multiplayer.is_server():
		server.forward({self: {"bullets": capacity,"cool_down": false}})
