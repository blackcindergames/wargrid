extends SceneTree

const SCENE = preload("res://scenes/art_lab.tscn")
const LabPanel = preload("res://scripts/lab/lab_panel.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const SelectionLab = preload("res://scripts/lab/selection_lab.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const LabLook = preload("res://scripts/lab/lab_look.gd")
const LabMarks = preload("res://scripts/lab/lab_marks.gd")

const SIZE := Vector2i(1280, 800)
const LETTERS := "abc"
const SETTLE_FRAMES: int = 3
const LIVE_CAP: int = 900
const AFTER_SHOT: int = 45
const MAX_PRESSES: int = 12
const FRAME_CAP: int = 1000
# A 3x3 grid can land wholly on the canvas at zoom 0.5.
const BLANK_GRID: int = 8
# Plane camera spots: both token_set panels over sand, or both over the canvas (map edge above them).
const TOKEN_SAND := Vector2(228, 138)
const TOKEN_CANVAS := Vector2(192, 620)
const CLEAR_AREA := Rect2(0, 96, 1280, 560)
const STACK_GAP: int = 8
const TAG_WIDTH: int = 24

var _viewport: SubViewport
var _lab: Node
var _frames: int = 0
var _failed: bool = false
var _crops := {}

static func shots() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for state: StringName in LabPanel.STATES:
		for dark: bool in [false, true]: list.append(_shot(&"token_set", 0, state, dark, 1.0))
	for state: StringName in [&"one", &"many"]: list.append(_shot(&"token_set", 0, state, false, 1.0, 0, false, true))
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

static func _shot(question: StringName, variant: int, state: StringName, dark: bool, zoom: float, held: int = 0, live: bool = false, canvas: bool = false) -> Dictionary:
	var name: String = "%s-%s-%s-%s-z%s" % [question, LETTERS[variant], state, "dark" if dark else "sand", str(zoom).trim_suffix(".0")]
	if held != 0: name += "-held%d" % held
	if live: name += "-live"
	if canvas: name += "-canvas"
	return {name = name, question = question, variant = variant, state = state, dark = dark, zoom = zoom, held = held, live = live, canvas = canvas}

# The capture frames each question for a fair look; the window keeps the lab's own camera.
static func camera_for(shot: Dictionary) -> Vector2:
	if shot.question == &"token_set": return TOKEN_CANVAS if shot.canvas else TOKEN_SAND
	if shot.held != 0: return SelectionLab.HELD_BOXES[shot.held].get_center()
	return Iso.world_to_plane(LabArmy.CAMERA_FOCUS)

# A SubViewport renders at exactly 1280x800 at scale 1 whatever the window and screen do.
static func stage(tree: SceneTree) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var lab: Node = SCENE.instantiate()
	viewport.add_child(lab)
	lab.paused = true
	# Status and key lines are for the person at the window, not for the pictures.
	lab.get_node("HUD/Status").hide()
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

# Steps the paused live fight to its first shot, so live bars have damage to show; false if none by LIVE_CAP.
static func to_first_shot(lab: Node, after: int) -> bool:
	while not lab.fight.simulation.combat_events().any(func(event: Dictionary) -> bool: return event.type == "shot"):
		if lab.fight.simulation.tick() >= LIVE_CAP: return false
		lab.advance()
	for i in after: lab.advance()
	return true

# A hang (a script error kills the await chain) must end the run, not wait for the shell timeout.
func _watch(cap: int) -> void:
	_frames += 1
	if _frames > cap: _fail("frame cap %d reached" % cap)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --path game --script res://scripts/lab/lab_capture.gd -- OUTPUT_DIR")
		quit(1)
		return
	process_frame.connect(_watch.bind(FRAME_CAP))
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
			if not to_first_shot(_lab, AFTER_SHOT):
				_fail("no shot in the live fight by tick %d" % LIVE_CAP)
				return
			stepped = true
		if not _apply(shot):
			_fail("could not set up %s" % shot.name)
			return
		for i in SETTLE_FRAMES: await process_frame
		var image: Image = _viewport.get_texture().get_image()
		if _blank(image):
			_fail("%s is blank" % shot.name)
			return
		var problem: String = _bars_broken(image) if shot.question == &"health_bar" else ""
		if not problem.is_empty():
			_fail("%s: %s" % [shot.name, problem])
			return
		var path: String = directory.path_join(shot.name + ".png")
		if image.save_png(path) != OK:
			_fail("cannot save %s" % path)
			return
		print("saved ", path)
		if shot.question == &"value_size": _crops.get_or_add(shot.state, []).append(image.get_region(_panel_crop(image)))
	for state: StringName in _crops:
		var path: String = directory.path_join("value_size-stack-%s.png" % state)
		var stacked: Image = await _stack(_crops[state])
		if stacked.save_png(path) != OK:
			_fail("cannot save %s" % path)
			return
		print("saved ", path)
	print("CAPTURE DONE %d shots, %d stacks at tick %d" % [shots().size(), _crops.size(), _lab.fight.simulation.tick()])
	quit(0)

func _panel_crop(image: Image) -> Rect2i:
	var panel: Rect2 = _lab.selection_lab._panels[0].panel_rect().grow(STACK_GAP)
	return Rect2i(panel).intersection(Rect2i(Vector2i.ZERO, image.get_size()))

# Value size A (14) above B (13) at 100 %, each tagged, because a phone shrinks a full shot.
func _stack(crops: Array) -> Image:
	var width: int = 0
	var height: int = STACK_GAP
	for crop: Image in crops:
		width = maxi(width, crop.get_width())
		height += crop.get_height() + STACK_GAP
	var view := SubViewport.new()
	view.size = Vector2i(TAG_WIDTH + width + STACK_GAP, height)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var fill := ColorRect.new()
	fill.color = LabLook.CANVAS
	fill.size = view.size
	view.add_child(fill)
	var y: int = STACK_GAP
	for i in crops.size():
		var crop: Image = crops[i]
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(crop)
		picture.position = Vector2(TAG_WIDTH, y)
		view.add_child(picture)
		var tag := Label.new()
		tag.text = "AB"[i]
		tag.label_settings = LabelSettings.new()
		tag.label_settings.font = LabLook.font(700)
		tag.label_settings.font_size = 14
		tag.position = Vector2(STACK_GAP, y + crop.get_height() / 2.0 - 10.0)
		view.add_child(tag)
		y += crop.get_height() + STACK_GAP
	root.add_child(view)
	for i in SETTLE_FRAMES: await process_frame
	var image: Image = view.get_texture().get_image()
	view.queue_free()
	return image

# Every bar no later bar covers must keep its frame column, the track rows around the fill and the fill.
func _bars_broken(image: Image) -> String:
	var marks: Node2D = _lab.selection_lab._over
	var xform: Transform2D = marks.get_global_transform_with_canvas()
	var list: Array[Dictionary] = LabMarks.bars(marks.model)
	var screens: Array = list.map(func(bar: Dictionary) -> Dictionary: return LabMarks.screen_bar(bar.rects, xform))
	var checked: int = 0
	for i in list.size():
		var screen: Dictionary = screens[i]
		if not CLEAR_AREA.encloses(screen.frame) or range(i + 1, list.size()).any(func(j: int) -> bool: return screens[j].frame.intersects(screen.frame)): continue
		var fill: Rect2 = screen.fill
		var middle: int = int(fill.position.y)
		var frame_ok: bool = _near(image.get_pixel(int(screen.frame.position.x), middle), list[i].frame)
		var track_ok: bool = [Vector2(screen.track.position.x, middle), Vector2(fill.position.x, screen.track.position.y), Vector2(fill.position.x, screen.track.end.y - 1)].all(func(at: Vector2) -> bool: return image.get_pixel(int(at.x), int(at.y)).get_luminance() < 0.3)
		var fill_ok: bool = fill.size.x < 1.0 or _near(image.get_pixel(int(fill.position.x), middle), list[i].fill)
		if not (frame_ok and track_ok and fill_ok): return "bar %d at %s lost its frame, track or fill" % [list[i].id, screen.frame]
		checked += 1
	if checked == 0: return "no bar could be checked"
	print("bars intact: %d of %d" % [checked, list.size()])
	return ""

static func _near(color: Color, wanted: Color) -> bool:
	return absf(color.r - wanted.r) < 0.02 and absf(color.g - wanted.g) < 0.02 and absf(color.b - wanted.b) < 0.02

func _apply(shot: Dictionary) -> bool:
	var ready: bool = setup(_viewport, shot.question, shot.variant, shot.zoom) \
		and lab_line(_viewport, KEY_G, "ground %s" % ("dark" if shot.dark else "sand")) \
		and lab_line(_viewport, KEY_D, "box %s (D)" % SelectionLab.HELD_NAMES[shot.held]) \
		and lab_line(_viewport, KEY_P, "panel %s (P)" % shot.state) \
		and (shot.question != &"health_bar" or lab_line(_viewport, KEY_V, "view %s (V)" % ("live" if shot.live else "frozen")))
	_lab._camera.position = camera_for(shot)
	return ready

static func _blank(image: Image) -> bool:
	var first: Color = image.get_pixel(0, 0)
	for y in BLANK_GRID:
		for x in BLANK_GRID:
			if image.get_pixel(floori(image.get_width() * x / float(BLANK_GRID)), floori(image.get_height() * y / float(BLANK_GRID))) != first: return false
	return true

func _fail(message: String) -> void:
	if _failed: return
	_failed = true
	printerr("lab_capture: ", message)
	quit(1)
