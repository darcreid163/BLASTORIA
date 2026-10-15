class_name ArcadeProgressionManager
extends RefCounted

# Separate namespace/file; prototype records and custom playtests cannot enter this table.
var save := SaveManager.new()

func _init() -> void:
	save.path = "user://official_arcade_23.json"
	save.max_bytes = 65536

func read_progress() -> void:
	save.read_profile(99)

func available(number: int) -> bool:
	return number >= 1 and number <= save.unlocked + 1 and not ArcadeLevelRegistry.load_stage(number).is_empty()

func key_for(data: Dictionary) -> String:
	return "official23_%s_%s" % [data.id, MapValidationService.fingerprint(data).left(16)]

func complete(state: GameState) -> Error:
	if state.mode != "official_arcade" or state.result != "MAP_CLEAR" or not available(state.level + 1):
		return ERR_INVALID_DATA
	var original := ArcadeLevelRegistry.load_stage(state.level + 1)
	if original.is_empty() or MapValidationService.fingerprint(original) != MapValidationService.fingerprint(state.map_data):
		return ERR_INVALID_DATA
	save.record_arcade(key_for(original), state.score, state.level_ticks, true)
	save.unlocked = maxi(save.unlocked, mini(99, state.level + 1))
	return save.write_profile()
