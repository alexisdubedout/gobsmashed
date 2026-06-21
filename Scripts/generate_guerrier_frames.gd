@tool
extends EditorScript

## Génère body_guerrier_level_1_frames.tres depuis les PNGs exportés par le
## LPC generator (zip by animation).
## Usage : Script > Exécuter (Ctrl+Shift+X)

const SRC_STD    := "res://assets/guerrier_lvl_1/standard/"
const SRC_CUSTOM := "res://assets/guerrier_lvl_1/custom/"
const OUT        := "res://assets/sprites/placeholder/body_guerrier_level_1_frames.tres"
const FPS        := 8.0
const DIRS       := ["up", "left", "down", "right"]

# [nom_jeu, dossier, fichier, taille_frame, nb_frames, loop, single_direction]
const ANIMS := [
	["idle",   "std",    "idle.png",      64,  2, true,  false],
	["run",    "std",    "run.png",        64,  8, true,  false],
	["attack", "custom", "slash_128.png", 128,  6, true,  false],
	["hurt",   "std",    "hurt.png",       64,  6, false, true ],
]

func _run() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for cfg: Array in ANIMS:
		var game_name : String = cfg[0]
		var src_dir   : String = SRC_STD if cfg[1] == "std" else SRC_CUSTOM
		var file      : String = cfg[2]
		var fw        : int    = cfg[3]
		var n_frames  : int    = cfg[4]
		var loop      : bool   = cfg[5]
		var single_dir: bool   = cfg[6]

		var tex := load(src_dir + file) as Texture2D
		if tex == null:
			push_error("Fichier introuvable : " + src_dir + file)
			continue

		for d in DIRS.size():
			var dir       : String = DIRS[d]
			var full_name : String = game_name + "_" + dir
			var row       : int    = 0 if single_dir else d

			sf.add_animation(full_name)
			sf.set_animation_speed(full_name, FPS)
			sf.set_animation_loop(full_name, loop)

			for f in n_frames:
				var atlas      := AtlasTexture.new()
				atlas.atlas     = tex
				atlas.region    = Rect2(f * fw, row * fw, fw, fw)
				sf.add_frame(full_name, atlas)

	if ResourceSaver.save(sf, OUT) == OK:
		print("✓ Généré : ", OUT)
		get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("✗ Échec : " + OUT)
