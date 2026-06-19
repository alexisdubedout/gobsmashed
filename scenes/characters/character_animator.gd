class_name CharacterAnimator
extends RefCounted

## Contrôle le sprite unique d'un personnage (node "body").
## Usage :
##   var anim := CharacterAnimator.new()
##   anim.init(self)
##   anim.play("run", "left")

var _sprite: AnimatedSprite2D

func init(character: CharacterBody2D) -> void:
	_sprite = character.get_node_or_null("body") as AnimatedSprite2D

func play(anim: String, direction: String = "down") -> void:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return
	var full_name := anim + "_" + direction
	if not _sprite.sprite_frames.has_animation(full_name):
		return
	if _sprite.animation != full_name or not _sprite.is_playing():
		_sprite.play(full_name)

func stop() -> void:
	if is_instance_valid(_sprite):
		_sprite.stop()

func is_playing() -> bool:
	return is_instance_valid(_sprite) and _sprite.is_playing()

func is_finished() -> bool:
	return not is_playing()

func current_animation() -> String:
	if is_instance_valid(_sprite):
		return _sprite.animation
	return ""

static func expected_animations() -> Array[String]:
	var result: Array[String] = []
	for anim in ["idle", "run", "attack", "hurt", "die"]:
		for dir in ["up", "down", "left", "right"]:
			result.append(anim + "_" + dir)
	return result
