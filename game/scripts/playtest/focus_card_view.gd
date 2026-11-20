extends PanelContainer

const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
var _cards: Array[Dictionary]
var _open_count: Callable
var _end_sitting: Callable
var _web: bool
var _picker: OptionButton
var _session: Label
var _filed_row: HBoxContainer
var _filed_label: Label
var _filed: LineEdit
var _content: VBoxContainer

func _init(cards: Array[Dictionary], open_count: Callable = func() -> int: return -1, end_sitting: Callable = func() -> void: pass, web: bool = false) -> void:
	name = "FocusPanel"
	_cards = cards
	_open_count = open_count
	_end_sitting = end_sitting
	_web = web
	visible = false
	theme_type_variation = &"HudSmallPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 32.0
	offset_top = 32.0
	offset_right = -32.0
	offset_bottom = -32.0
	var box := VBoxContainer.new()
	box.name = "Box"
	add_child(box)
	_picker = OptionButton.new()
	_picker.theme_type_variation = &"HudSmallButton"
	_picker.get_popup().add_theme_font_size_override("font_size", 12)
	_picker.name = "Picker"
	_picker.visible = cards.size() > 1
	for entry in cards: _picker.add_item(entry.title)
	_picker.item_selected.connect(_pick)
	box.add_child(_picker)
	_session = Label.new()
	_session.theme_type_variation = &"HudSmallLabel"
	_session.name = "OpenSession"
	box.add_child(_session)
	_filed_row = HBoxContainer.new()
	box.add_child(_filed_row)
	_filed_label = Label.new()
	_filed_label.theme_type_variation = &"HudSmallLabel"
	_filed_label.name = "LastFiledLabel"
	_filed_row.add_child(_filed_label)
	_filed = LineEdit.new()
	_filed.theme_type_variation = &"HudSmallField"
	_filed.name = "LastFiled"
	_filed.editable = false # read-only but selectable, so the path can be copied
	_filed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filed_row.add_child(_filed)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	var close := Button.new()
	close.theme_type_variation = &"HudSmallButton"
	close.name = "Close"
	close.text = "Close"
	box.add_child(close)
	visibility_changed.connect(_render)
	_render()

func _pick(index: int) -> void:
	var id: String = _cards[index].id
	if _open_count.call() >= 0 and PlaytestSession.open_focus() != id: _end_sitting.call()
	# A failed filing leaves the sitting open; switching cards then would mix two cards' answers.
	if _open_count.call() < 0 or PlaytestSession.open_focus() == id: FocusCards.chosen = id
	_render()

func _render() -> void:
	var current: Dictionary = FocusCards.card(FocusCards.shown(), _cards)
	if current.is_empty(): return
	_picker.select(_cards.find(current))
	var open: int = _open_count.call()
	_session.visible = open >= 0
	_session.text = "Session open: %d %s. Picking another card files the session." % [open, "match" if open == 1 else "matches"]
	var filed: bool = not PlaytestSession.last_filed.is_empty()
	_filed_row.visible = filed or not _web
	_filed_label.text = ("Notes downloaded:" if _web else "Previous session saved to:") if filed else "Notes folder:"
	_filed.text = PlaytestSession.last_filed if filed else ProjectSettings.globalize_path(PlaytestSession.dir)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_add(current.title, 30)
	_add("New in this build")
	for line: String in current.new: _add("• " + line)
	_add("Try")
	for step: Dictionary in current.get("try"): _add("• " + step.text)

func _add(text: String, font_size: int = 0) -> void:
	var label := Label.new()
	label.theme_type_variation = &"HudSmallLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0: label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)
