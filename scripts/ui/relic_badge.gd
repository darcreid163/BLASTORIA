class_name RelicBadge
extends Control

var angle: float = -0.7

func _process(delta: float) -> void:
	angle += delta * 0.35
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, 25, 0, TAU, 40, Color("89ebed"), 2, true)
	for i in range(4):
		var d := Vector2.from_angle(i * PI * 0.5)
		draw_line(center + d * 20, center + d * 29, Color("89ebed"), 2, true)
	var north := Vector2.from_angle(angle)
	var side := north.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + north * 22, center + side * 5, center - north * 12, center - side * 5]), Color("ffe395"))
