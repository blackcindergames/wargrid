extends Control

const Lockstep = preload("res://scripts/net/lockstep.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const Wire = preload("res://scripts/net/wire.gd")
const OnlineScene = preload("res://scenes/skirmish.tscn")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const VolumeSliders = preload("res://scripts/presentation/volume_sliders.gd")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Credits = preload("res://scripts/presentation/credits.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const JoinLink = preload("res://scripts/join_link.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const FocusCardView = preload("res://scripts/playtest/focus_card_view.gd")
const PasteShim = preload("res://scripts/presentation/paste_shim.gd")
const ViewCaps = preload("res://scripts/presentation/view_caps.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const OFFLINE_SCENE: String = "res://scenes/skirmish.tscn"
const HEADLESS_FLAGS: Array[String] = ["--netclient", "--relay", "--replay-log", "--probe-relay"]
const DashedPanel = preload("res://scripts/presentation/dashed_panel.gd")
const PAGES: Array[String] = ["Play", "Settings", "Credits"]
const SHELL: Array[String] = ["SidebarBg", "ContentBg", "Sidebar", "Pages"]
const PLAYERS := "Pages/Play/Body/Players"
const TEAMS := PLAYERS + "/Teams/List"
# Rows the team list shows before it scrolls: the most that leave the footer on a 720 px high window.
const ROWS_SHOWN := 5
const MAP_COLUMN := "Pages/Play/Body/MapColumn"
const ONLINE := "Pages/Settings/Body/Playtest/Online"
const RELAY_FIELD := ONLINE + "/RelayUrl"
const MODE_BAR := "Pages/Play/ModeBar"
const JOIN := "Pages/Play/JoinPage"
const MODES: Dictionary = {"skirmish": "Skirmish", "host": "Host", "join": "Join"}
const RANDOM := LauncherSettings.RANDOM
# Fits "Free Resistance Coalition" at 13 px with the arrow; every row reserves it, so the columns line up.
const FACTION_WIDTH := 224.0
const ACTION_WIDTH := 40.0
const REMOVE_ICON = preload("res://ui/remove_x.svg")
const COPY_ICON = preload("res://ui/copy.svg")
const CHECK_ICON = preload("res://ui/check.svg")
# Page content is 960 px wide: leaves room for the 170 px button, the gap and the strip padding.
const STATUS_WIDTH := 700.0
const HOST_CANCELLED := "Hosting cancelled"
const JOIN_CANCELLED := "Join cancelled"
const HOSTING_STOPPED := "Hosting stopped. The code no longer works."
const DID_NOT_JOIN := "Your friend did not join in time." + NEW_CODE
const SKIRMISH_SUBTITLE := "Play against bots on this computer."
const HOST_SUBTITLE := "Invite a friend with a code; add bots to fill the teams."
const JOIN_SUBTITLE := "Play with a friend who is hosting."
const GUEST_SUBTITLE := "Joined your friend’s game · the host sets up the match"
const STOP_TITLE := "Stop hosting?"
const STOP_TEXT := "Your friend leaves and the code stops working. Your bots and map stay."
const LEAVE_TITLE := "Leave the game?"
const LEAVE_TEXT := "You leave your friend's game. The code still works if you want to join again."
const NEED_CODE := "Enter the 6-character invite code."
const FROM_LINK := "Filled in from your friend’s link."
# The relay also says "unknown match" for an expired or crashed room, and "match full" for a started one.
const NO_GAME := "No open game with code %s. Check the code, or ask your friend for a new one."
const GAME_FULL := "That game is full or has already started. Ask your friend to host a new one."
const BIGGER_MAP := "a bigger map fits more bots"
const ONLINE_BOTS := "online games take up to %d bots"
const NO_BOT := "Add a bot to play against."
const FRIEND_WAIT := "Start match unlocks when your friend joins"
const READY := "Everyone is here. Start when you are ready"
const WAITING_FOR_HOST := "Waiting for the host to start"
const STARTING := "Starting…"
const CLOCK := " · room closes in %d:%02d"
# The clock shows only when it matters, so the footer does not tick for 15 minutes.
const CLOCK_FROM_SEC := 180
const ROOM_CLOSED := "The room closed: nothing changed for 15 minutes."
const ROOM_GONE := "The room closed after an hour."
const NEW_CODE := " Press Try again for a new code."
const ROOM_CLOSED_HOST := ROOM_CLOSED + NEW_CODE
const LEFT_GAME := "You left the game"
const UNREACHABLE := "Can't reach the relay (%s). Check your connection and try again."
const CUE_MSEC := 5000
# Under the relay's settings refill of 2/s with margin, so a steady sender never drains its burst of 10 (relay/limits.go).
const SETTINGS_GAP_MSEC := 750
# The tested 2v2 layout; Palette.team_colours colours only two bots.
const HOST_BOTS := 2
const PICKS_AT_START := "Picks at start"
const FRIEND_JOINED := "Your friend joined"
const FRIEND_LEFT := "Your friend left"
const MAP_CHANGED := "Host changed the map to %s"
const BOT_ADDED := "Host added a bot"
const BOT_REMOVED := "Host removed a bot"
const BOT_FACTION := "Host changed a bot's faction"
const SETUP_CHANGED := "Host changed the setup"
const HOST_PICKED := "Host picked %s"
const HOST_GONE := "The host stopped hosting. Ask them for a new code."
const INVITE_TIP := "Send this code to your friend. They enter it under Join game."
const INVITE_TIP_WEB := "Send this link to your friend."
const VERSION_MISMATCH := "Your game is v%s; your friend’s is different. Both of you need the same version."
const OLD_RELAY := "The relay runs a different version. Try again later, or update Wargrid."
const RELAY_BUSY := "The relay is busy. Try again in a minute."
const RELAY_REFUSED := "The relay refused the connection (%s)."
const LOOKALIKE := "Codes never use O, 0, I or 1. Check the code with your friend."
const TEAM_JOINED := " · you are on the host’s team now"
const TEAM_SPLIT := " · you play against the host now"
const MAP_TOO_SMALL := "This map has %d starts; your setup needs %d."
const HINT_PICK := "Click a free start to take it, or let the game place you."
const HINT_BOTS := "Click a free start to place yourself, then each bot. The game places the rest."
const TIP_FREE := "Free start: click to start here"
const TIP_FREE_BOT := "Free start: click to place %s here"
const TIP_YOURS := "Your start: click again to let the game place you"
const TIP_FRIENDS := "Your friend's start"
const TIP_HOSTS := "Host's start"
const TIP_BOT := "%s's start"
const TIP_BOT_HOST := "%s's start: click to let the game place it"
const HOST_MOVED := "Host moved their start"
const HOST_PLACED := "Host placed a bot"
const HOST_FREED := "Host let the game place a bot"
var mode: String = "skirmish"
# Bot factions in seat order; Random stays Random until the match starts.
var lobby_bots: Array[String] = []
var _own_pick: String = Registry.Factions.DEFAULT_FACTION
var _confirm: ConfirmationDialog
# The mode a Mode row click asked for while hosting or joined, taken once the room is left.
var _next_mode: String = ""
var _transport: RefCounted
var _clock: Callable = Time.get_ticks_usec
var _connect_msec: int = 0
var _room_msec: int = 0
var _created_msec: int = 0
var _sent_msec: int = 0
var _match: String = ""
var _seat: int = 0
var _code: String = ""
var _hello_sent: bool = false
# The room's setup: what the host last sent, or what the guest last received.
var _settings: Dictionary = {}
# Random bots roll here, outside the simulation, so both windows seat the same faction.
var _roll: Callable = func() -> String: return _resolve(RANDOM)
var _dirty: bool = false
var _friend: bool = false
var _asked: bool = false
var _cue: String = ""
var _cue_msec: int = 0
# Display only: the guests' picks by seat as the host heard them; factions still go in-band at the start.
var _picks: Dictionary = {}
var _pick_dirty: bool = false
var _pick_msec: int = 0
var _sent_pick: Dictionary = {}
# Start seats by player (1 is you, offline and hosting); unpicked players are placed by the rule at the start.
var _spots: Dictionary = {}
# The guest's own start as last asked of the host; the settings show where it stands.
var _own_start: int = 0
var _lockstep: RefCounted
var current_page: String = "Play"
var _origin: String = "Play"
var _play_error: bool = false
static var code_applied: bool = false
var prerelease: bool = PlaytestSettings.prerelease()
var web: bool = OS.has_feature("web")
var quit: Callable
var download: Callable = JavaScriptBridge.download_buffer
var focus_cards: Array[Dictionary] = FocusCards.load_cards()
var page: String = _page_value("location.origin + location.pathname")
var log_error: Callable = func(line: String) -> void: push_error(line)
var search: String = _page_value("location.search")

func _enter_tree() -> void:
	ViewCaps.release(get_tree().root)

func _ready() -> void:
	# Release exports reject a scene path argument, so CI and Task 10 reach the headless client through these flags.
	for flag in HEADLESS_FLAGS:
		if flag in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file.call_deferred("res://scenes/net_headless.tscn")
			return
	_add_confirm()
	_fill_maps()
	_apply_picks()
	_add_audio()
	_add_fullscreen()
	_add_graphics()
	if PlaytestSettings.enabled(): PlaytestSession.settle(PlaytestSettings.build_id(), web, download)
	_add_playtest()
	if not quit.is_valid(): quit = get_tree().quit
	$Sidebar/Nav/Quit.visible = not web
	$Sidebar/Nav/Quit.pressed.connect(func() -> void:
		_close_sitting()
		quit.call())
	$Pages/Play/Footer/Start.pressed.connect(_on_start)
	_connect_play_controls()
	_connect_join_page()
	$Pages/Play/Footer/CancelConnect.pressed.connect(_cancel)
	$Pages/Play/Footer/TryAgain.pressed.connect(_host)
	get_node(ONLINE).visible = prerelease
	get_node(RELAY_FIELD).text_changed.connect(_save_relay)
	for page_name in PAGES:
		get_node("Sidebar/Nav/" + page_name).toggled.connect(func(on: bool) -> void:
			if on and current_page != page_name: show_page(page_name))
	$Sidebar/Version.text = "v" + _build()
	get_node(JOIN + "/Row/Code").max_length = JoinLink.MAX_INPUT
	set_process(false)
	show_page("Play")
	set_mode("skirmish")
	_apply_page()
	_install_paste_shim()

func _add_confirm() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.name = "Confirm"
	_confirm.confirmed.connect(_leave_room)
	_confirm.canceled.connect(func() -> void: _next_mode = "")
	add_child(_confirm)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not web: _close_sitting() # web files at the next launcher open instead

func _close_sitting() -> void:
	if PlaytestSettings.enabled(): PlaytestSession.close_sitting(web, download)

func _install_paste_shim() -> void:
	if not OS.has_feature("web"):
		return
	PasteShim.adopt(get_node(JOIN + "/Row/Code"))
	PasteShim.adopt(get_node(RELAY_FIELD))
	if not get_tree().root.has_node("PasteShim"):
		get_tree().root.add_child.call_deferred(PasteShim.new())

static func _page_value(expression: String) -> String:
	return str(JavaScriptBridge.eval(expression)) if OS.has_feature("web") else ""

func _copy_text() -> String:
	return _code if page.is_empty() else JoinLink.link(page, _code, _relay_url())

func _apply_page() -> void:
	var query: Dictionary = JoinLink.parse(search)
	_set_relay(LauncherSettings.relay() if prerelease else JoinLink.DEFAULT_RELAY)
	var link_code: String = "" if code_applied else JoinLink.code(query.get("code", ""))
	code_applied = true # a stale link must not refill the field after "back to menu"
	if not link_code.is_empty():
		get_node(JOIN + "/Row/Code").text = link_code
		set_mode("join")
		_show_message(FROM_LINK)
	var relay: String = JoinLink.relay(query.get("relay", "")) if prerelease else ""
	# A link's relay holds for this session only; the saved one comes back next start.
	if not relay.is_empty(): _set_relay(relay)
	# A friend's code link means the default relay unless it names another; a saved test relay must not hijack it.
	elif not link_code.is_empty(): _set_relay(JoinLink.DEFAULT_RELAY)
	for path: String in ["/Invite/Box", "/Invite/Box/Copy"]: get_node(MODE_BAR + path).tooltip_text = INVITE_TIP_WEB if not page.is_empty() else INVITE_TIP

func _save_relay(text: String) -> void:
	if prerelease: LauncherSettings.save_relay(text.strip_edges())

func _set_relay(url: String) -> void:
	get_node(RELAY_FIELD).text = url

func _relay_url() -> String:
	var url: String = get_node(RELAY_FIELD).text.strip_edges()
	return url if not url.is_empty() else JoinLink.DEFAULT_RELAY

func set_mode(kind: String) -> void:
	# Bot player numbers differ between Skirmish and Host game, so only the own start carries over.
	if kind != mode: _spots = {1: _spots[1]} if _spots.has(1) else {}
	mode = kind
	_fit_bots()
	_play_error = false
	if kind == "join": _show_message("")
	_refresh_play()
	if current_page == "Play" and is_inside_tree(): _focus_primary()

# Host game keeps a start for the friend; Skirmish never opens without an enemy.
func _fit_bots() -> void:
	lobby_bots.resize(mini(lobby_bots.size(), maxi(0, _bot_cap())))
	if mode == "skirmish" and lobby_bots.is_empty(): lobby_bots.append(LauncherSettings.load_picks().bots[0])

func _bot_cap() -> int:
	return _cap_for(_start_count(_map_id()))

func _cap_for(starts: int) -> int:
	return mini(HOST_BOTS, starts - 2) if mode == "host" else starts - 1

func _is_guest() -> bool:
	return _seat > 1

func _friend_in() -> bool:
	return _seat == 1 and _friend

func _used() -> int:
	return 1 + lobby_bots.size() + (1 if _friend_in() else 0)

func _kept() -> int:
	return 1 if mode == "host" and not _friend_in() else 0

func _shown_map() -> String:
	return _settings.map if _is_guest() else _map_id()

func _refresh_play() -> void:
	var guest: bool = _is_guest()
	var joining: bool = mode == "join" and not guest
	$Pages/Play/Subtitle.text = GUEST_SUBTITLE if guest else {"skirmish": SKIRMISH_SUBTITLE, "host": HOST_SUBTITLE, "join": JOIN_SUBTITLE}[mode]
	_refresh_mode_bar(guest)
	for path: String in ["Body", "Divider", "Footer"]: get_node("Pages/Play/" + path).visible = not joining
	$Pages/Play/JoinPage.visible = joining
	get_node(JOIN + "/Row/Cancel").visible = _transport != null
	_build_rows()
	var id: String = _shown_map()
	$Pages/Play/Body/Players/Count.visible = not guest
	_refresh_count(_start_count(id))
	$Pages/Play/Body/Players/Cue.visible = not _cue.is_empty()
	$Pages/Play/Body/Players/Cue.text = _cue
	$Pages/Play/Body/MapColumn/Map.visible = not guest
	$Pages/Play/Body/MapColumn/Map.disabled = _asked
	$Pages/Play/Body/MapColumn/MapName.visible = guest
	$Pages/Play/Body/MapColumn/MapName.text = MatchSettings.PLAY_MAPS.get(id, id)
	$Pages/Play/Body/MapColumn/Preview.show_map(_map_data(id))
	_refresh_starts(guest)
	$Pages/Play/Body/MapColumn/MapInfo.text = _map_info(id)
	_grey_maps()
	_refresh_footer(guest)

# The count line names what greys + Add enemy bot, and the button's tooltip says the same.
func _refresh_count(starts: int) -> void:
	var full: bool = lobby_bots.size() >= _bot_cap()
	var line: String = "%d of %d starts used" % [_used(), starts]
	if _kept() > 0: line += " · 1 kept for your friend"
	if full: line += " · " + _full_reason(starts)
	var add: Button = $Pages/Play/Body/Players/Count/AddBot
	$Pages/Play/Body/Players/Count/Line.text = line
	add.disabled = full or _asked
	add.tooltip_text = line if full else ""

func _full_reason(starts: int) -> String:
	return ONLINE_BOTS % HOST_BOTS if mode == "host" and HOST_BOTS < starts - 2 else BIGGER_MAP

func _refresh_mode_bar(guest: bool) -> void:
	for kind: String in MODES: (get_node(MODE_BAR + "/" + MODES[kind]) as Button).set_pressed_no_signal(mode == kind)
	get_node(MODE_BAR + "/Invite").visible = not _code.is_empty()
	get_node(MODE_BAR + "/Invite/Box/Copy").visible = not guest
	get_node(MODE_BAR + "/Invite/Box/Code").text = _code.left(3) + " " + _code.right(3) if not _code.is_empty() else ""

func _refresh_starts(guest: bool) -> void:
	var spots: Dictionary = _guest_spots() if guest else _spots
	# The guest's own ask shows at once as a ring until the host's settings agree.
	var pending: Dictionary = {_own_start: _hue(_seat)} if guest and _own_start > 0 and _spots_of(_settings).get(_seat, 0) != _own_start else {}
	var players: Dictionary = {}
	for player: int in spots:
		if not pending.has(spots[player]): players[spots[player]] = _hue(player)
	var seats: Array = _start_seats(_shown_map())
	var tips: Dictionary = {}
	for seat: int in seats: tips[seat] = _start_tip(seat, spots, guest)
	$Pages/Play/Body/MapColumn/Preview.show_starts(players, tips, pending)
	$Pages/Play/Body/MapColumn/MapHint.text = HINT_BOTS if not guest and not lobby_bots.is_empty() else HINT_PICK

# The settings' starts, with the guest's own as it last asked.
func _guest_spots() -> Dictionary:
	var spots: Dictionary = _spots_of(_settings)
	spots.erase(_seat)
	if _own_start > 0: spots[_seat] = _own_start
	return spots

func _start_tip(seat: int, spots: Dictionary, guest: bool) -> String:
	var here: int = spots.find_key(seat) if spots.values().has(seat) else 0
	if here == (_seat if guest else 1): return TIP_YOURS
	if _bot_players().has(here): return (TIP_BOT if guest else TIP_BOT_HOST) % _bot_name(here)
	if here != 0: return TIP_HOSTS if guest else TIP_FRIENDS
	var next: int = 0 if guest else _next_placed()
	return TIP_FREE_BOT % _bot_name(next) if next > 1 else TIP_FREE

func _bot_name(player: int) -> String:
	return "Bot %d" % (_bot_players().find(player) + 1)

static func _spots_of(settings: Dictionary) -> Dictionary:
	var spots: Dictionary = {}
	for row: Dictionary in settings.get("chosen", []): spots[int(row.player)] = int(row.start)
	return spots

func _start_seats(id: String) -> Array:
	return _map_data(id).starts.map(func(start: Dictionary) -> int: return int(start.seat))

# Free for this player: nobody else starts there.
func _free(seat: int, player: int) -> bool:
	return _spots.keys().all(func(other: int) -> bool: return other == player or _spots[other] != seat)

func _on_start_pressed(seat: int) -> void:
	if _is_guest(): _guest_start(seat)
	elif not _asked: _take_start(seat)

# A free start goes to you, then to each bot without one (Zero Hour's order); clicking your start or a bot's clears it.
func _take_start(seat: int) -> void:
	var here: int = _spots.find_key(seat) if _spots.values().has(seat) else 0
	if here == 1 or _bot_players().has(here): _spots.erase(here)
	elif here == 0: _spots[_next_placed()] = seat
	else: return
	_changed()

# Once everyone has a start, a free start moves you.
func _next_placed() -> int:
	for player: int in [1] + _bot_players():
		if not _spots.has(player): return player
	return 1

func _guest_start(seat: int) -> void:
	if seat != _own_start and _blocked(seat): return
	_own_start = 0 if seat == _own_start else seat
	_pick_dirty = true
	_refresh_starts(true)

# For the guest: another player or a bot starts there.
func _blocked(seat: int) -> bool:
	var others: Dictionary = _spots_of(_settings)
	others.erase(_seat)
	return others.values().has(seat)

func _placement() -> Dictionary:
	var placed: Dictionary = {}
	var players: Array = _spots.keys()
	players.sort()
	if not players.is_empty(): placed["chosen"] = players.map(func(player: int) -> Dictionary: return {"player": player, "start": _spots[player]})
	return placed

func _refresh_footer(guest: bool) -> void:
	var start: Button = $Pages/Play/Footer/Start
	start.visible = not guest
	start.disabled = lobby_bots.is_empty() if mode == "skirmish" else not _friend_in() or _asked
	$Pages/Play/Footer/CancelConnect.visible = _transport != null and _origin == "Play" and _code.is_empty()
	$Pages/Play/Footer/TryAgain.visible = mode == "host" and _transport == null
	$Pages/Play/Footer/Leave.visible = guest or (mode == "host" and not _code.is_empty())
	$Pages/Play/Footer/Leave.text = "Leave" if guest else "Stop hosting"
	var text: String = _play_status(guest)
	if not _play_error and not text.is_empty(): _show_status($Pages/Play/Footer/Status, text)

# Empty while connecting: the ticking line owns the footer then.
func _play_status(guest: bool) -> String:
	if guest: return WAITING_FOR_HOST if _room_msec < 0 else _timed(WAITING_FOR_HOST, _room_deadline(), _now_msec())
	if mode == "join": return ""
	if mode == "skirmish": return _summary() if not lobby_bots.is_empty() else NO_BOT
	if _code.is_empty(): return ""
	if _asked: return STARTING
	return _timed(READY if _friend_in() else FRIEND_WAIT, _room_deadline(), _now_msec())

func _grey_maps() -> void:
	var map: OptionButton = $Pages/Play/Body/MapColumn/Map
	var need: int = _used() + _kept()
	for index in map.item_count:
		var starts: int = _start_count(map.get_item_metadata(index))
		map.set_item_disabled(index, starts < need)
		map.set_item_tooltip(index, MAP_TOO_SMALL % [starts, need] if starts < need else "")

func _build_rows() -> void:
	for team: int in [1, 2]:
		for row: Node in get_node(TEAMS + "/Team%d" % team).get_children():
			if row.name == "Head": continue
			row.get_parent().remove_child(row)
			row.queue_free()
	var entries: Array[Dictionary] = _guest_entries() if _is_guest() else _lobby_entries()
	for team: int in [1, 2]: get_node(TEAMS + "/Team%d" % team).visible = entries.any(func(entry: Dictionary) -> bool: return entry.team == team)
	for entry: Dictionary in entries: get_node(TEAMS + "/Team%d" % entry.team).add_child(_make_row(entry))
	_fit_teams(entries.size())

func _fit_teams(rows: int) -> void:
	var list: Control = get_node(TEAMS)
	var height: float = list.get_combined_minimum_size().y
	var row: Control = get_node(TEAMS + "/Team1").get_child(1)
	if rows > ROWS_SHOWN: height -= (rows - ROWS_SHOWN) * (row.get_combined_minimum_size().y + get_node(TEAMS + "/Team1").get_theme_constant("separation"))
	get_node(PLAYERS + "/Teams").custom_minimum_size.y = height

func _lobby_entries() -> Array[Dictionary]:
	var host: bool = mode == "host"
	var entries: Array[Dictionary] = [{"name": "You", "title": "You", "meta": "Host" if host else "", "player": 1, "team": 1, "own": true}]
	if host:
		var friend: Dictionary = {"name": "Friend", "player": 2, "team": 1 if not lobby_bots.is_empty() else 2}
		if _friend_in(): friend.merge({"title": "Your friend", "meta": "Player", "text": _faction_name(_picks[2]) if _picks.has(2) else PICKS_AT_START})
		else: friend.merge({"title": "Open", "meta": "Waiting for your friend…" if not _code.is_empty() else "Your friend joins with the code", "open": true})
		entries.append(friend)
	for i in lobby_bots.size():
		entries.append({"name": "Bot%d" % (i + 1), "title": "Bot %d" % (i + 1), "meta": "Computer player", "player": (3 if host else 2) + i, "team": 2, "bot": i})
	return entries

func _guest_entries() -> Array[Dictionary]:
	var bots: Array = _settings.get("bots", [])
	var teams: Array[int] = MatchSettings.teams(2, bots.size())
	var entries: Array[Dictionary] = []
	var host_pick: String = _host_pick(_settings)
	entries.append({"name": "Host", "title": "Host", "meta": "Sets up the match", "player": 1, "team": teams[0], "text": PICKS_AT_START if host_pick.is_empty() else _faction_name(host_pick)})
	entries.append({"name": "You", "title": "You", "meta": "", "player": _seat, "team": teams[1], "own": true})
	for i in bots.size():
		entries.append({"name": "Bot%d" % (i + 1), "title": "Bot %d" % (i + 1), "meta": "Computer player", "player": int(bots[i].player), "team": teams[2 + i], "text": _faction_name(RANDOM if bots[i].get("random", false) else bots[i].faction)})
	return entries

func _make_row(entry: Dictionary) -> PanelContainer:
	var open: bool = entry.get("open", false)
	var panel: PanelContainer = _dashed() if open else PanelContainer.new()
	panel.name = entry.name
	panel.theme_type_variation = &"OpenSlot" if open else &"PlayerRow"
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	# Text-only rows match the height of rows that hold a dropdown.
	row.custom_minimum_size.y = ACTION_WIDTH
	panel.add_child(row)
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = Color.TRANSPARENT if open else _hue(entry.player)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	row.add_child(_who(entry.title, entry.meta))
	if entry.get("own", false): row.add_child(_own_row_selector())
	elif entry.has("bot"): row.add_child(_bot_selector(entry.bot))
	elif entry.has("text"): row.add_child(_text_cell(entry.text))
	row.add_child(_remove_button(entry.bot) if entry.has("bot") else _action_space())
	return panel

func _dashed() -> PanelContainer:
	var dashed: DashedPanel = DashedPanel.new()
	dashed.color = get_theme_color(&"line", &"Tokens")
	return dashed

func _who(title: String, meta: String) -> VBoxContainer:
	var who := VBoxContainer.new()
	who.name = "Who"
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 0)
	for part: Array in [["Name", title, &"PanelTitle"], ["Meta", meta, &"Hint"]]:
		var label := Label.new()
		label.name = part[0]
		label.text = part[1]
		label.theme_type_variation = part[2]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = not label.text.is_empty()
		who.add_child(label)
	return who

func _text_cell(text: String) -> Label:
	var label := Label.new()
	label.name = "Faction"
	label.text = text
	label.custom_minimum_size.x = FACTION_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _own_row_selector() -> OptionButton:
	var selector: OptionButton = _faction_selector(_own_pick)
	selector.tooltip_text = "Your faction"
	selector.item_selected.connect(func(index: int) -> void:
		_play_error = false
		_set_own(selector.get_item_metadata(index))
		_focus_primary())
	return selector

func _bot_selector(index: int) -> OptionButton:
	var selector: OptionButton = _faction_selector(lobby_bots[index])
	selector.tooltip_text = "This bot's faction"
	selector.disabled = _asked
	selector.item_selected.connect(func(item: int) -> void:
		if _asked: return
		lobby_bots[index] = selector.get_item_metadata(item)
		_dirty = true
		_play_error = false
		_refresh_footer(false)
		_focus_primary())
	return selector

func _remove_button(index: int) -> Button:
	var button := Button.new()
	button.name = "Remove"
	button.theme_type_variation = &"RemoveButton"
	button.icon = REMOVE_ICON
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(ACTION_WIDTH, ACTION_WIDTH)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Remove bot"
	button.disabled = _asked
	button.pressed.connect(_remove_bot.bind(index))
	return button

func _action_space() -> Control:
	var space := Control.new()
	space.name = "Action"
	space.custom_minimum_size = Vector2(ACTION_WIDTH, 0)
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space

func _add_bot() -> void:
	if _asked or lobby_bots.size() >= _bot_cap(): return
	lobby_bots.append(RANDOM)
	_changed()

func _remove_bot(index: int) -> void:
	if _asked or index >= lobby_bots.size(): return
	var gone: int = _bot_players()[index]
	var spots: Dictionary = {}
	for player: int in _spots:
		if player != gone: spots[player - 1 if player > gone else player] = _spots[player]
	_spots = spots
	lobby_bots.remove_at(index)
	_changed()

func _changed() -> void:
	_dirty = true
	_play_error = false
	_refresh_play()
	_focus_primary()

# The hues the match will draw, so Neon players see the same colours here.
func _hue(player: int) -> Color:
	var neon: bool = GraphicsSettings.load_neon()
	var online: bool = mode == "host" or _is_guest()
	var team: Dictionary = Palette.team_colours(_bot_players()) if online and not _bot_players().is_empty() else {}
	if team.has(player): return team[player][1 if neon else 0]
	return (Palette.OWNER_BRIGHT if neon else Palette.OWNER_BASE)[player - 1]

func _bot_players() -> Array[int]:
	if _is_guest(): return MatchSettings.bot_players(_settings)
	var first: int = 3 if mode == "host" else 2
	var players: Array[int] = []
	for i in lobby_bots.size(): players.append(first + i)
	return players

func _own_selector() -> OptionButton:
	var row: Node = get_node(PLAYERS).find_child("You", true, false)
	return row.get_node("Row/Faction") if row != null else null

func _map_data(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MatchSettings.map_path(id)))

func _start_count(id: String) -> int:
	return _map_data(id).starts.size()

func _map_info(id: String) -> String:
	var data: Dictionary = _map_data(id)
	return "%d start positions · %d supply sources" % [data.starts.size(), data.sources.size()]

func _summary() -> String:
	var against: String = "%s bot" % _faction_name(lobby_bots[0]) if lobby_bots.size() == 1 else "%d bots" % lobby_bots.size()
	return "%s · %s vs %s" % [MatchSettings.PLAY_MAPS[_map_id()], _faction_name(_own_pick), against]

func _connect_play_controls() -> void:
	for kind: String in MODES:
		get_node(MODE_BAR + "/" + MODES[kind]).pressed.connect(func() -> void:
			if _transport != null:
				_leave_for(kind)
				return
			set_mode(kind)
			if kind == "host": _host())
	get_node(MODE_BAR + "/Invite/Box/Copy").pressed.connect(_copy)
	get_node(MODE_BAR + "/Invite/CopyReset").timeout.connect(_copy_reset)
	_copy_reset()
	$Pages/Play/Body/Players/Count/AddBot.pressed.connect(_add_bot)
	$Pages/Play/Footer/Leave.pressed.connect(func() -> void:
		if not _is_guest(): _ask_stop()
		elif _transport != null: _refuse(LEFT_GAME))
	$Pages/Play/Body/MapColumn/Map.item_selected.connect(func(_index: int) -> void:
		_spots.clear()
		_changed())
	$Pages/Play/Body/MapColumn/Preview.start_pressed.connect(_on_start_pressed)

func _connect_join_page() -> void:
	get_node(JOIN + "/Row/Join").pressed.connect(_join)
	get_node(JOIN + "/Row/Code").text_submitted.connect(func(_text: String) -> void: _join())
	get_node(JOIN + "/Row/Cancel").pressed.connect(func() -> void:
		if _transport != null: _cancel())

func _host() -> void:
	_origin = "Play"
	_play_error = false
	_connect("")

func _copy() -> void:
	DisplayServer.clipboard_set(_copy_text())
	_show_copy("Copied", CHECK_ICON)
	get_node(MODE_BAR + "/Invite/CopyReset").start()

func _copy_reset() -> void:
	_show_copy("Copy code" if page.is_empty() else "Copy link", COPY_ICON)

func _show_copy(text: String, icon: Texture2D) -> void:
	var copy: Button = get_node(MODE_BAR + "/Invite/Box/Copy")
	copy.text = text
	copy.icon = icon

# Every mode leaves (user, 2026-11-27): the friend expected Skirmish to leave hosting, so another mode leaves the room, asking first when someone would be dropped.
func _leave_for(kind: String) -> void:
	if kind == mode:
		_refresh_play()
		return
	_next_mode = kind
	if _seat == 0: _cancel()
	elif _is_guest(): _ask_leave()
	else: _ask_stop()

# With a friend in, leaving drops them, so it asks first.
func _ask_stop() -> void:
	_refresh_play()
	if _friend_in(): _ask(STOP_TITLE, STOP_TEXT, "Stop hosting")
	else: _stop_hosting()

func _ask_leave() -> void:
	_refresh_play()
	_ask(LEAVE_TITLE, LEAVE_TEXT, "Leave")

func _ask(title: String, text: String, ok: String) -> void:
	_confirm.title = title
	_confirm.dialog_text = text
	_confirm.ok_button_text = ok
	_confirm.popup_centered()

func _leave_room() -> void:
	if _transport != null: _refuse(LEFT_GAME if _is_guest() else HOSTING_STOPPED)

func _stop_hosting() -> void:
	if _transport != null: _refuse(HOSTING_STOPPED)

func _apply_picks() -> void:
	var picks: Dictionary = LauncherSettings.load_picks()
	_select_id($Pages/Play/Body/MapColumn/Map, picks.map)
	lobby_bots.assign(picks.bots)
	_set_own(picks.faction)

func _set_own(id: String) -> void:
	_own_pick = id
	_dirty = true
	if _is_guest(): _pick_dirty = true
	var own: OptionButton = _own_selector()
	if own != null: _select_id(own, id)
	if not _play_error: _refresh_footer(_is_guest())

func _select_id(selector: OptionButton, id: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == id: selector.select(index)

func show_page(page_name: String) -> void:
	current_page = page_name
	for each in PAGES: get_node("Pages/" + each).visible = each == page_name
	get_node("Sidebar/Nav/" + page_name).button_pressed = true
	if page_name == "Credits": _fill_credits()
	if is_inside_tree(): _focus_primary()

# Enter only reaches a focused control, so each page focuses the one action it is for.
func _focus_primary() -> void:
	if current_page == "Play": _play_focus().grab_focus()

func _play_focus() -> Control:
	if _is_guest(): return _own_selector()
	if mode == "join": return _join_focus()
	if mode == "skirmish" or _friend_in(): return $Pages/Play/Footer/Start
	if not _code.is_empty(): return get_node(MODE_BAR + "/Invite/Box/Copy")
	return $Pages/Play/Footer/CancelConnect if _transport != null else $Pages/Play/Footer/TryAgain

func _join_focus() -> Control:
	var code: LineEdit = get_node(JOIN + "/Row/Code")
	if _transport != null: return get_node(JOIN + "/Row/Cancel")
	if not code.text.is_empty(): return get_node(JOIN + "/Row/Join")
	code.caret_column = code.text.length()
	return code

func _fill_credits() -> void:
	var text: RichTextLabel = $Pages/Credits/Body/Text
	if text.text.is_empty():
		text.text = Credits.text(FileAccess.get_file_as_string("res://audio/CREDITS.md"), FileAccess.get_file_as_string("res://data/maps/NOTICE.md"), Engine.get_license_text(), Engine.get_copyright_info(), Engine.get_license_info(), FileAccess.get_file_as_string("res://fonts/PublicSans-OFL.txt"))

# The footer's buttons take their share of the line, so a status that would push them off wraps instead.
func _status_budget(label: Label) -> float:
	var budget: float = STATUS_WIDTH
	if label.get_parent() != $Pages/Play/Footer: return budget
	for button: Button in [$Pages/Play/Footer/Leave, $Pages/Play/Footer/CancelConnect, $Pages/Play/Footer/TryAgain]:
		if button.visible: budget -= button.custom_minimum_size.x + $Pages/Play/Footer.get_theme_constant("separation")
	return budget

func _show_status(label: Label, text: String, error: bool = false) -> void:
	label.text = text
	label.theme_type_variation = &"FooterError" if error else &"FooterStatus"
	var width: float = label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
	var wide: bool = width > _status_budget(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN

# Joining speaks under the code field, where the eye is; hosting and the guest view use the footer.
func _status_label() -> Label:
	return get_node(JOIN + "/Message") if _on_card() else $Pages/Play/Footer/Status

func _on_card() -> bool:
	return _origin == "Join" and not _is_guest()

func _show_message(text: String, error: bool = false) -> void:
	var message: Label = get_node(JOIN + "/Message")
	message.text = text
	message.theme_type_variation = &"JoinError" if error else &"Hint"

func _show_origin(text: String, error: bool = false) -> void:
	if _on_card(): _show_message(text, error)
	else: _show_status($Pages/Play/Footer/Status, text, error)

func _set_shell_visible(shown: bool) -> void:
	for each in SHELL: get_node(each).visible = shown

func _add_playtest() -> void:
	var column: VBoxContainer = $Pages/Settings/Body/Playtest
	var toggle := CheckButton.new()
	toggle.name = "PlaytestSwitch"
	toggle.text = "Playtest helper"
	toggle.button_pressed = PlaytestSettings.enabled()
	column.add_child(toggle)
	column.move_child(toggle, $Pages/Settings/Body/Playtest/PlaytestHeader.get_index() + 1)
	toggle.toggled.connect(PlaytestSettings.save_enabled)
	if focus_cards.is_empty(): return
	var panel := FocusCardView.new(focus_cards, PlaytestSession.open_count, _close_sitting, web)
	add_child(panel)
	var build: Button = $Pages/Play/ThisBuild
	var show_panel := func(open: bool) -> void:
		build.text = "This build: " + FocusCards.card(FocusCards.shown(), focus_cards).title
		panel.visible = open
		_set_shell_visible(not open)
	show_panel.call(false)
	build.visible = toggle.button_pressed
	build.pressed.connect(show_panel.bind(true))
	toggle.toggled.connect(build.set_visible)
	panel.get_node("Box/Close").pressed.connect(show_panel.bind(false))

func _add_fullscreen() -> void:
	if OS.has_feature("web"): return
	var toggle := CheckButton.new()
	toggle.name = "Fullscreen"
	toggle.text = "Fullscreen"
	toggle.button_pressed = LauncherSettings.fullscreen()
	toggle.toggled.connect(func(on: bool) -> void:
		LauncherSettings.save_fullscreen(on)
		_apply_fullscreen(on))
	var audio: VBoxContainer = $Pages/Settings/Body/Audio
	var header: Label = audio.get_node("AudioHeader").duplicate()
	header.name = "DisplayHeader"
	header.text = "Display"
	audio.add_child(header)
	audio.add_child(toggle)
	_apply_fullscreen(toggle.button_pressed)

func _add_graphics() -> void:
	var column: VBoxContainer = $Pages/Settings/Body/Playtest
	var header: Label = $Pages/Settings/Body/Audio/AudioHeader.duplicate()
	header.name = "GraphicsHeader"
	header.text = "Graphics"
	var controls: Array[Control] = [
		header, _quality_toggle(),
		_graphics_switch("Neon", "Neon colours", GraphicsSettings.load_neon(), GraphicsSettings.save_neon),
		_graphics_switch("Smooth", "Smooth movement", GraphicsSettings.load_smooth(), GraphicsSettings.save_smooth),
		_graphics_switch("Destinations", "Show unit destinations", GraphicsSettings.load_destinations(), GraphicsSettings.save_destinations),
	]
	for control: Control in controls:
		column.add_child(control)
		column.move_child(control, controls.find(control))

func _quality_toggle() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Quality"
	row.add_theme_constant_override("separation", 6)
	var sides: Dictionary = {"Low": GraphicsSettings.LOW, "High": GraphicsSettings.HIGH}
	var buttons: Dictionary = {}
	var refresh := func() -> void:
		for side: String in sides: buttons[side].set_pressed_no_signal(GraphicsSettings.stored_quality() == sides[side])
	for side: String in sides:
		var button := Button.new()
		button.name = side
		button.text = side + " quality"
		button.toggle_mode = true
		button.theme_type_variation = &"ToggleButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			GraphicsSettings.save_quality(sides[side])
			refresh.call())
		buttons[side] = button
		row.add_child(button)
	refresh.call()
	return row

# Same stored keys and labels as the Esc menu's Settings page.
func _graphics_switch(switch_name: String, label: String, on: bool, save: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = switch_name
	toggle.text = label
	toggle.button_pressed = on
	toggle.toggled.connect(save)
	return toggle

static func fullscreen_target(on: bool, current: DisplayServer.WindowMode) -> int:
	var is_fullscreen: bool = current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if on: return -1 if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else -1

# The window mode stays untouched headless so tests never flip a real window.
func _apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	var target: int = fullscreen_target(on, DisplayServer.window_get_mode())
	if target >= 0: DisplayServer.window_set_mode(target as DisplayServer.WindowMode)

func _add_audio() -> void:
	add_child(SoundPlayer.new(0))
	var music := MusicPlayer.new()
	add_child(music)
	music.play_list([MusicPlayer.menu()], 0.0)
	var sliders := VolumeSliders.new()
	sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sliders.add_theme_constant_override("v_separation", 15)
	for title: String in ["MusicLabel", "EffectsLabel", "VoiceLabel", "MuteLabel"]: sliders.get_node(title).custom_minimum_size.x = 104.0
	$Pages/Settings/Body/Audio.add_child(sliders)

static func _faction_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(Registry.Factions.FACTIONS.keys())
	ids.sort()
	ids.append(RANDOM)
	return ids

func _faction_selector(id: String) -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "Faction"
	selector.fit_to_longest_item = false
	selector.custom_minimum_size.x = FACTION_WIDTH
	selector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for each: String in _faction_ids():
		selector.add_item(_faction_name(each))
		selector.set_item_metadata(selector.item_count - 1, each)
	_select_id(selector, id)
	return selector

static func _faction_name(id: String) -> String:
	return "Random" if id == RANDOM else Registry.faction(id).display_name

# Random is resolved per match start, outside the simulation, so randi is fine here.
static func _resolve(id: String) -> String:
	if id != RANDOM: return id
	var ids: Array[String] = _faction_ids()
	ids.erase(RANDOM)
	return ids[randi() % ids.size()]

func _fill_maps() -> void:
	var selector: OptionButton = $Pages/Play/Body/MapColumn/Map
	selector.clear()
	for id: String in MatchSettings.PLAY_MAPS:
		selector.add_item(MatchSettings.PLAY_MAPS[id])
		selector.set_item_metadata(selector.item_count - 1, id)

func _map_id() -> String:
	var selector: OptionButton = $Pages/Play/Body/MapColumn/Map
	return selector.get_item_metadata(selector.selected)

func _offline_setup() -> bool:
	var id: String = _map_id()
	if lobby_bots.size() + 1 > _start_count(id):
		log_error.call("Offline start refused: %d bots do not fit the %d starts of %s" % [lobby_bots.size(), _start_count(id), id])
		return false
	LauncherSettings.save_picks(_lobby_picks(id).merged({"faction": _own_pick}))
	SkirmishMain.factions = {1: _resolve(_own_pick)}
	for i in lobby_bots.size(): SkirmishMain.factions[i + 2] = _resolve(lobby_bots[i])
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = randi()
	SkirmishMain.placement = _placement()
	SkirmishMain.starts = MatchSettings.starts(id, SkirmishMain.match_seed, MatchSettings.teams(1, lobby_bots.size()), SkirmishMain.placement)
	return true

# A host's 1v1 has no bots; the next Skirmish keeps the last bots instead of opening empty.
func _lobby_picks(id: String) -> Dictionary:
	var picks: Dictionary = {"map": id}
	if not lobby_bots.is_empty(): picks["bots"] = lobby_bots.duplicate()
	return picks

func _on_start() -> void:
	if mode == "skirmish":
		if _offline_setup(): get_tree().change_scene_to_file(OFFLINE_SCENE)
	elif _friend_in() and not _asked:
		_send_setup(true)
		_asked = true
		_transport.send_text(Wire.encode({"type": "start_request"}))
		_refresh_play()

func _join() -> void:
	if _transport != null: return
	_origin = "Join"
	var code: String = JoinLink.code_from(get_node(JOIN + "/Row/Code").text)
	if code.is_empty(): _show_message(LOOKALIKE if JoinLink.lookalike(get_node(JOIN + "/Row/Code").text) else NEED_CODE, true)
	else: _connect(code)

func _cancel() -> void:
	if _transport != null: _refuse(HOST_CANCELLED if _origin == "Play" else JOIN_CANCELLED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_page == "Play" and _transport != null and _code.is_empty():
		_cancel()
		get_viewport().set_input_as_handled()

func _now_msec() -> int:
	return floori(int(_clock.call()) / 1000.0)

func _show_connecting(now_msec: int) -> void:
	var text := "Connecting… %d s" % floori(maxi(0, now_msec - _connect_msec) / 1000.0)
	if _status_label().text != text: _show_origin(text)

func _timed(text: String, deadline_msec: int, now_msec: int) -> String:
	var left: int = maxi(0, ceili((deadline_msec - now_msec) / 1000.0))
	return text if left > CLOCK_FROM_SEC else text + CLOCK % [floori(left / 60.0), left % 60]

# relay/room.go extendLobby: 15 minutes from the last settings, never past an hour from the room's creation.
func _room_deadline() -> int:
	return mini(_room_msec + RelayTransport.LOBBY_EXPIRY_SEC * 1000, _created_msec + RelayTransport.LOBBY_CAP_SEC * 1000)

func _capped() -> bool:
	return _room_msec >= 0 and _room_msec + RelayTransport.LOBBY_EXPIRY_SEC * 1000 > _created_msec + RelayTransport.LOBBY_CAP_SEC * 1000

func _connect(code: String) -> void:
	_match = code
	_reset_room()
	_hello_sent = false
	_connect_msec = _now_msec()
	_transport = RelayTransport.new(_clock)
	var error: Error = _transport.connect_to(_relay_url())
	if error != OK:
		_fail(UNREACHABLE % _relay_url())
		return
	_set_busy(true)
	_show_connecting(_connect_msec)
	set_process(true)

func _set_busy(busy: bool) -> void:
	# Settings and Credits stay open while a room is; quitting would drop the friend unasked.
	_lock(get_node("Sidebar/Nav/Quit"), busy)
	_lock(get_node(JOIN + "/Row/Join"), busy)
	for path: String in [RELAY_FIELD, JOIN + "/Row/Code"]: get_node(path).editable = not busy
	_refresh_play()
	# The pressed Join game turns disabled; busy, the focus goes to Cancel.
	_focus_primary()

# Godot draws a disabled button in its disabled style even when pressed; the selected item must stay grey.
func _lock(button: BaseButton, busy: bool) -> void:
	button.disabled = busy
	if busy and button.button_pressed: button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
	else: button.remove_theme_stylebox_override("disabled")

func _reset_room() -> void:
	_lockstep = null
	_settings = {}
	_code = ""
	_seat = 0
	_dirty = false
	_friend = false
	_asked = false
	_cue = ""
	_picks.clear()
	_pick_dirty = false
	_sent_pick = {}
	_own_start = 0
	_spots.erase(2)
	get_node(MODE_BAR + "/Invite/CopyReset").stop()
	_copy_reset()

# Stopping or cancelling goes back to Skirmish; a failed room stays on Host game with the reason and Try again.
func _fail(reason: String) -> void:
	_transport = null
	_reset_room()
	_confirm.hide()
	var chosen: bool = reason in [HOST_CANCELLED, JOIN_CANCELLED, HOSTING_STOPPED, LEFT_GAME]
	var next: String = _next_mode if chosen else ""
	_next_mode = ""
	if mode == "host" and chosen and next.is_empty(): set_mode("skirmish")
	_play_error = _origin == "Play"
	if current_page != "Play": show_page("Play")
	_set_busy(false)
	_show_origin(reason, not chosen)
	if _on_card() and not chosen: _select_code()
	set_process(false)
	if next.is_empty(): return
	set_mode(next)
	if next == "host": _host()

# After a failed join the code is ready to retype or paste over.
func _select_code() -> void:
	var code: LineEdit = get_node(JOIN + "/Row/Code")
	code.grab_focus()
	code.select_all()

func _process(_delta: float) -> void:
	if _transport == null: return
	var frames: PackedStringArray = _transport.poll()
	if _transport.is_open() and not _hello_sent: _send_hello()
	for text in frames:
		if _lockstep != null: _lockstep.receive(text)
		elif not _handle(text): return
	if _lockstep != null: return
	if _transport.closed() or _transport.silent(int(_clock.call())): _fail("Connection to relay lost" if _seat != 0 else UNREACHABLE % _relay_url())
	else:
		_send_setup()
		_send_pick()
		_show_ticking()

func _send_hello() -> void:
	_hello_sent = true
	var hello: Dictionary = {"type": "hello", "protocol": Wire.PROTOCOL, "build": _build(), "match": _match}
	if _match.is_empty():
		_settings = _snapshot()
		_sent_msec = _now_msec()
		_dirty = false
		hello["settings"] = _settings
	_transport.send_text(Wire.encode(hello))

# The latest snapshot wins; force is Start match, which leaves no change behind and re-rolls Random bots.
func _send_setup(force: bool = false) -> void:
	if _seat != 1 or _asked: return
	if not force and (not _dirty or _now_msec() - _sent_msec < SETTINGS_GAP_MSEC): return
	_dirty = false
	var snapshot: Dictionary = _snapshot(force)
	if snapshot == _settings: return
	_settings = snapshot
	_sent_msec = _now_msec()
	_room_msec = _sent_msec # relay/room.go extendLobby restarts the expiry on each settings
	_transport.send_text(Wire.encode({"type": "settings", "settings": snapshot}))

func _snapshot(reroll: bool = false) -> Dictionary:
	var settings: Dictionary = MatchSettings.for_map(_map_id(), _bot_rows(reroll))
	var players: Array = [{"player": 1, "faction": _own_pick}]
	for seat: int in _picks: players.append({"player": seat, "faction": _picks[seat]})
	settings["players"] = players
	settings.merge(_placement())
	return settings

func _send_pick(force: bool = false) -> void:
	if not _pick_dirty or not _is_guest(): return
	if not force and _now_msec() - _pick_msec < SETTINGS_GAP_MSEC: return
	_pick_dirty = false
	var pick: Dictionary = {"faction": _own_pick}
	# The map lets the host drop a start asked for on the map it just left.
	if _own_start > 0: pick.merge({"start": _own_start, "map": _settings.get("map")})
	if pick == _sent_pick: return
	_sent_pick = pick
	_pick_msec = _now_msec()
	_transport.send_text(Wire.encode({"type": "pick", "pick": pick}))

func _take_pick(message: Dictionary) -> void:
	# The launcher's room holds one friend, on seat 2.
	if message.get("seat") != 2: return
	var seat: int = int(message.seat)
	var faction: Variant = message.pick.get("faction")
	if faction is String and (Registry.Factions.FACTIONS.has(faction) or faction == RANDOM): _picks[seat] = faction
	if not _asked and (not message.pick.has("start") or message.pick.get("map") == _map_id()): _take_guest_start(seat, message.pick.get("start", 0))
	_dirty = true
	_refresh_live()

# The host's settings are the truth: a clash or a bad value keeps the guest's last start, and the guest's view follows the settings.
func _take_guest_start(seat: int, start: Variant) -> void:
	if typeof(start) not in [TYPE_INT, TYPE_FLOAT] or start != floorf(start): return
	var wanted: int = int(start)
	if wanted == 0: _spots.erase(seat)
	elif _start_seats(_map_id()).has(wanted) and _free(wanted, seat): _spots[seat] = wanted

static func _host_pick(settings: Dictionary) -> String:
	for row: Variant in settings.get("players", []):
		if row is Dictionary and row.get("player") == 1 and row.get("faction") is String: return row.faction
	return ""

func _show_status_if_changed(label: Label, text: String) -> void:
	if label.text != text: _show_status(label, text)

func _show_ticking() -> void:
	if _cue in [FRIEND_JOINED, FRIEND_LEFT] and _now_msec() - _cue_msec >= CUE_MSEC:
		_cue = ""
		$Pages/Play/Body/Players/Cue.visible = false
	if _seat == 0: _show_connecting(_now_msec())
	else: _show_status_if_changed($Pages/Play/Footer/Status, _play_status(_is_guest()))

func _handle(text: String) -> bool:
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok: return _refuse("Protocol error: " + decoded.error)
	var message: Dictionary = decoded.message
	match message.type:
		"welcome": return _welcome(message)
		"joined": _set_friend(true, FRIEND_JOINED)
		"left":
			if message.seat == 1: return _refuse(HOST_GONE)
			_picks.erase(message.seat)
			_spots.erase(int(message.seat))
			_dirty = true
			_set_friend(false, FRIEND_LEFT)
		"pick" when _seat == 1: _take_pick(message)
		"settings" when _is_guest(): return _take_settings(message.settings)
		"start": return _start(message)
		"error": return _refuse(_relay_reason(message.reason))
		_: return _refuse("Protocol error: unexpected " + message.type)
	return true

func _refuse(reason: String) -> bool:
	_transport.close()
	_fail(reason)
	return false

func _welcome(message: Dictionary) -> bool:
	_seat = message.seat
	_code = message.match
	_transport.patient = true
	_room_msec = _now_msec()
	# The guest's welcome comes after the room's creation, so its cap is an upper bound.
	_created_msec = _room_msec
	if _is_guest():
		if not _take_settings(message.get("settings", {})): return false
		_pick_dirty = true
		_send_pick(true)
	_refresh_play()
	_focus_primary()
	return true

func _set_friend(present: bool, cue: String) -> void:
	if _seat != 1: return
	_friend = present
	# The relay ignores a start_request sent before the room is full, so a leave lets the host ask again.
	if not present: _asked = false
	_cue = cue
	_cue_msec = _now_msec()
	_refresh_live()
	if present: _hand_start()

# The friend arriving moves the focus to Start match unless the player is busy elsewhere, and asks for the window.
func _hand_start() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var idle: bool = focused == null or focused == get_node(MODE_BAR + "/Invite/Box/Copy") or focused.get_parent() == get_node(MODE_BAR)
	if idle and current_page == "Play": $Pages/Play/Footer/Start.grab_focus()
	_request_attention()

func _request_attention() -> void:
	if DisplayServer.get_name() != "headless": DisplayServer.window_request_attention()

func _take_settings(settings: Dictionary) -> bool:
	var reason: String = MatchSettings.refusal(settings)
	if not reason.is_empty(): return _refuse(reason)
	var first: bool = _settings.is_empty()
	var line: String = "" if first else _change_line(_settings, settings)
	if not line.is_empty(): _cue = line
	var new_map: bool = _settings.get("map") != settings.get("map")
	_settings = settings
	# An ask on the old map, or on a start now taken, is dropped even while it waits, so it never lands on the wrong map or hides the host's marker.
	if _own_start > 0 and (new_map or _blocked(_own_start)): _own_start = 0
	# A pick still waiting to go out must not be undone by settings sent before the host heard it; a welcome may still hold the last guest's start.
	elif not _pick_dirty and not first: _own_start = _spots_of(_settings).get(_seat, 0)
	# The host dropped the start this guest asked for, so asking again must send.
	if int(_sent_pick.get("start", 0)) != _own_start: _sent_pick.erase("start")
	# The relay's expiry runs from the room's creation or last settings, not from this join, so no clock until a change.
	_room_msec = -1 if first else _now_msec()
	if not first: _refresh_live()
	return true

# A live change waits for an open dropdown list and moves the focus only when the player has lost it.
func _refresh_live() -> void:
	var open: PopupMenu = _open_list()
	if open != null:
		if not open.popup_hide.is_connected(_refresh_live): open.popup_hide.connect(_refresh_live, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	_refresh_play()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or focused.is_queued_for_deletion(): _focus_primary()

func _open_list() -> PopupMenu:
	for selector: Node in get_node(PLAYERS).find_children("Faction", "OptionButton", true, false):
		if (selector as OptionButton).get_popup().visible: return (selector as OptionButton).get_popup()
	return null

# One change is named; several at once read as one line.
static func _change_line(before: Dictionary, after: Dictionary) -> String:
	var changes: Array[String] = []
	if before.get("map") != after.get("map"): changes.append(MAP_CHANGED % MatchSettings.PLAY_MAPS.get(after.map, after.map))
	var old_bots: Array = before.get("bots", [])
	var new_bots: Array = after.get("bots", [])
	var faction := func(row: Dictionary) -> String: return RANDOM if row.get("random", false) else row.faction
	var team_line: String = "" if old_bots.is_empty() == new_bots.is_empty() else (TEAM_SPLIT if new_bots.is_empty() else TEAM_JOINED)
	var picked: String = _host_pick(after)
	if picked != _host_pick(before) and not picked.is_empty(): changes.append(HOST_PICKED % _faction_name(picked))
	if new_bots.size() > old_bots.size(): changes.append(BOT_ADDED)
	elif new_bots.size() < old_bots.size(): changes.append(BOT_REMOVED)
	elif old_bots.map(faction) != new_bots.map(faction): changes.append(BOT_FACTION)
	if before.get("map") == after.get("map"): changes.append_array(_start_changes(before, after))
	if changes.is_empty(): return ""
	return (SETUP_CHANGED if changes.size() > 1 else changes[0]) + team_line

static func _start_changes(before: Dictionary, after: Dictionary) -> Array[String]:
	var changes: Array[String] = []
	if _spots_of(before).get(1) != _spots_of(after).get(1): changes.append(HOST_MOVED)
	# Removing a bot renumbers the later bots, which is that removal, not a placement.
	var bots: Array[int] = MatchSettings.bot_players(after)
	if bots != MatchSettings.bot_players(before): return changes
	var moved: Array[int] = bots.filter(func(player: int) -> bool: return _spots_of(before).get(player) != _spots_of(after).get(player))
	if moved.any(func(player: int) -> bool: return _spots_of(after).has(player)): changes.append(HOST_PLACED)
	elif not moved.is_empty(): changes.append(HOST_FREED)
	return changes

func _relay_reason(reason: String) -> String:
	match reason:
		"lobby expired":
			var closed: String = ROOM_GONE if _capped() else ROOM_CLOSED
			if _is_guest(): return closed
			return closed + NEW_CODE if _friend_in() else DID_NOT_JOIN
		"host left": return HOST_GONE
		"build mismatch": return VERSION_MISMATCH % _build()
		"unknown match": return NO_GAME % _match
		"match full": return GAME_FULL
		"protocol mismatch": return OLD_RELAY
		"relay busy", "too many connections", "too many joins": return RELAY_BUSY
	return RELAY_REFUSED % reason

# Test builds send version and commit, so two different test builds never share a room.
func _build() -> String:
	return PlaytestSettings.hello_build() if prerelease else str(ProjectSettings.get_setting("application/config/version"))

# Bot players follow the two relay seats; a Random bot keeps its roll until it changes or reroll is asked, and is marked so the guest reads Random.
func _bot_rows(reroll: bool = false) -> Array:
	var sent: Array = _settings.get("bots", [])
	var rows: Array = []
	for i in lobby_bots.size():
		var row: Dictionary = {"player": 3 + i, "faction": lobby_bots[i]}
		if lobby_bots[i] == RANDOM:
			var kept: bool = not reroll and i < sent.size() and sent[i].get("random", false)
			row.faction = sent[i].faction if kept else _roll.call()
			row["random"] = true
		rows.append(row)
	return rows

func _start(message: Dictionary) -> bool:
	var reason: String = MatchSettings.refusal(message.settings, message.seats.size())
	if not reason.is_empty(): return _refuse(reason)
	_lockstep = Lockstep.for_start(_seat, message)
	_open_match(message)
	return true

func _open_match(start: Dictionary) -> void:
	if _is_guest(): _request_attention()
	var settings: Dictionary = start.settings
	var id: String = settings.map
	var bots: Array[int] = MatchSettings.bot_players(settings)
	# Wire numbers arrive as floats; integer keys, or the bots never get their factions.
	var factions: Dictionary = {}
	for i in bots.size(): factions[bots[i]] = settings.bots[i].faction
	var picks: Dictionary = {"faction": _own_pick}
	if _seat == 1: picks.merge(_lobby_picks(id))
	LauncherSettings.save_picks(picks)
	SkirmishMain.factions = factions
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = start.seed
	SkirmishMain.placement = settings
	SkirmishMain.starts = MatchSettings.starts(id, start.seed, MatchSettings.teams(start.seats.size(), bots.size()), settings)
	set_process(false)
	var game: Node = OnlineScene.instantiate()
	game.setup(_transport, _lockstep, _seat, _resolve(_own_pick))
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()
