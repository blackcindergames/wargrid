extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

var _sim: Simulation
var _lockstep: RefCounted

func _init(sim: Simulation, lockstep: RefCounted) -> void:
	_sim = sim
	_lockstep = lockstep

func snapshot() -> Dictionary:
	return _sim.snapshot()

func tick() -> int:
	return _sim.tick()

func issue_command(command: Dictionary) -> Dictionary:
	var player: int = command.get("player", 0)
	if not _lockstep.may_submit(player): return {"ok": false, "error": "not this seat's order"}
	var owner: int = _lockstep.owner_of(player)
	# The lockstep stamps tick and sequence, so only the rest of the order is judged.
	var error: String = _sim.check_command(command.merged({"tick": _sim.tick(), "player": owner, "sequence": _sim.last_sequence(owner) + 1}, true))
	if not error.is_empty(): return {"ok": false, "error": error}
	var ok: bool = _lockstep.submit(command, player)
	return {"ok": ok, "error": "" if ok else "too many orders"}

func map_data() -> Dictionary:
	return _sim.map_data()

func simulation() -> Simulation:
	return _sim
