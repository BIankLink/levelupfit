extends Node
## Autoload name: SaveData
## Holds all app data in one Dictionary and saves it as JSON.
## On the web export, user:// is stored in the browser (IndexedDB).

signal data_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"setup_done": false,
			"height_cm": 170.0,
			"sex": "neutral",        # male | female | neutral
			"units": "kg",           # kg | lb
			"goal": "general",       # lose_fat | build_muscle | endurance | general | beginner
			"goal_target": 0.0,
			"equipment": "gym",      # gym | home | none
			"days_per_week": 4,
		},
		"stats": {
			"strength": {"value": 0.0},
			"endurance": {"value": 0.0},
			"agility": {"value": 0.0},
			"vitality": {"value": 0.0},
		},
		"streak": 0,
		"last_quest_date": "",
		"logs": [],        # every logged workout
		"weigh_ins": [],   # {date, weight_kg, body_fat_pct, muscle_pct?, lean_kg?}
		"targets": {},     # current quest target per exercise id (float, unrounded)
		"missed_days": 0,  # consecutive days with no main quest done
		"quests": {"date": "", "list": [], "all_clear": false},
		"imported_ids": [],  # Health workouts already imported (stops double counting)
		"weekly": {"week_start": 0, "rest_done": false},
		"grand_quest": {"goal_kg": 0.0, "start_kg": 0.0, "milestones": 0, "done": false},
	}


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = default_data()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = default_data()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = _restore_ints(parsed)
		_fill_missing(data, default_data())
		_drop_old_level_data()
	else:
		data = default_data()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	data_changed.emit()


func reset_data() -> void:
	data = default_data()
	save_data()


## JSON turns every number into a float. This turns whole numbers back into ints
## so levels, reps and streaks stay integers after loading.
func _restore_ints(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value:
			value[key] = _restore_ints(value[key])
		return value
	if value is Array:
		for i in value.size():
			value[i] = _restore_ints(value[i])
		return value
	if value is float and value == floorf(value) and absf(value) < 1.0e15:
		return int(value)
	return value


## Early versions stored "level" and "xp" per stat. Stats are now one number ("value").
func _drop_old_level_data() -> void:
	for id in data["stats"]:
		data["stats"][id].erase("level")
		data["stats"][id].erase("xp")


## Adds keys that exist in defaults but not in loaded data (keeps old saves working
## when new fields are added in later versions).
func _fill_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not target.has(key):
			target[key] = defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_fill_missing(target[key], defaults[key])


# --- Helpers used by other scripts ---

static func today_string() -> String:
	return Time.get_date_string_from_system()  # "YYYY-MM-DD"
