extends RefCounted

func run(test: SceneTree) -> void:
	test.check(AchievementCatalog.validate(), "v2.4: 37 unique localized achievements with four hidden, planned only")
	var catalog := AchievementCatalog.entries()
	test.check(catalog.size() == 37, "v2.4: achievement catalog loads from JSON")
	var locked: Array[String] = []
	var visible := AchievementCatalog.player_visible_entries(locked)
	test.check(visible.size() == 33, "v2.4: unknown secret achievements do not appear in player UI data")
	var leak := false
	for item in visible:
		if item.category == "secret":
			leak = true
	test.check(not leak, "v2.4: no locked secret metadata leaked via visible catalog")
	locked.append("ACH_SECRET_FIRST")
	var discovered := AchievementCatalog.player_visible_entries(locked)
	var found := false
	for item in discovered:
		if item.id == "ACH_SECRET_FIRST":
			found = true
	test.check(discovered.size() == 34 and found, "v2.4: only an unlocked hidden achievement becomes visible")
