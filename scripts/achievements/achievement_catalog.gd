class_name AchievementCatalog
extends RefCounted

static var cached: Array = []

static func entries() -> Array:
	if not cached.is_empty(): return cached.duplicate(true)
	var data := RuntimeBundle.section("milestones")
	if data.get("schema_version") != 1 or not data.get("entries") is Array: return []
	for entry in data.entries:
		if not entry is Dictionary or entry.get("status") != "local" or entry.get("hidden", true): return []
	cached = data.entries.duplicate(true)
	return cached.duplicate(true)

static func validate() -> bool:
	var used := {}
	if entries().is_empty(): return false
	for entry in entries():
		if not entry.get("id") is String or not entry.id.begins_with("ACH_") or used.has(entry.id): return false
		if not entry.get("title") is Dictionary or not entry.get("description") is Dictionary: return false
		for locale in ["ru", "en"]:
			if not entry.title.get(locale) is String or entry.title[locale].is_empty(): return false
			if not entry.description.get(locale) is String or entry.description[locale].is_empty(): return false
		if entry.get("hidden", true) or entry.get("status") != "local": return false
		used[entry.id] = true
	return true

static func player_visible_entries(_unlocked_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries(): result.append(entry)
	return result
