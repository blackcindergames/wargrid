extends Node

const LabLook = preload("res://scripts/lab/lab_look.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const LabMarks = preload("res://scripts/lab/lab_marks.gd")
const LabDragBox = preload("res://scripts/lab/lab_drag_box.gd")
const LabPanel = preload("res://scripts/lab/lab_panel.gd")
const AbVariants = preload("res://scripts/lab/ab_variants.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")

# Plane rects, so a held box stays put at every zoom: none, over the army, 44 % past the south-west map edge yet within a zoom-2 screen, over the army with Shift.
const HELD_BOXES: Array[Rect2] = [Rect2(), Rect2(-140, 280, 200, 140), Rect2(-330, 440, 200, 380), Rect2(-140, 280, 200, 140)]
const SHIFT_BOX: int = 3
const HELD_NAMES: Array[String] = ["none", "army", "edge", "army+Shift"]
const BASELINE_STYLE: int = 2
const TOKEN_SET_NUMBERS: int = 13

var visuals: VisualDirector
var _view: Node2D
var _camera: Camera2D
var _army := LabArmy.new()
var _under := LabMarks.new()
var _over := LabMarks.new()
var _drag := LabDragBox.new()
var _panels: Array[LabPanel] = [LabPanel.new(), LabPanel.new()]
var _canvas := CanvasLayer.new()
var _on: bool = false
var _question: StringName = &""
var _variants: AbVariants
var _live_state: Dictionary = {}
var _shown: Dictionary = {}
var _selected: Array[int] = []
var _hovered: int = -1
var _panel_state: int = 0
var _panel_key: Array = []
var _dark: bool = false
var _held: int = 0
var _live: bool = false
var _was_live: bool = false
var _frozen_selected: Array[int] = []
var _frozen_hovered: int = -1
var _dragging: bool = false
var _drag_start := Vector2.ZERO
var _drag_point := Vector2.ZERO
var _drag_selection: Array[int] = []
var _drag_shift: bool = false
var _camera_before := Vector2.ZERO

func setup(view: Node2D, camera: Camera2D, hud: CanvasLayer) -> void:
	_view = view
	_camera = camera
	_under.show_behind_parent = true
	view.add_child(_under)
	view.move_child(_under, view.get_node("Bodies").get_index())
	_over.on_top = true
	view.add_child(_over)
	hud.add_child(_drag)
	for panel in _panels:
		# The panel spans the screen; ignoring the mouse keeps clicks reaching the world.
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(panel)
	_canvas.layer = -1
	var fill := ColorRect.new()
	fill.color = LabLook.CANVAS
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(fill)
	add_child(_canvas)
	_set_shown(false)
	reset()

func present(question: StringName, variants: AbVariants, live_state: Dictionary) -> void:
	_question = question
	_variants = variants
	_live_state = live_state
	if not _on: _enter()
	_camera.offset = Vector2.ZERO
	_refresh()

func hide_all(view: Node2D) -> void:
	if not _on: return
	_on = false
	_dragging = false
	_set_shown(false)
	view.set_palette_a(false)
	view.set_smooth(true)
	view.set_visuals(visuals)
	_camera.position = _camera_before

func key(code: Key) -> bool:
	match code:
		KEY_P: _panel_state = (_panel_state + 1) % LabPanel.STATES.size()
		KEY_G: _dark = not _dark
		KEY_D: _held = (_held + 1) % HELD_BOXES.size()
		KEY_V:
			if _question != &"health_bar": return false
			_live = not _live
		_: return false
	_refresh()
	return true

func pointer(event: InputEvent, view: Node2D) -> bool:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hovered = view.pick_entity(view.make_canvas_position_local(motion.position), true)
		if _dragging: _drag_point = motion.position
		_update()
		return true
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT: return false
	if button.pressed:
		_dragging = true
		_drag_start = button.position
		_drag_point = button.position
		_drag_selection = _selected.duplicate()
		_drag_shift = button.shift_pressed
	elif _dragging:
		_drag_point = button.position
		_release(view)
	_update()
	return true

func end_drag() -> void:
	_dragging = false
	_update()

func reset() -> void:
	_selected = _army.selected.duplicate()
	_hovered = _army.hovered
	_held = 0
	_dragging = false
	_live = false
	_was_live = false
	_refresh()

func status_line() -> String:
	var line: String = "panel %s (P) | ground %s (G) | box %s (D) | selected %d" % [LabPanel.STATES[_panel_state], "dark" if _dark else "sand", HELD_NAMES[_held], _selected.size()]
	if _question == &"health_bar": line += " | view %s (V)" % ("live" if _live_view() else "frozen")
	return line

func _process(_delta: float) -> void:
	if _on: _place_box()

func _enter() -> void:
	_on = true
	_set_shown(true)
	_view.set_palette_a(true)
	_view.set_smooth(false)
	_camera_before = _camera.position
	_camera.position = Iso.world_to_plane(LabArmy.CAMERA_FOCUS)

func _set_shown(on: bool) -> void:
	for node: CanvasItem in [_under, _over, _drag, _panels[0], _panels[1]]: node.visible = on
	_canvas.visible = on

func _live_view() -> bool:
	return _live and _question == &"health_bar"

func _refresh() -> void:
	if not _on: return
	if _live_view() != _was_live: _swap_selection()
	var source: Dictionary = _live_state if _live_view() else _army.state
	_shown = AbVariants.recolored(source, _variants.opponent_owner)
	_view.set_biome(0 if _dark else Palette.DEFAULT_BIOME)
	# The live fight's effects and turret angles belong to its ids, not the frozen army's.
	_view.set_visuals(visuals if _live_view() else null)
	_view.set_state(LabArmy.view_copy(_shown), [] as Array[int])
	_update()

# Frozen ids mean nothing in the live fight, so each view keeps its own selection and hover.
func _swap_selection() -> void:
	_was_live = not _was_live
	_dragging = false
	if _was_live:
		_frozen_selected = _selected
		_frozen_hovered = _hovered
		_selected = live_pick(_live_state)
		_hovered = -1
	else:
		_selected = _frozen_selected
		_hovered = _frozen_hovered

# Like the fixture: 5 own units at full health and 5 damaged, else the first 10 own.
static func live_pick(state: Dictionary) -> Array[int]:
	var own: Array[int] = []
	var full: Array[int] = []
	var damaged: Array[int] = []
	for row: Dictionary in state.entities:
		if row.owner != LabArmy.OWN: continue
		own.append(row.id)
		if row.hp == row.max_hp: full.append(row.id)
		else: damaged.append(row.id)
	if full.size() < 5 or damaged.size() < 5: return own.slice(0, 10)
	var picked: Array[int] = full.slice(0, 5)
	picked.append_array(damaged.slice(0, 5))
	picked.sort()
	return picked

func _update() -> void:
	if not _on: return
	_show_panels()
	_drag.style = _variants.variant(&"drag_box")
	var boxed: bool = LabDragBox.past_threshold(_drag_start, _drag_point) if _dragging else _held != 0
	var preview: Array[int] = []
	if boxed and _drag.style != BASELINE_STYLE:
		var start: Array[int] = _drag_selection if _dragging else _selected
		var shift: bool = _drag_shift if _dragging else _held == SHIFT_BOX
		preview = LabMarks.preview_ids(_view.pick_entities(_plane_box()), start, shift)
	_drag.showing = boxed
	_place_box()
	var model := {state = _shown, selected = _selected, hovered = _hovered, rule = _variants.variant(&"health_bar"), preview = preview, dragging = boxed, map_size = Vector2i(_shown.map.size[0], _shown.map.size[1])}
	_under.model = model
	_over.model = model

func _plane_box() -> Rect2:
	if not _dragging: return HELD_BOXES[_held]
	var from: Vector2 = _view.make_canvas_position_local(_drag_start)
	return Rect2(from, _view.make_canvas_position_local(_drag_point) - from)

func _place_box() -> void:
	if _dragging:
		_drag.box = Rect2(_drag_start, _drag_point - _drag_start)
	elif _held != 0:
		var xform: Transform2D = _view.get_global_transform_with_canvas()
		var rect: Rect2 = HELD_BOXES[_held]
		_drag.box = Rect2(xform * rect.position, xform * rect.end - xform * rect.position)

func _release(view: Node2D) -> void:
	_dragging = false
	if LabDragBox.past_threshold(_drag_start, _drag_point):
		var from: Vector2 = view.make_canvas_position_local(_drag_start)
		_selected = LabMarks.release_selection(view.pick_entities(Rect2(from, view.make_canvas_position_local(_drag_point) - from)), _drag_selection, _drag_shift)
		return
	var id: int = view.pick_entity(view.make_canvas_position_local(_drag_point))
	_selected = []
	if id != -1: _selected.append(id)

func _show_panels() -> void:
	var both: bool = _question == &"token_set"
	var swap: int = _variants.variant(&"token_set")
	var number_size: int = LabLook.VALUE_SIZES[_variants.variant(&"value_size")]
	_panels[1].visible = both
	var wanted: Array = [both, swap, number_size, _panel_state]
	if wanted == _panel_key: return
	_panel_key = wanted
	var state: StringName = LabPanel.STATES[_panel_state]
	if not both:
		_panels[0].show_state(state, LabLook.tokens(&"a"), number_size, 0, "")
		return
	for slot in 2:
		var token_set: StringName = [&"a", &"b"][slot ^ swap]
		_panels[slot].show_state(state, LabLook.tokens(token_set), TOKEN_SET_NUMBERS, slot, String(token_set).to_upper())
