extends SceneTree

var valid: bool = true

func require(condition: bool, label: String) -> void:
	valid = valid and condition
	print("PASS: " if condition else "FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	require(not FileAccess.file_exists("res://resources/arcade/secrets.json"), "developer secret registry absent from player package")
	require(not FileAccess.file_exists("res://resources/achievements/registry.json"), "plaintext achievement registry absent from player package")
	require(not FileAccess.file_exists("res://tools/private_content.json"), "plaintext content source absent from player package")
	require(not FileAccess.file_exists("res://resources/secrets/ghost_compass.tres"), "old semantic resource filename absent")
	require(not FileAccess.file_exists("res://docs/MASTER_SPEC.md"), "developer specification absent from player package")
	require(SecretDefinition.active().valid, "encrypted active content readable in actual export")
	require(AchievementCatalog.validate(), "encrypted milestone catalog readable in actual export")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.profile = SaveManager.new()
	scene.profile.language = "ru"
	TranslationServer.set_locale("ru")
	scene.show_discoveries()
	var text_value := ""
	for child in scene.hud.column.get_children():
		if child is Label: text_value += child.text + "\n"
	require(not text_value.contains(SecretDefinition.active().id) and not text_value.contains("1 / 10") and not text_value.contains(SecretDefinition.active().localized("name")), "unfound collection reveals no name, identifier or total")
	scene.profile.record_secret(SecretDefinition.active().id)
	scene.show_discoveries()
	text_value = ""
	for child in scene.hud.column.get_children():
		if child is Label: text_value += child.text + "\n"
	require(text_value.contains(SecretDefinition.active().localized("name")) and not text_value.contains(SecretDefinition.active().id) and not text_value.contains("1 / 10"), "found collection shows only public description")
	scene.queue_free()
	await process_frame
	print("PRIVACY EXPORT: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
