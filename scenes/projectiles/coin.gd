extends Area2D

const SPEED = 300.0
const DAMAGE = 10
var direction = Vector2.ZERO
var is_enemy_projectile = false

func _ready():
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		queue_free()

var anim_timer = 0.0
var anim_delay = 0.08
var anim_frame = 0

func _physics_process(_delta):
	global_position += direction * SPEED * _delta
	
	# Animation rotation pièce
	anim_timer += _delta
	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 8
		$Sprite2D.frame = anim_frame
	
	if is_enemy_projectile:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < 20.0:
				player.take_damage(DAMAGE)
				queue_free()
	else:
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 20.0:
				enemy.take_damage(DAMAGE)
				queue_free()
				return
