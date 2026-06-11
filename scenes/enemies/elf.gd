extends BaseEnemy

func setup():
	max_hp = 20
	current_hp = 20
	speed = 180.0
	base_speed = 180.0
	damage = 6
	xp_value = 3
	anim_frames_count = 8

func get_direction() -> Vector2:
	# Zigzague en approchant
	var dir = (player.global_position - global_position).normalized()
	var zigzag = Vector2(sin(Time.get_ticks_msec() * 0.005), 0) * 0.8
	return (dir + zigzag).normalized()
