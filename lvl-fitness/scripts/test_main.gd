extends Node
## Attach this to a plain Node in a new scene, set it as the main scene, press F5.
## It logs a few workouts and prints the results to the Output panel.

func _ready() -> void:
	StatsManager.leveled_up.connect(func(stat, lvl): print(">>> LEVEL UP: %s is now level %d" % [stat, lvl]))

	print("Exercises (gym user, lifts): ", ExerciseLibrary.list_available("lift", "gym"))

	print("Bench press 3x8 @ 60kg: ", StatsManager.log_lift("bench_press", 3, 8, 60.0))
	print("Push-ups x30: ", StatsManager.log_bodyweight("pushup", 30))
	print("Run 25 min, 4 km: ", StatsManager.log_cardio("run", 25.0, 4.0))
	print("Steps 8000: ", StatsManager.log_steps(8000))
	print("Weigh-in: ", StatsManager.log_weigh_in(126.5, 37.4))

	for id in StatsManager.STAT_IDS:
		print("%s  Lv %d  (%.0f%% to next)" % [id, StatsManager.get_level(id), StatsManager.get_progress(id) * 100.0])
	print("Overall level: ", StatsManager.overall_level())
	print("Saved to: ", ProjectSettings.globalize_path(SaveData.SAVE_PATH))
