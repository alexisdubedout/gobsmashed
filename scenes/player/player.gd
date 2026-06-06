extends CharacterBody2D

const LEVEL_UP_SCENE = preload("res://scenes/level_up_screen.tscn")
const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")
const SPEED = 150.0

var level_up_screen
var ATTACK_DELAY = 1.0
var multi_shot = 0
var max_hp = 100
var current_hp = 100
var invincible = false
var invincible_duration = 1.0
var invincible_timer = 0.0
var attack_timer = 0.0
var xp = 0
var xp_next_level = 3
var level = 1
var anim_timer = 0.0
var anim_delay = 0.15
var anim_frame = 0
var is_moving = false
var flaque_timer = 0.0

func _ready():
	level_up_screen = LEVEL_UP_SCENE.instantiate()

func _physics_process(_delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	
	# Direction et animation
	var row = 0
	if direction != Vector2.ZERO:
		is_moving = true
		if abs(direction.x) > abs(direction.y):
			row = 2 if direction.x > 0 else 1  # EST (row 2) ou OUEST (row 1)
		else:
			row = 0 if direction.y > 0 else 3  # SUD (row 0) ou NORD (row 3)
	else:
		is_moving = false

	# Animation de marche
	anim_timer += _delta
	if is_moving and anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 3
	elif not is_moving:
		anim_frame = 0

	$Sprite2D.frame = row * 3 + anim_frame

	if direction != Vector2.ZERO:
		direction = direction.normalized()
	velocity = direction * SPEED
	move_and_slide()

	# Pose une trappe aléatoirement
	if trappe_active and randf() < 0.002:
		poser_trappe()
	# Pose une flaque en marchant
	if poison_on_kill:
		flaque_timer += _delta
		if flaque_timer >= 5.0:
			flaque_timer = 0.0
			poser_flaque()

	if invincible:
		invincible_timer += _delta
		if invincible_timer >= invincible_duration:
			invincible = false
			invincible_timer = 0.0

	attack_timer += _delta
	if attack_timer >= ATTACK_DELAY:
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
	
	# Tir principal
	fire_coin(closest.global_position)
	
	# Tirs supplémentaires multi-shot
	for i in multi_shot:
		var angle_offset = (i + 1) * 0.3
		var enemies2 = get_tree().get_nodes_in_group("enemy")
		enemies2.shuffle()
		if enemies2.size() > i + 1:
			fire_coin(enemies2[i + 1].global_position)
		else:
			fire_coin(closest.global_position.rotated(angle_offset))

func fire_coin(target_pos):
	var coin = COIN_SCENE.instantiate()
	var shoot_direction = (target_pos - global_position).normalized()
	coin.global_position = global_position + shoot_direction * 30.0
	coin.direction = shoot_direction
	get_tree().current_scene.add_child(coin)

func take_damage(amount):
	if invincible:
		return
	current_hp -= amount
	invincible = true
	print("PV restants : ", current_hp)
	if current_hp <= 0:
		die()

func gagner_xp(montant):
	xp += montant
	if xp >= xp_next_level:
		xp = 0
		xp_next_level = int(xp_next_level * 1.5)
		level_up()

func level_up():
	level += 1
	var pool = Augments.LISTE.duplicate()
	pool.shuffle()
	var cartes = pool.slice(0, min(3, pool.size()))
	if not level_up_screen.is_inside_tree():
		get_tree().current_scene.add_child(level_up_screen)
	level_up_screen.afficher(cartes)

func die():
	print("Le gobelin est mort !")
	get_tree().reload_current_scene()
const POISON_SCENE = preload("res://scenes/effects/poison_pool.tscn")
const TRAP_SCENE = preload("res://scenes/effects/trap.tscn")
const ALLY_SCENE = preload("res://scenes/player/ally.tscn")
var poison_on_kill = false
var pieces_lourdes = false
var trappe_active = false



func ajouter_collegue():
	var ally = ALLY_SCENE.instantiate()
	get_tree().current_scene.add_child(ally)
	ally.global_position = global_position + Vector2(60, 0)

func activer_flaque_poison():
	poison_on_kill = true

func activer_pieces_lourdes():
	pieces_lourdes = true


func activer_trappe():
	trappe_active = true

func poser_flaque():
	var pool = POISON_SCENE.instantiate()
	pool.global_position = global_position
	get_tree().current_scene.add_child(pool)

func poser_trappe():
	var trap = TRAP_SCENE.instantiate()
	trap.global_position = global_position
	get_tree().current_scene.add_child(trap)
