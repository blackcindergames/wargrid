extends RefCounted

const Orders = preload("res://scripts/match/orders.gd")
# OpenRA's dead zone: a right press that stays this close is a click, past it a pan.
const SLOP: float = 8.0
# 100 px from the anchor pans at the arrow keys' 400 px/s.
const ANCHOR_SPEED: float = 4.0
# shortcut: Godot's macOS pan gesture is the scroll delta in points scaled by 0.03 (not checked in its source), so ~33 px per unit; tune if the trackpad feels slow or fast.
const GESTURE_PX: float = 33.0
# A pinch steps the zoom once its accumulated factor passes this, either way.
const PINCH_STEP: float = 1.25

var _screen: Node
var _press: InputEventMouseButton = null
var _anchoring: bool = false
var _pointer: Vector2
var _grabbing: bool = false
var _grab_last: Vector2
var _pinch: float = 1.0

func _init(screen: Node) -> void:
	_screen = screen

func anchoring() -> bool:
	return _anchoring

# Zero Hour's anchor scroll (GeneralsGameCode afc2a103f LookAtXlat.cpp:256-281, :476-483): speed grows with distance from the press.
func anchor_offset() -> Vector2:
	return (_pointer - _press.position) * ANCHOR_SPEED if _anchoring else Vector2.ZERO

# Presses come only from the map (`_unhandled_input`); motion and releases come from `_input` too, so this stays idempotent.
func take(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	# Zero Hour starts no RMB scroll under a drag box (LookAtXlat.cpp:266); orders ignore these presses there.
	if button != null and button.pressed and _screen.orders.is_selecting(): return false
	# A release lost off-window must not swallow the next click.
	if button != null and button.pressed and button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]: drop()
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		_press = button
		_pointer = button.position
		return true
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_MIDDLE:
		_grabbing = true
		_grab_last = button.position
		return true
	if event is InputEventPanGesture:
		_screen.grab_camera((event as InputEventPanGesture).delta * GESTURE_PX / _screen.get_node("Camera2D").zoom.x)
		return true
	if event is InputEventMagnifyGesture:
		_pinched((event as InputEventMagnifyGesture).factor)
		return true
	return follow(event)

func _pinched(factor: float) -> void:
	_pinch *= factor
	if _pinch < PINCH_STEP and _pinch > 1.0 / PINCH_STEP: return
	_screen.change_zoom(1 if _pinch > 1.0 else -1)
	_pinch = 1.0

func follow(event: InputEvent) -> bool:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
		if _press != null and not _anchoring and _pointer.distance_to(_press.position) > SLOP: _set_anchoring(true)
		# Relative steps, so a zoom mid-grab does not jump; the second call per event moves zero.
		if _grabbing: _screen.grab_camera((_grab_last - _pointer) / _screen.get_node("Camera2D").zoom.x)
		_grab_last = _pointer
		return false
	var button := event as InputEventMouseButton
	if button == null or button.pressed: return false
	if button.button_index == MOUSE_BUTTON_MIDDLE and _grabbing:
		_grabbing = false
		return true
	if button.button_index != MOUSE_BUTTON_RIGHT or _press == null: return false
	var press: InputEventMouseButton = _press
	_press = null
	if _anchoring:
		_set_anchoring(false)
		return true
	if not _screen.menu_open(): _screen.orders.handle(press)
	return false

func drop() -> void:
	_press = null
	_grabbing = false
	if _anchoring: _set_anchoring(false)

func _set_anchoring(on: bool) -> void:
	_anchoring = on
	Orders.set_cursor.call(Input.CURSOR_MOVE if on else (Input.CURSOR_CROSS if _screen.orders._attack_move_mode else Input.CURSOR_ARROW))
