extends SceneTree
var valid: bool = true
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_074/"+name+".png")
func fits(control: Control) -> bool:
	var rect:=control.get_global_rect()
	return rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=800
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/qa_074")
	var scene=load("res://scenes/main.tscn").instantiate(); root.add_child(scene); await process_frame
	scene.set_physics_process(false); scene.official.save.unlocked=19
	var bounds: Dictionary={}
	for locale in LanguageCatalog.LOCALES:
		LanguageCatalog.apply(self,locale);scene.profile.language=locale
		var ok:=true
		for page in range(2):
			scene.show_official_menu(page);await shot("chapter_%d_" % (page+1)+locale)
			ok=ok and fits(scene.hud.column)
			for button in scene.hud.column.get_child(3).get_children():ok=ok and fits(button)
			scene.show_official_records(page);await shot("records_%d_" % (page+1)+locale)
			ok=ok and fits(scene.hud.column)
		bounds[locale]=ok;valid=valid and ok
	LanguageCatalog.apply(self,"ru");scene.profile.language="ru"
	for stage in [11,15,20]:
		scene.start_official(stage);scene.state.paused=true;await shot("stage_%02d_ru" % stage)
	LanguageCatalog.apply(self,"ar");scene.profile.language="ar";scene.start_official(11);scene.state.paused=true
	for kind in MapValidationService.POWERS:scene.state.collect(scene.state.actors[0],kind)
	scene.hud.clear_pickup();scene.hud.update_state(scene.state)
	var corners_ok:=true
	for cell in [Vector2i(1,1),Vector2i(23,1),Vector2i(1,15),Vector2i(23,15)]:
		scene.state.actors[0].cell=cell
		scene.view.follow.update(scene.view.camera,scene.view.pos(cell),25,17,0,true)
		scene.view.actors[0].position=scene.view.pos(cell)
		await shot("max_ar_%d_%d" % [cell.x,cell.y])
		var head:Vector2=scene.view.camera.unproject_position(scene.view.pos(cell)+Vector3(0,1,0))
		var feet:Vector2=scene.view.camera.unproject_position(scene.view.pos(cell))
		corners_ok=corners_ok and head.y>=scene.hud.top_frame.get_global_rect().end.y+16 and feet.y<=scene.hud.hint_frame.get_global_rect().position.y-16
		print("HERO CLEARANCE: ",cell," head=",head.y," feet=",feet.y," top=",scene.hud.top_frame.get_global_rect().end.y," bottom=",scene.hud.hint_frame.get_global_rect().position.y)
	bounds["ar_max_powers_corners"]=corners_ok;valid=valid and corners_ok
	var f:=FileAccess.open("res://docs/qa/ruins_bounds.json",FileAccess.WRITE);f.store_string(JSON.stringify(bounds,"  ")+"\n")
	print("RUINS GRAPHICAL: ",bounds)
	scene.audio_manager.stop_effects();await create_timer(0.15).timeout
	scene.queue_free();await process_frame;await process_frame;await create_timer(0.1).timeout;quit(0 if valid else 1)
