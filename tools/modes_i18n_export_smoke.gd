extends SceneTree
var valid := true
func _initialize() -> void: call_deferred("run")
func require(condition: bool, title: String) -> void:
	valid = valid and condition
	print("PASS: " if condition else "FAIL: ", title)
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate(); root.add_child(scene)
	await process_frame
	require(scene.encounters.enabled, "export enables official discovery earning")
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self, locale); scene.profile.language = locale
		scene.show_main_menu(); scene.show_settings(); scene.show_achievements(); scene.show_workshop()
		require(scene.workshop.mode_select.item_count == 4 and scene.achievements.display_rows(locale)[0].title == AchievementCatalog.entries()[0].title[locale], locale + ": shipped UI and achievements use selected locale")
		require(not SecretDefinition.active().localized("name", locale).is_empty(), locale + ": shipped owned discovery display is localized")
	for mode in MapValidationService.MODES:
		var data: Dictionary = CustomMapGenerator.generate({"mode":mode}, 700).data
		scene.start_custom(data, false)
		require(scene.state.map_data.mode == mode and not scene.state.map_data.has("secrets") and scene.encounters.evaluate(scene.state).is_empty(), "custom " + mode + ": no official discovery access")
	scene.profile = SaveManager.new(); scene.profile.path = "user://export_discoveries.json"
	scene.start_game("arena", 0)
	scene.state.level_ticks = 1800; scene.state.activity.steps = [12,12]; scene.state.activity.placements = [3,3]
	for actor in scene.state.actors: actor.alive = false
	scene.state.check_end()
	var loaded := SaveManager.new(); loaded.path = scene.profile.path; loaded.read_profile(2)
	require(loaded.artifacts.size() == 1 and scene.state.score == 0, "actual release Arena result persists discovery through main without score reward")
	scene.state.check_end()
	require(scene.profile.artifacts.size() == 1, "terminal recheck cannot duplicate discovery")
	var official := GameState.new(); official.start_map(ArcadeLevelRegistry.load_stage(3),3)
	official.activity.powers = ["range","capacity","speed"]
	for actor in official.actors:
		if actor.enemy: actor.alive = false
	official.advance()
	require(scene.encounters.evaluate(official).size() == 1, "release Arcade official qualification reads sealed criteria")
	scene.queue_free(); await process_frame
	print("MODES I18N EXPORT: ", "PASS" if valid else "FAIL"); quit(0 if valid else 1)
