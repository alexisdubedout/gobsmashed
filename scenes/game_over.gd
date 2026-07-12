extends CanvasLayer

const NOMS_TYPES = {
	"guerrier": "Guerriers",
	"paladin":  "Paladins",
	"elf":      "Archers",
	"mage":     "Mages",
	"?":        "Inconnus",
}

var label_vague_val  : Label
var label_kills_val  : Label
var label_temps_val  : Label
var label_or_val     : Label
var label_xp_val     : Label
var label_top_dmg    : Label
var _recap: CanvasLayer = null

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	visible = false
	$Button.pressed.connect(_on_rejouer)
	$ButtonDonjon.pressed.connect(_on_donjon)
	label_vague_val = $LabelVague
	label_kills_val = $LabelKills
	label_temps_val = $LabelTemps

	label_top_dmg = Label.new()
	label_top_dmg.offset_left   = 3.0
	label_top_dmg.offset_top    = 248.0
	label_top_dmg.offset_right  = 405.0
	label_top_dmg.offset_bottom = 300.0
	add_child(label_top_dmg)

	label_or_val = Label.new()
	label_or_val.offset_left   = 3.0
	label_or_val.offset_top    = 308.0
	label_or_val.offset_right  = 205.0
	label_or_val.offset_bottom = 355.0
	add_child(label_or_val)

	label_xp_val = Label.new()
	label_xp_val.offset_left   = 205.0
	label_xp_val.offset_top    = 308.0
	label_xp_val.offset_right  = 405.0
	label_xp_val.offset_bottom = 355.0
	add_child(label_xp_val)

	var btn_chrono = Button.new()
	btn_chrono.offset_left   = 15.0
	btn_chrono.offset_top    = 368.0
	btn_chrono.offset_right  = 390.0
	btn_chrono.offset_bottom = 408.0
	btn_chrono.flat = true
	btn_chrono.text = "📜  Chroniques de la Débâcle"
	btn_chrono.add_theme_font_size_override("font_size", 15)
	btn_chrono.add_theme_color_override("font_color", Color("#c8a96e"))
	btn_chrono.pressed.connect(_ouvrir_chroniques)
	add_child(btn_chrono)

func afficher(p_kills: int, p_temps: float, p_vague: int, p_or: int = 0, p_xp: int = 0, p_dommages: Dictionary = {}):
	visible = true
	var minutes = int(p_temps) / 60
	var secondes = int(p_temps) % 60
	_styler_label(label_vague_val, "Vague atteinte : " + str(p_vague) + " / 10")
	_styler_label(label_kills_val, "Héros vaincus : " + str(p_kills))
	_styler_label(label_temps_val, "Temps perdu : " + str(minutes) + "m " + str(secondes) + "s")
	_styler_label(label_or_val, "🪙 +" + str(p_or))
	_styler_label(label_xp_val, "✨ +" + str(p_xp) + " xp")
	if p_dommages.is_empty():
		_styler_label(label_top_dmg, "")
	else:
		var sorted = p_dommages.keys()
		sorted.sort_custom(func(a, b): return p_dommages[a] > p_dommages[b])
		var top = sorted[0]
		_styler_label(label_top_dmg, "⚔️ Pire ennemi : " + NOMS_TYPES.get(top, top) + " (" + str(p_dommages[top]) + " dmg)")
	await get_tree().create_timer(0.1).timeout
	if get_tree():
		get_tree().paused = true

func _ouvrir_chroniques():
	if _recap == null:
		var script = preload("res://scenes/recap_general.gd")
		_recap = CanvasLayer.new()
		_recap.set_script(script)
		_recap.layer = layer + 1
		get_tree().current_scene.add_child(_recap)
	_recap.afficher()

func _styler_label(lbl: Label, texte: String):
	lbl.text = texte
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color("#e8b84b"))
	lbl.add_theme_color_override("font_shadow_color", Color("#000000"))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)

func _on_rejouer():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _on_donjon():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/donjon.tscn")
