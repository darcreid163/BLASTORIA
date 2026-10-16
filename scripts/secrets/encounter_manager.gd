class_name EncounterManager
extends RefCounted

var enabled: bool = not OS.is_debug_build()

func evaluate(state: GameState) -> Array[String]:
	var result: Array[String] = []
	if not enabled or state.result.is_empty(): return result
	if state.mode == "official_arcade":
		var official := ArcadeLevelRegistry.load_stage(state.level + 1)
		if official.is_empty() or MapValidationService.fingerprint(official) != MapValidationService.fingerprint(state.map_data): return result
	elif state.mode != "arena" or not state.map_data.is_empty(): return result
	for id in RuntimeBundle.section("encounters"):
		var rule: Dictionary = RuntimeBundle.section("encounters")[id]
		if rule.kind == "arcade_clear" and state.mode == "official_arcade" and state.result == "MAP_CLEAR" and state.level + 1 == int(rule.stage) and state.actors[0].alive and state.level_ticks <= int(rule.max_ticks) and state.activity.powers.size() >= int(rule.min_powers):
			result.append(id)
		elif rule.kind == "arena_draw" and state.mode == "arena" and state.result == "DRAW" and state.level_ticks >= int(rule.min_ticks):
			if state.activity.steps[0] >= int(rule.min_steps) and state.activity.steps[1] >= int(rule.min_steps) and state.activity.placements[0] >= int(rule.min_placements) and state.activity.placements[1] >= int(rule.min_placements): result.append(id)
	return result
