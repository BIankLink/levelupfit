extends RefCounted
## Reads data sent by an iOS Shortcut (steps, weight, body fat, workouts from Apple Health)
## and logs it. The Shortcut opens the web app with the data after the "#" in the link, e.g.
##   https://you.github.io/levelupfit/#v=1&steps=8234&w=125.4&wd=2026-11-10&bf=36.8&wk=Running|2026-11-10T07:30:00|32|5.2
## Data after "#" stays on the phone; it is never sent to the web host.
##
## Keys:  steps = today's total steps         w  = weight in kg      wd = date of that weight (YYYY-MM-DD)
##        bf = body fat %    mp = muscle %    lm = lean mass kg
##        wk = today's workouts, "Name|StartISO|Minutes|Km" separated by "~"

const MAX_REMEMBERED := 300


## "#a=1&b=two%20words" -> {"a": "1", "b": "two words"}
static func parse_hash(raw: String) -> Dictionary:
	var out := {}
	for pair in raw.lstrip("#").split("&", false):
		var parts := pair.split("=", true, 1)
		if parts.size() == 2:
			out[parts[0]] = parts[1].uri_decode()
	return out


## Logs everything in the payload. Safe to run twice with the same data.
## Returns short messages for pop-ups.
static func apply(payload: Dictionary) -> Array:
	var messages: Array = []
	if payload.is_empty():
		return messages
	var today: String = SaveData.today_string()

	if payload.has("steps"):
		var total := int(float(payload["steps"]))
		var already := _steps_logged_today(today)
		if total > already:
			StatsManager.log_steps(total - already)  # Health gives a day total, so only add the difference
			messages.append("%d steps synced" % total)

	if payload.has("w"):
		var message := _import_weight(payload, today)
		if message != "":
			messages.append(message)

	if payload.has("wk"):
		messages.append_array(_import_workouts(String(payload["wk"]), today))

	SaveData.save_data()
	return messages


# ---------------------------------------------------------------- steps

static func _steps_logged_today(today: String) -> int:
	var total := 0
	for entry in SaveData.data["logs"]:
		if entry["type"] == "steps" and entry["date"] == today:
			total += int(entry["steps"])
	return total


# ---------------------------------------------------------------- weight

static func _import_weight(payload: Dictionary, today: String) -> String:
	var weight := float(payload["w"])
	if weight < 20.0 or weight > 500.0:
		return ""
	var date := String(payload.get("wd", today))
	if date.length() != 10 or date[4] != "-":
		date = today
	for entry in SaveData.data["weigh_ins"]:
		if entry["date"] == date:
			return ""  # already have a weigh-in for that day

	var fat := float(payload.get("bf", "0"))
	if fat > 0.0 and fat <= 1.0:
		fat *= 100.0  # some scales report 0.374 instead of 37.4
	if fat <= 0.0:
		fat = _last_body_fat()
	if fat <= 0.0:
		return ""  # the avatar needs body fat too

	var muscle := float(payload.get("mp", "-1"))
	var lean := float(payload.get("lm", "-1"))
	if date == today:
		StatsManager.log_weigh_in(weight, fat, muscle if muscle > 0.0 else -1.0, lean if lean > 0.0 else -1.0)
	else:
		# An older reading: keep the history in order, but no XP for it.
		var entry := {"date": date, "weight_kg": weight, "body_fat_pct": fat}
		if muscle > 0.0:
			entry["muscle_pct"] = muscle
		if lean > 0.0:
			entry["lean_kg"] = lean
		var list: Array = SaveData.data["weigh_ins"]
		var index := list.size()
		while index > 0 and String(list[index - 1]["date"]) > date:
			index -= 1
		list.insert(index, entry)
		QuestManager.sync_grand_quest()
	return "Weigh-in synced: %.1f kg" % weight


static func _last_body_fat() -> float:
	var list: Array = SaveData.data["weigh_ins"]
	if list.is_empty():
		return -1.0
	return float(list[list.size() - 1]["body_fat_pct"])


# ---------------------------------------------------------------- workouts

## Apple workout name -> how we log it.
static func map_workout(workout_name: String) -> Dictionary:
	var n := workout_name.to_lower()
	if "run" in n or "jog" in n:
		return {"kind": "cardio", "id": "run"}
	if "walk" in n or "hik" in n:
		return {"kind": "cardio", "id": "walk"}
	if "cycl" in n or "bik" in n:
		return {"kind": "cardio", "id": "bike"}
	if "swim" in n:
		return {"kind": "cardio", "id": "swim"}
	if "yoga" in n or "pilates" in n:
		return {"kind": "recovery", "id": "yoga"}
	if "stretch" in n or "flexib" in n or "cooldown" in n or "mind" in n:
		return {"kind": "recovery", "id": "stretching"}
	if "strength" in n or "crossfit" in n or "core" in n or "calisthen" in n:
		return {"kind": "strength", "id": "strength_session"}
	return {"kind": "cardio", "id": "other_cardio"}  # elliptical, rowing, HIIT, ...


static func _import_workouts(text: String, today: String) -> Array:
	var messages: Array = []
	var done: Array = SaveData.data["imported_ids"]
	for item in text.split("~", false):
		var fields := item.split("|")
		if fields.size() < 3:
			continue
		var workout_name := fields[0]
		var start := fields[1]
		var minutes := float(fields[2])
		var km := float(fields[3]) if fields.size() > 3 else 0.0
		var id := "%s@%s" % [workout_name, start]
		# Only today's workouts count, so they line up with today's quests.
		if id in done or minutes < 1.0 or start.substr(0, 10) != today:
			continue
		var how := map_workout(workout_name)
		match how["kind"]:
			"cardio":
				StatsManager.log_cardio(how["id"], minutes, km)
			"recovery":
				StatsManager.log_recovery(how["id"], minutes)
			"strength":
				StatsManager.log_strength_session(minutes)
		done.append(id)
		messages.append("Workout synced: %s %d min" % [workout_name, int(minutes)])
	while done.size() > MAX_REMEMBERED:
		done.pop_front()
	return messages
