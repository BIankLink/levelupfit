extends Node
## Autoload name: ExerciseLibrary
## Maps every exercise to a category, equipment need and the stats it feeds.

# category: "lift" | "bodyweight" | "cardio" | "recovery" | "imported"
# equipment: "gym" | "home" | "none"
const EXERCISES := {
	# --- Gym lifts ---
	"bench_press": {"name": "Bench Press", "category": "lift", "equipment": "gym"},
	"squat": {"name": "Barbell Squat", "category": "lift", "equipment": "gym"},
	"deadlift": {"name": "Deadlift", "category": "lift", "equipment": "gym"},
	"overhead_press": {"name": "Overhead Press", "category": "lift", "equipment": "gym"},
	"barbell_row": {"name": "Barbell Row", "category": "lift", "equipment": "gym"},
	"lat_pulldown": {"name": "Lat Pulldown", "category": "lift", "equipment": "gym"},
	"dumbbell_curl": {"name": "Dumbbell Curl", "category": "lift", "equipment": "home"},
	# --- Bodyweight ---
	"pushup": {"name": "Push-ups", "category": "bodyweight", "equipment": "none"},
	"bodyweight_squat": {"name": "Squats", "category": "bodyweight", "equipment": "none"},
	"situp": {"name": "Sit-ups", "category": "bodyweight", "equipment": "none"},
	"pullup": {"name": "Pull-ups", "category": "bodyweight", "equipment": "home"},
	"lunge": {"name": "Lunges", "category": "bodyweight", "equipment": "none"},
	"burpee": {"name": "Burpees", "category": "bodyweight", "equipment": "none"},
	# --- Cardio ---
	"run": {"name": "Run", "category": "cardio", "equipment": "none"},
	"walk": {"name": "Walk", "category": "cardio", "equipment": "none"},
	"bike": {"name": "Cycling", "category": "cardio", "equipment": "none"},
	"swim": {"name": "Swimming", "category": "cardio", "equipment": "none"},
	# --- Imported from Apple Health (never used for daily quests) ---
	"other_cardio": {"name": "Other cardio", "category": "imported", "equipment": "none"},
	"strength_session": {"name": "Strength session", "category": "imported", "equipment": "none"},
	# --- Recovery (used by the weekly rest quest, never by daily quests) ---
	"stretching": {"name": "Stretching", "category": "recovery", "equipment": "none"},
	"yoga": {"name": "Yoga", "category": "recovery", "equipment": "none"},
	"foam_rolling": {"name": "Foam rolling", "category": "recovery", "equipment": "none"},
}


func get_exercise(id: String) -> Dictionary:
	return EXERCISES.get(id, {})


func list_by_category(category: String) -> Array:
	var result: Array = []
	for id in EXERCISES:
		if EXERCISES[id]["category"] == category:
			result.append(id)
	return result


## Equipment levels are nested: "gym" can do everything, "home" can do home + none.
func list_available(category: String, user_equipment: String) -> Array:
	var allowed := {"gym": ["gym", "home", "none"], "home": ["home", "none"], "none": ["none"]}
	var ok: Array = allowed.get(user_equipment, ["none"])
	var result: Array = []
	for id in list_by_category(category):
		if EXERCISES[id]["equipment"] in ok:
			result.append(id)
	return result
