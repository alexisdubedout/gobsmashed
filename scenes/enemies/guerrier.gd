extends CharacterBody2D
class_name BaseEnemy

const BLOOD_POOL_SCENE = preload("res://scenes/effects/blood_pool.tscn")

const SPRITES_PATH := "res://assets/sprites/placeholder/"

var max_hp    = 40
var current_hp = 40
var speed     = 130.0
var base_speed = 130.0
var damage    = 8
var xp_value  = 3

var player
var rooted  = false
var slowed  = false

var body_level        := 1
var enemy_type_name   := "guerrier"
var body_visual_scale := Vector2(1.35, 1.35)
var body_color        := Color.WHITE

var _animator: CharacterAnimator
var _face_dir := "down"
var _attack_anim_timer := 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	setup()
	_animator = CharacterAnimator.new()
	_animator.init(self)
	_appliquer_sprite()

func _appliquer_sprite() -> void:
	var path := SPRITES_PATH + "body_%s_level_%d_frames.tres" % [enemy_type_name, body_level]
	if ResourceLoader.exists(path):
		$body.sprite_frames = load(path)
	$body.scale    = body_visual_scale
	$body.modulate = body_color
	$body.visible  = true
	for layer in ["shadow", "clothes", "armor_chest", "armor_legs", "helmet", "weapon"]:
		var node = get_node_or_null(layer)
		if node:
			node.visible = false

func setup():
	enemy_type_name = "guerrier"
	body_level      = 1

func _physics_process(_delta):
	_attack_anim_timer = max(0.0, _attack_anim_timer - _delta)
	if rooted:
		velocity = Vector2.ZERO
		move_and_slide()
		_animator.play("idle", _face_dir)
		return

	if player:
		var current_speed = base_speed * 0.4 if slowed else speed
		var direction = get_direction()
		direction += get_separation_force()
		direction = direction.normalized()
		animate(direction, _delta)
		velocity = direction * current_speed
		move_and_slide()

		var dist = global_position.distance_to(player.global_position)
		if dist < 35.0:
			player.take_damage_from(damage, self)
			_attack_anim_timer = 0.5

func get_direction() -> Vector2:
	return (player.global_position - global_position).normalized()

func animate(direction: Vector2, _delta: float):
	if _attack_anim_timer > 0.0 and player:
		var to_player: Vector2 = player.global_position - global_position
		if abs(to_player.x) > abs(to_player.y):
			_face_dir = "right" if to_player.x > 0 else "left"
		else:
			_face_dir = "down" if to_player.y > 0 else "up"
		_animator.play("attack", _face_dir)
		return
	if abs(direction.x) > abs(direction.y):
		_face_dir = "right" if direction.x > 0 else "left"
	else:
		_face_dir = "down" if direction.y > 0 else "up"
	_animator.play("run", _face_dir)

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
	$body.modulate = Color(1.5, 0.6, 0.2)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		$body.modulate = body_color

func die():
	var pool: BloodPool = BLOOD_POOL_SCENE.instantiate()
	pool.global_position = global_position
	pool.radius = body_visual_scale.x * 20.0
	get_tree().current_scene.add_child(pool)

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.gagner_xp(xp_value)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.ajouter_kill()
	queue_free()
