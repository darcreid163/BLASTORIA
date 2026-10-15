extends SceneTree

var scene: Node
var valid: bool = true

func _initialize() -> void:
	call_deferred("run")

func buttons() -> Array:
	return scene.hud.column.get_children().filter(func(node): return node is Button)

func labels() -> Array:
	return buttons().map(func(button): return button.text)

func require(condition: bool, title: String) -> void:
	valid = valid and condition
	print("PASS: " if condition else "FAIL: ", title)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	TranslationServer.set_locale("ru")
	scene.show_main_menu()
	var expected := ["Обучение", "Кампания", "Приключение", "Классика", "Аркада", "Мастерская", "Арена", "Коллекция секретов", "Настройки", "Выйти"]
	require(labels() == expected, "Russian menu labels and order: " + " / ".join(labels()))
	for index in range(expected.size()):
		scene.show_main_menu()
		buttons()[index].pressed.emit()
		match index:
			0: require(scene.screen == "playing" and scene.state.mode == "tutorial", "Training opens tutorial")
			1:
				require(scene.screen == "campaign_menu", "Campaign opens its submenu")
				buttons()[0].pressed.emit()
				require(scene.state.mode == "campaign" and scene.state.level == scene.profile.unlocked, "Continue resumes unlocked campaign stage")
				scene.handle_action("campaign_menu")
				buttons()[1].pressed.emit()
				require(scene.state.mode == "campaign" and scene.state.level == 0, "New campaign starts first stage")
			2: require(scene.screen == "adventure_menu" and scene.hud.column.get_child(0).text == "Приключение", "Adventure heading translated")
			3: require(scene.screen == "classic_menu" and scene.hud.column.get_child(0).text == "Классика", "Classic heading translated")
			4: require(scene.screen == "official_menu", "Arcade opens official stage selection")
			5: require(scene.screen == "editor" and scene.workshop.visible, "Workshop opens editor")
			6: require(scene.screen == "playing" and scene.state.mode == "arena", "Arena starts local match")
			7: require(scene.screen == "collection" and scene.hud.column.get_child(0).text == "Коллекция секретов", "Secret collection heading translated")
			8: require(scene.screen == "settings", "Settings opens")
			9: require(scene.hud.column.get_child(0).text == "Выйти из BLASTORIA?", "Exit opens confirmation")
	TranslationServer.set_locale("en")
	scene.show_main_menu()
	require(labels() == ["Training", "Campaign", "Adventure", "Classic", "Arcade", "Workshop", "Arena", "Secret collection", "Settings", "Exit"], "English columns no longer reversed")
	TranslationServer.set_locale("ru")
	scene.show_main_menu()
	await process_frame
	await process_frame
	require(scene.hud.column.size.y < 800, "Ten menu entries fit base viewport height")
	scene.queue_free()
	await process_frame
	print("MENU SMOKE: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
