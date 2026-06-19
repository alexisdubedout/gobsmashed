@tool
extends Node2D

const FRAMES_PATH := "res://assets/sprites/placeholder/body_frames.tres"
const ANIMS := ["idle", "run", "attack", "hurt", "die"]
const DIRS := ["down", "up", "left", "right"]

const CELL_W := 90
const CELL_H := 110
const MARGIN := 60

func _ready() -> void:
	if not ResourceLoader.exists(FRAMES_PATH):
		push_error("Génère d'abord le SpriteFrames via Scripts/generate_body_sprite_frames.gd")
		return

	var sf: SpriteFrames = load(FRAMES_PATH)

	_add_label("direction →", MARGIN - 10, 10, true)
	_add_label("animation ↓", 10, MARGIN - 10, false)

	for col in DIRS.size():
		_add_label(DIRS[col], MARGIN + col * CELL_W + CELL_W / 2, 30, true)

	for row in ANIMS.size():
		_add_label(ANIMS[row], 10, MARGIN + row * CELL_H + CELL_H / 2, false)

		for col in DIRS.size():
			var anim_name := "%s_%s" % [ANIMS[row], DIRS[col]]
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = sf
			sprite.position = Vector2(
				MARGIN + col * CELL_W + CELL_W / 2,
				MARGIN + row * CELL_H + CELL_H / 2
			)
			sprite.scale = Vector2(1.5, 1.5)
			add_child(sprite)
			if sf.has_animation(anim_name):
				sprite.play(anim_name)


func _add_label(text: String, x: float, y: float, centered: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(CELL_W, 20)
		lbl.position.x -= CELL_W / 2.0
	add_child(lbl)
