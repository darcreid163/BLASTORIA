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
	scene.queue_free()
	await process_frame
	if not valid:
		push_error("Exported mode smoke failed")
	print("EXPORTED MODES: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
