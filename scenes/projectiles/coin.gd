extends Area2D

var speed = 280.0
var damage = 15
var direction = Vector2.ZERO
var is_enemy_projectile = false
var piece_lourde_niveau = 0
var can_pierce = false
var can_bounce = false
var already_hit = []
var hit_radius = 20.0

var anim_timer = 0.0
var anim_delay = 0.08
var anim_frame = 0

func _ready():
	_ajouter_lumiere()
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		queue_free()

func _ajouter_lumiere() -> void:
	var light = PointLight2D.new()
	light.texture        = _creer_texture_lumiere(64)
	light.texture_scale  = 1.1
	light.energy         = 1.2
	light.color          = Color(0.96, 0.78, 0.15)
	light.blend_mode     = PointLight2D.BLEND_MODE_ADD
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

func _spawn_impact_sparks() -> void:
	var p = CPUParticles2D.new()
	p.emitting             = false
	p.amount               = 7
	p.lifetime             = 0.35
	p.one_shot             = true
	p.explosiveness        = 1.0
	p.direction            = Vector2.UP
	p.spread               = 160.0
	p.gravity              = Vector2(0.0, 320.0)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min     = 2.5
	p.scale_amount_max     = 4.5
	p.color                = Color(0.96, 0.78, 0.15, 1.0)
	p.global_position      = global_position
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _physics_process(_delta):
	global_position += direction * speed * _delta

	anim_timer += _delta
	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 8
		$Sprite2D.frame = anim_frame

	if is_enemy_projectile:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < hit_radius and player.take_damage(damage):
				queue_free()
	else:
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			if enemy in already_hit:
				continue
			var dist = global_position.distance_to(enemy.global_position)
			if dist < hit_radius:
				var _p = get_tree().get_first_node_in_group("player")
				# Frappe critique
				var _crit_chance = _p.get("crit_chance") if _p else null
				var _crit = _crit_chance != null and randf() < _crit_chance
				var _dmg_final = damage * (2 if _crit else 1)
				enemy.take_damage(_dmg_final)
				if _crit:
					_texte_flottant("CRIT! " + str(_dmg_final), enemy.global_position, Color("#ff3300"), 19)
					if _crit_chance != null and _crit_chance >= 0.35:
						_exploser(enemy, 1)
				else:
					_texte_flottant(str(_dmg_final), enemy.global_position, Color("#ffe566"), 16)
				if _p:
					var _drain = _p.get("drain_niveau")
					if _drain != null and _drain > 0:
						if _p.get("ultime_forteresse"): _drain *= 3
						_p.current_hp = min(_p.max_hp, _p.current_hp + _drain)
						_texte_flottant("+" + str(_drain) + "♥", _p.global_position, Color("#88ff99"))
					var _explo = _p.get("explosion_niveau")
					if _explo != null and _explo > 0:
						_exploser(enemy, _explo)
					# Pièces empoisonnées
					var _pe_val = _p.get("pieces_empoisonnees")
					var _pe: int = _pe_val if _pe_val != null else 0
					if _pe > 0:
						_appliquer_poison_ennemi(enemy, _pe)
				if piece_lourde_niveau >= 1:
					enemy.slowed = true
					var slow_dur: float = 1.5 + float(piece_lourde_niveau - 1)
					get_tree().create_timer(slow_dur).timeout.connect(
						func(): if is_instance_valid(enemy): enemy.slowed = false
					)
				if piece_lourde_niveau >= 3:
					enemy.rooted = true
					await get_tree().create_timer(0.5).timeout
					if is_instance_valid(enemy):
						enemy.rooted = false
				if can_pierce:
					already_hit.append(enemy)
					_spawn_impact_sparks()
					continue
				if can_bounce and already_hit.is_empty():
					already_hit.append(enemy)
					_spawn_impact_sparks()
					var others = get_tree().get_nodes_in_group("enemy")
					others = others.filter(func(e): return e != enemy)
					if not others.is_empty():
						var next = others[randi() % others.size()]
						direction = (next.global_position - global_position).normalized()
					return
				_spawn_impact_sparks()
				queue_free()
				return

func _exploser(source: Node, niveau: int):
	var rayons: Array[float] = [50.0, 75.0, 100.0]
	var pcts: Array[float]   = [0.3,  0.5,  0.7]
	var rayon: float = rayons[niveau - 1]
	var dmg_aoe: int = int(damage * pcts[niveau - 1])
	var flash = Node2D.new()
	flash.set_script(preload("res://scenes/effects/explosion_flash.gd"))
	flash.global_position = global_position
	flash.set("radius", rayon)
	get_tree().current_scene.add_child(flash)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == source: continue
		if global_position.distance_to(e.global_position) < rayon:
			e.take_damage(dmg_aoe)
			_texte_flottant(str(dmg_aoe), e.global_position, Color("#ff8c42"), 13)
			if niveau >= 3:
				e.set("slowed", true)

func _appliquer_poison_ennemi(enemy: Node, niveau: int) -> void:
	var dmgs = [2, 3, 4]
	var durs = [2.0, 3.0, 4.0]
	var dmg_dot = dmgs[niveau - 1]
	var duree   = durs[niveau - 1]
	for i in int(duree):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(enemy): return
		enemy.take_damage(dmg_dot)
	if niveau >= 3 and is_instance_valid(enemy):
		enemy.set("slowed", true)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(enemy): enemy.set("slowed", false)

func _texte_flottant(texte: String, pos: Vector2, couleur: Color, font_size: int = 14) -> void:
	var lbl = Label.new()
	lbl.text = texte
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", couleur)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = pos + Vector2(randf_range(-18, 18), -28)
	get_tree().current_scene.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 36, 0.65).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(lbl.queue_free)
