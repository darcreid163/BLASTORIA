class_name Exploration
extends RefCounted

# Last observed terrain; distant changes do not leak through the map.
var known: Dictionary = {}
var total: int = 0
var last_cell := Vector2i(-999, -999)

func setup(board: GridBoard) -> void:
	known.clear()
	total = 0
	last_cell = Vector2i(-999, -999)
	for cell in board.cells:
		if board.kind(cell) not in [GridBoard.Cell.WALL, GridBoard.Cell.WATER]:
			total += 1

func reveal(board: GridBoard, origin: Vector2i, force: bool = false) -> void:
	if origin == last_cell and not force:
		return
	last_cell = origin
	var queue: Array[Vector2i] = [origin]
	var distance := {origin: 0}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		known[cell] = board.kind(cell)
		if distance[cell] >= 4 or (cell != origin and board.kind(cell) != GridBoard.Cell.FLOOR):
			continue
		for d in GridBoard.DIRS:
			var next := cell + d
			if board.cells.has(next) and not distance.has(next):
				distance[next] = distance[cell] + 1
				queue.append(next)

func explored_count() -> int:
	var count := 0
	for cell in known:
		if known[cell] not in [GridBoard.Cell.WALL, GridBoard.Cell.WATER]:
			count += 1
	return count

func percent() -> int:
	return int(100.0 * explored_count() / maxi(1, total))
