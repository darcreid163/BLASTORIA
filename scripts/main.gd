extends Node3D

const CONFIG = preload("res://resources/configurations/default.tres")
var state := GameState.new()
var view: BoardView
var hud: GameHUD
var profile := SaveManager.new()
var screen: String = "menu"
var arena_seed: int = 4242
var save_error: bool = false
var arcade := ArcadeRun.new()
var audio_manager: AudioManager
var settings_return: String = "menu"
var waiting_binding: String = ""
var controls_player: int = 1

func _ready() -> void:
	profile.read_profile(CONFIG.campaign_seeds.size() - 1)
	InputRouter.install(profile.settings.bindings)
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	audio_manager.apply_settings(profile.settings)
	apply_display_mode()
	TranslationServer.set_locale(profile.language)
	view = BoardView.new()
	add_child(view)
	hud = GameHUD.new()
	add_child(hud)
	hud.action_requested.connect(handle_action)
	hud.volume_changed.connect(func(bus: String, value: float):
		profile.settings.set(bus, value)
		audio_manager.apply_settings(profile.settings))
	state.feedback.connect(audio_manager.play)
	state.finished.connect(on_finished)
	state.pickup.connect(func(_id: int, kind: String): hud.notify_pickup(kind))
	start_game("campaign", 0)
	show_main_menu()

func start_game(mode: String, level: int) -> void:
	audio_manager.stop_effects()
	var map_seed: int = arena_seed if mode == "arena" else CONFIG.campaign_seeds[level]
	if mode == "arcade":
		map_seed = CONFIG.arcade_seeds[level]
	state.start(CONFIG, mode, level, map_seed)
	view.build(state)
	hud.toast.text = ""
	hud.overlay.hide()
	screen = "playing"
	hud.update_state(state, arcade)

func show_main_menu() -> void:
	audio_manager.stop_effects()
	state.paused = true
	screen = "menu"
	hud.show_menu("TITLE", [["TUTORIAL", "tutorial"], ["CONTINUE", "continue"], ["NEW_CAMPAIGN", "campaign"], ["ARCADE", "arcade_menu"], ["ARENA", "arena"], ["SETTINGS", "settings"], ["QUIT", "quit"]], tr("SAVE_ERROR") if save_error else "")

func _physics_process(_delta: float) -> void:
	if screen != "playing":
		return
	state.advance(InputRouter.commands())
	hud.update_state(state, arcade)

func _process(delta: float) -> void:
	if view != null and state.board != null:
		view.sync(state, 0.0 if state.paused else delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if screen == "playing":
					pause_game()
				elif screen == "pause":
					handle_action("resume")
			KEY_R:
				if screen == "result" or screen == "pause":
					handle_action("retry")
			KEY_F11:
				handle_action("fullscreen")
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if screen == "playing":
			pause_game()
		elif screen == "pause":
			handle_action("resume")

func pause_game() -> void:
	audio_manager.stop_effects()
	state.paused = true
	screen = "pause"
	hud.show_menu("PAUSED", [["RESUME", "resume"], ["RESTART_RUN" if state.mode == "arcade" else "RETRY", "retry"], ["SETTINGS", "settings"], ["MENU", "menu"]], tr("ARCADE_RESTART_NOTE") if state.mode == "arcade" else "")

func handle_action(action: String) -> void:
	audio_manager.play("ui")
	if action.begins_with("bind:"):
		waiting_binding = action.trim_prefix("bind:")
		screen = "binding"
		hud.show_menu("PRESS_KEY", [["CANCEL", "controls_back"]], tr("BIND_HELP"))
		return
	match action:
		"tutorial": start_game("tutorial", 0)
		"settings":
			settings_return = "pause" if screen == "pause" else "menu"
			show_settings()
		"settings_back":
			save_profile()
			if settings_return == "pause":
				pause_game()
			else:
				show_main_menu()
		"keys1": show_controls(1)
		"keys2": show_controls(2)
		"controls_back":
			waiting_binding = ""
			show_controls(controls_player)
		"controls_done": show_settings()
		"keys_reset":
			profile.settings.reset_keys()
			InputRouter.install(profile.settings.bindings)
			show_controls(controls_player)
		"campaign": start_game("campaign", 0)
		"continue": start_game("campaign", profile.unlocked)
		"arcade_menu": show_arcade_menu()
		"arcade_start":
			arcade = ArcadeRun.new()
			start_game("arcade", 0)
		"arena":
			arena_seed += 1
			start_game("arena", 0)
		"retry":
			if state.mode == "arcade":
				handle_action("arcade_start")
			else:
				start_game(state.mode, state.level)
		"next":
			if state.mode == "arcade" and not arcade.ended:
				start_game("arcade", arcade.next_stage)
			elif state.mode == "campaign":
				start_game("campaign", mini(state.level + 1, CONFIG.campaign_seeds.size() - 1))
		"resume":
			state.paused = false
			screen = "playing"
			hud.overlay.hide()
		"menu": show_main_menu()
		"language":
			profile.language = "en" if profile.language == "ru" else "ru"
			TranslationServer.set_locale(profile.language)
			save_profile()
			show_settings()
		"fullscreen":
			profile.settings.fullscreen = not profile.settings.fullscreen
			apply_display_mode()
			save_profile()
			if screen == "settings":
				show_settings()
		"quit": hud.show_menu("QUIT_CONFIRM", [["YES_QUIT", "quit_yes"], ["MENU", "menu"]])
		"quit_yes": get_tree().quit()

func show_arcade_menu() -> void:
	state.paused = true
	screen = "arcade_menu"
	var rules := tr("ARCADE_RULES") % [CONFIG.arcade_seeds.size(), CONFIG.score_crate, CONFIG.score_enemy, CONFIG.score_pickup, CONFIG.score_stage_clear, CONFIG.arcade_par_seconds, CONFIG.score_per_second]
	hud.show_menu("ARCADE", [["START_RUN", "arcade_start"], ["MENU", "menu"]], rules + "\n\n" + record_text())

func record_text() -> String:
	var record := profile.record_for(CONFIG.arcade_rules_id)
	var best := ArcadeRun.format_time(record.best_ticks) if record.best_ticks > 0 else tr("NO_RECORD")
	return tr("RECORDS") % [record.score, best]

func on_finished(result: String) -> void:
	screen = "result"
	var buttons: Array = [["RESTART_RUN" if state.mode == "arcade" else "RETRY", "retry"], ["MENU", "menu"]]
	var details := ""
	if state.mode == "arcade":
		var accepted := arcade.accept_stage(state)
		details = tr("RUN_RESULT") % [arcade.score, ArcadeRun.format_time(arcade.elapsed_ticks), state.time_bonus]
		if result == "LEVEL_CLEAR":
			buttons.push_front(["NEXT", "next"])
		elif accepted and arcade.ended and not arcade.records_saved:
			var changed := profile.record_arcade(CONFIG.arcade_rules_id, arcade.score, arcade.elapsed_ticks, arcade.completed)
			arcade.records_saved = true
			save_profile()
			if changed.score:
				details += "\n" + tr("NEW_SCORE_RECORD")
			if changed.time:
				details += "\n" + tr("NEW_TIME_RECORD")
		details += "\n\n" + record_text()
	elif result == "TUTORIAL_DONE":
		buttons.push_front(["NEW_CAMPAIGN", "campaign"])
	elif result == "LEVEL_CLEAR":
		profile.unlocked = maxi(profile.unlocked, state.level + 1)
		save_profile()
		buttons.push_front(["NEXT", "next"])
	if save_error:
		details += "\n" + tr("SAVE_ERROR")
	hud.show_menu(result, buttons, details)

func save_profile() -> void:
	var error := profile.write_profile()
	save_error = error != OK
	if save_error:
		push_warning("Profile write failed: %s" % error_string(error))
		hud.toast.text = tr("SAVE_ERROR")

func apply_display_mode() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func show_settings() -> void:
	state.paused = true
	screen = "settings"
	var details := tr("SETTINGS_HINT")
	if save_error:
		details += "\n" + tr("SAVE_ERROR")
	hud.show_menu("SETTINGS", [["KEYS_P1", "keys1"], ["KEYS_P2", "keys2"], ["LANGUAGE", "language"], ["FULLSCREEN", "fullscreen"], ["BACK_SAVE", "settings_back"]], details)
	hud.add_volume_sliders(profile.settings)

func show_controls(player: int, notice: String = "") -> void:
	controls_player = player
	screen = "controls"
	var buttons: Array = []
	for direction in ["up", "down", "left", "right", "bomb"]:
		var action := "p%d_%s" % [player, direction]
		buttons.append([tr("KEY_" + direction.to_upper()) + " : " + InputRouter.key_label(action), "bind:" + action])
	buttons.append(["RESET_KEYS", "keys_reset"])
	buttons.append(["BACK", "controls_done"])
	hud.show_menu("KEYS_P%d" % player, buttons, notice)

func _input(event: InputEvent) -> void:
	if waiting_binding.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		waiting_binding = ""
		show_controls(controls_player)
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var error := "KEY_RESERVED" if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed else profile.settings.rebind(waiting_binding, key)
	if not error.is_empty():
		hud.show_menu("PRESS_KEY", [["CANCEL", "controls_back"]], tr(error) + "\n" + tr("BIND_HELP"))
		return
	waiting_binding = ""
	InputRouter.install(profile.settings.bindings)
	show_controls(controls_player, tr("KEY_SAVED"))
