extends Node2D

const RAYONS = [60.0, 80.0, 100.0]

var _light:   PointLight2D
var _pulse_t: float = 0.0

func _ready() -> void:
	z_index = -1
	_light               = PointLight2D.new()
	_light.texture       = _creer_tex(128)
	_light.texture_scale = 1.8
	_light.energy        = 0.0
	_light.color         = Color(0.65, 0.05, 0.05)
	_light.blend_mode    = PointLight2D.BLEND_MODE_ADD
	_light.shadow_enabled = false
	add_child(_light)

func pulse() -> void:
	var niveau = _aura_niveau()
	if niveau <= 0:
		return
	_light.texture_scale = RAYONS[niveau - 1] / 38.0
	_pulse_t = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	var niveau  = _aura_niveau()
	var ambient = 0.07 if niveau > 0 else 0.0
	if _pulse_t > 0.0:
		_pulse_t = max(0.0, _pulse_t - delta * 1.8)
		_light.energy = ambient + _pulse_t * 0.42
		queue_redraw()
	elif abs(_light.energy - ambient) > 0.005:
		_light.energy = lerp(_light.energy, ambient, delta * 4.0)

func _draw() -> void:
	var niveau = _aura_niveau()
	if niveau <= 0:
		return
	var rayon = RAYONS[niveau - 1]
	# Anneau de bord — toujours visible en ambient
	var alpha_ring = 0.09 + _pulse_t * 0.28
	var width_ring = 1.2  + _pulse_t * 2.8
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 72, Color(0.85, 0.08, 0.08, alpha_ring), width_ring)
	# Remplissage léger seulement pendant le pulse
	if _pulse_t > 0.15:
		draw_circle(Vector2.ZERO, rayon, Color(0.55, 0.03, 0.03, _pulse_t * 0.045))

func _aura_niveau() -> int:
	var p = get_parent()
	if not p:
		return 0
	var v = p.get("aura_niveau")
	return v if v != null else 0

static func _creer_tex(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c   = size / 2.0
	for x in size:
		for y in size:
			var d = Vector2(x, y).distance_to(Vector2(c, c)) / c
			var a = maxf(0.0, 1.0 - d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)
