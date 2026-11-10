extends RefCounted
## Turns saved logs and weigh-ins into point lists for the charts.
## Points are Vector2(day_number, value), where day_number is days since 1970-01-01.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func date_to_day(date: String) -> int:
	return int(floor(Time.get_unix_time_from_datetime_string(date) / 86400.0))


static func today_day() -> int:
	return date_to_day(SaveData.today_string())


static func day_to_label(day: int) -> String:
	var d := Time.get_date_dict_from_unix_time(day * 86400)
	return "%s %d" % [MONTHS[int(d["month"]) - 1], int(d["day"])]


## Weigh-in values over time (one point per day, last entry of the day wins).
## If fewer than 2 fall inside the window, the last 2 overall are used so a line can be drawn.
static func weigh_in_points(key: String, window_days: int) -> Array:
	var by_day := {}
	for entry in SaveData.data["weigh_ins"]:
		if entry.has(key):
			by_day[date_to_day(entry["date"])] = float(entry[key])
	var days: Array = by_day.keys()
	days.sort()
	var cutoff := today_day() - window_days + 1
	var picked: Array = []
	for day in days:
		if day >= cutoff:
			picked.append(Vector2(day, by_day[day]))
	if picked.size() < 2 and days.size() >= 2:
		picked = []
		for day in days.slice(days.size() - 2):
			picked.append(Vector2(day, by_day[day]))
	return picked


## First and last day for the chart's horizontal axis.
static func x_range(points: Array, window_days: int) -> Vector2:
	var first := today_day() - window_days + 1
	if not points.is_empty():
		first = mini(first, int(points[0].x))
	return Vector2(first, today_day())


## One value per day for the last N days (zeros included). kind: steps | cardio | volume
static func daily_series(kind: String, window_days: int) -> Array:
	var sums := {}
	for entry in SaveData.data["logs"]:
		var amount := 0.0
		match kind:
			"steps":
				if entry["type"] == "steps":
					amount = float(entry["steps"])
			"cardio":
				if entry["type"] == "cardio":
					amount = float(entry["minutes"])
			"volume":
				if entry["type"] == "lift":
					amount = float(entry["sets"]) * float(entry["reps"]) * float(entry["weight_kg"])
		if amount > 0.0:
			var day := date_to_day(entry["date"])
			sums[day] = float(sums.get(day, 0.0)) + amount
	var series: Array = []
	var start := today_day() - window_days + 1
	for day in range(start, today_day() + 1):
		series.append(Vector2(day, float(sums.get(day, 0.0))))
	return series


static func total(series: Array) -> float:
	var sum := 0.0
	for p in series:
		sum += p.y
	return sum
