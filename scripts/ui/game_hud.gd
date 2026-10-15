class_name GameHUD
extends CanvasLayer

signal action_requested(action: String)
var status: Label
var hint: Label
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
	layout.add_child(status)
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
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.065, 0.09, 0.94)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 460
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

func show_menu(title: String, buttons: Array) -> void:
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
	subtitle.text = "BLASTORIA  •  Worlds of Chaos  •  0.2"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	for item in buttons:
		var button := Button.new()
		button.text = tr(item[0])
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 20)
		var action: String = item[1]
		button.pressed.connect(func(): action_requested.emit(action))
		column.add_child(button)
	overlay.show()
	if column.get_child_count() > 2:
		column.get_child(2).grab_focus()

func update_state(state: GameState) -> void:
	var actor: Dictionary = state.actors[0]
	status.text = "%s  |  %s %d  |  %s %d  |  B %d / R %d" % ["BLASTORIA", tr(state.mode.to_upper()), state.level + 1, tr("ENEMIES"), state.alive_enemies(), actor.capacity, actor.radius]
	hint.text = tr("CONTROLS")
	if state.mode == "campaign":
		hint.text += "\n" + tr("GOAL")

func notify_pickup(kind: String) -> void:
	toast.text = tr("PICKUP_" + kind.to_upper())
	toast_time = 2.0

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast.text = ""
