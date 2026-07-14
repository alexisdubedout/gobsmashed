extends Area2D

const SPEED = 270.0
const DAMAGE = 12

var enemy_type_name := "mage"
var direction = Vector2.ZERO
var reflechi := false
var reflechi_mult := 1.0
var reflechi_aoe := false

func _ready():
	$AnimatedSprite2D.play("default")
	await get_tree().create_timer(4.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(_delta):
	global_position += direction * SPEED * _delta

	if reflechi:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if global_position.distance_to(enemy.global_position) < 28.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(int(DAMAGE * reflechi_mult))
					if reflechi_aoe:
						for e2 in get_tree().get_nodes_in_group("enemy"):
							if e2 != enemy and global_position.distance_to(e2.global_position) < 90.0:
								e2.take_damage(int(DAMAGE * reflechi_mult * 0.6))
				queue_free()
				return
		return

	# Blesse le joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 25.0:
			if player.has_method("tenter_bloquer_projectile") and player.tenter_bloquer_projectile(self, direction):
				return
			player.take_damage_from(DAMAGE, self)
			queue_free()
