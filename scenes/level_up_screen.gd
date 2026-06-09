extends CanvasLayer

const AUGMENTS = Augments.LISTE
var player

func _ready():
	player = get_tree().get_first_node_in_group("player")
	visible = false

func afficher(cartes):
	visible = true
	if get_tree():
		get_tree().paused = true
	
	for child in $CenterContainer/Cartes.get_children():
		child.queue_free()
	
	for augment in cartes:
		var carte = _creer_carte(augment)
		$CenterContainer/Cartes.add_child(carte)

func _creer_carte(augment: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 180)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2a1f0e")
	style.border_color = Color("#c9922a")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var icone = Label.new()
	icone.text = augment.get("icone", "⚔️")
	icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icone.add_theme_font_size_override("font_size", 28)
	vbox.add_child(icone)
	
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color("#c9922a")
	sep_style.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)
	
	var nom = Label.new()
	nom.text = augment["nom"]
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD
	nom.add_theme_font_size_override("font_size", 11)
	nom.add_theme_color_override("font_color", Color("#e8b84b"))
	vbox.add_child(nom)

	var stack_actuel = Augments.stacks.get(augment["nom"], 0)
	if stack_actuel > 0:
		var stack_label = Label.new()
		stack_label.text = "★ " + str(stack_actuel) + " / 3"
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_label.add_theme_font_size_override("font_size", 10)
		stack_label.add_theme_color_override("font_color", Color("#ff6b35"))
		vbox.add_child(stack_label)
	
	var desc = Label.new()
	desc.text = Augments.get_desc(augment)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color("#c8b89a"))
	vbox.add_child(desc)
	
	var btn = Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_carte_choisie.bind(augment))
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(btn)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)
	
	return panel

func _on_carte_choisie(augment):
	visible = false
	if get_tree():
		get_tree().paused = false
	appliquer_augment(augment)

func appliquer_augment(augment):
	var p = get_tree().get_first_node_in_group("player")
	if p:
		Augments.appliquer(augment, p)
