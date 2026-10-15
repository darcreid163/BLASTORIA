class_name GameHUD
extends CanvasLayer

signal action_requested(action: String)
signal volume_changed(bus: String, value: float)
var map_view: ExplorationMap
var status: Label
var hint: Label
var metrics: Label
var toast: Label
var overlay: ColorRect
var column: VBoxContainer
var toast_time: float = 0.0

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("ffda8b"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	metrics = Label.new()
	metrics.add_theme_font_size_override("font_size", 22)
	layout.add_child(metrics)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 20)
	layout.add_child(toast)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	layout.add_child(hint)
	map_view = ExplorationMap.new()
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.hide()
	add_child(map_view)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.065, 0.09, 0.94)
	add_child(overlay)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.follow_focus = true
	overlay.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 460
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

func show_menu(title: String, buttons: Array, details: String = "") -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = tr(title)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("ffda8b"))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "BLASTORIA  •  Worlds of Chaos  •  " + str(ProjectSettings.get_setting("application/config/version"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	if not details.is_empty():
		var description := Label.new()
		description.text = details
		description.custom_minimum_size.x = 460
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.add_theme_font_size_override("font_size", 18)
		column.add_child(description)
	for item in buttons:
		var button := Button.new()
		button.text = tr(item[0])
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 20)
		var action: String = item[1]
		button.pressed.connect(func(): action_requested.emit(action))
		column.add_child(button)
	overlay.show()
	for child in column.get_children():
		if child is Button:
			child.grab_focus()
			break

func update_state(state: GameState, arcade: ArcadeRun = null, classic_lives: int = 1) -> void:
	var actor: Dictionary = state.actors[0]
	status.text = "%s  |  %s %d  |  %s %d  |  B %d / R %d" % ["BLASTORIA", tr(state.mode.to_upper()), state.level + 1, tr("ENEMIES"), state.alive_enemies(), actor.capacity, actor.radius]
	metrics.text = ""
	if state.mode == "arcade" and arcade != null:
		metrics.text = tr("ARCADE_METRICS") % [arcade.live_score(state), ArcadeRun.format_time(arcade.live_ticks(state))]
	if state.mode in ["classic", "adventure"]:
		metrics.text = tr("SOLO_METRICS") % [state.score, str(state.remaining_seconds()) if state.config.level_seconds > 0 else "∞"]
		metrics.text += "  |  " + tr("LIVES") + ": " + str(classic_lives if state.mode == "classic" else (1 if actor.alive else 0))
		if state.penalty_phase:
			metrics.text += "  |  " + tr("PENALTY_PHASE")
		var active: Array[String] = []
		for power in ["remote", "wall_pass", "bomb_pass", "flame_pass"]:
			if actor[power]:
				active.append(tr("POWER_" + power.to_upper()))
		if state.tick < actor.invulnerable_until:
			active.append(tr("POWER_INVULNERABILITY") + " %ds" % ceili(float(actor.invulnerable_until - state.tick) / state.config.tick_rate))
		if not active.is_empty():
			metrics.text += "\n" + " • ".join(active)
	if not state.map_data.is_empty():
		metrics.text = "%d очков · %s · %s" % [state.score, ArcadeRun.format_time(state.level_ticks), state.map_data.title]
		if state.config.level_seconds > 0: metrics.text += " · осталось %d с" % state.remaining_seconds()
	if map_view.visible:
		map_view.queue_redraw()
	hint.text = tr("DYNAMIC_CONTROLS") % InputRouter.player_hint(1)
	if state.mode in ["arena", "custom_arena"]:
		hint.text += " | " + tr("PLAYER_TWO_KEYS") % InputRouter.player_hint(2)
	if state.mode == "tutorial":
		hint.text += "\n" + tr(state.tutorial_hint())
	elif state.mode in ["classic", "adventure"]:
		hint.text += " | " + tr("REMOTE_KEY") % InputRouter.key_label("p1_detonate")
		hint.text += "\n" + tr("HIDDEN_GOAL")
		if state.mode == "adventure":
			hint.text += " | " + tr("MAP_KEY")
		if state.completion_walk:
			hint.text = tr("COMPASS_RETURN")
	elif not state.map_data.is_empty():
		hint.text += "\nУничтожьте обязательных врагов — выход не требуется." if state.mode != "custom_arena" else "\nПобеждает последний оставшийся игрок."
	elif state.mode != "arena":
		hint.text += "\n" + tr("GOAL")

func notify_pickup(kind: String) -> void:
	toast.text = tr("PICKUP_" + kind.to_upper())
	toast_time = 2.0

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast.text = ""

func add_volume_sliders(settings: GameSettings) -> void:
	var position_index := 2
	for field in ["master", "sfx", "ui"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = tr("VOLUME_" + field.to_upper())
		label.custom_minimum_size.x = 190
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = settings.get(field) * 100
		slider.custom_minimum_size = Vector2(180, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 48
		number.text = "%d%%" % slider.value
		row.add_child(number)
		var setting_name: String = field
		slider.value_changed.connect(func(value: float):
			number.text = "%d%%" % value
			volume_changed.emit(setting_name, value / 100.0))
		column.add_child(row)
		column.move_child(row, position_index)
		position_index += 1

func set_map(state: GameState, mode: int) -> void:
	map_view.state = state
	map_view.expanded = mode == 2
	map_view.visible = mode > 0 and state.mode == "adventure"
	if mode == 2:
		map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_view.anchor_left = 0.12
		map_view.anchor_right = 0.88
		map_view.anchor_top = 0.17
		map_view.anchor_bottom = 0.88
	else:
		map_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		map_view.offset_left = -284
		map_view.offset_right = -24
		map_view.offset_top = 140
		map_view.offset_bottom = 360
	map_view.queue_redraw()

func add_compass_badge() -> void:
	var badge := CompassBadge.new()
	badge.custom_minimum_size.y = 64
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(badge)
	column.move_child(badge, 2)
