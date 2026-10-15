extends Node3D

const CONFIG = preload("res://resources/configurations/default.tres")
const CLASSIC = preload("res://resources/game_rules/classic.tres")
const ADVENTURE = preload("res://resources/game_rules/adventure.tres")
var state := GameState.new()
var classic_carry: Dictionary = {}
var classic_score: int = 0
var map_mode: int = 0
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
var official := ArcadeProgressionManager.new()
var workshop: CustomMapEditor
var custom_records := SaveManager.new()
var custom_record_result: bool = false

func _ready() -> void:
	profile.read_profile(CONFIG.campaign_seeds.size() - 1)
	official.read_progress()
	custom_records.path = "user://custom_records.json"
	custom_records.max_bytes = 65536
	custom_records.read_profile(0)
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
	state.secret_found.connect(func(id: String):
		if profile.record_secret(id):
			save_profile())
	state.finished.connect(on_finished)
	state.pickup.connect(func(_id: int, kind: String): hud.notify_pickup(kind))
	start_game("campaign", 0)
	show_main_menu()

func start_game(mode: String, level: int) -> void:
	audio_manager.stop_effects()
	var map_seed: int = arena_seed if mode == "arena" else CONFIG.campaign_seeds[level]
	if mode == "arcade":
		map_seed = CONFIG.arcade_seeds[level]
	var rules: GameConfig = CLASSIC if mode == "classic" else (ADVENTURE if mode == "adventure" else CONFIG)
	state.start(rules, mode, level, map_seed)
	if mode == "classic":
		for key in classic_carry:
			state.actors[0][key] = classic_carry[key]
		state.score = classic_score
	if mode == "adventure" and profile.artifacts.has("ghost_compass"):
		state.secrets.enabled = false
	map_mode = 0
	hud.set_map(state, 0)
	view.build(state)
	hud.toast.text = ""
	hud.overlay.hide()
	screen = "playing"
	hud.update_state(state, arcade)

func show_main_menu() -> void:
	audio_manager.stop_effects()
	state.paused = true
	if is_instance_valid(workshop): workshop.hide()
	hud.map_view.hide()
	screen = "menu"
	hud.show_menu("TITLE", [["TUTORIAL", "tutorial"], ["CAMPAIGN_MENU", "campaign_menu"], ["ADVENTURE", "adventure_menu"], ["CLASSIC", "classic_menu"], ["ARCADE", "official_menu"], ["WORKSHOP", "workshop"], ["ARENA", "arena"], ["COLLECTION", "collection"], ["SETTINGS", "settings"], ["QUIT", "quit"]], tr("SAVE_ERROR") if save_error else "")

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
			KEY_TAB:
				if screen == "playing" and state.mode == "adventure":
					toggle_map()
			KEY_R:
				if screen == "result" or screen == "pause":
					handle_action("retry")
			KEY_F11:
				handle_action("fullscreen")
	if event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_BACK and screen == "playing" and state.mode == "adventure":
		toggle_map()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if screen == "playing":
			pause_game()
		elif screen == "pause":
			handle_action("resume")

func pause_game() -> void:
	audio_manager.stop_effects()
	state.paused = true
	hud.map_view.hide()
	screen = "pause"
	hud.show_menu("PAUSED", [["RESUME", "resume"], ["RESTART_RUN" if state.mode == "arcade" else "RETRY", "retry"], ["SETTINGS", "settings"], ["MENU", "menu"]], tr("ARCADE_RESTART_NOTE") if state.mode == "arcade" else "")

	if state.mode in ["custom", "custom_arena"]:
		hud.show_menu("PAUSED", [["RESUME", "resume"], ["RETRY", "retry"], ["Вернуться в редактор", "editor_return"]])

func handle_action(action: String) -> void:
	audio_manager.play("ui")
	if action.begins_with("official:"):
		start_official(int(action.trim_prefix("official:")))
		return
	if action == "official_menu":
		show_official_menu()
		return
	if action == "workshop":
		show_workshop()
		return
	if action == "editor_return":
		show_workshop()
		return
	if action.begins_with("bind:"):
		waiting_binding = action.trim_prefix("bind:")
		screen = "binding"
		hud.show_menu("PRESS_KEY", [["CANCEL", "controls_back"]], tr("BIND_HELP"))
		return
	match action:
		"tutorial": start_game("tutorial", 0)
		"campaign_menu":
			state.paused = true
			screen = "campaign_menu"
			hud.show_menu("CAMPAIGN_MENU", [["CONTINUE", "campaign_continue"], ["NEW_CAMPAIGN", "campaign"], ["MENU", "menu"]])
		"campaign_continue": start_game("campaign", profile.unlocked)
		"adventure_menu":
			screen = "adventure_menu"
			hud.show_menu("ADVENTURE", [["ENTER_RUINS", "adventure"], ["LEGACY_CAMPAIGN", "legacy_continue"], ["MENU", "menu"]], tr("ADVENTURE_RULES"))
		"adventure": start_game("adventure", 0)
		"legacy_continue": start_game("campaign", profile.unlocked)
		"classic_menu":
			screen = "classic_menu"
			hud.show_menu("CLASSIC", [["START_CLASSIC", "classic_start"], ["MENU", "menu"]], tr("CLASSIC_RULES"))
		"classic_start":
			classic_carry.clear()
			classic_score = 0
			start_game("classic", 0)
		"collection":
			screen = "collection"
			var details := tr("COLLECTION_FOUND") if profile.artifacts.has("ghost_compass") else tr("COLLECTION_EMPTY")
			hud.show_menu("COLLECTION", [["MENU", "menu"]], details + "\nКоллекция прототипа Приключения. Официальные секреты Аркады будут отдельными.")
			if profile.artifacts.has("ghost_compass"):
				hud.add_compass_badge()
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
		"continue": start_game("adventure", 0)
		"arcade_menu": show_arcade_menu()
		"arcade_start":
			arcade = ArcadeRun.new()
			start_game("arcade", 0)
		"arena":
			arena_seed += 1
			start_game("arena", 0)
		"retry":
			if state.mode == "official_arcade":
				start_official(state.level + 1)
			elif state.mode in ["custom", "custom_arena"]:
				start_custom(state.map_data, custom_record_result)
			elif state.mode == "arcade":
				handle_action("arcade_start")
			else:
				if state.mode == "classic":
					# Chosen classic death policy: keep capacity/range; reset other powers.
					classic_carry = {"capacity": state.actors[0].capacity, "radius": state.actors[0].radius}
				start_game(state.mode, state.level)
		"next":
			if state.mode == "official_arcade":
				start_official(state.level + 2)
			elif state.mode == "arcade" and not arcade.ended:
				start_game("arcade", arcade.next_stage)
			elif state.mode == "classic":
				classic_carry.clear()
				for key in ["capacity", "radius", "step", "remote", "wall_pass", "bomb_pass", "flame_pass"]:
					classic_carry[key] = state.actors[0][key]
				classic_score = state.score
				start_game("classic", mini(state.level + 1, CLASSIC.campaign_seeds.size() - 1))
			elif state.mode == "campaign":
				start_game("campaign", mini(state.level + 1, CONFIG.campaign_seeds.size() - 1))
		"resume":
			state.paused = false
			screen = "playing"
			hud.overlay.hide()
			hud.set_map(state, map_mode)
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
	if not state.map_data.is_empty():
		finish_map(result)
		return
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
		buttons.push_front(["ADVENTURE", "adventure"])
	elif result == "LEVEL_CLEAR" and state.mode == "campaign":
		profile.unlocked = maxi(profile.unlocked, state.level + 1)
		save_profile()
		buttons.push_front(["NEXT", "next"])
	if state.mode == "classic" and result == "LEVEL_CLEAR":
		buttons.push_front(["NEXT", "next"])
	if state.mode in ["classic", "adventure"]:
		details = tr("SOLO_RESULT") % state.score
		if state.secrets.awarded:
			details += "\n" + tr("COMPASS_REWARD")
	if save_error:
		details += "\n" + tr("SAVE_ERROR")
	hud.show_menu(result, buttons, details)
	if state.secrets.awarded:
		hud.add_compass_badge()

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
	for direction in ["up", "down", "left", "right", "bomb", "detonate"]:
		var action := "p%d_%s" % [player, direction]
		buttons.append([tr("KEY_" + direction.to_upper()) + " : " + InputRouter.key_label(action), "bind:" + action])
	buttons.append(["RESET_KEYS", "keys_reset"])
	buttons.append(["BACK", "controls_done"])
	hud.show_menu("KEYS_P%d" % player, buttons, notice)

func _input(event: InputEvent) -> void:
	if screen == "playing" and state.mode == "adventure" and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
		get_viewport().set_input_as_handled()
		toggle_map()
		return
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

func toggle_map() -> void:
	map_mode = (map_mode + 1) % 3
	if map_mode > 0:
		state.secrets.map_used = true
	hud.set_map(state, map_mode)

func show_official_menu() -> void:
	state.paused = true
	screen = "official_menu"
	var buttons: Array = []
	for number in range(1, ArcadeLevelRegistry.playable_count() + 1):
		var data := ArcadeLevelRegistry.load_stage(number)
		if official.available(number):
			var record := official.save.record_for(official.key_for(data))
			buttons.append(["%s · %d очк." % [data.title, record.score], "official:%d" % number])
	buttons.append(["Аркада v1 — архив прототипа", "arcade_menu"])
	buttons.append(["MENU", "menu"])
	hud.show_menu("ARCADE", buttons, "Официальная Аркада 2.3 · готовы 3 из 100 этапов.\nЦель: уничтожить обязательных врагов. Выход не нужен.\nСледующий этап открывается после победы; повторы сохраняют карту.")

func start_official(number: int) -> void:
	if not official.available(number):
		show_official_menu()
		return
	var data := ArcadeLevelRegistry.load_stage(number)
	var error := state.start_map(data, number)
	if not error.is_empty():
		hud.show_menu("Ошибка карты", [["MENU", "menu"]], error)
		return
	show_loaded_map()

func show_loaded_map() -> void:
	audio_manager.stop_effects()
	map_mode = 0
	hud.set_map(state, 0)
	view.build(state)
	hud.toast.text = ""
	hud.overlay.hide()
	screen = "playing"
	hud.update_state(state, arcade)

func show_workshop() -> void:
	audio_manager.stop_effects()
	state.paused = true
	hud.map_view.hide()
	hud.overlay.hide()
	screen = "editor"
	if not is_instance_valid(workshop):
		workshop = CustomMapEditor.new()
		add_child(workshop)
		workshop.play_requested.connect(start_custom)
		workshop.closed.connect(show_main_menu)
	workshop.show()
	workshop.focus_button.grab_focus()

func start_custom(data: Dictionary, record_result: bool) -> void:
	var error := state.start_map(data)
	if not error.is_empty():
		show_workshop()
		workshop.notice.text = error
		return
	custom_record_result = record_result
	if is_instance_valid(workshop): workshop.hide()
	show_loaded_map()

func finish_map(result: String) -> void:
	screen = "result"
	state.paused = true
	var details := "%d очков · %s\n%s" % [state.score, ArcadeRun.format_time(state.level_ticks), state.map_data.title]
	var buttons: Array = [["RETRY", "retry"]]
	if state.mode == "official_arcade":
		if result == "MAP_CLEAR":
			if official.complete(state) != OK:
				details += "\nНе удалось сохранить официальный результат."
			if official.available(state.level + 2):
				buttons.push_front(["NEXT", "next"])
			else:
				details += "\nДоступные этапы завершены. Продолжение разрабатывается."
		var record := official.save.record_for(official.key_for(state.map_data))
		details += "\nРекорд этапа: %d · лучшее время: %s" % [record.score, ArcadeRun.format_time(record.best_ticks)]
		buttons.append(["Выбор этапа", "official_menu"])
		buttons.append(["MENU", "menu"])
	else:
		if custom_record_result and result == "MAP_CLEAR":
			var key: String = "custom_" + (state.map_data.id + ":" + str(state.map_data.revision) + ":" + MapValidationService.fingerprint(state.map_data)).sha256_text().left(40)
			if not custom_records.arcade_records.has(key) and custom_records.arcade_records.size() >= 200:
				custom_records.arcade_records.erase(custom_records.arcade_records.keys()[0])
			custom_records.record_arcade(key, state.score, state.level_ticks, true)
			if custom_records.write_profile() != OK:
				details += "\nОшибка сохранения пользовательского результата."
			var record := custom_records.record_for(key)
			details += "\nРекорд этой версии карты: %d · %s" % [record.score, ArcadeRun.format_time(record.best_ticks)]
		else:
			details += "\nПроверка карты: официальные результаты не изменены."
		buttons.append(["Вернуться в редактор", "editor_return"])
	hud.show_menu("Уровень пройден" if result == "MAP_CLEAR" else result, buttons, details)
