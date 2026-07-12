extends Node2D

const FILL_RATES: Array = [2.0, 3.5, 5.0, 7.0]  # pièces/sec selon coffre_regen_niveau
const RAYON:      float = 150.0

var player_inside: bool  = false
var _fill_acc:     float = 0.0
var _visuals:      Node2D

func _ready():
	add_to_group("coffre")
	_construire_visuel()

func _construire_visuel():
	_visuals = Node2D.new()
	add_child(_visuals)

	# Indicateur de zone
	_ajouter_cercle(RAYON, Color(0.78, 0.57, 0.16, 0.06), Color("#c9922a", 0.35), 2.0)

	# Corps (plus grand)
	var corps = ColorRect.new()
	corps.size = Vector2(48, 34)
	corps.position = Vector2(-24, -34)
	corps.color = Color("#5c3d1a")
	_visuals.add_child(corps)

	# Couvercle
	var couvercle = ColorRect.new()
	couvercle.size = Vector2(54, 14)
	couvercle.position = Vector2(-27, -52)
	couvercle.color = Color("#7a5228")
	_visuals.add_child(couvercle)

	# Serrure
	var serrure = ColorRect.new()
	serrure.size = Vector2(11, 11)
	serrure.position = Vector2(-5, -29)
	serrure.color = Color("#e8c84b")
	_visuals.add_child(serrure)

	# Bandes latérales
	for dx in [-24, 20]:
		var bande = ColorRect.new()
		bande.size = Vector2(4, 34)
		bande.position = Vector2(dx, -34)
		bande.color = Color("#c9922a", 0.7)
		_visuals.add_child(bande)

	# Label flottant au-dessus
	var lbl = Label.new()
	lbl.text = "COFFRE"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#e8c84b"))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-27, -68)
	lbl.size = Vector2(54, 16)
	_visuals.add_child(lbl)

func _ajouter_cercle(rayon: float, fill: Color, stroke: Color, width: float) -> void:
	var pts  = PackedVector2Array()
	var segs = 32
	for i in segs:
		var a = (float(i) / segs) * TAU
		pts.append(Vector2(cos(a), sin(a)) * rayon)

	var poly = Polygon2D.new()
	poly.polygon = pts
	poly.color   = fill
	add_child(poly)

	var lpts = pts.duplicate()
	lpts.append(pts[0])
	var line = Line2D.new()
	line.points        = lpts
	line.default_color = stroke
	line.width         = width
	add_child(line)

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player_inside = false
		return

	player_inside = global_position.distance_to(player.global_position) < RAYON

	if player_inside:
		_fill_acc += delta
		var niv: int = clampi(player.get("coffre_regen_niveau") if player.get("coffre_regen_niveau") != null else 0, 0, 3)
		if _fill_acc >= 1.0 / FILL_RATES[niv]:
			_fill_acc = 0.0
			player.ajouter_bourse(1)

	# Pulse doré quand actif
	if _visuals:
		if player_inside:
			var t = (sin(Time.get_ticks_msec() * 0.003) + 1.0) * 0.5
			_visuals.modulate = Color.WHITE.lerp(Color(1.2, 1.0, 0.6), t * 0.4)
		else:
			_visuals.modulate = Color.WHITE
