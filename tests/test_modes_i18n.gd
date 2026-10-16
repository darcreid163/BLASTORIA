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
