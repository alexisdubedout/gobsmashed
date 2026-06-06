extends BaseEnemy

func setup():
	# Stats du paladin — lent mais beaucoup de PV
	max_hp = 50
	current_hp = 50
	speed = 60.0
	base_speed = 60.0
	damage = 15
	xp_value = 2
	anim_frames_count = 8

func get_direction() -> Vector2:
	# Fonceur — fonce droit sur le joueur, ignore tout
	return (player.global_position - global_position).normalized()
