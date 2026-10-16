extends Node3D

const CONFIG = preload("res://resources/configurations/default.tres")
const CLASSIC = preload("res://resources/game_rules/classic.tres")
const ADVENTURE = preload("res://resources/game_rules/adventure.tres")
var encounters := EncounterManager.new()
var state := GameState.new()
var classic_carry: Dictionary = {}
var classic_score: int = 0
var classic_progress := ClassicCampaignProgress.new()
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
var achievements := AchievementManager.new()
var achievement_page: int = 0
var guide_return: String = "menu"
var guide_page: int = 0
var official := ArcadeProgressionManager.new()
var workshop: CustomMapEditor
var custom_records := SaveManager.new()
var custom_record_result: bool = false

func _ready() -> void:
	achievements.read_progress()
	profile.read_profile(CONFIG.campaign_seeds.size() - 1)
	classic_progress.load_profile()
	official.read_progress()
	custom_records.path = "user://custom_records.json"
	custom_records.max_bytes = 65536
	custom_records.read_profile(0)
	InputRouter.install(profile.settings.bindings)
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	audio_manager.apply_settings(profile.settings)
	apply_display_mode()
	LanguageCatalog.apply(get_tree(), profile.language)
	view = BoardView.new()
	add_child(view)
	hud = GameHUD.new()
	add_child(hud)
	hud.action_requested.connect(handle_action)
	achievements.unlocked.connect(func(title: String):
		hud.notify_achievement(title)
		audio_manager.play("pickup"))
	achievements.save_failed.connect(func(): hud.notify_achievement(tr("SAVE_ERROR")))
	hud.volume_changed.connect(func(bus: String, value: float):
		profile.settings.set(bus, value)
		audio_manager.apply_settings(profile.settings))
	state.feedback.connect(audio_manager.play)
	state.secret_found.connect(func(id: String):
		if profile.record_secret(id):
			save_profile())
	state.finished.connect(on_finished)
	state.pickup.connect(func(id: int, kind: String):
		hud.notify_pickup(kind)
		view.notify_pickup(state, id))
	start_game("campaign", 0)
	show_main_menu()

func start_game(mode: String, level: int) -> void:
	achievements.flush()
	audio_manager.stop_effects()
	var map_seed: int = arena_seed if mode == "arena" else CONFIG.campaign_seeds[mini(level, CONFIG.campaign_seeds.size() - 1)]
	if mode == "arcade":
		map_seed = CONFIG.arcade_seeds[level]
	elif mode == "classic":
		var stage_data := ClassicStagePlan.stage(level + 1)
		if not ReleasePlan.stage_available(level + 1) or stage_data.is_empty():
			push_error("Unknown Classic Campaign stage: %d" % (level + 1))
			return
		map_seed = int(stage_data.seed)
	var rules: GameConfig = CLASSIC if mode == "classic" else (ADVENTURE if mode == "adventure" else CONFIG)
	state.start(rules, mode, level, map_seed)
	if mode == "classic":
		for key in classic_carry:
			state.actors[0][key] = classic_carry[key]
		state.score = classic_score
	if mode == "adventure" and profile.artifacts.has(SecretDefinition.active().id):
		state.secrets.enabled = false
	map_mode = 0
	hud.set_map(state, 0)
	view.build(state)
	hud.clear_pickup()
	hud.overlay.hide()
	hud.set_playing_visible(true)
	screen = "playing"
	hud.update_state(state, arcade, classic_progress.lives)

func start_classic_campaign(reset: bool) -> void:
	if reset:
		var error := classic_progress.reset_run()
		if error != OK:
			push_warning("Classic profile save failed: %s" % error_string(error))
	if not ReleasePlan.stage_available(classic_progress.stage):
		hud.show_menu("ADVENTURE", [["NEW_CAMPAIGN", "campaign"], ["MENU", "menu"]],
			tr("FUTURE_SAVE"))
		return
	if classic_progress.completed or classic_progress.lives <= 0:
		show_main_menu()
		return
	classic_carry = classic_progress.carry.duplicate(true)
	classic_score = classic_progress.score
	start_game("classic", classic_progress.stage - 1)


func show_main_menu() -> void:
	achievements.flush()
	audio_manager.stop_effects()
	state.paused = true
	if is_instance_valid(workshop): workshop.hide()
	hud.map_view.hide()
	screen = "menu"
	hud.show_home(tr("SAVE_ERROR") if save_error else "")

func _physics_process(_delta: float) -> void:
	if screen != "playing":
		return
	state.advance(InputRouter.commands())
	achievements.observe(state)
	hud.update_state(state, arcade, classic_progress.lives)

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
	if event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_X and screen == "result":
		handle_action("retry")
		return
	if event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_BACK and screen == "playing" and state.mode == "adventure":
		toggle_map()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if screen == "playing":
			pause_game()
		elif screen == "pause":
			handle_action("resume")

func pause_game() -> void:
	achievements.flush()
	audio_manager.stop_effects()
	state.paused = true
	hud.map_view.hide()
	screen = "pause"
	hud.show_menu("PAUSED", [["RESUME", "resume"], ["RESTART_RUN" if state.mode == "arcade" else "RETRY", "retry"], ["GUIDE", "guide"], ["SETTINGS", "settings"], ["MENU", "menu"]], tr("ARCADE_RESTART_NOTE") if state.mode == "arcade" else "")

	if state.mode in ["custom", "custom_coop", "custom_arena"]:
		hud.show_menu("PAUSED", [["RESUME", "resume"], ["RETRY", "retry"], ["GUIDE", "guide"], ["EDITOR_RETURN", "editor_return"]])

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
		"guide":
			guide_return = "pause" if screen == "pause" else "menu"
			show_guide()
		"guide_home": show_guide()
		"guide_bonuses":
			guide_page = 0
			show_bonus_guide()
		"guide_next":
			guide_page = 1
			show_bonus_guide()
		"guide_prev":
			guide_page = 0
			show_bonus_guide()
		"guide_enemies": show_enemy_guide()
		"guide_back":
			if guide_return == "pause": pause_game()
			else: show_main_menu()
		"campaign_menu":
			state.paused = true
			screen = "campaign_menu"
			hud.show_menu("CAMPAIGN_MENU", [["CONTINUE", "campaign_continue"], ["NEW_CAMPAIGN", "campaign"], ["MENU", "menu"]])
		"campaign_continue": start_classic_campaign(false)
		"adventure_menu":
			screen = "adventure_menu"
			hud.show_menu("ADVENTURE", [["CONTINUE", "campaign_continue"], ["NEW_CAMPAIGN", "campaign"], ["ENTER_RUINS", "adventure"], ["MENU", "menu"]], tr("ADVENTURE_DESC") + "\n" + tr("HIDDEN_GOAL"))
		"adventure": start_game("adventure", 0)
		"legacy_continue": start_game("campaign", profile.unlocked)
		"classic_menu":
			screen = "classic_menu"
			hud.show_menu("CLASSIC", [["START_CLASSIC", "classic_start"], ["MENU", "menu"]], tr("CLASSIC_RULES"))
		"classic_start": start_classic_campaign(true)
		"collection": show_collection_menu()
		"discoveries": show_discoveries()
		"secret_hall": show_secret_hall()
		"achievements":
			achievement_page = 0
			show_achievements()
		"achievements_prev":
			achievement_page = maxi(0, achievement_page - 1)
			show_achievements()
		"achievements_next":
			achievement_page += 1
			show_achievements()
		"records": show_official_records()
		"settings":
			if screen != "language": settings_return = "pause" if screen == "pause" else "menu"
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
		"campaign": start_classic_campaign(true)
		"continue": start_game("adventure", 0)
		"arcade_menu": show_arcade_menu()
		"arcade_start":
			arcade = ArcadeRun.new()
			start_game("arcade", 0)
		"arena_menu":
			screen = "arena_menu"
			hud.show_menu("ARENA", [["WS_DUEL", "arena"], ["MENU", "menu"]], tr("ARENA_DESC"))
		"arena":
			arena_seed += 1
			start_game("arena", 0)
		"retry":
			if state.mode == "official_arcade":
				start_official(state.level + 1)
			elif state.mode == "classic":
				if classic_progress.lives <= 0:
					start_classic_campaign(true)
				else:
					# Manual restart keeps range/capacity only, without granting extra lives.
					classic_carry = {"capacity": classic_progress.carry.get("capacity", CLASSIC.initial_capacity), "radius": classic_progress.carry.get("radius", CLASSIC.initial_range)}
					classic_score = classic_progress.score
					start_game("classic", classic_progress.stage - 1)
			elif state.mode in ["custom", "custom_coop", "custom_arena"]:
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
				classic_carry = classic_progress.carry.duplicate(true)
				classic_score = classic_progress.score
				start_game("classic", classic_progress.stage - 1)
			elif state.mode == "campaign":
				start_game("campaign", mini(state.level + 1, CONFIG.campaign_seeds.size() - 1))
		"resume":
			state.paused = false
			screen = "playing"
			hud.overlay.hide()
			hud.set_map(state, map_mode)
		"menu": show_main_menu()
		"language": show_language_list()
		"fullscreen":
			profile.settings.fullscreen = not profile.settings.fullscreen
			apply_display_mode()
			save_profile()
			if screen == "settings":
				show_settings()
		"quit": hud.show_menu("QUIT_CONFIRM", [["YES_QUIT", "quit_yes"], ["MENU", "menu"]])
		"quit_yes":
			achievements.flush()
			get_tree().quit()

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
	var found: Array[String] = []
	for id in encounters.evaluate(state):
		if profile.record_secret(id): found.append(id)
	if not found.is_empty():
		save_profile()
		hud.notify_achievement.call_deferred(SecretDefinition.public_text(found[0], "name"))
	achievements.observe(state)
	if not state.map_data.is_empty():
		finish_map(result)
		return
	screen = "result"
	var buttons: Array = [["RESTART_RUN" if state.mode == "arcade" else "RETRY", "retry"], ["MENU", "menu"]]
	var details := ""
	var classic_save_warning := ""
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
	if state.mode == "classic":
		if result in ["LEVEL_CLEAR", "CLASSIC_DONE"]:
			var clear_error := classic_progress.record_clear(state.level + 1, state.actors[0], state.score)
			if clear_error != OK:
				classic_save_warning = "\n" + tr("SAVE_ERROR")
			elif result == "LEVEL_CLEAR":
				buttons.push_front(["NEXT", "next"])
		elif result == "DEFEAT":
			if classic_progress.record_loss(state.actors[0]) != OK:
				classic_save_warning = "\n" + tr("SAVE_ERROR")
	if state.mode in ["classic", "adventure"]:
		details = tr("SOLO_RESULT") % state.score
		if state.mode == "classic":
			details += "\n" + tr("LIVES") + ": %d · " % classic_progress.lives + tr("STAGE") % (state.level + 1)
			details += classic_save_warning
		if state.secrets.awarded:
			details += "\n" + SecretDefinition.active().localized("reward")
	if save_error:
		details += "\n" + tr("SAVE_ERROR")
	if result == "DEFEAT" and not state.defeat_reason.is_empty(): details += "\n" + tr(state.defeat_reason)
	hud.show_menu(result, buttons, details)
	if state.secrets.awarded:
		hud.add_relic_badge()

func save_profile() -> void:
	var error := profile.write_profile()
	save_error = error != OK
	if save_error:
		push_warning("Profile write failed: %s" % error_string(error))
		hud.notify_message(tr("SAVE_ERROR"))

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

func show_collection_menu() -> void:
	state.paused = true
	screen = "collection"
	hud.show_menu("COLLECTION", [["DISCOVERIES", "discoveries"], ["SECRET_HALL", "secret_hall"], ["ACHIEVEMENTS", "achievements"], ["MENU", "menu"]])

func show_discoveries() -> void:
	state.paused = true
	screen = "discoveries"
	var lines: Array[String] = []
	for id in profile.artifacts:
		var name := SecretDefinition.public_text(id, "name")
		if not name.is_empty(): lines.append(name + "\n" + SecretDefinition.public_text(id, "description"))
	hud.show_menu("DISCOVERIES", [["COLLECTION", "collection"], ["MENU", "menu"]], "\n\n".join(lines) if not lines.is_empty() else tr("COLLECTION_EMPTY"))
	if not lines.is_empty(): hud.add_relic_badge()

func show_secret_hall() -> void:
	state.paused = true
	screen = "secret_hall"
	hud.show_menu("SECRET_HALL", [["COLLECTION", "collection"], ["MENU", "menu"]], tr("HALL_OFFLINE"))

func show_achievements() -> void:
	state.paused = true
	screen = "achievements"
	var rows := achievements.display_rows(profile.language)
	var last := maxi(0, ceili(float(rows.size()) / 5.0) - 1)
	achievement_page = clampi(achievement_page, 0, last)
	var buttons: Array = []
	if achievement_page > 0: buttons.append(["PREVIOUS", "achievements_prev"])
	if achievement_page < last: buttons.append(["NEXT", "achievements_next"])
	buttons.append(["COLLECTION", "collection"])
	buttons.append(["MENU", "menu"])
	var details := tr("LOCAL_ACHIEVEMENTS")
	if not achievements.award_enabled: details += "\n" + tr("DEBUG_AWARDS")
	hud.show_menu("ACHIEVEMENTS", buttons, details)
	hud.add_achievement_rows(rows.slice(achievement_page * 5, achievement_page * 5 + 5), profile.language)

func stage_name(number: int) -> String:
	return tr("STAGE") % number + " · " + tr("ARCADE_NAME_%02d" % number)

func show_official_records() -> void:
	state.paused = true
	screen = "records"
	var lines: Array[String] = []
	for number in range(1, ArcadeLevelRegistry.playable_count() + 1):
		var data := ArcadeLevelRegistry.load_stage(number)
		if data.is_empty(): continue
		var record := official.save.record_for(official.key_for(data))
		lines.append(stage_name(number) + " · " + tr("BEST_SCORE") % record.score + " · " + tr("BEST_TIME") % (ArcadeRun.format_time(record.best_ticks) if record.best_ticks > 0 else tr("NO_RECORD")))
	hud.show_menu("STAGE_RECORDS", [["ARCADE", "official_menu"], ["MENU", "menu"]], "\n".join(lines))

func show_official_menu() -> void:
	state.paused = true
	screen = "official_menu"
	var stages: Array = []
	for number in range(1, ArcadeLevelRegistry.playable_count() + 1):
		stages.append([stage_name(number), "official:%d" % number, official.available(number)])
	hud.show_stages(stages, tr("OFFICIAL_RULES") + "\n" + tr("CONTENT_STATUS") % [ArcadeLevelRegistry.playable_count(), ReleasePlan.LAUNCH_STAGES])

func show_language_list() -> void:
	state.paused = true
	screen = "language"
	hud.show_menu("LANGUAGE", [["BACK", "settings"]])
	var search := LineEdit.new()
	search.placeholder_text = tr("SEARCH_LANGUAGE")
	search.add_theme_font_override("font", LanguageCatalog.universal_font())
	hud.column.add_child(search)
	hud.column.move_child(search, 2)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 440)
	scroll.follow_focus = true
	hud.column.add_child(scroll)
	hud.column.move_child(scroll, 3)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rebuild := func(query: String):
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		for locale in LanguageCatalog.LOCALES:
			var display := LanguageCatalog.display_name(locale, profile.language)
			if not query.strip_edges().is_empty() and not LanguageCatalog.matches(locale, query, profile.language): continue
			var button := Button.new()
			button.text = display
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.add_theme_font_override("font", LanguageCatalog.universal_font())
			button.custom_minimum_size.y = 48
			button.toggle_mode = true
			button.button_pressed = locale == profile.language
			button.pressed.connect(func():
				profile.language = locale
				LanguageCatalog.apply(get_tree(), locale)
				save_profile()
				show_language_list())
			list.add_child(button)
		if list.get_child_count() == 0:
			var empty := Label.new(); empty.text = tr("NO_RESULTS"); list.add_child(empty)
	search.text_changed.connect(rebuild)
	rebuild.call("")
	search.grab_focus()

func start_official(number: int) -> void:
	achievements.flush()
	if not official.available(number):
		show_official_menu()
		return
	var data := ArcadeLevelRegistry.load_stage(number)
	var error := state.start_map(data, number)
	if not error.is_empty():
		hud.show_menu("MAP_INVALID", [["MENU", "menu"]])
		return
	show_loaded_map()

func show_loaded_map() -> void:
	audio_manager.stop_effects()
	map_mode = 0
	hud.set_map(state, 0)
	view.build(state)
	hud.clear_pickup()
	hud.overlay.hide()
	hud.set_playing_visible(true)
	screen = "playing"
	hud.update_state(state, arcade, classic_progress.lives)

func show_workshop() -> void:
	audio_manager.stop_effects()
	state.paused = true
	hud.map_view.hide()
	hud.overlay.hide()
	hud.set_playing_visible(false)
	screen = "editor"
	if not is_instance_valid(workshop):
		workshop = CustomMapEditor.new()
		add_child(workshop)
		workshop.play_requested.connect(start_custom)
		workshop.library.saved.connect(func(data: Dictionary): achievements.map_event("saved", data))
		workshop.library.imported.connect(func(data: Dictionary): achievements.map_event("imported", data))
		workshop.library.exported.connect(func(data: Dictionary): achievements.map_event("exported", data))
		workshop.closed.connect(show_main_menu)
	workshop.show()
	workshop.focus_button.grab_focus()

func start_custom(data: Dictionary, record_result: bool) -> void:
	achievements.flush()
	var error := state.start_map(data)
	if not error.is_empty():
		show_workshop()
		workshop.notice.text = tr("MAP_INVALID")
		return
	custom_record_result = record_result
	if is_instance_valid(workshop): workshop.hide()
	show_loaded_map()

func finish_map(result: String) -> void:
	achievements.custom_complete(state, custom_record_result)
	screen = "result"
	state.paused = true
	var details := tr("SCORE") + ": %d · " % state.score + tr("TIME") + ": " + ArcadeRun.format_time(state.level_ticks) + "\n" + (stage_name(state.level + 1) if state.mode == "official_arcade" else str(state.map_data.title))
	var buttons: Array = [[tr("RETRY") + " · R / X", "retry"]]
	if state.mode == "official_arcade":
		if result == "MAP_CLEAR":
			if official.complete(state) != OK:
				details += "\n" + tr("SAVE_ERROR")
			if official.available(state.level + 2):
				buttons.push_front(["NEXT", "next"])
			else:
				details += "\n" + tr("CONTENT_END")
		var record := official.save.record_for(official.key_for(state.map_data))
		details += "\n" + tr("BEST_SCORE") % record.score + " · " + tr("BEST_TIME") % (ArcadeRun.format_time(record.best_ticks) if int(record.best_ticks)>0 else tr("NO_RECORD"))
		buttons.append(["ARCADE", "official_menu"])
		buttons.append(["MENU", "menu"])
	else:
		if custom_record_result and result == "MAP_CLEAR":
			var key: String = "custom_" + (state.map_data.id + ":" + str(state.map_data.revision) + ":" + MapValidationService.fingerprint(state.map_data)).sha256_text().left(40)
			if not custom_records.arcade_records.has(key) and custom_records.arcade_records.size() >= 200:
				custom_records.arcade_records.erase(custom_records.arcade_records.keys()[0])
			custom_records.record_arcade(key, state.score, state.level_ticks, true)
			if custom_records.write_profile() != OK:
				details += "\n" + tr("SAVE_ERROR")
			var record := custom_records.record_for(key)
			details += "\n" + tr("BEST_SCORE") % record.score + " · " + tr("BEST_TIME") % (ArcadeRun.format_time(record.best_ticks) if int(record.best_ticks)>0 else tr("NO_RECORD"))
		else:
			details += ""
		buttons.append(["EDITOR_RETURN", "editor_return"])
	if state.scoring_mode(): details += "\n\n" + attempt_summary()
	if result == "DEFEAT" and not state.defeat_reason.is_empty(): details += "\n" + tr(state.defeat_reason)
	hud.show_menu(result, buttons, details, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		achievements.flush()

func attempt_summary() -> String:
	var lines: Array[String] = []
	for entry in [["CRATES_BROKEN", state.activity.crates, state.config.score_crate], ["DEFEATED", state.activity.kills, state.config.score_enemy], ["PICKUPS_COLLECTED", state.activity.pickups, state.config.score_pickup]]:
		lines.append(tr(entry[0]) + ": %d (+%d)" % [entry[1], int(entry[1])*int(entry[2])])
	if state.result == "MAP_CLEAR":
		lines.append(tr("CLEAR_BONUS") + ": +%d" % state.config.score_stage_clear)
		lines.append(tr("TIME_BONUS") + ": +%d" % state.time_bonus)
	return "\n".join(lines)

func show_guide() -> void:
	state.paused = true
	screen = "guide"
	var buttons: Array = [["GUIDE_BONUSES", "guide_bonuses"], ["GUIDE_ENEMIES", "guide_enemies"]]
	if guide_return == "menu": buttons.push_front(["TUTORIAL", "tutorial"])
	buttons.append(["BACK", "guide_back"])
	hud.show_menu("GUIDE", buttons, tr("DYNAMIC_CONTROLS") % InputRouter.player_hint(1))

func show_bonus_guide() -> void:
	screen = "guide_bonuses"
	state.paused = true
	var buttons: Array = []
	buttons.append(["PAGE_NEXT" if guide_page == 0 else "PAGE_PREV", "guide_next" if guide_page == 0 else "guide_prev"])
	buttons.append(["BACK", "guide_home"])
	hud.show_menu("GUIDE_BONUSES", buttons)
	var entries: Array = []
	for kind in MapValidationService.POWERS.slice(guide_page*4, guide_page*4+4):
		entries.append({"kind":kind,"title":tr("POWER_"+kind.to_upper()),"description":tr("INFO_"+kind.to_upper())})
	hud.add_guide_rows(entries, true)

func show_enemy_guide() -> void:
	screen = "guide_enemies"
	state.paused = true
	hud.show_menu("GUIDE_ENEMIES", [["BACK", "guide_home"]])
	var entries: Array = []
	for kind in MapValidationService.ENEMIES:
		entries.append({"kind":kind,"title":tr("WS_"+kind.to_upper()),"description":tr("ENEMY_"+kind.to_upper())})
	hud.add_guide_rows(entries, false)
