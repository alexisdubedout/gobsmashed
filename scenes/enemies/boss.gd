extends CharacterBody2D

const BOSS_NAMES := {
	"guerrier": "Grug le Magnifique",
	"mage":     "Nadège la Ténébreuse",
	"paladin":  "Régis le Sanctifié",
	"elf":      "Sylvara l'Insaisissable",
}

const BOSS_COLORS := {
	"guerrier": Color("#cc3322"),
	"mage":     Color("#7755ee"),
	"paladin":  Color("#bb9900"),
	"elf":      Color("#228855"),
}

const SPEED_NORMAL  := 130.0
const SPEED_CHARGE  := 310.0
const CHARGE_EVERY  := 2.2   # secondes entre deux charges
const CHARGE_DUR    := 0.55  # durée de la charge

var boss_type: String = ""
var aura_timer: float = 0.0
var transition_triggered: bool = false

var _charge_timer: float   = 0.0
var _charge_active: bool   = false
var _charge_remaining: float = 0.0

func setup(type: String):
	boss_type = type

func _ready():
	$Sprite2D.visible = false
	_setup_sprite()
	_creer_aura()
	_creer_message_arrivee()

func _setup_sprite():
	var tres := "res://assets/sprites/placeholder/body_%s_level_1_frames.tres" % boss_type
	var body := $body as AnimatedSprite2D
	if ResourceLoader.exists(tres):
		body.sprite_frames = load(tres)
		body.scale = Vector2(1.35, 1.35)
		body.visible = true
		body.play("idle_down")

func _creer_aura():
	var boss_color: Color = BOSS_COLORS.get(boss_type, Color("#ffffff"))
	var p := CPUParticles2D.new()
	p.z_index = -1
	p.emitting = true
	p.amount = 16
	p.lifetime = 1.5
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -15.0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var pc := boss_color
	pc.a = 0.55
	p.color = pc
	add_child(p)

func _creer_message_arrivee():
	var boss_name: String = BOSS_NAMES.get(boss_type, "Boss")
	var lbl := Label.new()
	lbl.text = "%s est arrivé !" % boss_name
	lbl.add_theme_font_size_override("font_size", 11)
	var col: Color = BOSS_COLORS.get(boss_type, Color("#ff4444"))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(160, 20)
	lbl.position = Vector2(-80, -58)
	add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

func take_damage(_amount):
	pass

func _physics_process(delta):
	if transition_triggered:
		return

	aura_timer += delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	# Gestion de la charge
	_charge_timer += delta
	if not _charge_active and _charge_timer >= CHARGE_EVERY:
		_charge_timer = 0.0
		_charge_active = true
		_charge_remaining = CHARGE_DUR
		_flash_charge()

	var current_speed := SPEED_NORMAL
	if _charge_active:
		_charge_remaining -= delta
		current_speed = SPEED_CHARGE
		if _charge_remaining <= 0.0:
			_charge_active = false
			_fin_charge()

	var dir: Vector2 = (player.global_position - global_position).normalized()
	velocity = dir * current_speed
	move_and_slide()

	_animer(dir)

	if global_position.distance_to(player.global_position) < 65.0:
		_declencher_combat(player)

func _flash_charge():
	var boss_color: Color = BOSS_COLORS.get(boss_type, Color("#ffffff"))
	var body := $body as AnimatedSprite2D
	var tw := create_tween().set_loops(0)
	tw.tween_property(body, "modulate", boss_color.lightened(0.6), 0.08)
	tw.tween_property(body, "modulate", Color(1, 1, 1), 0.08)
	# s'arrête automatiquement quand _fin_charge() tue le tween via reset modulate
	get_tree().create_timer(CHARGE_DUR).timeout.connect(func(): tw.kill())

func _fin_charge():
	($body as AnimatedSprite2D).modulate = Color(1, 1, 1)

func _animer(dir: Vector2):
	var body := $body as AnimatedSprite2D
	if body.sprite_frames == null:
		return
	var d_str := "down"
	if abs(dir.x) > abs(dir.y):
		d_str = "right" if dir.x > 0 else "left"
	elif dir.y < 0:
		d_str = "up"
	var anim := "run_" + d_str
	if not body.sprite_frames.has_animation(anim):
		anim = "idle_" + d_str
	if not body.sprite_frames.has_animation(anim):
		return
	if body.animation != anim or not body.is_playing():
		body.play(anim)

func _declencher_combat(player: Node2D):
	transition_triggered = true
	GameState.boss_type = boss_type
	GameState.boss_hp_joueur = int(player.get("current_hp"))

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		GameState.boss_kills_run = hud.ennemis_tues
		GameState.boss_temps_run = hud.temps

	get_tree().change_scene_to_file("res://scenes/boss_fight/boss_intro.tscn")
