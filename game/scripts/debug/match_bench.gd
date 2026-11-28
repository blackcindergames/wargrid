extends Node

const BenchLoads = preload("res://scripts/debug/bench_loads.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const ScreenScene = preload("res://scenes/match_bench_screen.tscn")
const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const FAST_FORWARD_TICKS_PER_FRAME: int = 30
const IDLE_FRAMES: int = 91
const DIGEST_EVERY: int = 300
const ONLINE_DIGEST_EVERY: int = 30
const ARMS: Array[String] = ["inline", "worker"]

var _terminal: bool = false
var _quality: String = "high"
var _smooth: bool = true
var _cadence: bool = false
var _holds := Vector2i.ZERO

func _ready() -> void:
	var params: Dictionary = _params()
	var arms: PackedStringArray = str(params.driver).split(",")
	var loads: PackedStringArray = str(params.load).split(",")
	var build: String = _build()
	print("WORKER BENCH engine=%s os=%s export=%s load=%s arms=%s build=%s window=%d+%d path=simpump" % [Engine.get_version_info().string, OS.get_name(), "threads" if OS.has_feature("threads") else "nothreads", ",".join(loads), ",".join(arms), build, BenchLoads.WARMUP, BenchLoads.WINDOW])
	for load_name: String in loads:
		if not BenchLoads.LOADS.has(load_name): return _finish("WORKER BENCH FAILED unknown load " + load_name, 1)
	for arm: String in arms:
		if not ARMS.has(arm): return _finish("WORKER BENCH FAILED driver must be inline or worker, not " + arm, 1)
		if arm == "worker" and not OS.has_feature("threads"): return _finish("WORKER BENCH FAILED the worker arm needs a build with threads", 1)
	for switch: String in ["smooth", "online_cadence"]:
		if not ["on", "off"].has(str(params[switch])): return _finish("WORKER BENCH FAILED %s must be on or off, not %s" % [switch, params[switch]], 1)
	_quality = str(params.quality)
	if not ["high", "low"].has(_quality): return _finish("WORKER BENCH FAILED quality must be high or low, not " + _quality, 1)
	var cap: String = str(params.physics_cap)
	if not cap.is_empty():
		if not cap.is_valid_int() or int(cap) < 1: return _finish("WORKER BENCH FAILED physics_cap must be a whole number of at least 1, not " + cap, 1)
		Engine.max_physics_steps_per_frame = int(cap)
	var hold: PackedStringArray = str(params.holds).split(",")
	if str(params.holds) != "off":
		if hold.size() != 2 or not hold[0].is_valid_int() or not hold[1].is_valid_int() or int(hold[0]) < 1 or int(hold[1]) < 1: return _finish("WORKER BENCH FAILED holds must be off or <count>,<ms>, not " + str(params.holds), 1)
		_holds = Vector2i(int(hold[0]), int(hold[1]))
	_smooth = params.smooth == "on"
	_cadence = params.online_cadence == "on"
	# Headless has no vsync; the cap keeps the frame loop from spinning, so the line's frames_per_s is the observed cadence.
	if DisplayServer.get_name() == "headless": Engine.max_fps = 60
	print("WORKER BENCH CONFIG quality=%s smooth=%s online_cadence=%s holds=%s max_fps=%d max_physics_steps_per_frame=%d%s" % [_quality, params.smooth, params.online_cadence, params.holds, Engine.max_fps, Engine.max_physics_steps_per_frame, "" if not cap.is_empty() else " (untouched)"])
	get_tree().create_timer(float(params.deadline)).timeout.connect(func() -> void: _finish("WORKER BENCH TIMEOUT", 3))
	var idle_ms: float = await _idle_frame_ms()
	if _terminal: return
	var run: int = 0
	for load_name: String in loads:
		for arm: String in arms:
			run += 1
			var failure: String = await _run(load_name, arm, run, build, idle_ms)
			if _terminal: return
			if not failure.is_empty(): return _finish("WORKER BENCH FAILED " + failure, 1)
	_finish("WORKER BENCH DONE", 0)

func _run(load_name: String, arm: String, run: int, build: String, idle_ms: float) -> String:
	var live: RefCounted = BenchLoads.create(load_name)
	var start: int = BenchLoads.start_tick(load_name)
	while live.tick() < start:
		BenchLoads.advance(load_name, live)
		if live.tick() % FAST_FORWARD_TICKS_PER_FRAME == 0:
			await get_tree().process_frame
			if _terminal: return ""
	var driver := OfflineDriver.new(1)
	driver.bots = BenchLoads.bots(load_name)
	driver.digest_every = ONLINE_DIGEST_EVERY if _cadence else DIGEST_EVERY
	var screen: Node = ScreenScene.instantiate()
	screen.driver = driver
	screen.bench_sim = live
	live = null
	screen.arm = arm
	screen.load_name = load_name
	screen.run_index = run
	screen.build_id = build
	screen.start_tick = start
	screen.smooth = _smooth
	screen.quality_param = _quality
	screen.quality = GraphicsSettings.LOW if _quality == "low" else GraphicsSettings.HIGH
	screen.online_cadence = _cadence
	screen.holds = _holds
	SimPump.force_mode_for_test(arm)
	add_child(screen)
	SimPump.force_mode_for_test("")
	if driver.sim_mode() != arm: return "the pump runs %s, not %s" % [driver.sim_mode(), arm]
	var result: Dictionary = await screen.finished
	_report(screen.digests, result, run, idle_ms)
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return str(result.failed)

func _report(digests: PackedStringArray, result: Dictionary, run: int, idle_ms: float) -> void:
	print("RUN %d arm=%s" % [run, result.arm])
	var first: int = result.start_tick - result.start_tick % DIGEST_EVERY
	for entry: String in digests:
		var tick: int = int(entry.split(" ")[0])
		if tick >= first and tick <= result.end_tick: print("DIGEST tick=%s %s" % Array(entry.split(" ")))
	print("WORKER RUN " + JSON.stringify(result.merged({"smooth_param": "on" if _smooth else "off", "refresh_hz": DisplayServer.screen_get_refresh_rate(), "idle_frame_ms": idle_ms})))

# Median frame interval with nothing loaded.
func _idle_frame_ms() -> float:
	var intervals := PackedFloat64Array()
	var last: int = Time.get_ticks_usec()
	for i: int in IDLE_FRAMES:
		await get_tree().process_frame
		if _terminal: return 0.0
		var now: int = Time.get_ticks_usec()
		if i > 0: intervals.append((now - last) / 1000.0)
		last = now
	return TimingStats.summary(intervals).p50

func _params() -> Dictionary:
	var params: Dictionary = {"driver": "inline", "load": "team", "deadline": 3000, "quality": "high", "physics_cap": "", "smooth": "on", "online_cadence": "off", "holds": "off"}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() < 2: continue
		var key: String = {"driver": "driver", "load": "load", "deadline-s": "deadline", "deadline": "deadline", "quality": "quality", "physics_cap": "physics_cap", "physics-cap": "physics_cap", "smooth": "smooth", "online_cadence": "online_cadence", "online-cadence": "online_cadence", "holds": "holds"}.get(parts[0], "")
		if not key.is_empty(): params[key] = parts[1]
	return params

func _build() -> String:
	return FileAccess.get_file_as_string("res://build_commit.txt").strip_edges() if FileAccess.file_exists("res://build_commit.txt") else "none"

func _finish(line: String, code: int) -> void:
	if _terminal: return
	_terminal = true
	print(line)
	SimPump.finish_quit(get_tree(), code)
