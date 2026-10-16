extends SceneTree
var valid: bool = true
func _initialize() -> void:call_deferred("run")
func require(condition: bool,title: String) -> void:
	valid=valid and condition
	print("PASS: " if condition else "FAIL: ",title)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:quit(1);return
	var scene = load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.official.save.path="user://qa_chapter_official.json";scene.official.save.unlocked=3
	require(ArcadeLevelRegistry.playable_count()==20 and ArcadeLevelRegistry.load_stage(21).is_empty(),"release: twenty authored stages and planned next stage blocked")
	for number in range(4,21):
		var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("stage_%03d.json" % number)))
		scene.start_official(number)
		require(scene.state.level==number-1 and scene.state.mode=="official_arcade","release: menu progression loads stage %d" % number)
		for frame in replay.commands:
			scene.state.advance({0:{"move":Vector2i(int(frame[0]),int(frame[1])),"bomb":frame[2],"detonate":frame[3]}})
		var data := ArcadeLevelRegistry.load_stage(number)
		var record: Dictionary = scene.official.save.record_for(scene.official.key_for(data))
		require(scene.state.result=="MAP_CLEAR" and scene.state.score==int(replay.score) and scene.state.level_ticks==int(replay.ticks),"release: real inputs clear stage %d with exact score/time" % number)
		require(record.score==int(replay.score) and record.best_ticks==int(replay.ticks),"release: result screen persists stage %d record" % number)
	var loaded:=ArcadeProgressionManager.new();loaded.save.path=scene.official.save.path;loaded.read_progress()
	require(loaded.save.unlocked==20 and loaded.save.arcade_records.size()==17 and not loaded.available(21),"release: chapter reload preserves all records without enabling planned content")
	require(not FileAccess.file_exists("res://tools/qa_arcade_pilot.gd") and not FileAccess.file_exists("res://tests/fixtures/arcade/stage_004.json"),"release: QA input driver and replays are excluded from player package")
	scene.queue_free();await process_frame
	print("CHAPTER EXPORT: ","PASS" if valid else "FAIL");quit(0 if valid else 1)
