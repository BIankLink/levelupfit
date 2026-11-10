extends RefCounted
## The Grand Quest: reach your goal weight. Progress runs from the weight you started at
## to the goal, with a milestone every few kg that rewards Vitality.
## (Uses the "goal weight" from Setup and your weigh-ins.)

const MILESTONE_POINTS := 50.0
const COMPLETE_POINTS := 200.0


static func _gq() -> Dictionary:
	return SaveData.data["grand_quest"]


static func goal_kg() -> float:
	return float(SaveData.data["profile"]["goal_target"])


static func has_goal() -> bool:
	return goal_kg() > 0.0


static func start_kg() -> float:
	return float(_gq()["start_kg"])


## Latest weigh-in weight, or -1.0 if there are none.
static func current_kg() -> float:
	var entries: Array = SaveData.data["weigh_ins"]
	if entries.is_empty():
		return -1.0
	return float(entries[entries.size() - 1]["weight_kg"])


static func is_active() -> bool:
	return has_goal() and start_kg() > 0.0 and current_kg() > 0.0 and total_kg() > 0.05


static func total_kg() -> float:
	return absf(start_kg() - goal_kg())


static func progress_kg() -> float:
	if goal_kg() < start_kg():
		return start_kg() - current_kg()  # losing weight
	return current_kg() - start_kg()      # gaining weight


static func ratio() -> float:
	return clampf(progress_kg() / total_kg(), 0.0, 1.0)


static func to_go_kg() -> float:
	return maxf(total_kg() - progress_kg(), 0.0)


## kg per milestone: about 5 milestones for short goals, every 5 kg for long ones.
static func step_kg() -> float:
	return clampf(total_kg() / 5.0, 1.0, 5.0)


static func milestone_total() -> int:
	return int(floor(total_kg() / step_kg() + 0.0001))


static func milestones_done() -> int:
	return int(_gq()["milestones"])


static func is_done() -> bool:
	return bool(_gq()["done"])


## Call after weigh-ins or the goal change. Returns messages for pop-ups.
static func sync() -> Array:
	var messages: Array = []
	var gq := _gq()

	# Goal changed in Setup: start a fresh Grand Quest from the current weight.
	if absf(goal_kg() - float(gq["goal_kg"])) > 0.001:
		gq["goal_kg"] = goal_kg()
		gq["start_kg"] = 0.0
		gq["milestones"] = 0
		gq["done"] = false
	if not has_goal():
		return messages

	if start_kg() <= 0.0:
		if current_kg() > 0.0:
			gq["start_kg"] = current_kg()
		return messages
	if not is_active():
		return messages

	var earned := mini(int(floor(progress_kg() / step_kg())), milestone_total())
	while int(gq["milestones"]) < earned:
		gq["milestones"] = int(gq["milestones"]) + 1
		StatsManager.add_points("vitality", MILESTONE_POINTS)
		messages.append("Grand Quest milestone %d / %d reached!" % [gq["milestones"], milestone_total()])
	if progress_kg() >= total_kg() and not is_done():
		gq["done"] = true
		StatsManager.add_points("vitality", COMPLETE_POINTS)
		messages.append("GRAND QUEST COMPLETE!")
	return messages
