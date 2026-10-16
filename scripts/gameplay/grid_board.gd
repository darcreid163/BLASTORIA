class_name GridBoard
extends RefCounted

enum Cell { FLOOR, WALL, CRATE, WATER }
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var width: int
var height: int
var cells: Dictionary = {}
var exit_cell: Vector2i
var landmarks: Array[Vector2i] = []
var guaranteed_drops: Dictionary = {}

func generate(config: GameConfig, rng: RandomNumberGenerator, arena: bool) -> void:
	width = config.width
	height = config.height
	exit_cell = Vector2i(width - 2, height - 2)
	cells.clear()
	landmarks.clear()
	guaranteed_drops.clear()
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
	if config.width >= 41:
		# Authored sector spines plus seeded side alcoves, never a solid crate carpet.
		for x in range(1, width - 1):
			cells[Vector2i(x, 5)] = Cell.FLOOR
			cells[Vector2i(x, height - 6)] = Cell.FLOOR
		for y in range(1, height - 1):
			cells[Vector2i(5, y)] = Cell.FLOOR
			cells[Vector2i(width - 6, y)] = Cell.FLOOR
		landmarks.assign([Vector2i(11, 5), Vector2i(width - 6, 15), Vector2i(11, height - 6)])
		if SecretManager.DEFINITION.valid:
			cells[SecretManager.DEFINITION.niche] = Cell.FLOOR
		cells[Vector2i(3, 2)] = Cell.FLOOR
		cells[Vector2i(2, 3)] = Cell.FLOOR
	if config.full_powerups:
		# One guaranteed instance of every ability; random drops only supplement these.
		var kinds := ["capacity", "range", "speed", "remote", "wall_pass", "bomb_pass", "flame_pass", "invulnerability"]
		for i in range(kinds.size()):
			var p := Vector2i(5 + i * 2, 3)
			cells[p] = Cell.CRATE
			guaranteed_drops[p] = kinds[i]
	cells[exit_cell] = Cell.CRATE if config.hidden_exit else Cell.FLOOR

func kind(p: Vector2i) -> int:
	return cells.get(p, Cell.WALL)

func blast(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	for direction in DIRS:
		for distance in range(1, radius + 1):
			var p := origin + direction * distance
			var cell := kind(p)
			if cell in [Cell.WALL, Cell.WATER]:
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
			if visited.has(next) or kind(next) in [Cell.WALL, Cell.WATER]:
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

# Call only after MapValidationService validates, or from that validator after terrain checks.
func load_map(data: Dictionary) -> void:
	width = int(data.width)
	height = int(data.height)
	exit_cell = Vector2i(-1, -1)
	cells.clear()
	landmarks.clear()
	guaranteed_drops.clear()
	for y in range(height):
		for x in range(width):
			cells[Vector2i(x, y)] = {".": Cell.FLOOR, "#": Cell.WALL, "C": Cell.CRATE, "~": Cell.WATER}[data.rows[y][x]]
