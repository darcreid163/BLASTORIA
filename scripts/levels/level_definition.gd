class_name LevelDefinition
extends Resource

@export var rows: Array[String] = []
@export var spawn: Vector2i = Vector2i(1, 3)
@export var exit_cell: Vector2i = Vector2i(13, 7)
@export var checkpoint: Vector2i = Vector2i(3, 3)
@export var lesson_crate: Vector2i = Vector2i(5, 3)

func valid() -> bool:
	if rows.size() != 11:
		return false
	for y in range(rows.size()):
		if rows[y].length() != 15:
			return false
		for x in range(15):
			var cell := rows[y][x]
			if not cell in ["#", ".", "C"]:
				return false
			if (x == 0 or y == 0 or x == 14 or y == 10) and cell != "#":
				return false
	for point in [spawn, exit_cell, checkpoint, lesson_crate]:
		if point.x < 1 or point.x > 13 or point.y < 1 or point.y > 9:
			return false
	return rows[spawn.y][spawn.x] == "." and rows[exit_cell.y][exit_cell.x] == "." and rows[checkpoint.y][checkpoint.x] == "." and rows[lesson_crate.y][lesson_crate.x] == "C"
