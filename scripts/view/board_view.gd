class_name BoardView
extends Node3D

var config: GameConfig
var world: Node3D
var camera: Camera3D
var actors: Dictionary = {}
var crates: Dictionary = {}
var bombs: Dictionary = {}
var fire: Dictionary = {}
var drops: Dictionary = {}
var exit_mesh: MeshInstance3D
var materials: Dictionary = {}
var follow := FollowCamera.new()
var artifact: Node3D
var static_batches: Dictionary = {}

func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.position = Vector3(0, 17, 12)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101e29")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3dbc8")
	env.ambient_light_energy = 0.35
	environment.environment = env
	add_child(environment)

func material(color: String, glow: bool = false) -> StandardMaterial3D:
	var key := color + str(glow)
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.8
		if Color(color).a < 1: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = glow
		mat.emission = Color(color)
		mat.emission_energy_multiplier = 1.3
		materials[key] = mat
	return materials[key]

func box(parent: Node3D, position_value: Vector3, size: Vector3, color: String, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, glow)
	node.position = position_value
	parent.add_child(node)
	return node

func sphere(parent: Node3D, position_value: Vector3, radius: float, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position_value
	parent.add_child(node)
	return node

func pos(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - (config.width - 1) / 2.0, 0, cell.y - (config.height - 1) / 2.0)

func build(state: GameState) -> void:
	config = state.config
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	actors.clear()
	crates.clear()
	bombs.clear()
	fire.clear()
	drops.clear()
	exit_mesh = null
	static_batches.clear()
	artifact = null
	var floor_colors := ["34544e", "2d4946"]
	var wall_colors := ["53736c", "78938b"]
	var crate_colors := ["ae7950", "c49a70"]
	if state.mode == "classic" and state.level < 10:
		var palettes: Array = [
			["34544e", "53736c", "ae7950"], ["375568", "678b9c", "b58d67"],
			["595341", "877955", "c69b68"], ["3b5b59", "648b73", "ba8857"],
			["595346", "867f61", "b17b58"], ["425160", "687d92", "c29a61"],
			["465750", "789577", "b48a64"], ["4b4f66", "78819a", "ac8b64"],
			["54505f", "887d9b", "b88e73"], ["3e4f57", "73939b", "d19b67"]
		]
		var palette: Array = palettes[state.level]
		floor_colors = [palette[0], palette[0]]
		wall_colors = [palette[1], "9eb5a9"]
		crate_colors = [palette[2], "e8c68a"]
	box(world, Vector3(0, -0.5, 0), Vector3(config.width + 0.6, 0.6, config.height + 0.6), "182e33")
	for cell in state.board.cells:
		var color: String = floor_colors[(cell.x + cell.y) % 2]
		static_box(pos(cell) + Vector3(0, -0.13, 0), Vector3(0.98, 0.2, 0.98), color)
		match state.board.kind(cell):
			GridBoard.Cell.WALL:
				var wall_height := 0.24 if cell.y == config.height - 1 else 0.55
				static_box(pos(cell) + Vector3(0, wall_height * 0.5, 0), Vector3(0.94, wall_height, 0.94), wall_colors[0])
				static_box(pos(cell) + Vector3(0, wall_height + 0.04, 0), Vector3(0.96, 0.08, 0.96), wall_colors[1])
			GridBoard.Cell.CRATE:
				var node := Node3D.new()
				world.add_child(node)
				node.position = pos(cell)
				box(node, Vector3(0, 0.3, 0), Vector3(0.79, 0.65, 0.79), crate_colors[0])
				box(node, Vector3(0, 0.65, 0), Vector3(0.84, 0.08, 0.84), crate_colors[1])
				var brace := box(node, Vector3(0, 0.37, 0.405), Vector3(0.12, 0.75, 0.04), "654e3e")
				brace.rotation_degrees.z = -43
				box(node, Vector3(-0.29, 0.34, 0.41), Vector3(0.08, 0.61, 0.04), "72563e")
				crates[cell] = node
	if state.mode == "tutorial":
		box(world, pos(state.TUTORIAL.checkpoint) + Vector3(0, 0.015, 0), Vector3(0.75, 0.07, 0.75), "6cbaff", true)
	flush_static_batches()
	for actor in state.actors:
		add_actor_view(actor)
	if state.mode == "adventure":
		for i in range(state.board.landmarks.size()):
			var cell: Vector2i = state.board.landmarks[i]
			# Original rune columns with one/two/three inlays hint at an ordering.
			for n in range(i + 1):
				box(world, pos(cell) + Vector3(-0.22 + n * 0.22, 0.05, 0), Vector3(0.12, 0.1, 0.5), "bfa9d5", true)
		artifact = Node3D.new()
		world.add_child(artifact)
		artifact.position = pos(SecretManager.DEFINITION.niche) + Vector3(0, 0.4, 0)
		for i in range(8):
			var angle := i * TAU / 8
			var piece := box(artifact, Vector3(cos(angle), 0, sin(angle)) * 0.35, Vector3(0.16, 0.08, 0.16), "89ebed", true)
			piece.rotation.y = angle
		var needle := box(artifact, Vector3(0, 0.07, 0), Vector3(0.12, 0.12, 0.55), "ffe395", true)
		needle.rotation.y = PI * 0.25
		artifact.hide()
		follow.update(camera, pos(state.followed_actor().cell), config.width, config.height, 0, true)
	else:
		shared_camera()
	if state.mode != "arena" and state.map_data.is_empty():
		exit_mesh = box(world, pos(state.board.exit_cell) + Vector3(0, 0.02, 0), Vector3(0.8, 0.08, 0.8), "77775a")
		exit_mesh.visible = state.exit_revealed

	if state.mode == "classic" or (not state.map_data.is_empty() and state.mode not in ["custom_arena", "custom_coop"]):
		follow.update(camera, pos(state.followed_actor().cell), config.width, config.height, 0, true)

func sync(state: GameState, delta: float) -> void:
	if state.mode in ["arena", "custom_arena", "custom_coop"]: shared_camera()
	if state.mode in ["adventure", "classic"] or (not state.map_data.is_empty() and state.mode not in ["custom_arena", "custom_coop"]):
		follow.update(camera, pos(state.followed_actor().cell), config.width, config.height, delta)
		if is_instance_valid(artifact):
			artifact.visible = state.secrets.revealed and not state.secrets.awarded
			artifact.rotation.y += delta * 0.7
	for cell in crates.keys():
		if state.board.kind(cell) != GridBoard.Cell.CRATE:
			crates[cell].queue_free()
			crates.erase(cell)
	for actor in state.actors:
		if not actors.has(actor.id):
			add_actor_view(actor)
		var root: Node3D = actors[actor.id]
		root.visible = actor.alive
		if root.get_meta("role") != actor.role:
			var old: Node3D = root.get_meta("visual_body")
			root.remove_child(old); old.queue_free()
			var body := Node3D.new(); root.add_child(body)
			make_monster(body, actor.role)
			root.set_meta("visual_body", body); root.set_meta("role", actor.role)
		var previous: Vector2i = root.get_meta("last_cell")
		if actor.cell != previous:
			var direction: Vector2i = actor.cell - previous
			root.rotation.y = atan2(float(direction.x), float(direction.y))
			root.set_meta("last_cell", actor.cell)
		root.position = root.position.move_toward(pos(actor.cell), delta * 12.0)
	for id in bombs.keys():
		if not state.bombs.bombs.has(id):
			bombs[id].queue_free()
			bombs.erase(id)
	for id in state.bombs.bombs:
		var b: Dictionary = state.bombs.bombs[id]
		if not bombs.has(id):
			var root := Node3D.new()
			world.add_child(root)
			root.position = pos(b.cell)
			sphere(root, Vector3(0, 0.29, 0), 0.29, "172937")
			box(root, Vector3(0, 0.61, 0), Vector3(0.14, 0.16, 0.14), "ffd269", true)
			bombs[id] = root
		var remaining: int = b.due - state.tick
		var pulse := 1.0 + 0.08 * sin(float(state.tick) * (0.8 if remaining < 45 else 0.25))
		bombs[id].scale = Vector3.ONE * pulse
	for cell in fire.keys():
		if not state.bombs.fire.has(cell):
			fire[cell].queue_free()
			fire.erase(cell)
	for cell in state.bombs.fire:
		if not fire.has(cell):
			var root := Node3D.new()
			world.add_child(root)
			root.position = pos(cell)
			box(root, Vector3(0, 0.14, 0), Vector3(0.94, 0.28, 0.94), "f28e39", true)
			box(root, Vector3(0, 0.32, 0), Vector3(0.58, 0.12, 0.58), "ffdf89", true)
			fire[cell] = root
	for cell in drops.keys():
		if not state.powerups.has(cell):
			drops[cell].queue_free()
			drops.erase(cell)
	for cell in state.powerups:
		if not drops.has(cell):
			var root := Node3D.new()
			world.add_child(root)
			root.position = pos(cell)
			make_powerup(root, state.powerups[cell])
			drops[cell] = root
		drops[cell].visible = not state.bombs.fire.has(cell)
	if is_instance_valid(exit_mesh):
		exit_mesh.visible = state.exit_revealed
		exit_mesh.material_override = material("58e3ba" if state.exit_open() else "77775a", true)

func add_actor_view(actor: Dictionary) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.position = pos(actor.cell)
	var body := Node3D.new()
	root.add_child(body)
	root.set_meta("visual_body", body)
	root.set_meta("role", actor.role)
	root.set_meta("last_cell", actor.cell)
	if actor.enemy: make_monster(body, actor.role)
	else: make_miner(body, actor.id)
	actors[actor.id] = root

func make_miner(root: Node3D, id: int) -> void:
	var cloth := "2e8c85" if id == 0 else "ac8546"
	var helmet := "db964c" if id == 0 else "589bb6"
	for x in [-0.13, 0.13]:
		box(root, Vector3(x, 0.12, 0.03), Vector3(0.18, 0.23, 0.25), "273d47")
		box(root, Vector3(x, 0.02, 0.1), Vector3(0.22, 0.12, 0.32), "25303b")
	box(root, Vector3(0, 0.35, 0), Vector3(0.42, 0.4, 0.3), cloth)
	box(root, Vector3(0, 0.28, 0.17), Vector3(0.45, 0.07, 0.05), "664f3d")
	box(root, Vector3(0, 0.28, 0.21), Vector3(0.1, 0.09, 0.05), "d0a56d")
	for x in [-0.26, 0.26]:
		box(root, Vector3(x, 0.4, 0), Vector3(0.15, 0.26, 0.19), cloth)
		sphere(root, Vector3(x, 0.27, 0.02), 0.095, "ba8c64")
	sphere(root, Vector3(0, 0.67, 0), 0.235, "d9ad88")
	box(root, Vector3(0, 0.59, 0.18), Vector3(0.34, 0.14, 0.13), "775548")
	for x in [-0.09, 0.09]:
		box(root, Vector3(x, 0.72, 0.218), Vector3(0.048, 0.055, 0.025), "263844")
	var cap := sphere(root, Vector3(0, 0.87, 0), 0.27, helmet)
	cap.scale.y = 0.55
	box(root, Vector3(0, 0.82, 0.04), Vector3(0.61, 0.06, 0.52), helmet)
	sphere(root, Vector3(0, 0.91, 0.22), 0.085, "3c4b4e")
	box(root, Vector3(0, 0.92, 0.295), Vector3(0.1, 0.08, 0.045), "ffdf9c", true)
	var handle := box(root, Vector3(-0.29, 0.4, -0.2), Vector3(0.05, 0.5, 0.06), "976a47")
	handle.rotation_degrees.z = -25
	box(root, Vector3(-0.38, 0.63, -0.2), Vector3(0.37, 0.07, 0.1), "a4b4b5")

func make_monster(root: Node3D, role: String) -> void:
	match role:
		"patrol":
			var body := sphere(root, Vector3(0, 0.34, 0), 0.32, "cd7b72")
			body.scale = Vector3(1.08, 0.85, 0.9)
			for x in [-0.23, 0.23]:
				sphere(root, Vector3(x, 0.12, 0.12), 0.12, "8e5367")
				box(root, Vector3(x, 0.55, 0), Vector3(0.11, 0.26, 0.14), "dab7a0").rotation_degrees.z = -signf(x) * 25
		"chaser":
			sphere(root, Vector3(0, 0.38, 0), 0.28, "8e81b1")
			for x in [-0.16, 0.16]:
				box(root, Vector3(x, 0.73, 0), Vector3(0.055, 0.4, 0.06), "76608c").rotation_degrees.z = -signf(x) * 18
				sphere(root, Vector3(x * 1.5, 0.92, 0), 0.07, "b8d2c9")
		"warden":
			var crystal := box(root, Vector3(0, 0.55, 0), Vector3(0.4, 0.55, 0.4), "b4bdd4")
			crystal.rotation_degrees = Vector3(0, 45, 25)
			for x in [-0.31, 0.31]:
				box(root, Vector3(x, 0.43, 0), Vector3(0.12, 0.34, 0.26), "73849c").rotation_degrees.z = signf(x) * 30
		_:
			box(root, Vector3(0, 0.35, 0), Vector3(0.47, 0.48, 0.42), "527e98")
			box(root, Vector3(0.13, 0.72, -0.08), Vector3(0.16, 0.36, 0.17), "3a5266")
			box(root, Vector3(0.13, 0.92, -0.08), Vector3(0.21, 0.06, 0.22), "b1b8af")
			for x in [-0.23, 0.23]: sphere(root, Vector3(x, 0.12, 0.12), 0.11, "3c4c60")
	for x in [-0.1, 0.1]:
		sphere(root, Vector3(x, 0.46, 0.255), 0.083, "e9dfc8")
		box(root, Vector3(x, 0.46, 0.33), Vector3(0.045, 0.065, 0.035), "223c48")

func make_powerup(root: Node3D, kind: String) -> void:
	var color: String = {"capacity": "7bb5c9", "range": "df9b69", "speed": "b4a2cb", "remote": "b5c6a8", "wall_pass": "8cb59b", "bomb_pass": "b1bbce", "flame_pass": "b78683", "invulnerability": "dfc88f"}[kind]
	var base := CylinderMesh.new(); base.top_radius = 0.32; base.bottom_radius = 0.36; base.height = 0.1; base.radial_segments = 6
	var pedestal := MeshInstance3D.new(); pedestal.mesh = base; pedestal.material_override = material("344a54"); pedestal.position.y = 0.08; root.add_child(pedestal)
	match kind:
		"capacity":
			for x in [-0.13, 0.13]:
				sphere(root, Vector3(x, 0.3, 0), 0.13, color)
				box(root, Vector3(x, 0.45, 0), Vector3(0.04, 0.1, 0.04), "ffe0a0", true)
		"range":
			box(root, Vector3(0, 0.3, 0), Vector3(0.5, 0.12, 0.1), color)
			box(root, Vector3(0, 0.3, 0), Vector3(0.1, 0.12, 0.5), color)
		"speed":
			for x in [-0.13, 0.13]:
				box(root, Vector3(x, 0.25, 0.03), Vector3(0.15, 0.17, 0.32), color)
				box(root, Vector3(x, 0.36, -0.06), Vector3(0.13, 0.16, 0.13), color)
		"remote":
			box(root, Vector3(0, 0.3, 0), Vector3(0.3, 0.28, 0.22), color)
			box(root, Vector3(0.1, 0.57, -0.05), Vector3(0.035, 0.28, 0.035), "d8cfab")
			sphere(root, Vector3(-0.06, 0.46, 0), 0.055, "e98970")
		"wall_pass":
			for x in [-0.2, 0.2]: box(root, Vector3(x, 0.3, 0), Vector3(0.12, 0.35, 0.22), color)
			box(root, Vector3(0, 0.49, 0), Vector3(0.5, 0.09, 0.22), color)
		"bomb_pass":
			sphere(root, Vector3(0, 0.28, 0), 0.18, color)
			box(root, Vector3(0, 0.3, 0.19), Vector3(0.37, 0.07, 0.05), "f5dfa9", true)
		"flame_pass":
			var shield := box(root, Vector3(0, 0.34, 0), Vector3(0.35, 0.4, 0.1), color)
			shield.rotation_degrees.z = 45
			box(root, Vector3(0, 0.34, 0.07), Vector3(0.07, 0.25, 0.06), "f5dfa9", true)
		"invulnerability":
			sphere(root, Vector3(0, 0.36, 0), 0.22, color)
			box(root, Vector3(0, 0.36, 0.21), Vector3(0.07, 0.28, 0.05), "fff0c8", true)

func static_box(at: Vector3, dimensions: Vector3, color: String) -> void:
	var key := color + str(dimensions)
	if not static_batches.has(key):
		static_batches[key] = {"size": dimensions, "color": color, "points": []}
	static_batches[key].points.append(at)

func flush_static_batches() -> void:
	for batch in static_batches.values():
		var mesh := BoxMesh.new()
		mesh.size = batch.size
		mesh.material = material(batch.color)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = batch.points.size()
		for i in range(batch.points.size()):
			instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, batch.points[i]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		world.add_child(node)
	static_batches.clear()

func shared_camera() -> void:
	var viewport := camera.get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(1, viewport.y)
	camera.size = maxf(17, maxf(config.height * 1.32, config.width / aspect * 1.22))
	camera.position = FollowCamera.OFFSET
	camera.look_at(Vector3.ZERO)
