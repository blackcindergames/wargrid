extends Node2D

const LabLook = preload("res://scripts/lab/lab_look.gd")
const WorldView = preload("res://scripts/presentation/world_view.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")

const TICK_SHARE: float = 0.32
const BAR_TRACK := Color(0, 0, 0, 0.7)

var on_top: bool = false
var _drawn_xform := Transform2D()
var model: Dictionary = {}:
	set(value):
		model = value
		queue_redraw()

static func unit_diamond(kind: String, plane: Vector2) -> PackedVector2Array:
	var row: Dictionary = Registry.kind(kind)
	var half: float = 16.0
	if row.get("class", "") == "infantry": half = 10.0
	elif CombatDefinitions.weapon(row.get("weapon", "")).get("damage_type", "") == "armor_piercing": half = 19.0
	return PackedVector2Array([plane + Vector2(0, -half / 2.0), plane + Vector2(half, 0), plane + Vector2(0, half / 2.0), plane + Vector2(-half, 0)])

static func hover_ticks(diamond: PackedVector2Array) -> PackedVector2Array:
	var ticks := PackedVector2Array()
	for i in 4:
		var corner: Vector2 = diamond[i]
		for neighbour: Vector2 in [diamond[(i + 1) % 4], diamond[(i + 3) % 4]]:
			ticks.append_array([corner, corner.lerp(neighbour, TICK_SHARE)])
	return ticks

static func edge_faces(map_size: Vector2i) -> Array[PackedVector2Array]:
	var drop := Vector2(0, LabLook.EDGE_HEIGHT)
	var west: Vector2 = Iso.world_to_plane(Vector2(0, map_size.y))
	var south: Vector2 = Iso.world_to_plane(Vector2(map_size))
	var east: Vector2 = Iso.world_to_plane(Vector2(map_size.x, 0))
	return [PackedVector2Array([west, south, south + drop, west + drop]), PackedVector2Array([east, south, south + drop, east + drop])]

static func bar_rects(top_left: Vector2, fraction: float) -> Dictionary:
	return {
		fill = Rect2(top_left, Vector2(WorldView.HEALTH_BAR.x * fraction, WorldView.HEALTH_BAR.y)),
		track = Rect2(top_left - Vector2.ONE, Vector2(26, 5)),
		frame = Rect2(top_left - Vector2(2, 2), Vector2(28, 7)),
	}

# Frame, track and fill only stay apart on whole screen pixels; below zoom 1 the bar keeps its 1x size.
static func screen_bar(rects: Dictionary, to_screen: Transform2D) -> Dictionary:
	var pixel: float = maxf(1.0, roundf(to_screen.get_scale().x))
	var anchor: Vector2 = (to_screen * rects.fill.position).round()
	var result := {scale = pixel}
	for part: String in ["frame", "track", "fill"]:
		var rect: Rect2 = rects[part]
		result[part] = Rect2(anchor + (rect.position - rects.fill.position) * pixel, (rect.size * pixel).round())
	return result

static func bars(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected: Array[int] = source.selected
	for row: Dictionary in source.state.entities:
		var top_left: Vector2 = WorldBatch.pick_extent(row.kind).position + _plane(row.position) + Vector2(0, -10)
		_add_bar(result, row, top_left, source, selected.has(row.id))
	for building: Dictionary in source.state.buildings:
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		var centre: Vector2 = Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0)
		var top_left: Vector2 = centre + Vector2(-WorldView.HEALTH_BAR.x / 2.0, -WorldBatch.top_lift(building.kind) - 10.0)
		_add_bar(result, building, top_left, source, selected.has(building.id))
	return result

static func _add_bar(result: Array[Dictionary], row: Dictionary, top_left: Vector2, source: Dictionary, selected: bool) -> void:
	if not LabLook.bar_shown(source.rule, selected, row.id == source.hovered, row.hp, row.max_hp): return
	var fraction: float = WorldView.hp_fraction(row.hp, row.max_hp)
	result.append({id = row.id, rects = bar_rects(top_left, fraction), fill = WorldView.health_color(fraction), frame = LabLook.PALETTE_A[row.owner - 1]})

static func preview_ids(picked: Array[int], start_selection: Array[int], shift: bool) -> Array[int]:
	var ids: Array[int] = []
	for id in picked:
		if not (shift and start_selection.has(id)): ids.append(id)
	return ids

static func release_selection(picked: Array[int], start_selection: Array[int], shift: bool) -> Array[int]:
	var ids: Array[int] = start_selection.duplicate() if shift else ([] as Array[int])
	for id in picked:
		if not ids.has(id): ids.append(id)
	ids.sort()
	return ids

static func _plane(at: Array) -> Vector2:
	return Iso.world_to_plane(Vector2(at[0], at[1]))

func _draw() -> void:
	if model.is_empty(): return
	if not on_top:
		var faces: Array[PackedVector2Array] = edge_faces(model.map_size)
		draw_colored_polygon(faces[0], LabLook.EDGE_SIDE)
		draw_colored_polygon(faces[1], LabLook.EDGE_SIDE.darkened(0.3))
		return
	var selected: Array[int] = model.selected
	var diamonds := {}
	for row: Dictionary in model.state.entities: diamonds[row.id] = unit_diamond(row.kind, _plane(row.position))
	for building: Dictionary in model.state.buildings:
		var definition: Dictionary = Definitions.building(building.kind)
		if selected.has(building.id) and not definition.is_empty(): _white_loop(_footprint(building, definition), 1.5, 4.5)
	for id in selected:
		if diamonds.has(id): _white_loop(diamonds[id], 1.25, 3.25)
	if not model.dragging and diamonds.has(model.hovered): _white_segments(hover_ticks(diamonds[model.hovered]), 1.5)
	for id: int in model.preview:
		if diamonds.has(id): _white_segments(hover_ticks(diamonds[id]), 1.5)
	_drawn_xform = get_global_transform_with_canvas()
	draw_set_transform_matrix(_drawn_xform.affine_inverse())
	for bar: Dictionary in bars(model): _draw_bar(bar, screen_bar(bar.rects, _drawn_xform))
	draw_set_transform_matrix(Transform2D.IDENTITY)

# Bars sit in screen pixels, so a pan or zoom must redraw them.
func _process(_delta: float) -> void:
	if on_top and visible and get_global_transform_with_canvas() != _drawn_xform: queue_redraw()

static func _footprint(building: Dictionary, definition: Dictionary) -> PackedVector2Array:
	var origin := Vector2(building.origin[0], building.origin[1])
	var size := Vector2(definition.footprint)
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)), Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])

func _white_loop(corners: PackedVector2Array, width: float, under: float) -> void:
	var closed: PackedVector2Array = corners.duplicate()
	closed.append(corners[0])
	draw_polyline(closed, LabLook.UNDER_STROKE, under, true)
	draw_polyline(closed, Color.WHITE, width, true)

func _white_segments(points: PackedVector2Array, width: float) -> void:
	draw_multiline(points, LabLook.UNDER_STROKE, width + 2.0, true)
	draw_multiline(points, Color.WHITE, width, true)

func _draw_bar(bar: Dictionary, screen: Dictionary) -> void:
	# A centred stroke on the inset rect keeps the outline inside the frame.
	draw_rect(screen.frame.grow(-screen.scale / 2.0), bar.frame, false, screen.scale)
	draw_rect(screen.track, BAR_TRACK)
	draw_rect(screen.fill, bar.fill)
