extends Control

signal menu_chosen(index: int)
signal entry_cancelled(entry_id: int)
signal produce_pressed()
signal cancel_build_pressed()

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

func _init() -> void:
	name = "Hud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

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
	if _economy == null: menu_kinds = kinds
	else: _economy_controls(building, selection, kinds)
	if _status == null: return
	_status.text = _status_text(view, selection, building, HudModel.player(view, view_player), seat)
	if _economy != null: _economy.position.y = maxf(116.0, _status.position.y + _status.get_minimum_size().y + 8.0)

func _economy_controls(building: Dictionary, selection: Dictionary, kinds: Array) -> void:
	_produce.visible = not building.is_empty() and building.completed and not selection.production_kind.is_empty()
	_produce.text = "Produce %s (E)" % Registry.kind(selection.production_kind).get("display_name", "") if not building.is_empty() else "Produce (E)"
	_cancel_build.visible = not building.is_empty() and not building.completed
	_refresh_menu(kinds)
	_refresh_queue(building.get("queue", []))

func _status_text(view: Dictionary, selection: Dictionary, building: Dictionary, player: Dictionary, seat: int) -> String:
	var detail: String = "Units: " + str(selection.ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [Registry.kind(building.kind).display_name, building.id, building.work, Definitions.building(building.kind).ticks * 1000]
	var resume: String = "Right-click: resume\n" if selection.resume_id != -1 else ""
	var placing: String = Registry.kind(selection.placement_kind).get("display_name", "")
	var text: String = "Credits: %d | Power: %d/%d | Tick: %d\n%s | Place: %s\n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n%s%s" % [player.credits, player.power_supply, player.power_demand, view.tick, detail, placing, resume, note]
	text += "\n" + _selected_summary(view, selection.ids) + _enemy_summary(view, selection.inspected_id)
	if not selection.over: text += "A: attack-move click | S: stop | You are %s (P%d)" % ["blue" if seat == 1 else "red", seat]
	if not selection.notice.is_empty(): text += "\n" + selection.notice
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
