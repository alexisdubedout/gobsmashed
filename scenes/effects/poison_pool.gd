extends Area2D

const DAMAGE = 5
const DURATION = 5.0
var timer = 0.0
var tick_timer = 0.0
var anim_timer = 0.0
var anim_delay = 0.12
var anim_frame = 0

func _ready():
	pass

func _process(delta):
	timer += delta
	tick_timer += delta
	anim_timer += delta
	
	# Animation
	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 9
		$Sprite2D.frame = anim_frame
	
	if timer >= DURATION:
		queue_free()
		return
	
	if tick_timer >= 0.5:
		tick_timer = 0.0
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 50.0:
				enemy.take_damage(DAMAGE)
