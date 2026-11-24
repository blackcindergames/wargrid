extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")
const Factions = preload("res://scripts/simulation/definitions/factions.gd")

const PLAY_MAPS := {"dry_wells": "Dry Wells", "broken_crown": "Broken Crown", "ashfall": "Ashfall"}
const TEST_MAP := "skirmish"
const NOT_IN_BUILD := "The host's map is not in your build"
const BAD_BOTS := "The host's bot setup is not valid"
const TOO_SMALL := "The host's map has too few starting places for this match"

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
	return _bots_refusal(settings.get("bots"), seat_count, id)

static func _bots_refusal(rows: Variant, seat_count: int, id: String) -> String:
	if rows == null: return ""
	if rows is not Array or rows.is_empty(): return BAD_BOTS
	for i: int in rows.size():
		var row: Variant = rows[i]
		if row is not Dictionary or not Factions.FACTIONS.has(row.get("faction")): return BAD_BOTS
		var player: Variant = row.get("player")
		if typeof(player) not in [TYPE_INT, TYPE_FLOAT] or player != seat_count + 1 + i: return BAD_BOTS
	if seat_count + rows.size() > MapData.load(map_path(id)).starts.size(): return TOO_SMALL
	return ""

static func report_fields(id: String, match_seed: int, chosen: Array[int]) -> Dictionary:
	return {"map": id, "seed": match_seed, "starts": chosen}

static func starts(id: String, match_seed: int, team_ids: Array[int] = [1, 2]) -> Array[int]:
	# The test map keeps seat N on start N so pinned traces hold.
	if id == TEST_MAP: return []
	var chosen: Array[int] = []
	chosen.resize(team_ids.size())
	chosen.fill(0)
	return StartSpots.assign(MapData.load(map_path(id)), match_seed, team_ids, chosen)

static func _valid_id(id: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_]{1,32}$")
	return pattern.search(id) != null
