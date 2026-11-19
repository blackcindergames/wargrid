extends "res://scripts/presentation/world_view.gd"

const LabLook = preload("res://scripts/lab/lab_look.gd")

# shortcut: horde rings keep today's colours, they are not judged in the four questions; override _append_ring if one is.
class LabBatch extends "res://scripts/presentation/world_batch.gd":
	var palette_a: bool = false

	func _mesh_colors(mesh: Dictionary, owner: int) -> PackedColorArray:
		if not palette_a: return super(mesh, owner)
		var by_owner: Dictionary = mesh.get_or_add("colors", {})
		var key: int = owner + 2000
		if not by_owner.has(key):
			var palette: PackedColorArray = LabLook.owner_colors_a(owner)
			var slots: PackedByteArray = mesh.slots
			var built := PackedColorArray()
			built.resize(slots.size())
			for i in slots.size(): built[i] = palette[slots[i]]
			by_owner[key] = built
		return by_owner[key]

var _palette_a: bool = false

func _init() -> void:
	super()
	_batch = LabBatch.new()

func set_palette_a(on: bool) -> void:
	if on == _palette_a: return
	_palette_a = on
	(_batch as LabBatch).palette_a = on
	_structure_key = []
	_structures.queue_redraw()
	_rebuild_batch()

func _tint(owner_id: int) -> Color:
	if _palette_a and owner_id >= 1 and owner_id <= LabLook.PALETTE_A.size(): return LabLook.PALETTE_A[owner_id - 1]
	return super(owner_id)
