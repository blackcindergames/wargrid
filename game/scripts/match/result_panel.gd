extends Control

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
var _rows: Array[Dictionary] = []
var _wants_focus: bool = false
var _grab_pending: bool = false

func _init() -> void:
	name = "ResultPanel"
	visible = false
	theme = load("res://ui/launcher_theme.tres")
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
	_status.add_theme_font_size_override("font_size", 15)
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
	var gap := Control.new()
	gap.custom_minimum_size.y = 16.0
	box.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_play_again = _button(buttons, "PlayAgain", "Play again", play_again_pressed.emit)
	_play_again.theme_type_variation = "PrimaryButton"
	_change_setup = _button(buttons, "ChangeSetup", "Back to menu", change_setup_pressed.emit)

# Variant A of the result-panel A/B (user, 2026-11-15); the match-slab look follows in slice 2.
func _ready() -> void:
	var card: PanelContainer = $Center/Card
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#2a2a2a")
	panel.border_color = Color("#808080")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	_pad(panel, 24.0, 24.0)
	card.add_theme_stylebox_override("panel", panel)
	_outcome.add_theme_font_override("font", get_theme_font("font", "PrimaryButton"))
	for button: Button in [$Center/Card/Box/Buttons/PlayAgain, $Center/Card/Box/Buttons/ChangeSetup]:
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size = Vector2(144.0, 36.0)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style: StyleBox = button.get_theme_stylebox(state).duplicate()
			_pad(style, 12.0, 4.0)
			button.add_theme_stylebox_override(state, style)
	var waiting := StyleBoxFlat.new()
	waiting.bg_color = Color("#666a6c")
	waiting.set_corner_radius_all(5)
	_pad(waiting, 12.0, 4.0)
	_play_again.add_theme_stylebox_override("disabled", waiting)
	_play_again.add_theme_color_override("font_disabled_color", Color.WHITE)

static func _pad(style: StyleBox, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical

func show_result(outcome: String, status: String, can_play: bool, rows: Array[Dictionary] = [], length: String = "", waiting: bool = false) -> void:
	_outcome.text = outcome
	_status.text = status
	_play_again.disabled = not can_play
	visible = not outcome.is_empty()
	_length.text = length
	_length.visible = not rows.is_empty()
	_table.visible = not rows.is_empty()
	if rows != _rows:
		_rows.assign(rows)
		_rebuild_table()
	_take_focus(visible and not can_play and not waiting)

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
	_change_setup.grab_focus()
	_grab_pending = false

func _rebuild_table() -> void:
	for cell in _table.get_children(): cell.free()
	if _rows.is_empty(): return
	for header: String in ["", "Units built", "Units lost", "Buildings lost"]: _cell(header, false, header.is_empty())
	for row in _rows:
		var you: bool = row.you
		_cell(row.name, you, true)
		for key: String in ["built", "units_lost", "buildings_lost"]: _cell(str(row[key]), you, false)

func _cell(text: String, bold: bool, left: bool) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	if bold: label.add_theme_font_override("font", get_theme_font("font", "PrimaryButton"))
	_table.add_child(label)

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
