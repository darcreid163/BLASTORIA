extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_072/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa_072")
	var scene = load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	var bounds := {}
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self,locale);scene.profile.language=locale
		var fits: bool = true
		for page in range(2):
			scene.guide_page=page;scene.show_bonus_guide();await shot("bonuses_%d_" % page+locale)
			fits=fits and scene.hud.column.size.x<=1280
		scene.show_enemy_guide();await shot("enemies_"+locale)
		fits=fits and scene.hud.column.size.x<=1280
		bounds[locale]=fits
	LanguageCatalog.apply(self,"ru");scene.profile.language="ru";scene.official.save.unlocked=9
	scene.start_official(6);scene.state.paused=true
	scene.state.collect(scene.state.actors[0],"remote");scene.hud.update_state(scene.state);scene.hud.notify_pickup("remote")
	await shot("remote_hud_ru")
	LanguageCatalog.apply(self,"ar");scene.profile.language="ar"
	for kind in MapValidationService.POWERS:scene.state.collect(scene.state.actors[0],kind)
	scene.hud.update_state(scene.state);scene.hud.notify_pickup("invulnerability");await shot("all_powers_ar")
	var hero: Vector2 = scene.view.camera.unproject_position(scene.view.pos(scene.state.actors[0].cell)+Vector3(0,1,0))
	bounds["ar_max_powers_clear"] = hero.y >= scene.hud.top_frame.get_global_rect().end.y + 20
	print("HUD MARGINS: ",hero.y," top=",scene.hud.top_frame.get_global_rect().end.y)
	LanguageCatalog.apply(self,"ru");scene.profile.language="ru"
	scene.start_official(4)
	scene.official.save.path="user://qa_visual_feedback.json"
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade/stage_004.json"))
	for frame in replay.commands:scene.state.advance({0:{"move":Vector2i(int(frame[0]),int(frame[1])),"bomb":frame[2],"detonate":frame[3]}})
	await shot("result_ru")
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self,locale);scene.profile.language=locale;scene.finish_map(scene.state.result);await shot("result_"+locale)
		var rect: Rect2 = scene.hud.column.get_global_rect()
		bounds[locale]=bounds[locale] and rect.position.y>=0 and rect.end.y<=800
	LanguageCatalog.apply(self,"ar");scene.profile.language="ar"
	scene.start_official(1);scene.state.bombs.fire[scene.state.actors[0].cell]=30;scene.state.advance();await shot("defeat_ar")
	var file:=FileAccess.open("res://docs/qa/feedback_bounds.json",FileAccess.WRITE);file.store_string(JSON.stringify(bounds,"  "))
	print("FEEDBACK CAPTURE: ",bounds)
	scene.queue_free();await process_frame;await process_frame;await process_frame;quit()
