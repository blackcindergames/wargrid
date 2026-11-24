extends Control

const MatchSettings = preload("res://scripts/match_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const MATCH_ENDED := "Match ended"
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]

signal play_again_pressed
signal change_setup_pressed

# Set by the match screen: the pause menu keeps the focus while it is open.
var yields_to: Control:
	set(value):
		yields_to = value
		value.visibility_changed.connect(_menu_toggled)
# Set by the match screen: the playtest form and text fields keep the focus too.
var yields_when: Callable
var _outcome: Label
var _status: Label
var _length: Label
var _table: GridContainer
var _play_again: Button
var _change_setup: Button
var _copy: Button
var _focus_target: Button
var _buttons: HBoxContainer
var _gap: Control
var _mark: Control
var _body: Label
var _divider: HSeparator
var _footer: HBoxContainer
var _version: Label
var _code: Label
var _rows: Array[Dictionary] = []
var _wants_focus: bool = false
var _grab_pending: bool = false
var _frozen: bool = false
var _report: String = ""
var copy_text: Callable = DisplayServer.clipboard_set

func _init() -> void:
	name = "ResultPanel"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	_outcome = _label(box, "Outcome")
	_outcome.add_theme_font_size_override("font_size", 30)
	_status = _label(box, "Status")
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color("#d4d4d4"))
	# Reserved even when empty so the card never changes height (user, 2026-11-15).
	_status.custom_minimum_size.y = 20.0
	_length = _label(box, "Length")
	_length.visible = false
	_table = GridContainer.new()
	_table.name = "Table"
	_table.columns = 4
	_table.visible = false
	_table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_table.add_theme_constant_override("h_separation", 24)
	box.add_child(_table)
	_add_freeze_parts(box)
	_gap = Control.new()
	_gap.custom_minimum_size.y = 16.0
	box.add_child(_gap)
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	_copy = _button(_buttons, "Copy", "Copy report", _copy_report)
	_copy.visible = false
	_play_again = _button(_buttons, "PlayAgain", "Play again", play_again_pressed.emit)
	_play_again.theme_type_variation = "PrimaryButton"
	_change_setup = _button(_buttons, "ChangeSetup", "Back to menu", change_setup_pressed.emit)
	_focus_target = _change_setup

# The freeze variant's parts, hidden on the Victory/Defeat card.
func _add_freeze_parts(box: VBoxContainer) -> void:
	_mark = Control.new()
	_mark.name = "Mark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_mark.offset_top = -14.0
	_mark.offset_bottom = 14.0
	_mark.offset_right = 32.0
	_mark.draw.connect(_draw_mark)
	_mark.visible = false
	_outcome.add_child(_mark)
	_body = _label(box, "Body")
	_body.text = "The game hit an error and cannot continue. Please copy the report and send it to us."
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 400.0
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color("#d4d4d4"))
	_divider = HSeparator.new()
	_divider.name = "Divider"
	_divider.add_theme_constant_override("separation", 16)
	var line := StyleBoxLine.new()
	line.color = Color("#808080")
	line.thickness = 1
	_divider.add_theme_stylebox_override("separator", line)
	box.add_child(_divider)
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	box.add_child(_footer)
	_version = _label(_footer, "Version")
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_version.add_theme_font_size_override("font_size", 13)
	_version.add_theme_color_override("font_color", Color("#d4d4d4"))
	_code = _label(_footer, "Code")
	_code.text = "GAME ERROR"
	_code.add_theme_font_size_override("font_size", 13)
	for part: Control in [_body, _divider, _footer]: part.visible = false

# Variant A of the result-panel A/B (user, 2026-11-15); the match-slab look follows in slice 2.
func _ready() -> void:
	var card: PanelContainer = $Center/Card
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#2a2a2a")
	panel.border_color = Color("#808080")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(0)
	_pad(panel, 24.0, 24.0)
	card.add_theme_stylebox_override("panel", panel)
	_outcome.add_theme_font_override("font", get_theme_font("font", "PrimaryButton"))
	_code.add_theme_font_override("font", get_theme_font("font", &"HudLabel"))
	_mark.self_modulate = get_theme_color("warn", &"Tokens")
	for button: Button in [_copy, _play_again, _change_setup]:
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size = Vector2(144.0, 36.0)
		_square(button, button.theme_type_variation)
	var waiting := StyleBoxFlat.new()
	waiting.bg_color = Color("#666a6c")
	waiting.set_corner_radius_all(0)
	_pad(waiting, 12.0, 4.0)
	_play_again.add_theme_stylebox_override("disabled", waiting)
	_play_again.add_theme_color_override("font_disabled_color", Color.WHITE)

# Reads the look's styles afresh, so Back to menu can switch between the secondary and the primary look.
static func _square(button: Button, look: StringName) -> void:
	button.theme_type_variation = look
	for state: String in BUTTON_STATES:
		button.remove_theme_stylebox_override(state)
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		_pad(style, 12.0, 4.0)
		if style is StyleBoxFlat: (style as StyleBoxFlat).set_corner_radius_all(0)
		button.add_theme_stylebox_override(state, style)

static func _pad(style: StyleBox, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical

func show_result(outcome: String, status: String, can_play: bool, rows: Array[Dictionary] = [], length: String = "", waiting: bool = false, accept: bool = false) -> void:
	_set_freeze(false)
	_outcome.text = outcome
	_status.text = status
	_play_again.disabled = not can_play
	_play_again.text = "Accept rematch" if accept and can_play else "Play again"
	_play_again.visible = outcome != MATCH_ENDED
	var look: StringName = &"" if _play_again.visible else &"PrimaryButton"
	if _change_setup.theme_type_variation != look: _square(_change_setup, look)
	visible = not outcome.is_empty()
	_length.text = length
	_length.visible = not rows.is_empty()
	_table.visible = not rows.is_empty()
	if rows != _rows:
		_rows.assign(rows)
		_rebuild_table()
	_take_focus(visible and not can_play and not waiting)

# Later calls keep the report, the focus and Report copied.
func show_freeze(report: String, footer: String) -> void:
	if _frozen:
		_try_grab()
		return
	_set_freeze(true)
	_report = report
	_version.text = footer
	_outcome.text = "Match stopped"
	_copy.text = "Copy report"
	# The one Enter guard: takes_enter reads it, and Copy report holds the focus.
	_play_again.disabled = true
	visible = true
	_take_focus(true)

func _set_freeze(on: bool) -> void:
	if on == _frozen: return
	_frozen = on
	for part: Control in [_mark, _body, _divider, _footer, _copy]: part.visible = on
	for part: Control in [_status, _play_again]: part.visible = not on
	_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if on else HORIZONTAL_ALIGNMENT_CENTER
	if on:
		_length.visible = false
		_table.visible = false
		var margin := StyleBoxEmpty.new()
		margin.content_margin_left = 40.0
		_outcome.add_theme_stylebox_override("normal", margin)
	else: _outcome.remove_theme_stylebox_override("normal")
	_buttons.alignment = BoxContainer.ALIGNMENT_END if on else BoxContainer.ALIGNMENT_CENTER
	_gap.custom_minimum_size.y = 8.0 if on else 16.0
	_square(_change_setup, &"PrimaryButton" if on else &"")
	_focus_target = _copy if on else _change_setup
	_wants_focus = false

func _copy_report() -> void:
	copy_text.call(_report)
	_copy.text = "Report copied"

func _draw_mark() -> void:
	var outline := PackedVector2Array([Vector2(16.0, 1.0), Vector2(31.0, 27.0), Vector2(1.0, 27.0), Vector2(16.0, 1.0)])
	_mark.draw_colored_polygon(outline.slice(0, 3), Color.WHITE)
	# draw_colored_polygon has no antialiasing; the antialiased outline smooths its edges.
	_mark.draw_polyline(outline, Color.WHITE, 1.0, true)
	_mark.draw_rect(Rect2(14.0, 9.0, 4.0, 10.0), Color.BLACK)
	_mark.draw_rect(Rect2(14.0, 21.0, 4.0, 4.0), Color.BLACK)

static func report_text(reason: String, build: String, map: String, tick: int) -> String:
	return "Wargrid game error report\nerror: %s\nversion: %s\nmap: %s\ntick: %d" % [reason, build, map, tick]

static func footer_text(build: String, map: String) -> String:
	return "Version %s · %s" % [build, MatchSettings.PLAY_MAPS.get(map, map)]

# Back to menu is the only live button once Play again is gone; wait for the pause menu to close.
func _take_focus(wanted: bool) -> void:
	if wanted and not _wants_focus: _grab_pending = true
	if not wanted: _grab_pending = false
	_wants_focus = wanted
	_try_grab()

# Opening the menu takes the focus and closing it hides the focused button, so grab again on close.
func _menu_toggled() -> void:
	if yields_to.visible and _wants_focus: _grab_pending = true
	_try_grab()

func _try_grab() -> void:
	if not _grab_pending or (yields_to != null and yields_to.visible) or (yields_when.is_valid() and yields_when.call()): return
	_focus_target.grab_focus()
	_grab_pending = false

func _rebuild_table() -> void:
	for cell in _table.get_children(): cell.free()
	if _rows.is_empty(): return
	for header: String in ["", "Units built", "Units lost", "Buildings lost"]: _cell(header, false, header.is_empty())
	for row in _rows:
		if row.has("group"):
			_cell(row.group, true, true).add_theme_color_override("font_color", Color("#d4d4d4"))
			for i in 3: _cell("", false, false)
			continue
		var you: bool = row.you
		var named: Label = _cell(row.name, you, true)
		if row.has("colour"): _mark_owner(named, row.colour)
		for key: String in ["built", "units_lost", "buildings_lost"]: _cell(str(row[key]), you, false)

# The mock-up's 8 px owner square in the label's left margin, so the cell stays one Label.
func _mark_owner(label: Label, colour: Color) -> void:
	var margin := StyleBoxEmpty.new()
	margin.content_margin_left = 14.0
	label.add_theme_stylebox_override("normal", margin)
	label.draw.connect(func() -> void: label.draw_rect(Rect2(0.0, (label.size.y - 8.0) / 2.0, 8.0, 8.0), colour))

func _cell(text: String, bold: bool, left: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	if bold: label.add_theme_font_override("font", get_theme_font("font", "PrimaryButton"))
	_table.add_child(label)
	return label

static func result_text(match_state: Variant, team: int) -> String:
	if match_state == null: return ""
	if match_state.status == "draw": return "Draw"
	if match_state.status != "won": return ""
	return "Victory" if match_state.winner == team else "Defeat"

static func player_name(id: int, faction: String) -> String:
	var tag: String = Registry.faction(faction).get("short_name", "")
	return "P%d %s" % [id, tag] if not tag.is_empty() else "P%d" % id

static func length_text(ticks: int, rate: int) -> String:
	var seconds: int = floori(float(ticks) / rate)
	return "Match length %d:%02d" % [floori(seconds / 60.0), seconds % 60]

func takes_enter(event: InputEvent) -> bool:
	if not visible or _play_again.disabled or _change_setup.has_focus(): return false
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)

func _label(parent: Control, label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _button(parent: Control, button_name: String, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button
