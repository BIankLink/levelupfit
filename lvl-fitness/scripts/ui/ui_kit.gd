extends RefCounted
## Shared colors and small helpers for building the UI in code.

const BG := Color("#0f1220")
const CARD := Color("#1a1f36")
const CARD_DONE := Color("#16352c")
const NAV_BG := Color("#141830")
const TOAST_BG := Color("#2b3568")
const BAR_BG := Color("#2a3050")
const TEXT := Color("#e8ebf7")
const MUTED := Color("#8b93b3")
const ACCENT := Color("#6c8cff")
const GOOD := Color("#4fd08a")

# "Status window" look: dark glass panel, thin light-blue lines, glowing text.
const PANEL_BG := Color(0.03, 0.07, 0.13, 0.92)
const PANEL_LINE := Color("#8fd0ff")
const GLOW := Color("#d4efff")
const GLOW_HALO := Color(0.3, 0.7, 1.0, 0.85)
const MUTED_BLUE := Color("#7da7c9")

const RANK_COLORS := {
	"F": Color("#8b93b3"), "E": Color("#6fbf73"), "D": Color("#4fa3e0"),
	"C": Color("#9b6fe0"), "B": Color("#e0b04f"), "A": Color("#e07a4f"),
	"S": Color("#e04f6f"), "SS": Color("#ff3b8a"), "SSS": Color("#ffd447"),
}


static func rank_color(rank: String) -> Color:
	return RANK_COLORS.get(rank, TEXT)


static func _box(color: Color, radius: int = 14, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	for type_name in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, TEXT)
		t.set_color("font_pressed_color", type_name, Color.WHITE)
		t.set_color("font_focus_color", type_name, TEXT)
	for type_name in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type_name, _box(CARD, 14, 14))
		t.set_stylebox("hover", type_name, _box(CARD.lightened(0.1), 14, 14))
		t.set_stylebox("pressed", type_name, _box(ACCENT, 14, 14))
		t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		t.set_stylebox("disabled", type_name, _box(CARD.darkened(0.3), 14, 14))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "LineEdit", _box(BAR_BG, 10, 10))
	t.set_stylebox("focus", "LineEdit", _box(BAR_BG.lightened(0.1), 10, 10))
	t.set_stylebox("background", "ProgressBar", _box(BAR_BG, 7, 0))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, 7, 0))
	t.set_constant("v_separation", "PopupMenu", 18)
	return t


static func make_card(color: Color = CARD) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(color, 16, 16))
	return panel


## expand = true makes the label fill the row and wrap long text.
static func make_label(text: String, size: int = 24, color: Color = TEXT, expand: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if expand:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
	return label


static func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	return button


static func make_progress(ratio: float, color: Color = ACCENT) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("fill", _box(color, 7, 0))
	return bar


## Big window frame: dark glass with a glowing light-blue border.
static func make_status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_border_width_all(2)
	box.border_color = PANEL_LINE
	box.set_corner_radius_all(2)
	box.set_content_margin_all(16)
	box.shadow_color = Color(0.3, 0.7, 1.0, 0.35)
	box.shadow_size = 10
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Thin outlined box used inside the status window.
static func make_outline_box(margin: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.12, 0.2, 0.35)
	box.set_border_width_all(1)
	box.border_color = Color(0.56, 0.82, 1.0, 0.75)
	box.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Text with a soft blue glow around it.
static func make_glow_label(text: String, size: int = 24, color: Color = GLOW, expand: bool = true) -> Label:
	var label := make_label(text, size, color, expand)
	label.add_theme_color_override("font_shadow_color", GLOW_HALO)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 6)
	return label


## Slim square-edged bar for the status window.
static func make_thin_bar(ratio: float, color: Color = GLOW) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", _box(Color(0.1, 0.2, 0.3, 0.8), 2, 0))
	bar.add_theme_stylebox_override("fill", _box(color, 2, 0))
	return bar


static func set_bar_color(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("fill", _box(color, 2, 0))


## Whole number with thousands separators, e.g. 12400 -> "12,400".
static func fmt(value: float) -> String:
	var digits := str(int(roundf(value)))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and digits[i - 1] != "-":
			out = "," + out
	return out


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
