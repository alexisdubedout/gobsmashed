extends Node2D

const PLAYER_SCENE = preload("res://scenes/boss_fight/player_platformer.tscn")
const BOSS_SCENE   = preload("res://scenes/boss_fight/boss_platformer.tscn")

const ARENA_H        = 600.0
const GROUND_Y       = 500.0
const PLAT_H         = 18.0
const PLATFORM_COLOR = Color("#4a3018")
const PLATFORM_EDGE  = Color("#7a5828")

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
		"plat_heights":     [130.0, 165.0],
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
		"plat_heights":     [120.0, 160.0],
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
		"plat_heights":     [95.0, 145.0, 190.0, 225.0],
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
		"plat_heights":     [90.0, 145.0, 195.0, 248.0],
		"plat_x_zone":      [0.06, 0.94],
		"center_gap":       0.0,
		"lava_zones":       [[0.37, 0.63]],
		"lava_color":       Color("#008844"),
	},
}

# ── Init ──────────────────────────────────────────────────────────────────────

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

func _setup_camera():
	var vp = get_viewport().get_visible_rect().size
	$Camera2D.position = Vector2(arena_w * 0.5, ARENA_H * 0.5 - 30)
	var zoom = min(vp.x / arena_w, vp.y / ARENA_H)
	$Camera2D.zoom = Vector2(zoom, zoom)

# ── Génération d'arène ────────────────────────────────────────────────────────

func _creer_arene(profil: Dictionary):
	var bg = ColorRect.new()
	bg.color = Color("#0d0916")
	bg.size = Vector2(arena_w, ARENA_H + 200)
	$World.add_child(bg)

	for _i in 70:
		var star = ColorRect.new()
		star.color = Color(1, 1, 1, randf_range(0.15, 0.65))
		var sz = randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, arena_w), randf_range(0, GROUND_Y - 80))
		$World.add_child(star)

	_creer_mur(Vector2(-5, ARENA_H * 0.5),         Vector2(10, ARENA_H + 200))
	_creer_mur(Vector2(arena_w + 5, ARENA_H * 0.5), Vector2(10, ARENA_H + 200))
	_creer_plateforme(Vector2(arena_w * 0.5, GROUND_Y + 25), Vector2(arena_w, 50), false)

	_generer_plateformes(profil)

	if profil.has("lava_zones"):
		for zone in profil["lava_zones"]:
			_creer_zone_lava(zone[0] * arena_w, zone[1] * arena_w, profil["lava_color"])

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

	var visual = ColorRect.new()
	visual.color    = PLATFORM_COLOR
	visual.size     = taille
	visual.position = -taille * 0.5
	body.add_child(visual)

	var bord = ColorRect.new()
	bord.color    = PLATFORM_EDGE
	bord.size     = Vector2(taille.x, 4)
	bord.position = Vector2(-taille.x * 0.5, -taille.y * 0.5)
	body.add_child(bord)

	if one_way:
		body.set_meta("width", taille.x)
		platform_nodes.append(body)

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

	# Surface brillante (bande haute)
	var surface = ColorRect.new()
	surface.color    = couleur.lightened(0.15)
	surface.position = Vector2(x_debut, GROUND_Y)
	surface.size     = Vector2(largeur, 5)
	$World.add_child(surface)

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
	boss_node.setup(GameState.boss_type, player_node, arena_w)
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

func _process(delta: float):
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
