extends Control

const BOSS_DATA = {
	"mage": {
		"nom":          "Grand Mage",
		"titre":        "Archimage des Profondeurs",
		"couleur":      Color("#7755ee"),
		"couleur_sombre": Color("#100820"),
		"couleur_accent": Color("#bbaaff"),
		"dialogue":     "Tu oses te présenter devant moi ?\nJe vais t'enseigner ce qu'est\nla vraie puissance...\nTa mort sera instructive.",
		"texture":      "res://assets/characters/Mage.png",
	},
	"guerrier": {
		"nom":          "Guerrier Légendaire",
		"titre":        "Titan de l'Arène Maudite",
		"couleur":      Color("#cc3322"),
		"couleur_sombre": Color("#1e0606"),
		"couleur_accent": Color("#ff8877"),
		"dialogue":     "Enfin un adversaire !\nÇa fait trop longtemps que\nje n'ai pas senti le goût du sang.\nViens... souffrir.",
		"texture":      "res://assets/characters/Guerrier.png",
	},
	"paladin": {
		"nom":          "Paladin Maudit",
		"titre":        "Lame de la Lumière Noire",
		"couleur":      Color("#bb9900"),
		"couleur_sombre": Color("#1a1400"),
		"couleur_accent": Color("#ffdd55"),
		"dialogue":     "La lumière divine\nne tolère pas ton insolence.\nTu as cherché ton jugement...\ntu l'as trouvé.",
		"texture":      "res://assets/characters/Paladin.png",
	},
	"elf": {
		"nom":          "Elfe Fantôme",
		"titre":        "Chasseuse des Ombres Éternelles",
		"couleur":      Color("#228855"),
		"couleur_sombre": Color("#05150a"),
		"couleur_accent": Color("#55ffaa"),
		"dialogue":     "Tu es rapide...\npour un gobelin.\nMais personne ne m'a jamais rattrapée.\nPersonne ne le fera jamais.",
		"texture":      "res://assets/characters/Elf.png",
	},
}

var _sprite_ref: Sprite2D = null
var _text_label: RichTextLabel = null
var _anim_timer: float = 0.0
var _chars_shown: float = 0.0

func _enter_tree():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_window().content_scale_size = Vector2i(720, 405)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	_build_ui()

func _build_ui():
	var data = BOSS_DATA.get(GameState.boss_type, BOSS_DATA["mage"])

	# Fond principal
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#050309")
	add_child(bg)

	# Lueur colorée sur la partie gauche (zone portrait)
	var wash = ColorRect.new()
	wash.color = data["couleur"]
	wash.color.a = 0.08
	wash.anchor_left = 0.0
	wash.anchor_right = 0.0
	wash.anchor_top = 0.0
	wash.anchor_bottom = 1.0
	wash.offset_right = 225
	add_child(wash)

	# Layout principal horizontal
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	var portrait = _creer_portrait(data)
	portrait.custom_minimum_size.x = 210
	portrait.size_flags_horizontal = 0  # SIZE_SHRINK_BEGIN — largeur fixe
	portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(portrait)

	var dialogue = _creer_dialogue(data)
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(dialogue)

# ── Portrait ────────────────────────────────────────────────────────────────

func _creer_portrait(data: Dictionary) -> Control:
	var wrapper = Control.new()

	# Arrière-plan lumineux (couleur boss, voile)
	var glow = ColorRect.new()
	glow.color = data["couleur"]
	glow.color.a = 0.22
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(glow)

	# Cadre principal du portrait (Panel pour pouvoir avoir plusieurs enfants)
	var frame = Panel.new()
	frame.anchor_left   = 0.0
	frame.anchor_right  = 1.0
	frame.anchor_top    = 0.0
	frame.anchor_bottom = 1.0
	frame.offset_left   = 5
	frame.offset_right  = -5
	frame.offset_top    = 6
	frame.offset_bottom = -6
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color        = data["couleur_sombre"]
	frame_style.border_color    = data["couleur"]
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	wrapper.add_child(frame)

	# Double bordure intérieure (ligne fine accent)
	var inner_line = Panel.new()
	inner_line.anchor_left   = 0.0
	inner_line.anchor_right  = 1.0
	inner_line.anchor_top    = 0.0
	inner_line.anchor_bottom = 1.0
	inner_line.offset_left   = 8
	inner_line.offset_right  = -8
	inner_line.offset_top    = 8
	inner_line.offset_bottom = -8
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color     = Color(0, 0, 0, 0)
	inner_style.border_color = data["couleur"]
	inner_style.border_color.a = 0.35
	inner_style.set_border_width_all(1)
	frame.add_child(inner_line)

	# Contenu : sprite + nom
	var vbox = VBoxContainer.new()
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left   = 12
	vbox.offset_right  = -12
	vbox.offset_top    = 14
	vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	# Zone sprite (SubViewport pour animation)
	var svc = SubViewportContainer.new()
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	vbox.add_child(svc)

	var sv = SubViewport.new()
	sv.size = Vector2i(160, 290)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	var sprite = Sprite2D.new()
	sprite.texture = load(data["texture"])
	sprite.hframes = 8
	sprite.vframes = 4
	sprite.position = Vector2(80, 130)
	sprite.scale    = Vector2(4.2, 4.2)
	sv.add_child(sprite)
	_sprite_ref = sprite

	# Voile atmosphérique sur le sprite
	var atmo = ColorRect.new()
	atmo.color  = data["couleur"]
	atmo.color.a = 0.10
	atmo.size   = Vector2(160, 290)
	sv.add_child(atmo)

	# Vignette basse (dégradé du bas vers le haut, sombre)
	var vign = ColorRect.new()
	vign.color  = data["couleur_sombre"]
	vign.color.a = 0.55
	vign.position = Vector2(0, 200)
	vign.size   = Vector2(160, 90)
	sv.add_child(vign)

	# Nom du boss (sous le portrait)
	var nom_lbl = Label.new()
	nom_lbl.text = data["nom"].to_upper()
	nom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom_lbl.add_theme_font_size_override("font_size", 10)
	nom_lbl.add_theme_color_override("font_color", data["couleur_accent"])
	nom_lbl.add_theme_color_override("font_shadow_color", Color("#000000", 0.9))
	nom_lbl.add_theme_constant_override("shadow_offset_x", 1)
	nom_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(nom_lbl)

	# Ornements de coin (diamonds ◆)
	_ajouter_ornements_coin(frame, data["couleur"])

	return wrapper

func _ajouter_ornements_coin(parent: Control, couleur: Color):
	var configs = [
		[0.0, 0.0,  6,   6,  22,  22],   # haut-gauche
		[1.0, 0.0, -22,  6,  -6,  22],   # haut-droite
		[0.0, 1.0,  6,  -22,  22,  -6],  # bas-gauche
		[1.0, 1.0, -22, -22,  -6,  -6],  # bas-droite
	]
	for cfg in configs:
		var lbl = Label.new()
		lbl.text = "◆"
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", couleur.lightened(0.15))
		lbl.anchor_left   = cfg[0]
		lbl.anchor_right  = cfg[0]
		lbl.anchor_top    = cfg[1]
		lbl.anchor_bottom = cfg[1]
		lbl.offset_left   = cfg[2]
		lbl.offset_top    = cfg[3]
		lbl.offset_right  = cfg[4]
		lbl.offset_bottom = cfg[5]
		lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)

# ── Dialogue ────────────────────────────────────────────────────────────────

func _creer_dialogue(data: Dictionary) -> Control:
	var outer = Control.new()

	var bg = ColorRect.new()
	bg.color = Color("#060310")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left   = 26
	vbox.offset_right  = -26
	vbox.offset_top    = 22
	vbox.offset_bottom = -22
	vbox.add_theme_constant_override("separation", 10)
	outer.add_child(vbox)

	# Sous-titre (rôle du boss)
	var role_lbl = Label.new()
	var role_color = data["couleur"]
	role_color.a = 0.70
	role_lbl.text = data["titre"].to_upper()
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", role_color)
	vbox.add_child(role_lbl)

	# Nom du boss (grand)
	var nom_lbl = Label.new()
	nom_lbl.text = data["nom"]
	nom_lbl.add_theme_font_size_override("font_size", 22)
	nom_lbl.add_theme_color_override("font_color", Color("#ede0c4"))
	nom_lbl.add_theme_color_override("font_shadow_color", data["couleur"])
	nom_lbl.add_theme_constant_override("shadow_offset_x", 2)
	nom_lbl.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(nom_lbl)

	# Ligne de séparation colorée
	var div = ColorRect.new()
	div.color = data["couleur"]
	div.color.a = 0.60
	div.custom_minimum_size = Vector2(0, 2)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(div)

	# Texte du boss (effet machine à écrire)
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active  = false
	rtl.text = "[color=#ccbbaa][i]" + data["dialogue"] + "[/i][/color]"
	rtl.add_theme_font_size_override("normal_font_size", 16)
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.visible_characters  = 0
	vbox.add_child(rtl)
	_text_label = rtl

	# ── Section contrôles ────────────────────────────────────────
	var ctrl_sep = ColorRect.new()
	ctrl_sep.color = data["couleur"]
	ctrl_sep.color.a = 0.25
	ctrl_sep.custom_minimum_size = Vector2(0, 1)
	ctrl_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(ctrl_sep)

	var ctrl_wrap = VBoxContainer.new()
	ctrl_wrap.add_theme_constant_override("separation", 5)
	vbox.add_child(ctrl_wrap)

	var ctrl_title = Label.new()
	ctrl_title.text = "CONTRÔLES"
	ctrl_title.add_theme_font_size_override("font_size", 9)
	ctrl_title.add_theme_color_override("font_color", data["couleur"])
	ctrl_title.modulate = Color(1, 1, 1, 0.65)
	ctrl_wrap.add_child(ctrl_title)

	for hint: Array in [
		["▶▶  2× avant",  "Dash"],
		["▼▼  2× bas",    "Tomber de la plateforme"],
	]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		ctrl_wrap.add_child(row)

		var key_lbl = Label.new()
		key_lbl.text = hint[0]
		key_lbl.custom_minimum_size.x = 150
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", data["couleur_accent"])
		row.add_child(key_lbl)

		var arrow_lbl = Label.new()
		arrow_lbl.text = "→"
		arrow_lbl.add_theme_font_size_override("font_size", 11)
		arrow_lbl.add_theme_color_override("font_color", data["couleur"])
		row.add_child(arrow_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = hint[1]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color("#998877"))
		row.add_child(desc_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	# Bouton PRÊT AU COMBAT
	var btn = Button.new()
	btn.text = "⚔   ENTRER DANS L'ARÈNE"
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 15)
	var bs_n = StyleBoxFlat.new()
	bs_n.bg_color     = data["couleur"].darkened(0.40)
	bs_n.border_color = data["couleur"]
	bs_n.set_border_width_all(2)
	bs_n.set_corner_radius_all(5)
	bs_n.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", bs_n)
	var bs_h = bs_n.duplicate()
	bs_h.bg_color = data["couleur"].darkened(0.15)
	btn.add_theme_stylebox_override("hover", bs_h)
	var bs_p = bs_n.duplicate()
	bs_p.bg_color = data["couleur"].darkened(0.65)
	btn.add_theme_stylebox_override("pressed", bs_p)
	btn.add_theme_color_override("font_color", data["couleur_accent"])
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/boss_fight/boss_fight.tscn")
	)
	vbox.add_child(btn)

	return outer

# ── Update ──────────────────────────────────────────────────────────────────

func _process(delta: float):
	_anim_timer += delta

	# Animation du sprite du boss
	if is_instance_valid(_sprite_ref):
		_sprite_ref.frame = int(_anim_timer * 7.0) % 8

	# Effet machine à écrire
	if is_instance_valid(_text_label):
		var total = _text_label.get_total_character_count()
		if _text_label.visible_characters < total:
			_chars_shown += 22.0 * delta
			_text_label.visible_characters = int(min(_chars_shown, total))

func _input(event: InputEvent):
	# Tap/clic sur la zone dialogue → saute la machine à écrire
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed and is_instance_valid(_text_label):
			var total = _text_label.get_total_character_count()
			if _text_label.visible_characters < total:
				_text_label.visible_characters = -1
				_chars_shown = 9999.0
