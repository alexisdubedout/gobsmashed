extends Area2D

const ROOT_DURATION = 3.0
var triggered = false
var triggered_enemies = []

func _ready():
	# Frame 1 — piège ouvert, en attente
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = 0
	
	# Quand l'animation est finie → disparaît après un délai
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if triggered:
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < 30.0 and enemy not in triggered_enemies:
			triggered = true
			triggered_enemies.append(enemy)
			# Lance l'animation de fermeture
			$AnimatedSprite2D.play("default")
			# Root l'ennemi
			enemy.rooted = true
			await get_tree().create_timer(ROOT_DURATION).timeout
			if is_instance_valid(enemy):
				enemy.rooted = false

func _on_animation_finished():
	# Attend 1 seconde puis disparaît
	await get_tree().create_timer(1.0).timeout
	queue_free()
