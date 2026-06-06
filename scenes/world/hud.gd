extends CanvasLayer

var temps = 0.0
var ennemis_tues = 0

func _process(delta):
	temps += delta
	$LabelTimer.text = "⏱ " + str(int(temps)) + "s"
	
	# On récupère les PV du joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		$HBoxContainer/BarreHP.value = player.current_hp
		$HBoxContainer/BarreHP.max_value = player.max_hp

func ajouter_kill():
	ennemis_tues += 1
	$LabelScore.text = "💀 " + str(ennemis_tues)
