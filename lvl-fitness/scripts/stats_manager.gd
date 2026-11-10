extends Node
## Autoload name: StatsManager
## Each stat is a plain number. The number falls into a rank band, from F up to SSS.

signal rank_up(stat_id: String, new_rank: String)
signal points_gained(stat_id: String, amount: float)
signal workout_logged(entry: Dictionary)
signal weigh_in_logged(entry: Dictionary)
signal notice(text: String)  # short messages for pop-ups

const STAT_IDS := ["strength", "endurance", "agility", "vitality"]
const STAT_NAMES := {"strength": "Strength", "endurance": "Endurance", "agility": "Agility", "vitality": "Vitality"}
const STAT_SHORT := {"strength": "STR", "endurance": "END", "agility": "AGI", "vitality": "VIT"}

# RANK_MIN[i] is the stat number needed to reach RANK_NAMES[i].
# F is 0-199, E is 200-499, D is 500-999 ... SSS is 10000 and up. Tune freely.
const RANK_NAMES := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_MIN := [0, 200, 500, 1000, 1800, 3000, 4800, 7200, 10000]

# Stats that get a bonus for each goal (see brief, section 6).
const GOAL_FAVORED := {
	"lose_fat": ["endurance", "agility", "vitality"],
	"build_muscle": ["strength"],
	"endurance": ["endurance", "agility"],
	"general": ["strength", "endurance", "agility", "vitality"],
	"beginner": ["vitality", "agility"],
}
const GOAL_BONUS := 1.25


# ---------------------------------------------------------------- reading stats

func get_value(stat_id: String) -> float:
	return float(SaveData.data["stats"][stat_id]["value"])


func rank_index_for(value: float) -> int:
	var index := 0
	for i in RANK_MIN.size():
		if value >= RANK_MIN[i]:
			index = i
	return index


func get_rank(stat_id: String) -> String:
	return RANK_NAMES[rank_index_for(get_value(stat_id))]


func is_max_rank(stat_id: String) -> bool:
	return rank_index_for(get_value(stat_id)) >= RANK_NAMES.size() - 1


## Letter of the next rank, or "" if already at the top.
func next_rank_name(stat_id: String) -> String:
	if is_max_rank(stat_id):
		return ""
	return RANK_NAMES[rank_index_for(get_value(stat_id)) + 1]


## Stat number needed for the next rank, or -1 if already at the top.
func next_rank_min(stat_id: String) -> float:
	if is_max_rank(stat_id):
		return -1.0
	return float(RANK_MIN[rank_index_for(get_value(stat_id)) + 1])


func points_to_next(stat_id: String) -> float:
	if is_max_rank(stat_id):
		return 0.0
	return next_rank_min(stat_id) - get_value(stat_id)


## 0.0 to 1.0 progress through the current rank band (for progress bars).
func rank_progress(stat_id: String) -> float:
	if is_max_rank(stat_id):
		return 1.0
	var value := get_value(stat_id)
	var index := rank_index_for(value)
	var low := float(RANK_MIN[index])
	var high := float(RANK_MIN[index + 1])
	return (value - low) / (high - low)


func overall_value() -> float:
	var total := 0.0
	for id in STAT_IDS:
		total += get_value(id)
	return total / STAT_IDS.size()


func overall_rank() -> String:
	return RANK_NAMES[rank_index_for(overall_value())]


# ---------------------------------------------------------------- adding points

func goal_multiplier(stat_id: String) -> float:
	var goal: String = SaveData.data["profile"]["goal"]
	if goal == "general":
		return 1.0  # everything favored equally, so no extra bonus
	if stat_id in GOAL_FAVORED.get(goal, []):
		return GOAL_BONUS
	return 1.0


func add_points(stat_id: String, base_amount: float) -> float:
	var amount := base_amount * goal_multiplier(stat_id)
	var rank_before := rank_index_for(get_value(stat_id))
	SaveData.data["stats"][stat_id]["value"] = get_value(stat_id) + amount
	var rank_after := rank_index_for(get_value(stat_id))
	points_gained.emit(stat_id, amount)
	if rank_after > rank_before:
		rank_up.emit(stat_id, RANK_NAMES[rank_after])
	return amount


# --- Logging. Each returns {stat_id: points_awarded} so the UI can show "STR +12". ---

func log_lift(exercise_id: String, sets: int, reps: int, weight_kg: float) -> Dictionary:
	var points := sets * reps * weight_kg / 100.0
	var gained := {"strength": add_points("strength", points)}
	_store_log({"type": "lift", "exercise": exercise_id, "sets": sets, "reps": reps, "weight_kg": weight_kg})
	return gained


func log_bodyweight(exercise_id: String, reps: int, fast_paced := false) -> Dictionary:
	var gained := {"strength": add_points("strength", reps * 0.5)}
	if fast_paced:
		gained["agility"] = add_points("agility", reps * 0.25)
	_store_log({"type": "bodyweight", "exercise": exercise_id, "reps": reps})
	return gained


func log_cardio(exercise_id: String, minutes: float, distance_km := 0.0) -> Dictionary:
	var points := minutes * 2.0 + distance_km * 5.0
	var gained := {"endurance": add_points("endurance", points)}
	_store_log({"type": "cardio", "exercise": exercise_id, "minutes": minutes, "distance_km": distance_km})
	return gained


## A gym session imported from Health: only the length is known (no sets or reps).
func log_strength_session(minutes: float) -> Dictionary:
	var gained := {"strength": add_points("strength", minutes * 1.2)}
	_store_log({"type": "strength_session", "exercise": "strength_session", "minutes": minutes})
	return gained


func log_recovery(exercise_id: String, minutes: float) -> Dictionary:
	var gained := {"vitality": add_points("vitality", minutes * 1.0)}
	_store_log({"type": "recovery", "exercise": exercise_id, "minutes": minutes})
	return gained


func log_steps(steps: int) -> Dictionary:
	var gained := {"agility": add_points("agility", steps / 200.0)}
	_store_log({"type": "steps", "steps": steps})
	return gained


func log_weigh_in(weight_kg: float, body_fat_pct: float, muscle_pct := -1.0, lean_kg := -1.0) -> Dictionary:
	var entry := {"date": SaveData.today_string(), "weight_kg": weight_kg, "body_fat_pct": body_fat_pct}
	if muscle_pct >= 0.0:
		entry["muscle_pct"] = muscle_pct
	if lean_kg >= 0.0:
		entry["lean_kg"] = lean_kg
	SaveData.data["weigh_ins"].append(entry)
	var gained := {"vitality": add_points("vitality", 25.0)}
	SaveData.save_data()
	weigh_in_logged.emit(entry)
	return gained


func _store_log(entry: Dictionary) -> void:
	entry["date"] = SaveData.today_string()
	entry["time"] = Time.get_time_string_from_system()
	SaveData.data["logs"].append(entry)
	SaveData.save_data()
	workout_logged.emit(entry)
