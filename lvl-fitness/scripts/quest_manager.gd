extends Node
## Autoload name: QuestManager  (add AFTER SaveData and StatsManager)
##
## Builds 3 main quests + 1 bonus quest per day from the user's goal and equipment,
## tracks progress from logged workouts, and scales targets up or down over time.

signal quests_changed
signal quest_completed(quest: Dictionary)
signal all_main_completed

const GrandQuest = preload("res://scripts/grand_quest.gd")
const WeeklyQuests = preload("res://scripts/weekly_quests.gd")

const MAIN_QUEST_COUNT := 3
const QUEST_COMPLETE_XP := 20.0
const BONUS_COMPLETE_XP := 35.0
const ALL_CLEAR_BASE_XP := 15.0      # vitality XP, plus 2 per streak day (max 10 days counted)
const BONUS_TARGET_FACTOR := 0.75    # bonus quests are a little shorter
const RAISE_RATE := 1.08             # target +8% after a completed quest
const RAISE_RATE_BEGINNER := 1.05    # slower ramp for the beginner goal
const MISSED_DAYS_LIMIT := 3         # this many empty days in a row lowers targets
const DROP_FACTOR := 0.9
const BEGINNER_FACTOR := 0.6         # beginner starting targets are 60% of normal

# How likely each quest "slot" is for each goal (brief, section 6).
const SLOT_WEIGHTS := {
	"lose_fat": {"cardio": 0.4, "steps": 0.3, "strength": 0.3},
	"build_muscle": {"strength": 0.6, "cardio": 0.2, "steps": 0.2},
	"endurance": {"cardio": 0.6, "steps": 0.2, "strength": 0.2},
	"general": {"strength": 1.0, "cardio": 1.0, "steps": 1.0},
	"beginner": {"cardio": 0.4, "strength": 0.4, "steps": 0.2},
}

const BEGINNER_BODYWEIGHT := ["pushup", "bodyweight_squat", "situp"]

# exercise id: [starting target, minimum, maximum]
# Units: lifts = sets, bodyweight = reps, cardio = minutes, steps = steps.
const TARGETS := {
	"bench_press": [3, 2, 6], "squat": [3, 2, 6], "deadlift": [3, 2, 5],
	"overhead_press": [3, 2, 6], "barbell_row": [3, 2, 6], "lat_pulldown": [3, 2, 6],
	"dumbbell_curl": [3, 2, 6],
	"pushup": [20, 5, 100], "bodyweight_squat": [30, 10, 150], "situp": [20, 5, 100],
	"pullup": [5, 1, 30], "lunge": [20, 6, 80], "burpee": [10, 3, 50],
	"run": [20, 10, 90], "walk": [30, 10, 90], "bike": [25, 10, 90], "swim": [15, 5, 60],
	"steps": [7000, 2000, 20000],
}


func _ready() -> void:
	StatsManager.workout_logged.connect(_on_workout_logged)
	StatsManager.weigh_in_logged.connect(_on_weigh_in_logged)
	refresh_for_today()


# ---------------------------------------------------------------- public API

func get_quests() -> Array:
	return SaveData.data["quests"]["list"]


## Call when the app opens or resumes. Creates today's quests if they don't exist
## yet, and handles the previous day (target scaling, streak, missed days).
func refresh_for_today() -> void:
	var today: String = SaveData.today_string()
	var q: Dictionary = SaveData.data["quests"]
	if q["date"] == today and not q["list"].is_empty():
		return
	if q["date"] != "":
		_close_previous_day(q["date"], today)
	q["date"] = today
	q["all_clear"] = false
	q["list"] = _generate_quests(today)
	SaveData.save_data()
	quests_changed.emit()


## Throws away today's quests and builds new ones (useful for testing, or if the
## user changes their goal or equipment mid-day).
func regenerate_today() -> void:
	var today: String = SaveData.today_string()
	var q: Dictionary = SaveData.data["quests"]
	q["date"] = today
	q["all_clear"] = false
	q["list"] = _generate_quests(today)
	SaveData.save_data()
	quests_changed.emit()


## Name shown on a quest card, e.g. "Push-ups" or "Steps".
func title_for(quest: Dictionary) -> String:
	if quest["exercise"] == "steps":
		return "Steps"
	return ExerciseLibrary.get_exercise(quest["exercise"]).get("name", quest["exercise"])


## Short text for the UI, e.g. "Push-ups: 12 / 20 reps".
func describe(quest: Dictionary) -> String:
	return "%s: %d / %d %s" % [title_for(quest), int(quest["progress"]), int(quest["target"]), quest["unit"]]


## Updates Grand Quest progress and milestones, and sends pop-up messages.
func sync_grand_quest() -> void:
	for message in GrandQuest.sync():
		StatsManager.notice.emit(message)
	SaveData.save_data()


func _on_weigh_in_logged(entry: Dictionary) -> void:
	var message := WeeklyQuests.on_weigh_in(entry)
	if message != "":
		StatsManager.notice.emit(message)
	sync_grand_quest()
	quests_changed.emit()


# ---------------------------------------------------------------- generation

func _generate_quests(date: String) -> Array:
	var goal: String = SaveData.data["profile"]["goal"]
	var equipment: String = SaveData.data["profile"]["equipment"]
	var quests: Array = []
	var used: Array = []

	for slot in _pick_slots(goal, equipment):
		var exercise := _pick_exercise(slot, used, goal, equipment)
		used.append(exercise)
		quests.append(_make_quest(exercise, _stat_for(exercise), false, quests.size(), date))

	# Bonus quest comes from the weakest stat.
	var bonus_stat := _weakest_stat()
	var bonus_exercise := _pick_bonus_exercise(bonus_stat, used, goal, equipment)
	quests.append(_make_quest(bonus_exercise, bonus_stat, true, quests.size(), date))
	return quests


func _pick_slots(goal: String, equipment: String) -> Array:
	if goal == "general":
		return ["strength", "cardio", "steps"]  # one of each, evenly
	var weights: Dictionary = SLOT_WEIGHTS.get(goal, SLOT_WEIGHTS["general"])
	var slots: Array = []
	var counts := {}
	while slots.size() < MAIN_QUEST_COUNT:
		# A slot can't repeat more often than it has different exercises available.
		var open := {}
		for slot in weights:
			if counts.get(slot, 0) < _pool_for(slot, goal, equipment).size():
				open[slot] = weights[slot]
		if open.is_empty():
			break
		var pick := _weighted_pick(open)
		slots.append(pick)
		counts[pick] = counts.get(pick, 0) + 1
	return slots


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll := randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys()[0]


func _pool_for(slot: String, goal: String, equipment: String) -> Array:
	match slot:
		"steps":
			return ["steps"]
		"cardio":
			if goal == "beginner":
				return ["walk"]
			return ExerciseLibrary.list_available("cardio", equipment)
		"strength":
			var bodyweight: Array = ExerciseLibrary.list_available("bodyweight", equipment)
			if goal == "beginner":
				return bodyweight.filter(func(e): return e in BEGINNER_BODYWEIGHT)
			return ExerciseLibrary.list_available("lift", equipment) + bodyweight
	return []


func _pick_exercise(slot: String, used: Array, goal: String, equipment: String) -> String:
	var pool := _pool_for(slot, goal, equipment)
	var fresh: Array = pool.filter(func(e): return e not in used)
	if slot == "strength":
		var lifts: Array = fresh.filter(func(e): return ExerciseLibrary.get_exercise(e)["category"] == "lift")
		var bodyweights: Array = fresh.filter(func(e): return ExerciseLibrary.get_exercise(e)["category"] == "bodyweight")
		var lift_chance := 0.7 if goal == "build_muscle" else 0.5
		if not lifts.is_empty() and (bodyweights.is_empty() or randf() < lift_chance):
			return lifts.pick_random()
		return bodyweights.pick_random()
	return fresh.pick_random()


func _pick_bonus_exercise(stat: String, used: Array, goal: String, equipment: String) -> String:
	var pool: Array = []
	match stat:
		"strength":
			pool = _pool_for("strength", goal, equipment)
		"endurance":
			pool = _pool_for("cardio", goal, equipment)
		"agility":
			pool = ["steps"] if goal == "beginner" else ["steps", "burpee"]
		"vitality":
			pool = ["walk"]  # extra easy movement
	var fresh: Array = pool.filter(func(e): return e not in used)
	if fresh.is_empty():
		fresh = pool
	return fresh.pick_random()


func _weakest_stat() -> String:
	var ids: Array = StatsManager.STAT_IDS.duplicate()
	ids.shuffle()  # random tie-break
	var weakest: String = ids[0]
	var lowest := INF
	for id in ids:
		var score := StatsManager.get_value(id)
		if score < lowest:
			lowest = score
			weakest = id
	return weakest


func _make_quest(exercise: String, stat: String, is_bonus: bool, index: int, date: String) -> Dictionary:
	var target := _get_target(exercise)
	if is_bonus:
		target *= BONUS_TARGET_FACTOR
	return {
		"id": "%s_%d" % [date, index],
		"exercise": exercise,
		"stat": stat,
		"unit": _unit_for(exercise),
		"target": _round_target(exercise, target),
		"progress": 0,
		"completed": false,
		"bonus": is_bonus,
	}


func _stat_for(exercise: String) -> String:
	if exercise == "steps":
		return "agility"
	if ExerciseLibrary.get_exercise(exercise)["category"] == "cardio":
		return "endurance"
	return "strength"


func _unit_for(exercise: String) -> String:
	if exercise == "steps":
		return "steps"
	match ExerciseLibrary.get_exercise(exercise)["category"]:
		"lift":
			return "sets"
		"cardio":
			return "min"
	return "reps"


# ---------------------------------------------------------------- targets

## Targets are stored as unrounded floats so small changes (e.g. +8% of 3 sets)
## can build up over several days. They are rounded when a quest is made.
func _get_target(exercise: String) -> float:
	var targets: Dictionary = SaveData.data["targets"]
	if not targets.has(exercise):
		var goal: String = SaveData.data["profile"]["goal"]
		var value := float(TARGETS[exercise][0])
		if goal == "beginner":
			value *= BEGINNER_FACTOR
		if exercise == "steps" and goal == "lose_fat":
			value = 8000.0
		targets[exercise] = _clamp_target(exercise, value)
	return float(targets[exercise])


func _clamp_target(exercise: String, value: float) -> float:
	var info: Array = TARGETS[exercise]
	return clampf(value, float(info[1]), float(info[2]))


func _round_target(exercise: String, value: float) -> int:
	value = _clamp_target(exercise, value)
	if exercise == "steps":
		return int(roundf(value / 100.0)) * 100
	return int(roundf(value))


func _scale_target(exercise: String, factor: float) -> void:
	SaveData.data["targets"][exercise] = _clamp_target(exercise, _get_target(exercise) * factor)


# ---------------------------------------------------------------- day rollover

func _close_previous_day(prev_date: String, today: String) -> void:
	var q: Dictionary = SaveData.data["quests"]
	var goal: String = SaveData.data["profile"]["goal"]
	var rate := RAISE_RATE_BEGINNER if goal == "beginner" else RAISE_RATE
	var main_done := 0
	var main_total := 0

	for quest in q["list"]:
		if quest["bonus"]:
			continue
		main_total += 1
		if quest["completed"]:
			main_done += 1
			_scale_target(quest["exercise"], rate)  # finished it, so make it a bit harder

	var gap := _days_between(prev_date, today)

	# Streak: breaks if yesterday wasn't fully cleared, or if days were skipped.
	if gap > 1 or main_total == 0 or main_done < main_total:
		SaveData.data["streak"] = 0

	# Missed days: after several empty days in a row, ease every target down.
	var missed: int = SaveData.data["missed_days"]
	if main_done == 0:
		missed += 1
	else:
		missed = 0
	if gap > 1:
		missed += gap - 1
	if missed >= MISSED_DAYS_LIMIT:
		for exercise in SaveData.data["targets"].keys():
			if TARGETS.has(exercise):
				_scale_target(exercise, DROP_FACTOR)
		missed = 0
	SaveData.data["missed_days"] = missed


func _days_between(from_date: String, to_date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(from_date)
	var b := Time.get_unix_time_from_datetime_string(to_date)
	return int(roundf((b - a) / 86400.0))


# ---------------------------------------------------------------- progress

func _on_workout_logged(entry: Dictionary) -> void:
	refresh_for_today()  # in case the app stayed open past midnight
	var weekly_message := WeeklyQuests.on_workout(entry)
	if weekly_message != "":
		StatsManager.notice.emit(weekly_message)

	var exercise := ""
	var amount := 0.0
	match entry["type"]:
		"lift":
			exercise = entry["exercise"]
			amount = entry["sets"]
		"bodyweight":
			exercise = entry["exercise"]
			amount = entry["reps"]
		"cardio":
			exercise = entry["exercise"]
			amount = entry["minutes"]
		"steps":
			exercise = "steps"
			amount = entry["steps"]
		_:
			SaveData.save_data()
			quests_changed.emit()
			return

	for quest in get_quests():
		if quest["completed"] or quest["exercise"] != exercise:
			continue
		quest["progress"] += amount
		if quest["progress"] >= quest["target"]:
			_complete_quest(quest)

	_check_all_clear()
	SaveData.save_data()
	quests_changed.emit()


func _complete_quest(quest: Dictionary) -> void:
	quest["completed"] = true
	var xp := BONUS_COMPLETE_XP if quest["bonus"] else QUEST_COMPLETE_XP
	StatsManager.add_points(quest["stat"], xp)
	quest_completed.emit(quest)


func _check_all_clear() -> void:
	var q: Dictionary = SaveData.data["quests"]
	if q["all_clear"]:
		return
	for quest in q["list"]:
		if not quest["bonus"] and not quest["completed"]:
			return
	q["all_clear"] = true
	SaveData.data["streak"] += 1
	StatsManager.add_points("vitality", ALL_CLEAR_BASE_XP + 2.0 * min(SaveData.data["streak"], 10))
	all_main_completed.emit()
