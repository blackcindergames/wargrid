extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")
const Factions = preload("res://scripts/simulation/definitions/factions.gd")

const PLAY_MAPS := {"dry_wells": "Dry Wells", "broken_crown": "Broken Crown", "ashfall": "Ashfall"}
const TEST_MAP := "skirmish"
const NOT_IN_BUILD := "The host's map is not in your build"
const BAD_BOTS := "The host's bot setup is not valid"
const TOO_SMALL := "The host's map has too few starting places for this match"
const BAD_STARTS := "The host's start setup is not valid"

static func map_path(id: String) -> String:
	return "res://data/maps/%s.json" % id

static func map_hash(path: String) -> String:
	# No .gitattributes, so a CRLF checkout must not make the hashes differ.
	return FileAccess.get_file_as_string(path).replace("\r", "").sha256_text()

static func for_map(id: String, bots: Array = []) -> Dictionary:
	var settings := {"map": id, "map_hash": map_hash(map_path(id))}
	if not bots.is_empty(): settings["bots"] = bots
	return settings

static func bot_players(settings: Dictionary) -> Array[int]:
	var players: Array[int] = []
	var rows: Variant = settings.get("bots", [])
	if rows is not Array: return players
	for row: Variant in rows:
		if row is Dictionary and typeof(row.get("player")) in [TYPE_INT, TYPE_FLOAT]: players.append(int(row.player))
	return players

static func teams(seats: int, bot_count: int = 0) -> Array[int]:
	var result: Array[int] = []
	for seat in seats + bot_count: result.append(seat + 1 if bot_count == 0 else (1 if seat < seats else 2))
	return result

static func refusal(settings: Dictionary, seat_count: int = 2) -> String:
	var id: Variant = settings.get("map")
	if not id is String or not _valid_id(id) or not FileAccess.file_exists(map_path(id)): return NOT_IN_BUILD
	var theirs: Variant = settings.get("map_hash")
	if not theirs is String or theirs != map_hash(map_path(id)): return "Your copy of %s differs from the host's" % PLAY_MAPS.get(id, id)
	# Key presence, not a null value: a crafted "bots": null would pass and break the start.
	var placed: bool = settings.has("chosen") or settings.has("closed")
	if not settings.has("bots") and not placed: return ""
	var seats: Array = MapData.load(map_path(id)).starts.map(func(start: Dictionary) -> int: return int(start.seat))
	var reason: String = _bots_refusal(settings.bots, seat_count) if settings.has("bots") else ""
	if reason.is_empty() and placed: reason = _starts_refusal(settings.get("chosen", []), settings.get("closed", []), seat_count, seats)
	if not reason.is_empty(): return reason
	if seat_count + settings.get("bots", []).size() + settings.get("closed", []).size() > seats.size(): return TOO_SMALL
	return ""

static func _bots_refusal(rows: Variant, seat_count: int) -> String:
	if rows is not Array or rows.is_empty(): return BAD_BOTS
	for i: int in rows.size():
		var row: Variant = rows[i]
		if row is not Dictionary or not Factions.FACTIONS.has(row.get("faction")): return BAD_BOTS
		var player: Variant = row.get("player")
		if typeof(player) not in [TYPE_INT, TYPE_FLOAT] or player != seat_count + 1 + i: return BAD_BOTS
	return ""

# Only the human seats choose; a start is chosen or closed at most once.
static func _starts_refusal(chosen: Variant, closed: Variant, seat_count: int, seats: Array) -> String:
	if chosen is not Array or closed is not Array: return BAD_STARTS
	var used: Dictionary = {}
	for start: Variant in closed:
		if not _taken(used, start, seats): return BAD_STARTS
	var players: Dictionary = {}
	for row: Variant in chosen:
		if row is not Dictionary or not _taken(players, row.get("player"), range(1, seat_count + 1)) or not _taken(used, row.get("start"), seats): return BAD_STARTS
	return ""

static func _taken(used: Dictionary, value: Variant, allowed: Array) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or value != floorf(value) or not allowed.has(int(value)) or used.has(int(value)): return false
	used[int(value)] = true
	return true

# Validated settings only: by player number, 0 where the rule places the player.
static func chosen_starts(settings: Dictionary, count: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(count)
	result.fill(0)
	for row: Dictionary in settings.get("chosen", []):
		if int(row.player) <= count: result[int(row.player) - 1] = int(row.start)
	return result

static func closed_starts(settings: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for start: Variant in settings.get("closed", []): result.append(int(start))
	return result

static func report_fields(id: String, match_seed: int, chosen: Array[int]) -> Dictionary:
	return {"map": id, "seed": match_seed, "starts": chosen}

# Settings may carry the players' chosen starts and the closed ones; a closed start leaves the map, so nobody is placed there.
static func starts(id: String, match_seed: int, team_ids: Array[int] = [1, 2], settings: Dictionary = {}) -> Array[int]:
	# The test map keeps seat N on start N so pinned traces hold.
	if id == TEST_MAP: return []
	var shut: Array[int] = closed_starts(settings)
	var open: Array = MapData.load(map_path(id)).starts.filter(func(start: Dictionary) -> bool: return not shut.has(int(start.seat)))
	return StartSpots.assign({"starts": open}, match_seed, team_ids, chosen_starts(settings, team_ids.size()))

static func _valid_id(id: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_]{1,32}$")
	return pattern.search(id) != null
