@warning_ignore_start("untyped_declaration")
extends RefCounted

const OnlineScene = preload("res://scenes/skirmish.tscn")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const SkirmishScene = preload("res://tests/test_skirmish_scene.gd")
const IcRows = preload("res://tests/input_script_rows.gd")
const JoinLink = preload("res://scripts/join_link.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const ViewCaps = preload("res://scripts/presentation/view_caps.gd")
const PEER_TICKS: int = 60
const RelayFrameOrder = preload("res://tests/relay_frame_order.gd")

# Records the ticks the world view consumed, after the real director stored them.
class VisualSpy extends "res://scripts/presentation/visual_director.gd":
	var ticks: Array[int] = []
	func _consume(step: Dictionary) -> void:
		super(step)
		ticks.append(step.tick)

class ErrorLog extends Logger:
	var lines := PackedStringArray()
	func _log_message(message: String, error: bool) -> void:
		if error: lines.append(message)

class FakeTransport extends RefCounted:
	var patient: bool = false
	var frames := PackedStringArray()
	var sent: Array[String] = []
	var is_closed: bool = false
	var is_silent: bool = false
	var close_calls: int = 0
	var order := RelayFrameOrder.new()
	var expect_refusal: bool = false
	func poll() -> PackedStringArray:
		var out := frames
		frames = PackedStringArray()
		for text in out:
			if Wire.decode(text).message.get("type", "") == "start": order.rematch()
		return out
	func send_text(text: String) -> void:
		sent.append(text)
		if order.accepts(text): return
		if not expect_refusal: push_error("relay refused: %s" % text)
		frames.append(Wire.encode({"type": "error", "reason": "invalid message"}))
		is_closed = true
	func closed() -> bool: return is_closed
	func silent(_now: int) -> bool: return is_silent
	func close() -> void:
		close_calls += 1
		is_closed = true
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array([40000])

func cases() -> Array[Callable]:
	return [test_seat_two_controls_player_two, test_status_lines_and_layout, test_rejection_line, test_funds_rejection_is_announced, test_overlay_net_line, test_match_end_sends_over_and_keeps_socket, test_abnormal_end_closes_without_rematch, test_play_again_sends_once, test_friend_again_before_own_end, test_friend_left_after_end, test_accept_rematch_ends_with_the_friend, test_panel_follows_again_while_processing, test_leave_ends_the_phase, test_room_closed_after_end, test_room_gone_on_the_ending_frame, test_abnormal_end_after_friend_again, test_create_resets_catch_up_credit, test_rematch_builds_new_match, test_rematch_start_after_quit_stays_stopped, test_start_while_playing_is_protocol_error, test_patient_holds_on_result_panel, test_start_then_left_same_batch, test_patient_until_first_peer_tick, test_runs_at_tick_rate, test_catch_up_is_bounded, test_two_tick_frame_keeps_earlier_results, test_sb1_online_snapshot_per_hash_tick, test_stall_frames_are_not_step_frames, test_notices_reach_the_hud_while_processing, test_launcher_sections, test_launcher_faction_rows, test_plays_dry_wells_from_each_seat, test_offline_uses_chosen_map, test_online_start_saves_picks, test_restart_keeps_map_and_starts, test_restart_drops_old_stepped_results, test_joiner_refuses_other_map, test_old_relay_mismatch_is_shown, test_cancel_and_copy_while_waiting, test_start_without_settings_is_a_protocol_error, test_both_seats_share_map_and_starts, test_host_told_opponent_left_before_start, test_opponent_left_mid_match, test_leave_panel_focus_after_pause, test_leave_panel_yields_focus, test_back_to_menu_once, test_pause_leave_mid_match_with_the_helper_on, test_back_to_menu_after_the_review_files_the_match, test_credits_panel_layout, test_online_playtest_record, test_launcher_release_hides_relay, test_launcher_prefills_from_page, test_launcher_relay_help, test_copy_link_on_web, test_launcher_reads_no_page_off_web, test_input_script_online, test_sb2_online_placement_closes_and_reopens, test_hint_outlives_an_earlier_order, test_sb2_online_refusal_keeps_new_gesture, test_sb2_online_refusal_after_a_later_gesture, test_sb2_online_preview_waits_for_step, test_sb2_preview_after_catch_up, test_sb2_rematch_drops_pending_preview, test_sb3_online_two_notes, test_too_many_orders_note, test_sb4_take_ahead_past_end, test_sb4_leave_on_end_tick_catch_up, test_sb4_no_waiting_after_end, test_sb4_three_callbacks_one_drain, test_sb4_publish_is_not_a_tick, test_sb4_rematch_starts_from_new_pump, test_sb4_desync_report_ring, test_sb4_no_send_after_end, test_sb4_foreign_note_ends_match, test_sb4_refused_post_ends_match, test_sb4_protocol_end_after_win_logs_once, test_sb4_step_after_close_takes_no_tick, test_ph_peer_command_without_sequence_refused, test_ph_fake_relay_frame_order, test_ph_receive_ends_lockstep_with_undrained_job, test_ph_frame_order_through_end_and_rematch, test_ph_preview_on_last_job_of_catch_up, test_ph_preview_on_single_job_when_next_tick_waits, test_ph_preview_on_steady_step, test_view_player_after_the_online_seat, test_pal_two_seat_create_unchanged, test_pal_three_seat_create, test_pal_three_seat_starts, test_match_starts_with_builder_selected]

func _online(runner, seat: int) -> Dictionary:
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var lockstep = Lockstep.new(seat, seats)
	var main = OnlineScene.instantiate()
	main.setup(transport, lockstep, seat)
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	# The open checklist covers the right of the view where these cases click, and it takes those clicks (Task 13).
	main.get_node("HUD/Playtest/Checklist").hide()
	await runner.process_frame
	return {"main": main, "transport": transport, "lockstep": lockstep}

func _peer_packets(transport: FakeTransport, peer: int, from_tick: int, to_tick: int) -> void:
	for tick in range(from_tick, to_tick + 1):
		var commands: Array = [{"type": "choose_faction", "faction": "usa", "tick": 4, "player": peer, "sequence": 0}] if tick == 4 else []
		transport.frames.append(Wire.encode(Wire.tick_message(peer, tick, commands, null)))

func _peer_stop(transport: FakeTransport, tick: int) -> void:
	transport.frames.append(Wire.encode(Wire.tick_message(1, tick, [{"type": "stop", "entity_ids": [3], "tick": tick, "player": 1, "sequence": 1}], null)))

func _run(main, frames: int) -> void:
	for i in frames: BaseScene.tick(main)

func _entity(main, id: int) -> Dictionary:
	for unit in main.driver.pump.live().snapshot().entities:
		if unit.id == id: return unit
	return {}

func _own_commands(transport: FakeTransport) -> Array:
	var commands: Array = []
	for text in transport.sent:
		commands.append_array(Wire.decode(text).message.get("commands", []).filter(func(command: Dictionary) -> bool: return command.type != "choose_faction"))
	return commands

func _layout_ok(runner, main, label: String, panel_up: bool = false) -> void:
	BaseScene.slab_clear(runner, main, "N3 " + label)
	runner.check(main.get_node("HUD/ResultPanel").visible == panel_up, "N3 result panel %s: %s" % ["up" if panel_up else "hidden", label])

func test_seat_two_controls_player_two(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var view = main.get_node("WorldView")
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	var mine: Dictionary = _entity(main, 5)
	var theirs: Dictionary = _entity(main, 3)
	runner.check(mine.owner == 2 and theirs.owner == 1, "N1 fixture: entity 5 is player 2's builder")
	var mine_plane: Vector2 = Iso.world_to_plane(Vector2(mine.position[0], mine.position[1])) + Vector2(0, -8)
	var theirs_plane: Vector2 = Iso.world_to_plane(Vector2(theirs.position[0], theirs.position[1])) + Vector2(0, -8)
	runner.check(view.pick_entity(mine_plane) == 5, "N1 seat 2 picks its own unit")
	runner.check(view.pick_entity(theirs_plane) == -1, "N1 seat 2 cannot select player 1's unit")
	main.orders.selected_ids.assign([5])
	main.orders._move(Vector2(40.5, 10.5))
	_run(main, 20)
	var commands: Array = _own_commands(online.transport)
	runner.check(commands.size() == 1 and commands[0].type == "move" and commands[0].player == 2, "N1 move leaves as a player 2 command, got " + str(commands))
	runner.check(_entity(main, 5).order != null, "N1 the move order reached player 2's builder through lockstep")
	runner.check(main.driver.pump.live().tick() > 4 and online.lockstep.status() == "running", "N1 ticks advance with peer packets")
	main.free()
	var seat1: Dictionary = await _online(runner, 1)
	seat1.main.orders.selected_ids.assign([3])
	seat1.main.orders._move(Vector2(10.5, 14.5))
	_peer_packets(seat1.transport, 2, 4, 12)
	_run(seat1.main, 6)
	runner.check(_own_commands(seat1.transport).all(func(command: Dictionary) -> bool: return command.player == 1) and not _own_commands(seat1.transport).is_empty(), "N1 seat 1 commands carry player 1")
	seat1.main.free()
	return true

func test_status_lines_and_layout(runner) -> bool:
	var waiting: Dictionary = await _online(runner, 2)
	_run(waiting.main, 12)
	runner.check(waiting.lockstep.status() == "waiting" and BaseScene.hud_text(waiting.main).contains("Waiting for player 1"), "N2 waiting line")
	_layout_ok(runner, waiting.main, "waiting")
	waiting.main.free()
	var left: Dictionary = await _online(runner, 2)
	left.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": 4}))
	_run(left.main, 12)
	runner.check(BaseScene.hud_text(left.main).contains("Player 1 disconnected"), "N2 left line")
	_layout_ok(runner, left.main, "left", true)
	left.main.free()
	var lost: Dictionary = await _online(runner, 2)
	lost.transport.is_closed = true
	_run(lost.main, 2)
	runner.check(BaseScene.hud_text(lost.main).contains("Connection to relay lost"), "N2 relay lost line")
	_layout_ok(runner, lost.main, "relay lost")
	lost.main.free()
	var silent: Dictionary = await _online(runner, 2)
	silent.transport.is_silent = true
	_run(silent.main, 2)
	runner.check(silent.lockstep.status() == "ended_relay" and silent.lockstep.end_reason() == "connection to relay lost", "N2 silent relay ends the match with the relay-lost reason")
	silent.main.free()
	var before_seed: int = SkirmishMain.match_seed
	SkirmishMain.match_seed = 7
	var desync: Dictionary = await _online(runner, 2)
	SkirmishMain.match_seed = before_seed
	desync.transport.frames.append(Wire.encode(Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"})))
	_run(desync.main, 12)
	var text: String = BaseScene.hud_text(desync.main)
	runner.check(desync.lockstep.status() == "ended_desync" and text.contains("Desync — report saved to") and FileAccess.file_exists("user://desync/desync-seat2.json"), "N2 desync line and report file, got " + text)
	var report = JSON.parse_string(FileAccess.get_file_as_string("user://desync/desync-seat2.json"))
	runner.check(report is Dictionary and report.get("seed") == 7 and report.get("map") == SkirmishMain.map_path.get_file().get_basename() and report.get("starts") == SkirmishMain.starts and not report.get("hash_ring", []).is_empty(), "N2 desync report carries the screen's seed, map, starts and the sim's hash ring, got " + str(report))
	_layout_ok(runner, desync.main, "desync")
	DirAccess.remove_absolute("user://desync/desync-seat2.json")
	desync.main.free()

	var web_desync: Dictionary = await _online(runner, 2)
	var downloads: Array = []
	web_desync.main.driver.web = true
	web_desync.main.driver.download = func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer.size(), file_name, mime])
	web_desync.transport.frames.append(Wire.encode(Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"})))
	_run(web_desync.main, 12)
	var web_text: String = BaseScene.hud_text(web_desync.main)
	runner.check(downloads.size() == 1 and downloads[0][0] > 0 and downloads[0][1] == "desync-seat2.json" and web_text.contains("report downloaded as desync-seat2.json") and not FileAccess.file_exists("user://desync/desync-seat2.json"), "N2w web desync downloads the report and writes no file, got " + web_text)
	web_desync.main.free()
	return true

func _end_match(online: Dictionary) -> void:
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 8)
	online.main.driver.pump.live().remove_object(4)
	online.main.driver.pump.live().remove_object(6)
	_run(online.main, 2)

func _sent_types(transport: FakeTransport, type: String) -> int:
	return transport.sent.filter(func(text: String) -> bool: return Wire.decode(text).message.type == type).size()

func _panel_line(main) -> String:
	var status: Label = main.get_node("HUD/ResultPanel/Center/Card/Box/Status")
	return status.text if status.visible else ""

func _play_again_button(main) -> Button:
	return main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons/PlayAgain")

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _rematch_start(match_seed: int) -> String:
	return Wire.encode(_start_message(SkirmishMain.map_path.get_file().get_basename(), match_seed))

func _sent_faction_choice(transport: FakeTransport, from: int) -> bool:
	for i in range(from, transport.sent.size()):
		var message: Dictionary = Wire.decode(transport.sent[i]).message
		if message.type == "tick" and message.tick == 4 and message.commands.any(func(command: Dictionary) -> bool: return command.type == "choose_faction"): return true
	return false

func test_match_end_sends_over_and_keeps_socket(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	runner.check(main.driver.pump.live().snapshot().match.status == "ongoing", "N4 fixture: the match started")
	main.driver.pump.live().remove_object(4)
	main.driver.pump.live().remove_object(6)
	_run(main, 2)
	runner.check(online.transport.close_calls == 0, "N4 the socket stays open after a sim-decided end")
	runner.check(main.driver.latency_line().contains("RTT n=1 p95=40.0 ms"), "N4 latency line carries RTT p95, got " + main.driver.latency_line())
	runner.check(FileAccess.file_exists("user://netplay-latency.txt"), "N4 latency file written")
	_run(main, 4)
	runner.check(_sent_types(online.transport, "over") == 1 and online.transport.close_calls == 0, "N4 exactly one over leaves, got %d" % _sent_types(online.transport, "over"))
	runner.check(online.transport.patient, "N4 the result panel waits patiently")
	runner.check(online.lockstep.status() != "ended_relay" and main.driver.notice() == "", "N4 the end is not a relay loss, got " + main.driver.notice())
	runner.check(main.get_node("HUD/ResultPanel").visible and not _play_again_button(main).disabled and _panel_line(main) == "", "N4 panel up, Play again enabled, no status line, got '%s'" % _panel_line(main))
	main.free()
	return true

func test_abnormal_end_closes_without_rematch(runner) -> bool:
	var left: Dictionary = await _online(runner, 2)
	_peer_packets(left.transport, 1, 4, PEER_TICKS)
	_run(left.main, 8)
	left.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": 40}))
	_run(left.main, 40)
	runner.check(left.lockstep.status() == "ended_left" and left.transport.close_calls == 1 and _sent_types(left.transport, "over") == 0, "N13 a friend leaving mid-match closes once and sends no over, got %s %d" % [left.lockstep.status(), left.transport.close_calls])
	runner.check(_panel_line(left.main) == "Your opponent left" and not left.main.driver.can_play_again(), "N13 a leave mid-match tells the opponent left and closes the room, got '%s'" % _panel_line(left.main))
	left.main.free()
	var lost: Dictionary = await _online(runner, 2)
	_peer_packets(lost.transport, 1, 4, PEER_TICKS)
	_run(lost.main, 8)
	lost.transport.is_closed = true
	_run(lost.main, 4)
	runner.check(lost.lockstep.status() == "ended_relay" and lost.transport.close_calls == 1 and _sent_types(lost.transport, "over") == 0, "N13 a lost relay mid-match closes once and sends no over, got %s %d" % [lost.lockstep.status(), lost.transport.close_calls])
	runner.check(not lost.main.get_node("HUD/ResultPanel").visible, "N13 no result panel after a lost relay")
	lost.main.free()
	return true

func test_play_again_sends_once(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	main._playtest._dialog.show()
	main._input(_key(KEY_ENTER))
	runner.check(_sent_types(online.transport, "again") == 0, "N14 Enter under the marker dialog sends nothing")
	main._playtest._dialog.hide()
	_play_again_button(main).pressed.emit()
	_play_again_button(main).pressed.emit()
	main._input(_key(KEY_ENTER))
	_run(main, 1)
	main._input(_key(KEY_ENTER))
	_run(main, 2)
	runner.check(_sent_types(online.transport, "again") == 1, "N14 exactly one again leaves, got %d" % _sent_types(online.transport, "again"))
	runner.check(_panel_line(main) == "Waiting for your friend…" and _play_again_button(main).disabled, "N14 waiting line and Play again disabled, got '%s'" % _panel_line(main))
	main.free()
	return true

func test_friend_again_before_own_end(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(main, 1)
	runner.check(not online.lockstep.status().begins_with("ended") and not main.driver.pump.live().match_over(), "N15 the friend's early again does not end the match, got " + online.lockstep.status())
	main.driver.pump.live().remove_object(4)
	main.driver.pump.live().remove_object(6)
	_run(main, 2)
	runner.check(_panel_line(main) == "Your friend wants a rematch" and not _play_again_button(main).disabled and _play_again_button(main).text == "Accept rematch", "N15 the early again shows after the end with Accept rematch, got '%s' '%s'" % [_panel_line(main), _play_again_button(main).text])
	main.free()
	return true

func test_friend_left_after_end(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	main.set_process(true)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	online.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": PEER_TICKS}))
	_run(main, 3)
	runner.check(_panel_line(main) == "Your friend left" and _play_again_button(main).disabled, "N16 friend left line, Play again disabled, got '%s'" % _panel_line(main))
	runner.check(online.transport.close_calls == 1, "N16 the socket closes once, got %d" % online.transport.close_calls)
	runner.check(main.driver.notice() == "" and not BaseScene.hud_text(main).contains("relay"), "N16 a friend leaving is no relay loss, got '%s'" % main.driver.notice())
	main.free()
	return true

func test_accept_rematch_ends_with_the_friend(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	main.set_process(true)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(main, 2)
	runner.check(_play_again_button(main).text == "Accept rematch" and not _play_again_button(main).disabled, "N34 fixture: the friend's again offers Accept rematch")
	online.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": PEER_TICKS}))
	_run(main, 3)
	runner.check(_panel_line(main) == "Your friend left" and _play_again_button(main).disabled and _play_again_button(main).text == "Play again", "N34 the friend leaving after their again greys the button back to Play again, got '%s' '%s'" % [_panel_line(main), _play_again_button(main).text])
	main.free()
	var closed: Dictionary = await _online(runner, 2)
	_end_match(closed)
	closed.main.set_process(true)
	closed.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(closed.main, 2)
	closed.transport.is_closed = true
	_run(closed.main, 2)
	runner.check(_panel_line(closed.main) == "The room closed" and _play_again_button(closed.main).disabled and _play_again_button(closed.main).text == "Play again", "N34 a closed room after the friend's again reads Play again, got '%s' '%s'" % [_panel_line(closed.main), _play_again_button(closed.main).text])
	closed.main.free()
	return true

func test_panel_follows_again_while_processing(runner) -> bool:
	var own: Dictionary = await _online(runner, 2)
	_end_match(own)
	own.main.set_process(true)
	_run(own.main, 2)
	var tick: int = own.main.driver.pump.live().tick()
	_play_again_button(own.main).pressed.emit()
	runner.check(_panel_line(own.main) == "Waiting for your friend…" and _play_again_button(own.main).disabled and _play_again_button(own.main).text == "Play again", "N26 own again redraws the panel at once and keeps the label, got '%s' '%s'" % [_panel_line(own.main), _play_again_button(own.main).text])
	_run(own.main, 2)
	runner.check(own.main.driver.pump.live().tick() == tick and _panel_line(own.main) == "Waiting for your friend…" and _play_again_button(own.main).disabled, "N26 the waiting panel holds on later frames, got '%s'" % _panel_line(own.main))
	own.main.free()
	var friend: Dictionary = await _online(runner, 2)
	_end_match(friend)
	friend.main.set_process(true)
	_run(friend.main, 2)
	friend.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(friend.main, 1)
	runner.check(_panel_line(friend.main) == "Your friend wants a rematch" and not _play_again_button(friend.main).disabled and _play_again_button(friend.main).text == "Accept rematch", "N26 a friend's again after the end is drawn with Accept rematch, got '%s' '%s'" % [_panel_line(friend.main), _play_again_button(friend.main).text])
	_play_again_button(friend.main).pressed.emit()
	runner.check(_panel_line(friend.main) == "Your friend wants a rematch" and _play_again_button(friend.main).disabled and _play_again_button(friend.main).text == "Play again", "N26 answering a friend's again does not flash the waiting line and the greyed button reads Play again, got '%s' '%s'" % [_panel_line(friend.main), _play_again_button(friend.main).text])
	friend.main.free()
	return true

func test_leave_ends_the_phase(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_end_match(online)
	online.main.driver.leave()
	runner.check(not online.main.driver.can_play_again(), "N28 Play again is off as soon as the player leaves")
	online.main.driver.play_again()
	runner.check(_sent_types(online.transport, "again") == 0, "N28 no again after leave, got %d" % _sent_types(online.transport, "again"))
	online.main.free()
	return true

func test_room_closed_after_end(runner) -> bool:
	var expired: Dictionary = await _online(runner, 2)
	_end_match(expired)
	expired.transport.frames.append(Wire.encode({"type": "error", "reason": "room expired"}))
	_run(expired.main, 2)
	runner.check(_panel_line(expired.main) == "The room closed" and _play_again_button(expired.main).disabled, "N17 room expired: closed line, Play again disabled, got '%s'" % _panel_line(expired.main))
	runner.check(expired.transport.close_calls == 1, "N17 room expired closes the socket once, got %d" % expired.transport.close_calls)
	expired.main.free()
	var closed: Dictionary = await _online(runner, 2)
	_end_match(closed)
	closed.transport.is_closed = true
	_run(closed.main, 2)
	runner.check(_panel_line(closed.main) == "The room closed" and _play_again_button(closed.main).disabled, "N17 closed socket: closed line, Play again disabled, got '%s'" % _panel_line(closed.main))
	runner.check(closed.main.driver.notice() == "Connection to relay lost", "N17 a lost socket after the match reads as a relay loss, got " + closed.main.driver.notice())
	closed.main.free()
	var silent: Dictionary = await _online(runner, 2)
	_end_match(silent)
	silent.transport.is_silent = true
	_run(silent.main, 2)
	runner.check(_panel_line(silent.main) == "The room closed" and _play_again_button(silent.main).disabled and silent.transport.close_calls == 1, "N17 silent relay: closed line, Play again disabled, got '%s'" % _panel_line(silent.main))
	silent.main.free()
	return true

func test_room_gone_on_the_ending_frame(runner) -> bool:
	for label: String in ["left", "closed", "silent"]:
		var online: Dictionary = await _online(runner, 2)
		var main = online.main
		_peer_packets(online.transport, 1, 4, PEER_TICKS)
		_run(main, 8)
		main.driver.pump.live().remove_object(4)
		main.driver.pump.live().remove_object(6)
		if label == "left": online.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": PEER_TICKS}))
		if label == "closed": online.transport.is_closed = true
		if label == "silent": online.transport.is_silent = true
		_run(main, 1)
		runner.check(not main.driver.can_play_again() and _play_again_button(main).disabled, "N23 %s on the ending frame: Play again disabled" % label)
		main.driver.play_again()
		runner.check(_sent_types(online.transport, "again") == 0, "N23 %s on the ending frame: play_again sends nothing, got %d" % [label, _sent_types(online.transport, "again")])
		main.free()
	return true

func test_abnormal_end_after_friend_again(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(main, 1)
	main.driver.pump.live().remove_object(4)
	main.driver.pump.live().remove_object(6)
	online.transport.is_closed = true
	_run(main, 2)
	runner.check(online.lockstep.status() == "ended_relay", "N24 setup: abnormal end, got " + online.lockstep.status())
	runner.check(main.driver.rematch_line() == "The room closed" and not main.driver.can_play_again(), "N24 an abnormal end after the friend's again reads as a closed room, got '%s'" % main.driver.rematch_line())
	main.free()
	return true

func test_create_resets_catch_up_credit(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var driver = online.main.driver
	driver._credit = 4
	driver.create(SkirmishMain.map_path, SkirmishMain.starts, {}, 1)
	runner.check(driver._credit == 0, "N25 a new match starts without catch-up credit, got %d" % driver._credit)
	online.main.free()
	return true

func test_rematch_builds_new_match(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	var old_sim = main.driver.pump.live()
	var old_lockstep = main.driver._lockstep
	var sent_before: int = online.transport.sent.size()
	# A stale value proves the rematch recomputes starts (the test map's own are empty).
	SkirmishMain.starts = [2, 1]
	online.transport.frames.append(_rematch_start(99))
	_peer_packets(online.transport, 1, 4, 4)
	_run(main, 1)
	runner.check(not is_same(main.driver.pump.live(), old_sim) and not is_same(main.driver._lockstep, old_lockstep), "N18 the rematch builds a new simulation and lockstep")
	runner.check(SkirmishMain.match_seed == 99 and SkirmishMain.starts == MatchSettings.starts(SkirmishMain.map_path.get_file().get_basename(), 99), "N18 the rematch takes the relay's seed and its starts, got %d %s" % [SkirmishMain.match_seed, SkirmishMain.starts])
	runner.check(not main.get_node("HUD/ResultPanel").visible, "N18 the panel hides for the new match")
	runner.check(not online.transport.patient, "N18 the batched peer tick clears patient in the same frame")
	runner.check(_sent_faction_choice(online.transport, sent_before), "N18 the new match sends tick 4 with choose_faction")
	_peer_packets(online.transport, 1, 5, 12)
	_run(main, 6)
	runner.check(main.driver.pump.live().tick() > 4 and main.driver._lockstep.status() == "running", "N18 the batched peer tick 4 reached the new lockstep, got tick %d %s" % [main.driver.pump.live().tick(), main.driver._lockstep.status()])
	runner.check(not online.transport.patient and online.transport.close_calls == 0, "N18 the new match is live on the same socket")
	main.driver.pump.live().remove_object(4)
	main.driver.pump.live().remove_object(6)
	_run(main, 2)
	runner.check(_sent_types(online.transport, "over") == 2 and _panel_line(main) == "" and not _play_again_button(main).disabled and _play_again_button(main).text == "Play again", "N18 the second end sends its own over with a fresh panel and the plain label, got %d '%s' '%s'" % [_sent_types(online.transport, "over"), _panel_line(main), _play_again_button(main).text])
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_run(main, 1)
	runner.check(_panel_line(main) == "Your friend wants a rematch" and _play_again_button(main).text == "Accept rematch", "N18 the new lockstep hands the friend's again to the driver, got '%s'" % _panel_line(main))
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_rematch_start_after_quit_stays_stopped(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	PlaytestSession.last_filed = ""
	main._playtest.set_active(true)
	main._playtest.begin_match()
	PlaytestSession.current.set_answer("q", 3, "")
	_end_match(online)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	main.close_match(true)
	runner.check(not PlaytestSession.last_filed.is_empty() and PlaytestSession.current == null, "N36 fixture: Quit filed the sitting, got '%s'" % PlaytestSession.last_filed)
	var old_pump = main.driver.pump
	online.transport.frames.append(_rematch_start(99))
	_run(main, 1)
	runner.check(is_same(main.driver.pump, old_pump), "N36 a start arriving after Quit builds no new pump")
	runner.check(PlaytestSession.current == null, "N36 a start arriving after Quit opens no new sitting")
	main.free()
	if PlaytestSession.current != null: PlaytestSession.current.discard()
	PlaytestSession.last_filed = ""
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_start_while_playing_is_protocol_error(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 8)
	online.transport.frames.append(_rematch_start(99))
	_run(online.main, 1)
	runner.check(online.lockstep.status() == "ended_protocol", "N19 a start mid-match is a protocol error, got " + online.lockstep.status())
	online.main.free()
	var own: Dictionary = await _online(runner, 2)
	_peer_packets(own.transport, 1, 4, PEER_TICKS)
	_run(own.main, 8)
	own.transport.frames.append(Wire.encode({"type": "again", "seat": 2}))
	_run(own.main, 1)
	runner.check(own.lockstep.status() == "ended_protocol", "N19 an again carrying our own seat is a protocol error, got " + own.lockstep.status())
	own.main.free()
	return true

func test_patient_holds_on_result_panel(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	runner.check(online.lockstep.received_any() and online.transport.patient, "N20 fixture: the old match saw peer ticks and the panel is patient")
	_run(main, 10)
	runner.check(online.transport.patient, "N20 the old match's peer ticks never clear patient on the panel")
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	online.transport.frames.append(_rematch_start(5))
	_run(main, 2)
	runner.check(online.transport.patient, "N20 still patient until the new match's first peer tick")
	_peer_packets(online.transport, 1, 4, 4)
	_run(main, 1)
	runner.check(not online.transport.patient, "N20 the new match's first peer tick clears patient")
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_start_then_left_same_batch(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var batches: Dictionary = {
		"left": [_rematch_start(99), Wire.encode({"type": "left", "seat": 1, "after_tick": 3})],
		"room expired": [_rematch_start(99), Wire.encode({"type": "error", "reason": "room expired"})],
		"closed": [_rematch_start(99)],
	}
	var lines: Dictionary = {"left": "Your friend left", "room expired": "The room closed", "closed": "The room closed"}
	for label: String in batches:
		var online: Dictionary = await _online(runner, 2)
		var main = online.main
		_end_match(online)
		_play_again_button(main).pressed.emit()
		_run(main, 1)
		var old_sim = main.driver.pump.live()
		var sent_before: int = online.transport.sent.size()
		for frame: String in batches[label]: online.transport.frames.append(frame)
		if label == "closed": online.transport.is_closed = true
		_run(main, 2)
		runner.check(is_same(main.driver.pump.live(), old_sim) and main.driver.take_rematch() == -1 and SkirmishMain.match_seed == before[2], "N21 %s: start then end in one batch builds no match" % label)
		runner.check(_panel_line(main) == lines[label] and _play_again_button(main).disabled, "N21 %s: panel line and Play again disabled, got '%s'" % [label, _panel_line(main)])
		runner.check(not _sent_faction_choice(online.transport, sent_before), "N21 %s: no choose_faction sent" % label)
		main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_patient_until_first_peer_tick(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	online.transport.patient = true
	_run(online.main, 3)
	runner.check(online.transport.patient, "N22 patient holds before the first peer tick")
	_peer_packets(online.transport, 1, 4, 4)
	_run(online.main, 1)
	runner.check(not online.transport.patient, "N22 the first peer tick clears patient")
	online.main.free()
	return true

func test_runs_at_tick_rate(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 20)
	runner.check(online.main.driver.pump.live().tick() <= 20, "N5 never faster than one tick per physics frame, got %d" % online.main.driver.pump.live().tick())
	runner.check(online.main.driver.pump.live().tick() >= 19, "N5 keeps pace when packets are available, got %d" % online.main.driver.pump.live().tick())
	online.main.free()
	return true

func test_catch_up_is_bounded(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_run(online.main, 10)
	runner.check(online.main.driver.pump.live().tick() == 4, "N5 waits for the first peer packet, got %d" % online.main.driver.pump.live().tick())
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 1)
	runner.check(online.main.driver.pump.live().tick() == 6, "N5 catch-up is two ticks per frame, got %d" % online.main.driver.pump.live().tick())
	_run(online.main, 19)
	var tick: int = online.main.driver.pump.live().tick()
	runner.check(tick > 24 and tick <= 24 + online.main.driver.MAX_CATCH_UP_CREDIT, "N5 catch-up debt is capped, got %d" % tick)
	online.main.free()
	return true

const DUE_REJECTION: String = "Footprint outside map or overlaps obstacle"

func _double_build(online: Dictionary) -> void:
	var order := {"type": "build", "builder_id": 3, "building_kind": "usa_power_plant", "origin": [10, 10]}
	online.main.driver.submit(order)
	online.main.driver.submit(order)

func test_two_tick_frame_keeps_earlier_results(runner) -> bool:
	var control: Dictionary = await _online(runner, 1)
	_double_build(control)
	_peer_packets(control.transport, 2, 4, PEER_TICKS)
	_run(control.main, 6)
	runner.check(BaseScene.hud_text(control.main).contains(DUE_REJECTION), "N27 control: a one-tick frame shows the own due-time rejection")
	control.main.free()
	var online: Dictionary = await _online(runner, 1)
	_double_build(online)
	_run(online.main, 10)
	_peer_packets(online.transport, 2, 4, 4)
	_run(online.main, 1)
	_peer_packets(online.transport, 2, 5, PEER_TICKS)
	_run(online.main, 1)
	runner.check(online.main.driver.pump.live().tick() == 7, "N27 fixture: the frame advanced ticks 5 and 6, got %d" % online.main.driver.pump.live().tick())
	runner.check(BaseScene.hud_text(online.main).contains(DUE_REJECTION), "N27 a two-tick frame keeps the earlier tick's own rejection")
	online.main.free()
	return true

func test_sb1_online_snapshot_per_hash_tick(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	_peer_packets(online.transport, 2, 4, 64)
	Profiler.reset()
	Profiler.enabled = true
	var frames: int = 0
	while online.main.driver.pump.live().tick() <= 60 and frames < 200:
		_run(online.main, 1)
		frames += 1
	var snapshots: int = Profiler.calls(&"snapshot")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(online.main.driver.pump.live().tick() > 60, "RB8 fixture: the simulation passed tick 60, got %d" % online.main.driver.pump.live().tick())
	runner.check(snapshots == 2, "RB8 online ticks take one snapshot per hash tick, got %d" % snapshots)
	online.main.free()
	return true

func test_stall_frames_are_not_step_frames(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_run(main, 10)
	main.set_process(true)
	_run(main, 3)
	await runner.process_frame
	await runner.process_frame
	runner.check(main.driver.pump.live().tick() == 4 and main._clock.split_share() == 0.0, "N5 stall frames neither count as step frames nor refresh, got tick %d share %s" % [main.driver.pump.live().tick(), main._clock.split_share()])
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 1)
	await runner.process_frame
	await runner.process_frame
	runner.check(main._clock.split_share() == 1.0, "N5 an advancing frame still splits, got %s" % main._clock.split_share())
	main.free()
	return true

func test_notices_reach_the_hud_while_processing(runner) -> bool:
	var waiting: Dictionary = await _online(runner, 2)
	waiting.main.set_process(true)
	_run(waiting.main, 6)
	runner.check(BaseScene.hud_text(waiting.main).contains("Waiting for player 1"), "N2 waiting line shows while processing")
	runner.check(waiting.main._clock.split_share() == 0.0, "N2 notice refresh leaves the clock alone")
	waiting.transport.is_closed = true
	_run(waiting.main, 3)
	runner.check(BaseScene.hud_text(waiting.main).contains("Connection to relay lost"), "N2 ended match shows its message while processing")
	waiting.main.free()
	return true

const LAUNCHER_PAGE_PATHS: Dictionary = {
	"Play:bot": ["Title", "Subtitle", "Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/OpponentLabel", "Body/MapInfo", "Body/Opponent", "Body/BotLabel", "Body/Bot", "ThisBuild", "Footer/Status", "Footer/Start"],
	"Play:friend": ["Title", "Subtitle", "Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/OpponentLabel", "Body/MapInfo", "Body/Opponent", "Body/OpenSlot", "Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl", "ThisBuild", "Footer/Status", "Footer/Create"],
	"Join": ["Title", "Subtitle", "Body/CodeLabel", "Body/MapLabel", "Body/Code", "Body/MapHint", "Body/CodeHint", "Body/OwnLabel", "Body/Own", "Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl", "ThisBuild", "Footer/Status", "Footer/Join"],
	"Settings": ["Title", "Subtitle", "Body/Audio/AudioHeader", "Body/Audio/Volume/MusicLabel", "Body/Audio/Volume/Music", "Body/Audio/Volume/MusicValue", "Body/Audio/Volume/EffectsLabel", "Body/Audio/Volume/Effects", "Body/Audio/Volume/EffectsValue", "Body/Audio/Volume/VoiceLabel", "Body/Audio/Volume/Voice", "Body/Audio/Volume/VoiceValue", "Body/Audio/Volume/MuteLabel", "Body/Audio/Volume/Mute", "Body/Audio/DisplayHeader", "Body/Audio/Fullscreen", "Body/Playtest/GraphicsHeader", "Body/Playtest/Quality", "Body/Playtest/Neon", "Body/Playtest/Smooth", "Body/Playtest/Destinations", "Body/Playtest/PlaytestHeader", "Body/Playtest/PlaytestSwitch", "Body/Playtest/PlaytestHint"],
	"Credits": ["Title", "Subtitle", "Body/Text", "Body/Legal"],
	"Waiting": ["Title", "Subtitle", "Body/Left/Invite/Link", "Body/Left/Invite/Copy", "Body/Left/One", "Body/Left/Two", "Body/Right/Map", "Footer/Status", "Footer/Cancel"],
}
const LAUNCHER_NAV_ORDER: Array[String] = ["Play", "Join", "Divider", "Settings", "Credits"]
const PAGE_TITLES: Dictionary = {"Play": "Play", "Join": "Join a match", "Settings": "Settings", "Credits": "Credits", "Waiting": "Waiting for your friend"}

func _force_visible(launcher: Node) -> void:
	launcher.set_opponent("friend")
	for page_name: String in ["Play", "Join"]: launcher.get_node("Pages/%s/ThisBuild" % page_name).visible = true

func _page_controls_ok(runner, launcher: Node, size: Vector2i, id: String, skip: Array = []) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var content: Control = launcher.get_node("Pages")
	var opponent: String = launcher.opponent
	for key: String in LAUNCHER_PAGE_PATHS:
		var page_name: String = key.get_slice(":", 0)
		if ":" in key: launcher.set_opponent(key.get_slice(":", 1))
		launcher.show_page(page_name)
		await runner.process_frame
		await runner.process_frame
		var rects: Array[Rect2] = []
		for path: String in LAUNCHER_PAGE_PATHS[key]:
			if path in skip: continue
			var control: Control = launcher.get_node_or_null("Pages/%s/%s" % [page_name, path])
			runner.check(control != null and control.visible and view.encloses(control.get_global_rect()) and content.get_global_rect().grow(0.5).encloses(control.get_global_rect()), "%s %s/%s inside %s" % [id, key, path, size])
			if control != null: rects.append(control.get_global_rect())
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				runner.check(not rects[i].intersects(rects[j]), "%s %s controls %d and %d do not overlap at %s" % [id, key, i, j, size])
	launcher.set_opponent(opponent)

func test_launcher_sections(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-sections-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		launcher.prerelease = true
		port.add_child(launcher)
		_force_visible(launcher)
		await runner.process_frame
		await runner.process_frame
		for page_name: String in PAGE_TITLES:
			var header: Label = launcher.get_node_or_null("Pages/%s/Title" % page_name)
			runner.check(header != null and header.text == PAGE_TITLES[page_name], "N20 %s page reads %s at %s" % [page_name, PAGE_TITLES[page_name], size])
		var nav: Control = launcher.get_node("Sidebar/Nav")
		var indexes: Array[int] = []
		for name in LAUNCHER_NAV_ORDER:
			var node: Node = nav.get_node_or_null(name)
			indexes.append(node.get_index() if node != null else -1)
		var in_order: bool = not indexes.has(-1)
		for i in range(1, indexes.size()):
			in_order = in_order and indexes[i - 1] < indexes[i]
		runner.check(in_order, "N20 sections are in order at %s, got %s" % [size, indexes])
		var play: Control = launcher.get_node("Pages/Play")
		var advanced: Button = play.get_node_or_null("Body/Advanced/Toggle")
		var relay: LineEdit = play.get_node_or_null("Body/Advanced/RelayUrl")
		if advanced != null and relay != null:
			runner.check(not advanced.button_pressed and not relay.visible and advanced.text == "Advanced settings" and not advanced.flat, "N20 Advanced starts closed, as a visible button, at %s" % size)
			runner.check(relay.text == "wss://relay.pdstuber.dev/ws", "N20 closed fold keeps the default relay URL at %s" % size)
			advanced.button_pressed = true
			runner.check(relay.visible and advanced.button_pressed, "N20 opening Advanced shows the relay field at %s" % size)
			runner.check(advanced.text.to_utf8_buffer().size() == advanced.text.length(), "N20 toggle text is plain ASCII, the default font has no arrow glyphs, at %s" % size)
			await _page_controls_ok(runner, launcher, size, "N20")
		launcher.show_page("Play")
		var status: Label = play.get_node("Footer/Status")
		for text in ["Match code: ABC234 — waiting for player 2", "Connection to relay lost"] + MatchSettings.PLAY_MAPS.values().map(func(label: String) -> String: return "Your copy of %s differs from the host's" % label):
			launcher._show_status(status, text, true)
			await runner.process_frame
			runner.check(status.get_line_count() == 1, "N20 Status stays one line at %s: %s" % [size, text])
			runner.check(status.get_global_rect().end.x <= play.get_node("Footer/Start").get_global_rect().position.x, "N20 Status ends left of Start at %s: %s" % [size, text])
		launcher.show_page("Settings")
		await runner.process_frame
		await runner.process_frame
		runner.check(launcher.get_node("Pages/Settings/Body/Audio").get_global_rect().encloses(launcher.get_node("Pages/Settings/Body/Audio/Volume").get_global_rect()), "N5 Volume inside the audio column at %s" % size)
		var legal: String = launcher.get_node("Pages/Credits/Body/Legal").text
		for part in ["Electronic Arts", "GNU GPL", "no warranty", "github.com/pdstuber/wargrid"]:
			runner.check(part in legal, "N5 launcher legal notice names %s" % part)
		launcher.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	var offline = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.check(offline.get_script().resource_path == "res://scripts/match/match_screen.gd", "N5 Play offline loads the offline skirmish")
	offline.free()
	return true

func test_overlay_net_line(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var overlay = online.main.get_node("HUD/PerfOverlay")
	overlay.toggle()
	runner.check(overlay.text.contains("RTT p95 40 ms"), "N9 overlay shows the transport RTT")
	online.main.free()
	return true

func test_rejection_line(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	online.lockstep._rejections.append({"tick": 5, "sequence": 0, "error": "No units left"})
	_run(main, 1)
	runner.check(BaseScene.hud_text(main).contains("No units left"), "H5 online rejection line, got " + BaseScene.hud_text(main))
	_layout_ok(runner, main, "rejection")
	main.free()
	return true

func test_funds_rejection_is_announced(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	online.lockstep._rejections.append({"tick": 5, "sequence": 0, "error": "Insufficient credits"})
	_run(main, 1)
	var cues: Array = main._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)
	var stream: AudioStream = main._sound._voice.stream
	runner.check(stream != null and stream.resource_path.get_file() == "insufficient_funds.wav", "N6 online funds rejection says insufficient_funds")
	runner.check(not cues.has("error"), "N6 online funds rejection gives no error beep, got %s" % [cues])
	main.free()
	return true

func _row_texts(row: Node) -> Array:
	return row.get_children().map(func(node: Node) -> String: return node.text if node is Label else node.name)

func _faction_row_controls(page: Control) -> Array[Control]:
	var controls: Array[Control] = []
	for path in ["Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/BotLabel", "Body/Bot", "Footer/Start", "Footer/Create"]:
		controls.append(page.get_node(path))
	return controls

func test_launcher_faction_rows(runner) -> bool:
	var before := [SkirmishMain.factions, SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var window: Window = runner.root
	var saved := [window.size, window.content_scale_size, window.content_scale_aspect]
	for row: Array in [[Vector2i(1280, 720), Vector2i(1280, 720)], [Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(1280, 720), Vector2i(3840, 1080)]]:
		var size: Vector2i = row[0]
		window.size = row[1]
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		port.add_child(launcher)
		await runner.process_frame
		await runner.process_frame
		var page: Control = launcher.get_node("Pages/Play")
		page.get_node("Footer/Create").visible = true
		await runner.process_frame
		await runner.process_frame
		var body: Control = page.get_node("Body")
		runner.check(_row_texts(body) == ["You", "Map", "Own", "Map", "Opponent", launcher._map_info("dry_wells"), "Opponent", "Spacer1", "Bot", "Spacer2", "Bot", "Spacer3", "OpenSlot", "Spacer4", "Advanced"], "N25 Play body children at %s, got %s" % [size, _row_texts(body)])
		runner.check(page.find_children("Own", "OptionButton", true, false).size() == 1, "N25 Play has one Own selector at %s" % size)
		runner.check(page.get_node("Footer/Create").text == "Create match" and page.get_node("Footer/Start").text == "Start match", "N25 button texts kept at %s" % size)
		var controls: Array[Control] = _faction_row_controls(page)
		var inside: bool = true
		var clear: bool = true
		for i in controls.size():
			inside = inside and Rect2(Vector2.ZERO, Vector2(size)).encloses(controls[i].get_global_rect()) and page.get_global_rect().encloses(controls[i].get_global_rect())
			for j in range(i + 1, controls.size()):
				clear = clear and not controls[i].get_global_rect().intersects(controls[j].get_global_rect())
		runner.check(inside and clear, "N25 row controls inside the viewport and clear of each other at %s" % size)
		for path in ["Body/OwnLabel", "Body/BotLabel", "Body/MapLabel"]:
			var label: Label = page.get_node(path)
			runner.check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.text.to_utf8_buffer().size() == label.text.length(), "N25 %s is plain ASCII and ignores the mouse at %s" % [path, size])
		var own: OptionButton = page.get_node("Body/Own")
		var bot: OptionButton = page.get_node("Body/Bot")
		runner.check(own.item_count == 3 and bot.item_count == 3 and own.selected == bot.selected, "N25 Own and Bot list the factions and start equal at %s" % size)
		runner.check(body.get_global_rect().size.x < 1100.0, "F5 Play body stays under 1100 px wide at %s" % size)
		runner.check(own.get_item_text(0) == "China" and own.get_item_text(1) == "Free Resistance Coalition" and own.get_item_text(own.selected) == "United States", "F5 selector lists faction display names and defaults to the United States")
		var default_index: int = own.selected
		bot.select(0)
		runner.check(default_index != 0 and own.selected == default_index, "N25 Bot leaves Own alone at %s" % size)
		own.select(1)
		runner.check(bot.selected == 0, "N25 Own leaves Bot alone at %s" % size)
		var second: String = own.get_item_metadata(1)
		var third: String = own.get_item_metadata(2)
		bot.select(2)
		launcher._offline_setup()
		runner.check(SkirmishMain.factions == {1: second, 2: third}, "N25 offline Start passes Own and Bot at %s, got %s" % [size, SkirmishMain.factions])
		own.select(2)
		runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "N25 the launcher keeps expand until the match starts at %s" % size)
		launcher._transport = FakeTransport.new()
		launcher._seat = 1
		launcher._start(_start_message("dry_wells", 3))
		var root: Window = runner.root.get_tree().root
		var layout: Dictionary = ViewCaps.layout_for(root.size)
		runner.check([root.content_scale_size, root.content_scale_aspect] == [layout.size, layout.aspect], "N25 the match scene is added under its caps for the %s window, before any frame, at %s, got %s %d" % [root.size, size, root.content_scale_size, root.content_scale_aspect])
		var main = runner.root.get_tree().current_scene
		runner.check(main.driver._own_faction == third, "N25 online match carries Own's faction at %s, got %s" % [size, main.driver._own_faction])
		main.free()
		await runner.process_frame
		runner.check([root.content_scale_size, root.content_scale_aspect] == [ViewCaps.BASE, Window.CONTENT_SCALE_ASPECT_EXPAND], "N25 leaving the match writes 1280x720 expand at %s, got %s %d" % [size, root.content_scale_size, root.content_scale_aspect])
		port.free()
	window.size = saved[0]
	window.content_scale_size = saved[1]
	window.content_scale_aspect = saved[2]
	SkirmishMain.factions = before[0]
	SkirmishMain.map_path = before[1]
	SkirmishMain.starts = before[2]
	SkirmishMain.match_seed = before[3]
	return true

func _start_message(id: String, match_seed: int) -> Dictionary:
	return {"type": "start", "seats": [1, 2], "delay": 4, "seed": match_seed, "settings": MatchSettings.for_map(id)}

func test_plays_dry_wells_from_each_seat(runner) -> bool:
	var before: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	runner.check(before == "res://data/maps/skirmish.json", "N7 without the launcher the scenes keep the test map")
	for seat in [1, 2]:
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("dry_wells", 3))
		var main = runner.root.get_tree().current_scene
		var map: Dictionary = main.driver.pump.live().map_data()
		var start: Vector2i = MapData.start_cell(map, seat)
		runner.check(map.name == "Dry Wells" and main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(start) + Vector2(0.5, 0.5)), "N7 seat %d plays the host's map with the camera on its own base" % seat)
		main.free()
		await runner.process_frame
	SkirmishMain.map_path = before
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_online_start_saves_picks(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	for seat in [1, 2]:
		LauncherSettings.save_picks({"faction": "usa", "bot_faction": "china", "map": "dry_wells"})
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._set_own("frc")
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("ashfall", 3))
		var picks: Dictionary = LauncherSettings.load_picks()
		var expected: Dictionary = {"faction": "frc", "bot_faction": "china", "map": "ashfall" if seat == 1 else "dry_wells"}
		runner.check(picks == expected, "L9e seat %d start saves %s, got %s" % [seat, expected, picks])
		runner.root.get_tree().current_scene.free()
		await runner.process_frame
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_offline_uses_chosen_map(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var map_row: OptionButton = launcher.get_node("Pages/Play/Body/Map")
	var labels: Array = MatchSettings.PLAY_MAPS.values()
	runner.check(map_row.item_count == 3 and launcher._map_id() == "dry_wells", "N11 three maps, Dry Wells selected by default")
	for i in map_row.item_count:
		runner.check(map_row.get_item_text(i) == labels[i], "N11 dropdown item %d is %s" % [i, labels[i]])
	for i in map_row.item_count:
		map_row.select(i)
		var id: String = launcher._map_id()
		launcher._offline_setup()
		runner.check(SkirmishMain.map_path == MatchSettings.map_path(id), "N11 %s: Play offline uses the chosen map" % id)
		runner.check(SkirmishMain.starts.size() == 2, "N11 %s: two start spots chosen" % id)
		runner.check(SkirmishMain.starts == MatchSettings.starts(id, SkirmishMain.match_seed), "N11 %s: the starts come from the recorded match seed" % id)
		if id == "ashfall":
			runner.check((SkirmishMain.starts[0] - SkirmishMain.starts[1] + 8) % 8 == 4, "N11 Ashfall pair is diagonal, got %s" % str(SkirmishMain.starts))
	launcher.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_restart_keeps_map_and_starts(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	SkirmishMain.map_path = MatchSettings.map_path("broken_crown")
	SkirmishMain.starts = [3, 1]
	var main = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	var old_sim = main.driver.pump.live()
	main._restart()
	runner.check(not is_same(old_sim, main.driver.pump.live()), "N12 Restart builds a new simulation")
	var start: Vector2i = MapData.start_cell(main.driver.pump.live().map_data(), 1)
	var seat3: Vector2i = MapData.start_cell(MapData.load(SkirmishMain.map_path), 3)
	runner.check(start == seat3, "N12 Restart keeps seat 1 on the chosen start, got %s want %s" % [start, seat3])
	runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(start) + Vector2(0.5, 0.5)), "N12 camera on the chosen start after Restart")
	main.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_restart_drops_old_stepped_results(runner) -> bool:
	var main = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	main.stepped_results.append({"ok": false, "error": "old match", "player": main.local_player, "tick": 50, "sequence": 0})
	main._restart()
	runner.check(not BaseScene.hud_text(main).contains("old match"), "N12 Restart drops the old match's stepped results")
	main.free()
	return true

func test_joiner_refuses_other_map(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._seat = 2
	var message: Dictionary = _start_message("ashfall", 5)
	message.settings.map_hash = "0"
	var scene_before = runner.root.get_tree().current_scene
	launcher._origin = "Join"
	launcher._set_busy(true)
	runner.check(not launcher._handle(Wire.encode(message)), "N13 the joiner refuses a different map before the simulation exists")
	runner.check(runner.root.get_tree().current_scene == scene_before and transport.close_calls == 1, "N13 no online scene, transport closed once")
	runner.check(launcher.get_node("Pages/Join/Footer/Status").text == "Your copy of Ashfall differs from the host's", "N13 the reason is shown in Join's footer")
	runner.check(not launcher.get_node("Pages/Join/Footer/Join").disabled, "N13 Join usable again")
	launcher._process(0.0)
	launcher.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_old_relay_mismatch_is_shown(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	launcher._transport = FakeTransport.new()
	launcher._set_busy(true)
	launcher._handle('{"type":"error","reason":"protocol mismatch"}')
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "protocol mismatch" and not launcher.get_node("Pages/Play/Footer/Create").disabled, "N14 a protocol mismatch from an old relay is shown")
	launcher.free()
	return true

func test_cancel_and_copy_while_waiting(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._set_busy(true)
	launcher.set_process(true)
	var wait: Control = launcher.get_node("Pages/Waiting")
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(wait.visible and launcher.get_node("Pages/Play/Footer/Start").disabled and launcher.get_node("Pages/Play/Footer/Create").disabled and not launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").disabled and not launcher.get_node("Pages/Waiting/Footer/Cancel").disabled, "N17 waiting shows Copy and Cancel, launcher stays busy")
	runner.check(launcher._code == "ABC234", "N18 welcome stores the match code for Copy")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").pressed.emit()
		runner.check(DisplayServer.clipboard_get() == "ABC234", "N18 Copy puts the match code on the clipboard")
	launcher.get_node("Pages/Waiting/Footer/Cancel").pressed.emit()
	var enabled: bool = true
	for path in ["Play/Footer/Start", "Play/Footer/Create", "Join/Footer/Join", "Play/Body/Map", "Play/Body/Own", "Play/Body/Bot"]:
		enabled = enabled and not launcher.get_node("Pages/" + path).disabled
	runner.check(transport.close_calls == 1 and not wait.visible and enabled, "N17 Cancel restores the launcher")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "Match cancelled" and not launcher.is_processing(), "N17 Cancel says so and stops polling")
	launcher._transport = FakeTransport.new()
	launcher._handle('{"type":"welcome","seat":2,"match":"ABC234"}')
	runner.check(not wait.visible, "N18 seat 2 never sees the wait row")
	await runner.process_frame
	launcher.free()
	return true

func test_start_without_settings_is_a_protocol_error(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._set_busy(true)
	var message: Dictionary = _start_message("ashfall", 5)
	message.erase("settings")
	runner.check(not launcher._handle(JSON.stringify(message)), "N15 a start without settings is not accepted")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text.begins_with("Protocol error"), "N15 protocol error shown")
	runner.check(transport.close_calls == 1 and not launcher.get_node("Pages/Play/Footer/Create").disabled, "N15 transport closed once, Create usable")
	var other := FakeTransport.new()
	launcher._transport = other
	runner.check(not launcher._handle('{"type":"tick","seat":1,"tick":0}') and other.close_calls == 1, "N15 an unexpected message type closes the transport")
	launcher.free()
	return true

func test_both_seats_share_map_and_starts(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var chosen: Array[int] = MatchSettings.starts("ashfall", 11)
	var raw: Dictionary = MapData.load(MatchSettings.map_path("ashfall"))
	runner.check((chosen[0] - chosen[1] + 8) % 8 == 4, "N19 the seeded pair is diagonal, got %s" % str(chosen))
	for seat in [1, 2]:
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("ashfall", 11))
		runner.check(SkirmishMain.match_seed == 11, "N19 seat %d records the host's seed for reports, got %d" % [seat, SkirmishMain.match_seed])
		var main = runner.root.get_tree().current_scene
		var map: Dictionary = main.driver.pump.live().map_data()
		var cells: Array = [MapData.start_cell(map, 1), MapData.start_cell(map, 2)]
		runner.check(cells == [MapData.start_cell(raw, chosen[0]), MapData.start_cell(raw, chosen[1])], "N19 seat %d sim starts on the seeded cells, got %s" % [seat, str(cells)])
		runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(cells[seat - 1]) + Vector2(0.5, 0.5)), "N19 seat %d camera on its own base" % seat)
		main.free()
		await runner.process_frame
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_host_told_opponent_left_before_start(runner) -> bool:
	var notice: String = "Opponent left before the start (a different map or version, or their game tab was hidden)"
	var early: Dictionary = await _online(runner, 1)
	early.lockstep.receive('{"type":"left","seat":2,"after_tick":3}')
	_run(early.main, 12)
	runner.check(BaseScene.hud_text(early.main).contains(notice), "N16 left before the start is explained")
	_layout_ok(runner, early.main, "left before start")
	runner.check(not early.main.get_node("HUD/ResultPanel").visible, "N16 left before the start shows no result panel")
	early.main.free()
	var late: Dictionary = await _online(runner, 1)
	_peer_packets(late.transport, 2, 4, 40)
	late.lockstep.receive('{"type":"left","seat":2,"after_tick":40}')
	_run(late.main, 80)
	var text: String = BaseScene.hud_text(late.main)
	runner.check(text.contains("Player 2 disconnected") and not text.contains(notice), "N16 a later leave keeps the plain text, got " + text)
	late.main.free()
	return true

func test_opponent_left_mid_match(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, 40)
	online.lockstep.receive('{"type":"left","seat":2,"after_tick":40}')
	_run(main, 80)
	var panel: Control = main.get_node("HUD/ResultPanel")
	var cells: Array = main.get_node("HUD/ResultPanel/Center/Card/Box/Table").get_children()
	runner.check(panel.visible and main.get_node("HUD/ResultPanel/Center/Card/Box/Outcome").text == "Victory", "N29 the opponent leaving mid-match is a Victory")
	runner.check(_panel_line(main) == "Your opponent left" and _play_again_button(main).disabled, "N29 the line says the opponent left, Play again disabled, got '%s'" % _panel_line(main))
	runner.check(main.get_viewport().gui_get_focus_owner() == main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons/ChangeSetup"), "N29 Back to menu has the focus")
	runner.check(cells.size() == 12 and cells[4].text.ends_with("(you)") and not cells[8].text.contains("(you)"), "N29 the table shows both players, got %d cells" % cells.size())
	runner.check(BaseScene.hud_text(main).contains("Player 2 disconnected"), "N29 the status line keeps the disconnect text")
	BaseScene.slab_clear(runner, main, "N29")
	main.free()
	return true

const BACK_TO_MENU: String = "HUD/ResultPanel/Center/Card/Box/Buttons/ChangeSetup"

func _opponent_leaves(online: Dictionary) -> void:
	_peer_packets(online.transport, 2, 4, 40)
	online.lockstep.receive('{"type":"left","seat":2,"after_tick":40}')
	_run(online.main, 80)

func _focus_owner(main) -> Control:
	return main.get_viewport().gui_get_focus_owner()

func test_leave_panel_focus_after_pause(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	main.set_process(true)
	main._pause.open()
	_opponent_leaves(online)
	var menu_focus: Control = _focus_owner(main)
	runner.check(main.get_node("HUD/ResultPanel").visible and menu_focus != null and main._pause.is_ancestor_of(menu_focus), "N30 fixture: the panel is up and the pause menu holds the focus")
	main._pause.close()
	_run(main, 3)
	runner.check(_focus_owner(main) == main.get_node(BACK_TO_MENU), "N30 closing the pause menu hands the focus to Back to menu, got %s" % _focus_owner(main))
	main._pause.open()
	main._pause.close()
	_run(main, 3)
	runner.check(_focus_owner(main) == main.get_node(BACK_TO_MENU), "N30 opening and closing the pause menu with Back to menu focused returns the focus, got %s" % _focus_owner(main))
	main.free()
	return true

func test_leave_panel_yields_focus(runner) -> bool:
	var form: Dictionary = await _online(runner, 1)
	form.main.set_process(true)
	form.main._playtest._dialog.show()
	_opponent_leaves(form)
	runner.check(form.main.get_node("HUD/ResultPanel").visible and _focus_owner(form.main) != form.main.get_node(BACK_TO_MENU), "N31 the panel leaves the focus alone while the marker dialog is open, got %s" % _focus_owner(form.main))
	form.main.free()
	var typing: Dictionary = await _online(runner, 1)
	typing.main.set_process(true)
	var note := LineEdit.new()
	typing.main.get_node("HUD").add_child(note)
	note.grab_focus()
	_opponent_leaves(typing)
	runner.check(typing.main.get_node("HUD/ResultPanel").visible and _focus_owner(typing.main) == note, "N31 the panel leaves a focused text field alone, got %s" % _focus_owner(typing.main))
	typing.main.free()
	return true

func test_back_to_menu_once(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	main._playtest.set_active(false)
	_opponent_leaves(online)
	var closed_by_the_leave: int = online.transport.close_calls
	runner.check(_focus_owner(main) == main.get_node(BACK_TO_MENU), "N32 fixture: Back to menu has the focus")
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		main.get_viewport().push_input(event)
	runner.check(scenes.size() == 1 and _focus_owner(main) != main.get_node(BACK_TO_MENU), "N32 leaving releases the focus from Back to menu, scenes %d" % scenes.size())
	main.get_node("HUD/ResultPanel").change_setup_pressed.emit()
	runner.check(online.transport.close_calls == closed_by_the_leave + 1 and scenes.size() == 1, "N32 a second Enter on Back to menu leaves once, closes %d after %d, scenes %d" % [online.transport.close_calls, closed_by_the_leave, scenes.size()])
	main.free()
	return true

func test_pause_leave_mid_match_with_the_helper_on(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	main._playtest.set_active(true)
	main._playtest.begin_match()
	_peer_packets(online.transport, 2, 4, 40)
	_run(main, 20)
	main._pause.open()
	main._pause.leave_requested.emit()
	_run(main, 3)
	main._refresh()
	var status: String = BaseScene.hud_text(main)
	runner.check(main._playtest._active, "N33 fixture: the playtest helper is on")
	runner.check(scenes == ["res://scenes/launcher.tscn"], "N33 (F22) a deliberate leave reaches the launcher without waiting for the playtest form, got %s" % [scenes])
	runner.check(not status.contains("relay") and main.driver.notice() == "", "N33 (F22) a deliberate leave shows no relay loss, got '%s'" % main.driver.notice())
	main.free()
	PlaytestSession.current.discard()
	return true

func test_back_to_menu_after_the_review_files_the_match(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	main._playtest.set_active(true)
	main._playtest.begin_match()
	var filed_before: int = PlaytestSession.current.data.matches.size()
	_end_match(online)
	online.transport.is_closed = true
	_run(main, 2)
	main._playtest._process(0.0)
	var matches: Array = PlaytestSession.current.data.matches
	runner.check(matches.size() == filed_before + 1 and main._playtest.get_node("Checklist").visible and not main._playtest.holds_match(), "N35 fixture: the closed room's match is filed and the panel is open without holding the match, matches %d after %d" % [matches.size(), filed_before])
	main._playtest._dialog.hide()
	main.get_node("HUD/ResultPanel").change_setup_pressed.emit()
	runner.check(scenes == ["res://scenes/launcher.tscn"] and matches.size() == filed_before + 1, "N35 Back to menu after the review changes scene once and files no second match, scenes %s, matches %d after %d" % [scenes, matches.size(), filed_before])
	main.free()
	PlaytestSession.current.discard()
	return true

func _credits_wired(runner, shown: String, size: Vector2i) -> void:
	runner.check("Electronic Arts" in FileAccess.get_file_as_string("res://data/maps/NOTICE.md") and "Electronic Arts" in shown, "N10 Credits text carries the maps notice at %s" % size)
	var license_line: String = ""
	for line in Engine.get_license_text().split("\n"):
		if line.length() > 40:
			license_line = line
			break
	runner.check(not license_line.is_empty() and license_line in shown, "N10 Credits text carries Godot's licence text at %s" % size)
	var info: Dictionary = Engine.get_license_info()
	var info_line: String = ""
	for line in info[info.keys()[0]].split("\n"):
		if line.length() > 40 and "[" not in line:
			info_line = line
			break
	runner.check(Engine.get_copyright_info()[-1].name in shown, "N10 Credits text names an engine component at %s" % size)
	runner.check(not info_line.is_empty() and info_line in shown, "N10 Credits text carries an engine licence text at %s" % size)
	var at: Array[int] = []
	for heading in ["Wargrid ©", "\nMusic\n", "\nVoice: ", "\nMaps\n", "\nGodot Engine\n", "\nThird-party components in Godot\n"]:
		at.append(shown.find(heading))
	var ordered: bool = at[0] >= 0
	for i in range(1, at.size()):
		ordered = ordered and at[i] > at[i - 1]
	runner.check(ordered, "N10 Credits sections run Wargrid, Music, Voice, Maps, Godot, third-party at %s, got %s" % [size, at])

func test_credits_panel_layout(runner) -> bool:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		port.add_child(launcher)
		await runner.process_frame
		await runner.process_frame
		var panel: Control = launcher.get_node("Pages/Credits")
		runner.check(not panel.visible and launcher.get_node("Pages/Play").visible, "N10 Credits page starts hidden at %s" % size)
		launcher.get_node("Sidebar/Nav/Credits").button_pressed = true
		await runner.process_frame
		await runner.process_frame
		var text: RichTextLabel = panel.get_node("Body/Text")
		var legal: Control = panel.get_node("Body/Legal")
		var view := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(panel.visible and view.encloses(panel.get_global_rect()), "N10 Credits page inside the viewport at %s" % size)
		runner.check(not launcher.get_node("Pages/Play").visible, "N10 launcher controls hidden behind Credits at %s" % size)
		runner.check(panel.get_global_rect().encloses(text.get_global_rect()) and panel.get_global_rect().encloses(legal.get_global_rect()) and not text.get_global_rect().intersects(legal.get_global_rect()), "N10 Text and Legal fit the page at %s" % size)
		runner.check("Zhelanov" in text.get_parsed_text(), "N10 Credits text names the composers at %s" % size)
		_credits_wired(runner, text.get_parsed_text(), size)
		launcher.get_node("Sidebar/Nav/Play").button_pressed = true
		runner.check(not panel.visible and launcher.get_node("Pages/Play").visible, "N10 Play returns to the launcher at %s" % size)
		launcher.free()
		port.free()
	return true

func test_online_playtest_record(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, PEER_TICKS)
	_run(main, 10)
	var record: Dictionary = main.playtest_match()
	runner.check(record.mode == "online" and record.build == PlaytestSettings.build_id(), "N-PT1 the online record names its mode and build")
	runner.check(not record.has("tick_hashes"), "N-PT1 the online record carries no tick_hashes")
	runner.check(record.commands == Lockstep.log_lines(online.lockstep.command_log()) and record.commands.size() >= 1, "N-PT1 the record holds the lockstep command lines")
	runner.check(main.playtest_context().over == false, "N-PT1 a running online match is not over")
	main.free()
	return true

func _launcher(runner, parent: Node, prerelease: bool, search: String = "", page: String = "", first_visit: bool = true):
	if first_visit: LauncherScript.code_applied = false
	var launcher = Launcher.instantiate()
	launcher.prerelease = prerelease
	launcher.search = search
	launcher.page = page
	parent.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	return launcher

func test_launcher_release_hides_relay(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-release-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = await _launcher(runner, port, false)
		_force_visible(launcher)
		await runner.process_frame
		await runner.process_frame
		var box: Control = launcher.get_node("Pages/Play/Body")
		var relay: LineEdit = box.get_node("Advanced/RelayUrl")
		runner.check(not box.get_node("Advanced").visible and not relay.visible, "N21 release hides the fold and the relay field at %s" % size)
		runner.check(relay.text == JoinLink.DEFAULT_RELAY, "N21 release keeps the default relay at %s" % size)
		launcher._set_busy(true)
		runner.check(not relay.editable, "N21 busy locks the hidden relay field at %s" % size)
		launcher._set_busy(false)
		runner.check(relay.editable, "N21 idle unlocks the hidden relay field at %s" % size)
		await _page_controls_ok(runner, launcher, size, "N21", ["Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl"])
		launcher.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func _page_case(runner, prerelease: bool, search: String, label: String) -> Dictionary:
	var launcher = await _launcher(runner, runner.root, prerelease, search)
	var pages: Control = launcher.get_node("Pages")
	runner.check(launcher._transport == null and not launcher.is_processing(), "N22 page address never connects: %s" % label)
	var result := {"code": pages.get_node("Join/Body/Code").text, "relay": pages.get_node("Play/Body/Advanced/RelayUrl").text, "relay_visible": pages.get_node("Play/Body/Advanced/RelayUrl").visible, "open": pages.get_node("Play/Body/Advanced/Toggle").button_pressed}
	launcher.free()
	return result

func test_launcher_prefills_from_page(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-prefill-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var both: String = "?code=abc234&relay=wss%3A%2F%2Fx.example%2Fws"
	var release: Dictionary = await _page_case(runner, false, both, "release")
	runner.check(release.code == "ABC234" and release.relay == JoinLink.DEFAULT_RELAY and not release.relay_visible, "N22 release takes the code and ignores ?relay=")
	var dev: Dictionary = await _page_case(runner, true, both, "prerelease")
	runner.check(dev.code == "ABC234" and dev.relay == "wss://x.example/ws" and dev.relay_visible and dev.open, "N22 prerelease takes the code and the relay and opens the fold")
	var bad_relay: Dictionary = await _page_case(runner, true, "?relay=https%3A%2F%2Fx.example%2Fws&code=ABC2345", "bad relay and code")
	runner.check(bad_relay.relay == JoinLink.DEFAULT_RELAY and not bad_relay.open and bad_relay.code == "", "N22 a bad relay and a 7-character code are ignored")
	var oversize: Dictionary = await _page_case(runner, true, "?code=" + "A".repeat(3000), "oversize")
	runner.check(oversize.code == "", "N22 an oversize query is ignored")
	var first = await _launcher(runner, runner.root, true, both)
	var back = await _launcher(runner, runner.root, true, both, "", false)
	var back_pages: Control = back.get_node("Pages")
	runner.check(first.get_node("Pages/Join/Body/Code").text == "ABC234", "N22 the first visit takes the code")
	runner.check(back_pages.get_node("Join/Body/Code").text == "" and back_pages.get_node("Play/Body/Advanced/RelayUrl").text == "wss://x.example/ws" and back_pages.get_node("Play/Body/Advanced/Toggle").button_pressed, "N22 a return to the launcher drops the code and keeps the relay")
	first.free()
	back.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

const RELAY_HELP := "Relay server: matches players online. Test builds only; leave it unless you are trying another relay."

func test_launcher_relay_help(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-relay-help-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = await _launcher(runner, port, true)
		_force_visible(launcher)
		await runner.process_frame
		var box: Control = launcher.get_node("Pages/Play/Body")
		var help: Label = box.get_node_or_null("Advanced/RelayHelp")
		runner.check(help != null and not help.visible, "N26 RelayHelp exists and is hidden while the fold is closed at %s" % size)
		if help == null:
			launcher.free()
			port.free()
			continue
		box.get_node("Advanced/Toggle").button_pressed = true
		await runner.process_frame
		await runner.process_frame
		var relay: LineEdit = box.get_node("Advanced/RelayUrl")
		runner.check(help.visible and help.text == RELAY_HELP, "N26 opening the fold shows the exact caption at %s" % size)
		runner.check(help.get_index() == relay.get_index() - 1, "N26 caption sits directly above the relay field at %s" % size)
		var view := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(view.encloses(help.get_global_rect()), "N26 caption inside %s" % size)
		for path: String in LAUNCHER_PAGE_PATHS["Play:friend"]:
			var control: Control = launcher.get_node_or_null("Pages/Play/" + path)
			if control == null or control == help or not control.visible: continue
			runner.check(not control.get_global_rect().intersects(help.get_global_rect()), "N26 caption does not overlap %s at %s" % [path, size])
		var height: float = box.get_combined_minimum_size().y
		print("N26 prerelease fold-open worst-case Pages/Play/Body at %s: %s x %s" % [size, box.get_global_rect().size.x, height])
		runner.check(height <= 720.0 and box.get_global_rect().size.x < 1100.0, "N26 worst-case body %s fits 720 high and under 1100 wide at %s" % [box.get_global_rect().size, size])
		launcher._fail("A very long relay reason that wraps over many lines. ".repeat(8))
		await runner.process_frame
		await runner.process_frame
		var pages: Control = launcher.get_node("Pages")
		var view_rect := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(pages.get_combined_minimum_size().y <= 720.0, "N26 a long Status keeps the worst-case Play page needing at most 720 high at %s, got %s" % [size, pages.get_combined_minimum_size().y])
		runner.check(view_rect.encloses(launcher.get_node("Pages/Play/Footer/Status").get_global_rect()) and view_rect.encloses(launcher.get_node("Pages/Play/Footer/Start").get_global_rect()), "N26 a long Status keeps Status and Start inside the viewport at %s" % size)
		launcher.free()
		var opened = await _launcher(runner, port, true, "?relay=wss%3A%2F%2Fx.example%2Fws")
		runner.check(opened.get_node("Pages/Play/Body/Advanced/RelayHelp").visible, "N26 ?relay= opens the fold with the caption at %s" % size)
		opened.free()
		var release = await _launcher(runner, port, false, "?relay=wss%3A%2F%2Fx.example%2Fws")
		runner.check(not release.get_node("Pages/Play/Body/Advanced/RelayHelp").visible, "N26 release hides the caption on load and ignores ?relay= at %s" % size)
		runner.check(release.get_node("Pages/Play/Body").get_combined_minimum_size().y <= 720.0 or size.y > 720, "N26 release box fits at %s" % size)
		release.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func test_copy_link_on_web(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-copy-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var launcher = await _launcher(runner, runner.root, true, "", "https://wargrid-web-test.fly.dev/")
	launcher._code = "ABC234"
	runner.check(launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").text == "Copy link", "N23 Copy reads Copy link on the web")
	runner.check(launcher._copy_text() == "https://wargrid-web-test.fly.dev/?code=ABC234", "N23 the link carries the code only for the default relay")
	launcher.get_node("Pages/Play/Body/Advanced/RelayUrl").text = "wss://x.example/ws"
	runner.check(launcher._copy_text().ends_with("&relay=wss%3A%2F%2Fx.example%2Fws"), "N23 a non-default relay rides along")
	launcher.free()
	var desktop = await _launcher(runner, runner.root, true)
	desktop._code = "ABC234"
	runner.check(desktop.get_node("Pages/Waiting/Body/Left/Invite/Copy").text == "Copy code" and desktop._copy_text() == "ABC234", "N23 off the web Copy copies the bare code")
	desktop.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func _ic_row(main, transport: FakeTransport, step: int, seen: Array, status: bool = false) -> String:
	var sent: Array = _own_commands(transport)
	var added: PackedStringArray = []
	for command: Dictionary in sent.slice(mini(seen[0], sent.size())): added.append(JSON.stringify(command))
	seen[0] = sent.size()
	var row: String = "%d|sel=%s|bld=%d|insp=%d|place=%s|sub=%s|am=%s|esc=%s|menu=%s|perf=%s|%s" % [step, main.orders.selected_ids, main.orders.selected_building_id, main.orders.inspected_id, main.orders._placement_kind, main.orders._sub_grid, main.orders._attack_move_mode, main._escape_pending(), main.menu_open(), main._perf.visible, ";".join(added)]
	return row + "|refusal=" + main.hud.refusal if status else row

func _ic_esc(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	var pass_on: bool = not main._pause.visible and main._escape_pending()
	main._input(event)
	if pass_on: main._unhandled_input(event)

func _ic_plane(main, id: int) -> Vector2:
	var unit: Dictionary = _entity(main, id)
	return Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))

func _ic_first_difference(rows: PackedStringArray, expected: PackedStringArray) -> int:
	for i in maxi(rows.size(), expected.size()):
		if i >= rows.size() or i >= expected.size() or rows[i] != expected[i]: return i
	return -1

func test_input_script_online(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var transport: FakeTransport = online.transport
	_peer_packets(transport, 2, 4, 200)
	_run(main, 8)
	runner.check(not _entity(main, 3).is_empty(), "IC2 fixture: the own start unit exists")
	var seen: Array = [0]
	var rows := PackedStringArray()
	var step = func(number: int, frames: int, status: bool = false) -> void:
		_run(main, frames)
		rows.append(_ic_row(main, transport, number, seen, status))
	var commands = func(type: String) -> int: return _own_commands(transport).filter(func(command: Dictionary) -> bool: return command.type == type).size()
	var box = func() -> Array: return [_ic_plane(main, 3) - Vector2.ONE * 40.0, _ic_plane(main, 3) + Vector2.ONE * 40.0]
	var corners: Array = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	step.call(1, 3)
	runner.check(main.orders.selected_ids.has(3), "IC2 step 1 took effect")
	helper.pointer(main, Iso.world_to_plane(Vector2(12.5, 18.5)), MOUSE_BUTTON_RIGHT, true)
	step.call(2, 3)
	runner.check(commands.call("move") == 1, "IC2 step 2 took effect")
	helper.key(main, KEY_S)
	step.call(4, 3)
	runner.check(commands.call("stop") == 0, "IC2 step 4 S on a lone builder sends no stop (3-14)")
	corners = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_S)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	step.call(6, 3)
	runner.check(commands.call("stop") == 0 and main.orders.selected_ids.has(3), "IC2 step 6 took effect")
	_ic_esc(main)
	step.call(7, 3)
	runner.check(main.orders.selected_ids.is_empty(), "IC2 step 7 took effect")
	_ic_esc(main)
	runner.check(main.menu_open(), "IC2 step 8 opened the menu")
	_ic_esc(main)
	step.call(8, 3)
	runner.check(not main.menu_open(), "IC2 step 8 took effect")
	var at: Vector2 = _ic_plane(main, 3) + Vector2(0, -8)
	helper.pointer(main, at, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, at, MOUSE_BUTTON_LEFT, false)
	helper.build_key(main, "usa_power_plant")
	step.call(9, 3, true)
	runner.check(not main.orders._placement_kind.is_empty(), "IC2 step 9 took effect")
	helper.key(main, KEY_F3)
	step.call(10, 3)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	step.call(11, 3)
	runner.check(commands.call("build") == 1, "IC2 step 11 took effect")
	corners = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_Q)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders._placement_kind.is_empty(), "IC2 step 17 a card key during the drag pressed nothing")
	helper.build_key(main, "usa_power_plant")
	step.call(17, 3)
	runner.check(not main.orders._placement_kind.is_empty(), "IC2 step 17 took effect")
	_ic_esc(main)
	_ic_esc(main)
	step.call(18, 3)
	runner.check(main.orders._placement_kind.is_empty() and main.orders.selected_ids.is_empty(), "IC2 step 18 took effect")
	var first: int = _ic_first_difference(rows, IcRows.IC2_ROWS)
	runner.check(first == -1, "IC2 row %d matches the chain recorded 2026-11-14, got %s" % [first, rows[first] if first >= 0 and first < rows.size() else "no row"])
	main.free()
	return true

func test_launcher_reads_no_page_off_web(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.check(launcher.get("page") == "" and launcher.get("search") == "", "N24 a headless launcher reads no page address")
	launcher.free()
	return true

func _run_until_answered(main, frames: int) -> void:
	for i in frames:
		if main.orders._awaiting_build.is_empty(): return
		BaseScene.tick(main)

func test_hint_outlives_an_earlier_order(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, 200)
	_run(main, 8)
	main.orders.selected_ids.assign([3])
	main._refresh()
	var stops = func() -> int: return online.lockstep.command_log().filter(func(command: Dictionary) -> bool: return command.type == "stop" and command.player == 1).size()
	main._submit({"type": "stop", "entity_ids": [3]})
	main.orders.selected_ids.clear()
	main.orders._open_build()
	_run(main, 30)
	runner.check(stops.call() == 1, "RN3 online fixture: the earlier stop was played and answered, got %d" % stops.call())
	runner.check(main.hud.refusal == "Choose one builder" and main.get_node("HUD/Hud/RefusalLine").visible, "RN3 online: the earlier order's answer leaves the later hint, got '%s'" % main.hud.refusal)
	main._submit({"type": "stop", "entity_ids": [3]})
	_run(main, 30)
	runner.check(stops.call() == 2 and main.hud.refusal.is_empty() and not main.get_node("HUD/Hud/RefusalLine").visible, "RN3 online: an order sent after the hint clears it, got '%s'" % main.hud.refusal)
	main.free()
	return true

func test_sb2_online_placement_closes_and_reopens(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var transport: FakeTransport = online.transport
	_peer_packets(transport, 2, 4, 200)
	_run(main, 8)
	main.orders.selected_ids.assign([3])
	main._refresh()
	var builds = func() -> int: return _own_commands(transport).filter(func(command: Dictionary) -> bool: return command.type == "build").size()
	helper.build_key(main, "usa_power_plant")
	var kind: String = main.orders._placement_kind
	helper.pointer(main, Iso.world_to_plane(Vector2(-3.5, -3.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(not kind.is_empty() and main.orders._placement_kind.is_empty(), "RA8 a build click closes placement at once")
	_run_until_answered(main, 30)
	runner.check(main.orders._placement_kind == kind and not main.hud.refusal.is_empty(), "RA8 a refusal reopens placement with the same kind, got '%s' '%s'" % [main.orders._placement_kind, main.hud.refusal])
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders._placement_kind.is_empty(), "RA8 an accepted build click closes placement in the same frame")
	helper.build_key(main, "usa_power_plant")
	helper.pointer(main, Iso.world_to_plane(Vector2(14.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	_run_until_answered(main, 30)
	_run(main, 3)
	runner.check(main.orders._awaiting_build.is_empty(), "RA8 the accepted build answer arrives")
	runner.check(builds.call() == 2, "RA8 a placement click while a build answer is pending is ignored, builds %d" % builds.call())
	main.free()
	return true

func test_sb2_online_refusal_keeps_new_gesture(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var transport: FakeTransport = online.transport
	_peer_packets(transport, 2, 4, 200)
	_run(main, 8)
	var count = func(type: String) -> int: return _own_commands(transport).filter(func(command: Dictionary) -> bool: return command.type == type).size()
	main.orders.selected_ids.assign([3])
	main._refresh()
	helper.build_key(main, "usa_power_plant")
	helper.pointer(main, Iso.world_to_plane(Vector2(-3.5, -3.5)), MOUSE_BUTTON_LEFT, false)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, true)
	_run_until_answered(main, 30)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	_run(main, 3)
	runner.check(not main.hud.refusal.is_empty() and count.call("build") == 1, "RA9 a refusal during a selection click does not turn its release into a build, builds %d" % count.call("build"))
	main.orders.selected_ids.assign([3])
	main._refresh()
	helper.build_key(main, "usa_power_plant")
	helper.pointer(main, Iso.world_to_plane(Vector2(-3.5, -3.5)), MOUSE_BUTTON_LEFT, false)
	main.orders.arm_attack_move()
	_run_until_answered(main, 30)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	_run(main, 3)
	runner.check(count.call("build") == 2 and count.call("attack_move") == 1, "RA9 a refusal in attack-move mode keeps the attack-move click, builds %d attack moves %d" % [count.call("build"), count.call("attack_move")])
	main.free()
	return true

func test_sb2_online_refusal_after_a_later_gesture(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, 200)
	_run(main, 8)
	main._refresh()
	var rows = main.shown_state.units
	var at: int = rows.index_of(3)
	runner.check(at != -1, "RA10 fixture: builder 3 is shown")
	if at == -1: return true
	var second: int = main.driver.pump.live().spawn(1, Vector2(rows.x[at] + 1.0, rows.y[at]), "usa_builder")
	_run(main, 1)
	runner.check(second != -1, "RA10 fixture: a second own builder")
	var ground: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5))
	var gestures: Dictionary = {
		"another builder selected": func() -> void:
			main.orders.selected_ids.assign([second])
			main._refresh(),
		"attack move then a ground click": func() -> void:
			main.orders.arm_attack_move()
			helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
			helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false),
		"a right-click move": func() -> void: helper.pointer(main, ground, MOUSE_BUTTON_RIGHT, true),
		"Esc, then the same builder again": func() -> void:
			helper.key(main, KEY_ESCAPE)
			main.orders.selected_ids.assign([3])
			main._refresh(),
		"nothing": func() -> void: pass,
	}
	for gesture: String in gestures:
		main.orders.selected_ids.assign([3])
		main._refresh()
		helper.build_key(main, "usa_power_plant")
		var kind: String = main.orders._placement_kind
		helper.pointer(main, Iso.world_to_plane(Vector2(-3.5, -3.5)), MOUSE_BUTTON_LEFT, false)
		gestures[gesture].call()
		_run_until_answered(main, 30)
		var reopened: bool = main.orders._placement_kind == kind
		runner.check(not kind.is_empty() and main.orders._awaiting_build.is_empty() and not main.hud.refusal.is_empty() and reopened == (gesture == "nothing"), "RA10 %s before the refusal answer: placement reopened %s, got '%s'" % [gesture, gesture == "nothing", main.orders._placement_kind])
		if not main.orders._placement_kind.is_empty(): main.orders._clear_placement()
	main.free()
	return true

func _builder(main, owner: int) -> int:
	var rows = main.driver.pump.live().view_state().units
	for i in rows.size():
		if rows.owner[i] == owner and rows.kinds[rows.kind[i]].ends_with("_builder"): return rows.id[i]
	return -1

func _place(main) -> void:
	main.orders.selected_ids.assign([_builder(main, 1)])
	main._refresh()
	BaseScene.new().build_key(main, "usa_power_plant")

func test_sb2_online_preview_waits_for_step(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var view = main.get_node("WorldView")
	_peer_packets(online.transport, 2, 4, 12)
	_run(main, 8)
	_place(main)
	helper.hover(main, Iso.world_to_plane(Vector2(10.5, 10.5)))
	var tick: int = -1
	for i in 30:
		if main.driver._lockstep.status() == "waiting" and main.driver.pump.live().tick() == tick: break
		tick = main.driver.pump.live().tick()
		_run(main, 1)
	runner.check(main.driver._lockstep.status() == "waiting" and main.driver.preview_answer().get("origin") == Vector2i(10, 10) and view._preview_valid, "RP4 fixture: answered before the stall, got %s %s" % [main.driver._lockstep.status(), main.driver.preview_answer()])
	helper.hover(main, Iso.world_to_plane(Vector2(-3.5, -3.5)))
	_run(main, 1)
	runner.check(main.driver.pump.live().tick() == tick and main.driver.preview_answer().get("origin") == Vector2i(10, 10) and view._preview_valid, "RP4 a stalled frame answers no preview, got %s" % [main.driver.preview_answer()])
	_peer_packets(online.transport, 2, 13, PEER_TICKS)
	_run(main, 1)
	runner.check(main.driver.preview_answer().get("origin") == main.orders._preview_origin and not view._preview_valid, "RP4 the next step answers the current origin, got %s" % [main.driver.preview_answer()])
	main.free()
	return true

func test_sb2_preview_after_catch_up(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, 8)
	_run(main, 16)
	_place(main)
	BaseScene.new().hover(main, Iso.world_to_plane(Vector2(10.5, 10.5)))
	var tick: int = main.driver.pump.live().tick()
	runner.check(main.driver.preview_answer().is_empty() and not main.orders._placement_kind.is_empty(), "RP8 fixture: placing with a pending request, got %s" % [main.driver.preview_answer()])
	var builder: int = _builder(main, 1)
	var free: bool = main.driver.pump.live().preview_build(1, builder, main.orders._placement_kind, Vector2i(10, 10)).ok
	var block := {"type": "build", "builder_id": _builder(main, 2), "building_kind": "usa_power_plant", "origin": [10, 10], "tick": tick + 1, "player": 2, "sequence": 1}
	for t in range(9, PEER_TICKS + 1):
		online.transport.frames.append(Wire.encode(Wire.tick_message(2, t, [block] if t == tick + 1 else [], null)))
	_run(main, 1)
	var answer: Dictionary = main.driver.preview_answer()
	runner.check(main.driver.pump.live().tick() == tick + 2 and free, "RP8 fixture: two ticks in one frame, spot free before, got %d %s" % [main.driver.pump.live().tick() - tick, free])
	runner.check(answer.get("origin") == Vector2i(10, 10) and not answer.ok and main.get_node("WorldView")._preview_valid == answer.ok, "RP8 the answer reflects the second tick (spot taken), got %s" % [answer])
	main.free()
	return true

func test_sb2_rematch_drops_pending_preview(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	main.driver.request_preview({"player": 2, "builder_id": _builder(main, 2), "kind": "usa_power_plant", "origin": Vector2i(10, 10)})
	var old_sim = main.driver.pump.live()
	online.transport.frames.append(_rematch_start(99))
	_peer_packets(online.transport, 1, 4, 4)
	_run(main, 1)
	runner.check(not is_same(main.driver.pump.live(), old_sim), "RP5 fixture: the rematch built a new match")
	_peer_packets(online.transport, 1, 5, 12)
	_run(main, 2)
	runner.check(main.driver.preview_answer().is_empty() and main.get_node("WorldView")._preview_cells.is_empty(), "RP5 a rematch drops the pending preview, got %s" % [main.driver.preview_answer()])
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_sb3_online_two_notes(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_double_build(online)
	_run(main, 10)
	_peer_packets(online.transport, 2, 4, PEER_TICKS)
	main.set_process(true)
	var director = main._sound.director
	var before: int = director.collected_ticks().size()
	var visuals := VisualSpy.new()
	main._visuals = visuals
	main._view.set_visuals(visuals)
	main._physics_process(1.0 / 30.0)
	main._drain_notes()
	var ticks: Array[int] = director.collected_ticks().slice(before)
	runner.check(ticks == [5, 6] and main.driver.current().tick == 6, "SB3 one drain collects both catch-up ticks in order, got %s and tick %d" % [ticks, main.driver.current().tick])
	var rows = func(results: Array) -> Array: return results.map(func(result: Dictionary) -> Array: return [result.tick, result.player, result.sequence, result.ok, result.error])
	var faction_rows: Array = [[4, 1, 0, true, ""], [4, 2, 0, true, ""]]
	var build_rows: Array = [[5, 1, 1, true, ""], [5, 1, 2, false, DUE_REJECTION]]
	runner.check(rows.call(director.pending_step(before).results) == faction_rows and rows.call(director.pending_step(before + 1).results) == build_rows, "SB3 sound gets each tick's own results, got %s and %s" % [rows.call(director.pending_step(before).results), rows.call(director.pending_step(before + 1).results)])
	runner.check(rows.call(main.stepped_results) == faction_rows + build_rows, "SB3 stepped results hold both ticks' results in order, got %s" % [rows.call(main.stepped_results)])
	main._refresh()
	runner.check(visuals.ticks == [5, 6], "SB3 the view consumes both ticks' visuals in order, got %s" % [visuals.ticks])
	main.free()
	return true

func test_too_many_orders_note(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_run(main, 1)
	var order := {"type": "move", "entity_ids": range(1, 301), "target": [10.5, 10.5]}
	for i in 200: main._submit(order)
	_run(main, 1)
	var status: String = BaseScene.hud_text(main)
	runner.check(status.contains(main.driver.TOO_MANY_ORDERS), "N-cap the HUD shows the refused order, got " + status)
	_layout_ok(runner, main, "too many orders")
	main.free()
	return true

func _sent_ticks(transport: FakeTransport) -> Array[int]:
	var ticks: Array[int] = []
	for text in transport.sent:
		var message: Dictionary = Wire.decode(text).message
		if message.type == "tick": ticks.append(message.tick)
	return ticks

func _contiguous(ticks: Array[int], first: int) -> bool:
	for i in ticks.size():
		if ticks[i] != first + i: return false
	return not ticks.is_empty()

func _end_in_catch_up(runner, online: Dictionary, last_peer_tick: int, extra: Array) -> void:
	var transport: FakeTransport = online.transport
	var driver = online.main.driver
	_peer_packets(transport, 1, 4, 8)
	_run(online.main, 12)
	runner.check(driver.current().tick == 9 and driver._credit == 3 and driver.CATCH_UP_STEPS == 2, "SB4 fixture: stalled at tick 9 with credit 3 and two takes per callback, got %d %d %d" % [driver.current().tick, driver._credit, driver.CATCH_UP_STEPS])
	driver.pump.live().remove_object(4)
	driver.pump.live().remove_object(6)
	_peer_packets(transport, 1, 9, 9)
	if last_peer_tick >= 10:
		_peer_stop(transport, 10)
		_peer_packets(transport, 1, 11, last_peer_tick)
	for frame: String in extra: transport.frames.append(frame)
	_run(online.main, 1)
	runner.check(driver.get("_next_tick") == mini(last_peer_tick, 10) + 1, "SB4 fixture: the last frame took tick 9 and, with a peer packet for 10, tick 10, got next %s" % driver.get("_next_tick"))

func test_sb4_take_ahead_past_end(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var driver = online.main.driver
	_end_in_catch_up(runner, online, PEER_TICKS, [])
	runner.check(driver.current().tick == 10 and driver.over() and driver.record().match.status != "ongoing", "SB4 the match ends at tick 10, got %d %s" % [driver.current().tick, driver.record().match])
	runner.check(online.lockstep.command_log().all(func(command: Dictionary) -> bool: return command.tick != 10), "SB4 the take past the end logs no tick-10 command")
	var ticks: Array[int] = _sent_ticks(online.transport)
	runner.check(_contiguous(ticks, 4) and ticks[-1] == 14, "SB4 packets end with 14, each once, no 15, got %s" % [ticks])
	runner.check(_sent_types(online.transport, "over") == 1, "SB4 one over, got %d" % _sent_types(online.transport, "over"))
	runner.check(online.lockstep.status() == "running" and driver.notice() == "", "SB4 status running, no notice, got %s '%s'" % [online.lockstep.status(), driver.notice()])
	runner.check(driver.record().tick == 10, "SB4 record at tick 10, got %d" % driver.record().tick)
	online.main.free()
	return true

func test_sb4_leave_on_end_tick_catch_up(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var driver = online.main.driver
	_end_in_catch_up(runner, online, 9, [Wire.encode({"type": "left", "seat": 1, "after_tick": 9})])
	runner.check(online.lockstep.status() == "running" and not driver.opponent_left(), "SB4 a leave after the end tick is a normal end, got " + online.lockstep.status())
	runner.check(_sent_types(online.transport, "over") == 1, "SB4 one over, got %d" % _sent_types(online.transport, "over"))
	runner.check(driver.rematch_line() == "Your friend left", "SB4 friend-left line, got '%s'" % driver.rematch_line())
	online.main.free()
	return true

func test_sb4_no_waiting_after_end(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_in_catch_up(runner, online, 9, [])
	_run(main, 3)
	runner.check(online.lockstep.status() == "running" and main.driver.notice() == "", "SB4 no waiting after the end, got %s '%s'" % [online.lockstep.status(), main.driver.notice()])
	runner.check(not BaseScene.hud_text(main).contains("Waiting"), "SB4 no waiting line, got " + BaseScene.hud_text(main))
	main.free()
	return true

func test_sb4_three_callbacks_one_drain(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var driver = main.driver
	_run(main, 10)
	runner.check(driver.current().tick == 4 and driver._credit == driver.MAX_CATCH_UP_CREDIT, "SB4 fixture: stalled at tick 4 with full credit, got %d %d" % [driver.current().tick, driver._credit])
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	for i in 3: main._physics_process(1.0 / 30.0)
	main._drain_notes()
	runner.check(online.lockstep.status() == "running" and driver.notice() == "", "SB4 no self-waiting after three callbacks, got %s '%s'" % [online.lockstep.status(), driver.notice()])
	var tick: int = driver.current().tick
	runner.check(tick == 9, "SB4 three callbacks advance to tick 9, the sixth take waiting for the drain, got %d" % tick)
	_run(main, 3)
	runner.check(driver.current().tick > tick and _contiguous(_sent_ticks(online.transport), 4), "SB4 the ticks go on and own packets stay contiguous, got %d %s" % [driver.current().tick, _sent_ticks(online.transport)])
	main.free()
	return true

func test_sb4_publish_is_not_a_tick(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	var logged: int = online.lockstep.command_log().size()
	var sent: int = online.transport.sent.size()
	var tick: int = main.driver.current().tick
	BaseScene.publish(main)
	runner.check(online.lockstep.command_log().size() == logged and online.transport.sent.size() == sent, "SB4 a publish records and sends nothing")
	_run(main, 1)
	runner.check(main.driver.current().tick == tick + 1, "SB4 the next frame advances one tick, got %d from %d" % [main.driver.current().tick, tick])
	main.free()
	return true

func test_sb4_rematch_starts_from_new_pump(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	var old_lockstep = main.driver._lockstep
	# Tick 0 holds no units, so only another map makes a stale start digest differ from the new one.
	SkirmishMain.map_path = MatchSettings.map_path("dry_wells")
	online.transport.frames.append(_rematch_start(99))
	_peer_packets(online.transport, 1, 4, 4)
	_run(main, 1)
	var digest: String = StateHash.digest(main.driver.pump.live().snapshot())
	runner.check(old_lockstep.hash_rows()[0] != "0\t" + digest, "SB4 fixture: the old match's tick 0 differs from the rematch's, got %s" % old_lockstep.hash_rows()[0])
	runner.check(not is_same(main.driver._lockstep, old_lockstep) and main.driver._lockstep.hash_rows() == PackedStringArray(["0\t" + digest]), "SB4 the new lockstep's row 0 is the new match's tick-0 digest, got %s" % [main.driver._lockstep.hash_rows()])
	var last: Dictionary = Wire.decode(online.transport.sent[-1]).message
	runner.check(last.type == "tick" and last.tick == 4 and last.get("hash", {}).get("tick") == 0 and last.get("hash", {}).get("value") == digest, "SB4 the last frame is the new tick 4 with that hash, got %s" % [last])
	_run(main, 6)
	# Lockstep.take now refuses any other tick, so the driver's count must restart with the new match.
	runner.check(main.driver.current().tick == 5 and main.driver._lockstep._next_tick == 5 and main.driver.get("_next_tick") == 5, "SB4 the rematch takes ticks 0-4 in order, got %d %d %s" % [main.driver.current().tick, main.driver._lockstep._next_tick, main.driver.get("_next_tick")])
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

# No file: N2 writes and deletes the seat-2 report, and suite shards would race on that path.
func test_sb4_desync_report_ring(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var downloads: Array = []
	main.driver.web = true
	main.driver.download = func(buffer: PackedByteArray, _file_name: String, _mime: String) -> void: downloads.append(buffer)
	_peer_packets(online.transport, 1, 4, 33)
	online.transport.frames.append(Wire.encode(Wire.tick_message(1, 34, [], {"tick": 30, "value": "0000000000000000"})))
	_run(main, 40)
	runner.check(downloads.size() == 1, "SB4 one report download, got %d" % downloads.size())
	var report = JSON.parse_string(downloads[0].get_string_from_utf8()) if downloads.size() == 1 else null
	runner.check(report is Dictionary and report.get("hash_ring") == Array(main.driver.pump.live().hash_ring()) and not report.hash_ring.is_empty(), "SB4 the report's ring is the live ring at the desync")
	runner.check(report is Dictionary and report.tick == 30 and report.hash_rows.size() == 2 and report.hash_rows[-1].begins_with("30\t"), "SB4 the report's rows end with the desync tick 30, got %s" % [report.get("hash_rows") if report is Dictionary else null])
	runner.check(report is Dictionary and report.snapshot.get("tick") == 30 and main.driver.current().tick > 30, "SB4 the report's snapshot is tick 30's job snapshot, not the live state, got %s at %d" % [report.snapshot.get("tick") if report is Dictionary else null, main.driver.current().tick])
	main.free()
	return true

func test_sb4_no_send_after_end(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var driver = main.driver
	_run(main, 10)
	_peer_packets(online.transport, 1, 4, 5)
	_peer_stop(online.transport, 6)
	_peer_packets(online.transport, 1, 7, PEER_TICKS)
	var kept: Array[int] = _sent_ticks(online.transport)
	driver._lockstep._queue.append({"type": "move", "entity_ids": range(1, 20000), "target": [10.5, 10.5], "tick": 9, "player": 2, "sequence": 1})
	for i in 3: main._physics_process(1.0 / 30.0)
	main._drain_notes()
	runner.check(online.lockstep.status() == "ended_protocol" and online.lockstep.end_reason().begins_with("own frame"), "SB4 the oversized own frame ends the match, got %s '%s'" % [online.lockstep.status(), online.lockstep.end_reason()])
	runner.check(_sent_ticks(online.transport) == kept, "SB4 nothing is sent after the failing frame, got %s from %s" % [_sent_ticks(online.transport), kept])
	var factions: Array = online.lockstep.command_log().filter(func(command: Dictionary) -> bool: return command.tick == 4 and command.type == "choose_faction")
	runner.check(factions.size() == 2, "SB4 the recorded tick 4 keeps both faction choices, got %d" % factions.size())
	runner.check(online.lockstep.command_log().any(func(command: Dictionary) -> bool: return command.tick == 6 and command.type == "stop"), "SB4 a note after the end still records its tick 6")
	main.free()
	return true

func test_sb4_foreign_note_ends_match(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var driver = main.driver
	_peer_packets(online.transport, 1, 4, 8)
	_peer_stop(online.transport, 9)
	_peer_packets(online.transport, 1, 10, PEER_TICKS)
	_run(main, 8)
	var t: int = driver.current().tick
	runner.check(t == 8, "SB4 fixture: steady at tick 8 before the stop at 9, got %d" % t)
	var kept: Array[int] = _sent_ticks(online.transport)
	main._physics_process(1.0 / 30.0)
	runner.check(driver.get("_next_tick") == t + 1, "SB4 fixture: one callback takes tick %d only, got %s" % [t, driver.get("_next_tick")])
	var job := SimPump.Job.new()
	job.step = false
	driver.pump.post(job)
	main._physics_process(1.0 / 30.0)
	main._drain_notes()
	runner.check(online.lockstep.status() == "ended_protocol" and online.lockstep.end_reason().begins_with("note at tick"), "SB4 a foreign note between two ticks ends the match, got %s '%s'" % [online.lockstep.status(), online.lockstep.end_reason()])
	runner.check(online.lockstep.command_log().all(func(command: Dictionary) -> bool: return command.tick != t + 1), "SB4 the mispaired tick %d is not recorded" % (t + 1))
	var ticks: Array[int] = _sent_ticks(online.transport)
	runner.check(ticks.size() == kept.size() + 1 and ticks.slice(0, kept.size()) == kept and ticks[-1] == kept[-1] + 1, "SB4 only tick %d's packet is sent, got %s from %s" % [t, ticks, kept])
	runner.check(_sent_types(online.transport, "over") == 0, "SB4 no over after a protocol error, got %d" % _sent_types(online.transport, "over"))
	runner.check(driver.notice() == "Match stopped: game error. Please report it.", "SB4 the HUD shows the plain game error, got '%s'" % driver.notice())
	runner.check(driver.over() and online.transport.closed(), "SB4 the same drain finishes and closes the room")
	main.free()
	return true

func test_sb4_refused_post_ends_match(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var driver = main.driver
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	var kept: Array[int] = _sent_ticks(online.transport)
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	driver.pump.stop()
	var kept_tick: int = driver.pump.live().tick()
	var kept_sequence: int = driver.pump.live().last_sequence(2)
	_run(main, 1)
	runner.check(driver.pump.live().tick() == kept_tick and driver.pump.live().last_sequence(2) == kept_sequence, "PH a refused online post issues and steps nothing, got tick %d" % driver.pump.live().tick())
	runner.check(online.lockstep.status() == "ended_protocol" and online.lockstep.end_reason() == "sim pump refused tick 8", "SB4 a refused job ends the match, got %s '%s'" % [online.lockstep.status(), online.lockstep.end_reason()])
	_run(main, 3)
	OS.remove_logger(errors)
	runner.check(driver.over() and online.transport.closed() and driver.notice() == "Match stopped: game error. Please report it.", "SB4 the refusal closes the room with the plain game error, got '%s'" % driver.notice())
	runner.check(errors.lines.size() == 1 and errors.lines[0].contains("NETPLAY PROTOCOL END sim pump refused tick 8"), "SB4 the technical reason reaches the error log once, got %s" % errors.lines)
	runner.check(main.playtest_match().get("end") == "ended_protocol sim pump refused tick 8", "SB4 the playtest record carries the end reason, got %s" % main.playtest_match().get("end"))
	runner.check(_sent_ticks(online.transport) == kept and _sent_types(online.transport, "over") == 0, "SB4 nothing is sent for the refused tick, got %s from %s" % [_sent_ticks(online.transport), kept])
	main.free()
	return true

func test_sb4_protocol_end_after_win_logs_once(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_end_match(online)
	runner.check(main.driver.over() and online.lockstep.status() == "running", "SB4 the match is won before the late frame, got %s" % online.lockstep.status())
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	online.transport.frames.append(Wire.encode(_start_message("dry_wells", 3)))
	_run(main, 4)
	OS.remove_logger(errors)
	runner.check(online.lockstep.status() == "ended_protocol" and main.driver.notice() == "Match stopped: game error. Please report it.", "SB4 a start on the result panel ends the lockstep, got %s '%s'" % [online.lockstep.status(), main.driver.notice()])
	runner.check(errors.lines.size() == 1 and errors.lines[0].contains("NETPLAY PROTOCOL END unexpected start"), "SB4 a protocol end after the win is logged once, got %s" % errors.lines)
	main.free()
	return true

func test_sb4_step_after_close_takes_no_tick(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var driver = main.driver
	_peer_packets(online.transport, 2, 4, 40)
	_run(main, 8)
	var kept: Array[int] = _sent_ticks(online.transport)
	var kept_tick: int = driver.pump.live().tick()
	main.close_match(true)
	for i in 3:
		driver.step()
		main._drain_notes()
	runner.check(online.lockstep.status() == "running" and online.lockstep.end_reason() == "", "SB4 a step after close does not end the lockstep, got %s '%s'" % [online.lockstep.status(), online.lockstep.end_reason()])
	runner.check(not online.transport.closed(), "SB4 a step after close leaves the transport open")
	runner.check(driver.pump.live().tick() == kept_tick and _sent_ticks(online.transport) == kept, "SB4 no tick is taken after close, got %s from %s" % [_sent_ticks(online.transport), kept])
	main.free()
	return true

func test_ph_peer_command_without_sequence_refused(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_run(main, 10)
	_peer_packets(online.transport, 1, 4, 5)
	online.transport.frames.append(Wire.encode(Wire.tick_message(1, 6, [{"type": "stop", "entity_ids": [3], "tick": 6, "player": 1}], null)))
	_peer_packets(online.transport, 1, 7, PEER_TICKS)
	_run(main, 12)
	runner.check(main.driver.pump.live().last_sequence(1) == 0 and online.lockstep.status() == "running", "PH a peer command without a sequence is refused, as the headless client refuses it, got %d and %s" % [main.driver.pump.live().last_sequence(1), online.lockstep.status()])
	main.free()
	return true

func _tick_text(tick: int) -> String:
	return Wire.encode(Wire.tick_message(2, tick, [], null))

func test_ph_fake_relay_frame_order(runner) -> bool:
	var order := RelayFrameOrder.new()
	runner.check(order.accepts(_tick_text(4)) and order.accepts(_tick_text(5)), "PH relay rule: ticks 4 and 5 are accepted")
	runner.check(not order.accepts(_tick_text(5)), "PH relay rule: tick 5 again is refused")
	runner.check(order.accepts(Wire.encode({"type": "over"})), "PH relay rule: over after a tick is accepted")
	runner.check(not order.accepts(_tick_text(6)), "PH relay rule: a tick after over is refused")
	runner.check(order.refusals == ["tick 5 refused", "tick 6 refused"], "PH relay rule: refusals are recorded, got %s" % [order.refusals])
	runner.check(not order.accepts(Wire.encode({"type": "over"})), "PH relay rule: over twice is refused")
	runner.check(order.accepts(Wire.encode({"type": "again"})), "PH relay rule: again after over is accepted")
	runner.check(not order.accepts(Wire.encode({"type": "again"})), "PH relay rule: again twice is refused")
	order.rematch()
	runner.check(order.accepts(_tick_text(4)), "PH relay rule: a rematch resets the last tick and over")
	runner.check(order.accepts(Wire.encode({"type": "over"})) and order.accepts(Wire.encode({"type": "again"})), "PH relay rule: a rematch resets again")
	var transport := FakeTransport.new()
	transport.expect_refusal = true
	transport.send_text(Wire.encode({"type": "over"}))
	var replies: Array = Array(transport.poll()).map(func(text: String) -> Dictionary: return Wire.decode(text).message)
	runner.check(replies == [{"type": "error", "reason": "invalid message"}], "PH fake relay: an illegal frame queues the relay's error, got %s" % [replies])
	runner.check(transport.closed(), "PH fake relay: and closes")
	var fresh := RelayFrameOrder.new()
	runner.check(not fresh.accepts(Wire.encode({"type": "over"})), "PH relay rule: over before any tick is refused")
	runner.check(not fresh.accepts(Wire.encode({"type": "again"})), "PH relay rule: again before over is refused")
	fresh.rematch()
	runner.check(fresh.accepts(_tick_text(4)), "PH relay rule: tick 4 is accepted after a rematch")
	return true

func test_ph_receive_ends_lockstep_with_undrained_job(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var driver = main.driver
	var transport: FakeTransport = online.transport
	_peer_packets(transport, 1, 4, 7)
	_peer_stop(transport, 8)
	_peer_packets(transport, 1, 9, PEER_TICKS)
	_run(main, 8)
	runner.check(driver.current().tick == 8, "PH fixture: steady at tick 8, got %d" % driver.current().tick)
	var kept: Array[int] = _sent_ticks(transport)
	main._physics_process(1.0 / 30.0)
	runner.check(driver.get("_next_tick") == 9, "PH fixture: one callback takes tick 8 only, got %s" % driver.get("_next_tick"))
	transport.frames.append(Wire.encode({"type": "error", "reason": "room closed"}))
	main._physics_process(1.0 / 30.0)
	main._drain_notes()
	runner.check(online.lockstep.command_log().any(func(command: Dictionary) -> bool: return command.tick == 8 and command.type == "stop"), "PH a receive that ends the lockstep still records the undrained tick")
	runner.check(_sent_ticks(transport) == kept, "PH nothing is sent for it, got %s from %s" % [_sent_ticks(transport), kept])
	runner.check(_sent_types(transport, "over") == 0, "PH no over after the end")
	runner.check(driver.notice() == "Relay: room closed", "PH the HUD names the end, got '%s'" % driver.notice())
	runner.check(driver.over() and transport.closed(), "PH the same drain closes the room")
	runner.check(transport.order.refusals.is_empty(), "PH legal frames only, got %s" % [transport.order.refusals])
	main.free()
	return true

func test_ph_frame_order_through_end_and_rematch(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var transport: FakeTransport = online.transport
	_end_in_catch_up(runner, online, PEER_TICKS, [])
	runner.check(transport.order.refusals.is_empty(), "PH the catch-up end sends only legal frames, got %s" % [transport.order.refusals])
	runner.check(_sent_types(transport, "over") == 1 and _contiguous(_sent_ticks(transport), 4) and online.lockstep.status() == "running", "PH the catch-up end sends one over after contiguous ticks")
	transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	SkirmishMain.map_path = MatchSettings.map_path("dry_wells")
	transport.frames.append(_rematch_start(99))
	_peer_packets(transport, 1, 4, 4)
	_run(main, 1)
	var last: Dictionary = Wire.decode(transport.sent[-1]).message
	runner.check(transport.order.refusals.is_empty() and _sent_types(transport, "again") == 1 and last.type == "tick" and last.tick == 4, "PH the rematch sends only legal frames, got %s and %s" % [transport.order.refusals, last])
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func _preview_fixture(online: Dictionary, peer_to: int = 8) -> int:
	var main = online.main
	_peer_packets(online.transport, 2, 4, peer_to)
	_run(main, 16)
	_place(main)
	BaseScene.new().hover(main, Iso.world_to_plane(Vector2(10.5, 10.5)))
	return main.driver.pump.live().tick()

func test_ph_preview_on_last_job_of_catch_up(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var tick: int = _preview_fixture(online)
	_peer_packets(online.transport, 2, 9, PEER_TICKS)
	main._physics_process(1.0 / 30.0)
	var notes: Array[SimPump.Note] = main.driver.drain()
	var previews: int = notes.filter(func(note: SimPump.Note) -> bool: return not note.preview.is_empty()).size()
	runner.check(notes.size() == 2 and previews == 1, "PH a two-tick step call asks for the preview once, got %d notes and %d previews at tick %d" % [notes.size(), previews, tick])
	runner.check(not notes[-1].preview.is_empty(), "PH on its last job")
	main.free()
	return true

func test_ph_preview_on_single_job_when_next_tick_waits(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var tick: int = _preview_fixture(online)
	_peer_packets(online.transport, 2, tick, tick)
	main._physics_process(1.0 / 30.0)
	var notes: Array[SimPump.Note] = main.driver.drain()
	runner.check(notes.size() == 1 and not notes[0].preview.is_empty(), "PH a one-tick step call carries the preview, got %d notes" % notes.size())
	main.free()
	return true

func test_ph_preview_on_steady_step(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_preview_fixture(online, PEER_TICKS)
	main._physics_process(1.0 / 30.0)
	var notes: Array[SimPump.Note] = main.driver.drain()
	runner.check(notes.size() == 1 and not notes[0].preview.is_empty(), "PH a steady one-credit step call carries the preview, got %d notes" % notes.size())
	main.free()
	return true

func _start_plane(main, seat: int) -> Vector2:
	return Iso.world_to_plane(Vector2(main.driver.first_note.starts[seat]) + Vector2(0.5, 0.5))

func test_view_player_after_the_online_seat(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var camera: Camera2D = main.get_node("Camera2D")
	runner.check(main.local_player == 2 and main.view_player == 2, "VP1 a seat 2 join views player 2, got %d" % main.view_player)
	runner.check(main.driver.first_note.starts[1] != main.driver.first_note.starts[2] and camera.position == _start_plane(main, 2), "VP1 the camera starts on seat 2's start, got %s" % camera.position)
	var seats: Array[Dictionary] = [{"seat": 1, "team": 1, "controller": "human", "credits": 1111, "faction": "usa"}, {"seat": 2, "team": 2, "controller": "human", "credits": 2222, "faction": "usa"}]
	var sim = MapData.create(MapData.load(Skirmish.MAP_PATH), seats)
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	BaseScene.publish(main)
	var credits: Label = main.get_node("HUD/Hud/TopStrip").find_child("Credits", true, false)
	runner.check(credits.text == "2222", "VP1 the strip shows seat 2's credits, got " + credits.text)
	main.view_player = 1
	_end_match(online)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	SkirmishMain.starts = [2, 1]
	online.transport.frames.append(_rematch_start(99))
	_peer_packets(online.transport, 1, 4, 4)
	_run(main, 1)
	runner.check(main.view_player == 2 and camera.position == _start_plane(main, 2), "VP1 after a rematch the view is player 2 again, got %d" % main.view_player)
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_pal_two_seat_create_unchanged(runner) -> bool:
	var plain: RefCounted = Skirmish.create()
	var explicit: RefCounted = Skirmish.create(true, "human", Skirmish.Registry.Factions.DEFAULT_SKIRMISH, Skirmish.MAP_PATH, [] as Array[int], 2)
	runner.check(plain.tick_hash() == explicit.tick_hash() and plain.snapshot() == explicit.snapshot(), "PAL two-seat create is unchanged by the seat count")
	return true

func test_pal_three_seat_create(runner) -> bool:
	var sim: RefCounted = Skirmish.create(true, "human", {}, MatchSettings.map_path("broken_crown"), [] as Array[int], 3)
	var state: Dictionary = sim.snapshot()
	var teams: Array = state.players.map(func(player: Dictionary) -> int: return player.team)
	runner.check(teams == [1, 2, 3] and state.match.players == [1, 2, 3] and state.match.status == "setup", "PAL three seats, three teams, in setup, got %s %s" % [teams, state.match])
	return true

func test_pal_three_seat_starts(runner) -> bool:
	var got: Array[int] = MatchSettings.starts("broken_crown", 7, [1, 2, 3] as Array[int])
	var distinct := {}
	for start in got: distinct[start] = true
	runner.check(got.size() == 3 and distinct.size() == 3, "PAL three distinct starts, got " + str(got))
	runner.check(got == MatchSettings.starts("broken_crown", 7, [1, 2, 3] as Array[int]), "PAL three starts are stable for one seed")
	return true

# Online the seat owns nothing until its choose_faction step, so the start selection waits for that view.
func test_match_starts_with_builder_selected(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	runner.check(main.orders.selected_ids.is_empty(), "SS3 online: nothing to select before choose_faction, got %s" % str(main.orders.selected_ids))
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	var start: int = SkirmishScene.start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids == [start], "SS3 online: the first view holding the seat's units selects its start builder %d, got %s" % [start, main.orders.selected_ids])
	runner.check(main._sound._unit_voice.stream == null, "SS3 online: no voice")
	main.orders.selected_ids.clear()
	_run(main, 2)
	runner.check(main.orders.selected_ids.is_empty(), "SS3 online: a deselect holds, got %s" % str(main.orders.selected_ids))
	main.driver.pump.live().remove_object(4)
	main.driver.pump.live().remove_object(6)
	_run(main, 2)
	online.transport.frames.append(Wire.encode({"type": "again", "seat": 1}))
	_play_again_button(main).pressed.emit()
	_run(main, 1)
	online.transport.frames.append(_rematch_start(99))
	_run(main, 1)
	runner.check(main.orders.selected_ids.is_empty(), "SS4 online rematch: nothing selected before the new choose_faction, got %s" % str(main.orders.selected_ids))
	_peer_packets(online.transport, 1, 4, 12)
	_run(main, 8)
	start = SkirmishScene.start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids == [start], "SS4 online rematch: the new start builder %d is selected, got %s" % [start, main.orders.selected_ids])
	main.free()
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]

	online = await _online(runner, 2)
	main = online.main
	var live = main.driver.pump.live()
	live.setup_seat(2, "usa")
	start = SkirmishScene.start_unit_id(main)
	live.remove_object(start)
	BaseScene.publish(main)
	runner.check(main.orders.selected_ids.is_empty() and not main.get_node("HUD/Economy/Card").is_visible_in_tree(), "SS5 start builder gone before the first view: nothing selected, no card, got %s" % str(main.orders.selected_ids))
	live.spawn(2, Vector2(20.5, 20.5), "usa_builder")
	BaseScene.publish(main)
	runner.check(main.orders.selected_ids.is_empty(), "SS5 a later builder is never the start selection, got %s" % str(main.orders.selected_ids))
	main.free()

	online = await _online(runner, 2)
	main = online.main
	var press := InputEventMouseButton.new()
	press.position = main.get_viewport().get_visible_rect().size / 2.0
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main._unhandled_input(press)
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	runner.check(main.orders.is_selecting() and main.orders.selected_ids.is_empty(), "SS6 a drag begun before the start view keeps the player's selection, got %s" % str(main.orders.selected_ids))
	main.free()

	online = await _online(runner, 2)
	main = online.main
	var note: Control = main.get_node("HUD/Playtest/MarkerDialog")
	note.show()
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	start = SkirmishScene.start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids.is_empty(), "SS9 online: the seat's first view under an open note selects nothing, got %s" % str(main.orders.selected_ids))
	note.hide()
	_run(main, 1)
	runner.check(main.orders.selected_ids == [start], "SS9 online: the note closed, the start builder %d is selected, got %s" % [start, main.orders.selected_ids])
	main.free()
	return true
