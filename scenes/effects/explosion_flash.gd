extends Node2D

var radius: float = 60.0

func _ready():
	queue_redraw()
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.30).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(queue_free)

func _draw():
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.1, 0.45))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 2.5)
