extends Node2D

const ENEMIES = {
	"guerrier": preload("res://scenes/enemies/guerrier.tscn"),
	"paladin": preload("res://scenes/enemies/paladin.tscn"),
	"elf": preload("res://scenes/enemies/elf.tscn"),
	"mage": preload("res://scenes/enemies/mage.tscn"),
	}


const WAVES = [
	{"duree": 25, "ennemis": ["guerrier"], "spawn_delay": 2.5},
	{"duree": 30, "ennemis": ["guerrier", "elf"], "spawn_delay": 2.0},
	{"duree": 35, "ennemis": ["guerrier", "elf", "paladin"], "spawn_delay": 1.5},
	{"duree": 40, "ennemis": ["paladin", "mage"], "spawn_delay": 1.1},
	{"duree": 45, "ennemis": ["paladin", "mage", "elf"], "spawn_delay": 0.8},
	{"duree": 60, "ennemis": ["guerrier", "paladin", "mage", "elf"], "spawn_delay": 0.8, "spawn_delay_end": 0.4},
]

var current_wave = 0
var wave_timer = 0.0
var spawn_timer = 0.0
var spawn_radius = 600.0
var player
var wave_active = true

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	afficher_vague()

func _process(delta):
	if not player or not wave_active:
		return
	
	wave_timer += delta
	var vague = WAVES[current_wave]
	
	var current_delay = vague["spawn_delay"]
	if vague.has("spawn_delay_end"):
		current_delay = lerp(vague["spawn_delay"], vague["spawn_delay_end"], wave_timer / vague["duree"])

	spawn_timer += delta
	if spawn_timer >= current_delay:
		spawn_timer = 0.0
		spawn_enemy(vague["ennemis"])
	
	if wave_timer >= vague["duree"]:
		wave_timer = 0.0
		next_wave()

func spawn_enemy(pool: Array):
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	var type = pool[randi() % pool.size()]
	var enemy = ENEMIES[type].instantiate()
	enemy.global_position = player.global_position + offset
	get_parent().add_child(enemy)

func next_wave():
	current_wave += 1
	if current_wave >= WAVES.size():
		wave_active = false
		print("BOSS !")
		return
	afficher_vague()

func afficher_vague():
	print("=== VAGUE ", current_wave + 1, " / ", WAVES.size(), " ===")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_wave(current_wave + 1, WAVES.size())
