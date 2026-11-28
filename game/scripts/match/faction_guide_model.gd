extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const FACTIONS: Array[String] = ["usa", "china", "frc"]

# combat.gd's sustained rate per tick: a clip's shots over its delays and reload, a ramp weapon at its last percent, FRC at its base tier, scaled by the target's armour.
static func counter_rate(attacker: String, target: String) -> float:
	var row: Dictionary = Registry.kind(attacker)
	if row.get("weapon", "").is_empty(): return 0.0
	var weapon: Dictionary = _weapon(attacker)
	var damage: float = weapon.damage * (weapon.ramp.percent[-1] / 100.0 if weapon.has("ramp") else 1.0)
	var rate: float = weapon.clip_size * damage / ((weapon.clip_size - 1) * weapon.delay_ticks + weapon.reload_ticks) if weapon.clip_size > 0 else damage / weapon.delay_ticks
	return rate * Shared.ARMOR[Registry.kind(target).armor][weapon.damage_type] / 100.0

# Equal credits on both sides: the time the attackers need to kill the targets (a squad's cost split over its quantity).
static func counter_time(attacker: String, target: String) -> float:
	var rate: float = counter_rate(attacker, target)
	if rate == 0.0: return INF
	return Registry.kind(target).max_hp * _unit_cost(attacker) / (rate * _unit_cost(target))

# Our time to kill them over theirs to kill us: at most 0.5 we beat them, at least 2 they beat us.
static func ratio(kind: String, other: String) -> float:
	return counter_time(kind, other) / counter_time(other, kind)

static func is_worker(kind: String) -> bool:
	return Registry.is_builder(kind) or not Registry.collects(kind).is_empty()

# {"beats": {faction: [kinds]}, "weak": {faction: [kinds]}}; close fights are left out, workers have none.
static func counters(kind: String) -> Dictionary:
	var found: Dictionary = {"beats": {}, "weak": {}}
	for faction: String in FACTIONS:
		found.beats[faction] = []
		found.weak[faction] = []
		if is_worker(kind): continue
		for other: String in roster(faction):
			if is_worker(other): continue
			var r: float = ratio(kind, other)
			if r <= 0.5: found.beats[faction].append(other)
			elif r >= 2.0: found.weak[faction].append(other)
	return found

# Combat units cheapest first, then the builder and the collector.
static func roster(faction: String) -> Array[String]:
	var row: Dictionary = Registry.faction(faction)
	var combat: Array[String] = []
	for building: String in row.units_for: combat.append_array(row.units_for[building])
	combat.sort_custom(func(a: String, b: String) -> bool: return Registry.kind(a).cost < Registry.kind(b).cost or (Registry.kind(a).cost == Registry.kind(b).cost and a < b))
	var workers: Array[String] = [row.start_unit]
	for id: String in Registry.units():
		if id.begins_with(faction + "_") and not Registry.collects(id).is_empty() and not workers.has(id): workers.append(id)
	return combat + workers

static func facts(kind: String) -> Dictionary:
	var row: Dictionary = Registry.kind(kind)
	var producer: String = Registry.unit_view(kind).producer
	var needs: String = Registry.kind(producer).get("prerequisite", "")
	var weapon: Dictionary = _weapon(kind)
	return {
		"cost": str(row.cost), "time": "%d s" % ceili(row.ticks / float(Skirmish.TICKS_PER_SECOND)), "health": str(row.max_hp / 1000),
		"speed": "%.1f" % row.speed, "range": "%d" % weapon.range if not weapon.is_empty() else "–",
		"vision": "%d" % row.vision if row.has("vision") else "–",
		"trained_at": Registry.kind(producer).get("display_name", ""), "needs": Registry.kind(needs).get("display_name", "") if not needs.is_empty() else ""}

static func _weapon(kind: String) -> Dictionary:
	var row: Dictionary = Registry.kind(kind)
	if row.get("weapon", "").is_empty(): return {}
	return Shared.WEAPONS[row.get("weapon_tiers", [row.weapon])[0]]

static func _unit_cost(kind: String) -> float:
	return Registry.kind(kind).cost / float(Registry.kind(kind).get("quantity", 1))
