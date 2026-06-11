extends CharacterBody2D

const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")
const ORB_SCENE  = preload("res://scenes/projectiles/magic_orb.tscn")

const TEXTURES = {
	"guerrier": "res://assets/characters/Guerrier.png",
	"paladin":  "res://assets/characters/Paladin.png",
	"elf":      "res://assets/characters/Elf.png",
	"mage":     "res://assets/characters/Mage.png",
}

const STATS = {
	"guerrier": {"hp": 500, "scale": 2.2, "delay_p1": 1.6, "delay_p2": 0.9},
	"paladin":  {"hp": 750, "scale": 2.6, "delay_p1": 2.0, "delay_p2": 1.1},
	"elf":      {"hp": 320, "scale": 1.9, "delay_p1": 1.3, "delay_p2": 0.75},
	"mage":     {"hp": 380, "scale": 2.1, "delay_p1": 1.5, "delay_p2": 0.9},
}

const SEQUENCES = {
	"guerrier": [
		["charge", "stomp", "spin"],
		["double_charge", "stomp", "spin"],
	],
	"paladin": [
		["charge_lente", "bouclier", "zone"],
		["charge_rapide", "zone", "charge_rapide"],
	],
	"elf": [
		["salve", "dash", "pluie"],
		["rafale", "dash", "salve", "pluie"],
	],
	"mage": [
		["spirale", "vise", "pluie_mage"],
		["spirale", "homing", "vise", "pluie_mage"],
	],
}

const GRAVITY    = 700.0
const JUMP_FORCE = -530.0

var boss_type: String = ""
var current_hp: int   = 0
var max_hp: int       = 0
var phase: int        = 0
var player_ref
var arena_width: float = 800.0

var attaque_active: bool = false
var attaque_timer: float = 0.0
var seq_index: int       = 0
var delay_p1: float = 1.6
var delay_p2: float = 0.9

var en_charge: bool       = false
var vitesse_charge: float = 0.0
var dir_charge: int       = 1
var shield_active: bool   = false
var en_descente: bool     = false
var contact_cooldown: float = 0.0
var contact_dmg: int       = 18

var saut_timer: float    = 0.0
var saut_cooldown: float = 2.2

var anim_timer: float = 0.0
var anim_frame: int   = 0

# Téléportation mage (phase 2 uniquement)
var tele_timer: float    = 4.0  # Délai avant la première téléportation
var tele_zone: int       = 2    # Zone actuelle : 0=gauche 1=centre 2=droite
var en_teleportation: bool = false

# ── Setup ──────────────────────────────────────────────────────

func setup(type: String, p_player, p_arena_width: float):
	boss_type   = type
	player_ref  = p_player
	arena_width = p_arena_width
	var s = STATS[type]
	max_hp    = s["hp"]
	current_hp = max_hp
	delay_p1  = s["delay_p1"]
	delay_p2  = s["delay_p2"]
	scale = Vector2(s["scale"], s["scale"])
	$Sprite2D.texture = load(TEXTURES[type])
	$Sprite2D.hframes = 8
	$Sprite2D.vframes = 4

func _ready():
	up_direction = Vector2.UP

# ── Physique ───────────────────────────────────────────────────

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_mouvement(delta)
	move_and_slide()
	_animer(delta)

	if en_charge and contact_cooldown <= 0 and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < 58:
			player_ref.take_damage(contact_dmg)
			contact_cooldown = 0.5
	if contact_cooldown > 0:
		contact_cooldown -= delta

	if phase == 1 and boss_type == "mage":
		tele_timer -= delta

	if not attaque_active and not en_teleportation:
		_verifier_phase()
		attaque_timer += delta
		if attaque_timer >= (delay_p2 if phase == 1 else delay_p1):
			attaque_timer = 0.0
			_lancer_attaque()

# ── Mouvement ──────────────────────────────────────────────────

func _mouvement(delta: float):
	if en_teleportation:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		return
	if en_charge:
		velocity.x = dir_charge * vitesse_charge
		return
	if en_descente or not is_instance_valid(player_ref):
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		return
	if shield_active:
		velocity.x = move_toward(velocity.x, 0, 150 * delta)
		return

	var dx = player_ref.global_position.x - global_position.x
	var dy = player_ref.global_position.y - global_position.y

	match boss_type:
		"guerrier":
			velocity.x = sign(dx) * 130.0 if abs(dx) > 55 else move_toward(velocity.x, 0, 500 * delta)
		"paladin":
			velocity.x = sign(dx) * 80.0 if abs(dx) > 75 else move_toward(velocity.x, 0, 200 * delta)
		"elf":
			if abs(dx) > 200:   velocity.x = sign(dx) * 170.0
			elif abs(dx) < 80:  velocity.x = -sign(dx) * 130.0
			else:               velocity.x = move_toward(velocity.x, 0, 350 * delta)
		"mage":
			var ideal = 250.0
			if abs(dx) > ideal + 50:    velocity.x = sign(dx) * 90.0
			elif abs(dx) < ideal - 50:  velocity.x = -sign(dx) * 90.0
			else:                       velocity.x = move_toward(velocity.x, 0, 200 * delta)

	saut_timer += delta
	if is_on_floor() and saut_timer >= saut_cooldown and not attaque_active:
		if dy > 140:
			_descendre()
		elif dy < -70:
			_sauter(dx)
		elif randf() < _proba_saut():
			_sauter(dx)

func _proba_saut() -> float:
	match boss_type:
		"guerrier": return 0.30 if phase == 0 else 0.55
		"paladin":  return 0.12 if phase == 0 else 0.28
		"elf":      return 0.65 if phase == 0 else 0.85
		"mage":     return 0.22 if phase == 0 else 0.42
	return 0.3

func _sauter(dx: float):
	velocity.y = JUMP_FORCE
	if abs(dx) > 50:
		velocity.x = sign(dx) * 160.0
	saut_timer = 0.0
	saut_cooldown = randf_range(1.5, 2.8) if phase == 0 else randf_range(0.9, 1.8)

func _descendre():
	en_descente = true
	saut_timer = 0.0
	saut_cooldown = randf_range(1.2, 2.2)
	set_collision_mask_value(2, false)
	velocity.y = 100.0
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self):
		set_collision_mask_value(2, true)
		en_descente = false

# ── Phase ──────────────────────────────────────────────────────

func _verifier_phase():
	if phase == 0 and current_hp <= max_hp * 0.5:
		phase = 1
		saut_cooldown = 1.2
		_annonce_phase_deux()

func _annonce_phase_deux():
	for _i in 8:
		$Sprite2D.modulate = Color(2.5, 0.1, 0.1)
		await get_tree().create_timer(0.09).timeout
		if not is_instance_valid(self): return
		$Sprite2D.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.06).timeout

func _animer(delta: float):
	anim_timer += delta
	if anim_timer >= 0.09:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 8
	if not shield_active:
		$Sprite2D.frame = anim_frame

# ── Séquence ───────────────────────────────────────────────────

func _lancer_attaque():
	attaque_active = true
	var seq = SEQUENCES[boss_type][phase]
	await _executer(seq[seq_index % seq.size()])
	seq_index += 1
	attaque_active = false

	if boss_type == "mage" and phase == 1 and tele_timer <= 0 and not en_teleportation:
		_teleporter()

func _executer(nom: String):
	match nom:
		"charge":         await _guerrier_charge(680.0, 0.55, 22)
		"stomp":          await _guerrier_stomp()
		"spin":           await _guerrier_spin()
		"double_charge":  await _guerrier_double_charge()
		"charge_lente":   await _paladin_charge(300.0, 0.8, 24)
		"charge_rapide":  await _paladin_charge(600.0, 0.55, 30)
		"bouclier":       await _paladin_bouclier()
		"zone":           await _paladin_zone()
		"salve":          await _elf_salve(6)
		"rafale":         await _elf_rafale()
		"dash":           await _elf_dash()
		"pluie":          await _elf_pluie()
		"spirale":        await _mage_spirale()
		"vise":           await _mage_vise()
		"homing":         await _mage_homing()
		"pluie_mage":     await _mage_pluie()

# ══ MAGE — TÉLÉPORTATION ══════════════════════════════════════

func _teleporter():
	en_teleportation = true
	tele_timer = randf_range(7.0, 11.0)

	# Choisir une zone différente de l'actuelle (0=gauche 1=centre 2=droite)
	var zones_x = [arena_width * 0.18, arena_width * 0.50, arena_width * 0.80]
	var dest = randi() % 3
	while dest == tele_zone:
		dest = randi() % 3
	tele_zone = dest
	var dest_x = zones_x[dest]

	# ── Phase 1 : cast (mage incante, scintille doré 0.9s) ───────
	var t = 0.0
	while t < 0.9:
		if not is_instance_valid(self): return
		var p = sin(t * TAU * 6.0) * 0.5 + 0.5
		$Sprite2D.modulate = Color(1.0 + p * 1.8, 1.0 + p * 0.8, 0.1 + p * 0.2)
		await get_tree().process_frame
		t += get_process_delta_time()

	# ── Phase 2 : fantôme à la destination (0.55s) ───────────────
	var ghost = Sprite2D.new()
	ghost.texture  = $Sprite2D.texture
	ghost.hframes  = 8
	ghost.vframes  = 4
	ghost.frame    = anim_frame
	ghost.scale    = scale
	ghost.position = Vector2(dest_x, global_position.y)
	get_tree().current_scene.add_child(ghost)

	t = 0.0
	while t < 0.55:
		if not is_instance_valid(self):
			if is_instance_valid(ghost): ghost.queue_free()
			return
		var p = sin(t * TAU * 5.0) * 0.5 + 0.5
		ghost.modulate = Color(0.2 + p * 0.4, 0.6 + p * 0.5, 1.0, 0.25 + p * 0.5)
		await get_tree().process_frame
		t += get_process_delta_time()

	if is_instance_valid(ghost): ghost.queue_free()

	# ── Phase 3 : apparition (flash blanc → fondu 0.35s) ─────────
	global_position.x = dest_x
	t = 0.0
	while t < 0.35:
		if not is_instance_valid(self): return
		var fade = 1.0 - t / 0.35
		$Sprite2D.modulate = Color(1.0 + fade * 2.5, 1.0 + fade * 2.5, 1.0 + fade * 2.5)
		await get_tree().process_frame
		t += get_process_delta_time()

	if is_instance_valid(self):
		$Sprite2D.modulate = Color(1, 1, 1)
		en_teleportation = false

# ══ GUERRIER ═══════════════════════════════════════════════════

func _guerrier_charge(vitesse: float, duree: float, dmg: int):
	if not is_instance_valid(player_ref): return
	dir_charge = sign(player_ref.global_position.x - global_position.x)
	vitesse_charge = vitesse
	contact_dmg = dmg
	en_charge = true
	await get_tree().create_timer(duree).timeout
	en_charge = false
	vitesse_charge = 0.0
	await get_tree().create_timer(0.15).timeout

func _guerrier_stomp():
	velocity.y = -500.0
	var t = 0.0
	while not is_on_floor() and t < 1.4:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not is_instance_valid(self): return
	_spawn_coin(global_position, Vector2(1, -0.2), 16)
	_spawn_coin(global_position, Vector2(-1, -0.2), 16)
	if phase == 1:
		_spawn_coin(global_position, Vector2(0.7, -0.6), 12)
		_spawn_coin(global_position, Vector2(-0.7, -0.6), 12)
	await get_tree().create_timer(0.2).timeout

func _guerrier_spin():
	var nb = 8 if phase == 0 else 12
	for i in nb:
		var a = i * (TAU / nb)
		_spawn_coin(global_position, Vector2(cos(a), sin(a)), 12)
	if phase == 1:
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(self): return
		for i in nb:
			var a = i * (TAU / nb) + PI / nb
			_spawn_coin(global_position, Vector2(cos(a), sin(a)), 12)
	await get_tree().create_timer(0.2).timeout

func _guerrier_double_charge():
	await _guerrier_charge(780.0, 0.5, 26)
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self): return
	await _guerrier_charge(780.0, 0.5, 26)

# ══ PALADIN ════════════════════════════════════════════════════

func _paladin_charge(vitesse: float, duree: float, dmg: int):
	if not is_instance_valid(player_ref): return
	dir_charge = sign(player_ref.global_position.x - global_position.x)
	vitesse_charge = vitesse
	contact_dmg = dmg
	en_charge = true
	await get_tree().create_timer(duree).timeout
	en_charge = false
	vitesse_charge = 0.0
	await get_tree().create_timer(0.2).timeout

func _paladin_bouclier():
	shield_active = true
	$Sprite2D.modulate = Color(0.3, 0.3, 2.5)
	for _i in 4:
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self): return
		if is_instance_valid(player_ref):
			_spawn_coin(global_position, (player_ref.global_position - global_position).normalized(), 15)
	shield_active = false
	$Sprite2D.modulate = Color(1, 1, 1)
	# Explosion de sortie de bouclier
	for i in 6:
		var a = i * (TAU / 6.0)
		_spawn_coin(global_position, Vector2(cos(a), sin(a)), 14)
	await get_tree().create_timer(0.15).timeout

func _paladin_zone():
	for _p in (5 if phase == 1 else 4):
		if not is_instance_valid(self): return
		if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < 180:
			player_ref.take_damage(16)
		for i in 10:
			var a = i * (TAU / 10.0)
			_spawn_coin(global_position, Vector2(cos(a), sin(a)), 10)
		await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(0.2).timeout

# ══ ELF ════════════════════════════════════════════════════════

func _elf_salve(nb: int):
	if not is_instance_valid(player_ref): return
	var base = (player_ref.global_position - global_position).normalized()
	var step = deg_to_rad(14.0)
	var start = -(nb / 2.0) * step
	for i in nb:
		_spawn_coin(global_position, base.rotated(start + i * step), 12)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.15).timeout

func _elf_rafale():
	if not is_instance_valid(player_ref): return
	for _i in 7:
		if not is_instance_valid(self) or not is_instance_valid(player_ref): return
		_spawn_coin(global_position, (player_ref.global_position - global_position).normalized(), 10)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.1).timeout

func _elf_dash():
	# Téléporte et tire immédiatement
	var nouveau_x = (arena_width - 140.0) if global_position.x < arena_width * 0.5 else 140.0
	global_position.x = nouveau_x
	await _elf_salve(4)

func _elf_pluie():
	var nb = 9 if phase == 1 else 7
	for _i in nb:
		if not is_instance_valid(self): return
		_spawn_coin(Vector2(randf_range(60.0, arena_width - 60.0), 0), Vector2(0, 1), 11)
		await get_tree().create_timer(0.13).timeout
	await get_tree().create_timer(0.1).timeout

# ══ MAGE ═══════════════════════════════════════════════════════

func _mage_spirale():
	var anneaux = 4 if phase == 1 else 3
	for ring in anneaux:
		if not is_instance_valid(self): return
		for i in 10:
			var a = i * (TAU / 10.0) + ring * (PI / 10.0)
			_spawn_orb(global_position, Vector2(cos(a), sin(a)))
		await get_tree().create_timer(0.38).timeout
	await get_tree().create_timer(0.1).timeout

func _mage_vise():
	var nb = 5 if phase == 1 else 3
	for _i in nb:
		if not is_instance_valid(self) or not is_instance_valid(player_ref): return
		_spawn_orb(global_position, (player_ref.global_position - global_position).normalized())
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.1).timeout

func _mage_homing():
	var nb = 6 if phase == 1 else 4
	for _i in nb:
		if not is_instance_valid(self) or not is_instance_valid(player_ref): return
		_spawn_orb(global_position, (player_ref.global_position - global_position).normalized())
		await get_tree().create_timer(0.18).timeout
	await get_tree().create_timer(0.1).timeout

func _mage_pluie():
	var nb = 11 if phase == 1 else 8
	for _i in nb:
		if not is_instance_valid(self): return
		_spawn_orb(Vector2(randf_range(50.0, arena_width - 50.0), 0), Vector2(0, 1))
		await get_tree().create_timer(0.11).timeout
	await get_tree().create_timer(0.1).timeout

# ── Projectiles ────────────────────────────────────────────────

func _spawn_coin(from: Vector2, dir: Vector2, dmg: int):
	var coin = COIN_SCENE.instantiate()
	coin.global_position = from + dir * 32.0
	coin.direction = dir
	coin.damage = dmg
	coin.is_enemy_projectile = true
	get_tree().current_scene.add_child(coin)

func _spawn_orb(from: Vector2, dir: Vector2):
	var orb = ORB_SCENE.instantiate()
	orb.global_position = from + dir * 32.0
	orb.direction = dir
	get_tree().current_scene.add_child(orb)

# ── Dégâts / mort ──────────────────────────────────────────────

func take_damage(amount: int):
	if shield_active: return
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		_mourir()

func _flash_hit():
	$Sprite2D.modulate = Color(1.8, 0.4, 0.1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and not shield_active:
		$Sprite2D.modulate = Color(1, 1, 1)

func _mourir():
	set_physics_process(false)
	attaque_active = true
	for _i in 5:
		$Sprite2D.modulate = Color(2.5, 2.2, 0.3)
		await get_tree().create_timer(0.13).timeout
		if not is_instance_valid(self): return
		$Sprite2D.modulate = Color(0.1, 0.1, 0.1)
		await get_tree().create_timer(0.09).timeout
	Augments.reset()
	GameState.ajouter_recompense(GameState.boss_kills_run + 60, GameState.boss_temps_run)
	get_tree().change_scene_to_file("res://scenes/donjon.tscn")
