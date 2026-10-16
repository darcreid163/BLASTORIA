class_name GuideBadge
extends Control
# Original vector silhouettes echo the existing item/monster meshes. No gameplay authority.
var kind: String = "capacity"
var bonus: bool = true
const COLORS := {"capacity":"7bb5c9","range":"df9b69","speed":"b4a2cb","remote":"b5c6a8","wall_pass":"8cb59b","bomb_pass":"b1bbce","flame_pass":"b78683","invulnerability":"dfc88f","patrol":"cd7b72","chaser":"8e81b1","bomber":"527e98","warden":"b4bdd4"}
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := Vector2(39,39)
	var tint := Color(COLORS.get(kind,"ffffff"))
	draw_circle(center,34,Color("243d46"))
	if not bonus:
		if kind=="warden":draw_colored_polygon(PackedVector2Array([Vector2(39,12),Vector2(62,39),Vector2(39,64),Vector2(16,39)]),tint)
		else:draw_circle(center,20,tint)
		if kind=="patrol":
			for x in [22,56]:draw_line(Vector2(x,30),Vector2(x,14),tint,8)
		if kind=="chaser":
			for x in [27,51]:draw_line(Vector2(x,29),Vector2(x,10),tint,3);draw_circle(Vector2(x,10),5,tint)
		if kind=="bomber":draw_rect(Rect2(46,8,10,24),tint)
		for x in [31,47]:draw_circle(Vector2(x,36),6,Color("eee6d3"));draw_circle(Vector2(x,37),2,Color("172e3a"))
		return
	match kind:
		"capacity":
			for x in [26,52]:draw_circle(Vector2(x,42),12,tint);draw_line(Vector2(x,28),Vector2(x+4,20),Color("ffe0a0"),3)
		"range":
			draw_line(Vector2(16,39),Vector2(62,39),tint,10);draw_line(Vector2(39,16),Vector2(39,62),tint,10)
		"speed":
			for x in [23,45]:draw_rect(Rect2(x,23,12,29),tint);draw_rect(Rect2(x,44,20,12),tint)
		"remote":
			draw_rect(Rect2(23,29,32,28),tint);draw_line(Vector2(48,29),Vector2(48,12),tint,3);draw_circle(Vector2(34,39),5,Color("e98970"))
		"wall_pass":
			draw_rect(Rect2(17,21,12,41),tint);draw_rect(Rect2(49,21,12,41),tint);draw_rect(Rect2(17,17,44,12),tint)
		"bomb_pass":
			draw_circle(center,20,tint);draw_line(Vector2(14,39),Vector2(64,39),Color("f5dfa9"),5)
		"flame_pass":
			draw_colored_polygon(PackedVector2Array([Vector2(39,13),Vector2(60,28),Vector2(53,52),Vector2(39,65),Vector2(25,52),Vector2(18,28)]),tint)
			draw_line(Vector2(39,24),Vector2(39,52),Color("f5dfa9"),5)
		"invulnerability":
			draw_circle(center,21,tint);draw_circle(center,27,tint,false,2);draw_line(Vector2(39,24),Vector2(39,54),Color("fff0c8"),5)
