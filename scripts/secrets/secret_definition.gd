class_name SecretDefinition
extends Resource

@export var id: String = ""
@export var reward: int = 0
@export var explored_percent: int = 101
@export var landmark_order: Array[int] = []
@export var niche: Vector2i = Vector2i(-1, -1)
var text: Dictionary = {}
var valid: bool = false
static var cached: SecretDefinition

static func active() -> SecretDefinition:
	if cached != null: return cached
	cached = SecretDefinition.new()
	var path := "res://resources/private/content.dat"
	if not FileAccess.file_exists(path): return cached
	var data := SealedData.open_bytes(FileAccess.get_file_as_bytes(path), "content")
	if not data.get("id") is String or not data.get("text") is Dictionary or not data.get("order") is Array or not data.get("niche") is Array: return cached
	if data.niche.size() != 2 or data.order != [0.0, 1.0, 2.0] or data.get("percent") != 90 or data.get("reward") != 50000: return cached
	cached.id = data.id
	cached.reward = int(data.reward)
	cached.explored_percent = int(data.percent)
	cached.landmark_order.assign([0, 1, 2])
	cached.niche = Vector2i(int(data.niche[0]), int(data.niche[1]))
	cached.text = data.text
	cached.valid = true
	return cached

func localized(field: String, locale: String = "") -> String:
	var language := TranslationServer.get_locale().left(2) if locale.is_empty() else locale
	return str(text.get(field, {}).get(language, text.get(field, {}).get("en", "")))

static func normalize_id(value: Variant) -> String:
	if not value is String or not active().valid: return ""
	if value == active().id: return value
	# Legacy migration accepts only the old known identifier, without a readable alias in runtime code.
	if value.sha256_text() == "4619a142b1e8bfc35bd395089b56fd3638e4bcc09caa072f0963ae3f1b1bd1cd": return active().id
	return ""
