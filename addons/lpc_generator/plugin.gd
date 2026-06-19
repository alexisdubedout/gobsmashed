@tool
extends EditorPlugin

## Génère automatiquement les SpriteFrames depuis les spritesheets LPC.
## Dès qu'un PNG correspondant apparaît dans le dossier, le .tres est créé.
##
## Format attendu : spritesheet Universal LPC 128×128 par frame, 13 colonnes.
## Nommage : guerrier_level_1.png → guerrier_level_1_frames.tres
##
## Layout LPC (rows, 4 directions chacune : down/left/right/up) :
##   Rows  0-3  : SPELLCAST  (7 frames)  — ignoré
##   Rows  4-7  : THRUST     (8 frames)  — ignoré
##   Rows  8-11 : WALK       (9 frames)  → "run"    (8 frames utilisés)
##   Rows 12-15 : SLASH      (6 frames)  → "attack"
##   Rows 16-19 : SHOOT      (13 frames) — ignoré
##   Rows 20-23 : HURT       (6 frames)  → "hurt"
##   Rows 24-27 : DEATH      (6 frames)  → "die"    (si présent)
##
## Pour changer le mapping, modifie LPC_MAP ci-dessous.

const FRAME_W := 64
const FRAME_H := 64
const FPS     := 8

## Mapping LPC → animations du jeu.
## Format : [ row_base, nb_frames, loop, single_direction ]
## single_direction=true : toutes les directions utilisent la même ligne (row_base+0).
## Direction order dans chaque groupe : up(+0), left(+1), right(+2), down(+3)
const LPC_MAP := {
	"idle":   [8,  1, true,  false],  # walk row 8, 1 frame = pose neutre
	"run":    [8,  6, true,  false],  # walk rows 8-11 (down=11)
	"attack": [54, 6, true,  false],  # slash rows 54-57 (down=57)
	"die":    [21, 6, false, true ],  # death row 21 — direction unique
}
const LPC_DIRS := ["down", "left", "right", "up"]

const ENEMY_TYPES  := ["guerrier", "elf", "mage", "paladin"]
const ENEMY_LEVELS := 6
const SPRITES_PATH := "res://assets/sprites/placeholder/"
const PLAYER_NAME  := "goblin"

var _timer: Timer


func _enter_tree() -> void:
	_timer = Timer.new()
	_timer.one_shot   = true
	_timer.wait_time  = 1.0
	_timer.timeout.connect(_auto_generate)
	add_child(_timer)
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_on_fs_changed)
	# Passe aussi au démarrage de l'éditeur
	_timer.start()


func _exit_tree() -> void:
	var fs := get_editor_interface().get_resource_filesystem()
	if fs.filesystem_changed.is_connected(_on_fs_changed):
		fs.filesystem_changed.disconnect(_on_fs_changed)


func _on_fs_changed() -> void:
	# Redémarre le timer à chaque changement — génère seulement après que
	# l'import du PNG soit terminé (plus de changements pendant 1 s).
	_timer.stop()
	_timer.start()


func _auto_generate() -> void:
	var generated := 0
	for type in ENEMY_TYPES:
		for level in range(1, ENEMY_LEVELS + 1):
			var base := "body_%s_level_%d" % [type, level]
			var png  := SPRITES_PATH + base + "_lpc.png"
			var tres := SPRITES_PATH + base + "_frames.tres"
			if _exists(png) and not _exists(tres):
				if _generate(png, tres):
					generated += 1

	var p_png  := SPRITES_PATH + "body_" + PLAYER_NAME + "_lpc.png"
	var p_tres := SPRITES_PATH + "body_" + PLAYER_NAME + "_frames.tres"
	if _exists(p_png) and not _exists(p_tres):
		if _generate(p_png, p_tres):
			generated += 1

	if generated > 0:
		print("[LPC Generator] %d SpriteFrames généré(s)." % generated)
		get_editor_interface().get_resource_filesystem().scan()


func _exists(res_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(res_path))


func _generate(png_path: String, out_path: String) -> bool:
	if not ResourceLoader.exists(png_path):
		return false
	var tex := load(png_path) as Texture2D
	if tex == null:
		return false
	var tex_h := tex.get_height()

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for anim_name: String in LPC_MAP:
		var cfg        : Array = LPC_MAP[anim_name]
		var row_base   : int   = cfg[0]
		var n_frames   : int   = cfg[1]
		var loop       : bool  = cfg[2]
		var single_dir : bool  = cfg[3]

		for d in LPC_DIRS.size():
			var row  : int    = row_base + (0 if single_dir else d)
			var dir  : String = LPC_DIRS[d]
			var full : String = anim_name + "_" + dir

			if (row + 1) * FRAME_H > tex_h:
				continue

			sf.add_animation(full)
			sf.set_animation_speed(full, FPS)
			sf.set_animation_loop(full, loop)

			for i in n_frames:
				var atlas       := AtlasTexture.new()
				atlas.atlas      = tex
				atlas.region     = Rect2(i * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
				sf.add_frame(full, atlas)

	var ok := ResourceSaver.save(sf, out_path) == OK
	if ok:
		print("  ✓ ", out_path)
	else:
		push_error("  ✗ Échec : " + out_path)
	return ok
