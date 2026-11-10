extends ScrollContainer
## Log: record lifts, bodyweight work, cardio, steps and weigh-ins.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MODES := ["Gym lift", "Bodyweight", "Cardio", "Steps", "Weigh-in"]

var _box: VBoxContainer
var _mode := 0
var _mode_option: OptionButton
var _form: VBoxContainer
var _fields := {}
var _exercise_ids: Array = []
var _result: Label


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)

	_box.add_child(UIKit.make_label("Log", 34))

	_mode_option = OptionButton.new()
	_mode_option.custom_minimum_size = Vector2(0, 64)
	for mode_name in MODES:
		_mode_option.add_item(mode_name)
	_mode_option.item_selected.connect(_on_mode_selected)
	_box.add_child(_mode_option)

	var card := UIKit.make_card()
	_box.add_child(card)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 10)
	card.add_child(_form)

	var log_button := UIKit.make_button("Log it")
	log_button.pressed.connect(_on_log_pressed)
	_box.add_child(log_button)

	_result = UIKit.make_label("", 24, UIKit.GOOD)
	_box.add_child(_result)
	_build_form()


func refresh() -> void:
	if _mode == 4:
		_build_form()  # refresh weigh-in defaults from the latest entry


func _on_mode_selected(index: int) -> void:
	_mode = index
	_result.text = ""
	_build_form()


func _build_form() -> void:
	UIKit.clear(_form)
	_fields.clear()
	_exercise_ids = []
	match _mode:
		0:
			_add_exercise_picker("lift")
			_add_spin("sets", "Sets", 1, 20, 1, 3, "")
			_add_spin("reps", "Reps per set", 1, 100, 1, 8, "")
			_add_spin("weight", "Weight", 0, 500, 0.5, 20, " kg")
		1:
			_add_exercise_picker("bodyweight")
			_add_spin("reps", "Total reps", 1, 1000, 1, 20, "")
			var fast := CheckBox.new()
			fast.text = "Fast paced (bonus Agility)"
			_fields["fast"] = fast
			_form.add_child(fast)
		2:
			_add_exercise_picker("cardio")
			_add_spin("minutes", "Duration", 1, 600, 1, 20, " min")
			_add_spin("distance", "Distance (optional)", 0, 200, 0.1, 0, " km")
		3:
			_form.add_child(UIKit.make_label("Enter only the steps you haven't logged yet today. They add up through the day.", 20, UIKit.MUTED))
			_add_spin("steps", "Steps", 0, 100000, 100, 1000, "")
		4:
			var last := _last_weigh_in()
			_add_spin("weight", "Weight", 20, 400, 0.1, last.get("weight_kg", 80.0), " kg")
			_add_spin("fat", "Body fat", 2, 75, 0.1, last.get("body_fat_pct", 25.0), " %")
			_form.add_child(UIKit.make_label("Optional: leave at 0 to skip.", 20, UIKit.MUTED))
			_add_spin("muscle", "Skeletal muscle", 0, 100, 0.1, 0, " %")
			_add_spin("lean", "Lean body mass", 0, 300, 0.1, 0, " kg")


func _add_exercise_picker(category: String) -> void:
	_form.add_child(UIKit.make_label("Exercise", 20, UIKit.MUTED))
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 60)
	_exercise_ids = ExerciseLibrary.list_by_category(category)
	for id in _exercise_ids:
		option.add_item(ExerciseLibrary.get_exercise(id)["name"])
	_form.add_child(option)
	_fields["exercise"] = option


func _add_spin(key: String, title: String, min_v: float, max_v: float, step_v: float, value: float, suffix: String) -> void:
	_form.add_child(UIKit.make_label(title, 20, UIKit.MUTED))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value = value
	spin.suffix = suffix
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(0, 60)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_child(spin)
	_fields[key] = spin


func _value(key: String) -> float:
	var spin: SpinBox = _fields[key]
	spin.apply()  # commit text that is still being typed
	return spin.value


func _selected_exercise() -> String:
	return _exercise_ids[_fields["exercise"].selected]


func _last_weigh_in() -> Dictionary:
	var list: Array = SaveData.data["weigh_ins"]
	if list.is_empty():
		return {}
	return list[list.size() - 1]


func _on_log_pressed() -> void:
	var gained: Dictionary = {}
	match _mode:
		0:
			gained = StatsManager.log_lift(_selected_exercise(), int(_value("sets")), int(_value("reps")), _value("weight"))
		1:
			gained = StatsManager.log_bodyweight(_selected_exercise(), int(_value("reps")), _fields["fast"].button_pressed)
		2:
			gained = StatsManager.log_cardio(_selected_exercise(), _value("minutes"), _value("distance"))
		3:
			var steps := int(_value("steps"))
			if steps <= 0:
				_result.text = "Enter a number of steps first."
				return
			gained = StatsManager.log_steps(steps)
		4:
			var muscle := _value("muscle")
			var lean := _value("lean")
			gained = StatsManager.log_weigh_in(
				_value("weight"), _value("fat"),
				muscle if muscle > 0.0 else -1.0,
				lean if lean > 0.0 else -1.0)
	_result.text = "Logged!  " + _format_gains(gained)


func _format_gains(gained: Dictionary) -> String:
	var parts: Array = []
	for id in gained:
		parts.append("%s +%.1f" % [StatsManager.STAT_SHORT[id], gained[id]])
	return ",  ".join(parts)
