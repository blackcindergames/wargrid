extends Control

const Palette = preload("res://scripts/presentation/palette.gd")
const BACK := Color("0c141a")
const MARK := Color("eef3f5")
const PAD := 14.0

var _size := Vector2.ONE
var _starts: Array[Vector2] = []
var _sources: Array[Vector2] = []

# The map file's size, start cells and supply origins, drawn as the isometric diamond the match shows.
func show_map(data: Dictionary) -> void:
	_size = Vector2(data.size[0], data.size[1])
	_starts.assign(data.starts.map(func(start: Dictionary) -> Vector2: return Vector2(start.cell[0], start.cell[1])))
	_sources.assign(data.sources.map(func(source: Dictionary) -> Vector2: return Vector2(source.origin[0], source.origin[1])))
	queue_redraw()

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
	for start: Vector2 in _starts:
		draw_circle(_point(start), 8.0, BACK)
		draw_arc(_point(start), 8.0, 0.0, TAU, 24, MARK, 1.5)
