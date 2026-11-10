extends Control
## Small drawn icon for each stat (no image files needed).

var kind := "strength"
var color := Color("#d4efff")


func _init() -> void:
	custom_minimum_size = Vector2(34, 34)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	match kind:
		"strength":
			_dumbbell()
		"endurance":
			_stopwatch()
		"agility":
			_bolt()
		"vitality":
			_heart()


func _dumbbell() -> void:
	draw_rect(Rect2(6, 15, 22, 4), color)
	draw_rect(Rect2(2, 10, 5, 14), color)
	draw_rect(Rect2(7, 6, 5, 22), color)
	draw_rect(Rect2(22, 6, 5, 22), color)
	draw_rect(Rect2(27, 10, 5, 14), color)


func _stopwatch() -> void:
	draw_arc(Vector2(17, 19), 11.0, 0.0, TAU, 32, color, 3.0)
	draw_rect(Rect2(13, 2, 8, 4), color)
	draw_line(Vector2(17, 19), Vector2(17, 11), color, 3.0)
	draw_line(Vector2(17, 19), Vector2(23, 22), color, 3.0)


func _bolt() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(21, 1), Vector2(6, 19), Vector2(15, 19),
		Vector2(12, 33), Vector2(28, 14), Vector2(19, 14),
	]), color)


func _heart() -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(17.0 + x * 0.95, 16.0 - y * 0.95))
	draw_colored_polygon(pts, color)
