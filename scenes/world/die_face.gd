extends Control

var face: int = 1:
	set(v):
		face = v
		queue_redraw()

func _draw():
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#f4ecd8"))
	draw_rect(Rect2(Vector2(2, 2), s - Vector2(4, 4)), Color("#2a2418"), false, 4.0)
	var pip_radius := s.x * 0.085
	var pip_color := Color("#241f14")
	for p in _pip_positions(face):
		draw_circle(Vector2(p.x * s.x, p.y * s.y), pip_radius, pip_color)

func _pip_positions(f: int) -> Array:
	match f:
		1: return [Vector2(0.5, 0.5)]
		2: return [Vector2(0.27, 0.27), Vector2(0.73, 0.73)]
		3: return [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)]
		4: return [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
		5: return [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
		6: return [Vector2(0.27, 0.22), Vector2(0.73, 0.22), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.78), Vector2(0.73, 0.78)]
		_: return []
