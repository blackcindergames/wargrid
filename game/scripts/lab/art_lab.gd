extends Node

const Fight = preload("res://scripts/lab/lab_fight.gd")
const AbVariants = preload("res://scripts/lab/ab_variants.gd")
const AbOverlay = preload("res://scripts/lab/ab_overlay.gd")
const SelectionLab = preload("res://scripts/lab/selection_lab.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const RESTART_TICK: int = 2400
const PAN_SPEED: float = 400.0
const SESSION_SIZE := Vector2i(1280, 800)
# Below the lab panel's top strips (two in token_set).
const LAB_STATUS_TOP: float = 96.0
const STATUS_TOP: float = 16.0

var fight: Fight = Fight.new()
# The owner's P2.3a picks: a session opens on them, Tab compares against the others.
const PICKS := {&"token_set": 0, &"health_bar": 0, &"value_size": 1, &"drag_box": 0}

var variants := AbVariants.new()
var question_index: int = 0
var quality: int = GraphicsSettings.HIGH
var zoom_index: int = 1
var paused: bool = false
var selection_lab: SelectionLab = SelectionLab.new()
var _current: Dictionary = {}
var _opponent_before: int = 0
var _selected: Array[int] = []
var _visuals := VisualDirector.new()
var _ground := AbOverlay.new()
var _top := AbOverlay.new()
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $HUD/Status

func _ready() -> void:
	_view.set_visuals(_visuals)
	_ground.variants = variants
	_ground.show_behind_parent = true
	_view.add_child(_ground)
	_view.move_child(_ground, _view.get_node("Bodies").get_index())
	_top.variants = variants
	_top.on_top = true
	_view.add_child(_top)
	_camera.position = Iso.world_to_plane(Fight.FOCUS)
	add_child(selection_lab)
	selection_lab.visuals = _visuals
	selection_lab.setup(_view, _camera, $HUD)
	if get_tree().current_scene == self: _start_session()
	_apply_view()
	advance()

# Only the running main scene: a test or capture viewport keeps its window and variants.
func _start_session() -> void:
	var window: Window = get_window()
	window.size = SESSION_SIZE
	window.content_scale_size = SESSION_SIZE
	window.unresizable = true
	var letters := PackedStringArray()
	for question in AbVariants.P2_3A:
		variants.set_variant(question, PICKS[question])
		letters.append("%s %s" % [question, "ABCDEF"[variants.variant(question)]])
	question_index = AbVariants.QUESTIONS.find(&"token_set")
	print("P2.3a start variants: ", ", ".join(letters))

func current_question() -> StringName:
	return AbVariants.QUESTIONS[question_index]

func _lab_question() -> bool:
	return AbVariants.P2_3A.has(current_question())

func advance() -> void:
	var sim := fight.simulation
	fight.step()
	_visuals.collect_step(sim.tick(), sim.combat_events(), sim.command_results())
	_current = sim.snapshot()
	variants.observe(_current, WorldBatch.objects(_current), sim.combat_events())
	_show(_current)
	if sim.tick() >= RESTART_TICK: _restart_fight()

func restart() -> void:
	selection_lab.reset()
	_restart_fight()

# The timed loop keeps the lab's selection and held box; only R resets them.
func _restart_fight() -> void:
	fight = Fight.new()
	_visuals.reset()
	variants.reset()
	_current = {}
	_selected.clear()
	advance()

func _show(state: Dictionary) -> void:
	variants.focus = current_question()
	# Also in the new questions, so the focus change re-applies the old question's ground on the way back.
	variants.apply(_view, _camera)
	_ground.visible = not _lab_question()
	_top.visible = not _lab_question()
	if _lab_question():
		if _opponent_before == 0: _opponent_before = variants.opponent_owner
		# Owner 3 is the frozen army's ally.
		if variants.opponent_owner == LabArmy.ALLY: variants.opponent_owner += 1
		# The questions judge palette A, so Neon goes off here; leaving re-applies it.
		if _view.bright_owners(): _view.set_bright_owners(false)
		selection_lab.present(current_question(), variants, state)
		return
	if _opponent_before != 0:
		variants.opponent_owner = _opponent_before
		_opponent_before = 0
	selection_lab.hide_all(_view)
	_view.set_state(AbVariants.recolored(state, variants.opponent_owner), _selected)

func _physics_process(_delta: float) -> void:
	if not paused: advance()

func _process(delta: float) -> void:
	var pan := Vector2(int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT)), int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP)))
	_camera.position += pan.normalized() * PAN_SPEED * delta / _camera.zoom.x
	if not paused: _view.advance_frame()
	_ground.queue_redraw()
	_top.queue_redraw()
	_status.text = status_text()
	_status.position.y = LAB_STATUS_TOP if _lab_question() else STATUS_TOP

func status_text() -> String:
	var question: StringName = current_question()
	var labels: Array = AbVariants.LABELS[question]
	var letter: String = "ABCDEF"[variants.variant(question)]
	var keys: String = "PageUp/PageDown or [ ]: question | Tab: next variant | Q: Low/High | Z: zoom | O: opponent colour (now P%d) | Space: pause | R: restart | arrows: pan | Esc: quit" % variants.opponent_owner
	if AbVariants.P2_3A.has(question):
		var header: String = "%d/%d %s | variant %s of %s | %s | zoom %s" % [question_index + 1, AbVariants.QUESTIONS.size(), question, letter, "ABCDEF"[labels.size() - 1], "High" if quality == GraphicsSettings.HIGH else "Low", ZOOMS[zoom_index]]
		return "\n".join([header, keys, selection_lab.status_line()])
	var options := PackedStringArray()
	for i in labels.size(): options.append("%s: %s" % ["ABCDEF"[i], labels[i]])
	var separator: String = " | " if labels.size() > 2 else "\n"
	var lines: PackedStringArray = [
		"%d/%d %s | variant %s | %s | zoom %s" % [question_index + 1, AbVariants.QUESTIONS.size(), question, letter, "High" if quality == GraphicsSettings.HIGH else "Low", ZOOMS[zoom_index]],
		separator.join(options),
		keys,
	]
	if question == &"sand_tone": lines.append("step %d/%d %s" % [variants.variant(question) + 1, labels.size(), labels[variants.variant(question)]])
	return "\n".join(lines)

func step_question(direction: int) -> void:
	selection_lab.end_drag()
	question_index = posmod(question_index + direction, AbVariants.QUESTIONS.size())
	if not _current.is_empty(): _show(_current)

func toggle_variant() -> void:
	variants.set_variant(current_question(), (variants.variant(current_question()) + 1) % variants.variant_count(current_question()))
	_show(_current)

func toggle_quality() -> void:
	quality = GraphicsSettings.LOW if quality == GraphicsSettings.HIGH else GraphicsSettings.HIGH
	_apply_view()

func cycle_opponent_colour() -> void:
	variants.opponent_owner = 2 if variants.opponent_owner >= 8 else variants.opponent_owner + 1
	_show(_current)

func cycle_zoom() -> void:
	zoom_index = (zoom_index + 1) % ZOOMS.size()
	_apply_view()

func _apply_view() -> void:
	_view.set_quality(quality)
	_camera.zoom = Vector2.ONE * ZOOMS[zoom_index]
	_view.set_zoom(ZOOMS[zoom_index])

func click(plane_point: Vector2) -> void:
	var id: int = _view.pick_entity(plane_point, true)
	_selected.clear()
	if id != -1: _selected.append(id)
	_show(_current)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and _lab_question():
		selection_lab.pointer(event, _view)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(_view.make_canvas_position_local(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.physical_keycode)

func _key(code: Key) -> void:
	if _lab_question() and selection_lab.key(code): return
	match code:
		KEY_PAGEUP, KEY_BRACKETLEFT: step_question(-1)
		KEY_PAGEDOWN, KEY_BRACKETRIGHT: step_question(1)
		KEY_TAB: toggle_variant()
		KEY_Q: toggle_quality()
		KEY_Z: cycle_zoom()
		KEY_O: cycle_opponent_colour()
		KEY_SPACE: paused = not paused
		KEY_R: restart()
		KEY_ESCAPE: get_tree().quit()
