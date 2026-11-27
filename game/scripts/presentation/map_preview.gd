extends Control

signal start_pressed(seat: int)

const Palette = preload("res://scripts/presentation/palette.gd")
const BACK := Color("0c141a")
const MARK := Color("eef3f5")
const LIGHT := Color("60e5ed")
const PAD := 14.0
# Half of the 32 px click-target rule.
const HIT := 16.0

var _size := Vector2.ONE
var _starts: Array[Vector2] = []
var _seats: Array[int] = []
var _sources: Array[Vector2] = []
var _colours: Dictionary = {}
var _tips: Dictionary = {}
var _asking: Dictionary = {}
var _hovered: int = 0
var _next := LIGHT

# The map file's size, start cells and supply origins, drawn as the isometric diamond the match shows.
func show_map(data: Dictionary) -> void:
	_size = Vector2(data.size[0], data.size[1])
	_starts.assign(data.starts.map(func(start: Dictionary) -> Vector2: return Vector2(start.cell[0], start.cell[1])))
	_seats.assign(data.starts.map(func(start: Dictionary) -> int: return int(start.seat)))
	_sources.assign(data.sources.map(func(source: Dictionary) -> Vector2: return Vector2(source.origin[0], source.origin[1])))
	queue_redraw()

# colours: start seat -> the colour of the player there; pending: a start asked for but not yet in the host's settings.
# next: the colour of whoever a click on a free start would place.
func show_starts(colours: Dictionary, tips: Dictionary, pending: Dictionary = {}, next: Color = LIGHT) -> void:
	_colours = colours
	_next = next
	_tips = tips
	_asking = pending
	queue_redraw()

func seat_at(at: Vector2) -> int:
	var hit: float = hit_radius()
	for i in _starts.size():
		if at.distance_to(_point(_starts[i])) <= hit: return _seats[i]
	return 0

# Targets never overlap: half the gap to the nearest other start, at most HIT.
func hit_radius() -> float:
	var hit: float = HIT
	for i in _starts.size():
		for j in range(i + 1, _starts.size()): hit = minf(hit, _point(_starts[i]).distance_to(_point(_starts[j])) / 2.0)
	return hit

func point_of(seat: int) -> Vector2:
	return _point(_starts[_seats.find(seat)])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: _hover(seat_at(event.position))
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT: return
	var seat: int = seat_at(press.position)
	if seat == 0: return
	accept_event()
	# The second press of a double-click would give the start straight back.
	if press.double_click: return
	start_pressed.emit(seat)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT: _hover(0)

func _hover(seat: int) -> void:
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if seat != 0 else CURSOR_ARROW
	if seat == _hovered: return
	_hovered = seat
	queue_redraw()

func ring(seat: int) -> Color:
	return LIGHT if _colours.has(seat) or _asking.has(seat) else _next

func _get_tooltip(at: Vector2) -> String:
	return _tips.get(seat_at(at), "")

func _point(cell: Vector2) -> Vector2:
	var span := Vector2(_size.x + _size.y, (_size.x + _size.y) / 2.0)
	var scale_by: float = minf((size.x - 2.0 * PAD) / span.x, (size.y - 2.0 * PAD) / span.y)
	var offset: Vector2 = (size - span * scale_by) / 2.0
	return offset + Vector2(cell.x - cell.y + _size.y, (cell.x + cell.y) / 2.0) * scale_by

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(_size.x, 0), _size, Vector2(0, _size.y)]
	draw_colored_polygon(PackedVector2Array(corners.map(_point)), Palette.SAND)
	for source: Vector2 in _sources:
		var at: Vector2 = _point(source)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(4, 0), at + Vector2(0, 3), at + Vector2(-4, 0)]), Palette.NEUTRAL)
	for i in _starts.size(): _draw_start(_point(_starts[i]), _seats[i])

# Marker shapes from the lobby round picture (docs/images/lobby-round/lobby.html).
func _draw_start(at: Vector2, seat: int) -> void:
	if seat == _hovered: draw_arc(at, 13.0, 0.0, TAU, 32, ring(seat), 2.0)
	if _asking.has(seat):
		draw_circle(at, 8.0, BACK)
		draw_arc(at, 9.0, 0.0, TAU, 24, _asking[seat], 2.0)
	elif _colours.has(seat):
		draw_circle(at, 10.0, _colours[seat])
		draw_arc(at, 10.0, 0.0, TAU, 24, BACK, 2.0)
	else:
		_draw_dashed_ring(at, 8.0)

# A free start reads as open: dashes of about 3 px with 2 px gaps, like the picture's stroke-dasharray 3 2.
func _draw_dashed_ring(at: Vector2, radius: float) -> void:
	var dashes: int = roundi(TAU * radius / 5.0)
	var step: float = TAU / dashes
	for i in dashes: draw_arc(at, radius, i * step, i * step + step * 0.6, 4, MARK, 1.5)
