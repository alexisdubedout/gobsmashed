extends Area2D

const DURATION = 5.0
var niveau = 1
var timer = 0.0
var tick_timer = 0.0
var anim_timer = 0.0
var anim_delay = 0.12
var anim_frame = 0

func _ready():
	var scale_factor = 1.0 + (niveau - 1) * 0.5  # niveau 1=1x, 2=1.5x, 3=2x
	scale = Vector2(scale_factor, scale_factor)

func _process(delta):
	timer += delta
	tick_timer += delta
	anim_timer += delta

	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 9
		$Sprite2D.frame = anim_frame

	if timer >= DURATION:
		queue_free()
		return

	var rayon = 50.0 * (1.0 + (niveau - 1) * 0.5)
	var degats = 5 if niveau < 3 else 10
	var tick_delay = 0.5

	if tick_timer >= tick_delay:
		tick_timer = 0.0
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < rayon:
				enemy.take_damage(degats)
				if niveau >= 2:
					enemy.slowed = true
