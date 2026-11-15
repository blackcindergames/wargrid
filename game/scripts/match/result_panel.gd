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
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	_outcome = _label(box, "Outcome")
	_outcome.add_theme_font_size_override("font_size", 32)
	_status = _label(box, "Status")
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_play_again = _button(buttons, "PlayAgain", "Play again", play_again_pressed.emit)
	_play_again.theme_type_variation = "PrimaryButton"
	_button(buttons, "ChangeSetup", "Change setup", change_setup_pressed.emit)

func show_result(outcome: String, status: String, can_play: bool) -> void:
	_outcome.text = outcome
	_status.text = status
	_status.visible = not status.is_empty()
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
