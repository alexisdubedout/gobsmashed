extends CharacterBody2D
class_name BaseEnemy

const BLOOD_POOL_SCENE       = preload("res://scenes/effects/blood_pool.tscn")
const GUERRIER_SCENE         = preload("res://scenes/enemies/guerrier.tscn")
const PIECE_RAMASSABLE_SCENE = preload("res://scenes/projectiles/piece_ramassable.tscn")

const SPRITES_PATH := "res://assets/sprites/placeholder/"

var max_hp    = 40
var current_hp = 40
var speed     = 175.0
var base_speed = 175.0
var damage    = 9
var xp_value  = 3

var player
var rooted  = false
var slowed  = false

var body_level        := 1
var enemy_type_name   := "guerrier"
var body_visual_scale := Vector2(1.35, 1.35)
var body_color        := Color.WHITE

var _animator: CharacterAnimator
var _face_dir := "down"
var _attack_anim_timer := 0.0
var _stuck_timer:     float   = 0.0
var _pos_check_timer: float   = 0.0
var _last_check_pos:  Vector2 = Vector2.ZERO
static var _last_bubble_time: float = -9999.0
var _pas_bulle: float = 0.0

# Skills niveau difficulté (cumulatifs)
var diff: int = 1
var _en_rage:         bool  = false   # niv 2 : ×2 vitesse sous 30% HP
var _saut_cd:         float = 0.0    # niv 3 : mini-charge périodique
var _saut_dir:        Vector2 = Vector2.ZERO
var _saut_actif:      bool  = false
var _resistance:      int   = 0      # niv 4 : −2 dégâts/coup
var _ressuscite:      bool  = false  # niv 5 : revient une fois (utilisé dans die())

func _ready():
	player = get_tree().get_first_node_in_group("player")
	setup()
	if diff == 1:
		diff = GameState.niveau_difficulte
	_animator = CharacterAnimator.new()
	_animator.init(self)
	_appliquer_sprite()
	_activer_competences()

func _activer_competences() -> void:
	if diff >= 4:
		_resistance = 2
	if diff >= 5:
		_ressuscite = false  # disponible une fois

func _appliquer_sprite() -> void:
	var path := SPRITES_PATH + "body_%s_level_%d_frames.tres" % [enemy_type_name, body_level]
	if ResourceLoader.exists(path):
		$body.sprite_frames = load(path)
	$body.scale    = body_visual_scale
	$body.modulate = body_color
	$body.visible  = true
	_appliquer_outline($body)
	for layer in ["shadow", "clothes", "armor_chest", "armor_legs", "helmet", "weapon"]:
		var node = get_node_or_null(layer)
		if node:
			node.visible = false

static func _appliquer_outline(sprite: CanvasItem) -> void:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 px  = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, UV);
	if (base.a > 0.01) { COLOR = base; return; }
	float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
	        + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
	        + texture(TEXTURE, UV + vec2(0.0, px.y)).a
	        + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	COLOR = vec4(0.06, 0.03, 0.0, clamp(a, 0.0, 1.0));
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	sprite.material = mat

func setup():
	enemy_type_name = "guerrier"
	body_level      = 1

const MEMES_GUERRIER = [
	"THIS IS SPARTAAAA !!",
	"LEEEEROYYYY JENKINSSS !!",
	"GET OVER HERE !",
	"IT'S OVER 9000 !!",
	"DO YOU EVEN LIFT BRO",
	"we do a little trolling",
	"UNLIMITED POWER !!!",
]

func _physics_process(_delta):
	_attack_anim_timer = max(0.0, _attack_anim_timer - _delta)
	if rooted:
		velocity = Vector2.ZERO
		move_and_slide()
		_animator.play("idle", _face_dir)
		return

	self.modulate = Color(0.6, 0.75, 1.5) if slowed else Color.WHITE

	# Niv 3 — saut d'assaut
	if diff >= 3:
		_saut_cd = max(0.0, _saut_cd - _delta)
		if _saut_actif:
			velocity = _saut_dir * 380.0
			move_and_slide()
			var dist_s = global_position.distance_to(player.global_position) if player else 999.0
			if dist_s < 35.0:
				player.take_damage_from(damage, self)
				_attack_anim_timer = 0.5
			_saut_cd = 5.0
			_saut_actif = false
			return
		elif _saut_cd <= 0.0 and player:
			var dist_s = global_position.distance_to(player.global_position)
			if dist_s > 80.0 and dist_s < 350.0:
				_saut_dir = (player.global_position - global_position).normalized()
				_saut_actif = true
				_saut_cd = 5.0

	if player:
		var current_speed = base_speed * 0.4 if slowed else speed
		# Niv 2 — rage sous 30% HP
		if diff >= 2 and _en_rage:
			current_speed = speed * 2.0
		var direction = get_direction()
		direction = (direction + get_separation_force()).normalized()
		animate(direction, _delta)
		velocity = velocity.lerp(direction * current_speed, min(1.0, _delta * 10.0))
		move_and_slide()

		# Unstuck : seulement contre les murs/tuiles (pas les autres ennemis)
		var wall_hits = 0
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col and not col.get_collider().is_in_group("enemy") and not col.get_collider().is_in_group("player"):
				wall_hits += 1
		if wall_hits > 0:
			_stuck_timer += _delta
			if _stuck_timer > 0.25:
				_stuck_timer = 0.0
				var sign = 1.0 if randf() > 0.5 else -1.0
				velocity = direction.rotated(sign * randf_range(0.5, 1.1)) * current_speed * 1.2
				move_and_slide()
		else:
			_stuck_timer = 0.0

		_pas_bulle += velocity.length() * _delta
		if _pas_bulle >= 800.0:
			_pas_bulle = 0.0
			_afficher_bulle(MEMES_GUERRIER[randi() % MEMES_GUERRIER.size()])

		var dist = global_position.distance_to(player.global_position)
		if dist < 35.0:
			player.take_damage_from(damage, self)
			_attack_anim_timer = 0.5

	# Téléportation de secours
	_pos_check_timer += _delta
	if _pos_check_timer >= 3.0:
		if player:
			var moved      = global_position.distance_to(_last_check_pos)
			var dist_player = global_position.distance_to(player.global_position)
			if (moved < 25.0 and dist_player > 300.0) or (dist_player > 520.0 and moved < 40.0):
				_teleporter_pres_joueur()
		_last_check_pos  = global_position
		_pos_check_timer = 0.0

const MAP_HALF := 900.0

func _teleporter_pres_joueur() -> void:
	var angle = randf() * TAU
	var rayon = randf_range(380.0, 460.0)
	var tele  = player.global_position + Vector2(cos(angle), sin(angle)) * rayon
	tele.x = clampf(tele.x, -(MAP_HALF - 10.0), MAP_HALF - 10.0)
	tele.y = clampf(tele.y, -(MAP_HALF - 10.0), MAP_HALF - 10.0)
	global_position = tele

func get_direction() -> Vector2:
	var to_player = (player.global_position - global_position).normalized()
	# Si l'ennemi est déjà proche du joueur, il fonce — la limite de map ne bloque pas
	if global_position.distance_to(player.global_position) < 200.0:
		return to_player
	var px = absf(global_position.x)
	var py = absf(global_position.y)
	var edge_excess = maxf(px - MAP_HALF, py - MAP_HALF)
	if edge_excess > 0.0:
		var inward = Vector2.ZERO
		if px > MAP_HALF: inward.x = -signf(global_position.x)
		if py > MAP_HALF: inward.y = -signf(global_position.y)
		if inward != Vector2.ZERO: inward = inward.normalized()
		var blend = clampf(edge_excess / 40.0, 0.0, 1.0)
		return to_player.lerp(inward, blend).normalized()
	return to_player

func animate(direction: Vector2, _delta: float):
	if _attack_anim_timer > 0.0 and player:
		var to_player: Vector2 = player.global_position - global_position
		if abs(to_player.x) > abs(to_player.y):
			_face_dir = "right" if to_player.x > 0 else "left"
		else:
			_face_dir = "down" if to_player.y > 0 else "up"
		_animator.play("attack", _face_dir)
		return
	# Hysteresis : ne change d'axe que si un composant est clairement dominant
	if abs(direction.x) > abs(direction.y) + 0.2:
		_face_dir = "right" if direction.x > 0 else "left"
	elif abs(direction.y) > abs(direction.x) + 0.2:
		_face_dir = "down" if direction.y > 0 else "up"
	_animator.play("run", _face_dir)

func get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	for other in enemies:
		if other == self:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < 55.0:
			var push = (global_position - other.global_position).normalized()
			force += push * (55.0 - dist) / 55.0 * 1.6
	if player:
		var dist_player = global_position.distance_to(player.global_position)
		if dist_player < 38.0:
			var push = (global_position - player.global_position).normalized()
			force += push * 0.8
	return force

func take_damage(amount):
	var dmg = max(1, amount - _resistance)
	current_hp -= dmg
	# Niv 2 — rage activée sous 30% HP
	if diff >= 2 and not _en_rage and current_hp <= max_hp * 0.3:
		_en_rage = true
		$body.modulate = Color(2.0, 0.3, 0.3)
	_flash_hit()
	if current_hp <= 0:
		die()

func _flash_hit():
	$body.modulate = Color(1.5, 0.6, 0.2)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		$body.modulate = body_color

func _afficher_bulle(texte: String) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_bubble_time < randf_range(100.0, 130.0):
		return
	if not is_inside_tree():
		return
	_last_bubble_time = now
	_creer_bulle_tete(texte)
	_creer_bandeau_aw(texte)

func _creer_bulle_tete(texte: String) -> void:
	if get_node_or_null("BulleDialogue"):
		return
	var panel = PanelContainer.new()
	panel.name = "BulleDialogue"
	panel.z_index = 10
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 0.93, 0.93)
	style.border_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.corner_radius_top_left = 5; style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5; style.corner_radius_bottom_right = 5
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 3; style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = texte
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	panel.add_child(lbl)
	add_child(panel)
	var w = texte.length() * 5.5 + 14.0
	panel.position = Vector2(-w * 0.5, -88)
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)

func _creer_bandeau_aw(texte: String) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	var old = scene.get_node_or_null("BandeauAW")
	if old:
		old.queue_free()
	var vp = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.name = "BandeauAW"
	canvas.layer = 18
	scene.add_child(canvas)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(vp.x - 4.0, 72.0)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.07, 0.04, 0.12, 0.93)
	pstyle.border_color = Color(0.75, 0.6, 0.15)
	pstyle.border_width_top = 3
	pstyle.border_width_left = 0; pstyle.border_width_right = 0; pstyle.border_width_bottom = 0
	pstyle.content_margin_left = 10; pstyle.content_margin_right = 8
	pstyle.content_margin_top = 6; pstyle.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", pstyle)
	canvas.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Zone texte (gauche)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)

	var lbl_txt = Label.new()
	lbl_txt.text = texte
	lbl_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_txt.add_theme_font_size_override("font_size", 13)
	lbl_txt.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	lbl_txt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl_txt.add_theme_constant_override("shadow_offset_x", 1)
	lbl_txt.add_theme_constant_override("shadow_offset_y", 1)
	lbl_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl_txt)

	# Portrait sprite (droite, style Advance Wars)
	var pbg = PanelContainer.new()
	pbg.custom_minimum_size = Vector2(58, 58)
	pbg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ec = _get_couleur_ennemi()
	var pbg_style = StyleBoxFlat.new()
	pbg_style.bg_color = ec.darkened(0.6)
	pbg_style.border_color = ec
	pbg_style.border_width_top = 2; pbg_style.border_width_bottom = 2
	pbg_style.border_width_left = 2; pbg_style.border_width_right = 2
	pbg_style.corner_radius_top_left = 4; pbg_style.corner_radius_top_right = 4
	pbg_style.corner_radius_bottom_left = 4; pbg_style.corner_radius_bottom_right = 4
	pbg.add_theme_stylebox_override("panel", pbg_style)
	hbox.add_child(pbg)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(54, 54)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body_node = get_node_or_null("body") as AnimatedSprite2D
	if body_node and body_node.sprite_frames:
		for anim_try in ["idle_down", "run_down", "idle_up", "run_up"]:
			if body_node.sprite_frames.has_animation(anim_try) and \
					body_node.sprite_frames.get_frame_count(anim_try) > 0:
				portrait.texture = body_node.sprite_frames.get_frame_texture(anim_try, 0)
				break
	pbg.add_child(portrait)

	panel.position = Vector2(2.0, vp.y + 20.0)
	var tween = canvas.create_tween()
	tween.tween_property(panel, "position:y", vp.y - 96.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(7.0)
	tween.tween_property(panel, "scale", Vector2(0.12, 0.12), 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(panel, "position", Vector2(vp.x - 22.0, vp.y - 12.0), 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(canvas.queue_free)

func _get_couleur_ennemi() -> Color:
	match enemy_type_name:
		"guerrier": return Color("#cc6633")
		"elf":      return Color("#44bb66")
		"paladin":  return Color("#4466dd")
		"mage":     return Color("#aa33cc")
	return Color("#888888")

func die():
	# Niv 5 — frénésie : se divise en 2 mini-guerriers
	if diff >= 5 and not _ressuscite:
		_ressuscite = true
		_spawner_mini_guerriers()

	var pool: BloodPool = BLOOD_POOL_SCENE.instantiate()
	pool.global_position = global_position
	pool.radius = body_visual_scale.x * 20.0
	get_tree().current_scene.add_child(pool)

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.gagner_xp(xp_value)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.ajouter_kill()

	# Drop pièces ramassables
	for _i in randi_range(2, 4):
		var piece = PIECE_RAMASSABLE_SCENE.instantiate()
		piece.global_position = global_position + Vector2(randf_range(-28, 28), randf_range(-20, 20))
		get_tree().current_scene.add_child(piece)

	queue_free()

func _spawner_mini_guerriers() -> void:
	for i in 2:
		var mini = GUERRIER_SCENE.instantiate()
		mini.diff = 0  # empêche _ready() d'écraser avec le niveau global
		mini.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		get_tree().current_scene.add_child(mini)
		# _ready() a tiré ici avec diff=0, on surcharge les stats après
		mini.max_hp     = 20
		mini.current_hp = 20
		mini.speed      = speed * 1.2
		mini.base_speed = speed * 1.2
		mini.damage     = int(damage * 0.6)
		mini.xp_value   = 0
