extends CanvasLayer

var temps = 0.0
var ennemis_tues = 0
var game_over_screen
var dommages_run: Dictionary = {}

var dash_btn_bg: ColorRect
var dash_cd_lbl: Label
var dash_was_ready: bool = true
var _bandeau_de: Label = null
var _bourse_label: Label = null
var _coffre_label: Label = null
var _coffre_bg: ColorRect = null
var _level_label: Label = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var go = preload("res://scenes/game_over.tscn").instantiate()
	get_tree().current_scene.add_child.call_deferred(go)
	game_over_screen = go
	_creer_bouton_dash()
	_creer_vignette()
	_creer_bourse_label()
	_creer_coffre_indicator()
	_creer_level_label()

func _creer_level_label() -> void:
	_level_label = Label.new()
	_level_label.text = "Niv. 1 / 15"
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", Color("#aaaaaa"))
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_level_label.add_theme_constant_override("shadow_offset_x", 1)
	_level_label.add_theme_constant_override("shadow_offset_y", 1)
	_level_label.offset_left   = 20
	_level_label.offset_top    = 95
	_level_label.offset_right  = 200
	_level_label.offset_bottom = 112
	add_child(_level_label)

func _creer_bourse_label() -> void:
	_bourse_label = Label.new()
	_bourse_label.text = "💰 20 / 30"
	_bourse_label.add_theme_font_size_override("font_size", 13)
	_bourse_label.add_theme_color_override("font_color", Color("#e8c84b"))
	_bourse_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_bourse_label.add_theme_constant_override("shadow_offset_x", 1)
	_bourse_label.add_theme_constant_override("shadow_offset_y", 1)
	_bourse_label.offset_left   = 20
	_bourse_label.offset_top    = 76
	_bourse_label.offset_right  = 200
	_bourse_label.offset_bottom = 95
	add_child(_bourse_label)

func _creer_coffre_indicator() -> void:
	_coffre_bg = ColorRect.new()
	_coffre_bg.color = Color(0, 0, 0, 0.55)
	_coffre_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_coffre_bg.offset_left   = -90
	_coffre_bg.offset_right  = 90
	_coffre_bg.offset_top    = -52
	_coffre_bg.offset_bottom = -28
	_coffre_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_coffre_bg.visible = false
	add_child(_coffre_bg)

	_coffre_label = Label.new()
	_coffre_label.text = ""
	_coffre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coffre_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_coffre_label.add_theme_font_size_override("font_size", 17)
	_coffre_label.add_theme_color_override("font_color", Color("#e8c84b"))
	_coffre_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_coffre_label.add_theme_constant_override("shadow_offset_x", 2)
	_coffre_label.add_theme_constant_override("shadow_offset_y", 2)
	_coffre_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_coffre_label.offset_left   = -90
	_coffre_label.offset_right  = 90
	_coffre_label.offset_top    = -52
	_coffre_label.offset_bottom = -28
	_coffre_label.visible = false
	add_child(_coffre_label)

func _update_coffre_indicator(player) -> void:
	if not _coffre_label:
		return
	var coffres = get_tree().get_nodes_in_group("coffre")
	if coffres.is_empty():
		_coffre_label.visible = false
		if _coffre_bg: _coffre_bg.visible = false
		return
	var coffre = coffres[0]
	var diff_vec = coffre.global_position - player.global_position
	var dist = diff_vec.length()
	_coffre_label.visible = true
	if _coffre_bg: _coffre_bg.visible = true
	if dist < 160.0:
		_coffre_label.text = "COFFRE  ici"
		_coffre_label.add_theme_color_override("font_color", Color("#88ee55"))
	else:
		var arrows = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
		var idx = posmod(roundi(diff_vec.angle() / (PI / 4.0)), 8)
		_coffre_label.text = "COFFRE  %s  %dm" % [arrows[idx], int(dist / 10)]
		_coffre_label.add_theme_color_override("font_color", Color("#e8c84b"))

func _creer_vignette() -> void:
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v  = dot(uv, uv) * 0.55;
	v = clamp(v * v, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.62);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)

func _creer_bouton_dash():
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.offset_left   = -90
	container.offset_top    = -90
	container.offset_right  = -10
	container.offset_bottom = -10
	add_child(container)

	dash_btn_bg = ColorRect.new()
	dash_btn_bg.color = Color("#1a3a5c")
	dash_btn_bg.size  = Vector2(80, 80)
	dash_btn_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(dash_btn_bg)

	var icon = Label.new()
	icon.text = "💨"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 28)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_top = -8
	container.add_child(icon)

	dash_cd_lbl = Label.new()
	dash_cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_cd_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	dash_cd_lbl.add_theme_font_size_override("font_size", 13)
	dash_cd_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	dash_cd_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_cd_lbl.offset_top = 24
	container.add_child(dash_cd_lbl)

	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func():
		var p = get_tree().get_first_node_in_group("player")
		if p: p.dash_requested = true
	)
	container.add_child(btn)

func update_wave(wave: int, total: int):
	$LabelTimer.text = "⚔️ Vague " + str(wave) + " / " + str(total)

func _process(delta):
	temps += delta
	var player = get_tree().get_first_node_in_group("player")
	if player:
		$VBoxContainer/HBoxContainer/BarreHP.value = player.current_hp
		$VBoxContainer/HBoxContainer/BarreHP.max_value = player.max_hp
		$VBoxContainer/HBoxContainer2/BarreXP.value = player.xp
		$VBoxContainer/HBoxContainer2/BarreXP.max_value = player.xp_next_level
		_update_bouton_dash(player)
		_update_bourse(player)
		_update_coffre_indicator(player)
		if _level_label:
			var lv = player.level
			var max_lv = (player.MAX_LEVEL - 1)
			if lv >= player.MAX_LEVEL:
				_level_label.text = "Niv. MAX"
				_level_label.add_theme_color_override("font_color", Color("#e8c84b"))
				$VBoxContainer/HBoxContainer2/BarreXP.value = $VBoxContainer/HBoxContainer2/BarreXP.max_value
			else:
				_level_label.text = "Niv. %d / %d" % [lv, max_lv]
				_level_label.add_theme_color_override("font_color",
					Color("#e8c84b") if lv >= max_lv else Color("#aaaaaa"))

func _update_bourse(player) -> void:
	if not _bourse_label:
		return
	var b: int = player.get("bourse") if player.get("bourse") != null else 0
	var bm: int = player.get("bourse_max") if player.get("bourse_max") != null else 30
	_bourse_label.text = "💰 %d / %d" % [b, bm]
	var couleur: Color
	if b <= 5:
		couleur = Color("#dd4444")
	elif b <= 12:
		couleur = Color("#e8a030")
	else:
		couleur = Color("#e8c84b")
	_bourse_label.add_theme_color_override("font_color", couleur)

func _update_bouton_dash(player) -> void:
	if not dash_btn_bg: return
	var ready = player.dash_cd <= 0.05
	if ready:
		dash_btn_bg.color = Color("#1a5c3a")
		dash_cd_lbl.text = ""
		if not dash_was_ready:
			dash_was_ready = true
			_flash_dash_pret()
	else:
		dash_was_ready = false
		var ratio = player.dash_cd / player.dash_cd_dur
		dash_btn_bg.color = Color("#1a3a5c").lerp(Color("#0d1a2e"), ratio)
		dash_cd_lbl.text = "%.1f" % player.dash_cd

func _flash_dash_pret():
	if not dash_btn_bg: return
	dash_btn_bg.color = Color("#88ffcc")
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(dash_btn_bg):
		dash_btn_bg.color = Color("#1a5c3a")

func ajouter_kill():
	ennemis_tues += 1
	$LabelScore.text = "💀 " + str(ennemis_tues)

func afficher_annonce_boss(type: String):
	var noms = {
		"guerrier": "Grug le Magnifique",
		"paladin":  "Régis le Sanctifié",
		"elf":      "Sylvara l'Insaisissable",
		"mage":     "Nadège la Ténébreuse",
	}
	var label = Label.new()
	label.text = "★  " + noms.get(type, "Boss") + "  ★\napproche..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("#ff4444"))
	label.add_theme_color_override("font_shadow_color", Color("#000000", 1.0))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -40
	label.offset_bottom = 40
	add_child(label)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(label):
		label.queue_free()

const DE_COULEURS := {
	"mauvais": Color("#dd4444"),
	"neutre":  Color("#aaaabb"),
	"bon":     Color("#55cc77"),
}

const DieFaceScript := preload("res://scenes/world/die_face.gd")

func lancer_de() -> int:
	# Probabilités pipées : favorise les bons effets (rétention post-pub)
	# 30% mauvais (1-2) | 15% neutre (3-4) | 55% bon (5-6)
	var _r := randf()
	var resultat: int
	if _r < 0.30:
		resultat = randi_range(1, 2)
	elif _r < 0.45:
		resultat = randi_range(3, 4)
	else:
		resultat = randi_range(5, 6)
	get_tree().paused = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var titre := Label.new()
	titre.text = "Une présence ancienne s'éveille...\nLe Dé du Destin va décider du sort\nde cette traversée. Bonne ou funeste,\nsa volonté s'imposera jusqu'au combat final."
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 15)
	titre.add_theme_color_override("font_color", Color("#cccccc"))
	titre.set_anchors_preset(Control.PRESET_CENTER)
	titre.offset_left = -220; titre.offset_right = 220
	titre.offset_top = -190; titre.offset_bottom = -100
	overlay.add_child(titre)

	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(overlay):
		get_tree().paused = false
		return resultat

	var die := Control.new()
	die.set_script(DieFaceScript)
	die.size = Vector2(110, 110)
	die.pivot_offset = Vector2(55, 55)
	die.set("face", 1)
	die.set_anchors_preset(Control.PRESET_CENTER)
	die.offset_left = -55; die.offset_right = 55
	die.offset_top = -55; die.offset_bottom = 55
	overlay.add_child(die)

	# Roulement : vite au début, ralentit fortement en fin de course
	var steps := 16
	for i in steps:
		die.set("face", randi_range(1, 6))
		var t := float(i) / float(steps - 1)
		var delay: float = lerp(0.04, 0.34, pow(t, 2.4))
		var wobble := die.create_tween()
		wobble.tween_property(die, "rotation", randf_range(-0.35, 0.35), delay * 0.5)
		wobble.tween_property(die, "rotation", 0.0, delay * 0.5)
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(overlay):
			get_tree().paused = false
			return resultat
	die.set("face", resultat)
	die.rotation = 0.0

	var settle := die.create_tween()
	settle.tween_property(die, "scale", Vector2(1.25, 1.25), 0.12).set_ease(Tween.EASE_OUT)
	settle.tween_property(die, "scale", Vector2(1.0, 1.0), 0.18).set_ease(Tween.EASE_IN)

	var effet: Dictionary = GameState.appliquer_de(resultat)
	var couleur: Color = DE_COULEURS.get(effet.get("qualite", "neutre"), Color("#aaaabb"))

	var lbl_nom := Label.new()
	lbl_nom.text = str(resultat) + " — " + effet.get("nom", "")
	lbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nom.add_theme_font_size_override("font_size", 22)
	lbl_nom.add_theme_color_override("font_color", couleur)
	lbl_nom.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	lbl_nom.add_theme_constant_override("shadow_offset_x", 2)
	lbl_nom.add_theme_constant_override("shadow_offset_y", 2)
	lbl_nom.set_anchors_preset(Control.PRESET_CENTER)
	lbl_nom.offset_left = -220; lbl_nom.offset_right = 220
	lbl_nom.offset_top = 75; lbl_nom.offset_bottom = 105
	overlay.add_child(lbl_nom)

	var lbl_desc := Label.new()
	lbl_desc.text = effet.get("desc", "")
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 14)
	lbl_desc.add_theme_color_override("font_color", Color("#dddddd"))
	lbl_desc.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	lbl_desc.add_theme_constant_override("shadow_offset_x", 1)
	lbl_desc.add_theme_constant_override("shadow_offset_y", 1)
	lbl_desc.set_anchors_preset(Control.PRESET_CENTER)
	lbl_desc.offset_left = -190; lbl_desc.offset_right = 190
	lbl_desc.offset_top = 110; lbl_desc.offset_bottom = 168
	overlay.add_child(lbl_desc)

	await get_tree().create_timer(2.8).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()

	get_tree().paused = false
	_afficher_bandeau_de(resultat, effet)
	return resultat

func _afficher_bandeau_de(resultat: int, effet: Dictionary):
	if is_instance_valid(_bandeau_de):
		_bandeau_de.queue_free()
	var couleur: Color = DE_COULEURS.get(effet.get("qualite", "neutre"), Color("#aaaabb"))
	_bandeau_de = Label.new()
	_bandeau_de.text = str(resultat) + " — " + effet.get("nom", "")
	_bandeau_de.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bandeau_de.add_theme_font_size_override("font_size", 13)
	_bandeau_de.add_theme_color_override("font_color", couleur)
	_bandeau_de.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_bandeau_de.add_theme_constant_override("shadow_offset_x", 1)
	_bandeau_de.add_theme_constant_override("shadow_offset_y", 1)
	_bandeau_de.offset_left = 110
	_bandeau_de.offset_right = 340
	_bandeau_de.offset_top = 50
	_bandeau_de.offset_bottom = 73
	add_child(_bandeau_de)

func enregistrer_dommage(source_type: String, amount: int) -> void:
	dommages_run[source_type] = dommages_run.get(source_type, 0) + amount

func afficher_game_over(vague: int):
	var or_gagne = ennemis_tues * 5
	var xp_gagne = int(temps * 2)
	GameState.ajouter_recompense(ennemis_tues, temps)
	GameState.ajouter_dommages(dommages_run)
	if game_over_screen:
		game_over_screen.afficher(ennemis_tues, temps, vague, or_gagne, xp_gagne, dommages_run)
