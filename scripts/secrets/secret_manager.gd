class_name SecretManager
extends RefCounted

static var COMPASS: SecretDefinition = SecretDefinition.active()
var enabled: bool = false
var map_used: bool = false
var damaged: bool = false
var failed_order: bool = false
var visited: Array[int] = []
var revealed: bool = false
var awarded: bool = false

func visit(index: int) -> void:
	if not COMPASS.valid or not enabled or visited.has(index) or failed_order:
		return
	if visited.size() >= COMPASS.landmark_order.size() or index != COMPASS.landmark_order[visited.size()]:
		failed_order = true
		return
	visited.append(index)

func finish(explored: int, total: int) -> bool:
	if not COMPASS.valid or not enabled or revealed or awarded or map_used or damaged or failed_order or total <= 0:
		return false
	if explored * 100 < total * COMPASS.explored_percent or visited != COMPASS.landmark_order:
		return false
	revealed = true
	return true

func collect(cell: Vector2i) -> int:
	if not COMPASS.valid or not enabled or not revealed or awarded or cell != COMPASS.niche:
		return 0
	awarded = true
	return COMPASS.reward
