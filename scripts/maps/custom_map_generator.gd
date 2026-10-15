class_name CustomMapGenerator
extends RefCounted

static func generate(options: Dictionary, seed_value: int) -> Dictionary:
	var option_error := MapValidationService.validate_options(options)
	if not option_error.is_empty():
		return {"error": option_error}
	if seed_value < 0 or seed_value > 2147483647:
		return {"error": "Seed вне допустимого диапазона."}
	var width: int = int(options.get("width", 25))
	var height: int = int(options.get("height", 17))
	var count: int = int(options.get("enemy_count", 3))
	var bonuses: int = int(options.get("bonus_count", 3))
	var mode: String = options.get("mode", "solo")
	var kind: String = options.get("enemy_kind", "patrol")
	var power: String = options.get("bonus_kind", "range")
	if width < 11 or width > 41 or height < 11 or height > 31 or width % 2 == 0 or height % 2 == 0:
		return {"error": "Выберите нечётные размеры 11–41 × 11–31."}
	if count < 1 or count > 32 or bonuses < 0 or bonuses > 128 or kind not in MapValidationService.ENEMIES or power not in MapValidationService.POWERS or mode not in ["solo", "versus"]:
		return {"error": "Неподдерживаемые настройки врагов, бонусов или режима."}
	var allowed := ["width", "height", "enemy_count", "bonus_count", "mode", "enemy_kind", "bonus_kind", "enemy_step", "hidden", "crates", "walls", "capacity", "range", "fuse_ticks", "remote", "time_limit"]
	for key in options:
		if not key in allowed:
			return {"error": "Настройка не поддерживается: " + str(key)}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spawns: Array = [[1, 1]] if mode == "solo" else [[1, 1], [width - 2, height - 2]]
	var rows: Array = []
	var candidates: Array[Vector2i] = []
	for y in range(height):
		var row := ""
		for x in range(width):
			var at := Vector2i(x, y)
			var border := x == 0 or y == 0 or x == width - 1 or y == height - 1
			var safe := false
			for p in spawns:
				if absi(x - int(p[0])) + absi(y - int(p[1])) <= 3:
					safe = true
			var wall: bool = border or (options.get("walls", true) and x % 2 == 0 and y % 2 == 0 and not safe)
			row += "#" if wall else ("C" if not safe and options.get("crates", true) and rng.randf() < 0.25 else ".")
			if not wall and not safe:
				var distant := true
				for p in spawns:
					if absi(x - int(p[0])) + absi(y - int(p[1])) < 5:
						distant = false
				if distant:
					candidates.append(at)
		rows.append(row)
	# Seeded Fisher-Yates; no retries or global RNG.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var actual_count := count if mode == "solo" else 0
	if candidates.size() < actual_count + bonuses:
		return {"error": "Недостаточно места. Увеличьте карту или уменьшите число объектов."}
	if bonuses > 0 and options.get("hidden", true) and not options.get("crates", true):
		return {"error": "Скрытые бонусы требуют блоков. Включите блоки или отключите скрытие."}
	var enemies: Array = []
	var powers: Array = []
	for i in range(actual_count + bonuses):
		var at := candidates[i]
		var hidden: bool = options.get("hidden", true) and i >= actual_count
		rows[at.y][at.x] = "C" if hidden else "."
		if i < actual_count:
			enemies.append({"cell": [at.x, at.y], "kind": kind, "step": options.get("enemy_step", 36), "required": true})
		else:
			powers.append({"cell": [at.x, at.y], "kind": power, "hidden": hidden})
	var data := {"format": 1, "generation": options.duplicate(true), "id": "custom_%d" % seed_value, "revision": 1, "title": "Моя карта", "author": "Игрок", "description": "", "created": "", "modified": "", "mode": mode, "theme": "green_maze", "width": width, "height": height, "seed": seed_value, "generator_version": 1, "rows": rows, "spawns": spawns, "enemies": enemies, "powerups": powers, "secrets": [], "rules": {"capacity": options.get("capacity", 1), "range": options.get("range", 2), "fuse_ticks": options.get("fuse_ticks", 150), "remote": options.get("remote", false), "time_limit": options.get("time_limit", 0), "goal": "eliminate" if mode == "solo" else "last_player"}}
	var error := MapValidationService.validate(data)
	return {"data": data} if error.is_empty() else {"error": error}
