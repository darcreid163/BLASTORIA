extends SceneTree
var valid: bool = true
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_073/" + name + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa_073")
	var scene = load("res://scenes/main.tscn").instantiate(); root.add_child(scene); await process_frame
	scene.set_physics_process(false); scene.set_process(false)
	scene.official.save.path = "user://qa_hazard_visual_records.json"; scene.official.save.unlocked = 9
	LanguageCatalog.apply(self, "ru"); scene.profile.language = "ru"
	var captures := {}
	for stage in [4, 6]:
		scene.start_official(stage)
		var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade/stage_%03d.json" % stage))
		var blast_at := -100
		for frame in replay.commands:
			scene.state.advance({0: {"move": Vector2i(int(frame[0]), int(frame[1])), "bomb": frame[2], "detonate": frame[3]}})
			scene.view.sync(scene.state, 1.0 / 60.0); scene.hud.update_state(scene.state)
			if stage == 4 and not captures.has("warning_ru"):
				for bomb in scene.state.bombs.bombs.values():
					if not bomb.remote and bomb.due - scene.state.tick == 25:
						await shot("warning_ru"); captures.warning_ru = true; break
			if stage == 4 and scene.state.bombs.detonations_this_tick > 0 and blast_at < 0: blast_at = scene.state.tick
			if stage == 4 and scene.state.tick == blast_at + 5:
				await shot("blast_ru"); captures.blast_ru = true
			if stage == 4 and not captures.has("pickup_ru") and scene.view.effects.any(func(e): return e.kind == "pickup"):
				await shot("pickup_ru"); captures.pickup_ru = true
			if stage == 6 and not captures.has("remote_ru"):
				for bomb in scene.state.bombs.bombs.values():
					if bomb.remote and scene.view.actors[0].position.distance_to(scene.view.pos(bomb.cell)) > 0.95:
						await shot("remote_ru"); captures.remote_ru = true; break
			if scene.state.result != "": break
		captures["stage_%d_clear" % stage] = scene.state.result == "MAP_CLEAR"
	# Exercise the real voice pool under the native graphical Dummy backend.
	var audio: AudioManager = scene.audio_manager
	audio.stop_effects(); audio.play("victory")
	for i in range(16): audio.play("step")
	var protected := false
	for voice in audio.voices:
		if voice.playing and voice.get_meta("kind", "") == "victory": protected = true
	captures.result_voice_protected = protected
	captures.graphical_playback_enabled = audio.playback_enabled
	audio.stop_effects()
	captures.voices_stopped = audio.voices.all(func(v): return not v.playing)
	await create_timer(0.15).timeout
	for value in captures.values(): valid = valid and bool(value)
	valid = valid and captures.has_all(["warning_ru", "blast_ru", "pickup_ru", "remote_ru"])
	var file := FileAccess.open("res://docs/qa/hazard_visual.json", FileAccess.WRITE); file.store_string(JSON.stringify(captures, "  ") + "\n")
	print("HAZARD GRAPHICAL: ", captures)
	scene.queue_free(); await process_frame; await process_frame; await process_frame; await create_timer(0.1).timeout; quit(0 if valid else 1)
