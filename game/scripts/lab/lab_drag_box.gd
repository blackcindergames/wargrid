extends Control

const LabLook = preload("res://scripts/lab/lab_look.gd")

const THRESHOLD: float = 6.0
const LINE_WIDTH: float = 1.5
const FILL := Color(1, 1, 1, 0.04)
const GREEN_TODAY := Color(0.55, 1, 0.53)

var style: int = 0:
	set(value):
		style = value
		queue_redraw()
var box: Rect2 = Rect2():
	set(value):
		box = value.abs()
		queue_redraw()
var showing: bool = false:
	set(value):
		showing = value
		queue_redraw()

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

static func past_threshold(start: Vector2, point: Vector2) -> bool:
	return start.distance_to(point) >= THRESHOLD

func _draw() -> void:
	if not showing: return
	if style == 2:
		draw_rect(box, GREEN_TODAY, false, 1.0)
		return
	if style == 1: draw_rect(box, FILL)
	draw_rect(box, LabLook.UNDER_STROKE, false, LINE_WIDTH + 2.0)
	draw_rect(box, Color.WHITE, false, LINE_WIDTH)
