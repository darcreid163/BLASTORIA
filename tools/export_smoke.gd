extends SceneTree

# External QA entrypoint, excluded from the shipped PCK by export_presets.cfg.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.handle_action("adventure")
	var valid: bool = scene.state.board.width == 41 and scene.state.board.height == 31 and not scene.state.exit_revealed
	scene.toggle_map()
	scene.toggle_map()
	scene.state.advance({0: {"move": Vector2i.DOWN}})
	scene.view.sync(scene.state, 0.1)
	valid = valid and scene.state.actors[0].cell == Vector2i(1, 2) and scene.hud.map_view.expanded
	scene.handle_action("classic_start")
	valid = valid and scene.state.actors[0].radius == 1 and scene.state.remaining_seconds() == 200
	scene.state.pending_penalty = 2
	scene.state.spawn_penalties()
	scene.view.sync(scene.state, 0.1)
	valid = valid and scene.view.actors.size() == scene.state.actors.size()
	scene.handle_action("tutorial")
	valid = valid and scene.state.board.kind(scene.state.TUTORIAL.lesson_crate) == GridBoard.Cell.CRATE
	scene.handle_action("arcade_start")
	valid = valid and scene.state.mode == "arcade" and scene.state.score == 0
	scene.official.save.unlocked = 0
	scene.start_official(1)
	valid = valid and scene.state.mode == "official_arcade" and scene.view.exit_mesh == null and scene.state.board.width == 25
	scene.show_workshop()
	await process_frame
	valid = valid and scene.workshop.visible and not scene.workshop.document.data.is_empty()
	var rows: Array = scene.workshop.document.data.rows.duplicate()
	scene.workshop.play(false)
	valid = valid and scene.state.mode == "custom" and scene.state.map_data.rows == rows
	scene.show_workshop()
	valid = valid and scene.workshop.document.data.rows == rows
	var final_state := GameState.new()
	final_state.start(load("res://resources/game_rules/classic.tres"), "classic", 50, 731)
	for actor in final_state.actors:
		if actor.enemy: actor.alive = false
	final_state.exit_revealed = true
	final_state.board.cells[final_state.board.exit_cell] = GridBoard.Cell.FLOOR
	final_state.actors[0].cell = final_state.board.exit_cell
	final_state.check_end()
	valid = valid and final_state.result == "CLASSIC_DONE"
	final_state.start(load("res://resources/game_rules/classic.tres"), "classic", 51, 731)
	valid = valid and final_state.result == "INVALID_LEVEL" and ArcadeLevelRegistry.load_stage(52).is_empty()
	scene.classic_progress.stage = 80
	var before := FileAccess.get_file_as_string(scene.classic_progress.path)
	scene.start_classic_campaign(false)
	valid = valid and scene.classic_progress.stage == 80 and FileAccess.get_file_as_string(scene.classic_progress.path) == before
	print("EXPORTED RELEASE 51: ", "PASS" if valid else "FAIL")
	scene.queue_free()
	await process_frame
	if not valid:
		push_error("Exported mode smoke failed")
	print("EXPORTED MODES: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
