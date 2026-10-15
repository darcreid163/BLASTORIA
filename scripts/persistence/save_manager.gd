class_name SaveManager
extends RefCounted

const VERSION := 2
var path: String = "user://profile.json"
var unlocked: int = 0
var language: String = "ru"
var recovered_from_backup: bool = false
var arcade_records: Dictionary = {}
var writable: bool = true

static func valid_int(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

func read_profile(last_level: int) -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 16384:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var data = parser.data
		if not data is Dictionary:
			continue
		var version = data.get("version")
		if valid_int(version, VERSION + 1, 1000000):
			writable = false # Never overwrite a profile produced by a future version.
			return
		if not valid_int(version, 1, VERSION) or not valid_int(data.get("unlocked"), 0, last_level):
			continue
		unlocked = int(data.unlocked)
		language = "en" if data.get("language") == "en" else "ru"
		arcade_records.clear()
		# v1 has no arcade data. Migrate in memory and write v2 only on the next save.
		if version == 2 and data.get("arcade_records") is Dictionary:
			for key in data.arcade_records:
				var record = data.arcade_records[key]
				if key is String and key.length() <= 64 and valid_record(record):
					arcade_records[key] = {"score": int(record.score), "score_ticks": int(record.score_ticks), "best_ticks": int(record.best_ticks)}
		recovered_from_backup = candidate.ends_with(".bak")
		return

static func valid_record(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	for field in ["score", "score_ticks", "best_ticks"]:
		if not valid_int(record.get(field), 0, 1000000000):
			return false
	return record.score == 0 or record.score_ticks > 0

func record_for(rules_id: String) -> Dictionary:
	return arcade_records.get(rules_id, {"score": 0, "score_ticks": 0, "best_ticks": 0}).duplicate()

func record_arcade(rules_id: String, score: int, ticks: int, completed: bool) -> Dictionary:
	var changed := {"score": false, "time": false}
	if not writable or score < 0 or score > 1000000000 or ticks <= 0 or ticks > 1000000000:
		return changed
	var record := record_for(rules_id)
	if score > record.score or (score > 0 and score == record.score and ticks < record.score_ticks):
		record.score = score
		record.score_ticks = ticks
		changed.score = true
	if completed and (record.best_ticks == 0 or ticks < record.best_ticks):
		record.best_ticks = ticks
		changed.time = true
	arcade_records[rules_id] = record
	return changed

func write_profile() -> Error:
	if not writable:
		return ERR_UNAVAILABLE
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "unlocked": unlocked, "language": language, "arcade_records": arcade_records}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		if not recovered_from_backup:
			error = DirAccess.copy_absolute(path, path + ".bak")
			if error != OK:
				return error
		error = DirAccess.remove_absolute(path)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, path)
	if error == OK:
		recovered_from_backup = false
	return error
