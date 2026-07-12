extends Node2D

const PLAYER_SCENE = preload("res://scenes/boss_fight/player_platformer.tscn")
const BOSS_SCENE   = preload("res://scenes/boss_fight/boss_platformer.tscn")

const ARENA_H        = 600.0
const GROUND_Y       = 500.0
const PLAT_H         = 18.0
const PLATFORM_COLOR = Color("#4a3018")
const PLATFORM_EDGE  = Color("#7a5828")

const BOSS_THEME_COLORS := {
	"guerrier": Color("#cc3322"),
	"mage":     Color("#7755ee"),
	"paladin":  Color("#bb9900"),
	"elf":      Color("#228855"),
}

# Largeur dynamique — calculée depuis le profil du boss
var arena_w: float = 800.0

var player_node: CharacterBody2D
var boss_node: CharacterBody2D
var hud_player_bar: ProgressBar
var hud_boss_bar: ProgressBar
var hud_phase_label: Label
var dash_btn_bg: ColorRect
var dash_cd_lbl: Label
var dash_was_ready: bool = true

# Zones de danger au sol — remplies à la génération d'arène
var lava_zones_data: Array = []
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var platform_nodes:  Array = []
var _lava_cd: float = 0.0
const LAVA_DMG = 9

# ── Profils d'arène par boss ─────────────────────────────────────────────────
#
# Chaque marqueur est déduit directement des attaques du boss.
# L'arène générée depuis ces contraintes défavorise activement le joueur.
#
# Marqueurs communs :
#   arena_w_range      → largeur min/max (px)
#   plat_count_range   → nb de plateformes flottantes [min, max]
#   plat_width_range   → largeur plateforme [min, max] (px)
#   plat_heights       → hauteurs disponibles depuis GROUND_Y (liste, px)
#   plat_x_zone        → fraction [left, right] de l'arène où poser les plateformes
#   center_gap         → fraction centrale sans plateforme (0.0 = désactivé)
#   lava_zones         → liste de zones danger au sol [[frac_debut, frac_fin], ...]
#   lava_color         → couleur de la lave (Color)
#
const BOSS_ARENA_PROFILES = {

	# ── MAGE ──────────────────────────────────────────────────────
	# Spirale : joueur exposé en espace ouvert au centre
	# Pluie   : arène large → x aléatoire couvre plus de surface → aucun abri au centre
	# Vise    : plateformes étroites = impossible de dodge latéralement dessus
	# Kiting  : grande arène = mage maintient son 250px idéal librement
	# → Plateformes à gauche uniquement, centre dégagé, mage tient la droite
	"mage": {
		"arena_w_range":    [950.0, 1100.0],
		"plat_count_range": [1, 2],
		"plat_width_range": [80.0, 115.0],
		"plat_heights":     [155.0, 190.0],
		"plat_x_zone":      [0.05, 0.44],
		"center_gap":       0.0,
	},

	# ── GUERRIER ──────────────────────────────────────────────────
	# Charge      : arène 1200px → charge 680px/s × 0.55s ≈ 370px (30% de l'arène).
	#               Lisible et décisive. Plateforme à 160px+ = hors portée (hitbox sol).
	# Stomp       : shockwave check dy > -90 → toute plateforme ≥ 160px est SAFE.
	#               Message clair : "monte = survie", pas de confusion avec les bas perchoirs.
	# Spin        : rayon 135px → recul sur plateforme + tir à distance.
	# Lave bords  : empêche le camping de coin sans bloquer le centre.
	#               Le centre reste ouvert pour le duel et les esquives au dash.
	# → Arène compacte, 3-4 plateformes larges et hautes, lave aux extrémités uniquement.
	"guerrier": {
		"arena_w_range":    [1150.0, 1250.0],
		"plat_count_range": [3, 4],
		"plat_width_range": [140.0, 200.0],
		"plat_heights":     [145.0, 185.0],
		"plat_x_zone":      [0.10, 0.90],
		"center_gap":       0.0,
		"lava_zones":       [[0.0, 0.08], [0.92, 1.0]],
		"lava_color":       Color("#dd2200"),
	},

	# ── PALADIN ───────────────────────────────────────────────────
	# Zone    : AoE 180px → joueur ne peut pas s'éloigner indéfiniment
	#           La lave sur les FLANCS (0–9% et 91–100%) coupe la retraite aux murs
	#           → Joueur coincé dans une zone "médiane" pile dans la portée de la zone
	# Bouclier: tirs ciblés depuis n'importe où → plateformes hautes = seul abri partiel
	# Charge rapide : 600px/s × 0.55s = 330px traversés → avec arène 1150px c'est brutal
	# → Lave aux deux bords, obligation de garder une distance médiane impossible à tenir
	"paladin": {
		"arena_w_range":    [1100.0, 1200.0],
		"plat_count_range": [3, 5],
		"plat_width_range": [88.0, 132.0],
		"plat_heights":     [120.0, 170.0, 215.0, 250.0],
		"plat_x_zone":      [0.08, 0.92],
		"center_gap":       0.0,
		"lava_zones":       [[0.0, 0.09], [0.91, 1.0]],
		"lava_color":       Color("#cc8800"),
	},

	# ── ELF ───────────────────────────────────────────────────────
	# Dash    : téléporte côté opposé et tire → dans 1300px d'arène, la salve couvre
	#           une grande surface, le joueur doit être en HEIGHT pour réduire l'angle
	# Pluie   : tombant de positions aléatoires → 5–7 plateformes ÉTROITES créent
	#           une jungle verticale où le joueur saute de plateforme en plateforme
	# Rafale  : tirs rapides ciblés → lave centrale force à rester dans un couloir exposé
	# → Venin vert central, nombreuses plateformes étroites et très hautes
	"elf": {
		"arena_w_range":    [1250.0, 1380.0],
		"plat_count_range": [5, 7],
		"plat_width_range": [65.0, 100.0],
		"plat_heights":     [115.0, 170.0, 220.0, 273.0],
		"plat_x_zone":      [0.06, 0.94],
		"center_gap":       0.0,
		"lava_zones":       [[0.37, 0.63]],
		"lava_color":       Color("#008844"),
	},
}

# ── Init ──────────────────────────────────────────────────────────────────────

func _enter_tree():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_window().content_scale_size = Vector2i(720, 405)

func _ready():
	if GameState.boss_type == "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/boss_fight/boss_select_debug.tscn")
		return

	var profil = BOSS_ARENA_PROFILES.get(GameState.boss_type, BOSS_ARENA_PROFILES["mage"])
	arena_w = randf_range(profil["arena_w_range"][0], profil["arena_w_range"][1])

	_setup_camera()
	_creer_arene(profil)
	_spawner_joueur()
	_spawner_boss()
	_creer_hud()
	_creer_vignette()

func _setup_camera():
	var vp = get_viewport().get_visible_rect().size
	$Camera2D.position = Vector2(arena_w * 0.5, ARENA_H * 0.5 - 30)
	var zoom = min(vp.x / arena_w, vp.y / ARENA_H)
	$Camera2D.zoom = Vector2(zoom, zoom)

# ── Génération d'arène ────────────────────────────────────────────────────────

func _creer_arene(profil: Dictionary):
	var boss_color := BOSS_THEME_COLORS.get(GameState.boss_type, Color("#334466")) as Color

	var bg = ColorRect.new()
	bg.color = Color("#080610")
	bg.size = Vector2(arena_w, ARENA_H + 200)
	$World.add_child(bg)

	# Lueurs atmosphériques basses (3 couches de couleur boss)
	for i in 3:
		var atmo = ColorRect.new()
		atmo.color   = boss_color
		atmo.color.a = 0.03 + i * 0.025
		atmo.size    = Vector2(arena_w, GROUND_Y * (0.35 - i * 0.08))
		atmo.position = Vector2(0, GROUND_Y - atmo.size.y)
		$World.add_child(atmo)

	# Étoiles légèrement teintées
	for _i in 60:
		var star = ColorRect.new()
		star.color   = Color.WHITE.lerp(boss_color, 0.25)
		star.color.a = randf_range(0.1, 0.5)
		var sz = randf_range(1.0, 2.5)
		star.size     = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, arena_w), randf_range(0, GROUND_Y - 80))
		$World.add_child(star)

	# Plafond sombre (effet dungeon fermé)
	var plafond := ColorRect.new()
	plafond.color    = Color(0, 0, 0, 0.55)
	plafond.size     = Vector2(arena_w, 28)
	plafond.position = Vector2(0, 0)
	$World.add_child(plafond)

	# Ligne au sol juste avant le sol
	var sol_edge_c := boss_color.lightened(0.1); sol_edge_c.a = 0.4
	var sol_edge := ColorRect.new()
	sol_edge.color    = sol_edge_c
	sol_edge.size     = Vector2(arena_w, 2)
	sol_edge.position = Vector2(0, GROUND_Y - 2)
	$World.add_child(sol_edge)

	_creer_colonnes(boss_color)

	_creer_mur(Vector2(-5, ARENA_H * 0.5),         Vector2(10, ARENA_H + 200))
	_creer_mur(Vector2(arena_w + 5, ARENA_H * 0.5), Vector2(10, ARENA_H + 200))
	_creer_plateforme(Vector2(arena_w * 0.5, GROUND_Y + 25), Vector2(arena_w, 50), false)

	_generer_plateformes(profil)

	if profil.has("lava_zones"):
		for zone in profil["lava_zones"]:
			_creer_zone_lava(zone[0] * arena_w, zone[1] * arena_w, profil["lava_color"])

	_creer_particules_ambiantes(boss_color)

func _generer_plateformes(profil: Dictionary):
	var nb       = randi_range(profil["plat_count_range"][0], profil["plat_count_range"][1])
	var w_min    = profil["plat_width_range"][0]
	var w_max    = profil["plat_width_range"][1]
	var heights  = profil["plat_heights"]
	var xz_l     = profil["plat_x_zone"][0]
	var xz_r     = profil["plat_x_zone"][1]
	var gap_frac = profil.get("center_gap", 0.0)
	# Distance max centre-à-centre franchissable en un saut (JUMP_FORCE=-560, SPEED=200)
	const MAX_JUMP_GAP = 300.0

	var center_l = arena_w * (0.5 - gap_frac * 0.5)
	var center_r = arena_w * (0.5 + gap_frac * 0.5)

	var placed: Array = []
	var attempts = 0

	while placed.size() < nb and attempts < 40:
		attempts += 1
		var pw    = randf_range(w_min, w_max)
		var ph    = heights[randi() % heights.size()]
		var half  = pw * 0.5
		var x_lo  = max(xz_l * arena_w + half + 15.0, half + 20.0)
		var x_hi  = min(xz_r * arena_w - half - 15.0, arena_w - half - 20.0)

		if x_lo >= x_hi:
			continue

		var x = randf_range(x_lo, x_hi)

		if gap_frac > 0.0 and x + half > center_l and x - half < center_r:
			continue

		var ok = true
		for p in placed:
			if abs(p.y - ph) < 30.0 and abs(p.x - x) < (pw + p.z) * 0.5 + 25.0:
				ok = false
				break
		if not ok:
			continue

		placed.append(Vector3(x, ph, pw))

	# ── Garantie de jouabilité : aucun trou infranchissable ───────────
	placed.sort_custom(func(a, b): return a.x < b.x)

	# Pour chaque zone de lave, s'assurer qu'un plateau est accessible
	# depuis chaque bord (sinon le joueur ne peut pas traverser la lave)
	if profil.has("lava_zones"):
		for zone in profil["lava_zones"]:
			var edge_l = zone[0] * arena_w
			var edge_r = zone[1] * arena_w
			if placed.is_empty() or placed[0].x > edge_l + MAX_JUMP_GAP:
				var bx = clamp(edge_l + MAX_JUMP_GAP * 0.6,
						xz_l * arena_w + 60.0, xz_r * arena_w - 60.0)
				placed.insert(0, Vector3(bx,
						heights[randi() % heights.size()], randf_range(w_min, w_max)))
			if placed.is_empty() or placed[-1].x < edge_r - MAX_JUMP_GAP:
				var bx = clamp(edge_r - MAX_JUMP_GAP * 0.6,
						xz_l * arena_w + 60.0, xz_r * arena_w - 60.0)
				placed.append(Vector3(bx,
						heights[randi() % heights.size()], randf_range(w_min, w_max)))
		placed.sort_custom(func(a, b): return a.x < b.x)

	# Combler les trous trop larges entre plateformes consécutives
	var fi = 0
	while fi < placed.size() - 1:
		if placed[fi + 1].x - placed[fi].x > MAX_JUMP_GAP:
			var bx = (placed[fi].x + placed[fi + 1].x) * 0.5
			placed.insert(fi + 1, Vector3(bx,
					heights[randi() % heights.size()], randf_range(w_min, w_max)))
		else:
			fi += 1

	# Créer les plateformes physiques
	for p in placed:
		_creer_plateforme(Vector2(p.x, GROUND_Y - p.y), Vector2(p.z, PLAT_H), true)

# ── Constructeurs ──────────────────────────────────────────────────────────────

func _creer_mur(pos: Vector2, taille: Vector2):
	var body  = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	body.position = pos
	$World.add_child(body)
	var shape = CollisionShape2D.new()
	var rect  = RectangleShape2D.new()
	rect.size = taille
	shape.shape = rect
	body.add_child(shape)

func _creer_plateforme(pos: Vector2, taille: Vector2, one_way: bool = false):
	var body = StaticBody2D.new()
	body.collision_layer = 2 if one_way else 1
	body.collision_mask  = 0
	body.position = pos
	$World.add_child(body)

	var shape = CollisionShape2D.new()
	var rect  = RectangleShape2D.new()
	rect.size = taille
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)

	var accent := BOSS_THEME_COLORS.get(GameState.boss_type, PLATFORM_EDGE) as Color
	_creer_visuel_plateforme(body, taille, not one_way, accent)

	if one_way:
		body.set_meta("width", taille.x)
		platform_nodes.append(body)

func _creer_visuel_plateforme(body: StaticBody2D, taille: Vector2, is_floor: bool, accent: Color) -> void:
	var hw  := taille.x * 0.5
	var hh  := taille.y * 0.5
	var bw  := 48.0 if is_floor else 28.0  # largeur des blocs pierre

	# Corps principal
	var corps := ColorRect.new()
	corps.color    = PLATFORM_COLOR
	corps.size     = taille
	corps.position = Vector2(-hw, -hh)
	body.add_child(corps)

	# Grille pierre — joints verticaux
	var jc := Color(0.0, 0.0, 0.0, 0.28)
	var x  := fmod(hw, bw)
	while x < taille.x:
		var jv := ColorRect.new()
		jv.color    = jc
		jv.size     = Vector2(1, taille.y)
		jv.position = Vector2(-hw + x, -hh)
		body.add_child(jv)
		x += bw

	# Joint horizontal central
	var jh := ColorRect.new()
	jh.color    = Color(0.0, 0.0, 0.0, 0.16)
	jh.size     = Vector2(taille.x, 1)
	jh.position = Vector2(-hw, 0)
	body.add_child(jh)

	# Bord supérieur lumineux
	var top := ColorRect.new()
	top.color    = PLATFORM_EDGE.lerp(accent, 0.45).lightened(0.12)
	top.size     = Vector2(taille.x, 4)
	top.position = Vector2(-hw, -hh)
	body.add_child(top)

	# Reflet brillant 1px sous le bord
	var reflet := ColorRect.new()
	reflet.color    = Color(1, 1, 1, 0.09)
	reflet.size     = Vector2(taille.x, 1)
	reflet.position = Vector2(-hw, -hh + 4)
	body.add_child(reflet)

	# Ombre basse
	var shadow := ColorRect.new()
	shadow.color    = Color(0.0, 0.0, 0.0, 0.45)
	shadow.size     = Vector2(taille.x, 3)
	shadow.position = Vector2(-hw, hh - 3)
	body.add_child(shadow)

func _creer_colonnes(boss_color: Color) -> void:
	var col_color   := Color(0.06, 0.04, 0.10)
	var cap_color   := boss_color.darkened(0.65)
	var spacing     := 175.0
	var nb          := int(arena_w / spacing) + 2

	for i in nb:
		var cx := i * spacing
		# Fût
		var fut := ColorRect.new()
		fut.color    = col_color
		fut.z_index  = -2
		fut.size     = Vector2(18, GROUND_Y)
		fut.position = Vector2(cx - 9, 0)
		$World.add_child(fut)
		# Chapiteau haut
		var cap := ColorRect.new()
		cap.color    = cap_color
		cap.z_index  = -2
		cap.size     = Vector2(28, 7)
		cap.position = Vector2(cx - 14, 0)
		$World.add_child(cap)
		# Base basse
		var base := ColorRect.new()
		base.color    = cap_color
		base.z_index  = -2
		base.size     = Vector2(26, 5)
		base.position = Vector2(cx - 13, GROUND_Y - 5)
		$World.add_child(base)
		# Halo de torche
		var halo_c := boss_color; halo_c.a = 0.12
		var halo := ColorRect.new()
		halo.color    = halo_c
		halo.z_index  = -1
		halo.size     = Vector2(55, 70)
		halo.position = Vector2(cx - 27, -35)
		$World.add_child(halo)
		# Flamme (scintille via tween en boucle)
		var flame := ColorRect.new()
		flame.z_index  = -1
		flame.color    = boss_color.lightened(0.35)
		flame.size     = Vector2(5, 9)
		flame.position = Vector2(cx - 2, -9)
		$World.add_child(flame)
		var tw := flame.create_tween()
		tw.set_loops()
		tw.tween_property(flame, "modulate:a", 0.35, randf_range(0.12, 0.25))
		tw.tween_property(flame, "modulate:a", 1.0,  randf_range(0.10, 0.22))

func _creer_particules_ambiantes(boss_color: Color) -> void:
	var p := CPUParticles2D.new()
	p.z_index               = -1
	p.position              = Vector2(arena_w * 0.5, GROUND_Y - 4)
	p.emitting              = true
	p.amount                = 38
	p.lifetime              = 3.8
	p.randomness            = 0.9
	p.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(arena_w * 0.5, 3)
	p.direction             = Vector2(0, -1)
	p.spread                = 18.0
	p.gravity               = Vector2(0, -6)
	p.initial_velocity_min  = 6.0
	p.initial_velocity_max  = 22.0
	p.scale_amount_min      = 1.0
	p.scale_amount_max      = 2.5
	var pc := boss_color.lightened(0.05)
	pc.a   = 0.30
	p.color = pc
	$World.add_child(p)

# ── Zones de danger (lave / venin / feu divin) ───────────────────────────────

func _creer_zone_lava(x_debut: float, x_fin: float, couleur: Color):
	var largeur = x_fin - x_debut

	# Enregistre pour le check de dégâts
	lava_zones_data.append({"x_min": x_debut, "x_max": x_fin})

	# Fond sombre
	var fond = ColorRect.new()
	fond.color    = couleur.darkened(0.55)
	fond.position = Vector2(x_debut, GROUND_Y)
	fond.size     = Vector2(largeur, 52)
	$World.add_child(fond)

	# Surface brillante (bande haute) — animée
	var surface = ColorRect.new()
	surface.color    = couleur.lightened(0.15)
	surface.position = Vector2(x_debut, GROUND_Y)
	surface.size     = Vector2(largeur, 5)
	$World.add_child(surface)
	var lava_tw := surface.create_tween()
	lava_tw.set_loops()
	lava_tw.tween_property(surface, "modulate:a", 0.45, randf_range(0.35, 0.6))
	lava_tw.tween_property(surface, "modulate:a", 1.0,  randf_range(0.25, 0.5))

	# Ligne de danger juste au-dessus du sol (bord supérieur, très brillant)
	var bord = ColorRect.new()
	bord.color    = couleur.lightened(0.5)
	bord.color.a  = 0.8
	bord.position = Vector2(x_debut, GROUND_Y - 3)
	bord.size     = Vector2(largeur, 3)
	$World.add_child(bord)

	# Bulles / éclaboussures aléatoires
	var rng = RandomNumberGenerator.new()
	rng.seed = int(x_debut * 137 + largeur * 31)
	for _i in int(largeur / 35):
		var bub = ColorRect.new()
		var bsz = rng.randf_range(3.5, 9.0)
		bub.color    = couleur.lightened(rng.randf_range(0.1, 0.5))
		bub.color.a  = rng.randf_range(0.45, 0.8)
		bub.size     = Vector2(bsz, bsz)
		bub.position = Vector2(
			x_debut + rng.randf_range(4, largeur - 8),
			GROUND_Y + rng.randf_range(5, 40)
		)
		$World.add_child(bub)

func _transition_phase_deux():
	var flash_col: Color = BOSS_THEME_COLORS.get(GameState.boss_type, Color("#ff4400"))
	flash_col.a   = 0.80
	_flash_screen(flash_col, 0.5)
	shake(13.0, 0.6)
	var base_zoom: Vector2 = ($Camera2D as Camera2D).zoom
	var zoom_tw   := $Camera2D.create_tween()
	zoom_tw.tween_property($Camera2D, "zoom", base_zoom * 1.3, 0.18).set_ease(Tween.EASE_OUT)
	zoom_tw.tween_interval(0.28)
	zoom_tw.tween_property($Camera2D, "zoom", base_zoom, 0.4)

	# Faire tomber les plus grandes plateformes en premier
	platform_nodes.sort_custom(func(a, b): return a.get_meta("width") > b.get_meta("width"))
	var nb = platform_nodes.size() / 2
	for i in nb:
		var p = platform_nodes[i]
		if not is_instance_valid(p): continue
		p.collision_layer = 0
		var tw = p.create_tween()
		tw.tween_property(p, "modulate", Color(2.2, 0.15, 0.05), 0.30)
		tw.tween_property(p, "position", p.position + Vector2(0, 150), 0.50)
		tw.tween_callback(p.queue_free)
	platform_nodes = platform_nodes.slice(nb)

	# Deux nouvelles plaques de lave au sol
	_creer_zone_lava(arena_w * 0.20, arena_w * 0.33, Color("#dd2200"))
	_creer_zone_lava(arena_w * 0.67, arena_w * 0.80, Color("#dd2200"))

func _verifier_lava(delta: float):
	if lava_zones_data.is_empty() or not is_instance_valid(player_node):
		return
	_lava_cd -= delta
	if _lava_cd > 0.0:
		return
	# Seulement si le joueur est proche du sol
	if player_node.global_position.y < GROUND_Y - 65:
		return
	var px = player_node.global_position.x
	for zone in lava_zones_data:
		if px >= zone["x_min"] and px <= zone["x_max"]:
			player_node.take_damage(LAVA_DMG)
			_lava_cd = 0.42
			return

# ── Spawn ──────────────────────────────────────────────────────────────────────

func _spawner_joueur():
	player_node = PLAYER_SCENE.instantiate()
	player_node.position = Vector2(130, GROUND_Y - 60)
	$World.add_child(player_node)

func _spawner_boss():
	boss_node = BOSS_SCENE.instantiate()
	boss_node.setup(GameState.boss_type, player_node, arena_w, GameState.boss_level)
	boss_node.position = Vector2(arena_w - 130, GROUND_Y - 80)
	$World.add_child(boss_node)
	player_node.boss_ref = boss_node

# ── HUD ────────────────────────────────────────────────────────────────────────

func _creer_hud():
	var hud = $HUD

	var fond = ColorRect.new()
	fond.color = Color("#0d0916", 0.88)
	fond.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fond.offset_bottom = 58
	hud.add_child(fond)

	var sec_j = VBoxContainer.new()
	sec_j.position = Vector2(12, 8)
	hud.add_child(sec_j)
	var lbl_j = Label.new()
	lbl_j.text = "Gobelin"
	lbl_j.add_theme_font_size_override("font_size", 11)
	lbl_j.add_theme_color_override("font_color", Color("#88dd88"))
	sec_j.add_child(lbl_j)
	hud_player_bar = ProgressBar.new()
	hud_player_bar.custom_minimum_size = Vector2(210, 16)
	hud_player_bar.max_value = 100
	hud_player_bar.value = 100
	hud_player_bar.show_percentage = false
	sec_j.add_child(hud_player_bar)

	var sec_b = VBoxContainer.new()
	sec_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sec_b.position = Vector2(-222, 8)
	hud.add_child(sec_b)
	var lbl_b = Label.new()
	lbl_b.text = _nom_boss()
	lbl_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_b.add_theme_font_size_override("font_size", 11)
	lbl_b.add_theme_color_override("font_color", Color("#ff6666"))
	sec_b.add_child(lbl_b)
	hud_boss_bar = ProgressBar.new()
	hud_boss_bar.custom_minimum_size = Vector2(210, 16)
	hud_boss_bar.max_value = 100
	hud_boss_bar.value = 100
	hud_boss_bar.show_percentage = false
	sec_b.add_child(hud_boss_bar)

	hud_phase_label = Label.new()
	hud_phase_label.text = "Phase I"
	hud_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_phase_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_phase_label.offset_top = 8
	hud_phase_label.offset_bottom = 36
	hud_phase_label.add_theme_font_size_override("font_size", 14)
	hud_phase_label.add_theme_color_override("font_color", Color("#e8b84b"))
	hud.add_child(hud_phase_label)

	# Bouton dash — bas droite
	var dash_container = Control.new()
	dash_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_container.offset_left   = -90
	dash_container.offset_top    = -90
	dash_container.offset_right  = -10
	dash_container.offset_bottom = -10
	hud.add_child(dash_container)

	dash_btn_bg = ColorRect.new()
	dash_btn_bg.color = Color("#1a5c3a")
	dash_btn_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_container.add_child(dash_btn_bg)

	var d_icon = Label.new()
	d_icon.text = "💨"
	d_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_icon.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	d_icon.add_theme_font_size_override("font_size", 28)
	d_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	d_icon.offset_top = -8
	dash_container.add_child(d_icon)

	dash_cd_lbl = Label.new()
	dash_cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_cd_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	dash_cd_lbl.add_theme_font_size_override("font_size", 13)
	dash_cd_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	dash_cd_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_cd_lbl.offset_top = 24
	dash_container.add_child(dash_cd_lbl)

	var d_btn = Button.new()
	d_btn.flat = true
	d_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	d_btn.pressed.connect(func(): player_node.dash_requested = true)
	dash_container.add_child(d_btn)

func _nom_boss() -> String:
	match GameState.boss_type:
		"guerrier": return "Guerrier Légendaire"
		"paladin":  return "Paladin Maudit"
		"elf":      return "Elfe Fantôme"
		"mage":     return "Grand Mage"
	return "Boss"

# ── Update ─────────────────────────────────────────────────────────────────────

func shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	_shake_intensity = intensity
	_shake_timer     = max(_shake_timer, duration)

func _flash_screen(color: Color, duration: float) -> void:
	var cl   := CanvasLayer.new()
	cl.layer  = 20
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(cl.queue_free)

func spawn_hit_particles(world_pos: Vector2, color: Color) -> void:
	var p              := CPUParticles2D.new()
	p.position          = world_pos
	p.z_index           = 10
	p.emitting          = true
	p.one_shot          = true
	p.explosiveness     = 0.95
	p.amount            = 10
	p.lifetime          = 0.4
	p.direction         = Vector2.UP
	p.spread            = 180.0
	p.gravity           = Vector2(0, 500)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min  = 2.0
	p.scale_amount_max  = 5.0
	p.color             = color
	$World.add_child(p)
	get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())

func on_boss_death(boss_pos: Vector2) -> void:
	shake(16.0, 0.8)
	_flash_screen(Color(1, 1, 1, 0.92), 0.55)
	var base_zoom: Vector2 = ($Camera2D as Camera2D).zoom
	var tw        := $Camera2D.create_tween()
	tw.tween_property($Camera2D, "zoom", base_zoom * 1.45, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property($Camera2D, "zoom", base_zoom, 0.5)
	for _i in 28:
		var off := Vector2(randf_range(-55, 55), randf_range(-80, 5))
		spawn_hit_particles(boss_pos + off,
			Color(1.0, randf_range(0.3, 0.9), 0.0))

func _creer_vignette() -> void:
	var cl   := CanvasLayer.new()
	cl.layer  = 10
	add_child(cl)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat  := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/vignette.gdshader")
	mat.set_shader_parameter("strength", 0.55)
	mat.set_shader_parameter("softness", 0.40)
	var boss_color := BOSS_THEME_COLORS.get(GameState.boss_type, Color("#000")) as Color
	mat.set_shader_parameter("tint", Color(boss_color.r * 0.25, boss_color.g * 0.25, boss_color.b * 0.25, 1.0))
	rect.material = mat
	cl.add_child(rect)

func _process(delta: float):
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var s := _shake_intensity * (_shake_timer / 0.25)
		$Camera2D.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		$Camera2D.offset = Vector2.ZERO

	if not is_instance_valid(player_node) or not is_instance_valid(boss_node):
		return
	hud_player_bar.value = float(player_node.current_hp) / float(player_node.max_hp) * 100.0
	hud_boss_bar.value   = float(boss_node.current_hp)   / float(boss_node.max_hp)   * 100.0
	if boss_node.phase == 1 and hud_phase_label.text != "Phase II  ⚠":
		hud_phase_label.text = "Phase II  ⚠"
		hud_phase_label.add_theme_color_override("font_color", Color("#ff4444"))
	_update_bouton_dash()
	_verifier_lava(delta)

func _update_bouton_dash() -> void:
	if not dash_btn_bg or not is_instance_valid(player_node): return
	var ready = player_node.dash_cd <= 0.05
	if ready:
		dash_cd_lbl.text = ""
		if not dash_was_ready:
			dash_was_ready = true
			dash_btn_bg.color = Color("#88ffcc")
			await get_tree().create_timer(0.12).timeout
			if is_instance_valid(dash_btn_bg): dash_btn_bg.color = Color("#1a5c3a")
	else:
		dash_was_ready = false
		var ratio = player_node.dash_cd / player_node.dash_cd_dur
		dash_btn_bg.color = Color("#1a3a5c").lerp(Color("#0d1a2e"), ratio)
		dash_cd_lbl.text = "%.1f" % player_node.dash_cd
