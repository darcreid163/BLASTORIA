class_name LanguageCatalog
extends RefCounted

const LOCALES := ["en", "ru", "ja", "ko", "zh_CN", "hi", "id", "th", "vi", "fr", "it", "de", "ar", "tr"]
const NAMES := {"en": ["English", "English"], "ru": ["Русский", "Russian"], "ja": ["日本語", "Japanese"], "ko": ["한국어", "Korean"], "zh_CN": ["简体中文", "Simplified Chinese"], "hi": ["हिन्दी", "Hindi"], "id": ["Bahasa Indonesia", "Indonesian"], "th": ["ไทย", "Thai"], "vi": ["Tiếng Việt", "Vietnamese"], "fr": ["Français", "French"], "it": ["Italiano", "Italian"], "de": ["Deutsch", "German"], "ar": ["العربية", "Arabic"], "tr": ["Türkçe", "Turkish"]}
const LOCALIZED_NAMES := {
"en": ["English", "Russian", "Japanese", "Korean", "Simplified Chinese", "Hindi", "Indonesian", "Thai", "Vietnamese", "French", "Italian", "German", "Arabic", "Turkish"],
"ru": ["Английский", "Русский", "Японский", "Корейский", "Упрощённый китайский", "Хинди", "Индонезийский", "Тайский", "Вьетнамский", "Французский", "Итальянский", "Немецкий", "Арабский", "Турецкий"],
"ja": ["英語", "ロシア語", "日本語", "韓国語", "簡体字中国語", "ヒンディー語", "インドネシア語", "タイ語", "ベトナム語", "フランス語", "イタリア語", "ドイツ語", "アラビア語", "トルコ語"],
"ko": ["영어", "러시아어", "일본어", "한국어", "중국어 간체", "힌디어", "인도네시아어", "태국어", "베트남어", "프랑스어", "이탈리아어", "독일어", "아랍어", "튀르키예어"],
"zh_CN": ["英语", "俄语", "日语", "韩语", "简体中文", "印地语", "印度尼西亚语", "泰语", "越南语", "法语", "意大利语", "德语", "阿拉伯语", "土耳其语"],
"hi": ["अंग्रेज़ी", "रूसी", "जापानी", "कोरियाई", "सरलीकृत चीनी", "हिन्दी", "इंडोनेशियाई", "थाई", "वियतनामी", "फ़्रेंच", "इतालवी", "जर्मन", "अरबी", "तुर्की"],
"id": ["Inggris", "Rusia", "Jepang", "Korea", "Mandarin Sederhana", "Hindi", "Indonesia", "Thai", "Vietnam", "Prancis", "Italia", "Jerman", "Arab", "Turki"],
"th": ["อังกฤษ", "รัสเซีย", "ญี่ปุ่น", "เกาหลี", "จีนตัวย่อ", "ฮินดี", "อินโดนีเซีย", "ไทย", "เวียดนาม", "ฝรั่งเศส", "อิตาลี", "เยอรมัน", "อาหรับ", "ตุรกี"],
"vi": ["Tiếng Anh", "Tiếng Nga", "Tiếng Nhật", "Tiếng Hàn", "Tiếng Trung giản thể", "Tiếng Hindi", "Tiếng Indonesia", "Tiếng Thái", "Tiếng Việt", "Tiếng Pháp", "Tiếng Ý", "Tiếng Đức", "Tiếng Ả Rập", "Tiếng Thổ Nhĩ Kỳ"],
"fr": ["Anglais", "Russe", "Japonais", "Coréen", "Chinois simplifié", "Hindi", "Indonésien", "Thaï", "Vietnamien", "Français", "Italien", "Allemand", "Arabe", "Turc"],
"it": ["Inglese", "Russo", "Giapponese", "Coreano", "Cinese semplificato", "Hindi", "Indonesiano", "Thailandese", "Vietnamita", "Francese", "Italiano", "Tedesco", "Arabo", "Turco"],
"de": ["Englisch", "Russisch", "Japanisch", "Koreanisch", "Chinesisch (vereinfacht)", "Hindi", "Indonesisch", "Thailändisch", "Vietnamesisch", "Französisch", "Italienisch", "Deutsch", "Arabisch", "Türkisch"],
"ar": ["الإنجليزية", "الروسية", "اليابانية", "الكورية", "الصينية المبسطة", "الهندية", "الإندونيسية", "التايلاندية", "الفيتنامية", "الفرنسية", "الإيطالية", "الألمانية", "العربية", "التركية"],
"tr": ["İngilizce", "Rusça", "Japonca", "Korece", "Basitleştirilmiş Çince", "Hintçe", "Endonezce", "Tayca", "Vietnamca", "Fransızca", "İtalyanca", "Almanca", "Arapça", "Türkçe"]}

static func display_name(locale: String, current: String) -> String:
	var autonym: String = NAMES[locale][0]
	var exonym: String = LOCALIZED_NAMES[normalize(current)][LOCALES.find(locale)]
	return autonym if autonym.to_lower() == exonym.to_lower() else autonym + " · " + exonym

static func matches(locale: String, query: String, current: String) -> bool:
	return (display_name(locale, current) + " " + str(NAMES[locale][1])).to_lower().contains(query.strip_edges().to_lower())

static var installed: bool = false
static var table: Dictionary = {}
static var fonts: Dictionary = {}

static func normalize(locale: String) -> String:
	if locale.to_lower().begins_with("zh"): return "zh_CN"
	var short := locale.left(2).to_lower()
	return short if short in LOCALES else "en"

static func install() -> void:
	if installed: return
	table = JSON.parse_string(FileAccess.get_file_as_string("res://localization/catalog.json"))
	for locale in LOCALES:
		var translation := Translation.new()
		translation.locale = locale
		for key in table[locale]: translation.add_message(key, table[locale][key])
		if locale in ["en", "ru"] and FileAccess.file_exists("res://localization/strings.csv"):
			var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
			file.get_csv_line()
			while not file.eof_reached():
				var row := file.get_csv_line()
				if row.size() == 3 and not table[locale].has(row[0]): translation.add_message(row[0], row[1 if locale == "en" else 2])
		TranslationServer.add_translation(translation)
	installed = true

static func font_for(locale: String) -> Font:
	locale = normalize(locale)
	if fonts.has(locale): return fonts[locale]
	var latin: Font = load("res://assets/fonts/NotoSans-Regular.ttf")
	var path: String = {"ja": "Interface-jp.otf", "ko": "Interface-kr.otf", "zh_CN": "Interface-sc.otf", "ar": "NotoSansArabic-Regular.ttf", "hi": "NotoSansDevanagari-Regular.ttf", "th": "NotoSansThai-Regular.ttf"}.get(locale, "NotoSans-Regular.ttf")
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/" + path)
	if path != "NotoSans-Regular.ttf": font.fallbacks = [latin]
	fonts[locale] = font
	return font

static func universal_font() -> Font:
	if fonts.has("universal"): return fonts.universal
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSans-Regular.ttf")
	var fallbacks: Array[Font] = []
	for locale in ["ja", "ko", "zh_CN", "hi", "th", "ar"]: fallbacks.append(font_for(locale))
	font.fallbacks = fallbacks
	fonts.universal = font
	return font

static func apply(tree: SceneTree, locale: String) -> void:
	install()
	locale = normalize(locale)
	TranslationServer.set_locale(locale)
	ThemeDB.fallback_font = font_for(locale)
	tree.root.theme = InterfaceTheme.create(locale)
	tree.root.content_scale_factor = 1.0
	tree.call_group("localized_surfaces", "retranslate")
