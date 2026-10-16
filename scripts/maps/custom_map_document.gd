class_name CustomMapDocument
extends RefCounted

var data: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func checkpoint() -> void:
	undo_stack.append(data.duplicate(true))
	if undo_stack.size() > 50:
		undo_stack.pop_front()
	redo_stack.clear()

func replace(value: Dictionary) -> void:
	if not data.is_empty():
		checkpoint()
	data = value.duplicate(true)

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(data.duplicate(true))
	data = undo_stack.pop_back()

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(data.duplicate(true))
	data = redo_stack.pop_back()

func paint(from: Vector2i, to: Vector2i, tool: String, properties: Dictionary) -> void:
	if data.is_empty():
		return
	checkpoint()
	for y in range(maxi(1, mini(from.y, to.y)), mini(int(data.height) - 2, maxi(from.y, to.y)) + 1):
		for x in range(maxi(1, mini(from.x, to.x)), mini(int(data.width) - 2, maxi(from.x, to.x)) + 1):
			var point := [x, y]
			for collection in [data.enemies, data.powerups]:
				for i in range(collection.size() - 1, -1, -1):
					if MapValidationService.cell(collection[i].cell) == Vector2i(x, y):
						collection.remove_at(i)
			data.rows[y][x] = {"floor": ".", "wall": "#", "crate": "C", "water": "~"}.get(tool, ".")
			if tool.begins_with("spawn"):
				var index := 0 if tool == "spawn1" else 1
				if index < data.spawns.size():
					data.spawns[index] = point
			elif tool in MapValidationService.ENEMIES:
				data.enemies.append({"cell": point, "kind": tool, "step": properties.get("step", 36), "required": properties.get("required", true)})
			elif tool in MapValidationService.POWERS:
				var hidden: bool = properties.get("hidden", false)
				data.rows[y][x] = "C" if hidden else "."
				data.powerups.append({"cell": point, "kind": tool, "hidden": hidden})

func sample(at: Vector2i) -> String:
	for enemy in data.enemies:
		if MapValidationService.cell(enemy.cell) == at:
			return enemy.kind
	for power in data.powerups:
		if MapValidationService.cell(power.cell) == at:
			return power.kind
	return {".": "floor", "#": "wall", "C": "crate", "~": "water"}[data.rows[at.y][at.x]]
