class_name MapPreviewRenderer
extends Control

signal paint_requested(from: Vector2i, to: Vector2i)
signal sample_requested(at: Vector2i)
signal leave_grid
signal cycle_tool
signal undo_requested
signal redo_requested
var document: CustomMapDocument
var cell_size: float = 26
var cursor := Vector2i(1, 1)
var rectangle: bool = false
var anchor := Vector2i(-1, -1)

func refresh() -> void:
	if document == null or document.data.is_empty():
		return
	custom_minimum_size = Vector2(int(document.data.width), int(document.data.height)) * cell_size
	queue_redraw()

func _draw() -> void:
	if document == null or document.data.is_empty():
		return
	var data := document.data
	for y in range(int(data.height)):
		for x in range(int(data.width)):
			var color: Color = {"#": Color("59786a"), "C": Color("b7824a"), ".": Color("17382f"), "~": Color("367f9b")}[data.rows[y][x]]
			draw_rect(Rect2(Vector2(x, y) * cell_size, Vector2.ONE * (cell_size - 1)), color)
	for power in data.powerups:
		var at := Vector2(power.cell[0], power.cell[1]) * cell_size
		draw_circle(at + Vector2.ONE * cell_size * 0.5, cell_size * 0.22, Color("90d5ff"))
	for enemy in data.enemies:
		var at := Vector2(enemy.cell[0], enemy.cell[1]) * cell_size
		draw_rect(Rect2(at + Vector2.ONE * cell_size * 0.2, Vector2.ONE * cell_size * 0.6), Color("ed7771") if enemy.required else Color("b48cdb"))
	for i in range(data.spawns.size()):
		var p: Array = data.spawns[i]
		draw_circle(Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5) * cell_size, cell_size * 0.34, Color("5ff3b8") if i == 0 else Color("ffd06c"))
	draw_rect(Rect2(Vector2(cursor) * cell_size, Vector2.ONE * cell_size), Color.WHITE, false, 2)
	if anchor.x >= 0:
		draw_rect(Rect2(Vector2(anchor) * cell_size, Vector2.ONE * cell_size), Color("ffd06c"), false, 3)

func activate() -> void:
	if rectangle and anchor.x < 0:
		anchor = cursor
	else:
		paint_requested.emit(cursor if anchor.x < 0 else anchor, cursor)
		anchor = Vector2i(-1, -1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if document.data.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			cursor = Vector2i(event.position / cell_size)
			cursor = cursor.clamp(Vector2i.ONE, Vector2i(int(document.data.width) - 2, int(document.data.height) - 2))
			grab_focus()
			if event.button_index == MOUSE_BUTTON_LEFT:
				activate()
			else:
				sample_requested.emit(cursor)
			accept_event()
	if not has_focus():
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_left"): direction = Vector2i.LEFT
	if event.is_action_pressed("ui_right"): direction = Vector2i.RIGHT
	if event.is_action_pressed("ui_up"): direction = Vector2i.UP
	if event.is_action_pressed("ui_down"): direction = Vector2i.DOWN
	if direction != Vector2i.ZERO:
		cursor = (cursor + direction).clamp(Vector2i.ONE, Vector2i(int(document.data.width) - 2, int(document.data.height) - 2))
		reveal_cursor()
		queue_redraw()
		accept_event()
	if event.is_action_pressed("ui_accept"):
		activate()
		accept_event()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_focus_next"):
		anchor = Vector2i(-1, -1)
		leave_grid.emit()
		accept_event()
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_Y: cycle_tool.emit()
			JOY_BUTTON_X: sample_requested.emit(cursor)
			JOY_BUTTON_LEFT_SHOULDER: undo_requested.emit()
			JOY_BUTTON_RIGHT_SHOULDER: redo_requested.emit()
		accept_event()

func reveal_cursor() -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	var point := Vector2(cursor) * cell_size
	if point.x < scroll.scroll_horizontal: scroll.scroll_horizontal = int(point.x)
	if point.y < scroll.scroll_vertical: scroll.scroll_vertical = int(point.y)
	if point.x + cell_size > scroll.scroll_horizontal + scroll.size.x - 20:
		scroll.scroll_horizontal = int(point.x + cell_size - scroll.size.x + 20)
	if point.y + cell_size > scroll.scroll_vertical + scroll.size.y - 20:
		scroll.scroll_vertical = int(point.y + cell_size - scroll.size.y + 20)
