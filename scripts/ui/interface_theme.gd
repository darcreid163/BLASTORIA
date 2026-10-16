class_name InterfaceTheme
extends RefCounted

static func panel(color: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

static func create(locale: String) -> Theme:
	var theme := Theme.new()
	theme.default_font = LanguageCatalog.font_for(locale)
	theme.default_font_size = 18
	for kind in ["Button", "OptionButton", "LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", kind, panel(Color("193039"), Color("3d5960")))
		theme.set_stylebox("hover", kind, panel(Color("29444b"), Color("be9564")))
		theme.set_stylebox("pressed", kind, panel(Color("3b4b45"), Color("e7b77b")))
		var focus := panel(Color(0, 0, 0, 0), Color("ffca80"))
		focus.set_border_width_all(3)
		theme.set_stylebox("focus", kind, focus)
		theme.set_color("font_color", kind, Color("e4ede6"))
		theme.set_color("font_hover_color", kind, Color("ffe3b7"))
		theme.set_color("font_focus_color", kind, Color("ffe3b7"))
	theme.set_stylebox("panel", "PanelContainer", panel(Color("11262e"), Color("31474f")))
	theme.set_color("font_color", "Label", Color("e4ede6"))
	return theme
