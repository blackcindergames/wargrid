extends Node2D

# Team pings (design answers P7 part 2, 7-23 and Q6, Q7): one mark per player, the newest replaces, gone after 30 s.
const Iso = preload("res://scripts/presentation/isometric.gd")
const LIFE_USEC: int = 30000000
const FADE_USEC: int = 5000000
const PULSE_USEC: int = 1000000
const PULSES: int = 2
const ALLY := Color("69ceaa")
const UNDER := Color("0c141a")
const RING := Vector2(24, 12)
const ARROW: float = 28.0
const ARROW_INSET: float = 8.0
# Below the notice slab (48 + 28), so an arrow at the top edge never covers the strip, Menu or the notice.
const ARROW_TOP: float = 84.0
const CHEVRON: PackedVector2Array = [Vector2(-9, -10), Vector2(11, 0), Vector2(-9, 10), Vector2(-3, 0)]

signal jump(world: Vector2)

class Arrow extends Control:
	signal clicked(world: Vector2)
	var target: Vector2
	var direction: Vector2 = Vector2.RIGHT
	var _pressed: bool = false

	func _init() -> void:
		size = Vector2(ARROW, ARROW)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		visible = false
		gui_input.connect(_take_click)

	func _take_click(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null or click.button_index != MOUSE_BUTTON_LEFT: return
		accept_event()
		# On release like a Button: a jump on the press hid the arrow and dropped the release onto the map.
		var released: bool = _pressed and not click.pressed and Rect2(Vector2.ZERO, size).has_point(click.position)
		_pressed = click.pressed
		if released: clicked.emit(target)

	func _draw() -> void:
		var points := PackedVector2Array()
		for point: Vector2 in CHEVRON: points.append(size / 2.0 + point.rotated(direction.angle()))
		draw_colored_polygon(points, ALLY)
		points.append(points[0])
		draw_polyline(points, UNDER, 1.5)

var now_usec: Callable = Time.get_ticks_usec
var marks: Dictionary = {}
var arrows: Dictionary = {}
var _layer: Control
var _block: Callable
var _circle := PackedVector2Array()

func _init() -> void:
	name = "PingMarks"
	for i in 33: _circle.append(Vector2.from_angle(TAU * i / 32.0))

# Arrows are HUD surfaces: kept once made, since the Hud's blocker list holds them for the match.
func setup(layer: Control, block: Callable) -> void:
	_layer = layer
	_block = block

func add(player: int, target: Vector2) -> void:
	marks[player] = {"target": target, "started": now_usec.call()}
	queue_redraw()

func clear() -> void:
	marks.clear()
	for arrow: Arrow in arrows.values(): arrow.visible = false
	queue_redraw()

# `floor_y`: the highest dock surface's top, so an arrow never sits under the dock.
func advance(view: Rect2, to_screen: Transform2D, floor_y: float) -> void:
	if marks.is_empty(): return
	var now: int = now_usec.call()
	for player: int in marks.keys():
		if now - marks[player].started >= LIFE_USEC: marks.erase(player)
	for player: int in arrows:
		if not marks.has(player): arrows[player].visible = false
	for player: int in marks: _place_arrow(player, to_screen * Iso.world_to_plane(marks[player].target), view, floor_y)
	queue_redraw()

func _place_arrow(player: int, point: Vector2, view: Rect2, floor_y: float) -> void:
	var arrow: Arrow = arrows.get(player)
	# The band under the dock counts as off screen: a ring there would hide under the slab.
	if Rect2(view.position, Vector2(view.size.x, floor_y - view.position.y)).has_point(point):
		if arrow != null: arrow.visible = false
		return
	if arrow == null:
		arrow = Arrow.new()
		arrow.name = "PingArrow%d" % player
		arrow.clicked.connect(jump.emit)
		_layer.add_child(arrow)
		_block.call(arrow)
		arrows[player] = arrow
	var spot: Vector2 = arrow_spot(point, view, floor_y)
	arrow.target = marks[player].target
	arrow.direction = (point - spot).normalized()
	arrow.position = spot - arrow.size / 2.0
	arrow.visible = true
	arrow.queue_redraw()

# Along the line from the arrow area's centre to the ping, clamped into the area: 8 in from the edges, beyond the 3 px edge-scroll band, and 8 above the dock.
static func arrow_spot(point: Vector2, view: Rect2, floor_y: float) -> Vector2:
	var half: float = ARROW / 2.0
	var top_left: Vector2 = view.position + Vector2(ARROW_INSET + half, ARROW_TOP + half)
	var area := Rect2(top_left, Vector2(view.end.x - ARROW_INSET - half, floor_y - ARROW_INSET - half) - top_left)
	var centre: Vector2 = area.get_center()
	var offset: Vector2 = point - centre
	var reach: float = 1.0
	if offset.x != 0.0: reach = minf(reach, area.size.x / 2.0 / absf(offset.x))
	if offset.y != 0.0: reach = minf(reach, area.size.y / 2.0 / absf(offset.y))
	return centre + offset * reach

# The ring pulses twice, then holds and fades over its last 5 s; dark under-strokes keep it readable on sand (art direction §11).
func _draw() -> void:
	var now: int = now_usec.call()
	for player: int in marks:
		var age: int = now - marks[player].started
		var alpha: float = clampf(float(LIFE_USEC - age) / FADE_USEC, 0.0, 1.0)
		var centre: Vector2 = Iso.world_to_plane(marks[player].target)
		if age < PULSES * PULSE_USEC:
			var phase: float = float(age % PULSE_USEC) / PULSE_USEC
			_ring(centre, RING * (1.0 + phase), 2.5, alpha * 0.8 * (1.0 - phase))
		_ring(centre, RING, 3.0, alpha)
		draw_colored_polygon(_ellipse(centre, Vector2(5, 2.5)).slice(0, -1), Color(ALLY, alpha))

func _ring(centre: Vector2, radii: Vector2, width: float, alpha: float) -> void:
	var points: PackedVector2Array = _ellipse(centre, radii)
	draw_polyline(points, Color(UNDER, alpha), width + 2.0)
	draw_polyline(points, Color(ALLY, alpha), width)

func _ellipse(centre: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for unit: Vector2 in _circle: points.append(centre + unit * radii)
	return points
