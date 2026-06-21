extends BaseEnemy

const ARROW_SCENE := preload("res://scenes/projectiles/arrow.tscn")

const RANGE_SHOOT  := 220.0   # distance pour s'arrêter et tirer
const RANGE_FLEE   := 100.0   # trop proche → fuite immédiate
const RANGE_RESET  := 300.0   # distance pour stopper la fuite et réapprocher

const BURST_COUNT    := 3
const BURST_INTERVAL := 0.30

enum State { APPROACH, SHOOT, RETREAT }

var _state       := State.APPROACH
var _state_timer := 0.0
var _shoot_timer := 0.0
var _burst_fired := 0

func setup() -> void:
	max_hp          = 20
	current_hp      = 20
	speed           = 160.0
	base_speed      = 160.0
	damage          = 6
	xp_value        = 3
	enemy_type_name = "elf"
	body_level      = 1

func _physics_process(delta: float) -> void:
	if not player:
		return
	_attack_anim_timer = max(0.0, _attack_anim_timer - delta)
	_state_timer += delta
	if rooted:
		velocity = Vector2.ZERO
		move_and_slide()
		_animator.play("idle", _face_dir)
		return
	var dist: float = global_position.distance_to(player.global_position)

	match _state:
		State.APPROACH:
			_do_zigzag(1.0)
			if dist <= RANGE_SHOOT:
				_state = State.SHOOT
				_shoot_timer = 0.0
				_burst_fired = 0

		State.SHOOT:
			_face_toward_player()
			velocity = Vector2.ZERO
			move_and_slide()

			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_fire_arrow()
				_burst_fired += 1
				if _burst_fired >= BURST_COUNT:
					_enter_retreat()
				else:
					_shoot_timer = BURST_INTERVAL

			if _attack_anim_timer > 0.0:
				_animator.play("attack", _face_dir)
			else:
				_animator.play("idle", _face_dir)

			if dist < RANGE_FLEE:
				_enter_retreat()

		State.RETREAT:
			_do_zigzag(-1.0)
			if dist >= RANGE_RESET:
				_state = State.APPROACH
				_state_timer = 0.0


func _enter_retreat() -> void:
	_state       = State.RETREAT
	_state_timer = 0.0


func _face_toward_player() -> void:
	var to_p: Vector2 = player.global_position - global_position
	if abs(to_p.x) > abs(to_p.y):
		_face_dir = "right" if to_p.x > 0 else "left"
	else:
		_face_dir = "down" if to_p.y > 0 else "up"


func _do_zigzag(sign: float) -> void:
	var toward: Vector2 = (player.global_position - global_position).normalized()
	var dir: Vector2    = toward * sign
	# zigzag perpendiculaire à la direction de déplacement
	var perp: Vector2   = dir.rotated(PI * 0.5)
	var move: Vector2   = (dir + perp * sin(_state_timer * 4.0) * 0.8).normalized()
	move = (move + get_separation_force()).normalized()
	animate(move, 0.0)
	var current_speed = base_speed * 0.4 if slowed else speed
	velocity = move * current_speed
	move_and_slide()


func _fire_arrow() -> void:
	if not player or not is_inside_tree():
		return
	_face_toward_player()
	_attack_anim_timer = 0.5
	var arrow := ARROW_SCENE.instantiate()
	var dir: Vector2 = (player.global_position - global_position).normalized()
	arrow.direction       = dir
	arrow.global_position = global_position + dir * 20.0
	arrow.rotation        = dir.angle()
	get_tree().current_scene.add_child(arrow)
