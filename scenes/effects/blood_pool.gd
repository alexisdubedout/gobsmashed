class_name BloodPool
extends Node2D

var radius := 20.0

const TEXTURE_PATH := "res://assets/effects/bloodhit_128x128.png"
const HFRAMES := 9
const VFRAMES := 7
const ACTIVE_FRAMES := 39
const FPS := 18.0

var _sprite: Sprite2D
var _elapsed := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEXTURE_PATH)
	_sprite.hframes = HFRAMES
	_sprite.vframes = VFRAMES
	_sprite.frame = 0
	_sprite.scale = Vector2(radius / 40.0, radius / 40.0)
	add_child(_sprite)

func _process(delta: float) -> void:
	_elapsed += delta
	var frame := int(_elapsed * FPS)
	if frame >= ACTIVE_FRAMES:
		queue_free()
		return
	_sprite.frame = frame
