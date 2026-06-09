extends CanvasLayer

var label_vague_val : Label
var label_kills_val : Label
var label_temps_val : Label

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	visible = false
	$Button.pressed.connect(_on_rejouer)
	$ButtonDonjon.pressed.connect(_on_donjon)
	label_vague_val = $LabelVague
	label_kills_val = $LabelKills
	label_temps_val = $LabelTemps

func afficher(p_kills: int, p_temps: float, p_vague: int):
	visible = true
	var minutes = int(p_temps) / 60
	var secondes = int(p_temps) % 60
	_styler_label(label_vague_val, "Vague atteinte : " + str(p_vague) + " / 6")
	_styler_label(label_kills_val, "Héros vaincus : " + str(p_kills))
	_styler_label(label_temps_val, "Temps perdu : " + str(minutes) + "m " + str(secondes) + "s")
	await get_tree().create_timer(0.1).timeout
	if get_tree():
		get_tree().paused = true

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
