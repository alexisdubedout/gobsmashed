"""
generate_tres.py — Génère les fichiers SpriteFrames .tres pour Godot 4.
Lit les PNG déjà convertis et produit un .tres par combinaison (layer, name).

Usage : python generate_tres.py
        (détecte automatiquement toutes les combinaisons layer/name présentes)
"""
import os, random, string

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
RES_BASE   = "res://assets/sprites/placeholder/"
FRAME_SIZE = 64
FPS        = 8.0

LAYER_NAMES = ["shadow", "body", "clothes", "armor_chest", "armor_legs", "helmet", "weapon"]

ANIM_FRAMES = {
    "idle":   4,
    "run":    6,
    "attack": 5,
    "hurt":   2,
    "die":    6,
}
DIRECTIONS = ["down", "up", "left", "right"]


def uid() -> str:
    chars = string.ascii_lowercase + string.digits
    return "uid://" + "".join(random.choices(chars, k=12))


def short_id(n: int = 5) -> str:
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choices(chars, k=n))


def detect_combos():
    combos = []
    seen = set()
    for fname in sorted(os.listdir(BASE_DIR)):
        if not fname.endswith("_idle_down.png"):
            continue
        for layer in LAYER_NAMES:
            prefix = layer + "_"
            if fname.startswith(prefix):
                name = fname[len(prefix):][:-len("_idle_down.png")]
                key = (layer, name)
                if key not in seen and name != "":
                    seen.add(key)
                    combos.append(key)
                break
    return combos


def generate_tres(layer: str, name: str):
    # Build ordered list of (anim, direction) → png filename
    entries = []
    for anim in sorted(ANIM_FRAMES.keys()):
        for direction in sorted(DIRECTIONS):
            fname = f"{layer}_{name}_{anim}_{direction}.png"
            fpath = os.path.join(BASE_DIR, fname)
            if os.path.exists(fpath):
                entries.append((anim, direction, fname))

    if not entries:
        print(f"  SKIP {layer}_{name} — aucun PNG trouvé")
        return

    # Assign ext_resource ids
    # One ext_resource per PNG file (deduplicated by filename)
    png_files = sorted(set(e[2] for e in entries))
    ext_ids = {}
    for i, fname in enumerate(png_files, 1):
        ext_ids[fname] = f"{i}_{short_id()}"

    lines = []

    # Header
    lines.append(f'[gd_resource type="SpriteFrames" format=3 uid="{uid()}"]')
    lines.append("")

    # ext_resources
    for fname in png_files:
        res_path = RES_BASE + fname
        lines.append(f'[ext_resource type="Texture2D" uid="{uid()}" path="{res_path}" id="{ext_ids[fname]}"]')
    lines.append("")

    # Build atlas sub_resources and animation data
    atlas_ids = {}   # (anim, dir, frame_idx) → atlas sub_resource id
    sub_lines = []

    for anim, direction, fname in entries:
        n_frames = ANIM_FRAMES[anim]
        ext_id = ext_ids[fname]
        for i in range(n_frames):
            aid = f"AtlasTexture_{short_id()}"
            atlas_ids[(anim, direction, i)] = aid
            sub_lines.append(f'[sub_resource type="AtlasTexture" id="{aid}"]')
            sub_lines.append(f'atlas = ExtResource("{ext_id}")')
            sub_lines.append(f'region = Rect2({i * FRAME_SIZE}, 0, {FRAME_SIZE}, {FRAME_SIZE})')
            sub_lines.append("")

    lines.extend(sub_lines)

    # Main resource
    lines.append('[resource]')
    lines.append('animations = [{')

    anim_blocks = []
    for anim_name in sorted(ANIM_FRAMES.keys()):
        for direction in DIRECTIONS:
            if (anim_name, direction, 0) not in atlas_ids:
                continue
            n_frames = ANIM_FRAMES[anim_name]
            loop = "true" if anim_name != "die" else "false"
            full_name = f"{anim_name}_{direction}"

            frame_entries = []
            for i in range(n_frames):
                aid = atlas_ids[(anim_name, direction, i)]
                frame_entries.append(
                    '"duration": 1.0,\n'
                    f'"texture": SubResource("{aid}")'
                )

            frames_str = "}, {\n".join(frame_entries)
            block = (
                f'"frames": [{{\n{frames_str}\n}}],\n'
                f'"loop": {loop},\n'
                f'"name": &"{full_name}",\n'
                f'"speed": {FPS}'
            )
            anim_blocks.append(block)

    lines.append(("}, {\n").join(anim_blocks))
    lines.append("}]")

    out_path = os.path.join(BASE_DIR, f"{layer}_{name}_frames.tres")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"  OK {layer}_{name}_frames.tres")


def main():
    combos = detect_combos()
    print(f"{len(combos)} combinaison(s) détectée(s) : {combos}")
    for layer, name in combos:
        generate_tres(layer, name)
    print(f"\nTerminé — recharge le projet Godot (Project > Reload).")


if __name__ == "__main__":
    main()
