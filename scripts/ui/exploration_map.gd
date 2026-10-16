class_name ExplorationMap
extends Control

var state: GameState
var expanded: bool = false

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.04, 0.055, 0.96))
	var unit := minf((size.x - 24) / state.board.width, (size.y - 42) / state.board.height)
	var offset := Vector2((size.x - unit * state.board.width) * 0.5, 28)
	for cell in state.exploration.known:
		var kind: int = state.exploration.known[cell]
		var color: Color = [Color("34544e"), Color("8caca2"), Color("9c704d"), Color("367f9b")][kind]
		draw_rect(Rect2(offset + Vector2(cell) * unit, Vector2.ONE * maxf(1, unit - 0.5)), color)
	for landmark in state.board.landmarks:
		if state.exploration.known.get(landmark) == GridBoard.Cell.FLOOR:
			draw_circle(offset + (Vector2(landmark) + Vector2.ONE * 0.5) * unit, maxf(2, unit * 0.3), Color("bfa9d5"))
	var exit_cell := state.board.exit_cell
	if state.exit_revealed and state.exploration.known.get(exit_cell) == GridBoard.Cell.FLOOR:
		draw_circle(offset + (Vector2(exit_cell) + Vector2.ONE * 0.5) * unit, maxf(2, unit * 0.4), Color("ffd269"))
	draw_circle(offset + (Vector2(state.actors[0].cell) + Vector2.ONE * 0.5) * unit, maxf(3, unit * 0.45), Color("59ffe0"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 19), tr("MAP_TITLE") % state.exploration.percent(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
