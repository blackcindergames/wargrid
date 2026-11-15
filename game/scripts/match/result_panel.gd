extends Control

signal play_again_pressed
signal change_setup_pressed

var _outcome: Label
var _status: Label
var _play_again: Button

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
	_button(buttons, "ChangeSetup", "Back to menu", change_setup_pressed.emit)

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

func show_result(outcome: String, status: String, can_play: bool) -> void:
	_outcome.text = outcome
	_status.text = status
	_play_again.disabled = not can_play
	visible = not outcome.is_empty()

func takes_enter(event: InputEvent) -> bool:
	if not visible or _play_again.disabled: return false
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
