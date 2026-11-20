extends RefCounted

const SCORES: int = 5
const SCALE_LEGEND := "1 strongly disagree … 5 strongly agree"

static func add_action(parent: Control, button_name: String, label: String, target: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"HudSmallButton"
	button.name = button_name
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(target)
	parent.add_child(button)
	return button

static func add_markers(parent: VBoxContainer, session: PlaytestSession, match_index: int) -> void:
	var markers: Array = session.data.matches[match_index].markers
	for k: int in markers.size():
		var marker: Dictionary = markers[k]
		var seconds: int = floori(float(marker.tick) / Engine.physics_ticks_per_second)
		var text: String = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
		if not str(marker.kind).is_empty(): text = "%s, %s" % [str(marker.kind).capitalize(), text]
		if not str(marker.text).is_empty(): text += ": " + str(marker.text)
		add_label(parent, text)
		var comment := LineEdit.new()
		_add_field(parent, comment, "Comment_%d_%d" % [match_index, k], "Comment", str(marker.comment))
		_save_on_leave(comment, func() -> void: session.set_comment(match_index, k, comment.text))

static func add_question(parent: VBoxContainer, session: PlaytestSession, question: Dictionary) -> void:
	var id: String = question.id
	var stored: Dictionary = session.data.answers.get(id, {})
	var score: Array[int] = [int(stored.get("score", 0))]
	add_label(parent, question.text)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var group := ButtonGroup.new()
	var answer := LineEdit.new()
	for n: int in range(1, SCORES + 1):
		var button := Button.new()
		button.theme_type_variation = &"HudSmallButton"
		button.name = "%s_%d" % [id, n]
		button.text = str(n)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(score[0] == n)
		button.toggled.connect(func(on: bool) -> void:
			if not on: return
			score[0] = n
			session.set_answer(id, n, answer.text))
		row.add_child(button)
	_add_field(parent, answer, "Answer_" + id, "Optional comment", str(stored.get("text", "")))
	_save_on_leave(answer, func() -> void: session.set_answer(id, score[0], answer.text))

static func add_label(parent: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudSmallLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

static func _add_field(parent: VBoxContainer, field: LineEdit, field_name: String, placeholder: String, text: String) -> void:
	field.theme_type_variation = &"HudSmallField"
	field.name = field_name
	field.placeholder_text = placeholder
	field.text = text
	parent.add_child(field)

# Saving per keystroke would write the file on every letter; Enter or leaving the field is enough.
static func _save_on_leave(field: LineEdit, save: Callable) -> void:
	field.text_submitted.connect(func(_text: String) -> void:
		if field.has_focus(): field.release_focus()
		else: save.call())
	field.focus_exited.connect(save)
