extends Area2D

var duration: float = 5.0
var ultime_actif: bool = false
var niveau = 1
var timer = 0.0
var tick_timer = 0.0
var anim_timer = 0.0
var anim_delay = 0.12
var anim_frame = 0
var slowed_by_me: Array = []

func _ready():
	z_index = 0
	add_to_group("poison_pool")
	if ultime_actif:
		duration = 20.0
		scale = Vector2(1.8, 1.8) * (1.0 + (niveau - 1) * 0.5)
	else:
		var scale_factor = 1.0 + (niveau - 1) * 0.5
		scale = Vector2(scale_factor, scale_factor)

func _process(delta):
	timer += delta
	tick_timer += delta
	anim_timer += delta

	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 9
		$Sprite2D.frame = anim_frame

	if timer >= duration:
		for enemy in slowed_by_me:
			if is_instance_valid(enemy): enemy.slowed = false
		queue_free()
		return

	var rayon = 50.0 * (1.0 + (niveau - 1) * 0.5)
	var degats = 5 if niveau < 3 else 10
	var tick_delay = 0.5

	if tick_timer >= tick_delay:
		tick_timer = 0.0
		var enemies_in_range: Array = []
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < rayon:
				enemy.take_damage(degats)
				if niveau >= 2:
					enemy.slowed = true
					if not enemy in slowed_by_me:
						slowed_by_me.append(enemy)
				enemies_in_range.append(enemy)
		if niveau >= 2:
			for enemy in slowed_by_me.duplicate():
				if not is_instance_valid(enemy) or not enemy in enemies_in_range:
					if is_instance_valid(enemy): enemy.slowed = false
					slowed_by_me.erase(enemy)

