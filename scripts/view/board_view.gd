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
	light.light_energy = 1.5
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101e29")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3dbc8")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)

func material(color: String, glow: bool = false) -> StandardMaterial3D:
	var key := color + str(glow)
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.7
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
	box(world, Vector3(0, -0.5, 0), Vector3(config.width + 0.6, 0.6, config.height + 0.6), "182e33")
	for cell in state.board.cells:
		var color := "34544e" if (cell.x + cell.y) % 2 == 0 else "2d4946"
		box(world, pos(cell) + Vector3(0, -0.13, 0), Vector3(0.98, 0.2, 0.98), color)
		match state.board.kind(cell):
			GridBoard.Cell.WALL:
				box(world, pos(cell) + Vector3(0, 0.4, 0), Vector3(0.94, 0.95, 0.94), "53736c")
				box(world, pos(cell) + Vector3(0, 0.9, 0), Vector3(0.96, 0.1, 0.96), "90ac8c")
			GridBoard.Cell.CRATE:
				var node := Node3D.new()
				world.add_child(node)
				node.position = pos(cell)
				box(node, Vector3(0, 0.3, 0), Vector3(0.79, 0.65, 0.79), "ae7950")
				box(node, Vector3(0, 0.65, 0), Vector3(0.84, 0.08, 0.84), "e3b575")
				crates[cell] = node
	for actor in state.actors:
		var root := Node3D.new()
		world.add_child(root)
		root.position = pos(actor.cell)
		var color := "ef806c" if actor.enemy else ("59e4c7" if actor.id == 0 else "ffd269")
		# Temporary original crystal scouts; explicit geometric silhouettes.
		var body := box(root, Vector3(0, 0.45, 0), Vector3(0.51, 0.62, 0.51), color)
		body.rotation_degrees.y = 45
		box(root, Vector3(0, 0.82, 0), Vector3(0.16, 0.16, 0.16), "efffdb", true)
		box(root, Vector3(0, 0.52, 0.28), Vector3(0.34, 0.12, 0.07), "16303c")
		actors[actor.id] = root
	if state.mode == "campaign":
		exit_mesh = box(world, pos(state.board.exit_cell) + Vector3(0, 0.02, 0), Vector3(0.8, 0.08, 0.8), "77775a")

func sync(state: GameState, delta: float) -> void:
	for cell in crates.keys():
		if state.board.kind(cell) != GridBoard.Cell.CRATE:
			crates[cell].queue_free()
			crates.erase(cell)
	for actor in state.actors:
		var root: Node3D = actors[actor.id]
		root.visible = actor.alive
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
			var color: String = {"capacity": "6cbaff", "range": "ff9e65", "speed": "c6a1ff"}[state.powerups[cell]]
			var root := Node3D.new()
			world.add_child(root)
			root.position = pos(cell)
			box(root, Vector3(0, 0.25, 0), Vector3(0.35, 0.35, 0.35), color, true)
			var label := Label3D.new()
			label.text = {"capacity": "+B", "range": "+R", "speed": "+S"}[state.powerups[cell]]
			label.position.y = 0.6
			label.font_size = 32
			label.pixel_size = 0.01
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			root.add_child(label)
			drops[cell] = root
		drops[cell].visible = not state.bombs.fire.has(cell)
	if is_instance_valid(exit_mesh):
		exit_mesh.material_override = material("58e3ba" if state.alive_enemies() == 0 else "77775a", true)
