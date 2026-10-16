extends RefCounted

func run(test: SceneTree) -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://resources/achievements/registry.json"))
	var ids := {}
	var hidden := 0
	for entry in source.entries:
		ids[entry.id] = true
		if entry.hidden: hidden += 1
	test.check(source.entries.size() == 37 and ids.size() == 37 and hidden == 4, "v2.4: complete developer-only design catalog retained")
	test.check(AchievementCatalog.validate(), "catalog: runtime public definitions validate")
	var active := AchievementCatalog.entries()
	test.check(active.size() == 17, "catalog: only seventeen implemented public milestones shipped")
	var leak := false
	for entry in active:
		if entry.hidden or entry.category == "secret" or entry.status != "local": leak = true
	test.check(not leak, "catalog: future/hidden conditions completely absent from runtime bundle")
	var forged: Array[String] = ["ACH_SECRET_FIRST", "ACH_SECRET_DISCOVERER"]
	test.check(AchievementCatalog.player_visible_entries(forged).size() == active.size(), "catalog: claiming a hidden API ID cannot disclose an unavailable definition")
