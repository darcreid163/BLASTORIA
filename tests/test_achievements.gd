extends RefCounted

func cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)

func manager(path: String) -> AchievementManager:
	var value := AchievementManager.new()
	value.path = path
	value.award_enabled = true # Isolated QA override; debug UI never exposes it.
	return value

func run(test: SceneTree) -> void:
	var path := "user://qa_achievements.progress"
	cleanup(path)
	var progress := manager(path)
	progress.award_enabled = false
	progress.grant("ACH_FIRST_BLAST")
	test.check(progress.progress.earned.is_empty(), "achievements: debug-disabled manager cannot grant even directly")
	progress.award_enabled = true
	progress.grant("ACH_SECRET_DISCOVERER")
	test.check(progress.progress.earned.is_empty(), "achievements: local manager cannot grant server/hidden achievement")
	var config := GameConfig.new()
	var state := GameState.new()
	state.start(config, "tutorial", 0, 0)
	progress.observe(state)
	test.check(progress.progress.earned.is_empty(), "achievements: entering a mode is not an achievement event")
	state.advance({0: {"bomb": true}})
	state.advance({0: {"bomb": true}})
	progress.observe(state)
	test.check(state.activity.bombs == 1 and not progress.progress.earned.has("ACH_FIRST_BLAST"), "achievements: rejected duplicate bomb not counted; placement alone not sufficient")
	state.actors[0].invulnerable_until = 1000
	for i in range(config.fuse_ticks): state.advance()
	progress.observe(state)
	test.check(progress.progress.earned.has("ACH_FIRST_BLAST") and state.activity.detonations == 1, "achievements: actual player bomb detonation unlocks First blast")
	var earned_at = progress.progress.earned.ACH_FIRST_BLAST
	progress.observe(state)
	test.check(progress.progress.earned.ACH_FIRST_BLAST == earned_at and progress.progress.pending.count("ACH_FIRST_BLAST") == 1, "achievements: same event never duplicates date or Steam pending item")
	var loaded := manager(path)
	loaded.read_progress()
	test.check(loaded.progress.earned == progress.progress.earned and loaded.progress.pending == progress.progress.pending, "achievements: offline unlock and pending sync survive reload")
	var rows := loaded.display_rows("ru")
	var names_ok := true
	for row in rows:
		if row.has("id") or row.title.begins_with("ACH_") or not FileAccess.file_exists(row.icon): names_ok = false
	test.check(names_ok and rows.size() == 17, "achievements: public presentation includes icons/localized names, no API IDs or future definitions")
	var board := GridBoard.new()
	board.generate(config, RandomNumberGenerator.new(), false)
	for cell in board.cells:
		if board.kind(cell) == GridBoard.Cell.CRATE: board.cells[cell] = GridBoard.Cell.FLOOR
	var bombs := BombSystem.new()
	for x in [1, 3, 5, 7, 9]: bombs.place(Vector2i(x, 1), 0, 2, 5, 0, 1)
	bombs.advance(1, board, 30)
	test.check(bombs.detonations_this_tick == 5 and bombs.max_player_chain_this_tick == 1, "chain metrics: five independent same-tick fuses are not a five-bomb chain")
	bombs = BombSystem.new()
	for x in [1, 3, 5, 7, 9]: bombs.place(Vector2i(x, 1), 0, 2, 5, 0, 1 if x == 1 else 100)
	bombs.advance(1, board, 30)
	test.check(bombs.max_player_chain_this_tick == 5, "chain metrics: five causally triggered bombs count as one chain")
	state.start(config, "arena", 0, 1)
	state.activity.max_chain = bombs.max_player_chain_this_tick
	progress.observe(state)
	test.check(progress.progress.earned.has("ACH_CHAIN_5"), "achievements: causal chain metric unlocks Chain reaction")
	state.start(config, "arena", 0, 1)
	for cell in state.board.cells:
		if state.board.kind(cell) == GridBoard.Cell.CRATE: state.board.cells[cell] = GridBoard.Cell.FLOOR
	state.add_actor(Vector2i(3, 1), true)
	state.bombs.place(Vector2i(3, 1), 0, 1, 1, 0, 1)
	state.advance()
	test.check(state.activity.kills == 1, "achievement stats: actual player flame receives enemy kill credit")
	progress.observe(state)
	var kills: int = progress.progress.stats.kills
	progress.observe(state)
	test.check(progress.progress.stats.kills == kills, "achievement stats: polling same kill does not increment twice")
	state.start(config, "arena", 0, 1)
	state.add_actor(Vector2i(3, 1), true)
	state.bombs.place(Vector2i(3, 1), 2, 1, 1, 0, 1)
	state.advance()
	test.check(state.activity.kills == 0, "achievement stats: enemy suicide does not count as player kill")
	var custom := CustomMapGenerator.generate({"bonus_count": 0}, 491).data as Dictionary
	state.start_map(custom)
	state.activity.kills = 9999
	progress.observe(state)
	test.check(progress.progress.stats.kills == kills, "achievements: custom/test map cannot farm official mastery counters")
	state.start(config, "arena", 0, 1)
	state.activity.kills = 1000
	state.activity.crates = 1000
	progress.observe(state)
	test.check(progress.progress.earned.has("ACH_ENEMIES_100") and progress.progress.earned.has("ACH_ENEMIES_1000") and progress.progress.earned.has("ACH_BLOCKS_1000"), "achievements: cumulative kill/crate thresholds unlock correctly")
	loaded = manager(path); loaded.read_progress()
	loaded.observe(state)
	test.check(loaded.progress.stats.kills == progress.progress.stats.kills, "achievements: persisted attempt cursor prevents replayed counter delta after reload")
	state.start(config, "arena", 0, 1)
	for kind in MapValidationService.POWERS: state.collect(state.actors[0], kind)
	progress.observe(state)
	test.check(progress.progress.earned.has("ACH_POWERUP_MASTER"), "achievements: all power categories in one eligible attempt unlock Full arsenal")
	state.start(preload("res://resources/game_rules/classic.tres"), "classic", 0, 1)
	for actor in state.actors:
		if actor.enemy: actor.alive = false
	state.exit_revealed = true
	state.actors[0].cell = state.board.exit_cell
	state.check_end()
	progress.observe(state)
	test.check(state.result == "LEVEL_CLEAR" and progress.progress.earned.has("ACH_FIRST_VICTORY"), "achievements: first Classic Campaign clear unlocks First step")
	state.start(preload("res://resources/game_rules/adventure.tres"), "adventure", 0, 1)
	for cell in state.board.cells:
		if state.board.kind(cell) != GridBoard.Cell.WALL: state.exploration.known[cell] = state.board.kind(cell)
	progress.observe(state)
	test.check(progress.progress.earned.has("ACH_MAZE_EXPLORER"), "achievements: actual exploration state unlocks Explorer independently of rare secret conditions")
	state.start(config, "arena", 0, 1)
	state.actors[1].alive = false
	state.advance(); progress.observe(state)
	test.check(not progress.progress.earned.has("ACH_ARENA_FIRST"), "arena achievements: instant/idle match cannot qualify")
	for i in range(50):
		state.start(config, "arena", 0, 1)
		state.level_ticks = 1800
		state.activity.steps = [3, 3]
		state.activity.placements = [1, 1]
		state.actors[1].alive = false
		state.advance(); progress.observe(state); progress.observe(state)
	test.check(progress.progress.stats.arena_wins == 50 and progress.progress.earned.has("ACH_ARENA_50") and progress.progress.earned.has("ACH_ARENA_10"), "arena achievements: qualifying wins count once per match and reach ten/fifty thresholds")
	state.start(config, "arena", 0, 1)
	state.level_ticks = 1800; state.activity.steps = [3, 3]; state.activity.placements = [1, 1]
	state.actors[0].alive = false
	state.advance(); progress.observe(state)
	test.check(progress.progress.stats.arena_wins == 50 and progress.progress.stats.arena_matches == 51, "arena achievements: player two victory does not count as local player one win")
	var library := CustomMapLibrary.new()
	library.directory = "user://qa_achievement_maps"
	library.saved.connect(func(data: Dictionary): progress.map_event("saved", data))
	library.imported.connect(func(data: Dictionary): progress.map_event("imported", data))
	library.exported.connect(func(data: Dictionary): progress.map_event("exported", data))
	var map := CustomMapGenerator.generate({"bonus_count": 0}, 723).data as Dictionary
	test.check(library.store_map(map) == OK and progress.progress.earned.has("ACH_EDITOR_FIRST"), "workshop achievements: successful validated save unlocks Architect")
	var clone := map.duplicate(true); clone.id = CustomMapLibrary.new_id(); clone.title = "Rename"; clone.seed = 1
	library.store_map(clone)
	test.check(progress.progress.owned.size() == 1, "workshop achievements: ID/title/seed-only copies are not distinct creations")
	var invalid := map.duplicate(true); invalid.rows[1][1] = "#"
	test.check(library.store_map(invalid) != OK and progress.progress.owned.size() == 1, "workshop achievements: invalid save cannot grant or count creation")
	state.start_map(map)
	for actor in state.actors:
		if actor.enemy: actor.alive = false
	state.advance()
	progress.custom_complete(state, false)
	test.check(not progress.progress.earned.has("ACH_EDITOR_PLAY"), "workshop achievements: editor playtest never grants rewards")
	progress.custom_complete(state, true)
	test.check(progress.progress.earned.has("ACH_EDITOR_PLAY"), "workshop achievements: completed owned map in regular play unlocks Self challenge")
	var export_path := "user://qa_achievement_map.blastmap"
	test.check(library.export_map(export_path, map) == OK and progress.progress.earned.has("ACH_EDITOR_SHARE"), "workshop achievements: actual successful file export unlocks Share the world")
	var friend_map := CustomMapGenerator.generate({"bonus_count": 0}, 982).data as Dictionary
	library.write_file(export_path, friend_map)
	var imported := library.import_map(export_path)
	test.check(not imported.is_empty() and progress.progress.owned.size() == 1, "workshop achievements: import does not count as authoring")
	state.start_map(imported)
	for actor in state.actors:
		if actor.enemy: actor.alive = false
	state.advance(); progress.custom_complete(state, true)
	test.check(progress.progress.earned.has("ACH_EDITOR_IMPORT"), "workshop achievements: imported map requires successful play before award")
	for i in range(9): library.store_map(CustomMapGenerator.generate({"bonus_count": 0}, 4000 + i).data)
	test.check(progress.progress.owned.size() == 10 and progress.progress.earned.has("ACH_EDITOR_10"), "workshop achievements: ten distinct geometries unlock Cartographer")
	var before: int = progress.progress.earned.size()
	progress.observe(state); progress.observe(state)
	test.check(progress.progress.earned.size() == before, "achievements: repeat result cannot re-award completed milestones")
	for data in library.list_maps(): library.remove_map(data.id)
	DirAccess.remove_absolute(library.directory); DirAccess.remove_absolute(export_path)
	# Preserve good backup when current encrypted primary is damaged.
	progress.dirty = true; progress.flush()
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string("broken"); file.close()
	loaded = manager(path); loaded.read_progress()
	test.check(loaded.recovered and not loaded.progress.earned.is_empty(), "achievements: corrupted progress recovers authenticated backup")
	loaded.progress.stats.crates += 1; loaded.dirty = true
	test.check(loaded.flush() == OK and AchievementManager.valid_file(path + ".bak"), "achievements: recovery save preserves valid backup")
	file = FileAccess.open(path, FileAccess.WRITE); file.store_buffer(SealedData.seal({"version": 99}, "achievement_progress")); file.close()
	loaded = manager(path); loaded.read_progress()
	test.check(not loaded.writable and loaded.flush() == ERR_UNAVAILABLE, "achievements: future encrypted progress format is never overwritten")
	cleanup(path)
	var blocked := manager("user://missing_achievement_folder/progress.dat")
	blocked.grant("ACH_FIRST_BLAST")
	test.check(blocked.flush() != OK and blocked.dirty and blocked.progress.pending.size() == 1, "achievements: disk failure retains pending unlock in memory for retry")
	var scene = load("res://scenes/main.tscn").instantiate()
	test.root.add_child(scene)
	await test.process_frame
	scene.achievements.path = path
	scene.achievements.award_enabled = true
	scene.show_achievements()
	var content := ""
	for child in scene.hud.column.get_children():
		if child is Label: content += child.text + "\n"
		for nested in child.get_children():
			if nested is Label: content += nested.text + "\n"
	test.check(scene.screen == "achievements" and not content.contains("ACH_") and not content.contains("Первый в мире"), "UI: achievement page shows public labels without API IDs/hidden entries")
	scene.handle_action("achievements_next")
	test.check(scene.achievement_page == 1, "UI: achievements support paginated controller-friendly navigation")
	scene.handle_action("achievements_prev")
	test.check(scene.achievement_page == 0, "UI: achievement pagination returns to first page")
	scene.start_game("tutorial", 0)
	scene.state.actors[0].invulnerable_until = 1000
	scene.state.advance({0: {"bomb": true}})
	for i in range(config.fuse_ticks): scene.state.advance()
	scene.achievements.observe(scene.state)
	test.check(scene.hud.achievement_notice.visible and not scene.hud.achievement_notice.text.contains("ACH_"), "UI: real unlock displays localized achievement notification")
	scene.queue_free()
	await test.process_frame
	cleanup(path)
