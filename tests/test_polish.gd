extends RefCounted

func move(state: GameState, direction: Vector2i, count: int) -> void:
	for i in range(count):
		while state.tick < state.actors[0].ready and state.result.is_empty():
			state.advance()
		if not state.result.is_empty():
			return
		state.advance({0: {"move": direction}})

func cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run(test) -> void:
	var config := GameConfig.new()
	var state := GameState.new()
	var events: Array[String] = []
	state.feedback.connect(func(kind: String): events.append(kind))
	state.start(config, "tutorial", 0, 0)
	test.check(state.TUTORIAL.valid() and state.actors.size() == 1, "tutorial: valid authored map with one player and no enemies")
	test.check(not state.board.reachable(state.actors[0].cell).has(state.board.exit_cell), "tutorial: crate blocks route to exit")
	test.check(state.board.reachable(state.actors[0].cell, true).has(state.board.exit_cell), "tutorial: destruction opens a connected route")
	test.check(not state.exit_open() and state.tutorial_hint() == "TUT_MOVE", "tutorial: exit locked and movement instruction shown")
	move(state, Vector2i.RIGHT, 2)
	test.check(state.tutorial_moved and state.tutorial_hint() == "TUT_BOMB", "tutorial: stepping on marker advances instruction")
	move(state, Vector2i.RIGHT, 1)
	state.advance({0: {"bomb": true}})
	test.check(events.count("place") == 1, "audio: accepted bomb emits one placement event")
	state.advance({0: {"bomb": true}})
	test.check(events.count("place") == 1, "audio: rejected duplicate bomb is silent")
	move(state, Vector2i.LEFT, 3)
	for i in range(190):
		state.advance()
	test.check(state.actors[0].alive and state.board.kind(state.TUTORIAL.lesson_crate) == GridBoard.Cell.FLOOR, "tutorial: real movement/placement/retreat safely destroys crate")
	test.check(events.count("explosion") == 1 and events.count("crate") == 1 and events.count("fuse") == 2, "audio: detonation destruction and two fuse warnings dispatched")
	test.check(state.powerups.get(state.TUTORIAL.lesson_crate) == "range" and state.tutorial_hint() == "TUT_PICKUP", "tutorial: guaranteed upgrade and next instruction")
	move(state, Vector2i.RIGHT, 4)
	test.check(state.tutorial_picked and state.actors[0].radius == 3 and state.exit_open(), "tutorial: pickup unlocks exit and increases range")
	test.check(events.count("pickup") == 1 and events.count("step") > 0, "audio: pickup and successful steps dispatched")
	move(state, Vector2i.RIGHT, 8)
	move(state, Vector2i.DOWN, 4)
	test.check(state.result == "TUTORIAL_DONE" and events.count("victory") == 1, "tutorial: complete command-driven playthrough reaches victory")
	var event_count := events.size()
	state.advance()
	state.check_end()
	test.check(events.size() == event_count, "audio: terminal state cannot replay victory")
	state.start(config, "tutorial", 0, 0)
	test.check(not state.tutorial_moved and not state.tutorial_picked and not state.exit_open(), "tutorial: restart restores lesson objectives and crate")
	state.advance({0: {"bomb": true}})
	for i in range(150):
		state.advance()
	test.check(state.result == "DEFEAT" and events.has("death") and events.has("defeat"), "tutorial: standing next to bomb causes real loss and audio events")
	var invalid := LevelDefinition.new()
	invalid.rows = ["invalid"]
	test.check(not invalid.valid(), "authored map validator rejects malformed data")

	var settings := GameSettings.new()
	test.check(settings.rebind("p1_up", KEY_Q).is_empty(), "bindings: free key accepted")
	test.check(settings.rebind("p2_up", KEY_Q) == "KEY_IN_USE", "bindings: conflicts across players rejected")
	test.check(settings.rebind("p1_up", KEY_ESCAPE) == "KEY_RESERVED" and settings.rebind("p1_up", KEY_F11) == "KEY_RESERVED", "bindings: navigation escape and fullscreen protected")
	InputRouter.install(settings.bindings)
	var n := InputMap.action_get_events("p1_up").size()
	InputRouter.install(settings.bindings)
	test.check(InputMap.action_get_events("p1_up").size() == n and n == 2, "bindings: reinstall does not duplicate keyboard/gamepad events")
	test.check(InputRouter.key_label("p1_up") == "Q", "bindings: HUD hint resolves current binding")
	var copy := GameSettings.new()
	copy.read_data(settings.to_data())
	test.check(copy.bindings == settings.bindings, "settings: custom bindings survive serialization")
	copy.read_data({"master": 5, "sfx": -2, "ui": "bad", "bindings": {"p1_up": KEY_ESCAPE}})
	test.check(copy.master == 1 and copy.sfx == 0 and copy.bindings.p1_up == KEY_Q, "settings: malformed values bounded and incomplete bindings rejected")
	settings.reset_keys()
	InputRouter.install(settings.bindings)
	test.check(settings.bindings.p1_up == KEY_UP, "bindings: reset restores defaults")

	var path := "user://qa_polish_profile.json"
	cleanup(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "unlocked": 2, "language": "en", "arcade_records": {"arcade_v1": {"score": 500, "score_ticks": 600, "best_ticks": 700}}}))
	file.close()
	var profile := SaveManager.new()
	profile.path = path
	profile.read_profile(2)
	test.check(profile.unlocked == 2 and profile.language == "en" and profile.record_for("arcade_v1").score == 500, "save v2 to v3: campaign language and arcade records retained")
	profile.settings.master = 0.35
	profile.settings.fullscreen = true
	profile.settings.rebind("p1_up", KEY_Q)
	profile.write_profile()
	var loaded := SaveManager.new()
	loaded.path = path
	loaded.read_profile(2)
	test.check(is_equal_approx(loaded.settings.master, 0.35) and loaded.settings.fullscreen and loaded.settings.bindings.p1_up == KEY_Q, "save v3: volume fullscreen and bindings reload")
	cleanup(path)

	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.profile = SaveManager.new()
	scene.profile.path = path
	var audio: AudioManager = scene.audio_manager
	var assets_ok := AudioManager.SOUNDS.size() == 10
	for stream in AudioManager.SOUNDS.values():
		assets_ok = assets_ok and stream is AudioStreamWAV and stream.get_length() > 0.02 and stream.get_length() < 1.0
	test.check(assets_ok, "audio: all 10 WAV effects import with expected durations")
	test.check(audio.voices.size() == 8 and AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("Ambience") != -1, "audio: bounded pool and named bus layout")
	scene.profile.settings.master = 0
	audio.apply_settings(scene.profile.settings)
	test.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "audio: zero master volume mutes bus")
	scene.profile.settings.master = 0.8
	audio.apply_settings(scene.profile.settings)
	test.check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "audio: raising volume restores bus")
	scene.handle_action("tutorial")
	test.check(scene.state.mode == "tutorial" and scene.screen == "playing", "UI: training starts from menu")
	scene.pause_game()
	scene.handle_action("settings")
	test.check(scene.screen == "settings" and scene.settings_return == "pause" and scene.state.paused, "UI: settings from pause keeps gameplay stopped")
	var before: Dictionary = scene.state.snapshot()
	await test.physics_frame
	await test.physics_frame
	test.check(scene.state.snapshot() == before, "UI: settings time excluded from simulation")
	scene.hud.volume_changed.emit("sfx", 0.25)
	test.check(is_equal_approx(scene.profile.settings.sfx, 0.25), "UI: slider changes audio setting")
	scene.handle_action("keys1")
	scene.handle_action("bind:p1_up")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_Q
	key.keycode = KEY_Q
	scene._input(key)
	test.check(scene.profile.settings.bindings.p1_up == KEY_Q and scene.waiting_binding.is_empty(), "UI: key capture applies requested physical key")
	scene.handle_action("bind:p1_up")
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	scene._input(key)
	test.check(scene.screen == "controls" and scene.profile.settings.bindings.p1_up == KEY_Q, "UI: Escape cancels key capture without changing binding")
	scene.handle_action("controls_done")
	scene.handle_action("settings_back")
	test.check(scene.screen == "pause" and FileAccess.file_exists(path), "UI: settings persist and return to pause")
	scene.handle_action("resume")
	scene.hud.update_state(scene.state)
	test.check(scene.screen == "playing" and scene.hud.hint.text.contains("Q"), "UI: resume uses new controls and updated HUD hint")
	scene.handle_action("menu")
	scene.handle_action("settings")
	await test.process_frame
	await test.process_frame
	test.check(scene.hud.column.size.y < 800, "UI: settings content fits base 800px viewport height")
	scene.queue_free()
	await test.process_frame
	InputRouter.install()
	cleanup(path)
