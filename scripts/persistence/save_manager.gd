class_name SaveManager
extends RefCounted

const VERSION := 1
var path: String = "user://profile.json"
var unlocked: int = 0
var language: String = "ru"
var recovered_from_backup: bool = false

func read_profile(last_level: int) -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 4096:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var data = parser.data
		if not data is Dictionary or data.get("version") != VERSION:
			continue
		var value = data.get("unlocked")
		if not (value is float or value is int) or value < 0 or value > last_level:
			continue
		unlocked = int(value)
		language = "en" if data.get("language") == "en" else "ru"
		recovered_from_backup = candidate.ends_with(".bak")
		return

func write_profile() -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "unlocked": unlocked, "language": language}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	# Keep the prior complete file, then replace. Recovery also reads the backup.
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
