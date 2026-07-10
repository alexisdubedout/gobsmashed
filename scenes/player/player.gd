extends CharacterBody2D

const LEVEL_UP_SCENE = preload("res://scenes/level_up_screen.tscn")
const COIN_SCENE = preload("res://scenes/projectiles/coin.tscn")
const POISON_SCENE = preload("res://scenes/effects/poison_pool.tscn")
const TRAP_SCENE = preload("res://scenes/effects/trap.tscn")
const ALLY_SCENE = preload("res://scenes/player/ally.tscn")

const SPEED = 200.0

var bourse:     int = 20
var bourse_max: int = 30

var touch_direction = Vector2.ZERO
var touch_id = -1
var joystick_origin = Vector2.ZERO
var coin_bounce = false
var coin_pierce = false
var ally_fast = false
var pieces_lourdes_niveau = 0
var avarice_niveau = 0
var rage_niveau = 0
var level_up_screen
var ATTACK_DELAY = 1.2
var multi_shot = 0
var max_hp = 100	
var current_hp = 100
var attack_timer = 0.0
var xp = 0
var xp_next_level = 10
var level = 1
var is_moving = false
var _face_dir: String = "down"
var _animator: CharacterAnimator
var _attack_anim_timer := 0.0
var flaque_timer = 0.0
var poison_on_kill = false
var poison_niveau = 1 
var pieces_lourdes = false
var trappe_active = false

# Cooldowns de dégâts par source
var damage_cooldowns = {}
var damage_cooldown_duration = 0.5

# Dash
var dash_requested: bool  = false
var dash_active:    bool  = false
var dash_timer:     float = 0.0
var dash_cd:        float = 0.0
var dash_cd_dur:    float = 1.5
var dash_dur:       float = 0.22
var iframe_dur_wave: float = 0.18
var invincible:     bool  = false
var last_move_dir:  Vector2 = Vector2.RIGHT

# Bouclier
var bouclier_actif:         bool  = false
var bouclier_magique_actif: bool  = false
var bouclier_cd:            float = 0.0
var bouclier_cd_dur:        float = 8.0
var bouclier_soin_actif:    bool  = false
var bouclier_renvoi_mult:   float = 1.0
var bouclier_renvoi_aoe:    bool  = false

var drain_niveau:         int = 0
var fortification_niveau: int = 0
var explosion_niveau:     int = 0
var coffre_regen_niveau:  int = 0

func _ready():
	_animator = CharacterAnimator.new()
	_animator.init(self)
	var path := "res://assets/sprites/placeholder/body_goblin_frames.tres"
	if ResourceLoader.exists(path):
		$body.sprite_frames = load(path)
	$body.scale   = Vector2(1.20, 1.20)
	$body.visible = true
	for layer in ["shadow", "clothes", "armor_chest", "armor_legs", "helmet", "weapon"]:
		var node = get_node_or_null(layer)
		if node:
			node.visible = false
	level_up_screen = LEVEL_UP_SCENE.instantiate()
	# Applique les bonus permanents
	max_hp = 100 + GameState.get_hp_max_bonus()
	current_hp = max_hp
	ATTACK_DELAY = 1.2 / GameState.get_attaque_bonus()
	# Démarre légèrement en bas de la base
	global_position = Vector2(0, 80)
	# La vitesse et les dégâts sont appliqués dynamiquement
	match Augments.stacks.get("Dash éclair", 0):
		1: dash_cd_dur = 1.1; iframe_dur_wave = 0.22
		2: dash_cd_dur = 0.7; iframe_dur_wave = 0.28; dash_dur = 0.24
		3: dash_cd_dur = 0.5; iframe_dur_wave = 0.35; dash_dur = 0.28
	if GameState.objets_base["tourelle"]:
		ajouter_collegue()
	if GameState.objets_base["piege"]:
		activer_trappe()
	if GameState.objets_base["bouclier"]:
		bouclier_actif = true
		if not GameState.objets_base["bouclier_magique"]:
			var orbite = Node2D.new()
			orbite.set_script(preload("res://scenes/effects/bouclier_orbite.gd"))
			add_child(orbite)
	if GameState.objets_base["bouclier_magique"]:
		bouclier_magique_actif = true
		var bulle = Node2D.new()
		bulle.set_script(preload("res://scenes/effects/bouclier_bulle.gd"))
		add_child(bulle)
	_ajouter_lumiere()

func _ajouter_lumiere() -> void:
	var light = PointLight2D.new()
	light.texture       = _creer_texture_lumiere(128)
	light.texture_scale = 4.5
	light.energy        = 1.1
	light.color         = Color(0.91, 0.72, 0.25)
	light.blend_mode    = PointLight2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	add_child(light)

static func _creer_texture_lumiere(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c   = size / 2.0
	for x in size:
		for y in size:
			var d = Vector2(x, y).distance_to(Vector2(c, c)) / c
			var a = maxf(0.0, 1.0 - d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			dash_requested = true
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_id = event.index
			joystick_origin = event.position
		elif event.index == touch_id:
			touch_id = -1
			touch_direction = Vector2.ZERO
	
	if event is InputEventScreenDrag:
		if event.index == touch_id:
			var delta = event.position - joystick_origin
			if delta.length() > 20:
				touch_direction = delta.normalized()
			else:
				touch_direction = Vector2.ZERO

func _physics_process(_delta):
	_attack_anim_timer = max(0.0, _attack_anim_timer - _delta)

	# Mise à jour des cooldowns
	for key in damage_cooldowns.keys():
		damage_cooldowns[key] -= _delta
		if damage_cooldowns[key] <= 0:
			damage_cooldowns.erase(key)

	dash_cd = max(dash_cd - _delta, 0.0)
	bouclier_cd = max(bouclier_cd - _delta, 0.0)

	# Déplacement
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
		
	if touch_direction != Vector2.ZERO:
		direction = touch_direction

	if direction != Vector2.ZERO:
		last_move_dir = direction.normalized()

	# Direction et animation
	if direction != Vector2.ZERO:
		is_moving = true
		if abs(direction.x) > abs(direction.y):
			_face_dir = "right" if direction.x > 0 else "left"
		else:
			_face_dir = "down" if direction.y > 0 else "up"
	else:
		is_moving = false

	if _attack_anim_timer > 0.0:
		_animator.play("attack", _face_dir)
	else:
		_animator.play("run" if is_moving else "idle", _face_dir)

	if dash_active:
		dash_timer -= _delta
		velocity = last_move_dir * 550.0
		if dash_timer <= 0.0:
			dash_active = false
	elif dash_requested and dash_cd <= 0.0:
		dash_requested = false
		dash_active = true
		dash_timer = dash_dur
		dash_cd = dash_cd_dur * GameState.de_dash_cd_mult
		velocity = last_move_dir * 550.0
		_iframe_wave()
	else:
		if direction != Vector2.ZERO:
			direction = direction.normalized()
		velocity = direction * SPEED * GameState.get_vitesse_bonus() * GameState.de_player_speed_mult
	move_and_slide()

	# Flaque de poison
	if poison_on_kill:
		flaque_timer += _delta
		if flaque_timer >= 5.0:
			flaque_timer = 0.0
			poser_flaque()

	# Trappe aléatoire
	if trappe_active and randf() < 0.002:
		poser_trappe()

	# Attaque auto
	attack_timer += _delta
	if attack_timer >= ATTACK_DELAY:
		attack_timer = 0.0
		shoot()

func shoot():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty() or bourse <= 0:
		return
	_attack_anim_timer = 0.4
	var closest = null
	var closest_dist = INF
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	if closest == null:
		return
	fire_coin(closest.global_position)
	bourse -= 1
	for i in multi_shot:
		if bourse <= 0:
			break
		var enemies2 = get_tree().get_nodes_in_group("enemy")
		enemies2.shuffle()
		if enemies2.size() > i + 1:
			fire_coin(enemies2[i + 1].global_position)
		else:
			fire_coin(closest.global_position.rotated((i + 1) * 0.3))
		bourse -= 1

func ajouter_bourse(amount: int) -> void:
	bourse = mini(bourse + amount, bourse_max)

func fire_coin(target_pos):
	var coin = COIN_SCENE.instantiate()
	var shoot_direction = (target_pos - global_position).normalized()
	coin.global_position = global_position + shoot_direction * 30.0
	coin.direction = shoot_direction
	coin.piece_lourde_niveau = pieces_lourdes_niveau
	coin.can_pierce = coin_pierce
	coin.can_bounce = coin_bounce
	coin.damage = int(15 * (1.0 + rage_niveau * 0.2) * GameState.get_degats_bonus())
	get_tree().current_scene.add_child(coin)

func _iframe_wave():
	invincible = true
	var t = 0.0
	while t < iframe_dur_wave:
		$body.modulate = Color(0.3, 0.8, 2.0) if int(t * 20) % 2 == 0 else Color(1, 1, 1)
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(self):
		$body.modulate = Color(1, 1, 1)
		invincible = false

func tenter_bloquer_projectile(projectile: Node, incoming_dir: Vector2) -> bool:
	if invincible or not bouclier_actif or bouclier_cd > 0.0:
		return false
	bouclier_cd = bouclier_cd_dur
	_flash_bouclier()
	if bouclier_soin_actif:
		current_hp = min(max_hp, current_hp + 3)
	if not is_instance_valid(projectile):
		return true
	if bouclier_magique_actif:
		projectile.set("direction", -incoming_dir)
		projectile.set("reflechi", true)
		projectile.set("reflechi_mult", bouclier_renvoi_mult)
		projectile.set("reflechi_aoe", bouclier_renvoi_aoe)
	else:
		projectile.queue_free()
	return true

func _flash_bouclier():
	$body.modulate = Color(0.4, 0.9, 2.2)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and not invincible:
		$body.modulate = Color(1, 1, 1)

func take_damage_from(amount: int, source) -> void:
	if invincible: return
	var source_id = source.get_instance_id()
	if source_id in damage_cooldowns:
		return
	damage_cooldowns[source_id] = damage_cooldown_duration
	var dmg: int = max(1, amount - min(fortification_niveau * 2, 4))
	if fortification_niveau >= 3:
		dmg = max(1, int(dmg * 0.85))
	var dmg_final := int(dmg * GameState.de_dmg_taken_mult)
	current_hp -= dmg_final
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("enregistrer_dommage"):
		var type_src: String = source.get("enemy_type_name") if source.get("enemy_type_name") != null else "?"
		hud.enregistrer_dommage(type_src, dmg_final)
	if current_hp <= 0:
		die()

func take_damage(amount: int) -> bool:
	if invincible: return false
	var dmg: int = max(1, amount - min(fortification_niveau * 2, 4))
	if fortification_niveau >= 3:
		dmg = max(1, int(dmg * 0.85))
	current_hp -= int(dmg * GameState.de_dmg_taken_mult)
	if current_hp <= 0:
		die()
	return true

func _invincible_bref(duree: float):
	if invincible: return
	invincible = true
	await get_tree().create_timer(duree).timeout
	if is_instance_valid(self):
		invincible = false

func appliquer_poison(dmg_per_sec: int, duree: float) -> void:
	var ticks = int(duree)
	for i in ticks:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or invincible:
			return
		take_damage(dmg_per_sec)

func gagner_xp(montant):
	xp += int(montant * GameState.de_xp_mult)
	if avarice_niveau > 0:
		current_hp = min(max_hp, current_hp + avarice_niveau)
	if xp >= xp_next_level:
		xp = 0
		xp_next_level = int(xp_next_level * 1.25)
		level_up()


func level_up():
	level += 1
	var pool = Augments.get_liste_disponible().duplicate()
	pool.shuffle()
	var cartes = pool.slice(0, min(3, pool.size()))
	if cartes.is_empty():
		return
	if not level_up_screen.is_inside_tree():
		get_tree().current_scene.add_child(level_up_screen)
	level_up_screen.afficher(cartes)

func die():
	GameState.ajouter_mort()
	Augments.reset()
	var hud = get_tree().get_first_node_in_group("hud")
	var vague = 1
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		vague = spawner.current_wave + 1
	if hud:
		hud.afficher_game_over(vague)
	else:
		get_tree().reload_current_scene()
	queue_free()

func ajouter_collegue():
	var ally = ALLY_SCENE.instantiate()
	get_tree().current_scene.add_child(ally)
	ally.global_position = global_position + Vector2(60, 0)

func activer_flaque_poison(niveau: int):
	poison_on_kill = true
	poison_niveau = niveau

func activer_pieces_lourdes():
	pass  # plus utilisé, géré via pieces_lourdes_niveau

func activer_trappe():
	trappe_active = true

func poser_flaque():
	var pool = POISON_SCENE.instantiate()
	pool.global_position = global_position
	pool.niveau = poison_niveau
	get_tree().current_scene.add_child(pool)

func poser_trappe():
	var trap = TRAP_SCENE.instantiate()
	trap.global_position = global_position
	get_tree().current_scene.add_child(trap)
	
