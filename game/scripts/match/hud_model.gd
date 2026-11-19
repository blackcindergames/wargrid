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
