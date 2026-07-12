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

func _teleporter_pres_joueur() -> void:
	var angle = randf() * TAU
	var rayon = randf_range(380.0, 460.0)
	var tele  = player.global_position + Vector2(cos(angle), sin(angle)) * rayon
	if tele.length() > 640.0:
		tele = tele.normalized() * 630.0
	global_position = tele

func get_direction() -> Vector2:
	var to_player   = (player.global_position - global_position).normalized()
	var dist_center = global_position.length()
	if dist_center > 640.0:
		# Blend progressif : 0% repulsion à 640px, 100% à 680px
		var inward = -global_position.normalized()
		var blend  = clampf((dist_center - 640.0) / 40.0, 0.0, 1.0)
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
