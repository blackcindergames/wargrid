extends RefCounted

const BASE := Vector2i(1280, 720)
const WIDE := Vector2i(1728, 720)
const TALL := Vector2i(1280, 800)
const MAX_ASPECT := 2.4
const MIN_ASPECT := 1.6

static var writes: int = 0 # lets tests see that a resize settles instead of looping
static var _pending: bool = false

static func layout_for(window: Vector2i) -> Dictionary:
	var aspect: float = float(window.x) / float(maxi(window.y, 1))
	if aspect > MAX_ASPECT: return {"size": WIDE, "aspect": Window.CONTENT_SCALE_ASPECT_KEEP}
	if aspect < MIN_ASPECT: return {"size": TALL, "aspect": Window.CONTENT_SCALE_ASPECT_KEEP}
	return {"size": BASE, "aspect": Window.CONTENT_SCALE_ASPECT_EXPAND}

static func apply(root: Window) -> void:
	_write(root, layout_for(root.size))
	if not root.size_changed.is_connected(_on_size_changed.bind(root)): root.size_changed.connect(_on_size_changed.bind(root))

static func release(root: Window) -> void:
	if root.size_changed.is_connected(_on_size_changed.bind(root)): root.size_changed.disconnect(_on_size_changed.bind(root))
	_pending = false
	_write(root, {"size": BASE, "aspect": Window.CONTENT_SCALE_ASPECT_EXPAND})

# The engine emits size_changed inside _set_size() and re-attaches its rect afterwards, so a nested write could be lost.
static func _on_size_changed(root: Window) -> void:
	if _pending: return
	_pending = true
	_write_pending.call_deferred(root)

static func _write_pending(root: Window) -> void:
	if not _pending: return
	_pending = false
	_write(root, layout_for(root.size))

static func _write(root: Window, layout: Dictionary) -> void:
	if root.content_scale_size == layout.size and root.content_scale_aspect == layout.aspect: return
	writes += 1
	if root.content_scale_size != layout.size: root.content_scale_size = layout.size
	if root.content_scale_aspect != layout.aspect: root.content_scale_aspect = layout.aspect
