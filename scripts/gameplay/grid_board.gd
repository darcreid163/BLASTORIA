class_name GridBoard
extends RefCounted

enum Cell { FLOOR, WALL, CRATE }
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var width: int
var height: int
var cells: Dictionary = {}
var exit_cell: Vector2i

func generate(config: GameConfig, rng: RandomNumberGenerator, arena: bool) -> void:
	width = config.width
	height = config.height
	exit_cell = Vector2i(width - 2, height - 2)
	cells.clear()
	var starts: Array[Vector2i] = [Vector2i(1, 1), exit_cell, Vector2i(width - 2, 1), Vector2i(1, height - 2), Vector2i(width - 4, height - 4)]
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			var wall := x == 0 or y == 0 or x == width - 1 or y == height - 1 or (x % 2 == 0 and y % 2 == 0)
			var safe := false
			for start in starts:
				if absi(p.x - start.x) + absi(p.y - start.y) <= 1:
					safe = true
			cells[p] = Cell.WALL if wall else Cell.FLOOR
			if not wall and not safe and rng.randf() < config.crate_density:
				cells[p] = Cell.CRATE
	# Rotational symmetry gives both arena players equivalent starting geometry.
	if arena:
		for y in range(height):
			for x in range(width):
				var p := Vector2i(x, y)
				var mirror := Vector2i(width - 1 - x, height - 1 - y)
				if y * width + x < mirror.y * width + mirror.x:
					cells[mirror] = cells[p]
	cells[exit_cell] = Cell.FLOOR

func kind(p: Vector2i) -> int:
	return cells.get(p, Cell.WALL)

func blast(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	for direction in DIRS:
		for distance in range(1, radius + 1):
			var p := origin + direction * distance
			var cell := kind(p)
			if cell == Cell.WALL:
				break
			result.append(p)
			if cell == Cell.CRATE:
				break
	return result

func reachable(start: Vector2i, crates_breakable: bool = false) -> Dictionary:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var p := queue[index]
		index += 1
		for d in DIRS:
			var next := p + d
			if visited.has(next) or kind(next) == Cell.WALL:
				continue
			if kind(next) == Cell.CRATE and not crates_breakable:
				continue
			visited[next] = true
			queue.append(next)
	return visited

func load_authored(definition: LevelDefinition) -> bool:
	if not definition.valid():
		return false
	width = 15
	height = 11
	exit_cell = definition.exit_cell
	cells.clear()
	for y in range(height):
		for x in range(width):
			cells[Vector2i(x, y)] = {"#": Cell.WALL, ".": Cell.FLOOR, "C": Cell.CRATE}[definition.rows[y][x]]
	return reachable(definition.spawn, true).has(exit_cell)
