extends RefCounted

const CLASSIC := preload("res://resources/game_rules/classic.tres")

func run(test: SceneTree) -> void:
	test.check(ClassicChapterOneMap.validate(), "ch1: ten different authored, reachable Classic topologies")
	var signatures: Dictionary = {}
	var consistent := true
	var previous_area := 0
	for number in range(1, 11):
		var data := ClassicChapterOneMap.stage(number)
		var plan := ClassicStagePlan.stage(number)
		var state := GameState.new()
		state.start(CLASSIC, "classic", number - 1, int(plan.seed))
		if data.is_empty():
			consistent = false
			continue
		var prize := ClassicChapterOneMap.point(data.prize)
		var exit_cell := ClassicChapterOneMap.point(data.exit)
		var fingerprint: String = "\n".join(PackedStringArray(data.rows))
		consistent = consistent and not signatures.has(fingerprint)
		signatures[fingerprint] = true
		consistent = consistent and state.result.is_empty()
		consistent = consistent and state.board.width == data.width and state.board.height == data.height
		consistent = consistent and state.board.width * state.board.height >= previous_area
		previous_area = state.board.width * state.board.height
		consistent = consistent and state.board.exit_cell == exit_cell and not state.exit_revealed
		consistent = consistent and state.board.kind(exit_cell) == GridBoard.Cell.CRATE
		consistent = consistent and state.board.kind(prize) == GridBoard.Cell.CRATE
		consistent = consistent and state.hidden_powerups.size() == 1 and state.hidden_powerups.get(prize) == plan.sealed_prize
		consistent = consistent and state.alive_enemies() == plan.enemy_count
		var reachable := state.board.reachable(Vector2i(1, 1), true)
		consistent = consistent and reachable.has(exit_cell) and reachable.has(prize)
		for enemy in state.actors:
			if enemy.enemy:
				consistent = consistent and state.board.kind(enemy.cell) == GridBoard.Cell.FLOOR
		var replica := GameState.new()
		replica.start(CLASSIC, "classic", number - 1, int(plan.seed))
		consistent = consistent and state.board.cells == replica.board.cells and state.actors == replica.actors
	test.check(consistent and signatures.size() == 10, "ch1: ten distinct stage layouts, pinned prizes, exits and enemy positions")
	var third := GameState.new()
	third.start(CLASSIC, "classic", 2, int(ClassicStagePlan.stage(3).seed))
	var p := third.sealed_prize_cell
	third.bombs.place(p + Vector2i.UP, 0, 1, 1, 0, 1)
	third.advance()
	test.check(third.powerups.get(p) == "remote", "ch1: stage three drops only its predefined remote detonator")
	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.classic_progress.stage = 8
	scene.classic_progress.lives = 5
	scene.start_classic_campaign(false)
	var initial_camera: Vector3 = scene.view.camera.position
	scene.state.actors[0].cell = Vector2i(scene.state.board.width - 2, scene.state.board.height - 2)
	scene.view.sync(scene.state, 0.2)
	test.check(scene.state.level == 7 and scene.state.board.width == 31 and scene.view.camera.position != initial_camera,
		"ch1: campaign continues at stage eight and orthographic 2.5D camera follows on multi-screen board")
	scene.queue_free()
	await test.process_frame
