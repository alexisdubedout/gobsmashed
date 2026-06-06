extends CanvasLayer

# Liste de tous les augments possibles
const AUGMENTS = Augments.LISTE

var player

func _ready():
	player = get_tree().get_first_node_in_group("player")
	visible = false

func afficher(cartes):
	print("Visible avant : ", visible)
	print("Est dans le tree : ", is_inside_tree())
	visible = true
	print("Visible après : ", visible)
	if get_tree():
		get_tree().paused = true
	
	# On vide les cartes existantes
	for child in $CenterContainer/Cartes.get_children():
		child.queue_free()
	
	# On crée 3 boutons de cartes
	for augment in cartes:
		var btn = Button.new()
		btn.text = "[ " + augment["nom"] + " ]\n\n" + augment["desc"]
		btn.custom_minimum_size = Vector2(220, 150)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_carte_choisie.bind(augment))
		$CenterContainer/Cartes.add_child(btn)

func _on_carte_choisie(augment):
	visible = false
	if get_tree():
		get_tree().paused = false
	appliquer_augment(augment)

func appliquer_augment(augment):
	var p = get_tree().get_first_node_in_group("player")
	if p:
		Augments.appliquer(augment, p)
