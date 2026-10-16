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
const LABELS := {"floor": "Пол / стереть", "wall": "Каменная стена", "crate": "Деревянный блок", "spawn1": "Старт игрока 1", "spawn2": "Старт игрока 2", "patrol": "Патрульный", "chaser": "Преследователь", "bomber": "Бомбардир", "warden": "Страж", "capacity": "Больше бомб", "range": "Дальность", "speed": "Скорость", "remote": "Детонатор", "wall_pass": "Проход сквозь блоки", "bomb_pass": "Проход сквозь бомбы", "flame_pass": "Защита от огня", "invulnerability": "Неуязвимость"}

func _ready() -> void:
	layer = 10
	root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var layout := VBoxContainer.new()
	root.add_child(layout)
	var heading := Label.new()
	heading.text = "МАСТЕРСКАЯ КАРТ · Зелёный лабиринт · прототип 0.5"
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var left := side(body, 260)
	title_field = LineEdit.new()
	title_field.text = "Моя карта"
	title_field.max_length = 80
	left.add_child(title_field)
	author_field = LineEdit.new()
	author_field.text = "Игрок"
	author_field.max_length = 80
	left.add_child(author_field)
	mode_select = option(left, ["Соло: уничтожить врагов", "Дуэль: последний игрок"])
	add_number(left, "width", "Ширина", 11, 41, 2, 25)
	add_number(left, "height", "Высота", 11, 31, 2, 17)
	add_number(left, "enemy_count", "Врагов", 1, 32, 1, 3)
	enemy_select = option(left, MapValidationService.ENEMIES.map(func(k): return LABELS[k]))
	add_number(left, "enemy_step", "Шаг врага, тики", 9, 90, 1, 36)
	add_number(left, "bonus_count", "Бонусов", 0, 128, 1, 3)
	bonus_select = option(left, MapValidationService.POWERS.map(func(k): return LABELS[k]))
	hidden_check = checkbox(left, "Бонус под блоком", true)
	settings.walls = checkbox(left, "Каменные опоры", true)
	settings.crates = checkbox(left, "Разрушимые блоки", true)
	add_number(left, "capacity", "Бомб одновременно", 1, 5, 1, 1)
	add_number(left, "range", "Дальность бомбы", 1, 6, 1, 2)
	add_number(left, "fuse_ticks", "Фитиль, тики (60/с)", 90, 600, 30, 150)
	add_number(left, "time_limit", "Лимит секунд (0=∞)", 0, 1800, 30, 0)
	settings.remote = checkbox(left, "Дистанционные бомбы", false)
	button(left, "Сгенерировать новую", generate_map)
	button(left, "Применить правила", apply_rules)
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
	help.text = "Сетка: стрелки / D-pad · Enter / A — поставить · Esc / B — панель\nY — инструмент · X / ПКМ — взять образец · LB / RB — отмена / повтор\nЗелёный — игрок 1, жёлтый — игрок 2, красный — враг, синий — бонус"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(help)
	var right := side(body, 235)
	palette = option(right, tools_list.map(func(k): return LABELS[k]))
	required_check = checkbox(right, "Обязательный враг", true)
	rectangle_check = checkbox(right, "Прямоугольник: 2 точки", false)
	rectangle_check.toggled.connect(func(value: bool): preview.rectangle = value; preview.anchor = Vector2i(-1, -1))
	focus_button = button(right, "Редактировать сетку", func(): preview.grab_focus())
	button(right, "Отменить", undo)
	button(right, "Повторить", redo)
	button(right, "Увеличить +", func(): zoom(4))
	button(right, "Уменьшить −", func(): zoom(-4))
	button(right, "Проверить карту", func(): play(false))
	button(right, "Играть на рекорд", func(): play(true))
	button(right, "Сохранить", save_map)
	button(right, "Мои карты", show_library)
	button(right, "Создать копию", copy_map)
	button(right, "Экспорт .blastmap", export_dialog)
	button(right, "Импорт .blastmap", import_dialog)
	button(right, "Главное меню", func(): hide(); closed.emit())
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 52
	layout.add_child(notice)
	generate_map()

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
	value.text = text
	value.custom_minimum_size.y = 36
	value.pressed.connect(callback)
	parent.add_child(value)
	return value

func option(parent: Control, labels: Array) -> OptionButton:
	var value := OptionButton.new()
	for text in labels:
		value.add_item(text)
	value.custom_minimum_size.y = 36
	parent.add_child(value)
	return value

func checkbox(parent: Control, text: String, enabled: bool) -> CheckBox:
	var value := CheckBox.new()
	value.text = text
	value.button_pressed = enabled
	parent.add_child(value)
	return value

func add_number(parent: Control, key: String, text: String, low: int, high: int, step: int, initial: int) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var number := SpinBox.new()
	number.min_value = low
	number.max_value = high
	number.step = step
	number.value = initial
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(row, "−", func(): number.value -= step)
	row.add_child(number)
	button(row, "+", func(): number.value += step)
	settings[key] = number

func options() -> Dictionary:
	var result := {}
	for key in settings:
		result[key] = settings[key].button_pressed if settings[key] is CheckBox else int(settings[key].value)
	result.mode = "solo" if mode_select.selected == 0 else "versus"
	result.enemy_kind = MapValidationService.ENEMIES[enemy_select.selected]
	result.bonus_kind = MapValidationService.POWERS[bonus_select.selected]
	result.hidden = hidden_check.button_pressed
	return result

func generate_map() -> void:
	var seed_value := int(Crypto.new().generate_random_bytes(4).decode_u32(0) & 0x7fffffff)
	if not document.data.is_empty() and seed_value == int(document.data.seed):
		seed_value = (seed_value + 1) % 2147483647
	var result := CustomMapGenerator.generate(options(), seed_value)
	if result.has("error"):
		notice.text = result.error
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
	notice.text = "Создан новый экземпляр · seed %d. Геометрия сохраняется целиком. Проверка маршрутов не заменяет пробное прохождение." % seed_value

func paint(from: Vector2i, to: Vector2i) -> void:
	document.paint(from, to, tools_list[palette.selected], {"step": int(settings.enemy_step.value), "required": required_check.button_pressed, "hidden": hidden_check.button_pressed})
	preview.refresh()
	notice.text = "Изменено. " + MapValidationService.validate(document.data)

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
	notice.text = "Правила применены. Размер, состав и режим меняются при новой генерации. " + MapValidationService.validate(document.data)

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
		notice.text = "Карта сохранена. Раздел «Мои карты» — для повторной игры."
	else:
		notice.text = library.error

func copy_map() -> void:
	document.checkpoint()
	document.data.id = CustomMapLibrary.new_id()
	document.data.revision = 1
	document.data.title += " · копия"
	document.data.created = Time.get_datetime_string_from_system(true)
	sync_fields()
	notice.text = "Независимая копия. Нажмите «Сохранить», чтобы добавить в библиотеку."

func play(record_result: bool) -> void:
	update_metadata()
	var error := MapValidationService.validate(document.data)
	if not error.is_empty():
		notice.text = error
		return
	hide()
	play_requested.emit(document.data.duplicate(true), record_result)

func sync_fields() -> void:
	if document.data.is_empty():
		return
	title_field.text = document.data.title
	author_field.text = document.data.author
	mode_select.select(0 if document.data.mode == "solo" else 1)
	settings.width.value = int(document.data.width)
	settings.height.value = int(document.data.height)
	for key in ["capacity", "range", "fuse_ticks", "time_limit"]:
		settings[key].value = document.data.rules[key]
	settings.remote.button_pressed = document.data.rules.remote
	preview.refresh()

func show_library() -> void:
	var maps := library.list_maps()
	var dialog := Window.new()
	dialog.title = "Мои карты — до 200 записей"
	dialog.size = Vector2i(700, 500)
	dialog.exclusive = true
	add_child(dialog)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(layout)
	var items := ItemList.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for data in maps:
		items.add_item("%s · %s · v%d" % [data.title, data.mode, int(data.revision)])
	layout.add_child(items)
	if not maps.is_empty(): items.select(0)
	button(layout, "Загрузить / редактировать", func():
		if items.get_selected_items().is_empty(): return
		document.replace(maps[items.get_selected_items()[0]])
		sync_fields()
		dialog.queue_free())
	button(layout, "Удалить…", func():
		if items.get_selected_items().is_empty(): return
		var selected: Dictionary = maps[items.get_selected_items()[0]]
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "Удалить «%s»?" % selected.title
		dialog.add_child(confirm)
		confirm.confirmed.connect(func():
			var result := library.remove_map(selected.id)
			notice.text = "Удалено." if result == OK else "Ошибка удаления: " + error_string(result)
			dialog.queue_free())
		confirm.popup_centered())
	button(layout, "Закрыть", func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	items.grab_focus()

func file_dialog(save_mode: bool) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.blastmap ; BLASTORIA map"])
	dialog.title = "Экспорт карты" if save_mode else "Импорт карты"
	dialog.current_file = "my_map.blastmap" if save_mode else ""
	add_child(dialog)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.8)
	return dialog

func export_dialog() -> void:
	update_metadata()
	var error := MapValidationService.validate(document.data)
	if not error.is_empty():
		notice.text = error
		return
	var dialog := file_dialog(true)
	dialog.file_selected.connect(func(path: String):
		notice.text = "Карта экспортирована. Файл можно передать другу." if library.export_map(path, document.data) == OK else library.error
		dialog.queue_free())

func import_dialog() -> void:
	var dialog := file_dialog(false)
	dialog.file_selected.connect(func(path: String):
		var data := library.import_map(path)
		if data.is_empty():
			notice.text = library.error
		else:
			document.replace(data)
			sync_fields()
			notice.text = "Импортировано в «Мои карты» как отдельная карта."
		dialog.queue_free())
