extends Area2D

const SPEED  = 380.0
const DAMAGE = 8

var direction := Vector2.ZERO
var reflechi := false
var reflechi_mult := 1.0
var reflechi_aoe := false
var poison := false

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

	if reflechi:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if global_position.distance_to(enemy.global_position) < 16.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(int(DAMAGE * reflechi_mult))
					if reflechi_aoe:
						for e2 in get_tree().get_nodes_in_group("enemy"):
							if e2 != enemy and global_position.distance_to(e2.global_position) < 90.0:
								e2.take_damage(int(DAMAGE * reflechi_mult * 0.6))
				queue_free()
				return
		return

	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 12.0:
		if player.has_method("tenter_bloquer_projectile") and player.tenter_bloquer_projectile(self, direction):
			return
		if player.take_damage(DAMAGE):
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("enregistrer_dommage"):
				hud.enregistrer_dommage("elf", DAMAGE)
			if poison and player.has_method("appliquer_poison"):
				player.appliquer_poison(2, 3.0)
		queue_free()
