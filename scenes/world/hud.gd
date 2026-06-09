extends CanvasLayer

var temps = 0.0
var ennemis_tues = 0
var game_over_screen

func _ready():
	var go = preload("res://scenes/game_over.tscn").instantiate()
	get_tree().current_scene.add_child.call_deferred(go)
	game_over_screen = go

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

func ajouter_kill():
	ennemis_tues += 1
	$LabelScore.text = "💀 " + str(ennemis_tues)

func afficher_game_over(vague: int):
	GameState.ajouter_recompense(ennemis_tues, temps)
	if game_over_screen:
		game_over_screen.afficher(ennemis_tues, temps, vague)
