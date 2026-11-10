extends Control
## A simple chart that draws itself. mode "line" for trends, "bars" for daily totals.
## Tap a point or bar to see its value.

const HistoryData = preload("res://scripts/history_data.gd")

const PAD_L := 58.0
const PAD_R := 14.0
const PAD_T := 14.0
const PAD_B := 32.0

var mode := "line"
var color := Color("#6cc3ff")
var unit := ""
var decimals := 1
var goal_value := -1.0
var empty_text := "No data yet"
var points: Array = []  # Vector2(day, value)
var x_min := 0.0
var x_max := 1.0
var _selected := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # taps are read, scrolling still works


func set_data(new_points: Array, first_day: float, last_day: float) -> void:
	points = new_points
	x_min = first_day
	x_max = last_day
	_selected = -1
	queue_redraw()


func _area() -> Rect2:
	return Rect2(PAD_L, PAD_T, size.x - PAD_L - PAD_R, size.y - PAD_T - PAD_B)


func _y_range() -> Vector2:
	var low := INF
	var high := -INF
	for p in points:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	if goal_value > 0.0:
		low = minf(low, goal_value)
		high = maxf(high, goal_value)
	if mode == "bars":
		return Vector2(0.0, _nice_ceil(maxf(high, 1.0)))
	var pad := maxf((high - low) * 0.15, 0.5)
	return Vector2(low - pad, high + pad)


## Rounds up to 1, 2, 5 or 10 times a power of ten, so axis labels look tidy.
func _nice_ceil(value: float) -> float:
	var base := pow(10.0, floor(log(value) / log(10.0)))
	var f := value / base
	var nice := 10.0
	if f <= 1.0:
		nice = 1.0
	elif f <= 2.0:
		nice = 2.0
	elif f <= 5.0:
		nice = 5.0
	return nice * base


func _center_x(day: float, area: Rect2) -> float:
	if mode == "bars":
		var count := maxf(x_max - x_min + 1.0, 1.0)
		return area.position.x + (day - x_min + 0.5) * area.size.x / count
	if x_max <= x_min:
		return area.position.x + area.size.x * 0.5
	return area.position.x + (day - x_min) / (x_max - x_min) * area.size.x


func _y_pos(value: float, area: Rect2, y_lo: float, y_hi: float) -> float:
	return area.end.y - (value - y_lo) / (y_hi - y_lo) * area.size.y


func _fmt(value: float) -> String:
	if decimals == 0:
		return str(int(roundf(value)))
	return String.num(value, decimals)


func _draw() -> void:
	var font := get_theme_default_font()
	var label_color := Color("#7da7c9")
	var grid_color := Color(0.56, 0.82, 1.0, 0.18)
	var area := _area()

	var has_values := not points.is_empty()
	if has_values and mode == "bars":
		has_values = HistoryData.total(points) > 0.0
	if not has_values:
		draw_string(font, Vector2(0, size.y * 0.5 + 6), empty_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, label_color)
		return

	var y_range := _y_range()
	var y_lo := y_range.x
	var y_hi := y_range.y

	# Grid and value labels.
	for i in 3:
		var t := i / 2.0
		var y := area.position.y + area.size.y * t
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color, 1.0)
		draw_string(font, Vector2(0, y + 5), _fmt(y_hi - (y_hi - y_lo) * t), HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 8, 15, label_color)

	# Date labels.
	draw_string(font, Vector2(area.position.x, size.y - 6), HistoryData.day_to_label(int(x_min)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, label_color)
	draw_string(font, Vector2(area.end.x - 110.0, size.y - 6), HistoryData.day_to_label(int(x_max)), HORIZONTAL_ALIGNMENT_RIGHT, 110, 15, label_color)

	# Goal line.
	if goal_value > 0.0:
		var gy := _y_pos(goal_value, area, y_lo, y_hi)
		draw_dashed_line(Vector2(area.position.x, gy), Vector2(area.end.x, gy), Color("#ffd447"), 2.0, 8.0)
		draw_string(font, Vector2(area.end.x - 80.0, gy - 6), "goal", HORIZONTAL_ALIGNMENT_RIGHT, 80, 15, Color("#ffd447"))

	# Data.
	if mode == "bars":
		var count := maxf(x_max - x_min + 1.0, 1.0)
		var slot := area.size.x / count
		for p in points:
			var h: float = p.y / y_hi * area.size.y
			if h > 0.0:
				var bar_x: float = area.position.x + (p.x - x_min) * slot + slot * 0.15
				draw_rect(Rect2(bar_x, area.end.y - h, maxf(slot * 0.7, 1.0), h), color)
	else:
		var line := PackedVector2Array()
		for p in points:
			line.append(Vector2(_center_x(p.x, area), _y_pos(p.y, area, y_lo, y_hi)))
		if line.size() >= 2:
			draw_polyline(line, color, 3.0, true)
		for pt in line:
			draw_circle(pt, 4.5, color)

	# Selected value.
	if _selected >= 0 and _selected < points.size():
		var sp: Vector2 = points[_selected]
		var anchor := Vector2(_center_x(sp.x, area), _y_pos(sp.y, area, y_lo, y_hi))
		draw_circle(anchor, 6.0, Color.WHITE)
		var text := "%s: %s %s" % [HistoryData.day_to_label(int(sp.x)), _fmt(sp.y), unit]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var box_pos := Vector2(
			clampf(anchor.x - text_size.x * 0.5 - 8.0, 0.0, size.x - text_size.x - 16.0),
			maxf(anchor.y - text_size.y - 22.0, 0.0))
		draw_rect(Rect2(box_pos, text_size + Vector2(16, 8)), Color(0.05, 0.12, 0.2, 0.95))
		draw_rect(Rect2(box_pos, text_size + Vector2(16, 8)), Color(0.56, 0.82, 1.0, 0.8), false, 1.0)
		draw_string(font, box_pos + Vector2(8, text_size.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(event.position.x)


func _pick(pixel_x: float) -> void:
	var area := _area()
	var best := -1
	var best_distance := INF
	for i in points.size():
		var distance := absf(_center_x(points[i].x, area) - pixel_x)
		if distance < best_distance:
			best_distance = distance
			best = i
	_selected = best
	queue_redraw()
