from PIL import Image, ImageDraw
import os

FRAME_SIZE = 64
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

BEIGE = (232, 201, 154, 255)
BLUE = (91, 141, 217, 255)
DARK_BLUE = (58, 95, 160, 255)
RED = (224, 80, 80, 255)
TRANSPARENT = (0, 0, 0, 0)

DIRECTIONS = ["down", "up", "left", "right"]

ANIMATIONS = {
    "idle": 4,
    "run": 6,
    "attack": 5,
    "hurt": 2,
    "die": 6,
}


def flip_x(x, w=0):
    """Mirror x coordinate around canvas center (for left direction)."""
    return FRAME_SIZE - x - w


def draw_rect(draw, x, y, w, h, color):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def draw_circle(draw, cx, cy, r, color):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def indicator_offset(direction, radius=8, dot_r=3):
    """Return (dx, dy) offset of direction dot center from head center."""
    offsets = {
        "down":  (0,  radius + dot_r),
        "up":    (0, -(radius + dot_r)),
        "left":  (-(radius + dot_r), 0),
        "right": ( radius + dot_r, 0),
    }
    return offsets[direction]


def draw_frame(direction, anim, frame_idx):
    img = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    is_left = direction == "left"
    is_up = direction == "up"
    is_right = direction == "right"
    is_down = direction == "down"

    # ── Base positions ──────────────────────────────────────────
    head_cx, head_cy = 32, 16
    head_r = 8

    torso_x, torso_y = 24, 24   # top-left of 16×20 centered at (32,34)
    torso_w, torso_h = 16, 20

    arm_l_x, arm_l_y = 22, 26   # 6×14
    arm_r_x, arm_r_y = 36, 26
    arm_w, arm_h = 6, 14

    leg_l_x, leg_l_y = 25, 48   # 7×14
    leg_r_x, leg_r_y = 33, 48
    leg_w, leg_h = 7, 14

    torso_color = BLUE

    # ── Animation deltas ────────────────────────────────────────
    body_dx = 0   # global x offset (hurt)
    torso_dy = 0
    arm_l_dy = 0
    arm_r_dy = 0
    leg_l_dy = 0
    leg_r_dy = 0
    leg_l_dx = 0
    leg_r_dx = 0
    arm_r_extend = 0   # attack: extend arm toward direction
    torso_squash = torso_h  # die

    if anim == "idle":
        torso_dy = [0, -1, 0, 1][frame_idx]

    elif anim == "run":
        leg_offsets_l = [-6, -3, 0, 6, 3, 0]
        leg_offsets_r = [6, 3, 0, -6, -3, 0]
        arm_offsets_l = [4, 2, 0, -4, -2, 0]
        arm_offsets_r = [-4, -2, 0, 4, 2, 0]
        leg_l_dy = leg_offsets_l[frame_idx]
        leg_r_dy = leg_offsets_r[frame_idx]
        arm_l_dy = arm_offsets_l[frame_idx]
        arm_r_dy = arm_offsets_r[frame_idx]

    elif anim == "attack":
        extend_seq = [0, 4, 8, 4, 0]
        torso_lean = [0, 1, 2, 1, 0]
        arm_r_extend = extend_seq[frame_idx]
        torso_dy = torso_lean[frame_idx]

    elif anim == "hurt":
        knockback = [-4, 0]
        raw_dx = knockback[frame_idx]
        # Flip knockback direction for left-facing
        body_dx = raw_dx if not is_left else -raw_dx
        if frame_idx == 0:
            torso_color = RED

    elif anim == "die":
        squash_seq = [20, 16, 12, 8, 4, 2]
        spread_seq = [0, 2, 4, 6, 8, 10]
        sink_seq = [0, 2, 4, 6, 8, 9]
        torso_squash = squash_seq[frame_idx]
        leg_l_dx = -spread_seq[frame_idx]
        leg_r_dx = spread_seq[frame_idx]
        torso_dy = sink_seq[frame_idx]
        leg_l_dy = sink_seq[frame_idx]
        leg_r_dy = sink_seq[frame_idx]

    # ── Up direction: arms slightly raised ─────────────────────
    if is_up:
        arm_l_dy -= 4
        arm_r_dy -= 4

    # ── Apply attack extension toward direction ─────────────────
    attack_arm_dx = 0
    attack_arm_dy = 0
    if anim == "attack":
        if is_right:
            attack_arm_dx = arm_r_extend
        elif is_left:
            attack_arm_dx = -arm_r_extend
        elif is_down:
            attack_arm_dy = arm_r_extend
        elif is_up:
            attack_arm_dy = -arm_r_extend

    # ── Horizontal flip for LEFT direction ──────────────────────
    def maybe_flip(x, w):
        if is_left:
            return flip_x(x, w)
        return x

    # ── Draw order: legs → torso → arms → head → dot ───────────
    # Legs
    ll_x = maybe_flip(leg_l_x + leg_l_dx, leg_w) + body_dx
    ll_y = leg_l_y + leg_l_dy
    lr_x = maybe_flip(leg_r_x + leg_r_dx, leg_w) + body_dx
    lr_y = leg_r_y + leg_r_dy
    draw_rect(draw, ll_x, ll_y, leg_w, leg_h, DARK_BLUE)
    draw_rect(draw, lr_x, lr_y, leg_w, leg_h, DARK_BLUE)

    # Torso
    tx = maybe_flip(torso_x, torso_w) + body_dx
    ty = torso_y + torso_dy
    draw_rect(draw, tx, ty, torso_w, torso_squash, torso_color)

    # Arms
    al_x = maybe_flip(arm_l_x, arm_w) + body_dx
    al_y = arm_l_y + arm_l_dy
    ar_x = maybe_flip(arm_r_x, arm_w) + body_dx + attack_arm_dx
    ar_y = arm_r_y + arm_r_dy + attack_arm_dy
    draw_rect(draw, al_x, al_y, arm_w, arm_h, BLUE)
    draw_rect(draw, ar_x, ar_y, arm_w, arm_h, BLUE)

    # Head
    hx = head_cx + body_dx
    hy = head_cy
    draw_circle(draw, hx, hy, head_r, BEIGE)

    # Direction indicator
    ddx, ddy = indicator_offset(direction if not is_left else "right", head_r, 3)
    if is_left:
        ddx = -ddx  # dot on left side for left-facing
    draw_circle(draw, hx + ddx, hy + ddy, 3, RED)

    return img


def generate_spritesheet(anim, direction, n_frames):
    frames = [draw_frame(direction, anim, i) for i in range(n_frames)]
    sheet = Image.new("RGBA", (FRAME_SIZE * n_frames, FRAME_SIZE), TRANSPARENT)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * FRAME_SIZE, 0))
    return sheet


def main():
    results = []
    for anim, n_frames in ANIMATIONS.items():
        for direction in DIRECTIONS:
            filename = f"body_{anim}_{direction}.png"
            path = os.path.join(OUT_DIR, filename)
            sheet = generate_spritesheet(anim, direction, n_frames)
            sheet.save(path)
            w, h = sheet.size
            results.append((filename, w, h))
            print(f"  {filename:35s} {w}×{h}")

    print(f"\n{len(results)} fichiers générés dans {OUT_DIR}")
    errors = [r for r in results if r[2] != FRAME_SIZE]
    if errors:
        print("ERREUR hauteur incorrecte :", errors)
    wrong_w = [r for r in results if r[1] != FRAME_SIZE * ANIMATIONS[r[0].split("_")[1]]]
    if wrong_w:
        print("ERREUR largeur incorrecte :", wrong_w)
    if not errors and not wrong_w:
        print("Toutes les dimensions sont correctes.")


if __name__ == "__main__":
    main()
