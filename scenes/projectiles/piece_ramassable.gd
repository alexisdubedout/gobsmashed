extends Node2D

const EXPIRY        := 7.0
const MAGNET_RANGE  := 130.0

var valeur: int = 1
var _bob:        float = 0.0
var _pos_y_init: float = 0.0
var _age:        float = 0.0
var _magnetized: bool  = false

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
	_age += delta

	if _age >= EXPIRY:
		queue_free()
		return

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < MAGNET_RANGE:
			_magnetized = true
		if _magnetized:
			# Accélération quadratique : rapide au contact, douce au bord
			var t = clampf(1.0 - dist / MAGNET_RANGE, 0.0, 1.0)
			var pull = lerp(120.0, 550.0, t * t)
			global_position = global_position.move_toward(player.global_position, pull * delta)
			_pos_y_init = global_position.y  # évite que le bob lutte contre le mouvement
		if dist < 14.0:
			var bonus = 1 if player.get("filon_bonus_actif") and randf() < 0.25 else 0
			player.ajouter_bourse(valeur + bonus)
			queue_free()
			return

	# Bob uniquement hors magnétisme
	if not _magnetized:
		_bob += delta
		global_position.y = _pos_y_init + sin(_bob * 4.0) * 3.0

	# Fade + shrink dans les 2 dernières secondes
	var remaining = EXPIRY - _age
	if remaining < 2.0 and not _magnetized:
		var t = remaining / 2.0
		modulate.a = t
		scale = Vector2(t, t)
