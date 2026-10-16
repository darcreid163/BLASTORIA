class_name AchievementManager
extends RefCounted

signal unlocked(public_title: String)
signal save_failed
var path: String = "user://milestones.progress"
var award_enabled: bool = not OS.is_debug_build()
var writable: bool = true
var recovered: bool = false
var dirty: bool = false
var progress: Dictionary = fresh()
var last_error: Error = OK

static func fresh() -> Dictionary:
	return {"version": 1, "stats": {"kills": 0, "crates": 0, "best_chain": 0, "best_powers": 0, "arena_matches": 0, "arena_wins": 0}, "earned": {}, "pending": [], "owned": [], "imported": [], "attempts": {}}

func read_progress() -> void:
	for source in [path, path + ".bak"]:
		var file := FileAccess.open(source, FileAccess.READ)
		if file == null or file.get_length() > 65536: continue
		var data := SealedData.open_bytes(file.get_buffer(file.get_length()), "achievement_progress")
		file.close()
		if SaveManager.valid_int(data.get("version"), 2, 1000000):
			writable = false
			return
		if not valid(data): continue
		progress = MapValidationService.normalize_numbers(data)
		recovered = source.ends_with(".bak")
		return

static func valid(data: Dictionary) -> bool:
	if not SaveManager.valid_int(data.get("version"), 1, 1) or not data.get("stats") is Dictionary or not data.get("earned") is Dictionary or not data.get("attempts") is Dictionary: return false
	for key in fresh().stats:
		if not SaveManager.valid_int(data.stats.get(key), 0, 1000000000): return false
	for key in ["pending", "owned", "imported"]:
		if not data.get(key) is Array or data[key].size() > 100: return false
		for value in data[key]:
			if not value is String or value.length() > 80: return false
	if data.earned.size() > 100 or data.attempts.size() > 64: return false
	for id in data.earned:
		if not id is String or id.length() > 80 or not SaveManager.valid_int(data.earned[id], 0, 10000000000): return false
	for id in data.attempts:
		var entry = data.attempts[id]
		if not id is String or id.length() != 32 or not entry is Dictionary or not entry.get("done") is bool: return false
		for key in ["kills", "crates"]:
			if not SaveManager.valid_int(entry.get(key), 0, 1000000000): return false
	return true

func enabled() -> bool:
	return award_enabled and writable and AchievementCatalog.validate()

func grant(id: String) -> void:
	if progress.earned.has(id) or not enabled(): return
	for item in AchievementCatalog.entries():
		if item.id == id and item.status == "local" and not item.hidden:
			progress.earned[id] = int(Time.get_unix_time_from_system())
			if not progress.pending.has(id): progress.pending.append(id)
			dirty = true
			var locale := TranslationServer.get_locale().left(2)
			unlocked.emit(str(item.title.get(locale, item.title.en)))
			return

func observe(state: GameState) -> void:
	if not enabled() or state.mode in ["custom", "custom_arena"] or state.attempt_id.is_empty(): return
	if not progress.attempts.has(state.attempt_id):
		if progress.attempts.size() >= 64: progress.attempts.erase(progress.attempts.keys()[0])
		progress.attempts[state.attempt_id] = {"kills": 0, "crates": 0, "done": false}
	var cursor: Dictionary = progress.attempts[state.attempt_id]
	if cursor.done: return
	var previous_earned: int = progress.earned.size()
	if int(state.activity.bombs) > 0 and int(state.activity.detonations) > 0: grant("ACH_FIRST_BLAST")
	if state.mode != "tutorial":
		for field in ["kills", "crates"]:
			var current := int(state.activity[field])
			var amount := maxi(0, current - int(cursor[field]))
			if amount > 0:
				progress.stats[field] = mini(1000000000, int(progress.stats[field]) + amount)
				cursor[field] = current
				dirty = true
		if int(state.activity.max_chain) > int(progress.stats.best_chain) or state.activity.powers.size() > int(progress.stats.best_powers): dirty = true
		progress.stats.best_chain = maxi(int(progress.stats.best_chain), int(state.activity.max_chain))
		progress.stats.best_powers = maxi(int(progress.stats.best_powers), state.activity.powers.size())
		if int(state.activity.max_chain) >= 5: grant("ACH_CHAIN_5")
		if state.activity.powers.size() == MapValidationService.POWERS.size(): grant("ACH_POWERUP_MASTER")
		if int(progress.stats.kills) >= 100: grant("ACH_ENEMIES_100")
		if int(progress.stats.kills) >= 1000: grant("ACH_ENEMIES_1000")
		if int(progress.stats.crates) >= 1000: grant("ACH_BLOCKS_1000")
	if state.mode == "adventure" and state.actors[0].alive and state.exploration.total > 0 and state.exploration.explored_count() * 100 >= state.exploration.total * 90:
		grant("ACH_MAZE_EXPLORER")
	if not state.result.is_empty():
		cursor.done = true
		dirty = true
		if state.mode == "classic" and state.level == 0 and state.result == "LEVEL_CLEAR" and state.actors[0].alive: grant("ACH_FIRST_VICTORY")
		if state.mode == "arena" and state.result in ["DRAW", "P1_WINS", "P2_WINS"] and state.level_ticks >= 1800 and state.activity.steps[0] >= 3 and state.activity.steps[1] >= 3 and state.activity.placements[0] >= 1 and state.activity.placements[1] >= 1:
			progress.stats.arena_matches = mini(1000000000, int(progress.stats.arena_matches) + 1)
			grant("ACH_ARENA_FIRST")
			if state.result == "P1_WINS":
				progress.stats.arena_wins = mini(1000000000, int(progress.stats.arena_wins) + 1)
				grant("ACH_ARENA_WIN")
				if int(progress.stats.arena_wins) >= 10: grant("ACH_ARENA_10")
				if int(progress.stats.arena_wins) >= 50: grant("ACH_ARENA_50")
	if progress.earned.size() != previous_earned or not state.result.is_empty() or state.tick % 300 == 0: flush()

static func map_signature(data: Dictionary) -> String:
	var layout := {}
	for key in ["mode", "width", "height", "rows", "spawns", "enemies", "powerups", "rules"]: layout[key] = data[key]
	return JSON.stringify(MapValidationService.normalize_numbers(layout), "", true).sha256_text()

func map_event(kind: String, data: Dictionary) -> void:
	if not enabled() or not MapValidationService.validate(data).is_empty(): return
	var signature := map_signature(data)
	if kind == "imported":
		if not progress.imported.has(signature) and progress.imported.size() < 100: progress.imported.append(signature)
	elif kind == "saved" and not progress.imported.has(signature):
		if not progress.owned.has(signature) and progress.owned.size() < 100: progress.owned.append(signature)
		grant("ACH_EDITOR_FIRST")
		if progress.owned.size() >= 10: grant("ACH_EDITOR_10")
	elif kind == "exported": grant("ACH_EDITOR_SHARE")
	dirty = true
	flush()

func custom_complete(state: GameState, ranked_play: bool) -> void:
	if not enabled() or not ranked_play or state.mode != "custom" or state.result != "MAP_CLEAR" or not state.actors[0].alive: return
	var signature := map_signature(state.map_data)
	if progress.owned.has(signature): grant("ACH_EDITOR_PLAY")
	if progress.imported.has(signature): grant("ACH_EDITOR_IMPORT")
	flush()

func flush() -> Error:
	if not writable: return ERR_UNAVAILABLE
	if not dirty: return OK
	var bytes := SealedData.seal(progress, "achievement_progress")
	if bytes.is_empty() or bytes.size() > 65536: return report_error(ERR_OUT_OF_MEMORY)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return report_error(FileAccess.get_open_error())
	file.store_buffer(bytes); file.flush()
	var error := file.get_error(); file.close()
	if error != OK: return report_error(error)
	if FileAccess.file_exists(path) and not recovered and valid_file(path):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK: return report_error(error)
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK: return report_error(error)
	dirty = false
	recovered = false
	last_error = OK
	return OK

func report_error(error: Error) -> Error:
	last_error = error
	save_failed.emit()
	return error

func display_rows(locale: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in AchievementCatalog.entries():
		var obtained: bool = progress.earned.has(entry.id)
		result.append({"title": str(entry.title.get(locale, entry.title.en)), "description": str(entry.description.get(locale, entry.description.en)), "icon": entry.icon, "earned": obtained, "date": Time.get_datetime_string_from_unix_time(int(progress.earned[entry.id])) if obtained else "", "progress": progress_text(entry.id)})
	return result

func progress_text(id: String) -> String:
	var goals := {"ACH_ENEMIES_100": [progress.stats.kills, 100], "ACH_ENEMIES_1000": [progress.stats.kills, 1000], "ACH_BLOCKS_1000": [progress.stats.crates, 1000], "ACH_CHAIN_5": [progress.stats.best_chain, 5], "ACH_POWERUP_MASTER": [progress.stats.best_powers, MapValidationService.POWERS.size()], "ACH_ARENA_FIRST": [progress.stats.arena_matches, 1], "ACH_ARENA_WIN": [progress.stats.arena_wins, 1], "ACH_ARENA_10": [progress.stats.arena_wins, 10], "ACH_ARENA_50": [progress.stats.arena_wins, 50], "ACH_EDITOR_FIRST": [progress.owned.size(), 1], "ACH_EDITOR_10": [progress.owned.size(), 10]}
	if not goals.has(id): return ""
	return "%d / %d" % [mini(int(goals[id][0]), int(goals[id][1])), int(goals[id][1])]

static func valid_file(source: String) -> bool:
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > 65536: return false
	var data := SealedData.open_bytes(file.get_buffer(file.get_length()), "achievement_progress")
	file.close()
	return valid(data)
