extends RefCounted
func run(test: SceneTree) -> void:
	var state := GameState.new()
	var data := ArcadeLevelRegistry.load_stage(1)
	state.start_map(data,1)
	state.bombs.fire[state.actors[0].cell]=30;state.apply_damage();state.check_end()
	test.check(state.result=="DEFEAT" and state.defeat_reason=="DEATH_BLAST", "feedback: blast cause comes from actual fatal damage")
	state.start_map(data,1)
	state.actors[1].cell=state.actors[0].cell;state.apply_contact();state.check_end()
	test.check(state.result=="DEFEAT" and state.defeat_reason=="DEATH_CONTACT", "feedback: contact cause differs from blast")
	var timed:=data.duplicate(true);timed.rules.time_limit=1
	state.start_map(timed);state.level_ticks=59;state.advance()
	test.check(state.result=="DEFEAT" and state.defeat_reason=="DEATH_TIMEOUT", "feedback: actual custom timer expiry reports time limit")
	state.start_map(data,1)
	test.check(state.defeat_reason.is_empty() and state.activity.pickups==0,"feedback: restart resets attempt diagnostics")
	state.collect(state.actors[0],"capacity");state.collect(state.actors[0],"capacity")
	test.check(state.activity.pickups==2 and state.score==50,"feedback: repeated same-kind pickups count individually")
	var coop: Dictionary = CustomMapGenerator.generate({"mode":"coop","enemy_kind":"chaser"},77).data
	state.start_map(coop)
	state.collect(state.actors[1],"range")
	test.check(state.activity.pickups==1 and state.score==25,"feedback: player two contributes shared pickup count")
	for cell in state.board.cells:
		if state.board.kind(cell)!=GridBoard.Cell.WALL:state.board.cells[cell]=GridBoard.Cell.FLOOR
	for x in range(1,12):state.board.cells[Vector2i(x,5)]=GridBoard.Cell.FLOOR
	state.actors[0].cell=Vector2i(2,5);state.actors[0].alive=false
	state.actors[1].cell=Vector2i(10,5)
	state.actors[2].cell=Vector2i(6,5);state.actors[2].role="chaser"
	for index in range(3,state.actors.size()):state.actors[index].alive=false
	var command:=EnemyAI.classic_command(state.actors[2],state)
	test.check(command.get("move")==Vector2i.RIGHT,"coop: pursuit follows surviving player instead of dead player one")
	var scene = load("res://scenes/main.tscn").instantiate();test.root.add_child(scene);await test.process_frame
	scene.official.save.path="user://qa_feedback_official.json";scene.official.save.unlocked=0;scene.official.save.arcade_records.clear()
	scene.start_official(1);scene.state.paused=true
	scene.hud.notify_pickup("range")
	scene.start_official(1);scene.state.paused=true
	test.check(not scene.hud.toast_frame.visible and scene.hud.toast_time==0,"feedback: restart clears stale pickup panel and timeout")
	scene.hud.update_state(scene.state)
	test.check(not scene.hud.hint.text.contains(TranslationServer.translate("HIDDEN_GOAL")),"feedback: official Arcade never advertises a hidden exit")
	scene.profile.settings=GameSettings.new()
	test.check(scene.profile.settings.rebind("p1_detonate",KEY_Q).is_empty(),"feedback: custom remote key accepted for prompt test")
	InputRouter.install(scene.profile.settings.bindings)
	scene.state.collect(scene.state.actors[0],"remote");scene.hud.update_state(scene.state)
	test.check(scene.hud.metrics.text.contains(TranslationServer.translate("POWER_REMOTE")) and scene.hud.hint.text.contains(InputRouter.key_label("p1_detonate")),"feedback: Arcade shows remote ability and current detonation binding")
	scene.pause_game();var before: Dictionary = scene.state.snapshot()
	scene.handle_action("guide");scene.handle_action("guide_bonuses");scene.handle_action("guide_next");scene.handle_action("guide_home");scene.handle_action("guide_enemies");scene.handle_action("guide_home");scene.handle_action("guide_back")
	test.check(scene.screen=="pause" and scene.state.snapshot()==before,"guide: browsing from pause preserves the complete attempt")
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(test,locale);scene.profile.language=locale
		scene.show_bonus_guide();scene.show_enemy_guide()
		test.check(scene.hud.column.get_child(0).text==TranslationServer.translate("GUIDE_ENEMIES"),locale+": guide headings and descriptions use current language")
	LanguageCatalog.apply(test,"en")
	scene.state.paused=false
	scene.state.bombs.fire[scene.state.actors[0].cell]=scene.state.tick+30
	scene.state.advance()
	test.check(scene.screen=="result" and scene.state.defeat_reason=="DEATH_BLAST","feedback: fatal simulation reaches explanatory result screen")
	test.check(not scene.hud.column.get_child(2).text.contains(TranslationServer.translate("BEST_TIME") % "00:00.00"),"feedback: absent record never appears as a zero-time personal best")
	var event:=InputEventJoypadButton.new();event.device=1;event.button_index=JOY_BUTTON_X;event.pressed=true
	scene._unhandled_input(event)
	test.check(scene.screen=="result","quick retry: second controller cannot reset the solo player's attempt")
	event.device=0;scene._unhandled_input(event)
	test.check(scene.screen=="playing" and scene.state.level==0 and scene.state.level_ticks==0 and scene.state.score==0 and scene.state.defeat_reason.is_empty(),"quick retry: player one X starts same stage with clean attempt")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scene.official.save.path+suffix):DirAccess.remove_absolute(scene.official.save.path+suffix)
	scene.queue_free();await test.process_frame
