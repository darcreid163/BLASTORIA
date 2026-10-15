extends Node3D

const CONFIG = preload("res://resources/configurations/default.tres")
var state := GameState.new()
var view: BoardView
var hud: GameHUD
var profile := SaveManager.new()
var screen: String = "menu"
var arena_seed: int = 4242
var save_error: bool = false

func _ready() -> void:
	InputRouter.install()
	profile.read_profile(CONFIG.campaign_seeds.size() - 1)
	TranslationServer.set_locale(profile.language)
	view = BoardView.new()
	add_child(view)
	hud = GameHUD.new()
	add_child(hud)
	hud.action_requested.connect(handle_action)
	state.finished.connect(on_finished)
	state.pickup.connect(func(_id: int, kind: String): hud.notify_pickup(kind))
	start_game("campaign", 0)
	show_main_menu()

func start_game(mode: String, level: int) -> void:
	var map_seed: int = arena_seed if mode == "arena" else CONFIG.campaign_seeds[level]
	state.start(CONFIG, mode, level, map_seed)
	view.build(state)
	hud.toast.text = ""
	hud.overlay.hide()
	screen = "playing"
	hud.update_state(state)

func show_main_menu() -> void:
	state.paused = true
	screen = "menu"
	hud.show_menu("TITLE", [["CONTINUE", "continue"], ["NEW_CAMPAIGN", "campaign"], ["ARENA", "arena"], ["LANGUAGE", "language"], ["FULLSCREEN", "fullscreen"], ["QUIT", "quit"]])

func _physics_process(_delta: float) -> void:
	if screen != "playing":
		return
	state.advance(InputRouter.commands())
	hud.update_state(state)

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
	state.paused = true
	screen = "pause"
	hud.show_menu("PAUSED", [["RESUME", "resume"], ["RETRY", "retry"], ["MENU", "menu"]])

func handle_action(action: String) -> void:
	match action:
		"campaign": start_game("campaign", 0)
		"continue": start_game("campaign", profile.unlocked)
		"arena":
			arena_seed += 1
			start_game("arena", 0)
		"retry": start_game(state.mode, state.level)
		"next": start_game("campaign", mini(state.level + 1, CONFIG.campaign_seeds.size() - 1))
		"resume":
			state.paused = false
			screen = "playing"
			hud.overlay.hide()
		"menu": show_main_menu()
		"language":
			profile.language = "en" if profile.language == "ru" else "ru"
			TranslationServer.set_locale(profile.language)
			save_profile()
			show_main_menu()
		"fullscreen":
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		"quit": hud.show_menu("QUIT_CONFIRM", [["YES_QUIT", "quit_yes"], ["MENU", "menu"]])
		"quit_yes": get_tree().quit()

func on_finished(result: String) -> void:
	screen = "result"
	var buttons: Array = [["RETRY", "retry"], ["MENU", "menu"]]
	if result == "LEVEL_CLEAR":
		profile.unlocked = maxi(profile.unlocked, state.level + 1)
		save_profile()
		buttons.push_front(["NEXT", "next"])
	hud.show_menu(result, buttons)
	if save_error:
		hud.toast.text = tr("SAVE_ERROR")

func save_profile() -> void:
	var error := profile.write_profile()
	save_error = error != OK
	if save_error:
		push_warning("Profile write failed: %s" % error_string(error))
		hud.toast.text = tr("SAVE_ERROR")
