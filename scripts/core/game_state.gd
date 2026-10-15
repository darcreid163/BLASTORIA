class_name GameState
extends RefCounted

signal finished(result: String)
signal pickup(actor_id: int, kind: String)
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

func start(settings: GameConfig, new_mode: String, level_index: int, map_seed: int) -> void:
	config = settings
	mode = new_mode
	level = level_index
	seed_value = map_seed
	rng.seed = map_seed
	tick = 0
	score = 0
	time_bonus = 0
	result = ""
	paused = false
	actors.clear()
	powerups.clear()
	board = GridBoard.new()
	board.generate(config, rng, mode == "arena")
	bombs = BombSystem.new()
	add_actor(Vector2i(1, 1), false)
	if mode == "arena":
		add_actor(board.exit_cell, false)
	else:
		var starts: Array[Vector2i] = [Vector2i(config.width - 2, 1), Vector2i(1, config.height - 2), Vector2i(config.width - 4, config.height - 4)]
		for i in range(config.enemy_counts[level]):
			add_actor(starts[i], true)

func add_actor(cell: Vector2i, enemy: bool) -> void:
	actors.append({"id": actors.size(), "cell": cell, "enemy": enemy, "alive": true,
		"ready": 0, "radius": config.initial_range, "capacity": config.initial_capacity,
		"step": config.enemy_step_ticks if enemy else config.player_step_ticks})

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
	# Resolve hazards before movement so stepping away at the detonation tick cannot dodge damage.
	var destroyed := bombs.advance(tick, board, config.fire_ticks)
	for cell in destroyed:
		if mode == "arcade" and bombs.credited(cell, 0):
			score += config.score_crate
		if rng.randf() < config.drop_chance:
			powerups[cell] = ["capacity", "range", "speed"][rng.randi_range(0, 2)]
	apply_damage()
	for actor in actors:
		if not actor.alive:
			continue
		var command: Dictionary = commands.get(actor.id, {})
		if actor.enemy:
			command = EnemyAI.command(actor, self) if tick >= actor.ready else {}
		# Placement precedes movement, consistently for human and AI commands.
		if command.get("bomb", false):
			bombs.place(actor.cell, actor.id, actor.radius, actor.capacity, tick, config.fuse_ticks)
		var direction: Vector2i = command.get("move", Vector2i.ZERO)
		if GridBoard.DIRS.has(direction) and tick >= actor.ready:
			var next: Vector2i = actor.cell + direction
			if walkable(next):
				actor.cell = next
			actor.ready = tick + actor.step
		elif actor.enemy and tick >= actor.ready:
			actor.ready = tick + actor.step
	apply_damage()
	for actor in actors:
		if actor.alive and not actor.enemy and powerups.has(actor.cell) and not bombs.fire.has(actor.cell):
			collect(actor, powerups[actor.cell])
			powerups.erase(actor.cell)
	check_end()

func apply_damage() -> void:
	for actor in actors:
		if actor.alive and bombs.fire.has(actor.cell):
			actor.alive = false
			if mode == "arcade" and actor.enemy and bombs.credited(actor.cell, 0):
				score += config.score_enemy

func collect(actor: Dictionary, kind: String) -> void:
	match kind:
		"capacity": actor.capacity = mini(actor.capacity + 1, config.max_capacity)
		"range": actor.radius = mini(actor.radius + 1, config.max_range)
		"speed": actor.step = maxi(actor.step - 1, config.min_step_ticks)
	if mode == "arcade" and not actor.enemy:
		score += config.score_pickup
	pickup.emit(actor.id, kind)

func check_end() -> void:
	if not result.is_empty():
		return
	if mode != "arena":
		if not actors[0].alive:
			result = "DEFEAT"
		elif alive_enemies() == 0 and actors[0].cell == board.exit_cell:
			if mode == "arcade":
				var seconds_used := ceili(float(tick) / config.tick_rate)
				time_bonus = maxi(0, config.arcade_par_seconds - seconds_used) * config.score_per_second
				score += config.score_stage_clear + time_bonus
				result = "ARCADE_DONE" if level + 1 == config.arcade_seeds.size() else "LEVEL_CLEAR"
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
		"fire_owners": bombs.fire_owners.duplicate(true)}
