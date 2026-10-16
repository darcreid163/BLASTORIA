extends RefCounted
func run(test: SceneTree) -> void:
	var data := ArcadeLevelRegistry.load_stage(11)
	var state := GameState.new(); state.start_map(data,11)
	var water := Vector2i(8,5); var bridge := Vector2i(8,4)
	test.check(state.board.kind(water)==GridBoard.Cell.WATER and state.board.kind(bridge)==GridBoard.Cell.FLOOR, "water: authored channel and bridge load as distinct logical terrain")
	var actor: Dictionary=state.actors[0]; actor.wall_pass=true; actor.bomb_pass=true; actor.flame_pass=true
	test.check(not state.can_enter(actor,water) and state.can_enter(actor,bridge), "water: passage powers do not permit swimming; bridge stays passable")
	actor.cell=Vector2i(7,5); state.advance({0:{"move":Vector2i.RIGHT}})
	test.check(actor.cell==Vector2i(7,5), "water: ordinary movement cannot enter the channel")
	var ray:=state.board.blast(Vector2i(7,5),6)
	test.check(not ray.has(water) and not ray.has(Vector2i(10,5)), "water: blast stops before channel and cannot damage the far bank")
	test.check(state.board.blast(Vector2i(7,4),4).has(Vector2i(10,4)), "water: fire travels across a floor bridge normally")
	state.bombs.place(Vector2i(7,5),0,6,1,state.tick,1); state.bombs.advance(state.tick+1,state.board,30)
	test.check(state.board.kind(water)==GridBoard.Cell.WATER and not state.bombs.fire.has(water), "water: real detonation neither destroys nor ignites the channel")
	var reachable:=state.board.reachable(Vector2i(1,1),true)
	test.check(not reachable.has(water) and reachable.has(Vector2i(22,14)), "water: reachability excludes water and reaches the far bank by bridges")
	var invalid:=data.duplicate(true); invalid.enemies[0].cell=[8,5]
	test.check(not MapValidationService.validate(invalid).is_empty(), "water validation: enemy cannot spawn in channel")
	invalid=data.duplicate(true); invalid.powerups[0].cell=[8,5]
	test.check(not MapValidationService.validate(invalid).is_empty(), "water validation: item cannot be placed in channel")
	invalid=data.duplicate(true)
	for y in range(1,16): invalid.rows[y][8]="~"; invalid.rows[y][9]="~"
	test.check(not MapValidationService.validate(invalid).is_empty(), "water validation: removing every crossing rejects unreachable mandatory enemies")
	var document:=CustomMapDocument.new(); document.replace(data)
	var before:=document.data.duplicate(true)
	document.paint(Vector2i(4,4),Vector2i(4,4),"water",{})
	test.check(document.sample(Vector2i(4,4))=="water" and document.data.rows[4][4]=="~", "workshop: water brush and eyedropper preserve water terrain")
	document.undo(); test.check(document.data==before,"workshop: undo restores exact map before water painting")
	document.redo(); test.check(document.sample(Vector2i(4,4))=="water","workshop: redo restores water brush edit")
	var parsed: Variant=JSON.parse_string(JSON.stringify(document.data))
	test.check(MapValidationService.validate(parsed).is_empty() and parsed.rows==document.data.rows,"workshop: water map survives JSON roundtrip and validation")
	var scene=load("res://scenes/main.tscn").instantiate(); test.root.add_child(scene); await test.process_frame
	scene.official.save.unlocked=10; scene.show_official_menu()
	test.check(scene.stage_page==1 and scene.hud.column.get_child(3).get_child(0).get_meta("stage_action")=="official:11","chapters: first-chapter save automatically selects newly available chapter")
	scene.handle_action("stages_prev"); test.check(scene.stage_page==0,"chapters: previous page returns to stages one through ten")
	scene.handle_action("stages_next"); scene.show_official_records()
	test.check(scene.stage_page==1 and scene.hud.column.get_child(2).text.contains(scene.stage_name(11)) and not scene.hud.column.get_child(2).text.contains(scene.stage_name(1)),"records: chapter two page contains its own ten stages")
	scene.handle_action("records_prev"); test.check(scene.stage_page==0,"records: navigation switches chapter without changing progress")
	scene.official.save.unlocked=3; scene.show_official_records(1); scene.handle_action("official_menu")
	test.check(scene.stage_page==1,"records: returning to Arcade preserves viewed chapter even when it is locked")
	scene.official.save.unlocked=10
	scene.show_official_menu(99); test.check(scene.stage_page==1 and scene.official.save.unlocked==10,"chapters: out-of-range page clamps without unlocking content")
	scene.start_official(11); scene.state.paused=true; scene.hud.update_state(scene.state)
	test.check(scene.hud.hint.text.contains(TranslationServer.translate("WATER_RULES")),"water: actual level HUD explains bridge and blast rule")
	scene.queue_free(); await test.process_frame; await test.process_frame
