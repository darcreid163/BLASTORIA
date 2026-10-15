class_name CustomMapLibrary
extends RefCounted

var directory: String = "user://maps"
var error: String = ""

func read_file(path: String) -> Dictionary:
	error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MapValidationService.MAX_BYTES:
		error = "Файл недоступен или превышает 256 КиБ."
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Повреждённый JSON."
		return {}
	error = MapValidationService.validate(parser.data)
	return parser.data if error.is_empty() else {}

func store_map(data: Dictionary) -> Error:
	error = MapValidationService.validate(data)
	if not error.is_empty():
		return ERR_INVALID_DATA
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		error = "Не удалось создать папку карт."
		return result
	return write_file(directory.path_join(data.id + ".blastmap"), data)

func write_file(path: String, data: Dictionary) -> Error:
	error = MapValidationService.validate(data)
	if not error.is_empty():
		return ERR_INVALID_DATA
	var body := JSON.stringify(data, "\t", true)
	if body.to_utf8_buffer().size() > MapValidationService.MAX_BYTES:
		error = "Карта превышает 256 КиБ."
		return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Не удалось открыть файл для записи."
		return FileAccess.get_open_error()
	file.store_string(body)
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK:
		error = "Ошибка сохранения: " + error_string(result)
	return result

func import_map(path: String) -> Dictionary:
	var data := read_file(path)
	if data.is_empty():
		return {}
	# Never use the sender's ID as a storage destination or overwrite an existing map.
	data.id = new_id()
	data.created = Time.get_datetime_string_from_system(true)
	data.modified = data.created
	return data if store_map(data) == OK else {}

static func new_id() -> String:
	return "map_" + Crypto.new().generate_random_bytes(16).hex_encode()

func list_maps() -> Array[Dictionary]:
	var maps: Array[Dictionary] = []
	var folder := DirAccess.open(directory)
	if folder == null:
		return maps
	var names := folder.get_files()
	names.sort()
	for name in names:
		if maps.size() >= 200:
			break
		if name.ends_with(".blastmap") and MapValidationService.valid_id(name.trim_suffix(".blastmap")):
			var data := read_file(directory.path_join(name))
			if not data.is_empty():
				maps.append(data)
	return maps

func remove_map(id: String) -> Error:
	if not MapValidationService.valid_id(id):
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(directory.path_join(id + ".blastmap"))
