extends CharacterBody2D

const SPEED = 120.0
const ATTACK_DELAY = 1.2
const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")
const MAP_HALF   = 895.0
const TELEPORT_DIST = 500.0

var attack_timer = 0.0
var player

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var dist_player = global_position.distance_to(player.global_position)

	# Téléportation de secours si trop loin
	if dist_player > TELEPORT_DIST:
		var angle = randf() * TAU
		global_position = player.global_position + Vector2(cos(angle), sin(angle)) * 60.0

	if dist_player > 80:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# Reste dans les limites de la carte
	global_position.x = clampf(global_position.x, -MAP_HALF, MAP_HALF)
	global_position.y = clampf(global_position.y, -MAP_HALF, MAP_HALF)

	attack_timer += _delta
	var af = player.allies_fervents
	var speed_mult = 1.0
	if player.ally_fast or af >= 1: speed_mult = 0.7
	if af >= 2: speed_mult = 0.5
	if af >= 3: speed_mult = 0.3
	if attack_timer >= ATTACK_DELAY * speed_mult:
		attack_timer = 0.0
		shoot()

func shoot():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var closest = null
	var closest_dist = INF
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	if closest == null:
		return
	_tirer_vers(closest.global_position)

func _tirer_vers(target_pos: Vector2) -> void:
	var coin = COIN_SCENE.instantiate()
	var dir = (target_pos - global_position).normalized()
	coin.global_position = global_position + dir * 30.0
	coin.direction = dir
	# Dégâts : base 15 + rage joueur + bonus alliés fervents
	var af = player.allies_fervents if player else 0
	var rage = player.rage_niveau if player else 0
	coin.damage = int((15 + rage * 3 + (5 if af >= 2 else 0)) * 1.0)
	# Héritage pierce/bounce (Alliés fervents stack 3)
	if af >= 3:
		coin.can_pierce = player.coin_pierce
		coin.can_bounce = player.coin_bounce
	get_tree().current_scene.add_child(coin)
