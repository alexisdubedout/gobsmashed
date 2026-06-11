extends CharacterBody2D
class_name BaseEnemy

var max_hp = 40
var current_hp = 40
var speed = 130.0
var base_speed = 130.0
var damage = 8
var xp_value = 3

var anim_timer = 0.0
var anim_delay = 0.1
var anim_frame = 0
var anim_frames_count = 8

var player
var rooted = false
var slowed = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	setup()

func setup():
	pass

func _physics_process(_delta):
	if rooted:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if player:
		var current_speed = base_speed * 0.4 if slowed else speed
		var direction = get_direction()
		direction += get_separation_force()
		direction = direction.normalized()
		animate(direction, _delta)
		velocity = direction * current_speed
		move_and_slide()
		
		# Dégâts continus par proximité avec cooldown par source
		var dist = global_position.distance_to(player.global_position)
		if dist < 35.0:
			player.take_damage_from(damage, self)

func get_direction() -> Vector2:
	return (player.global_position - global_position).normalized()

func animate(direction: Vector2, _delta: float):
	var row = 0
	if abs(direction.x) > abs(direction.y):
		row = 2 if direction.x > 0 else 1
	else:
		row = 0 if direction.y > 0 else 3
	
	anim_timer += _delta
	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % anim_frames_count
	
	$Sprite2D.frame = row * anim_frames_count + anim_frame

func get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	for other in enemies:
		if other == self:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < 40.0:
			var push = (global_position - other.global_position).normalized()
			force += push * (40.0 - dist) / 40.0
	if player:
		var dist_player = global_position.distance_to(player.global_position)
		if dist_player < 35.0:
			var push = (global_position - player.global_position).normalized()
			force += push * 0.5
	return force

func take_damage(amount):
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		die()
		
func _flash_hit():
	$Sprite2D.modulate = Color(1.5, 0.6, 0.2)  # orange chaud
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		$Sprite2D.modulate = Color(1, 1, 1)

func die():
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.gagner_xp(xp_value)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.ajouter_kill()
	queue_free()
