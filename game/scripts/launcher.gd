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
const OFFLINE_SCENE: String = "res://scenes/skirmish.tscn"
const HEADLESS_FLAGS: Array[String] = ["--netclient", "--relay", "--replay-log", "--probe-relay"]
const PAGES: Array[String] = ["Play", "Join", "Settings", "Credits", "Waiting"]
const NAV_PAGES: Array[String] = ["Play", "Join", "Settings", "Credits"]
const SHELL: Array[String] = ["SidebarBg", "ContentBg", "Sidebar", "Pages"]
const OWNS: Array[String] = ["Pages/Play/Body/Own", "Pages/Join/Body/Own"]
const FOLDS: Array[String] = ["Pages/Play/Body/Advanced", "Pages/Join/Body/Advanced"]
const BOT_ONLY: Array[String] = ["Body/BotLabel", "Body/Spacer2", "Body/Bot", "Body/Spacer3", "Footer/Start"]
const FRIEND_ONLY: Array[String] = ["Body/OpenSlot", "Body/Spacer4", "Footer/Create"]
# Page content is 960 px wide: leaves room for the 170 px button, the gap and the strip padding.
const STATUS_WIDTH := 700.0
const FRIEND_HINT := "You get a link to send to your friend."
const CANCELLED := "Match cancelled"
const DID_NOT_JOIN := "Your friend did not join in time"
var _transport: RefCounted
var _clock: Callable = Time.get_ticks_usec
var _connect_msec: int = 0
var _welcome_msec: int = -1
var _match: String = ""
var _seat: int = 0
var _code: String = ""
var _hello_sent: bool = false
var _lockstep: RefCounted
var current_page: String = "Play"
var opponent: String = "bot"
var _origin: String = "Play"
var _play_error: bool = false
static var code_applied: bool = false
var prerelease: bool = PlaytestSettings.prerelease()
var web: bool = OS.has_feature("web")
var quit: Callable
var download: Callable = JavaScriptBridge.download_buffer
var focus_cards: Array[Dictionary] = FocusCards.load_cards()
var page: String = _page_value("location.origin + location.pathname")
var search: String = _page_value("location.search")

func _enter_tree() -> void:
	ViewCaps.release(get_tree().root)

func _ready() -> void:
	# Release exports reject a scene path argument, so CI and Task 10 reach the headless client through these flags.
	for flag in HEADLESS_FLAGS:
		if flag in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file.call_deferred("res://scenes/net_headless.tscn")
			return
	_fill_factions()
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
	$Pages/Play/Footer/Start.pressed.connect(func() -> void:
		_offline_setup()
		get_tree().change_scene_to_file(OFFLINE_SCENE))
	_connect_play_controls()
	$Pages/Play/Footer/Create.pressed.connect(func() -> void:
		_origin = "Play"
		_connect(""))
	$Pages/Join/Footer/Join.pressed.connect(_join)
	$Pages/Join/Body/Code.text_submitted.connect(func(_text: String) -> void: _join())
	$Pages/Waiting/Body/Left/Invite/Copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(_copy_text()))
	for path: String in ["Waiting/Footer/Cancel", "Play/Footer/CancelConnect", "Join/Footer/CancelConnect"]:
		get_node("Pages/" + path).pressed.connect(_cancel)
	for page_name in NAV_PAGES:
		get_node("Sidebar/Nav/" + page_name).toggled.connect(func(on: bool) -> void:
			if on and _nav_of(current_page) != page_name: show_page(page_name))
	$Sidebar/Version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	set_process(false)
	show_page("Play")
	set_opponent("bot")
	_apply_page()
	_install_paste_shim()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not web: _close_sitting() # web files at the next launcher open instead

func _close_sitting() -> void:
	if PlaytestSettings.enabled(): PlaytestSession.close_sitting(web, download)

func _install_paste_shim() -> void:
	if not OS.has_feature("web"):
		return
	PasteShim.adopt($Pages/Join/Body/Code)
	for fold in FOLDS: PasteShim.adopt(get_node(fold + "/RelayUrl"))
	if not get_tree().root.has_node("PasteShim"):
		get_tree().root.add_child.call_deferred(PasteShim.new())

static func _page_value(expression: String) -> String:
	return str(JavaScriptBridge.eval(expression)) if OS.has_feature("web") else ""

func _copy_text() -> String:
	return _code if page.is_empty() else JoinLink.link(page, _code, _relay_url())

func _apply_page() -> void:
	var query: Dictionary = JoinLink.parse(search)
	_set_relay(JoinLink.DEFAULT_RELAY)
	$Pages/Join/Body/Advanced.visible = prerelease
	var opens_join: bool = not code_applied and not JoinLink.code(query.get("code", "")).is_empty()
	if not code_applied: $Pages/Join/Body/Code.text = JoinLink.code(query.get("code", ""))
	code_applied = true # a stale link must not refill the field after "back to menu"
	if opens_join: show_page("Join")
	var relay: String = JoinLink.relay(query.get("relay", "")) if prerelease else ""
	if not relay.is_empty():
		_set_relay(relay)
		_set_advanced(true)
	$Pages/Waiting/Body/Left/InviteLabel.text = "Invite link" if not page.is_empty() else "Match code"
	$Pages/Waiting/Body/Left/Invite/Copy.text = "Copy link" if not page.is_empty() else "Copy code"

func _set_advanced(open: bool) -> void:
	for fold in FOLDS:
		get_node(fold + "/Toggle").set_pressed_no_signal(open)
		get_node(fold + "/RelayUrl").visible = open
		get_node(fold + "/RelayHelp").visible = open

func _set_relay(url: String) -> void:
	for fold in FOLDS:
		var field: LineEdit = get_node(fold + "/RelayUrl")
		if field.text != url: field.text = url

func _relay_url() -> String:
	return $Pages/Play/Body/Advanced/RelayUrl.text.strip_edges()

func set_opponent(kind: String) -> void:
	opponent = kind
	var bot: bool = kind == "bot"
	$Pages/Play/Body/Opponent/BotToggle.set_pressed_no_signal(bot)
	$Pages/Play/Body/Opponent/FriendToggle.set_pressed_no_signal(not bot)
	for path in BOT_ONLY: get_node("Pages/Play/" + path).visible = bot
	for path in FRIEND_ONLY: get_node("Pages/Play/" + path).visible = not bot
	$Pages/Play/Body/Advanced.visible = prerelease and not bot
	_play_error = false
	_refresh_play()
	if current_page == "Play" and is_inside_tree(): _focus_primary()

func _refresh_play() -> void:
	$Pages/Play/Body/MapInfo.text = _map_info(_map_id())
	if not _play_error: _show_status($Pages/Play/Footer/Status, _summary() if opponent == "bot" else FRIEND_HINT)

func _map_info(id: String) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MatchSettings.map_path(id)))
	return "%d start positions · %d supply sources" % [data.starts.size(), data.sources.size()]

func _summary() -> String:
	return "%s · %s vs %s bot" % [MatchSettings.PLAY_MAPS[_map_id()], Registry.faction(_faction($Pages/Play/Body/Own)).display_name, Registry.faction(_faction($Pages/Play/Body/Bot)).display_name]

func _connect_play_controls() -> void:
	$Pages/Play/Body/Opponent/BotToggle.pressed.connect(set_opponent.bind("bot"))
	$Pages/Play/Body/Opponent/FriendToggle.pressed.connect(set_opponent.bind("friend"))
	for path in OWNS:
		var selector: OptionButton = get_node(path)
		var on_play: bool = path.begins_with("Pages/Play")
		selector.item_selected.connect(func(index: int) -> void:
			if on_play: _play_error = false
			_set_own(selector.get_item_metadata(index))
			_focus_primary())
	for selector: OptionButton in [$Pages/Play/Body/Bot, $Pages/Play/Body/Map]:
		selector.item_selected.connect(func(_index: int) -> void:
			_play_error = false
			_refresh_play()
			_focus_primary())
	for fold in FOLDS:
		get_node(fold + "/Toggle").toggled.connect(_set_advanced)
		get_node(fold + "/RelayUrl").text_changed.connect(_set_relay)

func _apply_picks() -> void:
	var picks: Dictionary = LauncherSettings.load_picks()
	_select_id($Pages/Play/Body/Bot, picks.bot_faction)
	_select_id($Pages/Play/Body/Map, picks.map)
	_set_own(picks.faction)

func _set_own(id: String) -> void:
	for path in OWNS: _select_id(get_node(path), id)
	_refresh_play()

func _select_id(selector: OptionButton, id: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == id: selector.select(index)

func show_page(page_name: String) -> void:
	current_page = page_name
	for each in PAGES: get_node("Pages/" + each).visible = each == page_name
	get_node("Sidebar/Nav/" + _nav_of(page_name)).button_pressed = true
	if page_name == "Credits": _fill_credits()
	if is_inside_tree(): _focus_primary()

# Enter only reaches a focused control, so each page focuses the one action it is for.
func _focus_primary() -> void:
	match current_page:
		"Play": get_node("Pages/Play/Footer/" + ("Start" if opponent == "bot" else "Create")).grab_focus()
		"Join": _focus_join()
		"Waiting": $Pages/Waiting/Body/Left/Invite/Copy.grab_focus()

func _focus_join() -> void:
	var code: LineEdit = $Pages/Join/Body/Code
	if not code.text.is_empty():
		$Pages/Join/Footer/Join.grab_focus()
		return
	code.grab_focus()
	code.caret_column = code.text.length()

static func _nav_of(page_name: String) -> String:
	return "Play" if page_name == "Waiting" else page_name

func _fill_credits() -> void:
	var text: RichTextLabel = $Pages/Credits/Body/Text
	if text.text.is_empty():
		text.text = Credits.text(FileAccess.get_file_as_string("res://audio/CREDITS.md"), FileAccess.get_file_as_string("res://data/maps/NOTICE.md"), Engine.get_license_text(), Engine.get_copyright_info(), Engine.get_license_info(), FileAccess.get_file_as_string("res://fonts/PublicSans-OFL.txt"))

func _show_status(label: Label, text: String, error: bool = false) -> void:
	label.text = text
	label.theme_type_variation = &"FooterError" if error else &"FooterStatus"
	var width: float = label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
	var wide: bool = width > STATUS_WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN

func _status_label() -> Label:
	return get_node("Pages/%s/Footer/Status" % _origin)

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
	var builds: Array[Button] = [$Pages/Play/ThisBuild, $Pages/Join/ThisBuild]
	var show_panel := func(open: bool) -> void:
		for build: Button in builds: build.text = "This build: " + FocusCards.card(FocusCards.shown(), focus_cards).title
		panel.visible = open
		_set_shell_visible(not open)
	show_panel.call(false)
	for build: Button in builds:
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

# Same stored keys and labels as the Esc menu; pause_menu.gd keeps its state in the menu, so it cannot be shared as is.
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

func _fill_factions() -> void:
	var ids: Array = Registry.Factions.FACTIONS.keys()
	ids.sort()
	for selector: OptionButton in [$Pages/Play/Body/Own, $Pages/Join/Body/Own, $Pages/Play/Body/Bot]:
		for id: String in ids:
			selector.add_item(Registry.faction(id).display_name)
			selector.set_item_metadata(selector.item_count - 1, id)
		selector.select(maxi(ids.find(Registry.Factions.DEFAULT_FACTION), 0))

func _faction(selector: OptionButton) -> String:
	return selector.get_item_metadata(selector.selected)

func _fill_maps() -> void:
	var selector: OptionButton = $Pages/Play/Body/Map
	for id: String in MatchSettings.PLAY_MAPS:
		selector.add_item(MatchSettings.PLAY_MAPS[id])
		selector.set_item_metadata(selector.item_count - 1, id)

func _map_id() -> String:
	var selector: OptionButton = $Pages/Play/Body/Map
	return selector.get_item_metadata(selector.selected)

func _offline_setup() -> void:
	var id: String = _map_id()
	LauncherSettings.save_picks({"faction": _faction($Pages/Play/Body/Own), "bot_faction": _faction($Pages/Play/Body/Bot), "map": id})
	SkirmishMain.factions = {1: _faction($Pages/Play/Body/Own), 2: _faction($Pages/Play/Body/Bot)}
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = randi()
	SkirmishMain.starts = MatchSettings.starts(id, SkirmishMain.match_seed)

func _join() -> void:
	if _transport != null: return
	_origin = "Join"
	var code: String = JoinLink.code($Pages/Join/Body/Code.text.strip_edges())
	if code.is_empty(): _show_status($Pages/Join/Footer/Status, "Enter the 6-character match code", true)
	else: _connect(code)

func _cancel() -> void:
	if _transport == null: return
	_transport.close()
	_fail(CANCELLED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _transport != null and current_page != "Waiting":
		_cancel()
		get_viewport().set_input_as_handled()

func _now_msec() -> int:
	return floori(int(_clock.call()) / 1000.0)

func _show_connecting(now_msec: int) -> void:
	var text := "Connecting… %d s" % floori(maxi(0, now_msec - _connect_msec) / 1000.0)
	var label: Label = _status_label()
	if label.text != text: _show_status(label, text)

func _show_countdown(now_msec: int) -> void:
	var left: int = maxi(0, RelayTransport.LOBBY_EXPIRY_SEC - floori(maxi(0, now_msec - _welcome_msec) / 1000.0))
	var text := "Match code [b][color=#ffffff]%s[/color][/b] · closes in %d:%02d" % [_code, floori(left / 60.0), left % 60]
	if $Pages/Waiting/Footer/Status.text != text: $Pages/Waiting/Footer/Status.text = text

func _connect(code: String) -> void:
	_match = code
	_hello_sent = false
	_welcome_msec = -1
	_connect_msec = _now_msec()
	_transport = RelayTransport.new(_clock)
	var error: Error = _transport.connect_to(_relay_url())
	if error != OK:
		_fail("Cannot connect to relay")
		return
	_show_connecting(_connect_msec)
	_set_busy(true)
	set_process(true)

func _set_busy(busy: bool) -> void:
	for path: String in ["Play", "Join"]: get_node("Pages/%s/Footer/CancelConnect" % path).visible = busy
	for button_name: String in NAV_PAGES + ["Quit"]: _lock(get_node("Sidebar/Nav/" + button_name), busy)
	for path: String in ["Play/Footer/Start", "Play/Footer/Create", "Play/Body/Advanced/RelayUrl", "Join/Body/Advanced/RelayUrl", "Join/Body/Code", "Join/Footer/Join", "Play/Body/Own", "Join/Body/Own", "Play/Body/Bot", "Play/Body/Map", "Play/Body/Opponent/BotToggle", "Play/Body/Opponent/FriendToggle"]:
		var control: Control = get_node("Pages/" + path)
		if control is BaseButton: _lock(control, busy)
		else: control.editable = not busy
	# The pressed Create or Join turns disabled, so focus would sit on a dead button.
	get_node("Pages/%s/Footer/%s" % [_origin, "CancelConnect" if busy else ("Join" if _origin == "Join" else "Create")]).grab_focus()

# Godot draws a disabled button in its disabled style even when pressed; the selected item must stay grey.
func _lock(button: BaseButton, busy: bool) -> void:
	button.disabled = busy
	if busy and button.button_pressed: button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
	else: button.remove_theme_stylebox_override("disabled")

func _fail(reason: String) -> void:
	_show_status(_status_label(), reason, reason != CANCELLED)
	_play_error = _origin == "Play"
	_transport = null
	if current_page == "Waiting": show_page(_origin)
	_set_busy(false)
	set_process(false)

func _process(_delta: float) -> void:
	if _transport == null: return
	var frames: PackedStringArray = _transport.poll()
	if _transport.is_open() and not _hello_sent:
		_hello_sent = true
		var hello: Dictionary = {"type": "hello", "protocol": Wire.PROTOCOL, "build": str(ProjectSettings.get_setting("application/config/version")), "match": _match}
		if _match.is_empty(): hello["settings"] = MatchSettings.for_map(_map_id())
		_transport.send_text(Wire.encode(hello))
	for text in frames:
		if _lockstep != null: _lockstep.receive(text)
		elif not _handle(text): return
	if _transport.closed() or _transport.silent(int(_clock.call())): _fail("Connection to relay lost")
	elif _transport != null: _show_ticking()

func _show_ticking() -> void:
	if _welcome_msec < 0: _show_connecting(_now_msec())
	elif current_page == "Waiting": _show_countdown(_now_msec())

func _handle(text: String) -> bool:
	var decoded: Dictionary = Wire.decode(text)
	if not decoded.ok:
		_transport.close()
		_fail("Protocol error: " + decoded.error)
		return false
	var message: Dictionary = decoded.message
	match message.type:
		"welcome":
			_seat = message.seat
			_code = message.match
			_transport.patient = true
			_welcome_msec = _now_msec()
			if _seat == 1:
				_fill_waiting()
				show_page("Waiting")
			else:
				_show_status(_status_label(), "Joined match %s" % message.match)
		"start": return _start(message)
		"error":
			_transport.close()
			_fail(DID_NOT_JOIN if message.reason == "lobby expired" else message.reason)
			return false
		_:
			_transport.close()
			_fail("Protocol error: unexpected " + message.type)
			return false
	return true

func _fill_waiting() -> void:
	var body: Control = $Pages/Waiting/Body
	var own: OptionButton = $Pages/Play/Body/Own
	var id: String = _map_id()
	body.get_node("Left/Invite/Link").text = _copy_text()
	body.get_node("Left/CodeHint").text = "Or tell them the code: [b][color=#ffffff]%s[/color][/b]" % _code
	body.get_node("Left/One/Row/Faction").text = own.get_item_text(own.selected)
	body.get_node("Right/Map/Box/Name").text = MatchSettings.PLAY_MAPS[id]
	body.get_node("Right/Map/Box/Info").text = _map_info(id)
	_show_countdown(_welcome_msec)

func _start(message: Dictionary) -> bool:
	var reason: String = MatchSettings.refusal(message.settings)
	if not reason.is_empty():
		_transport.close()
		_fail(reason)
		return false
	_lockstep = Lockstep.for_start(_seat, message)
	var id: String = message.settings.map
	var picks: Dictionary = {"faction": _faction($Pages/Play/Body/Own)}
	if _seat == 1: picks["map"] = id
	LauncherSettings.save_picks(picks)
	SkirmishMain.map_path = MatchSettings.map_path(id)
	SkirmishMain.match_seed = message.seed
	SkirmishMain.starts = MatchSettings.starts(id, message.seed)
	var game: Node = OnlineScene.instantiate()
	game.setup(_transport, _lockstep, _seat, _faction($Pages/Play/Body/Own))
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()
	return true
