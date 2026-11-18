extends SceneTree

const SCENE = preload("res://scenes/art_lab.tscn")
const LabPanel = preload("res://scripts/lab/lab_panel.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const SelectionLab = preload("res://scripts/lab/selection_lab.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

const SIZE := Vector2i(1280, 800)
const LETTERS := "abc"
const SETTLE_FRAMES: int = 3
const LIVE_CAP: int = 900
const AFTER_SHOT: int = 15
const MAX_PRESSES: int = 12

var _viewport: SubViewport
var _lab: Node

static func shots() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for state: StringName in LabPanel.STATES:
		for dark: bool in [false, true]: list.append(_shot(&"token_set", 0, state, dark, 1.0))
	for rule in 3:
		for dark: bool in [false, true]:
			for zoom: float in [0.5, 1.0]: list.append(_shot(&"health_bar", rule, &"many", dark, zoom))
	for rule in 3:
		for zoom: float in [0.5, 1.0]: list.append(_shot(&"health_bar", rule, &"many", false, zoom, 0, true))
	for size in 2:
		for state: StringName in [&"one", &"many", &"building"]: list.append(_shot(&"value_size", size, state, false, 1.0))
	for style in 3:
		for held: int in [1, 2]:
			for dark: bool in [false, true]:
				for zoom: float in [0.5, 1.0, 2.0]: list.append(_shot(&"drag_box", style, &"many", dark, zoom, held))
	for style in 3: list.append(_shot(&"drag_box", style, &"many", false, 1.0, 3))
	return list

static func _shot(question: StringName, variant: int, state: StringName, dark: bool, zoom: float, held: int = 0, live: bool = false) -> Dictionary:
	var name: String = "%s-%s-%s-%s-z%s" % [question, LETTERS[variant], state, "dark" if dark else "sand", str(zoom).trim_suffix(".0")]
	if held != 0: name += "-held%d" % held
	if live: name += "-live"
	return {name = name, question = question, variant = variant, state = state, dark = dark, zoom = zoom, held = held, live = live}

# A SubViewport renders at exactly 1280x800 at scale 1 whatever the window and screen do.
static func stage(tree: SceneTree) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var lab: Node = SCENE.instantiate()
	viewport.add_child(lab)
	lab.paused = true
	return viewport

static func press(viewport: SubViewport, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event, true)

# Presses one lab key until done() holds, as the owner would.
static func until(viewport: SubViewport, code: Key, done: Callable) -> bool:
	for i in MAX_PRESSES:
		if done.call(): return true
		press(viewport, code)
	return done.call()

static func setup(viewport: SubViewport, question: StringName, variant: int, zoom: float = 1.0) -> bool:
	var lab: Node = viewport.get_child(0)
	return until(viewport, KEY_BRACKETRIGHT, func() -> bool: return lab.current_question() == question) \
		and until(viewport, KEY_TAB, func() -> bool: return lab.variants.variant(question) == variant) \
		and until(viewport, KEY_Z, func() -> bool: return is_equal_approx(lab.ZOOMS[lab.zoom_index], zoom))

static func lab_line(viewport: SubViewport, code: Key, text: String) -> bool:
	var lab: Node = viewport.get_child(0)
	return until(viewport, code, func() -> bool: return lab.selection_lab.status_line().contains(text))

# Steps the paused live fight to its first shot, so live bars have damage to show.
static func to_first_shot(lab: Node, after: int) -> void:
	while lab.fight.simulation.tick() < LIVE_CAP and not lab.fight.simulation.combat_events().any(func(event: Dictionary) -> bool: return event.type == "shot"): lab.advance()
	for i in after: lab.advance()

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --path game --script res://scripts/lab/lab_capture.gd -- OUTPUT_DIR")
		quit(1)
		return
	_run(args[0])

func _run(directory: String) -> void:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("cannot create %s" % directory)
		return
	# The root is not inside the tree during _initialize, and push_input needs it.
	await process_frame
	_viewport = stage(self)
	_lab = _viewport.get_child(0)
	var stepped: bool = false
	for shot: Dictionary in shots():
		if shot.live and not stepped:
			to_first_shot(_lab, AFTER_SHOT)
			stepped = true
		if not _apply(shot):
			_fail("could not set up %s" % shot.name)
			return
		for i in SETTLE_FRAMES: await process_frame
		var image: Image = _viewport.get_texture().get_image()
		if _blank(image):
			_fail("%s is blank" % shot.name)
			return
		var path: String = directory.path_join(shot.name + ".png")
		if image.save_png(path) != OK:
			_fail("cannot save %s" % path)
			return
		print("saved ", path)
	print("CAPTURE DONE %d shots at tick %d" % [shots().size(), _lab.fight.simulation.tick()])
	quit(0)

func _apply(shot: Dictionary) -> bool:
	var ready: bool = setup(_viewport, shot.question, shot.variant, shot.zoom) \
		and lab_line(_viewport, KEY_G, "ground %s" % ("dark" if shot.dark else "sand")) \
		and lab_line(_viewport, KEY_D, "box %d (D)" % shot.held) \
		and lab_line(_viewport, KEY_P, "panel %s (P)" % shot.state) \
		and (shot.question != &"health_bar" or lab_line(_viewport, KEY_V, "view %s (V)" % ("live" if shot.live else "frozen")))
	# At zoom 2 the held boxes run off the left of the screen; the owner pans there, the capture centres on them.
	var zoomed_box: bool = shot.held != 0 and shot.zoom == 2.0
	_lab._camera.position = SelectionLab.HELD_BOXES[shot.held].get_center() if zoomed_box else Iso.world_to_plane(LabArmy.CAMERA_FOCUS)
	return ready

static func _blank(image: Image) -> bool:
	var first: Color = image.get_pixel(0, 0)
	for y in 3:
		for x in 3:
			if image.get_pixel(floori(image.get_width() * x / 3.0), floori(image.get_height() * y / 3.0)) != first: return false
	return true

func _fail(message: String) -> void:
	printerr("lab_capture: ", message)
	quit(1)
