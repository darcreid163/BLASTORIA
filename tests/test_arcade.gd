extends RefCounted

var config := GameConfig.new()

func arena(stage: int = 0) -> GameState:
	var state := GameState.new()
	state.start(config, "arcade", stage, config.arcade_seeds[stage])
	for cell in state.board.cells:
		if state.board.kind(cell) == GridBoard.Cell.CRATE:
			state.board.cells[cell] = GridBoard.Cell.FLOOR
	for actor in state.actors:
		actor.ready = 1000000
	state.actors[0].cell = Vector2i(1, 9)
	return state

func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run(test) -> void:
	var state := arena()
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	state.bombs.place(Vector2i(2, 1), 0, 1, 1, 0, 1)
	state.bombs.place(Vector2i(4, 1), 1, 1, 1, 0, 1)
	state.advance()
	test.check(state.score == 10, "arcade: overlapping player/enemy rays score one crate once")
	state.advance()
	test.check(state.score == 10, "arcade: destroyed crate never scores again")
	state = arena()
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	state.bombs.place(Vector2i(2, 1), 1, 1, 1, 0, 1)
	state.advance()
	test.check(state.score == 0, "arcade: enemy destruction does not earn player points")
	state = arena()
	state.actors[1].cell = Vector2i(3, 1)
	state.bombs.place(Vector2i(3, 1), 0, 1, 1, 0, 1)
	state.advance()
	state.apply_damage()
	test.check(state.score == 100 and not state.actors[1].alive, "arcade: enemy kill scores once across damage passes")
	state = arena()
	state.actors[1].cell = Vector2i(3, 1)
	state.bombs.place(Vector2i(3, 1), 1, 1, 1, 0, 1)
	state.advance()
	test.check(state.score == 0, "arcade: enemy suicide yields no kill points")
	state = arena()
	state.actors[0].ready = 0
	state.powerups[Vector2i(1, 8)] = "range"
	state.advance({0: {"move": Vector2i.UP}})
	state.advance()
	test.check(state.score == 25 and state.powerups.is_empty(), "arcade: collected item scores once")
	state = arena()
	state.bombs.place(Vector2i(3, 1), 0, 1, 1, 0, 1)
	state.bombs.advance(1, state.board, 30)
	state.bombs.place(Vector2i(5, 1), 1, 2, 1, 1, 29)
	state.bombs.advance(30, state.board, 30)
	state.bombs.advance(31, state.board, 30)
	test.check(state.bombs.fire.has(Vector2i(3, 1)) and not state.bombs.credited(Vector2i(3, 1), 0), "arcade: expired player flame does not retain credit when enemy fire extends cell")

	state = arena()
	for i in range(60):
		state.advance()
	test.check(state.tick == 60 and ArcadeRun.format_time(state.tick) == "00:01.00", "arcade: 60 active ticks equal one second")
	state.paused = true
	for i in range(120):
		state.advance()
	test.check(state.tick == 60 and state.score == 0, "arcade: pause stops score and timer")
	state.paused = false
	state.tick = 6000
	state.actors[1].alive = false
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	test.check(state.score == 900 and state.time_bonus == 400, "arcade: clear at 100 seconds awards 500 plus 400 time bonus")
	state.check_end()
	test.check(state.score == 900, "arcade: repeated victory check cannot duplicate clear points")
	var run := ArcadeRun.new()
	test.check(run.accept_stage(state) and not run.accept_stage(state), "arcade: stage results accepted exactly once")
	test.check(run.score == 900 and run.elapsed_ticks == 6000 and run.next_stage == 1, "arcade: cumulative result transfers to next stage")
	state = arena(1)
	state.tick = 12000
	for actor in state.actors:
		actor.alive = not actor.enemy
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	test.check(state.time_bonus == 0 and state.score == 500, "arcade: slow completion never incurs negative time bonus")
	run.accept_stage(state)
	state = arena(2)
	state.tick = 60
	state.score = 10
	state.actors[0].alive = false
	state.check_end()
	run.accept_stage(state)
	test.check(run.ended and not run.completed and run.score == 1410 and run.elapsed_ticks == 18060, "arcade: defeat preserves earned points and accumulated active time")
	test.check(not run.accept_stage(state), "arcade: finalized run cannot accept more results")
	var complete := ArcadeRun.new()
	for stage in range(3):
		state = arena(stage)
		state.tick = 60
		for actor in state.actors:
			actor.alive = not actor.enemy
		state.actors[0].cell = state.board.exit_cell
		state.check_end()
		complete.accept_stage(state)
	test.check(state.result == "ARCADE_DONE" and complete.completed and complete.elapsed_ticks == 180, "arcade: three completed stages end a full timed run")
	test.check(complete.live_score(state) == complete.score and complete.live_ticks(state) == 180, "arcade: result HUD does not double count final stage")

	var profile := SaveManager.new()
	profile.path = "user://qa_arcade_profile.json"
	clean(profile.path)
	profile.record_arcade("arcade_v1", 200, 600, false)
	test.check(profile.record_for("arcade_v1").score == 200 and profile.record_for("arcade_v1").best_ticks == 0, "arcade: failed run can set score but never best completion time")
	profile.record_arcade("arcade_v1", 150, 400, true)
	test.check(profile.record_for("arcade_v1").score == 200 and profile.record_for("arcade_v1").best_ticks == 400, "arcade: fastest completion independent of high score")
	profile.record_arcade("arcade_v1", 200, 500, false)
	test.check(profile.record_for("arcade_v1").score_ticks == 500, "arcade: equal score prefers shorter active time")
	profile.record_arcade("arcade_v1", 100, 900, true)
	test.check(profile.record_for("arcade_v1").best_ticks == 400, "arcade: slower completion cannot overwrite time record")
	test.check(profile.record_for("arcade_v2").score == 0, "arcade: records separated by rules version")
	profile.write_profile()
	var loaded := SaveManager.new()
	loaded.path = profile.path
	loaded.read_profile(2)
	test.check(loaded.record_for("arcade_v1") == profile.record_for("arcade_v1"), "arcade: records survive save and reload")
	clean(profile.path)
	write_json(profile.path, {"version": 1, "unlocked": 2, "language": "en"})
	loaded = SaveManager.new()
	loaded.path = profile.path
	loaded.read_profile(2)
	test.check(loaded.unlocked == 2 and loaded.language == "en" and loaded.arcade_records.is_empty(), "save v1 migrates without losing campaign or language")
	loaded.record_arcade("arcade_v1", 300, 600, true)
	loaded.write_profile()
	var parser := JSON.new()
	parser.parse(FileAccess.get_file_as_string(profile.path))
	test.check(parser.data.version == SaveManager.VERSION and parser.data.unlocked == 2, "save migration writes current schema on next save")
	parser.parse(FileAccess.get_file_as_string(profile.path + ".bak"))
	test.check(parser.data.version == 1, "save migration retains original v1 backup")
	write_json(profile.path, {"version": 99, "unlocked": 2})
	loaded = SaveManager.new()
	loaded.path = profile.path
	loaded.read_profile(2)
	test.check(loaded.write_profile() == ERR_UNAVAILABLE, "future save schema is never overwritten")
	write_json(profile.path, {"version": 2, "unlocked": 1, "language": "ru", "arcade_records": {"arcade_v1": {"score": -20, "score_ticks": 2, "best_ticks": 2}}})
	loaded = SaveManager.new()
	loaded.path = profile.path
	loaded.read_profile(2)
	test.check(loaded.unlocked == 1 and loaded.record_for("arcade_v1").score == 0, "malformed records ignored without discarding valid campaign data")
	clean(profile.path)

	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.profile = SaveManager.new()
	scene.profile.path = profile.path
	scene.handle_action("arcade_menu")
	test.check(scene.screen == "arcade_menu" and scene.state.paused, "arcade menu shows rules and records before run")
	scene.handle_action("arcade_start")
	test.check(scene.state.mode == "arcade" and scene.state.actors.filter(func(a): return not a.enemy).size() == 1, "arcade starts with exactly one human player")
	var first_map: Dictionary = scene.state.board.cells.duplicate()
	scene.state.score = 200
	scene.state.tick = 120
	scene.pause_game()
	var before: Dictionary = scene.state.snapshot()
	await test.physics_frame
	await test.physics_frame
	test.check(scene.state.snapshot() == before, "arcade pause UI freezes active clock")
	scene.handle_action("retry")
	test.check(scene.state.tick == 0 and scene.arcade.score == 0 and scene.state.board.cells == first_map, "arcade retry resets whole run and repeats identical first map")
	for stage in range(3):
		scene.state.tick = 60
		for actor in scene.state.actors:
			actor.alive = not actor.enemy
		scene.state.actors[0].cell = scene.state.board.exit_cell
		scene.state.check_end()
		if stage < 2:
			scene.handle_action("next")
	test.check(scene.screen == "result" and scene.arcade.completed and scene.profile.record_for("arcade_v1").best_ticks == 180, "arcade actual scene completes all stages and saves fastest run")
	test.check(scene.profile.unlocked == 0, "arcade completion never unlocks campaign levels")
	scene.handle_action("arcade_start")
	scene.state.score = 999999
	scene.handle_action("menu")
	test.check(scene.profile.record_for("arcade_v1").score != 999999, "abandoned run is not recorded")
	scene.queue_free()
	await test.process_frame
	clean(profile.path)
