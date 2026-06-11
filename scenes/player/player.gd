extends CharacterBody2D

const LEVEL_UP_SCENE = preload("res://scenes/level_up_screen.tscn")
const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")
const POISON_SCENE = preload("res://scenes/effects/poison_pool.tscn")
const TRAP_SCENE = preload("res://scenes/effects/trap.tscn")
const ALLY_SCENE = preload("res://scenes/player/ally.tscn")

const SPEED = 200.0

var touch_direction = Vector2.ZERO
var touch_id = -1
var joystick_origin = Vector2.ZERO
var coin_bounce = false
var coin_pierce = false
var ally_fast = false
var pieces_lourdes_niveau = 0
var avarice_niveau = 0
var rage_niveau = 0
var level_up_screen
var ATTACK_DELAY = 1.2
var multi_shot = 0
var max_hp = 100	
var current_hp = 100
var attack_timer = 0.0
var xp = 0
var xp_next_level = 10
var level = 1
var anim_timer = 0.0
var anim_delay = 0.15
var anim_frame = 0
var is_moving = false
var flaque_timer = 0.0
var poison_on_kill = false
var poison_niveau = 1 
var pieces_lourdes = false
var trappe_active = false

# Cooldowns de dégâts par source
var damage_cooldowns = {}
var damage_cooldown_duration = 0.5

func _ready():
	level_up_screen = LEVEL_UP_SCENE.instantiate()
	# Applique les bonus permanents
	max_hp = 100 + GameState.get_hp_max_bonus()
	current_hp = max_hp
	ATTACK_DELAY = 1.2 / GameState.get_attaque_bonus()
	# Démarre légèrement en bas de la base
	global_position = Vector2(0, 80)
	# La vitesse et les dégâts sont appliqués dynamiquement
	
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_id = event.index
			joystick_origin = event.position
		elif event.index == touch_id:
			touch_id = -1
			touch_direction = Vector2.ZERO
	
	if event is InputEventScreenDrag:
		if event.index == touch_id:
			var delta = event.position - joystick_origin
			if delta.length() > 20:
				touch_direction = delta.normalized()
			else:
				touch_direction = Vector2.ZERO

func _physics_process(_delta):
	# Mise à jour des cooldowns
	for key in damage_cooldowns.keys():
		damage_cooldowns[key] -= _delta
		if damage_cooldowns[key] <= 0:
			damage_cooldowns.erase(key)

	# Déplacement
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
		
	if touch_direction != Vector2.ZERO:
			direction = touch_direction

	# Direction et animation
	var row = 0
	if direction != Vector2.ZERO:
		is_moving = true
		if abs(direction.x) > abs(direction.y):
			row = 2 if direction.x > 0 else 1
		else:
			row = 0 if direction.y > 0 else 3
	else:
		is_moving = false

	anim_timer += _delta
	if is_moving and anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 3
	elif not is_moving:
		anim_frame = 0

	$Sprite2D.frame = row * 3 + anim_frame

	if direction != Vector2.ZERO:
		direction = direction.normalized()
	velocity = direction * SPEED * GameState.get_vitesse_bonus()
	move_and_slide()

	# Flaque de poison
	if poison_on_kill:
		flaque_timer += _delta
		if flaque_timer >= 5.0:
			flaque_timer = 0.0
			poser_flaque()

	# Trappe aléatoire
	if trappe_active and randf() < 0.002:
		poser_trappe()

	# Attaque auto
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
	fire_coin(closest.global_position)
	for i in multi_shot:
		var enemies2 = get_tree().get_nodes_in_group("enemy")
		enemies2.shuffle()
		if enemies2.size() > i + 1:
			fire_coin(enemies2[i + 1].global_position)
		else:
			fire_coin(closest.global_position.rotated((i + 1) * 0.3))

func fire_coin(target_pos):
	var coin = COIN_SCENE.instantiate()
	var shoot_direction = (target_pos - global_position).normalized()
	coin.global_position = global_position + shoot_direction * 30.0
	coin.direction = shoot_direction
	coin.piece_lourde_niveau = pieces_lourdes_niveau
	coin.can_pierce = coin_pierce
	coin.can_bounce = coin_bounce
	coin.damage = int(15 * (1.0 + rage_niveau * 0.2) * GameState.get_degats_bonus())
	get_tree().current_scene.add_child(coin)

func take_damage_from(amount: int, source) -> void:
	var source_id = source.get_instance_id()
	if source_id in damage_cooldowns:
		return
	damage_cooldowns[source_id] = damage_cooldown_duration
	current_hp -= amount
	print("PV restants : ", current_hp)
	if current_hp <= 0:
		die()

func take_damage(amount: int) -> void:
	current_hp -= amount
	print("PV restants : ", current_hp)
	if current_hp <= 0:
		die()

func gagner_xp(montant):
	xp += montant
	if avarice_niveau > 0:
		current_hp = min(max_hp, current_hp + avarice_niveau)
	if xp >= xp_next_level:
		xp = 0
		xp_next_level = int(xp_next_level * 1.25)
		level_up()


func level_up():
	level += 1
	var pool = Augments.get_liste_disponible().duplicate()
	pool.shuffle()
	var cartes = pool.slice(0, min(3, pool.size()))
	if cartes.is_empty():
		return
	if not level_up_screen.is_inside_tree():
		get_tree().current_scene.add_child(level_up_screen)
	level_up_screen.afficher(cartes)

func die():
	Augments.reset()
	var hud = get_tree().get_first_node_in_group("hud")
	var vague = 1
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		vague = spawner.current_wave + 1
	if hud:
		hud.afficher_game_over(vague)
	else:
		get_tree().reload_current_scene()
	queue_free()

func ajouter_collegue():
	var ally = ALLY_SCENE.instantiate()
	get_tree().current_scene.add_child(ally)
	ally.global_position = global_position + Vector2(60, 0)

func activer_flaque_poison(niveau: int):
	poison_on_kill = true
	poison_niveau = niveau

func activer_pieces_lourdes():
	pass  # plus utilisé, géré via pieces_lourdes_niveau

func activer_trappe():
	trappe_active = true

func poser_flaque():
	var pool = POISON_SCENE.instantiate()
	pool.global_position = global_position
	pool.niveau = poison_niveau
	get_tree().current_scene.add_child(pool)

func poser_trappe():
	var trap = TRAP_SCENE.instantiate()
	trap.global_position = global_position
	get_tree().current_scene.add_child(trap)
	
