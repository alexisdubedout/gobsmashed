extends CanvasLayer

const STATS_META = {
	"hp_max":  {"icone": "❤️", "nom": "PV max",  "desc": "+10 PV par niveau"},
	"degats":  {"icone": "⚔️", "nom": "Dégâts",  "desc": "+5% dégâts par niveau"},
	"vitesse": {"icone": "💨", "nom": "Vitesse",  "desc": "+5% vitesse par niveau"},
	"attaque": {"icone": "⚡", "nom": "Cadence",  "desc": "+5% vitesse d'attaque par niveau"},
}

const OBJETS_META = {
	"lit":              {"icone": "🛏️", "nom": "Lit",              "desc": "Régénère des PV entre les waves"},
	"tourelle":         {"icone": "🗼", "nom": "Tourelle",         "desc": "Tire automatiquement sur les ennemis proches"},
	"piege":            {"icone": "🪤", "nom": "Piège",            "desc": "Pose des pièges aléatoires sur le terrain"},
	"bouclier":         {"icone": "🛡️", "nom": "Bouclier",         "desc": "Bloque passivement un projectile toutes les 8s"},
	"bouclier_magique": {"icone": "✨", "nom": "Bouclier magique", "desc": "Le bouclier renvoie aussi le projectile bloqué vers son tireur"},
}

const SKILLS_META = {
	"Pièces lourdes":    {"icone": "💰", "nom": "Lancer appuyé",        "saveur": "Je les jette plus fort. Efficace.\nChaque pièce au sol me brise un peu."},
	"Flaque de poison":  {"icone": "☠️", "nom": "Poches surprises",     "saveur": "Un alchimiste douteux m'a vendu ça.\nPas cher — ce qui m'inquiète."},
	"Multi-shot":        {"icone": "🪙", "nom": "Salve familiale",       "saveur": "Jeter PLUSIEURS pièces à la fois.\nGrand-père se retourne dans sa tombe."},
	"Fortification":     {"icone": "🪨", "nom": "Art d'encaisser",       "saveur": "Un vieux nain m'a enseigné ça.\nIl m'a facturé. Évidemment."},
	"Collègue gobelin":  {"icone": "👺", "nom": "Cousin Vladoslav",      "saveur": "Il travaille pour la famille. Il a négocié\nses propres conditions. J'évite de demander."},
	"Dash éclair":       {"icone": "💨", "nom": "Fuite digne",           "saveur": "Courir, c'est l'affaire des lâches.\nJe cours donc, mais avec beaucoup de dignité."},
	"Drain vital":       {"icone": "🩸", "nom": "Récupération malsaine", "saveur": "Je leur siphonne leur force vitale.\nC'est honteux. Mais c'est pas mes pièces d'or."},
	"Pièces explosives": {"icone": "🧨", "nom": "Héritage volatil",      "saveur": "Des pièces qui explosent. EXPLOSENT.\nJamais remboursé. Jamais pardonné."},
}

var label_or: Label
var label_xp: Label
var scroll_content: VBoxContainer

func _ready():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	get_window().content_scale_size = Vector2i(405, 720)
	_construire_ui()

func _construire_ui():
	# ── Image de fond plein écran ─────────────────────────
	var bg = TextureRect.new()
	bg.texture = load("res://assets/ui/donjon.jpg")
	bg.anchor_left = 0.0
	bg.anchor_right = 1.0
	bg.anchor_top = 0.0
	bg.anchor_bottom = 0.0
	bg.offset_bottom = 400
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	# ── Racine verticale plein écran ──────────────────────
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Zone haute : image visible + titre flottant ───────
	var header_zone = Control.new()
	header_zone.custom_minimum_size.y = 340
	root.add_child(header_zone)
	# Titre et monnaies ancrés en HAUT de la zone image
	var header_top = _creer_header_flottant()
	header_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_zone.add_child(header_top)

	# ── Zone basse : panneau sombre avec le contenu ───────
	var panneau = PanelContainer.new()
	panneau.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style_panneau = StyleBoxFlat.new()
	style_panneau.bg_color = Color("#0f0b05", 0.96)
	style_panneau.set_corner_radius_all(0)
	style_panneau.border_color = Color("#c9922a", 0.4)
	style_panneau.border_width_top = 2
	panneau.add_theme_stylebox_override("panel", style_panneau)
	root.add_child(panneau)

	var panneau_vbox = VBoxContainer.new()
	panneau_vbox.add_theme_constant_override("separation", 0)
	panneau.add_child(panneau_vbox)

	# Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panneau_vbox.add_child(scroll)

	scroll_content = VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 4)
	scroll.add_child(scroll_content)

	_construire_contenu()

	# Bouton jouer fixe en bas du panneau
	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left", 14)
	btn_margin.add_theme_constant_override("margin_right", 14)
	btn_margin.add_theme_constant_override("margin_top", 8)
	btn_margin.add_theme_constant_override("margin_bottom", 12)
	panneau_vbox.add_child(btn_margin)
	btn_margin.add_child(_creer_bouton_jouer())

func _creer_header_flottant() -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Fond semi-transparent derrière le texte pour lisibilité
	var fond = ColorRect.new()
	fond.color = Color("#0f0b05", 0.65)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(fond)

	var inner = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	container.add_child(inner)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	var titre = Label.new()
	titre.text = "Le Donjon"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 30)
	titre.add_theme_color_override("font_color", Color("#c9922a"))
	titre.add_theme_color_override("font_shadow_color", Color("#000000", 0.8))
	titre.add_theme_constant_override("shadow_offset_x", 2)
	titre.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(titre)

	var monnaies = HBoxContainer.new()
	monnaies.alignment = BoxContainer.ALIGNMENT_CENTER
	monnaies.add_theme_constant_override("separation", 30)
	vbox.add_child(monnaies)

	label_or = Label.new()
	label_or.add_theme_font_size_override("font_size", 16)
	label_or.add_theme_color_override("font_color", Color("#e8b84b"))
	label_or.add_theme_color_override("font_shadow_color", Color("#000000", 0.9))
	label_or.add_theme_constant_override("shadow_offset_x", 1)
	label_or.add_theme_constant_override("shadow_offset_y", 1)
	monnaies.add_child(label_or)

	label_xp = Label.new()
	label_xp.add_theme_font_size_override("font_size", 16)
	label_xp.add_theme_color_override("font_color", Color("#88dd88"))
	label_xp.add_theme_color_override("font_shadow_color", Color("#000000", 0.9))
	label_xp.add_theme_constant_override("shadow_offset_x", 1)
	label_xp.add_theme_constant_override("shadow_offset_y", 1)
	monnaies.add_child(label_xp)

	_rafraichir_monnaies()
	return container

func _construire_contenu():
	for c in scroll_content.get_children():
		c.queue_free()

	scroll_content.add_child(_creer_titre_section("⚔️  AMÉLIORATIONS"))
	for stat in GameState.stats:
		scroll_content.add_child(_creer_carte_stat(stat))

	scroll_content.add_child(_creer_separateur())

	scroll_content.add_child(_creer_titre_section("🏚️  OBJETS"))
	for objet in GameState.objets_base:
		if objet == "bouclier_magique" and not GameState.objets_base["bouclier"]:
			continue
		scroll_content.add_child(_creer_carte_objet(objet))

	scroll_content.add_child(_creer_separateur())

	scroll_content.add_child(_creer_titre_section("📜  SAVOIRS DOUTEUX"))
	for skill in GameState.COUT_SKILLS:
		scroll_content.add_child(_creer_carte_skill(skill))

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 6
	scroll_content.add_child(spacer)

# ── Composants ───────────────────────────────────────────

func _creer_titre_section(texte: String) -> Control:
	var wrapper = MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", 16)
	wrapper.add_theme_constant_override("margin_right", 16)
	wrapper.add_theme_constant_override("margin_top", 10)
	wrapper.add_theme_constant_override("margin_bottom", 2)
	var label = Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#c9922a", 0.7))
	wrapper.add_child(label)
	return wrapper

func _creer_carte_stat(stat: String) -> Control:
	var meta = STATS_META[stat]
	var niveau = GameState.stats[stat]
	var maxe = niveau >= GameState.MAX_NIVEAU_STAT
	var cout = GameState.COUT_STATS[stat] * (niveau + 1)
	var peut_acheter = GameState.xp_total >= cout and not maxe

	var wrapper = MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", 10)
	wrapper.add_theme_constant_override("margin_right", 10)
	wrapper.add_theme_constant_override("margin_top", 3)
	wrapper.add_theme_constant_override("margin_bottom", 3)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1c1208", 0.95)
	style.border_color = Color("#c9922a", 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	hbox.add_child(info)

	var nom = Label.new()
	nom.text = meta["icone"] + "  " + meta["nom"]
	nom.add_theme_font_size_override("font_size", 14)
	nom.add_theme_color_override("font_color", Color("#ede0c4"))
	info.add_child(nom)

	var barre = HBoxContainer.new()
	barre.add_theme_constant_override("separation", 3)
	info.add_child(barre)
	for i in GameState.MAX_NIVEAU_STAT:
		var seg = ColorRect.new()
		seg.custom_minimum_size = Vector2(0, 6)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.color = Color("#c9922a") if i < niveau else Color("#2a1a08")
		barre.add_child(seg)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(82, 46)
	if maxe:
		btn.text = "MAX"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color("#c9922a"))
	else:
		btn.text = "✨\n" + str(cout) + " xp"
		btn.disabled = not peut_acheter
		btn.add_theme_color_override("font_color", Color("#88dd88") if peut_acheter else Color("#664433"))
		btn.pressed.connect(func():
			if GameState.acheter_stat(stat):
				_rafraichir_monnaies()
				_construire_contenu()
		)
	hbox.add_child(btn)
	return wrapper

func _creer_carte_objet(objet: String) -> Control:
	var meta = OBJETS_META[objet]
	var achete = GameState.objets_base[objet]
	var cout = GameState.COUT_OBJETS[objet]
	var peut_acheter = GameState.or_total >= cout and not achete

	var wrapper = MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", 10)
	wrapper.add_theme_constant_override("margin_right", 10)
	wrapper.add_theme_constant_override("margin_top", 3)
	wrapper.add_theme_constant_override("margin_bottom", 3)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#c9922a", 0.12) if achete else Color("#1c1208", 0.95)
	style.border_color = Color("#c9922a", 0.6) if achete else Color("#c9922a", 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	hbox.add_child(info)

	var nom = Label.new()
	nom.text = meta["icone"] + "  " + meta["nom"]
	nom.add_theme_font_size_override("font_size", 14)
	nom.add_theme_color_override("font_color", Color("#ede0c4"))
	info.add_child(nom)

	var desc = Label.new()
	desc.text = meta["desc"]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("#907050"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(82, 46)
	if achete:
		btn.text = "✅\nAcheté"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color("#88dd88"))
	else:
		btn.text = "💰\n" + str(cout) + " or"
		btn.disabled = not peut_acheter
		btn.add_theme_color_override("font_color", Color("#e8b84b") if peut_acheter else Color("#664433"))
		btn.pressed.connect(func():
			if GameState.acheter_objet(objet):
				_rafraichir_monnaies()
				_construire_contenu()
		)
	hbox.add_child(btn)
	return wrapper

func _creer_separateur() -> Control:
	var sep_margin = MarginContainer.new()
	sep_margin.add_theme_constant_override("margin_left", 16)
	sep_margin.add_theme_constant_override("margin_right", 16)
	sep_margin.add_theme_constant_override("margin_top", 6)
	sep_margin.add_theme_constant_override("margin_bottom", 6)
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color("#c9922a", 0.25))
	sep_margin.add_child(sep)
	return sep_margin

func _creer_carte_skill(skill: String) -> Control:
	var meta = SKILLS_META[skill]
	var debloque = GameState.skills_debloques.get(skill, false)
	var cout = GameState.COUT_SKILLS[skill]
	var peut_acheter = GameState.xp_total >= cout and not debloque

	var wrapper = MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", 10)
	wrapper.add_theme_constant_override("margin_right", 10)
	wrapper.add_theme_constant_override("margin_top", 3)
	wrapper.add_theme_constant_override("margin_bottom", 3)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#0a1a0a", 0.95) if debloque else Color("#1c1208", 0.95)
	style.border_color = Color("#44aa44", 0.5) if debloque else Color("#c9922a", 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	hbox.add_child(info)

	var nom = Label.new()
	nom.text = meta["icone"] + "  " + meta["nom"]
	nom.add_theme_font_size_override("font_size", 14)
	nom.add_theme_color_override("font_color", Color("#ede0c4"))
	info.add_child(nom)

	var saveur = Label.new()
	saveur.text = meta["saveur"]
	saveur.add_theme_font_size_override("font_size", 10)
	saveur.add_theme_color_override("font_color", Color("#558855") if debloque else Color("#907050"))
	saveur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(saveur)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(82, 46)
	if debloque:
		btn.text = "✅\nAppris"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color("#44aa44"))
	else:
		btn.text = "✨\n" + str(cout) + " xp"
		btn.disabled = not peut_acheter
		btn.add_theme_color_override("font_color", Color("#88dd88") if peut_acheter else Color("#664433"))
		btn.pressed.connect(func():
			if GameState.debloquer_skill(skill):
				_rafraichir_monnaies()
				_construire_contenu()
		)
	hbox.add_child(btn)
	return wrapper

func _creer_bouton_jouer() -> Button:
	var btn = Button.new()
	btn.text = "⚔️   PARTIR EN RUN   ⚔️"
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#1a1208"))

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#c9922a")
	style_normal.set_corner_radius_all(7)
	style_normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color("#e8b84b")
	style_hover.set_corner_radius_all(7)
	style_hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color("#a07020")
	style_pressed.set_corner_radius_all(7)
	style_pressed.set_content_margin_all(10)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_jouer)
	return btn

# ── Logique ──────────────────────────────────────────────

func _rafraichir_monnaies():
	label_or.text = "💰  " + str(GameState.or_total) + " or"
	label_xp.text = "✨  " + str(GameState.xp_total) + " xp"

func _on_jouer():
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
