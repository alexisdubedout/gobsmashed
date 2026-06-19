@tool
extends EditorScript

## Génère body_goblin_frames.tres depuis les PNGs exportés par le LPC generator.
## Usage : Script > Exécuter (Ctrl+Shift+X)

const SRC := "res://assets/gobelin_lvl_1/standard/"
const OUT := "res://assets/sprites/placeholder/body_goblin_frames.tres"
const FW  := 64
const FH  := 64
const FPS := 8.0
const DIRS := ["up", "left", "down", "right"]

# [nom_jeu, fichier_lpc, nb_frames, loop, single_direction]
const ANIMS := [
	["idle",   "idle.png",          2, true,  false],
	["run",    "run.png",           8, true,  false],
	["attack", "1h_halfslash.png",  6, false, false],
	["hurt",   "hurt.png",          6, false, true ],
]

func _run() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for cfg: Array in ANIMS:
		var game_name : String = cfg[0]
		var file      : String = cfg[1]
		var n_frames  : int    = cfg[2]
		var loop      : bool   = cfg[3]
		var single_dir: bool   = cfg[4]

		var tex := load(SRC + file) as Texture2D
		if tex == null:
			push_error("Fichier introuvable : " + SRC + file)
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
				atlas.region    = Rect2(f * FW, row * FH, FW, FH)
				sf.add_frame(full_name, atlas)

	if ResourceSaver.save(sf, OUT) == OK:
		print("✓ Généré : ", OUT)
		get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("✗ Échec : " + OUT)
