class_name InputRouter
extends RefCounted

static func install(bindings: Dictionary = GameSettings.DEFAULT_KEYS) -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	for player in range(2):
		var prefix := "p%d_" % (player + 1)
		var buttons := {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "bomb": JOY_BUTTON_A}
		for action in buttons:
			var event := InputEventJoypadButton.new()
			event.device = player
			event.button_index = buttons[action]
			InputMap.action_add_event(prefix + action, event)

static func commands() -> Dictionary:
	var result: Dictionary = {}
	for player in range(2):
		var prefix := "p%d_" % (player + 1)
		var direction := Vector2i.ZERO
		for pair in [["up", Vector2i.UP], ["down", Vector2i.DOWN], ["left", Vector2i.LEFT], ["right", Vector2i.RIGHT]]:
			if Input.is_action_pressed(prefix + pair[0]):
				direction = pair[1]
				break
		result[player] = {"move": direction, "bomb": Input.is_action_just_pressed(prefix + "bomb")}
	return result

static func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "?"

static func player_hint(player: int) -> String:
	var prefix := "p%d_" % player
	var parts: Array[String] = []
	for action in ["up", "left", "down", "right"]:
		parts.append(key_label(prefix + action))
	return "/".join(parts) + " + " + key_label(prefix + "bomb")
