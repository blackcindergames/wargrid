extends Node

const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PerfOverlay = preload("res://scripts/presentation/perf_overlay.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Orders = preload("res://scripts/match/orders.gd")
const Hud = preload("res://scripts/match/hud.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const LAUNCHER_SCENE: String = "res://scenes/launcher.tscn"
const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
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
const AUTO_FRAMES: int = 120
const AUTO_SKIP_FRAMES: int = 60
static var factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH
static var map_path: String = Skirmish.MAP_PATH
static var starts: Array[int] = []
static var match_seed: int = 0
var driver: RefCounted
var orders: RefCounted = Orders.new(self)
var hud: Hud
var local_player: int = 1
var stepped_results: Array = []
var _last_result_tick: int = -1
var _last_result_sequence: int = -1
var shown_state: Dictionary = {}
var _shown_note: String = ""
var _camera_bounds: Rect2
@onready var _view: Node2D = $WorldView
@onready var _camera: Camera2D = $Camera2D
var _perf: Label
var _clock := PresentationClock.new()
var _pause: Control
var _result_panel: Control
var change_scene: Callable = _change_scene
var quit: Callable
@onready var _selection_box: ReferenceRect = $HUD/SelectionBox
var _sound: SoundPlayer = null
var _auto_samples := PackedFloat32Array()
var _auto_pending: bool = false
var _auto_frame: int = 0
var _auto_tick_usec: int = 0
var _visuals := VisualDirector.new()
var _playtest: PlaytestOverlay
var _leaving: bool = false

func setup(transport: RefCounted, lockstep: RefCounted, seat: int, faction: String = Skirmish.default_faction()) -> void:
	driver = OnlineDriver.new(transport, lockstep, faction, seat)
	local_player = seat

func _ready() -> void:
	if driver == null: driver = OfflineDriver.new(local_player)
	_result_panel = ResultPanel.new()
	_result_panel.play_again_pressed.connect(_play_again)
	_result_panel.change_setup_pressed.connect(_leave)
	$HUD.add_child(_result_panel)
	hud = Hud.new()
	$HUD.add_child(hud)
	$HUD.move_child(hud, $HUD/Status.get_index() + 1)
	hud.setup($HUD/Economy, $HUD/Status)
	# Above the result card's dim and click catcher, so Menu stays live after the match, as the Playtest chip does.
	var menu_chip: Control = hud.get_node("MenuChip")
	menu_chip.reparent($HUD, false)
	$HUD.move_child(menu_chip, _result_panel.get_index() + 1)
	hud.menu_chosen.connect(orders._menu_choose.bind(false))
	hud.entry_cancelled.connect(orders._cancel_entry)
	hud.produce_pressed.connect(orders._produce_selected)
	hud.cancel_build_pressed.connect(orders._cancel_build)
	hud.attack_move_pressed.connect(orders.arm_attack_move)
	hud.stop_pressed.connect(orders.stop_selected)
	hud.unload_pressed.connect(orders._unload_selected)
	_perf = PerfOverlay.new()
	$HUD.add_child(_perf)
	_pause = PauseMenu.new()
	_pause.confirm_leave = driver.confirm_leave()
	_pause.resume_requested.connect(_pause.close)
	hud.menu_pressed.connect(_pause.open)
	_pause.leave_requested.connect(_leave)
	if not quit.is_valid(): quit = get_tree().quit
	_pause.quit_requested.connect(func() -> void:
		close_match(true)
		quit.call())
	_pause.quality_changed.connect(_view.set_quality)
	_pause.neon_changed.connect(_view.set_bright_owners)
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
	if driver.has_method("net_line"): _perf.extra = driver.net_line
	driver.start()

func _enter_tree() -> void:
	ViewCaps.apply(get_tree().root)

func _exit_tree() -> void:
	orders._set_attack_move(false)
	driver.detach()
	ViewCaps.release(get_tree().root)

func _add_playtest() -> void:
	_playtest = PlaytestOverlay.new()
	_playtest.setup(FocusCards.card(FocusCards.shown(), FocusCards.load_cards()), playtest_context, playtest_match, playtest_header)
	$HUD.add_child(_playtest)
	$HUD.move_child(_playtest, _pause.get_index())
	_pause.opened.connect(_playtest.observe_menu)
	_pause.playtest_changed.connect(_playtest.set_active)
	_playtest.set_active(PlaytestSettings.enabled())
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
	var size: Array = driver.current().view.map.size
	_camera_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for corner: Variant in [Vector2(size[0], 0), Vector2(0, size[1]), Vector2(size[0], size[1])]:
		_camera_bounds = _camera_bounds.expand(Iso.world_to_plane(corner))
	var start: Vector2i = driver.first_note.starts.get(local_player, Vector2i(-1, -1))
	var focus := Vector2(start) + Vector2(0.5, 0.5) if start.x >= 0 else Vector2(size[0], size[1]) / 2.0
	_camera.position = Iso.world_to_plane(focus)

func _create_world() -> void:
	driver.create(map_path, starts, factions, match_seed)

func playtest_context() -> Dictionary:
	var camera: Vector2 = Iso.plane_to_world(_camera.position)
	return {"tick": shown_state.tick, "camera": [camera.x, camera.y], "selected": orders.view_selection(), "over": driver.over(), "menu": _pause.visible}

func playtest_match() -> Dictionary:
	var played: Dictionary = driver.match_log()
	return _match_record(played.mode, played.factions, played.commands).merged({"end": played.get("end", "")})

func playtest_header() -> Dictionary:
	var played: Dictionary = driver.match_header()
	return _header(played.mode, played.factions)

func _header(mode: String, match_factions: Array) -> Dictionary:
	return {"mode": mode, "map": _map_id(), "seed": match_seed, "factions": match_factions, "seat": local_player, "build": PlaytestSettings.build_id()}

func _map_id() -> String:
	return map_path.get_file().get_basename()

func _match_record(mode: String, match_factions: Array, lines: PackedStringArray) -> Dictionary:
	var record: Dictionary = driver.record()
	return _header(mode, match_factions).merged({"end_tick": record.tick, "end_digest": record.digest, "result": _result_text(record.match), "commands": lines})

func _take_answers() -> void:
	for answer: Dictionary in driver.take_answers():
		if answer.ok: _playtest.observe_command(answer.command)
		else:
			_ensure_sound()
			_sound.rejected(answer.error)
			hud.note = "Rejected: " + answer.error
			hud.refusal = answer.error
		orders.answered(answer)

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
	change_scene.call(LAUNCHER_SCENE)

func close_match(file_sitting: bool) -> void:
	driver.stop()
	if file_sitting: _playtest.close_out()
	else: _playtest.keep_match()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _playtest.web: close_match(true) # web files at the next launcher open instead

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.physical_keycode == KEY_F3: return
	if event.is_action_pressed("deselect"):
		if _pause.visible: _pause.back()
		elif not _escape_pending(): _pause.open()
		else: return
	elif not _pause.visible:
		if _result_panel.takes_enter(event) and not _typing() and not _playtest.holds_match(): _play_again()
		else: return
	elif event.is_action_pressed("ui_accept"): return
	get_viewport().set_input_as_handled()

func esc_opens_menu() -> bool:
	return not _escape_pending() and not _playtest.holds_match() and not _typing() and not _pause.visible

# Focus and the note form change without a new view, so the chip follows every frame.
func _show_esc_chip() -> void:
	hud.set_esc_chip(esc_opens_menu())

# The pause menu and the note form open without a new view, so this runs every frame too.
func _drop_stale_attack_move() -> void:
	if orders._attack_move_mode and (not orders.takes_orders() or _pause.visible or orders.selected_ids.is_empty()): orders._set_attack_move(false)

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
	_drop_stale_attack_move()
	var drained_at: int = Time.get_ticks_usec()
	if _drain_notes() and _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - drained_at
	var presented_at: int = Time.get_ticks_usec()
	if _present_if_due() and _auto_pending: _auto_tick_usec += Time.get_ticks_usec() - presented_at
	if not _typing(): pan_camera(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"), delta)
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
	if orders.busy():
		return
	_camera.position += direction.normalized() * 400.0 * delta / _camera.zoom.x
	_camera.position = _camera.position.clamp(_camera_bounds.position, _camera_bounds.end)

func change_zoom(direction: int) -> void:
	if orders.busy():
		return
	var index: int = ZOOMS.find(_camera.zoom.x)
	index = clampi(index + signi(direction), 0, ZOOMS.size() - 1)
	_camera.zoom = Vector2.ONE * ZOOMS[index]
	_view.set_zoom(ZOOMS[index])

func _unhandled_input(event: InputEvent) -> void:
	# A field passes on shortcuts it does not use (Cmd+S, Ctrl+1); orders ignore modifiers, so they would fire.
	if event is InputEventKey and _typing(): return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _typing() and not _playtest.holds_match(): get_viewport().gui_release_focus()
	orders.handle(event)

func _refresh() -> void:
	_show(driver.current().view)

func _note() -> String:
	# The rematch line changes without a tick, so a finished match still redraws its panel.
	return hud.note + driver.notice() + driver.rematch_line()

func shown_over() -> bool:
	return shown_state.get("match") != null and shown_state.match.status in ["won", "draw"]

func _reshow() -> void:
	_show(shown_state, false)

# Only a new view consumes step results and sound; a repaint on input must leave them for the next refresh.
func _show(state: Dictionary, fresh: bool = true) -> void:
	shown_state = state
	# The forecast card must never show over a result card or an ended online match.
	if (shown_over() or driver.over()) and not orders._placement_kind.is_empty(): orders._clear_placement()
	_shown_note = _note()
	_perf.set_counts(state.units.size(), state.get("buildings", []).size(), state.tick)
	_perf.split_share = _clock.split_share()
	var zone: int = Profiler.begin()
	orders.prune(state)
	_drop_stale_attack_move()
	orders.show_preview(driver.preview_answer())
	Profiler.end(&"refresh.selection", zone)
	_view.set_view(state, orders.view_selection())
	zone = Profiler.begin()
	_ensure_sound()
	_take_results(state)
	hud.update_hud(state, _hud_selection(state), local_player, local_player)
	_place_floor()
	orders.menu = hud.menu_kinds
	_view.set_inspected(orders.inspected_id)
	if frozen(): _show_freeze()
	else: _show_result(state)
	if fresh: _sound.update(state)
	Profiler.end(&"refresh.hud", zone)
	if fresh: stepped_results.clear()

func _take_results(state: Dictionary) -> void:
	for result: Dictionary in stepped_results + state.command_results:
		if result.player == local_player and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			if not result.ok:
				hud.note = result.error
				hud.refusal = result.error
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence

func _hud_selection(state: Dictionary) -> Dictionary:
	var building: Dictionary = _building(state, orders.selected_building_id)
	var production: String = _production_kind(building, state) if not building.is_empty() else ""
	return {"ids": orders.selected_ids, "building_id": orders.selected_building_id, "inspected_id": orders.inspected_id, "placement_kind": orders._placement_kind, "resume_id": _view.resume_candidate(), "notice": "" if shown_over() or frozen() else driver.notice(), "production_kind": production, "bright_owners": _view.bright_owners(), "over": not _result(state).is_empty(), "esc_opens_menu": esc_opens_menu(), "attack_move": orders._attack_move_mode}

func _result(state: Dictionary) -> String:
	var result: String = "" if state.match == null else _result_text(state.match)
	return "Victory" if result.is_empty() and driver.opponent_left() else result

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
	var stats: Array[Dictionary] = driver.match_stats()
	for player: Dictionary in state.players:
		var row: Dictionary = stats.filter(func(entry: Dictionary) -> bool: return entry.player == player.id)[0]
		var you: bool = player.id == local_player
		var faction: String = Registry.faction(player.get("faction", Registry.Factions.DEFAULT_FACTION)).display_name
		rows.append({"name": "P%d %s%s" % [player.id, faction, " (you)" if you else ""], "you": you, "built": row.units_built, "units_lost": row.units_lost, "buildings_lost": row.buildings_lost})
	return rows

func _result_text(match_state: Variant) -> String:
	return ResultPanel.result_text(match_state, _local_team())

func _local_team() -> int:
	for player: Dictionary in shown_state.players:
		if player.id == local_player: return player.team
	return 0

func _show_hint(payload: Dictionary) -> void:
	var point: Variant = orders._hint_point(payload)
	if point != null: _view.add_hint(point, shown_state.tick)

func _submit(payload: Dictionary) -> void:
	_show_hint(payload)
	driver.submit(payload)
	hud.note = ""
	hud.refusal = ""
	_reshow()
	_sound.order(payload)

func refuse(error: String) -> void:
	_ensure_sound()
	_sound.rejected(error)
	hud.note = "Rejected: " + error
	hud.refusal = error
	_reshow()

func _ensure_sound() -> void:
	if _sound != null: return
	_sound = SoundPlayer.new(local_player)
	add_child(_sound)

func _collect_note(note: SimPump.Note) -> void:
	_ensure_sound()
	_sound.collect_step(note.tick, note.events, note.results)
	_visuals.collect_step(note.tick, note.events, note.results)

func _production_kind(building: Dictionary, state: Dictionary) -> String:
	var kind: String = Skirmish.unit_for(_local_state(state).get("faction", Skirmish.default_faction()), building.kind)
	return kind if not kind.is_empty() else Definitions.building(building.kind).produces

func _local_state(state: Dictionary) -> Dictionary:
	return HudModel.player(state, local_player)

func _building(state: Dictionary, id: int) -> Dictionary:
	return HudModel.building(state, id)

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
	starts = MatchSettings.starts(map_path.get_file().get_basename(), match_seed_value)
	_restart_world()

func _restart_world() -> void:
	_playtest.begin_match()
	_create_world()
	_clock = PresentationClock.new()
	_sound.director.reset()
	_sound._unit_voice.stop()
	_visuals.reset()
	orders.reset()
	hud.reset()
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
