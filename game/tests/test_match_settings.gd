@warning_ignore_start("untyped_declaration")
extends RefCounted

const MatchSettings = preload("res://scripts/match_settings.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")
const Wire = preload("res://scripts/net/wire.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const JoinLink = preload("res://scripts/join_link.gd")

func cases() -> Array[Callable]:
	return [test_names, test_line_endings, test_refusals, test_test_map, test_seeded_starts, test_bots_round_trip, test_refusal_rejects_bad_bots, test_teams_from_bots, test_team_starts_side_by_side, test_invite_link_carries_no_settings, test_chosen_start_honoured, test_closed_start_excluded, test_starts_same_through_the_wire, test_refusal_rejects_bad_starts, test_chosen_starts_pinned_trace, test_refusal_rejects_bad_players, test_refusal_counts_seats_without_bots]

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
	runner.check(MatchSettings.refusal(base.merged({"bots": null}), 2) == MatchSettings.BAD_BOTS, "MS7 refused: a bots key that is null")
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

func _placed(chosen: Array, closed: Array = []) -> Dictionary:
	var rows: Array = []
	for pair: Array in chosen: rows.append({"player": pair[0], "start": pair[1]})
	return {"chosen": rows, "closed": closed}

func test_chosen_start_honoured(runner) -> bool:
	for s in 8:
		runner.check(MatchSettings.starts("broken_crown", s, MatchSettings.teams(1, 2), _placed([[1, 1]])) == ([1, 3, 2] as Array[int]), "MS11 seed %d: you keep start 1, the first bot takes the farthest (3), its teammate the closest to it (2)" % s)
		runner.check(MatchSettings.starts("ashfall", s, [1, 2] as Array[int], _placed([[2, 6]])) == StartSpots.assign(MapData.load(MatchSettings.map_path("ashfall")), s, [1, 2], [0, 6]), "MS11 seed %d: a guest's chosen start is honoured" % s)
	runner.check(MatchSettings.starts("ashfall", 3, [1, 2] as Array[int], _placed([[1, 4], [2, 8]])) == ([4, 8] as Array[int]), "MS11 both chosen starts are honoured")
	runner.check(MatchSettings.starts("ashfall", 3, [1, 2] as Array[int], {}) == StartSpots.assign(MapData.load(MatchSettings.map_path("ashfall")), 3, [1, 2], [0, 0]), "MS11 settings without picks keep today's starts")
	return true

func test_closed_start_excluded(runner) -> bool:
	for s in 8:
		runner.check(MatchSettings.starts("broken_crown", s, MatchSettings.teams(1, 2), _placed([[1, 1]], [3])) == ([1, 2, 4] as Array[int]), "MS12 seed %d: with start 3 closed the bots fill 2 and 4 by the rule" % s)
	var ok := true
	for s in 64:
		var got: Array[int] = MatchSettings.starts("ashfall", s, [1, 1, 2, 2] as Array[int], _placed([], [1, 2, 3, 4]))
		ok = ok and got.all(func(seat: int) -> bool: return seat >= 5) and got.size() == 4
	runner.check(ok, "MS12 nobody, bot or player, is placed on a closed start")
	return true

func test_starts_same_through_the_wire(runner) -> bool:
	var settings: Dictionary = MatchSettings.for_map("broken_crown", _bots(3, ["china"])).merged(_placed([[1, 4], [2, 2]], [1]))
	var decoded: Dictionary = Wire.decode(Wire.encode({"type": "start", "seats": [1, 2], "delay": 4, "seed": 5, "settings": settings})).message.settings
	var host: Array[int] = MatchSettings.starts("broken_crown", 5, MatchSettings.teams(2, 1), settings)
	runner.check(MatchSettings.refusal(decoded, 2).is_empty() and host == MatchSettings.starts("broken_crown", 5, MatchSettings.teams(2, 1), decoded) and host == ([4, 2, 3] as Array[int]), "MS13 both peers place the same starts from the wire's settings, got %s" % [host])
	return true

func test_refusal_rejects_bad_starts(runner) -> bool:
	var base: Dictionary = MatchSettings.for_map("broken_crown", _bots(3, ["china"]))
	var bad := {
		"chosen that is no list": {"chosen": {"player": 1, "start": 2}}, "a null chosen": {"chosen": null}, "a row that is no dictionary": {"chosen": [[1, 2]]},
		"player 0": _placed([[0, 2]]), "a bot's player": _placed([[3, 2]]), "a duplicate player": _placed([[1, 2], [1, 3]]), "a fractional player": _placed([[1.5, 2]]),
		"a start not on the map": _placed([[1, 5]]), "start 0": _placed([[1, 0]]), "a fractional start": _placed([[1, 2.5]]), "a start as text": _placed([[1, "2"]]), "a start taken twice": _placed([[1, 2], [2, 2]]),
		"a closed start chosen": _placed([[1, 2]], [2]), "closed that is no list": {"closed": 2}, "a null closed": {"closed": null}, "a closed start not on the map": _placed([], [9]), "a start closed twice": _placed([], [2, 2]),
	}
	for what: String in bad:
		runner.check(MatchSettings.refusal(base.merged(bad[what]), 2) == MatchSettings.BAD_STARTS, "MS14 refused: %s, got '%s'" % [what, MatchSettings.refusal(base.merged(bad[what]), 2)])
	runner.check(MatchSettings.refusal(base.merged(_placed([], [1, 2])), 2) == MatchSettings.TOO_SMALL, "MS14 refused: three players and two closed starts on four")
	runner.check(MatchSettings.refusal(MatchSettings.for_map("dry_wells").merged(_placed([], [1])), 2) == MatchSettings.TOO_SMALL, "MS14 refused: a closed start leaves a 1v1 one start")
	runner.check(MatchSettings.refusal(base.merged(_placed([[1, 2], [2, 4]], [1])), 2).is_empty(), "MS14 accepted: two picks and one closed start beside a bot")
	return true

const MS15_STARTS: Array[int] = [6, 1]
const MS15_DIGESTS: Array[String] = ["8eda411dce0324b8", "f3436b436dc9d2f0", "f05947326dc9d2f0"]

# A pinned trace with chosen starts settles both windows agreeing before any match.
func test_chosen_starts_pinned_trace(runner) -> bool:
	var settings: Dictionary = MatchSettings.for_map("ashfall", _bots(2, ["china"])).merged(_placed([[1, 6]], [2]))
	var teams: Array[int] = MatchSettings.teams(1, 1)
	var chosen: Array[int] = MatchSettings.starts("ashfall", 11, teams, settings)
	var digests: Array[String] = []
	for run in 2:
		var sim = Skirmish.create(true, "ai", {1: "usa", 2: "china"}, MatchSettings.map_path("ashfall"), chosen, 2, teams)
		for tick in 301:
			if tick % 150 == 0 and run == 0: digests.append(StateHash.digest(sim.snapshot()))
			if tick < 300:
				Skirmish.issue_opponents(sim, [2] as Array[int])
				sim.step()
		if run == 1: runner.check(StateHash.digest(sim.snapshot()) == digests[-1], "MS15 two runs from the same settings agree at tick 300")
	runner.check(chosen == MS15_STARTS, "MS15 chosen starts pinned, got %s" % [chosen])
	runner.check(digests == MS15_DIGESTS, "MS15 digests at ticks 0, 150 and 300 pinned, got %s" % [digests])
	return true

func test_refusal_rejects_bad_players(runner) -> bool:
	var base: Dictionary = MatchSettings.for_map("broken_crown")
	var bad := {"players that is no list": 5, "null players": null, "a row that is no dictionary": [1], "an unknown faction": [{"player": 1, "faction": "bogus"}], "player 0": [{"player": 0, "faction": "usa"}], "a player past the seats": [{"player": 3, "faction": "usa"}], "a duplicate player": [{"player": 1, "faction": "usa"}, {"player": 1, "faction": "china"}], "a faction that is no text": [{"player": 1, "faction": 5}]}
	for what: String in bad:
		runner.check(MatchSettings.refusal(base.merged({"players": bad[what]}), 2) == MatchSettings.BAD_PLAYERS, "MS16 refused: %s, got '%s'" % [what, MatchSettings.refusal(base.merged({"players": bad[what]}), 2)])
	runner.check(MatchSettings.refusal(base.merged({"players": [{"player": 1, "faction": "random"}, {"player": 2, "faction": "frc"}]}), 2).is_empty(), "MS16 accepted: the host's Random and the friend's faction")
	return true

func test_refusal_counts_seats_without_bots(runner) -> bool:
	runner.check(MatchSettings.refusal(MatchSettings.for_map("dry_wells"), 3) == MatchSettings.TOO_SMALL, "MS17 three seats do not fit Dry Wells' two starts even without bots")
	runner.check(MatchSettings.refusal(MatchSettings.for_map("dry_wells"), 2).is_empty(), "MS17 two seats fit")
	return true
