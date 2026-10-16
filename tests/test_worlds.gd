extends RefCounted

const CLASSIC = preload("res://resources/game_rules/classic.tres")
const ADVENTURE = preload("res://resources/game_rules/adventure.tres")

func fresh(mode: String = "classic") -> GameState:
	var state := GameState.new()
	state.start(CLASSIC if mode == "classic" else ADVENTURE, mode, 0, 731)
	for actor in state.actors:
		if actor.enemy:
			actor.ready = 1000000
	return state

func freeze_clear(state: GameState) -> void:
	for actor in state.actors:
		if actor.enemy:
			actor.alive = false
	for cell in state.board.cells:
		if state.board.kind(cell) == GridBoard.Cell.CRATE:
			state.board.cells[cell] = GridBoard.Cell.FLOOR
	state.exit_revealed = true

func qualified() -> SecretManager:
	var secret := SecretManager.new()
	secret.enabled = true
	for index in [0, 1, 2]:
		secret.visit(index)
	return secret

func cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run(test: SceneTree) -> void:
	var state := fresh()
	test.check(state.actors[0].radius == 1 and state.actors[0].capacity == 1 and state.remaining_seconds() == 200, "classic: explicit one-bomb/range-one/200-second preset")
	test.check(not state.exit_revealed and state.board.kind(state.board.exit_cell) == GridBoard.Cell.CRATE and not state.exit_open(), "classic: exit starts concealed and locked")
	var exit := state.board.exit_cell
	state.board.cells[exit + Vector2i.LEFT] = GridBoard.Cell.FLOOR
	state.bombs.place(exit + Vector2i.LEFT, 0, 1, 1, 0, 1)
	state.advance()
	test.check(state.exit_revealed and not state.exit_open() and state.alive_enemies() == 2, "classic: uncovering exit does not itself spawn punishment")
	for i in range(31): state.advance()
	state.bombs.place(exit + Vector2i.LEFT, 0, 1, 1, state.tick, 1)
	state.advance()
	test.check(state.alive_enemies() == 4, "classic: fresh blast on uncovered exit summons configured reinforcements")
	state.advance()
	test.check(state.alive_enemies() == 4, "classic: lingering fire does not repeatedly spawn enemies")
	for actor in state.actors:
		actor.alive = not actor.enemy
	state.actors[0].cell = exit
	state.bombs = BombSystem.new()
	state.check_end()
	var score := state.score
	state.check_end()
	test.check(state.result == "LEVEL_CLEAR" and state.score == score, "classic: visible exit completes only after enemies and scores once")

	state = fresh()
	state.level_ticks = CLASSIC.level_seconds * CLASSIC.ticks_per_game_second - 1
	state.paused = true
	state.advance()
	test.check(state.remaining_seconds() == 1 and not state.penalty_phase, "classic: paused timer never enters punishment")
	state.paused = false
	state.advance()
	test.check(state.penalty_phase and state.actors[0].alive and state.alive_enemies() == 6, "classic: zero time adds Wardens rather than unexplained instant death")
	state.advance()
	test.check(state.alive_enemies() == 6, "classic: timeout phase starts exactly once")
	state = fresh()
	state.actors[1].cell = Vector2i(2, 1)
	state.advance({0: {"move": Vector2i.RIGHT}})
	test.check(state.result == "DEFEAT", "classic: player contact with enemy is lethal")
	state = fresh()
	state.actors[1].cell = Vector2i(1, 2)
	state.actors[1].ready = 0
	state.actors[1].role = "chaser"
	state.advance()
	test.check(state.result == "DEFEAT", "classic: pursuing enemy can enter player cell")

	state = fresh()
	state.collect(state.actors[0], "remote")
	state.advance({0: {"bomb": true, "move": Vector2i.DOWN}})
	state.actors[0].ready = 0
	state.board.cells[Vector2i(1, 3)] = GridBoard.Cell.FLOOR
	state.advance({0: {"move": Vector2i.DOWN}})
	for i in range(180): state.advance()
	test.check(state.bombs.bombs.size() == 1 and state.actors[0].alive, "powerups: remote bomb waits beyond normal fuse")
	state.advance({0: {"detonate": true}})
	test.check(state.bombs.bombs.is_empty() and state.bombs.fire.has(Vector2i(1, 1)), "powerups: remote input resolves bomb on simulation tick")
	var system := BombSystem.new()
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.FLOOR
	system.place(Vector2i(1, 1), 0, 3, 2, 0, 100, true)
	system.place(Vector2i(3, 1), 1, 2, 1, 0, 1)
	system.advance(1, state.board, 30)
	test.check(system.bombs.is_empty(), "powerups: ordinary blast chains a remote bomb")

	state = fresh()
	state.board.cells[Vector2i(2, 1)] = GridBoard.Cell.CRATE
	state.collect(state.actors[0], "wall_pass")
	state.advance({0: {"move": Vector2i.RIGHT}})
	test.check(state.actors[0].cell == Vector2i(2, 1) and not state.can_enter(state.actors[0], Vector2i(2, 2)), "powerups: Wall Pass crosses crates but never solid walls")
	state.advance({0: {"bomb": true}})
	test.check(state.bombs.bombs.is_empty(), "powerups: no bomb can be hidden inside solid crate terrain")
	state = fresh()
	state.bombs.place(Vector2i(2, 1), 1, 1, 1, 0, 150)
	state.collect(state.actors[0], "bomb_pass")
	state.advance({0: {"move": Vector2i.RIGHT}})
	test.check(state.actors[0].cell == Vector2i(2, 1), "powerups: Bomb Pass enters an occupied bomb cell")
	state.collect(state.actors[0], "flame_pass")
	state.bombs.fire[Vector2i(2, 1)] = state.tick + 100
	state.advance()
	test.check(state.actors[0].alive, "powerups: Flame Pass protects against active fire")
	state.bombs.fire.clear()
	state.actors[1].cell = state.actors[0].cell
	state.advance()
	test.check(state.result == "DEFEAT", "powerups: Flame Pass does not protect against contact")
	state = fresh()
	state.collect(state.actors[0], "invulnerability")
	state.actors[1].cell = state.actors[0].cell
	state.tick = state.actors[0].invulnerable_until - 2
	state.advance()
	test.check(state.actors[0].alive, "powerups: temporary invulnerability protects through last valid tick")
	state.advance()
	test.check(state.result == "DEFEAT", "powerups: temporary invulnerability expires exactly at boundary")

	state = fresh()
	test.check(state.hidden_powerups.size() == 1 and state.hidden_powerups.get(ClassicStagePlan.PRIZE_CELL) == "range", "classic100: stage one has exactly one sealed Fire Up prize")
	var prize := ClassicStagePlan.PRIZE_CELL
	state.board.cells[prize + Vector2i.UP] = GridBoard.Cell.FLOOR
	state.bombs.place(prize + Vector2i.UP, 0, 1, 1, 0, 1)
	state.advance()
	test.check(state.powerups.size() == 1 and state.powerups.has(prize) and state.hidden_powerups.is_empty(), "classic100: blast exposes exactly one stage-specific prize")
	state.bombs = BombSystem.new()
	state.actors[0].cell = prize
	state.advance()
	test.check(state.actors[0].radius == 2 and state.actors[0].capacity == 1 and state.powerups.is_empty(), "classic100: collectible Fire Up changes only blast radius")

	var maps_ok := true
	var abilities_ok := true
	for seed_value in range(40):
		state.start(ADVENTURE, "adventure", 0, seed_value)
		var reachable := state.board.reachable(Vector2i(1, 1), true)
		for cell in state.board.cells:
			if state.board.kind(cell) != GridBoard.Cell.WALL and not reachable.has(cell): maps_ok = false
		for cell in state.board.landmarks + [SecretManager.DEFINITION.niche, state.board.exit_cell]:
			maps_ok = maps_ok and reachable.has(cell)
		abilities_ok = abilities_ok and state.hidden_powerups.size() == 8
		for cell in state.hidden_powerups:
			abilities_ok = abilities_ok and state.board.kind(cell) == GridBoard.Cell.CRATE
	test.check(maps_ok and state.board.width == 41 and state.board.height == 31, "large worlds: 40 seeds connect all traversable cells, landmarks, niche and exit")
	test.check(abilities_ok and state.board.kind(SecretManager.DEFINITION.niche) == GridBoard.Cell.FLOOR, "large worlds: eight powers guaranteed under crates; starting niche empty")
	state = fresh("adventure")
	var far_cell := Vector2i(35, 25)
	state.board.cells[far_cell] = GridBoard.Cell.FLOOR
	state.bombs.place(far_cell, 0, 1, 1, 0, 1)
	state.advance()
	test.check(state.bombs.fire.has(far_cell), "large worlds: off-screen bomb detonates without a camera")
	state.actors[1].ready = 0
	var previous: Vector2i = state.actors[1].cell
	state.advance()
	test.check(state.actors[1].cell != previous, "large worlds: distant enemy continues moving without visual nodes")
	var second := fresh("adventure")
	state = fresh("adventure")
	for i in range(240):
		state.advance()
		second.advance()
	test.check(state.snapshot() == second.snapshot(), "large worlds: identical seed and commands replay deterministically")

	state = fresh("adventure")
	test.check(state.exploration.percent() < 10 and not state.exploration.known.has(state.board.exit_cell), "map: initial fog conceals distant exit and most terrain")
	var unseen := Vector2i(35, 25)
	state.board.cells[unseen] = GridBoard.Cell.FLOOR
	state.exploration.reveal(state.board, Vector2i(1, 1), true)
	test.check(not state.exploration.known.has(unseen), "map: remote destruction does not disclose unexplored terrain")
	state.exploration.reveal(state.board, unseen)
	test.check(state.exploration.known.has(unseen), "map: arriving discovers local terrain")
	state.board.cells[unseen] = GridBoard.Cell.CRATE
	state.exploration.reveal(state.board, Vector2i(1, 1))
	test.check(state.exploration.known[unseen] == GridBoard.Cell.FLOOR, "map: distant terrain retains last observed state")
	var camera := FollowCamera.new()
	var bounds_ok := true
	for aspect in [1.25, 1.6, 16.0 / 9, 21.0 / 9]:
		for player in [Vector3(-20, 0, -15), Vector3(20, 0, 15), Vector3.ZERO]:
			var target := camera.target(player, 41, 31, 16, aspect)
			bounds_ok = bounds_ok and absf(target.x) + 8 * aspect <= 20.501 and absf(target.z) + 8 * FollowCamera.OFFSET.length() / 17 <= 15.501
	test.check(bounds_ok, "camera: entire ground footprint stays inside 41x31 at four aspect ratios")

	var secret := qualified()
	test.check(not secret.finish(89, 100) and secret.finish(90, 100), "secret: exact exploration threshold and completion required")
	test.check(secret.collect(Vector2i(9, 9)) == 0 and secret.collect(SecretManager.DEFINITION.niche) == 50000 and secret.collect(SecretManager.DEFINITION.niche) == 0, "secret: physical niche pickup awards 50000 exactly once")
	secret = qualified()
	secret.map_used = true
	test.check(not secret.finish(100, 100), "secret: any map use disqualifies compass")
	secret = qualified()
	secret.damaged = true
	test.check(not secret.finish(100, 100), "secret: damage disqualifies compass")
	secret = SecretManager.new()
	secret.enabled = true
	for index in [1, 0, 1, 2]: secret.visit(index)
	test.check(not secret.finish(100, 100), "secret: wrong first-visit order cannot be repaired by revisiting")
	secret = qualified()
	secret.visit(0)
	test.check(secret.finish(90, 100), "secret: revisiting already found landmark is harmless")
	secret = qualified()
	secret.enabled = false
	test.check(not secret.finish(100, 100), "secret: disabled modes never produce secret rewards")
	state = fresh("adventure")
	freeze_clear(state)
	# Deterministic developer fixture supplies prior exploration, not a shipped cheat action.
	for cell in state.board.cells: state.exploration.reveal(state.board, cell)
	for cell in state.board.landmarks:
		state.actors[0].cell = cell
		state.advance()
	state.actors[0].cell = state.board.exit_cell
	state.advance()
	var completion_tick := state.level_ticks
	test.check(state.completion_walk and state.result.is_empty() and state.secrets.revealed, "secret integration: eligible completion opens a playable return to the niche")
	state.actors[0].cell = SecretManager.DEFINITION.niche
	state.advance()
	test.check(state.result == "ADVENTURE_DONE" and state.score == 50500 and state.level_ticks == completion_tick, "secret integration: collection completes level, score includes reward, epilogue excludes timer")
	state.start(ADVENTURE, "adventure", 0, 731)
	test.check(not state.secrets.revealed and state.secrets.visited.is_empty() and state.exploration.percent() < 10, "secret integration: retry resets exploration and secret progress")

	var bad_keys := GameSettings.DEFAULT_KEYS.duplicate()
	bad_keys.p1_up = NAN
	var safe_settings := GameSettings.new()
	safe_settings.read_data({"bindings": bad_keys})
	test.check(safe_settings.bindings == GameSettings.DEFAULT_KEYS, "settings: non-finite key codes rejected without integer conversion")

	var path := "user://qa_worlds_profile.json"
	cleanup(path)
	var old_keys := GameSettings.DEFAULT_KEYS.duplicate()
	old_keys.erase("p1_detonate")
	old_keys.erase("p2_detonate")
	old_keys.p1_up = KEY_E
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 3, "unlocked": 2, "language": "en", "arcade_records": {"arcade_v1": {"score": 1234, "score_ticks": 400, "best_ticks": 0}}, "settings": {"bindings": old_keys, "master": 0.3}}))
	file.close()
	var save := SaveManager.new()
	save.path = path
	save.read_profile(2)
	test.check(save.unlocked == 2 and save.record_for("arcade_v1").score == 1234 and save.settings.bindings.p1_up == KEY_E and save.settings.bindings.p1_detonate != KEY_E, "save v4: old campaign, Arcade and custom keys survive migration with collision-free remote key")
	test.check(save.record_secret("ghost_compass") and not save.record_secret("ghost_compass") and not save.record_secret("unknown"), "save v4: collection rejects duplicate and unknown artifact")
	test.check(save.write_profile() == OK, "save v4: collection writes with settings")
	var loaded := SaveManager.new()
	loaded.path = path
	loaded.read_profile(2)
	test.check(loaded.artifacts == [SecretDefinition.active().id] and loaded.settings.bindings == save.settings.bindings, "save v4: collection and migrated controls reload")

	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.profile = loaded
	scene.handle_action("adventure")
	test.check(scene.state.board.width == 41 and not scene.state.secrets.enabled and not scene.hud.map_view.visible, "UI: Adventure starts large map; owned compass and hidden minimap respected")
	scene.toggle_map()
	test.check(scene.hud.map_view.visible and scene.state.secrets.map_used, "UI: opening minimap records use")
	scene.toggle_map()
	test.check(scene.hud.map_view.expanded, "UI: second map action opens expanded explored map")
	scene.pause_game()
	test.check(not scene.hud.map_view.visible, "UI: pause hides map over menus")
	scene.handle_action("resume")
	test.check(scene.hud.map_view.visible, "UI: resume restores chosen map view")
	var old_position: Vector3 = scene.view.camera.position
	scene.state.actors[0].cell = Vector2i(39, 29)
	scene.view.sync(scene.state, 0.1)
	test.check(scene.view.camera.position != old_position and scene.view.follow.center.x < 7.8, "UI: real Camera3D follows smoothly rather than snapping to far corner")
	scene.handle_action("classic_start")
	scene.state.actors[0].capacity = 3
	scene.state.actors[0].remote = true
	scene.state.score = 200
	scene.state.result = "LEVEL_CLEAR"
	scene.on_finished("LEVEL_CLEAR")
	scene.handle_action("next")
	test.check(scene.state.level == 1 and scene.state.actors[0].capacity == 3 and scene.state.actors[0].remote and scene.state.score == 200, "UI: classic progression carries score and permanent powers")
	scene.state.score += 999
	scene.handle_action("retry")
	test.check(scene.state.score == 200, "UI: classic retry rolls score back to stage entry, preventing retry farming")
	test.check(scene.state.actors[0].capacity == 3 and not scene.state.actors[0].remote, "UI: classic retry retains Bomb/Fire Up and resets special powers")
	scene.state.pending_penalty = 2
	scene.state.spawn_penalties()
	scene.view.sync(scene.state, 0)
	test.check(scene.view.actors.size() == scene.state.actors.size(), "UI: reinforcement actors receive real 3D views")
	scene.handle_action("menu")
	await test.process_frame
	await test.process_frame
	test.check(scene.hud.column.size.y < 800, "UI: expanded main menu fits base viewport height")
	scene.queue_free()
	await test.process_frame
	cleanup(path)
	InputRouter.install()
