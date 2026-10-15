class_name InputRouter
extends RefCounted

static func install() -> void:
	var bindings := {
		"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p1_bomb": KEY_SPACE,
		"p2_up": KEY_UP, "p2_down": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_bomb": KEY_ENTER}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
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
