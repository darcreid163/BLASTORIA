extends RefCounted

const CLASSIC = preload("res://resources/game_rules/classic.tres")

func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run(test: SceneTree) -> void:
	test.check(ClassicStagePlan.validate(), "classic100: valid fixed hundred-stage catalog")
	var required := {
		"range": [1, 7, 15, 19, 27, 38],
		"capacity": [2, 5, 6, 11, 12, 17, 23, 28, 32],
		"remote": [3, 8, 13, 20, 22, 24, 29, 33, 37, 41, 44, 48],
		"speed": [4], "bomb_pass": [9, 14, 18, 21, 25, 35, 43, 47],
		"wall_pass": [10, 16, 31, 39, 42, 46],
		"flame_pass": [30, 36, 49], "invulnerability": [26, 34, 40, 45, 50]
	}
	var pinned_ok := true
	for kind in required:
		for n in required[kind]:
			pinned_ok = pinned_ok and ClassicStagePlan.stage(n).get("sealed_prize") == kind
	test.check(pinned_ok, "classic100: every owner-specified prize on stages 1-50 stays fixed")
	var all_rules := true
	var previous_enemies := 0
	for n in range(1, 101):
		var d := ClassicStagePlan.stage(n)
		var config := ClassicStagePlan.rules_for(CLASSIC, n)
		all_rules = all_rules and config.width == d.width and config.height == d.height
		all_rules = all_rules and config.level_seconds == d.level_seconds and not config.full_powerups
		all_rules = all_rules and d.enemy_count >= previous_enemies
		previous_enemies = d.enemy_count
	test.check(all_rules, "classic100: map sizes, timers and enemy counts follow progressive plan")
	var state := GameState.new()
	state.start(CLASSIC, "classic", 50, 731)
	test.check(state.config.width == ClassicStagePlan.stage(51).width and state.config.height == ClassicStagePlan.stage(51).height and state.actors.size() == int(ClassicStagePlan.stage(51).enemy_count) + 1, "release51: final stage follows its preserved catalog configuration")
	for actor in state.actors:
		if actor.enemy:
			actor.alive = false
	state.exit_revealed = true
	state.board.cells[state.board.exit_cell] = GridBoard.Cell.FLOOR
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	test.check(state.result == "CLASSIC_DONE", "release51: stage 51 completes launch Campaign without stage 52")

	test.check(ReleasePlan.stage_available(51) and not ReleasePlan.stage_available(52) and not ReleasePlan.stage_available(0), "release51: official launch boundary is enforced")
	test.check(not ClassicStagePlan.stage(100).is_empty(), "release51: future plan retained without enabling future gameplay")
	state.start(CLASSIC, "classic", 51, 731)
	test.check(state.result == "INVALID_LEVEL" and state.actors.is_empty(), "release51: direct simulation cannot start stage 52")
	test.check(ArcadeLevelRegistry.load_stage(52).is_empty() and ArcadeLevelRegistry.load_stage(100).is_empty(), "release51: official Arcade refuses future stages")

	state.start(CLASSIC, "classic", 0, 731)
	var prize := ClassicStagePlan.PRIZE_CELL
	state.board.cells[prize + Vector2i.UP] = GridBoard.Cell.FLOOR
	state.bombs.place(prize + Vector2i.UP, 0, 1, 1, 0, 1)
	state.advance()
	var initial_enemies := state.alive_enemies()
	test.check(state.powerups.get(prize) == "range" and initial_enemies == 2, "classic100: first blast reveals prize without penalty")
	state.bombs = BombSystem.new()
	state.bombs.place(prize + Vector2i.UP, 0, 1, 1, state.tick, 1)
	state.advance()
	test.check(state.alive_enemies() == initial_enemies + CLASSIC.exit_penalty_enemies and not state.powerups.has(prize), "classic100: rebombing exposed reward removes it and spawns aggressive reinforcements")
	state.advance()
	test.check(state.alive_enemies() == initial_enemies + CLASSIC.exit_penalty_enemies, "classic100: fire persists but never double-spawns reward penalty")

	state.start(CLASSIC, "classic", 0, 731)
	state.level_ticks = state.config.level_seconds * state.config.ticks_per_game_second - 1
	state.advance()
	var aggressive := true
	for actor in state.actors:
		if actor.enemy and actor.alive:
			aggressive = aggressive and actor.role == "warden" and actor.wall_pass
	test.check(state.penalty_phase and aggressive and state.alive_enemies() >= 6, "classic100: timeout upgrades surviving foes and spawns aggressive reinforcements")

	var progress := ClassicCampaignProgress.new()
	progress.path = "user://qa_classic_100.json"
	clean(progress.path)
	test.check(progress.reset_run() == OK and progress.stage == 1 and progress.lives == 3, "classic100: new run starts at stage one with three lives")
	var hero := {"capacity": 3, "radius": 4, "step": 7, "remote": true}
	test.check(progress.record_clear(1, hero, 500) == OK and progress.stage == 2 and progress.lives == 4, "classic100: each first clear unlocks next stage and awards one life")
	test.check(progress.record_clear(1, hero, 500) != OK and progress.lives == 4, "classic100: duplicate clear cannot farm extra lives")
	var restored := ClassicCampaignProgress.new()
	restored.path = progress.path
	restored.load_profile()
	test.check(restored.stage == 2 and restored.lives == 4 and restored.carry.get("remote") == true, "classic100: completed stage, lives, powers and score survive reload")
	test.check(restored.record_loss() == OK and restored.lives == 3 and not restored.carry.has("remote") and restored.carry.get("capacity") == 3, "classic100: death costs a life and removes temporary/special powers")
	progress.stage = 51
	progress.completed = false
	test.check(progress.record_clear(51, hero, 900) == OK and progress.completed and progress.stage == 51, "release51: final clear persists completion and never unlocks 52")
	restored.load_profile()
	test.check(restored.completed and restored.stage == 51 and restored.cleared.has(51), "release51: launch completion survives reload")
	progress.completed = false
	progress.stage = 52
	test.check(progress.record_clear(52, hero, 1000) != OK, "release51: future profile cannot record an unavailable stage")
	progress.stage = 80
	progress.score = 12345
	progress.write_profile()
	restored.load_profile()
	test.check(restored.stage == 80 and restored.score == 12345, "release51: legacy future progress is retained without truncation")
	clean(progress.path)
