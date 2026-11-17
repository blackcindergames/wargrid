extends SceneTree
# Bakes every shape of an export through the game's own ShapeBake and writes the triangles for the page to compare.
# Run from the repository root: "${GODOT_BIN:-godot}" --headless --path game -s <repo>/docs/images/map-art/source/roundtrip.gd -- --in=<shapes json> --out=<json>

const Shapes = preload("res://scripts/presentation/shapes.gd")
const ShapeBake = preload("res://scripts/presentation/shape_bake.gd")

const DETAILS: Array[int] = [0, 1, 2]
const HULL_BUCKETS: Array[int] = [0, 8, 16, 24, 32, 40, 48, 56]
const TURRET_OFFSET := 11

func _init() -> void:
	# quit first: a script error below aborts this function, and the pending quit still ends the process (exit code 1).
	quit(1)
	var in_path: String = ""
	var out_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--in="): in_path = arg.substr(5)
		if arg.begins_with("--out="): out_path = arg.substr(6)
	if in_path.is_empty() or out_path.is_empty():
		push_error("--in= and --out= are required")
		return
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(in_path)) if FileAccess.file_exists(in_path) else null
	if not doc is Dictionary:
		push_error("cannot read " + in_path)
		return
	var poses: Array = _bake_all(doc)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + out_path)
		return
	file.store_string(JSON.stringify(poses))
	file.close()
	print("ROUNDTRIP BAKED %d" % poses.size())
	quit(0)

func _bake_all(doc: Dictionary) -> Array:
	var poses: Array = []
	for list_name: String in ["shapes", "extras"]:
		for entry: Dictionary in doc.get(list_name, []):
			if entry.has("parts"): _bake_entry(entry, poses)
	return poses

func _bake_entry(entry: Dictionary, poses: Array) -> void:
	var variants: Array[int] = [0]
	for key: String in entry.get("damage_variants", {}):
		variants.append(int(key))
	for variant in variants:
		var role := StringName("rt:%s:%d" % [entry.id, variant])
		var by_detail: Dictionary = {}
		for detail in DETAILS:
			by_detail[detail] = _game_parts(_raw_parts(entry, variant, detail))
		Shapes._parts_cache[role] = by_detail
		for detail in DETAILS:
			for hull in HULL_BUCKETS:
				poses.append(_pose(entry, role, variant, detail, hull))

func _raw_parts(entry: Dictionary, variant: int, detail: int) -> Array:
	if variant > 0:
		return entry.damage_variants[str(variant)].parts
	return entry.get("parts_by_detail", {}).get(str(detail), entry.parts)

# Built with the game's own part and primitive constructors so the dictionaries are the ones the bake reads.
func _game_parts(raw_parts: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for raw: Dictionary in raw_parts:
		var prims: Array = []
		for prim: Dictionary in raw.prims:
			prims.append(Shapes._prim(StringName(prim.type), _vec3(prim.offset), _vec3(prim.size), int(prim.slot)))
		found.append(Shapes._part(StringName(raw.name), StringName(raw.angle), prims, Vector2(raw.pivot[0], raw.pivot[1])))
	return found

func _vec3(raw: Array) -> Vector3:
	return Vector3(raw[0], raw[1], raw[2])

func _pose(entry: Dictionary, role: StringName, variant: int, detail: int, hull: int) -> Dictionary:
	var turret: int = (hull + TURRET_OFFSET) % Shapes.HEADING_BUCKETS if entry.get("has_turret", false) else hull
	var specs: Array[Dictionary] = Shapes.parts(role, detail)
	var tris: Array = []
	var order: Array = []
	for part in specs.size():
		var part_bucket: int = turret if specs[part].angle == &"turret" else hull
		_append_triangles(tris, ShapeBake.mesh(role, part, part_bucket, detail, 0, hull))
		order.append(_prim_order(specs[part], part_bucket))
	return {"shape": entry.id, "variant": variant, "detail": detail, "hull_bucket": hull, "turret_bucket": turret, "tris": tris, "order": order}

# The order the bake drew a part's prims in, so the page can tell a float-noise tie from a real difference.
func _prim_order(spec: Dictionary, part_bucket: int) -> Array:
	var angle: float = 0.0 if spec.angle == &"fixed" else part_bucket * TAU / Shapes.HEADING_BUCKETS
	var order: Array = []
	for prim: Dictionary in ShapeBake._back_to_front(spec.prims, angle):
		order.append(spec.prims.find(prim))
	return order

func _append_triangles(tris: Array, mesh: Dictionary) -> void:
	var points: PackedVector2Array = mesh.points
	for i in range(0, points.size(), 3):
		var row: Array = []
		for k in 3:
			row.append(snappedf(points[i + k].x, 1e-5))
			row.append(snappedf(points[i + k].y, 1e-5))
		row.append(mesh.slots[i])
		tris.append(row)
