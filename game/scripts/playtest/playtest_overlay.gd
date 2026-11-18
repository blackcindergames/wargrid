extends Control

const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const MarkerCapture = preload("res://scripts/playtest/marker_capture.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const SessionForm = preload("res://scripts/playtest/session_form.gd")
const CHECKLIST_KEY: Key = KEY_QUOTELEFT
const MARKER_KEY: Key = KEY_N
const CHECKLIST_WIDTH: float = 320.0
const PANEL_SHARE: float = 0.6
const DIALOG_WIDTH: float = 360.0
const MARGIN: float = 16.0
var image_source: Callable = _viewport_image
var web: bool = OS.has_feature("web")
var download: Callable = JavaScriptBridge.download_buffer
var match_record: Callable
var _card: Dictionary
var _context: Callable
var _header: Callable
var _active: bool = false
var _session: PlaytestSession
var _checklist: PanelContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _saved: Label
var _boxes: Dictionary = {}
var _dialog: PanelContainer
var _reviewed: bool = false
var _text: LineEdit
var _save: Button
var _kinds: Dictionary = {}
var _kind: String = ""
var _captured: Dictionary = {}
var _jpg: String = ""

func setup(card: Dictionary, context: Callable, record: Callable, header: Callable) -> void:
	_card = card
	_context = context
	match_record = record
	_header = header
	name = "Playtest"
	theme = UiStyle.hud_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_checklist()
	_build_dialog()

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func set_active(on: bool) -> void:
	if on == _active: return
	_active = on
	if not on:
		_checklist.hide()
		cancel_marker()
		return
	_open_session()
	_checklist.show()

func _open_session() -> void:
	var first: bool = _session == null
	_session = PlaytestSession.resume_or_open(str(_card.get("id", "")), PlaytestSettings.build_id())
	if first: _session.start_match() # the sitting outlives scenes and may still point at the last scene's match
	_rebuild()

func end_match() -> void:
	if not _active or _reviewed: return
	_save_draft()
	cancel_marker()
	_record_match()
	_rebuild()
	_checklist.show()
	if _typed_field() == null: _scroll_to_markers.call_deferred()

func keep_match() -> void:
	if _active and not _reviewed: _record_match()

func close_out() -> void:
	if not _active: return
	get_viewport().gui_release_focus() # focus_exited saves the field being typed in
	_save_draft()
	keep_match()
	PlaytestSession.close_sitting(web, download)

func _save_draft() -> void:
	if _dialog.visible and not _text.text.is_empty(): save_marker(_kind, _text.text)

func _record_match() -> int:
	_reviewed = true
	return _session.finish_match(match_record.call())

func begin_match() -> void:
	_reviewed = false
	if _session != null: _session.start_match()
	if _active: _open_session()

func _process(_delta: float) -> void:
	if _active and not _reviewed and _context.call().over: end_match()
	_show_saved()

func is_active() -> bool:
	return _active

func holds_match() -> bool:
	return _dialog.visible

func checked(item_id: String) -> bool:
	return _session != null and _session.data.checklist.get(item_id, false)

func observe_command(payload: Dictionary) -> void:
	_tick_triggers(func(trigger: String) -> bool: return FocusCards.matches_command(trigger, payload))

func observe_menu() -> void:
	_tick_triggers(func(trigger: String) -> bool: return trigger == "esc_menu")

func open_marker() -> void:
	if not _active or _dialog.visible: return
	var context: Dictionary = _context.call()
	if context.over or context.menu: return
	_captured = context
	_jpg = MarkerCapture.jpg_base64(image_source.call())
	_choose_kind("")
	_text.clear()
	_dialog.show()
	_text.grab_focus()

func save_marker(kind: String, text: String) -> void:
	_session.add_marker(MarkerCapture.marker(kind, text, _captured, _jpg), _header.call())
	cancel_marker()
	_rebuild()

func cancel_marker() -> void:
	_dialog.hide()

func _input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey and event.pressed and not event.echo): return
	var key: Key = (event as InputEventKey).physical_keycode
	if _dialog.visible:
		if key != KEY_ESCAPE: return
		cancel_marker()
	elif _typed_field() != null:
		if key != KEY_ESCAPE: return
		get_viewport().gui_release_focus()
	elif key == CHECKLIST_KEY: _checklist.visible = not _checklist.visible
	elif key == MARKER_KEY: open_marker()
	else:
		_tick_triggers(func(trigger: String) -> bool: return trigger.begins_with("key:") and OS.find_keycode_from_string(trigger.substr(4)) == key)
		return
	get_viewport().set_input_as_handled()

func _typed_field() -> LineEdit:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus as LineEdit if focus is LineEdit and _checklist.is_ancestor_of(focus) else null

func _viewport_image() -> Image:
	return get_viewport().get_texture().get_image()

func _tick_triggers(matches: Callable) -> void:
	if not _active: return
	for item: Dictionary in _card.get("try", []):
		var id: String = item.id
		if item.has("trigger") and not checked(id) and matches.call(item.trigger):
			_boxes[id].set_pressed_no_signal(true)
			_session.set_checked(id, true, false)

func _build_checklist() -> void:
	_checklist = _corner_panel("Checklist", CHECKLIST_WIDTH, 1.0)
	var box := VBoxContainer.new()
	_checklist.add_child(box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.minimum_size_changed.connect(_fit)
	_scroll.add_child(_rows)
	_saved = Label.new()
	_saved.name = "Saved"
	_saved.hide()
	box.add_child(_saved)
	_rebuild()
	_checklist.hide()

func _rebuild() -> void:
	var typed: LineEdit = _typed_field() if is_inside_tree() else null
	var typed_name: String = typed.name if typed != null else ""
	var caret: int = typed.caret_column if typed != null else 0
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_boxes.clear()
	SessionForm.add_label(_rows, "%s  (%s)" % [_card.get("title", ""), _key_label(CHECKLIST_KEY)]).name = "Title"
	for item: Dictionary in _card.get("try", []):
		var check := CheckBox.new()
		check.name = item.id
		check.text = item.text
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.focus_mode = Control.FOCUS_NONE
		check.set_pressed_no_signal(checked(item.id))
		check.toggled.connect(func(on: bool) -> void: _session.set_checked(item.id, on, true))
		_rows.add_child(check)
		_boxes[item.id] = check
	if _session == null: return
	for question: Dictionary in _card.get("questions", []): SessionForm.add_question(_rows, _session, question)
	SessionForm.add_label(_rows, SessionForm.SCALE_LEGEND).name = "ScaleLegend"
	var shown: int = _session.marker_match()
	var listed: bool = shown >= 0 and not _session.data.matches[shown].markers.is_empty()
	SessionForm.add_label(_rows, "Last match" if listed and not _reviewed and shown == _session.last_match else "This match").name = "MarkersTitle"
	if listed: SessionForm.add_markers(_rows, _session, shown)
	else: SessionForm.add_label(_rows, "No markers this match" if _reviewed else "No markers yet (%s adds one)" % _key_label(MARKER_KEY)).name = "NoMarkers"
	_refocus(typed_name, caret)
	_show_saved()
	_fit()

# Rows are rebuilt from scratch, so the field being typed in gets its focus back by its stable name.
func _refocus(field_name: String, caret: int) -> void:
	var field: LineEdit = _rows.find_child(field_name, true, false) as LineEdit if not field_name.is_empty() else null
	if field == null: return
	field.grab_focus()
	field.caret_column = caret

func _scroll_to_markers() -> void:
	var title: Control = _rows.get_node_or_null("MarkersTitle")
	if title != null: _scroll.ensure_control_visible(title)

func _key_label(key: Key) -> String:
	var label: Key = key if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(key)
	return char(label) if label > KEY_SPACE and label < 128 else OS.get_keycode_string(label)

func _show_saved() -> void:
	_saved.visible = _session != null and (_session.save_failed or not _session.saved_at.is_empty())
	if _saved.visible: _saved.text = "Not saved" if _session.save_failed else "Saved %s" % _session.saved_at

# A ScrollContainer reports no minimum height, so the panel would collapse without this.
func _fit() -> void:
	if not is_inside_tree(): return
	var spare: float = _checklist.get_theme_stylebox("panel").get_minimum_size().y + _saved.get_combined_minimum_size().y + _scroll.get_parent().get_theme_constant("separation")
	_scroll.custom_minimum_size.y = minf(_rows.get_combined_minimum_size().y, PANEL_SHARE * get_viewport_rect().size.y - spare)

func _build_dialog() -> void:
	_dialog = _corner_panel("MarkerDialog", DIALOG_WIDTH, 0.5)
	var box := VBoxContainer.new()
	_dialog.add_child(box)
	var kinds := HBoxContainer.new()
	box.add_child(kinds)
	for kind in MarkerCapture.KINDS:
		var button := Button.new()
		button.name = kind.capitalize()
		button.text = kind.capitalize()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_kind.bind(kind))
		kinds.add_child(button)
		_kinds[kind] = button
	_text = LineEdit.new()
	_text.name = "Text"
	_text.placeholder_text = "Optional note"
	box.add_child(_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	_save = SessionForm.add_action(row, "Save", "Save", func() -> void: save_marker(_kind, _text.text))
	SessionForm.add_action(row, "Cancel", "Cancel", cancel_marker)
	_dialog.hide()

func _choose_kind(kind: String) -> void:
	_kind = kind
	for id: String in _kinds: _kinds[id].set_pressed_no_signal(id == kind)
	_save.disabled = kind.is_empty()

# Both panels sit on the bottom edge and grow upward; `anchor_x` 1.0 is the right corner, 0.5 the centre.
func _corner_panel(panel_name: String, width: float, anchor_x: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.anchor_left = anchor_x
	panel.anchor_right = anchor_x
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	var right: float = -MARGIN if anchor_x == 1.0 else width / 2.0
	panel.offset_left = right - width
	panel.offset_right = right
	panel.offset_top = -MARGIN
	panel.offset_bottom = -MARGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	return panel
