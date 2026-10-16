extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, title: String) -> void:
	if condition: passed += 1; print("PASS: ", title)
	else: failed += 1; push_error("FAIL: " + title)
func run() -> void:
	# Same behavioral contract against compiled view/audio in the actual PCK.
	await load(OS.get_cmdline_user_args()[0]).new().run(self)
	print("HAZARD EXPORT: %d passed / %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
