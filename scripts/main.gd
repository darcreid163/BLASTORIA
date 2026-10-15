extends Node3D
## BLASTORIA 0.1 — original prototype. Logic is tile based; visuals are generated 3D meshes.

const W := 15
const H := 11
const STEP := 0.145
const FUSE := 2.05
const FIRE_TIME := 0.52
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var rng := RandomNumberGenerator.new()
var mode := "campaign"
var level := 1
var cells: Dictionary = {} # Vector2i -> "solid" / "crate" / "empty"
var tiles: Dictionary = {}
var players: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bombs: Array[Dictionary] = []
var fires: Dictionary = {} # Vector2i -> seconds left
var bomb_nodes: Dictionary = {}
var fire_nodes: Dictionary = {}
var crate_nodes: Dictionary = {}
var world: Node3D
var ui: CanvasLayer
var status_label: Label
var hint_label: Label
var tick := 0.0
var ended := false
var exit_cell := Vector2i(13, 9)
var exit_node: MeshInstance3D
var material_cache: Dictionary = {}
var camera: Camera3D

func _ready() -> void:
	rng.randomize()
	_create_camera_and_light()
	_create_ui()
	_start_game("campaign")

func _make_material(color: Color, emission := false) -> StandardMaterial3D:
	var key := color.to_html() + str(emission)
	if material_cache.has(key):
		return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.68
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	material_cache[key] = mat
	return mat

func _cube(parent: Node3D, pos: Vector3, scale: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = scale
	m.mesh = mesh
	m.position = pos
	m.material_override = _make_material(color, glow)
	parent.add_child(m)
	return m

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = 2.0 * radius
	m.mesh = mesh
	m.position = pos
	m.material_override = _make_material(color, glow)
	parent.add_child(m)
	return m

func _world_pos(p: Vector2i) -> Vector3:
	return Vector3(float(p.x) - (W - 1) * 0.5, 0, float(p.y) - (H - 1) * 0.5)

func _create_camera_and_light() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21
	camera.position = Vector3(0, 19, 13)
	camera.rotation_degrees = Vector3(-56, 0, 0)
	camera.current = true
	add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	light.light_energy = 1.6
	add_child(light)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101c2d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b2c6ec")
	env.ambient_light_energy = 0.75
	ambient.environment = env
	add_child(ambient)

func _create_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.13, 0.85)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 78
	ui.add_child(panel)
	status_label = Label.new()
	status_label.position = Vector2(25, 12)
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color("f7db82"))
	ui.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(26, 48)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("d8e7ff"))
	ui.add_child(hint_label)

func _start_game(new_mode: String) -> void:
	mode = new_mode
	ended = false
	tick = 0
	cells.clear(); tiles.clear(); players.clear(); enemies.clear(); bombs.clear(); fires.clear()
	bomb_nodes.clear(); fire_nodes.clear(); crate_nodes.clear()
	if is_instance_valid(world):
		world.queue_free()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_level()
	_spawn_actor(Vector2i(1,1), 0, false)
	if mode == "arena":
		_spawn_actor(Vector2i(W-2,H-2), 1, false)
	else:
		for p in [Vector2i(13,1), Vector2i(1,9), Vector2i(11,7)]:
			_spawn_actor(p, -1, true)
	_update_hud()

func _build_level() -> void:
	var floor_colors := [Color("233d52"), Color("28465b")]
	for y in range(H):
		for x in range(W):
			var p := Vector2i(x,y)
			var solid := (x == 0 or x == W-1 or y == 0 or y == H-1 or (x % 2 == 0 and y % 2 == 0))
			var safe := _is_spawn_safe(p)
			var crate := not solid and not safe and rng.randf() < (0.37 if mode == "campaign" else 0.43)
			var kind := "solid" if solid else ("crate" if crate else "empty")
			cells[p] = kind
			_cube(world, _world_pos(p) + Vector3(0, -0.18, 0), Vector3(0.98, 0.24, 0.98), floor_colors[(x + y) % 2])
			if kind == "solid":
				_cube(world, _world_pos(p) + Vector3(0, 0.45, 0), Vector3(0.95, 1.13, 0.95), Color("57778f"))
				_cube(world, _world_pos(p) + Vector3(0, 1.03, 0), Vector3(0.92, 0.08, 0.92), Color("86a7b6"))
			elif kind == "crate":
				crate_nodes[p] = _cube(world, _world_pos(p) + Vector3(0, 0.32, 0), Vector3(0.82, 0.68, 0.82), Color("bc8356"))
	if mode == "campaign":
		cells[exit_cell] = "empty"
		if crate_nodes.has(exit_cell):
			crate_nodes[exit_cell].queue_free(); crate_nodes.erase(exit_cell)
		exit_node = _cube(world, _world_pos(exit_cell) + Vector3(0, 0.02, 0), Vector3(0.65, 0.07, 0.65), Color("31caa7"), true)

func _is_spawn_safe(p: Vector2i) -> bool:
	for center in [Vector2i(1,1), Vector2i(13,9), Vector2i(13,1), Vector2i(1,9), Vector2i(11,7)]:
		if abs(p.x-center.x)+abs(p.y-center.y) <= 1:
			return true
	return false

func _spawn_actor(p: Vector2i, id: int, is_enemy: bool) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.position = _world_pos(p)
	_sphere(root, Vector3(0, 0.45, 0), 0.36, Color("f17c6a") if is_enemy else (Color("5ce2ce") if id == 0 else Color("ffce65")))
	_sphere(root, Vector3(-0.11, 0.53, -0.29), 0.065, Color("142635"))
	_sphere(root, Vector3(0.11, 0.53, -0.29), 0.065, Color("142635"))
	var a := {"cell":p, "id":id, "enemy":is_enemy, "alive":true, "root":root, "cooldown":0.0, "range":2, "capacity":1}
	if is_enemy:
		enemies.append(a)
	else:
		players.append(a)

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R) and ended:
		_start_game(mode)
	if Input.is_key_pressed(KEY_F1) and mode != "campaign":
		level = 1; _start_game("campaign")
	if Input.is_key_pressed(KEY_F2) and mode != "arena":
		_start_game("arena")
	if ended:
		return
	for a in players:
		if a["alive"]:
			a["cooldown"] = maxf(0.0, a["cooldown"] - delta)
			_handle_input(a)
	for a in enemies:
		if a["alive"]:
			a["cooldown"] -= delta
			if a["cooldown"] <= 0:
				_enemy_turn(a)
	for b in bombs.duplicate():
		b["time"] -= delta
		if b["time"] <= 0:
			_explode(b)
	for p in fires.keys():
		fires[p] -= delta
		if fires[p] <= 0:
			fires.erase(p)
			if fire_nodes.has(p):
				fire_nodes[p].queue_free(); fire_nodes.erase(p)
	for a in players + enemies:
		if a["alive"] and fires.has(a["cell"]):
			_kill(a)
	_check_end()

func _handle_input(a: Dictionary) -> void:
	var prefix := "move_" if a["id"] == 0 else "p2_"
	var dir := Vector2i.ZERO
	if Input.is_action_pressed(prefix+"up"): dir = Vector2i.UP
	elif Input.is_action_pressed(prefix+"down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed(prefix+"left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed(prefix+"right"): dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO and a["cooldown"] <= 0:
		_move(a, dir)
		if a["cooldown"] == 0.0: a["cooldown"] = STEP
	if Input.is_action_just_pressed("bomb_p1" if a["id"] == 0 else "bomb_p2"):
		_place_bomb(a)

func _walkable(p: Vector2i) -> bool:
	if cells.get(p,"solid") != "empty": return false
	for b in bombs:
		if b["cell"] == p: return false
	for a in players + enemies:
		if a["alive"] and a["cell"] == p: return false
	return true

func _move(a: Dictionary, d: Vector2i) -> void:
	var dest: Vector2i = a["cell"] + d
	if not _walkable(dest): return
	a["cell"] = dest
	a["cooldown"] = STEP if not a["enemy"] else 0.42
	var tween := create_tween()
	tween.tween_property(a["root"], "position", _world_pos(dest), STEP * 0.8)

func _enemy_turn(a: Dictionary) -> void:
	var choices: Array[Vector2i] = []
	for d in DIRS:
		var p: Vector2i = a["cell"] + d
		if _walkable(p) and not _is_threatened(p): choices.append(d)
	if choices.is_empty():
		a["cooldown"] = 0.33
		return
	var d: Vector2i = choices[rng.randi_range(0, choices.size()-1)]
	_move(a, d)
	if rng.randf() < 0.27: _place_bomb(a)

func _is_threatened(p: Vector2i) -> bool:
	if fires.has(p): return true
	for b in bombs:
		if b["cell"].x == p.x or b["cell"].y == p.y:
			if abs(b["cell"].x-p.x)+abs(b["cell"].y-p.y) <= b["range"]: return true
	return false

func _place_bomb(a: Dictionary) -> void:
	var owned := 0
	for b in bombs:
		if b["owner"] == a["root"]: owned += 1
	if owned >= a["capacity"]: return
	var p: Vector2i = a["cell"]
	for b in bombs:
		if b["cell"] == p: return
	var node := Node3D.new()
	world.add_child(node)
	node.position = _world_pos(p)
	_sphere(node, Vector3(0, 0.37, 0), 0.31, Color("182334"))
	_sphere(node, Vector3(0, 0.68, 0), 0.105, Color("ffe17b"), true)
	var bomb := {"cell":p,"time":FUSE,"range":a["range"],"owner":a["root"],"node":node}
	bombs.append(bomb)

func _explode(b: Dictionary) -> void:
	if not bombs.has(b): return
	bombs.erase(b)
	b["node"].queue_free()
	var origin: Vector2i = b["cell"]
	_ignite(origin)
	for d in DIRS:
		for distance in range(1, b["range"]+1):
			var p: Vector2i = origin + d*distance
			var kind: String = cells.get(p,"solid")
			if kind == "solid": break
			_ignite(p)
			if kind == "crate":
				cells[p] = "empty"
				if crate_nodes.has(p):
					crate_nodes[p].queue_free(); crate_nodes.erase(p)
				break
	for other in bombs.duplicate():
		if fires.has(other["cell"]): _explode(other)

func _ignite(p: Vector2i) -> void:
	fires[p] = FIRE_TIME
	if fire_nodes.has(p): return
	var visual := _cube(world, _world_pos(p)+Vector3(0,0.24,0), Vector3(0.82,0.46,0.82), Color("ff9c41"), true)
	fire_nodes[p] = visual

func _kill(a: Dictionary) -> void:
	a["alive"] = false
	a["root"].visible = false

func _check_end() -> void:
	if mode == "campaign":
		if not players[0]["alive"]:
			_end("Поражение! Нажми R для повтора")
			return
		var remain := 0
		for a in enemies:
			if a["alive"]: remain += 1
		if remain == 0 and players[0]["cell"] == exit_cell:
			level += 1
			_start_game("campaign")
		else:
			status_label.text = "BLASTORIA  ·  КАМПАНИЯ / УРОВЕНЬ %d  ·  ВРАГОВ: %d" % [level, remain]
	else:
		var living: Array[Dictionary] = []
		for a in players:
			if a["alive"]: living.append(a)
		if living.size() <= 1:
			_end("НИЧЬЯ!" if living.is_empty() else ("ПОБЕДИЛ ИГРОК %d!" % (living[0]["id"]+1)))

func _end(message: String) -> void:
	ended = true
	status_label.text = message
	hint_label.text = "R — начать заново  |  F1 — кампания  |  F2 — арена"

func _update_hud() -> void:
	status_label.text = "BLASTORIA  ·  КАМПАНИЯ" if mode == "campaign" else "BLASTORIA  ·  АРЕНА НА ДВОИХ"
	hint_label.text = "WASD + ПРОБЕЛ — игрок 1  |  СТРЕЛКИ + ENTER — игрок 2  |  F1 — кампания  |  F2 — арена  |  R — рестарт. В кампании уничтожь врагов и дойди до зелёного выхода."
