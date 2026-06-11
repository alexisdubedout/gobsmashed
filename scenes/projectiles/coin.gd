extends Area2D

var speed = 280.0
var damage = 15
var direction = Vector2.ZERO
var is_enemy_projectile = false
var piece_lourde_niveau = 0
var can_pierce = false
var can_bounce = false
var already_hit = []
var hit_radius = 20.0

var anim_timer = 0.0
var anim_delay = 0.08
var anim_frame = 0

func _ready():
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(_delta):
	global_position += direction * speed * _delta

	anim_timer += _delta
	if anim_timer >= anim_delay:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 8
		$Sprite2D.frame = anim_frame

	if is_enemy_projectile:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < hit_radius and player.take_damage(damage):
				queue_free()
	else:
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			if enemy in already_hit:
				continue
			var dist = global_position.distance_to(enemy.global_position)
			if dist < hit_radius:
				enemy.take_damage(damage)
				if piece_lourde_niveau >= 1:
					enemy.slowed = true
				if piece_lourde_niveau >= 3:
					enemy.rooted = true
					await get_tree().create_timer(0.5).timeout
					if is_instance_valid(enemy):
						enemy.rooted = false
				if can_pierce:
					already_hit.append(enemy)
					continue
				if can_bounce and already_hit.is_empty():
					already_hit.append(enemy)
					var others = get_tree().get_nodes_in_group("enemy")
					others = others.filter(func(e): return e != enemy)
					if not others.is_empty():
						var next = others[randi() % others.size()]
						direction = (next.global_position - global_position).normalized()
					return
				queue_free()
				return
