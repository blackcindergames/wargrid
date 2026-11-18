extends SceneTree

const LabCapture = preload("res://scripts/lab/lab_capture.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

# Screen points across the own block, clear of the top strips and the panel.
const DRAG_FROM := Vector2(110, 250)
const DRAG_TO := Vector2(630, 620)
const DRAG_DWELL: int = 15
const DRAG_MOVE: int = 75
const HOVER_DWELL: int = 12
const HOVER_MOVE: int = 14
const HOVER_AREA := Rect2(0, 120, 1280, 520)
const WARM_FRAMES: int = 2

var _viewport: SubViewport
var _lab: Node
var _route: Array[Vector2] = []

static func clips() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for style in 3: list.append(_clip(&"drag_box", style, &"drag", 120))
	list.append(_clip(&"drag_box", 0, &"drag", 120, true))
	list.append(_clip(&"health_bar", 0, &"hover", 90))
	for rule in 3: list.append(_clip(&"health_bar", rule, &"live", 180))
	return list

static func _clip(question: StringName, variant: int, scene: StringName, frames: int, shift: bool = false) -> Dictionary:
	var what: String = "shift-drag" if shift else String(scene)
	return {name = "%s-%s-%s" % [question, LabCapture.LETTERS[variant], what], question = question, variant = variant, scene = scene, frames = frames, shift = shift}

# Movie Maker records at the project's 1280x720 viewport whatever the window, so frames come from the 1280x800 SubViewport.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --path game --fixed-fps 30 --script res://scripts/lab/lab_clips.gd -- OUTPUT_DIR")
		quit(1)
		return
	_run(args[0])

func _run(directory: String) -> void:
	await process_frame
	for clip: Dictionary in clips():
		var problem: String = await _record(clip, directory.path_join(clip.name))
		if not problem.is_empty():
			printerr("lab_clips: %s: %s" % [clip.name, problem])
			quit(1)
			return
		print("recorded %s %d frames" % [clip.name, clip.frames])
	print("CLIPS DONE %d" % clips().size())
	quit(0)

# One fresh lab per clip, so a drag's selection or the running fight never leaks into the next clip.
func _record(clip: Dictionary, folder: String) -> String:
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return "cannot create %s" % folder
	_viewport = LabCapture.stage(self)
	_lab = _viewport.get_child(0)
	if not _setup(clip): return "could not set up the lab"
	for i in WARM_FRAMES: await process_frame
	if clip.scene == &"hover":
		_route = _hover_route()
		if _route.size() != 4: return "hover found %d of 4 units on screen" % _route.size()
	for frame: int in clip.frames:
		_pointer(clip, frame)
		await RenderingServer.frame_post_draw
		if _viewport.get_texture().get_image().save_png(folder.path_join("%04d.png" % frame)) != OK: return "cannot save frame %d" % frame
	_viewport.queue_free()
	return ""

func _setup(clip: Dictionary) -> bool:
	if not (LabCapture.setup(_viewport, clip.question, clip.variant) and LabCapture.lab_line(_viewport, KEY_P, "panel many (P)")): return false
	if clip.scene != &"live": return true
	LabCapture.to_first_shot(_lab, 0)
	_lab.paused = false
	return LabCapture.lab_line(_viewport, KEY_V, "view live (V)")

func _pointer(clip: Dictionary, frame: int) -> void:
	match clip.scene:
		&"drag":
			var at: Vector2 = along([DRAG_FROM, DRAG_TO], DRAG_DWELL, DRAG_MOVE, frame)
			if frame == DRAG_DWELL: _push(_button(at, true, clip.shift))
			_push(_motion(at, frame >= DRAG_DWELL and frame <= DRAG_DWELL * 2 + DRAG_MOVE, clip.shift))
			if frame == DRAG_DWELL * 2 + DRAG_MOVE: _push(_button(at, false, clip.shift))
		&"hover": _push(_motion(along(_route, HOVER_DWELL, HOVER_MOVE, frame), false, false))

# Waits dwell frames on each point, then moves to the next in move frames, eased.
static func along(points: Array[Vector2], dwell: int, move: int, frame: int) -> Vector2:
	var leg: int = mini(floori(frame / float(dwell + move)), points.size() - 1)
	var into: int = frame - leg * (dwell + move) - dwell
	if leg == points.size() - 1 or into <= 0: return points[leg]
	return points[leg].lerp(points[leg + 1], ease(minf(into / float(move), 1.0), -2.0))

# A full-health enemy, a damaged enemy, a selected own unit and an unselected own unit.
func _hover_route() -> Array[Vector2]:
	var army: LabArmy = _lab.selection_lab._army
	var picks: Array[Callable] = [
		func(row: Dictionary) -> bool: return row.id == army.hovered,
		func(row: Dictionary) -> bool: return row.owner == LabArmy.ENEMY and row.hp < row.max_hp,
		func(row: Dictionary) -> bool: return army.selected.has(row.id),
		func(row: Dictionary) -> bool: return row.owner == LabArmy.OWN and not army.selected.has(row.id) and row.hp < row.max_hp,
	]
	var route: Array[Vector2] = []
	var xform: Transform2D = _lab._view.get_global_transform_with_canvas()
	for pick: Callable in picks:
		for row: Dictionary in army.state.entities:
			var at: Vector2 = xform * (Iso.world_to_plane(Vector2(row.position[0], row.position[1])) + Vector2(0, -4))
			if pick.call(row) and HOVER_AREA.has_point(at):
				route.append(at)
				break
	return route

func _push(event: InputEvent) -> void:
	_viewport.push_input(event, true)

static func _button(at: Vector2, pressed: bool, shift: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event

static func _motion(at: Vector2, held: bool, shift: bool) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	return event
