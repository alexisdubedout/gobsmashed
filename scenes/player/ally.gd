extends CharacterBody2D

const SPEED = 120.0
const ATTACK_DELAY = 1.2
const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")

var attack_timer = 0.0
var player

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	if not player:
		return
	
	# Suit le joueur à distance
	var dist_player = global_position.distance_to(player.global_position)
	if dist_player > 80:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	# Tire sur l'ennemi le plus proche
	attack_timer += _delta
	var current_delay = ATTACK_DELAY * (0.55 if player.ally_fast else 1.0)
	if attack_timer >= current_delay:
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
	var coin = COIN_SCENE.instantiate()
	var direction = (closest.global_position - global_position).normalized()
	coin.global_position = global_position + direction * 30.0
	coin.direction = direction
	get_tree().current_scene.add_child(coin)
