extends ScrollContainer
## Home: today's quests, streak and overall rank.

signal log_requested(mode: int)  # asks the app to open the Log tab on a given type

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const WeeklyQuests = preload("res://scripts/weekly_quests.gd")
const GrandQuest = preload("res://scripts/grand_quest.gd")

var _box: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)


func refresh() -> void:
	UIKit.clear(_box)
	var main_quests: Array = []
	var bonus_quests: Array = []
	for quest in QuestManager.get_quests():
		if quest["bonus"]:
			bonus_quests.append(quest)
		else:
			main_quests.append(quest)

	_box.add_child(_header())

	var done := 0
	for quest in main_quests:
		if quest["completed"]:
			done += 1
	_box.add_child(UIKit.make_label("Daily Quests   %d / %d" % [done, main_quests.size()], 28))
	for quest in main_quests:
		_box.add_child(_quest_card(quest))

	if not bonus_quests.is_empty():
		_box.add_child(UIKit.make_label("Bonus Quest", 28, UIKit.rank_color("B")))
		for quest in bonus_quests:
			_box.add_child(_quest_card(quest))

	_box.add_child(_weekly_section())
	_box.add_child(_grand_quest_card())

	_box.add_child(UIKit.make_label("Log a workout in the Log tab and quests fill automatically.", 18, UIKit.MUTED))


func _header() -> Control:
	var card := UIKit.make_card()
	var row := HBoxContainer.new()
	card.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UIKit.make_label("Today", 34))
	left.add_child(UIKit.make_label(SaveData.today_string(), 20, UIKit.MUTED))
	left.add_child(UIKit.make_label("Streak: %d days" % SaveData.data["streak"], 22, UIKit.GOOD))

	var right := VBoxContainer.new()
	row.add_child(right)
	var rank := StatsManager.overall_rank()
	var big := UIKit.make_label(rank, 68, UIKit.rank_color(rank), false)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(big)
	var caption := UIKit.make_label("Overall", 18, UIKit.MUTED, false)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(caption)
	return card


func _quest_card(quest: Dictionary) -> Control:
	var done: bool = quest["completed"]
	var card := UIKit.make_card(UIKit.CARD_DONE if done else UIKit.CARD)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(UIKit.make_label(QuestManager.title_for(quest), 26))
	top.add_child(UIKit.make_label(StatsManager.STAT_SHORT[quest["stat"]], 20, UIKit.MUTED, false))

	var target := maxf(float(quest["target"]), 1.0)
	var ratio := float(quest["progress"]) / target
	column.add_child(UIKit.make_progress(ratio, UIKit.GOOD if done else UIKit.ACCENT))

	var text := "%d / %d %s" % [int(quest["progress"]), int(quest["target"]), quest["unit"]]
	if done:
		text += "   Complete"
	column.add_child(UIKit.make_label(text, 20, UIKit.GOOD if done else UIKit.MUTED))
	return card


func _grand_quest_card() -> Control:
	var panel := UIKit.make_status_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UIKit.make_glow_label("GRAND QUEST", 24))

	if not GrandQuest.has_goal():
		column.add_child(UIKit.make_label("Set a goal weight in Setup to start your Grand Quest.", 20, UIKit.MUTED_BLUE))
		return panel
	column.add_child(UIKit.make_glow_label("Reach %.1f kg" % GrandQuest.goal_kg(), 30, Color.WHITE))
	if not GrandQuest.is_active():
		column.add_child(UIKit.make_label("Log a weigh-in to begin. Your first weigh-in is the starting point.", 20, UIKit.MUTED_BLUE))
		return panel

	column.add_child(UIKit.make_thin_bar(GrandQuest.ratio(), UIKit.rank_color("B")))
	column.add_child(UIKit.make_label("%.1f kg now   |   %.1f kg to go" % [GrandQuest.current_kg(), GrandQuest.to_go_kg()], 20, UIKit.GLOW))
	var status := "Milestones %d / %d  (every %.1f kg)" % [GrandQuest.milestones_done(), GrandQuest.milestone_total(), GrandQuest.step_kg()]
	if GrandQuest.is_done():
		status = "COMPLETE!  " + status
	column.add_child(UIKit.make_label(status, 18, UIKit.MUTED_BLUE))
	return panel


func _weekly_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	section.add_child(UIKit.make_label("Weekly", 28, UIKit.ACCENT))
	section.add_child(_weigh_in_card())
	section.add_child(_rest_card())
	return section


func _weigh_in_card() -> Control:
	var due := WeeklyQuests.weigh_in_due()
	var card := UIKit.make_card(Color("#233066") if due else UIKit.CARD)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(UIKit.make_label("Weekly weigh-in", 26))
	top.add_child(UIKit.make_label("VIT", 20, UIKit.MUTED, false))

	var days := WeeklyQuests.days_since_weigh_in()
	var text := ""
	if days < 0:
		text = "Log your first weigh-in to shape your avatar."
	elif due:
		text = "Due now. Last weigh-in was %d days ago." % days
	else:
		text = "Next in %d days" % WeeklyQuests.days_until_weigh_in()
	column.add_child(UIKit.make_progress(clampf(float(maxi(days, 0)) / WeeklyQuests.WEIGH_IN_EVERY_DAYS, 0.0, 1.0), UIKit.ACCENT))
	column.add_child(UIKit.make_label(text, 20, UIKit.GLOW if due else UIKit.MUTED))

	if due:
		var button := UIKit.make_button("Weigh in now")
		button.pressed.connect(func(): log_requested.emit(4))
		column.add_child(button)
	return card


func _rest_card() -> Control:
	var done := WeeklyQuests.rest_done()
	var card := UIKit.make_card(UIKit.CARD_DONE if done else UIKit.CARD)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(UIKit.make_label("Rest quest (optional)", 26))
	top.add_child(UIKit.make_label("VIT", 20, UIKit.MUTED, false))

	column.add_child(UIKit.make_progress(1.0 if done else 0.0, UIKit.GOOD))
	var text := "10 min of stretching or yoga, or a 15 min walk. Once a week."
	if done:
		text = "Complete this week. Nice recovery."
	column.add_child(UIKit.make_label(text, 20, UIKit.GOOD if done else UIKit.MUTED))

	if not done:
		var button := UIKit.make_button("Log recovery")
		button.pressed.connect(func(): log_requested.emit(5))
		column.add_child(button)
	return card
