extends CanvasLayer

var temps = 0.0
var ennemis_tues = 0
var game_over_screen

var dash_btn_bg: ColorRect
var dash_cd_lbl: Label
var dash_was_ready: bool = true

func _ready():
	var go = preload("res://scenes/game_over.tscn").instantiate()
	get_tree().current_scene.add_child.call_deferred(go)
	game_over_screen = go
	_creer_bouton_dash()

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
		"guerrier": "Le Guerrier Légendaire",
		"paladin": "Le Paladin Maudit",
		"elf": "L'Elfe Fantôme",
		"mage": "Le Grand Mage",
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

func afficher_game_over(vague: int):
	GameState.ajouter_recompense(ennemis_tues, temps)
	if game_over_screen:
		game_over_screen.afficher(ennemis_tues, temps, vague)
