extends Node2D

const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")

# Rayon de soin du lit (passif)
const LIT_RAYON = 120.0
const LIT_HEAL_INTERVAL = 3.0

# Tourelle
const TOURELLE_RAYON = 350.0
const TOURELLE_DELAY = 1.8

var player = null
var lit_timer = 0.0
var tourelle_timer = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	_construire_visuels()

func _construire_visuels():
	# Sol de la base — cercle sombre au sol
	var sol = _creer_cercle(80, Color("#2a1f0e"), Color("#c9922a", 0.5), 3)
	add_child(sol)

	# Structure centrale — simple carré pour placeholder
	var structure = ColorRect.new()
	structure.size = Vector2(40, 40)
	structure.position = Vector2(-20, -36)
	structure.color = Color("#5c3d1a")
	add_child(structure)

	# Toit
	var toit = ColorRect.new()
	toit.size = Vector2(50, 12)
	toit.position = Vector2(-25, -50)
	toit.color = Color("#3a2510")
	add_child(toit)

	# Tourelle (visible seulement si achetée)
	if GameState.objets_base["tourelle"]:
		_ajouter_tourelle_visuel()

	# Lit (visible seulement si acheté)
	if GameState.objets_base["lit"]:
		_ajouter_lit_visuel()

	# Piège (visible seulement si acheté)
	if GameState.objets_base["piege"]:
		_ajouter_piege_visuel()

func _ajouter_tourelle_visuel():
	var base_tourelle = ColorRect.new()
	base_tourelle.size = Vector2(14, 14)
	base_tourelle.position = Vector2(18, -46)
	base_tourelle.color = Color("#8b6914")
	add_child(base_tourelle)

	var canon = ColorRect.new()
	canon.size = Vector2(6, 20)
	canon.position = Vector2(22, -62)
	canon.color = Color("#c9922a")
	add_child(canon)

func _ajouter_lit_visuel():
	var lit = ColorRect.new()
	lit.size = Vector2(20, 12)
	lit.position = Vector2(-34, -28)
	lit.color = Color("#6b3a1f")
	add_child(lit)

	# Indicateur de rayon de soin (cercle discret)
	var rayon = _creer_cercle(LIT_RAYON, Color(0, 0, 0, 0), Color("#88dd88", 0.12), 1)
	add_child(rayon)

func _ajouter_piege_visuel():
	# Quelques petites croix autour de la base
	for angle_deg in [0, 90, 180, 270]:
		var angle = deg_to_rad(angle_deg)
		var pos = Vector2(cos(angle), sin(angle)) * 70
		var spike = ColorRect.new()
		spike.size = Vector2(8, 8)
		spike.position = pos - Vector2(4, 4)
		spike.color = Color("#8b6914")
		add_child(spike)

func _physics_process(delta):
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Lit — soin passif si le joueur est dans le rayon
	if GameState.objets_base["lit"]:
		lit_timer += delta
		if lit_timer >= LIT_HEAL_INTERVAL:
			lit_timer = 0.0
			var dist = global_position.distance_to(player.global_position)
			if dist <= LIT_RAYON:
				player.current_hp = min(player.max_hp, player.current_hp + 2)

	# Tourelle — tire sur l'ennemi le plus proche dans le rayon
	if GameState.objets_base["tourelle"]:
		tourelle_timer += delta
		if tourelle_timer >= TOURELLE_DELAY:
			tourelle_timer = 0.0
			_tourelle_tirer()

func _tourelle_tirer():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var closest_dist = INF
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist <= TOURELLE_RAYON:
			closest_dist = dist
			closest = enemy
	if closest == null:
		return

	var coin = COIN_SCENE.instantiate()
	var dir = (closest.global_position - global_position).normalized()
	coin.global_position = global_position + dir * 30.0
	coin.direction = dir
	coin.damage = int(10 * GameState.get_degats_bonus())
	get_tree().current_scene.add_child(coin)

# Dessine un cercle via _draw (pour les indicateurs visuels)
func _creer_cercle(rayon: float, fill: Color, stroke: Color, stroke_width: float) -> Node2D:
	var node = Node2D.new()
	var points = PackedVector2Array()
	var segments = 32
	for i in segments:
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * rayon)

	var poly = Polygon2D.new()
	poly.polygon = points
	poly.color = fill
	node.add_child(poly)

	var line_points = points.duplicate()
	line_points.append(points[0])
	var line = Line2D.new()
	line.points = line_points
	line.default_color = stroke
	line.width = stroke_width
	node.add_child(line)

	return node
