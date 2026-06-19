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

const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")

var current_wave = 0
var wave_timer = 0.0
var spawn_timer = 0.0
var spawn_radius = 600.0
var player
var wave_active = true
var lit_timer = 0.0
var tourelle_timer = 0.0
var base_position = Vector2.ZERO

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	_placer_base()
	afficher_vague()

func _placer_base():
	var base = Node2D.new()
	base.name = "Base"
	base.z_index = 10
	get_parent().add_child(base)
	base.global_position = player.global_position if player else Vector2.ZERO

	# Test visuel — carré rouge vif
	var test = Polygon2D.new()
	test.polygon = PackedVector2Array([
		Vector2(-30, -30), Vector2(30, -30),
		Vector2(30, 30), Vector2(-30, 30)
	])
	test.color = Color.RED
	base.add_child(test)

	base_position = base.global_position
	print("Base placée à ", base.global_position)

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

	# Lit — soin passif si le joueur est proche de la base
	if GameState.objets_base["lit"]:
		lit_timer += delta
		if lit_timer >= 3.0:
			lit_timer = 0.0
			if player and player.global_position.distance_to(base_position) <= 120.0:
				player.current_hp = min(player.max_hp, player.current_hp + 2)

	# Tourelle — tire sur l'ennemi le plus proche
	if GameState.objets_base["tourelle"]:
		tourelle_timer += delta
		if tourelle_timer >= 1.8:
			tourelle_timer = 0.0
			_tourelle_tirer()

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

func _tourelle_tirer():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var closest_dist = INF
	for enemy in enemies:
		var dist = base_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist <= 350.0:
			closest_dist = dist
			closest = enemy
	if closest == null:
		return
	var coin = COIN_SCENE.instantiate()
	var dir = (closest.global_position - base_position).normalized()
	coin.global_position = base_position + dir * 30.0
	coin.direction = dir
	coin.damage = int(10 * GameState.get_degats_bonus())
	get_tree().current_scene.add_child(coin)

func _vider_ennemis():
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

func _spawner_boss():
	var type = BOSS_TYPES[randi() % BOSS_TYPES.size()]
	var boss = BOSS_SCENE.instantiate()
	boss.setup(type)
	if player:
		boss.global_position = player.global_position + Vector2(0, -500)
	get_parent().add_child(boss)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.afficher_annonce_boss(type)

func afficher_vague():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_wave(current_wave + 1, WAVES.size())
