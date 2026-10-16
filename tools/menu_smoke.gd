extends SceneTree
var scene: Node
var valid: bool = true
func _initialize() -> void: call_deferred("run")
func require(condition: bool, title: String) -> void:
	valid = valid and condition
	print("PASS: " if condition else "FAIL: ", title)
func buttons(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons(child))
	return result
func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate(); root.add_child(scene)
	await process_frame
	for locale in LanguageCatalog.LOCALES:
		scene.profile.language = locale; LanguageCatalog.apply(self, locale); scene.show_main_menu()
		var all := buttons(scene.hud.column)
		var cards := all.filter(func(button): return button.has_meta("mode"))
		require(cards.size() == 3, locale + ": exactly three main modes")
		for index in range(3):
			scene.show_main_menu(); buttons(scene.hud.column)[index].pressed.emit()
			require(scene.screen == ["official_menu", "arena_menu", "adventure_menu"][index], locale + ": mode route " + str(index))
		scene.show_collection_menu(); scene.show_discoveries(); scene.show_secret_hall(); scene.show_achievements(); scene.show_settings(); scene.show_language_list(); scene.show_workshop()
		require(scene.workshop.mode_select.item_count == 4, locale + ": four workshop formats")
		scene.workshop.hide()
	scene.handle_action("campaign_continue")
	require(scene.state.mode == "classic", "saved journey remains accessible inside Adventure")
	scene.handle_action("arena")
	require(scene.state.mode == "arena" and scene.state.actors.size() == 2, "official Arena has two local players")
	scene.queue_free(); await process_frame
	print("MENU SMOKE: ", "PASS" if valid else "FAIL"); quit(0 if valid else 1)
