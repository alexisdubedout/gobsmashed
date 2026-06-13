class_name CharacterAnimator
extends RefCounted

## Synchronise toutes les couches visuelles d'un personnage en un seul appel.
## Usage :
##   var anim := CharacterAnimator.new()
##   anim.init(self)          # self = CharacterBody2D
##   anim.play("run", "left")

const LAYER_NAMES: Array[String] = [
	"shadow", "body", "clothes", "armor_chest", "armor_legs", "helmet", "weapon"
]

const ANIM_FRAME_COUNTS: Dictionary = {
	"idle":   4,
	"run":    6,
	"attack": 5,
	"hurt":   2,
	"die":    6,
}

const DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var _layers: Dictionary = {}  # layer_name -> AnimatedSprite2D

# Associe l'animator au CharacterBody2D donné.
# À appeler dans _ready() du personnage.
func init(character: CharacterBody2D) -> void:
	_layers.clear()
	for layer_name in LAYER_NAMES:
		var node = character.get_node_or_null(layer_name)
		if node is AnimatedSprite2D:
			_layers[layer_name] = node

# Joue l'animation sur toutes les couches visibles qui possèdent cette animation.
# anim      : "idle" | "run" | "attack" | "hurt" | "die"
# direction : "up" | "down" | "left" | "right"
func play(anim: String, direction: String = "down") -> void:
	var full_name: String = anim + "_" + direction
	for layer_name in _layers:
		var layer: AnimatedSprite2D = _layers[layer_name]
		if not layer.visible:
			continue
		if layer.sprite_frames == null:
			continue
		if layer.sprite_frames.has_animation(full_name):
			if layer.animation != full_name or not layer.is_playing():
				layer.play(full_name)

func stop() -> void:
	for layer_name in _layers:
		_layers[layer_name].stop()

func is_playing() -> bool:
	for layer_name in _layers:
		var layer: AnimatedSprite2D = _layers[layer_name]
		if layer.visible and layer.sprite_frames != null and layer.is_playing():
			return true
	return false

# Vrai si l'animation courante a atteint la dernière frame sur au moins une couche visible.
func is_finished() -> bool:
	for layer_name in _layers:
		var layer: AnimatedSprite2D = _layers[layer_name]
		if layer.visible and layer.sprite_frames != null:
			return not layer.is_playing()
	return true

# Retourne le nom complet de l'animation en cours (ex: "run_left").
func current_animation() -> String:
	for layer_name in _layers:
		var layer: AnimatedSprite2D = _layers[layer_name]
		if layer.visible and layer.sprite_frames != null:
			return layer.animation
	return ""

# Retourne la liste exhaustive des noms d'animations attendus.
# Utile pour vérifier qu'un SpriteFrames est complet.
static func expected_animations() -> Array[String]:
	var result: Array[String] = []
	for anim in ANIM_FRAME_COUNTS:
		for dir in DIRECTIONS:
			result.append(anim + "_" + dir)
	return result

# Retourne le nombre de frames attendu pour une animation donnée.
static func expected_frame_count(anim_base: String) -> int:
	return ANIM_FRAME_COUNTS.get(anim_base, 0)
