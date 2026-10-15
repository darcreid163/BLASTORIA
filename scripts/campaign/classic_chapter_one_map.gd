class_name ClassicChapterOneMap
extends RefCounted

const PATH := "res://resources/campaign/chapter_one_maps.json"
const COUNT := 10

static func maps() -> Array:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary or value.get("schema_version") != 1:
		return []
	var entries = value.get("maps", [])
	return entries if entries is Array and entries.size() == COUNT else []

static func stage(number: int) -> Dictionary:
	if number < 1 or number > COUNT:
		return {}
	var entries := maps()
	if entries.is_empty():
		return {}
	var item = entries[number - 1]
	if not item is Dictionary or int(item.get("stage", -1)) != number:
		return {}
	return item

static func point(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))

static func apply(board: GridBoard, number: int) -> bool:
	var data := stage(number)
	if data.is_empty() or not valid_map(data):
		return false
	board.width = int(data.width)
	board.height = int(data.height)
	board.exit_cell = point(data.exit)
	board.cells.clear()
	board.landmarks.clear()
	board.guaranteed_drops.clear()
	var types := {"#": GridBoard.Cell.WALL, ".": GridBoard.Cell.FLOOR, "C": GridBoard.Cell.CRATE}
	for y in range(board.height):
		for x in range(board.width):
			board.cells[Vector2i(x, y)] = types[data.rows[y][x]]
	return true

static func valid_map(data: Dictionary) -> bool:
	var width := int(data.get("width", 0))
	var height := int(data.get("height", 0))
	if width < 15 or width > 81 or height < 11 or height > 61:
		return false
	var rows = data.get("rows", [])
	if not rows is Array or rows.size() != height:
		return false
	for y in range(height):
		if not rows[y] is String or rows[y].length() != width:
			return false
		for x in range(width):
			if rows[y][x] not in ["#", ".", "C"]:
				return false
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				if rows[y][x] != "#":
					return false
	for key in ["prize", "exit"]:
		var raw = data.get(key, [])
		if not raw is Array or raw.size() != 2:
			return false
		var p := point(raw)
		if p.x < 1 or p.x >= width - 1 or p.y < 1 or p.y >= height - 1:
			return false
		if rows[p.y][p.x] != "C":
			return false
	if data.prize == data.exit or rows[1][1] != ".":
		return false
	var enemies = data.get("enemy_spawns", [])
	if not enemies is Array or enemies.is_empty():
		return false
	for raw in enemies:
		if not raw is Array or raw.size() != 2:
			return false
		var p := point(raw)
		if p.x < 1 or p.y < 1 or p.x >= width - 1 or p.y >= height - 1:
			return false
		if rows[p.y][p.x] != ".":
			return false
	var visited := {Vector2i(1, 1): true}
	var queue: Array[Vector2i] = [Vector2i(1, 1)]
	var index := 0
	while index < queue.size():
		var p := queue[index]
		index += 1
		for d in GridBoard.DIRS:
			var next := p + d
			if visited.has(next) or next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if rows[next.y][next.x] == "#":
				continue
			visited[next] = true
			queue.append(next)
	for y in range(height):
		for x in range(width):
			if rows[y][x] != "#" and not visited.has(Vector2i(x, y)):
				return false
	return true

static func validate() -> bool:
	var entries := maps()
	if entries.size() != COUNT:
		return false
	var fingerprints: Dictionary = {}
	var previous_area := 0
	for i in range(COUNT):
		var data = entries[i]
		if not data is Dictionary or int(data.get("stage", -1)) != i + 1 or not valid_map(data):
			return false
		var area := int(data.width) * int(data.height)
		if area < previous_area:
			return false
		previous_area = area
		var signature := "\n".join(PackedStringArray(data.rows))
		if fingerprints.has(signature):
			return false
		fingerprints[signature] = true
	return true
