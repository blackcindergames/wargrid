@warning_ignore_start("untyped_declaration")
extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")

const KNOWN_KEYS := ["display_name", "class", "cost", "ticks", "speed", "accel", "brake", "locomotor", "turn_cos", "turn_sin", "max_hp", "armor", "weapon", "radius", "builds", "min_turn_speed", "collects", "vision", "horde", "quantity", "salvage", "weapon_tiers", "contains", "power", "footprint", "prerequisite", "produces", "receives_supply", "counts_for_victory", "icon", "slot", "spawns_on_complete", "powered", "supply_clearance", "rebuild_hole", "hole"]
const LOCOMOTORS := ["air", "legs", "treads", "wheels"]
const CLASSES := ["air", "infantry", "vehicle"]
const SALVAGE := ["money", "weapon"]
const SLOTS := ["barracks", "command_center", "defence", "factory", "power_plant", "supply_center"]
const GOOD_ROW := {"class": "vehicle", "cost": 1, "ticks": 1, "speed": 1.0, "locomotor": "wheels", "max_hp": 1000, "armor": "tank", "weapon": ""}

func cases() -> Array[Callable]:
	return [test_unknown_key_is_named, test_dangling_reference_is_named, test_nested_and_enum_values_are_checked, test_faction_references_are_checked, test_real_registry_is_clean]

static func lint(kinds: Dictionary, factions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var buildings: Dictionary = _ids_of(kinds, false)
	var units: Dictionary = _ids_of(kinds, true)
	for id: String in kinds:
		var row: Dictionary = kinds[id]
		for key: String in row:
			if not KNOWN_KEYS.has(key): errors.append("%s: unknown key %s" % [id, key])
		_check_refs(id, row, buildings, units, errors)
		_check_nested(id, row, units, errors)
	for faction: String in factions: _check_faction(faction, factions[faction], kinds, buildings, units, errors)
	return errors

static func _ids_of(kinds: Dictionary, units: bool) -> Dictionary:
	var ids: Dictionary = {}
	for id: String in kinds:
		if kinds[id].has("class") == units: ids[id] = true
	return ids

static func _check_refs(id: String, row: Dictionary, buildings: Dictionary, units: Dictionary, errors: Array[String]) -> void:
	_expect(errors, id, "weapon", row.get("weapon", ""), Shared.WEAPONS, true)
	for weapon: String in row.get("weapon_tiers", []): _expect(errors, id, "weapon_tiers", weapon, Shared.WEAPONS, false)
	_expect(errors, id, "armor", row.get("armor", ""), Shared.ARMOR, false)
	if row.has("locomotor") and not LOCOMOTORS.has(row.locomotor): errors.append("%s: locomotor %s does not resolve" % [id, row.locomotor])
	_expect(errors, id, "prerequisite", row.get("prerequisite", ""), buildings, true)
	_expect(errors, id, "rebuild_hole", row.get("rebuild_hole", ""), buildings, true)
	for target: String in row.get("builds", []): _expect(errors, id, "builds", target, buildings, false)
	for key: String in ["produces", "spawns_on_complete"]:
		for target: String in row.get(key, []): _expect(errors, id, key, target, units, false)

static func _check_nested(id: String, row: Dictionary, units: Dictionary, errors: Array[String]) -> void:
	_expect(errors, id, "class", row.get("class", "vehicle"), _set_of(CLASSES), false)
	_expect(errors, id, "salvage", row.get("salvage", "money"), _set_of(SALVAGE), false)
	_expect(errors, id, "slot", row.get("slot", "factory"), _set_of(SLOTS), false)
	if row.has("hole"): _expect(errors, id, "hole.worker", row.hole.get("worker", ""), units, false)
	if row.has("contains"): _check_accepts(id, row.contains, errors)

static func _check_accepts(id: String, contains: Dictionary, errors: Array[String]) -> void:
	if not contains.get("accepts") is Array:
		errors.append("%s: contains.accepts is missing" % id)
		return
	for role: String in contains.accepts: _expect(errors, id, "contains.accepts", role, _set_of(CLASSES), false)

static func _check_faction(id: String, faction: Dictionary, kinds: Dictionary, buildings: Dictionary, units: Dictionary, errors: Array[String]) -> void:
	_expect(errors, id, "start_building", faction.get("start_building", ""), buildings, false)
	_expect(errors, id, "start_unit", faction.get("start_unit", ""), units, false)
	if not faction.get("build_order") is Array: errors.append("%s: build_order is missing" % id)
	for target: String in faction.get("build_order", []):
		_expect(errors, id, "build_order", target, buildings, false)
		if buildings.has(target) and not SLOTS.has(kinds[target].get("slot", "")): errors.append("%s: build_order %s has no valid slot" % [id, target])
	if not faction.get("units_for") is Dictionary: errors.append("%s: units_for is missing" % id)
	var units_for: Dictionary = faction.get("units_for", {})
	for producer: String in units_for:
		_expect(errors, id, "units_for", producer, buildings, false)
		for target: String in units_for[producer]: _check_producible(id, producer, target, kinds, units, errors)

static func _check_producible(id: String, producer: String, target: String, kinds: Dictionary, units: Dictionary, errors: Array[String]) -> void:
	_expect(errors, id, "units_for", target, units, false)
	if units.has(target) and kinds.has(producer) and not kinds[producer].get("produces", []).has(target): errors.append("%s: units_for %s is not produced by %s" % [id, target, producer])

static func _set_of(values: Array) -> Dictionary:
	var ids: Dictionary = {}
	for value: String in values: ids[value] = true
	return ids

static func _expect(errors: Array[String], id: String, key: String, value: String, table: Dictionary, empty_ok: bool) -> void:
	if value.is_empty() and empty_ok: return
	if not table.has(value): errors.append("%s: %s %s does not resolve" % [id, key, value])

static func _registry_kinds() -> Dictionary:
	var kinds: Dictionary = {}
	for id: String in Registry.units() + Registry.buildings(): kinds[id] = Registry.kind(id)
	return kinds

func _lint_test_kind(row: Dictionary) -> Array[String]:
	Registry.add_test_kind("x_lint", row)
	var errors: Array[String] = lint(_registry_kinds(), Registry.Factions.FACTIONS)
	Registry.clear_test_kinds()
	return errors

func test_unknown_key_is_named(runner) -> bool:
	var row: Dictionary = GOOD_ROW.duplicate()
	row.visoin = 6.0
	var errors: Array[String] = _lint_test_kind(row)
	runner.check(errors.size() == 1 and errors[0].contains("x_lint") and errors[0].contains("visoin"), "DL1 a misspelled key fails, naming kind and key: %s" % [errors])
	runner.check(_lint_test_kind(GOOD_ROW.duplicate()).is_empty(), "DL1 a clean test kind passes")
	return true

func test_dangling_reference_is_named(runner) -> bool:
	var row: Dictionary = GOOD_ROW.duplicate()
	row.weapon = "no_such_gun"
	var errors: Array[String] = _lint_test_kind(row)
	runner.check(errors.size() == 1 and errors[0].contains("x_lint") and errors[0].contains("weapon") and errors[0].contains("no_such_gun"), "DL2 an unknown weapon fails, naming kind, key and value: %s" % [errors])
	for case: Array in [["armor", "no_such_armor"], ["locomotor", "hover"], ["prerequisite", "no_such_kind"], ["weapon_tiers", ["rifle", "no_such_gun"]], ["builds", ["no_such_kind"]], ["produces", ["no_such_kind"]], ["spawns_on_complete", ["no_such_kind"]], ["rebuild_hole", "no_such_kind"], ["prerequisite", "usa_tank"], ["builds", ["usa_tank"]], ["rebuild_hole", "usa_tank"], ["produces", ["usa_barracks"]], ["spawns_on_complete", ["usa_barracks"]]]:
		var bad: Dictionary = GOOD_ROW.duplicate()
		bad[case[0]] = case[1]
		var found: Array[String] = _lint_test_kind(bad)
		runner.check(found.size() == 1 and found[0].contains(String(case[0])), "DL2 a bad %s %s fails: %s" % [case[0], case[1], found])
	var none: Dictionary = GOOD_ROW.duplicate()
	none.prerequisite = ""
	runner.check(_lint_test_kind(none).is_empty(), "DL2 an empty weapon and prerequisite mean none")
	return true

func test_nested_and_enum_values_are_checked(runner) -> bool:
	for case: Array in [["slot", "factroy"], ["class", "vehcile"], ["salvage", "gold"], ["hole", {"worker": "no_such_kind"}], ["hole", {}], ["hole", {"worker": "usa_barracks"}], ["contains", {"accepts": ["infantyr"]}], ["contains", {"accept": ["infantry"]}]]:
		var bad: Dictionary = GOOD_ROW.duplicate(true)
		bad[case[0]] = case[1]
		var found: Array[String] = _lint_test_kind(bad)
		runner.check(found.size() == 1 and found[0].contains("x_lint") and found[0].contains(String(case[0])), "DL4 a bad %s %s fails: %s" % [case[0], case[1], found])
	var good: Dictionary = GOOD_ROW.duplicate(true)
	good.hole = {"worker": "usa_builder"}
	good.contains = {"accepts": ["infantry", "vehicle"]}
	runner.check(_lint_test_kind(good).is_empty(), "DL4 a valid hole worker and container accepts pass")
	return true

func test_faction_references_are_checked(runner) -> bool:
	for case: Array in [["start_building", "usa_factroy"], ["start_unit", "usa_factory"], ["build_order", ["usa_power_plant", "no_such_kind"]], ["build_order", ["usa_tank"]], ["units_for", {"no_such_kind": []}], ["units_for", {"usa_barracks": ["usa_barracks"]}]]:
		var factions: Dictionary = Registry.Factions.FACTIONS.duplicate(true)
		factions.usa[case[0]] = case[1]
		var found: Array[String] = lint(_registry_kinds(), factions)
		runner.check(found.size() == 1 and found[0].contains("usa") and found[0].contains(String(case[0])), "DL5 a bad faction %s %s fails: %s" % [case[0], case[1], found])
	_check_faction_shape(runner)
	return true

func _check_faction_shape(runner) -> void:
	for key: String in ["build_order", "units_for"]:
		var factions: Dictionary = Registry.Factions.FACTIONS.duplicate(true)
		factions.usa.erase(key)
		var found: Array[String] = lint(_registry_kinds(), factions)
		runner.check(found.size() == 1 and found[0].contains("usa") and found[0].contains(key), "DL5 a faction without %s fails: %s" % [key, found])
	var kinds: Dictionary = _registry_kinds().duplicate(true)
	kinds.usa_factory.erase("slot")
	var slotless: Array[String] = lint(kinds, Registry.Factions.FACTIONS)
	runner.check(slotless.size() == 1 and slotless[0].contains("usa_factory") and slotless[0].contains("slot"), "DL5 a build_order building without a slot fails: %s" % [slotless])
	var wrong: Dictionary = Registry.Factions.FACTIONS.duplicate(true)
	wrong.usa.units_for.usa_barracks = ["usa_tank"]
	var found_wrong: Array[String] = lint(_registry_kinds(), wrong)
	runner.check(found_wrong.size() == 1 and found_wrong[0].contains("usa_tank") and found_wrong[0].contains("units_for"), "DL5 a unit its producer cannot produce fails: %s" % [found_wrong])

func test_real_registry_is_clean(runner) -> bool:
	# A test kind leaked by an earlier case in the same shard would read as a real kind.
	Registry.clear_test_kinds()
	var kinds: Dictionary = _registry_kinds()
	runner.check(kinds.size() >= 37, "DL3 the registry has its kinds (%d)" % kinds.size())
	var errors: Array[String] = lint(kinds, Registry.Factions.FACTIONS)
	runner.check(errors.is_empty(), "DL3 today's definitions lint clean: %s" % [errors])
	return true
