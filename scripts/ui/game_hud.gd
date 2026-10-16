class_name GameHUD
extends CanvasLayer

signal action_requested(action: String)
signal volume_changed(bus: String, value: float)
var play_frame: Control
var top_frame: PanelContainer
var hint_frame: PanelContainer
var map_view: ExplorationMap
var status: Label
var hint: Label
var metrics: Label
var toast: Label
var overlay: ColorRect
var column: VBoxContainer
var toast_time: float = 0.0
var achievement_notice: Label
var achievement_time: float = 0.0

func _ready() -> void:
	add_to_group("localized_surfaces")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	play_frame = margin
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	top_frame = PanelContainer.new()
	layout.add_child(top_frame)
	var top := VBoxContainer.new()
	top_frame.add_child(top)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("ffda8b"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(status)
	metrics = Label.new()
	metrics.add_theme_font_size_override("font_size", 22)
	top.add_child(metrics)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 20)
	layout.add_child(toast)
	toast.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint_frame = PanelContainer.new()
	layout.add_child(hint_frame)
	hint_frame.add_child(hint)
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
	column.custom_minimum_size.x = 720
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	achievement_notice = Label.new()
	achievement_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	achievement_notice.offset_top = 8
	achievement_notice.offset_bottom = 62
	achievement_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_notice.add_theme_font_size_override("font_size", 22)
	achievement_notice.add_theme_color_override("font_color", Color("ffda8b"))
	achievement_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achievement_notice.z_index = 10
	achievement_notice.hide()
	add_child(achievement_notice)

func show_menu(title: String, buttons: Array, details: String = "") -> void:
	set_playing_visible(false)
	retranslate()
	column.custom_minimum_size.x = 720
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
	subtitle.text = "BLASTORIA" if title != "BLASTORIA" else ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	if not details.is_empty():
		var description := Label.new()
		description.text = details
		description.custom_minimum_size.x = 720
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.add_theme_font_size_override("font_size", 18)
		column.add_child(description)
	for item in buttons:
		var button := Button.new()
		button.text = tr(item[0])
		button.custom_minimum_size.y = 44
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
	var mode_label := "ADVENTURE" if state.mode in ["classic", "campaign", "adventure"] else ("ARCADE" if state.mode in ["official_arcade", "arcade"] else ("WORKSHOP" if state.mode.begins_with("custom") else state.mode.to_upper()))
	status.text = tr(mode_label) + " · " + tr("STAGE") % (state.level + 1) + " · " + tr("ENEMIES") + ": %d" % state.alive_enemies()
	metrics.text = ""
	if state.mode == "arcade" and arcade != null:
		metrics.text = tr("SCORE") + ": %d · " % arcade.live_score(state) + tr("TIME") + ": " + ArcadeRun.format_time(arcade.live_ticks(state))
	if state.mode in ["classic", "adventure"]:
		metrics.text = tr("SCORE") + ": %d · " % state.score + tr("TIME_LEFT") + ": " + (str(state.remaining_seconds()) if state.config.level_seconds > 0 else "∞")
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
		metrics.text = tr("SCORE") + ": %d · " % state.score + tr("TIME") + ": " + ArcadeRun.format_time(state.level_ticks)
		if state.mode != "official_arcade": metrics.text += " · " + str(state.map_data.title)
		if state.config.level_seconds > 0: metrics.text += " · " + tr("TIME_LEFT") + ": %d" % state.remaining_seconds()
	if map_view.visible:
		map_view.queue_redraw()
	hint.text = tr("DYNAMIC_CONTROLS") % InputRouter.player_hint(1)
	if state.mode in ["arena", "custom_coop"] or state.map_data.get("mode") == "versus":
		hint.text += " | " + tr("PLAYER_TWO_KEYS") % InputRouter.player_hint(2)
	if state.mode == "tutorial":
		hint.text += "\n" + tr(state.tutorial_hint())
	elif state.mode in ["classic", "adventure"]:
		hint.text += " | " + tr("KEY_DETONATE") + ": " + InputRouter.key_label("p1_detonate") + " / B"
		hint.text += "\n" + tr("HIDDEN_GOAL")
		if state.mode == "adventure":
			hint.text += " | " + tr("MAP_KEY")
		if state.completion_walk:
			hint.text = SecretDefinition.active().localized("return")
	elif not state.map_data.is_empty():
		hint.text += "\n" + tr("OFFICIAL_RULES" if state.mode != "custom_arena" else "ARENA_DESC")
	elif state.mode != "arena":
		hint.text += "\n" + tr("GOAL")

func notify_pickup(kind: String) -> void:
	toast.text = tr("PICKUP_" + kind.to_upper())
	toast_time = 2.0
	toast.show()

func _process(delta: float) -> void:
	if achievement_time > 0:
		achievement_time -= delta
		if achievement_time <= 0: achievement_notice.hide()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast.text = ""
			toast.hide()

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

func add_relic_badge() -> void:
	var badge := RelicBadge.new()
	badge.custom_minimum_size.y = 64
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(badge)
	column.move_child(badge, 2)

func notify_achievement(title: String) -> void:
	achievement_notice.text = title
	achievement_notice.show()
	achievement_time = 4.0

func add_achievement_rows(rows: Array[Dictionary], _locale: String) -> void:
	var index := 2
	for item in rows:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 82
		var icon := TextureRect.new()
		icon.texture = load(item.icon)
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if item.earned else Color(0.45, 0.5, 0.5)
		row.add_child(icon)
		var label := Label.new()
		var status_text: String = tr("EARNED") + " · " + item.date if item.earned else tr("IN_PROGRESS") + (" · " + item.progress if not item.progress.is_empty() else "")
		label.text = item.title + "\n" + item.description + "\n" + status_text
		label.custom_minimum_size.x = 380
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		column.add_child(row)
		column.move_child(row, index)
		index += 1

func retranslate() -> void:
	var locale := LanguageCatalog.normalize(TranslationServer.get_locale())
	var theme := InterfaceTheme.create(locale)
	if is_instance_valid(column):
		column.theme = theme
		column.layout_direction = Control.LAYOUT_DIRECTION_RTL if locale == "ar" else Control.LAYOUT_DIRECTION_LTR
	if is_instance_valid(play_frame):
		play_frame.theme = theme
		play_frame.layout_direction = Control.LAYOUT_DIRECTION_RTL if locale == "ar" else Control.LAYOUT_DIRECTION_LTR
	if is_instance_valid(achievement_notice):
		achievement_notice.add_theme_font_override("font", LanguageCatalog.font_for(locale))
		achievement_notice.hide()
	if is_instance_valid(toast): toast.text = ""; toast.hide()

func set_playing_visible(value: bool) -> void:
	play_frame.visible = value

func show_home(warning: String = "") -> void:
	show_menu("BLASTORIA", [], tr("TITLE") + ("\n" + warning if not warning.is_empty() else ""))
	column.custom_minimum_size.x = 1000
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)
	for item in [["ARCADE", "official_menu"], ["ARENA", "arena_menu"], ["ADVENTURE", "adventure_menu"]]:
		var card := Button.new()
		card.custom_minimum_size = Vector2(320, 230)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("mode", item[0])
		var contents := VBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 20; contents.offset_right = -20
		contents.offset_top = 24; contents.offset_bottom = -24
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(contents)
		var title := Label.new()
		title.text = tr(item[0])
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color("ffce91"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(title)
		var description := Label.new()
		description.text = tr(item[0] + "_DESC")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(description)
		card.pressed.connect(func(): action_requested.emit(item[1]))
		cards.add_child(card)
	var secondary := GridContainer.new()
	secondary.columns = 2
	secondary.add_theme_constant_override("h_separation", 16)
	secondary.add_theme_constant_override("v_separation", 10)
	column.add_child(secondary)
	for item in [["WORKSHOP", "workshop"], ["COLLECTION", "collection"], ["TUTORIAL", "tutorial"], ["SETTINGS", "settings"], ["LANGUAGE", "language"], ["QUIT", "quit"]]:
		var button := Button.new()
		button.text = tr(item[0]); button.custom_minimum_size = Vector2(490, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): action_requested.emit(item[1]))
		secondary.add_child(button)
	cards.get_child(0).grab_focus()
