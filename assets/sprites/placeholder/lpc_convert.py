"""
lpc_convert.py — Convertit une spritesheet LPC vers le format gobsmashed.

USAGE :
  python lpc_convert.py <layer> <nom>

  <layer> : body | clothes | armor_chest | armor_legs | helmet | weapon
  <nom>   : goblin | male | female | guerrier | paladin | elf | mage | ...

  Le script lit  : <layer>_<nom>_lpc.png   (à déposer dans ce dossier)
  Il génère      : <layer>_<nom>_idle_down.png  … (20 fichiers)

EXEMPLES :
  python lpc_convert.py body goblin
  python lpc_convert.py body male
  python lpc_convert.py clothes guerrier
  python lpc_convert.py clothes paladin
  python lpc_convert.py armor_chest paladin

Si les animations sont décalées, ajuste la section CONFIG ci-dessous.
"""
import sys
from PIL import Image
import os

if len(sys.argv) < 3:
    print("Usage : python lpc_convert.py <layer> <nom>")
    print("  ex: python lpc_convert.py body goblin")
    print("      python lpc_convert.py clothes guerrier")
    sys.exit(1)

LAYER = sys.argv[1]
NAME  = sys.argv[2]

# ── CONFIG ────────────────────────────────────────────────────────────────────
LPC_FILE = f"{LAYER}_{NAME}_lpc.png"
FRAME = 64

LPC_DIR_ROWS = {"down": 0, "left": 1, "up": 2, "right": 3}

LPC_ANIM_START = {
    "spellcast":  0,
    "thrust":     4,
    "walk":       8,
    "slash":      12,
    "shoot":      16,
    "hurt":       20,
    "die":        21,
}

HURT_SINGLE_DIR = True
DIE_SINGLE_DIR  = True

TARGET = {
    "idle":   ("walk",  4, [0, 0, 0, 0]),
    "run":    ("walk",  6, list(range(6))),
    "attack": ("slash", 5, list(range(5))),
    "hurt":   ("hurt",  2, [0, 1]),
    "die":    ("die",   6, list(range(6))),
}
# ── FIN CONFIG ────────────────────────────────────────────────────────────────

DIRECTIONS = ["down", "up", "left", "right"]
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def crop_frame(img: Image.Image, row: int, col: int) -> Image.Image:
    x, y = col * FRAME, row * FRAME
    return img.crop((x, y, x + FRAME, y + FRAME))


def main():
    src_path = os.path.join(OUT_DIR, LPC_FILE)
    if not os.path.exists(src_path):
        print(f"ERREUR : '{LPC_FILE}' introuvable dans {OUT_DIR}")
        return

    lpc = Image.open(src_path).convert("RGBA")
    lpc_cols = lpc.width // FRAME
    lpc_rows = lpc.height // FRAME
    print(f"LPC chargé : {lpc.width}×{lpc.height}  ({lpc_cols} cols × {lpc_rows} rows)")

    count = 0
    for anim, (lpc_anim, n_frames, src_indices) in TARGET.items():
        start_row = LPC_ANIM_START[lpc_anim]
        for direction in DIRECTIONS:
            single = (lpc_anim == "hurt" and HURT_SINGLE_DIR) or \
                     (lpc_anim == "die"  and DIE_SINGLE_DIR)
            dir_offset = 0 if single else LPC_DIR_ROWS[direction]
            row = start_row + dir_offset

            sheet = Image.new("RGBA", (FRAME * n_frames, FRAME), (0, 0, 0, 0))
            for i, col in enumerate(src_indices):
                col = min(col, lpc_cols - 1)
                sheet.paste(crop_frame(lpc, row, col), (i * FRAME, 0))

            out = os.path.join(OUT_DIR, f"{LAYER}_{NAME}_{anim}_{direction}.png")
            sheet.save(out)
            print(f"  {LAYER}_{NAME}_{anim}_{direction}.png  {sheet.width}×{sheet.height}")
            count += 1

    print(f"\n{count}/20 fichiers générés.")


if __name__ == "__main__":
    main()
