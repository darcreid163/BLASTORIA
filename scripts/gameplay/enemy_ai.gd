class_name EnemyAI
extends RefCounted

# Conservative spatial escape search. Bounded by board size; never reads hidden drops.
static func escape_direction(actor: Dictionary, state, extra_danger: Dictionary = {}) -> Vector2i:
	var danger: Dictionary = state.bombs.danger(state.board)
	danger.merge(extra_danger)
	var start: Vector2i = actor.cell
	var queue: Array[Vector2i] = [start]
	var first: Dictionary = {start: Vector2i.ZERO}
	var distance: Dictionary = {start: 0}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell != start and not danger.has(cell):
			return first[cell]
		for d in GridBoard.DIRS:
			var next := cell + d
			if first.has(next) or not state.walkable(next) or state.bombs.fire.has(next):
				continue
			var steps: int = distance[cell] + 1
			# Escape routes must fit the earliest potentially affecting detonation.
			var deadline: int = state.config.fuse_ticks
			for b in state.bombs.bombs.values():
				deadline = mini(deadline, b.due - state.tick)
			if steps * state.config.enemy_step_ticks >= deadline:
				continue
			distance[next] = steps
			first[next] = d if cell == start else first[cell]
			queue.append(next)
	return Vector2i.ZERO

static func command(actor: Dictionary, state) -> Dictionary:
	if actor.get("role", "bomber") != "bomber":
		return classic_command(actor, state)
	var danger: Dictionary = state.bombs.danger(state.board)
	if danger.has(actor.cell):
		return {"move": escape_direction(actor, state), "bomb": false}
	var choices: Array[Vector2i] = []
	for d in GridBoard.DIRS:
		var p: Vector2i = actor.cell + d
		if state.walkable(p) and not danger.has(p):
			choices.append(d)
	var direction := Vector2i.ZERO
	if not choices.is_empty():
		direction = choices[state.rng.randi_range(0, choices.size() - 1)]
	# Bomb from current cell only with a demonstrated escape route and a target.
	var useful := false
	var projected: Dictionary = {}
	for cell in state.board.blast(actor.cell, actor.radius):
		projected[cell] = true
		if state.board.kind(cell) == GridBoard.Cell.CRATE:
			useful = true
		for other in state.actors:
			if not other.enemy and other.alive and other.cell == cell:
				useful = true
	if useful and state.rng.randf() < 0.3 and escape_direction(actor, state, projected) != Vector2i.ZERO:
		return {"move": Vector2i.ZERO, "bomb": true}
	return {"move": direction, "bomb": false}

static func classic_command(actor: Dictionary, state) -> Dictionary:
	var danger: Dictionary = state.bombs.danger(state.board)
	var choices: Array[Vector2i] = []
	for d in GridBoard.DIRS:
		if state.can_enter(actor, actor.cell + d) and (actor.role == "patrol" or not danger.has(actor.cell + d)):
			choices.append(d)
	if choices.is_empty():
		return {}
	var direction: Vector2i = choices[state.rng.randi_range(0, choices.size() - 1)]
	if actor.role == "patrol" and choices.has(actor.direction):
		direction = actor.direction
	elif actor.role in ["chaser", "warden"]:
		# Bounded pursuit, only when movement is ready. No render/camera dependency.
		var target: Vector2i = state.followed_actor().cell
		var queue: Array[Vector2i] = [actor.cell]
		var first := {actor.cell: Vector2i.ZERO}
		var index := 0
		while index < queue.size() and index < 256:
			var cell := queue[index]
			index += 1
			if cell == target:
				direction = first[cell]
				break
			for d in GridBoard.DIRS:
				var next := cell + d
				if not first.has(next) and state.can_enter(actor, next) and not danger.has(next):
					first[next] = d if cell == actor.cell else first[cell]
					queue.append(next)
	actor.direction = direction
	return {"move": direction}
