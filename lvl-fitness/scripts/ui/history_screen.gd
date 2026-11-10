extends ScrollContainer
## Charts: weight, body fat, steps, cardio and lifting volume over time.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const LineChart = preload("res://scripts/ui/line_chart.gd")
const HistoryData = preload("res://scripts/history_data.gd")
const GrandQuest = preload("res://scripts/grand_quest.gd")

const RANGES := [[7, "7 days"], [30, "30 days"], [90, "90 days"]]

var _box: VBoxContainer
var _cards: VBoxContainer
var _range := 30
var _range_buttons := {}


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)

	_box.add_child(UIKit.make_label("Charts", 34))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	var group := ButtonGroup.new()
	for item in RANGES:
		var button := UIKit.make_button(item[1])
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_on_range_pressed.bind(item[0]))
		row.add_child(button)
		_range_buttons[item[0]] = button
	_range_buttons[_range].set_pressed_no_signal(true)

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	_box.add_child(_cards)


func _on_range_pressed(days: int) -> void:
	_range = days
	refresh()


func refresh() -> void:
	_range_buttons[_range].set_pressed_no_signal(true)
	UIKit.clear(_cards)
	_add_weight_card("Weight", "weight_kg", "kg", UIKit.rank_color("D"), true)
	_add_weight_card("Body fat", "body_fat_pct", "%", UIKit.rank_color("A"), false)
	_add_daily_card("Steps", "steps", "steps", UIKit.GOOD, "avg")
	_add_daily_card("Cardio", "cardio", "min", UIKit.rank_color("C"), "total")
	_add_daily_card("Lifting volume", "volume", "kg", UIKit.rank_color("B"), "total")


func _add_weight_card(title: String, key: String, unit: String, color: Color, show_goal: bool) -> void:
	var data := HistoryData.weigh_in_points(key, _range)
	var chart := LineChart.new()
	chart.color = color
	chart.unit = unit
	chart.decimals = 1
	chart.empty_text = "Log a weigh-in to see this chart"
	if show_goal and GrandQuest.has_goal():
		chart.goal_value = GrandQuest.goal_kg()
	var span := HistoryData.x_range(data, _range)
	chart.set_data(data, span.x, span.y)

	var summary := ""
	if not data.is_empty():
		var last: float = data[data.size() - 1].y
		summary = "%.1f %s" % [last, unit]
		if data.size() >= 2:
			summary += "   (%+.1f)" % (last - float(data[0].y))
	_cards.add_child(_chart_card(title, summary, chart))


func _add_daily_card(title: String, kind: String, unit: String, color: Color, summary_kind: String) -> void:
	var series := HistoryData.daily_series(kind, _range)
	var chart := LineChart.new()
	chart.mode = "bars"
	chart.color = color
	chart.unit = unit
	chart.decimals = 0
	chart.empty_text = "Nothing logged in this period"
	var span := HistoryData.x_range([], _range)
	chart.set_data(series, span.x, span.y)

	var total := HistoryData.total(series)
	var summary := ""
	if total > 0.0:
		if summary_kind == "avg":
			summary = "avg %s / day" % UIKit.fmt(total / _range)
		else:
			summary = "total %s %s" % [UIKit.fmt(total), unit]
	_cards.add_child(_chart_card(title, summary, chart))


func _chart_card(title: String, summary: String, chart: Control) -> Control:
	var panel := UIKit.make_status_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(UIKit.make_glow_label(title, 26))
	var summary_label := UIKit.make_label(summary, 20, UIKit.MUTED_BLUE, false)
	top.add_child(summary_label)

	chart.custom_minimum_size = Vector2(0, 230)
	column.add_child(chart)
	return panel
