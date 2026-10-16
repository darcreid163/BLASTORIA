extends RefCounted
# QA input driver, never shipped or used by the game's enemies. Reads visible state only.
var visited := {}
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void: rng.seed = seed_value

func allowed(state: GameState, cell: Vector2i) -> bool:
	if not state.can_enter(state.actors[0], cell) or state.bombs.fire.has(cell): return false
	for enemy in state.actors:
		if enemy.enemy and enemy.alive and absi(enemy.cell.x-cell.x)+absi(enemy.cell.y-cell.y) < 2: return false
	return true

func path(state: GameState, blocked: Dictionary, escape: bool = false) -> Vector2i:
	var origin: Vector2i = state.actors[0].cell
	var queue: Array[Vector2i] = [origin]
	var first := {origin:Vector2i.ZERO}
	var distance := {origin:0}
	var best := Vector2i.ZERO
	var best_value := -INF
	var deadline := state.config.fuse_ticks
	for b in state.bombs.bombs.values(): deadline = mini(deadline,b.due-state.tick)
	var index := 0
	while index < queue.size():
		var cell := queue[index]; index += 1
		if cell != origin and not blocked.has(cell):
			if escape: return first[cell]
			var value := -float(distance[cell]) * 0.4 - float(visited.get(cell,0)) * 0.04
			if state.powerups.has(cell): value += 100
			var enemy_distance := 999
			for enemy in state.actors:
				if enemy.enemy and enemy.alive: enemy_distance = mini(enemy_distance, absi(cell.x-enemy.cell.x)+absi(cell.y-enemy.cell.y))
			value -= float(enemy_distance) * 4
			for d in GridBoard.DIRS:
				if state.board.kind(cell+d)==GridBoard.Cell.CRATE: value += 3
			value += rng.randf()*0.1
			if value > best_value: best_value = value; best = first[cell]
		for d in GridBoard.DIRS:
			var next := cell+d
			if first.has(next) or not allowed(state,next): continue
			if not escape and blocked.has(next): continue
			var length: int = distance[cell]+1
			if escape and length*int(state.actors[0].step)+2 >= deadline: continue
			distance[next]=length;first[next]=d if cell==origin else first[cell];queue.append(next)
	return best

func command(state: GameState) -> Dictionary:
	var actor: Dictionary = state.actors[0]
	var danger := state.bombs.danger(state.board)
	var detonate := false
	for bomb in state.bombs.bombs.values():
		if bomb.owner == 0 and bomb.get("remote",false) and not state.board.blast(bomb.cell,bomb.radius).has(actor.cell): detonate=true;break
	if state.tick < actor.ready: return {"detonate":detonate}
	visited[actor.cell]=int(visited.get(actor.cell,0))+1
	if danger.has(actor.cell): return {"move":path(state,danger,true),"detonate":detonate}
	var projected := danger.duplicate()
	var useful := false
	for cell in state.board.blast(actor.cell,actor.radius):
		projected[cell]=true
		if state.board.kind(cell)==GridBoard.Cell.CRATE:useful=true
		for enemy in state.actors:
			if enemy.enemy and enemy.alive and enemy.cell==cell:useful=true
	if useful and path(state,projected,true)!=Vector2i.ZERO and state.bombs.at(actor.cell)==-1:
		var owned := 0
		for bomb in state.bombs.bombs.values():
			if bomb.owner==0:owned+=1
		if owned<int(actor.capacity):return {"bomb":true,"move":path(state,projected,true),"detonate":detonate}
	return {"move":path(state,danger),"detonate":detonate}
