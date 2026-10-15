class_name ArcadeLevelRegistry
extends RefCounted

const PATH := "res://resources/arcade/registry.json"

static func catalog() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}

static func load_stage(number: int) -> Dictionary:
	var registry := catalog()
	if number < 1 or number > 100 or registry.is_empty():
		return {}
	var entry: Dictionary = registry.levels[number - 1]
	if entry.status != "playable":
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
	if not MapValidationService.validate(value).is_empty():
		return {}
	return value

static func playable_count() -> int:
	var count := 0
	for entry in catalog().get("levels", []):
		if entry.status == "playable":
			count += 1
	return count
