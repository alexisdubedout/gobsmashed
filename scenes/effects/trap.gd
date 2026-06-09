extends Node2D

const ENEMIES = {
	"guerrier": preload("res://scenes/enemies/guerrier.tscn"),
	"paladin": preload("res://scenes/enemies/paladin.tscn"),
	"elf": preload("res://scenes/enemies/elf.tscn"),
	"mage": preload("res://scenes/enemies/mage.tscn"),
}

# Définition des vagues
# Chaque vague : durée en secondes + quels ennemis spawner
const WAVES = [
	{"duree": 30, "ennemis": ["guerrier"], "spawn_delay": 2.0},
	{"duree": 40, "ennemis": ["guerrier", "elf"], "spawn_delay": 1.5},
	{"duree": 40, "ennemis": ["guerrier", "elf", "paladin"], "spawn_delay": 1.3},
	{"duree": 50, "ennemis": ["guerrier", "elf", "paladin", "mage"], "spawn_delay": 1.0},
	{"duree": 50, "ennemis": ["paladin", "mage", "elf"], "spawn_delay": 0.8},
	{"duree": 60, "ennemis": ["guerrier", "paladin", "mage", "elf"], "spawn_delay": 0.6},
]

var current_wave = 0
var wave_timer = 0.0
var spawn_timer = 0.0
var spawn_radius = 400.0
var player
var wave_active = true

func _ready():
	player = get_tree().get_first_node_in_group("player")
	afficher_vague()

func _process(delta):
	if not player or not wave_active:
		return
	
	# Timer de la vague
	wave_timer += delta
	var vague = WAVES[current_wave]
	
	# Spawn continu pendant la vague
	spawn_timer += delta
	if spawn_timer >= vague["spawn_delay"]:
		spawn_timer = 0.0
		spawn_enemy(vague["ennemis"])
	
	# Fin de vague
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
	
	# Toutes les vagues terminées → BOSS
	if current_wave >= WAVES.size():
		wave_active = false
		print("BOSS !")
		# On déclenchera le boss ici plus tard
		return
	
	# Moment de répit — on vide les ennemis restants
	afficher_vague()

func afficher_vague():
	print("=== VAGUE ", current_wave + 1, " / ", WAVES.size(), " ===")
	# On mettra à jour le HUD ici
