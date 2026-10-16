extends SceneTree
var scene: Node
var bounds := {}

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_070/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa_070")
	scene = load("res://scenes/main.tscn").instantiate(); root.add_child(scene)
	await process_frame
	for locale in LanguageCatalog.LOCALES:
		scene.profile.language = locale
		LanguageCatalog.apply(self, locale)
		scene.show_main_menu()
		await capture("menu_" + locale)
		var fits: bool = scene.hud.column.get_global_rect().end.y <= 800 and scene.hud.column.get_global_rect().end.x <= 1280
		var cards: Node = scene.hud.column.get_child(3)
		for card in cards.get_children():
			var box: Node = card.get_child(0)
			for label in box.get_children():
				fits = fits and card.get_global_rect().encloses(label.get_global_rect())
		bounds[locale] = fits
	LanguageCatalog.apply(self, "ar"); scene.profile.language = "ar"
	scene.show_workshop(); await capture("workshop_ar")
	LanguageCatalog.apply(self, "en"); scene.profile.language = "en"
	scene.show_workshop(); await capture("workshop_en")
	scene.workshop.hide(); scene.show_settings(); await capture("settings_en")
	scene.show_language_list(); await capture("languages")
	scene.show_workshop(); scene.workshop.import_dialog(); await capture("file_picker")
	for child in scene.workshop.get_children():
		if child is Window: child.queue_free()
	scene.workshop.hide(); scene.start_official(1); scene.state.paused = true
	await capture("level_en")
	scene.start_game("arena", 0); scene.state.paused = true
	await capture("arena_en")
	var file := FileAccess.open("res://docs/qa/menu_bounds.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(bounds, "  "))
	print("VISUAL CAPTURE: ", bounds)
	scene.queue_free(); await process_frame; quit()
