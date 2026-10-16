extends RefCounted

func run(test: SceneTree) -> void:
	var pool: Array[Dictionary] = []
	for i in range(8): pool.append({"playing": true, "kind": "victory", "order": i})
	test.check(AudioManager.select_voice(pool, "step") == -1 and AudioManager.select_voice(pool, "explosion") == -1, "audio priority: movement and blast cannot cut a full result pool")
	pool[5] = {"playing": true, "kind": "step", "order": 20}
	pool[2] = {"playing": true, "kind": "step", "order": 3}
	test.check(AudioManager.select_voice(pool, "death") == 2, "audio priority: fatal cue replaces oldest least-important sound")
	pool[6].playing = false
	test.check(AudioManager.select_voice(pool, "fuse") == 6, "audio priority: free voice is used before interrupting a sound")
	test.check(AudioManager.select_voice(pool, "unknown") == -1, "audio priority: unsupported cue never reaches pool")

	var state := GameState.new()
	state.start(GameConfig.new(), "arena", 0, 221)
	var view := BoardView.new(); test.root.add_child(view)
	await test.process_frame
	view.build(state)
	state.bombs.place(Vector2i(1, 1), 0, 3, 2, 0, 150)
	state.bombs.place(Vector2i(1, 3), 0, 3, 2, 0, 1, true)
	view.sync(state, 0)
	var timed: Node3D = view.bombs[1]
	var remote: Node3D = view.bombs[2]
	test.check(visible_pips(timed) == 4 and not timed.get_meta("remote") and remote.get_meta("remote"), "bomb view: four fuse divisions and distinct remote antenna")
	state.tick = 90; view.sync(state, 0)
	test.check(visible_pips(timed) == 2, "bomb view: divisions follow actual remaining fuse ticks")
	state.tick = 120; view.sync(state, 0)
	test.check(visible_pips(timed) == 1, "bomb view: final half-second keeps one visible warning")
	test.check(visible_pips(remote) == 4 and remote.scale == Vector3.ONE, "bomb view: overdue remote bomb never presents a false countdown")
	var before := state.snapshot(); view.sync(state, .2)
	test.check(state.snapshot() == before, "view: cues never mutate simulation, RNG or score")

	state.start(GameConfig.new(), "arena", 0, 221)
	for cell in state.board.cells:
		if state.board.kind(cell) == GridBoard.Cell.CRATE: state.board.cells[cell] = GridBoard.Cell.FLOOR
	state.board.cells[Vector2i(3, 1)] = GridBoard.Cell.CRATE
	state.actors[0].cell = Vector2i(5, 5)
	view.build(state)
	state.bombs.place(Vector2i(1, 1), 0, 4, 2, 0, 1)
	state.bombs.place(Vector2i(2, 1), 0, 4, 2, 0, 100)
	view.sync(state, 0)
	state.advance(); view.sync(state, 0)
	test.check(state.bombs.bombs.is_empty() and view.bombs.is_empty() and state.bombs.detonations_this_tick == 2, "view: actual chain removes both bomb models on the detonation tick")
	test.check(same_cells(view.fire, state.bombs.fire) and not view.fire.has(Vector2i(4, 1)), "view: fire footprint equals logical hazards and stops at destroyed crate")
	test.check(view.effects.size() == 1 and view.effects[0].kind == "crate" and not view.crates.has(Vector2i(3, 1)), "view: actual destruction creates one bounded wood burst")
	var receiver := func(id: int, _kind: String): view.notify_pickup(state, id)
	state.pickup.connect(receiver)
	state.collect(state.actors[0], "range")
	test.check(view.effects.size() == 2 and view.effects[1].kind == "pickup", "view: actual pickup event creates a local rising cue")
	state.bombs.fire[state.actors[0].cell] = state.tick + state.config.fire_ticks
	state.apply_damage(); view.sync(state, 0)
	var count := view.effects.size(); view.sync(state, 0)
	test.check(count == 3 and view.effects.size() == count and not view.actors[0].visible, "view: fatal damage creates one cue without respawning it on each frame")
	view.update_effects(state.tick)
	var point: Vector3 = view.effects[1].node.get_child(0).position
	state.paused = true; before = state.snapshot(); view.sync(state, 0)
	test.check(view.effects[1].node.get_child(0).position == point and state.snapshot() == before, "view: pause freezes effect trajectories and logical time")
	for i in range(40): view.spawn_effect("crate", Vector3.ZERO, state.tick, state.config.tick_rate)
	test.check(view.effects.size() == BoardView.MAX_EFFECTS, "view: mass destruction cannot exceed 24 transient groups")
	view.update_effects(state.tick + state.config.tick_rate)
	test.check(view.effects.is_empty(), "view: transient groups expire and detach after their duration")
	state.paused = false
	state.tick += state.config.fire_ticks + 1
	state.bombs.advance(state.tick, state.board, state.config.fire_ticks)
	view.sync(state, 0)
	test.check(view.fire.is_empty() and state.bombs.fire.is_empty(), "view: no decorative flame remains after the last hazardous tick")
	view.spawn_effect("pickup", Vector3.ZERO, state.tick, state.config.tick_rate)
	state.start(GameConfig.new(), "arena", 0, 221); view.build(state)
	test.check(view.effects.is_empty() and view.bombs.is_empty() and view.fire.is_empty(), "view: restart clears all old transient and hazard models")
	state.pickup.disconnect(receiver)
	view.queue_free(); await test.process_frame; await test.process_frame

func visible_pips(node: Node3D) -> int:
	var amount := 0
	for pip in node.get_meta("pips"):
		if pip.visible: amount += 1
	return amount

func same_cells(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for cell in a:
		if not b.has(cell): return false
	return true
