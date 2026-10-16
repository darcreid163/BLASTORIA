extends RefCounted

func run(test: SceneTree) -> void:
	var old_hashes := {1:"4d86b6f635c567c7b2ac4795ce075949e291e0d5566e6b3125d07e0b3198ef91",2:"1d6b8b7d5958cab801908849fb1242cc0cad306181fe51eb271afc8e67f6ba88",3:"cd9532f37151cd14c31c36e29ceb784f0aec1f7e2258be25e8bd5930f3da5200"}
	for number in old_hashes:
		test.check(FileAccess.get_sha256("res://resources/arcade/stage_%03d.json" % number)==old_hashes[number], "chapter: original stage %d bytes and record identity preserved" % number)
	var layouts := {}
	var progress := ArcadeProgressionManager.new()
	progress.save.path = "user://qa_chapter_records.json"
	progress.save.unlocked = 3
	var keys: Array[String] = []
	for number in range(4,11):
		var data := ArcadeLevelRegistry.load_stage(number)
		test.check(not data.is_empty() and MapValidationService.validate(data).is_empty(), "chapter: authored stage %d validates" % number)
		var geometry := JSON.stringify(data.rows).sha256_text()
		test.check(not layouts.has(geometry), "chapter: stage %d has a unique topology" % number)
		layouts[geometry]=true
		var state := GameState.new();state.start_map(data,number)
		var path := "res://tests/fixtures/arcade/stage_%03d.json" % number
		var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		test.check(replay.fingerprint==MapValidationService.fingerprint(data), "chapter: replay belongs to exact stage %d revision" % number)
		var pickup_count := [0]
		state.pickup.connect(func(id: int, _kind: String):
			if id==0: pickup_count[0]+=1)
		for frame in replay.commands:
			state.advance({0:{"move":Vector2i(int(frame[0]),int(frame[1])),"bomb":frame[2],"detonate":frame[3]}})
		test.check(state.result=="MAP_CLEAR" and state.actors[0].alive and state.required_enemies()==0, "chapter: stage %d cleared with ordinary inputs and live enemy AI" % number)
		test.check(state.score==int(replay.score) and state.level_ticks==int(replay.ticks) and state.level_ticks==replay.commands.size(), "chapter: stage %d score and active ticks replay exactly" % number)
		var expected: int = state.activity.crates*state.config.score_crate+state.activity.kills*state.config.score_enemy+pickup_count[0]*state.config.score_pickup+state.config.score_stage_clear+state.time_bonus
		test.check(state.score==expected and state.time_bonus==maxi(0,180-ceili(float(state.level_ticks)/60))*5, "chapter: stage %d actual pickups, kills, crates and time bonus match score" % number)
		var score := state.score;var ticks := state.level_ticks
		state.advance();state.check_end()
		test.check(state.score==score and state.level_ticks==ticks, "chapter: stage %d result cannot tick or score twice" % number)
		test.check(progress.available(number) and progress.complete(state)==OK, "chapter: stage %d normal victory persists and opens progression" % number)
		var key := progress.key_for(data);keys.append(key)
		var record := progress.save.record_for(key)
		test.check(record.score==score and record.best_ticks==ticks, "chapter: stage %d record is independent" % number)
		state.result="DEFEAT"
		test.check(progress.complete(state)==ERR_INVALID_DATA and progress.save.record_for(key)==record, "chapter: stage %d defeat cannot replace clear record" % number)
	var loaded := ArcadeProgressionManager.new();loaded.save.path=progress.save.path;loaded.read_progress()
	test.check(loaded.save.unlocked==10 and loaded.save.arcade_records.size()==7 and loaded.available(11) and not loaded.available(12), "chapter: first chapter reloads completed; stage 11 opens while stage 12 stays locked")
	for key in keys:test.check(loaded.save.record_for(key)==progress.save.record_for(key), "chapter: every stage record survives restart")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(progress.save.path+suffix):DirAccess.remove_absolute(progress.save.path+suffix)
	var scene = load("res://scenes/main.tscn").instantiate();test.root.add_child(scene)
	await test.process_frame
	scene.official.save.unlocked=3
	scene.show_official_menu()
	var grid: GridContainer = scene.hud.column.get_child(3)
	test.check(grid.get_child_count()==10 and not grid.get_child(3).disabled and grid.get_child(4).disabled, "chapter UI: ten stage tiles; saved first-three clear opens fourth only")
	grid.get_child(3).pressed.emit()
	test.check(scene.state.mode=="official_arcade" and scene.state.level==3, "chapter UI: new stage tile enters actual stage four")
	scene.queue_free();await test.process_frame
