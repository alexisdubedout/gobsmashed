extends BaseEnemy

enum State { POURSUITE, PREPARATION, CHARGE, COOLDOWN }

var state = State.POURSUITE
var state_timer = 0.0
var charge_direction = Vector2.ZERO

const CHARGE_SPEED = 420.0
const PREP_DURATION = 1.2
const CHARGE_DURATION = 0.5
const COOLDOWN_DURATION = 3.0

var _frappe_sainte_faite: bool = false   # niv 4 : AoE en fin de charge

func setup():
	max_hp          = 120
	current_hp      = 120
	speed           = 115.0
	base_speed      = 115.0
	damage          = 12
	xp_value        = 6
	enemy_type_name = "paladin"
	body_level      = 1

func _activer_competences() -> void:
	# Niv 2 — régénération 1 HP/s
	if diff >= 2:
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.autostart = true
		timer.timeout.connect(func():
			if is_instance_valid(self):
				current_hp = min(max_hp, current_hp + 1)
		)
		add_child(timer)

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
				# Niv 3 — aura : boost la vitesse des ennemis proches
				if diff >= 3:
					_appliquer_aura()
				# Niv 4 — frappe sainte : AoE en fin de charge
				if diff >= 4 and not _frappe_sainte_faite:
					_frappe_sainte_faite = true
					_frappe_sainte()

		State.COOLDOWN:
			super(_delta)
			if state_timer >= COOLDOWN_DURATION:
				state_timer = 0.0
				_frappe_sainte_faite = false
				state = State.POURSUITE

func take_damage(amount: int) -> void:
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		# Niv 5 — résurrection : revient à 25% HP une seule fois
		if diff >= 5 and not _ressuscite:
			_ressuscite = true
			current_hp  = int(max_hp * 0.25)
			$body.modulate = Color(3.0, 2.5, 0.5)
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(self):
				$body.modulate = body_color
		else:
			die()

func _appliquer_aura() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		if global_position.distance_to(e.global_position) < 150.0:
			e.speed = e.base_speed * 1.2

func _frappe_sainte() -> void:
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < 80.0:
		player.take_damage_from(int(damage * 1.5), self)
		player.velocity += (player.global_position - global_position).normalized() * 200.0
