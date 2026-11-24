@warning_ignore_start("untyped_declaration")
extends RefCounted

const MatchSettings = preload("res://scripts/match_settings.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")
const Wire = preload("res://scripts/net/wire.gd")
const JoinLink = preload("res://scripts/join_link.gd")

func cases() -> Array[Callable]:
	return [test_names, test_line_endings, test_refusals, test_test_map, test_seeded_starts, test_bots_round_trip, test_refusal_rejects_bad_bots, test_teams_from_bots, test_team_starts_side_by_side, test_invite_link_carries_no_settings]

func test_names(runner) -> bool:
	for id: String in MatchSettings.PLAY_MAPS:
		runner.check(MatchSettings.PLAY_MAPS[id] == MapData.load(MatchSettings.map_path(id)).name, "MS1 display name of %s matches the map file" % id)
	return true

func test_line_endings(runner) -> bool:
	var original: String = MatchSettings.map_path("dry_wells")
	var copy := "user://ms2_crlf-%d.json" % OS.get_process_id()
	var file := FileAccess.open(copy, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(original).replace("\n", "\r\n"))
	file.close()
	runner.check(MatchSettings.map_hash(copy) == MatchSettings.map_hash(original), "MS2 line endings do not change the hash")
	DirAccess.remove_absolute(copy)
	return true

func test_refusals(runner) -> bool:
	var missing := "The host's map is not in your build"
	for bad: Dictionary in [{}, {"map": 5}, {"map": "../project"}, {"map": "nope"}, {"map": "../maps/ashfall", "map_hash": MatchSettings.map_hash(MatchSettings.map_path("ashfall"))}, {"map": "../../../protocol/vectors/hello", "map_hash": "0"}, {"map": "ASHFALL", "map_hash": MatchSettings.map_hash(MatchSettings.map_path("ashfall"))}]:
		runner.check(MatchSettings.refusal(bad) == missing, "MS3 an unknown map id is refused: %s" % str(bad))
	for bad: Dictionary in [{"map": "ashfall"}, {"map": "ashfall", "map_hash": "0"}]:
		runner.check(MatchSettings.refusal(bad) == "Your copy of Ashfall differs from the host's", "MS3 a different map file is refused: %s" % str(bad))
	for id: String in ["dry_wells", "broken_crown", "ashfall", "skirmish"]:
		runner.check(MatchSettings.refusal(MatchSettings.for_map(id)).is_empty(), "MS3 own settings for %s are accepted" % id)
	return true

func test_test_map(runner) -> bool:
	runner.check(MatchSettings.starts("skirmish", 9).is_empty(), "MS4 the test map keeps its seats")
	return true

func test_seeded_starts(runner) -> bool:
	var map: Dictionary = MapData.load(MatchSettings.map_path("ashfall"))
	for s in 4:
		var got: Array[int] = MatchSettings.starts("ashfall", s)
		runner.check(got.size() == 2 and got == StartSpots.assign(map, s, [1, 2], [0, 0]), "MS5 a play map gets seeded starts for seed %d" % s)
	return true

func _bots(first: int = 3, factions: Array = ["china", "frc"]) -> Array:
	var rows: Array = []
	for i in factions.size(): rows.append({"player": first + i, "faction": factions[i]})
	return rows

func test_bots_round_trip(runner) -> bool:
	runner.check(not MatchSettings.for_map("ashfall").has("bots"), "MS6 a 1v1 hello carries no bots key")
	var settings: Dictionary = MatchSettings.for_map("ashfall", _bots())
	var decoded: Dictionary = Wire.decode(Wire.encode({"type": "start", "seats": [1, 2], "delay": 4, "seed": 1, "settings": settings}))
	runner.check(decoded.ok, "MS6 the start message decodes, got %s" % decoded.error)
	var got: Dictionary = decoded.message.settings
	runner.check(MatchSettings.bot_players(got) == ([3, 4] as Array[int]), "MS6 the readers return whole-number players as ints, got %s" % [MatchSettings.bot_players(got)])
	runner.check(got.bots[1].faction == "frc" and got.map == "ashfall", "MS6 factions and map survive the wire")
	runner.check(MatchSettings.refusal(got, 2).is_empty(), "MS6 the host's own settings are accepted by a guest")
	return true

func test_refusal_rejects_bad_bots(runner) -> bool:
	var base: Dictionary = MatchSettings.for_map("ashfall")
	var bad_rows := {
		"an unknown faction": _bots(3, ["china", "nope"]), "a relay seat": _bots(2), "a duplicate": _bots(3, ["usa", "usa"]).map(func(row: Dictionary) -> Dictionary: return row.merged({"player": 3}, true)),
		"player 0": _bots(0), "a negative player": _bots(-1), "past 8": _bots(9), "out of order": [{"player": 4, "faction": "usa"}, {"player": 3, "faction": "usa"}],
		"a gap": _bots(4), "a fraction": [{"player": 3.5, "faction": "usa"}], "a row that is no dictionary": [3, 4],
	}
	for what: String in bad_rows:
		runner.check(not MatchSettings.refusal(base.merged({"bots": bad_rows[what]}), 2).is_empty(), "MS7 refused: %s" % what)
	runner.check(not MatchSettings.refusal(base.merged({"bots": "3"}), 2).is_empty(), "MS7 refused: bots that is no list")
	runner.check(MatchSettings.refusal(base.merged({"bots": []}), 2) == MatchSettings.BAD_BOTS, "MS7 refused: an empty bots list")
	runner.check(not MatchSettings.refusal(base.merged({"bots": _bots(3, ["usa"])}), 3).is_empty(), "MS7 refused: bots counted from the wrong seat count")
	for id: String in ["dry_wells", "skirmish"]:
		runner.check(not MatchSettings.refusal(MatchSettings.for_map(id, _bots()), 2).is_empty(), "MS7 refused: four players on %s, which has two starts" % id)
	for id: String in ["broken_crown", "ashfall"]:
		runner.check(MatchSettings.refusal(MatchSettings.for_map(id, _bots()), 2).is_empty(), "MS7 accepted: two seats and two bots on %s" % id)
	return true

func test_teams_from_bots(runner) -> bool:
	runner.check(MatchSettings.teams(2, 0) == ([1, 2] as Array[int]), "MS8 no bots: one team per seat")
	runner.check(MatchSettings.teams(2, 2) == ([1, 1, 2, 2] as Array[int]), "MS8 two seats and two bots: humans on team 1, bots on team 2")
	return true

func test_team_starts_side_by_side(runner) -> bool:
	for id: String in ["broken_crown", "ashfall"]:
		var map: Dictionary = MapData.load(MatchSettings.map_path(id))
		for s in range(1, 6):
			var got: Array[int] = MatchSettings.starts(id, s, [1, 1, 2, 2] as Array[int])
			var cells: Array[Vector2i] = []
			for seat: int in got: cells.append(MapData.start_cell(map, seat))
			var nearest: Array[int] = [-1, -1]
			for k in 2:
				var best := INF
				for j in 4:
					if j != k and Vector2(cells[k] - cells[j]).length() < best:
						best = Vector2(cells[k] - cells[j]).length()
						nearest[k] = j
			runner.check(nearest[0] == 1 and nearest[1] == 0, "MS9 %s seed %d: players 1 and 2 are each other's nearest start, got %s" % [id, s, got])
	return true

func test_invite_link_carries_no_settings(runner) -> bool:
	var link: String = JoinLink.link("https://example.test/", "ABC234", JoinLink.DEFAULT_RELAY)
	runner.check(link == "https://example.test/?code=ABC234", "MS10 the invite link holds the code only, got %s" % link)
	return true
