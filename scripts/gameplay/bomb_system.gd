class_name BombSystem
extends RefCounted

var bombs: Dictionary = {} # Stable numeric ID -> logical bomb; no scene references.
var fire: Dictionary = {} # Cell -> last hazardous simulation tick (exclusive).
var fire_owners: Dictionary = {} # Cell -> {owner ID: exclusive expiry tick}.
var next_id: int = 1

func at(cell: Vector2i) -> int:
	for id in bombs:
		if bombs[id].cell == cell:
			return id
	return -1

func place(cell: Vector2i, owner: int, radius: int, capacity: int, now: int, fuse: int) -> bool:
	if at(cell) != -1 or fire.has(cell):
		return false
	var owned := 0
	for b in bombs.values():
		if b.owner == owner:
			owned += 1
	if owned >= capacity:
		return false
	bombs[next_id] = {"id": next_id, "cell": cell, "owner": owner, "radius": radius, "due": now + fuse}
	next_id += 1
	return true

func advance(now: int, board: GridBoard, fire_duration: int) -> Array[Vector2i]:
	for cell in fire.keys():
		if fire[cell] <= now:
			fire.erase(cell)
	for cell in fire_owners.keys():
		for owner in fire_owners[cell].keys():
			if fire_owners[cell][owner] <= now:
				fire_owners[cell].erase(owner)
		if fire_owners[cell].is_empty():
			fire_owners.erase(cell)
	var queue: Array[int] = []
	for id in bombs:
		if bombs[id].due <= now or fire.has(bombs[id].cell):
			queue.append(id)
	queue.sort()
	var processed: Dictionary = {}
	var destroyed: Array[Vector2i] = []
	var index := 0
	# Read one terrain snapshot for the entire tick. A crate stops every same-tick ray.
	while index < queue.size():
		var id := queue[index]
		index += 1
		if processed.has(id) or not bombs.has(id):
			continue
		processed[id] = true
		var b: Dictionary = bombs[id]
		bombs.erase(id)
		for cell in board.blast(b.cell, b.radius):
			fire[cell] = now + fire_duration
			if not fire_owners.has(cell):
				fire_owners[cell] = {}
			fire_owners[cell][b.owner] = now + fire_duration
			if board.kind(cell) == GridBoard.Cell.CRATE and not destroyed.has(cell):
				destroyed.append(cell)
			var chained := at(cell)
			if chained != -1 and not processed.has(chained):
				queue.append(chained)
	for cell in destroyed:
		board.cells[cell] = GridBoard.Cell.FLOOR
	return destroyed

func danger(board: GridBoard) -> Dictionary:
	var result := fire.duplicate()
	for b in bombs.values():
		for cell in board.blast(b.cell, b.radius):
			result[cell] = true
	return result

func credited(cell: Vector2i, owner: int) -> bool:
	return fire_owners.has(cell) and fire_owners[cell].has(owner)
