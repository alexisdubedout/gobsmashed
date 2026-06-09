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
	max_hp = 140
	current_hp = 140
	speed = 85.0
	base_speed = 85.0
	damage = 12
	xp_value = 4
	anim_frames_count = 8

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
			# Immobile, tremble
			velocity = Vector2.ZERO
			move_and_slide()
			# Flash visuel — alterne la modulation
			var flash = sin(state_timer * 20.0)
			$Sprite2D.modulate = Color(1.0 + flash * 0.5, 0.3, 0.3)
			if state_timer >= PREP_DURATION:
				state_timer = 0.0
				state = State.CHARGE
				# Verrouille la direction au moment de la charge
				if player:
					charge_direction = (player.global_position - global_position).normalized()
				$Sprite2D.modulate = Color(1, 1, 1)

		State.CHARGE:
			# Fonce en ligne droite, ignore la séparation
			velocity = charge_direction * CHARGE_SPEED
			move_and_slide()
			# Dégâts à l'impact
			if player:
				var dist = global_position.distance_to(player.global_position)
				if dist < 35.0:
					player.take_damage_from(damage * 2, self)
			if state_timer >= CHARGE_DURATION:
				state_timer = 0.0
				state = State.COOLDOWN
				$Sprite2D.modulate = Color(1, 1, 1)

		State.COOLDOWN:
			super(_delta)
			if state_timer >= COOLDOWN_DURATION:
				state_timer = 0.0
				state = State.POURSUITE
