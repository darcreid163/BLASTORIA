extends SceneTree

var valid: bool = true

func require(condition: bool, label: String) -> void:
	valid = valid and condition
	print("PASS: " if condition else "FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func move(state: GameState, direction: Vector2i, count: int) -> void:
	for i in range(count):
		while state.tick < state.actors[0].ready: state.advance()
		state.advance({0: {"move": direction}})

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var path := "user://qa_export_060.progress"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)
	scene.achievements.path = path
	scene.achievements.progress = AchievementManager.fresh()
	require(scene.achievements.award_enabled and not OS.is_debug_build(), "release export enables earning without debug override")
	scene.handle_action("tutorial")
	move(scene.state, Vector2i.RIGHT, 3)
	scene.state.advance({0: {"bomb": true}})
	scene.achievements.observe(scene.state)
	require(not scene.achievements.progress.earned.has("ACH_FIRST_BLAST"), "placing alone does not unlock")
	move(scene.state, Vector2i.LEFT, 3)
	for i in range(190):
		scene.state.advance()
		scene.achievements.observe(scene.state)
	require(scene.state.actors[0].alive and scene.achievements.progress.earned.has("ACH_FIRST_BLAST"), "actual placement/retreat/detonation earns milestone in shipped simulation")
	var reload := AchievementManager.new()
	reload.path = path
	reload.read_progress()
	require(reload.progress.earned.has("ACH_FIRST_BLAST") and reload.progress.pending.count("ACH_FIRST_BLAST") == 1, "release unlock and offline queue persist")
	scene.handle_action("achievements")
	var icons := 0
	var no_id_leaks := true
	for child in scene.hud.column.get_children():
		for nested in child.get_children():
			if nested is TextureRect and nested.texture != null: icons += 1
			if nested is Label and nested.text.contains("ACH_"): no_id_leaks = false
	require(icons == 5 and no_id_leaks, "achievement page imports vector icons and excludes API IDs")
	scene.handle_action("achievements_next")
	require(scene.achievement_page == 1, "exported pagination works")
	scene.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)
	print("ACHIEVEMENTS EXPORT: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
