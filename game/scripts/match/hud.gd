extends Control

signal cell_pressed(action: String)
signal entry_cancelled(entry_id: int)
signal cancel_build_pressed()
signal menu_pressed()
signal row_clicked(kind: String, shift: bool)

# Wider notices wrap, so a long desync path grows down, clear of the chips at 1280.
const NOTICE_WIDTH: float = 600.0
const PAD_LEFT: float = 12.0
const PAD_Y: float = 8.0
const GAP: int = 4
const ROW: float = 32.0
const TILE: Vector2 = Vector2(91, 60)
const TILE_PAD: float = 4.0
const FACTORY_PANEL: float = 152.0
# hud-v5-layout "Command card": 100 x 60 cells, padding 4 8, line 1 20 high, the name 4 under it.
const CELL: Vector2 = Vector2(100, 60)
const CELL_PAD: Vector2 = Vector2(8, 4)
const CELL_LINE: float = 20.0
const NAME_TOP: float = CELL_PAD.y + CELL_LINE + 4.0
const COMMAND_LINE: float = 28.0
const ITEM_NAME_SIZE: int = 12
# The page's empty-well fill, a literal there too (hud-v5-layout "Colour tokens").
const WELL: Color = Color("#0f1820")
# The cells' 15 px coin, its `$` in 1 px rects (cost step, user 2026-11-21).
const DOLLAR: Array[Rect2] = [Rect2(7, 2, 1, 1), Rect2(5, 3, 5, 2), Rect2(4, 5, 2, 1), Rect2(7, 5, 1, 1), Rect2(5, 6, 5, 2), Rect2(7, 8, 1, 1), Rect2(9, 8, 2, 1), Rect2(5, 9, 5, 2), Rect2(7, 11, 1, 1)]
const COIN: float = 15.0
# hud-v5-layout "Cell card"; the delay is the decided tooltip rule (user, 2026-11-15).
const CELL_CARD_WIDTH: float = 248.0
const CELL_CARD_LINE: float = 20.0
const CELL_CARD_DELAY_MSEC: int = 250

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")

var refusal: String = ""
var now_msec: Callable = Time.get_ticks_msec
var rebuilds: int = 0
var _economy: VBoxContainer
var _card: GridContainer
var _well: StyleBoxFlat
var _cell_queue: Array = []
var _cancel_build: Button
var _top_strip: HBoxContainer
var _credits_slab: PanelContainer
var _power_slab: PanelContainer
var _strip_style: StyleBoxFlat
var _preview_style: StyleBoxFlat
var _held: Vector2
var _menu: Button
var _notice: PanelContainer
var _notice_text: Label
var _refusal_line: PanelContainer
var _refusal_text: Label
var _refused_at: int = 0
var _group_line: PanelContainer
var _group_text: Label
var _grouped_at: int = 0
var _alert_line: PanelContainer
var _alert_text: Label
var _alerted_at: int = 0
var _esc: Label
var _resume: Label
var _queue: HBoxContainer
var _queue_more: Button
var _queue_empty: Label
var _queue_shown: Array = []
var _queue_for: int = -1
var _count_style: StyleBoxFlat
var _now_style: StyleBoxFlat
var _inset: StyleBoxFlat
var _edge: Color = Color.WHITE
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _many: BoxContainer
var _rows: GridContainer
var _row_looks: Dictionary = {}
var _counts: Dictionary = {}
var _labels: Dictionary = {}
var _last: Array = []
var _last_ids: Array[int] = []
var _shape: Array = []
var _hovered_cell: Button
var _blocked: StyleBox
var _hint_frame: StyleBoxFlat
var _cell_card: PanelContainer
var _tip_since: int = -1
var _tip_open: bool = false
var _strip_args: Array = []
var _blockers: Array[Control] = []
# The playtest helper's surfaces draw above the cell card, so the card steps left of them.
var helpers: Array[Control] = []

func _init() -> void:
	name = "Hud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_build_strip()
	_build_menu_chip()
	_build_notice()
	_build_refusal_line()
	_build_group_line()
	_build_alert_line()
	_build_looks()
	_build_panel()
	for surface: Control in [_top_strip, _menu, _panel]: block(surface)

# The spec's HUD blocks: a click, drag release or wheel on a panel never reaches the map.
func block(surface: Control) -> void:
	surface.mouse_filter = MOUSE_FILTER_STOP
	surface.mouse_force_pass_scroll_events = false
	_blockers.append(surface)

func blocking_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for surface: Control in _blockers:
		if surface.is_visible_in_tree(): rects.append(surface.get_global_rect())
	return rects

func blocks(point: Vector2) -> bool:
	return blocking_rects().any(func(rect: Rect2) -> bool: return rect.has_point(point))

# Mouse-transparent unless `block` makes it a HUD surface; the notice and refusal line stay so.
func _slab(slab_name: String, at: Vector2) -> PanelContainer:
	var slab := PanelContainer.new()
	slab.name = slab_name
	slab.theme_type_variation = &"HudSlab"
	slab.mouse_filter = MOUSE_FILTER_IGNORE
	slab.position = at
	add_child(slab)
	return slab

static func _box(parent: Control, box_name: String, box: BoxContainer, separation: int) -> BoxContainer:
	box.name = box_name
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

static func _label(parent: Control, label_name: String, variation: StringName, text: String = "") -> Label:
	var label := Label.new()
	label.name = label_name
	label.theme_type_variation = variation
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

# Label to value 8 (hud-v5-layout "Top strip"); a forecast follows today's number after the arrow, the coin 4 after a short one.
func _groups() -> void:
	var credits: BoxContainer = _box(_credits_slab, "Row", HBoxContainer.new(), 8)
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(8, 8)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	swatch.mouse_filter = MOUSE_FILTER_IGNORE
	credits.add_child(swatch)
	_label(credits, "CreditsLabel", &"HudLabel", "CREDITS")
	_label(credits, "Credits", &"HudCredits")
	_arrow(credits, "CreditsArrow")
	var forecast: BoxContainer = _box(credits, "Forecast", HBoxContainer.new(), 4)
	_label(forecast, "CreditsAfter", &"HudCredits")
	coin(forecast, "Coin")
	var power: BoxContainer = _box(_power_slab, "Row", HBoxContainer.new(), 8)
	_label(power, "PowerLabel", &"HudLabel", "POWER")
	_label(power, "Power", &"HudNumber")
	_arrow(power, "PowerArrow")
	_label(power, "PowerAfter", &"HudNumber")
	_label(power, "LowPower", &"HudLabel", HudModel.LOW_POWER).add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))

# Drawn, since Public Sans has no U+2192 (the ts-* states' arrow).
func _arrow(parent: Control, arrow_name: String) -> void:
	var arrow := Control.new()
	arrow.name = arrow_name
	arrow.custom_minimum_size = Vector2(12, 8)
	arrow.size_flags_vertical = SIZE_SHRINK_CENTER
	arrow.mouse_filter = MOUSE_FILTER_IGNORE
	var tone: Color = get_theme_color("muted", &"Tokens")
	arrow.draw.connect(func() -> void:
		arrow.draw_line(Vector2(0, 4), Vector2(10.5, 4), tone, 1.5, true)
		arrow.draw_polyline(PackedVector2Array([Vector2(7, 0.5), Vector2(10.5, 4), Vector2(7, 7.5)]), tone, 1.5, true))
	parent.add_child(arrow)

# One mark for "short of credits" on the strip and the cells.
func coin(parent: Control, coin_name: String) -> Control:
	var mark := Control.new()
	mark.name = coin_name
	mark.custom_minimum_size = Vector2(COIN, COIN)
	mark.size_flags_vertical = SIZE_SHRINK_CENTER
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	var warn: Color = get_theme_color("warn", &"Tokens")
	var cut: Color = get_theme_color("quiet", &"Tokens")
	mark.draw.connect(func() -> void:
		mark.draw_circle(Vector2(7.5, 7.5), 7.5, warn, true, -1.0, true)
		for rect: Rect2 in DOLLAR: mark.draw_rect(rect, cut))
	parent.add_child(mark)
	return mark

# A one-line slab: no vertical padding, a fixed height that centres its line.
func _flat(slab: PanelContainer, height: float) -> void:
	var style := get_theme_stylebox("panel", &"HudSlab").duplicate() as StyleBoxFlat
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	slab.add_theme_stylebox_override("panel", style)
	slab.custom_minimum_size.y = height

# Two slabs 8 apart at (8, 8), each hugging its numbers at rest (top strip round D, user 2026-11-22).
func _build_strip() -> void:
	_top_strip = _box(self, "TopStrip", HBoxContainer.new(), 8) as HBoxContainer
	_top_strip.position = Vector2(8, 8)
	_credits_slab = _strip_slab("CreditsGroup")
	_power_slab = _strip_slab("PowerGroup")
	_strip_style = _credits_slab.get_theme_stylebox("panel") as StyleBoxFlat
	_power_slab.add_theme_stylebox_override("panel", _strip_style)
	_preview_style = _strip_style.duplicate() as StyleBoxFlat
	_preview_style.border_color = get_theme_color("sel", &"Tokens")
	_groups()

# Measured in the tree: out of it a box has no theme separation and a label keeps a stale size.
func _ready() -> void:
	# Tabular digits: zeros measure every five-digit balance and four-digit shortfall; every part still shows.
	var widest: Dictionary = {"Credits": "00000", "CreditsAfter": "\u22120000", "Power": "00 / 00", "PowerAfter": "00 / 00"}
	for part: String in widest: (_top_strip.find_child(part, true, false) as Label).text = widest[part]
	_held = Vector2(_credits_slab.get_combined_minimum_size().x, _power_slab.get_combined_minimum_size().x)
	for part: String in widest: (_top_strip.find_child(part, true, false) as Label).text = ""

func _strip_slab(slab_name: String) -> PanelContainer:
	var slab := PanelContainer.new()
	slab.name = slab_name
	slab.theme_type_variation = &"HudSlab"
	slab.mouse_filter = MOUSE_FILTER_IGNORE
	_flat(slab, 32)
	_top_strip.add_child(slab)
	return slab

# A top-right chip that hugs its row of labels (hud-v5-layout "Menu chip, Team chip, playtest chip").
static func chip(chip_name: String, top: float, parts: Array) -> Button:
	var button := Button.new()
	button.name = chip_name
	button.theme_type_variation = &"HudChip"
	button.focus_mode = FOCUS_NONE
	button.custom_minimum_size.y = 32
	button.set_anchors_preset(PRESET_TOP_RIGHT)
	button.grow_horizontal = GROW_DIRECTION_BEGIN
	button.offset_left = -8
	button.offset_right = -8
	button.offset_top = top
	button.offset_bottom = top
	var row: BoxContainer = _box(button, "Row", HBoxContainer.new(), 8)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.minimum_size_changed.connect(func() -> void: button.custom_minimum_size.x = row.get_combined_minimum_size().x + 16)
	for part: Array in parts: _label(row, part[0], part[1], part[2])
	return button

func _build_menu_chip() -> void:
	_menu = chip("MenuChip", 8, [["Label", &"HudRow", "Menu"], ["EscChip", &"HudKey", "Esc"]])
	add_child(_menu)
	_esc = _menu.get_node("Row/EscChip")
	_esc.custom_minimum_size = Vector2(18, 18)
	_esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_esc.size_flags_vertical = SIZE_SHRINK_CENTER
	_menu.pressed.connect(menu_pressed.emit)

func _build_notice() -> void:
	_notice = _slab("Notice", Vector2.ZERO)
	_flat(_notice, 28)
	_notice.set_anchors_preset(PRESET_CENTER_TOP)
	_notice.grow_horizontal = GROW_DIRECTION_BOTH
	_notice.offset_top = 48
	_notice.offset_bottom = 48
	_notice_text = _label(_notice, "Text", &"HudRow")
	_notice_text.add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false

# A wrapping label has no width of its own: give it its text's width, capped.
func _show_notice(text: String) -> void:
	_notice.visible = not text.is_empty()
	if _notice_text.text == text: return
	_notice_text.text = text
	var width: float = _notice_text.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _notice_text.get_theme_font_size("font_size")).x
	var padding: float = _notice.get_theme_stylebox("panel").get_minimum_size().x
	_notice_text.custom_minimum_size.x = minf(ceilf(width) + 1.0, NOTICE_WIDTH - padding)

# hud-v5-layout "Refusal line": bottom centre, its bottom edge 8 above the dock line.
func _build_refusal_line() -> void:
	_refusal_line = _slab("RefusalLine", Vector2.ZERO)
	_flat(_refusal_line, 28)
	_refusal_line.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_refusal_line.grow_horizontal = GROW_DIRECTION_BOTH
	# Centred between the selection panel's 408 and the slab's W - 432, 8 above the screen bottom (gate B, user 2026-11-20).
	_refusal_line.offset_left = -12
	_refusal_line.offset_right = -12
	_refusal_line.offset_top = -36
	_refusal_line.offset_bottom = -8
	var row: BoxContainer = _box(_refusal_line, "Row", HBoxContainer.new(), 8)
	var square := ColorRect.new()
	square.name = "Square"
	square.color = get_theme_color("warn", &"Tokens")
	square.custom_minimum_size = Vector2(8, 8)
	square.size_flags_vertical = SIZE_SHRINK_CENTER
	square.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(square)
	_refusal_text = _label(row, "Text", &"HudRow")
	_refusal_text.add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))
	_refusal_line.visible = false

# 3-27: bottom centre, stacked above the refusal line it shares the middle with.
func _build_group_line() -> void:
	_group_line = _slab("GroupLine", Vector2.ZERO)
	_flat(_group_line, 28)
	_group_line.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_group_line.grow_horizontal = GROW_DIRECTION_BOTH
	_group_line.offset_left = -12
	_group_line.offset_right = -12
	_group_line.offset_top = -68
	_group_line.offset_bottom = -40
	_group_text = _label(_group_line, "Text", &"HudRow")
	_group_line.visible = false

# 3-24: top left under the strip, so the notice at the top centre never meets it.
func _build_alert_line() -> void:
	_alert_line = _slab("AlertLine", Vector2(8, 48))
	_flat(_alert_line, 28)
	_alert_text = _label(_alert_line, "Text", &"HudRow")
	_alert_text.add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))
	_alert_line.visible = false

func alert(text: String) -> void:
	_alerted_at = now_msec.call()
	_alert_text.text = text
	_alert_line.visible = true

func group_saved(slot: int, count: int) -> void:
	_grouped_at = now_msec.call()
	_group_text.text = "Group %d · %d unit%s" % [slot, count, "" if count == 1 else "s"]
	_group_line.visible = true

func refuse(raw_error: String) -> void:
	refusal = raw_error
	_refused_at = now_msec.call()
	_refusal_text.text = raw_error
	_refusal_line.visible = true

func clear_refusal() -> void:
	refusal = ""
	_refusal_line.visible = false

# The timer only hides the line; `refusal` keeps the words until replaced, cleared or reset.
func _process(_delta: float) -> void:
	if _refusal_line.visible and now_msec.call() - _refused_at >= 3000: _refusal_line.visible = false
	if _group_line.visible and now_msec.call() - _grouped_at >= 2000: _group_line.visible = false
	if _alert_line.visible and now_msec.call() - _alerted_at >= 4000: _alert_line.visible = false
	# Only the 250 ms wait needs the frame; hover and refresh lay out an open card.
	if _hovered_cell != null and not _cell_card.visible: _show_cell_card()

# Esc's first job is to back out of a selection, placement or form; the chip shows only when Esc opens the menu, and fades so Menu keeps its width.
func set_esc_chip(shown: bool) -> void:
	_esc.modulate.a = 1.0 if shown else 0.0

func setup(economy: VBoxContainer) -> void:
	_economy = economy
	if economy == null: return
	_cancel_build = economy.get_node("CancelBuild")
	_cancel_build.pressed.connect(cancel_build_pressed.emit)
	_build_slab()
	read_keys()
	block(economy)

func reset() -> void:
	clear_refusal()
	_group_line.visible = false
	_alert_line.visible = false
	_labels = {}
	_last = []
	_last_ids = []
	_counts = {}
	if _economy != null:
		end_hover()
		read_keys()

# hud-v5-layout "Command card": the VBox lays out rows, the Hud pads, fills and edges it.
func _build_slab() -> void:
	_economy.alignment = BoxContainer.ALIGNMENT_CENTER
	_economy.add_theme_constant_override("separation", GAP)
	_economy.draw.connect(_draw_slab)
	_economy.sort_children.connect(_pad_slab)
	_resume = _label(_economy, "ResumeHint", &"HudHint", "Right-click: resume")
	_build_card()
	_build_cell_card()
	_square(_cancel_build)
	var rows: Array[Control] = [_resume, _card, _cancel_build]
	for i in rows.size(): _economy.move_child(rows[i], i)

# The hover inset of ready cells and tiles, the NOW tile's fill, the `×N` badge (hud-v5-layout "Item cell").
func _build_looks() -> void:
	_inset = get_theme_stylebox("hover", &"HudButton").duplicate() as StyleBoxFlat
	_inset.border_color = get_theme_color("muted", &"Tokens")
	_now_style = get_theme_stylebox("normal", &"HudButton").duplicate() as StyleBoxFlat
	_now_style.bg_color = get_theme_color("panel2", &"Tokens")
	_count_style = StyleBoxFlat.new()
	_count_style.bg_color = get_theme_color("well", &"Tokens")
	_count_style.content_margin_left = 4
	_count_style.content_margin_right = 4
	# The 13 px line box is 16 high; the badge draws 14 (the page's line height).
	_count_style.expand_margin_top = -1
	_count_style.expand_margin_bottom = -1

# One cell per lattice position, named by its key; a cell keeps its position, only its words and look change.
func _build_card() -> void:
	_card = _grid("Card", 4)
	# The card itself reports the pointer leaving it from a gap or a well, which no cell does.
	_card.mouse_filter = MOUSE_FILTER_PASS
	_card.mouse_entered.connect(_restrip, CONNECT_DEFERRED)
	_card.mouse_exited.connect(_restrip, CONNECT_DEFERRED)
	_card.mouse_exited.connect(func() -> void: _tip_open = false)
	_well = StyleBoxFlat.new()
	_well.bg_color = WELL
	_well.border_color = get_theme_color("line", &"Tokens")
	_well.set_border_width_all(1)
	_blocked = get_theme_stylebox("disabled", &"HudButton")
	_hint_frame = StyleBoxFlat.new()
	_hint_frame.draw_center = false
	_hint_frame.border_color = get_theme_color("sel", &"Tokens")
	_hint_frame.set_border_width_all(1)
	for code: Key in HudModel.GRID_KEYS:
		var cell: Button = _button(_card, OS.get_keycode_string(code), CELL.x)
		cell.custom_minimum_size.y = CELL.y
		cell.set_meta("action", "")
		cell.pressed.connect(_press_cell.bind(cell))
		cell.gui_input.connect(_cell_input.bind(cell))
		cell.mouse_entered.connect(_hover_cell.bind(cell, true))
		cell.mouse_exited.connect(_hover_cell.bind(cell, false))
		_cell_label(cell, "Cost", &"HudNumber", Vector2(CELL_PAD.x, CELL_PAD.y), Vector2(CELL.x - 2.0 * CELL_PAD.x - 22.0, CELL_LINE))
		var key: Label = _cell_label(cell, "Chip", &"HudKey", Vector2(0, CELL_PAD.y + 1.0), Vector2(18, 18))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# A wide glyph or a layout's multi-character label grows the chip leftward, so it never leaves the cell.
		key.anchor_left = 1.0
		key.anchor_right = 1.0
		key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		key.offset_left = -CELL_PAD.x - 18.0
		key.offset_right = -CELL_PAD.x
		var name_label: Label = _cell_label(cell, "Name", &"HudRow", Vector2(CELL_PAD.x, NAME_TOP), Vector2(CELL.x - 2.0 * CELL_PAD.x, COMMAND_LINE))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Item names keep the page's 14 px line pitch, so two lines end inside the cell.
		name_label.add_theme_constant_override("line_spacing", -1)
		_cell_label(cell, "More", &"HudRow", Vector2(CELL_PAD.x, NAME_TOP), Vector2(0, COMMAND_LINE)).add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
		var mark: Control = coin(cell, "Coin")
		mark.size = mark.custom_minimum_size
		mark.position.y = CELL_PAD.y + (CELL_LINE - COIN) / 2.0
		mark.visible = false
		var hint := Panel.new()
		hint.name = "Hint"
		hint.mouse_filter = MOUSE_FILTER_IGNORE
		hint.add_theme_stylebox_override("panel", _hint_frame)
		hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		hint.visible = false
		cell.add_child(hint)
		_badge(cell)
		_cell_look(cell, &"well")

func _build_cell_card() -> void:
	_cell_card = _slab("CellCard", Vector2.ZERO)
	_cell_card.custom_minimum_size.x = CELL_CARD_WIDTH
	var lines: BoxContainer = _box(_cell_card, "Lines", VBoxContainer.new(), 0)
	var head: BoxContainer = _box(lines, "Head", HBoxContainer.new(), 4)
	_label(head, "Name", &"HudRow").custom_minimum_size.y = CELL_CARD_LINE
	_card_line(head, "Numbers")
	_card_line(lines, "Reason").add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))
	var counter: Label = _card_line(lines, "Counter")
	counter.add_theme_color_override("font_color", get_theme_color("text", &"Tokens"))
	# A broken counter line keeps the card's 20 px line pitch.
	counter.add_theme_constant_override("line_spacing", roundi(CELL_CARD_LINE - counter.get_theme_font("font").get_height(13)))
	_cell_card.visible = false

# The card's regular 13 px lines (the picture's body text).
func _card_line(parent: Control, line_name: String) -> Label:
	var label: Label = _label(parent, line_name, &"HudHint")
	label.add_theme_font_size_override("font_size", 13)
	label.custom_minimum_size.y = CELL_CARD_LINE
	return label

# The `×N` badge 4 from the bottom right (hud-v5-layout "Item cell").
func _badge(button: Button) -> void:
	var count: Label = _cell_label(button, "Count", &"HudNumber", Vector2.ZERO, Vector2.ZERO)
	count.add_theme_stylebox_override("normal", _count_style)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = GROW_DIRECTION_BEGIN
	count.grow_vertical = GROW_DIRECTION_BEGIN
	count.offset_left = -TILE_PAD
	count.offset_right = -TILE_PAD
	count.offset_top = -TILE_PAD + 1.0
	count.offset_bottom = -TILE_PAD + 1.0
	count.visible = false

static func _show_count(count: Label, queued: int, least: int) -> void:
	count.visible = queued >= least
	if count.visible: count.text = "×%d" % queued

# A 4 px `you` bar along the bottom edge, its right anchor the progress.
func _bar(parent: Control, bar_name: String) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -4
	bar.visible = false
	parent.add_child(bar)
	return bar

static func _show_progress(bar: ColorRect, entry: Dictionary, colour: Color) -> void:
	bar.color = colour
	bar.set_anchor(SIDE_RIGHT, minf(1.0, float(entry.work) / (Definitions.unit(entry.kind).ticks * 1000)), true)

static func _cell_label(cell: Button, label_name: String, variation: StringName, at: Vector2, minimum: Vector2) -> Label:
	var label: Label = _label(cell, label_name, variation)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.position = at
	label.custom_minimum_size = minimum
	label.size = minimum
	return label

# Chips name the cell's position in the player's layout; a reset and the menu opening re-read them.
func read_keys() -> void:
	for cell: Node in _card.get_children(): (cell.get_node("Chip") as Label).text = HudModel.key_label(HudModel.GRID_KEYS[cell.get_index()])

func _grid(grid_name: String, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = columns
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	_economy.add_child(grid)
	return grid

# No slab button keeps the focus: Space or Enter would press it again and the arrows walk a focus ring.
static func _square(button: Button) -> void:
	button.focus_mode = FOCUS_NONE
	button.theme_type_variation = &"HudButton"
	button.custom_minimum_size.y = ROW

func _button(parent: Control, button_name: String, width: float) -> Button:
	var button := Button.new()
	button.name = button_name
	_square(button)
	button.custom_minimum_size.x = width
	parent.add_child(button)
	return button

func _draw_slab() -> void:
	var area: Vector2 = _economy.size
	_economy.draw_rect(Rect2(Vector2.ZERO, area), get_theme_color("bg", &"Tokens"))
	_economy.draw_rect(Rect2(0, 0, area.x, 1), get_theme_color("line", &"Tokens"))
	_economy.draw_rect(Rect2(0, 0, 4, area.y), _edge)

# A VBox has no padding, so each row is moved inside it after every sort.
func _pad_slab() -> void:
	for child: Control in _economy.get_children():
		child.position.x = PAD_LEFT
		child.size.x = HudModel.SLAB_CONTENT

func _fit_slab() -> void:
	var height: float = _economy.get_combined_minimum_size().y
	_economy.visible = height > 0.0
	_economy.offset_top = -(height + 2.0 * PAD_Y)
	_economy.queue_redraw()

# The slab's top for the helper stack, read from offsets because the rect catches up a frame late.
func slab_top() -> float:
	var height: float = get_viewport_rect().size.y
	return height + _economy.offset_top if _economy != null and _economy.visible else height

func update_hud(view: Dictionary, selection: Dictionary, view_player: int, seat: int) -> void:
	var building: Dictionary = HudModel.building(view, selection.building_id)
	set_esc_chip(selection.esc_opens_menu)
	_show_notice(selection.notice)
	_show_selection(view, selection, seat, HudModel.player(view, view_player).get("faction", Registry.Factions.DEFAULT_FACTION))
	if _economy != null: _economy_controls(view, building, selection, seat)
	_strip_args = [view, selection, view_player]
	_show_strip(view, selection, view_player)
	_count_rebuild(selection)

# Structural changes only; values patch in place.
func _count_rebuild(selection: Dictionary) -> void:
	var shape: Array = [selection.ids.duplicate(), selection.building_id, selection.inspected_id, _counts.keys(), _many.visible, _panel.visible, selection.placement_kind, selection.notice, refusal]
	if shape == _shape: return
	_shape = shape
	rebuilds += 1

func _economy_controls(view: Dictionary, building: Dictionary, selection: Dictionary, seat: int) -> void:
	_edge = View.owner_color(seat, selection.bright_owners)
	_resume.visible = selection.resume_id != -1
	_cancel_build.visible = not building.is_empty() and not building.completed
	_cell_queue = building.get("queue", [])
	_show_card(view, HudModel.card(view, selection, seat), selection, seat)
	_fit_slab()
	_show_cell_card()

# hud-v5-layout "Hug rule for rows": rows from the top-most one holding a cell down to the edge; every other position is a well.
func _show_card(view: Dictionary, cells: Array, selection: Dictionary, seat: int) -> void:
	var actions: Dictionary = {}
	for cell: Array in cells: actions[cell[0]] = cell[1]
	var top: int = HudModel.GRID_KEYS.size()
	for code: Key in actions: top = mini(top, HudModel.GRID_KEYS.find(code))
	_card.visible = not actions.is_empty()
	# A hidden card sends no exit, so the next hover waits again.
	if not _card.visible: _tip_open = false
	for cell: Node in _card.get_children():
		var at: int = cell.get_index()
		cell.visible = at >= top - top % 4
		var action: String = actions.get(HudModel.GRID_KEYS[at], "")
		_fill_cell(cell, action, selection, HudModel.blocked(view, selection, seat, action))
		_show_queued(cell)
	# A hidden cell or a well sends no exit, so its hover ends here.
	if _hovered_cell != null and (not _hovered_cell.is_visible_in_tree() or str(_hovered_cell.get_meta("action")).is_empty()): _hovered_cell = null
	_show_hint()

# Blocked (hud-v5-layout "Looks"): quiet fill, muted name and cost; credits the sole blocker turn the cost warn with the coin 4 after it (3-2).
func _fill_cell(cell: Button, action: String, selection: Dictionary, blocked: Dictionary) -> void:
	cell.set_meta("action", action)
	cell.set_meta("blocked", blocked)
	var item: bool = _forecasts(action)
	var armed: bool = action == selection.placement_kind or (action == "attack_move" and selection.attack_move)
	_cell_look(cell, &"well" if action.is_empty() else (&"armed" if armed else (&"blocked" if not blocked.is_empty() else &"ready")))
	cell.get_node("Chip").visible = not action.is_empty()
	var cost: Label = cell.get_node("Cost")
	cost.visible = item
	var short: bool = blocked.get("cause", "") == "credits"
	if item:
		cost.text = str(Registry.kind(action).cost)
		_paint(cost, &"warn" if short else (&"muted" if not blocked.is_empty() else &""))
	var mark: Control = cell.get_node("Coin")
	mark.visible = item and short
	if mark.visible: mark.position.x = cost.position.x + _text_width(cost, cost.text) + 4.0
	var name_label: Label = cell.get_node("Name")
	_name_form(name_label, item)
	_paint(name_label, &"muted" if not blocked.is_empty() and not armed else &"")
	var words: String = "" if action.is_empty() else HudModel.cell_name(action, selection.placement_kind)
	cell.tooltip_text = "%s · %s or Esc" % [words, (cell.get_node("Chip") as Label).text] if action == "back" else ""
	if name_label.text != words:
		name_label.text = words
		name_label.reset_size()
	var more: Label = cell.get_node("More")
	more.visible = action == "build"
	if more.visible:
		more.text = "\u203a"
		more.position.x = name_label.position.x + _text_width(name_label, words) + 4.0

static func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x

# Item names take the smaller two-line form, top-aligned; commands sit centred in their 28 px line.
func _name_form(label: Label, item: bool) -> void:
	if label.has_theme_font_size_override("font_size") == item: return
	if item: label.add_theme_font_size_override("font_size", ITEM_NAME_SIZE)
	else: label.remove_theme_font_size_override("font_size")
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if item else VERTICAL_ALIGNMENT_CENTER
	label.reset_size()

# Ready cells take the tiles' hover inset; the armed look keeps its own hover; a well takes no pointer; a blocked cell still takes its click (click = key).
func _cell_look(cell: Button, look: StringName) -> void:
	if cell.get_meta("look", &"") == look: return
	cell.set_meta("look", look)
	cell.theme_type_variation = &"HudButtonArmed" if look == &"armed" else &"HudButton"
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		if look == &"well": cell.add_theme_stylebox_override(state, _well)
		elif look == &"blocked": cell.add_theme_stylebox_override(state, _blocked)
		elif look == &"ready" and state != "normal": cell.add_theme_stylebox_override(state, _inset)
		else: cell.remove_theme_stylebox_override(state)
	cell.mouse_filter = MOUSE_FILTER_IGNORE if look == &"well" else MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = CURSOR_POINTING_HAND if look in [&"ready", &"armed"] else CURSOR_ARROW

# A click closes the cell card until the pointer enters a cell again.
func _press_cell(cell: Button) -> void:
	_tip_since = -1
	_tip_open = false
	_show_cell_card()
	var action: String = cell.get_meta("action")
	# The sound player hears this press after the action has refilled the cell (Build opens the sub-grid in place).
	cell.set_meta("pressed_blocked", cell.get_meta("blocked"))
	if not action.is_empty(): cell_pressed.emit(action)

# Progress shows only on the NOW tile, never twice (user, 2026-11-23).
func _show_queued(cell: Button) -> void:
	var action: String = cell.get_meta("action")
	_show_count(cell.get_node("Count") as Label, _cell_queue.filter(func(entry: Dictionary) -> bool: return entry.kind == action).size(), 1)

# OpenRA's right-click (user, 2026-11-21): cancels the newest entry of the cell's kind; none queued, nothing sent.
func _cell_input(event: InputEvent, cell: Button) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_RIGHT or not click.pressed: return
	var id: int = HudModel.newest_of_kind(_cell_queue, cell.get_meta("action"))
	if id != -1: entry_cancelled.emit(id)

func _show_strip(view: Dictionary, selection: Dictionary, view_player: int) -> void:
	var numbers: Dictionary = HudModel.strip(view, view_player, _hovered_kind() if not _hovered_kind().is_empty() else selection.placement_kind)
	_power_slab.visible = HudModel.uses_power(HudModel.player(view, view_player).get("faction", Registry.Factions.DEFAULT_FACTION))
	(_top_strip.find_child("Swatch", true, false) as ColorRect).color = View.owner_color(view_player, selection.bright_owners)
	var after: int = numbers.get("after_credits", numbers.credits)
	var credits: bool = _forecast(_credits_slab, "Credits", [str(numbers.credits), "\u2212%d" % -after if after < 0 else str(after)], [false, after < 0])
	_credits_slab.find_child("Forecast", true, false).visible = credits
	_credits_slab.find_child("Coin", true, false).visible = after < 0
	var used: Array[int] = [numbers.used, numbers.get("after_used", numbers.used)]
	var available: Array[int] = [numbers.available, numbers.get("after_available", numbers.available)]
	var low: Array[bool] = [used[0] > available[0], used[1] > available[1]]
	var power: bool = _forecast(_power_slab, "Power", ["%d / %d" % [used[0], available[0]], "%d / %d" % [used[1], available[1]]], low)
	# 3-5: a forecast names low power only when the purchase flips it; already low, its warn numbers say so.
	_power_slab.find_child("LowPower", true, false).visible = low[1] and not ((credits or power) and low[0])
	var held: bool = _strip_held(selection)
	_credits_slab.custom_minimum_size.x = _held.x if held else 0.0
	_power_slab.custom_minimum_size.x = _held.y if held else 0.0
	for slab: Control in [_credits_slab, _power_slab, _top_strip]: slab.reset_size()

# Today's number, then the arrow and the forecast only when it differs, framed in sel (label A, user 2026-11-22).
func _forecast(slab: PanelContainer, part: String, texts: Array[String], warns: Array[bool]) -> bool:
	var changes: bool = texts[1] != texts[0]
	_tint(slab.find_child(part, true, false), texts[0], warns[0])
	_tint(slab.find_child(part + "After", true, false), texts[1], warns[1])
	slab.find_child(part + "Arrow", true, false).visible = changes
	slab.find_child(part + "After", true, false).visible = changes
	var style: StyleBoxFlat = _preview_style if changes else _strip_style
	if slab.get_theme_stylebox("panel") != style: slab.add_theme_stylebox_override("panel", style)
	return changes

# Shape D: while a forecast can show, both slabs keep their widest width, so nothing on the strip moves between cells.
func _strip_held(selection: Dictionary) -> bool:
	if selection.over: return false
	if not selection.placement_kind.is_empty(): return true
	# The mouse position outlives a window leave; the hovered control does not.
	if _card == null or not _card.is_visible_in_tree() or _card.get_viewport().gui_get_hovered_control() == null or not _card.get_global_rect().has_point(_card.get_global_mouse_position()): return false
	return _card.get_children().any(func(cell: Control) -> bool: return cell.visible and _forecasts(cell.get_meta("action")))

static func _forecasts(action: String) -> bool:
	return not action.is_empty() and not HudModel.COMMANDS.has(action)

# Only an item cell previews; of the refused ones only a credits shortfall does (TS round B), never a missing prerequisite or a full queue.
func _hovered_kind() -> String:
	if _hovered_cell == null: return ""
	var action: String = _hovered_cell.get_meta("action")
	var cause: String = (_hovered_cell.get_meta("blocked", {}) as Dictionary).get("cause", "")
	return action if _forecasts(action) and cause in ["", "credits"] else ""

func _tint(label: Label, text: String, warn: bool) -> void:
	label.text = text
	_paint(label, &"warn" if warn else &"")

# A token's colour, or the theme's with none; each override write re-themes the label, so only a change may touch it.
func _paint(label: Label, token: StringName) -> void:
	if token.is_empty():
		if label.has_theme_color_override("font_color"): label.remove_theme_color_override("font_color")
		return
	var colour: Color = get_theme_color(token, &"Tokens")
	if not label.has_theme_color_override("font_color") or label.get_theme_color("font_color") != colour: label.add_theme_color_override("font_color", colour)

func end_hover() -> void:
	_hovered_cell = null
	_tip_open = false
	_tip_since = -1
	_show_hint()
	_show_cell_card()

func _hover_cell(cell: Button, entered: bool) -> void:
	# An ending without a card (desync, relay lost) leaves the card up but previews nothing.
	if not _strip_args.is_empty() and _strip_args[1].over: return
	if not entered and _hovered_cell != cell: return
	_hovered_cell = cell if entered else null
	if entered: _tip_since = now_msec.call()
	_show_hint()
	_show_cell_card()
	_restrip()

# 3-10: the missing prerequisite of the hovered cell, when the card shows it, gets a sel frame.
func _show_hint() -> void:
	var missing: String = "" if _hovered_cell == null else (_hovered_cell.get_meta("blocked", {}) as Dictionary).get("missing", "")
	for cell: Node in _card.get_children(): (cell.get_node("Hint") as Control).visible = not missing.is_empty() and cell.get_meta("action") == missing

# Opens 250 ms after the pointer enters a cell and at once on a neighbour while one was open (decided tooltip rules).
func _show_cell_card() -> void:
	if _cell_card == null: return
	var shown: bool = _hovered_cell != null and _tip_since >= 0 and _has_card(_hovered_cell) and (_tip_open or now_msec.call() - _tip_since >= CELL_CARD_DELAY_MSEC)
	_cell_card.visible = shown
	if not shown: return
	_tip_open = true
	var action: String = _hovered_cell.get_meta("action")
	var reason: String = (_hovered_cell.get_meta("blocked") as Dictionary).get("reason", "")
	(_cell_card.find_child("Name", true, false) as Label).text = (_hovered_cell.get_node("Name") as Label).text
	var numbers: Label = _cell_card.find_child("Numbers", true, false)
	numbers.visible = not HudModel.COMMANDS.has(action)
	if numbers.visible: numbers.text = "%d · %d s" % [Registry.kind(action).cost, ceili(Registry.kind(action).ticks / float(Engine.physics_ticks_per_second))]
	var line: Label = _cell_card.find_child("Reason", true, false)
	line.visible = not reason.is_empty()
	line.text = reason
	var counter: Label = _cell_card.find_child("Counter", true, false)
	var words: String = HudModel.COUNTER_LINES.get(action, "")
	var room: float = CELL_CARD_WIDTH - _cell_card.get_theme_stylebox("panel").get_minimum_size().x
	# The card refreshes every view; only new words or a new width measure again.
	if counter.get_meta("fit", []) != [words, room]:
		counter.set_meta("fit", [words, room])
		# Too wide for the card, the line breaks between its claims, never inside one.
		counter.text = words if _text_width(counter, words) <= room else words.replace(" · ", "\n")
		counter.custom_minimum_size.y = CELL_CARD_LINE * (counter.text.count("\n") + 1)
	counter.visible = not words.is_empty()
	_cell_card.reset_size()
	var cell: Rect2 = _hovered_cell.get_global_rect()
	var at := Rect2(Vector2(clampf(cell.position.x, 8.0, get_viewport_rect().size.x - 8.0 - _cell_card.size.x), slab_top() - 8.0 - _cell_card.size.y), _cell_card.size)
	for helper: Control in helpers:
		if helper.is_visible_in_tree() and at.intersects(helper.get_global_rect()): at.position.x = maxf(8.0, helper.get_global_rect().position.x - 8.0 - at.size.x)
	_cell_card.position = at.position

# Item cells always; a command only while blocked, to name why.
static func _has_card(cell: Button) -> bool:
	return _forecasts(cell.get_meta("action")) or not (cell.get_meta("blocked", {}) as Dictionary).is_empty()

func _restrip() -> void:
	if not _strip_args.is_empty(): _show_strip.callv(_strip_args)

# hud-v5-layout "Selection panel" (P2.3b, 3-3): one row of four 91 x 60 tiles under the identity, in every own producer's panel.
func _build_queue(body: BoxContainer) -> void:
	_queue = _box(body, "Queue", HBoxContainer.new(), GAP) as HBoxContainer
	_queue.custom_minimum_size.y = TILE.y
	# The row itself reports the pointer leaving it from a gap, which no tile does.
	_queue.mouse_filter = MOUSE_FILTER_PASS
	_queue.mouse_exited.connect(_release_queue, CONNECT_DEFERRED)
	for i in HudModel.QUEUE_TILES: _tile("Tile%d" % (i + 1))
	_queue_more = _queue_tile("More")
	var plain: StyleBox = get_theme_stylebox("normal", &"HudButton")
	for look: String in ["normal", "hover", "pressed", "hover_pressed"]: _queue_more.add_theme_stylebox_override(look, plain)
	_queue_more.mouse_default_cursor_shape = CURSOR_ARROW
	var more: Label = _cell_label(_queue_more, "Count", &"HudNumber", Vector2(0, 13), Vector2(TILE.x, 16))
	more.add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cell_label(_queue_more, "Label", &"HudHint", Vector2(0, 31), Vector2(TILE.x, 15)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_queue_more.get_node("Label") as Label).text = "more"
	_queue_empty = _label(_queue, "Empty", &"HudHint", "Nothing in production")
	_queue_empty.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _queue_tile(tile_name: String) -> Button:
	var tile: Button = _button(_queue, tile_name, TILE.x)
	tile.custom_minimum_size.y = TILE.y
	tile.size_flags_vertical = SIZE_SHRINK_BEGIN
	return tile

# Name, the making cell's chip, NOW and the bar on the entry in production, `×N` on a run; no digits (3-3).
func _tile(tile_name: String) -> void:
	var tile: Button = _queue_tile(tile_name)
	_cell_look(tile, &"ready")
	tile.set_meta("ids", [])
	tile.pressed.connect(_cancel_tile.bind(tile))
	tile.mouse_entered.connect(_hover_tile.bind(tile, true))
	tile.mouse_exited.connect(_hover_tile.bind(tile, false))
	tile.mouse_exited.connect(_release_queue, CONNECT_DEFERRED)
	_cell_label(tile, "Now", &"HudLabel", Vector2(TILE_PAD, TILE_PAD), Vector2(0, CELL_LINE)).text = "NOW"
	var key: Label = _cell_label(tile, "Chip", &"HudKey", Vector2(0, TILE_PAD + 1.0), Vector2(18, 18))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.anchor_left = 1.0
	key.anchor_right = 1.0
	key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	key.offset_left = -TILE_PAD - 18.0
	key.offset_right = -TILE_PAD
	var name_label: Label = _cell_label(tile, "Name", &"HudRow", Vector2(TILE_PAD, TILE_PAD + CELL_LINE + 2.0), Vector2(TILE.x - 2.0 * TILE_PAD, COMMAND_LINE))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", ITEM_NAME_SIZE)
	name_label.add_theme_constant_override("line_spacing", -1)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_badge(tile)
	var track: ColorRect = _bar(tile, "Track")
	track.color = get_theme_color("well", &"Tokens")
	track.anchor_right = 1.0
	_bar(track, "Bar").visible = true

func _show_queue(queue: Array, building_id: int) -> void:
	var held: bool = building_id == _queue_for and not _queue_shown.is_empty() and _queue_held()
	_queue_for = building_id
	_queue_shown = queue
	if held: _keep_tiles(queue)
	else: _fill_tiles(queue)

# As the kind rows' hold: the mouse position outlives a window leave, the hovered control does not.
func _queue_held() -> bool:
	return _queue.is_visible_in_tree() and get_viewport().gui_get_hovered_control() != null and _queue.get_global_rect().has_point(_queue.get_global_mouse_position())

func _release_queue() -> void:
	if _queue.is_visible_in_tree() and not _queue_held(): _fill_tiles(_queue_shown)

# Over four tiles: three, then `+N more` counting the hidden entries (DA:1475).
func _fill_tiles(queue: Array) -> void:
	var tiles: Array = HudModel.queue_tiles(queue)
	var shown: int = tiles.size() if tiles.size() <= HudModel.QUEUE_TILES else HudModel.QUEUE_TILES - 1
	for i in HudModel.QUEUE_TILES:
		var tile: Button = _queue.get_child(i)
		tile.visible = i < shown
		if tile.visible: _fill_tile(tile, tiles[i], queue[0] if i == 0 else {})
	_queue_more.visible = tiles.size() > shown
	if _queue_more.visible: _fill_more(tiles.slice(shown))
	_queue_empty.visible = queue.is_empty()

func _fill_tile(tile: Button, run: Dictionary, producing: Dictionary) -> void:
	tile.set_meta("ids", run.ids)
	tile.set_meta("key", HudModel.key_label(HudModel.CELL_KEYS.get(HudModel.role(run.kind), KEY_NONE)))
	var name_label: Label = tile.get_node("Name")
	if name_label.text != Registry.kind(run.kind).display_name:
		name_label.text = Registry.kind(run.kind).display_name
		name_label.reset_size()
	if not tile.is_hovered(): (tile.get_node("Chip") as Label).text = tile.get_meta("key")
	tile.tooltip_text = "Cancel · refunds %d" % run.refund
	_show_count(tile.get_node("Count") as Label, run.ids.size(), 2)
	_mute_tile(tile, false)
	_mark_now(tile, producing)

func _mark_now(tile: Button, producing: Dictionary) -> void:
	(tile.get_node("Now") as Control).visible = not producing.is_empty()
	(tile.get_node("Track") as Control).visible = not producing.is_empty()
	if not producing.is_empty(): _show_progress(tile.get_node("Track/Bar") as ColorRect, producing, _panel_style.border_color)
	if producing.is_empty(): tile.remove_theme_stylebox_override("normal")
	else: tile.add_theme_stylebox_override("normal", _now_style)

func _fill_more(runs: Array) -> void:
	var count: int = 0
	var lines: PackedStringArray = []
	for run: Dictionary in runs:
		count += run.ids.size()
		lines.append(Registry.kind(run.kind).display_name + (" ×%d" % run.ids.size() if run.ids.size() > 1 else ""))
	(_queue_more.get_node("Count") as Label).text = "+%d" % count
	_queue_more.tooltip_text = "\n".join(lines)

# Held under the pointer: no tile moves; each keeps its entries still queued, NOW follows the entry in production, an emptied tile mutes.
func _keep_tiles(queue: Array) -> void:
	var queued: Array = queue.map(func(entry: Dictionary) -> int: return entry.id)
	for i in HudModel.QUEUE_TILES:
		var tile: Button = _queue.get_child(i)
		if not tile.visible: continue
		var live: Array = Array(tile.get_meta("ids")).filter(func(id: int) -> bool: return queued.has(id))
		tile.set_meta("ids", live)
		_show_count(tile.get_node("Count") as Label, live.size(), 2)
		_mute_tile(tile, live.is_empty())
		_mark_now(tile, queue[0] if not queue.is_empty() and live.has(queue[0].id) else {})

# As a held kind row: muted, with no cancel to offer.
func _mute_tile(tile: Button, muted: bool) -> void:
	if tile.disabled == muted: return
	tile.disabled = muted
	tile.mouse_default_cursor_shape = CURSOR_ARROW if muted else CURSOR_POINTING_HAND
	if muted: tile.tooltip_text = ""
	if muted: tile.get_node("Name").add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
	else: tile.get_node("Name").remove_theme_color_override("font_color")
	_hover_tile(tile, tile.is_hovered())

# The newest stored entry of the run, so the older ones keep their order; never another entry.
func _cancel_tile(tile: Button) -> void:
	var ids: Array = tile.get_meta("ids")
	if not ids.is_empty(): entry_cancelled.emit(ids.back())

func _hover_tile(tile: Button, hovered: bool) -> void:
	var mark: Label = tile.get_node("Chip")
	hovered = hovered and not tile.disabled
	mark.text = "×" if hovered else str(tile.get_meta("key", ""))
	if hovered: mark.add_theme_color_override("font_color", get_theme_color("text", &"Tokens"))
	else: mark.remove_theme_color_override("font_color")
	_inset_track(tile, hovered, 4.0)

# hud-v5-layout "Selection panel": x 0, 408 wide, bottom on H, height hugs; the 4 px owner edge is the style's left border.
func _build_panel() -> void:
	_panel = _slab("SelectionPanel", Vector2.ZERO)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = get_theme_color("bg", &"Tokens")
	_panel_style.border_width_left = 4
	_panel_style.content_margin_left = 16
	_panel_style.content_margin_right = 16
	_panel_style.content_margin_top = 12
	_panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_panel.grow_vertical = GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size.x = 408
	_panel.draw.connect(_draw_panel_lines)
	_panel.mouse_exited.connect(_release_hold, CONNECT_DEFERRED)
	# The title's line box is 18 against the page's 14, so 4 under it keeps the spec heights.
	var box: BoxContainer = _box(_panel, "Box", VBoxContainer.new(), 4)
	var top: BoxContainer = _box(box, "Top", HBoxContainer.new(), 8)
	_label(top, "Name", &"HudTitle").size_flags_horizontal = SIZE_EXPAND_FILL
	_label(top, "RightLabel", &"HudLabel")
	var body: BoxContainer = _box(box, "Body", VBoxContainer.new(), 8)
	_bar_row(body, "ProgressRow", "Progress", "Percent")
	_bar_row(body, "HealthRow", "HealthBar", "Health")
	var pair: BoxContainer = _box(body, "KeyRow", HBoxContainer.new(), 0)
	_label(pair, "Key", &"HudLabel").custom_minimum_size.x = 112
	_label(pair, "Value", &"HudNumber")
	_build_queue(body)
	_label(body, "Footer", &"HudHint", HudModel.RALLY)
	_build_rows(box)
	_panel.visible = false

# hud-v5-layout "Kind rows": header row 18, rows 186 x 26 in two columns 4 apart, the rule line last.
func _build_rows(box: BoxContainer) -> void:
	_many = _box(box, "Many", VBoxContainer.new(), 8)
	_label(_many, "Header", &"HudTitle")
	_rows = GridContainer.new()
	_rows.name = "Rows"
	_rows.columns = 2
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("h_separation", GAP)
	_rows.add_theme_constant_override("v_separation", GAP)
	_many.add_child(_rows)
	_label(_many, "Footer", &"HudHint", HudModel.ROWS_RULE)
	_many.visible = false
	for look: Array in [["normal", "btn", 0], ["hover", "panel2", 1], ["disabled", "quiet", 0]]:
		var style := StyleBoxFlat.new()
		style.bg_color = get_theme_color(look[1], &"Tokens")
		style.set_border_width_all(look[2])
		style.border_color = get_theme_color("muted", &"Tokens")
		_row_looks[look[0]] = style
	_row_looks.pressed = _row_looks.hover
	_row_looks.hover_pressed = _row_looks.hover
	_row_looks.focus = StyleBoxEmpty.new()

# A 160 x 6 bar on a `well` track, then its muted number 8 to the right.
func _bar_row(parent: Control, row_name: String, bar_name: String, number_name: String) -> void:
	var row: BoxContainer = _box(parent, row_name, HBoxContainer.new(), 8)
	var track := ColorRect.new()
	track.name = bar_name
	track.color = get_theme_color("well", &"Tokens")
	track.custom_minimum_size = Vector2(160, 6)
	track.size_flags_vertical = SIZE_SHRINK_CENTER
	track.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(track)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	track.add_child(fill)
	_label(row, number_name, &"HudNumber").add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))

func _draw_panel_lines() -> void:
	var area: Vector2 = _panel.size
	var line: Color = get_theme_color("line", &"Tokens")
	_panel.draw_rect(Rect2(4, 0, area.x - 4, 1), line)
	_panel.draw_rect(Rect2(area.x - 1, 0, 1, area.y), line)

func panel_edge() -> Color:
	return _panel_style.border_color

func _show_selection(view: Dictionary, selection: Dictionary, seat: int, faction: String) -> void:
	_last = [view, selection, seat, faction]
	# Only a shrink (a death, a row click) holds the rows; a fresh selection replaces them.
	if _holding() and not selection.ids.all(func(id: int) -> bool: return _last_ids.has(id)): _counts = {}
	_last_ids = selection.ids.duplicate()
	_labels = HudModel.collector_labels(view, selection.ids, seat, _labels)
	var many: bool = selection.building_id == -1 and (selection.ids.size() > 1 or (_holding() and not _counts.is_empty() and not selection.ids.is_empty()))
	_many.visible = many
	_panel.get_node("Box/Top").visible = not many
	_panel.get_node("Box/Body").visible = not many
	if many:
		_queue.visible = false
		_panel.custom_minimum_size.y = 0.0
		_show_rows(view, selection.ids, seat, selection.bright_owners)
	else:
		_counts = {}
		var row: Dictionary = HudModel.panel(view, selection, seat, faction, _labels)
		_show_panel(row, selection.bright_owners)
		# Never hidden in between: a hide drops the pointer's hover and with it the tiles' hold.
		_queue.visible = row.has("queue")
		# Fixed, so a queue change never moves the panel's top (3-3); a rally footer's 15 px line box adds 1.
		_panel.custom_minimum_size.y = FACTORY_PANEL if _queue.visible else 0.0
		if _queue.visible: _show_queue(row.queue, selection.building_id)
	if not _queue.visible: _queue_for = -1

# The row set holds while the pointer is over the panel, so a row never moves under it.
# The mouse position outlives a window leave; the hovered control does not.
func _holding() -> bool:
	return _many.is_visible_in_tree() and get_viewport().gui_get_hovered_control() != null and _panel.get_global_rect().has_point(_panel.get_global_mouse_position())

func _release_hold() -> void:
	if not _holding() and not _last.is_empty(): _show_selection.callv(_last)

func _show_rows(view: Dictionary, ids: Array[int], seat: int, bright: bool) -> void:
	var live: Dictionary = HudModel.kind_rows(view, ids)
	var kinds: Array = live.keys()
	if _holding():
		for kind: String in _counts:
			if not kinds.has(kind): kinds.append(kind)
	kinds.sort_custom(func(a: String, b: String) -> bool: return HudModel.roster_key(a) < HudModel.roster_key(b))
	if kinds != _counts.keys():
		for row: Node in _rows.get_children(): row.free()
		for kind: String in kinds: _kind_row(kind)
	_counts = {}
	for kind: String in kinds:
		var sums: Array = live.get(kind, [0, 0, 1])
		_counts[kind] = sums[0]
		_fill_row(_rows.get_node("Row_" + kind), sums[0], float(sums[1]) / sums[2])
	var idle: int = _labels.values().filter(HudModel.is_idle).size()
	var header: String = "%d selected · %d %s" % [ids.size(), live.size(), "kind" if live.size() == 1 else "kinds"]
	if idle > 0: header += " · %d idle %s" % [idle, "collector" if idle == 1 else "collectors"]
	(_many.get_node("Header") as Label).text = header
	_many.get_node("Footer").visible = kinds.size() > 1
	_panel.visible = true
	_set_edge(View.owner_color(seat, bright))

func _kind_row(kind: String) -> void:
	var row := Button.new()
	row.name = "Row_" + kind
	row.focus_mode = FOCUS_NONE
	row.custom_minimum_size = Vector2(186, 26)
	row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for look: String in _row_looks: row.add_theme_stylebox_override(look, _row_looks[look])
	row.gui_input.connect(_row_input.bind(row, kind))
	# Deferred: a row freed under the pointer exits during the rebuild itself.
	row.mouse_exited.connect(_release_hold, CONNECT_DEFERRED)
	row.mouse_entered.connect(_inset_track.bind(row, true, 3.0))
	row.mouse_exited.connect(_inset_track.bind(row, false, 3.0))
	_rows.add_child(row)
	var title: Label = _label(row, "Name", &"HudRow", Registry.kind(kind).get("display_name", kind))
	title.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	title.offset_left = 8
	title.offset_right = -36
	title.offset_bottom = -4
	var count: Label = _label(row, "Count", &"HudNumber")
	count.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	count.offset_left = -36
	count.offset_right = -8
	count.offset_bottom = -4
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var track := ColorRect.new()
	track.name = "Track"
	track.color = get_theme_color("well", &"Tokens")
	track.mouse_filter = MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	track.offset_top = -3
	row.add_child(track)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	track.add_child(bar)

# A held row (its kind gone while the pointer is over the panel) reads 0, muted, with an empty bar.
func _fill_row(row: Button, count: int, fraction: float) -> void:
	(row.get_node("Count") as Label).text = str(count)
	var held: bool = count == 0
	if row.disabled != held:
		row.disabled = held
		row.mouse_default_cursor_shape = CURSOR_ARROW if held else CURSOR_POINTING_HAND
		for part: String in ["Name", "Count"]:
			if held: row.get_node(part).add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
			else: row.get_node(part).remove_theme_color_override("font_color")
	var bar: ColorRect = row.get_node("Track/Bar")
	var right: float = 0.0 if held else clampf(fraction, 0.0, 1.0)
	if bar.anchor_right != right: bar.anchor_right = right
	var colour: Color = View.health_color(right)
	if bar.color != colour: bar.color = colour

# The release reaches the pressed row wherever it lands, so only one inside that row counts.
func _row_input(event: InputEvent, row: Button, kind: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or click.pressed or _counts.get(kind, 0) == 0: return
	if not Rect2(Vector2.ZERO, row.size).has_point(click.position): return
	# Deferred: the repaint it causes may free this row, which is still inside its own input.
	row_clicked.emit.call_deferred(kind, click.shift_pressed)

# The track would cover the hover frame's bottom edge.
func _inset_track(row: Button, hovered: bool, height: float) -> void:
	var inset: float = 1.0 if hovered and not row.disabled else 0.0
	var track: Control = row.get_node("Track")
	track.offset_left = inset
	track.offset_right = -inset
	track.offset_bottom = -inset
	track.offset_top = -height - inset

func _set_edge(edge: Color) -> void:
	if _panel_style.border_color == edge: return
	_panel_style.border_color = edge
	_panel.queue_redraw()

func _show_panel(row: Dictionary, bright: bool) -> void:
	_panel.visible = not row.is_empty()
	if row.is_empty(): return
	_set_edge(get_theme_color("line", &"Tokens") if row.owner == -1 else View.owner_color(row.owner, bright))
	_panel.get_node("Box/Top/Name").text = row.name
	var right: Label = _panel.get_node("Box/Top/RightLabel")
	right.visible = row.has("right")
	_tint(right, row.get("right", ""), row.get("warn", false))
	var body: Node = _panel.get_node("Box/Body")
	_fill_bar(body.get_node("HealthRow"), row.has("health"), row.get("fraction", 0.0), View.health_color(row.get("fraction", 0.0)), row.get("health", ""))
	var progress: Color = get_theme_color("muted", &"Tokens") if row.get("paused", false) else _panel_style.border_color
	_fill_bar(body.get_node("ProgressRow"), row.has("percent"), row.get("percent", 0) / 100.0, progress, "%d %%" % row.get("percent", 0))
	body.get_node("KeyRow").visible = row.has("key")
	body.get_node("KeyRow/Key").text = row.get("key", "")
	body.get_node("KeyRow/Value").text = row.get("value", "")
	body.get_node("Footer").visible = row.has("footer")

func _fill_bar(row: Node, shown: bool, fraction: float, colour: Color, number: String) -> void:
	row.visible = shown
	if not shown: return
	var fill: ColorRect = row.get_child(0).get_node("Fill")
	fill.color = colour
	var right: float = clampf(fraction, 0.0, 1.0)
	if fill.anchor_right != right: fill.anchor_right = right
	(row.get_child(1) as Label).text = number
