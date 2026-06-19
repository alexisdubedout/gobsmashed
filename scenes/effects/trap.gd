extends Area2D

const DAMAGE = 30

var triggered := false

func _ready():
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.animation_finished.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if triggered or not body.is_in_group("enemy"):
		return
	triggered = true
	$CollisionShape2D.set_deferred("disabled", true)
	body.take_damage(DAMAGE)
	$AnimatedSprite2D.play("default")
