class_name AppTheme
## Minimalist design system: neutrals + one accent; green/red only for gains/losses.

const LIGHT := {
	"bg": Color("#F7F7F5"), "surface": Color("#FFFFFF"), "surface2": Color("#F0F0EE"),
	"text": Color("#18181B"), "muted": Color("#71717A"), "faint": Color("#A1A1AA"),
	"border": Color("#E7E5E4"), "accent": Color("#0F766E"), "on_accent": Color("#FFFFFF"),
	"gain": Color("#15803D"), "loss": Color("#B91C1C"), "scrim": Color(0, 0, 0, 0.35),
}
const DARK := {
	"bg": Color("#0E0E10"), "surface": Color("#18181B"), "surface2": Color("#232327"),
	"text": Color("#F4F4F5"), "muted": Color("#A1A1AA"), "faint": Color("#6B6B73"),
	"border": Color("#2A2A2F"), "accent": Color("#2DD4BF"), "on_accent": Color("#0E0E10"),
	"gain": Color("#4ADE80"), "loss": Color("#F87171"), "scrim": Color(0, 0, 0, 0.55),
}

static var colors: Dictionary = LIGHT
static var dark := false
static var _font_cache := {}


static func c(name: String) -> Color:
	return colors.get(name, Color.MAGENTA)


static func font(weight: int = 400) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var base: FontFile = load("res://assets/fonts/InterVariable.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_font_cache[weight] = fv
	return fv


static func box(bg: Color, radius: int = 12, border: Color = Color.TRANSPARENT, pad_h: int = 14, pad_v: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = true
	s.corner_detail = 6
	if border.a > 0:
		s.set_border_width_all(1)
		s.border_color = border
	return s


static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func build(is_dark: bool) -> Theme:
	dark = is_dark
	colors = DARK if is_dark else LIGHT
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15

	# Labels
	t.set_color("font_color", "Label", c("text"))
	for v in ["Title", "Big", "Muted", "Section", "Small", "Strong", "Gain", "Loss", "Accent", "Faint"]:
		t.set_type_variation(v, "Label")
	t.set_font("font", "Title", font(650))
	t.set_font_size("font_size", "Title", 24)
	t.set_font("font", "Big", font(650))
	t.set_font_size("font_size", "Big", 34)
	t.set_color("font_color", "Muted", c("muted"))
	t.set_font_size("font_size", "Muted", 13)
	t.set_color("font_color", "Faint", c("faint"))
	t.set_font_size("font_size", "Faint", 12)
	t.set_color("font_color", "Section", c("muted"))
	t.set_font("font", "Section", font(600))
	t.set_font_size("font_size", "Section", 12)
	t.set_font_size("font_size", "Small", 13)
	t.set_font("font", "Strong", font(600))
	t.set_font("font", "Gain", font(600))
	t.set_color("font_color", "Gain", c("gain"))
	t.set_font("font", "Loss", font(600))
	t.set_color("font_color", "Loss", c("loss"))
	t.set_font("font", "Accent", font(600))
	t.set_color("font_color", "Accent", c("accent"))

	# Panels
	t.set_stylebox("panel", "PanelContainer", empty_box())
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(c("surface"), 16, c("border"), 16, 16))
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", box(c("surface"), 20, c("border"), 20, 20))
	t.set_type_variation("Bar", "PanelContainer")
	var bar := box(c("surface"), 0, Color.TRANSPARENT, 8, 6)
	bar.border_width_top = 1
	bar.border_color = c("border")
	t.set_stylebox("panel", "Bar", bar)

	# Buttons
	_button(t, "Button", c("surface2"), c("text"), c("surface2").darkened(0.05) if not is_dark else c("surface2").lightened(0.06))
	t.set_type_variation("Primary", "Button")
	_button(t, "Primary", c("text"), c("bg"), c("text").lightened(0.15) if not is_dark else c("text").darkened(0.12))
	t.set_type_variation("Ghost", "Button")
	var ghost := box(Color.TRANSPARENT, 10, Color.TRANSPARENT, 10, 8)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(st, "Ghost", ghost)
	t.set_stylebox("focus", "Ghost", empty_box())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(col, "Ghost", c("accent"))
	t.set_font("font", "Ghost", font(600))
	t.set_type_variation("Danger", "Button")
	_button(t, "Danger", c("surface2"), c("loss"), c("surface2"))
	t.set_type_variation("Row", "Button")
	var row := box(Color.TRANSPARENT, 12, Color.TRANSPARENT, 4, 10)
	var row_h := box(c("surface2"), 12, Color.TRANSPARENT, 4, 10)
	t.set_stylebox("normal", "Row", row)
	t.set_stylebox("hover", "Row", row_h)
	t.set_stylebox("pressed", "Row", row_h)
	t.set_stylebox("focus", "Row", empty_box())
	t.set_type_variation("Chip", "Button")
	_button(t, "Chip", Color.TRANSPARENT, c("muted"), c("surface2"), 10, 8, 999)
	t.set_stylebox("pressed", "Chip", box(c("surface2"), 999, Color.TRANSPARENT, 10, 6))
	t.set_stylebox("hover_pressed", "Chip", box(c("surface2"), 999, Color.TRANSPARENT, 10, 6))
	t.set_color("font_pressed_color", "Chip", c("text"))
	t.set_color("font_hover_pressed_color", "Chip", c("text"))
	t.set_font_size("font_size", "Chip", 13)
	t.set_type_variation("Tab", "Button")
	_button(t, "Tab", Color.TRANSPARENT, c("faint"), Color.TRANSPARENT, 6, 8, 12)
	t.set_color("font_pressed_color", "Tab", c("text"))
	t.set_color("font_hover_pressed_color", "Tab", c("text"))
	t.set_font_size("font_size", "Tab", 12)
	t.set_type_variation("Choice", "Button")
	_button(t, "Choice", c("surface"), c("text"), c("surface2"), 14, 12, 14)
	var ch := box(c("surface"), 14, c("border"), 14, 12)
	t.set_stylebox("normal", "Choice", ch)
	var ch_on := box(c("surface"), 14, c("text"), 14, 12)
	ch_on.set_border_width_all(2)
	t.set_stylebox("pressed", "Choice", ch_on)
	t.set_stylebox("hover_pressed", "Choice", ch_on)
	t.set_color("font_pressed_color", "Choice", c("text"))
	t.set_color("font_hover_pressed_color", "Choice", c("text"))

	# Inputs
	var field := box(c("surface"), 12, c("border"), 14, 12)
	var field_focus := box(c("surface"), 12, c("accent"), 14, 12)
	field_focus.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", box(c("surface2"), 12, c("border"), 14, 12))
	t.set_color("font_color", "LineEdit", c("text"))
	t.set_color("font_placeholder_color", "LineEdit", c("faint"))
	t.set_color("caret_color", "LineEdit", c("accent"))
	t.set_color("selection_color", "LineEdit", Color(c("accent"), 0.25))
	t.set_font_size("font_size", "LineEdit", 16)
	_button(t, "OptionButton", c("surface"), c("text"), c("surface2"), 14, 12, 12)
	t.set_stylebox("normal", "OptionButton", field)
	t.set_stylebox("hover", "OptionButton", field)
	t.set_stylebox("pressed", "OptionButton", field_focus)
	t.set_stylebox("focus", "OptionButton", empty_box())
	t.set_font_size("font_size", "OptionButton", 16)
	t.set_color("font_color", "OptionButton", c("text"))
	t.set_constant("arrow_margin", "OptionButton", 12)
	var popup := box(c("surface"), 14, c("border"), 6, 6)
	popup.shadow_color = Color(0, 0, 0, 0.12)
	popup.shadow_size = 12
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", box(c("surface2"), 10, Color.TRANSPARENT, 10, 6))
	t.set_color("font_color", "PopupMenu", c("text"))
	t.set_color("font_hover_color", "PopupMenu", c("text"))
	t.set_color("font_disabled_color", "PopupMenu", c("faint"))
	t.set_color("font_separator_color", "PopupMenu", c("muted"))
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_constant("item_start_padding", "PopupMenu", 14)
	t.set_constant("item_end_padding", "PopupMenu", 14)
	t.set_stylebox("panel", "PopupPanel", popup)
	t.set_stylebox("embedded_border", "Window", popup)
	t.set_stylebox("embedded_unfocused_border", "Window", popup)

	# Check boxes
	t.set_color("font_color", "CheckButton", c("text"))
	t.set_color("font_pressed_color", "CheckButton", c("text"))
	t.set_color("font_hover_color", "CheckButton", c("text"))
	t.set_color("font_hover_pressed_color", "CheckButton", c("text"))

	# Scrolling: thin, quiet scrollbars
	var grab := box(Color(c("muted"), 0.35), 4, Color.TRANSPARENT, 0, 0)
	var scroll_bg := box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 0)
	scroll_bg.content_margin_left = 3
	scroll_bg.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("panel", "ScrollContainer", empty_box())
	t.set_stylebox("separator", "HSeparator", box(c("border"), 0, Color.TRANSPARENT, 0, 0))
	t.set_constant("separation", "HSeparator", 1)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


static func _button(t: Theme, type: String, bg: Color, fg: Color, bg_hover: Color, ph: int = 16, pv: int = 12, radius: int = 12) -> void:
	t.set_stylebox("normal", type, box(bg, radius, Color.TRANSPARENT, ph, pv))
	t.set_stylebox("hover", type, box(bg_hover, radius, Color.TRANSPARENT, ph, pv))
	t.set_stylebox("pressed", type, box(bg_hover, radius, Color.TRANSPARENT, ph, pv))
	t.set_stylebox("hover_pressed", type, box(bg_hover, radius, Color.TRANSPARENT, ph, pv))
	t.set_stylebox("disabled", type, box(Color(bg, bg.a * 0.5), radius, Color.TRANSPARENT, ph, pv))
	t.set_stylebox("focus", type, empty_box())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(col, type, fg)
	t.set_color("font_disabled_color", type, Color(fg, 0.4))
	t.set_font("font", type, font(600))
