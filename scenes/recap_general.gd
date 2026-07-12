extends CanvasLayer

const NOMS_TYPES = {
	"guerrier": "Guerriers",
	"paladin":  "Paladins",
	"elf":      "Archers",
	"mage":     "Mages",
}

const ICONES_TYPES = {
	"guerrier": "⚔️",
	"paladin":  "🛡️",
	"elf":      "🏹",
	"mage":     "🔮",
}

var _overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.04, 0.08, 0.96)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.visible = false

func afficher():
	_overlay.visible = true
	for child in _overlay.get_children():
		child.queue_free()

	_ajouter_label("📜  Le Livre des Défaites", 52, Color("#c8a96e"), 28, true)
	_ajouter_label("— Mémoires d'un gobelin peu chanceux —", 95, Color("#8888aa"), 13, true)

	_ajouter_separateur(125)

	var morts = GameState.morts_totales
	var or_c  = GameState.or_cumule
	_ajouter_label("💀  Déroutes mémorables", 148, Color("#cc6666"), 16, false)
	_ajouter_label(str(morts) + " fois terrassé", 172, Color("#eeeeee"), 20, true)

	_ajouter_label("🪙  Pillage total", 212, Color("#e8b84b"), 16, false)
	_ajouter_label(str(or_c) + " pièces d'or extorquées", 236, Color("#eeeeee"), 20, true)

	_ajouter_separateur(268)

	_ajouter_label("🗡️  Tes pires cauchemars", 288, Color("#cc8844"), 16, false)

	var dmg = GameState.dommages_cumules
	if dmg.is_empty():
		_ajouter_label("(aucune donnée encore)", 318, Color("#666688"), 14, true)
	else:
		var sorted = dmg.keys()
		sorted.sort_custom(func(a, b): return dmg[a] > dmg[b])
		var y = 318.0
		for i in min(3, sorted.size()):
			var t = sorted[i]
			var ico = ICONES_TYPES.get(t, "👹")
			var nom = NOMS_TYPES.get(t, t)
			var txt = str(i + 1) + ".  " + ico + " " + nom + "  —  " + str(dmg[t]) + " dmg"
			var col = [Color("#ff8866"), Color("#ddaa55"), Color("#aaaacc")][i]
			_ajouter_label(txt, y, col, 16, false)
			y += 38.0

	var btn_fermer = Button.new()
	btn_fermer.offset_left   = 80.0
	btn_fermer.offset_top    = 530.0
	btn_fermer.offset_right  = 320.0
	btn_fermer.offset_bottom = 575.0
	btn_fermer.flat = true
	btn_fermer.text = "Fermer"
	btn_fermer.add_theme_font_size_override("font_size", 18)
	btn_fermer.add_theme_color_override("font_color", Color("#888899"))
	btn_fermer.pressed.connect(func(): _overlay.visible = false)
	_overlay.add_child(btn_fermer)

func _ajouter_label(texte: String, y: float, couleur: Color, taille: int, centrer: bool):
	var lbl = Label.new()
	lbl.text = texte
	lbl.add_theme_font_size_override("font_size", taille)
	lbl.add_theme_color_override("font_color", couleur)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.offset_left   = 20.0
	lbl.offset_top    = y
	lbl.offset_right  = 385.0
	lbl.offset_bottom = y + taille + 10.0
	if centrer:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(lbl)

func _ajouter_separateur(y: float):
	var sep = ColorRect.new()
	sep.color = Color("#334455")
	sep.offset_left   = 30.0
	sep.offset_top    = y
	sep.offset_right  = 375.0
	sep.offset_bottom = y + 2.0
	_overlay.add_child(sep)
