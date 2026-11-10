extends ScrollContainer
## Setup: goal, equipment and profile. Also the first screen shown on a fresh install.

signal saved(message: String)

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const GOALS := [
	["lose_fat", "Lose fat"],
	["build_muscle", "Build muscle"],
	["endurance", "Improve endurance"],
	["general", "General fitness"],
	["beginner", "Get active (beginner)"],
]
const SEX := [
	["male", "Male"],
	["female", "Female"],
	["neutral", "Neutral"],
]
const EQUIPMENT := [
	["gym", "Full gym"],
	["home", "Home (some equipment)"],
	["none", "No equipment"],
]

var _box: VBoxContainer
var _intro: Label
var _goal_option: OptionButton
var _equipment_option: OptionButton
var _sex_option: OptionButton
var _start_box: VBoxContainer
var _start_weight: SpinBox
var _start_fat: SpinBox
var _height: SpinBox
var _days: SpinBox
var _target: SpinBox
var _reset_button: Button
var _reset_armed := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)

	_box.add_child(UIKit.make_label("Setup", 34))
	_intro = UIKit.make_label("Welcome! Pick your goal and equipment so your daily quests fit you.", 22, UIKit.GOOD)
	_box.add_child(_intro)

	var card := UIKit.make_card()
	_box.add_child(card)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	card.add_child(form)

	form.add_child(UIKit.make_label("Goal", 20, UIKit.MUTED))
	_goal_option = _make_option(GOALS)
	form.add_child(_goal_option)

	form.add_child(UIKit.make_label("Equipment", 20, UIKit.MUTED))
	_equipment_option = _make_option(EQUIPMENT)
	form.add_child(_equipment_option)

	form.add_child(UIKit.make_label("Avatar silhouette", 20, UIKit.MUTED))
	_sex_option = _make_option(SEX)
	form.add_child(_sex_option)

	form.add_child(UIKit.make_label("Height", 20, UIKit.MUTED))
	_height = _make_spin(100, 250, 1, " cm")
	form.add_child(_height)

	form.add_child(UIKit.make_label("Days per week you can train", 20, UIKit.MUTED))
	_days = _make_spin(1, 7, 1, "")
	form.add_child(_days)

	form.add_child(UIKit.make_label("Grand Quest goal weight (0 = none)", 20, UIKit.MUTED))
	_target = _make_spin(0, 400, 0.1, " kg")
	form.add_child(_target)

	# Only shown until the first weigh-in exists. It shapes your starting avatar.
	_start_box = VBoxContainer.new()
	_start_box.add_theme_constant_override("separation", 10)
	form.add_child(_start_box)
	_start_box.add_child(UIKit.make_label("Current weight (0 = skip)", 20, UIKit.MUTED))
	_start_weight = _make_spin(0, 400, 0.1, " kg")
	_start_box.add_child(_start_weight)
	_start_box.add_child(UIKit.make_label("Current body fat (0 = skip)", 20, UIKit.MUTED))
	_start_fat = _make_spin(0, 75, 0.1, " %")
	_start_box.add_child(_start_fat)

	var save_button := UIKit.make_button("Save")
	save_button.pressed.connect(_on_save)
	_box.add_child(save_button)

	_reset_button = UIKit.make_button("Reset all data")
	_reset_button.pressed.connect(_on_reset)
	_box.add_child(_reset_button)


func refresh() -> void:
	var p: Dictionary = SaveData.data["profile"]
	_intro.visible = not p["setup_done"]
	_goal_option.select(_index_of(GOALS, p["goal"]))
	_equipment_option.select(_index_of(EQUIPMENT, p["equipment"]))
	_sex_option.select(_index_of(SEX, p["sex"]))
	_start_box.visible = SaveData.data["weigh_ins"].is_empty()
	_height.value = float(p["height_cm"])
	_days.value = float(p["days_per_week"])
	_target.value = float(p["goal_target"])
	_reset_armed = false
	_reset_button.text = "Reset all data"


func _make_option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 60)
	for item in items:
		option.add_item(item[1])
	return option


func _make_spin(min_v: float, max_v: float, step_v: float, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.suffix = suffix
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(0, 60)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _index_of(list: Array, id: String) -> int:
	for i in list.size():
		if list[i][0] == id:
			return i
	return 0


func _quests_untouched() -> bool:
	for quest in QuestManager.get_quests():
		if float(quest["progress"]) > 0.0:
			return false
	return true


func _on_save() -> void:
	# Commit anything still being typed in the number boxes.
	for spin in [_height, _days, _target, _start_weight, _start_fat]:
		spin.apply()
	var p: Dictionary = SaveData.data["profile"]
	var old_goal: String = p["goal"]
	var old_equipment: String = p["equipment"]
	var first_time: bool = not p["setup_done"]

	p["goal"] = GOALS[_goal_option.selected][0]
	p["equipment"] = EQUIPMENT[_equipment_option.selected][0]
	p["sex"] = SEX[_sex_option.selected][0]
	p["height_cm"] = _height.value
	p["days_per_week"] = int(_days.value)
	p["goal_target"] = _target.value
	p["setup_done"] = true
	# First weigh-in from Setup: gives the avatar a starting body (no XP for this one).
	if SaveData.data["weigh_ins"].is_empty() and _start_weight.value > 0.0 and _start_fat.value > 0.0:
		SaveData.data["weigh_ins"].append({
			"date": SaveData.today_string(),
			"weight_kg": _start_weight.value,
			"body_fat_pct": _start_fat.value,
		})
	SaveData.save_data()
	QuestManager.sync_grand_quest()

	var changed: bool = first_time or old_goal != p["goal"] or old_equipment != p["equipment"]
	var message := "Profile saved"
	if changed:
		if _quests_untouched():
			QuestManager.regenerate_today()
			message = "Saved. Today's quests updated."
		else:
			message = "Saved. Changes apply to tomorrow's quests."
	saved.emit(message)


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Tap again to erase ALL data"
		return
	SaveData.reset_data()
	QuestManager.regenerate_today()
	refresh()
	saved.emit("All data reset")
