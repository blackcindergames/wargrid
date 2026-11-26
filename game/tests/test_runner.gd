@warning_ignore_start("untyped_declaration")
extends RefCounted

const Runner = preload("res://tests/run_tests.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

func cases() -> Array[Callable]:
	return [test_shards_cover_every_suite_once, test_no_shard_runs_everything, test_bad_shard_runs_nothing, test_only_filter, test_shards_by_cost, test_case_stat_line, test_sb5a_runner_flags_live_worker]

func test_shards_cover_every_suite_once(runner) -> bool:
	var seen: Array[int] = []
	for i in range(4):
		seen.append_array(Runner.shard(34, PackedStringArray(["--shard=%d/4" % i])))
	seen.sort()
	runner.check(seen == Array(range(34), TYPE_INT, "", null), "R1 four shards run each of 34 cases exactly once")
	return true

func test_no_shard_runs_everything(runner) -> bool:
	runner.check(Runner.shard(5, PackedStringArray()) == [0, 1, 2, 3, 4], "R2 no shard arg runs every case")
	return true

func test_bad_shard_runs_nothing(runner) -> bool:
	runner.check(Runner.shard(5, PackedStringArray(["--shard=2/2"])).is_empty(), "R3 index past count runs nothing")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=0/0"])).is_empty(), "R3 zero shards runs nothing")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=x"])).is_empty(), "R3 malformed shard runs nothing")
	return true

func test_only_filter(runner) -> bool:
	runner.check(Runner.only_filter(PackedStringArray(["--shard=0/4", "--only=test_supply"])) == "test_supply", "R4 --only picks the filter text")
	runner.check(Runner.only_filter(PackedStringArray(["--shard=0/4"])).is_empty(), "R4 no --only means no filter")
	return true

func test_shards_by_cost(runner) -> bool:
	var costs := PackedFloat64Array([5.0, 1, 1, 1, 1, 1])
	runner.check(Runner.shard(6, PackedStringArray(["--shard=0/2"]), costs) == [0], "R5 the slow case gets a process to itself")
	runner.check(Runner.shard(6, PackedStringArray(["--shard=1/2"]), costs) == [1, 2, 3, 4, 5], "R5 the rest share the other process")
	var equal := PackedFloat64Array([1.0, 1, 1, 1, 1])
	runner.check(Runner.shard(5, PackedStringArray(["--shard=0/2"]), equal) == [0, 2, 4], "R5 equal costs keep the modulo deal, shard 0")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=1/2"]), equal) == [1, 3], "R5 equal costs keep the modulo deal, shard 1")
	return true

func test_case_stat_line(runner) -> bool:
	runner.check(Runner.stat_line("test_x", 1234, 7) == "CASE_STAT test_x 1.2 7", "R6 the stat line has the case, one-decimal seconds and its checks")
	runner.check(Runner.stat_line("test_x", 44860, 0) == "CASE_STAT test_x 44.9 0", "R6 seconds round to one decimal")
	runner.check(Runner.stats_enabled("1"), "R6 WARGRID_CASE_STATS=1 turns stats on")
	runner.check(not Runner.stats_enabled("") and not Runner.stats_enabled("0"), "R6 stats stay off otherwise")
	return true

func test_sb5a_runner_flags_live_worker(runner) -> bool:
	SimPump.stop_live_for_test()
	if OS.has_feature("threads"):
		SimPump.force_mode_for_test("worker")
		var pump := SimPump.new(Skirmish.create(true, "ai", {1: "usa", 2: "china"}, Skirmish.MAP_PATH, [] as Array[int]))
		SimPump.force_mode_for_test("")
		pump.start()
		var stopped: int = SimPump.stop_live_for_test()
		runner.check(stopped == 1 and SimPump.live_workers() == 0, "R7 the runner stops the worker a case left, got %d" % stopped)
		runner.check(Runner.leaked_worker_line("test_x", stopped) == "FAIL: live sim worker after test_x", "R7 a case that leaves a worker is named, got '%s'" % Runner.leaked_worker_line("test_x", stopped))
	_leak_per_case(runner)
	runner.check(Runner.leaked_worker_line("test_sb3_job0_starts", 1).is_empty(), "R7 a case on the left-to-the-runner list is not named")
	runner.check(Runner.leaked_worker_line("test_x", 0).is_empty(), "R7 a case that leaves nothing is not named")
	return true

# The runner's own per-case step: with the switch a leak is named and counted, without it only cleaned up; either way the forced mode is cleared.
func _leak_per_case(runner) -> void:
	if not OS.has_feature("threads"): return
	var saved: String = OS.get_environment("WARGRID_SIM_THREAD")
	var failed: int = runner.failures
	SimPump.stop_live_for_test()
	for on in [true, false]:
		if on: OS.set_environment("WARGRID_SIM_THREAD", "1")
		else: OS.unset_environment("WARGRID_SIM_THREAD")
		SimPump.force_mode_for_test("worker")
		SimPump.new(Skirmish.create(true, "ai", {1: "usa", 2: "china"}, Skirmish.MAP_PATH, [] as Array[int])).start()
		var leak: String = runner._after_case("test_x")
		var counted: int = runner.failures - failed
		runner.failures = failed
		runner.check(SimPump.live_workers() == 0 and SimPump._forced.is_empty(), "R7 the per-case step stops the worker and clears the forced mode (switch %s)" % on)
		runner.check(leak == ("FAIL: live sim worker after test_x" if on else "") and counted == (1 if on else 0), "R7 the leak is named and counted only under the switch (switch %s), got '%s' and %d" % [on, leak, counted])
	if saved.is_empty(): OS.unset_environment("WARGRID_SIM_THREAD")
	else: OS.set_environment("WARGRID_SIM_THREAD", saved)
