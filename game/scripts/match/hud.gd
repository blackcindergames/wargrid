extends Control

signal menu_chosen(index: int)
signal entry_cancelled(entry_id: int)
signal produce_pressed()
signal cancel_build_pressed()
signal menu_pressed()
signal attack_move_pressed()
signal stop_pressed()
signal unload_pressed()

# Wider notices wrap, so a long desync path grows down, clear of the chips at 1280.
const NOTICE_WIDTH: float = 600.0
const PAD_LEFT: float = 12.0
const PAD_Y: float = 8.0
const GAP: int = 4
const ROW: float = 32.0

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")

var refusal: String = ""
var note: String = ""
var rebuilds: int = 0
var menu_kinds: Array = []
var _status: Label
var _economy: VBoxContainer
var _build_menu: GridContainer
var _queue: Control
var _produce: Button
var _cancel_build: Button
var _top_strip: PanelContainer
var _forecast: PanelContainer
var _menu: Button
var _notice: PanelContainer
var _notice_text: Label
var _esc: Label
var _resume: Label
var _commands: GridContainer
var _queue_header: HBoxContainer
var _queue_more: Button
var _queue_open: bool = false
var _queue_for: int = -1
var _edge: Color = Color.WHITE
var _keys: Dictionary = {}
var _panel: PanelContainer
var _panel_style: StyleBoxFlat

func _init() -> void:
	name = "Hud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_top_strip = _slab("TopStrip", Vector2(8, 8))
	_forecast = _slab("Forecast", Vector2(8, 48))
	_build_strip()
	_build_forecast()
	_build_menu_chip()
	_build_notice()
	_build_panel()

# Mouse-transparent until the HUD routing task decides what the panels catch.
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

# Groups 24 apart, label to value 8 (hud-v5-layout "Top strip").
func _groups(parent: Control, value: StringName) -> void:
	var row: BoxContainer = _box(parent, "Row", HBoxContainer.new(), 24)
	var credits: BoxContainer = _box(row, "CreditsGroup", HBoxContainer.new(), 8)
	_label(credits, "CreditsLabel", &"HudLabel", "CREDITS")
	_label(credits, "Credits", &"HudCredits")
	var power: BoxContainer = _box(row, "PowerGroup", HBoxContainer.new(), 8)
	_label(power, "PowerLabel", &"HudLabel", "POWER")
	_label(power, "Power", value)
	_label(power, "LowPower", &"HudLabel", HudModel.LOW_POWER).add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))

# A one-line slab: no vertical padding, a fixed height that centres its line.
func _flat(slab: PanelContainer, height: float) -> void:
	var style := get_theme_stylebox("panel", &"HudSlab").duplicate() as StyleBoxFlat
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	slab.add_theme_stylebox_override("panel", style)
	slab.custom_minimum_size.y = height

func _build_strip() -> void:
	_flat(_top_strip, 32)
	_groups(_top_strip, &"HudNumber")
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(8, 8)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	swatch.mouse_filter = MOUSE_FILTER_IGNORE
	_top_strip.get_node("Row/CreditsGroup").add_child(swatch)
	_top_strip.get_node("Row/CreditsGroup").move_child(swatch, 0)

func _build_forecast() -> void:
	var box: BoxContainer = _box(_forecast, "Box", VBoxContainer.new(), 4)
	_label(box, "Title", &"HudLabel", "AFTER PURCHASE")
	_groups(box, &"HudCredits")
	_forecast.visible = false

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

# Esc's first job is to back out of a selection, placement or form; the chip says so only when it opens the menu.
func set_esc_chip(shown: bool) -> void:
	_esc.visible = shown

func setup(economy: VBoxContainer, status: Label) -> void:
	_status = status
	_economy = economy
	if economy == null: return
	_queue = economy.get_node("Queue")
	_produce = economy.get_node("Produce")
	_cancel_build = economy.get_node("CancelBuild")
	_produce.pressed.connect(produce_pressed.emit)
	_cancel_build.pressed.connect(cancel_build_pressed.emit)
	_build_slab()
	_read_keys()

func reset() -> void:
	note = ""
	refusal = ""
	if _economy != null: _read_keys()

# hud-v5-layout "Command card": the VBox lays out rows, the Hud pads, fills and edges it.
func _build_slab() -> void:
	_economy.alignment = BoxContainer.ALIGNMENT_CENTER
	_economy.add_theme_constant_override("separation", GAP)
	_economy.draw.connect(_draw_slab)
	_economy.sort_children.connect(_pad_slab)
	_resume = _label(_economy, "ResumeHint", &"HudHint", "Right-click: resume")
	_commands = _grid("Orders", 2)
	for part: Array in [["AttackMove", attack_move_pressed], ["Stop", stop_pressed], ["Unload", unload_pressed]]:
		var button: Button = _button(_commands, part[0], _cell_width(2))
		button.focus_mode = FOCUS_NONE
		button.pressed.connect((part[1] as Signal).emit)
	var font: Font = get_theme_font("font", &"HudButton")
	_build_menu = _grid("BuildMenu", HudModel.menu_columns(font, get_theme_font_size("font_size", &"HudButton")))
	for row: Button in [_produce, _cancel_build]: _square(row)
	_queue_header = _box(_economy, "QueueHeader", HBoxContainer.new(), 8) as HBoxContainer
	_label(_queue_header, "Title", &"HudLabel", "QUEUE").size_flags_horizontal = SIZE_EXPAND_FILL
	_label(_queue_header, "Waiting", &"HudHint")
	(_queue as BoxContainer).add_theme_constant_override("separation", GAP)
	_queue_more = _button(_economy, "QueueMore", 0.0)
	_queue_more.add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
	_queue_more.add_theme_color_override("font_hover_color", get_theme_color("muted", &"Tokens"))
	_queue_more.draw.connect(_draw_chevron)
	_queue_more.pressed.connect(_toggle_queue)
	var rows: Array[Control] = [_resume, _commands, _build_menu, _produce, _cancel_build, _queue_header, _queue, _queue_more]
	for i in rows.size(): _economy.move_child(rows[i], i)

func _read_keys() -> void:
	for action: String in HudModel.ORDER_KEYS: _keys[action] = HudModel.key_label(HudModel.ORDER_KEYS[action])
	(_commands.get_node("AttackMove") as Button).text = "Attack move (%s)" % _keys.attack_move
	(_commands.get_node("Stop") as Button).text = "Stop (%s)" % _keys.stop
	(_commands.get_node("Unload") as Button).text = "Unload (%s)" % _keys.unload

func _grid(grid_name: String, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = columns
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	_economy.add_child(grid)
	return grid

func _cell_width(columns: int) -> float:
	return (HudModel.SLAB_CONTENT - (columns - 1) * GAP) / columns

static func _square(button: Button) -> void:
	button.theme_type_variation = &"HudButton"
	button.custom_minimum_size.y = ROW

func _button(parent: Control, button_name: String, width: float) -> Button:
	var button := Button.new()
	button.name = button_name
	_square(button)
	button.custom_minimum_size.x = width
	parent.add_child(button)
	return button

# A label pinned inside a button's right padding; the button keeps the click.
static func _right_label(button: Button, label_name: String, variation: StringName, right: float) -> Label:
	var label: Label = _label(button, label_name, variation)
	label.set_anchors_preset(PRESET_RIGHT_WIDE)
	label.grow_horizontal = GROW_DIRECTION_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.offset_left = right
	label.offset_right = right
	return label

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
	var faction: String = HudModel.player(view, seat).get("faction", Registry.Factions.DEFAULT_FACTION)
	var kinds: Array = HudModel.menu_kinds(view, building, selection.ids, faction)
	_show_strip(view, selection, view_player)
	set_esc_chip(selection.esc_opens_menu)
	_show_notice(selection.notice)
	_show_panel(HudModel.panel(view, selection, seat, faction), selection.bright_owners)
	if _economy == null: menu_kinds = kinds
	else: _economy_controls(view, building, selection, kinds, seat)
	if _status == null: return
	_status.text = _status_text(view, selection)

func _economy_controls(view: Dictionary, building: Dictionary, selection: Dictionary, kinds: Array, seat: int) -> void:
	var edge: Color = View.owner_color(seat, selection.bright_owners)
	_resume.visible = selection.resume_id != -1
	_show_commands(view, selection, seat)
	_produce.visible = not building.is_empty() and building.completed and not selection.production_kind.is_empty()
	_produce.text = "Produce %s (%s)" % [Registry.kind(selection.production_kind).get("display_name", ""), _keys.produce] if not building.is_empty() else "Produce (%s)" % _keys.produce
	_cancel_build.visible = not building.is_empty() and not building.completed
	_refresh_menu(kinds, HudModel.shows_build_menu(view, selection, seat), HudModel.player(view, seat).get("credits", 0), selection.placement_kind)
	if edge != _edge:
		_edge = edge
		for row: Node in _queue.get_children(): (row.get_node("Track/Bar") as ColorRect).color = edge
	_refresh_queue(building, edge)
	_fit_slab()

# The keys keep today's paths for any own selection; only the buttons follow the row rule.
func _show_commands(view: Dictionary, selection: Dictionary, seat: int) -> void:
	var armed: bool = HudModel.has_armed_unit(view, selection.ids, seat)
	var unload: bool = HudModel.unload_target(view, selection, seat) != -1
	_commands.get_node("AttackMove").visible = armed
	_commands.get_node("Stop").visible = armed
	_commands.get_node("Unload").visible = unload
	_commands.visible = armed or unload
	_look(_commands.get_node("AttackMove"), selection.attack_move)

static func _look(button: Button, armed: bool) -> void:
	var look: StringName = &"HudButtonArmed" if armed else &"HudButton"
	if button.theme_type_variation != look: button.theme_type_variation = look

func _show_strip(view: Dictionary, selection: Dictionary, view_player: int) -> void:
	var numbers: Dictionary = HudModel.strip(view, view_player, selection.placement_kind)
	var powered: bool = HudModel.uses_power(HudModel.player(view, view_player).get("faction", Registry.Factions.DEFAULT_FACTION))
	(_top_strip.get_node("Row/CreditsGroup/Swatch") as ColorRect).color = View.owner_color(view_player, selection.bright_owners)
	_fill(_top_strip, str(numbers.credits), false, numbers.used, numbers.available, powered)
	_forecast.visible = numbers.has("after_credits")
	if _forecast.visible:
		var credits: int = numbers.after_credits
		_fill(_forecast, str(credits) if credits >= 0 else "\u2212%d" % -credits, credits < 0, numbers.after_used, numbers.after_available, powered)

func _fill(slab: PanelContainer, credits: String, short: bool, used: int, available: int, powered: bool) -> void:
	var low: bool = used > available
	_tint(slab.find_child("Credits", true, false), credits, short)
	_tint(slab.find_child("Power", true, false), "%d / %d" % [used, available], low)
	slab.find_child("LowPower", true, false).visible = low
	slab.find_child("PowerGroup", true, false).visible = powered
	slab.reset_size()

func _tint(label: Label, text: String, warn: bool) -> void:
	label.text = text
	# Each override write re-themes the label, so only a flip may touch it.
	if label.has_theme_color_override("font_color") == warn: return
	if warn: label.add_theme_color_override("font_color", get_theme_color("warn", &"Tokens"))
	else: label.remove_theme_color_override("font_color")

# Only the collector phase is left here until the kind rows carry it (Task 11).
func _status_text(view: Dictionary, selection: Dictionary) -> String:
	var phase: String = ""
	var i: int = view.units.index_of(selection.ids[0]) if selection.ids.size() == 1 else -1
	if i != -1:
		var unit: Dictionary = HudModel.unit_record(view.units, i)
		if unit.collection != null and unit.collection.enabled: phase = _collection_suffix(view, unit)
	return "%s\n%s" % [note, phase]

func _refresh_menu(kinds: Array, shown: bool, credits: int, placement_kind: String) -> void:
	menu_kinds = kinds
	var grid: GridContainer = _build_menu
	grid.visible = shown and not kinds.is_empty()
	while grid.get_child_count() > kinds.size(): grid.get_child(grid.get_child_count() - 1).free()
	for i in kinds.size():
		var button: Button = grid.get_child(i) if i < grid.get_child_count() else null
		if button == null:
			button = _button(grid, "Item%d" % i, _cell_width(grid.columns))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(menu_chosen.emit.bind(i))
			_right_label(button, "Price", &"HudRow", -12.0)
		var cost: int = Registry.kind(kinds[i]).cost
		button.text = HudModel.menu_name(i, kinds[i])
		_tint(button.get_node("Price"), "$%d" % cost, cost > credits)
		_look(button, kinds[i] == placement_kind)

func _refresh_queue(building: Dictionary, edge: Color) -> void:
	var queue: Array = building.get("queue", [])
	if building.get("id", -1) != _queue_for or queue.size() <= HudModel.QUEUE_SHOWN: _queue_open = false
	_queue_for = building.get("id", -1)
	var ids: Array = queue.map(func(entry: Dictionary) -> String: return str(entry.id))
	for child in _queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for i in queue.size():
		var entry: Dictionary = queue[i]
		var button: Button = _queue.get_node_or_null(str(entry.id))
		if button == null: button = _queue_row(entry.id, edge)
		var parts: PackedStringArray = queue_parts(entry)
		button.text = parts[0]
		var percent: Label = button.get_node("Percent")
		percent.text = parts[1]
		percent.visible = i == 0 and not parts[1].is_empty()
		var track: ColorRect = button.get_node("Track")
		track.visible = i == 0
		(track.get_node("Bar") as ColorRect).set_anchor(SIDE_RIGHT, minf(1.0, float(entry.work) / (Definitions.unit(entry.kind).ticks * 1000)), true)
	_queue.visible = not queue.is_empty()
	_queue_header.visible = not queue.is_empty()
	var waiting: Label = _queue_header.get_node("Waiting")
	waiting.text = "%d waiting" % (queue.size() - 1)
	waiting.visible = queue.size() > 1
	_show_queue_rows()

# The whole row cancels, as Zero Hour's queue button does; the × is only its sign.
func _queue_row(entry_id: int, edge: Color) -> Button:
	var button: Button = _button(_queue, str(entry_id), 0.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(entry_cancelled.emit.bind(entry_id))
	var cancel: Label = _right_label(button, "Cancel", &"HudHint", -12.0)
	cancel.text = "\u00d7"
	_right_label(button, "Percent", &"HudHint", -12.0 - cancel.get_combined_minimum_size().x - 8.0)
	var track := ColorRect.new()
	track.name = "Track"
	track.color = get_theme_color("well", &"Tokens")
	track.mouse_filter = MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	track.offset_top = -2
	button.add_child(track)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.color = edge
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	track.add_child(bar)
	return button

func _show_queue_rows() -> void:
	var rows: Dictionary = HudModel.queue_rows(_queue.get_child_count(), _queue_open)
	for i in _queue.get_child_count(): (_queue.get_child(i) as Control).visible = i < rows.shown
	_queue_more.visible = rows.more > 0
	_queue_more.text = "Show fewer" if _queue_open else "Show %d more queued" % rows.more

func _toggle_queue() -> void:
	_queue_open = not _queue_open
	_show_queue_rows()
	_fit_slab()

# Public Sans has no chevron glyph, so it is drawn after the centred text.
func _draw_chevron() -> void:
	var font: Font = _queue_more.get_theme_font("font")
	var font_size: int = _queue_more.get_theme_font_size("font_size")
	var x: float = (_queue_more.size.x + font.get_string_size(_queue_more.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2.0 + 8.0
	var y: float = _queue_more.size.y / 2.0
	var tip: float = -3.0 if _queue_open else 3.0
	_queue_more.draw_polyline([Vector2(x, y - tip), Vector2(x + 4.0, y + tip), Vector2(x + 8.0, y - tip)], get_theme_color("muted", &"Tokens"), 1.5, true)

static func queue_parts(entry: Dictionary) -> PackedStringArray:
	var percent: String = "" if entry.work == 0 else "%d %%" % (entry.work * 100 / (Definitions.unit(entry.kind).ticks * 1000))
	return PackedStringArray([Registry.kind(entry.kind).display_name, percent])

func _collection_suffix(view: Dictionary, unit: Dictionary) -> String:
	var line: String = " | " + unit.collection.phase
	if unit.collection.phase.begins_with("waiting_"): line += " (%s in line)" % _ordinal(View.line_position(view.units, view.units.index_of(unit.id)))
	return line

func _ordinal(n: int) -> String:
	var suffix: String = "th" if n % 100 in [11, 12, 13] else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix

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
	_label(body, "Footer", &"HudHint", HudModel.RALLY)
	_panel.visible = false

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

func _show_panel(row: Dictionary, bright: bool) -> void:
	_panel.visible = not row.is_empty()
	if row.is_empty(): return
	var edge: Color = get_theme_color("line", &"Tokens") if row.owner == -1 else View.owner_color(row.owner, bright)
	if _panel_style.border_color != edge:
		_panel_style.border_color = edge
		_panel.queue_redraw()
	_panel.get_node("Box/Top/Name").text = row.name
	var right: Label = _panel.get_node("Box/Top/RightLabel")
	right.visible = row.has("right")
	_tint(right, row.get("right", ""), row.get("warn", false))
	var body: Node = _panel.get_node("Box/Body")
	_fill_bar(body.get_node("HealthRow"), row.has("health"), row.get("fraction", 0.0), View.health_color(row.get("fraction", 0.0)), row.get("health", ""))
	var progress: Color = get_theme_color("muted", &"Tokens") if row.get("paused", false) else edge
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
