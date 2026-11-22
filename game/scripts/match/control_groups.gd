extends RefCounted

const COUNT: int = 9
const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
# Zero Hour's double tap window (ZH#5).
const DOUBLE_TAP_MSEC: int = 667

var now_msec: Callable = Time.get_ticks_msec
var _members: Array = []
var _tapped: int = -1
var _tapped_at: int = 0

func _init() -> void:
	reset()

func reset() -> void:
	_members.clear()
	for slot: int in COUNT:
		var empty: Array[int] = []
		_members.append(empty)
	_tapped = -1

func ids(slot: int) -> Array[int]:
	var found: Array[int] = []
	found.assign(_members[slot])
	return found

func save(slot: int, units: Array[int]) -> void:
	_release(units)
	_members[slot] = _sorted(units)

func add(slot: int, units: Array[int]) -> void:
	_release(units)
	_members[slot] = _sorted(_members[slot] + units)

func clear(slot: int) -> void:
	_members[slot] = []

func keep(slot: int, units: Array[int]) -> void:
	_members[slot] = units.duplicate()

# One group per unit (ZH#1).
func _release(units: Array[int]) -> void:
	for slot: int in COUNT:
		_members[slot] = _members[slot].filter(func(id: int) -> bool: return not units.has(id))

static func _sorted(units: Array) -> Array[int]:
	var result: Array[int] = []
	for id: int in units:
		if not result.has(id): result.append(id)
	result.sort()
	return result

# True on the second tap of one group within the window; a double tap starts the next pair afresh.
func double_tap(slot: int) -> bool:
	var now: int = now_msec.call()
	var again: bool = slot == _tapped and now - _tapped_at <= DOUBLE_TAP_MSEC
	_tapped = -1 if again else slot
	_tapped_at = now
	return again
