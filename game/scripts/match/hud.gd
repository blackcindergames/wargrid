extends Control

signal menu_chosen(index: int)
signal entry_cancelled(entry_id: int)
signal produce_pressed()
signal cancel_build_pressed()
signal menu_pressed()

# Wider notices wrap, so a long desync path grows down, clear of the chips at 1280.
const NOTICE_WIDTH: float = 600.0

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
	_build_menu = economy.get_node("BuildMenu")
	_queue = economy.get_node("Queue")
	_produce = economy.get_node("Produce")
	_cancel_build = economy.get_node("CancelBuild")
	_produce.pressed.connect(produce_pressed.emit)
	_cancel_build.pressed.connect(cancel_build_pressed.emit)

func reset() -> void:
	note = ""
	refusal = ""

func update_hud(view: Dictionary, selection: Dictionary, view_player: int, seat: int) -> void:
	var building: Dictionary = HudModel.building(view, selection.building_id)
	var faction: String = HudModel.player(view, seat).get("faction", Registry.Factions.DEFAULT_FACTION)
	var kinds: Array = HudModel.menu_kinds(view, building, selection.ids, faction)
	_show_strip(view, selection, view_player)
	set_esc_chip(selection.esc_opens_menu)
	_show_notice(selection.notice)
	if _economy == null: menu_kinds = kinds
	else: _economy_controls(building, selection, kinds)
	if _status == null: return
	_status.text = _status_text(view, selection, building)
	if _economy != null: _economy.position.y = maxf(116.0, _status.position.y + _status.get_minimum_size().y + 8.0)

func _economy_controls(building: Dictionary, selection: Dictionary, kinds: Array) -> void:
	_produce.visible = not building.is_empty() and building.completed and not selection.production_kind.is_empty()
	_produce.text = "Produce %s (E)" % Registry.kind(selection.production_kind).get("display_name", "") if not building.is_empty() else "Produce (E)"
	_cancel_build.visible = not building.is_empty() and not building.completed
	_refresh_menu(kinds)
	_refresh_queue(building.get("queue", []))

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

func _status_text(view: Dictionary, selection: Dictionary, building: Dictionary) -> String:
	var detail: String = "Units: " + str(selection.ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [Registry.kind(building.kind).display_name, building.id, building.work, Definitions.building(building.kind).ticks * 1000]
	var resume: String = "Right-click: resume\n" if selection.resume_id != -1 else ""
	var placing: String = Registry.kind(selection.placement_kind).get("display_name", "")
	var text: String = "%s | Place: %s\n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n%s%s" % [detail, placing, resume, note]
	text += "\n" + _selected_summary(view, selection.ids) + _enemy_summary(view, selection.inspected_id)
	if not selection.over: text += "A: attack-move click | S: stop"
	return text

func _refresh_menu(kinds: Array) -> void:
	menu_kinds = kinds
	var grid: GridContainer = _build_menu
	while grid.get_child_count() > kinds.size(): grid.get_child(grid.get_child_count() - 1).free()
	for i in kinds.size():
		var button: Button = grid.get_child(i) if i < grid.get_child_count() else null
		if button == null:
			button = Button.new()
			button.theme_type_variation = &"HudSmallButton"
			button.pressed.connect(menu_chosen.emit.bind(i))
			grid.add_child(button)
		button.text = HudModel.menu_label(i, kinds[i])

func _refresh_queue(queue: Array) -> void:
	var ids: Array = queue.map(func(entry: Dictionary) -> String: return str(entry.id))
	for child in _queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for entry: Variant in queue:
		var button: Button = _queue.get_node_or_null(str(entry.id))
		if button == null:
			button = Button.new()
			button.theme_type_variation = &"HudSmallButton"
			button.name = str(entry.id)
			button.pressed.connect(entry_cancelled.emit.bind(entry.id))
			_queue.add_child(button)
		button.text = queue_label(entry)

static func queue_label(entry: Dictionary) -> String:
	var label: String = Registry.kind(entry.kind).display_name
	if entry.work == 0: return "Cancel %s (queued)" % label
	return "Cancel %s (%d%%)" % [label, entry.work * 100 / (Definitions.unit(entry.kind).ticks * 1000)]

func _selected_summary(view: Dictionary, ids: Array[int]) -> String:
	if ids.size() != 1: return ""
	var i: int = view.units.index_of(ids[0])
	if i == -1: return ""
	var unit: Dictionary = HudModel.unit_record(view.units, i)
	var line: String = "%s #%d HP %d/%d" % [Registry.kind(unit.kind).display_name, unit.id, unit.hp / 1000, unit.max_hp / 1000]
	if unit.combat != null: line += " | %s%s" % [unit.combat.mode, "" if unit.combat.target_id == null else " -> #" + str(unit.combat.target_id)]
	if unit.collection != null and unit.collection.enabled: line += _collection_suffix(view, unit)
	return line + "\n"

func _collection_suffix(view: Dictionary, unit: Dictionary) -> String:
	var line: String = " | " + unit.collection.phase
	if unit.collection.phase.begins_with("waiting_"): line += " (%s in line)" % _ordinal(View.line_position(view.units, view.units.index_of(unit.id)))
	return line

func _ordinal(n: int) -> String:
	var suffix: String = "th" if n % 100 in [11, 12, 13] else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix

func _enemy_summary(view: Dictionary, inspected_id: int) -> String:
	var object: Dictionary = HudModel.inspected(view, inspected_id)
	if object.is_empty(): return ""
	var line: String = "Enemy (P%d) %s #%d HP %d/%d" % [object.owner, Registry.kind(object.kind).display_name, object.id, object.hp / 1000, object.max_hp / 1000]
	var combat: Variant = object.get("combat")
	if combat != null: line += " | " + combat.mode + ("" if combat.target_id == null else " -> #%d" % combat.target_id)
	return line + "\n"
