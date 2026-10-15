class_name ClassicCampaignProgress
extends RefCounted

# Separate profile: legacy three-stage campaign and Official Arcade remain untouched.
const PATH := "user://classic_100_v1.json"
const VERSION := 1
const MAX_BYTES := 65536
const MAX_LIVES := 9
const KEYS := ["capacity", "radius", "step", "remote", "wall_pass", "bomb_pass", "flame_pass"]
var path: String = PATH
var stage: int = 1
var lives: int = 3
var score: int = 0
var carry: Dictionary = {}
var cleared: Dictionary = {}
var completed: bool = false
var writable: bool = true
var recovered_from_backup: bool = false

func reset_run() -> Error:
	if not writable:
		return ERR_UNAVAILABLE
	stage = 1
	lives = 3
	score = 0
	carry.clear()
	cleared.clear()
	completed = false
	return write_profile()

func load_profile() -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var f := FileAccess.open(candidate, FileAccess.READ)
		if f == null or f.get_length() > MAX_BYTES:
			continue
		var value = JSON.parse_string(f.get_as_text())
		if not value is Dictionary:
			continue
		if SaveManager.valid_int(value.get("version"), VERSION + 1, 1000000):
			writable = false
			return
		if not SaveManager.valid_int(value.get("version"), 1, VERSION):
			continue
		if not SaveManager.valid_int(value.get("stage"), 1, 100) or not SaveManager.valid_int(value.get("lives"), 0, MAX_LIVES):
			continue
		if not SaveManager.valid_int(value.get("score"), 0, 1000000000):
			continue
		if not value.get("carry", {}) is Dictionary or not value.get("cleared", []) is Array or not value.get("completed", false) is bool:
			continue
		var restored: Dictionary = {}
		var valid := true
		for key in value.carry:
			if key not in KEYS:
				valid = false
				break
			if key in ["capacity", "radius", "step"] and not SaveManager.valid_int(value.carry[key], 1, 100):
				valid = false
				break
			if key not in ["capacity", "radius", "step"] and not value.carry[key] is bool:
				valid = false
				break
			restored[key] = value.carry[key]
		if not valid:
			continue
		var restored_cleared: Dictionary = {}
		for n in value.cleared:
			if not SaveManager.valid_int(n, 1, 100) or restored_cleared.has(int(n)):
				valid = false
				break
			restored_cleared[int(n)] = true
		if not valid:
			continue
		stage = int(value.stage)
		lives = int(value.lives)
		score = int(value.score)
		carry = restored
		cleared = restored_cleared
		completed = value.completed
		recovered_from_backup = candidate.ends_with(".bak")
		return

func write_profile() -> Error:
	if not writable:
		return ERR_UNAVAILABLE
	var completed_stages: Array[int] = []
	for n in cleared:
		completed_stages.append(n)
	completed_stages.sort()
	var payload := {"version": VERSION, "stage": stage, "lives": lives, "score": score,
		"carry": carry, "cleared": completed_stages, "completed": completed}
	var temporary := path + ".tmp"
	var f := FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(payload))
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		if not recovered_from_backup:
			error = DirAccess.copy_absolute(path, path + ".bak")
			if error != OK:
				return error
		error = DirAccess.remove_absolute(path)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, path)
	if error == OK:
		recovered_from_backup = false
	return error

func record_clear(number: int, actor: Dictionary, new_score: int) -> Error:
	if not writable or completed or number != stage or cleared.has(number):
		return ERR_INVALID_DATA
	if new_score < 0 or new_score > 1000000000:
		return ERR_INVALID_DATA
	cleared[number] = true
	lives = mini(MAX_LIVES, lives + 1) # Original +1 rule with explicit balance cap.
	score = new_score
	carry.clear()
	for key in KEYS:
		if actor.has(key):
			carry[key] = actor[key]
	if number == 100:
		completed = true
	else:
		stage = number + 1
	return write_profile()

func record_loss() -> Error:
	if not writable or lives <= 0:
		return ERR_INVALID_DATA
	lives -= 1
	# Classic retry: bomb capacity and fire range persist; temporary/special abilities are lost.
	for key in carry.keys():
		if key not in ["capacity", "radius"]:
			carry.erase(key)
	return write_profile()
