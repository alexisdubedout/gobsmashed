extends Control

const BOSS_INFO = [
	{"type": "mage",     "label": "Grand Mage",         "couleur": Color("#7755ee"), "emoji": "🔮"},
	{"type": "guerrier", "label": "Guerrier Légendaire", "couleur": Color("#cc3322"), "emoji": "⚔️"},
	{"type": "paladin",  "label": "Paladin Maudit",      "couleur": Color("#bb9900"), "emoji": "🛡️"},
	{"type": "elf",      "label": "Elfe Fantôme",        "couleur": Color("#228855"), "emoji": "🏹"},
]

func _ready():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	get_window().content_scale_size = Vector2i(405, 720)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#080511")
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	vbox.add_child(_creer_header())

	var sep1 = Control.new()
	sep1.custom_minimum_size.y = 4
	vbox.add_child(sep1)

	for info in BOSS_INFO:
		vbox.add_child(_creer_carte(info))

	var sep2 = Control.new()
	sep2.custom_minimum_size.y = 2
	vbox.add_child(sep2)

	var wrap_direct = MarginContainer.new()
	wrap_direct.add_theme_constant_override("margin_left", 40)
	wrap_direct.add_theme_constant_override("margin_right", 40)
	wrap_direct.add_child(_creer_btn_direct())
	vbox.add_child(wrap_direct)

func _creer_header() -> Control:
	var wrap = MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 20)
	wrap.add_theme_constant_override("margin_right", 20)
	wrap.add_theme_constant_override("margin_bottom", 4)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	wrap.add_child(vb)

	var debug_lbl = Label.new()
	debug_lbl.text = "[ DEBUG — PHASE DE DÉVELOPPEMENT ]"
	debug_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_lbl.add_theme_font_size_override("font_size", 10)
	debug_lbl.add_theme_color_override("font_color", Color("#442211"))
	vb.add_child(debug_lbl)

	var titre = Label.new()
	titre.text = "Choisir le Boss"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 26)
	titre.add_theme_color_override("font_color", Color("#e8b84b"))
	titre.add_theme_color_override("font_shadow_color", Color("#000000", 0.8))
	titre.add_theme_constant_override("shadow_offset_x", 2)
	titre.add_theme_constant_override("shadow_offset_y", 2)
	vb.add_child(titre)

	return wrap

func _creer_carte(info: Dictionary) -> Control:
	var wrap = MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 20)
	wrap.add_theme_constant_override("margin_right", 20)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = info["couleur"].darkened(0.78)
	style.border_color = info["couleur"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	wrap.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var ico = Label.new()
	ico.text = info["emoji"]
	ico.add_theme_font_size_override("font_size", 28)
	ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ico.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(ico)

	var nom = Label.new()
	nom.text = info["label"]
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.add_theme_font_size_override("font_size", 17)
	nom.add_theme_color_override("font_color", Color("#ede0c4"))
	nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(nom)

	var btn = Button.new()
	btn.text = "COMBAT →"
	btn.custom_minimum_size = Vector2(92, 40)
	btn.add_theme_font_size_override("font_size", 11)
	var bs_n = StyleBoxFlat.new()
	bs_n.bg_color = info["couleur"].darkened(0.45)
	bs_n.border_color = info["couleur"]
	bs_n.set_border_width_all(2)
	bs_n.set_corner_radius_all(5)
	bs_n.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", bs_n)
	var bs_h = bs_n.duplicate()
	bs_h.bg_color = info["couleur"].darkened(0.15)
	btn.add_theme_stylebox_override("hover", bs_h)
	var bs_p = bs_n.duplicate()
	bs_p.bg_color = info["couleur"].darkened(0.65)
	btn.add_theme_stylebox_override("pressed", bs_p)
	btn.add_theme_color_override("font_color", info["couleur"].lightened(0.35))
	var t = info["type"]
	btn.pressed.connect(func():
		GameState.boss_type = t
		GameState.boss_hp_joueur = 80
		get_tree().change_scene_to_file("res://scenes/boss_fight/boss_intro.tscn")
	)
	hbox.add_child(btn)

	return wrap

func _creer_btn_direct() -> Button:
	var btn = Button.new()
	btn.text = "⚡ Accès direct sans intro"
	btn.add_theme_font_size_override("font_size", 11)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color("#08050e")
	bs.border_color = Color("#221100")
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(4)
	bs.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_color_override("font_color", Color("#3a2211"))
	btn.pressed.connect(func():
		if GameState.boss_type == "":
			GameState.boss_type = "mage"
		GameState.boss_hp_joueur = 80
		get_tree().change_scene_to_file("res://scenes/boss_fight/boss_fight.tscn")
	)
	return btn
