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

# H: the faction's start building, lowest id; else the costliest own one, lowest id. Holes and sites do not count.
static func home_building(view: Dictionary, seat: int) -> Dictionary:
	var start: String = Registry.faction(player(view, seat).get("faction", Registry.Factions.DEFAULT_FACTION)).get("start_building", "")
	var best: Dictionary = {}
	for found: Dictionary in view.buildings:
		if found.owner == seat and found.get("completed", true) and not found.has("rebuild") and (best.is_empty() or _home_before(found, best, start)): best = found
	return best

static func _home_before(a: Dictionary, b: Dictionary, start: String) -> bool:
	if (a.kind == start) != (b.kind == start): return a.kind == start
	var cost_a: int = Registry.kind(a.kind).get("cost", 0)
	var cost_b: int = Registry.kind(b.kind).get("cost", 0)
	if a.kind != start and cost_a != cost_b: return cost_a > cost_b
	return a.id < b.id

const LOW_POWER := "LOW POWER · DEFENCES OFF"

static func strip(view: Dictionary, id: int, placement_kind: String) -> Dictionary:
	var found: Dictionary = player(view, id)
	var numbers: Dictionary = {"credits": found.credits, "used": found.power_demand, "available": found.power_supply}
	if placement_kind.is_empty(): return numbers
	var power: int = Registry.kind(placement_kind).get("power", 0)
	return numbers.merged({"after_credits": found.credits - Registry.kind(placement_kind).cost, "after_used": numbers.used + maxi(0, -power), "after_available": numbers.available + maxi(0, power)})

static func _faction_kinds(faction: String) -> Array:
	var row: Dictionary = Registry.faction(faction)
	return Registry.kind(row.get("start_unit", "")).get("builds", []) + [row.get("start_building", "")]

# FRC builds nothing that makes or uses power, so a 0 / 0 group would read like a bug.
static func uses_power(faction: String) -> bool:
	return _faction_kinds(faction).any(func(kind: String) -> bool: return Registry.kind(kind).get("power", 0) != 0)

# Physical keycodes: orders read their keys here and the buttons print them, so a label never names an unused key.
const ORDER_KEYS := {"attack_move": KEY_A, "stop": KEY_S, "unload": KEY_F}
const BUILD_KEY: Key = KEY_Q
const BACK_KEY: Key = KEY_V
# The card owns every unmodified key of its Q W E R / A S D F / Z X C V position grid.
const GRID_KEYS: Array[Key] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]
# One cell per role in every faction (user, 2026-11-15); a building names its role in `slot`, a unit after its faction prefix.
const CELL_KEYS := {"power_plant": KEY_Q, "supply_center": KEY_W, "barracks": KEY_E, "factory": KEY_R, "defence": KEY_A, "builder": KEY_Q, "collector": KEY_Q, "rifle_infantry": KEY_Q, "rocket_infantry": KEY_W, "light_vehicle": KEY_Q, "tank": KEY_W}

static func role(kind: String) -> String:
	return Registry.kind(kind).get("slot", kind.substr(kind.find("_") + 1))

static func kind_cells(kinds: Array) -> Array:
	return kinds.map(func(kind: String) -> Array: return [CELL_KEYS.get(role(kind), KEY_NONE), kind])

# The cells the card shows, as [key, action]: a kind to build or produce, else "build", "back" or an ORDER_KEYS name. Orders press only these.
static func card(view: Dictionary, selection: Dictionary, seat: int) -> Array:
	var cells: Array = []
	var chosen: Dictionary = building(view, selection.building_id)
	var builders: Array = _builder_kinds(view, selection.ids, seat)
	if not chosen.is_empty():
		if chosen.owner == seat and chosen.completed: cells = kind_cells(Registry.kind(chosen.kind).produces)
	elif selection.get("sub_grid", false) and builders.size() == 1:
		cells = kind_cells(Registry.kind(builders[0]).builds) + [[BACK_KEY, "back"]]
	elif not builders.is_empty():
		cells = [[BUILD_KEY, "build"]]
	elif _has_own_unit(view, selection.ids, seat):
		if has_armed_unit(view, selection.ids, seat): cells.append([ORDER_KEYS.attack_move, "attack_move"])
		cells.append([ORDER_KEYS.stop, "stop"])
	if unload_target(view, selection, seat) != -1: cells.append([ORDER_KEYS.unload, "unload"])
	return cells

static func _has_own_unit(view: Dictionary, ids: Array[int], seat: int) -> bool:
	for id: int in ids:
		var i: int = view.units.index_of(id)
		if i != -1 and view.units.owner[i] == seat: return true
	return false

# The selected units' kinds when every one is an own builder, else none.
static func _builder_kinds(view: Dictionary, ids: Array[int], seat: int) -> Array:
	var kinds: Array = []
	for id: int in ids:
		var i: int = view.units.index_of(id)
		if i == -1 or view.units.owner[i] != seat or not Registry.is_builder(view.units.kinds[view.units.kind[i]]): return []
		kinds.append(view.units.kinds[view.units.kind[i]])
	return kinds

const SELECT_ONE_BUILDER := "Select one builder"
const QUEUE_LIMIT: int = 9

# Why a shown cell cannot be pressed, in the simulation's order (prerequisite, queue, credits); a unit cell takes its producer's prerequisite.
static func blocked(view: Dictionary, selection: Dictionary, seat: int, action: String) -> Dictionary:
	if action == "build": return {"cause": "builders", "reason": SELECT_ONE_BUILDER, "sound": ""} if _builder_kinds(view, selection.ids, seat).size() > 1 else {}
	if action.is_empty() or COMMANDS.has(action): return {}
	var producer: Dictionary = building(view, selection.building_id)
	var needs: String = Registry.kind(producer.kind if not producer.is_empty() else action).get("prerequisite", "")
	if not needs.is_empty() and not _owns_completed(view, seat, needs): return {"cause": "prerequisite", "reason": "Needs %s" % Registry.kind(needs).display_name, "sound": "error", "missing": needs}
	if producer.get("queue", []).size() >= QUEUE_LIMIT: return {"cause": "queue", "reason": "Queue full", "sound": "error"}
	var short: int = Registry.kind(action).cost - player(view, seat).credits
	if short > 0: return {"cause": "credits", "reason": "%d credits short" % short, "sound": "disabled"}
	return {}

static func _owns_completed(view: Dictionary, seat: int, kind: String) -> bool:
	return view.buildings.any(func(found: Dictionary) -> bool: return found.owner == seat and found.kind == kind and found.completed)

# The refusal for Build with nothing selected names the faction's own builder (user, 2026-11-21).
static func select_builder(view: Dictionary, seat: int) -> String:
	var faction: String = player(view, seat).get("faction", Registry.Factions.DEFAULT_FACTION)
	return "Select a %s" % Registry.kind(Registry.faction(faction).get("start_unit", "")).display_name

# Intended counters, [strong against, weak against], from each unit's Zero Hour role: Ranger, Red Guard and Rebel hunt infantry and fall to tanks; rocket infantry hunt vehicles and fall to infantry; Humvee, Technical and Gattling Tank hunt infantry and fall to tanks; Crusader, Battlemaster and Scorpion hunt light vehicles.
const COUNTER_INTENDED := {
	"usa_rifle_infantry": [["infantry"], ["tanks"]], "china_rifle_infantry": [["infantry"], ["tanks"]], "frc_rifle_infantry": [["infantry"], ["tanks"]],
	"usa_rocket_infantry": [["tanks", "light vehicles"], ["infantry"]], "china_rocket_infantry": [["tanks", "light vehicles"], ["infantry"]], "frc_rocket_infantry": [["tanks", "light vehicles"], ["infantry"]],
	"usa_light_vehicle": [["infantry"], ["tanks"]], "frc_light_vehicle": [["infantry"], ["tanks"]], "china_tank": [["infantry"], ["tanks"]],
	"usa_tank": [["light vehicles"], []], "china_light_vehicle": [["light vehicles"], []], "frc_tank": [["light vehicles"], []]}
# The cell card's counter line: the COUNTER_INTENDED claims its damage numbers hold (test_hud.gd CL1 derives every one).
const COUNTER_LINES := {
	"usa_rocket_infantry": "Beats tanks · Weak against infantry", "china_rocket_infantry": "Beats tanks · Weak against infantry", "frc_rocket_infantry": "Beats tanks · Weak against infantry",
	"usa_light_vehicle": "Weak against tanks", "frc_light_vehicle": "Weak against tanks", "china_tank": "Good against infantry at full spin · Weak against tanks",
	"usa_tank": "Beats light vehicles", "china_light_vehicle": "Beats light vehicles", "frc_tank": "Beats light vehicles"}

const SLAB_WIDTH: float = 432.0
const SLAB_CONTENT: float = SLAB_WIDTH - 20.0
const COMMANDS := {"build": "Build", "back": "Back", "attack_move": "Attack Move", "stop": "Stop", "unload": "Unload"}

# Back cancels while a building is armed (hud-v5-layout "Cards per state").
static func cell_name(action: String, placement_kind: String) -> String:
	if action == "back" and not placement_kind.is_empty(): return "Cancel"
	if COMMANDS.has(action): return COMMANDS[action]
	return Registry.kind(action).display_name

const QUEUE_TILES: int = 4

# The entry in production alone, then adjacent waiting entries of one kind together: {kind, ids, refund} (3-3, `DA:1475`).
static func queue_tiles(queue: Array) -> Array:
	var tiles: Array = []
	for i: int in queue.size():
		var entry: Dictionary = queue[i]
		if i < 2 or tiles.back().kind != entry.kind: tiles.append({"kind": entry.kind, "ids": []})
		tiles.back().ids.append(entry.id)
		tiles.back().refund = entry.paid_cost
	return tiles

static func newest_of_kind(queue: Array, kind: String) -> int:
	for i: int in range(queue.size() - 1, -1, -1):
		if queue[i].kind == kind: return queue[i].id
	return -1

# A seam so the layout path runs headless; tests swap it and restore it on every path.
static var layout_label: Callable = _platform_label

# Headless and web report no layout, and the label call errors there.
static func _platform_label(physical: Key) -> Key:
	if DisplayServer.keyboard_get_layout_count() > 0: return DisplayServer.keyboard_get_label_from_physical(physical)
	return physical

static func key_label(physical: Key) -> String:
	return OS.get_keycode_string(layout_label.call(physical))

static func is_container(view: Dictionary, id: int, seat: int) -> bool:
	var host: Dictionary = building(view, id)
	if host.is_empty():
		var i: int = view.units.index_of(id)
		if i == -1: return false
		host = {"owner": view.units.owner[i], "kind": view.units.kinds[view.units.kind[i]]}
	return host.owner == seat and host.get("completed", true) and not Registry.kind(host.kind).get("contains", {}).is_empty()

static func unload_target(view: Dictionary, selection: Dictionary, seat: int) -> int:
	var id: int = selection.building_id if selection.building_id != -1 else (selection.ids[0] if selection.ids.size() == 1 else -1)
	if not is_container(view, id, seat): return -1
	if not building(view, id).is_empty(): return id if not player(view, seat).get("tunnel", []).is_empty() else -1
	var units: RefCounted = view.units
	for i: int in units.size():
		if units.owner[i] == seat and units.container[i] == id: return id
	return -1

static func has_armed_unit(view: Dictionary, ids: Array[int], seat: int) -> bool:
	return ids.any(func(id: int) -> bool: return is_armed_unit(view, id, seat))

static func is_armed_unit(view: Dictionary, id: int, seat: int) -> bool:
	var i: int = view.units.index_of(id)
	return i != -1 and view.units.owner[i] == seat and not Registry.kind(view.units.kinds[view.units.kind[i]]).get("weapon", "").is_empty()

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
	if not Registry.kind(object.kind).get("produces", []).is_empty():
		row.queue = object.queue
		if not object.queue.is_empty(): row.right = "QUEUE %d / %d" % [object.queue.size(), QUEUE_LIMIT]
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
	var kinds: Array = [Registry.faction(faction).get("start_unit", "")]
	for building_kind: String in _faction_kinds(faction): kinds.append_array(Registry.kind(building_kind).get("produces", []))
	for kind: String in kinds:
		if not Registry.collects(kind).is_empty(): return Registry.collects(kind).box_value
	return 0

const ROWS_RULE := "Click a kind: select only that kind · Shift-click: deselect it"
const IDLE := "IDLE"
const WAITING_AT_PILE := "WAITING AT PILE"
const NO_DROP_OFF := "NO <DROP-OFF>"
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
		_drop_offs[faction] = ""
		for kind: String in _faction_kinds(faction):
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
	var has_drop_off: bool = false
	for site: Dictionary in view.buildings:
		if not site.completed: builders[site.get("builder_id")] = true
		elif site.owner == seat and Registry.kind(site.kind).get("receives_supply", false): has_drop_off = true
	var boxes_left: bool = view.get("sources", []).any(func(source: Dictionary) -> bool: return source.boxes > 0)
	for i: int in found: labels[units.id[i]] = collector_label(view, i, previous.get(units.id[i], ""), builders, boxes_left, has_drop_off)
	return labels

# The header counts these as idle collectors.
static func is_idle(label: String) -> bool:
	return label == IDLE or label.begins_with(NO_DROP_OFF.get_slice("<", 0))

static func collector_label(view: Dictionary, i: int, previous: String, builders: Dictionary, boxes_left: bool, has_drop_off: bool) -> String:
	var units: RefCounted = view.units
	if units.flags[i] & ViewRows.COLLECTING:
		var phase: String = units.phases[units.phase[i]]
		if phase == "seeking": return previous
		var drop: String = drop_off(player(view, units.owner[i]).get("faction", Registry.Factions.DEFAULT_FACTION))
		# Idle while collecting is a retry at a busy dock while a pile still holds boxes; without a drop-off there is no dock to retry.
		if phase == "idle" and not has_drop_off: return NO_DROP_OFF.replace("<DROP-OFF>", drop)
		if phase == "idle": return WAITING_AT_PILE if boxes_left else IDLE
		return PHASE_LABELS[phase].replace("<DROP-OFF>", drop)
	var status: int = units.status[i]
	if status != ViewRows.NONE and ViewRows.STATUSES[status] in ["moving", "path_pending"]: return "MOVING"
	if builders.has(units.id[i]): return "BUILDING"
	return "" if units.flags[i] & ViewRows.CONTAINED else IDLE
