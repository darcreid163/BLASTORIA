class_name AchievementCatalog
extends RefCounted

# The registry defines future achievements. It does not unlock Steam achievements.
# The client must not enumerate unknown Easter eggs in any collection UI.
const PATH := "res://resources/private/milestones.dat"

static func entries() -> Array:
	var parsed = SealedData.open_bytes(FileAccess.get_file_as_bytes(PATH), "milestones")
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		return []
	return parsed.get("entries", []) if parsed.get("entries") is Array else []

static func validate() -> bool:
	var values := entries()
	if values.size() != 37:
		return false
	var used: Dictionary = {}
	var hidden := 0
	for item in values:
		if not item is Dictionary:
			return false
		var identifier = item.get("id")
		var names = item.get("title")
		var descriptions = item.get("description")
		if not identifier is String or not identifier.begins_with("ACH_") or used.has(identifier):
			return false
		if not names is Dictionary or not descriptions is Dictionary:
			return false
		for locale in ["ru", "en"]:
			if not names.get(locale) is String or names[locale].is_empty():
				return false
			if not descriptions.get(locale) is String or descriptions[locale].is_empty():
				return false
		if not item.get("hidden") is bool or item.get("status") != "planned":
			return false
		if item.hidden:
			if item.get("category") != "secret":
				return false
			hidden += 1
		used[identifier] = true
	return hidden == 4

static func player_visible_entries(unlocked_ids: Array[String]) -> Array[Dictionary]:
	# Hidden achievements never appear as unknown items or placeholders.
	var result: Array[Dictionary] = []
	for item in entries():
		if not item is Dictionary:
			continue
		if item.get("hidden", false) and not unlocked_ids.has(item.get("id", "")):
			continue
		result.append(item)
	return result
