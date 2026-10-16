extends SceneTree

func _initialize() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://tools/private_content.json"))
	var registry = JSON.parse_string(FileAccess.get_file_as_string("res://resources/achievements/registry.json"))
	if not source is Dictionary or not registry is Dictionary: quit(1); return
	var codec = preload("res://scripts/persistence/sealed_data.gd")
	# Future and hidden definitions stay in development sources, never in this release payload.
	var entries: Array = []
	for entry in registry.entries:
		if entry.get("status") == "local" and not entry.get("hidden", true): entries.append(entry)
	var active: Dictionary = source.duplicate(true)
	active.view = codec.seal(active.text, "display").hex_encode()
	active.erase("text")
	var envelope := {"payload": {"active": active, "milestones": {"schema_version": 1, "entries": entries}}, "padding": ""}
	var size := JSON.stringify(envelope).to_utf8_buffer().size()
	var target := ceili(float(size) / 16384.0) * 16384
	var count := target - size
	envelope.padding = Crypto.new().generate_random_bytes(ceili(float(count) / 2.0)).hex_encode().left(count)
	DirAccess.make_dir_recursive_absolute("res://resources/data")
	var file := FileAccess.open("res://resources/data/runtime.bin", FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_buffer(codec.seal(envelope, "runtime"))
	file.close()
	print("Runtime bundle built; inactive definitions excluded; size bucket padded.")
	quit()
