extends ScrollContainer
## Stats: a "status window" with rank, quest bars and the four stats, plus the avatar.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const AvatarMath = preload("res://scripts/avatar_math.gd")
const StatIcon = preload("res://scripts/ui/stat_icon.gd")

const GOAL_NAMES := {
	"lose_fat": "Lose fat",
	"build_muscle": "Build muscle",
	"endurance": "Endurance",
	"general": "General fitness",
	"beginner": "Beginner",
}
# Left column first, then right column (two stats per row).
const CELL_ORDER := ["strength", "vitality", "agility", "endurance"]

var _box: VBoxContainer
var _rank_big: Label
var _goal_value: Label
var _streak_value: Label
var _quest_bar: ProgressBar
var _quest_text: Label
var _bonus_bar: ProgressBar
var _bonus_text: Label
var _cells := {}  # stat id -> {"value", "rank", "bar", "next"}
var _avatar: Control
var _body_label: Label


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 16)
	add_child(_box)
	_box.add_child(_build_status_window())
	_box.add_child(_build_body_window())
	_box.add_child(_build_ladder_window())


# ---------------------------------------------------------------- building

func _title_box(text: String, width: float) -> Control:
	var frame := UIKit.make_outline_box(8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size = Vector2(width, 0)
	var title := UIKit.make_glow_label(text, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title)
	return frame


func _build_status_window() -> Control:
	var panel := UIKit.make_status_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	column.add_child(_title_box("STATUS", 300.0))

	# Rank (like the level number) with goal and streak lines beside it.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	column.add_child(head)
	var rank_column := VBoxContainer.new()
	head.add_child(rank_column)
	_rank_big = UIKit.make_glow_label("F", 84, UIKit.GLOW, false)
	_rank_big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rank_column.add_child(_rank_big)
	var rank_caption := UIKit.make_label("RANK", 20, UIKit.MUTED_BLUE, false)
	rank_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rank_column.add_child(rank_caption)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	head.add_child(info)
	_goal_value = _add_info_line(info, "GOAL")
	_streak_value = _add_info_line(info, "STREAK")

	# Bars box (like the HP / MP box).
	var bars_box := UIKit.make_outline_box(14)
	column.add_child(bars_box)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 12)
	bars_box.add_child(bars)
	var quest_row := _add_bar_row(bars, "QUESTS")
	_quest_bar = quest_row["bar"]
	_quest_text = quest_row["text"]
	var bonus_row := _add_bar_row(bars, "BONUS")
	_bonus_bar = bonus_row["bar"]
	_bonus_text = bonus_row["text"]

	# Stats box.
	var stats_box := UIKit.make_outline_box(16)
	column.add_child(stats_box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 22)
	stats_box.add_child(grid)
	for id in CELL_ORDER:
		grid.add_child(_build_cell(id))
	return panel


func _add_info_line(parent: Control, key: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var key_label := UIKit.make_label(key + ":", 18, UIKit.MUTED_BLUE, false)
	key_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(key_label)
	var value := UIKit.make_glow_label("", 24)
	row.add_child(value)
	return value


func _add_bar_row(parent: Control, title: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := UIKit.make_label(title, 20, UIKit.MUTED_BLUE, false)
	name_label.custom_minimum_size = Vector2(96, 0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(name_label)
	var bar := UIKit.make_thin_bar(0.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var text := UIKit.make_label("", 18, UIKit.GLOW, false)
	text.custom_minimum_size = Vector2(56, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(text)
	return {"bar": bar, "text": text}


func _build_cell(id: String) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	cell.add_child(top)
	var icon := StatIcon.new()
	icon.kind = id
	top.add_child(icon)
	top.add_child(UIKit.make_glow_label(StatsManager.STAT_SHORT[id] + ":", 24))

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 14)
	cell.add_child(middle)
	var value := UIKit.make_glow_label("0", 44, Color.WHITE, false)
	value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	middle.add_child(value)
	var rank := UIKit.make_glow_label("F", 44, UIKit.GLOW, false)
	rank.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	middle.add_child(rank)

	var bar := UIKit.make_thin_bar(0.0)
	cell.add_child(bar)
	var next := UIKit.make_label("", 16, UIKit.MUTED_BLUE)
	cell.add_child(next)

	_cells[id] = {"value": value, "rank": rank, "bar": bar, "next": next}
	return cell


func _build_body_window() -> Control:
	var panel := UIKit.make_status_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_title_box("BODY", 220.0))
	_avatar = AvatarView.new()
	_avatar.custom_minimum_size = Vector2(240, 400)
	_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_avatar.fill_color = Color("#0d2a4a")
	column.add_child(_avatar)
	_body_label = UIKit.make_glow_label("", 22)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_body_label)
	return panel


func _build_ladder_window() -> Control:
	var panel := UIKit.make_status_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_title_box("RANKS", 220.0))
	var parts: Array = []
	for i in StatsManager.RANK_NAMES.size():
		parts.append("%s  %d+" % [StatsManager.RANK_NAMES[i], StatsManager.RANK_MIN[i]])
	var text := UIKit.make_label("    ".join(parts), 20, UIKit.MUTED_BLUE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(text)
	return panel


# ---------------------------------------------------------------- updating

func refresh() -> void:
	var overall := StatsManager.overall_rank()
	_rank_big.text = overall
	_rank_big.add_theme_color_override("font_color", UIKit.rank_color(overall))

	var goal: String = SaveData.data["profile"]["goal"]
	_goal_value.text = GOAL_NAMES.get(goal, goal)
	_streak_value.text = "%d days" % SaveData.data["streak"]

	var main_done := 0
	var main_total := 0
	var bonus_done := 0
	var bonus_total := 0
	for quest in QuestManager.get_quests():
		if quest["bonus"]:
			bonus_total += 1
			if quest["completed"]:
				bonus_done += 1
		else:
			main_total += 1
			if quest["completed"]:
				main_done += 1
	_quest_bar.value = float(main_done) / maxf(main_total, 1)
	_quest_text.text = "%d/%d" % [main_done, main_total]
	_bonus_bar.value = float(bonus_done) / maxf(bonus_total, 1)
	_bonus_text.text = "%d/%d" % [bonus_done, bonus_total]

	for id in StatsManager.STAT_IDS:
		var rank := StatsManager.get_rank(id)
		var color := UIKit.rank_color(rank)
		var cell: Dictionary = _cells[id]
		cell["value"].text = "%d" % int(StatsManager.get_value(id))
		cell["rank"].text = rank
		cell["rank"].add_theme_color_override("font_color", color)
		cell["bar"].value = StatsManager.rank_progress(id)
		UIKit.set_bar_color(cell["bar"], color)
		if StatsManager.is_max_rank(id):
			cell["next"].text = "MAX RANK"
		else:
			cell["next"].text = "%d / %d to %s" % [
				int(StatsManager.get_value(id)),
				int(StatsManager.next_rank_min(id)),
				StatsManager.next_rank_name(id),
			]

	# Avatar
	var avatar_data := AvatarMath.compute()
	_avatar.outline_color = UIKit.PANEL_LINE
	_avatar.set_state(avatar_data["sex"], avatar_data["fat"], avatar_data["muscle"])
	var latest := AvatarMath.latest_weigh_in()
	if latest.is_empty():
		_body_label.text = "Add your weight and body fat in Setup to shape your avatar."
	else:
		_body_label.text = "%.1f kg   |   %.1f%% body fat" % [float(latest["weight_kg"]), float(latest["body_fat_pct"])]
