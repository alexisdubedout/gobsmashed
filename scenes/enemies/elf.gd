extends BaseEnemy

func setup():
	max_hp = 15
	current_hp = 15
	speed = 160.0
	base_speed = 160.0
	damage = 5
	xp_value = 1
	anim_frames_count = 8

func get_direction() -> Vector2:
	# Zigzague en approchant
	var dir = (player.global_position - global_position).normalized()
	var zigzag = Vector2(sin(Time.get_ticks_msec() * 0.005), 0) * 0.8
	return (dir + zigzag).normalized()
