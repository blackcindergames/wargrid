extends Node

const Iso = preload("res://scripts/presentation/isometric.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PerfOverlay = preload("res://scripts/presentation/perf_overlay.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Orders = preload("res://scripts/match/orders.gd")
const MousePan = preload("res://scripts/match/mouse_pan.gd")
const Hud = preload("res://scripts/match/hud.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const LAUNCHER_SCENE: String = "res://scenes/launcher.tscn"
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const MusicPlayer = preload("res://scripts/presentation/music_player.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const PlaytestOverlay = preload("res://scripts/playtest/playtest_overlay.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const ViewCaps = preload("res://scripts/presentation/view_caps.gd")
const PingMarks = preload("res://scripts/presentation/ping_marks.gd")
const AUTO_FRAMES: int = 120
const AUTO_SKIP_FRAMES: int = 60
const EDGE_BAND: float = 3.0
const EDGE_STEP_MAX: float = 0.05
# Zero Hour snaps (View::lookAt); the owner found the snap disorienting (user, 2026-11-23).
const GLIDE_MIN_SECONDS: float = 0.15
const GLIDE_MAX_SECONDS: float = 0.45
const GLIDE_FAR_PX: float = 2000.0
const GLIDE_SNAP_PX: float = 4.0
# The fixed dock band below the dock line (hud-v5-layout.md), so the shown panel never moves a target.
const DOCK_HEIGHT: float = 168.0
# Screen px: a camera panned further off the Headquarters than this recentres on it instead of going back.
const JUMP_NEAR_PX: float = 24.0
static var factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH
static var map_path: String = Skirmish.MAP_PATH
static var starts: Array[int] = []
static var match_seed: int = 0
var driver: RefCounted
var orders: RefCounted = Orders.new(self)
var mouse_pan: RefCounted = MousePan.new(self)
var hud: Hud
var local_player: int = 1
var view_player: int = 1
var stepped_results: Array = []
var _last_result_tick: int = -1
var _last_result_sequence: int = -1
var shown_state: Dictionary = {}
var _shown_note: String = ""
var _camera_bounds: Rect2
var _glide_from: Vector2
var _glide_to: Vector2
var _glide_world: Vector2
var _jump_back: Variant = null
var _glide_left: float = 0.0
var _glide_seconds: float = GLIDE_MAX_SECONDS
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
var _perf: Label
var _clock := PresentationClock.new()
var _pause: Control
var _result_panel: Control
var change_scene: Callable = _change_scene
var outside_probe: Callable = _outside_probe
var quit: Callable
@onready var _selection_box: ReferenceRect = $HUD/SelectionBox
var _sound: SoundPlayer = null
var _auto_samples := PackedFloat32Array()
var _auto_pending: bool = false
var _auto_frame: int = 0
var _auto_tick_usec: int = 0
var _visuals := VisualDirector.new()
var _pings: PingMarks
var _playtest: PlaytestOverlay
var _leaving: bool = false
var _unanswered: int = 0
var _stale: int = 0
# Window events are sorted here in `_input`; tests that call `_unhandled_input` directly feed map logic points past the view.
var _off_picture: InputEvent = null
var _pointer: Vector2 = Vector2.ZERO
var _pointer_in: bool = false
var _focused: bool = true

func setup(transport: RefCounted, lockstep: RefCounted, seat: int, faction: String = Skirmish.default_faction()) -> void:
	driver = OnlineDriver.new(transport, lockstep, faction, seat)
	local_player = seat
	view_player = seat

func _ready() -> void:
	view_player = local_player
	# The launcher may have seen the focus-out during the scene load; headless has no window focus to read.
	_focused = DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()
	get_viewport().size_changed.connect(func() -> void: _pointer_in = false) # the cached pointer is in the old picture's coordinates
	if driver == null: driver = OfflineDriver.new(local_player)
	_result_panel = ResultPanel.new()
	_result_panel.play_again_pressed.connect(_play_again)
	_result_panel.change_setup_pressed.connect(_leave)
	$HUD.add_child(_result_panel)
	hud = Hud.new()
	$HUD.add_child(hud)
	$HUD.move_child(hud, 0)
	hud.setup($HUD/Economy)
	# Above the result card's dim and click catcher, so Menu stays live after the match, as the Playtest chip does.
	var menu_chip: Control = hud.get_node("MenuChip")
	menu_chip.reparent($HUD, false)
	$HUD.move_child(menu_chip, _result_panel.get_index() + 1)
	hud.cell_pressed.connect(orders.press_cell)
	hud.entry_cancelled.connect(orders._cancel_entry)
	hud.cancel_build_pressed.connect(orders._cancel_build)
	hud.row_clicked.connect(_select_kind)
	hud.producer_pressed.connect(orders.select_producer)
	hud.ping_pressed.connect(orders.arm_ping)
	# Made here, not at declaration: a scene freed before it enters the tree would orphan the node.
	_pings = PingMarks.new()
	_pings.hud = hud
	_pings.jump.connect(centre_camera)
	_view.add_child(_pings)
	hud.hint_covered = func() -> bool: return menu_open() or not _focused or input_over()
	_perf = PerfOverlay.new()
	$HUD.add_child(_perf)
	_pause = PauseMenu.new()
	_pause.confirm_leave = driver.confirm_leave()
	_pause.resume_requested.connect(_pause.close)
	_pause.opened.connect(_fill_questions)
	hud.menu_pressed.connect(_pause.open)
	_pause.leave_requested.connect(_leave)
	if not quit.is_valid(): quit = get_tree().quit
	_pause.quit_requested.connect(func() -> void:
		close_match(true)
		quit.call())
	_pause.quality_changed.connect(_view.set_quality)
	_pause.neon_changed.connect(_view.set_bright_owners)
	_pause.neon_changed.connect(func(_bright: bool) -> void: _reshow())
	_pause.smooth_changed.connect(_view.set_smooth)
	_pause.destinations_changed.connect(_view.set_show_destinations)
	$HUD.add_child(_pause)
	_result_panel.yields_to = _pause
	_result_panel.yields_when = func() -> bool: return _playtest.holds_match() or _typing()
	_view.set_quality(GraphicsSettings.stored_quality())
	_view.set_bright_owners(GraphicsSettings.load_neon())
	_view.set_smooth(GraphicsSettings.load_smooth())
	_view.set_show_destinations(GraphicsSettings.load_destinations())
	_view.local_player = local_player
	_create_world()
	_clock = PresentationClock.new()
	_reset_camera()
	_add_playtest()
	_refresh()
	_view.set_visuals(_visuals)
	_start_auto_pick(GraphicsSettings.load_quality() == -1 and DisplayServer.get_name() != "headless")
	var music := MusicPlayer.new()
	add_child(music)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	music.play_match(rng, MusicPlayer.GAP_SECONDS)
	_perf.mode = driver.sim_mode()
	if driver.has_method("net_line"): _perf.extra = driver.net_line
	if driver.has_method("bot_line"):
		_perf.extra = driver.bot_line
		_perf.visibility_changed.connect(func() -> void: driver.show_bots = _perf.visible)
	driver.start()

func _enter_tree() -> void:
	ViewCaps.apply(get_tree().root)

func _exit_tree() -> void:
	mouse_pan.drop()
	orders._set_attack_move(false)
	orders._set_ping(false)
	driver.stop()
	driver.detach()
	ViewCaps.release(get_tree().root)

func _add_playtest() -> void:
	_playtest = PlaytestOverlay.new()
	_playtest.setup(FocusCards.card(FocusCards.shown(), FocusCards.load_cards()), playtest_context, playtest_match, playtest_header)
	$HUD.add_child(_playtest)
	$HUD.move_child(_playtest, _pause.get_index())
	_pause.opened.connect(_playtest.observe_menu)
	_pause.opened.connect(hud.read_keys)
	_pause.playtest_changed.connect(_playtest.set_active)
	_playtest.set_active(PlaytestSettings.enabled())
	for surface: Control in _playtest.surfaces(): hud.block(surface)
	hud.helpers = _playtest.surfaces()
	_playtest.stack_changed.connect(_place_perf)
	$HUD/Economy.item_rect_changed.connect(_place_floor)
	$HUD/Economy.visibility_changed.connect(_place_floor)
	_perf.resized.connect(_place_perf)
	_place_perf()

# Show more and window resizes move the slab between views, so the helper stack follows the slab itself.
func _place_floor() -> void:
	_playtest.set_floor(hud.slab_top())

func _place_perf() -> void:
	_perf.place(_playtest.slot_for(_perf.size))

func _reset_camera() -> void:
	_jump_back = null
	var size: Array = driver.current().view.map.size
	_camera_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for corner: Variant in [Vector2(size[0], 0), Vector2(0, size[1]), Vector2(size[0], size[1])]:
		_camera_bounds = _camera_bounds.expand(Iso.world_to_plane(corner))
	var start: Vector2i = driver.first_note.starts.get(view_player, Vector2i(-1, -1))
	var focus := Vector2(start) + Vector2(0.5, 0.5) if start.x >= 0 else Vector2(size[0], size[1]) / 2.0
	_glide_left = 0.0
	_camera.position = Iso.world_to_plane(focus)

func _create_world() -> void:
	driver.create(map_path, starts, factions, match_seed)
	if driver.teammate() == 0: Palette.clear_team_colours()
	else: Palette.set_team_colours(driver.bot_players())

func playtest_context() -> Dictionary:
	var camera: Vector2 = Iso.plane_to_world(_camera.position)
	return {"tick": shown_state.tick, "camera": [camera.x, camera.y], "selected": orders.view_selection(), "over": driver.over(), "menu": _pause.visible}

func playtest_match() -> Dictionary:
	var played: Dictionary = driver.match_log()
	return _match_record(played, played.commands).merged({"end": played.get("end", "")})

func playtest_header() -> Dictionary:
	var played: Dictionary = driver.match_header()
	return _header(played)

func _header(played: Dictionary) -> Dictionary:
	return {"mode": played.mode, "map": _map_id(), "seed": match_seed, "factions": played.factions, "teams": played.teams, "bots": played.bots, "seat": local_player, "controller": "human", "sim": driver.sim_mode(), "build": PlaytestSettings.build_id()}

func _map_id() -> String:
	return map_path.get_file().get_basename()

func _match_record(header: Dictionary, lines: PackedStringArray) -> Dictionary:
	var record: Dictionary = driver.record()
	var played: Dictionary = _header(header).merged({"end_tick": record.tick, "end_digest": record.digest, "result": _result_text(record.match), "commands": lines, "accidental_cancels": orders.accidental_cancels, "next_clicks": hud.next_clicks})
	if record.has("tick_hashes"): played.tick_hashes = record.tick_hashes
	return played

# Only an answer to an order sent after the refusal clears it, so an earlier order in flight cannot wipe a hint.
# shortcut: answers are counted, not matched; an order that never gets one leaves the line to its timer; match by sequence if that shows up.
func _take_answers() -> void:
	var answers: Array[Dictionary] = driver.take_answers()
	var refused: Dictionary = {}
	var fresh: bool = false
	for answer: Dictionary in answers:
		# A refused ping stays silent (plan T2-8): its only effect would have been the mark.
		if not answer.ok and answer.command.get("type") != "ping": refused = answer
		if answer.command.is_empty(): continue
		_unanswered = maxi(_unanswered - 1, 0)
		if _stale > 0: _stale -= 1
		elif answer.ok and answer.command.get("type") != "ping": fresh = true
	if not refused.is_empty(): refuse(refused.error, SoundPlayer.SoundDirector.refusal_sound(refused.error))
	elif fresh: hud.clear_refusal()
	for answer: Dictionary in answers:
		if answer.ok: _playtest.observe_command(answer.command)
		orders.answered(answer)
		hud.cancel_answered(answer)

# Each team ping asks for the tone; the announcer's cooldown keeps a burst to one (7-24).
func _take_pings() -> void:
	for ping: Dictionary in driver.take_pings():
		_pings.add(ping.player, ping.target)
		# The pinger knows where it clicked, and its tone's cooldown would mute the teammate's answer.
		if ping.player == local_player: continue
		_ensure_sound()
		_sound.director.announcer.request("ping", ping.tick)

# Pings go to a human teammate, so the chip and the input exist only with one (Q7).
func can_ping() -> bool:
	return driver.can_ping() and not input_over()

func menu_open() -> bool:
	return _pause.visible or _playtest.holds_match()

func _escape_pending() -> bool:
	return not shown_over() and not frozen() and orders.escape_pending()

# Only the offline driver ever returns the freeze notice, so failure() is read only then.
func frozen() -> bool:
	return driver.notice() == OfflineDriver.FREEZE_NOTICE

func _leave() -> void:
	if _leaving: return
	_leaving = true
	driver.leave()
	get_viewport().gui_release_focus()
	close_match(false)
	Palette.clear_team_colours()
	change_scene.call(LAUNCHER_SCENE)

# An empty driver question keeps the 1v1 words.
func _fill_questions() -> void:
	var leave: String = driver.leave_question()
	var quitting: String = driver.quit_question()
	_pause.leave_question = leave if not leave.is_empty() else PauseMenu.LEAVE_QUESTION
	_pause.quit_question = quitting if not quitting.is_empty() else PauseMenu.QUIT_QUESTION

func close_match(file_sitting: bool) -> void:
	driver.stop()
	if file_sitting: _playtest.close_out()
	else: _playtest.keep_match()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not _playtest.web: close_match(true) # web files at the next launcher open instead
		NOTIFICATION_WM_MOUSE_EXIT: _pointer_in = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			mouse_pan.drop()
		NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN: _focused = true

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = event.position
		_pointer_in = get_viewport().get_visible_rect().has_point(event.position)
	mouse_pan.follow(event)
	if event is InputEventMouse and not _pointer_in: _off_picture = event
	elif event is InputEventMouseMotion and hud.blocks(event.position): orders.handle(event) # a STOP panel takes motion before `_unhandled_input`: the drag box keeps up and the hover clears
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.physical_keycode == KEY_F3: return
	if event.is_action_pressed("deselect"):
		if _pause.visible: _pause.back()
		elif not _escape_pending(): _pause.open()
		else: return
	elif not _pause.visible:
		if _result_panel.takes_enter(event) and not _typing() and not _playtest.holds_match(): _play_again()
		# Space is ui_accept: hammered in a base fight it must not press the card's focused Back to menu.
		elif not (_result_panel.visible and not _typing() and event.physical_keycode == KEY_SPACE): return
	elif event.is_action_pressed("ui_accept"): return
	get_viewport().set_input_as_handled()

# The bars past a stretch cap show no map: a click there is nobody's, a drag ending there stops at the picture's edge.
# Dropped after the GUI, so a control that took the press still gets its release in a bar.
func _drop_off_picture(event: InputEventMouse) -> void:
	_off_picture = null
	if not orders.is_selecting(): return
	var view: Rect2 = get_viewport().get_visible_rect()
	var clamped := event.duplicate() as InputEventMouse
	clamped.position = event.position.clamp(view.position, view.end)
	orders.handle(clamped)

func esc_opens_menu() -> bool:
	return not _escape_pending() and not _playtest.holds_match() and not _typing() and not _pause.visible

# Focus and the note form change without a new view, so the chip follows every frame.
func _show_esc_chip() -> void:
	hud.set_esc_chip(esc_opens_menu())

# The pause menu and the note form open without a new view, so this runs every frame too.
func _drop_stale_attack_move() -> void:
	if orders._attack_move_mode and (not orders.takes_orders() or _pause.visible or not HudModel.has_armed_unit(shown_state, orders.selected_ids, local_player)): orders._set_attack_move(false)
	if orders.ping_armed and (not orders.takes_orders() or _pause.visible or not can_ping()): orders._set_ping(false)

func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _physics_process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_step_frame()
	if _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - started

func _step_frame() -> void:
	if menu_open() and driver.pauses_sim(): return
	var started: int = Time.get_ticks_usec()
	driver.step()
	var rematch_seed: int = driver.take_rematch()
	if rematch_seed >= 0:
		_rematch(rematch_seed)
		return
	_perf.record_step((Time.get_ticks_usec() - started) / 1000.0)

func _drain_notes() -> bool:
	var tick_before: int = driver.current().tick
	var last_tick: int = tick_before
	for note: SimPump.Note in driver.drain():
		_collect_note(note)
		# A finished match re-reports its last results without a new tick.
		if note.tick > last_tick: stepped_results.append_array(note.results)
		last_tick = note.tick
	_take_answers()
	_take_pings()
	# A stall frame (online, waiting for the peer) is not a step frame; counting it would inflate the split share.
	var advanced: bool = driver.current().tick != tick_before
	if not is_processing() or (advanced and _clock.stepped(Engine.get_process_frames(), driver.current().tick)) or (not advanced and _note() != _shown_note):
		_refresh()
		return true
	return false

func _present_if_due() -> bool:
	if not _clock.rendered(Engine.get_process_frames(), driver.current().tick): return false
	_refresh()
	return true

func _process(delta: float) -> void:
	_show_esc_chip()
	if menu_open() or input_over(): mouse_pan.drop()
	_drop_stale_attack_move()
	var drained_at: int = Time.get_ticks_usec()
	if _drain_notes() and _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - drained_at
	var presented_at: int = Time.get_ticks_usec()
	if _present_if_due() and _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - presented_at
	var arrows: Vector2 = Vector2.ZERO if _typing() or menu_open() or input_over() else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if arrows != Vector2.ZERO: pan_camera(arrows, delta)
	elif mouse_pan.anchoring() and not orders.is_selecting(): _pan_by(mouse_pan.anchor_offset() * minf(delta, EDGE_STEP_MAX))
	elif not mouse_pan.grabbing(): edge_scroll(delta)
	glide_camera(delta)
	var view: Rect2 = get_viewport().get_visible_rect()
	_pings.advance(view, _view.get_global_transform_with_canvas(), minf(view.end.y - DOCK_HEIGHT, hud.dock_top()))
	_view.advance_frame()
	if not _auto_pending: return
	_auto_sample((_auto_tick_usec + _view.draw_usec) / 1000.0)
	_auto_tick_usec = 0
	_view.draw_usec = 0

# shortcut: measured at match start on a nearly empty map, so it only catches very slow machines; re-check under load if playtesters report a slow High.
# The first frames hold scene load and lazy bakes, so they are skipped.
func _start_auto_pick(enabled: bool) -> void:
	_auto_pending = enabled
	_view.time_draws = enabled

func _auto_sample(frame_ms: float) -> void:
	if not _auto_pending: return
	_auto_frame += 1
	if _auto_frame <= AUTO_SKIP_FRAMES: return
	_auto_samples.append(frame_ms)
	if _auto_samples.size() < AUTO_FRAMES: return
	_start_auto_pick(false)
	_auto_samples.sort()
	var quality: int = GraphicsSettings.pick(_auto_samples[int(AUTO_FRAMES * 0.95)])
	GraphicsSettings.save_quality(quality)
	_view.set_quality(quality)

func pan_camera(direction: Vector2, delta: float) -> void:
	if orders.is_selecting() or direction == Vector2.ZERO:
		return
	_pan_by(direction.normalized() * 400.0 * delta)

func _pan_by(canvas: Vector2) -> void:
	_glide_left = 0.0
	_jump_back = null
	_move_camera(_camera.position + canvas / _camera.zoom.x)

func grab_camera(step: Vector2) -> void:
	if menu_open() or input_over() or orders.is_selecting(): return
	_glide_left = 0.0
	_jump_back = null
	_move_camera(_camera.position + step)

func edge_scroll(delta: float) -> void:
	pan_camera(edge_direction(), minf(delta, EDGE_STEP_MAX))

# A pointer in a stretch-cap bar is off the picture and never pans; HUD panels are no exception (3-26).
func edge_direction() -> Vector2:
	if not _focused or _typing() or menu_open() or input_over(): return Vector2.ZERO
	if not _pointer_in: return Vector2.ZERO if _playtest.web else outside_probe.call()
	var view: Rect2 = get_viewport().get_visible_rect()
	return Vector2(_edge_sign(_pointer.x, view.position.x, view.end.x), _edge_sign(_pointer.y, view.position.y, view.end.y))

# A windowed pointer slides out past the band; outside a focused window keeps panning at any distance, as Warzone 2100 (user, 2026-11-23).
# Godot 4.7.2 on macOS and Windows gives these in one screen space: content rect, frame with title bar, pointer.
func _outside_probe() -> Vector2:
	if DisplayServer.get_name() == "headless": return Vector2.ZERO
	var window := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var frame := Rect2(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
	var screen: int = DisplayServer.window_get_current_screen()
	return outside_direction(DisplayServer.mouse_get_position(), window, frame, get_viewport().get_visible_rect().size, Rect2(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen)))

# The frame is the player's to drag and close; past a stretch-cap bar (more than one picture px wide) that axis holds, as the bar does (3-26).
# Only on the window's own screen: a pointer resting on another monitor must not pan (user, 2026-11-23).
static func outside_direction(pointer: Vector2, window: Rect2, frame: Rect2, picture: Vector2, screen: Rect2) -> Vector2:
	if window.has_point(pointer) or frame.has_point(pointer) or not screen.has_point(pointer): return Vector2.ZERO
	var bars: Vector2 = window.size / minf(window.size.x / picture.x, window.size.y / picture.y) - picture
	var beyond: Vector2 = (pointer - pointer.clamp(window.position, window.end - Vector2.ONE)).sign()
	return Vector2(0.0 if bars.x > 1.0 else beyond.x, 0.0 if bars.y > 1.0 else beyond.y)

static func _edge_sign(at: float, low: float, high: float) -> float:
	if at < low + EDGE_BAND: return -1.0
	return 1.0 if at >= high - EDGE_BAND else 0.0

# The target lands mid-way between the top and the dock line; HUD px are canvas px under the stretch, so only the zoom converts.
# Any pan or other jump forgets H's back spot, so H goes back only right after H (user, 2026-11-23).
func centre_camera(world: Vector2) -> void:
	_jump_back = null
	_glide_world = world
	_glide_to = _landing(world)
	_glide_from = _camera.position
	var screen_px: float = _glide_from.distance_to(_glide_to) * _camera.zoom.x
	_glide_seconds = lerpf(GLIDE_MIN_SECONDS, GLIDE_MAX_SECONDS, minf(screen_px / GLIDE_FAR_PX, 1.0))
	_glide_left = _glide_seconds
	if screen_px <= GLIDE_SNAP_PX: glide_camera(_glide_seconds)

func _below() -> Vector2:
	return Vector2(0.0, DOCK_HEIGHT / 2.0) / _camera.zoom.x

func _landing(world: Vector2) -> Vector2:
	return (Iso.world_to_plane(world) + _below()).clamp(_camera_bounds.position, _camera_bounds.end)

func glide_seconds_left() -> float:
	return _glide_left

# 0 A.D.'s jumpCamera (136720dada selection_panels_helpers.js:243-260): the key again on arrival, or mid-glide, goes back.
# True when it goes home, false when it goes back.
func jump_home(world: Vector2) -> bool:
	var heading: Vector2 = _glide_to if _glide_left > 0.0 else _camera.position
	if _jump_back != null and heading.distance_to(_landing(world)) * _camera.zoom.x <= JUMP_NEAR_PX:
		centre_camera(_jump_back)
		return false
	var back: Vector2 = Iso.plane_to_world(heading - _below())
	centre_camera(world)
	_jump_back = back
	return true

# A drag box ends the glide, as it holds a pan.
func glide_camera(delta: float) -> void:
	if _glide_left <= 0.0: return
	if orders.is_selecting():
		_glide_left = 0.0
		return
	_glide_left = maxf(_glide_left - delta, 0.0)
	var t: float = 1.0 - _glide_left / _glide_seconds
	_move_camera(_glide_from.lerp(_glide_to, 1.0 - pow(1.0 - t, 3.0)))

func _move_camera(plane: Vector2) -> void:
	var before: Vector2 = _camera.position
	_camera.position = plane.clamp(_camera_bounds.position, _camera_bounds.end)
	if _camera.position == before: return
	_camera.force_update_scroll()
	orders.camera_moved()

func change_zoom(direction: int) -> void:
	if orders.busy():
		return
	var index: int = ZOOMS.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, ZOOMS.size() - 1)
	_camera.zoom = Vector2.ONE * ZOOMS[index]
	_view.set_zoom(ZOOMS[index])
	# The dock offset is in screen px, so a glide under way retargets for the new zoom.
	if _glide_left <= 0.0: return
	var back: Variant = _jump_back
	centre_camera(_glide_world)
	_jump_back = back

func _unhandled_input(event: InputEvent) -> void:
	# A field passes on shortcuts it does not use (Cmd+S, Ctrl+1); orders ignore modifiers, so they would fire.
	if event is InputEventKey and _typing(): return
	if event == _off_picture:
		_drop_off_picture(event)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _typing() and not _playtest.holds_match(): get_viewport().gui_release_focus()
	if not input_over() and not menu_open() and mouse_pan.take(event): return
	orders.handle(event)

func _refresh() -> void:
	_show(driver.current().view)

func _note() -> String:
	# The rematch line changes without a tick, so a finished match still redraws its panel.
	return hud.refusal + driver.notice() + driver.rematch_line()

func shown_over() -> bool:
	return shown_state.get("match") != null and shown_state.match.status in ["won", "draw"]

# A result, an ended online room or the freeze card: nothing on the map takes input.
func input_over() -> bool:
	return shown_over() or driver.over() or frozen()

func _reshow() -> void:
	_show(shown_state, false)

# Only a new view consumes step results and sound; a repaint on input must leave them for the next refresh.
func _show(state: Dictionary, fresh: bool = true) -> void:
	shown_state = state
	# An armed placement (and its strip preview) and a drag box must never show over a result or freeze card or an ended online match.
	if input_over():
		if not orders._placement_kind.is_empty(): orders._clear_placement()
		hud.end_hover()
		orders._selecting = false
		_selection_box.hide()
	# A repaint leaves the note unshown, so a refusal's sound gets its fresh refresh next frame even while lockstep waits.
	if fresh: _shown_note = _note()
	_perf.set_counts(state.units.size(), state.get("buildings", []).size(), state.tick)
	_perf.split_share = _clock.split_share()
	var zone: int = Profiler.begin()
	orders.prune(state)
	orders.select_start(state)
	_drop_stale_attack_move()
	orders.show_preview(driver.preview_answer())
	Profiler.end(&"refresh.selection", zone)
	_view.view_player = view_player
	_view.set_view(state, orders.view_selection())
	zone = Profiler.begin()
	_ensure_sound()
	_take_results(state)
	hud.update_hud(state, _hud_selection(), view_player, local_player)
	hud.show_ping(can_ping(), orders.ping_armed)
	_place_floor()
	_view.set_inspected(orders.inspected_id)
	if frozen(): _show_freeze()
	else: _show_result(state)
	if fresh:
		_sound.update(state)
		var alert: String = _sound.director.take_alert()
		if not alert.is_empty(): hud.alert(alert)
	Profiler.end(&"refresh.hud", zone)
	if fresh: stepped_results.clear()

func _take_results(state: Dictionary) -> void:
	for result: Dictionary in stepped_results + state.command_results:
		if result.player == local_player and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			# The sound director already beeps for a due-time failure.
			if not result.ok: refuse(result.error, "")
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence

# A kind row narrows the selection to its kind; with Shift it drops that kind.
func _select_kind(kind: String, shift: bool) -> void:
	if not orders.takes_orders(): return
	var units: RefCounted = shown_state.units
	orders.selected_ids.assign(orders.selected_ids.filter(func(id: int) -> bool:
		var i: int = units.index_of(id)
		return (i != -1 and units.kinds[units.kind[i]] == kind) != shift))
	_reshow()

func _hud_selection() -> Dictionary:
	return {"ids": orders.selected_ids, "building_id": orders.selected_building_id, "inspected_id": orders.inspected_id, "placement_kind": orders._placement_kind, "sub_grid": orders._sub_grid, "resume_id": _view.resume_candidate(), "notice": "" if shown_over() or frozen() else driver.notice(), "bright_owners": _view.bright_owners(), "over": input_over(), "esc_opens_menu": esc_opens_menu(), "attack_move": orders._attack_move_mode}

func _result(state: Dictionary) -> String:
	var result: String = _result_text(state.match)
	return result if not result.is_empty() else driver.leave_heading()

func _show_result(state: Dictionary) -> void:
	var result: String = _result(state)
	var rows: Array[Dictionary] = []
	if not result.is_empty(): rows = _result_rows(state)
	var length: String = ResultPanel.length_text(state.tick, Engine.physics_ticks_per_second) if not result.is_empty() else ""
	_result_panel.show_result(result, driver.rematch_line(), driver.can_play_again(), rows, length, driver.rematch_pending(), driver.friend_wants_rematch())

func _show_freeze() -> void:
	var build: String = PlaytestSettings.build_id()
	_result_panel.show_freeze(ResultPanel.report_text(driver.failure(), build, _map_id(), driver.current().tick), ResultPanel.footer_text(build, _map_id()))

func _result_rows(state: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var ours: Array[Dictionary] = [{"group": "Your team"}]
	var stats: Array[Dictionary] = driver.match_stats()
	var mate: int = driver.teammate()
	for player: Dictionary in state.players:
		var row: Dictionary = stats.filter(func(entry: Dictionary) -> bool: return entry.player == player.id)[0]
		var you: bool = player.id == local_player
		var mark: String = " (you)" if you else " (teammate)" if player.id == mate else " (bot)" if driver.bot_players().has(player.id) else ""
		var shown: Dictionary = {"name": ResultPanel.player_name(player.id, player.get("faction", "")) + mark, "you": you, "built": row.units_built, "units_lost": row.units_lost, "buildings_lost": row.buildings_lost}
		if mate != 0: shown.colour = Palette.owner_colors(player.id, _view.bright_owners())[0]
		if mate == 0 or not (you or player.id == mate): rows.append(shown)
		elif you: ours.insert(1, shown)
		else: ours.append(shown)
	# Grouped only with a human teammate, so the offline and 1v1 tables keep their shape (7-19).
	if mate == 0: return rows
	ours.append({"group": "Enemy bots"})
	ours.append_array(rows)
	return ours

func _result_text(match_state: Variant) -> String:
	return ResultPanel.result_text(match_state, _local_team())

func _local_team() -> int:
	for player: Dictionary in shown_state.players:
		if player.id == local_player: return player.team
	return 0

func _show_hint(payload: Dictionary) -> void:
	var point: Variant = orders._hint_point(payload)
	if point != null: _view.add_hint(point, shown_state.tick)

# A batch passes `reshow` false and repaints once after it.
func _submit(payload: Dictionary, reshow: bool = true) -> Dictionary:
	orders.gestures += 1
	_show_hint(payload)
	var sent: Dictionary = driver.submit(payload)
	_unanswered += 1
	if reshow: _reshow()
	_sound.order(payload)
	return sent

# The result and freeze cards already say why nothing is taken, as with the notice.
func refuse(text: String, sound: String = "error") -> void:
	if shown_over() or frozen(): return
	_stale = _unanswered
	if not sound.is_empty():
		_ensure_sound()
		_sound.rejected(sound)
	hud.refuse(text)
	# A repeat keeps the note's words, so its sound would wait for the peer without a fresh refresh.
	_shown_note = ""

func _ensure_sound() -> void:
	if _sound != null: return
	_sound = SoundPlayer.new(local_player)
	add_child(_sound)

func _collect_note(note: SimPump.Note) -> void:
	_ensure_sound()
	_sound.collect_step(note.tick, note.events, note.results)
	_visuals.collect_step(note.tick, note.events, note.results)

func _play_again() -> void:
	if driver.can_restart(): _restart()
	else:
		driver.play_again()
		_refresh()

func _restart() -> void:
	if not driver.can_restart(): return
	_restart_world()

func _rematch(match_seed_value: int) -> void:
	match_seed = match_seed_value
	starts = MatchSettings.starts(map_path.get_file().get_basename(), match_seed_value, driver.teams())
	_restart_world()

func _restart_world() -> void:
	view_player = local_player
	_playtest.begin_match()
	_create_world()
	_perf.mode = driver.sim_mode()
	_clock = PresentationClock.new()
	_sound.director.reset()
	_sound._unit_voice.stop()
	_visuals.reset()
	_pings.clear()
	orders.reset()
	hud.reset()
	_unanswered = 0
	_stale = 0
	_last_result_tick = -1
	_last_result_sequence = -1
	stepped_results.clear()
	_selection_box.hide()
	_camera.zoom = Vector2.ONE
	_view.set_zoom(1.0)
	_reset_camera()
	var empty: Array[Vector2i] = []
	_view.set_build_preview(empty, false)
	_refresh()
	driver.start()
