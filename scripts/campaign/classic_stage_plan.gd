class_name ClassicStagePlan
extends RefCounted

# Deterministic 100-stage Classic Campaign; independent of Official Arcade authoring.
const PATH := "res://resources/campaign/classic_100.json"
const BONUS_TYPES := ["range", "capacity", "remote", "speed", "bomb_pass",
	"wall_pass", "flame_pass", "invulnerability"]
const MAX_STAGES := 100
const PRIZE_CELL := Vector2i(5, 3)

static func catalog() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}

static func stage(number: int) -> Dictionary:
	if number < 1 or number > MAX_STAGES:
		return {}
	var entries = catalog().get("stages", [])
	if not entries is Array or entries.size() != MAX_STAGES:
		return {}
	var result = entries[number - 1]
	if not result is Dictionary or int(result.get("number", -1)) != number:
		return {}
	return result

static func rules_for(template: GameConfig, number: int) -> GameConfig:
	var rules: GameConfig = template.duplicate(true) as GameConfig
	var data := stage(number)
	if data.is_empty():
		return rules
	rules.width = int(data.width)
	rules.height = int(data.height)
	rules.enemy_step_ticks = int(data.enemy_step_ticks)
	rules.level_seconds = int(data.level_seconds)
	rules.crate_density = float(data.crate_density)
	# Authorial stage bonus replaces the old all-eight-drops-per-level behavior.
	rules.full_powerups = false
	rules.drop_chance = 0.0
	return rules

static func validate() -> bool:
	var data := catalog()
	if data.get("schema_version") != 1 or data.get("id") != "classic_campaign_100_v1":
		return false
	if data.get("first_life_count") != 3 or data.get("max_lives") != 9:
		return false
	var stages = data.get("stages", [])
	if not stages is Array or stages.size() != MAX_STAGES:
		return false
	var seeds: Dictionary = {}
	for i in range(MAX_STAGES):
		var s = stages[i]
		if not s is Dictionary or s.get("number") != i + 1:
			return false
		if s.get("sealed_prize") not in BONUS_TYPES:
			return false
		for k in ["seed", "width", "height", "enemy_count", "enemy_step_ticks", "level_seconds"]:
			if not SaveManager.valid_int(s.get(k), 1, 1000000000):
				return false
		if int(s.width) < 21 or int(s.height) < 15 or int(s.width) > 61 or int(s.height) > 41:
			return false
		if int(s.enemy_count) < 2 or int(s.enemy_count) > 9:
			return false
		if int(s.enemy_step_ticks) < 9 or int(s.level_seconds) < 200:
			return false
		if seeds.has(int(s.seed)):
			return false
		seeds[int(s.seed)] = true
	return true
