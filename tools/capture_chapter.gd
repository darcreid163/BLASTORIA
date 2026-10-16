extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_071/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa_071")
	var scene = load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.official.save.unlocked=9
	var bounds: Dictionary = {}
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self,locale);scene.profile.language=locale;scene.show_official_menu()
		await shot("stages_"+locale)
		var column: Control = scene.hud.column
		var fits: bool = column.get_global_rect().end.x<=1280 and column.get_global_rect().end.y<=800
		var grid: GridContainer = column.get_child(3)
		for button in grid.get_children():
			fits=fits and button.get_global_rect().end.x<=1280 and button.get_global_rect().end.y<=800
		bounds[locale]=fits
	LanguageCatalog.apply(self,"ru");scene.profile.language="ru"
	for number in [4,6,7,10]:
		scene.start_official(number);scene.state.paused=true
		await shot("stage_%02d" % number)
	var file:=FileAccess.open("res://docs/qa/chapter_menu_bounds.json",FileAccess.WRITE);file.store_string(JSON.stringify(bounds,"  "))
	print("CHAPTER CAPTURE: ",bounds)
	scene.queue_free();await process_frame;quit()
