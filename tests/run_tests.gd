extends SceneTree

var passed: int = 0
var failed: int = 0
var config := GameConfig.new()

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("FAIL: " + title)

func blank_state(mode: String = "arena") -> GameState:
	var state := GameState.new()
	state.start(config, mode, 0, 731)
	for cell in state.board.cells:
		if state.board.kind(cell) == GridBoard.Cell.CRATE:
			state.board.cells[cell] = GridBoard.Cell.FLOOR
	return state

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state := blank_state()
	var board := state.board
	check(board.kind(Vector2i(-1, 0)) == GridBoard.Cell.WALL, "outside grid is solid")
	check(not board.blast(Vector2i(1, 1), 6).has(Vector2i(0, 1)), "walls stop explosions")
	board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	var ray := board.blast(Vector2i(1, 1), 6)
	check(ray.has(Vector2i(3, 1)) and not ray.has(Vector2i(4, 1)), "crate included and stops ray")
	var system := BombSystem.new()
	check(system.place(Vector2i(1, 1), 0, 6, 1, 0, 150), "first bomb accepted")
	check(not system.place(Vector2i(1, 2), 0, 2, 1, 0, 150), "owner capacity enforced")
	check(not system.place(Vector2i(1, 1), 1, 2, 1, 0, 150), "duplicate cell rejected")
	system.advance(149, board, 30)
	check(system.bombs.size() == 1 and system.fire.is_empty(), "fuse does not detonate early")
	var destroyed := system.advance(150, board, 30)
	check(system.bombs.is_empty() and destroyed == [Vector2i(3, 1)], "fuse detonates at tick 150 and destroys crate")
	check(not system.fire.has(Vector2i(4, 1)), "destroyed crate blocks same explosion")
	system.advance(179, board, 30)
	check(system.fire.has(Vector2i(1, 1)), "fire stays through tick 179")
	system.advance(180, board, 30)
	check(system.fire.is_empty(), "fire expires exactly at tick 180")
	check(system.place(Vector2i(1, 1), 0, 2, 1, 180, 150), "capacity released after explosion")

	state = blank_state()
	system = state.bombs
	system.place(Vector2i(1, 1), 0, 3, 3, 0, 1)
	system.place(Vector2i(3, 1), 1, 3, 3, 0, 100)
	system.place(Vector2i(5, 1), 2, 3, 3, 0, 100)
	system.advance(1, state.board, 30)
	check(system.bombs.is_empty() and system.fire.has(Vector2i(7, 1)), "three-bomb chain resolves in one tick")
	check(system.advance(1, state.board, 30).is_empty(), "repeat resolve does not destroy twice")

	state = blank_state()
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	state.bombs.place(Vector2i(1, 1), 0, 6, 2, 0, 1)
	state.bombs.place(Vector2i(2, 1), 1, 6, 2, 0, 1)
	destroyed = state.bombs.advance(1, state.board, 30)
	check(destroyed.size() == 1 and not state.bombs.fire.has(Vector2i(4, 1)), "simultaneous rays share terrain snapshot and deduplicate destruction")

	state = blank_state()
	state.advance({0: {"move": Vector2i.LEFT}})
	check(state.actors[0].cell == Vector2i(1, 1), "player cannot enter wall")
	state.actors[0].ready = 0
	state.advance({0: {"bomb": true, "move": Vector2i.DOWN}, 1: {"move": Vector2i.UP}})
	check(state.actors[0].cell == Vector2i(1, 2) and state.actors[1].cell == Vector2i(13, 8), "two players move independently and owner leaves bomb")
	state.actors[0].ready = 0
	state.advance({0: {"move": Vector2i.UP}})
	check(state.actors[0].cell == Vector2i(1, 2), "owner cannot reenter bomb")
	var before := state.snapshot()
	state.paused = true
	for i in range(180):
		state.advance({0: {"bomb": true}})
	check(state.snapshot() == before, "pause freezes entire simulation")

	state = blank_state()
	state.bombs.place(Vector2i(1, 1), 0, 2, 1, 0, 1)
	state.bombs.place(Vector2i(13, 9), 1, 2, 1, 0, 1)
	state.advance({0: {"move": Vector2i.DOWN}})
	check(state.result == "DRAW", "same-tick deaths draw; movement cannot dodge expired fuse")
	before = state.snapshot()
	state.advance()
	check(state.snapshot() == before, "finished round cannot advance")
	state.start(config, "arena", 0, 4242)
	check(state.tick == 0 and state.result.is_empty() and state.bombs.bombs.is_empty() and state.bombs.fire.is_empty(), "restart resets timers bombs fire and result")

	state = blank_state("campaign")
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	check(state.result.is_empty(), "exit locked while enemies live")
	for actor in state.actors:
		if actor.enemy:
			actor.alive = false
	state.check_end()
	check(state.result == "LEVEL_CLEAR", "campaign exit wins after enemies defeated")
	state = blank_state("campaign")
	state.actors[0].alive = false
	state.check_end()
	check(state.result == "DEFEAT", "campaign player death loses")
	state = blank_state("campaign")
	state.level = 2
	for actor in state.actors:
		actor.alive = not actor.enemy
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	check(state.result == "CAMPAIGN_DONE", "final level ends campaign")

	state = blank_state()
	state.powerups[Vector2i(1, 2)] = "capacity"
	state.advance({0: {"move": Vector2i.DOWN}})
	check(state.actors[0].capacity == 2 and state.powerups.is_empty(), "pickup applies once and disappears")
	for i in range(20):
		for kind in ["capacity", "range", "speed"]:
			state.collect(state.actors[0], kind)
	check(state.actors[0].capacity == 5 and state.actors[0].radius == 6 and state.actors[0].step == 5, "all powerup limits enforced")

	var maps_ok := true
	var symmetry_ok := true
	for map_seed in range(100):
		state.start(config, "arena", 0, map_seed)
		var reachable := state.board.reachable(Vector2i(1, 1), true)
		for cell in state.board.cells:
			if state.board.kind(cell) != GridBoard.Cell.WALL and not reachable.has(cell):
				maps_ok = false
			var mirror := Vector2i(config.width - 1 - cell.x, config.height - 1 - cell.y)
			if state.board.kind(cell) != state.board.kind(mirror):
				symmetry_ok = false
		if state.board.kind(Vector2i(1, 2)) != GridBoard.Cell.FLOOR or state.board.kind(Vector2i(2, 1)) != GridBoard.Cell.FLOOR:
			maps_ok = false
	check(maps_ok, "100 seeds: reachable destroyable topology and safe spawn exits")
	check(symmetry_ok, "100 seeds: arena rotational symmetry")

	state = blank_state("campaign")
	state.bombs.place(Vector2i(1, 1), 0, 6, 1, 0, 150)
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	check(not state.bombs.danger(state.board).has(Vector2i(4, 1)), "AI danger map respects blockers")
	state.actors[1].cell = Vector2i(1, 3)
	var command := EnemyAI.command(state.actors[1], state)
	check(command.move != Vector2i.ZERO, "AI finds a route from impending blast")

	var first := GameState.new()
	var second := GameState.new()
	first.start(config, "campaign", 1, 1559)
	second.start(config, "campaign", 1, 1559)
	for i in range(1200):
		var commands := {0: {"move": GridBoard.DIRS[(i / 45) as int % 4], "bomb": i % 160 == 0}}
		first.advance(commands)
		second.advance(commands)
	check(first.snapshot() == second.snapshot(), "same seed and 1200 command ticks replay identically")
	var soak_ok := true
	for map_seed in range(25):
		state.start(config, "campaign", map_seed % 3, map_seed)
		for i in range(1200):
			state.advance({0: {"move": GridBoard.DIRS[(i / 30) as int % 4], "bomb": i % 160 == 0}})
			for actor in state.actors:
				if actor.alive and state.board.kind(actor.cell) != GridBoard.Cell.FLOOR:
					soak_ok = false
	check(soak_ok, "25 seeded simulations: actors never occupy terrain blockers")

	var save := SaveManager.new()
	save.path = "user://qa_profile.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save.path + suffix):
			DirAccess.remove_absolute(save.path + suffix)
	save.unlocked = 1
	check(save.write_profile() == OK, "profile writes successfully")
	var loaded := SaveManager.new()
	loaded.path = save.path
	loaded.read_profile(2)
	check(loaded.unlocked == 1, "profile reloads progress")
	save.unlocked = 2
	save.write_profile()
	var corrupt := FileAccess.open(save.path, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	loaded = SaveManager.new()
	loaded.path = save.path
	loaded.read_profile(2)
	check(loaded.unlocked == 1, "corrupt profile recovers previous backup")
	loaded.unlocked = 2
	check(loaded.write_profile() == OK, "recovered profile can save again")
	var backup_parser := JSON.new()
	backup_parser.parse(FileAccess.get_file_as_string(save.path + ".bak"))
	check(backup_parser.data.unlocked == 1, "recovery save preserves valid backup instead of corrupt primary")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save.path + suffix):
			DirAccess.remove_absolute(save.path + suffix)

	# Integration uses the actual main scene, HUD, controllers and view.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.screen == "menu" and scene.state.paused, "main scene opens menu with paused world")
	scene.handle_action("arena")
	check(scene.state.mode == "arena" and scene.state.actors.size() == 2, "menu starts local arena")
	scene.pause_game()
	before = scene.state.snapshot()
	await physics_frame
	await physics_frame
	check(scene.state.snapshot() == before, "pause UI freezes live scene")
	scene.handle_action("resume")
	check(scene.screen == "playing" and not scene.state.paused, "resume restores gameplay")
	for i in range(10):
		scene.handle_action("retry")
		await process_frame
	check(scene.view.get_child_count() == 4, "10 restarts keep one world and camera/light/environment")
	scene.handle_action("menu")
	check(scene.screen == "menu" and scene.hud.overlay.visible, "return to menu works")
	TranslationServer.set_locale("ru")
	check(TranslationServer.translate("PAUSED") == "Пауза", "Russian localization loaded")
	TranslationServer.set_locale("en")
	check(TranslationServer.translate("PAUSED") == "Paused", "English localization loaded")
	scene.queue_free()
	await process_frame
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
