extends Logger

# Godot calls this from any thread, so the counts are per thread id under their own lock; it logs nothing, so it cannot recurse.
var _mutex := Mutex.new()
var _counts: Dictionary = {}

func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING: return
	var id: int = OS.get_thread_caller_id()
	_mutex.lock()
	_counts[id] = int(_counts.get(id, 0)) + 1
	_mutex.unlock()

func count_for(id: int) -> int:
	_mutex.lock()
	var count: int = _counts.get(id, 0)
	_mutex.unlock()
	return count
