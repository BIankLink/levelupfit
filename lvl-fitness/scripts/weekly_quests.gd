extends RefCounted
## Weekly quests, separate from the daily ones (missing them never breaks a streak):
##  - Weekly weigh-in: due every 7 days, gives bonus Vitality.
##  - Rest quest (optional): 10 min of stretching/yoga/foam rolling, or a 15 min walk, once a week.

const HistoryData = preload("res://scripts/history_data.gd")

const WEIGH_IN_EVERY_DAYS := 7
const WEIGH_IN_BONUS := 30.0
const REST_BONUS := 20.0
const REST_WALK_MINUTES := 15.0
const REST_RECOVERY_MINUTES := 10.0


static func _weekly() -> Dictionary:
	return SaveData.data["weekly"]


# ---------------------------------------------------------------- weigh-in

## Days since the last weigh-in, or -1 if there has never been one.
static func days_since_weigh_in() -> int:
	var entries: Array = SaveData.data["weigh_ins"]
	if entries.is_empty():
		return -1
	return HistoryData.today_day() - HistoryData.date_to_day(entries[entries.size() - 1]["date"])


static func weigh_in_due() -> bool:
	var days := days_since_weigh_in()
	return days < 0 or days >= WEIGH_IN_EVERY_DAYS


static func days_until_weigh_in() -> int:
	return maxi(WEIGH_IN_EVERY_DAYS - days_since_weigh_in(), 0)


## Call after a weigh-in is saved. Returns a pop-up message, or "" if no bonus.
## A weigh-in only counts if the previous one was at least 6 days ago (stops farming).
static func on_weigh_in(entry: Dictionary) -> String:
	var entries: Array = SaveData.data["weigh_ins"]
	if entries.size() >= 2:
		var gap := HistoryData.date_to_day(entry["date"]) - HistoryData.date_to_day(entries[entries.size() - 2]["date"])
		if gap < WEIGH_IN_EVERY_DAYS - 1:
			return ""
	StatsManager.add_points("vitality", WEIGH_IN_BONUS)
	return "Weekly weigh-in complete!"


# ---------------------------------------------------------------- rest quest

## Day number of this week's Monday.
static func week_start_day() -> int:
	var today := HistoryData.today_day()
	var weekday := int(Time.get_date_dict_from_unix_time(today * 86400)["weekday"])  # 0 = Sunday
	return today - (weekday + 6) % 7


static func _refresh_week() -> void:
	var start := week_start_day()
	if int(_weekly()["week_start"]) != start:
		_weekly()["week_start"] = start
		_weekly()["rest_done"] = false


static func rest_done() -> bool:
	_refresh_week()
	return bool(_weekly()["rest_done"])


## Call after any workout is logged. Returns a pop-up message, or "".
static func on_workout(entry: Dictionary) -> String:
	_refresh_week()
	if bool(_weekly()["rest_done"]):
		return ""
	var counts := false
	match entry["type"]:
		"recovery":
			counts = float(entry["minutes"]) >= REST_RECOVERY_MINUTES
		"cardio":
			counts = entry["exercise"] == "walk" and float(entry["minutes"]) >= REST_WALK_MINUTES
	if not counts:
		return ""
	_weekly()["rest_done"] = true
	StatsManager.add_points("vitality", REST_BONUS)
	return "Rest quest complete!"
