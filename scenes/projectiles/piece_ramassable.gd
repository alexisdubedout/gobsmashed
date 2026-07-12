extends Node2D

var valeur: int = 1
var _bob: float = 0.0
var _pos_y_init: float = 0.0

func _ready():
	add_to_group("piece_ramassable")
	_pos_y_init = global_position.y
	_construire_visuel()

func _construire_visuel():
	var outer = ColorRect.new()
	outer.size = Vector2(12, 12)
	outer.position = Vector2(-6, -6)
	outer.color = Color("#e8c84b")
	add_child(outer)

	var inner = ColorRect.new()
	inner.size = Vector2(6, 6)
	inner.position = Vector2(-3, -3)
	inner.color = Color("#c9922a")
	add_child(inner)

	var light = PointLight2D.new()
	light.texture        = _creer_tex_lumiere(32)
	light.texture_scale  = 1.2
	light.energy         = 0.8
	light.color          = Color(0.96, 0.78, 0.15)
	light.blend_mode     = PointLight2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	add_child(light)

static func _creer_tex_lumiere(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c   = size / 2.0
	for x in size:
		for y in size:
			var d = Vector2(x, y).distance_to(Vector2(c, c)) / c
			var a = maxf(0.0, 1.0 - d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)

func _process(delta):
	_bob += delta
	global_position.y = _pos_y_init + sin(_bob * 4.0) * 3.0

	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 65.0:
		player.ajouter_bourse(valeur)
		queue_free()
