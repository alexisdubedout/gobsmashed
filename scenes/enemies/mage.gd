extends BaseEnemy

const PROJECTILE_SCENE = preload("res://scenes/projectiles/magic_orb.tscn")

# ── Orbe ────────────────────────────────────────────────────
var shoot_timer: float    = 0.0
var shoot_delay: float    = 1.8
var tele_timer: float     = 0.0
var tele_cooldown: float  = 0.0
var en_teleportation: bool = false
var _bouclier_actif: bool = false

# ── Laser (niv 3) ───────────────────────────────────────────
const MEMES_MAGE = [
	"AVADA KEDAVRA !",
	"I am the senate",
	"git gud",
	"I cast Magic Missile !",
	"Alakazam !",
	"You're a wizard, Harry",
	"404 dodge not found",
	"gg ez",
]

const BEAM_LENGTH   = 1700.0  # traverse presque toute l'arène
const BEAM_HALF_W   =   42.0  # demi-largeur → 84px total
const LASER_CHARGE  =    1.8  # secondes de chargement
const LASER_FIRE    =    0.45 # durée du flash
const LASER_DMG_MULT =   3    # dégâts × 3

var _laser_cd:       float   = 6.0
var _laser_charging: bool    = false
var _laser_firing:   bool    = false
var _laser_dir:      Vector2 = Vector2.RIGHT
var _laser_t:        float   = 0.0
var _laser_fire_t:   float   = 0.0

func setup():
	max_hp          = 25
	current_hp      = 25
	speed           = 100
	base_speed      = 100
	damage          = 9
	shoot_delay     = 1.8
	xp_value        = 5
	tele_cooldown   = randf_range(4.5, 7.0)
	enemy_type_name = "mage"
	body_level      = 1

func _activer_competences() -> void:
	if diff >= 2:
		shoot_delay = 1.2
	if diff >= 4:
		_bouclier_actif = true
		$body.modulate = Color(0.6, 0.8, 2.5)

func _couleur_corps() -> Color:
	return Color(0.6, 0.8, 2.5) if diff >= 4 else body_color

func _physics_process(delta):
	if _laser_charging:
		_update_charge(delta)
		return
	if _laser_firing:
		_update_fire(delta)
		return

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

	if diff >= 3:
		_laser_cd -= delta
		if _laser_cd <= 0.0 and not en_teleportation and player:
			_demarrer_laser()

# ── Laser : démarrage ───────────────────────────────────────
func _demarrer_laser() -> void:
	_laser_dir      = (player.global_position - global_position).normalized()
	_laser_charging = true
	_laser_t        = 0.0
	velocity        = Vector2.ZERO
	rooted          = true
	$body.modulate  = Color(2.2, 0.4, 3.0)
	if randf() < 0.15:
		_afficher_bulle("IMA FIRIN MAH LAZ0R")

func _update_charge(delta: float) -> void:
	_laser_t = minf(_laser_t + delta / LASER_CHARGE, 1.0)
	# Pulsation du corps pendant le chargement
	var pulse = abs(sin(_laser_t * TAU * 4.0)) * 0.6
	$body.modulate = Color(2.2 + pulse, 0.4, 3.0 + pulse)
	queue_redraw()
	if _laser_t >= 1.0:
		_laser_charging = false
		_laser_firing   = true
		_laser_fire_t   = 0.0
		_appliquer_degats()
		queue_redraw()

func _update_fire(delta: float) -> void:
	_laser_fire_t = minf(_laser_fire_t + delta / LASER_FIRE, 1.0)
	queue_redraw()
	if _laser_fire_t >= 1.0:
		_laser_firing = false
		rooted        = false
		$body.modulate = _couleur_corps()
		_laser_cd = randf_range(10.0, 16.0)
		queue_redraw()

func _appliquer_degats() -> void:
	if not player:
		return
	var to_p      = player.global_position - global_position
	var along     = to_p.dot(_laser_dir)
	var perp_dist = absf(to_p.dot(_laser_dir.rotated(PI * 0.5)))
	if along > -10.0 and along < BEAM_LENGTH and perp_dist < BEAM_HALF_W + 12.0:
		player.take_damage_from(damage * LASER_DMG_MULT, self)

# ── Dessin du telegraph / flash ─────────────────────────────
func _draw() -> void:
	if not _laser_charging and not _laser_firing:
		return

	var dir  := _laser_dir
	var perp := dir.rotated(PI * 0.5)

	if _laser_firing:
		var a     := 1.0 - _laser_fire_t
		var pts   := PackedVector2Array([
			 perp * BEAM_HALF_W,
			 dir  * BEAM_LENGTH + perp * BEAM_HALF_W,
			 dir  * BEAM_LENGTH - perp * BEAM_HALF_W,
			-perp * BEAM_HALF_W,
		])
		draw_colored_polygon(pts, Color(0.85, 0.3, 1.0, a * 0.75))
		draw_line(Vector2.ZERO, dir * BEAM_LENGTH, Color(1.0, 0.85, 1.0, a), 8.0)
		return

	# ── Phase chargement ────────────────────────────────────
	# Zone fantôme complète
	var ghost := Color(0.55, 0.1, 0.75, 0.20)
	var bord  := Color(0.65, 0.15, 0.85, 0.50)
	var pts_g := PackedVector2Array([
		 perp * BEAM_HALF_W,
		 dir  * BEAM_LENGTH + perp * BEAM_HALF_W,
		 dir  * BEAM_LENGTH - perp * BEAM_HALF_W,
		-perp * BEAM_HALF_W,
	])
	draw_colored_polygon(pts_g, ghost)
	draw_line( perp * BEAM_HALF_W,  dir * BEAM_LENGTH + perp * BEAM_HALF_W, bord, 2.0)
	draw_line(-perp * BEAM_HALF_W,  dir * BEAM_LENGTH - perp * BEAM_HALF_W, bord, 2.0)

	# Remplissage progressif (du mage vers l'extrémité)
	var filled := _laser_t * BEAM_LENGTH
	if filled > 0.5:
		var fill_a  := 0.35 + _laser_t * 0.3
		var pts_f   := PackedVector2Array([
			 perp * BEAM_HALF_W,
			 dir  * filled + perp * BEAM_HALF_W,
			 dir  * filled - perp * BEAM_HALF_W,
			-perp * BEAM_HALF_W,
		])
		draw_colored_polygon(pts_f, Color(0.8, 0.25, 1.0, fill_a))

	# Front pulsant
	var pulse := absf(sin(_laser_t * TAU * 3.5)) * 0.45
	draw_line(
		dir * filled + perp * BEAM_HALF_W,
		dir * filled - perp * BEAM_HALF_W,
		Color(1.0, 0.6, 1.0, 0.5 + pulse),
		4.0
	)
	# Ligne centrale pendant le chargement
	if filled > 2.0:
		draw_line(Vector2.ZERO, dir * filled, Color(0.9, 0.5, 1.0, 0.25 + pulse * 0.5), 2.0)

# ── Orbe ────────────────────────────────────────────────────
func _shoot():
	if not player:
		return
	_attack_anim_timer = 0.6
	if randf() < 0.02:
		_afficher_bulle(MEMES_MAGE[randi() % MEMES_MAGE.size()])
	var projectile = PROJECTILE_SCENE.instantiate()
	var dir = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + dir * 30.0
	projectile.direction = dir
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int) -> void:
	if diff >= 4 and _bouclier_actif:
		_bouclier_actif = false
		$body.modulate = Color(2.5, 2.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(self):
			$body.modulate = _couleur_corps()
		return
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		die()

func die() -> void:
	if diff >= 3 and player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 80.0:
			player.take_damage_from(int(damage * 0.8), self)
	super()

# ── Téléportation ───────────────────────────────────────────
func _teleporter():
	if not player or not is_inside_tree():
		return
	en_teleportation = true
	rooted = true

	if diff >= 5:
		var dir  = (player.global_position - global_position).normalized()
		var dest = player.global_position - dir * 40.0
		$body.modulate = Color(2.5, 2.5, 3.5)
		await get_tree().create_timer(0.12).timeout
		if not is_instance_valid(self): return
		$body.modulate = Color(0.0, 0.0, 0.0, 0.0)
		global_position = dest
		await get_tree().create_timer(0.08).timeout
		if not is_instance_valid(self): return
		$body.modulate = Color(2.5, 2.5, 3.5)
		await get_tree().create_timer(0.12).timeout
		if not is_instance_valid(self): return
		$body.modulate = _couleur_corps()
		for _i in 3:
			if not is_instance_valid(self): return
			_shoot()
			await get_tree().create_timer(0.14).timeout
		tele_cooldown = randf_range(3.0, 5.0)
		rooted = false
		en_teleportation = false
		return

	var side = 1 if randf() > 0.5 else -1
	var dest = player.global_position + Vector2(
		side * randf_range(160.0, 260.0),
		randf_range(-60.0, 60.0)
	)
	$body.modulate = Color(2.5, 2.5, 3.5)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self): return
	$body.modulate = Color(0.0, 0.0, 0.0, 0.0)
	global_position = dest
	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(self): return
	$body.modulate = Color(2.5, 2.5, 3.5)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self): return
	$body.modulate = _couleur_corps()
	for _i in 3:
		if not is_instance_valid(self): return
		_shoot()
		await get_tree().create_timer(0.14).timeout
	tele_cooldown = randf_range(4.5, 7.5)
	rooted = false
	en_teleportation = false
