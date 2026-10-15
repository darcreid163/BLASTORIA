class_name GameSettings
extends RefCounted

const DEFAULT_KEYS := {
	"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p1_bomb": KEY_SPACE,
	"p2_up": KEY_UP, "p2_down": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_bomb": KEY_ENTER}
const RESERVED := [KEY_ESCAPE, KEY_F11, KEY_R, KEY_TAB]
var master: float = 0.8
var sfx: float = 0.8
var ui: float = 0.7
var fullscreen: bool = false
var bindings: Dictionary = DEFAULT_KEYS.duplicate()

func read_data(data: Variant) -> void:
	if not data is Dictionary:
		return
	for field in ["master", "sfx", "ui"]:
		var value = data.get(field)
		if (value is float or value is int) and is_finite(float(value)):
			set(field, clampf(float(value), 0.0, 1.0))
	if data.get("fullscreen") is bool:
		fullscreen = data.fullscreen
	if data.get("bindings") is Dictionary:
		var candidate: Dictionary = data.bindings
		var seen: Dictionary = {}
		var valid := candidate.size() == DEFAULT_KEYS.size()
		for action in DEFAULT_KEYS:
			var key = candidate.get(action)
			if not (key is int or key is float) or key != floor(key) or not allowed_key(int(key)) or seen.has(int(key)):
				valid = false
				break
			seen[int(key)] = true
		if valid:
			for action in DEFAULT_KEYS:
				bindings[action] = int(candidate[action])

static func allowed_key(key: int) -> bool:
	if RESERVED.has(key):
		return false
	return (key >= KEY_A and key <= KEY_Z) or (key >= KEY_0 and key <= KEY_9) or key in [KEY_SPACE, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

func rebind(action: String, key: int) -> String:
	if not bindings.has(action) or not allowed_key(key):
		return "KEY_RESERVED"
	for other in bindings:
		if other != action and bindings[other] == key:
			return "KEY_IN_USE"
	bindings[action] = key
	return ""

func reset_keys() -> void:
	bindings = DEFAULT_KEYS.duplicate()

func to_data() -> Dictionary:
	return {"master": master, "sfx": sfx, "ui": ui, "fullscreen": fullscreen, "bindings": bindings.duplicate()}
