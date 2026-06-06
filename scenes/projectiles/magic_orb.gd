extends Area2D

const SPEED = 250.0
const DAMAGE = 8
var direction = Vector2.ZERO

func _ready():
	$AnimatedSprite2D.play("default")
	await get_tree().create_timer(4.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(_delta):
	global_position += direction * SPEED * _delta
	
	# Blesse le joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 25.0:
			player.take_damage(DAMAGE)
			queue_free()
