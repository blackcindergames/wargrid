extends Control

const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ControlGroups = preload("res://scripts/match/control_groups.gd")
const FactionGuide = preload("res://scripts/presentation/faction_guide.gd")
signal resume_requested
signal leave_requested
signal quit_requested
signal quality_changed(quality: int)
signal neon_changed(neon: bool)
signal smooth_changed(smooth: bool)
signal destinations_changed(on: bool)
signal playtest_changed(on: bool)
signal opened
const LEAVE_QUESTION := "Leave the match? Your opponent wins and the room closes."
const QUIT_QUESTION := "Quit the game? Your opponent wins and the room closes."
var confirm_leave: bool = false
var leave_question: String = LEAVE_QUESTION
var quit_question: String = QUIT_QUESTION
var _menu: Control
var _confirm: Control
var _settings: Control
var _controls: Control
var _guide: Control
# The local player's faction, which the guide opens on.
var faction: String = ""
var _resume: Button
var _cancel: Button
var _question: Label
var _confirm_button: Button
var _on_confirm: Callable
var _quality: HBoxContainer
# Each switch with its stored value's reader, so `open()` can show what another screen saved.
var _switches: Array = []

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
	var buttons: VBoxContainer = _column()
	_menu = _panel(center, "Menu", buttons)
	_resume = _button(buttons, "Resume", resume_requested.emit)
	_button(buttons, "Settings", func() -> void: _show(_settings, _settings.find_child("Back", true, false)))
	_button(buttons, "Controls", func() -> void: _show(_controls, _controls.find_child("Back", true, false)))
	_button(buttons, "Faction guide", func() -> void:
		_guide.show_faction(faction, faction)
		_show(_guide, _guide.find_child("Back", true, false)))
	_button(buttons, "Leave match", func() -> void: _ask(leave_question, "Leave", leave_requested.emit))
	# The browser tab cannot be closed by the game.
	if not web: _button(buttons, "Quit", func() -> void: _ask(quit_question, "Quit", quit_requested.emit))
	var box: VBoxContainer = _column()
	_confirm = _panel(center, "Confirm", box)
	_question = _label("", &"HudSmallLabel")
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# One line, the box widening to fit: the owner found a wrapped question hard to read (2v2 match, 2026-11-24).
	_question.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(_question)
	_confirm_button = _button(box, "", func() -> void: _on_confirm.call())
	_cancel = _button(box, "Cancel", _show_main)
	_settings = _page(center, "SettingsPage", "SETTINGS", _settings_body())
	_controls = _page(center, "ControlsPage", "CONTROLS", _controls_list())
	_guide = FactionGuide.new()
	_guide.back_requested.connect(_show_main)
	center.add_child(_guide)
	_read_settings()
	_show(_menu, null)

# Sections of [probe, keys, words, presses]; a press is a physical key with its modifier mask, read from the constants the input code reads, and test_pause_menu CL2 sends each one through the match.
static func controls(web: bool = OS.has_feature("web"), mac: bool = OS.has_feature("macos") or OS.has_feature("web_macos")) -> Array:
	var digits: Array = ControlGroups.KEYS
	var grid: Array = HudModel.GRID_KEYS
	var cards := PackedStringArray()
	for start: int in range(0, grid.size(), 4): cards.append("".join(grid.slice(start, start + 4).map(HudModel.key_label)))
	return [
		["Mouse", [
			["", "Left-click", "Select a unit or a building", []],
			["", "Left-drag", "Select the units in a box", []],
			["", "Shift+click", "Add or remove a unit", []],
			["", "Double-click", "Select that kind on screen", []],
			["", "Alt+double-click", "Select that kind on the map", []],
			["", "Left-click", "Place the building (right-click cancels)", []],
			["", "Right-click", "Move, attack, gather or enter", []],
			["", "Right-click", "Set the rally point (factory or barracks selected)", []],
			["", "Right-click", "Cancel the last queued of that unit (on its button)", []],
			["", "Right-drag", "Pan, faster the farther you drag", []],
			["", "Middle-drag", "Drag the map along", []],
			["", "Wheel", "Zoom", []]] + ([["", "Two-finger swipe", "Pan (trackpad)", []], ["", "Pinch", "Zoom (trackpad)", []]] if mac else [])],
		["Camera", [
			["pan", "Arrows", "Pan", [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]],
			["", "Screen edge", "Pan with the pointer", []],
			_key_row("home", KEY_H, "Centre on your Headquarters, again to go back"),
			_key_row("last_attack", KEY_SPACE, "Jump to your or an ally's base under attack")]],
		["Commands", [
			["grid", " · ".join(cards), "The button in that spot of the card; Shift: five", grid],
			_key_row("build", HudModel.BUILD_KEY, "Build, with one builder selected"),
			_key_row("back", HudModel.BACK_KEY, "Back to the builder's buttons"),
			_key_row("attack_move", HudModel.ORDER_KEYS.attack_move, "Attack move: armed units fight their way to the spot you click"),
			_key_row("stop", HudModel.ORDER_KEYS.stop, "Stop"),
			_key_row("unload", HudModel.ORDER_KEYS.unload, "Unload"),
			_key_row("ping", HudModel.PING_KEY, "Team matches: ping for your teammate, then click the spot; Alt+click pings at once"),
			["", "Click or right-click", "Cancel the unit in production (on NOW PRODUCING)", []],
			["", "Top-right production icons", "Click: select its building · Double-click: go there", []]]],
		["Groups", [
			["recall", _span(digits, 0), "Select a group, twice to centre on it", digits],
			_save_row(digits, web, mac),
			["add", _span(digits, KEY_MASK_SHIFT), "Add the selection to a group", _masked(digits, [KEY_MASK_SHIFT])]]],
		["Other", [
			["esc", "Esc", "Back out one step, then the menu", [(InputMap.action_get_events("deselect")[0] as InputEventKey).keycode]],
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
	return _confirm.visible

func open() -> void:
	_read_settings()
	_show_controls()
	visible = true
	_show_main()
	opened.emit()

func close() -> void:
	visible = false

# Esc and Back: a page or the question returns to the menu, the menu resumes.
func back() -> void:
	if _menu.visible: close()
	else: _show_main()

func _show_main() -> void:
	_show(_menu, _resume)

func _show(part: Control, focus: Control) -> void:
	for each: Control in [_menu, _confirm, _settings, _controls, _guide]: each.visible = each == part
	if focus != null: focus.grab_focus()

func _ask(question: String, verb: String, action: Callable) -> void:
	if not confirm_leave:
		action.call()
		return
	_question.text = question
	_confirm_button.text = verb
	_on_confirm = action
	_show(_confirm, _cancel)

func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 220.0
	box.add_theme_constant_override("separation", 4)
	return box

func _panel(parent: Control, panel_name: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.theme_type_variation = &"HudSmallPanel"
	var margin := MarginContainer.new()
	for side: Array in [["left", 12], ["top", 8], ["right", 12], ["bottom", 8]]: margin.add_theme_constant_override("margin_" + side[0], side[1])
	margin.add_child(content)
	panel.add_child(margin)
	parent.add_child(panel)
	return panel

# Esc menu round, page A: `‹ Back` and the title top left, `Esc: back` top right.
func _page(parent: Control, page_name: String, title: String, body: Control) -> PanelContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	page.add_child(head)
	_button(head, "‹ Back", _show_main).name = "Back"
	var heading: Label = _label(title, &"HudTitle")
	# The page title is a deliberate step up the type scale, as in the mock-up.
	heading.add_theme_font_size_override("font_size", 14)
	head.add_child(heading)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_label("Esc: back", &"HudHint"))
	page.add_child(body)
	return _panel(parent, page_name, page)

func _settings_body() -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	_section(body, "GRAPHICS")
	_quality = _quality_toggle()
	_row(body, "Quality", _quality)
	for each: Array in [["Neon", "Neon colours", GraphicsSettings.load_neon, GraphicsSettings.save_neon, neon_changed.emit],
			["Smooth", "Smooth movement", GraphicsSettings.load_smooth, GraphicsSettings.save_smooth, smooth_changed.emit],
			["Destinations", "Show unit destinations", GraphicsSettings.load_destinations, GraphicsSettings.save_destinations, destinations_changed.emit]]:
		_row(body, each[1], _switch(each[0], each[2], each[3], each[4]))
	_section(body, "SOUND")
	var sliders := VolumeSliders.new()
	sliders.add_theme_constant_override("h_separation", 24)
	for child: Node in sliders.get_children():
		if child is Label:
			child.theme_type_variation = &"HudSmallLabel"
			(child as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		elif child is CheckButton: child.theme_type_variation = &"HudSmallCheck"
	body.add_child(sliders)
	_section(body, "GAME")
	_row(body, "Playtest helper", _switch("Playtest", PlaytestSettings.enabled, PlaytestSettings.save_enabled, playtest_changed.emit))
	return body

func _section(body: VBoxContainer, title: String) -> void:
	if body.get_child_count() > 0: body.add_child(_gap(4.0))
	body.add_child(_label(title, &"HudLabel"))

func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap

func _row(body: VBoxContainer, words: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var label: Label = _label(words, &"HudSmallLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	body.add_child(row)

func _switch(switch_name: String, stored: Callable, save: Callable, changed: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = switch_name
	toggle.theme_type_variation = &"HudSmallCheck"
	# No margin, so a row is the switch's 22 px as in the mock-up; `small_check` stays for the playtest overlay.
	var flush := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]: toggle.add_theme_stylebox_override(state, flush)
	toggle.toggled.connect(save)
	toggle.toggled.connect(changed)
	_switches.append([toggle, stored])
	return toggle

func _quality_toggle() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Quality"
	row.add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for side: Array in [["Low", GraphicsSettings.LOW], ["High", GraphicsSettings.HIGH]]:
		var button := Button.new()
		button.name = side[0]
		button.text = side[0]
		button.theme_type_variation = &"HudSmallToggle"
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = 48.0
		button.toggled.connect(_quality_toggled.bind(side[1]))
		row.add_child(button)
	return row

func _quality_toggled(on: bool, quality: int) -> void:
	if not on: return
	GraphicsSettings.save_quality(quality)
	quality_changed.emit(quality)

func _read_settings() -> void:
	var quality: int = GraphicsSettings.stored_quality()
	(_quality.get_node("Low") as Button).set_pressed_no_signal(quality == GraphicsSettings.LOW)
	(_quality.get_node("High") as Button).set_pressed_no_signal(quality == GraphicsSettings.HIGH)
	for pair: Array in _switches: (pair[0] as CheckButton).set_pressed_no_signal(pair[1].call())

# Esc menu round, Controls A: Mouse left; Camera, Commands, Groups and Other right.
func _controls_list() -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.name = "Controls"
	columns.add_theme_constant_override("separation", 24)
	var sections: Array = controls()
	for part: Array in [sections.slice(0, 1), sections.slice(1)]:
		# One grid per column, so its words line up under every title.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 4)
		columns.add_child(grid)
		for section: Array in part:
			# A 4 px row: with its two gaps, 12 px above every later title.
			if grid.get_child_count() > 0: for i: int in 2: grid.add_child(_gap(4.0))
			grid.add_child(_label(section[0], &"HudLabel"))
			grid.add_child(Control.new())
			for row: Array in section[1]:
				var key: Label = _label(row[1], &"HudKey")
				key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				grid.add_child(key)
				var words: Label = _label(row[2], &"HudSmallLabel")
				words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				grid.add_child(words)
	return columns

# The layout can change between matches, as the card's chips re-read it on a reset.
func _show_controls() -> void:
	var texts: Array = []
	for section: Array in controls():
		texts.append(section[0])
		for row: Array in section[1]: texts.append_array([row[1], row[2]])
	var labels: Array[Node] = _controls.find_child("Controls", true, false).find_children("*", "Label", true, false)
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
