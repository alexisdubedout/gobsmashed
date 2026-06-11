extends BaseEnemy

const PROJECTILE_SCENE = preload("res://scenes/projectiles/magic_orb.tscn")
var shoot_timer = 0.0
var shoot_delay = 2.0
var preferred_distance = 250.0

func setup():
	max_hp = 25
	current_hp = 25
	speed = 115
	base_speed = 115
	damage = 8
	shoot_delay = 1.8
	xp_value = 5
	anim_frames_count = 8

func get_direction() -> Vector2:
	if not player:
		return Vector2.ZERO
	
	var dist = global_position.distance_to(player.global_position)
	
	# Recule si trop proche
	if dist < preferred_distance:
		return (global_position - player.global_position).normalized()
	# Avance si trop loin
	elif dist > preferred_distance + 50:
		return (player.global_position - global_position).normalized()
	else:
		# Se déplace latéralement
		var dir = (player.global_position - global_position).normalized()
		return Vector2(-dir.y, dir.x)

func _physics_process(_delta):
	super(_delta)
	
	# Tir sur le joueur
	shoot_timer += _delta
	if shoot_timer >= shoot_delay:
		shoot_timer = 0.0
		shoot()



func shoot():
	if not player:
		return
	var projectile = PROJECTILE_SCENE.instantiate()
	var dir = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + dir * 30.0
	projectile.direction = dir
	get_tree().current_scene.add_child(projectile)
