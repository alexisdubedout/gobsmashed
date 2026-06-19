@tool
extends EditorScript

## Génère les SpriteFrames depuis un spritesheet Universal LPC.
## Format : 128×128 par frame, 13 colonnes, layout LPC standard.
##
## Placer les fichiers :
##   assets/sprites/enemies/guerrier_level_1.png  (et autres types/niveaux)
##   assets/sprites/player/goblin.png
##
## Usage : Script > Exécuter (Ctrl+Shift+X)

# ── Taille d'une frame (LPC exporté à 2× = 128px) ──────────────────
const FRAME_W := 64
const FRAME_H := 64
const FPS     := 8

# ── Mapping : animation du jeu → ligne de base dans le spritesheet LPC ──
# Ordre des directions dans chaque groupe LPC : down, left, right, up
# Si une animation n'existe pas dans ton sheet (sheet trop court),
# elle sera simplement ignorée et l'ennemi jouera "idle" à la place.
const LPC_MAP := {
	# [ row_base, nb_frames, loop, single_direction ]
	"idle":   [8,  1, true,  false],
	"run":    [8,  6, true,  false],
	"attack": [54, 6, true,  false],
	"die":    [21, 6, false, true ],
}
const LPC_DIRS := ["down", "left", "right", "up"]

# ── Fichiers à traiter ──────────────────────────────────────────────
const ENEMY_TYPES  := ["guerrier", "elf", "mage", "paladin"]
const ENEMY_LEVELS := 6
const SPRITES_PATH := "res://assets/sprites/placeholder/"
const PLAYER_NAME  := "goblin"

func _run() -> void:
	var generated := 0
	for type in ENEMY_TYPES:
		for level in range(1, ENEMY_LEVELS + 1):
			var base := "body_%s_level_%d" % [type, level]
			var png  := SPRITES_PATH + base + "_lpc.png"
			if not ResourceLoader.exists(png):
				continue
			_generate(png, SPRITES_PATH + base + "_frames.tres")
			generated += 1
	var p_png := SPRITES_PATH + "body_" + PLAYER_NAME + "_lpc.png"
	if ResourceLoader.exists(p_png):
		_generate(p_png, SPRITES_PATH + "body_" + PLAYER_NAME + "_frames.tres")
		generated += 1
	print("Terminé — %d fichier(s) générés." % generated)


func _generate(png_path: String, out_path: String) -> void:
	var tex    : Texture2D = load(png_path)
	var tex_h  : int       = tex.get_height()
	var sf     := SpriteFrames.new()
	sf.remove_animation("default")

	for anim_name in LPC_MAP:
		var cfg        : Array = LPC_MAP[anim_name]
		var row_base   : int   = cfg[0]
		var n_frames   : int   = cfg[1]
		var loop       : bool  = cfg[2]
		var single_dir : bool  = cfg[3]

		for d in LPC_DIRS.size():
			var row      : int    = row_base + (0 if single_dir else d)
			var dir      : String = LPC_DIRS[d]
			var full     : String = anim_name + "_" + dir

			if (row + 1) * FRAME_H > tex_h:
				continue

			sf.add_animation(full)
			sf.set_animation_speed(full, FPS)
			sf.set_animation_loop(full, loop)

			for i in n_frames:
				var atlas := AtlasTexture.new()
				atlas.atlas  = tex
				atlas.region = Rect2(i * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
				sf.add_frame(full, atlas)

	if ResourceSaver.save(sf, out_path) == OK:
		print("  ✓ ", out_path)
	else:
		push_error("Échec : " + out_path)
