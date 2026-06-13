extends CharacterBody2D

const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")

const SPEED        = 200.0
const JUMP_FORCE   = -560.0
const GRAVITY      = 860.0
const ATTACK_DELAY = 1.1

const DASH_SPEED = 550.0

# Valeurs de base du dash — modifiées par l'augment "Dash éclair"
var dash_dur:  float = 0.18
var dash_cd_dur: float = 1.5
var iframe_dur:  float = 0.18

var current_hp: int
var max_hp: int
var attack_timer: float = 0.0
var boss_ref

var multi_shot: int = 0
var rage_niveau: int = 0
var pieces_lourdes_niveau: int = 0
var attack_delay_effective: float = ATTACK_DELAY

var anim_timer: float = 0.0
var anim_frame: int   = 0
var face_dir: int     = 1

var dash_requested: bool = false
var dash_active:    bool = false
var dash_timer:     float = 0.0
var dash_cd:        float = 0.0
var invincible:     bool  = false
var _iframes:       float = 0.0   # timer i-frames suite à un coup
var _knockback_timer: float = 0.0

const DOUBLE_TAP   = 0.28
var _fwd_tap_time: float = -99.0
var _down_tap_time: float = -99.0

func _ready():
	up_direction = Vector2.UP
	scale = Vector2(1.8, 1.8)
	max_hp = 100 + GameState.get_hp_max_bonus()
	current_hp = clamp(GameState.boss_hp_joueur, 1, max_hp)

	multi_shot            = Augments.stacks.get("Multi-shot", 0)
	rage_niveau           = Augments.stacks.get("Rage gobeline", 0)
	pieces_lourdes_niveau = Augments.stacks.get("Pièces lourdes", 0)

	var as_stack = Augments.stacks.get("Attack speed", 0)
	var as_mult  = [1.0, 0.85, 0.75, 0.50][as_stack]
	attack_delay_effective = ATTACK_DELAY * as_mult / GameState.get_attaque_bonus()

	# Dash éclair — améliore les stats du dash selon le niveau
	match Augments.stacks.get("Dash éclair", 0):
		1: dash_cd_dur = 1.1; iframe_dur = 0.22
		2: dash_cd_dur = 0.7; iframe_dur = 0.28; dash_dur = 0.22
		3: dash_cd_dur = 0.5; iframe_dur = 0.35; dash_dur = 0.26

func _physics_process(delta):
	dash_cd = max(dash_cd - delta, 0.0)

	# Flash i-frames (coup reçu) — géré ici pour être garanti chaque frame
	if _iframes > 0.0:
		_iframes -= delta
		if not dash_active:
			$Sprite2D.modulate = Color(2.2, 0.3, 0.05) if fmod(_iframes * 10.0, 2.0) >= 1.0 else Color(1.0, 1.0, 1.0, 0.3)
		if _iframes <= 0.0:
			invincible = false
			if not dash_active:
				$Sprite2D.modulate = Color(1, 1, 1)

	if dash_active:
		dash_timer -= delta
		velocity.x = face_dir * DASH_SPEED
		if dash_timer <= 0.0:
			dash_active = false
			$Sprite2D.scale = Vector2(1.0, 1.0)
		move_and_slide()
		_animer(delta, float(face_dir))
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta

		if Input.is_action_just_pressed("move_up") and is_on_floor():
			velocity.y = JUMP_FORCE

		# HUD button → dash
		if dash_requested and is_on_floor() and dash_cd <= 0.0:
			dash_requested = false
			_lancer_dash()
		else:
			dash_requested = false

		# Double-tap avant → dash
		var fwd_action = "move_right" if face_dir > 0 else "move_left"
		if Input.is_action_just_pressed(fwd_action):
			var t = Time.get_ticks_msec() * 0.001
			if t - _fwd_tap_time < DOUBLE_TAP and is_on_floor() and dash_cd <= 0.0:
				_lancer_dash()
			_fwd_tap_time = t

		# Double-tap bas → descendre de la plateforme
		if Input.is_action_just_pressed("move_down"):
			var t = Time.get_ticks_msec() * 0.001
			if t - _down_tap_time < DOUBLE_TAP and is_on_floor():
				_descendre_plateforme()
			_down_tap_time = t

		var dir = 0.0
		if Input.is_action_pressed("move_right"):
			dir += 1.0
			face_dir = 1
		if Input.is_action_pressed("move_left"):
			dir -= 1.0
			face_dir = -1
		if _knockback_timer > 0.0:
			_knockback_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		else:
			velocity.x = dir * SPEED * GameState.get_vitesse_bonus()

		move_and_slide()
		_animer(delta, dir)

	attack_timer += delta
	if attack_timer >= attack_delay_effective:
		attack_timer = 0.0
		shoot()

func _animer(delta: float, dir: float):
	anim_timer += delta
	if anim_timer >= 0.12:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 3 if dir != 0.0 else 0
	var row = (2 if face_dir > 0 else 1) if dir != 0.0 else 0
	$Sprite2D.frame = row * 3 + anim_frame

func shoot():
	if not is_instance_valid(boss_ref): return
	var base_dmg = int(15.0 * (1.0 + rage_niveau * 0.2) * GameState.get_degats_bonus())
	_fire_coin(boss_ref.global_position, base_dmg)
	for i in multi_shot:
		var angle = (i + 1) * 0.25 * (1.0 if i % 2 == 0 else -1.0)
		_fire_coin(boss_ref.global_position + Vector2(0, -30 * (i + 1)).rotated(angle), base_dmg)

func _fire_coin(target_pos: Vector2, dmg: int):
	var coin = COIN_SCENE.instantiate()
	var dir = (target_pos - global_position).normalized()
	coin.global_position = global_position + dir * 28.0
	coin.direction  = dir
	coin.damage     = dmg
	coin.speed      = 380.0
	coin.hit_radius = 40.0
	coin.piece_lourde_niveau = pieces_lourdes_niveau
	get_tree().current_scene.add_child(coin)

func _descendre_plateforme():
	set_collision_mask_value(2, false)
	velocity.y = 80.0
	await get_tree().create_timer(0.30).timeout
	if is_instance_valid(self):
		set_collision_mask_value(2, true)

func _lancer_dash():
	dash_active = true
	dash_timer  = dash_dur
	dash_cd     = dash_cd_dur
	$Sprite2D.scale = Vector2(1.5, 0.6)
	invincible = true
	_iframe()

func _iframe():
	var t = 0.0
	while t < iframe_dur:
		$Sprite2D.modulate = Color(0.3, 0.8, 2.0) if int(t * 20) % 2 == 0 else Color(1, 1, 1)
		await get_tree().process_frame
		if not is_instance_valid(self): return
		t += get_process_delta_time()
	if is_instance_valid(self) and not dash_active:
		$Sprite2D.modulate = Color(1, 1, 1)
	# Ne vide invincible que si les i-frames de coup sont aussi terminées
	if is_instance_valid(self) and _iframes <= 0.0:
		invincible = false

func take_damage(amount: int) -> bool:
	if invincible: return false
	current_hp -= amount
	invincible = true
	_iframes = 0.6
	if is_instance_valid(boss_ref):
		var dir = sign(global_position.x - boss_ref.global_position.x)
		if dir == 0: dir = 1
		velocity.x = dir * 600.0
		velocity.y = -260.0
		_knockback_timer = 0.45
	if current_hp <= 0:
		_iframes = 0.0
		invincible = false
		_mourir()
	return true

func take_damage_from(amount: int, _source) -> void:
	take_damage(amount)

func _mourir():
	set_physics_process(false)
	$Sprite2D.modulate = Color(0.5, 0.2, 0.2)
	Augments.reset()
	if not is_inside_tree(): return
	var tree = get_tree()
	await tree.create_timer(1.2).timeout
	if not is_instance_valid(self): return
	tree.change_scene_to_file("res://scenes/donjon.tscn")
