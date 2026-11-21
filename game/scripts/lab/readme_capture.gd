extends SceneTree

const LabCapture = preload("res://scripts/lab/lab_capture.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const SkirmishScene = preload("res://scenes/skirmish.tscn")
const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

const MAP := "res://data/maps/dry_wells.json"
const FACTIONS := {1: "usa", 2: "china"}
const NEED: int = 8
const RADIUS: float = 8.0
const TICK_CAP: int = 20000
const FRAMES: int = 300
# Four seconds in: the first shots have landed and both lines are firing.
const STILL_FRAME: int = 120
const SETTLE_FRAMES: int = 3
const FRAME_CAP: int = 2000
const WINDOW := Vector2i(1280, 720)
# Drawn at 2x like the HUD mock-ups, so README text stays sharp on high-density screens.
const PIXELS := Vector2i(2560, 1440)

var _overlays := OverlayTests.new()
var _port: SubViewport
var _main: Node
var _saved: String = ""
var _begun: bool = false
var _frames: int = 0
var _failed: bool = false

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		printerr("usage: godot --path game --fixed-fps 30 --script res://scripts/lab/readme_capture.gd -- /ABSOLUTE/OUTPUT_DIR")
		quit(1)
		return
	process_frame.connect(_watch)
	_run(args[0])

func _watch() -> void:
	_frames += 1
	if _frames > FRAME_CAP: _fail("frame cap %d reached" % FRAME_CAP)

func _run(directory: String) -> void:
	if DirAccess.make_dir_recursive_absolute(directory.path_join("clip")) != OK:
		_fail("cannot create %s" % directory)
		return
	var sim: RefCounted = Skirmish.create(true, "ai", FACTIONS, MAP)
	var clash: Variant = await _fight(sim)
	if _failed: return
	if clash == null:
		_fail("no clash of %d against %d within %.0f cells by tick %d" % [NEED, NEED, RADIUS, TICK_CAP])
		return
	var tick: int = sim.tick()
	var selected: int = await _stage(sim, clash)
	if _failed: return
	for frame in range(1, FRAMES + 1):
		# The offline driver runs only seat 2's bot; seat 1's keeps playing here, so both armies fight as in the headless run.
		Skirmish.issue_opponents(_main.driver.pump.live(), [1])
		BaseScene.tick(_main)
		_present()
		if not await _save(directory.path_join("clip/%04d.png" % frame)): return
		if frame != STILL_FRAME: continue
		if _main.orders.selected_ids.is_empty():
			_fail("the selection is empty at the still")
			return
		if not await _save(directory.path_join("still.png")): return
	_close()
	print("CAPTURE DONE tick %d selected %d frames %d" % [tick, selected, FRAMES])
	quit(0)

# Both seats run the skirmish bot, as `test_skirmish_match.gd` does, until the armies meet.
func _fight(sim: RefCounted) -> Variant:
	while sim.tick() < TICK_CAP:
		Skirmish.issue_opponents(sim, [1, 2])
		sim.step()
		if sim.tick() % 30 != 0: continue
		var clash: Variant = clash_point(sim.snapshot().entities, NEED, RADIUS)
		if clash != null: return clash
		if sim.tick() % 600 == 0: await process_frame
	return null

func _stage(sim: RefCounted, clash: Vector2) -> int:
	# Scratch settings with the playtest helper off: the owner's files stay untouched and the README shows no helper chip.
	_saved = _overlays._begin(false)
	_begun = true
	_port = BaseScene.sized_port(self, PIXELS, WINDOW)
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_main = await _overlays._scene(self, SkirmishScene, _port)
	_main.driver.adopt(sim)
	_main._reset_camera()
	_main._camera.position = Iso.world_to_plane(clash)
	# What a player would box-select: every own fighting unit on screen.
	var view := Rect2(_main._camera.position - Vector2(WINDOW) / 2.0, Vector2(WINDOW))
	var ids: Array[int] = []
	for row: Dictionary in sim.snapshot().entities:
		if row.owner == 1 and row.combat != null and view.has_point(Iso.world_to_plane(Vector2(row.position[0], row.position[1]))): ids.append(row.id)
	if ids.is_empty():
		_fail("no player 1 unit in view")
		return 0
	HudTests._select(_main, ids)
	for i in SETTLE_FRAMES: await process_frame
	_present()
	return ids.size()

# Interpolation reads the wall clock; drawing every frame at the tick's end keeps reruns identical.
func _present() -> void:
	_main._view.blend(1.0)

func _save(path: String) -> bool:
	await process_frame
	var image: Image = _port.get_texture().get_image()
	if LabCapture._blank(image):
		_fail("%s is blank" % path)
		return false
	if image.save_png(path) != OK:
		_fail("cannot save %s" % path)
		return false
	return true

func _close() -> void:
	if is_instance_valid(_port): _port.free()
	if _begun: _overlays._end(_saved)
	_begun = false

func _fail(message: String) -> void:
	if _failed: return
	_failed = true
	printerr("readme_capture: ", message)
	_close()
	quit(1)

# The centre of the biggest meeting of both armies, or null while neither side brings `need` units within `radius`.
static func clash_point(entities: Array, need: int, radius: float) -> Variant:
	var best: Array[Vector2] = []
	for row: Dictionary in entities:
		var centre := Vector2(row.position[0], row.position[1])
		var near: Array[Vector2] = []
		var counts: Dictionary = {1: 0, 2: 0}
		for other: Dictionary in entities:
			var at := Vector2(other.position[0], other.position[1])
			if not counts.has(other.owner) or at.distance_to(centre) > radius: continue
			counts[other.owner] += 1
			near.append(at)
		if counts[1] >= need and counts[2] >= need and near.size() > best.size(): best = near
	if best.is_empty(): return null
	var sum := Vector2.ZERO
	for at: Vector2 in best: sum += at
	return sum / best.size()
