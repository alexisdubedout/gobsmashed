@tool
extends EditorScript

## Génère body_paladin_level_1_frames.tres depuis les PNGs LPC.
## Usage : Script > Exécuter (Ctrl+Shift+X)

const SRC  := "res://assets/paladin-lvl-1/standard/"
const OUT  := "res://assets/sprites/placeholder/body_paladin_level_1_frames.tres"
const FW   := 64
const FPS  := 8.0
const DIRS := ["up", "left", "down", "right"]

# [nom_jeu, fichier, nb_frames, loop, single_dir]
const ANIMS := [
	["idle",   "walk.png",   1, true,  false],  # frame 0 = debout avec bouclier
	["run",    "walk.png",   9, true,  false],
	["attack", "thrust.png", 8, false, false],  # dash/charge
	["hurt",   "hurt.png",   6, false, true ],
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
				atlas.region    = Rect2(f * FW, row * FW, FW, FW)
				sf.add_frame(full_name, atlas)

	if ResourceSaver.save(sf, OUT) == OK:
		print("✓ Généré : ", OUT)
		get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("✗ Échec : " + OUT)
