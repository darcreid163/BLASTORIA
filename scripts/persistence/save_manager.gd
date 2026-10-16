class_name SaveManager
extends RefCounted

const VERSION := 6
var max_bytes: int = 16384
var path: String = "user://profile.json"
var unlocked: int = 0
var language: String = LanguageCatalog.normalize(OS.get_locale())
var recovered_from_backup: bool = false
var arcade_records: Dictionary = {}
var writable: bool = true
var settings := GameSettings.new()
var artifacts: Array[String] = []

static func valid_int(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

func read_profile(last_level: int) -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > max_bytes:
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
		var owned: Array[String] = []
		if version >= 5:
			var private_data := SealedData.open_hex(data.get("vault"), "collection")
			if not private_data.get("items") is Array:
				continue # Corrupt collection: recover whole previous profile, never turn corruption into grants.
			if not private_data.items.is_empty() and not SecretDefinition.active().valid:
				writable = false
				return # Preserve known discoveries when private content is unavailable.
			owned = normalize_artifacts(private_data.items)
		elif version >= 4 and data.get("artifacts") is Array:
			if not data.artifacts.is_empty() and not SecretDefinition.active().valid:
				writable = false
				return
			owned = normalize_artifacts(data.artifacts)
		unlocked = int(data.unlocked)
		language = LanguageCatalog.normalize(str(data.get("language", "en")))
		arcade_records.clear()
		# v1 has no arcade data. Migrate in memory and write current schema only on the next save.
		if version >= 2 and data.get("arcade_records") is Dictionary:
			for key in data.arcade_records:
				var record = data.arcade_records[key]
				if key is String and key.length() <= 64 and valid_record(record):
					arcade_records[key] = {"score": int(record.score), "score_ticks": int(record.score_ticks), "best_ticks": int(record.best_ticks)}
		if version >= 3:
			settings.read_data(data.get("settings"))
		artifacts = owned
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
	var payload := {"version": VERSION, "unlocked": unlocked, "language": language, "arcade_records": arcade_records, "settings": settings.to_data(), "vault": SealedData.seal({"items": artifacts}, "collection").hex_encode()}
	var body := JSON.stringify(payload)
	if body.to_utf8_buffer().size() > max_bytes:
		file.close()
		return ERR_OUT_OF_MEMORY
	file.store_string(body)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		if not recovered_from_backup:
			error = prepare_backup(path, path + ".bak")
			if error != OK:
				return error
		elif FileAccess.file_exists(path + ".bak"):
			error = prepare_backup(path + ".bak", path + ".bak")
			if error != OK: return error
		error = DirAccess.remove_absolute(path)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, path)
	if error == OK:
		recovered_from_backup = false
	return error

static func normalize_artifacts(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var normalized := SecretDefinition.normalize_id(value)
		if not normalized.is_empty() and not result.has(normalized): result.append(normalized)
	return result

func record_secret(id: String) -> bool:
	var normalized := SecretDefinition.normalize_id(id)
	if not writable or normalized.is_empty() or artifacts.has(normalized):
		return false
	artifacts.append(normalized)
	return true

func prepare_backup(source: String, target: String) -> Error:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null or input.get_length() > max_bytes: return ERR_FILE_CORRUPT
	var bytes := input.get_buffer(input.get_length())
	input.close()
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return ERR_FILE_CORRUPT
	var data: Dictionary = parser.data
	# Preserve old no-secret backups exactly. Migrate only legacy clear-text collection fields.
	if valid_int(data.get("version"), 1, 4) and data.get("artifacts") is Array:
		data.vault = SealedData.seal({"items": normalize_artifacts(data.artifacts)}, "collection").hex_encode()
		data.erase("artifacts")
		data.version = VERSION
		bytes = JSON.stringify(data).to_utf8_buffer()
	var output := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if output == null: return FileAccess.get_open_error()
	output.store_buffer(bytes)
	output.flush()
	var error := output.get_error()
	output.close()
	if error != OK: return error
	return DirAccess.rename_absolute(target + ".tmp", target)
