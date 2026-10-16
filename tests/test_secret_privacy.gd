extends RefCounted

func cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute(path + suffix)

func run(test: SceneTree) -> void:
	var definition := SecretDefinition.active()
	test.check(definition.valid and definition.reward == 50000, "privacy: active definition decrypts and preserves gameplay reward")
	var plaintext := {"items": [definition.id], "name": definition.localized("name", "ru")}
	var first := SealedData.seal(plaintext, "collection")
	var second := SealedData.seal(plaintext, "collection")
	test.check(first != second, "privacy: each encryption uses a fresh IV")
	test.check(SealedData.open_bytes(first, "collection") == plaintext, "privacy: authenticated encrypted data roundtrips")
	test.check(SealedData.open_bytes(first, "content").is_empty(), "privacy: containers cannot be substituted across purposes")
	var tampered := first.duplicate()
	tampered[10] = tampered[10] ^ 1
	test.check(SealedData.open_bytes(tampered, "collection").is_empty(), "privacy: modified IV rejected before decryption")
	tampered = first.duplicate()
	tampered[30] = tampered[30] ^ 1
	test.check(SealedData.open_bytes(tampered, "collection").is_empty(), "privacy: modified ciphertext rejected")
	tampered = first.duplicate()
	tampered[-1] = tampered[-1] ^ 1
	test.check(SealedData.open_bytes(tampered, "collection").is_empty(), "privacy: modified authentication tag rejected")
	test.check(SealedData.open_bytes(first.slice(0, 60), "collection").is_empty() and SealedData.open_hex("not hex", "collection").is_empty(), "privacy: truncated/malformed containers rejected without grants")
	var path := "user://qa_secret_privacy.json"
	cleanup(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "unlocked": 2, "language": "ru", "artifacts": ["ghost_compass"], "settings": GameSettings.new().to_data()}))
	file.close()
	var save := SaveManager.new()
	save.path = path
	save.read_profile(2)
	test.check(save.artifacts == [definition.id] and save.unlocked == 2, "privacy: legacy secret identifier migrates to opaque token without losing progress")
	test.check(save.write_profile() == OK, "privacy: migrated profile writes encrypted collection")
	var primary := FileAccess.get_file_as_string(path)
	var backup := FileAccess.get_file_as_string(path + ".bak")
	test.check(not primary.contains("ghost_compass") and not primary.contains(definition.id) and not primary.contains("artifacts"), "privacy: current JSON contains neither semantic IDs nor plaintext opaque tokens")
	test.check(not backup.contains("ghost_compass") and not backup.contains(definition.id), "privacy: migrated backup also removes plaintext secret IDs")
	var loaded := SaveManager.new()
	loaded.path = path
	loaded.read_profile(2)
	test.check(loaded.artifacts == [definition.id], "privacy: encrypted collection survives reload")
	var data = JSON.parse_string(primary)
	data.vault[40] = "a" if data.vault[40] != "a" else "b"
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	loaded = SaveManager.new(); loaded.path = path; loaded.read_profile(2)
	test.check(loaded.recovered_from_backup and loaded.artifacts == [definition.id], "privacy: tampered primary recovers authenticated backup")
	test.check(loaded.write_profile() == OK, "privacy: recovered profile can save without replacing valid backup with corruption")
	var cached: SecretDefinition = SecretDefinition.cached
	SecretDefinition.cached = SecretDefinition.new()
	var unavailable := SaveManager.new()
	unavailable.path = path
	unavailable.read_profile(2)
	test.check(unavailable.write_profile() == ERR_UNAVAILABLE, "privacy: missing content cannot overwrite an existing encrypted collection")
	SecretDefinition.cached = cached
	cleanup(path)
	var saved_definition: SecretDefinition = SecretManager.COMPASS
	SecretManager.COMPASS = SecretDefinition.new()
	var manager := SecretManager.new()
	manager.enabled = true
	manager.revealed = true
	test.check(manager.collect(Vector2i(-1, -1)) == 0 and not manager.awarded and not manager.finish(100, 100), "privacy: unavailable private content never grants a secret reward")
	SecretManager.COMPASS = saved_definition
	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.profile = SaveManager.new()
	scene.profile.language = "ru"
	TranslationServer.set_locale("ru")
	scene.show_discoveries()
	var label_text := ""
	for child in scene.hud.column.get_children():
		if child is Label: label_text += child.text + "\n"
	test.check(not label_text.contains(definition.localized("name", "ru")) and not label_text.contains("/10") and not label_text.contains("1 / 10") and not label_text.contains(definition.id), "privacy: empty discovery screen exposes no hidden name, total or technical ID")
	scene.profile.record_secret(definition.id)
	scene.show_discoveries()
	label_text = ""
	for child in scene.hud.column.get_children():
		if child is Label: label_text += child.text + "\n"
	test.check(label_text.contains(definition.localized("name", "ru")) and not label_text.contains("1 / 10") and not label_text.contains(definition.id), "privacy: owned screen reveals public name only, without total/index/ID")
	scene.show_secret_hall()
	label_text = ""
	for child in scene.hud.column.get_children():
		if child is Label: label_text += child.text + "\n"
	test.check(not label_text.contains(definition.localized("name", "ru")) and not label_text.contains(definition.id), "privacy: offline world hall does not invent discoveries or expose hidden metadata")
	scene.queue_free()
	await test.process_frame
