extends Node2D

const ENEMIES = {
	"guerrier": preload("res://scenes/enemies/guerrier.tscn"),
	"paladin":  preload("res://scenes/enemies/paladin.tscn"),
	"elf":      preload("res://scenes/enemies/elf.tscn"),
	"mage":     preload("res://scenes/enemies/mage.tscn"),
}
const BOSS_SCENE   = preload("res://scenes/enemies/boss.tscn")
const COFFRE_SCENE = preload("res://scenes/world/coffre.tscn")
const BOSS_TYPES  = ["guerrier", "paladin", "elf", "mage"]
const ALL_CLASSES = ["guerrier", "elf", "paladin", "mage"]

# 9 phases jouables — le boss arrive en "phase 10" après la dernière
const WAVES = [
	# Phase 1 — Guerriers
	{"duree": 25, "mode": "solo",   "classes": ["guerrier"],                           "spawn_delay": 1.4},
	# Phase 2 — Archers
	{"duree": 25, "mode": "solo",   "classes": ["elf"],                                "spawn_delay": 1.4},
	# Phase 3 — Paladins
	{"duree": 28, "mode": "solo",   "classes": ["paladin"],                            "spawn_delay": 1.6},
	# Phase 4 — Mages
	{"duree": 25, "mode": "solo",   "classes": ["mage"],                               "spawn_delay": 1.4},
	# [Dé du Destin entre phase 4 et 5]
	# Phase 5 — 2 classes aléatoires, groupes
	{"duree": 35, "mode": "groupe", "classes": [], "nb_add": 2,                        "spawn_delay": 6.5},
	# Phase 6 — +1 classe
	{"duree": 40, "mode": "groupe", "classes": [], "nb_add": 1,                        "spawn_delay": 4.5},
	# Phase 7 — +1 classe
	{"duree": 45, "mode": "groupe", "classes": [], "nb_add": 1,                        "spawn_delay": 4.0},
	# Phase 8 — Toutes les classes
	{"duree": 50, "mode": "groupe", "classes": ["guerrier","paladin","elf","mage"],     "spawn_delay": 3.5},
	# Phase 9 — Débordement total
	{"duree": 60, "mode": "groupe", "classes": ["guerrier","paladin","elf","mage"],     "spawn_delay": 2.5, "spawn_delay_end": 1.5},
]

var current_wave    = 0
var wave_timer      = 0.0
var spawn_timer     = 0.0
var spawn_radius    = 600.0
var player
var wave_active     = true
var _wave_cooldown  = 0.0

var boss_incoming:         bool   = false
var boss_type_pending:     String = ""
var boss_enemies_at_start: int    = 0
var boss_annonce_faite:    bool   = false

# Classes actives (phases 5–7 : accumulées aléatoirement)
var active_pool:  Array = []
var wave_classes: Array = []

# Distribution angulaire des spawns solos (rotation 8 secteurs)
var _spawn_sector: int = 0

# ── Debug panel ──────────────────────────────────────────
var _dbg_type:   String = "guerrier"
var _dbg_level:  int    = 1
var _dbg_panel:  Control
var _dbg_paused: bool   = false
var _dbg_btn_pause: Button

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	GameState.reset_de()
	wave_classes = WAVES[0]["classes"].duplicate()
	afficher_vague()
	_setup_atmosphere()
	_placer_coffre()
	if OS.is_debug_build():
		_creer_debug_panel()

func _placer_coffre() -> void:
	var coffre = COFFRE_SCENE.instantiate()
	coffre.global_position = Vector2(240, -60)
	get_parent().add_child(coffre)

func _creer_debug_panel() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_dbg_panel = PanelContainer.new()
	_dbg_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dbg_panel.offset_left  = -210
	_dbg_panel.offset_right = -8
	_dbg_panel.offset_top   = 8
	canvas.add_child(_dbg_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_dbg_panel.add_child(vbox)

	# Label titre
	var titre = Label.new()
	titre.text = "DEBUG SPAWN"
	titre.add_theme_font_size_override("font_size", 11)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titre)

	# Boutons types
	var lbl_type = Label.new()
	lbl_type.text = "Type :"
	lbl_type.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_type)

	var hbox_types = HBoxContainer.new()
	hbox_types.add_theme_constant_override("separation", 3)
	vbox.add_child(hbox_types)

	for t in ["guerrier", "elf", "mage", "paladin"]:
		var btn = Button.new()
		btn.text = t.capitalize()
		btn.add_theme_font_size_override("font_size", 10)
		btn.toggle_mode = true
		btn.button_pressed = (t == _dbg_type)
		btn.pressed.connect(func():
			_dbg_type = t
			_refresh_debug_buttons(hbox_types, t)
		)
		btn.set_meta("type_id", t)
		hbox_types.add_child(btn)

	# Boutons niveaux
	var lbl_lvl = Label.new()
	lbl_lvl.text = "Niveau :"
	lbl_lvl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_lvl)

	var hbox_lvls = HBoxContainer.new()
	hbox_lvls.add_theme_constant_override("separation", 3)
	vbox.add_child(hbox_lvls)

	for n in range(1, 6):
		var btn = Button.new()
		btn.text = str(n)
		btn.add_theme_font_size_override("font_size", 10)
		btn.toggle_mode = true
		btn.button_pressed = (n == _dbg_level)
		btn.pressed.connect(func():
			_dbg_level = n
			_refresh_debug_buttons(hbox_lvls, str(n))
		)
		btn.set_meta("type_id", str(n))
		hbox_lvls.add_child(btn)

	# Bouton pause vagues
	var sep = HSeparator.new()
	vbox.add_child(sep)

	_dbg_btn_pause = Button.new()
	_dbg_btn_pause.text = "▶ Vagues ON"
	_dbg_btn_pause.add_theme_font_size_override("font_size", 10)
	_dbg_btn_pause.toggle_mode = true
	_dbg_btn_pause.pressed.connect(_debug_toggle_pause)
	vbox.add_child(_dbg_btn_pause)

	# Bouton Spawn
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var btn_spawn = Button.new()
	btn_spawn.text = "⚔ Spawn 1"
	btn_spawn.add_theme_font_size_override("font_size", 11)
	btn_spawn.pressed.connect(_debug_spawn_enemy)
	vbox.add_child(btn_spawn)

	var btn_clear = Button.new()
	btn_clear.text = "✕ Clear"
	btn_clear.add_theme_font_size_override("font_size", 10)
	btn_clear.pressed.connect(_vider_ennemis)
	vbox.add_child(btn_clear)

func _refresh_debug_buttons(container: HBoxContainer, selected_id: String) -> void:
	for child in container.get_children():
		if child is Button:
			child.button_pressed = (child.get_meta("type_id") == selected_id)

func _debug_toggle_pause() -> void:
	_dbg_paused = not _dbg_paused
	if _dbg_paused:
		wave_active   = false
		boss_incoming = false
		_dbg_btn_pause.text = "⏸ Vagues OFF"
	else:
		wave_active = true
		_dbg_btn_pause.text = "▶ Vagues ON"
	_dbg_btn_pause.button_pressed = _dbg_paused

func _debug_spawn_enemy() -> void:
	if not ENEMIES.has(_dbg_type):
		return
	var enemy = ENEMIES[_dbg_type].instantiate()
	enemy.diff = _dbg_level
	var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
	enemy.global_position = (player.global_position if player else Vector2.ZERO) + offset
	get_parent().add_child(enemy)
	# setup() dans _ready() remet body_level à 1 — on force le bon niveau après
	enemy.body_level = _dbg_level
	enemy._appliquer_sprite()

func _setup_atmosphere() -> void:
	var cm = CanvasModulate.new()
	cm.color = Color(0.82, 0.74, 0.62)
	add_child(cm)

func _input(event: InputEvent):
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key and key.pressed and key.keycode == KEY_F9:
		wave_active   = false
		boss_incoming = false
		boss_type_pending = BOSS_TYPES[randi() % BOSS_TYPES.size()]
		_vider_ennemis()
		_spawner_boss_maintenant()

func _process(delta):
	if not player:
		return

	if boss_incoming:
		var alive = get_tree().get_nodes_in_group("enemy").size()
		var seuil = max(1, int(ceil(boss_enemies_at_start * 0.10)))
		if not boss_annonce_faite and alive <= seuil:
			boss_annonce_faite = true
			var hud = get_tree().get_first_node_in_group("hud")
			if hud:
				hud.afficher_annonce_boss(boss_type_pending)
		if alive == 0:
			boss_incoming = false
			_spawner_boss_maintenant()
		return

	if not wave_active:
		return

	if _wave_cooldown > 0.0:
		_wave_cooldown -= delta
		return

	wave_timer += delta
	var vague = WAVES[current_wave]

	var current_delay: float = vague["spawn_delay"]
	if vague.has("spawn_delay_end"):
		current_delay = lerp(vague["spawn_delay"], vague["spawn_delay_end"], wave_timer / vague["duree"])
	current_delay /= GameState.de_count_mult
	if _joueur_au_coffre():
		current_delay /= 1.3  # anti-camping : +30% spawn rate

	spawn_timer += delta
	if spawn_timer >= current_delay:
		spawn_timer = 0.0
		match vague["mode"]:
			"solo":   _spawn_solo(wave_classes)
			"groupe": _spawn_group(wave_classes)

	if wave_timer >= vague["duree"]:
		wave_timer = 0.0
		next_wave()

func next_wave():
	current_wave += 1
	if current_wave >= WAVES.size():
		wave_active = false
		boss_type_pending     = BOSS_TYPES[randi() % BOSS_TYPES.size()]
		boss_enemies_at_start = get_tree().get_nodes_in_group("enemy").size()
		boss_annonce_faite    = false
		if boss_enemies_at_start == 0:
			_spawner_boss_maintenant()
		else:
			boss_incoming = true
		return
	if GameState.objets_base["lit"] and player:
		player.current_hp = min(player.max_hp, player.current_hp + 20)
	wave_active = false
	_setup_wave_classes(current_wave)
	if current_wave == 4:
		_lancer_de()
	else:
		_transition_vague()

func _setup_wave_classes(wave_idx: int) -> void:
	var vague = WAVES[wave_idx]
	var nb_add: int = vague.get("nb_add", 0)
	if nb_add > 0:
		var remaining = ALL_CLASSES.filter(func(c): return not active_pool.has(c))
		remaining.shuffle()
		for i in min(nb_add, remaining.size()):
			active_pool.append(remaining[i])
		wave_classes = active_pool.duplicate()
	else:
		wave_classes = vague["classes"].duplicate()

# Spawn individuel depuis les 8 secteurs en rotation
func _spawn_solo(classes: Array) -> void:
	_spawn_sector += 1
	var angle = _spawn_sector * (TAU / 8.0) + randf_range(-0.3, 0.3)
	var pos = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
	pos += Vector2(randf_range(-50, 50), randf_range(-50, 50))
	_spawn_at(classes[randi() % classes.size()], pos)

# Spawn en formation : paladins devant, guerriers flancs, elfs/mages derrière
func _spawn_group(classes: Array) -> void:
	var angle  = randf() * TAU
	var origin = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
	var toward = (player.global_position - origin).normalized()
	var perp   = Vector2(-toward.y, toward.x)

	var has_p = "paladin"  in classes
	var has_g = "guerrier" in classes
	var has_e = "elf"      in classes
	var has_m = "mage"     in classes

	# Paladins — en tête (côté joueur)
	if has_p:
		_spawn_at("paladin", origin + toward * 65.0)
		if classes.size() >= 3:
			_spawn_at("paladin", origin + toward * 55.0 + perp * 30.0)

	# Guerriers — flancs, légèrement en avant
	if has_g:
		_spawn_at("guerrier", origin + perp * 65.0 + toward * 25.0)
		_spawn_at("guerrier", origin - perp * 65.0 + toward * 25.0)
		if has_p or has_m:
			_spawn_at("guerrier", origin + toward * 15.0)
	elif has_p:
		_spawn_at("paladin", origin + perp * 55.0)
		_spawn_at("paladin", origin - perp * 55.0)

	# Archers — derrière, protégés par la mêlée
	if has_e:
		_spawn_at("elf", origin - toward * 55.0 + perp * 60.0)
		_spawn_at("elf", origin - toward * 55.0 - perp * 60.0)

	# Mages — loin derrière
	if has_m:
		_spawn_at("mage", origin - toward * 90.0 + perp * 35.0)
		_spawn_at("mage", origin - toward * 90.0 - perp * 35.0)

func _spawn_at(type: String, pos: Vector2) -> void:
	var enemy = ENEMIES[type].instantiate()
	enemy.global_position = pos
	if GameState.de_speed_mult != 1.0:
		var spd = enemy.get("speed")
		if spd != null:
			enemy.set("speed", float(spd) * GameState.de_speed_mult)
	get_parent().add_child(enemy)
	if GameState.de_mort_spontanee:
		_ajouter_mort_spontanee(enemy)

func _transition_vague():
	await get_tree().create_timer(0.4).timeout
	wave_timer  = 0.0
	spawn_timer = 0.0
	wave_active = true
	afficher_vague()

func _lancer_de():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.lancer_de()
	var effet: Dictionary = GameState.de_effet
	spawn_radius += effet.get("spawn_radius_delta", 0.0)
	if effet.get("regen_actif", false):
		_demarrer_regen()
	var hp_bonus: int = effet.get("player_hp_bonus", 0)
	if hp_bonus > 0 and player:
		player.current_hp = min(player.max_hp, player.current_hp + hp_bonus)
	await get_tree().create_timer(0.4).timeout
	wave_timer      = 0.0
	spawn_timer     = 0.0
	_wave_cooldown  = effet.get("calm_delay", 0.0)
	wave_active     = true
	afficher_vague()

func _demarrer_regen():
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(func():
		if is_instance_valid(player) and GameState.de_regen_actif:
			player.current_hp = min(player.max_hp, player.current_hp + 1)
	)
	add_child(timer)

func _ajouter_mort_spontanee(enemy: Node):
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(func():
		if is_instance_valid(enemy) and randf() < 0.15:
			enemy.queue_free()
	)
	enemy.add_child(timer)

func _vider_ennemis():
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

func _spawner_boss_maintenant():
	var boss_pos = player.global_position + Vector2(0, -160) if player else Vector2.ZERO
	var boss     = BOSS_SCENE.instantiate()
	boss.setup(boss_type_pending)
	boss.global_position = boss_pos
	get_parent().add_child(boss)
	_spawner_renforts_boss(boss_type_pending)

func _spawner_renforts_boss(type: String) -> void:
	for i in 6:
		var angle := i * TAU / 6.0 + randf_range(-0.2, 0.2)
		var enemy = ENEMIES[type].instantiate()
		enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
		get_parent().add_child(enemy)

func _joueur_au_coffre() -> bool:
	for coffre in get_tree().get_nodes_in_group("coffre"):
		if coffre.get("player_inside") == true:
			return true
	return false

func afficher_vague():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_wave(current_wave + 1, WAVES.size() + 1)
