extends BaseEnemy

const PROJECTILE_SCENE = preload("res://scenes/projectiles/magic_orb.tscn")

var shoot_timer: float    = 0.0
var shoot_delay: float    = 1.8
var tele_timer: float     = 0.0
var tele_cooldown: float  = 0.0
var en_teleportation: bool = false

func setup():
	max_hp = 25
	current_hp = 25
	speed = 95
	base_speed = 95
	damage = 8
	shoot_delay = 1.8
	xp_value = 5
	anim_frames_count = 8
	tele_cooldown = randf_range(4.5, 7.0)

# Pas d'override de get_direction — avance vers le joueur par défaut (BaseEnemy)

func _physics_process(delta):
	super(delta)
	if en_teleportation:
		return
	shoot_timer += delta
	if shoot_timer >= shoot_delay:
		shoot_timer = 0.0
		_shoot()
	tele_timer += delta
	if tele_timer >= tele_cooldown:
		tele_timer = 0.0
		_teleporter()

func _shoot():
	if not player:
		return
	var projectile = PROJECTILE_SCENE.instantiate()
	var dir = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + dir * 30.0
	projectile.direction = dir
	get_tree().current_scene.add_child(projectile)

func _teleporter():
	if not player or not is_inside_tree():
		return
	en_teleportation = true
	rooted = true

	# Flanc ou derrière le joueur — jamais en fuite
	var side = 1 if randf() > 0.5 else -1
	var dest = player.global_position + Vector2(
		side * randf_range(160.0, 260.0),
		randf_range(-60.0, 60.0)
	)

	# Flash de sortie → invisible
	$Sprite2D.modulate = Color(2.5, 2.5, 3.5)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self): return
	$Sprite2D.modulate = Color(0.0, 0.0, 0.0, 0.0)
	global_position = dest

	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(self): return

	# Flash d'entrée
	$Sprite2D.modulate = Color(2.5, 2.5, 3.5)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self): return
	$Sprite2D.modulate = Color(1, 1, 1)

	# Burst immédiat après apparition
	for _i in 3:
		if not is_instance_valid(self): return
		_shoot()
		await get_tree().create_timer(0.14).timeout

	tele_cooldown = randf_range(4.5, 7.5)
	rooted = false
	en_teleportation = false
