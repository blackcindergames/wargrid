extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const TRIO: Array[int] = [1, 2, 3]
const QUAD_TEAMS: Array[int] = [1, 1, 2, 2]

static func sim(teams: Array[int] = TRIO, seat_two: Dictionary = {}) -> RefCounted:
	var seats: Array[int] = []
	var rows: Array[Dictionary] = []
	for index in teams.size():
		var row: Dictionary = {"seat": index + 1, "team": teams[index], "controller": "human", "credits": Skirmish.START_CREDITS, "faction": "usa"}
		if index == 1: row.merge(seat_two, true)
		rows.append(row)
		seats.append(index + 1)
	var created: RefCounted = Skirmish.MapData.create(Skirmish.MapData.load("res://data/maps/broken_crown.json"), rows)
	created.start_match(seats)
	return created

static func defeat(world: RefCounted, seat: int) -> void:
	for building: Dictionary in world.snapshot().buildings:
		if building.owner == seat: world.remove_object(building.id)
	for unit: Dictionary in world.snapshot().entities:
		if unit.owner == seat: world.remove_object(unit.id)
