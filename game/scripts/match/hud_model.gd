extends RefCounted

const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")

static func unit_record(units: RefCounted, i: int) -> Dictionary:
	var collection: Variant = {"enabled": (units.flags[i] & ViewRows.COLLECTING) != 0, "phase": units.phases[units.phase[i]]} if units.phase[i] != ViewRows.NONE else null
	return {"id": units.id[i], "owner": units.owner[i], "kind": units.kinds[units.kind[i]], "hp": units.hp[i], "max_hp": units.max_hp[i], "collection": collection}

static func inspected(view: Dictionary, id: int) -> Dictionary:
	var i: int = view.units.index_of(id)
	if i != -1: return unit_record(view.units, i)
	var found: Dictionary = building(view, id)
	if not found.is_empty(): return found
	for source: Dictionary in view.get("sources", []):
		if source.id == id: return source
	return {}

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

const SITE := "UNDER CONSTRUCTION"
const PAUSED := "PAUSED · NO BUILDER"
const OFFLINE := "OFFLINE · LOW POWER"
const RALLY := "Right-click ground: rally point"

# The selection panel's one object: the building, else one unit, else the inspected object; several units are the kind rows'.
# `labels` holds the selected own collectors' labels (`collector_labels`).
static func panel(view: Dictionary, selection: Dictionary, seat: int, faction: String, labels: Dictionary = {}) -> Dictionary:
	var id: int = selection.building_id
	if id == -1 and selection.ids.size() == 1: id = selection.ids[0]
	elif id == -1 and selection.ids.is_empty(): id = selection.inspected_id
	var object: Dictionary = inspected(view, id) if id != -1 else {}
	if object.is_empty(): return {}
	if object.has("boxes"):
		var credits: int = object.boxes * box_value(faction)
		return {"name": "Supply Pile", "owner": -1, "key": "CREDITS LEFT", "value": str(credits) if credits > 0 else "Empty"}
	var row: Dictionary = {"name": Registry.kind(object.kind).display_name, "owner": object.owner, "health": "%d / %d" % [ceili(object.hp / 1000.0), ceili(object.max_hp / 1000.0)], "fraction": float(object.hp) / object.max_hp}
	if not object.has("completed"):
		if not labels.get(object.id, "").is_empty(): row.right = labels[object.id]
		return row
	var own: bool = object.owner == seat
	if not object.completed:
		var paused: bool = own and object.builder_id == null
		return row.merged({"right": PAUSED if paused else SITE, "paused": paused, "percent": object.work * 100 / (Definitions.building(object.kind).ticks * 1000)})
	if Registry.kind(object.kind).get("powered", false) and short_of_power(view, object.owner): row.merge({"right": OFFLINE, "warn": true})
	if not own: return row
	var power: int = Registry.kind(object.kind).get("power", 0)
	if power > 0: row.merge({"key": "POWER", "value": "+%d" % power})
	if Registry.can_rally(object.kind): row.footer = RALLY
	return row

# combat.gd's `_short_of_power`, read from the view's player rows.
static func short_of_power(view: Dictionary, owner: int) -> bool:
	var found: Dictionary = player(view, owner)
	return found.id == owner and found.power_demand > found.power_supply

# What one box pays the viewer: the box value of their faction's collector.
static func box_value(faction: String) -> int:
	var row: Dictionary = Registry.faction(faction)
	var kinds: Array = [row.get("start_unit", "")]
	for building_kind: String in Registry.kind(row.get("start_unit", "")).get("builds", []) + [row.get("start_building", "")]: kinds.append_array(Registry.kind(building_kind).get("produces", []))
	for kind: String in kinds:
		if not Registry.collects(kind).is_empty(): return Registry.collects(kind).box_value
	return 0

const ROWS_RULE := "Click a kind: select only that kind · Shift-click: deselect it"
const IDLE := "IDLE"
const WAITING_AT_PILE := "WAITING AT PILE"
# Every phase the simulation publishes; seeking and idle are decided in `collector_label`.
const PHASE_LABELS := {"flying_source": "TO PILE", "lead_source": "TO PILE", "waiting_source": WAITING_AT_PILE, "loading": "LOADING", "flying_depot": "TO <DROP-OFF>", "lead_depot": "TO <DROP-OFF>", "waiting_depot": "WAITING AT <DROP-OFF>", "unloading": "UNLOADING", "seeking": "", "idle": ""}
static var _drop_offs: Dictionary = {}

# Combat vehicles and aircraft, infantry, collectors, builders; then the kind id (the HUD v5 picture's order).
static func roster_key(kind: String) -> String:
	var row: Dictionary = Registry.kind(kind)
	var group: int = 0
	if not row.get("builds", []).is_empty(): group = 3
	elif not Registry.collects(kind).is_empty(): group = 2
	elif row.get("class", "") == "infantry": group = 1
	return "%d %s" % [group, kind]

# Kind to [count, sum of hp, sum of max_hp] over the selected units.
static func kind_rows(view: Dictionary, ids: Array[int]) -> Dictionary:
	var rows: Dictionary = {}
	var units: RefCounted = view.units
	for id: int in ids:
		var i: int = units.index_of(id)
		if i == -1: continue
		var kind: String = units.kinds[units.kind[i]]
		if not rows.has(kind): rows[kind] = [0, 0, 0]
		var row: Array = rows[kind]
		row[0] += 1
		row[1] += units.hp[i]
		row[2] += units.max_hp[i]
	return rows

# The uppercased name of the viewer faction's building that receives supply.
static func drop_off(faction: String) -> String:
	if not _drop_offs.has(faction):
		var row: Dictionary = Registry.faction(faction)
		var kinds: Array = Registry.kind(row.get("start_unit", "")).get("builds", []) + [row.get("start_building", "")]
		_drop_offs[faction] = ""
		for kind: String in kinds:
			if Registry.kind(kind).get("receives_supply", false): _drop_offs[faction] = Registry.kind(kind).display_name.to_upper()
	return _drop_offs[faction]

# The selected own collectors' labels; `previous` carries the last label through a `seeking` tick.
static func collector_labels(view: Dictionary, ids: Array[int], seat: int, previous: Dictionary) -> Dictionary:
	var labels: Dictionary = {}
	var units: RefCounted = view.units
	var found: Array[int] = []
	for id: int in ids:
		var i: int = units.index_of(id)
		if i != -1 and units.owner[i] == seat and not Registry.collects(units.kinds[units.kind[i]]).is_empty(): found.append(i)
	if found.is_empty(): return labels
	# One pass over buildings and piles per update, not one per collector.
	var builders: Dictionary = {}
	for site: Dictionary in view.buildings:
		if not site.completed: builders[site.get("builder_id")] = true
	var boxes_left: bool = view.get("sources", []).any(func(source: Dictionary) -> bool: return source.boxes > 0)
	for i: int in found: labels[units.id[i]] = collector_label(view, i, previous.get(units.id[i], ""), builders, boxes_left)
	return labels

static func collector_label(view: Dictionary, i: int, previous: String, builders: Dictionary, boxes_left: bool) -> String:
	var units: RefCounted = view.units
	if units.flags[i] & ViewRows.COLLECTING:
		var phase: String = units.phases[units.phase[i]]
		if phase == "seeking": return previous
		# Idle while collecting is a retry at a busy dock while a pile still holds boxes.
		if phase == "idle": return WAITING_AT_PILE if boxes_left else IDLE
		return PHASE_LABELS[phase].replace("<DROP-OFF>", drop_off(player(view, units.owner[i]).get("faction", Registry.Factions.DEFAULT_FACTION)))
	var status: int = units.status[i]
	if status != ViewRows.NONE and ViewRows.STATUSES[status] in ["moving", "path_pending"]: return "MOVING"
	if builders.has(units.id[i]): return "BUILDING"
	return "" if units.flags[i] & ViewRows.CONTAINED else IDLE
