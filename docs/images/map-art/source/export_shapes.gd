extends SceneTree
# Dumps the shapes the game draws into JSON, using the game's own classes only.
# Run from the repository root: see meta.export_command.

const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")

const SLOT_NAMES: Array[String] = ["roof", "roof_dark", "side", "side_dark", "machine", "smoke", "owner_flat", "skin"]
const ZOOM_KEYS: Array[String] = ["0.5", "1", "2"]
const CHECK_SHAPES: Array[String] = ["usa_tank", "usa_factory", "usa_rifle_infantry"]
const CHECK_POSES: Array = [[0, 0], [11, 40]]
const PILE_BOXES: Array[int] = [0, 1, 5, 15, 40]
const DRAW_ORDER_TEXT := "Per part, in Shapes.parts order, prims are sorted back to front: key [cx + cy, offset.z, index] with (cx, cy) = offset.xy rotated by the part angle (ShapeBake._back_to_front). Part angle: fixed = 0; heading = bucket*TAU/64; turret = turret bucket*TAU/64, where bucket = posmod(roundi(angle/TAU*64), 64) (roundi rounds half away from zero). Turret parts rotate their pivot (cells, hull frame) by the HULL bucket; their prims are relative to that pivot. Prim ring: box = corners (-hx,-hy),(hx,-hy),(hx,hy),(-hx,hy); cylinder = n points at TAU*(i+0.5)/n of radius size.x/2 with n = 4/6/8 for detail 0/1/2. Each ring point = pivot_rot + (offset.xy + corner) rotated by the part angle (all in cell space). Faces per prim: first the top face as a fan (ring[0], ring[i], ring[i+1]) at lift top = (offset.z + size.z) * 3.5, slot = prim slot; then for each ring edge a->b with normal n = (b-a).rotated(-PI/2): skip when n.x + n.y <= 1e-3*|n| (back-facing); otherwise two side triangles (a,b,b) lifts (top,top,base) and (a,b,a) lifts (top,base,base), base = offset.z*3.5. Side slot: when the prim slot is roof, roof_dark or machine, the side slot is side if n.x - n.y < 0 else side_dark; any other prim slot keeps its own slot on the sides. Vertex screen position = world_to_plane(cell) with y -= lift (px). No per-face darkening beyond slots; roof_dark = owner.darkened(0.25). Parts are concatenated in order, no global sort across prims of different parts. Items are drawn sorted by (layer, floor((ax+ay)*1024), id); air items are shifted up by air_lift px; construction rise<1 adds lift*(1-rise) to every vertex y. Detail = GraphicsSettings.detail(quality, zoom): low quality 0; high: zoom<1 -> 0, <2 -> 1, else 2. Heading is quantised to 64 buckets, so a shape never rotates continuously. Fill only, no outline, no antialiasing."

func _init() -> void:
	# quit first: a script error below aborts this function, and the pending quit still ends the process (exit code 1).
	quit(1)
	var out_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_path = arg.substr(6)
	if out_path.is_empty():
		push_error("--out= missing")
		return
	var data := {"meta": _meta(), "palette": _palette(), "shapes": _shapes(), "extras": _extras(), "draw_order": _draw_order(), "projected_check": _projected_check()}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + out_path)
		return
	file.store_string(_ser(data, 0) + "\n")
	file.close()
	print("EXPORT OK shapes=%d extras=%d file=%s" % [data.shapes.size(), data.extras.size(), out_path])
	quit(0)

# --- meta / palette ---------------------------------------------------------

func _meta() -> Dictionary:
	var out: Array = []
	var project: String = ProjectSettings.globalize_path("res://")
	OS.execute("git", ["-C", project, "rev-parse", "HEAD"], out)
	var dirty: Array = []
	OS.execute("git", ["-C", project, "status", "--short"], dirty)
	var origin: Vector2 = Iso.world_to_plane(Vector2.ZERO)
	var ex: Vector2 = Iso.world_to_plane(Vector2(1, 0)) - origin
	var ey: Vector2 = Iso.world_to_plane(Vector2(0, 1)) - origin
	var zooms: Array = _zoom_steps()
	var details: Dictionary = {}
	for z: float in zooms: details[_num(z)] = GraphicsSettings.detail(GraphicsSettings.HIGH, z)
	return {
		"git_revision": String(out[0]).strip_edges(),
		"git_dirty": not String(dirty[0]).strip_edges().is_empty(),
		"date_utc": Time.get_datetime_string_from_system(true) + "Z",
		"godot_version": Engine.get_version_info().string,
		"projection": {
			"note": "screen_px = zoom * (plane + camera offset); plane = world_to_plane(cell) with y -= lift_px; lift_px = z_units * z_unit_px. Cell diamond is 64 px wide and 32 px tall.",
			"world_to_plane": "x_px = 32*(cx - cy), y_px = 16*(cx + cy)",
			"basis_x_per_cell": _vec(ex), "basis_y_per_cell": _vec(ey),
			"cell_width_px": ex.x - ey.x, "cell_height_px": ex.y + ey.y,
			"z_unit_px": Bake.Z_SCALE, "air_lift_px": WorldBatch.AIR_LIFT,
			"heading_buckets": Shapes.HEADING_BUCKETS, "heading_zero": "+x cell axis, i.e. screen down-right; default unit heading is [1,0] = 0 rad",
		},
		"zoom_steps": zooms,
		"detail_by_zoom_high_quality": details,
		"detail_low_quality": 0,
		"viewport": {
			"width": ProjectSettings.get_setting("display/window/size/viewport_width"),
			"height": ProjectSettings.get_setting("display/window/size/viewport_height"),
			"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode"),
			"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect", "keep"),
			"stretch_scale": ProjectSettings.get_setting("display/window/stretch/scale", 1.0),
			"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		},
		"slot_names": SLOT_NAMES,
		"shadow": {"ground_radius_px": WorldBatch.GROUND_SHADOW_RADIUS, "air_radius_px": WorldBatch.SHADOW_RADIUS, "colour": _hex(Palette.SHADOW), "alpha": Palette.SHADOW.a, "shape": "diamond (0,-r),(r,0),(0,r),(-r,0) at the anchor; only at High quality"},
		"export_command": "\"${GODOT_BIN:-godot}\" --headless --path game -s <repo>/docs/images/map-art/source/export_shapes.gd -- --out=<file>",
	}

func _palette() -> Dictionary:
	var owners: Dictionary = {}
	for owner in range(0, 9):
		var entry: Dictionary = {}
		for mode: String in ["normal", "neon"]:
			var slots: PackedColorArray = Palette.owner_colors(owner, mode == "neon")
			entry[mode] = {"hex": Array(slots).map(_hex), "rgb": Array(slots).map(func(c: Color) -> Array: return [_r(c.r), _r(c.g), _r(c.b)])}
		owners[str(owner)] = entry
	return {
		"owner_base": Array(Palette.OWNER_BASE).map(_hex), "owner_bright_neon": Array(Palette.OWNER_BRIGHT).map(_hex),
		"note": "owner index 1..8 maps to list position 0..7; owner 0 = neutral (NEUTRAL), other = FALLBACK. owner_slots[owner][mode].hex is indexed by slot number 0..7 (see meta.slot_names)",
		"owner_slots": owners,
		"neutral": _hex(Palette.NEUTRAL), "fallback": _hex(Palette.FALLBACK),
		"side": _hex(Palette.SIDE), "side_dark": _hex(Palette.SIDE_DARK), "machine": _hex(Palette.MACHINE), "skin": _hex(Palette.SKIN), "smoke": _hex(Palette.SMOKE),
		"sand": _hex(Palette.SAND),
		"ground": {"sand_biome_1": _ground(Palette.ground(1)), "other_biome_0": _ground(Palette.ground(0))},
		"default_biome": Palette.DEFAULT_BIOME,
		"health": {"green": _hex(Palette.HEALTH_GREEN), "yellow": _hex(Palette.HEALTH_YELLOW), "red": _hex(Palette.HEALTH_RED)},
	}

func _ground(row: Dictionary) -> Dictionary:
	return {"ground": _hex(row.ground), "cliff_top": _hex(row.cliff_top), "cliff_side": _hex(row.cliff_side)}

# match_screen.gd cannot be loaded standalone, so its ZOOMS line is read as text.
func _zoom_steps() -> Array:
	var zoom_line: RegExMatch = RegEx.create_from_string("const ZOOMS: Array\\[float\\] = \\[([^\\]]+)\\]").search(FileAccess.get_file_as_string("res://scripts/match/match_screen.gd"))
	var steps: Array = []
	if zoom_line == null:
		push_error("ZOOMS not found in match_screen.gd")
		return steps
	for part: String in zoom_line.get_string(1).split(","): steps.append(float(part.strip_edges()))
	return steps

# --- shapes -----------------------------------------------------------------

func _shapes() -> Array:
	var ids: Array[String] = []
	ids.append_array(Definitions.units())
	ids.append_array(Definitions.buildings())
	var found: Array = []
	for id in ids: found.append(_shape_entry(id))
	return found

func _shape_entry(id: String) -> Dictionary:
	var row: Dictionary = Definitions.kind(id)
	var role: StringName = Shapes.role(id)
	var entry := {"id": id, "name": row.get("display_name", id), "faction": id.get_slice("_", 0), "class": row.get("class", "building"), "role": String(role)}
	entry["layer"] = "air" if Definitions.air_kinds.has(id) else "ground"
	if row.has("footprint"): entry["footprint"] = _vec(row.footprint)
	for key: String in ["radius", "max_hp"]:
		if row.has(key): entry[key] = row[key]
	var extent: Rect2 = WorldBatch.pick_extent(id)
	entry["pick_extent_px"] = [_r(extent.position.x), _r(extent.position.y), _r(extent.size.x), _r(extent.size.y)]
	entry.merge(_geometry(role, 0))
	if row.has("footprint"):
		var variants: Dictionary = _damage_variants(role)
		if not variants.is_empty(): entry["damage_variants"] = variants
	return entry

func _geometry(role: StringName, variant: int) -> Dictionary:
	var parts: Array[Dictionary] = Shapes.parts(role, 0, variant)
	var prims: int = 0
	for part in parts: prims += part.prims.size()
	var out := {"has_turret": Shapes.has_turret(role), "parts": _parts_json(parts), "prim_count": prims}
	if _parts_json(Shapes.parts(role, 2, variant)) != out.parts:
		out["parts_by_detail"] = {"1": _parts_json(Shapes.parts(role, 1, variant)), "2": _parts_json(Shapes.parts(role, 2, variant))}
	out["tri_count"] = _tri_counts(role, variant)
	return out

func _damage_variants(role: StringName) -> Dictionary:
	var base: Array = _parts_json(Shapes.parts(role, 0, 0))
	var found: Dictionary = {}
	for variant: int in [1, 2]:
		var parts: Array = _parts_json(Shapes.parts(role, 0, variant))
		if parts != base: found[str(variant)] = {"parts": parts, "tri_count": _tri_counts(role, variant), "note": "WorldBatch.damage_stage: 1 = hp <= 70%, 2 = hp <= 35%"}
	return found

func _parts_json(parts: Array) -> Array:
	var out: Array = []
	for part: Dictionary in parts:
		var prims: Array = []
		for prim: Dictionary in part.prims:
			prims.append({"type": String(prim.type), "offset": _vec(prim.offset), "size": _vec(prim.size), "slot": prim.slot})
		out.append({"name": String(part.name), "angle": String(part.angle), "pivot": _vec(part.pivot), "prims": prims})
	return out

# Real bake output: ShapeBake.mesh points / 3, turret bucket = hull bucket.
func _tri_counts(role: StringName, variant: int) -> Dictionary:
	var out: Dictionary = {}
	for z in ZOOM_KEYS:
		var detail: int = GraphicsSettings.detail(GraphicsSettings.HIGH, float(z))
		var lo: int = 1 << 30
		var hi: int = 0
		var zero: int = 0
		for bucket in Shapes.HEADING_BUCKETS:
			var tris: int = _tris_at(role, variant, detail, bucket)
			if bucket == 0: zero = tris
			lo = mini(lo, tris)
			hi = maxi(hi, tris)
		out[z] = {"detail": detail, "heading0": zero, "min": lo, "max": hi}
	return out

func _tris_at(role: StringName, variant: int, detail: int, bucket: int) -> int:
	var total: int = 0
	for part in Shapes.parts(role, detail, variant).size():
		total += Bake.mesh(role, part, bucket, detail, variant, bucket).points.size() / 3
	return total

# --- extras -----------------------------------------------------------------

func _extras() -> Array:
	var used: Dictionary = {}
	for id in Definitions.units() + Definitions.buildings(): used[Shapes.role(id)] = true
	var found: Array = []
	for r: StringName in [&"default_building", &"default_vehicle"]:
		var entry := {"id": String(r), "role": String(r), "used_in": "game fallback only (Shapes.role returns it for a kind with no own role; no shipped definition does; test kinds do)"}
		entry.merge(_geometry(r, 0))
		found.append(entry)
	for r: StringName in [&"rubble_1", &"rubble_2", &"rubble_3"]:
		if not used.has(r):
			var entry := {"id": String(r), "role": String(r), "used_in": "game (frc_hole_N footprint N); listed because no definition reached it"}
			entry.merge(_geometry(r, 0))
			found.append(entry)
	var plain := {"id": "supply_source_default", "role": "supply_source", "variant": 0, "footprint": [4, 5], "boxes": 0, "used_in": "game: variant 0 = default 4x5 pile, level 0"}
	plain.merge(_geometry(&"supply_source", 0))
	found.append(plain)
	for fp in _pile_footprints():
		for boxes in PILE_BOXES:
			var variant: int = Shapes.source_variant(boxes, fp)
			var entry := {"id": "supply_source_%dx%d_boxes%d" % [fp.x, fp.y, boxes], "role": "supply_source", "variant": variant, "footprint": _vec(fp), "boxes": boxes, "used_in": "game (supply piles on maps; WorldBatch.structure_items; level = number of SUPPLY_STEPS [1,5,15,40] reached; owner 0 = neutral amber)"}
			entry.merge(_geometry(&"supply_source", variant))
			found.append(entry)
	found.append({"id": "_not_in_shapes_gd", "note": "wrecks, crates (other than supply piles), docks, scaffolds, projectiles do not exist as shapes. Scaffolds = building shapes lowered by WorldBatch rise (y += lift*(1-rise)). Other non-shape things drawn by WorldBatch: ground shadow diamond, horde ring (24 triangles, RING_RADIUS 11x5.5), muzzle/hit/fade quads, dash streak (see WorldBatch consts)."})
	return found

func _pile_footprints() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for file_name in DirAccess.get_files_at("res://data/maps"):
		if not file_name.ends_with(".json"): continue
		var map: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + file_name))
		if not map is Dictionary: continue
		for source: Dictionary in map.get("sources", []):
			var fp: Vector2i = Definitions.source_footprint(source)
			if not found.has(fp): found.append(fp)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * 16 + a.y < b.x * 16 + b.y)
	return found

# --- draw_order -------------------------------------------------------------

func _draw_order() -> Dictionary:
	return {
		"text": DRAW_ORDER_TEXT,
		"constants": {
			"z_unit_px": Bake.Z_SCALE, "heading_buckets": Shapes.HEADING_BUCKETS,
			"cylinder_segments_by_detail": [4, 6, 8], "cylinder_point_phase": 0.5,
			"side_cull_epsilon": 1e-3, "side_normal": "(b - a).rotated(-PI/2)", "visible_side_test": "normal.x + normal.y > 1e-3*|normal|",
			"side_slot_pair_for_slots": ["roof", "roof_dark", "machine"], "side_pair": ["side", "side_dark"], "side_pair_pick": "normal.x - normal.y < 0 -> side, else side_dark",
			"top_face": "triangle fan from ring[0], slot = prim slot",
			"depth_scale": WorldBatch.DEPTH_SCALE, "air_lift_px": WorldBatch.AIR_LIFT,
			"layers": {"ground": WorldBatch.LAYER_GROUND, "air": WorldBatch.LAYER_AIR},
		},
	}

# --- projected_check --------------------------------------------------------

func _projected_check() -> Array:
	var found: Array = []
	for id in CHECK_SHAPES:
		for pose: Array in CHECK_POSES:
			if pose[0] != 0 and id != "usa_tank": continue
			found.append(_check_entry(id, pose[0], pose[1]))
	return found

# The exact points and colours WorldBatch.build submits for one object at the origin (no shadow), owner 1.
func _check_entry(id: String, hull_bucket: int, turret_bucket: int, detail: int = 1) -> Dictionary:
	var heading: float = hull_bucket * TAU / Shapes.HEADING_BUCKETS
	var turret: float = turret_bucket * TAU / Shapes.HEADING_BUCKETS
	var item := {"id": 1, "kind": id, "owner": 1, "role": Shapes.role(id), "layer": WorldBatch.LAYER_AIR if Definitions.air_kinds.has(id) else WorldBatch.LAYER_GROUND, "anchor": Vector2.ZERO, "footprint": Vector2i.ONE, "heading": heading, "target_id": -1, "hp": 1, "max_hp": 1, "rise": 1.0, "boxes": 0, "variant": 0, "shadow": 0.0, "horde": false}
	var items: Array[Dictionary] = [item]
	var batch := WorldBatch.new()
	batch.build(items, {1: turret}, detail, false)
	var tris: Array = []
	for i in batch.triangle_count:
		var row: Array = []
		for k in 3:
			row.append(_r5(batch.points[i * 3 + k].x))
			row.append(_r5(batch.points[i * 3 + k].y))
		row.append(_hex(batch.colors[i * 3]))
		tris.append(row)
	return {"shape": id, "hull_bucket": hull_bucket, "turret_bucket": turret_bucket, "heading_rad": heading, "turret_rad": turret, "zoom": 1.0, "detail": detail, "owner": 1, "neon": false, "tri_count": batch.triangle_count, "tris_note": "each row: x0,y0,x1,y1,x2,y2,hex colour; px relative to the anchor, zoom 1, in submit order", "tris": tris}

# --- helpers ----------------------------------------------------------------

func _r(v: float) -> float:
	return snappedf(v, 1e-6)

func _r5(v: float) -> float:
	return snappedf(v, 1e-5)

func _num(z: float) -> String:
	return str(int(z)) if z == floorf(z) else str(z)

func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

func _vec(v: Variant) -> Array:
	if v is Vector3: return [_r(v.x), _r(v.y), _r(v.z)]
	if v is Vector2: return [_r(v.x), _r(v.y)]
	return [v.x, v.y]

func _flat(v: Variant) -> bool:
	if v is Array:
		return Array(v).all(func(e: Variant) -> bool: return not (e is Array or e is Dictionary))
	if v is Dictionary:
		return Dictionary(v).values().all(func(e: Variant) -> bool: return not (e is Dictionary) and (not (e is Array) or _flat(e)))
	return true

# Scalar arrays and short scalar dictionaries (a prim, a part header) stay on one line; the rest is indented.
func _ser(v: Variant, depth: int) -> String:
	if not (v is Array or v is Dictionary) or (_flat(v) and JSON.stringify(v).length() < 220):
		return JSON.stringify(v)
	var pad: String = "\t".repeat(depth + 1)
	var items: PackedStringArray = []
	if v is Array:
		for e: Variant in v: items.append(pad + _ser(e, depth + 1))
		return "[\n" + ",\n".join(items) + "\n" + "\t".repeat(depth) + "]"
	for k: Variant in v: items.append(pad + JSON.stringify(k) + ": " + _ser(v[k], depth + 1))
	return "{\n" + ",\n".join(items) + "\n" + "\t".repeat(depth) + "}"
