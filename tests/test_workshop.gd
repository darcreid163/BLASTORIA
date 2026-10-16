extends RefCounted

func run(test: SceneTree) -> void:
	var registry := ArcadeLevelRegistry.catalog()
	test.check(registry.themes.size() == 10 and registry.levels.size() == 100, "official: ten themes and one hundred explicitly statused slots")
	test.check(ArcadeLevelRegistry.playable_count() == 3 and ArcadeLevelRegistry.load_stage(4).is_empty(), "official: only three authored playable stages; planned stages cannot start")
	var hashes: Array[String] = []
	for number in range(1, 4):
		var data := ArcadeLevelRegistry.load_stage(number)
		test.check(not data.is_empty() and MapValidationService.validate(data).is_empty(), "official: stage %d validates authored geometry, objects and escape routes" % number)
		if data.is_empty(): return
		hashes.append(JSON.stringify(data.rows).sha256_text())
		var state := GameState.new()
		state.start_map(data, number)
		var initial := state.snapshot()
		state.start_map(data, number)
		test.check(initial == state.snapshot(), "official: repeat stage %d reconstructs identical instance" % number)
		for actor in state.actors:
			if actor.enemy: actor.alive = false
		state.advance()
		test.check(state.result == "MAP_CLEAR" and state.actors[0].cell != state.board.exit_cell, "official: stage %d wins without exit" % number)
		var ticks := state.level_ticks
		var score := state.score
		state.advance()
		state.check_end()
		test.check(state.level_ticks == ticks and state.score == score, "official: clear freezes time and awards once")
	test.check(hashes[0] != hashes[1] and hashes[1] != hashes[2] and hashes[0] != hashes[2], "official: three different authored topologies, not just enemy counts")
	var secret_data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/arcade/secrets.json"))
	var stages: Array = []
	for entry in secret_data.entries:
		stages.append(int(entry.stage))
	test.check(stages == [9, 18, 29, 37, 49, 58, 67, 79, 87, 100] and secret_data.entries[-1].requires.size() == 9, "secrets: fixed ten-stage distribution and final prerequisite; implementation honestly planned")
	var options := {"width": 25, "height": 17, "enemy_count": 5, "enemy_kind": "chaser", "bonus_count": 3, "bonus_kind": "remote", "hidden": true, "range": 2, "remote": false}
	var generated := CustomMapGenerator.generate(options, 123)
	test.check(generated.has("data"), "generator: requested configuration succeeds")
	if not generated.has("data"): return
	var data: Dictionary = generated.data
	test.check(data == CustomMapGenerator.generate(options, 123).data, "generator: same seed and version produce exact same data")
	test.check(data.rows != CustomMapGenerator.generate(options, 124).data.rows, "generator: different seeds produce different geometry")
	var valid_count := 0
	for seed_value in range(40):
		var built := CustomMapGenerator.generate(options, seed_value)
		if built.has("data") and MapValidationService.validate(built.data).is_empty() and built.data.enemies.size() == 5 and built.data.powerups.size() == 3:
			var kinds_ok := true
			for enemy in built.data.enemies: kinds_ok = kinds_ok and enemy.kind == "chaser"
			for power in built.data.powerups: kinds_ok = kinds_ok and power.kind == "remote" and power.hidden
			if kinds_ok: valid_count += 1
	test.check(valid_count == 40, "generator: forty seeds honor exact enemy/bonus counts, types and reachability")
	var empty := CustomMapGenerator.generate({"width": 11, "height": 11, "crates": false, "walls": false, "bonus_count": 0}, 42)
	test.check(empty.has("data") and not "C" in "".join(empty.data.rows) and empty.data.powerups.is_empty(), "generator: excluded crates and bonuses never appear")
	test.check(CustomMapGenerator.generate({"crates": false, "hidden": true, "bonus_count": 3}, 1).has("error"), "generator: incompatible hidden bonuses rejected instead of changing requested rules")
	test.check(CustomMapGenerator.generate({"teleports": 5}, 1).has("error"), "generator: unsupported mechanism rejected explicitly")
	test.check(CustomMapGenerator.generate({"width": 11, "height": 11, "enemy_count": 32, "bonus_count": 128}, 1).has("error"), "generator: impossible object density returns bounded failure")
	test.check(CustomMapGenerator.generate({"enemy_count": 3.5}, 1).has("error"), "generator: fractional counts rejected instead of silently rounded")
	var large := CustomMapGenerator.generate({"width": 41, "height": 31, "enemy_count": 32, "bonus_count": 64}, 50)
	test.check(large.has("data"), "generator: maximum map and enemy count validate")
	var local := CustomMapGenerator.generate({"mode": "versus", "bonus_count": 0}, 321).data as Dictionary
	var state := GameState.new()
	state.start_map(local)
	test.check(state.mode == "custom_arena" and state.actors.size() == 2 and state.alive_enemies() == 0, "custom versus: common simulation loads two players without AI")
	state.actors[1].alive = false
	state.advance()
	test.check(state.result == "P1_WINS", "custom versus: last surviving player wins")
	state.start_map(data)
	for actor in state.actors:
		if actor.enemy: actor.required = false
	state.actors[1].required = true
	state.actors[1].alive = false
	state.advance()
	test.check(state.result == "MAP_CLEAR" and state.alive_enemies() == 4, "custom: optional enemies do not block clear")
	state.start_map(data)
	for actor in state.actors: actor.alive = false
	state.advance()
	test.check(state.result == "DEFEAT", "map rules: simultaneous player death takes precedence over clear")
	var timed := data.duplicate(true)
	timed.rules.time_limit = 1
	state.start_map(timed)
	state.level_ticks = 59
	state.advance()
	test.check(state.result == "DEFEAT" and state.pending_penalty == 0, "custom timer: time limit fails match without campaign reinforcements")
	var invalid_cases: Array = []
	var bad := data.duplicate(true)
	bad.id = "../../profile"
	invalid_cases.append(bad)
	bad = data.duplicate(true); bad.format = 3; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.width = 999999; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.rules.range = NAN; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.script = "res://main.gd"; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.enemies[0].kind = "script://enemy"; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.spawns = [[0, 0]]; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.rows[0][0] = "."; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.rows[1] = "#"; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.powerups[0].cell = [999, 2]; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.enemies[0].required = "yes"; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.rules.fuse_ticks = 0; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.enemies.resize(33); invalid_cases.append(bad)
	bad = data.duplicate(true); bad.enemies[0].cell = data.spawns[0]; invalid_cases.append(bad)
	bad = data.duplicate(true); bad.rows[1][2] = "#"; bad.rows[2][1] = "#"; invalid_cases.append(bad)
	var rejected := 0
	for candidate in invalid_cases:
		if not MapValidationService.validate(candidate).is_empty(): rejected += 1
	test.check(rejected == invalid_cases.size(), "import validation: fifteen malformed/version/type/path/bounds/spawn cases rejected")
	var doc := CustomMapDocument.new()
	doc.replace(data)
	var original := doc.data.duplicate(true)
	doc.paint(Vector2i(2, 3), Vector2i(4, 4), "crate", {})
	test.check(doc.data.rows[3][2] == "C" and doc.data.rows[4][4] == "C", "editor: rectangle fill changes all selected cells")
	doc.undo()
	test.check(doc.data == original, "editor: undo restores complete instance")
	doc.redo()
	test.check(doc.data.rows[3][2] == "C", "editor: redo restores edit")
	doc.paint(Vector2i(2, 3), Vector2i(2, 3), "remote", {"hidden": true})
	test.check(doc.sample(Vector2i(2, 3)) == "remote" and doc.data.rows[3][2] == "C", "editor: typed bonus placement and eyedropper preserve hidden state")
	var library := CustomMapLibrary.new()
	library.directory = "user://qa_workshop_maps"
	var path := "user://qa_workshop_export.blastmap"
	test.check(library.store_map(data) == OK and library.write_file(path, data) == OK, "library: save full instance and export standalone file")
	var loaded := library.read_file(path)
	test.check(MapValidationService.fingerprint(loaded) == MapValidationService.fingerprint(data), "library: file roundtrip retains exact gameplay fingerprint")
	var imported := library.import_map(path)
	test.check(not imported.is_empty() and imported.id != data.id and MapValidationService.fingerprint(imported) == MapValidationService.fingerprint(data), "library: import creates fresh ID without changing gameplay or overwriting original")
	test.check(library.list_maps().size() >= 2, "library: imported entry immediately visible")
	test.check(library.remove_map("../profile") == ERR_INVALID_PARAMETER, "library: delete path traversal rejected")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{"); file.close()
	test.check(library.read_file(path).is_empty(), "import: corrupted JSON rejected")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("x".repeat(MapValidationService.MAX_BYTES + 1)); file.close()
	test.check(library.read_file(path).is_empty(), "import: oversized input rejected before parse")
	for entry in library.list_maps(): library.remove_map(entry.id)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(library.directory)
	var progress := ArcadeProgressionManager.new()
	progress.save.path = "user://qa_official23.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(progress.save.path + suffix)
	test.check(progress.available(1) and not progress.available(2), "progress: sequential level lock")
	state.start_map(ArcadeLevelRegistry.load_stage(1), 1)
	for actor in state.actors:
		if actor.enemy: actor.alive = false
	state.advance()
	test.check(progress.complete(state) == OK and progress.available(2), "progress: winning official stage persists unlock and record")
	var reloaded := ArcadeProgressionManager.new()
	reloaded.save.path = progress.save.path
	reloaded.read_progress()
	test.check(reloaded.available(2) and reloaded.save.record_for(reloaded.key_for(state.map_data)).best_ticks == 1, "progress: records and unlocked stages survive reload")
	state.start_map(data)
	for actor in state.actors:
		if actor.enemy: actor.alive = false
	state.advance()
	var before := progress.save.arcade_records.duplicate(true)
	test.check(progress.complete(state) == ERR_INVALID_DATA and progress.save.arcade_records == before, "progress: custom results cannot update official records")
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(progress.save.path + suffix)
	var legacy := GameSettings.DEFAULT_KEYS.duplicate()
	legacy.merge({"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p2_up": KEY_UP, "p2_down": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT}, true)
	var settings := GameSettings.new()
	settings.read_data({"bindings": legacy})
	test.check(settings.bindings.p1_up == KEY_UP and settings.bindings.p2_up == KEY_W, "controls: untouched legacy defaults migrate to arrows for player one")
	legacy.p1_up = KEY_Q
	settings.read_data({"bindings": legacy})
	test.check(settings.bindings.p1_up == KEY_Q, "controls: custom binding is not overridden by default migration")
	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.profile.path = "user://qa_workshop_profile.json"
	scene.official.save.path = "user://qa_workshop_official.json"
	scene.official.save.unlocked = 0
	scene.custom_records.path = "user://qa_workshop_records.json"
	scene.handle_action("official_menu")
	test.check(scene.screen == "official_menu", "UI: official Arcade selection opens")
	scene.start_official(1)
	test.check(scene.state.mode == "official_arcade" and scene.view.exit_mesh == null, "UI: official stage renders with no exit")
	scene.show_workshop()
	await test.process_frame
	test.check(scene.screen == "editor" and scene.workshop.visible and not scene.workshop.document.data.is_empty(), "UI: Workshop opens with generated editable preview")
	var editor: CustomMapEditor = scene.workshop
	var snapshot := editor.document.data.duplicate(true)
	editor.preview.cursor = Vector2i(3, 3)
	editor.palette.select(2)
	editor.preview.activate()
	test.check(editor.document.data.rows[3][3] == "C", "UI: grid action applies selected palette object")
	editor.undo()
	test.check(editor.document.data == snapshot, "UI: undo restores pre-edit map")
	editor.preview.grab_focus()
	var previous := editor.preview.cursor
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	editor.preview._gui_input(arrow)
	test.check(editor.preview.cursor == previous + Vector2i.RIGHT, "UI: keyboard event moves editing cursor")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_Y
	controller.pressed = true
	var selected := editor.palette.selected
	editor.preview._gui_input(controller)
	test.check(editor.palette.selected == (selected + 1) % editor.tools_list.size(), "UI: gamepad Y event cycles palette without text input")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(3.5, 3.5) * editor.preview.cell_size
	editor.palette.select(2)
	editor.preview._gui_input(mouse)
	test.check(editor.document.data.rows[3][3] == "C", "UI: mouse event paints selected cell")
	editor.undo()
	var profile_before: Array = [scene.profile.unlocked, scene.profile.artifacts.duplicate(), scene.profile.arcade_records.duplicate(true), scene.official.save.unlocked, scene.official.save.arcade_records.duplicate(true)]
	editor.play(false)
	test.check(scene.screen == "playing" and scene.state.mode == "custom" and not editor.visible, "UI: playtest loads shared simulation and hides editor")
	for actor in scene.state.actors:
		if actor.enemy: actor.alive = false
	scene.state.advance()
	test.check(scene.screen == "result" and scene.state.result == "MAP_CLEAR", "UI: playtest clear opens result")
	scene.handle_action("editor_return")
	test.check(scene.screen == "editor" and editor.document.data.rows == snapshot.rows, "UI: return to editor preserves authored geometry")
	test.check(profile_before == [scene.profile.unlocked, scene.profile.artifacts, scene.profile.arcade_records, scene.official.save.unlocked, scene.official.save.arcade_records], "UI: playtest changes neither campaign, artifacts, legacy records nor official Arcade progress")
	scene.queue_free()
	await test.process_frame
