extends Control
## Root of the app: builds the layout, bottom navigation and pop-up messages.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const HomeScreen = preload("res://scripts/ui/home_screen.gd")
const LogScreen = preload("res://scripts/ui/log_screen.gd")
const StatsScreen = preload("res://scripts/ui/stats_screen.gd")
const HistoryScreen = preload("res://scripts/ui/history_screen.gd")
const ShortcutImport = preload("res://scripts/shortcut_import.gd")
const SettingsScreen = preload("res://scripts/ui/settings_screen.gd")

const NAV := [["home", "Home"], ["log", "Log"], ["stats", "Stats"], ["history", "Charts"], ["settings", "Setup"]]

var _screens := {}
var _nav_buttons := {}
var _current := ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	theme = UIKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()

	StatsManager.rank_up.connect(_on_rank_up)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.all_main_completed.connect(_on_all_clear)
	QuestManager.quests_changed.connect(_on_quests_changed)
	StatsManager.notice.connect(show_toast)
	_screens["settings"].saved.connect(_on_settings_saved)
	_screens["home"].log_requested.connect(_on_log_requested)

	QuestManager.sync_grand_quest()
	_import_from_link()
	var setup_done: bool = SaveData.data["profile"]["setup_done"]
	_show("home" if setup_done else "settings")


## On the web version, an iOS Shortcut can open the app with Health data after the "#".
## Example: https://you.github.io/levelupfit/#v=1&steps=8234&w=125.4&bf=36.8
func _import_from_link() -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.location.hash", true)
	if not (raw is String) or raw.length() < 2:
		return
	var messages: Array = ShortcutImport.apply(ShortcutImport.parse_hash(raw))
	# Remove the data from the address bar so a refresh doesn't run it again.
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.search)", true)
	QuestManager.refresh_for_today()
	for message in messages:
		show_toast(message, UIKit.GOOD)


func _notification(what: int) -> void:
	# When the app comes back to the foreground, check whether a new day started.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not _screens.is_empty():
		QuestManager.refresh_for_today()
		_on_quests_changed()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Screens live in one margin container; only the current one is visible.
	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("margin_left", 20)
	content.add_theme_constant_override("margin_right", 20)
	content.add_theme_constant_override("margin_top", 28)
	content.add_theme_constant_override("margin_bottom", 8)
	root.add_child(content)

	_screens = {
		"home": HomeScreen.new(),
		"log": LogScreen.new(),
		"stats": StatsScreen.new(),
		"history": HistoryScreen.new(),
		"settings": SettingsScreen.new(),
	}
	for key in _screens:
		_screens[key].visible = false
		content.add_child(_screens[key])

	# Bottom navigation bar.
	var nav_panel := UIKit.make_card(UIKit.NAV_BG)
	root.add_child(nav_panel)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav_panel.add_child(nav)
	var group := ButtonGroup.new()
	for item in NAV:
		var button := UIKit.make_button(item[1])
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 20)
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show.bind(item[0]))
		nav.add_child(button)
		_nav_buttons[item[0]] = button

	# Pop-up message (toast) overlay.
	var overlay := MarginContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_constant_override("margin_top", 90)
	add_child(overlay)
	_toast = UIKit.make_card(UIKit.TOAST_BG)
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	overlay.add_child(_toast)
	_toast_label = UIKit.make_label("", 22)
	_toast_label.custom_minimum_size = Vector2(420, 0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


func _show(screen_id: String) -> void:
	_current = screen_id
	for key in _screens:
		_screens[key].visible = (key == screen_id)
	for key in _nav_buttons:
		_nav_buttons[key].set_pressed_no_signal(key == screen_id)
	_screens[screen_id].refresh()


func show_toast(text: String, color: Color = UIKit.TEXT) -> void:
	if _toast.visible:
		_toast_label.text += "\n" + text  # several messages at once
	else:
		_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): _toast.visible = false)


func _on_quests_changed() -> void:
	# The Log screen is skipped so it doesn't wipe what you are typing.
	if _current != "" and _current != "log":
		_screens[_current].refresh()


func _on_rank_up(stat_id: String, new_rank: String) -> void:
	show_toast("%s reached rank %s!" % [StatsManager.STAT_NAMES[stat_id], new_rank], UIKit.rank_color(new_rank))


func _on_quest_completed(quest: Dictionary) -> void:
	show_toast("Quest complete: " + QuestManager.title_for(quest), UIKit.GOOD)


func _on_all_clear() -> void:
	show_toast("All quests cleared! Streak: %d" % SaveData.data["streak"], UIKit.GOOD)


func _on_log_requested(mode: int) -> void:
	_screens["log"].select_mode(mode)
	_show("log")


func _on_settings_saved(message: String) -> void:
	show_toast(message)
	_show("home")
