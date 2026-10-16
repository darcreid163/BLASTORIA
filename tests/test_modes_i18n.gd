extends RefCounted

func run(test: SceneTree) -> void:
	for mode in MapValidationService.MODES:
		var data: Dictionary = CustomMapGenerator.generate({"mode": mode, "width": 17, "height": 13}, 77).data
		test.check(data.format == 2 and not data.has("secrets") and MapValidationService.validate(data).is_empty(), "workshop: format 2 " + mode + " has no private fields")
		var injected := data.duplicate(true)
		injected.secrets = []
		test.check(not MapValidationService.validate(injected).is_empty(), "workshop: rejects injected field " + mode)
		var state := GameState.new()
		state.start_map(data)
		if mode == "coop":
			state.actors[0].alive = false
			state.check_end()
			test.check(state.result.is_empty() and state.followed_actor().id == 1, "coop: player two continues when player one dies")
			state.actors[1].alive = false
			state.check_end()
			test.check(state.result == "DEFEAT", "coop: both dead ends passage")
			state.start_map(data)
			state.actors[2].cell = state.actors[1].cell
			state.apply_contact()
			test.check(not state.actors[1].alive and state.actors[0].alive, "coop: contact checks player two")
			state.start_map(data)
			state.bombs.fire[state.actors[2].cell] = 20
			state.bombs.fire_owners[state.actors[2].cell] = {1: 20}
			state.apply_damage()
			test.check(state.activity.kills == 1 and state.score == state.config.score_enemy, "coop: player two blast earns shared score once")
		if mode == "arena_bot":
			state.actors[0].alive = false
			state.check_end()
			test.check(state.result == "DEFEAT", "bot arena: human loss ends match")
			state.start_map(data)
			for actor in state.actors: actor.alive = false
			state.check_end()
			test.check(state.result == "DRAW", "bot arena: simultaneous all-dead is draw")
			state.start_map(data)
			for actor in state.actors:
				if actor.enemy: actor.alive = false
			state.check_end()
			test.check(state.result == "P1_WINS", "bot arena: last human wins")
	var legacy := ArcadeLevelRegistry.load_stage(1)
	var library := CustomMapLibrary.new()
	var export_path := "user://legacy_upgrade.blastmap"
	test.check(library.export_map(export_path, legacy) == OK, "legacy custom map exports through current schema")
	var serialized: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(export_path))
	test.check(serialized.format == 2 and not serialized.has("secrets") and MapValidationService.fingerprint(serialized) == MapValidationService.fingerprint(legacy), "legacy export removes private field without changing gameplay")
	DirAccess.remove_absolute(export_path)
	LanguageCatalog.install()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/catalog.json"))
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(test, locale)
		test.check(TranslationServer.translate("ARCADE") == catalog[locale].ARCADE and not catalog[locale].ARCADE.is_empty(), locale + ": active translation installed")
		var font := LanguageCatalog.font_for(locale)
		var characters: String = "".join(catalog[locale].values())
		for item in AchievementCatalog.entries(): characters += str(item.title[locale]) + str(item.description[locale])
		characters += SecretDefinition.active().localized("name", locale) + SecretDefinition.active().localized("return", locale)
		var covered := true
		var missing := ""
		for character in characters:
			var code := character.unicode_at(0)
			if code > 32 and not font.has_char(code): covered = false; missing += String.chr(code)
		test.check(covered, locale + ": complete bundled glyph coverage " + missing)
		var save := SaveManager.new(); save.path = "user://locale_test.json"; save.language = locale
		test.check(save.write_profile() == OK, locale + ": language selection writes")
		var loaded := SaveManager.new(); loaded.path = save.path; loaded.read_profile(2)
		test.check(loaded.language == locale, locale + ": selected language survives restart")
		var rows := AchievementManager.new().display_rows(locale)
		test.check(rows.size() == 17 and rows[0].title == AchievementCatalog.entries()[0].title[locale], locale + ": achievement display follows locale")
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(save.path + suffix): DirAccess.remove_absolute(save.path + suffix)
	var manager := EncounterManager.new(); manager.enabled = true
	var official := GameState.new(); official.start_map(ArcadeLevelRegistry.load_stage(3), 3)
	official.activity.powers = ["range", "capacity", "remote"]
	for actor in official.actors:
		if actor.enemy: actor.alive = false
	official.advance()
	var owned := manager.evaluate(official)
	test.check(owned.size() == 1, "official Arcade terminal gameplay qualifies for discovery")
	official.level_ticks = 7201
	test.check(manager.evaluate(official).is_empty(), "late Arcade clear does not qualify")
	official.start_map(ArcadeLevelRegistry.load_stage(3)); official.result = "MAP_CLEAR"; official.activity.powers = ["range", "capacity", "remote"]
	test.check(manager.evaluate(official).is_empty(), "imported identical geometry cannot grant official discoveries")
	var arena := GameState.new(); arena.start(GameConfig.new(), "arena", 0, 8)
	arena.level_ticks = 1800; arena.activity.steps = [12,12]; arena.activity.placements = [3,3]
	for actor in arena.actors: actor.alive = false
	arena.check_end()
	var mirrors := manager.evaluate(arena)
	test.check(mirrors.size() == 1 and arena.score == 0, "official Arena draw qualifies without score reward")
	var profile := SaveManager.new(); profile.path = "user://encounters_test.json"
	for id in owned + mirrors: profile.record_secret(id)
	profile.write_profile()
	var reloaded := SaveManager.new(); reloaded.path = profile.path; reloaded.read_profile(2)
	test.check(reloaded.artifacts.size() == 2 and not profile.record_secret(owned[0]), "discovery collection persists and deduplicates")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile.path + suffix): DirAccess.remove_absolute(profile.path + suffix)
	LanguageCatalog.apply(test, "en")

	test.check(LanguageCatalog.matches("ja", "япон", "ru") and LanguageCatalog.matches("ko", "한국", "en") and LanguageCatalog.matches("zh_CN", "Chinese", "fr"), "language search accepts localized, native and English names")
	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.show_workshop()
	var editor: CustomMapEditor = scene.workshop
	editor.title_field.text = "My unchanged title"
	var before := editor.document.data.duplicate(true)
	var undo_count := editor.document.undo_stack.size()
	LanguageCatalog.apply(test, "ar")
	test.check(editor.document.data == before and editor.title_field.text == "My unchanged title" and editor.document.undo_stack.size() == undo_count, "language switch preserves edited map, user text and undo")
	var picker := MapFilePicker.new()
	picker.save_mode = true
	editor.add_child(picker)
	var emissions := [0]
	picker.file_selected.connect(func(_path): emissions[0] += 1)
	picker.path_field.text = "/this-folder-does-not-exist-blastoria"
	picker.choose()
	test.check(emissions[0] == 0 and picker.listing_folder.is_empty() and not picker.notice.text.is_empty(), "file picker refuses invalid destination instead of reusing old folder")
	picker.queue_free()
	scene.queue_free()
	await test.process_frame
	LanguageCatalog.apply(test, "en")
