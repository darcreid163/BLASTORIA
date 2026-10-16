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
var sealed_prize_cell := Vector2i(-1, -1)
var stage_profile: Dictionary = {}
var map_data: Dictionary = {}
var attempt_id: String = ""
var activity: Dictionary = {}


func start(settings: GameConfig, new_mode: String, level_index: int, map_seed: int, definition: Dictionary = {}) -> void:
	attempt_id = Crypto.new().generate_random_bytes(16).hex_encode()
	activity = {"bombs": 0, "detonations": 0, "kills": 0, "crates": 0, "max_chain": 0, "powers": [], "steps": [0, 0], "placements": [0, 0]}
	map_data = definition.duplicate(true)
	stage_profile = ClassicStagePlan.stage(level_index + 1) if new_mode == "classic" else {}
	config = ClassicStagePlan.rules_for(settings, level_index + 1) if not stage_profile.is_empty() else settings
	mode = new_mode
	level = level_index
	sealed_prize_cell = Vector2i(-1, -1)
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
	if not map_data.is_empty():
		board.load_map(map_data)
	elif mode == "tutorial":
		if not board.load_authored(TUTORIAL):
			push_error("Invalid authored tutorial")
			result = "INVALID_LEVEL"
			return
	elif mode == "classic" and level_index < ClassicChapterOneMap.COUNT:
		if not ClassicChapterOneMap.apply(board, level_index + 1):
			push_error("Chapter one map invalid: %d" % (level_index + 1))
			result = "INVALID_LEVEL"
			return
	else:
		board.generate(config, rng, mode == "arena")
	if mode == "classic" and not stage_profile.is_empty():
		var authored := ClassicChapterOneMap.stage(level_index + 1)
		sealed_prize_cell = ClassicChapterOneMap.point(authored.prize) if not authored.is_empty() else ClassicStagePlan.PRIZE_CELL
		board.cells[sealed_prize_cell] = GridBoard.Cell.CRATE
		board.guaranteed_drops = {sealed_prize_cell: stage_profile.sealed_prize}
	hidden_powerups = board.guaranteed_drops.duplicate()
	exploration.setup(board)
	exploration.reveal(board, Vector2i(1, 1))
	bombs = BombSystem.new()
	if not map_data.is_empty():
		for point in map_data.spawns:
			add_actor(MapValidationService.cell(point), false)
			actors[-1].remote = map_data.rules.remote
		for enemy in map_data.enemies:
			add_actor(MapValidationService.cell(enemy.cell), true)
			actors[-1].role = enemy.kind
			actors[-1].step = int(enemy.step)
			actors[-1].required = enemy.required
			actors[-1].wall_pass = enemy.kind == "warden"
		for power in map_data.powerups:
			var at := MapValidationService.cell(power.cell)
			if power.hidden:
				hidden_powerups[at] = power.kind
			else:
				powerups[at] = power.kind
		return
	add_actor(TUTORIAL.spawn if mode == "tutorial" else Vector2i(1, 1), false)
	if mode == "arena":
		add_actor(board.exit_cell, false)
	elif mode == "classic" and not stage_profile.is_empty():
		spawn_classic_enemies(int(stage_profile.enemy_count))
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

func spawn_classic_enemies(amount: int) -> void:
	var authored := ClassicChapterOneMap.stage(level + 1)
	if not authored.is_empty():
		for i in range(mini(amount, authored.enemy_spawns.size())):
			var at := ClassicChapterOneMap.point(authored.enemy_spawns[i])
			add_actor(at, true)
			actors[-1].role = "patrol" if level < 3 else ("chaser" if i % 2 == 1 else "patrol")
			actors[-1].step = maxi(9, int(stage_profile.enemy_step_ticks) + (i % 3) * 3)
		return
	# Later chapters use fixed seeds until their own authored layouts are ready.
	var choices: Array[Vector2i] = []
	var origin: Vector2i = actors[0].cell
	for p in board.cells:
		if board.kind(p) != GridBoard.Cell.FLOOR or p == board.exit_cell:
			continue
		if absi(p.x - origin.x) + absi(p.y - origin.y) < 6:
			continue
		choices.append(p)
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * board.width + a.x < b.y * board.width + b.x)
	for i in range(mini(amount, choices.size())):
		var at: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		choices.erase(at)
		add_actor(at, true)
		actors[-1].role = "patrol" if level < 10 else ("chaser" if i % 3 != 2 else "warden")
		actors[-1].step = maxi(9, int(stage_profile.enemy_step_ticks) + (i % 3) * 3)
		actors[-1].wall_pass = actors[-1].role == "warden"


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
	if map_data.is_empty() and config.level_seconds > 0 and remaining_seconds() == 0 and not penalty_phase:
		penalty_phase = true
		pending_penalty += config.timeout_enemies
		if mode == "classic":
			for enemy in actors:
				if enemy.enemy and enemy.alive:
					enemy.role = "warden"
					enemy.wall_pass = true
					enemy.step = maxi(6, int(float(enemy.step) / 2.0))
		feedback.emit("defeat")
	# Remote input is resolved before the tick's hazards, with the same damage priority.
	for actor in actors:
		if actor.alive and actor.remote and commands.get(actor.id, {}).get("detonate", false):
			bombs.trigger(actor.id, tick)
	var was_revealed := exit_revealed
	var exposed_prize := mode == "classic" and powerups.has(sealed_prize_cell)
	# Resolve hazards before movement so stepping away at the detonation tick cannot dodge damage.
	var destroyed := bombs.advance(tick, board, config.fire_ticks)
	activity.detonations += bombs.player_detonations_this_tick
	activity.max_chain = maxi(int(activity.max_chain), bombs.max_player_chain_this_tick)
	if config.hidden_exit and board.kind(board.exit_cell) == GridBoard.Cell.FLOOR:
		exit_revealed = true
	if mode == "classic" and was_revealed and bombs.hit_cells.has(board.exit_cell):
		pending_penalty = mini(32, pending_penalty + config.exit_penalty_enemies)
	if bombs.detonations_this_tick > 0:
		feedback.emit("explosion")
	if not destroyed.is_empty():
		feedback.emit("crate")
	for bomb in bombs.bombs.values():
		if not bomb.get("remote", false) and bomb.due - tick in [60, 30]:
			feedback.emit("fuse")
			break
	for cell in destroyed:
		if bombs.credited(cell, 0):
			activity.crates += 1
			if scoring_mode(): score += config.score_crate
		if mode == "tutorial" and cell == TUTORIAL.lesson_crate:
			powerups[cell] = "range"
		elif hidden_powerups.has(cell):
			powerups[cell] = hidden_powerups[cell]
			hidden_powerups.erase(cell)
		elif cell != board.exit_cell and rng.randf() < config.drop_chance:
			powerups[cell] = ["capacity", "range", "speed"][rng.randi_range(0, 2)]
	# Only a subsequent detonation hitting an already uncovered, uncollected prize is punished.
	if exposed_prize and bombs.hit_cells.has(sealed_prize_cell):
		powerups.erase(sealed_prize_cell)
		pending_penalty = mini(32, pending_penalty + config.exit_penalty_enemies)
	spawn_penalties()
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
				if actor.id == 0: activity.bombs += 1
				if actor.id < 2 and not actor.enemy: activity.placements[actor.id] += 1
				feedback.emit("place")
		var direction: Vector2i = command.get("move", Vector2i.ZERO)
		if GridBoard.DIRS.has(direction) and tick >= actor.ready:
			var next: Vector2i = actor.cell + direction
			if can_enter(actor, next):
				actor.cell = next
				if actor.id < 2 and not actor.enemy: activity.steps[actor.id] += 1
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
			secret_found.emit(SecretManager.DEFINITION.id)
			feedback.emit("pickup")
	check_end()

func apply_damage() -> void:
	for actor in actors:
		if actor.alive and bombs.fire.has(actor.cell) and not actor.flame_pass and tick >= actor.invulnerable_until:
			actor.alive = false
			feedback.emit("death")
			if actor.enemy and bombs.credited(actor.cell, 0):
				activity.kills += 1
				if scoring_mode(): score += config.score_enemy
			if not actor.enemy:
				secrets.damaged = true
	apply_contact()

func collect(actor: Dictionary, kind: String) -> void:
	if actor.id == 0 and not actor.enemy and MapValidationService.POWERS.has(kind) and not activity.powers.has(kind): activity.powers.append(kind)
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
	if mode not in ["arena", "custom_arena"]:
		if not actors[0].alive:
			result = "DEFEAT"
		elif mode in ["official_arcade", "custom"] and required_enemies() == 0:
			time_bonus = maxi(0, config.arcade_par_seconds - ceili(float(level_ticks) / config.tick_rate)) * config.score_per_second
			score += config.score_stage_clear + time_bonus
			result = "MAP_CLEAR"
		elif not map_data.is_empty() and config.level_seconds > 0 and remaining_seconds() == 0:
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
				result = "CLASSIC_DONE" if level + 1 == ClassicStagePlan.MAX_STAGES else "LEVEL_CLEAR"
			else:
				result = "CAMPAIGN_DONE" if level + 1 == config.campaign_seeds.size() else "LEVEL_CLEAR"
	else:
		var living: Array[int] = []
		for actor in actors:
			if actor.alive:
				living.append(actor.id)
		if living.size() <= 1:
			result = "DRAW" if living.is_empty() else "P%d_WINS" % (living[0] + 1)
		elif not map_data.is_empty() and config.level_seconds > 0 and remaining_seconds() == 0:
			result = "DRAW"
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
	return {"activity": activity.duplicate(true), "tick": tick, "actors": actors.duplicate(true), "bombs": bombs.bombs.duplicate(true),
		"fire": bombs.fire.duplicate(), "cells": board.cells.duplicate(), "powerups": powerups.duplicate(),
		"result": result, "rng_state": rng.state, "score": score, "time_bonus": time_bonus,
		"fire_owners": bombs.fire_owners.duplicate(true), "level_ticks": level_ticks,
		"exit_revealed": exit_revealed, "pending_penalty": pending_penalty,
		"sealed_prize_cell": sealed_prize_cell, "penalty_phase": penalty_phase,
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
	return mode in ["arcade", "classic", "adventure", "official_arcade", "custom"]

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

func required_enemies() -> int:
	var count := 0
	for actor in actors:
		if actor.enemy and actor.alive and actor.get("required", true):
			count += 1
	return count

func start_map(data: Dictionary, official_number: int = 0) -> String:
	var error := MapValidationService.validate(data)
	if not error.is_empty():
		return error
	var rules := GameConfig.new()
	rules.width = int(data.width)
	rules.height = int(data.height)
	rules.initial_capacity = int(data.rules.capacity)
	rules.initial_range = int(data.rules.range)
	rules.fuse_ticks = int(data.rules.fuse_ticks)
	rules.level_seconds = int(data.rules.time_limit)
	rules.contact_damage = data.mode == "solo"
	rules.drop_chance = 0.0 # Only authored/selected bonuses. Never inject unrequested types.
	var selected_mode := "official_arcade" if official_number > 0 else ("custom" if data.mode == "solo" else "custom_arena")
	start(rules, selected_mode, maxi(0, official_number - 1), int(data.seed), data)
	return ""
