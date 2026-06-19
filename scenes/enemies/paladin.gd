extends BaseEnemy

enum State { POURSUITE, PREPARATION, CHARGE, COOLDOWN }

var state = State.POURSUITE
var state_timer = 0.0
var charge_direction = Vector2.ZERO

const CHARGE_SPEED = 420.0
const PREP_DURATION = 1.2
const CHARGE_DURATION = 0.5
const COOLDOWN_DURATION = 3.0

func setup():
	max_hp          = 140
	current_hp      = 140
	speed           = 85.0
	base_speed      = 85.0
	damage          = 12
	xp_value        = 6
	enemy_type_name = "paladin"
	body_level      = 1

func _physics_process(_delta):
	state_timer += _delta

	match state:
		State.POURSUITE:
			# Comportement normal hérité
			super(_delta)
			# Déclenche une charge toutes les ~3s
			if state_timer >= COOLDOWN_DURATION:
				state_timer = 0.0
				state = State.PREPARATION
				velocity = Vector2.ZERO

		State.PREPARATION:
			velocity = Vector2.ZERO
			move_and_slide()
			var flash = sin(state_timer * 20.0)
			$body.modulate = Color(1.0 + flash * 0.5, 0.8, 0.0)
			_animator.play("idle", _face_dir)
			if state_timer >= PREP_DURATION:
				state_timer = 0.0
				state = State.CHARGE
				if player:
					charge_direction = (player.global_position - global_position).normalized()
					var d: Vector2 = charge_direction
					if abs(d.x) > abs(d.y):
						_face_dir = "right" if d.x > 0 else "left"
					else:
						_face_dir = "down" if d.y > 0 else "up"
				$body.modulate = body_color

		State.CHARGE:
			velocity = charge_direction * CHARGE_SPEED
			move_and_slide()
			_animator.play("attack", _face_dir)
			if player:
				var dist = global_position.distance_to(player.global_position)
				if dist < 35.0:
					player.take_damage_from(damage * 2, self)
			if state_timer >= CHARGE_DURATION:
				state_timer = 0.0
				state = State.COOLDOWN
				$body.modulate = body_color

		State.COOLDOWN:
			super(_delta)
			if state_timer >= COOLDOWN_DURATION:
				state_timer = 0.0
				state = State.POURSUITE
