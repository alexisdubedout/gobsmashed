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
	"guerrier": {"hp": 500, "scale": 2.4, "delay_p1": 1.8, "delay_p2": 1.1},
	"paladin":  {"hp": 750, "scale": 2.8, "delay_p1": 2.0, "delay_p2": 1.1},
	"elf":      {"hp": 320, "scale": 2.1, "delay_p1": 1.3, "delay_p2": 0.75},
	"mage":     {"hp": 380, "scale": 2.2, "delay_p1": 1.5, "delay_p2": 0.9},
}

const SEQUENCES = {
	"guerrier": [
		["charge", "stomp", "spin", "charge"],
		["double_charge", "stomp", "spin", "charge"],
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
	if type == "guerrier":
		saut_cooldown = 5.0

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

	if boss_type == "mage":
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
			velocity.x = sign(dx) * 185.0 if abs(dx) > 28 else move_toward(velocity.x, 0, 500 * delta)
		"paladin":
			velocity.x = sign(dx) * 80.0 if abs(dx) > 75 else move_toward(velocity.x, 0, 200 * delta)
		"elf":
			if abs(dx) > 200:   velocity.x = sign(dx) * 170.0
			elif abs(dx) < 80:  velocity.x = -sign(dx) * 130.0
			else:               velocity.x = move_toward(velocity.x, 0, 350 * delta)
		"mage":
			var spd = 100.0 if phase == 0 else 130.0
			velocity.x = sign(dx) * spd if abs(dx) > 55 else move_toward(velocity.x, 0, 300 * delta)

	saut_timer += delta
	if is_on_floor() and not attaque_active:
		if dy > 90 and boss_type == "guerrier":
			# Joueur en bas — descendre rapidement de la plateforme
			if saut_timer >= 1.5:
				_descendre()
				saut_cooldown = randf_range(1.5, 2.5)
		elif dy > 140:
			if saut_timer >= saut_cooldown:
				_descendre()
		elif dy < -90 and boss_type == "guerrier":
			# Joueur en hauteur — poursuite réactive
			if saut_timer >= 1.5:
				_sauter(dx)
				saut_cooldown = randf_range(1.5, 2.5)
		elif saut_timer >= saut_cooldown:
			if dy < -70 and boss_type != "guerrier":
				_sauter(dx)
			elif randf() < _proba_saut():
				_sauter(dx)

func _proba_saut() -> float:
	match boss_type:
		"guerrier": return 0.03 if phase == 0 else 0.05
		"paladin":  return 0.12 if phase == 0 else 0.28
		"elf":      return 0.65 if phase == 0 else 0.85
		"mage":     return 0.22 if phase == 0 else 0.42
	return 0.3

func _sauter(dx: float):
	velocity.y = JUMP_FORCE
	if abs(dx) > 50:
		velocity.x = sign(dx) * 160.0
	saut_timer = 0.0
	if boss_type == "guerrier":
		saut_cooldown = randf_range(4.5, 7.0) if phase == 0 else randf_range(3.0, 5.0)
	else:
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
		saut_cooldown = 3.5 if boss_type == "guerrier" else 1.2
		if boss_type == "guerrier":
			_intro_phase_deux_guerrier()
		else:
			_annonce_phase_deux()

func _intro_phase_deux_guerrier():
	attaque_active = true
	for _i in 8:
		$Sprite2D.modulate = Color(2.5, 0.1, 0.1)
		if not is_inside_tree(): return
		await get_tree().create_timer(0.09).timeout
		if not is_inside_tree(): return
		$Sprite2D.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.06).timeout

	await _guerrier_stomp(240.0, 16)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree(): return

	await _guerrier_stomp(380.0, 22)
	if not is_inside_tree(): return

	var bf = get_tree().current_scene
	if bf.has_method("_transition_phase_deux"):
		bf._transition_phase_deux()

	await get_tree().create_timer(0.5).timeout
	attaque_active = false

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
	var nom = seq[seq_index % seq.size()]

	# Guerrier : charge inutile si le joueur est en hauteur → stomp à la place
	if boss_type == "guerrier" and is_instance_valid(player_ref):
		var hauteur = global_position.y - player_ref.global_position.y
		if hauteur > 90 and nom in ["charge", "double_charge"]:
			nom = "stomp"

	await _executer(nom)
	seq_index += 1
	attaque_active = false

	if boss_type == "mage" and tele_timer <= 0 and not en_teleportation:
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
	tele_timer = randf_range(8.0, 13.0) if phase == 0 else randf_range(5.0, 8.0)

	# Destination offensive : flanc du joueur, côté opposé à notre position
	var side = -sign(player_ref.global_position.x - global_position.x)
	if side == 0: side = 1
	var dest_x = clamp(
		player_ref.global_position.x + side * randf_range(130.0, 210.0),
		80.0, arena_width - 80.0
	)

	# ── Incantation : scintille doré 0.9s ────────────────────────
	var t = 0.0
	while t < 0.9:
		if not is_instance_valid(self): return
		var p = sin(t * TAU * 6.0) * 0.5 + 0.5
		$Sprite2D.modulate = Color(1.0 + p * 1.8, 1.0 + p * 0.8, 0.1 + p * 0.2)
		await get_tree().process_frame
		t += get_process_delta_time()

	# ── Fantôme à la destination (0.55s) ─────────────────────────
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

	# ── Apparition : flash blanc → fondu 0.35s ───────────────────
	global_position.x = dest_x
	t = 0.0
	while t < 0.35:
		if not is_instance_valid(self): return
		var fade = 1.0 - t / 0.35
		$Sprite2D.modulate = Color(1.0 + fade * 2.5, 1.0 + fade * 2.5, 1.0 + fade * 2.5)
		await get_tree().process_frame
		t += get_process_delta_time()

	if not is_instance_valid(self): return
	$Sprite2D.modulate = Color(1, 1, 1)

	# Burst immédiat après apparition
	var nb_tir = 3 if phase == 1 else 2
	for _i in nb_tir:
		if not is_instance_valid(self) or not is_instance_valid(player_ref): break
		_spawn_orb(global_position, (player_ref.global_position - global_position).normalized())
		await get_tree().create_timer(0.16).timeout

	if is_instance_valid(self):
		en_teleportation = false

# ══ GUERRIER ═══════════════════════════════════════════════════

func _guerrier_charge(vitesse: float, duree: float, dmg: int):
	if not is_instance_valid(player_ref): return
	if not is_on_floor(): return

	# Télégraphe rouge lisible (~0.45s) pour laisser le temps de réagir
	for _i in 5:
		$Sprite2D.modulate = Color(3.0, 0.05, 0.05)
		if not is_inside_tree(): return
		await get_tree().create_timer(0.05).timeout
		if not is_inside_tree(): return
		$Sprite2D.modulate = Color(1, 1, 1)
		if not is_inside_tree(): return
		await get_tree().create_timer(0.04).timeout

	if not is_instance_valid(player_ref): return
	dir_charge    = sign(player_ref.global_position.x - global_position.x)
	vitesse_charge = vitesse
	contact_dmg   = dmg
	en_charge     = true

	# Charge avec traînée rouge
	var t        = 0.0
	var trail_cd = 0.0
	while t < duree:
		if not is_inside_tree(): return
		trail_cd -= get_process_delta_time()
		if trail_cd <= 0.0:
			_spawn_trail_rouge()
			trail_cd = 0.06
		await get_tree().process_frame
		t += get_process_delta_time()

	en_charge     = false
	vitesse_charge = 0.0

	# Stun d'impact — fenêtre de punition pour le joueur
	if not is_inside_tree(): return
	$Sprite2D.modulate = Color(0.28, 0.28, 0.28)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree(): return
	$Sprite2D.modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.15).timeout

func _guerrier_stomp(rayon_force: float = 0.0, dmg_force: int = 0):
	# Télégraphe doré avant le saut
	$Sprite2D.modulate = Color(2.2, 1.8, 0.15)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.20).timeout
	if not is_inside_tree(): return
	$Sprite2D.modulate = Color(1, 1, 1)

	velocity.y = -560.0
	var t = 0.0
	while not is_on_floor() and t < 1.5:
		if not is_inside_tree(): return
		await get_tree().process_frame
		t += get_process_delta_time()
	if not is_inside_tree(): return

	# Onde de choc à l'atterrissage
	var rayon    = rayon_force if rayon_force > 0 else (380.0 if phase == 1 else 240.0)
	var dmg_base = dmg_force  if dmg_force  > 0 else (22     if phase == 1 else 16)
	_creer_onde_choc(rayon)

	if is_instance_valid(player_ref):
		var dx = abs(player_ref.global_position.x - global_position.x)
		var dy = player_ref.global_position.y - global_position.y
		# abs(dy) < 90 : ne touche que les cibles au même niveau, pas en dessous
		if dx <= rayon and abs(dy) < 90:
			player_ref.take_damage(dmg_base)

	if phase == 1:
		if not is_inside_tree(): return
		await get_tree().create_timer(0.32).timeout
		if not is_inside_tree(): return
		_creer_onde_choc(rayon * 0.65)
		if is_instance_valid(player_ref):
			var dx2 = abs(player_ref.global_position.x - global_position.x)
			var dy2 = player_ref.global_position.y - global_position.y
			if dx2 <= rayon * 0.65 and abs(dy2) < 90:
				player_ref.take_damage(13)

	if not is_inside_tree(): return
	await get_tree().create_timer(0.28).timeout

func _guerrier_spin():
	var duree    = 1.55 if phase == 1 else 1.1
	var rayon    = 135.0 if phase == 1 else 100.0
	var dmg_tick = 14
	var dmg_cd   = 0.0

	var t = 0.0
	while t < duree:
		if not is_inside_tree(): return
		$Sprite2D.modulate = Color(1.6 + sin(t * 22.0) * 0.55, 0.12, 0.12)

		dmg_cd -= get_process_delta_time()
		if dmg_cd <= 0.0 and is_instance_valid(player_ref):
			if global_position.distance_to(player_ref.global_position) <= rayon:
				player_ref.take_damage(dmg_tick)
				dmg_cd = 0.28

		await get_tree().process_frame
		t += get_process_delta_time()

	if not is_inside_tree(): return
	$Sprite2D.modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.50).timeout

func _guerrier_double_charge():
	await _guerrier_charge(930.0, 0.46, 34)
	if not is_inside_tree(): return
	# Pause entre les deux charges — joueur peut se repositionner
	$Sprite2D.modulate = Color(3.0, 0.05, 0.05)
	await get_tree().create_timer(0.40).timeout
	if not is_inside_tree(): return
	$Sprite2D.modulate = Color(1, 1, 1)
	await _guerrier_charge(970.0, 0.44, 38)

# ── Helpers visuels guerrier ────────────────────────────────────

func _spawn_trail_rouge():
	var ghost = Sprite2D.new()
	ghost.texture         = $Sprite2D.texture
	ghost.hframes         = 8
	ghost.vframes         = 4
	ghost.frame           = $Sprite2D.frame
	ghost.scale           = scale
	ghost.modulate        = Color(1.8, 0.04, 0.04, 0.60)
	ghost.global_position = global_position
	get_tree().current_scene.add_child(ghost)
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.20)
	tw.tween_callback(ghost.queue_free)

func _creer_onde_choc(rayon: float):
	var onde = ColorRect.new()
	onde.color    = Color("#dd2200")
	onde.color.a  = 0.78
	onde.size     = Vector2(6, 26)
	onde.position = global_position - Vector2(3, 13)
	get_tree().current_scene.add_child(onde)

	var t = 0.0
	var duree    = 0.30
	var base_x   = global_position.x
	var base_y   = global_position.y
	while t < duree:
		if not is_instance_valid(onde): return
		var p = t / duree
		var w = rayon * 2.0 * p
		var h = 26.0 * (1.0 - p * 0.55)
		onde.size     = Vector2(w, h)
		onde.position = Vector2(base_x - w * 0.5, base_y - h * 0.5)
		onde.color.a  = 0.78 * (1.0 - p)
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(onde): onde.queue_free()

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
