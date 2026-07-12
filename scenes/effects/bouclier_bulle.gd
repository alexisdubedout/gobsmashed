extends Node2D

# Bulle dorée autour du joueur (bouclier magique)
# Pulse quand prête, fading quand en recharge

const RAYON   = 36.0
const OFFSET  = Vector2(0, -24)

var _t: float = 0.0

func _ready():
	z_index = 1

func _process(delta):
	var player = get_parent()
	if not is_instance_valid(player):
		return

	_t += delta

	var cd     = player.get("bouclier_cd")     if player.get("bouclier_cd")     != null else 0.0
	var cd_dur = player.get("bouclier_cd_dur") if player.get("bouclier_cd_dur") != null else 8.0
	var ratio  = clamp(cd / cd_dur, 0.0, 1.0)

	if ratio <= 0.05:
		# Prêt : pulse dorée
		modulate.a = 0.65 + sin(_t * 3.5) * 0.25
	else:
		# En recharge : fondu progressif
		modulate.a = lerp(0.55, 0.12, ratio)

	queue_redraw()

func _draw():
	draw_circle(OFFSET, RAYON,       Color(1.0, 0.85, 0.2,  0.12))
	draw_arc(OFFSET,    RAYON,       0.0, TAU, 48, Color(1.0, 0.85, 0.15, 0.90), 2.5)
	draw_arc(OFFSET,    RAYON - 4.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.5,  0.35), 1.5)
