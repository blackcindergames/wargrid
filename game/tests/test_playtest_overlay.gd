@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const SkirmishRules = preload("res://scripts/simulation/skirmish.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const SessionForm = preload("res://scripts/playtest/session_form.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MarkerCapture = preload("res://scripts/playtest/marker_capture.gd")
const PlaytestOverlay = preload("res://scripts/playtest/playtest_overlay.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const LAUNCHER: String = "res://scenes/launcher.tscn"
const CARD_ECONOMY := "p1-frc-economy"
const CARD_TUNNELS := "p1-frc-tunnels-online"
var scratch: String = "user://test-overlay-settings-%d.cfg" % OS.get_process_id()
var sessions: String = "user://test-overlay-playtests-%d" % OS.get_process_id()
var saved_dir: String = ""

class FakeTransport extends RefCounted:
	var patient: bool = false
	var polls: int = 0
	var close_calls: int = 0
	func poll() -> PackedStringArray:
		polls += 1
		return PackedStringArray()
	func send_text(_text: String) -> void: pass
	func closed() -> bool: return close_calls > 0
	func silent(_now: int) -> bool: return false
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

class Camera extends RefCounted:
	var seen_dialog_visible: Array[bool] = []
	var image: Image = null
	var overlay: Control = null
	func shot() -> Image:
		seen_dialog_visible.append(overlay.get_node("MarkerDialog").visible)
		return image

func cases() -> Array[Callable]:
	return [test_marker_pauses_offline, test_marker_does_not_pause_online, test_capture_before_dialog, test_note_typing_is_not_a_hotkey, test_marker_ignored_when_menu_or_over, test_checklist_triggers, test_helper_off_changes_nothing, test_overlay_layout, test_leave_flow, test_match_end_opens_review_once, test_back_to_menu_from_result_panel, test_leave_after_closed_sitting, test_two_match_session_file, test_web_save_downloads, test_desktop_write_error_keeps_session, test_window_close_files_typed_text, test_quit_with_write_error_still_quits, test_each_exit_files_filled_only, test_failed_save_says_not_saved, test_window_close_keeps_marker_draft, test_form_layout, test_resume_uses_stored_card, test_restart_keeps_markers, test_scale_legend, test_sb2_checklist_waits_for_answer, test_sb2_review_form_and_pending_answer, test_open_panel_never_holds, test_match_end_shows_panel_without_focus, test_marker_list_this_and_last, test_typing_is_text_not_keys, test_field_saves_on_submit_and_exit, test_world_click_releases_field, test_escape_in_field, test_toggles_take_no_focus, test_header_has_no_digest, test_modifier_keys_stay_in_field, test_arrows_do_not_pan_while_typing, test_world_click_keeps_dialog_text, test_panel_shrinks_on_resize, test_focused_text_survives_rebuilds, test_enter_in_field_then_play_again, test_empty_marker_states, test_match_end_keeps_field_focus, test_new_scene_starts_new_entry, test_resumed_sitting_lists_markers, test_match_end_keeps_marker_draft, test_mute_key_stays_in_field, test_match_end_scrolls_to_markers]

func _begin(helper_on: bool = true, card: String = CARD_ECONOMY) -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	PlaytestSettings.save_enabled(helper_on)
	saved_dir = PlaytestSession.dir
	PlaytestSession.dir = sessions
	PlaytestSession.current = null
	PlaytestSession.last_filed = ""
	FocusCards.chosen = card
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	WargridTestRunner.remove_dir(sessions)
	PlaytestSession.dir = saved_dir
	PlaytestSession.current = null
	PlaytestSession.last_filed = ""
	AudioSettings.path = saved
	FocusCards.chosen = ""

func _scene(runner, packed = Skirmish, parent = null):
	var main = packed.instantiate()
	(parent if parent != null else runner.root).add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return main

func _online(runner):
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var main = Skirmish.instantiate()
	main.setup(transport, Lockstep.new(1, seats), 1)
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return {"main": main, "transport": transport}

func _camera(main, image: Image = Image.create(1280, 720, false, Image.FORMAT_RGB8)) -> Camera:
	var camera := Camera.new()
	camera.overlay = main.get_node("HUD/Playtest")
	camera.image = image
	camera.overlay.image_source = camera.shot
	main.set_meta("camera", camera) # a Callable does not keep its RefCounted alive
	return camera

func _key(runner, code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	runner.root.push_input(event)

func _click(main, name: String) -> void:
	for button: Button in main.get_node("HUD/PauseMenu").find_children("*", "Button", true, false):
		if button.text == name and button.is_visible_in_tree():
			button.pressed.emit()
			return
	assert(false, "no visible button " + name)

func _own_unit(main) -> int:
	for unit: Dictionary in main.driver.pump.live().snapshot().entities:
		if unit.owner == main.local_player: return unit.id
	return -1

func _dialog(main) -> Control:
	return main.get_node("HUD/Playtest/MarkerDialog")

func test_marker_pauses_offline(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	BaseScene.tick(main)
	var unit: int = _own_unit(main)
	main.orders.selected_ids.assign([unit])
	var tick: int = main.driver.pump.live().tick()
	var camera := _camera(main)
	_key(runner, KEY_N)
	runner.check(_dialog(main).visible and main.menu_open(), "PO1 N opens the note and the match counts it as an open menu")
	for i in 5: BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() == tick, "PO1 tick frozen while the note is open")
	main.get_node("HUD/Playtest").save_marker("good", "nice")
	runner.check(not _dialog(main).visible and not main.menu_open(), "PO1 saving closes the note")
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() == tick + 1, "PO1 tick advances after saving")
	var session: PlaytestSession = PlaytestSession.current
	var markers: Array = session.data.matches[session.marker_match()].markers
	runner.check(markers.size() == 1 and markers[0].kind == "good" and markers[0].text == "nice" and markers[0].tick == tick and markers[0].selected == [unit] and not markers[0].jpg.is_empty(), "PO1 marker holds kind, text, tick, selection and a screenshot, got %s" % [markers.map(func(m: Dictionary) -> Dictionary: return m.merged({"jpg": m.jpg.length()}, true))])
	runner.check(camera.seen_dialog_visible.size() == 1, "PO1 one capture per note")
	main.free()
	_end(saved)
	return true

func test_marker_does_not_pause_online(runner) -> bool:
	var saved: String = _begin()
	var online: Dictionary = await _online(runner)
	var main = online.main
	_camera(main)
	BaseScene.tick(main)
	_key(runner, KEY_N)
	runner.check(_dialog(main).visible and main.menu_open(), "PO2 online N opens the note")
	var polls: int = online.transport.polls
	for i in 4: BaseScene.tick(main)
	runner.check(online.transport.polls == polls + 4, "PO2 online still polls the transport while the note is open, got %d" % (online.transport.polls - polls))
	main.free()
	_end(saved)
	return true

func test_capture_before_dialog(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var camera := _camera(main)
	main.get_node("HUD/Playtest").open_marker()
	runner.check(camera.seen_dialog_visible == [false] and _dialog(main).visible, "PO3 the screenshot is taken before the note is shown, saw %s" % [camera.seen_dialog_visible])
	main.get_node("HUD/Playtest").cancel_marker()
	camera.image = null
	main.get_node("HUD/Playtest").open_marker()
	main.get_node("HUD/Playtest").save_marker("bad", "no shot")
	var session: PlaytestSession = PlaytestSession.current
	var markers: Array = session.data.matches[session.marker_match()].markers
	runner.check(markers.size() == 1 and markers[0].jpg == "" and markers[0].kind == "bad", "PO3 a failed capture still saves the marker with an empty jpg")
	main.free()
	_end(saved)
	return true

func test_note_typing_is_not_a_hotkey(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	main.orders.selected_ids.assign([_own_unit(main)])
	var commands: int = main.playtest_match().commands.size()
	_key(runner, KEY_N)
	var text: LineEdit = main.get_node("HUD/Playtest/MarkerDialog").find_child("Text", true, false)
	runner.check(text.has_focus(), "PO4 the note's text field has focus")
	_key(runner, KEY_A, 97)
	_key(runner, KEY_S, 115)
	_key(runner, KEY_1, 49)
	_key(runner, KEY_N, 110)
	runner.check(text.text == "as1n" and not main.orders._attack_move_mode, "PO4 letters go into the text, not attack-move, got '%s'" % text.text)
	runner.check(main.playtest_match().commands.size() == commands and main.driver.queued().is_empty() and _dialog(main).visible, "PO4 typing issues no command and keeps the note open")
	main.orders.selected_ids.clear()
	_key(runner, KEY_ESCAPE)
	runner.check(not _dialog(main).visible and not main.get_node("HUD/PauseMenu").visible, "PO4 Esc closes the note and leaves the pause menu closed")
	main.free()
	_end(saved)
	return true

func test_marker_ignored_when_menu_or_over(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	_key(runner, KEY_ESCAPE)
	runner.check(main.get_node("HUD/PauseMenu").visible, "PO5 fixture: pause menu open")
	_key(runner, KEY_N)
	runner.check(not _dialog(main).visible, "PO5 N with the pause menu open opens nothing")
	_key(runner, KEY_ESCAPE)
	for building: Dictionary in main.driver.pump.live().snapshot().buildings: main.driver.pump.live().remove_object(building.id)
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().match_over(), "PO5 fixture: match over")
	_key(runner, KEY_N)
	runner.check(not _dialog(main).visible and PlaytestSession.current.data.matches.is_empty(), "PO5 N after the match ended opens nothing")
	main.free()
	_end(saved)
	return true

func test_checklist_triggers(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	var list: Control = overlay.get_node("Checklist")
	runner.check(list.visible and list.find_child("collect", true, false) is CheckBox, "PO6 checklist visible at match start with one box per item")
	var sim = SkirmishRules.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.adopt(sim)
	var pile: Dictionary = sim.snapshot().sources[0]
	var laborer: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder")
	main._submit({"type": "gather", "entity_ids": [999999], "source_id": pile.id})
	BaseScene.tick(main)
	runner.check(not main.hud.note.is_empty() and not overlay.checked("collect"), "PO6 a rejected gather ticks nothing, error '%s'" % main.hud.note)
	main._submit({"type": "gather", "entity_ids": [laborer], "source_id": pile.id})
	BaseScene.tick(main)
	runner.check(main.hud.note.is_empty() and overlay.checked("collect") and list.find_child("collect", true, false).button_pressed, "PO6 an accepted gather ticks collect, error '%s'" % main.hud.note)
	overlay.observe_command({"type": "build", "building_kind": "frc_supply_center"})
	runner.check(overlay.checked("cache") and not overlay.checked("workers"), "PO6 build:frc_supply_center ticks cache only")
	list.find_child("income", true, false).button_pressed = true
	runner.check(overlay.checked("income") and PlaytestSession.current.data.checklist.income == true, "PO6 a click ticks income and saves it")
	var saved_ticks: int = PlaytestSession.current.data.checklist.size()
	overlay.observe_command({"type": "gather"})
	runner.check(PlaytestSession.current.data.checklist.size() == saved_ticks, "PO6 an already ticked item is not written again")
	_key(runner, KEY_QUOTELEFT)
	runner.check(not list.visible, "PO6 ` hides the checklist")
	_key(runner, KEY_QUOTELEFT)
	runner.check(list.visible, "PO6 ` shows it again")
	main.free()
	PlaytestSession.current.discard() # a stored sitting keeps its own card
	FocusCards.chosen = CARD_TUNNELS
	main = await _scene(runner)
	overlay = main.get_node("HUD/Playtest")
	runner.check(not overlay.checked("esc"), "PO6 fixture: esc item open")
	_key(runner, KEY_ESCAPE)
	runner.check(overlay.checked("esc"), "PO6 opening the Esc menu ticks the esc_menu item")
	main.free()
	_end(saved)
	return true

func test_helper_off_changes_nothing(runner) -> bool:
	var saved: String = _begin(false)
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_key(runner, KEY_QUOTELEFT)
	_key(runner, KEY_N)
	runner.check(not overlay.get_node("Checklist").visible and not _dialog(main).visible and not overlay.is_active(), "PO7 off: ` and N do nothing")
	runner.check(main.menu_open() == main.get_node("HUD/PauseMenu").visible and PlaytestSession.current == null, "PO7 off: menu_open is the pause menu and no session exists")
	_key(runner, KEY_ESCAPE)
	runner.check(main.menu_open(), "PO7 off: Esc still opens the pause menu")
	_key(runner, KEY_ESCAPE)
	var sim = SkirmishRules.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.adopt(sim)
	var pile: Dictionary = sim.snapshot().sources[0]
	var laborer: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder")
	main._submit({"type": "gather", "entity_ids": [laborer], "source_id": pile.id})
	runner.check(main.hud.note.is_empty() and not overlay.get_node("Checklist").find_child("collect", true, false).button_pressed and PlaytestSession.current == null, "PO7 off: an accepted gather ticks nothing and opens no session, error '%s'" % main.hud.note)
	_key(runner, KEY_ESCAPE)
	_click(main, "Playtest helper: Off")
	runner.check(overlay.is_active() and overlay.get_node("Checklist").visible and PlaytestSettings.enabled(), "PO7 the pause menu switch turns the helper on mid-match and stores it")
	_click(main, "Playtest helper: On")
	runner.check(not overlay.is_active() and not overlay.get_node("Checklist").visible and not PlaytestSettings.enabled(), "PO7 and off again")
	main.free()
	_store_sitting("0.0.1-dev+old", true)
	var before: String = _current_text()
	var downloads: Array = []
	main = await _scene(runner)
	main.quit = func() -> void: pass
	main.get_node("HUD/Playtest").web = true
	main.get_node("HUD/Playtest").download = func(_buffer: PackedByteArray, file_name: String, _mime: String) -> void: downloads.append(file_name)
	main.get_node("HUD/PauseMenu").quit_requested.emit()
	_close_window(main)
	main.free()
	for web: bool in [false, true]:
		var launcher = await _open_launcher(runner, web, downloads)
		launcher.get_node("Sidebar/Nav/Quit").pressed.emit()
		_close_window(launcher)
		launcher.free()
	runner.check(_current_text() == before and Array(DirAccess.get_files_at(sessions)) == ["current.json"] and downloads.is_empty() and PlaytestSession.last_filed.is_empty(), "PO7 off: pause Quit, window close, launcher open and launcher Quit leave a stored sitting alone, got %s, %s" % [DirAccess.get_files_at(sessions), downloads])
	_end(saved)
	return true

func test_overlay_layout(runner) -> bool:
	var saved: String = _begin()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var main = await _scene(runner, Skirmish, port)
		_camera(main)
		main.orders.selected_ids.assign([_own_unit(main)])
		main._refresh()
		main.get_node("HUD/Playtest").open_marker()
		await runner.process_frame
		await runner.process_frame
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "PO8 the viewport really is %s, got %s" % [size, main.get_viewport().get_visible_rect().size])
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var panels: Array[Rect2] = []
		for path in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog"]:
			var panel: Control = main.get_node(path)
			runner.check(panel.visible and screen.encloses(panel.get_global_rect()), "PO8 %s inside %s, rect %s" % [path, size, panel.get_global_rect()])
			panels.append(panel.get_global_rect())
			for other in ["HUD/Status", "HUD/Economy"]:
				var control: Control = main.get_node(other)
				runner.check(not panel.get_global_rect().intersects(Rect2(control.global_position, control.get_combined_minimum_size())), "PO8 %s clear of %s at %s" % [path, other, size])
		runner.check(not panels[0].intersects(panels[1]), "PO8 checklist and note apart at %s" % size)
		port.free()
	_end(saved)
	return true

func _form(main) -> Control:
	return main.get_node_or_null("HUD/Playtest/SessionForm")

func _form_shown(main) -> bool:
	var form: Control = _form(main)
	return form != null and form.visible

func _no_form(main) -> bool:
	return _form(main) == null

func _panel(main) -> Control:
	return main.get_node("HUD/Playtest/Checklist")

func _field(main, field_name: String) -> LineEdit:
	return _panel(main).find_child(field_name, true, false) as LineEdit

func _markers_title(main) -> String:
	var label: Label = _panel(main).find_child("MarkersTitle", true, false)
	return label.text if label != null else ""

func _current_text() -> String:
	var path: String = sessions.path_join(PlaytestSession.CURRENT)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _stored_answer(question_id: String) -> String:
	var stored: Variant = JSON.parse_string(_current_text())
	return str(stored.answers.get(question_id, {}).get("text", "")) if stored is Dictionary else ""

func _pending(main, type: String) -> int:
	return (main.driver.pump.live().snapshot().pending_commands + main.driver.queued()).filter(func(command: Dictionary) -> bool: return command.type == type).size()

func _end_offline(main) -> void:
	var state: Dictionary = main.driver.pump.live().snapshot()
	for object: Dictionary in state.entities + state.buildings:
		if object.owner == 2: main.driver.pump.live().remove_object(object.id)
	BaseScene.tick(main)
	main.get_node("HUD/Playtest")._process(0.0)

func _focus_in_panel(main) -> bool:
	var focus: Control = main.get_viewport().gui_get_focus_owner()
	return focus != null and _panel(main).is_ancestor_of(focus)

func _questions() -> Array:
	return FocusCards.card(CARD_ECONOMY, FocusCards.load_cards()).questions

func _press(main, button_name: String) -> bool:
	var form: Control = main.get_node("HUD/Playtest")
	var button: Button = form.find_child(button_name, true, false) if form != null else null
	if button == null or not button.is_visible_in_tree(): return false
	if button.toggle_mode: button.button_pressed = true
	else: button.pressed.emit()
	return true

func _form_text(main) -> String:
	var form: Control = _form(main)
	if form == null: return ""
	return "\n".join(form.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text))

func _scenes(main) -> Array[String]:
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	return scenes

func _run(main, steps: int) -> void:
	for i in steps: BaseScene.tick(main)

func _move_own_unit(main) -> void:
	main.orders.selected_ids.assign([_own_unit(main)])
	for unit: Dictionary in main.driver.pump.live().snapshot().entities:
		if unit.id == main.orders.selected_ids[0]:
			main.orders._move(Vector2(unit.position[0] + 4.0, unit.position[1]))
			return

func _mark(overlay, kind: String, text: String) -> void:
	overlay.open_marker()
	overlay.save_marker(kind, text)

func _saved_session() -> Dictionary:
	for file in DirAccess.get_files_at(sessions):
		if file.begins_with("session-"): return JSON.parse_string(FileAccess.get_file_as_string(sessions.path_join(file)))
	return {}

func _rate_all(runner, main, score: int) -> void:
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	for question: Dictionary in card.questions:
		runner.check(_press(main, "%s_%d" % [question.id, score]), "PO10 rating button %s_%d is shown" % [question.id, score])

func test_leave_flow(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var scenes := _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER] and _no_form(main), "PO9 leaving with the helper on changes scene at once and shows no form, scenes %s" % [scenes])
	runner.check(PlaytestSession.current != null and PlaytestSession.current.data.matches.size() == 1, "PO9 the left match lands in the open sitting")
	main.free()
	_end(saved)
	saved = _begin(false)
	main = await _scene(runner)
	scenes = _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER] and _no_form(main) and PlaytestSession.current == null, "PO9 helper off: leaving changes scene at once and no form shows, got %s" % [scenes])
	main.free()
	_end(saved)
	saved = _begin()
	var online: Dictionary = await _online(runner)
	main = online.main
	scenes = _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(online.transport.close_calls == 0 and scenes.is_empty() and _no_form(main), "PO9 online: asking to leave does nothing yet")
	_click(main, "Leave")
	runner.check(online.transport.close_calls == 1 and scenes == [LAUNCHER] and _no_form(main), "PO9 online leave closes the transport once, changes scene at once and shows no form, closed %d, scenes %s" % [online.transport.close_calls, scenes])
	runner.check(PlaytestSession.current != null and PlaytestSession.current.data.matches.size() == 1, "PO9 online the left match lands in the open sitting")
	main.free()
	_end(saved)
	return true

func test_match_end_opens_review_once(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "bad", "before the end")
	var enemies: Dictionary = {}
	var state: Dictionary = main.driver.pump.live().snapshot()
	for object: Dictionary in state.entities + state.buildings:
		if object.owner == 2: enemies[object.id] = true
	for id: int in enemies: main.driver.pump.live().remove_object(id)
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().match_over() and PlaytestSession.current.data.matches[0].get("unfinished", false), "PO11 fixture: match over, still unfinished before the overlay polls")
	overlay._process(0.0)
	var comment: LineEdit = _field(main, "Comment_0_0")
	var matches: Array = PlaytestSession.current.data.matches
	runner.check(_panel(main).visible and matches.size() == 1 and not matches[0].has("unfinished") and comment != null, "PO11 one poll files the match and lists the marker's comment field in the panel")
	runner.check(main.get_node("HUD/Playtest").get_index() > main.get_node("HUD/ResultPanel").get_index(), "PO11 the panel draws above the result panel")
	if comment != null:
		comment.text = "looks fine"
		comment.text_submitted.emit(comment.text)
		runner.check(PlaytestSession.current.data.matches[0].markers[0].comment == "looks fine", "PO11 a submitted comment saves on the marker, stored '%s'" % PlaytestSession.current.data.matches[0].markers[0].comment)
	overlay._process(0.0)
	runner.check(PlaytestSession.current.data.matches.size() == 1, "PO11 a second poll adds no second match")
	runner.check(not overlay.holds_match(), "PO11 the panel at match end holds nothing")
	var scenes := _scenes(main)
	main.get_node("HUD/PauseMenu").leave_requested.emit()
	runner.check(scenes == [LAUNCHER] and _no_form(main) and PlaytestSession.current != null and PlaytestSession.current.data.matches.size() == 1, "PO11 leaving after the match end changes scene at once, adds no second match and keeps the sitting, scenes %s" % [scenes])
	main.free()
	_end(saved)
	return true

func test_back_to_menu_from_result_panel(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	_end_offline(main)
	main._refresh()
	var panel: Control = main.get_node("HUD/ResultPanel")
	var scenes := _scenes(main)
	runner.check(panel.visible and _no_form(main), "PO11b fixture: result panel up, no form")
	(panel.get_node("Center/Card/Box/Buttons/ChangeSetup") as Button).pressed.emit()
	runner.check(scenes == [LAUNCHER] and _no_form(main) and PlaytestSession.current.data.matches.size() == 1, "PO11b Back to menu with a focus card changes scene at once and the match is filed, scenes %s" % [scenes])
	main.free()
	_end(saved)
	return true

func test_leave_after_closed_sitting(runner) -> bool:
	for filled: bool in [true, false]:
		var saved: String = _begin()
		var main = await _scene(runner)
		var overlay = main.get_node("HUD/Playtest")
		_end_offline(main)
		if filled: _rate_all(runner, main, 3)
		PlaytestSession.close_sitting(false, overlay.download)
		var scenes := _scenes(main)
		main.get_node("HUD/PauseMenu").leave_requested.emit()
		var filed: Array = _saved_session().get("matches", [])
		runner.check(scenes == [LAUNCHER] and _no_form(main) and filed.size() == (1 if filled else 0) and _current_text().is_empty(), "PO11b leaving after a closed sitting (filled %s) reaches the launcher at once and files nothing again, scenes %s, filed %d" % [filled, scenes, filed.size()])
		main.free()
		_end(saved)
	return true

func test_two_match_session_file(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_move_own_unit(main)
	runner.check(main.hud.note.is_empty(), "PO12 fixture: the first move is accepted, '%s'" % main.hud.note)
	_run(main, 60)
	_mark(overlay, "good", "match one marker")
	var digests: Array[String] = [StateHash.digest(main.driver.pump.live().snapshot())]
	var commands: Array = [main.playtest_match().commands]
	overlay.end_match()
	runner.check(_panel(main).visible and not overlay.holds_match(), "PO12 ending match 1 shows the panel and holds nothing")
	main._restart()
	runner.check(_panel(main).visible, "PO12 a restart keeps the panel")
	_move_own_unit(main)
	runner.check(main.hud.note.is_empty(), "PO12 fixture: the second move is accepted, '%s'" % main.hud.note)
	_run(main, 45)
	_mark(overlay, "bad", "match two first")
	_run(main, 45)
	_mark(overlay, "confusing", "match two second")
	digests.append(StateHash.digest(main.driver.pump.live().snapshot()))
	commands.append(main.playtest_match().commands)
	main.orders.selected_ids.clear()
	overlay.end_match()
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	_rate_all(runner, main, 4)
	var first: LineEdit = _field(main, "Answer_" + card.questions[0].id)
	runner.check(first != null, "PO12 the first question has a text field in the panel")
	if first != null:
		first.text = "clear"
		first.text_submitted.emit(first.text)
	PlaytestSession.close_sitting(false, overlay.download)
	var file: Dictionary = _saved_session()
	var matches: Array = file.get("matches", [])
	runner.check(matches.size() == 2, "PO12 the file holds 2 matches, got %d" % matches.size())
	if matches.size() == 2:
		runner.check(matches[0].markers.size() == 1 and matches[1].markers.size() == 2, "PO12 markers 1 and 2 land in their own match, got %d and %d" % [matches[0].markers.size(), matches[1].markers.size()])
		runner.check(matches[0].markers[0].text == "match one marker" and matches[1].markers[0].text == "match two first", "PO12 marker texts stay with their match")
		runner.check(int(matches[0].end_tick) == 60 and int(matches[1].end_tick) == 90, "PO12 end ticks are 60 and 90, got %s and %s" % [matches[0].end_tick, matches[1].end_tick])
		runner.check(matches[1].markers.all(func(marker: Dictionary) -> bool: return int(marker.tick) <= 90), "PO12 match 2 marker ticks start from 0 again")
		runner.check(matches[0].end_digest == digests[0] and matches[1].end_digest == digests[1], "PO12 each match keeps its own end digest")
		runner.check(Array(matches[0].commands) == Array(commands[0]) and Array(matches[1].commands) == Array(commands[1]) and not matches[1].commands.is_empty(), "PO12 each match keeps its own command log")
	var answers: Dictionary = file.get("answers", {})
	runner.check(card.questions.all(func(question: Dictionary) -> bool: return answers.has(question.id) and int(answers[question.id].score) == 4), "PO12 every question holds score 4, got %s" % [answers])
	runner.check(answers.get(card.questions[0].id, {}).get("text", "") == "clear", "PO12 the first answer keeps its text")
	var out: String = OS.get_environment("WARGRID_SESSION_OUT")
	if not out.is_empty() and not file.is_empty():
		for name in DirAccess.get_files_at(sessions):
			if name.begins_with("session-"): DirAccess.copy_absolute(ProjectSettings.globalize_path(sessions.path_join(name)), out)
	main.free()
	_end(saved)
	return true

func _close_window(node) -> void:
	node.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

func _session_files() -> Array:
	return Array(DirAccess.get_files_at(sessions)).filter(func(file: String) -> bool: return file.begins_with("session-"))

func _store_sitting(build: String, filled: bool) -> void:
	PlaytestSession.current = null
	var session := PlaytestSession.resume_or_open(CARD_ECONOMY, build)
	if filled: session.set_answer(_questions()[0].id, 3, "stored")
	else: session.set_checked("collect", true, false)
	PlaytestSession.current = null

func _open_launcher(runner, web: bool = false, downloads: Array = []):
	var launcher = load(LAUNCHER).instantiate()
	launcher.web = web
	launcher.download = func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer.size(), file_name, mime])
	launcher.quit = func() -> void: pass
	runner.root.add_child(launcher)
	await runner.process_frame
	return launcher

func test_web_save_downloads(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.web = true
	var downloads: Array = []
	overlay.download = func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer.size(), file_name, mime])
	_mark(overlay, "good", "web")
	var before: String = _current_text()
	_close_window(main)
	runner.check(downloads.is_empty() and _current_text() == before and Array(DirAccess.get_files_at(sessions)) == ["current.json"], "PO13 a web window close in a match leaves current.json alone, got %s, %s" % [DirAccess.get_files_at(sessions), downloads])
	main.free()
	PlaytestSession.current = null
	var launcher = await _open_launcher(runner, true, downloads)
	runner.check(downloads.size() == 1 and str(downloads[0][1]).begins_with("session-") and _current_text().is_empty(), "PO13 the next web launcher open downloads it, got %s" % [downloads])
	launcher.free()
	_store_sitting(PlaytestSettings.build_id(), false)
	before = _current_text()
	launcher = await _open_launcher(runner, true, downloads)
	_close_window(launcher)
	runner.check(downloads.size() == 1 and _current_text() == before, "PO13 a web launcher window close leaves an open sitting alone")
	launcher.free()
	_end(saved)
	return true

func test_desktop_write_error_keeps_session(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.web = false
	_mark(overlay, "good", "keep me")
	_rate_all(runner, main, 5)
	var blocker: String = sessions.path_join(PlaytestSession.file_name(PlaytestSession.current.data.started))
	DirAccess.make_dir_recursive_absolute(blocker) # a directory in the file's place makes the open fail without an engine error
	_close_window(main)
	var stored: Variant = JSON.parse_string(_current_text())
	runner.check(stored is Dictionary and stored.matches.size() == 1 and stored.answers.size() > 0 and PlaytestSession.last_filed.is_empty(), "PO14 a failed write at window close keeps current.json with its match and answers")
	DirAccess.remove_absolute(blocker)
	_close_window(main)
	var filed: Array = _saved_session().get("matches", [])
	runner.check(filed.size() == 1 and not filed[0].has("unfinished") and _current_text().is_empty() and PlaytestSession.last_filed.ends_with(".json"), "PO14 the next close writes the finished match, last_filed %s" % PlaytestSession.last_filed)
	main.free()
	_end(saved)
	return true

func test_window_close_files_typed_text(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var id: String = _questions()[0].id
	var field: LineEdit = _field(main, "Answer_" + id)
	field.grab_focus()
	field.text = "typed only"
	runner.check(not PlaytestSession.current.filled() and _focus_in_panel(main), "NB9 fixture: the field has focus and nothing is filled yet")
	_close_window(main)
	var file: Dictionary = _saved_session()
	runner.check(str(file.get("answers", {}).get(id, {}).get("text", "")) == "typed only" and file.get("matches", []).size() == 1 and _current_text().is_empty(), "NB9 a window close files the focused field's text and the match, got %s" % [file.get("answers", {})])
	main.free()
	WargridTestRunner.remove_dir(sessions)
	_store_sitting(PlaytestSettings.build_id(), true)
	var launcher = await _open_launcher(runner)
	runner.check(_session_files().is_empty(), "NB9 fixture: opening the launcher files nothing")
	_close_window(launcher)
	runner.check(_session_files().size() == 1 and _current_text().is_empty(), "NB9 a launcher window close files the stored sitting, got %s" % [_session_files()])
	launcher.free()
	_end(saved)
	return true

func test_quit_with_write_error_still_quits(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	var quits: Array[int] = [0]
	var finished_first: Array[bool] = [false]
	main.quit = func() -> void:
		quits[0] += 1
		var on_disk: Variant = JSON.parse_string(_current_text())
		finished_first[0] = on_disk is Dictionary and on_disk.matches.size() == 1 and not on_disk.matches[0].has("unfinished") and on_disk.matches[0].has("end_digest")
	_mark(overlay, "good", "keep me")
	var blocker: String = sessions.path_join(PlaytestSession.file_name(PlaytestSession.current.data.started))
	DirAccess.make_dir_recursive_absolute(blocker)
	main.get_node("HUD/PauseMenu").quit_requested.emit()
	runner.check(quits[0] == 1, "NB10 pause Quit still quits after a failed write, got %d" % quits[0])
	runner.check(finished_first[0], "NB10 the match is stored as finished before quit runs")
	var stored: Variant = JSON.parse_string(_current_text())
	runner.check(stored is Dictionary and stored.matches.size() == 1 and stored.matches[0].markers.size() == 1 and _session_files().is_empty(), "NB10 current.json keeps the match and its marker")
	PlaytestSession.current = null
	var resumed := PlaytestSession.resume_or_open(CARD_ECONOMY, PlaytestSettings.build_id())
	runner.check(resumed.data.matches.size() == 1 and resumed.data.matches[0].markers[0].text == "keep me", "NB10 the next start resumes it")
	DirAccess.remove_absolute(blocker)
	main.free()
	_end(saved)
	return true

func test_each_exit_files_filled_only(runner) -> bool:
	for exit_name: String in ["pause quit", "launcher quit", "window close"]:
		for filled: bool in [true, false]:
			var saved: String = _begin()
			var label: String = "%s, filled %s" % [exit_name, filled]
			if exit_name == "launcher quit":
				_store_sitting(PlaytestSettings.build_id(), filled)
				var launcher = await _open_launcher(runner)
				runner.check(not _current_text().is_empty(), "NB11 %s: fixture stored" % label)
				launcher.get_node("Sidebar/Nav/Quit").pressed.emit()
				launcher.free()
			else:
				var main = await _scene(runner)
				main.quit = func() -> void: pass
				if filled: runner.check(_press(main, "%s_3" % _questions()[0].id), "NB11 %s: rating shown" % label)
				else: PlaytestSession.current.set_checked("collect", true, false)
				runner.check(not _current_text().is_empty(), "NB11 %s: fixture stored" % label)
				if exit_name == "pause quit": main.get_node("HUD/PauseMenu").quit_requested.emit()
				else: _close_window(main)
				main.free()
			runner.check(_session_files().size() == (1 if filled else 0) and _current_text().is_empty(), "NB11 %s: files %s and removes current.json" % [label, _session_files()])
			_end(saved)
	return true

func test_form_layout(runner) -> bool:
	var longest: Dictionary = {}
	for card: Dictionary in FocusCards.load_cards():
		if JSON.stringify(card).length() > JSON.stringify(longest).length(): longest = card
	var saved: String = _begin(true, longest.id)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		PlaytestSession.current = null
		DirAccess.remove_absolute(sessions.path_join(PlaytestSession.CURRENT))
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var main = await _scene(runner, Skirmish, port)
		var overlay = main.get_node("HUD/Playtest")
		_camera(main)
		for k in 5: _mark(overlay, ["good", "bad", "confusing"][k % 3], "marker %d with a longish note that has to wrap in the panel" % k)
		_end_offline(main)
		main._refresh()
		await runner.process_frame
		await runner.process_frame
		var panel: Control = _panel(main)
		var rect: Rect2 = panel.get_global_rect()
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size) and PlaytestSession.current.data.focus == longest.id, "PO15 fixture: a real %s viewport and the longest card" % size)
		runner.check(panel.visible and rect.size.y <= 0.6 * size.y + 0.5, "PO15 the panel is at most 60 %% of %s high, got %s" % [size, rect.size])
		runner.check(screen.encloses(rect), "PO15 the panel is inside %s, rect %s" % [size, rect])
		for other in ["HUD/Status", "HUD/Economy"]:
			var control: Control = main.get_node(other)
			runner.check(not rect.intersects(Rect2(control.global_position, control.get_combined_minimum_size())), "PO15 the panel is clear of %s at %s" % [other, size])
		var card: Control = main.get_node("HUD/ResultPanel/Center/Card")
		runner.check(card.is_visible_in_tree() and not rect.intersects(card.get_global_rect()), "PO15 the panel is clear of the result card at %s, card %s panel %s" % [size, card.get_global_rect(), rect])
		var scrolls: Array[Node] = panel.find_children("*", "ScrollContainer", true, false)
		var last: Control = panel.find_child("Comment_0_4", true, false)
		runner.check(scrolls.size() == 1 and last != null, "PO15 the panel scrolls and lists the fifth marker's comment at %s" % size)
		if scrolls.size() == 1 and last != null:
			(scrolls[0] as ScrollContainer).ensure_control_visible(last)
			await runner.process_frame
			await runner.process_frame
			runner.check(scrolls[0].get_global_rect().encloses(last.get_global_rect()), "PO15 the scroll reaches the last comment field at %s, scroll %s field %s" % [size, scrolls[0].get_global_rect(), last.get_global_rect()])
		port.free()
	_end(saved)
	return true

func test_resume_uses_stored_card(runner) -> bool:
	var saved: String = _begin(true, CARD_TUNNELS)
	var stored := PlaytestSession.resume_or_open(CARD_TUNNELS, "0.11.0-dev+abc")
	stored.finish_match({"mode": "offline", "end_tick": 10})
	PlaytestSession.current = null
	FocusCards.chosen = ""
	var main = await _scene(runner)
	var list: Control = main.get_node("HUD/Playtest/Checklist")
	runner.check(PlaytestSession.current != null and PlaytestSession.current.data.focus == CARD_TUNNELS, "PO16 the resumed sitting keeps its card")
	runner.check(list.find_child("esc", true, false) != null and list.find_child("collect", true, false) == null, "PO16 the checklist is the stored card's, not card 1's")
	main.free()
	_end(saved)
	return true

func test_restart_keeps_markers(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "bad", "abandoned")
	main._restart()
	var matches: Array = PlaytestSession.current.data.matches
	runner.check(matches.size() == 1 and matches[0].get("unfinished", false) and matches[0].markers.size() == 1, "PO17 a restart keeps the abandoned match's marker as an unfinished entry, got %s" % [matches.map(func(entry: Dictionary) -> int: return entry.markers.size())])
	_mark(overlay, "bad", "helper switched off")
	overlay.set_active(false)
	main._restart()
	overlay.set_active(true)
	runner.check(matches.size() == 2 and matches[1].get("unfinished", false) and matches[1].markers.size() == 1 and matches[1].markers[0].text == "helper switched off", "PO17 a restart with the helper off keeps them too")
	main.free()
	_end(saved)
	return true

func test_scale_legend(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var questions: Array = _questions()
	var legends: Array[Node] = _panel(main).find_children("ScaleLegend", "Label", true, false)
	runner.check(legends.size() == 1 and (legends[0] as Label).text == SessionForm.SCALE_LEGEND, "PO18 one ScaleLegend with the exact text, got %d" % legends.size())
	if legends.size() == 1:
		var rows: Node = legends[0].get_parent()
		var last: Control = rows.find_child("%s_5" % questions[questions.size() - 1].id, true, false)
		var title: Control = rows.find_child("MarkersTitle", false, false)
		runner.check(last != null and title != null and legends[0].get_index() > last.get_parent().get_index() and legends[0].get_index() < title.get_index(), "PO18 the legend sits after the last question and before the marker list")
	main.free()
	_end(saved)
	return true

func test_sb2_checklist_waits_for_answer(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	var sim = SkirmishRules.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.adopt(sim)
	main._refresh()
	var pile: Dictionary = sim.snapshot().sources[0]
	var laborer: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder")
	main._submit({"type": "gather", "entity_ids": [999999], "source_id": pile.id})
	BaseScene.tick(main)
	runner.check(main.hud.note.begins_with("Rejected: ") and not overlay.checked("collect"), "RA2 a refused gather ticks nothing, note '%s'" % main.hud.note)
	main._submit({"type": "gather", "entity_ids": [laborer], "source_id": pile.id})
	runner.check(not overlay.checked("collect"), "RA2 an accepted gather waits for its answer")
	BaseScene.tick(main)
	runner.check(overlay.checked("collect"), "RA2 the accepted answer ticks collect")
	main.free()
	_end(saved)
	return true

func test_sb2_review_form_and_pending_answer(runner) -> bool:
	var saved: String = _begin()
	var online: Dictionary = await _online(runner)
	var main = online.main
	var lockstep = main.driver._lockstep
	main.orders._awaiting_build = "usa_power_plant"
	lockstep._command_log.append({"type": "build", "player": 1, "sequence": 5, "tick": 9, "builder_id": 3, "building_kind": "usa_power_plant", "origin": [-4, -4]})
	lockstep._rejections.append({"tick": 9, "sequence": 5, "error": "Outside map"})
	lockstep._rejections.append({"tick": 9, "sequence": 6, "error": "No units left"})
	main._playtest.end_match()
	runner.check(_panel(main).visible and not main._playtest.holds_match(), "RA7 fixture: the panel is open and holds nothing")
	BaseScene.tick(main)
	runner.check(main.orders._awaiting_build.is_empty() and main.hud.note == "Rejected: No units left", "RA7 online answers arrive with the panel open, note '%s'" % main.hud.note)
	main.free()
	_end(saved)
	saved = _begin()
	main = await _scene(runner)
	main._submit({"type": "move", "entity_ids": [_own_unit(main)], "target": [-5.0, -5.0]})
	main._playtest.end_match()
	runner.check(_panel(main).visible and not main._playtest.holds_match(), "RA7 offline fixture: the panel is open and holds nothing")
	BaseScene.tick(main)
	runner.check(main.driver.queued().is_empty(), "RA7 offline delivers the queued move with the panel open, queued %d" % main.driver.queued().size())
	main.free()
	_end(saved)
	return true

func _enter_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	return event

func test_open_panel_never_holds(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	runner.check(_panel(main).visible and _panel(main).find_child("Rows", true, false) != null and not overlay.holds_match() and not main.menu_open(), "PO20 the open panel holds nothing and is no menu")
	var tick: int = main.driver.pump.live().tick()
	_move_own_unit(main)
	runner.check(_pending(main, "move") == 1, "PO20 a move order is sent with the panel open")
	_run(main, 10)
	runner.check(main.driver.pump.live().tick() == tick + 10 and _pending(main, "move") == 0 and main.hud.note.is_empty(), "PO20 ten frames advance ten ticks and deliver the move, tick %d, note '%s'" % [main.driver.pump.live().tick() - tick, main.hud.note])
	overlay.open_marker()
	runner.check(overlay.holds_match() and main.menu_open(), "PO20 the marker dialog still holds the match")
	_run(main, 5)
	runner.check(main.driver.pump.live().tick() == tick + 10, "PO20 the tick stops while the marker dialog is open")
	main.free()
	_end(saved)
	return true

func test_match_end_shows_panel_without_focus(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	_end_offline(main)
	main._refresh()
	runner.check(_panel(main).visible and not _focus_in_panel(main), "PO21 match end shows the panel without taking the focus, focus %s" % main.get_viewport().gui_get_focus_owner())
	var kept = main.driver.pump.live()
	main._input(_enter_key())
	runner.check(not is_same(main.driver.pump.live(), kept), "PO21 Enter on the result panel plays again")
	runner.check(_panel(main).visible, "PO21 Play again keeps the open panel open")
	_key(runner, KEY_QUOTELEFT)
	main._restart()
	runner.check(not _panel(main).visible, "PO21 Play again keeps a hidden panel hidden")
	main.free()
	_end(saved)
	return true

func test_marker_list_this_and_last(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "good", "first")
	runner.check(_markers_title(main) == "This match" and _field(main, "Comment_0_0") != null, "PO22 a marker lists under This match, title '%s'" % _markers_title(main))
	overlay.end_match()
	runner.check(_markers_title(main) == "This match" and _field(main, "Comment_0_0") != null, "PO22 the ended match stays This match, title '%s'" % _markers_title(main))
	main._restart()
	var comment: LineEdit = _field(main, "Comment_0_0")
	runner.check(_markers_title(main) == "Last match" and comment != null and comment.editable, "PO22 after Play again the old markers list as Last match, title '%s'" % _markers_title(main))
	if comment != null:
		comment.text = "later"
		comment.text_submitted.emit(comment.text)
		runner.check(PlaytestSession.current.data.matches[0].markers[0].comment == "later", "PO22 a Last match comment saves to entry 0")
	_mark(overlay, "bad", "second")
	runner.check(_markers_title(main) == "This match" and _field(main, "Comment_1_0") != null and _field(main, "Comment_0_0") == null, "PO22 the new match's first marker switches to This match, title '%s'" % _markers_title(main))
	main.free()
	_end(saved)
	return true

func test_typing_is_text_not_keys(runner) -> bool:
	var saved: String = _begin()
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards()).duplicate(true)
	card.try.append({"id": "h", "text": "Press H", "trigger": "key:H"})
	var overlay = PlaytestOverlay.new()
	overlay.setup(card, func() -> Dictionary: return {"tick": 0, "camera": [0.0, 0.0], "selected": [], "over": false, "menu": false}, func() -> Dictionary: return {}, func() -> Dictionary: return {})
	runner.root.add_child(overlay)
	overlay.set_active(true)
	var answer: LineEdit = overlay.get_node("Checklist").find_child("Answer_" + card.questions[0].id, true, false)
	runner.check(answer != null, "PO23 fixture: the panel has the answer field")
	if answer != null:
		answer.grab_focus()
		_key(runner, KEY_QUOTELEFT, 96)
		_key(runner, KEY_N, 110)
		_key(runner, KEY_H, 104)
		runner.check(overlay.get_node("Checklist").visible and not overlay.get_node("MarkerDialog").visible and not overlay.checked("h"), "PO23 ` N H in a field toggle nothing, open no marker and tick no key trigger")
		runner.check(overlay.get_viewport().gui_get_focus_owner() is LineEdit, "PO23 the field keeps the focus")
		_key(runner, KEY_ESCAPE)
		_key(runner, KEY_H, 104)
		runner.check(overlay.checked("h"), "PO23 fixture: H outside a field ticks the key trigger")
	overlay.free()
	_end(saved)
	return true

func test_field_saves_on_submit_and_exit(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var questions: Array = _questions()
	var answer: LineEdit = _field(main, "Answer_" + questions[0].id)
	var footer: Label = _panel(main).find_child("Saved", true, false)
	runner.check(answer != null and footer != null and not footer.visible, "PO24 fixture: the answer field and a hidden Saved footer")
	if answer != null and footer != null:
		var before: String = _current_text()
		answer.grab_focus()
		answer.text = "typed"
		answer.text_changed.emit(answer.text)
		runner.check(_current_text() == before, "PO24 typing alone writes nothing")
		answer.text_submitted.emit(answer.text)
		await runner.process_frame
		runner.check(_stored_answer(questions[0].id) == "typed" and main.get_viewport().gui_get_focus_owner() == null, "PO24 Enter saves the field and releases the focus, stored '%s'" % _stored_answer(questions[0].id))
		runner.check(footer.visible and footer.text == "Saved %s" % PlaytestSession.current.saved_at, "PO24 the footer shows the save time, got '%s'" % footer.text)
		var second: LineEdit = _field(main, "Answer_" + questions[1].id)
		second.grab_focus()
		second.text = "left"
		main.get_viewport().gui_release_focus()
		runner.check(_stored_answer(questions[1].id) == "left", "PO24 leaving a field saves it, stored '%s'" % _stored_answer(questions[1].id))
	main.free()
	_end(saved)
	return true

func test_world_click_releases_field(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "bad", "click away")
	var unit: int = _own_unit(main)
	main.orders.selected_ids.assign([unit])
	var comment: LineEdit = _field(main, "Comment_0_0")
	runner.check(comment != null, "PO25 fixture: the marker's comment field")
	if comment != null:
		comment.grab_focus()
		comment.text = "clicked"
		var target := Vector2.ZERO
		for entity: Dictionary in main.driver.pump.live().snapshot().entities:
			if entity.id == unit: target = Vector2(entity.position[0] + 4.0, entity.position[1])
		var click := InputEventMouseButton.new()
		click.position = main.get_node("WorldView").get_global_transform_with_canvas() * Iso.world_to_plane(target)
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = true
		main._unhandled_input(click)
		runner.check(main.get_viewport().gui_get_focus_owner() == null and PlaytestSession.current.data.matches[0].markers[0].comment == "clicked", "PO25 a right click on the ground releases and saves the field, focus %s" % main.get_viewport().gui_get_focus_owner())
		runner.check(_pending(main, "move") == 1, "PO25 the same click sends the move")
		_key(runner, KEY_S, 115)
		runner.check(_pending(main, "stop") == 1, "PO25 the stop hotkey then sends a stop")
	main.free()
	_end(saved)
	return true

func test_escape_in_field(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var questions: Array = _questions()
	var answer: LineEdit = _field(main, "Answer_" + questions[0].id)
	runner.check(answer != null, "PO26 fixture: the answer field")
	if answer != null:
		answer.grab_focus()
		answer.text = "escaped"
		_key(runner, KEY_ESCAPE)
		runner.check(main.get_viewport().gui_get_focus_owner() == null and _stored_answer(questions[0].id) == "escaped" and not main.get_node("HUD/PauseMenu").visible, "PO26 Esc in a field releases and saves it and leaves the pause menu closed")
		_key(runner, KEY_ESCAPE)
		runner.check(main.get_node("HUD/PauseMenu").visible, "PO26 a second Esc opens the pause menu")
	main.free()
	_end(saved)
	return true

func test_toggles_take_no_focus(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "good", "focus")
	var toggles: Array[Node] = []
	var fields: Array[Node] = []
	for path in ["Checklist", "MarkerDialog"]:
		for button: BaseButton in overlay.get_node(path).find_children("*", "BaseButton", true, false):
			if button.toggle_mode: toggles.append(button)
		fields.append_array(overlay.get_node(path).find_children("*", "LineEdit", true, false))
	var grabbing: Array = toggles.filter(func(button: BaseButton) -> bool: return button.focus_mode != Control.FOCUS_NONE).map(func(button: BaseButton) -> String: return button.name)
	runner.check(toggles.size() > 10 and grabbing.is_empty(), "PO27 every toggle takes no focus, %d toggles, focusable %s" % [toggles.size(), grabbing])
	runner.check(fields.size() > 1 and fields.all(func(field: LineEdit) -> bool: return field.focus_mode == Control.FOCUS_ALL), "PO27 every text field takes focus, %d fields" % fields.size())
	var answer: LineEdit = _field(main, "Answer_" + _questions()[0].id)
	if answer != null:
		answer.grab_focus()
		runner.check(answer.has_focus() and answer.get_theme_stylebox("focus") != answer.get_theme_stylebox("normal"), "PO27 a focused field has its own focus style")
	main.free()
	_end(saved)
	return true

func test_header_has_no_digest(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	var keys: Array = ["mode", "map", "seed", "factions", "seat", "build"]
	var header: Dictionary = main.playtest_header()
	runner.check(not header.has("end_digest") and header.has_all(keys), "PO28 the mid-match header has no digest and every header field, got %s" % [header.keys()])
	_mark(overlay, "bad", "cut short")
	var stored: Variant = JSON.parse_string(_current_text())
	var entry: Dictionary = stored.matches[0] if stored is Dictionary and not stored.matches.is_empty() else {}
	runner.check(entry.has_all(keys) and entry.get("unfinished", false) and str(entry.get("map", "")) == str(header.map), "PO28 the marker's entry on disk carries the header, got %s" % [entry.keys()])
	main.free()
	_end(saved)
	return true

func _mod_key(runner, code: Key, ctrl: bool, meta: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	event.pressed = true
	runner.root.push_input(event)

func _select_builder(main) -> bool:
	for unit: Dictionary in main.driver.pump.live().snapshot().entities:
		if unit.owner != main.local_player: continue
		main.orders.selected_ids.assign([unit.id])
		main._refresh()
		if not main.orders.menu.is_empty(): return true
	return false

func test_modifier_keys_stay_in_field(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	runner.check(_select_builder(main), "PO29 fixture: a selected unit with a build menu")
	var answer: LineEdit = _field(main, "Answer_" + _questions()[0].id)
	answer.grab_focus()
	_mod_key(runner, KEY_S, true, false)
	_mod_key(runner, KEY_S, false, true)
	runner.check(_pending(main, "stop") == 0, "PO29 Ctrl+S and Cmd+S in a field send no stop, got %d" % _pending(main, "stop"))
	_mod_key(runner, KEY_1, true, false)
	_mod_key(runner, KEY_E, false, true)
	runner.check(main.orders._placement_kind.is_empty() and _pending(main, "produce") == 0, "PO29 Ctrl+1 and Cmd+E in a field pick nothing, placement '%s'" % main.orders._placement_kind)
	runner.check(answer.has_focus(), "PO29 the field keeps the focus")
	main.free()
	_end(saved)
	return true

func test_arrows_do_not_pan_while_typing(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	var answer: LineEdit = _field(main, "Answer_" + _questions()[0].id)
	answer.grab_focus()
	var start: Vector2 = camera.position
	Input.action_press("ui_right")
	main._process(0.1)
	runner.check(camera.position == start, "PO30 an arrow held while typing does not pan, moved %s" % (camera.position - start))
	main.get_viewport().gui_release_focus()
	main._process(0.1)
	Input.action_release("ui_right")
	runner.check(camera.position != start, "PO30 fixture: the same arrow pans outside a field")
	main.free()
	_end(saved)
	return true

func test_world_click_keeps_dialog_text(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.open_marker()
	var text: LineEdit = _dialog(main).find_child("Text", true, false)
	var click := InputEventMouseButton.new()
	click.position = Vector2(200, 200)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._unhandled_input(click)
	runner.check(text.has_focus(), "PO31 a world click with the marker dialog open keeps its text focused, focus %s" % main.get_viewport().gui_get_focus_owner())
	main.free()
	_end(saved)
	return true

func test_panel_shrinks_on_resize(runner) -> bool:
	var saved: String = _begin()
	var port := SubViewport.new()
	port.size = Vector2i(1920, 1080)
	runner.root.add_child(port)
	var main = await _scene(runner, Skirmish, port)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	for k in 8: _mark(overlay, "bad", "marker %d with a longish note that has to wrap in the panel" % k)
	await runner.process_frame
	await runner.process_frame
	var tall: float = _panel(main).size.y
	port.size = Vector2i(1280, 720)
	await runner.process_frame
	await runner.process_frame
	var rect: Rect2 = _panel(main).get_global_rect()
	runner.check(tall > 0.6 * 720.0, "PO32 fixture: the panel is taller than 60 %% of 720 at 1080, got %s" % tall)
	runner.check(rect.size.y <= 0.6 * 720.0 + 0.5 and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect), "PO32 the panel shrinks into 60 %% of 720 after a resize, rect %s" % rect)
	port.free()
	_end(saved)
	return true

func test_focused_text_survives_rebuilds(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	var id: String = _questions()[0].id
	_mark(overlay, "bad", "one")
	var steps: Array = [["marker", func() -> void: _mark(overlay, "good", "two")], ["end", func() -> void: overlay.end_match()], ["begin", func() -> void: main._restart()]]
	for step: Array in steps:
		var answer: LineEdit = _field(main, "Answer_" + id)
		answer.grab_focus()
		answer.text = "answer before " + step[0]
		step[1].call()
		runner.check(_stored_answer(id) == "answer before " + step[0], "PO33 a focused answer survives the %s rebuild, stored '%s'" % [step[0], _stored_answer(id)])
	_mark(overlay, "bad", "three")
	var comment: LineEdit = _field(main, "Comment_1_0")
	comment.grab_focus()
	comment.text = "comment before end"
	overlay.end_match()
	runner.check(PlaytestSession.current.data.matches[1].markers[0].comment == "comment before end", "PO33 a focused comment survives the end rebuild")
	main.free()
	_end(saved)
	return true

func test_enter_in_field_then_play_again(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	_end_offline(main)
	main._refresh()
	var id: String = _questions()[0].id
	var answer: LineEdit = _field(main, "Answer_" + id)
	answer.grab_focus()
	answer.text = "entered"
	var kept = main.driver.pump.live()
	_key(runner, KEY_ENTER)
	runner.check(is_same(main.driver.pump.live(), kept) and _stored_answer(id) == "entered" and main.get_viewport().gui_get_focus_owner() == null, "PO34 the first Enter saves and releases the field without playing again")
	_key(runner, KEY_ENTER)
	runner.check(not is_same(main.driver.pump.live(), kept), "PO34 the second Enter plays again")
	main.free()
	_end(saved)
	return true

func _no_markers_line(main) -> String:
	var label: Label = _panel(main).find_child("NoMarkers", true, false)
	return label.text if label != null else ""

func test_empty_marker_states(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	runner.check(_markers_title(main) == "This match" and _no_markers_line(main) == "No markers yet (N adds one)", "PO35 a fresh match shows the empty state, '%s' '%s'" % [_markers_title(main), _no_markers_line(main)])
	overlay.end_match()
	runner.check(_markers_title(main) == "This match" and _no_markers_line(main) == "No markers this match", "PO35 an ended match without markers says so, got '%s'" % _no_markers_line(main))
	main._restart()
	runner.check(_markers_title(main) == "This match" and _no_markers_line(main) == "No markers yet (N adds one)", "PO35 after a match without markers there is no Last match, '%s'" % _markers_title(main))
	_mark(overlay, "good", "one")
	runner.check(_no_markers_line(main).is_empty() and _panel(main).find_children("*", "Label", true, false).all(func(label: Label) -> bool: return label.text != "No markers."), "PO35 a marker replaces the empty state")
	main.free()
	_end(saved)
	return true

func test_failed_save_says_not_saved(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "good", "one")
	var footer: Label = _panel(main).find_child("Saved", true, false)
	runner.check(footer.visible and footer.text.begins_with("Saved "), "PO36 fixture: a good write says Saved, got '%s'" % footer.text)
	var current: String = sessions.path_join(PlaytestSession.CURRENT)
	DirAccess.remove_absolute(current)
	DirAccess.make_dir_recursive_absolute(current) # a directory in the file's place makes the write fail
	_mark(overlay, "bad", "two")
	runner.check(footer.visible and footer.text == "Not saved", "PO36 a failed write says Not saved, got '%s'" % footer.text)
	DirAccess.remove_absolute(current)
	_mark(overlay, "good", "three")
	runner.check(footer.visible and footer.text == "Saved %s" % PlaytestSession.current.saved_at and not PlaytestSession.current.saved_at.is_empty(), "PO36 the next good write says Saved again, got '%s'" % footer.text)
	main.free()
	_end(saved)
	return true

func test_window_close_keeps_marker_draft(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.open_marker()
	_dialog(main).find_child("Text", true, false).text = "draft"
	_close_window(main)
	var matches: Array = _saved_session().get("matches", [])
	var markers: Array = matches[0].markers if matches.size() == 1 else []
	runner.check(markers.size() == 1 and markers[0].text == "draft", "NB14 a window close files the open marker draft, got %s" % [markers])
	main.free()
	_end(saved)
	return true

func test_match_end_keeps_field_focus(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	var id: String = _questions()[0].id
	var answer: LineEdit = _field(main, "Answer_" + id)
	answer.grab_focus()
	answer.text = "mid sentence"
	answer.caret_column = 3
	_end_offline(main)
	main._refresh()
	var focus: Control = main.get_viewport().gui_get_focus_owner()
	runner.check(focus != null and focus.name == "Answer_" + id and _panel(main).is_ancestor_of(focus) and (focus as LineEdit).caret_column == 3, "PO37 after match end the rebuilt field has the focus and the caret, focus %s" % focus)
	var kept = main.driver.pump.live()
	_key(runner, KEY_ENTER)
	runner.check(is_same(main.driver.pump.live(), kept) and _stored_answer(id) == "mid sentence" and main.get_viewport().gui_get_focus_owner() == null, "PO37 Enter after match end saves and releases the field without playing again, stored '%s'" % _stored_answer(id))
	_key(runner, KEY_ENTER)
	runner.check(not is_same(main.driver.pump.live(), kept), "PO37 the second Enter plays again")
	main.free()
	_end(saved)
	return true

func test_new_scene_starts_new_entry(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	var scenes := _scenes(main)
	_mark(overlay, "bad", "first scene")
	PlaytestSettings.save_enabled(false)
	overlay.set_active(false)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER], "PO38 fixture: Back to menu with the helper off leaves")
	main.free()
	PlaytestSettings.save_enabled(true)
	main = await _scene(runner)
	_camera(main)
	_mark(main.get_node("HUD/Playtest"), "good", "second scene")
	var matches: Array = PlaytestSession.current.data.matches
	runner.check(matches.size() == 2 and matches[1].markers.size() == 1 and matches[1].markers[0].text == "second scene", "PO38 a new match scene's marker starts its own entry, got %s" % [matches.map(func(entry: Dictionary) -> int: return entry.markers.size())])
	main.free()
	_end(saved)
	return true

func test_resumed_sitting_lists_markers(runner) -> bool:
	var saved: String = _begin()
	var stored := PlaytestSession.resume_or_open(CARD_ECONOMY, "0.11.0-dev+abc")
	stored.add_marker({"kind": "bad", "text": "before the crash", "tick": 30, "comment": ""}, {"mode": "offline"})
	PlaytestSession.current = null
	var main = await _scene(runner)
	var comment: LineEdit = _field(main, "Comment_0_0")
	runner.check(_markers_title(main) == "Last match" and comment != null, "PO39 a resumed sitting lists its marker under Last match, title '%s'" % _markers_title(main))
	if comment != null:
		comment.text = "after the crash"
		comment.text_submitted.emit(comment.text)
		var on_disk: Variant = JSON.parse_string(_current_text())
		runner.check(on_disk.matches[0].markers[0].comment == "after the crash", "PO39 its comment saves to the resumed entry")
	main.free()
	_end(saved)
	return true

func test_match_end_keeps_marker_draft(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.open_marker()
	_dialog(main).find_child("Text", true, false).text = "draft at the end"
	overlay.end_match()
	var matches: Array = PlaytestSession.current.data.matches
	runner.check(matches.size() == 1 and not matches[0].has("unfinished") and matches[0].markers.size() == 1 and matches[0].markers[0].text == "draft at the end" and not _dialog(main).visible, "PO40 match end files the open marker draft into the finished match, got %s" % [matches])
	main.free()
	_end(saved)
	return true

func test_mute_key_stays_in_field(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var muted: bool = AudioServer.is_bus_mute(0)
	_field(main, "Answer_" + _questions()[0].id).grab_focus()
	_mod_key(runner, KEY_M, true, false)
	runner.check(AudioServer.is_bus_mute(0) == muted, "PO41 Ctrl+M in a field leaves the mute alone")
	_mod_key(runner, KEY_M, false, true)
	runner.check(AudioServer.is_bus_mute(0) == muted, "PO41 Cmd+M in a field leaves the mute alone")
	main.get_viewport().gui_release_focus()
	_key(runner, KEY_M)
	runner.check(AudioServer.is_bus_mute(0) != muted, "PO41 fixture: M outside a field toggles the mute")
	AudioServer.set_bus_mute(0, muted)
	main.free()
	_end(saved)
	return true

func test_match_end_scrolls_to_markers(runner) -> bool:
	var saved: String = _begin(true, "p2-you-clicked")
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	runner.root.add_child(port)
	var main = await _scene(runner, Skirmish, port)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "good", "one")
	await runner.process_frame
	var scroll: ScrollContainer = _panel(main).find_child("Rows", true, false).get_parent()
	runner.check(_panel(main).find_child("Rows", true, false).size.y > scroll.size.y, "PO42 fixture: the card's rows overflow the panel at 720")
	overlay.end_match()
	await runner.process_frame
	await runner.process_frame
	var title: Control = _panel(main).find_child("MarkersTitle", true, false)
	runner.check(scroll.get_global_rect().encloses(title.get_global_rect()), "PO42 match end scrolls the markers title into view, title %s, scroll %s" % [title.get_global_rect(), scroll.get_global_rect()])
	port.free()
	_end(saved)
	return true
