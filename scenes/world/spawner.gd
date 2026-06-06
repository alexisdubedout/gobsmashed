extends Node2D

const ENEMIES = [
	preload("res://scenes/enemies/paladin.tscn"),
	preload("res://scenes/enemies/elf.tscn"),
	preload("res://scenes/enemies/mage.tscn"),
	preload("res://scenes/enemies/enemy.tscn"),
]

var spawn_delay = 2.0
var enemy_speed = 80.0
var min_spawn_delay = 0.3
var max_enemy_speed = 220.0
var difficulty_interval = 15.0
var player
var spawn_timer = 0.0
var difficulty_timer = 0.0
var spawn_radius = 400.0

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not player:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_delay:
		spawn_timer = 0.0
		spawn_enemy()
	difficulty_timer += delta
	if difficulty_timer >= difficulty_interval:
		difficulty_timer = 0.0
		increase_difficulty()

func spawn_enemy():
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	var scene = ENEMIES[randi() % ENEMIES.size()]
	print("Spawn : ", scene.resource_path)
	var enemy = scene.instantiate()
	enemy.global_position = player.global_position + offset
	enemy.speed = enemy_speed
	enemy.base_speed = enemy_speed
	get_parent().add_child(enemy)

func increase_difficulty():
	spawn_delay = max(min_spawn_delay, spawn_delay - 0.2)
	enemy_speed = min(max_enemy_speed, enemy_speed + 15.0)
	print("Difficulté ! Spawn: ", spawn_delay, "s | Vitesse: ", enemy_speed)
