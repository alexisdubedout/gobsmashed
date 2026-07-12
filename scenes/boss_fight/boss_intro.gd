extends Control

const BOSS_DATA = {
	"mage": {
		"nom":          "Nadège la Ténébreuse",
		"titre":        "Lanceuse de Sorts (En Formation)",
		"couleur":      Color("#7755ee"),
		"couleur_sombre": Color("#100820"),
		"couleur_accent": Color("#bbaaff"),
		"dialogues": [
			"J'ai appris 47 sorts.\nJ'en connais encore 3 par cœur.\nMais les 3 bons.\nEnfin... à peu près.",
			"Mon bâton est enchanté.\nBon, je l'ai enchanté moi-même hier.\nLe résultat est en cours.\nMais t'as vu l'intention.",
			"Le chef a dit 'amène quelqu'un de magique'.\nIl pensait à quelqu'un d'autre.\nMais j'étais là.\nMoi aussi je peux être magique.",
			"J'ai failli transformer une chaise en grenouille.\nElle a juste... bougé un peu.\nMais dans le bon sens.\nC'est déjà quelque chose.",
			"Je suis là pour le savoir.\nPas pour l'or du gobelin.\nBon l'or aussi.\nSurtout l'or en fait.",
		],
	},
	"guerrier": {
		"nom":          "Grug le Magnifique",
		"titre":        "Légende Vivante (Selon Lui-Même)",
		"couleur":      Color("#cc3322"),
		"couleur_sombre": Color("#1e0606"),
		"couleur_accent": Color("#ff8877"),
		"dialogues": [
			"On m'appelle l'Invincible.\nBon, j'ai perdu une fois.\nMais il m'avait mordu en premier.\nToi tu vas juste perdre.",
			"Mon épée a un nom.\nElle s'appelle Destructor.\nC'est moi qui l'ai trouvé.\nJe suis aussi très intelligent.",
			"J'ai combattu des dragons !\nBon, c'était un lézard.\nMais il était ÉNORME.\nToi t'es même pas un lézard.",
			"J'avais pas peur.\nJ'avais juste quelque chose dans l'œil.\nLes deux yeux. En même temps.\nAllez, viens qu'on en finisse.",
			"Le chef m'a dit de garder l'entrée.\nMais l'entrée c'était ennuyeux.\nAlors je suis entré quand même.\nC'est pareil en mieux.",
		],
	},
	"paladin": {
		"nom":          "Régis le Sanctifié",
		"titre":        "Serviteur de la Lumière (Bénévole)",
		"couleur":      Color("#bb9900"),
		"couleur_sombre": Color("#1a1400"),
		"couleur_accent": Color("#ffdd55"),
		"dialogues": [
			"La lumière divine guide mes pas.\nBon, surtout à gauche.\nMais elle essaie.\nToi aussi tu devrais essayer.",
			"Mon bouclier est béni par les dieux.\nJe l'ai béni moi-même ce matin.\nAvec de l'eau du robinet.\nÇa compte quand même.",
			"Le chef a dit qu'on ne volait pas.\nOn 'emprunte pour une juste cause'.\nLa juste cause c'est nos salaires.\nOn est bénévoles en fait.",
			"J'ai prié pendant une heure avant de venir.\nLes dieux n'ont pas vraiment répondu.\nMais ils n'ont pas dit non non plus.\nC'est forcément un signe.",
			"Je fais ça pour le bien supérieur.\nPas pour le trésor du gobelin.\nBon, le trésor aussi.\nC'est pour une bonne cause. La mienne.",
		],
	},
	"elf": {
		"nom":          "Sylvara l'Insaisissable",
		"titre":        "Elfe Supérieure (Objectivement)",
		"couleur":      Color("#228855"),
		"couleur_sombre": Color("#05150a"),
		"couleur_accent": Color("#55ffaa"),
		"dialogues": [
			"Je vis depuis 500 ans.\nJ'ai vu des empires s'effondrer.\nMais jamais un gobelin me battre.\nC'est mon premier vrai combat.",
			"Les elfes sont supérieurs.\nC'est pas de l'arrogance, c'est biologique.\nLe chef a dit d'arrêter de le répéter.\nJe vois pas pourquoi.",
			"Mon arc vient des forêts ancestrales.\nBon, je l'ai acheté à la guilde.\nMais le bois vient peut-être d'une forêt.\nC'est l'intention qui compte.",
			"Personne ne m'a jamais rattrapée.\nUne fois j'ai trébuché.\nMais c'était fait exprès.\nPour déstabiliser l'ennemi.",
			"Je suis là pour l'expérience.\nPas pour voler un gobelin.\nBon, un peu pour voler le gobelin.\nL'expérience de voler un gobelin.",
		],
	},
}

var _sprite_ref: AnimatedSprite2D = null
var _text_label: RichTextLabel = null
var _rot_icon: Label = null
var _anim_timer: float = 0.0
var _chars_shown: float = 0.0

func _enter_tree():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	get_window().content_scale_size = Vector2i(405, 720)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	_build_ui()
	if is_instance_valid(_sprite_ref):
		_sprite_ref.play("idle_down")

func _build_ui():
	var data = BOSS_DATA.get(GameState.boss_type, BOSS_DATA["mage"])

	# Fond principal
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#050309")
	add_child(bg)

	# Layout vertical portrait
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	var header = _creer_header(data)
	header.custom_minimum_size.y = 240
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var dialogue = _creer_dialogue(data)
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialogue)

# ── Header (portrait + nom côte à côte) ─────────────────────────────────────

func _creer_header(data: Dictionary) -> Control:
	var wrapper = Control.new()

	var glow = ColorRect.new()
	glow.color = data["couleur"]
	glow.color.a = 0.12
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(glow)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	wrapper.add_child(hbox)

	# Zone sprite (SubViewport)
	var svc = SubViewportContainer.new()
	svc.custom_minimum_size.x = 160
	svc.size_flags_horizontal = 0
	svc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	hbox.add_child(svc)

	var sv = SubViewport.new()
	sv.size = Vector2i(160, 240)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	var sprite = AnimatedSprite2D.new()
	var tres := "res://assets/sprites/placeholder/body_%s_level_%d_frames.tres" % [GameState.boss_type, GameState.boss_level]
	if ResourceLoader.exists(tres):
		sprite.sprite_frames = load(tres)
	sprite.position = Vector2(80, 110)
	sprite.scale    = Vector2(3.5, 3.5)
	sv.add_child(sprite)
	_sprite_ref = sprite

	var vign = ColorRect.new()
	vign.color    = data["couleur_sombre"]
	vign.color.a  = 0.45
	vign.position = Vector2(0, 170)
	vign.size     = Vector2(160, 70)
	sv.add_child(vign)

	# Infos boss (nom + titre)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	var info_style = StyleBoxFlat.new()
	info_style.bg_color       = data["couleur_sombre"]
	info_style.border_color   = data["couleur"]
	info_style.set_border_width_all(2)
	info.add_theme_stylebox_override("panel", info_style)
	hbox.add_child(info)

	var spacer_top = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer_top)

	var titre_lbl = Label.new()
	titre_lbl.text = data["titre"].to_upper()
	titre_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titre_lbl.add_theme_font_size_override("font_size", 14)
	titre_lbl.add_theme_color_override("font_color", data["couleur"])
	titre_lbl.offset_left = 14
	info.add_child(titre_lbl)

	var nom_lbl = Label.new()
	nom_lbl.text = data["nom"]
	nom_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom_lbl.add_theme_font_size_override("font_size", 28)
	nom_lbl.add_theme_color_override("font_color", Color("#ede0c4"))
	nom_lbl.add_theme_color_override("font_shadow_color", data["couleur"])
	nom_lbl.add_theme_constant_override("shadow_offset_x", 2)
	nom_lbl.add_theme_constant_override("shadow_offset_y", 2)
	nom_lbl.offset_left = 14
	info.add_child(nom_lbl)

	var div = ColorRect.new()
	div.color = data["couleur"]
	div.color.a = 0.5
	div.custom_minimum_size = Vector2(0, 2)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(div)

	var type_str = GameState.boss_type.capitalize()
	var meta_lbl = Label.new()
	meta_lbl.text = "%s  •  Niveau %d" % [type_str, GameState.boss_level]
	meta_lbl.add_theme_font_size_override("font_size", 14)
	meta_lbl.add_theme_color_override("font_color", data["couleur_accent"])
	meta_lbl.modulate = Color(1, 1, 1, 0.65)
	meta_lbl.offset_left = 14
	info.add_child(meta_lbl)

	var spacer_bot = Control.new()
	spacer_bot.custom_minimum_size.y = 6
	info.add_child(spacer_bot)

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
	vbox.offset_left   = 20
	vbox.offset_right  = -20
	vbox.offset_top    = 18
	vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	# Texte du boss (effet machine à écrire)
	var rtl = RichTextLabel.new()
	var dialogue: String
	if data.has("dialogues"):
		dialogue = data["dialogues"][randi() % data["dialogues"].size()]
	else:
		dialogue = data["dialogue"]
	rtl.bbcode_enabled = true
	rtl.scroll_active  = false
	rtl.text = "[color=#ccbbaa][i]" + dialogue + "[/i][/color]"
	rtl.add_theme_font_size_override("normal_font_size", 20)
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
	ctrl_title.add_theme_font_size_override("font_size", 12)
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
		key_lbl.custom_minimum_size.x = 170
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", data["couleur_accent"])
		row.add_child(key_lbl)

		var arrow_lbl = Label.new()
		arrow_lbl.text = "→"
		arrow_lbl.add_theme_font_size_override("font_size", 14)
		arrow_lbl.add_theme_color_override("font_color", data["couleur"])
		row.add_child(arrow_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = hint[1]
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color("#998877"))
		row.add_child(desc_lbl)

	# Indicateur rotation
	var rot_wrap = HBoxContainer.new()
	rot_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	rot_wrap.add_theme_constant_override("separation", 8)
	vbox.add_child(rot_wrap)

	var rot_icon = Label.new()
	rot_icon.text = "↻"
	rot_icon.add_theme_font_size_override("font_size", 28)
	rot_icon.add_theme_color_override("font_color", data["couleur_accent"])
	rot_wrap.add_child(rot_icon)
	_rot_icon = rot_icon

	var rot_lbl = Label.new()
	rot_lbl.text = "Tournez votre téléphone\npour le combat"
	rot_lbl.add_theme_font_size_override("font_size", 15)
	rot_lbl.add_theme_color_override("font_color", data["couleur_accent"])
	rot_lbl.modulate = Color(1, 1, 1, 0.75)
	rot_wrap.add_child(rot_lbl)

	# Bouton PRÊT AU COMBAT
	var btn = Button.new()
	btn.text = "⚔   ENTRER DANS L'ARÈNE"
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 18)
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

	# Rotation icône téléphone
	if is_instance_valid(_rot_icon):
		_rot_icon.pivot_offset = _rot_icon.size / 2.0
		_rot_icon.rotation += delta * 2.2

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
