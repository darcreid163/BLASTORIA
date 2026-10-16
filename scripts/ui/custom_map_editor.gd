class_name CustomMapEditor
extends CanvasLayer

signal play_requested(data: Dictionary, record_result: bool)
signal closed
var document := CustomMapDocument.new()
var library := CustomMapLibrary.new()
var preview: MapPreviewRenderer
var notice: Label
var title_field: LineEdit
var author_field: LineEdit
var palette: OptionButton
var mode_select: OptionButton
var enemy_select: OptionButton
var bonus_select: OptionButton
var settings: Dictionary = {}
var required_check: CheckBox
var hidden_check: CheckBox
var rectangle_check: CheckBox
var focus_button: Button
var root: PanelContainer
var tools_list := ["floor", "wall", "crate", "spawn1", "spawn2"] + MapValidationService.ENEMIES + MapValidationService.POWERS
const LABELS := {"floor": "WS_FLOOR", "wall": "WS_WALL", "crate": "WS_CRATE", "spawn1": "WS_SPAWN1", "spawn2": "WS_SPAWN2", "patrol": "WS_PATROL", "chaser": "WS_CHASER", "bomber": "WS_BOMBER", "warden": "WS_WARDEN", "capacity": "POWER_CAPACITY", "range": "POWER_RANGE", "speed": "POWER_SPEED", "remote": "POWER_REMOTE", "wall_pass": "POWER_WALL_PASS", "bomb_pass": "POWER_BOMB_PASS", "flame_pass": "POWER_FLAME_PASS", "invulnerability": "POWER_INVULNERABILITY"}

func _ready() -> void:
	add_to_group("localized_surfaces")
	layer = 10
	root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	var heading := Label.new()
	mark(heading, "WORKSHOP")
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var left := side(body, 260)
	title_field = LineEdit.new()
	title_field.text = tr("WS_TITLE")
	title_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_field.add_theme_font_override("font", LanguageCatalog.universal_font())
	title_field.max_length = 80
	left.add_child(title_field)
	author_field = LineEdit.new()
	author_field.text = tr("WS_AUTHOR")
	author_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	author_field.add_theme_font_override("font", LanguageCatalog.universal_font())
	author_field.max_length = 80
	left.add_child(author_field)
	mode_select = option(left, ["WS_SOLO", "WS_COOP", "WS_DUEL", "WS_BOTS"])
	add_number(left, "width", "WS_WIDTH", 11, 41, 2, 25)
	add_number(left, "height", "WS_HEIGHT", 11, 31, 2, 17)
	add_number(left, "enemy_count", "WS_ENEMIES", 1, 32, 1, 3)
	enemy_select = option(left, MapValidationService.ENEMIES.map(func(k): return LABELS[k]))
	add_number(left, "enemy_step", "WS_ENEMY_STEP", 9, 90, 1, 36)
	add_number(left, "bonus_count", "WS_BONUSES", 0, 128, 1, 3)
	bonus_select = option(left, MapValidationService.POWERS.map(func(k): return LABELS[k]))
	hidden_check = checkbox(left, "WS_HIDDEN", true)
	settings.walls = checkbox(left, "WS_WALLS", true)
	settings.crates = checkbox(left, "WS_CRATES", true)
	add_number(left, "capacity", "WS_CAPACITY", 1, 5, 1, 1)
	add_number(left, "range", "WS_RANGE", 1, 6, 1, 2)
	add_number(left, "fuse_ticks", "WS_FUSE", 90, 600, 30, 150)
	add_number(left, "time_limit", "WS_TIMER", 0, 1800, 30, 0)
	settings.remote = checkbox(left, "WS_REMOTE", false)
	button(left, "WS_GENERATE", generate_map)
	button(left, "WS_APPLY", apply_rules)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	center.add_child(scroll)
	preview = MapPreviewRenderer.new()
	preview.document = document
	preview.focus_mode = Control.FOCUS_ALL
	scroll.add_child(preview)
	preview.paint_requested.connect(paint)
	preview.sample_requested.connect(func(at: Vector2i):
		palette.select(maxi(0, tools_list.find(document.sample(at)))))
	preview.cycle_tool.connect(func(): palette.select((palette.selected + 1) % tools_list.size()))
	preview.undo_requested.connect(undo)
	preview.redo_requested.connect(redo)
	preview.leave_grid.connect(func(): focus_button.grab_focus())
	var help := Label.new()
	mark(help, "WS_HELP")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(help)
	var right := side(body, 235)
	palette = option(right, tools_list.map(func(k): return LABELS[k]))
	required_check = checkbox(right, "WS_REQUIRED", true)
	rectangle_check = checkbox(right, "WS_RECTANGLE", false)
	rectangle_check.toggled.connect(func(value: bool): preview.rectangle = value; preview.anchor = Vector2i(-1, -1))
	focus_button = button(right, "WS_EDIT", func(): preview.grab_focus())
	button(right, "UNDO", undo)
	button(right, "REDO", redo)
	button(right, "ZOOM_IN", func(): zoom(4))
	button(right, "ZOOM_OUT", func(): zoom(-4))
	button(right, "WS_TEST", func(): play(false))
	button(right, "WS_PLAY", func(): play(true))
	button(right, "SAVE", save_map)
	button(right, "MY_MAPS", show_library)
	button(right, "COPY", copy_map)
	button(right, "EXPORT", export_dialog)
	button(right, "IMPORT", import_dialog)
	button(right, "MENU", func(): hide(); closed.emit())
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 52
	layout.add_child(notice)
	generate_map()
	retranslate()

func side(parent: Control, width: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func button(parent: Control, text: String, callback: Callable) -> Button:
	var value := Button.new()
	mark(value, text)
	value.custom_minimum_size.y = 36
	value.pressed.connect(callback)
	parent.add_child(value)
	return value

func option(parent: Control, labels: Array) -> OptionButton:
	var value := OptionButton.new()
	value.set_meta("tr_keys", labels)
	for text in labels:
		value.add_item(tr(text))
	value.custom_minimum_size.y = 36
	parent.add_child(value)
	return value

func checkbox(parent: Control, text: String, enabled: bool) -> CheckBox:
	var value := CheckBox.new()
	mark(value, text)
	value.button_pressed = enabled
	parent.add_child(value)
	return value

func add_number(parent: Control, key: String, text: String, low: int, high: int, step: int, initial: int) -> void:
	var label := Label.new()
	mark(label, text)
	parent.add_child(label)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var number := SpinBox.new()
	number.min_value = low
	number.max_value = high
	number.step = step
	number.value = initial
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(row, "-", func(): number.value -= step)
	row.add_child(number)
	button(row, "+", func(): number.value += step)
	settings[key] = number

func options() -> Dictionary:
	var result := {}
	for key in settings:
		result[key] = settings[key].button_pressed if settings[key] is CheckBox else int(settings[key].value)
	result.mode = MapValidationService.MODES[mode_select.selected]
	result.enemy_kind = "bomber" if result.mode == "arena_bot" else MapValidationService.ENEMIES[enemy_select.selected]
	result.bonus_kind = MapValidationService.POWERS[bonus_select.selected]
	result.hidden = hidden_check.button_pressed
	return result

func generate_map() -> void:
	var seed_value := int(Crypto.new().generate_random_bytes(4).decode_u32(0) & 0x7fffffff)
	if not document.data.is_empty() and seed_value == int(document.data.seed):
		seed_value = (seed_value + 1) % 2147483647
	var result := CustomMapGenerator.generate(options(), seed_value)
	if result.has("error"):
		notice.text = tr("MAP_INVALID")
		return
	var data: Dictionary = result.data
	data.id = CustomMapLibrary.new_id()
	data.title = title_field.text
	data.author = author_field.text
	data.created = Time.get_datetime_string_from_system(true)
	data.modified = data.created
	document.replace(data)
	preview.cursor = Vector2i.ONE
	preview.refresh()
	notice.text = tr("WS_GENERATED")

func paint(from: Vector2i, to: Vector2i) -> void:
	document.paint(from, to, tools_list[palette.selected], {"step": int(settings.enemy_step.value), "required": required_check.button_pressed, "hidden": hidden_check.button_pressed})
	preview.refresh()
	notice.text = tr("DONE") if MapValidationService.validate(document.data).is_empty() else tr("MAP_INVALID")

func undo() -> void:
	document.undo()
	sync_fields()

func redo() -> void:
	document.redo()
	sync_fields()

func zoom(amount: float) -> void:
	preview.cell_size = clampf(preview.cell_size + amount, 12, 48)
	preview.refresh()

func apply_rules() -> void:
	if document.data.is_empty():
		return
	document.checkpoint()
	for key in ["capacity", "range", "fuse_ticks", "time_limit", "remote"]:
		document.data.rules[key] = options()[key]
	notice.text = tr("WS_RULES_APPLIED") if MapValidationService.validate(document.data).is_empty() else tr("MAP_INVALID")

func update_metadata() -> void:
	document.data.title = title_field.text.strip_edges()
	document.data.author = author_field.text.strip_edges()
	document.data.modified = Time.get_datetime_string_from_system(true)

func save_map() -> void:
	update_metadata()
	var candidate := document.data.duplicate(true)
	candidate.revision = int(candidate.revision) + 1
	if library.store_map(candidate) == OK:
		document.data = candidate
		notice.text = tr("DONE")
	else:
		notice.text = tr("IO_ERROR")

func copy_map() -> void:
	document.checkpoint()
	document.data.id = CustomMapLibrary.new_id()
	document.data.revision = 1
	document.data.title += " · " + tr("COPY")
	document.data.created = Time.get_datetime_string_from_system(true)
	sync_fields()
	notice.text = tr("DONE")

func play(record_result: bool) -> void:
	update_metadata()
	var error := MapValidationService.validate(document.data)
	if not error.is_empty():
		notice.text = tr("MAP_INVALID")
		return
	hide()
	play_requested.emit(document.data.duplicate(true), record_result)

func sync_fields() -> void:
	if document.data.is_empty():
		return
	title_field.text = document.data.title
	author_field.text = document.data.author
	mode_select.select(MapValidationService.MODES.find(document.data.mode))
	settings.width.value = int(document.data.width)
	settings.height.value = int(document.data.height)
	for key in ["capacity", "range", "fuse_ticks", "time_limit"]:
		settings[key].value = document.data.rules[key]
	settings.remote.button_pressed = document.data.rules.remote
	preview.refresh()

func show_library() -> void:
	var maps := library.list_maps()
	var dialog := Window.new()
	dialog.title = tr("MY_MAPS")
	dialog.size = Vector2i(700, 500)
	dialog.exclusive = true
	add_child(dialog)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(layout)
	var items := ItemList.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for data in maps:
		items.add_item("%s · %s · v%d" % [data.title, tr({"solo": "WS_SOLO", "coop": "WS_COOP", "versus": "WS_DUEL", "arena_bot": "WS_BOTS"}[data.mode]), int(data.revision)])
	layout.add_child(items)
	if not maps.is_empty(): items.select(0)
	button(layout, "LOAD", func():
		if items.get_selected_items().is_empty(): return
		document.replace(maps[items.get_selected_items()[0]])
		sync_fields()
		dialog.queue_free())
	button(layout, "DELETE", func():
		if items.get_selected_items().is_empty(): return
		var selected: Dictionary = maps[items.get_selected_items()[0]]
		var confirm := ConfirmationDialog.new()
		confirm.title = tr("DELETE")
		confirm.ok_button_text = tr("DELETE")
		confirm.cancel_button_text = tr("CANCEL")
		confirm.dialog_text = tr("CONFIRM_DELETE") % selected.title
		dialog.add_child(confirm)
		confirm.confirmed.connect(func():
			var result := library.remove_map(selected.id)
			notice.text = tr("DONE") if result == OK else tr("IO_ERROR")
			dialog.queue_free())
		confirm.popup_centered())
	button(layout, "CLOSE", func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	items.grab_focus()

func file_dialog(save_mode: bool) -> MapFilePicker:
	var dialog := MapFilePicker.new()
	dialog.save_mode = save_mode
	add_child(dialog)
	dialog.popup_centered()
	return dialog

func export_dialog() -> void:
	update_metadata()
	var error := MapValidationService.validate(document.data)
	if not error.is_empty():
		notice.text = tr("MAP_INVALID")
		return
	var dialog := file_dialog(true)
	dialog.file_selected.connect(func(path: String):
		notice.text = tr("DONE") if library.export_map(path, document.data) == OK else tr("IO_ERROR")
		dialog.queue_free())

func import_dialog() -> void:
	var dialog := file_dialog(false)
	dialog.file_selected.connect(func(path: String):
		var data := library.import_map(path)
		if data.is_empty():
			notice.text = tr("IO_ERROR")
		else:
			document.replace(data)
			sync_fields()
			notice.text = tr("DONE")
		dialog.queue_free())

func mark(control: Control, key: String) -> void:
	control.set_meta("tr_key", key)
	control.text = tr(key)

func retranslate() -> void:
	if not is_instance_valid(root): return
	var locale := LanguageCatalog.normalize(TranslationServer.get_locale())
	root.theme = InterfaceTheme.create(locale)
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if locale == "ar" else Control.LAYOUT_DIRECTION_LTR
	translate_children(root)
	if is_instance_valid(notice): notice.text = ""

func translate_children(node: Node) -> void:
	if node.has_meta("tr_key"): node.text = tr(node.get_meta("tr_key"))
	if node is OptionButton and node.has_meta("tr_keys"):
		var keys: Array = node.get_meta("tr_keys")
		for index in range(keys.size()): node.set_item_text(index, tr(keys[index]))
	for child in node.get_children(): translate_children(child)
