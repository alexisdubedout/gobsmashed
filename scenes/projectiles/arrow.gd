extends Area2D

const SPEED  = 380.0
const DAMAGE = 8

var direction := Vector2.ZERO

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 12.0:
		player.take_damage(DAMAGE)
		queue_free()
