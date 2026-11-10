extends Node
## Attach to a plain Node, set the scene as main, press F5.
## Builds today's quests for a chosen goal, then "does" each one to test completion.

const TEST_GOAL := "lose_fat"   # lose_fat | build_muscle | endurance | general | beginner
const TEST_EQUIPMENT := "gym"   # gym | home | none


func _ready() -> void:
	QuestManager.quest_completed.connect(func(q): print(">>> QUEST DONE: ", QuestManager.describe(q)))
	QuestManager.all_main_completed.connect(func(): print(">>> ALL MAIN QUESTS CLEARED! Streak: ", SaveData.data["streak"]))
	StatsManager.leveled_up.connect(func(stat, lvl): print(">>> LEVEL UP: %s is now level %d" % [stat, lvl]))

	SaveData.data["profile"]["goal"] = TEST_GOAL
	SaveData.data["profile"]["equipment"] = TEST_EQUIPMENT
	QuestManager.regenerate_today()

	print("--- Today's quests (%s, %s) ---" % [TEST_GOAL, TEST_EQUIPMENT])
	_print_quests()

	print("--- Doing the quests ---")
	for quest in QuestManager.get_quests().duplicate():
		_do_quest(quest)

	print("--- After ---")
	_print_quests()
	for id in StatsManager.STAT_IDS:
		print("%s  Lv %d  (%.0f%% to next)" % [id, StatsManager.get_level(id), StatsManager.get_progress(id) * 100.0])
	print("Streak: ", SaveData.data["streak"])


func _print_quests() -> void:
	for quest in QuestManager.get_quests():
		var tag := "[BONUS] " if quest["bonus"] else ""
		var done := " (done)" if quest["completed"] else ""
		print(tag, QuestManager.describe(quest), "  -> ", quest["stat"], done)


func _do_quest(quest: Dictionary) -> void:
	var exercise: String = quest["exercise"]
	var amount: int = int(quest["target"])
	if exercise == "steps":
		StatsManager.log_steps(amount)
		return
	match ExerciseLibrary.get_exercise(exercise)["category"]:
		"lift":
			StatsManager.log_lift(exercise, amount, 8, 40.0)
		"bodyweight":
			StatsManager.log_bodyweight(exercise, amount)
		"cardio":
			StatsManager.log_cardio(exercise, float(amount), 3.0)
