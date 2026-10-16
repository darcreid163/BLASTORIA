extends SceneTree
var valid: bool = true
func _initialize() -> void:call_deferred("run")
func require(condition: bool,title: String) -> void:
	valid=valid and condition;print("PASS: " if condition else "FAIL: ",title)
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.official.save.path="user://qa_export_feedback_records.json";scene.official.save.unlocked=0
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self,locale);scene.profile.language=locale
		for page in range(2):scene.guide_page=page;scene.show_bonus_guide()
		scene.show_enemy_guide()
		require(scene.hud.column.get_child(0).text==TranslationServer.translate("GUIDE_ENEMIES"),locale+": shipped guide and vector badges load")
	LanguageCatalog.apply(self,"en")
	scene.start_official(1);scene.state.paused=true
	scene.profile.settings=GameSettings.new()
	require(scene.profile.settings.rebind("p1_detonate",KEY_Q).is_empty(),"release: remote key can be rebound")
	InputRouter.install(scene.profile.settings.bindings)
	scene.state.collect(scene.state.actors[0],"remote");scene.hud.update_state(scene.state)
	require(scene.hud.metrics.text.contains(TranslationServer.translate("POWER_REMOTE")) and scene.hud.hint.text.contains(InputRouter.key_label("p1_detonate")),"release: active ability and rebound detonation prompt are visible")
	scene.pause_game();var before: Dictionary=scene.state.snapshot()
	scene.handle_action("guide");scene.handle_action("guide_bonuses");scene.handle_action("guide_home");scene.handle_action("guide_back")
	require(scene.screen=="pause" and before==scene.state.snapshot(),"release: help browsing does not consume or reset active attempt")
	scene.state.paused=false;scene.state.bombs.fire[scene.state.actors[0].cell]=scene.state.tick+30;scene.state.advance()
	require(scene.screen=="result" and scene.state.defeat_reason=="DEATH_BLAST","release: real death opens explanatory result")
	var text: String=scene.hud.column.get_child(2).text
	require(text.contains(TranslationServer.translate("DEATH_BLAST")) and text.contains(TranslationServer.translate("PICKUPS_COLLECTED")),"release: reason and score breakdown reach actual result UI")
	var event:=InputEventJoypadButton.new();event.device=0;event.button_index=JOY_BUTTON_X;event.pressed=true;scene._unhandled_input(event)
	require(scene.screen=="playing" and scene.state.level_ticks==0 and scene.state.activity.pickups==0 and not scene.hud.toast_frame.visible,"release: X repeats same stage with clean state and notifications")
	scene.queue_free();await process_frame;await process_frame
	print("FEEDBACK EXPORT: ","PASS" if valid else "FAIL");quit(0 if valid else 1)
