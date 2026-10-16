class_name SecretDefinition
extends Resource

@export var id: String = ""
@export var reward: int = 0
@export var explored_percent: int = 101
@export var landmark_order: Array[int] = []
@export var niche: Vector2i = Vector2i(-1, -1)
var display_cipher: String = ""
var valid: bool = false
static var cached: SecretDefinition

static func active() -> SecretDefinition:
	if cached != null: return cached
	cached = SecretDefinition.new()
	var data := RuntimeBundle.section("active")
	if not data.get("id") is String or not data.get("view") is String or not data.get("order") is Array or not data.get("niche") is Array: return cached
	if data.id.length() != 32 or data.niche.size() != 2 or data.order.is_empty() or data.order.size() > 32: return cached
	if not integer(data.get("percent"), 1, 100) or not integer(data.get("reward"), 1, 1000000): return cached
	for coordinate in data.niche:
		if not integer(coordinate, 1, 4096): return cached
	var seen := {}
	for index in data.order:
		if not integer(index, 0, 31) or seen.has(int(index)): return cached
		seen[int(index)] = true
	cached.id = data.id
	cached.reward = int(data.reward)
	cached.explored_percent = int(data.percent)
	for index in data.order: cached.landmark_order.append(int(index))
	cached.niche = Vector2i(int(data.niche[0]), int(data.niche[1]))
	cached.display_cipher = data.view
	cached.valid = true
	return cached

func localized(field: String, locale: String = "") -> String:
	var language := TranslationServer.get_locale().left(2) if locale.is_empty() else locale
	var text := SealedData.open_hex(display_cipher, "display")
	return str(text.get(field, {}).get(language, text.get(field, {}).get("en", "")))

static func normalize_id(value: Variant) -> String:
	if not value is String or not active().valid: return ""
	if value == active().id: return value
	# Legacy migration accepts only the old known identifier, without a readable alias in runtime code.
	if value.sha256_text() == "4619a142b1e8bfc35bd395089b56fd3638e4bcc09caa072f0963ae3f1b1bd1cd": return active().id
	return ""

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
