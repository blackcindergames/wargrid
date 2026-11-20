extends "res://scripts/match/sim_pump.gd"

var fail_next: bool = false

func _note_for(job: Job, slot: Slot) -> Note:
	if fail_next: return null
	return super(job, slot)
