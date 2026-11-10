extends Control
## Draws the silhouette avatar. The body is built from a handful of numbers (params_for),
## so morphing from one body to another is just blending those numbers.
## Coordinates are drawn in a 150 x 410 box and scaled to fit this control.

const BODY_H := 410.0
const BODY_W := 150.0

var outline_color := Color("#6c8cff")
var fill_color := Color("#2c376e")

var _params: Dictionary = {}
var _from: Dictionary = {}
var _to: Dictionary = {}
var _outline := PackedVector2Array()
var _tween: Tween


## fat and muscle are 0..1.
func set_state(sex: String, fat: float, muscle: float) -> void:
	var target := params_for(sex, fat, muscle)
	if _tween:
		_tween.kill()
	if _params.is_empty() or not is_inside_tree():
		_params = target
		_outline = outline_for(_params)
		queue_redraw()
		return
	_from = _params.duplicate()
	_to = target
	_tween = create_tween()
	_tween.tween_method(_blend, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _blend(t: float) -> void:
	for key in _to:
		_params[key] = lerpf(float(_from[key]), float(_to[key]), t)
	_outline = outline_for(_params)
	queue_redraw()


func _draw() -> void:
	if _outline.size() < 3:
		return
	var s := minf(size.x / BODY_W, size.y / BODY_H)
	draw_set_transform(Vector2(size.x * 0.5, (size.y - BODY_H * s) * 0.5), 0.0, Vector2(s, s))
	draw_colored_polygon(_outline, fill_color)
	draw_polyline(_closed(_outline), outline_color, 3.0, true)


# ---------------------------------------------------------------- body shape

## Half-widths of each body part, from the two axes and the silhouette type.
static func params_for(sex: String, fat: float, muscle: float) -> Dictionary:
	var f := clampf(fat, 0.0, 1.0)
	var m := clampf(muscle, 0.0, 1.0)
	var p := {
		"shoulder": 38.0 + 12.0 * m + 6.0 * f,
		"chest": 33.0 + 10.0 * m + 10.0 * f,
		"waist": 22.0 + 20.0 * f - 2.5 * m,
		"belly": 12.0 * f,
		"hip": 29.0 + 16.0 * f + 2.0 * m,
		"thigh": 12.0 + 9.0 * f + 3.0 * m,
		"calf": 7.0 + 3.5 * f + 2.0 * m,
		"arm": 7.0 + 3.0 * m + 6.0 * f,
		"neck": 8.0 + 3.0 * m + 4.0 * f,
	}
	match sex:
		"male":
			p["shoulder"] *= 1.08
			p["chest"] *= 1.04
			p["hip"] *= 0.95
		"female":
			p["shoulder"] *= 0.88
			p["chest"] *= 0.95
			p["waist"] *= 0.92
			p["hip"] *= 1.08
			p["neck"] *= 0.88
			p["arm"] *= 0.9
	return p


## One merged outline of head, neck, torso, arms and legs.
static func outline_for(p: Dictionary) -> PackedVector2Array:
	# Order matters: each part must overlap the shape built so far (torso, neck, then head).
	var parts: Array = [_torso(p), _neck(p), _head()]
	for side in [1.0, -1.0]:
		parts.append(_shoulder(p, side))
		parts.append(_arm(p, side))
		parts.append(_leg(p, side))
	var union: PackedVector2Array = parts[0]
	for i in range(1, parts.size()):
		union = _largest(Geometry2D.merge_polygons(union, parts[i]), union)
	return union


static func _head() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var angle := TAU * i / 28.0
		pts.append(Vector2(cos(angle) * 20.0, 24.0 + sin(angle) * 22.0))
	return pts


static func _neck(p: Dictionary) -> PackedVector2Array:
	var n: float = p["neck"]
	return PackedVector2Array([Vector2(-n, 40.0), Vector2(n, 40.0), Vector2(n + 3.0, 62.0), Vector2(-n - 3.0, 62.0)])


static func _torso(p: Dictionary) -> PackedVector2Array:
	# Right half from top to bottom (x, y); the left half is mirrored.
	var half := [
		Vector2(0.0, 54.0),
		Vector2(float(p["neck"]) + 4.0, 56.0),
		Vector2(float(p["shoulder"]) * 0.62, 62.0),
		Vector2(p["shoulder"], 74.0),
		Vector2(p["chest"], 100.0),
		Vector2(p["waist"], 135.0),
		Vector2(float(p["waist"]) + float(p["belly"]), 160.0),
		Vector2(p["hip"], 188.0),
		Vector2(float(p["hip"]) * 0.8, 206.0),
		Vector2(0.0, 208.0),
	]
	var ring := PackedVector2Array()
	for pt in half:
		ring.append(pt)
	for i in range(half.size() - 2, 0, -1):
		ring.append(Vector2(-half[i].x, half[i].y))
	return smooth_closed(ring, 6)


## Rounded shoulder joint, so the top of each arm blends into the torso.
static func _shoulder(p: Dictionary, side: float) -> PackedVector2Array:
	var s: float = p["shoulder"]
	var a: float = p["arm"]
	var center := Vector2(side * (s + a * 0.1), 80.0)
	var pts := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * a * 1.1)
	return pts


static func _arm(p: Dictionary, side: float) -> PackedVector2Array:
	var s: float = p["shoulder"]
	var a: float = p["arm"]
	var centers := [
		Vector2(side * (s + a * 0.1), 80.0),
		Vector2(side * (s + a * 0.4 + 3.0), 138.0),
		Vector2(side * (s + a * 0.5 + 7.0), 192.0),
		Vector2(side * (s + a * 0.5 + 9.0), 212.0),
	]
	return _limb(centers, [a, a * 0.85, a * 0.68, a * 0.55])


static func _leg(p: Dictionary, side: float) -> PackedVector2Array:
	var thigh: float = p["thigh"]
	var calf: float = p["calf"]
	var cx := thigh + 1.5
	var knee := (thigh + calf) * 0.5 * 0.9
	var centers := [
		Vector2(side * cx, 196.0),
		Vector2(side * (cx + 0.5), 250.0),
		Vector2(side * (cx + 1.0), 300.0),
		Vector2(side * cx, 345.0),
		Vector2(side * (cx - 0.5), 385.0),
		Vector2(side * (cx - 0.5), 399.0),
	]
	return _limb(centers, [thigh, thigh * 0.95, knee, calf, calf * 0.62, calf * 0.55])


## A tapered tube along a list of centre points. The far end is cut flat.
static func _limb(centers: Array, widths: Array) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var last := centers.size() - 1
	for i in centers.size():
		var dir: Vector2 = centers[mini(i + 1, last)] - centers[maxi(i - 1, 0)]
		dir = dir.normalized()
		var normal := Vector2(-dir.y, dir.x)
		left.append(centers[i] + normal * float(widths[i]))
		right.append(centers[i] - normal * float(widths[i]))
	var ring := smooth_open(left, 5)
	var back := smooth_open(right, 5)
	back.reverse()
	ring.append_array(back)
	return ring


# ---------------------------------------------------------------- geometry helpers

## Rounds off a closed polygon with a Catmull-Rom spline.
static func smooth_closed(points: PackedVector2Array, steps: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n:
		var p0 := points[(i - 1 + n) % n]
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var p3 := points[(i + 2) % n]
		for step in steps:
			out.append(_catmull(p0, p1, p2, p3, float(step) / steps))
	return out


## Smooths a line but keeps its two end points where they are (so ends stay square).
static func smooth_open(points: PackedVector2Array, steps: int = 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for step in steps:
			out.append(_catmull(p0, p1, p2, p3, float(step) / steps))
	out.append(points[n - 1])
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


## Of the polygons a merge returns (outer shape plus any holes), keep the biggest.
static func _largest(polygons: Array, fallback: PackedVector2Array) -> PackedVector2Array:
	var best := fallback
	var best_area := -1.0
	for poly in polygons:
		var area := _area(poly)
		if area > best_area:
			best_area = area
			best = poly
	return best


static func _area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
