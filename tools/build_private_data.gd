extends SceneTree

func _initialize() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://tools/private_content.json"))
	if not source is Dictionary: quit(1); return
	var bytes := preload("res://scripts/persistence/sealed_data.gd").seal(source, "content")
	var file := FileAccess.open("res://resources/private/content.dat", FileAccess.WRITE)
	if file == null or bytes.is_empty(): quit(1); return
	file.store_buffer(bytes)
	file.close()
	var registry = JSON.parse_string(FileAccess.get_file_as_string("res://resources/achievements/registry.json"))
	if not registry is Dictionary: quit(1); return
	file = FileAccess.open("res://resources/private/milestones.dat", FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_buffer(preload("res://scripts/persistence/sealed_data.gd").seal(registry, "milestones"))
	file.close()
	print("Private content container built. This is local anti-spoiler encryption, not server authority.")
	quit()
