extends BaseEnemy

const PROJECTILE_SCENE = preload("res://scenes/projectiles/magic_orb.tscn")

var shoot_timer: float    = 0.0
var shoot_delay: float    = 1.8
var tele_timer: float     = 0.0
var tele_cooldown: float  = 0.0
var en_teleportation: bool = false
var _bouclier_actif: bool = false   # niv 4 : absorbe un coup

func setup():
	max_hp          = 25
	current_hp      = 25
	speed           = 95
	base_speed      = 95
	damage          = 8
	shoot_delay     = 1.8
	xp_value        = 5
	tele_cooldown   = randf_range(4.5, 7.0)
	enemy_type_name = "mage"
	body_level      = 1

func _activer_competences() -> void:
	# Niv 2 — orbe rapide
	if diff >= 2:
		shoot_delay = 1.2
	# Niv 4 — bouclier magique
	if diff >= 4:
		_bouclier_actif = true
		$body.modulate = Color(0.6, 0.8, 2.5)

# Pas d'override de get_direction — avance vers le joueur par défaut (BaseEnemy)

func _physics_process(delta):
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

func _shoot():
	if not player:
		return
	_attack_anim_timer = 0.6
	var projectile = PROJECTILE_SCENE.instantiate()
	var dir = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + dir * 30.0
	projectile.direction = dir
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int) -> void:
	# Niv 4 — bouclier magique : absorbe le premier coup
	if diff >= 4 and _bouclier_actif:
		_bouclier_actif = false
		$body.modulate = Color(2.5, 2.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(self):
			$body.modulate = body_color
		return
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		die()

func die() -> void:
	# Niv 3 — explosion à la mort
	if diff >= 3 and player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 80.0:
			player.take_damage_from(int(damage * 0.8), self)
	super()

func _teleporter():
	if not player or not is_inside_tree():
		return
	en_teleportation = true
	rooted = true

	# Niv 5 — téléportation agressive : devant le joueur
	if diff >= 5:
		var dir = (player.global_position - global_position).normalized()
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
		$body.modulate = body_color
		for _i in 3:
			if not is_instance_valid(self): return
			_shoot()
			await get_tree().create_timer(0.14).timeout
		tele_cooldown = randf_range(3.0, 5.0)
		rooted = false
		en_teleportation = false
		return

	# Flanc ou derrière le joueur — comportement normal
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
	$body.modulate = body_color

	# Burst immédiat après apparition
	for _i in 3:
		if not is_instance_valid(self): return
		_shoot()
		await get_tree().create_timer(0.14).timeout

	tele_cooldown = randf_range(4.5, 7.5)
	rooted = false
	en_teleportation = false
