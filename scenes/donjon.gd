extends CanvasLayer

func _ready():
	_construire_ui()

func _construire_ui():
	var bg = ColorRect.new()
	bg.color = Color("#000000dd")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Titre
	var titre = Label.new()
	titre.text = "LE DONJON"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 36)
	titre.add_theme_color_override("font_color", Color("#c9922a"))
	vbox.add_child(titre)

	# Monnaies
	var or_label = Label.new()
	or_label.text = "Or : " + str(GameState.or_total)
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_color_override("font_color", Color("#e8b84b"))
	vbox.add_child(or_label)

	var xp_label = Label.new()
	xp_label.text = "XP : " + str(GameState.xp_total)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_color_override("font_color", Color("#aaffaa"))
	vbox.add_child(xp_label)

	# Stats
	var stats_titre = Label.new()
	stats_titre.text = "--- STATS ---"
	stats_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_titre.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(stats_titre)

	for stat in GameState.stats:
		vbox.add_child(_creer_bouton_stat(stat))

	# Objets
	var objets_titre = Label.new()
	objets_titre.text = "--- OBJETS ---"
	objets_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objets_titre.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(objets_titre)

	for objet in GameState.objets_base:
		vbox.add_child(_creer_bouton_objet(objet))

	# Bouton jouer
	var btn_jouer = Button.new()
	btn_jouer.text = "JOUER"
	btn_jouer.custom_minimum_size = Vector2(200, 50)
	btn_jouer.pressed.connect(_on_jouer)
	vbox.add_child(btn_jouer)

func _creer_bouton_stat(stat: String) -> Button:
	var niveau = GameState.stats[stat]
	var cout = GameState.COUT_STATS[stat] * (niveau + 1)
	var btn = Button.new()
	btn.text = stat + " (niv " + str(niveau) + ") — " + str(cout) + " xp"
	btn.custom_minimum_size = Vector2(300, 40)
	btn.pressed.connect(func():
		if GameState.acheter_stat(stat):
			get_tree().reload_current_scene()
	)
	return btn

func _creer_bouton_objet(objet: String) -> Button:
	var achete = GameState.objets_base[objet]
	var cout = GameState.COUT_OBJETS[objet]
	var btn = Button.new()
	if achete:
		btn.text = objet + " — ACHETÉ"
		btn.disabled = true
	else:
		btn.text = objet + " — " + str(cout) + " or"
		btn.pressed.connect(func():
			if GameState.acheter_objet(objet):
				get_tree().reload_current_scene()
		)
	return btn

func _on_jouer():
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
