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
	# Charge  : arène étroite = la charge est impossible à éviter latéralement
	# Stomp   : projectiles sol + côtés → plateformes nombreuses = joueur coincé sur l'une d'elles
	# Spin    : radial depuis courte portée → corridor étroit amplifie les hits
	# → Arène resserrée, plus de plateformes pour créer des pièges de mobilité
	"guerrier": {
		"arena_w_range":    [620.0, 760.0],
		"plat_count_range": [2, 4],
		"plat_width_range": [120.0, 190.0],
		"plat_heights":     [90.0, 140.0, 180.0],
		"plat_x_zone":      [0.08, 0.92],
		"center_gap":       0.0,
	},

	# ── PALADIN ───────────────────────────────────────────────────
	# Zone    : dégâts de proximité en pulsions → arène moyenne force le joueur proche
	# Bouclier: tirs ciblés + explosion de sortie → pas d'abri = plein impact
	# Charge  : lente mais telegraphée — peu d'importance sur la largeur
	# → Arène médiane, plateformes hautes → joueur grimpe mais reste dans portée zone
	"paladin": {
		"arena_w_range":    [700.0, 860.0],
		"plat_count_range": [2, 3],
		"plat_width_range": [100.0, 160.0],
		"plat_heights":     [90.0, 145.0, 185.0],
		"plat_x_zone":      [0.08, 0.92],
		"center_gap":       0.0,
	},

	# ── ELF ───────────────────────────────────────────────────────
	# Dash    : téléporte côté opposé et tire immédiatement → peu de plateformes = joueur exposé
	# Salve   : éventail → espace latéral limité amplifie les hits
	# Pluie   : coins depuis le ciel → peu d'abri = plein impact
	# → Arène moyenne, peu de cover, plateformes hautes pour rendre l'esquive verticale risquée
	"elf": {
		"arena_w_range":    [800.0, 960.0],
		"plat_count_range": [1, 3],
		"plat_width_range": [90.0, 140.0],
		"plat_heights":     [100.0, 160.0, 215.0],
		"plat_x_zone":      [0.08, 0.92],
		"center_gap":       0.0,
	},
}

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready():
	if GameState.boss_type == "":
		GameState.boss_type = "mage"
		GameState.boss_hp_joueur = 80

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

func _generer_plateformes(profil: Dictionary):
	var nb       = randi_range(profil["plat_count_range"][0], profil["plat_count_range"][1])
	var w_min    = profil["plat_width_range"][0]
	var w_max    = profil["plat_width_range"][1]
	var heights  = profil["plat_heights"]
	var xz_l     = profil["plat_x_zone"][0]
	var xz_r     = profil["plat_x_zone"][1]
	var gap_frac = profil["center_gap"]

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

		# Respecter la zone centrale interdite
		if gap_frac > 0.0 and x + half > center_l and x - half < center_r:
			continue

		# Éviter les chevauchements et plateformes trop proches à même hauteur
		var ok = true
		for p in placed:
			if abs(p.y - ph) < 30.0 and abs(p.x - x) < (pw + p.z) * 0.5 + 25.0:
				ok = false
				break
		if not ok:
			continue

		placed.append(Vector3(x, ph, pw))
		_creer_plateforme(Vector2(x, GROUND_Y - ph), Vector2(pw, PLAT_H), true)

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

func _process(_delta):
	if not is_instance_valid(player_node) or not is_instance_valid(boss_node):
		return
	hud_player_bar.value = float(player_node.current_hp) / float(player_node.max_hp) * 100.0
	hud_boss_bar.value   = float(boss_node.current_hp)   / float(boss_node.max_hp)   * 100.0
	if boss_node.phase == 1 and hud_phase_label.text != "Phase II  ⚠":
		hud_phase_label.text = "Phase II  ⚠"
		hud_phase_label.add_theme_color_override("font_color", Color("#ff4444"))
	_update_bouton_dash()

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
