extends Control

signal start_pressed(seat: int, close: bool)

const Palette = preload("res://scripts/presentation/palette.gd")
const BACK := Color("0c141a")
const MARK := Color("eef3f5")
const SHUT := Color("93a5b0")
const PAD := 14.0
const HIT := 12.0

var _size := Vector2.ONE
var _starts: Array[Vector2] = []
var _seats: Array[int] = []
var _sources: Array[Vector2] = []
var _colours: Dictionary = {}
var _closed: Array[int] = []
var _tips: Dictionary = {}

# The map file's size, start cells and supply origins, drawn as the isometric diamond the match shows.
func show_map(data: Dictionary) -> void:
	_size = Vector2(data.size[0], data.size[1])
	_starts.assign(data.starts.map(func(start: Dictionary) -> Vector2: return Vector2(start.cell[0], start.cell[1])))
	_seats.assign(data.starts.map(func(start: Dictionary) -> int: return int(start.seat)))
	_sources.assign(data.sources.map(func(source: Dictionary) -> Vector2: return Vector2(source.origin[0], source.origin[1])))
	queue_redraw()

# colours: start seat -> the colour of the player there; tips: start seat -> its tooltip.
func show_starts(colours: Dictionary, closed: Array[int], tips: Dictionary) -> void:
	_colours = colours
	_closed = closed
	_tips = tips
	queue_redraw()

func seat_at(at: Vector2) -> int:
	for i in _starts.size():
		if at.distance_to(_point(_starts[i])) <= HIT: return _seats[i]
	return 0

func point_of(seat: int) -> Vector2:
	return _point(_starts[_seats.find(seat)])

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	var seat: int = seat_at(press.position)
	if seat == 0: return
	accept_event()
	start_pressed.emit(seat, press.button_index == MOUSE_BUTTON_RIGHT)

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
	if _colours.has(seat):
		draw_circle(at, 10.0, _colours[seat])
		draw_arc(at, 10.0, 0.0, TAU, 24, BACK, 2.0)
	elif _closed.has(seat):
		draw_circle(at, 9.0, BACK)
		draw_arc(at, 9.0, 0.0, TAU, 24, SHUT, 1.5)
		draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), SHUT, 2.0)
		draw_line(at + Vector2(4, -4), at + Vector2(-4, 4), SHUT, 2.0)
	else:
		draw_circle(at, 8.0, BACK)
		draw_arc(at, 8.0, 0.0, TAU, 24, MARK, 1.5)
