extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var summary := {}
	for number in range(4,11):
		var results: Array = []
		for trial in range(1,7):
			var state := GameState.new();state.start_map(ArcadeLevelRegistry.load_stage(number),number)
			var pilot = load("res://tools/qa_arcade_pilot.gd").new(trial)
			var commands: Array = []
			for tick in range(18000):
				var command: Dictionary = pilot.command(state)
				state.advance({0:command})
				var movement: Vector2i = command.get("move",Vector2i.ZERO)
				commands.append([movement.x,movement.y,command.get("bomb",false),command.get("detonate",false)])
				if not state.result.is_empty():break
			results.append({"trial":trial,"result":state.result,"ticks":state.level_ticks,"score":state.score,"enemies_left":state.required_enemies()})
			if state.result=="MAP_CLEAR":
				DirAccess.make_dir_recursive_absolute("res://tests/fixtures/arcade")
				var file:=FileAccess.open("res://tests/fixtures/arcade/stage_%03d.json" % number,FileAccess.WRITE)
				file.store_string(JSON.stringify({"stage":number,"fingerprint":MapValidationService.fingerprint(state.map_data),"commands":commands,"score":state.score,"ticks":state.level_ticks},""))
				break
		summary[str(number)]=results
		print(number,": ",results)
	var output:=FileAccess.open("res://docs/qa/chapter_pilot.json",FileAccess.WRITE);output.store_string(JSON.stringify(summary,"  "));quit()
