@warning_ignore_start("untyped_declaration")
extends RefCounted

const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Client = preload("res://scripts/net/headless_client.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")
const Wire = preload("res://scripts/net/wire.gd")
const MAP := "broken_crown"
const FACTIONS := {1: "usa", 2: "china", 3: "frc", 4: "usa"}

func cases() -> Array[Callable]:
	return [test_three_bots_seated, test_every_bot_plays, test_header_lists_every_seat, test_one_bot_header_unchanged, test_seats_follow_seat_numbers, test_replay_oracle_seats_every_faction, test_replay_oracle_one_bot_unchanged, test_replay_oracle_takes_recorded_starts, test_lobby_start_keeps_the_lobby_map]

func _driver(bots: int):
	var factions := {}
	for seat in range(1, bots + 2): factions[seat] = FACTIONS[seat]
	var driver = OfflineDriver.new(1)
	driver.create(MatchSettings.map_path(MAP), MatchSettings.starts(MAP, 7, MatchSettings.teams(1, bots)), factions, 7)
	return driver

# A full worker pump drops the step, so each tick waits for the worker before the next.
func _play(driver, ticks: int) -> void:
	for i in ticks:
		driver.step()
		while driver.pump.busy(): OS.delay_usec(200)
	driver.drain()

func test_three_bots_seated(runner) -> bool:
	var driver = _driver(3)
	var state: Dictionary = driver.pump.live().snapshot()
	var teams: Array = state.players.map(func(player: Dictionary) -> int: return player.team)
	runner.check(state.match.players == [1, 2, 3, 4] and teams == [1, 2, 2, 2], "OB1 four seats on teams 1 2 2 2, got %s %s" % [state.match.players, teams])
	runner.check(driver.bot_players() == [2, 3, 4] and driver.teams() == [1, 2, 2, 2], "OB1 bots 2 3 4, got %s %s" % [driver.bot_players(), driver.teams()])
	driver.stop()
	return true

func test_every_bot_plays(runner) -> bool:
	var driver = _driver(3)
	_play(driver, 300)
	var seen: Array = []
	for command: Dictionary in driver.record().commands:
		if not seen.has(command.player): seen.append(command.player)
	seen.sort()
	runner.check(seen == [2, 3, 4], "OB2 bots 2, 3 and 4 each issue a command within 300 ticks, got %s" % [seen])
	driver.stop()
	return true

func test_header_lists_every_seat(runner) -> bool:
	var driver = _driver(3)
	var header: Dictionary = driver.match_header()
	runner.check(header.factions == ["usa", "china", "frc", "usa"] and header.teams == [1, 2, 2, 2], "OB3 header lists four factions and teams, got %s %s" % [header.factions, header.teams])
	driver.stop()
	return true

func test_one_bot_header_unchanged(runner) -> bool:
	var driver = _driver(1)
	var header: Dictionary = driver.match_header()
	runner.check(header == {"mode": "offline", "factions": ["usa", "china"], "teams": [1, 2], "bots": []} and driver.bot_players() == [2] and driver.teams() == [1, 2], "OB4 one bot keeps today's header, got %s" % [header])
	driver.stop()
	return true

func test_seats_follow_seat_numbers(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.create(MatchSettings.map_path(MAP), MatchSettings.starts(MAP, 7, MatchSettings.teams(1, 2)), {3: "frc", 1: "usa", 2: "china"}, 7)
	var header: Dictionary = driver.match_header()
	runner.check(driver.bot_players() == [2, 3] and header.factions == ["usa", "china", "frc"], "OB5 seats and header follow seat numbers, not insertion order, got %s %s" % [driver.bot_players(), header.factions])
	driver.stop()
	return true

class OracleClient extends Client:
	func _exit() -> void:
		pass

func _oracle(map: String, factions: String, extra: Dictionary = {}):
	var log_path := "user://ob_replay-%d.log" % OS.get_process_id()
	FileAccess.open(log_path, FileAccess.WRITE).close()
	var client = OracleClient.new()
	client._args = {"map": map, "seed": "7", "replay-log": log_path, "oracle-ticks": "1", "factions": factions}.merged(extra)
	var error: String = client._faction_error()
	if error.is_empty(): client._replay_oracle()
	DirAccess.remove_absolute(log_path)
	return [client, error]

func test_replay_oracle_seats_every_faction(runner) -> bool:
	var got: Array = _oracle(MAP, "usa,china,frc,usa")
	var client = got[0]
	runner.check(got[1] == "", "OB6 four --factions entries are accepted, got '%s'" % got[1])
	var state: Dictionary = client._sim.snapshot() if client._sim != null else {"match": {"players": []}, "players": []}
	var teams: Array = state.players.map(func(player: Dictionary) -> int: return player.team)
	var factions: Array = state.players.map(func(player: Dictionary) -> String: return player.get("faction", ""))
	runner.check(state.match.players == [1, 2, 3, 4] and teams == [1, 2, 2, 2] and factions == ["usa", "china", "frc", "usa"], "OB6 a 1 vs 3 record replays on four seats, you against three bots, got %s %s %s" % [state.match.players, teams, factions])
	client.free()
	return true

func test_replay_oracle_one_bot_unchanged(runner) -> bool:
	var got: Array = _oracle("ashfall", "usa,china")
	var client = got[0]
	var before = Skirmish.create(true, "ai", {1: "usa", 2: "china"}, MatchSettings.map_path("ashfall"), MatchSettings.starts("ashfall", 7))
	before.step()
	runner.check(client._sim != null and StateHash.digest(client._sim.snapshot()) == StateHash.digest(before.snapshot()), "OB7 a 1v1 record replays exactly as before: two seats, teams 1 and 2")
	client.free()
	return true

func test_replay_oracle_takes_recorded_starts(runner) -> bool:
	var got: Array = _oracle(MAP, "usa,china,frc", {"starts": "4,2,1"})
	var client = got[0]
	var map: Dictionary = MapData.load(MatchSettings.map_path(MAP))
	var placed: bool = client._sim != null and [1, 2, 3].all(func(player: int) -> bool: return MapData.start_cell(client._sim.map_data(), player) == MapData.start_cell(map, [4, 2, 1][player - 1]))
	runner.check(placed, "OB8 --starts replays a record's picked starts, not the rule's")
	client._args["starts"] = "4,x"
	runner.check(not client._lobby_error().is_empty(), "OB8 a bad --starts is refused")
	client._args["starts"] = "4,2"
	runner.check(not client._lobby_error().is_empty(), "OB8 --starts must name one start per seat")
	client._args["starts"] = "4,,2,1"
	runner.check(not client._lobby_error().is_empty(), "OB8 an empty --starts entry is refused, not skipped")
	client.free()
	return true

func test_lobby_start_keeps_the_lobby_map(runner) -> bool:
	var client = OracleClient.new()
	client._args = {"map": "broken_crown", "lobby-maps": "ashfall", "start": "4"}
	client._transport = OnlineTests.FakeTransport.new()
	client._seat = 1
	client._present = 2
	client._joins = 1
	client._picked = {2: "usa"}
	client._try_start()
	var maps: Array = client._transport.sent.map(func(text: String) -> Variant: return Wire.decode(text).message.get("settings", {}).get("map"))
	runner.check(maps == ["ashfall", null], "OB9 the host's start pick goes out on its lobby map, not the --map it opened on, got %s" % [maps])
	client.free()
	return true
