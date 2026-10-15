class_name GameState
extends RefCounted

signal finished(result: String)
signal pickup(actor_id: int, kind: String)
signal feedback(kind: String)
signal secret_found(id: String)
const TUTORIAL = preload("res://resources/levels/tutorial.tres")
var config: GameConfig
var board: GridBoard
var bombs: BombSystem
var rng := RandomNumberGenerator.new()
var actors: Array[Dictionary] = []
var powerups: Dictionary = {}
var tick: int = 0
var mode: String = "campaign"
var level: int = 0
var seed_value: int = 0
var result: String = ""
var paused: bool = false
var score: int = 0
var time_bonus: int = 0
var tutorial_moved: bool = false
var tutorial_picked: bool = false
var exit_revealed: bool = true
var level_ticks: int = 0
var penalty_phase: bool = false
var pending_penalty: int = 0
var exploration := Exploration.new()
var secrets := SecretManager.new()
var completion_walk: bool = false
var left_completion_exit: bool = false
var hidden_powerups: Dictionary = {}


func start(settings: GameConfig, new_mode: String, level_index: int, map_seed: int) -> void:
	config = settings
	mode = new_mode
	level = level_index
	seed_value = map_seed
	rng.seed = map_seed
	tick = 0
	score = 0
	time_bonus = 0
	tutorial_moved = false
	tutorial_picked = false
	exit_revealed = not config.hidden_exit
	level_ticks = 0
	penalty_phase = false
	pending_penalty = 0
	completion_walk = false
	left_completion_exit = false
	secrets = SecretManager.new()
	secrets.enabled = mode == "adventure"
	exploration = Exploration.new()
	result = ""
	paused = false
	actors.clear()
	powerups.clear()
	board = GridBoard.new()
	if mode == "tutorial":
		if not board.load_authored(TUTORIAL):
			push_error("Invalid authored tutorial")
			result = "INVALID_LEVEL"
			return
	else:
		board.generate(config, rng, mode == "arena")
	hidden_powerups = board.guaranteed_drops.duplicate()
	exploration.setup(board)
	exploration.reveal(board, Vector2i(1, 1))
	bombs = BombSystem.new()
	add_actor(TUTORIAL.spawn if mode == "tutorial" else Vector2i(1, 1), false)
	if mode == "arena":
		add_actor(board.exit_cell, false)
	elif mode != "tutorial":
		var starts: Array[Vector2i] = [Vector2i(config.width - 2, 1), Vector2i(1, config.height - 2), Vector2i(config.width - 4, config.height - 4)]
		for i in range(config.enemy_counts[level]):
			add_actor(starts[i], true)
			if config.contact_damage:
				actors[-1].role = "chaser" if i == 1 else "patrol"
	if mode == "adventure":
		for cell in [Vector2i(19, 5), Vector2i(35, 23), Vector2i(15, 25)]:
			board.cells[cell] = GridBoard.Cell.FLOOR
			add_actor(cell, true)
			actors[-1].role = "chaser"

func add_actor(cell: Vector2i, enemy: bool) -> void:
	actors.append({"id": actors.size(), "cell": cell, "enemy": enemy, "alive": true,
		"ready": 0, "radius": config.initial_range, "capacity": config.initial_capacity,
		"step": config.enemy_step_ticks if enemy else config.player_step_ticks,
		"role": "bomber", "direction": Vector2i.ZERO, "remote": false, "wall_pass": false,
		"bomb_pass": false, "flame_pass": false, "invulnerable_until": 0})

func walkable(cell: Vector2i) -> bool:
	if board.kind(cell) != GridBoard.Cell.FLOOR or bombs.at(cell) != -1:
		return false
	for actor in actors:
		if actor.alive and actor.cell == cell:
			return false
	return true

func advance(commands: Dictionary = {}) -> void:
	if paused or not result.is_empty():
		return
	tick += 1
	if not completion_walk:
		level_ticks += 1
	if config.level_seconds > 0 and remaining_seconds() == 0 and not penalty_phase:
		penalty_phase = true
		pending_penalty += config.timeout_enemies
		feedback.emit("defeat")
	# Remote input is resolved before the tick's hazards, with the same damage priority.
	for actor in actors:
		if actor.alive and actor.remote and commands.get(actor.id, {}).get("detonate", false):
			bombs.trigger(actor.id, tick)
	var was_revealed := exit_revealed
	# Resolve hazards before movement so stepping away at the detonation tick cannot dodge damage.
	var destroyed := bombs.advance(tick, board, config.fire_ticks)
	if config.hidden_exit and board.kind(board.exit_cell) == GridBoard.Cell.FLOOR:
		exit_revealed = true
	if mode == "classic" and was_revealed and bombs.hit_cells.has(board.exit_cell):
		pending_penalty = mini(32, pending_penalty + config.exit_penalty_enemies)
	spawn_penalties()
	if bombs.detonations_this_tick > 0:
		feedback.emit("explosion")
	if not destroyed.is_empty():
		feedback.emit("crate")
	for bomb in bombs.bombs.values():
		if not bomb.get("remote", false) and bomb.due - tick in [60, 30]:
			feedback.emit("fuse")
			break
	for cell in destroyed:
		if scoring_mode() and bombs.credited(cell, 0):
			score += config.score_crate
		if mode == "tutorial" and cell == TUTORIAL.lesson_crate:
			powerups[cell] = "range"
		elif hidden_powerups.has(cell):
			powerups[cell] = hidden_powerups[cell]
			hidden_powerups.erase(cell)
		elif cell != board.exit_cell and rng.randf() < config.drop_chance:
			powerups[cell] = ["capacity", "range", "speed"][rng.randi_range(0, 2)]
	apply_damage()
	for actor in actors:
		if not actor.alive:
			continue
		var command: Dictionary = commands.get(actor.id, {})
		if actor.enemy:
			command = EnemyAI.command(actor, self) if tick >= actor.ready else {}
		# Placement precedes movement, consistently for human and AI commands.
		if command.get("bomb", false) and not completion_walk and board.kind(actor.cell) == GridBoard.Cell.FLOOR:
			if bombs.place(actor.cell, actor.id, actor.radius, actor.capacity, tick, config.fuse_ticks, actor.remote):
				feedback.emit("place")
		var direction: Vector2i = command.get("move", Vector2i.ZERO)
		if GridBoard.DIRS.has(direction) and tick >= actor.ready:
			var next: Vector2i = actor.cell + direction
			if can_enter(actor, next):
				actor.cell = next
				apply_contact()
				if not actor.enemy:
					feedback.emit("step")
			actor.ready = tick + actor.step
		elif actor.enemy and tick >= actor.ready:
			actor.ready = tick + actor.step
	apply_damage()
	for actor in actors:
		if actor.alive and not actor.enemy and powerups.has(actor.cell) and not bombs.fire.has(actor.cell):
			collect(actor, powerups[actor.cell])
			powerups.erase(actor.cell)
	if mode == "tutorial" and actors[0].cell == TUTORIAL.checkpoint:
		tutorial_moved = true
	if mode == "adventure":
		exploration.reveal(board, actors[0].cell, not destroyed.is_empty())
		var landmark := board.landmarks.find(actors[0].cell)
		if landmark >= 0:
			secrets.visit(landmark)
	if completion_walk:
		if actors[0].cell != board.exit_cell:
			left_completion_exit = true
		var reward := secrets.collect(actors[0].cell)
		if reward > 0:
			score += reward
			secret_found.emit(SecretManager.COMPASS.id)
			feedback.emit("pickup")
	check_end()

func apply_damage() -> void:
	for actor in actors:
		if actor.alive and bombs.fire.has(actor.cell) and not actor.flame_pass and tick >= actor.invulnerable_until:
			actor.alive = false
			feedback.emit("death")
			if scoring_mode() and actor.enemy and bombs.credited(actor.cell, 0):
				score += config.score_enemy
			if not actor.enemy:
				secrets.damaged = true
	apply_contact()

func collect(actor: Dictionary, kind: String) -> void:
	match kind:
		"capacity": actor.capacity = mini(actor.capacity + 1, config.max_capacity)
		"range": actor.radius = mini(actor.radius + 1, config.max_range)
		"speed": actor.step = maxi(actor.step - 1, config.min_step_ticks)
		"remote", "wall_pass", "bomb_pass", "flame_pass": actor[kind] = true
		"invulnerability": actor.invulnerable_until = tick + config.invulnerable_ticks
	if scoring_mode() and not actor.enemy:
		score += config.score_pickup
	if mode == "tutorial":
		tutorial_picked = true
	feedback.emit("pickup")
	pickup.emit(actor.id, kind)

func check_end() -> void:
	if not result.is_empty():
		return
	if mode != "arena":
		if not actors[0].alive:
			result = "DEFEAT"
		elif completion_walk:
			if secrets.awarded or (left_completion_exit and actors[0].cell == board.exit_cell):
				result = "ADVENTURE_DONE"
		elif exit_open() and actors[0].cell == board.exit_cell:
			if mode == "tutorial":
				result = "TUTORIAL_DONE"
			elif mode == "arcade":
				var seconds_used := ceili(float(tick) / config.tick_rate)
				time_bonus = maxi(0, config.arcade_par_seconds - seconds_used) * config.score_per_second
				score += config.score_stage_clear + time_bonus
				result = "ARCADE_DONE" if level + 1 == config.arcade_seeds.size() else "LEVEL_CLEAR"
			elif mode == "adventure":
				score += config.score_stage_clear
				if secrets.finish(exploration.explored_count(), exploration.total):
					completion_walk = true
					bombs = BombSystem.new()
				else:
					result = "ADVENTURE_DONE"
			elif mode == "classic":
				score += config.score_stage_clear
				result = "CLASSIC_DONE" if level + 1 == config.campaign_seeds.size() else "LEVEL_CLEAR"
			else:
				result = "CAMPAIGN_DONE" if level + 1 == config.campaign_seeds.size() else "LEVEL_CLEAR"
	else:
		var living: Array[int] = []
		for actor in actors:
			if actor.alive:
				living.append(actor.id)
		if living.size() <= 1:
			result = "DRAW" if living.is_empty() else "P%d_WINS" % (living[0] + 1)
	if not result.is_empty():
		feedback.emit("defeat" if result in ["DEFEAT", "DRAW"] else "victory")
		finished.emit(result)

func alive_enemies() -> int:
	var count := 0
	for actor in actors:
		if actor.enemy and actor.alive:
			count += 1
	return count

func snapshot() -> Dictionary:
	return {"tick": tick, "actors": actors.duplicate(true), "bombs": bombs.bombs.duplicate(true),
		"fire": bombs.fire.duplicate(), "cells": board.cells.duplicate(), "powerups": powerups.duplicate(),
		"result": result, "rng_state": rng.state, "score": score, "time_bonus": time_bonus,
		"fire_owners": bombs.fire_owners.duplicate(true), "level_ticks": level_ticks,
		"exit_revealed": exit_revealed, "pending_penalty": pending_penalty,
		"explored": exploration.known.duplicate(), "completion_walk": completion_walk,
		"secret": [secrets.map_used, secrets.damaged, secrets.visited.duplicate(), secrets.failed_order, secrets.revealed, secrets.awarded]}

func exit_open() -> bool:
	if mode == "tutorial":
		return tutorial_moved and tutorial_picked and board.kind(TUTORIAL.lesson_crate) == GridBoard.Cell.FLOOR
	return exit_revealed and alive_enemies() == 0 and pending_penalty == 0

func tutorial_hint() -> String:
	if not tutorial_moved:
		return "TUT_MOVE"
	if board.kind(TUTORIAL.lesson_crate) == GridBoard.Cell.CRATE:
		return "TUT_BOMB"
	if not tutorial_picked:
		return "TUT_PICKUP"
	return "TUT_EXIT"

func scoring_mode() -> bool:
	return mode in ["arcade", "classic", "adventure"]

func remaining_seconds() -> int:
	return maxi(0, config.level_seconds - int(level_ticks / maxi(1, config.ticks_per_game_second)))

func can_enter(actor: Dictionary, cell: Vector2i) -> bool:
	var kind := board.kind(cell)
	if kind == GridBoard.Cell.WALL or (kind == GridBoard.Cell.CRATE and not actor.wall_pass):
		return false
	if bombs.at(cell) != -1 and not actor.bomb_pass:
		return false
	for other in actors:
		if other.id != actor.id and other.alive and other.cell == cell:
			if not config.contact_damage or other.enemy == actor.enemy:
				return false
	return true

func apply_contact() -> void:
	if not config.contact_damage or not actors[0].alive or tick < actors[0].invulnerable_until:
		return
	for enemy in actors:
		if enemy.enemy and enemy.alive and enemy.cell == actors[0].cell:
			actors[0].alive = false
			secrets.damaged = true
			feedback.emit("death")
			return

func spawn_penalties() -> void:
	if pending_penalty <= 0:
		return
	for cell in board.cells:
		if pending_penalty <= 0 or alive_enemies() >= 32:
			break
		if absi(cell.x - actors[0].cell.x) + absi(cell.y - actors[0].cell.y) < 5:
			continue
		if walkable(cell) and not bombs.fire.has(cell):
			add_actor(cell, true)
			actors[-1].role = "warden"
			actors[-1].wall_pass = true
			actors[-1].step = maxi(6, config.enemy_step_ticks / 2)
			actors[-1].ready = tick + actors[-1].step
			pending_penalty -= 1
