class_name PlaytestSession
extends RefCounted

const FORMAT: int = 1
const CURRENT := "current.json"
static var dir: String = "user://playtests"
static var current: PlaytestSession = null
static var last_filed: String = ""
var data: Dictionary = {}
var saved_at: String = ""
var last_match: int = -1
var _live: int = -1

static func resume_or_open(focus_id: String, build: String) -> PlaytestSession:
	if current != null: return current
	var session := new()
	session.data = _stored()
	if session.data.is_empty():
		session.data = {"format": FORMAT, "build": build, "focus": focus_id, "started": Time.get_datetime_string_from_system(true), "filled": false, "checklist": {}, "answers": {}, "matches": []}
	current = session
	return session

static func open_count() -> int:
	var shown: Dictionary = current.data if current != null else _stored()
	return shown.matches.size() if not shown.is_empty() else -1

static func open_focus() -> String:
	var shown: Dictionary = current.data if current != null else _stored()
	return str(shown.get("focus", ""))

static func file_name(started: String) -> String:
	return "session-%s.json" % started.replace(":", "-")

static func _stored() -> Dictionary:
	var path: String = dir.path_join(CURRENT)
	var json := JSON.new()
	var parsed: Variant = json.data if FileAccess.file_exists(path) and json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var valid: bool = parsed is Dictionary and parsed.get("format") == FORMAT and parsed.get("matches") is Array and parsed.get("answers") is Dictionary and parsed.get("checklist") is Dictionary
	if not valid: return {}
	if not parsed.has("filled"): parsed.filled = _has_content(parsed) # a 0.13.x file has no flag; its answers must survive
	return parsed

static func _has_content(stored: Dictionary) -> bool:
	for answer: Variant in stored.answers.values():
		if answer is Dictionary and (int(answer.get("score", 0)) > 0 or not str(answer.get("text", "")).is_empty()): return true
	return stored.checklist.values().has(true) or stored.matches.any(func(entry: Dictionary) -> bool: return not entry.get("markers", []).is_empty())

static func _open_sitting() -> PlaytestSession:
	if current != null: return current
	var stored: Dictionary = _stored()
	if stored.is_empty(): return null
	var session := new()
	session.data = stored
	return session

static func close_sitting(web: bool, download: Callable) -> void:
	var session: PlaytestSession = _open_sitting()
	if session == null: return
	if not session.filled():
		session.discard()
		return
	var filed: String = session.write(web, download)
	if not filed.is_empty(): last_filed = filed

static func settle(build: String, web: bool, download: Callable) -> void:
	var session: PlaytestSession = _open_sitting()
	if session != null and (str(session.data.get("build", "")) != build or (web and session.filled())): close_sitting(web, download)

func filled() -> bool:
	return bool(data.get("filled", false))

func start_match() -> void:
	_live = -1

func marker_match() -> int:
	return _live if _live >= 0 else last_match

func add_marker(marker: Dictionary, header: Dictionary) -> void:
	if _live < 0:
		data.matches.append(header.merged({"unfinished": true, "result": "unfinished", "commands": [], "markers": [], "end_tick": 0}))
		_live = data.matches.size() - 1
	var entry: Dictionary = data.matches[_live]
	entry.markers.append(marker)
	entry.end_tick = marker.tick
	data.filled = true
	_mirror()

func finish_match(record: Dictionary) -> int:
	var finished: Dictionary = record.duplicate(true)
	finished.markers = data.matches[_live].markers if _live >= 0 else []
	var index: int = _live if _live >= 0 else data.matches.size()
	if _live >= 0: data.matches[index] = finished
	else: data.matches.append(finished)
	_live = -1
	last_match = index
	_mirror()
	return index

func set_comment(match_index: int, marker_index: int, text: String) -> void:
	data.matches[match_index].markers[marker_index].comment = text
	if not text.is_empty(): data.filled = true
	_mirror()

func set_answer(question_id: String, score: int, text: String) -> void:
	data.answers[question_id] = {"score": score, "text": text}
	if score > 0 or not text.is_empty(): data.filled = true
	_mirror()

func set_checked(item_id: String, on: bool, manual: bool) -> void:
	data.checklist[item_id] = on
	if manual: data.filled = true
	_mirror()

func write(web: bool, download: Callable) -> String:
	var file: String = file_name(data.started)
	var json: String = JSON.stringify(data, "\t")
	var result: String = file
	if web:
		var kept: bool = _store("last-" + file, json) # the browser may block the download; this copy survives
		download.call(json.to_utf8_buffer(), file, "application/json")
		if not kept: return "" # a blocked download would leave no copy, so keep the sitting open
	else:
		if not _store(file, json): return ""
		result = ProjectSettings.globalize_path(dir.path_join(file))
	discard()
	return result

func discard() -> void:
	DirAccess.remove_absolute(dir.path_join(CURRENT))
	if current == self: current = null

func _mirror() -> void:
	if _store(CURRENT, JSON.stringify(data)): saved_at = Time.get_time_string_from_system().left(5)

func _store(file: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var out := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
	if out == null: return false
	var ok: bool = out.store_string(text)
	out.close()
	return ok
