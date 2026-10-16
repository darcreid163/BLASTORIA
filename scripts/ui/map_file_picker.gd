class_name MapFilePicker
extends Window

signal file_selected(path: String)
var save_mode: bool = false
var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
var path_field: LineEdit
var file_field: LineEdit
var items: ItemList
var notice: Label
var listing_folder: String = ""

func _ready() -> void:
	title = tr("EXPORT" if save_mode else "IMPORT")
	size = Vector2i(850, 600)
	exclusive = true
	theme = InterfaceTheme.create(TranslationServer.get_locale())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.layout_direction = Control.LAYOUT_DIRECTION_RTL if LanguageCatalog.normalize(TranslationServer.get_locale()) == "ar" else Control.LAYOUT_DIRECTION_LTR
	margin.add_child(layout)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var up := Button.new(); up.text = tr("UP_FOLDER"); row.add_child(up)
	up.pressed.connect(func(): navigate(listing_folder.get_base_dir()))
	path_field = LineEdit.new()
	path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_field.placeholder_text = tr("PATH")
	path_field.text_direction = Control.TEXT_DIRECTION_LTR
	path_field.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_FILE
	path_field.add_theme_font_override("font", LanguageCatalog.universal_font())
	row.add_child(path_field)
	path_field.text_submitted.connect(navigate)
	items = ItemList.new(); items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.add_theme_font_override("font", LanguageCatalog.universal_font())
	items.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layout.add_child(items)
	items.item_selected.connect(func(index: int):
		var data: Dictionary = items.get_item_metadata(index)
		if not data.directory: file_field.text = data.name)
	items.item_activated.connect(func(index: int):
		var data: Dictionary = items.get_item_metadata(index)
		if data.directory: navigate(listing_folder.path_join(data.name))
		else: file_field.text = data.name; choose())
	file_field = LineEdit.new(); file_field.placeholder_text = tr("FILENAME")
	file_field.text = "my_map.blastmap" if save_mode else ""
	file_field.text_direction = Control.TEXT_DIRECTION_LTR
	file_field.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_FILE
	file_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	file_field.add_theme_font_override("font", LanguageCatalog.universal_font())
	layout.add_child(file_field)
	file_field.text_submitted.connect(func(_value): choose())
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; layout.add_child(notice)
	var actions := HBoxContainer.new(); layout.add_child(actions)
	var accept := Button.new(); accept.text = tr("SAVE" if save_mode else "IMPORT"); actions.add_child(accept)
	accept.pressed.connect(choose)
	var cancel := Button.new(); cancel.text = tr("CANCEL"); actions.add_child(cancel)
	cancel.pressed.connect(queue_free)
	close_requested.connect(queue_free)
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): folder = OS.get_user_data_dir()
	navigate(folder)
	path_field.grab_focus()

func navigate(value: String) -> void:
	path_field.text = value
	items.clear()
	listing_folder = ""
	if not value.is_absolute_path(): notice.text = tr("IO_ERROR"); return
	var directory := DirAccess.open(value)
	if directory == null: notice.text = tr("IO_ERROR"); return
	listing_folder = directory.get_current_dir()
	path_field.text = listing_folder
	notice.text = ""
	var names: Array[String] = []
	for name in directory.get_directories(): names.append(name + "/")
	for name in directory.get_files():
		if name.get_extension().to_lower() == "blastmap": names.append(name)
	names.sort()
	for name in names:
		var index := items.add_item(name)
		items.set_item_metadata(index, {"name": name.trim_suffix("/"), "directory": name.ends_with("/")})

func choose() -> void:
	if path_field.text != listing_folder: navigate(path_field.text)
	if listing_folder.is_empty(): return
	var name := file_field.text.strip_edges()
	if name.is_empty() or name != name.get_file() or name in [".", ".."] or name.contains("\\"):
		notice.text = tr("IO_ERROR"); return
	if save_mode and name.get_extension().is_empty(): name += ".blastmap"
	if name.get_extension().to_lower() != "blastmap": notice.text = tr("IO_ERROR"); return
	var selected := listing_folder.path_join(name)
	if not save_mode and not FileAccess.file_exists(selected): notice.text = tr("IO_ERROR"); return
	if save_mode and FileAccess.file_exists(selected):
		var confirm := ConfirmationDialog.new()
		confirm.title = tr("REPLACE_FILE"); confirm.dialog_text = tr("REPLACE_FILE")
		confirm.ok_button_text = tr("SAVE"); confirm.cancel_button_text = tr("CANCEL")
		add_child(confirm)
		confirm.confirmed.connect(func(): file_selected.emit(selected))
		confirm.popup_centered()
	else: file_selected.emit(selected)
