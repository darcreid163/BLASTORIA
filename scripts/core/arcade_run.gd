class_name ArcadeRun
extends RefCounted

var score: int = 0
var elapsed_ticks: int = 0
var next_stage: int = 0
var ended: bool = false
var completed: bool = false
var records_saved: bool = false

func accept_stage(state: GameState) -> bool:
	if ended or state.mode != "arcade" or state.level != next_stage or state.result.is_empty():
		return false
	score += state.score
	elapsed_ticks += state.tick
	if state.result == "LEVEL_CLEAR":
		next_stage += 1
	else:
		ended = true
		completed = state.result == "ARCADE_DONE"
	return true

func live_score(state: GameState) -> int:
	return score + (state.score if state.result.is_empty() else 0)

func live_ticks(state: GameState) -> int:
	return elapsed_ticks + (state.tick if state.result.is_empty() else 0)

static func format_time(ticks: int, rate: int = 60) -> String:
	var centiseconds := int(ticks * 100.0 / rate)
	return "%02d:%02d.%02d" % [int(centiseconds / 6000.0), int(centiseconds / 100.0) % 60, centiseconds % 100]
