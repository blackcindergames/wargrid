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
	var ok: bool = _lockstep.submit(command, command.get("player", 0))
	return {"ok": ok, "error": "" if ok else "too many orders"}

func map_data() -> Dictionary:
	return _sim.map_data()

func simulation() -> Simulation:
	return _sim
