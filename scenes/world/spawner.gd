extends Node2D

const ENEMIES = {
	"guerrier": preload("res://scenes/enemies/guerrier.tscn"),
	"paladin": preload("res://scenes/enemies/paladin.tscn"),
	"elf": preload("res://scenes/enemies/elf.tscn"),
	"mage": preload("res://scenes/enemies/mage.tscn"),
}
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const BOSS_TYPES = ["guerrier", "paladin", "elf", "mage"]


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

func _input(event: InputEvent):
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key and key.pressed and key.keycode == KEY_F9:
		wave_active = false
		_vider_ennemis()
		_spawner_boss()

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
		_vider_ennemis()
		_spawner_boss()
		return
	if GameState.objets_base["lit"] and player:
		player.current_hp = min(player.max_hp, player.current_hp + 20)
	afficher_vague()

func _vider_ennemis():
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

func _spawner_boss():
	var type = BOSS_TYPES[randi() % BOSS_TYPES.size()]
	var boss_pos: Vector2 = player.global_position + Vector2(0, -160) if player else Vector2.ZERO

	var boss = BOSS_SCENE.instantiate()
	boss.setup(type)
	boss.global_position = boss_pos
	get_parent().add_child(boss)

	# Surprise : horde de renforts du même type depuis tous les bords
	_spawner_renforts_boss(type)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.afficher_annonce_boss(type)

func _spawner_renforts_boss(type: String):
	var nb := 6
	for i in nb:
		var angle := i * TAU / nb + randf_range(-0.2, 0.2)
		var enemy = ENEMIES[type].instantiate()
		enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
		get_parent().add_child(enemy)

func afficher_vague():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_wave(current_wave + 1, WAVES.size())
