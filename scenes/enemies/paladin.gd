extends BaseEnemy

enum State { POURSUITE, PREPARATION, CHARGE, COOLDOWN }

var state = State.POURSUITE
var state_timer = 0.0
var charge_direction = Vector2.ZERO

const CHARGE_SPEED      = 580.0
const PREP_DURATION     = 0.8
const CHARGE_DURATION   = 0.7
const COOLDOWN_DURATION = 3.0
const ARROW_MAX_LENGTH  = 200.0

var _frappe_sainte_faite: bool = false
var _arrow_visible: bool       = false
var _arrow_t:       float      = 0.0
var _arrow_dir:     Vector2    = Vector2.RIGHT

const MEMES_PALADIN = [
	"FOR THE HORDE !",
	"Witness meeee !",
	"You shall not pass !",
	"THIS ISN'T EVEN MY FINAL FORM",
	"PLUS ULTRA !!!",
	"I am inevitable",
	"MAXIMUM OVERDRIVE",
]

func setup():
	max_hp          = 130
	current_hp      = 130
	speed           = 122.0
	base_speed      = 122.0
	damage          = 13
	xp_value        = 6
	enemy_type_name = "paladin"
	body_level      = 1

func _activer_competences() -> void:
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

	# Masque la flèche dès qu'on quitte PREPARATION
	if state != State.PREPARATION and _arrow_visible:
		_arrow_visible = false
		queue_redraw()

	match state:
		State.POURSUITE:
			super(_delta)
			if state_timer >= COOLDOWN_DURATION:
				state_timer = 0.0
				state = State.PREPARATION
				velocity = Vector2.ZERO

		State.PREPARATION:
			velocity = Vector2.ZERO
			move_and_slide()
			_arrow_t = clampf(state_timer / PREP_DURATION, 0.0, 1.0)
			if player:
				_arrow_dir = (player.global_position - global_position).normalized()
			_arrow_visible = true
			queue_redraw()

			# Corps : doré → rouge sang + grossit
			var flash = sin(state_timer * 28.0) * (1.0 - _arrow_t * 0.6)
			$body.modulate = Color(1.5 + flash * 0.5, 0.7 * (1.0 - _arrow_t), 0.0)
			$body.scale = body_visual_scale * (1.0 + _arrow_t * 0.3)
			_animator.play("idle", _face_dir)

			if state_timer >= PREP_DURATION:
				$body.scale    = body_visual_scale
				$body.modulate = body_color
				state_timer    = 0.0
				state          = State.CHARGE
				if randf() < 0.08:
					_afficher_bulle(MEMES_PALADIN[randi() % MEMES_PALADIN.size()])
				if player:
					charge_direction = (player.global_position - global_position).normalized()
					var d: Vector2 = charge_direction
					if abs(d.x) > abs(d.y):
						_face_dir = "right" if d.x > 0 else "left"
					else:
						_face_dir = "down" if d.y > 0 else "up"

		State.CHARGE:
			velocity = charge_direction * CHARGE_SPEED
			move_and_slide()
			_animator.play("attack", _face_dir)
			if player and global_position.distance_to(player.global_position) < 35.0:
				player.take_damage_from(damage * 2, self)
			# Arrêt anticipé si le paladin percute la limite de la map
			var px = absf(global_position.x); var py = absf(global_position.y)
			var hit_boundary = maxf(px, py) > 910.0
			if hit_boundary or state_timer >= CHARGE_DURATION:
				if hit_boundary:
					global_position.x = clampf(global_position.x, -900.0, 900.0)
					global_position.y = clampf(global_position.y, -900.0, 900.0)
				state_timer    = 0.0
				state          = State.COOLDOWN
				$body.modulate = body_color
				_shockwave()
				if diff >= 3:
					_appliquer_aura()
				if diff >= 4 and not _frappe_sainte_faite:
					_frappe_sainte_faite = true
					_frappe_sainte()

		State.COOLDOWN:
			super(_delta)
			if state_timer >= COOLDOWN_DURATION:
				state_timer          = 0.0
				_frappe_sainte_faite = false
				state                = State.POURSUITE


func _draw() -> void:
	if not _arrow_visible:
		return

	var dir     = _arrow_dir
	var perp    = dir.rotated(PI * 0.5)
	var head_sz = 28.0
	var shaft_tip = dir * (ARROW_MAX_LENGTH - head_sz)   # bout de la tige
	var tip       = dir * ARROW_MAX_LENGTH                # pointe de la flèche
	var base_l    = shaft_tip + perp * head_sz * 0.55
	var base_r    = shaft_tip - perp * head_sz * 0.55

	# ── Fantôme (trajet complet, grisé dès le début) ──────────────
	var ghost = Color(1.0, 0.08, 0.0, 0.22)
	draw_line(Vector2.ZERO, shaft_tip, ghost, 7.0)
	draw_colored_polygon([tip, base_l, base_r], ghost)

	# ── Remplissage de la tige (base → pointe) ────────────────────
	var filled = clampf(_arrow_t * ARROW_MAX_LENGTH, 0.0, ARROW_MAX_LENGTH - head_sz)
	if filled > 0.5:
		var col = Color(1.0, 0.08, 0.0, 0.92)
		draw_line(Vector2.ZERO, dir * filled, col, 7.0)

	# ── Pointe : s'allume dans les 15% finaux ─────────────────────
	if _arrow_t > 0.85:
		var a   = (_arrow_t - 0.85) / 0.15
		var col = Color(1.0, 0.08, 0.0, a * 0.92)
		draw_colored_polygon([tip, base_l, base_r], col)

func take_damage(amount: int) -> void:
	# Invincible pendant la charge — flash blanc
	if state == State.CHARGE:
		$body.modulate = Color(2.5, 2.5, 2.5)
		await get_tree().create_timer(0.07).timeout
		if is_instance_valid(self):
			$body.modulate = body_color
		return
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		if diff >= 5 and not _ressuscite:
			_ressuscite = true
			current_hp  = int(max_hp * 0.25)
			$body.modulate = Color(3.0, 2.5, 0.5)
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(self):
				$body.modulate = body_color
		else:
			die()

func _shockwave() -> void:
	if not player: return
	if global_position.distance_to(player.global_position) < 80.0:
		player.take_damage_from(damage, self)

func _appliquer_aura() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self: continue
		if global_position.distance_to(e.global_position) < 150.0:
			e.speed = e.base_speed * 1.2

func _frappe_sainte() -> void:
	if not player: return
	if global_position.distance_to(player.global_position) < 80.0:
		player.take_damage_from(int(damage * 1.5), self)
		player.velocity += (player.global_position - global_position).normalized() * 200.0
