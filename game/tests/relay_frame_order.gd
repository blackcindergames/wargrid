extends RefCounted

# Mirrors relay/room.go forward, onOver, onAgain, rematch at 6ae89cd, and onSettings, onStartRequest (P20), for one seat.
const Wire = preload("res://scripts/net/wire.gd")

var delay: int = 4
var refusals: Array[String] = []
var _last: int = 0
var _over: bool = false
var _again: bool = false
var _started: bool = false
var _requested: bool = false

func accepts(text: String) -> bool:
	var message: Dictionary = Wire.decode(text).message
	var type: String = message.get("type", "")
	var ok := true
	match type:
		"tick": ok = not _over and message.tick == maxi(_last, delay - 1) + 1
		"over": ok = not _over and _last != 0
		"again": ok = _over and not _again
		"settings", "pick": ok = not _started
		"start_request": ok = not _started and not _requested
	if not ok:
		refusals.append("%s %s refused" % [type, str(message.tick) if type == "tick" else ""])
		return false
	match type:
		"tick": _last = message.tick
		"over": _over = true
		"again": _again = true
		"start_request": _requested = true
	return true

# relay/room.go ignores a start_request sent before the room is full, so one that crossed a leave may be sent again.
func seat_left() -> void:
	if not _started: _requested = false

func rematch() -> void:
	_started = true
	_last = 0
	_over = false
	_again = false
