extends CharacterBody2D

const TEXTURES = {
	"guerrier": "res://assets/characters/Guerrier.png",
	"paladin":  "res://assets/characters/Paladin.png",
	"elf":      "res://assets/characters/Elf.png",
	"mage":     "res://assets/characters/Mage.png",
}

var boss_type: String = ""
var speed: float = 55.0
var aura_timer: float = 0.0
var transition_triggered: bool = false

func setup(type: String):
	boss_type = type

func _ready():
	_setup_visuals()
	_creer_indicateur()

func _setup_visuals():
	scale = Vector2(2.5, 2.5)
	if boss_type in TEXTURES:
		$Sprite2D.texture = load(TEXTURES[boss_type])
	$Sprite2D.hframes = 8
	$Sprite2D.vframes = 4

func _creer_indicateur():
	var label = Label.new()
	label.text = "★ BOSS ★"
	label.position = Vector2(-35, -52)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#ff4444"))
	label.add_theme_color_override("font_shadow_color", Color("#000000", 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

func take_damage(_amount):
	pass  # Invulnérable dans la phase top-down

func _physics_process(delta):
	if transition_triggered:
		return

	aura_timer += delta
	var pulse = (sin(aura_timer * 4.0) + 1.0) * 0.5
	$Sprite2D.modulate = Color(1.0 + pulse * 0.6, 0.15, 0.15, 1.0)
	$Sprite2D.frame = int(aura_timer * 6) % 8

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	if global_position.distance_to(player.global_position) < 65.0:
		_declencher_combat(player)

func _declencher_combat(player):
	transition_triggered = true
	GameState.boss_type = boss_type
	GameState.boss_hp_joueur = player.current_hp

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		GameState.boss_kills_run = hud.ennemis_tues
		GameState.boss_temps_run = hud.temps

	get_tree().change_scene_to_file("res://scenes/boss_fight/boss_intro.tscn")
