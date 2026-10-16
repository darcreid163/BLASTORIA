class_name ReleasePlan
extends RefCounted

# Official stage numbering shared by both progression tracks; their rules remain distinct.
const LAUNCH_STAGES := 51
const PLANNED_STAGES := 100

static func stage_available(number: int) -> bool:
	return number >= 1 and number <= LAUNCH_STAGES
