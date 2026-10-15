class_name MapValidationService
extends RefCounted

const MAX_BYTES := 262144
const POWERS := ["capacity", "range", "speed", "remote", "wall_pass", "bomb_pass", "flame_pass", "invulnerability"]
const ENEMIES := ["patrol", "chaser", "bomber", "warden"]
const ROOT_KEYS := ["format", "id", "revision", "title", "author", "description", "created", "modified", "mode", "theme", "width", "height", "seed", "generator_version", "rows", "spawns", "enemies", "powerups", "rules", "secrets", "generation"]

static func integer(value: Variant, low: int, high: int) -> bool:
	return SaveManager.valid_int(value, low, high)

static func exact_keys(data: Variant, keys: Array) -> bool:
	if not data is Dictionary or data.size() != keys.size():
		return false
	for key in data:
		if not key in keys:
			return false
	return true

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() < 1 or value.length() > 48:
		return false
	for c in value:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func point(value: Variant, width: int, height: int) -> bool:
	return value is Array and value.size() == 2 and integer(value[0], 1, width - 2) and integer(value[1], 1, height - 2)

static func cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func validate(data: Variant) -> String:
	if not exact_keys(data, ROOT_KEYS):
		return "Неверный набор полей карты. Скрипты и пути ресурсов не поддерживаются."
	if not integer(data.format, 1, 1):
		return "Версия .blastmap не поддерживается."
	if not valid_id(data.id) or not integer(data.revision, 1, 1000000):
		return "Неверный ID или версия карты."
	for key in ["title", "author", "description", "created", "modified"]:
		if not data[key] is String or data[key].length() > (1024 if key == "description" else 80):
			return "Слишком длинное или неверное текстовое поле: " + key
	if data.title.strip_edges().is_empty():
		return "Введите название карты."
	if not integer(data.width, 11, 41) or not integer(data.height, 11, 31):
		return "Размер карты: от 11×11 до 41×31."
	if data.mode not in ["solo", "versus"] or data.theme != "green_maze":
		return "Поддерживаются Зелёный лабиринт и режимы соло / дуэль."
	var generation_error := validate_options(data.generation)
	if not generation_error.is_empty():
		return generation_error
	if not integer(data.seed, 0, 2147483647) or not integer(data.generator_version, 0, 1):
		return "Неверный seed или версия генератора."
	if not data.rows is Array or data.rows.size() != int(data.height):
		return "Неверная высота геометрии."
	for y in range(int(data.height)):
		var row = data.rows[y]
		if not row is String or row.length() != int(data.width):
			return "Неверная ширина геометрии."
		for x in range(int(data.width)):
			if not row[x] in ".#C":
				return "Неизвестный тип клетки."
			if (x == 0 or y == 0 or x == int(data.width) - 1 or y == int(data.height) - 1) and row[x] != "#":
				return "Граница карты должна быть закрыта стенами."
	if not exact_keys(data.rules, ["capacity", "range", "fuse_ticks", "remote", "time_limit", "goal"]):
		return "Неверные правила карты."
	var rules: Dictionary = data.rules
	if not integer(rules.capacity, 1, 5) or not integer(rules.range, 1, 6) or not integer(rules.fuse_ticks, 90, 600) or not rules.remote is bool or not integer(rules.time_limit, 0, 1800):
		return "Бомбы: 1–5, дальность: 1–6, фитиль: 90–600 тиков, время: 0–1800 секунд."
	if rules.goal != ("eliminate" if data.mode == "solo" else "last_player"):
		return "Цель не соответствует режиму."
	if not data.spawns is Array or data.spawns.size() != (1 if data.mode == "solo" else 2):
		return "Нужен один старт для соло или два для дуэли."
	var occupied: Dictionary = {}
	var board := GridBoard.new()
	board.load_map(data)
	for p in data.spawns:
		if not point(p, int(data.width), int(data.height)):
			return "Старт за границами карты."
		var at := cell(p)
		if board.kind(at) != GridBoard.Cell.FLOOR or occupied.has(at):
			return "Старты должны находиться на разных свободных клетках."
		occupied[at] = true
		# Conservative escape test: no enemies considered; requires reaching outside initial blast.
		var reachable := board.reachable(at)
		var safe := false
		var ray := board.blast(at, int(rules.range))
		for candidate in reachable:
			if not ray.has(candidate):
				safe = true
				break
		if not safe:
			return "Нет свободного пути укрытия от первой бомбы у старта."
	var reachable := board.reachable(cell(data.spawns[0]), true)
	for p in data.spawns:
		if not reachable.has(cell(p)):
			return "Старты игроков изолированы стенами."
	if not data.enemies is Array or data.enemies.size() > 32 or (data.mode == "solo" and data.enemies.is_empty()) or (data.mode == "versus" and not data.enemies.is_empty()):
		return "Соло: 1–32 врага. Дуэль: без ИИ."
	var required_count := 0
	for enemy in data.enemies:
		if not exact_keys(enemy, ["cell", "kind", "step", "required"]) or not point(enemy.cell, int(data.width), int(data.height)) or enemy.kind not in ENEMIES or not integer(enemy.step, 9, 90) or not enemy.required is bool:
			return "Неверный тип, скорость или положение врага."
		var at := cell(enemy.cell)
		if board.kind(at) != GridBoard.Cell.FLOOR or occupied.has(at) or not reachable.has(at):
			return "Враг перекрыт, недостижим или совпадает с другим объектом."
		for p in data.spawns:
			if absi(at.x - int(p[0])) + absi(at.y - int(p[1])) < 5:
				return "Враг должен находиться не ближе пяти клеток от старта."
		occupied[at] = true
		if enemy.required:
			required_count += 1
	if data.mode == "solo" and required_count == 0:
		return "Для победы нужен хотя бы один обязательный враг."
	if not data.powerups is Array or data.powerups.size() > 128:
		return "Допускается до 128 бонусов."
	for power in data.powerups:
		if not exact_keys(power, ["cell", "kind", "hidden"]) or not point(power.cell, int(data.width), int(data.height)) or power.kind not in POWERS or not power.hidden is bool:
			return "Неверный бонус."
		var at := cell(power.cell)
		if occupied.has(at) or not reachable.has(at) or board.kind(at) != (GridBoard.Cell.CRATE if power.hidden else GridBoard.Cell.FLOOR):
			return "Бонус должен быть достижим и соответствовать клетке / скрытию."
		occupied[at] = true
	if not data.secrets is Array or not data.secrets.is_empty():
		return "Пользовательские секретные испытания ещё не поддерживаются форматом 1."
	return ""

static func fingerprint(data: Dictionary) -> String:
	var gameplay := {}
	for key in ["mode", "theme", "width", "height", "seed", "generator_version", "rows", "spawns", "enemies", "powerups", "rules", "secrets"]:
		gameplay[key] = data[key]
	return JSON.stringify(normalize_numbers(gameplay), "", true).sha256_text()

# JSON parses all numbers as floats. Normalize validated integral gameplay values before hashing.
static func normalize_numbers(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var result: Array = []
		for item in value: result.append(normalize_numbers(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = normalize_numbers(value[key])
		return result
	return value

static func validate_options(options: Variant) -> String:
	if not options is Dictionary:
		return "Настройки генератора должны быть объектом."
	var limits := {"width": [11, 41], "height": [11, 31], "enemy_count": [1, 32], "bonus_count": [0, 128], "enemy_step": [9, 90], "capacity": [1, 5], "range": [1, 6], "fuse_ticks": [90, 600], "time_limit": [0, 1800]}
	for key in options:
		if limits.has(key):
			if not integer(options[key], limits[key][0], limits[key][1]):
				return "Неверное числовое ограничение: " + str(key)
		elif key in ["hidden", "crates", "walls", "remote"]:
			if not options[key] is bool: return "Ожидается переключатель: " + str(key)
		elif key == "mode":
			if options[key] not in ["solo", "versus"]: return "Неподдерживаемый режим."
		elif key == "enemy_kind":
			if options[key] not in ENEMIES: return "Неподдерживаемый тип врага."
		elif key == "bonus_kind":
			if options[key] not in POWERS: return "Неподдерживаемый бонус."
		else:
			return "Настройка не поддерживается: " + str(key)
	return ""
