extends Node2D

const NB      = 3
const RAYON   = 28.0
const VITESSE = 1.8
const OFFSET  = Vector2(0, -14)

var _angle: float = 0.0
var _icones: Array = []

static func _creer_tex(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c = size / 2.0
	for x in size:
		for y in size:
			var d = Vector2(x, y).distance_to(Vector2(c, c)) / c
			var a = maxf(0.0, 1.0 - d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)

func _ready():
	z_index = 2
	for i in NB:
		var lbl = Label.new()
		lbl.text = "⭐"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.position = Vector2.ZERO
		add_child(lbl)
		_icones.append(lbl)

	var light = PointLight2D.new()
	light.texture       = _creer_tex(64)
	light.texture_scale = 2.2
	light.energy        = 1.0
	light.color         = Color("#ffcc33")
	light.blend_mode    = PointLight2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	add_child(light)

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(light, "energy", 0.3, 0.85).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(light, "energy", 1.6, 0.85).set_ease(Tween.EASE_IN_OUT)

func _process(delta):
	_angle += delta * VITESSE
	for i in NB:
		var a = _angle + i * TAU / NB
		_icones[i].position = OFFSET + Vector2(cos(a), sin(a)) * RAYON - Vector2(5, 5)
