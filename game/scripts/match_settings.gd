extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")

const PLAY_MAPS := {"dry_wells": "Dry Wells", "broken_crown": "Broken Crown", "ashfall": "Ashfall"}
const TEST_MAP := "skirmish"
const NOT_IN_BUILD := "The host's map is not in your build"

static func map_path(id: String) -> String:
	return "res://data/maps/%s.json" % id

static func map_hash(path: String) -> String:
	# No .gitattributes, so a CRLF checkout must not make the hashes differ.
	return FileAccess.get_file_as_string(path).replace("\r", "").sha256_text()

static func for_map(id: String) -> Dictionary:
	return {"map": id, "map_hash": map_hash(map_path(id))}

static func bot_players(settings: Dictionary) -> Array[int]:
	var players: Array[int] = []
	var rows: Variant = settings.get("bots", [])
	if rows is not Array: return players
	for row: Variant in rows:
		if row is Dictionary and typeof(row.get("player")) in [TYPE_INT, TYPE_FLOAT]: players.append(int(row.player))
	return players

static func refusal(settings: Dictionary) -> String:
	var id: Variant = settings.get("map")
	if not id is String or not _valid_id(id) or not FileAccess.file_exists(map_path(id)): return NOT_IN_BUILD
	var theirs: Variant = settings.get("map_hash")
	if not theirs is String or theirs != map_hash(map_path(id)): return "Your copy of %s differs from the host's" % PLAY_MAPS.get(id, id)
	return ""

static func report_fields(id: String, match_seed: int, chosen: Array[int]) -> Dictionary:
	return {"map": id, "seed": match_seed, "starts": chosen}

static func starts(id: String, match_seed: int, teams: Array[int] = [1, 2]) -> Array[int]:
	# The test map keeps seat N on start N so pinned traces hold.
	if id == TEST_MAP: return []
	var chosen: Array[int] = []
	chosen.resize(teams.size())
	chosen.fill(0)
	return StartSpots.assign(MapData.load(map_path(id)), match_seed, teams, chosen)

static func _valid_id(id: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_]{1,32}$")
	return pattern.search(id) != null
