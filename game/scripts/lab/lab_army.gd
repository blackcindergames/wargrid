extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fight = preload("res://scripts/lab/lab_fight.gd")

const MAP_SIZE := Vector2i(24, 24)
const OWN := 1
const ENEMY := 2
const ALLY := 3
const CAMERA_FOCUS := Vector2(15, 9)
const PLANT_ORIGIN: Array[int] = [2, 2]
const SPACING: float = 1.5
# [owner, count, columns, first position]; columns run along world x, rows along world y.
const BLOCKS: Array = [
	[OWN, 47, 8, Vector2(5.75, 10.75)],
	[ALLY, 12, 4, Vector2(18.25, 11.75)],
	[ENEMY, 60, 10, Vector2(9.25, 0.75)],
]

var state: Dictionary
var selected: Array[int] = []
var hovered: int = -1
var building_id: int = -1

func _init() -> void:
	var simulation := Simulation.new([], MAP_SIZE)
	simulation.add_player(OWN, 30000, "human", 1)
	simulation.add_player(ENEMY, 30000, "human", 2)
	simulation.add_player(ALLY, 30000, "human", 1)
	var builder: int = simulation.spawn(OWN, Vector2(4.5, 4.5), "usa_builder")
	var command := {"type": "build", "builder_id": builder, "building_kind": "usa_power_plant", "origin": PLANT_ORIGIN, "tick": 0, "player": OWN, "sequence": 0}
	var ordered: bool = simulation.issue_command(command).ok
	assert(ordered, "lab army: the power plant order is accepted")
	for i in 3000:
		building_id = _completed_plant(simulation.snapshot())
		if building_id != -1: break
		simulation.step()
	assert(building_id != -1, "lab army: the power plant completes within 3000 ticks")
	for block: Array in BLOCKS: _spawn_block(simulation, block)
	state = simulation.snapshot()
	_write_health()
	_pick_marked(builder)

static func view_copy(source: Dictionary) -> Dictionary:
	var copy: Dictionary = source.duplicate(true)
	for key: String in ["entities", "buildings"]:
		for row: Dictionary in copy[key]: row.hp = row.max_hp
	return copy

static func _completed_plant(snapshot: Dictionary) -> int:
	for building: Dictionary in snapshot.buildings:
		if building.owner == OWN and building.kind == "usa_power_plant" and building.completed: return building.id
	return -1

static func _spawn_block(simulation: Simulation, block: Array) -> void:
	var columns: int = block[2]
	var first: Vector2 = block[3]
	for i: int in block[1]:
		var at: Vector2 = first + Vector2(i % columns, floori(i / float(columns))) * SPACING
		var id: int = simulation.spawn(block[0], at, Fight.LISTED_KINDS[i % Fight.LISTED_KINDS.size()])
		assert(id != -1, "lab army: every unit spawns")

# Per side, rows 0 and 2 of every 5 are damaged (40 %); every third damaged row is light (90-99 %).
func _write_health() -> void:
	var seen := {1: 0, 2: 0}
	var hurt := {1: 0, 2: 0}
	for row: Dictionary in state.entities:
		var side: int = 2 if row.owner == ENEMY else 1
		var i: int = seen[side]
		seen[side] += 1
		if i % 5 != 0 and i % 5 != 2: continue
		var j: int = hurt[side]
		hurt[side] += 1
		var heavy: int = j - floori(j / 3.0) - 1
		var percent: int = 91 + floori(j / 3.0) if j % 3 == 0 else (15 + heavy if side == 2 else 33 + 3 * heavy)
		row.hp = ceili(row.max_hp * percent / 100.0)

# The builder stands off at the plant, so the selection stays one group in the block.
func _pick_marked(builder: int) -> void:
	var full: int = 0
	var damaged: int = 0
	for row: Dictionary in state.entities:
		if row.owner == OWN and row.id != builder and selected.size() < 10:
			var is_full: bool = row.hp == row.max_hp
			if is_full and full < 5: full += 1
			elif not is_full and damaged < 5: damaged += 1
			else: continue
			selected.append(row.id)
		if row.owner == ENEMY and hovered == -1 and row.hp == row.max_hp: hovered = row.id
