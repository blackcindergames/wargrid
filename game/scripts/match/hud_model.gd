extends RefCounted

const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

static func unit_record(units: RefCounted, i: int) -> Dictionary:
	var target: Variant = units.target[i] if units.target[i] != -1 else null
	var combat: Variant = {"mode": units.modes[units.mode[i]], "target_id": target} if units.mode[i] != ViewRows.NONE else null
	var collection: Variant = {"enabled": (units.flags[i] & ViewRows.COLLECTING) != 0, "phase": units.phases[units.phase[i]]} if units.phase[i] != ViewRows.NONE else null
	return {"id": units.id[i], "owner": units.owner[i], "kind": units.kinds[units.kind[i]], "hp": units.hp[i], "max_hp": units.max_hp[i], "combat": combat, "collection": collection}

static func inspected(view: Dictionary, id: int) -> Dictionary:
	var i: int = view.units.index_of(id)
	if i != -1: return unit_record(view.units, i)
	return building(view, id)

static func building(view: Dictionary, id: int) -> Dictionary:
	for found: Dictionary in view.buildings:
		if found.id == id: return found
	return {}

static func player(view: Dictionary, id: int) -> Dictionary:
	for found: Dictionary in view.players:
		if found.id == id: return found
	return view.players[0]

static func menu_kinds(view: Dictionary, chosen: Dictionary, ids: Array[int], faction: String) -> Array:
	if not chosen.is_empty(): return Registry.kind(chosen.kind).produces if chosen.completed else []
	var kind: String = Registry.faction(faction).get("start_unit", "")
	if ids.size() == 1:
		var i: int = view.units.index_of(ids[0])
		var unit_kind: String = view.units.kinds[view.units.kind[i]] if i != -1 else ""
		if Registry.is_builder(unit_kind): kind = unit_kind
	return Registry.kind(kind).get("builds", [])

static func menu_label(index: int, kind: String) -> String:
	var quantity: int = Registry.kind(kind).get("quantity", 1)
	return "%d: %s%s $%d" % [index + 1, Registry.kind(kind).display_name, " x%d" % quantity if quantity > 1 else "", Registry.kind(kind).cost]

const LOW_POWER := "LOW POWER · DEFENCES OFF"
static var _powered: Dictionary = {}

static func strip(view: Dictionary, id: int, placement_kind: String) -> Dictionary:
	var found: Dictionary = player(view, id)
	var numbers: Dictionary = {"credits": found.credits, "used": found.power_demand, "available": found.power_supply}
	if placement_kind.is_empty(): return numbers
	var power: int = Registry.kind(placement_kind).get("power", 0)
	return numbers.merged({"after_credits": found.credits - Registry.kind(placement_kind).cost, "after_used": numbers.used + maxi(0, -power), "after_available": numbers.available + maxi(0, power)})

# FRC builds nothing that makes or uses power, so a 0 / 0 group would read like a bug.
static func uses_power(faction: String) -> bool:
	if not _powered.has(faction):
		var row: Dictionary = Registry.faction(faction)
		var kinds: Array = Registry.kind(row.get("start_unit", "")).get("builds", []) + [row.get("start_building", "")]
		_powered[faction] = kinds.any(func(kind: String) -> bool: return Registry.kind(kind).get("power", 0) != 0)
	return _powered[faction]

# Physical keycodes: orders read their keys here and the buttons print them, so a label never names an unused key.
const ORDER_KEYS := {"attack_move": KEY_A, "stop": KEY_S, "unload": KEY_F, "produce": KEY_E}
const SLAB_WIDTH: float = 432.0
const SLAB_CONTENT: float = SLAB_WIDTH - 20.0
const MENU_PADDING: float = 24.0
const MENU_GAP: float = 4.0

const QUEUE_SHOWN: int = 5
const QUEUE_COLLAPSED: int = 4

# A seam so the layout path runs headless; tests swap it and restore it on every path.
static var layout_label: Callable = _platform_label

# Headless and web report no layout, and the label call errors there.
static func _platform_label(physical: Key) -> Key:
	if DisplayServer.keyboard_get_layout_count() > 0: return DisplayServer.keyboard_get_label_from_physical(physical)
	return physical

static func key_text(label: Key) -> String:
	return OS.get_keycode_string(label)

static func key_label(physical: Key) -> String:
	return key_text(layout_label.call(physical))

static func menu_name(index: int, kind: String) -> String:
	var quantity: int = Registry.kind(kind).get("quantity", 1)
	return "%d: %s%s" % [index + 1, Registry.kind(kind).display_name, " x%d" % quantity if quantity > 1 else ""]

# Each faction's builds, and what each of those and the start building produce.
static func _every_menu() -> Array:
	var menus: Array = []
	for faction: String in Registry.Factions.FACTIONS:
		var row: Dictionary = Registry.faction(faction)
		var builds: Array = Registry.kind(row.get("start_unit", "")).get("builds", [])
		menus.append(builds)
		for kind: String in builds + [row.get("start_building", "")]: menus.append(Registry.kind(kind).get("produces", []))
	return menus

static func menu_columns(font: Font, size: int) -> int:
	var widest: float = 0.0
	for kinds: Array in _every_menu():
		for i in kinds.size(): widest = maxf(widest, font.get_string_size(menu_label(i, kinds[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	for columns: int in [4, 3, 2]:
		if columns * (widest + MENU_PADDING) + (columns - 1) * MENU_GAP <= SLAB_CONTENT: return columns
	return 1

static func _unit_index(view: Dictionary, id: int) -> int:
	return view.units.index_of(id)

static func is_container(view: Dictionary, id: int, seat: int) -> bool:
	var host: Dictionary = building(view, id)
	if host.is_empty():
		var i: int = _unit_index(view, id)
		if i == -1: return false
		host = {"owner": view.units.owner[i], "kind": view.units.kinds[view.units.kind[i]]}
	return host.owner == seat and host.get("completed", true) and not Registry.kind(host.kind).get("contains", {}).is_empty()

# The view has no container id, so a vehicle counts as loaded while any own unit rides anything.
static func unload_target(view: Dictionary, selection: Dictionary, seat: int) -> int:
	var id: int = selection.building_id if selection.building_id != -1 else (selection.ids[0] if selection.ids.size() == 1 else -1)
	if not is_container(view, id, seat): return -1
	if not building(view, id).is_empty(): return id if not player(view, seat).get("tunnel", []).is_empty() else -1
	var units: RefCounted = view.units
	for i: int in units.size():
		if units.owner[i] == seat and (units.flags[i] & ViewRows.CONTAINED) != 0: return id
	return -1

static func has_armed_unit(view: Dictionary, ids: Array[int], seat: int) -> bool:
	for id: int in ids:
		var i: int = _unit_index(view, id)
		if i != -1 and view.units.owner[i] == seat and not Registry.kind(view.units.kinds[view.units.kind[i]]).get("weapon", "").is_empty(): return true
	return false

# Every build button shown with a selection is one placement accepts (orders' `_builder()` rule).
static func shows_build_menu(view: Dictionary, selection: Dictionary, seat: int) -> bool:
	if selection.building_id != -1 or selection.ids.is_empty(): return true
	if selection.ids.size() != 1: return false
	var i: int = _unit_index(view, selection.ids[0])
	return i != -1 and view.units.owner[i] == seat and Registry.is_builder(view.units.kinds[view.units.kind[i]])

static func queue_rows(count: int, open: bool) -> Dictionary:
	var capped: bool = count > QUEUE_SHOWN
	return {"shown": QUEUE_COLLAPSED if capped and not open else count, "more": count - QUEUE_COLLAPSED if capped else 0}
