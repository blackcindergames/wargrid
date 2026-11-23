extends Control

const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ControlGroups = preload("res://scripts/match/control_groups.gd")
signal resume_requested
signal leave_requested
signal quit_requested
signal quality_changed(quality: int)
signal neon_changed(neon: bool)
signal smooth_changed(smooth: bool)
signal destinations_changed(on: bool)
signal playtest_changed(on: bool)
signal opened
var confirm_leave: bool = false
var _confirming: bool = false
var _main_row: HBoxContainer
var _main_box: VBoxContainer
var _confirm_box: VBoxContainer
var _quality_button: Button
var _neon_button: Button
var _smooth_button: Button
var _smooth: bool = true
var _destinations_button: Button
var _destinations: bool = false
var _playtest_button: Button
var _playtest: bool = false
var _neon: bool = false
var _quality: int = GraphicsSettings.HIGH

func _init(web: bool = OS.has_feature("web")) -> void:
	name = "PauseMenu"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_main_row = HBoxContainer.new()
	_main_row.add_theme_constant_override("separation", 16)
	center.add_child(_main_row)
	_main_box = _box(_main_row)
	_main_row.add_child(_controls_list())
	_button(_main_box, "Resume", resume_requested.emit)
	_button(_main_box, "Back to main menu", _leave_pressed)
	# The browser tab cannot be closed by the game.
	if not web: _button(_main_box, "Quit", quit_requested.emit)
	_quality_button = _button(_main_box, "", _toggle_quality)
	_quality_button.name = "Quality"
	_show_quality(GraphicsSettings.stored_quality())
	_neon_button = _button(_main_box, "", _toggle_neon)
	_neon_button.name = "Neon"
	_show_neon(GraphicsSettings.load_neon())
	_smooth_button = _button(_main_box, "", _toggle_smooth)
	_smooth_button.name = "Smooth"
	_show_smooth(GraphicsSettings.load_smooth())
	_destinations_button = _button(_main_box, "", _toggle_destinations)
	_destinations_button.name = "Destinations"
	_show_destinations(GraphicsSettings.load_destinations())
	_playtest_button = _button(_main_box, "", _toggle_playtest)
	_playtest_button.name = "Playtest"
	_show_playtest(PlaytestSettings.enabled())
	var sliders := VolumeSliders.new()
	for child: Node in sliders.get_children():
		if child is Label: child.theme_type_variation = &"HudSmallLabel"
		elif child is CheckButton: child.theme_type_variation = &"HudSmallCheck"
	_main_box.add_child(sliders)
	_confirm_box = _box(center)
	_confirm_box.visible = false
	var question := Label.new()
	question.theme_type_variation = &"HudSmallLabel"
	question.text = "Leave the match? Your opponent wins and the room closes."
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_box.add_child(question)
	_button(_confirm_box, "Leave", leave_requested.emit)
	_button(_confirm_box, "Cancel", _show_main)

# Sections of [probe, keys, words, presses]; a press is a physical key with its modifier mask, read from the constants the input code reads, and test_pause_menu CL2 sends each one through the match.
static func controls(web: bool = OS.has_feature("web"), mac: bool = OS.has_feature("macos") or OS.has_feature("web_macos")) -> Array:
	var digits: Array = ControlGroups.KEYS
	var grid: Array = HudModel.GRID_KEYS
	var cards := PackedStringArray()
	for start: int in range(0, grid.size(), 4): cards.append("".join(grid.slice(start, start + 4).map(HudModel.key_label)))
	return [
		["Mouse", [
			["", "Left-click", "Select a unit or a building", []],
			["", "Drag", "Select the units in a box", []],
			["", "Shift+click", "Add or remove a unit", []],
			["", "Double-click", "Select that kind on screen", []],
			["", "Alt+double-click", "Select that kind on the map", []],
			["", "Right-click", "Move, attack, gather or enter", []],
			["", "Right-click", "Set the rally point (factory or barracks selected)", []],
			["", "Right-click", "Cancel the newest queued one (on a unit's button)", []],
			["", "Left-click", "Place the building (right-click cancels)", []],
			["", "Wheel", "Zoom", []]]],
		["Camera", [
			["pan", "Arrows", "Pan", [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]],
			["", "Screen edge", "Pan with the pointer", []],
			_key_row("home", KEY_H, "Centre on your Headquarters"),
			_key_row("last_attack", KEY_SPACE, "Jump to your or an ally's base under attack")]],
		["Commands", [
			["grid", " · ".join(cards), "The button in that spot of the bottom-right card", grid],
			_key_row("build", HudModel.BUILD_KEY, "Build, with one builder selected"),
			_key_row("back", HudModel.BACK_KEY, "Back to the builder's buttons"),
			_key_row("attack_move", HudModel.ORDER_KEYS.attack_move, "Attack move: armed units fight their way to the spot you click"),
			_key_row("stop", HudModel.ORDER_KEYS.stop, "Stop"),
			_key_row("unload", HudModel.ORDER_KEYS.unload, "Unload")]],
		["Groups", [
			["recall", _span(digits, 0), "Select a group, twice to centre on it", digits],
			_save_row(digits, web, mac),
			["add", _span(digits, KEY_MASK_SHIFT), "Add the selection to a group", _masked(digits, [KEY_MASK_SHIFT])]]],
		["Other", [
			["esc", "Esc", "Back out one step, then this menu", [(InputMap.action_get_events("deselect")[0] as InputEventKey).keycode]],
			_key_row("mute", KEY_M, "Mute"),
			_key_row("perf", KEY_F3, "Performance numbers")]]]

static func _key_row(probe: String, key: Key, words: String) -> Array:
	return [probe, HudModel.key_label(key), words, [key]]

# A browser keeps Ctrl+1-9 for its tabs and Cmd is the Windows key off macOS, so the list leads with what works where it runs; every binding still works.
static func _save_row(digits: Array, web: bool, mac: bool) -> Array:
	var named: Array = [KEY_MASK_SHIFT | KEY_MASK_CTRL, KEY_MASK_CTRL] if web else [KEY_MASK_CTRL, KEY_MASK_SHIFT | KEY_MASK_CTRL]
	if mac: named.append(KEY_MASK_META)
	var also: Array = named.slice(1).map(func(mask: int) -> String: return _span(digits, mask))
	var words: String = "Save a group" + (", also " + " or ".join(also) if not also.is_empty() else "")
	return ["save", _span(digits, named[0]), words, _masked(digits, named.slice(0, 2) + [KEY_MASK_META])]

static func _span(keys: Array, mask: int) -> String:
	var mods: String = "".join([[KEY_MASK_SHIFT, "Shift+"], [KEY_MASK_CTRL, "Ctrl+"], [KEY_MASK_META, "Cmd+"]].filter(func(pair: Array) -> bool: return mask & pair[0] != 0).map(func(pair: Array) -> String: return pair[1]))
	# Digits name their position, not the symbol a layout like AZERTY puts there.
	return "%s%s-%s" % [mods, OS.get_keycode_string(keys[0]), OS.get_keycode_string(keys[-1])]

static func _masked(keys: Array, masks: Array) -> Array:
	var presses: Array = []
	for mask: int in masks: presses.append_array(keys.map(func(key: int) -> int: return key | mask))
	return presses

func is_confirming() -> bool:
	return _confirming

func open() -> void:
	_show_quality(GraphicsSettings.stored_quality())
	_show_neon(GraphicsSettings.load_neon())
	_show_smooth(GraphicsSettings.load_smooth())
	_show_destinations(GraphicsSettings.load_destinations())
	_show_playtest(PlaytestSettings.enabled())
	_show_controls()
	visible = true
	_show_main()
	opened.emit()

func close() -> void:
	visible = false

func back() -> void:
	if _confirming: _show_main()
	else: close()

func _box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 220.0
	parent.add_child(box)
	return box

func _controls_list() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Controls"
	panel.theme_type_variation = &"HudSmallPanel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	for side: Array in [["left", 12], ["top", 8], ["right", 12], ["bottom", 8]]: margin.add_theme_constant_override("margin_" + side[0], side[1])
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)
	var sections: Array = controls()
	for part: Array in [sections.slice(0, 2), sections.slice(2)]:
		# One grid per column, so its words line up under every title.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 3)
		columns.add_child(grid)
		for section: Array in part:
			grid.add_child(_label(section[0], &"HudLabel"))
			grid.add_child(Control.new())
			for row: Array in section[1]:
				var key: Label = _label(row[1], &"HudKey")
				key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				grid.add_child(key)
				var words: Label = _label(row[2], &"HudSmallLabel")
				words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				grid.add_child(words)
	return panel

# The layout can change between matches, as the card's chips re-read it on a reset.
func _show_controls() -> void:
	var texts: Array = []
	for section: Array in controls():
		texts.append(section[0])
		for row: Array in section[1]: texts.append_array([row[1], row[2]])
	var labels: Array[Node] = _main_row.get_node("Controls").find_children("*", "Label", true, false)
	for at: int in labels.size(): (labels[at] as Label).text = texts[at]

func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"HudSmallButton"
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _leave_pressed() -> void:
	if not confirm_leave:
		leave_requested.emit()
		return
	_confirming = true
	_main_row.visible = false
	_confirm_box.visible = true
	_confirm_box.get_child(2).grab_focus()

func _show_main() -> void:
	_confirming = false
	_confirm_box.visible = false
	_main_row.visible = true
	_main_box.get_child(0).grab_focus()

func _toggle_quality() -> void:
	_show_quality(GraphicsSettings.HIGH if _quality == GraphicsSettings.LOW else GraphicsSettings.LOW)
	GraphicsSettings.save_quality(_quality)
	quality_changed.emit(_quality)

func _show_quality(quality: int) -> void:
	_quality = quality
	_quality_button.text = "Quality: " + ("Low" if _quality == GraphicsSettings.LOW else "High")

func _toggle_neon() -> void:
	_show_neon(not _neon)
	GraphicsSettings.save_neon(_neon)
	neon_changed.emit(_neon)

func _show_neon(neon: bool) -> void:
	_neon = neon
	_neon_button.text = "Neon colours: " + ("On" if neon else "Off")

func _toggle_smooth() -> void:
	_show_smooth(not _smooth)
	GraphicsSettings.save_smooth(_smooth)
	smooth_changed.emit(_smooth)

func _show_smooth(smooth: bool) -> void:
	_smooth = smooth
	_smooth_button.text = "Smooth movement: " + ("On" if smooth else "Off")

func _toggle_destinations() -> void:
	_show_destinations(not _destinations)
	GraphicsSettings.save_destinations(_destinations)
	destinations_changed.emit(_destinations)

func _show_destinations(on: bool) -> void:
	_destinations = on
	_destinations_button.text = "Show unit destinations: " + ("On" if on else "Off")

func _toggle_playtest() -> void:
	_show_playtest(not _playtest)
	PlaytestSettings.save_enabled(_playtest)
	playtest_changed.emit(_playtest)

func _show_playtest(on: bool) -> void:
	_playtest = on
	_playtest_button.text = "Playtest helper: " + ("On" if on else "Off")
