extends Node2D

# 3 boucliers qui orbitent autour du joueur
# Opacité pleine = prêt, fadé = en recharge

const NB       = 3
const RAYON    = 38.0
const VITESSE  = 2.2
const OFFSET   = Vector2(0, -14)

var _angle: float = 0.0
var _icones: Array = []

func _ready():
	z_index = 2
	for i in NB:
		var lbl = Label.new()
		lbl.text = "🛡️"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.position = Vector2.ZERO
		add_child(lbl)
		_icones.append(lbl)

func _process(delta):
	var player = get_parent()
	if not is_instance_valid(player):
		return

	_angle += delta * VITESSE

	var cd     = player.get("bouclier_cd")     if player.get("bouclier_cd")     != null else 0.0
	var cd_dur = player.get("bouclier_cd_dur") if player.get("bouclier_cd_dur") != null else 8.0
	var ratio  = clamp(cd / cd_dur, 0.0, 1.0)
	modulate.a = lerp(1.0, 0.25, ratio)

	for i in NB:
		var a = _angle + i * TAU / NB
		_icones[i].position = OFFSET + Vector2(cos(a), sin(a)) * RAYON - Vector2(7, 7)
