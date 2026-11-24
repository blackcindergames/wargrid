@warning_ignore_start("untyped_declaration")
extends RefCounted

const Scene = preload("res://scenes/skirmish.tscn")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const ViewRows = preload("res://tests/test_view_rows.gd")
const IcRows = preload("res://tests/input_script_rows.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const OUTCOME: String = "HUD/ResultPanel/Center/Card/Box/Outcome"
const PLAY_AGAIN: String = "HUD/ResultPanel/Center/Card/Box/Buttons/PlayAgain"
const CHANGE_SETUP: String = "HUD/ResultPanel/Center/Card/Box/Buttons/ChangeSetup"
const TABLE: String = "HUD/ResultPanel/Center/Card/Box/Table"
const LENGTH: String = "HUD/ResultPanel/Center/Card/Box/Length"
const CARD: String = "HUD/ResultPanel/Center/Card"
const COPY: String = "HUD/ResultPanel/Center/Card/Box/Buttons/Copy"
const FREEZE_PARTS: Array[String] = ["HUD/ResultPanel/Center/Card/Box/Outcome/Mark", "HUD/ResultPanel/Center/Card/Box/Body", "HUD/ResultPanel/Center/Card/Box/Divider", "HUD/ResultPanel/Center/Card/Box/Footer", COPY]
const FailingPump = preload("res://tests/failing_pump.gd")
const ViewTests = preload("res://tests/test_view.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
var freeze_sessions: String = "user://test-freeze-playtests-%d" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_skirmish_ready_and_tick, test_combat_context_input, test_match_hud_and_restart, test_combat_view, test_hud_layout_and_focus, test_hud_build_line, test_enemy_selection_read_only, test_rally_input_and_marker, test_supply_pile_labels, test_attack_move_hint_and_rejection, test_selection_prunes_dead, test_order_marks_own_only, test_health_bar_clear_of_boxes, test_result_panel_layout, test_result_stats_from_sim, test_result_panel_focus, test_result_panel_keys, test_enter_in_text_field_keeps_match, test_change_setup_leaves, test_result_panel_unit, test_play_again_routes_by_driver, test_silent_keys_explain, test_hud_strings_use_display_names, test_hud_font_size_is_shared, test_defence_attack_scene, test_enter_unload_scene, test_right_click_pile_gathers, test_right_click_pile_in_launcher_flow, test_frc_laborer_right_click_pile, test_one_snapshot_per_refresh, test_refresh_waits_for_next_frame, test_auto_pick_samples_present_time, test_hud_summaries_are_pinned, test_input_script_offline, test_offline_driver_stamps_like_the_scene, test_sb1_submit_takes_no_snapshot, test_sb1_economy_input_reads_shown, test_sb1_combat_input_reads_shown, test_sb1_pick_of_unit_dead_since_shown, test_sb1_result_uses_shown_team, test_sb1_setup_shown_allows_input, test_sb1_idle_offline_ticks_take_no_snapshot, test_offline_driver_bot_memory_on_simulation, test_offline_driver_no_tick_hash_rows_after_the_end, test_orders_turn_input_into_payloads, test_hud_reads_only_state_and_orders, test_sb2_refusal_next_step, test_sb2_refusal_survives_accepted_result, test_one_line_one_beep_per_drain, test_due_failure_beeps_once, test_no_refusal_over_a_card, test_sb2_restart_drops_held_answer, test_sb2_answer_waits_for_unpause, test_sb3_submit_queues, test_sb3_match_log_equals_recorder, test_sb3_restart_drops_old_notes, test_sb3_paused_posts_nothing, test_sb3_over_stops_refreshing, test_sb3_process_drains, test_sb3_refusal_waits_in_queue, test_sb3_one_view_per_tick, test_sb3_record_reads_live_without_queue, test_ph_refused_post_keeps_queue_and_preview, test_freeze_card_on_a_failed_pump, test_freeze_leave_reaches_the_launcher, test_failure_first_met_while_leaving, test_freeze_card_copy_and_layout, test_freeze_card_keeps_the_focus, test_freeze_flush_keeps_the_queue, test_hover_equals_click, test_click_results, test_shift_toggles_on_the_map, test_hud_blocks_the_map, test_entering_the_hud_clears_hover, test_drag_across_a_panel, test_card_takes_a_click_after_a_drag, test_releases_on_a_panel_are_the_huds, test_view_player_changes_display_reads_only, test_slab_buttons_take_no_focus, test_drag_box_ends_with_the_match, test_match_starts_with_builder_selected, test_offline_bot_row_marked]

func _setup(runner):
	var main = Scene.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	# The open checklist covers the right of the view where these cases click, and it takes those clicks (Task 13).
	main.get_node("HUD/Playtest/Checklist").hide()
	await runner.process_frame
	return main

func _pending(main, type: String = "") -> int:
	return (main.driver.pump.live().snapshot().pending_commands + main.driver.queued()).filter(func(command: Dictionary) -> bool: return type.is_empty() or command.type == type).size()

func _arena(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var ids := {"infantry": sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry"), "tank": sim.spawn(1, Vector2(11.5, 10.5), "usa_tank"), "enemy": sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")}
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	main._refresh()
	return ids

func test_skirmish_ready_and_tick(runner) -> bool:
	var main = await _setup(runner)
	for path in ["WorldView", "Camera2D", "HUD/ResultPanel", BaseScene.PRODUCTION]:
		runner.check(main.has_node(path), "K2 node " + path)
	runner.check(main.driver.pump.live().snapshot() == Skirmish.create().snapshot(), "K2 exact scenario")
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().snapshot().tick == 1, "K2 one physics callback is one tick")
	runner.check(main.driver.pump.live().snapshot().buildings.all(func(b: Dictionary) -> bool: return b.owner != 2 or b.kind != "usa_power_plant"), "K2 the opponent has not built before its decision tick")
	main._process(0.1)
	main._refresh()
	runner.check(main.driver.pump.live().snapshot().tick == 1, "K2 _process and _refresh never step")
	while main.driver.pump.live().snapshot().tick <= Skirmish.next_decision(0, 2) and main.driver.pump.live().snapshot().tick < 40: BaseScene.tick(main)
	var state: Dictionary = main.driver.pump.live().snapshot()
	runner.check(state.tick == Skirmish.next_decision(0, 2) + 1 and state.buildings.size() == 3 and state.buildings[2].owner == 2 and state.buildings[2].kind == "usa_power_plant", "K2 the opponent's first command lands on its seat's decision tick")
	for building: Dictionary in main.driver.pump.live().snapshot().buildings: main.driver.pump.live().remove_object(building.id)
	BaseScene.tick(main)
	var frozen: Dictionary = main.driver.pump.live().snapshot()
	BaseScene.tick(main)
	runner.check(frozen.match.status == "draw" and main.driver.pump.live().snapshot() == frozen, "K2 terminal match stays frozen")
	main.free()
	return true

func test_combat_context_input(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var camera: Camera2D = main.get_node("Camera2D")
	var enemy_point: Vector2 = Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)
	for center in [Vector2(0, 320), Vector2(80, 320)]:
		for zoom in [0.5, 1.0, 2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			var before: int = _pending(main)
			helper.right_click(main, enemy_point)
			runner.check(_pending(main) == before + 1 and _pending(main, "move") == 0, "K3 enemy right-click submits one attack at zoom " + str(zoom))
	var group: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "attack")
	runner.check(group[0].entity_ids == [ids.infantry, ids.tank] and group[0].target_id == ids.enemy, "K3 mixed infantry and tank is one group command")
	main.orders.selected_ids.assign([1, ids.infantry])
	var pending: int = _pending(main)
	helper.right_click(main, enemy_point)
	runner.check(_pending(main) == pending + 1 and _pending(main, "move") == 0 and main.hud.refusal.is_empty(), "K3 an unarmed member no longer rejects the click")
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	pending = _pending(main)
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(_pending(main) == pending + 1 and _pending(main, "attack_move") == 1 and not main.orders._attack_move_mode, "K3 A then ground click submits one attack_move")
	helper.key(main, KEY_S)
	runner.check(_pending(main, "stop") == 1, "K3 S submits one stop")
	pending = _pending(main)
	helper.key(main, KEY_A)
	runner.check(main.orders._attack_move_mode, "K3 A enters attack-move mode")
	helper.key(main, KEY_ESCAPE)
	runner.check(not main.orders._attack_move_mode and main.orders.selected_ids == [ids.infantry, ids.tank], "K3 Escape cancels attack-move and keeps the selection")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(_pending(main) == pending, "K3 no attack-move after Escape")
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	helper.key(main, KEY_A)
	runner.check(main.orders._attack_move_mode, "K3 A re-enters attack-move mode")
	helper.right_click(main, enemy_point)
	runner.check(not main.orders._attack_move_mode and _pending(main) == pending, "K3 right-click cancels attack-move without an attack")
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	helper.key(main, KEY_A)
	main.orders.selected_ids.assign([1])
	helper.build_key(main, "usa_power_plant")
	runner.check(not main.orders._attack_move_mode and main.orders._placement_kind == "usa_power_plant", "K3 placement clears a stale attack-move mode")
	helper.key(main, KEY_ESCAPE)
	# The defence cell needs a completed Power Plant, else it is blocked and arms nothing.
	Fixture.add_completed(main.driver.pump.live(), 1, "usa_power_plant", Skirmish.origin("usa_power_plant", 1))
	BaseScene.publish(main)
	main.orders.selected_ids.assign([1])
	main._refresh()
	helper.build_key(main, "usa_power_plant")
	helper.key(main, KEY_A)
	runner.check(main.orders._placement_kind == "usa_defence" and not main.orders._attack_move_mode, "K3 in placement A is the sub-grid's defence cell, never attack-move, got '%s'" % main.orders._placement_kind)
	main.free()
	return true

func test_match_hud_and_restart(runner) -> bool:
	var main = await _setup(runner)
	runner.check(View.owner_color(1) != View.owner_color(2), "K4 owner colors differ")
	var ids: Dictionary = _arena(main)
	main.orders.selected_ids.assign([ids.tank])
	main._refresh()
	var credits: String = str(HudModel.player(main.shown_state, main.local_player).credits)
	runner.check(main.get_node("HUD/Hud/TopStrip").find_child("Credits", true, false).text == credits and _panel_text(main, "Name") == "Battle Tank" and _panel_text(main, "Health") == "480 / 480", "K4 credits, kind and health in the HUD")
	var setup: Dictionary = main.driver.pump.live().view_state()
	setup.match.status = "setup"
	main._show_result(setup)
	runner.check(main.get_node(OUTCOME).text.is_empty() and not main.get_node("HUD/ResultPanel").visible, "K4 the setup phase shows no result")
	main.driver.pump.live().remove_object(3)
	main.driver.pump.live().remove_object(4)
	BaseScene.tick(main)
	runner.check(main.get_node(OUTCOME).text == "Victory" and main.get_node(PLAY_AGAIN).visible and not main.get_node(PLAY_AGAIN).disabled, "K4 victory and restart button")
	runner.check(not BaseScene.hud_text(main).contains("A: attack-move click"), "K4 the HUD drops the order hints under a result")
	main.driver.pump.live()._players[main.local_player].team = 7
	BaseScene.publish(main)
	runner.check(main._result_text({"status": "won", "winner": 7}) == "Victory" and main._result_text({"status": "won", "winner": main.local_player}) == "Defeat", "K4 result compares the winning team id with the local team")
	var before: Array = main.driver.pump.live().snapshot().pending_commands
	main._submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	main._unhandled_input(InputEventKey.new())
	runner.check(main.driver.pump.live().snapshot().pending_commands == before, "K4 terminal match accepts no orders")
	BaseScene.tick(main)
	runner.check(main.hud.refusal.is_empty() and not main.get_node("HUD/Hud/RefusalLine").visible, "K4 the refused order of an ended match stays off the line (the card says why), got '%s'" % main.hud.refusal)
	main.orders._placement_kind = "usa_power_plant"
	main.orders._attack_move_mode = true
	main.hud.refusal = "old"
	main._last_result_tick = 99
	main._last_result_sequence = 99
	main.orders._selecting = true
	main.orders._dragged = true
	main.get_node("Camera2D").position = Vector2(500, 500)
	main.get_node("Camera2D").zoom = Vector2.ONE * 2.0
	main.get_node(PLAY_AGAIN).pressed.emit()
	runner.check(main.driver.pump.live().snapshot() == Skirmish.create().snapshot() and main.orders.selected_ids == [start_unit_id(main)] and main.orders._placement_kind.is_empty() and not main.orders._attack_move_mode and main.hud.refusal.is_empty() and main.get_node("Camera2D").zoom == Vector2.ONE and not main.get_node("HUD/ResultPanel").visible and main._last_result_tick == -1 and main._last_result_sequence == -1 and not main.orders._selecting and not main.orders._dragged and main.get_node("Camera2D").position != Vector2(500, 500) and main.get_node("WorldView")._preview_cells.is_empty(), "K4 restart leaves nothing from the old match")
	main.orders.selected_ids.assign([1])
	main._submit({"type": "move", "entity_ids": [1], "target": [6.5, 14.5]})
	runner.check(main.hud.refusal.is_empty() and _pending(main, "move") == 1, "K4 first order after restart is valid")
	for loser in [[1, "Defeat"], [-1, "Draw"]]:
		var other = await _setup(runner)
		if loser[0] == 1:
			other.driver.pump.live().remove_object(2)
		else:
			other.driver.pump.live().remove_object(2)
			other.driver.pump.live().remove_object(3)
			other.driver.pump.live().remove_object(4)
		BaseScene.tick(other)
		runner.check(other.get_node(OUTCOME).text == loser[1], "K4 " + loser[1])
		other.free()
	main.free()
	return true

func test_combat_view(runner) -> bool:
	var main = await _setup(runner)
	var view = main.get_node("WorldView")
	var sim = Skirmish.create(false)
	sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var victim: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	var historical: Dictionary = sim.snapshot()
	for unit in historical.entities:
		unit.erase("hp")
		unit.erase("max_hp")
		unit.erase("combat")
	historical.erase("combat_events")
	historical.erase("match")
	var none: Array[int] = []
	view.set_state(historical, none)
	await runner.process_frame
	runner.check(view.pick_target(Iso.world_to_plane(Vector2(14.5, 10.5)) + Vector2(0, -8), 1) == victim, "V1 historical snapshot tolerated and enemy picked")
	sim.step()
	var live: Dictionary = sim.snapshot()
	var copy: Dictionary = live.duplicate(true)
	view.set_state(live, none)
	await runner.process_frame
	runner.check(live == copy, "V1 cues are read-only")
	runner.check(View.hp_fraction(-5, 100) == 0.0 and View.hp_fraction(500, 100) == 1.0 and View.hp_fraction(50, 100) == 0.5 and View.hp_fraction(1, 0) == 1.0, "V1 HP fill clamped 0..1")
	main.free()
	return true

func test_hud_layout_and_focus(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.orders.selected_ids.assign([ids.tank])
	main._refresh()
	BaseScene.slab_clear(runner, main, "K5 tank selected")
	var view = main.get_node("WorldView")
	runner.check(view.focus_targets().is_empty(), "K5 no focus before an order")
	BaseScene.new().right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8))
	BaseScene.tick(main)
	runner.check(view.focus_targets() == {ids.enemy: true}, "K5 explicit attack target is marked strongly, got " + str(view.focus_targets()))
	main.orders.selected_ids.clear()
	main._refresh()
	runner.check(view.focus_targets().is_empty(), "K5 focus shows only for the selection")
	main.orders.inspected_id = ids.enemy
	main._refresh()
	BaseScene.slab_clear(runner, main, "K5 an inspected enemy")
	var pile: Dictionary = _pile_world(main)
	main.orders.selected_ids.assign([pile.waiting])
	main._refresh()
	BaseScene.slab_clear(runner, main, "K5 a queued collector")
	main.free()
	return true

func _pile_world(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var source: int = sim.add_supply_source(Vector2i(8, 8), 10)
	var first: int = sim.spawn(1, Vector2(10.0, 10.5), "usa_collector")
	var second: int = sim.spawn(1, Vector2(10.0, 10.5), "usa_collector")
	Fixture.send(sim, {"type": "gather", "entity_ids": [first, second], "source_id": source})
	Fixture.steps(sim, 19)
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_ids.clear()
	main._refresh()
	return {"source": source, "docked": first, "waiting": second}

# The local player's builder's sub-grid, as each item cell's "key name".
func _build_labels(main) -> Array:
	for unit: Dictionary in main.driver.pump.live().snapshot().entities:
		if unit.owner == main.local_player and Registry.is_builder(unit.kind): main.orders.selected_ids.assign([unit.id])
	main._refresh()
	BaseScene.new().key(main, HudModel.BUILD_KEY)
	return main.get_node("HUD/Economy/Card").get_children().filter(func(cell: Button) -> bool: return cell.is_visible_in_tree() and cell.get_node("Cost").visible).map(func(cell: Button) -> String: return "%s %s" % [cell.get_node("Chip").text, cell.get_node("Name").text])

func test_hud_build_line(runner) -> bool:
	var main = await _setup(runner)
	var labels: Array = _build_labels(main)
	var text: String = BaseScene.hud_text(main)
	runner.check(not labels.is_empty() and labels[0] == "Q Power Plant" and not text.contains("1-9: menu") and not text.contains("U: unload"), "H1 the build cells carry their keys and no key-hint line shows, got %s" % [labels])
	var base_helper = BaseScene.new()
	var base = await base_helper.setup(runner)
	runner.check(_build_labels(base) == labels, "H1 base scene shares the build cells")
	base.free()
	var sim = Skirmish.create(false)
	var hub: int = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(10, 10))
	var rifle: int = sim.spawn(1, Vector2(9.5, 10.5), "frc_rifle_infantry")
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = hub
	main._refresh()
	var unload: Button = main.get_node("HUD/Economy/Card/F")
	runner.check(not unload.is_visible_in_tree(), "H1 no Unload while the hub is empty")
	Fixture.load_unit(runner, sim, rifle, hub)
	BaseScene.publish(main)
	var words: String = "%s %s" % [unload.get_node("Chip").text, unload.get_node("Name").text]
	runner.check(unload.is_visible_in_tree() and words == "F Unload", "H1 a loaded hub shows Unload on F, got '%s'" % words)
	main.free()
	return true

func test_enemy_selection_read_only(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var enemy_point: Vector2 = Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.inspected_id == ids.enemy and main.orders.selected_ids.is_empty(), "E1 left-click selects the enemy read-only and replaces own selection")
	runner.check(_panel_text(main, "Name") == "Battle Tank" and _panel_text(main, "Health") == "480 / 480" and main.hud.panel_edge() == View.owner_color(2), "E1 the panel shows the enemy's name, health and owner edge, got '%s' '%s'" % [_panel_text(main, "Name"), _panel_text(main, "Health")])
	var before: Dictionary = main.driver.pump.live().snapshot()
	helper.key(main, KEY_E)
	helper.key(main, KEY_A)
	helper.key(main, KEY_S)
	helper.right_click(main, enemy_point)
	helper.right_click(main, Iso.world_to_plane(Vector2(20.5, 12.5)))
	runner.check(main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty() and not main.orders._attack_move_mode and main.orders.inspected_id == ids.enemy, "E1 E, A, S and right-clicks send nothing")
	var own_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_ids == [ids.infantry] and main.orders.inspected_id == -1, "E1 own click selects own unit and clears inspection")
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	main.driver.pump.live().remove_object(ids.enemy)
	BaseScene.publish(main)
	runner.check(main.orders.inspected_id == -1, "E1 dead enemy clears inspection")
	main.free()
	return true

func test_rally_input_and_marker(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_ids.clear()
	main._refresh()
	var view = main.get_node("WorldView")
	runner.check(view.rally_marker().is_empty(), "R1 no marker without a selection")
	var click: Vector2 = Iso.world_to_plane(Vector2(13.5, 13.5))
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_building_id == barracks and view.rally_marker() == [16.5, 13.5], "R1 marker shows the default rally while selected")
	helper.right_click(main, Iso.world_to_plane(Vector2(16.5, 10.5)))
	var orders: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "set_rally")
	runner.check(orders.size() == 1 and orders[0].building_id == barracks and orders[0].target == [16.5, 10.5], "R1 right-click on ground issues set_rally for that cell")
	BaseScene.tick(main)
	runner.check(view.rally_marker() == [16.5, 10.5], "R1 marker follows the new rally")
	helper.key(main, KEY_ESCAPE)
	runner.check(view.rally_marker().is_empty(), "R1 marker absent when deselected")
	var reactor: int = Fixture.build(runner, sim, "usa_power_plant", Vector2i(20, 20))
	main.orders.selected_building_id = reactor
	main.orders.selected_ids.assign([reactor])
	BaseScene.publish(main)
	runner.check(view.rally_marker().is_empty(), "R1 no marker for a reactor, which cannot take a rally")
	main.free()
	return true

func test_supply_pile_labels(runner) -> bool:
	var main = await _setup(runner)
	var pile: Dictionary = _pile_world(main)
	var view = main.get_node("WorldView")
	var source: Dictionary = Fixture.object(main.driver.pump.live(), pile.source)
	runner.check(Fixture.object(main.driver.pump.live(), pile.docked).collection.phase in ["loading"] and Fixture.object(main.driver.pump.live(), pile.waiting).collection.phase == "waiting_source", "S1 fixture: one collector docked, one waiting")
	runner.check(view.pile_lines(source) == PackedStringArray(["Boxes %d" % source.boxes, "docked 1 · waiting 1"]), "S1 pile label, got " + str(view.pile_lines(source)))
	var points: PackedVector2Array = view.pile_text_points(source)
	runner.check(points.size() == 2 and points[1].y - points[0].y >= ThemeDB.fallback_font.get_height(View.MAP_LABEL_SIZE), "S1 pile lines are a full text height apart, got " + str(points))
	main.orders.selected_ids.assign([pile.waiting])
	main._refresh()
	runner.check(_panel_text(main, "RightLabel") == "WAITING AT PILE", "S1 waiting collector reads WAITING AT PILE, got " + _panel_text(main, "RightLabel"))
	main.orders.selected_ids.assign([pile.docked])
	main._refresh()
	runner.check(_panel_text(main, "RightLabel") == "LOADING", "S1 docked collector reads LOADING, got " + _panel_text(main, "RightLabel"))
	main.free()
	return true

func test_attack_move_hint_and_rejection(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var view = main.get_node("WorldView")
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(19.5, 11.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(19.5, 11.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(view.hints().size() == 1, "H3 attack-move click leaves one hint")
	main.orders.selected_ids.assign([ids.infantry])
	var before: int = view.hints().size()
	main.driver.pump.live().remove_object(ids.infantry)
	helper.right_click(main, Iso.world_to_plane(Vector2(8.5, 8.5)))
	runner.check(view.hints().size() == before, "H3 a second command replaces the marker, still one")
	main.orders.selected_ids.clear()
	view.add_hint(Vector2(1, 1), 0)
	helper.right_click(main, Iso.world_to_plane(Vector2(9.5, 9.5)))
	runner.check(view.hints().size() == 1 and view.hints()[0].point == Vector2(1, 1), "H3 a right click with no movable selection adds no marker")
	main.free()
	return true

func test_selection_prunes_dead(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.driver.pump.live().remove_object(ids.tank)
	BaseScene.publish(main)
	runner.check(main.orders.selected_ids == [ids.infantry], "H4 selection keeps only live ids, got " + str(main.orders.selected_ids))
	main.free()
	return true

func test_order_marks_own_only(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	Fixture.send(main.driver.pump.live(), {"type": "move", "entity_ids": [ids.tank], "target": [12.5, 14.5]})
	Fixture.send(main.driver.pump.live(), {"type": "move", "player": 2, "entity_ids": [ids.enemy], "target": [16.5, 14.5]})
	Fixture.steps(main.driver.pump.live(), 2)
	BaseScene.publish(main)
	runner.check(main.get_node("WorldView").order_marks().is_empty(), "P1 order crosses are hidden by default")
	main.get_node("WorldView").set_show_destinations(true)
	var marks: Array[Vector2] = main.get_node("WorldView").order_marks()
	runner.check(marks == [Iso.world_to_plane(Vector2(12.5, 14.5))], "P1 only the local player's order shows a cross, got " + str(marks))
	main.free()
	return true

func test_health_bar_clear_of_boxes(runner) -> bool:
	var view = View.new()
	for half in [6.0, 15.0]:
		var bounds := Rect2(Vector2(100, 100), Vector2(half * 2.0, 16))
		runner.check(not view.health_rect(bounds).intersects(bounds.grow(4.0 + 1.5)), "P2 health bar clear of the focus box at half width %s" % half)
	view.free()
	return true

func _victory(main) -> void:
	main.driver.pump.live().remove_object(3)
	main.driver.pump.live().remove_object(4)
	BaseScene.tick(main)

func _enter(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func test_result_panel_layout(runner) -> bool:
	var no_rows: Array[Dictionary] = []
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = Scene.instantiate()
		port.add_child(main)
		main.set_physics_process(false)
		main.set_process(false)
		await runner.process_frame
		_arena(main)
		_victory(main)
		var panel = main.get_node("HUD/ResultPanel")
		await runner.process_frame
		await runner.process_frame
		var real_card: Rect2 = main.get_node("HUD/ResultPanel/Center/Card").get_global_rect()
		var real_table: GridContainer = main.get_node(TABLE)
		var real_cells: Array = real_table.get_children().map(func(cell: Label) -> String: return cell.text)
		runner.check(real_table.visible and real_table.columns == 4 and real_cells.size() == 12 and real_cells.slice(0, 4) == ["", "Units built", "Units lost", "Buildings lost"], "R1 the table has its headers and two player rows at %s, got %s" % [size, real_cells])
		runner.check(main.get_node(LENGTH).visible and main.get_node(LENGTH).text == ResultPanel.length_text(main.driver.pump.live().tick(), 30), "R1 the length reads the match ticks at %s, got '%s'" % [size, main.get_node(LENGTH).text])
		runner.check(real_card.grow(-16.0).encloses(real_table.get_global_rect()) and real_card.grow(-16.0).encloses(main.get_node(LENGTH).get_global_rect()), "R1 table and length inside the card at %s" % size)
		var real_buttons: Rect2 = main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons").get_global_rect()
		runner.check(absf(real_buttons.get_center().x - real_card.get_center().x) <= 1.0, "R1 the button row is centred on the card at %s" % size)
		runner.check(main.get_node(PLAY_AGAIN).text == "Play again", "R1 offline never offers Accept rematch at %s" % size)
		panel.show_result("Victory", "Your friend wants a rematch", true, no_rows, "", false, true)
		await runner.process_frame
		await runner.process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var card: Rect2 = main.get_node("HUD/ResultPanel/Center/Card").get_global_rect()
		var outcome: Label = main.get_node(OUTCOME)
		var status: Label = main.get_node("HUD/ResultPanel/Center/Card/Box/Status")
		var again: Rect2 = main.get_node(PLAY_AGAIN).get_global_rect()
		var setup: Rect2 = main.get_node(CHANGE_SETUP).get_global_rect()
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "R1 the viewport really is %s" % size)
		runner.check(panel.visible and outcome.text == "Victory" and status.visible and status.text == "Your friend wants a rematch", "R1 realistic texts shown at %s" % size)
		var accept: Button = main.get_node(PLAY_AGAIN)
		var accept_row: Rect2 = main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons").get_global_rect()
		runner.check(accept.text == "Accept rematch" and accept.size.x == 144.0 and accept.get_minimum_size().x <= 144.0 and setup.size.x == 144.0, "R1 Accept rematch fits the 144 px minimum width at %s, button %.0f, needs %.0f" % [size, accept.size.x, accept.get_minimum_size().x])
		runner.check(absf(accept_row.get_center().x - card.get_center().x) <= 1.0 and absf((again.position.x + setup.end.x) / 2.0 - card.get_center().x) <= 1.0, "R1 the two buttons stay centred with Accept rematch at %s" % size)
		runner.check(main.get_node("HUD/ResultPanel/Dim").get_global_rect() == screen, "R1 the dim covers %s" % size)
		runner.check(screen.encloses(card) and card.get_center().distance_to(screen.get_center()) <= 1.0, "R1 card centred inside %s, rect %s" % [size, card])
		runner.check(card.encloses(outcome.get_global_rect()) and card.encloses(status.get_global_rect()) and card.encloses(again) and card.encloses(setup), "R1 card holds its texts and buttons at %s" % size)
		runner.check(outcome.get_global_rect().end.y <= status.get_global_rect().position.y and status.get_global_rect().end.y <= again.position.y, "R1 outcome above status above buttons at %s" % size)
		runner.check(again.size.x > 0.0 and setup.size.x > 0.0 and not again.intersects(setup), "R1 the two buttons do not intersect at %s" % size)
		runner.check(card.grow(-16.0).encloses(again) and card.grow(-16.0).encloses(setup) and card.grow(-16.0).encloses(outcome.get_global_rect()), "R1 at least 16 px between the card edge and its contents at %s, card %s" % [size, card])
		runner.check(again.size.y <= 40.0 and setup.size.y <= 40.0 and again.position.x - card.position.x >= 16.0, "R1 compact buttons at most 40 px tall at %s, got %.0f" % [size, again.size.y])
		var index: int = panel.get_index()
		runner.check(index < main.get_node("HUD/PerfOverlay").get_index() and index < main.get_node("HUD/Playtest").get_index() and index < main.get_node("HUD/PauseMenu").get_index(), "R1 the panel draws below the overlays at %s" % size)
		var tall: float = main.get_node("HUD/ResultPanel/Center/Card").size.y
		panel.show_result("Victory", "", true)
		await runner.process_frame
		runner.check(accept.text == "Play again", "R1 without the friend's again the button reads Play again at %s" % size)
		runner.check(is_equal_approx(main.get_node("HUD/ResultPanel/Center/Card").size.y, tall), "R1 the card keeps its height without a status line at %s (user, 2026-11-15)" % size)
		panel.show_result("Victory", "Your friend wants a rematch", false, no_rows, "", true, true)
		runner.check(accept.text == "Play again" and accept.disabled, "R1 a disabled Play again never reads Accept rematch at %s" % size)
		panel.show_result("Victory", "Waiting for your friend…", false)
		await runner.process_frame
		var waiting: StyleBox = main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons/PlayAgain").get_theme_stylebox("disabled")
		runner.check(waiting is StyleBoxFlat and (waiting as StyleBoxFlat).bg_color.is_equal_approx(Color("#666a6c")), "R1 a waiting Play again is grey, not amber, at %s" % size)
		var rows: Array[Dictionary] = []
		for i in 8: rows.append({"name": "P%d Free Resistance Coalition%s" % [i + 1, " (you)" if i == 7 else ""], "you": i == 7, "built": 1234, "units_lost": 567, "buildings_lost": 89})
		panel.show_result("Victory", "Your friend wants a rematch", true, rows, "Match length 99:59", false, true)
		await runner.process_frame
		await runner.process_frame
		var long_card: Rect2 = main.get_node("HUD/ResultPanel/Center/Card").get_global_rect()
		var long_table: GridContainer = main.get_node(TABLE)
		runner.check(long_table.get_child_count() == 36 and screen.encloses(long_card), "R1 eight rows: 36 cells, card inside the viewport at %s, card %s" % [size, long_card])
		runner.check(long_card.grow(-16.0).encloses(long_table.get_global_rect()) and long_card.grow(-16.0).encloses(main.get_node(LENGTH).get_global_rect()), "R1 eight rows: table inside the card at %s, table %s" % [size, long_table.get_global_rect()])
		runner.check(not long_table.get_global_rect().intersects(main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons").get_global_rect()), "R1 eight rows: buttons clear of the table at %s" % size)
		runner.check(long_table.get_children().all(func(cell: Label) -> bool: return cell.get_theme_font_size("font_size") >= 12), "R1 every table label is at least 12 px at %s" % size)
		port.queue_free()
	return true

func test_result_stats_from_sim(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	for i in 900:
		if main.driver.pump.live().match_stats().any(func(row: Dictionary) -> bool: return row.units_lost > 0): break
		BaseScene.tick(main)
	var enemy: Array = main.driver.pump.live().snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 2) + main.driver.pump.live().snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 2)
	for object: Dictionary in enemy: main.driver.pump.live().remove_object(object.id)
	BaseScene.tick(main)
	var stats: Array = main.driver.pump.live().match_stats()
	var cells: Array = main.get_node(TABLE).get_children()
	runner.check(cells.size() == 4 + 4 * stats.size() and stats.size() == 2, "R7 fixture: a header and one row per player, got %d cells, stats %s, match %s, tick %d" % [cells.size(), stats, main.driver.pump.live().snapshot().match, main.driver.pump.live().tick()])
	runner.check(stats.any(func(row: Dictionary) -> bool: return row.units_lost > 0), "R7 fixture: the sim counted a lost unit")
	for i in stats.size():
		var row: Array = cells.slice(4 + 4 * i, 8 + 4 * i)
		runner.check([row[1].text, row[2].text, row[3].text] == [str(stats[i].units_built), str(stats[i].units_lost), str(stats[i].buildings_lost)], "R7 row %d numbers equal match_stats, got %s vs %s" % [i, [row[1].text, row[2].text, row[3].text], stats[i]])
		runner.check(row[1].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "R7 row %d numbers are right-aligned" % i)
	var mine: Label = cells[4]
	var theirs: Label = cells[8]
	runner.check(mine.text.begins_with("P1 ") and mine.text.ends_with(" (you)") and theirs.text.begins_with("P2 ") and not theirs.text.contains("(you)"), "R7 only the local row says (you), got '%s' and '%s'" % [mine.text, theirs.text])
	runner.check(mine.get_theme_font("font") != theirs.get_theme_font("font") and cells[5].get_theme_font("font") != cells[9].get_theme_font("font"), "R7 the local row is in the bold font, all four cells")
	runner.check(ResultPanel.length_text(0, 30) == "Match length 0:00" and ResultPanel.length_text(29, 30) == "Match length 0:00" and ResultPanel.length_text(22620, 30) == "Match length 12:34" and ResultPanel.length_text(108000, 30) == "Match length 60:00", "R7 the length rounds down to whole seconds")
	main.free()
	return true

func _push_enter(main) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		main.get_viewport().push_input(event)

func _focus_owner(main) -> Control:
	return main.get_viewport().gui_get_focus_owner()

func test_result_panel_focus(runner) -> bool:
	var rows: Array[Dictionary] = [{"name": "P1 United States (you)", "you": true, "built": 1, "units_lost": 0, "buildings_lost": 0}]
	var main = await _setup(runner)
	var panel = main.get_node("HUD/ResultPanel")
	var setup: Button = main.get_node(CHANGE_SETUP)
	var emitted: Array[String] = []
	panel.change_setup_pressed.connect(func() -> void: emitted.append("setup"))
	panel.play_again_pressed.connect(func() -> void: emitted.append("again"))
	main.change_scene = func(_path: String) -> void: pass
	panel.show_result("Victory", "Your friend left", false, rows)
	runner.check(_focus_owner(main) == setup, "R8 a closed room puts the focus on Back to menu")
	_push_enter(main)
	runner.check(emitted.has("setup") and not emitted.has("again"), "R8 a real Enter presses Back to menu, got %s" % [emitted])
	main.free()
	var waiting_main = await _setup(runner)
	var waiting_panel = waiting_main.get_node("HUD/ResultPanel")
	var waiting_emitted: Array[String] = []
	waiting_panel.change_setup_pressed.connect(func() -> void: waiting_emitted.append("setup"))
	waiting_panel.show_result("Victory", "Waiting for your friend…", false, rows, "", true)
	runner.check(_focus_owner(waiting_main) != waiting_main.get_node(CHANGE_SETUP), "R8 waiting for the friend leaves the focus alone")
	_push_enter(waiting_main)
	runner.check(waiting_emitted.is_empty(), "R8 a second Enter while waiting does not leave, got %s" % [waiting_emitted])
	waiting_panel.show_result("Victory", "Your friend left", false, rows, "", false)
	runner.check(_focus_owner(waiting_main) == waiting_main.get_node(CHANGE_SETUP), "R8 the friend leaving after the wait takes the focus")
	waiting_main.free()
	var enabled_main = await _setup(runner)
	var enabled_panel = enabled_main.get_node("HUD/ResultPanel")
	var enabled_emitted: Array[String] = []
	enabled_panel.change_setup_pressed.connect(func() -> void: enabled_emitted.append("setup"))
	enabled_panel.play_again_pressed.connect(func() -> void: enabled_emitted.append("again"))
	enabled_main.change_scene = func(_path: String) -> void: pass
	enabled_panel.show_result("Victory", "", true, rows)
	enabled_main.get_node(CHANGE_SETUP).grab_focus()
	runner.check(not enabled_panel.takes_enter(_enter(KEY_ENTER)), "R8 takes_enter yields while Back to menu has the focus")
	_push_enter(enabled_main)
	runner.check(enabled_emitted == ["setup"], "R8 Enter on a focused Back to menu leaves, not Play again, got %s" % [enabled_emitted])
	enabled_main.free()
	var paused = await _setup(runner)
	var paused_panel = paused.get_node("HUD/ResultPanel")
	paused.change_scene = func(_path: String) -> void: pass
	paused_panel.show_result("Victory", "", true, rows)
	paused._pause.open()
	var menu_focus: Control = _focus_owner(paused)
	runner.check(menu_focus != null and paused._pause.is_ancestor_of(menu_focus), "R8 fixture: the pause menu holds the focus")
	paused_panel.show_result("Victory", "Your friend left", false, rows)
	for i in 10: paused_panel.show_result("Victory", "Your friend left", false, rows)
	runner.check(_focus_owner(paused) == menu_focus, "R8 refreshes keep the pause menu's focus")
	paused._pause.close()
	paused_panel.show_result("Victory", "Your friend left", false, rows)
	runner.check(_focus_owner(paused) == paused.get_node(CHANGE_SETUP), "R8 the grab runs after the pause menu closes")
	paused.get_viewport().gui_release_focus()
	paused_panel.show_result("Victory", "Your friend left", false, rows)
	runner.check(_focus_owner(paused) != paused.get_node(CHANGE_SETUP), "R8 the grab runs once per change, not every refresh")
	paused.free()
	return true

func test_result_panel_keys(runner) -> bool:
	for code in [KEY_ENTER, KEY_KP_ENTER]:
		var main = await _setup(runner)
		_arena(main)
		_victory(main)
		runner.check(main.get_node("HUD/ResultPanel").visible, "R2 fixture: the panel is up")
		var arena_sim = main.driver.pump.live()
		main._input(_enter(code))
		runner.check(not is_same(main.driver.pump.live(), arena_sim) and not main.get_node("HUD/ResultPanel").visible, "R2 key %s restarts" % code)
		main.free()
	var main = await _setup(runner)
	_arena(main)
	_victory(main)
	var kept = main.driver.pump.live()
	main._pause.open()
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.pump.live(), kept) and main.get_node("HUD/ResultPanel").visible, "R2 Enter with the pause menu open does nothing")
	main._pause.close()
	main._playtest._dialog.show()
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.pump.live(), kept) and main._playtest._dialog.visible, "R2 Enter with the marker dialog open keeps the match and the dialog")
	main._playtest._dialog.hide()
	main._input(_enter(KEY_ESCAPE))
	runner.check(main._pause.visible and is_same(main.driver.pump.live(), kept), "R2 Esc with the panel up opens the pause menu")
	main.free()
	var live = await _setup(runner)
	var live_sim = live.driver.pump.live()
	live._input(_enter(KEY_ENTER))
	runner.check(is_same(live.driver.pump.live(), live_sim), "R2 Enter during a running match does nothing")
	live.free()
	return true

func test_enter_in_text_field_keeps_match(runner) -> bool:
	var port := SubViewport.new()
	runner.root.add_child(port)
	var main = Scene.instantiate()
	port.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	_arena(main)
	_victory(main)
	var sim_before = main.driver.pump.live()
	var field := LineEdit.new()
	main.get_node("HUD").add_child(field)
	field.grab_focus()
	runner.check(main.get_viewport().gui_get_focus_owner() == field, "R6 fixture: the text field has focus")
	main.get_viewport().push_input(InputEventMouseMotion.new())
	runner.check(not main.get_viewport().is_input_handled(), "R6 fixture: flag clear")
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.pump.live(), sim_before) and main.get_node("HUD/ResultPanel").visible, "R6 Enter in a text field does not restart")
	runner.check(not main.get_viewport().is_input_handled(), "R6 the Enter event is not swallowed")
	field.release_focus()
	field.queue_free()
	main._input(_enter(KEY_ENTER))
	runner.check(not is_same(main.driver.pump.live(), sim_before), "R6 Enter without text focus restarts")
	port.queue_free()
	return true

func test_change_setup_leaves(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = "user://r3_settings.cfg"
	DirAccess.remove_absolute(AudioSettings.path)
	PlaytestSettings.save_enabled(false)
	var main = await _setup(runner)
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_arena(main)
	_victory(main)
	main.get_node(CHANGE_SETUP).pressed.emit()
	runner.check(scenes == [main.LAUNCHER_SCENE], "R3 Back to menu leaves for the launcher, got %s" % [scenes])
	DirAccess.remove_absolute(AudioSettings.path)
	AudioSettings.path = saved
	main.free()
	return true

func test_result_panel_unit(runner) -> bool:
	var panel := ResultPanel.new()
	runner.root.add_child(panel)
	runner.check(not panel.visible, "R4 hidden at first")
	runner.check(not panel.takes_enter(_enter(KEY_ENTER)), "R4 a hidden panel takes no Enter")
	panel.show_result("Defeat", "Your friend left", false)
	var again: Button = panel.get_node("Center/Card/Box/Buttons/PlayAgain")
	var status: Label = panel.get_node("Center/Card/Box/Status")
	runner.check(panel.visible and status.text == "Your friend left" and status.visible and again.disabled, "R4 a closed room disables Play again")
	runner.check(not panel.takes_enter(_enter(KEY_ENTER)), "R4 a disabled Play again takes no Enter")
	panel.show_result("Draw", "", true)
	panel.get_viewport().gui_release_focus()
	runner.check(not again.disabled and status.visible and status.text.is_empty() and panel.takes_enter(_enter(KEY_ENTER)) and panel.takes_enter(_enter(KEY_KP_ENTER)), "R4 Enter accepted when enabled")
	runner.check(not panel.takes_enter(_enter(KEY_SPACE)), "R4 other keys are ignored")
	var echo := _enter(KEY_ENTER)
	echo.echo = true
	runner.check(not panel.takes_enter(echo), "R4 key echo is ignored")
	var release := _enter(KEY_ENTER)
	release.pressed = false
	runner.check(not panel.takes_enter(release), "R4 key release is ignored")
	var presses: Array[String] = []
	panel.play_again_pressed.connect(func() -> void: presses.append("again"))
	panel.change_setup_pressed.connect(func() -> void: presses.append("setup"))
	again.pressed.emit()
	panel.get_node("Center/Card/Box/Buttons/ChangeSetup").pressed.emit()
	runner.check(presses == ["again", "setup"], "R4 buttons emit their signals, got %s" % [presses])
	panel.show_result("", "", true)
	runner.check(not panel.visible, "R4 an empty outcome hides the panel")
	panel.free()
	return true

class StubDriver extends OfflineDriver:
	var restartable: bool
	var plays: int = 0
	func _init(can: bool) -> void:
		super(1)
		restartable = can
	func can_restart() -> bool:
		return restartable
	func play_again() -> void:
		plays += 1
	func can_play_again() -> bool:
		return restartable
	func rematch_line() -> String:
		return "Your friend left"
	var started: int = 0
	func start() -> void:
		started += 1

func test_play_again_routes_by_driver(runner) -> bool:
	var main = await _setup(runner)
	var real = main.driver
	_arena(main)
	_victory(main)
	var online := StubDriver.new(false)
	online.adopt(real.pump.live())
	main.driver = online
	main._show_result(real.pump.live().view_state())
	var status: Label = main.get_node("HUD/ResultPanel/Center/Card/Box/Status")
	runner.check(main.get_node(PLAY_AGAIN).disabled and status.text == "Your friend left", "R5 the panel shows the driver's line and can_play_again")
	main._play_again()
	runner.check(online.plays == 1, "R5 a driver that cannot restart gets play_again, got %d" % online.plays)
	var offline := StubDriver.new(true)
	main.driver = offline
	main._play_again()
	runner.check(offline.plays == 0 and offline.pump.live() != null and offline.started == 1, "R5 a restartable driver restarts, starts once and never gets play_again, started %d" % offline.started)
	main.driver = real
	main.free()
	return true

func test_silent_keys_explain(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.orders.selected_ids.clear()
	var before: Dictionary = main.driver.pump.live().snapshot()
	helper.key(main, KEY_Q)
	runner.check(main.orders._placement_kind.is_empty() and main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty() and main.hud.refusal == "Select a Bulldozer", "P4 Build with nothing selected says why, got '%s'" % main.hud.refusal)
	main.hud.refusal = ""
	main.orders.selected_ids.clear()
	helper.key(main, KEY_E)
	runner.check(main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty() and main.hud.refusal == "", "P4 E is no longer bound (user, 2026-11-20): nothing sent, no hint, got '%s'" % main.hud.refusal)
	main.free()
	return true

func _hud_texts(main) -> Array[String]:
	var texts: Array[String] = [BaseScene.hud_text(main), main.get_node("HUD/Economy/CancelBuild").text]
	var production: Node = main.get_node_or_null(BaseScene.PRODUCTION)
	if production != null: texts.append_array(BaseScene.shown_texts(production))
	return texts

func test_hud_strings_use_display_names(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = barracks
	main._refresh()
	main.orders.press_cell("usa_rifle_infantry")
	main.orders.press_cell("usa_rifle_infantry")
	BaseScene.tick(main)
	await runner.process_frame
	runner.check(BaseScene.now_row(main) != null, "N1 fixture: the queue shows")
	var shown: Array[String] = _hud_texts(main)
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1 and unit.kind == "usa_builder")[0].id
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([builder])
	main.orders._enter_placement("usa_power_plant")
	var armed: Array = main.get_node("HUD/Economy/Card").get_children().filter(func(cell: Button) -> bool: return cell.theme_type_variation == &"HudButtonArmed")
	runner.check(armed.size() == 1 and armed[0].get_node("Name").text == "Power Plant", "N1 the armed cell names the building, got %s" % [armed.map(func(cell: Button) -> String: return cell.get_node("Name").text)])
	shown.append_array(_hud_texts(main))
	main.orders._clear_placement()
	var enemy: Dictionary = sim.snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 2)[0]
	main.orders.inspected_id = enemy.id
	main._refresh()
	shown.append_array(_hud_texts(main))
	main.orders.selected_building_id = sim.snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 1 and building.kind == "usa_command_center")[0].id
	main._refresh()
	shown.append_array(_hud_texts(main))
	await runner.process_frame
	for text in shown: runner.check(not text.contains("usa_"), "N1 no raw kind id in HUD text: " + text)
	main.free()
	return true

func test_hud_font_size_is_shared(runner) -> bool:
	var main = await _setup(runner)
	var barracks: int = Fixture.build(runner, main.driver.pump.live(), "usa_barracks", Vector2i(12, 12))
	BaseScene.publish(main)
	main.orders.selected_building_id = barracks
	main._refresh()
	main.orders.press_cell("usa_rifle_infantry")
	BaseScene.tick(main)
	await runner.process_frame
	runner.check(BaseScene.now_row(main) != null, "FS1 fixture: a queue entry shows")
	for control: Control in main.get_node("HUD").find_children("*", "Control", true, false):
		if control is Label or control is BaseButton or control is LineEdit or control is TextEdit: runner.check(control.get_theme_font_size("font_size") >= 12, "FS1 %s is at least 12 px, got %d" % [control.name, control.get_theme_font_size("font_size")])
	main.free()
	return true

func test_defence_attack_scene(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(false)
	var defence: int = Fixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 10))
	var enemy: int = sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")
	var distant: int = sim.spawn(2, Vector2(30.5, 30.5), "usa_tank")
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = defence
	main._refresh()
	helper.right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8))
	var orders: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "defence_attack")
	runner.check(orders.size() == 1 and orders[0].building_id == defence and orders[0].target_id == enemy and main.hud.refusal.is_empty(), "DA5 right-click on an enemy in reach submits defence_attack")
	helper.right_click(main, Iso.world_to_plane(Vector2(30.5, 30.5)) + Vector2(0, -8))
	main.driver.flush()
	var queued: int = sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "defence_attack").size()
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "Target out of range" and queued == 1, "DA5 out of reach shows Target out of range, got " + main.hud.refusal + " " + str(distant))
	main.free()
	return true

func test_enter_unload_scene(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(false)
	var hub: int = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(10, 10))
	var enemy_hub: int = Fixture.add_completed(sim, 2, "frc_defence", Vector2i(20, 10))
	var rifle: int = sim.spawn(1, Vector2(14.5, 10.5), "frc_rifle_infantry")
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_ids.assign([rifle])
	main._refresh()
	var orders = func(type: String) -> Array: return main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == type)
	helper.right_click(main, Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8))
	var enters: Array = orders.call("enter")
	runner.check(enters.size() == 1 and enters[0].entity_ids == [rifle] and enters[0].target_id == hub and main.hud.refusal.is_empty(), "TU1 right-click on an own hub submits enter")
	helper.right_click(main, Iso.world_to_plane(Vector2(20.5, 10.5)) + Vector2(0, -8))
	var attacks: Array = orders.call("attack")
	runner.check(attacks.size() == 1 and attacks[0].target_id == enemy_hub and orders.call("enter").size() == 1, "TU1 right-click on an enemy hub still attacks")
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = hub
	main._refresh()
	helper.key(main, KEY_U)
	runner.check(orders.call("unload").is_empty(), "TU1 U no longer unloads")
	helper.key(main, KEY_F)
	runner.check(orders.call("unload").is_empty(), "TU1 F on the empty hub sends nothing (Unload hidden while empty)")
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([rifle])
	main._refresh()
	helper.key(main, KEY_F)
	runner.check(orders.call("unload").is_empty() and main.hud.refusal.is_empty(), "TU1 F without a container is not on the card: nothing sent, no hint, got '%s'" % main.hud.refusal)
	var hub_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	sim._entities[rifle].container_id = hub
	sim._entities[rifle].position = [10.5, 10.5]
	sim._players[1].tunnel = [rifle]
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = hub
	BaseScene.publish(main)
	helper.key(main, KEY_F)
	var unloads: Array = orders.call("unload")
	runner.check(unloads.size() == 1 and unloads[0].target_id == hub, "TU1 F with the loaded hub selected submits unload")
	runner.check(main._view.pick_object(hub_point) == hub, "TU1 clicking an occupied hub picks the hub, not an occupant")
	BaseScene.slab_clear(runner, main, "TU1")
	main.free()
	return true

func test_right_click_pile_gathers(runner) -> bool:
	var helper = BaseScene.new()
	for kind in ["usa_collector", "china_collector", "frc_builder"]:
		var main = await _setup(runner)
		var sim = Skirmish.create(false)
		var pile: int = sim.add_supply_source(Vector2i(20, 8), 10)
		var unit: int = sim.spawn(1, Vector2(15.5, 9.5), kind)
		sim.start_match([1, 2] as Array[int])
		main.driver.adopt(sim)
		main.orders.selected_ids.assign([unit])
		main._refresh()
		helper.right_click(main, Iso.world_to_plane(Vector2(21.5, 9.5)))
		var orders: Array = main.driver.queued()
		runner.check(orders.size() == 1 and orders[0].type == "gather" and orders[0].source_id == pile and orders[0].entity_ids == [unit], "K10 right-click on a pile sends %s to gather" % kind)
		main.free()
	return true

func test_right_click_pile_in_launcher_flow(runner) -> bool:
	var helper = BaseScene.new()
	for faction in ["frc", "china", "usa"]:
		var main = await _setup(runner)
		var sim = Skirmish.create(true, "ai", {1: faction, 2: "usa"})
		main.driver.adopt(sim)
		var pile: Dictionary = sim.snapshot().sources[0]
		var collector: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), faction + ("_builder" if faction == "frc" else "_collector"))
		var centre := Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5)
		main.orders.selected_ids.assign([collector])
		BaseScene.publish(main)
		helper.right_click(main, Iso.world_to_plane(centre))
		runner.check(_pending(main, "gather") == 1, "K11 %s collector right-click on the pile gathers, pending %s" % [faction, str(sim.snapshot().pending_commands)])
		var bystander: int = sim.spawn(1, centre, "usa_collector")
		var gathers: int = _pending(main, "gather")
		BaseScene.publish(main)
		helper.right_click(main, Iso.world_to_plane(centre) + Vector2(0, -26))
		runner.check(_pending(main, "gather") == gathers + 1 and bystander > 0, "K12 %s right-click on a pile with an own helicopter hovering over it still gathers, pending %s err %s" % [faction, str(sim.snapshot().pending_commands.map(func(c: Dictionary) -> String: return c.type)), main.hud.refusal])
		main.free()
	return true

func test_frc_laborer_right_click_pile(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.adopt(sim)
	var pile: Dictionary = sim.snapshot().sources[0]
	var click: Vector2 = Iso.world_to_plane(Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5))
	var laborers: Array[int] = []
	for unit: Dictionary in sim.snapshot().entities:
		if unit.owner == 1: laborers.append(unit.id)
	laborers.append(sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder"))
	var site: Dictionary = Fixture.send(sim, {"type": "build", "builder_id": laborers[1], "building_kind": "frc_barracks", "origin": [pile.origin[0] + 8, pile.origin[1] + 8]})
	runner.check(site.ok, "K13 foundation for the laborer: " + site.error)
	Fixture.steps(sim, 40)
	main.orders.selected_ids.assign(laborers)
	BaseScene.publish(main)
	helper.right_click(main, click)
	main.driver.flush()
	var orders: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "gather")
	runner.check(orders.size() == 1 and orders[0].entity_ids == laborers and orders[0].source_id == pile.id, "K13 several laborers, one of them building, right-click the pile gathers, got %s err %s" % [str(sim.snapshot().pending_commands), main.hud.refusal])
	Fixture.steps(sim, 3)
	runner.check(sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.id in laborers and u.collection.enabled).size() == laborers.size(), "K13 every laborer, including the builder, starts collecting")
	main.orders.selected_ids.assign([laborers[0]])
	BaseScene.publish(main)
	helper.build_key(main, "frc_supply_center")
	var ghost: String = main.orders._placement_kind
	helper.right_click(main, click)
	var gathers: int = _pending(main, "gather")
	runner.check(not ghost.is_empty() and main.orders._placement_kind.is_empty(), "K13 right-click with a build ghost cancels the ghost, ghost was " + ghost)
	helper.right_click(main, click)
	runner.check(_pending(main, "gather") == gathers + 1, "K13 the next right-click on the pile gathers")
	main.free()
	return true

func test_one_snapshot_per_refresh(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	main.driver.adopt(sim)
	main.orders.selected_building_id = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	BaseScene.publish(main)
	Profiler.reset()
	Profiler.enabled = true
	main._refresh()
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 0, "RF2 a skirmish refresh with a production building selected takes no snapshot and no view state, got %d and %d" % [snapshots, views])
	runner.check(main.get_node("HUD/Economy/Card/Q/Name").text == "Rifleman", "RF2 the barracks' card still names its unit, got '%s'" % main.get_node("HUD/Economy/Card/Q/Name").text)
	main.free()
	return true

func test_refresh_waits_for_next_frame(runner) -> bool:
	var main = await _setup(runner)
	main.set_process(true)
	await runner.process_frame
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() == 1 and main._view._state.tick == 0, "RF3 a step does not refresh in its own frame")
	await runner.process_frame
	runner.check(main._view._state.tick == 0, "RF3 still not refreshed before the frame's _process")
	await runner.process_frame
	runner.check(main._view._state.tick == 1, "RF3 the next frame's _process refreshes")
	main.free()
	return true

func test_auto_pick_samples_present_time(runner) -> bool:
	var main = await _setup(runner)
	main._start_auto_pick(true)
	main._auto_frame = main.AUTO_SKIP_FRAMES
	main.set_process(true)
	await runner.process_frame
	BaseScene.tick(main)
	main.set_process(false)
	await runner.process_frame
	main._auto_tick_usec = 0
	main._view.draw_usec = 0
	main._auto_samples.clear()
	main._process(0.0)
	main._start_auto_pick(false)
	runner.check(main._auto_samples.size() == 1 and main._auto_samples[0] > 0.0, "RF4 the automatic quality sample includes the time of the frame's present")
	main.free()
	return true

const HUD_TEXTS: Array[String] = ["Rifleman · 146 / 180 · ", "Supply Helicopter · 300 / 300 · WAITING AT PILE", "Supply Helicopter · 300 / 300 · TO PILE", "Bulldozer · 250 / 250 · ", "Rifleman · 180 / 180 · ", "Headquarters · 5000 / 5000 · "]

static func _panel_text(main, part: String) -> String:
	var label: Label = main.get_node("HUD/Hud/SelectionPanel").find_child(part, true, false)
	return label.text if label.is_visible_in_tree() else ""

func _ids_where(units: Array, test: Callable) -> Array[int]:
	var ids: Array[int] = []
	for unit: Dictionary in units:
		if test.call(unit): ids.append(unit.id)
	return ids

func test_hud_summaries_are_pinned(runner) -> bool:
	var main = await _setup(runner)
	var sim = ViewRows.skirmish_sim()
	main.driver.adopt(sim)
	var state: Dictionary = sim.snapshot()
	var own: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1)
	var waiting: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.collection != null and unit.collection.phase.begins_with("waiting_"))
	var working: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.collection != null and unit.collection.enabled and not unit.collection.phase.begins_with("waiting_"))
	var firing: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.combat != null and unit.combat.target_id != null)
	var plain: Array[int] = _ids_where(own, func(unit: Dictionary) -> bool: return unit.combat == null and unit.collection == null)
	var enemy_unit: Array[int] = _ids_where(state.entities, func(unit: Dictionary) -> bool: return unit.owner == 2 and unit.combat != null)
	var enemy_building: Array[int] = _ids_where(state.buildings, func(building: Dictionary) -> bool: return building.owner == 2)
	runner.check(waiting.size() >= 2 and not working.is_empty() and not firing.is_empty() and not plain.is_empty() and not enemy_unit.is_empty() and not enemy_building.is_empty(), "HUD1 fixture: every case has its unit")
	var view: Dictionary = sim.view_state()
	var texts: Array[String] = []
	var edges: Array = []
	for row: Array in [[firing[0], -1], [waiting[-1], -1], [working[0], -1], [plain[0], -1], [-1, enemy_unit[0]], [-1, enemy_building[0]]]:
		main.orders.selected_ids.assign([row[0]] if row[0] != -1 else [])
		main.orders.inspected_id = row[1]
		main._show(view)
		texts.append("%s · %s · %s" % [_panel_text(main, "Name"), _panel_text(main, "Health"), _panel_text(main, "RightLabel")])
		edges.append(main.hud.panel_edge() == View.owner_color(1 if row[1] == -1 else 2))
	runner.check(texts == HUD_TEXTS, "HUD1 pinned panel and collector texts, got " + str(texts))
	runner.check(not edges.has(false), "HUD1 each panel edge is its owner's colour, got %s" % [edges])
	main.free()
	return true

func _ic_row(main, step: int, seen: Array, status: bool = false) -> String:
	main.driver.flush()
	var pending: Array = main.driver.pump.live().snapshot().pending_commands
	var added: PackedStringArray = []
	for command: Dictionary in pending.slice(mini(seen[0], pending.size())): added.append(JSON.stringify(command))
	seen[0] = pending.size()
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

func _ic_click(helper, main, plane: Vector2) -> void:
	helper.pointer(main, plane, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, plane, MOUSE_BUTTON_LEFT, false)

func _ic_box(plane_a: Vector2, plane_b: Vector2, margin: float) -> Array[Vector2]:
	var low := Vector2(minf(plane_a.x, plane_b.x), minf(plane_a.y, plane_b.y)) - Vector2.ONE * margin
	var high := Vector2(maxf(plane_a.x, plane_b.x), maxf(plane_a.y, plane_b.y)) + Vector2.ONE * margin
	return [low, high]

func _ic_world(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var ids := {}
	ids.tank_a = sim.spawn(1, Vector2(10.5, 6.5), "usa_tank")
	ids.tank_b = sim.spawn(1, Vector2(11.5, 6.5), "usa_tank")
	ids.enemy = sim.spawn(2, Vector2(15.5, 6.5), "usa_tank")
	ids.builder = sim.spawn(1, Vector2(6.5, 12.5), "frc_builder")
	ids.infantry = sim.spawn(1, Vector2(14.5, 14.5), "frc_rifle_infantry")
	ids.barracks = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(20, 20))
	ids.site = Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(26, 12))
	sim._buildings[ids.site].completed = false
	ids.hub = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(30, 22))
	ids.occupant = sim.spawn(1, Vector2(28.5, 22.5), "frc_rifle_infantry")
	sim._entities[ids.occupant].container_id = ids.hub
	sim._entities[ids.occupant].position = [30.5, 22.5]
	sim._players[1].tunnel = [ids.occupant]
	ids.pile = sim.add_supply_source(Vector2i(34, 8), 10)
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main._refresh()
	return ids

func _ic_first_difference(rows: PackedStringArray, expected: PackedStringArray) -> int:
	for i in maxi(rows.size(), expected.size()):
		if i >= rows.size() or i >= expected.size() or rows[i] != expected[i]: return i
	return -1

func test_input_script_offline(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _ic_world(main)
	var seen: Array = [0]
	var rows := PackedStringArray()
	var at = func(x: float, y: float) -> Vector2: return Iso.world_to_plane(Vector2(x, y)) + Vector2(0, -8)
	var tanks: Array[Vector2] = _ic_box(Iso.world_to_plane(Vector2(10.5, 6.5)), Iso.world_to_plane(Vector2(11.5, 6.5)), 30.0)
	var sim_orders = func(type: String) -> int: return _pending(main, type)
	helper.pointer(main, tanks[0], MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, tanks[1], MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_ids == [ids.tank_a, ids.tank_b], "IC1 step 1 took effect")
	rows.append(_ic_row(main, 1, seen))
	helper.right_click(main, Iso.world_to_plane(Vector2(20.5, 10.5)))
	runner.check(sim_orders.call("move") == 1, "IC1 step 2 took effect")
	rows.append(_ic_row(main, 2, seen))
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(24.5, 8.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(24.5, 8.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(sim_orders.call("attack_move") == 1, "IC1 step 3 took effect")
	rows.append(_ic_row(main, 3, seen, true))
	helper.key(main, KEY_S)
	runner.check(sim_orders.call("stop") == 1, "IC1 step 4 took effect")
	rows.append(_ic_row(main, 4, seen))
	helper.right_click(main, at.call(15.5, 6.5))
	runner.check(sim_orders.call("attack") == 1, "IC1 step 5 took effect")
	rows.append(_ic_row(main, 5, seen))
	helper.pointer(main, tanks[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_S)
	helper.pointer(main, tanks[1], MOUSE_BUTTON_LEFT, false)
	runner.check(sim_orders.call("stop") == 1 and main.orders.selected_ids == [ids.tank_a, ids.tank_b], "IC1 step 6 took effect")
	rows.append(_ic_row(main, 6, seen))
	_ic_esc(main)
	runner.check(main.orders.selected_ids.is_empty(), "IC1 step 7 took effect")
	rows.append(_ic_row(main, 7, seen))
	_ic_esc(main)
	runner.check(main.menu_open(), "IC1 step 8 opened the menu")
	_ic_esc(main)
	runner.check(not main.menu_open(), "IC1 step 8 took effect")
	rows.append(_ic_row(main, 8, seen))
	_ic_click(helper, main, at.call(6.5, 12.5))
	helper.build_key(main, "frc_supply_center")
	runner.check(not main.orders._placement_kind.is_empty(), "IC1 step 9 took effect")
	rows.append(_ic_row(main, 9, seen, true))
	helper.key(main, KEY_F3)
	rows.append(_ic_row(main, 10, seen))
	helper.pointer(main, Iso.world_to_plane(Vector2(36.5, 26.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(sim_orders.call("build") == 1, "IC1 step 11 took effect")
	rows.append(_ic_row(main, 11, seen))
	BaseScene.tick(main)
	seen[0] = 0
	_ic_click(helper, main, at.call(21.0, 21.0))
	helper.produce_key(main, "usa_rifle_infantry")
	runner.check(sim_orders.call("produce") == 1, "IC1 step 12 took effect")
	rows.append(_ic_row(main, 12, seen, true))
	helper.right_click(main, Iso.world_to_plane(Vector2(26.5, 16.5)))
	runner.check(sim_orders.call("set_rally") == 1, "IC1 step 13 took effect")
	rows.append(_ic_row(main, 13, seen))
	_ic_click(helper, main, at.call(6.5, 12.5))
	helper.right_click(main, at.call(27.0, 13.0))
	runner.check(sim_orders.call("resume_build") == 1, "IC1 step 14 took effect")
	rows.append(_ic_row(main, 14, seen))
	_ic_click(helper, main, at.call(30.5, 22.5))
	helper.key(main, KEY_F)
	runner.check(sim_orders.call("unload") == 1, "IC1 step 15 took effect")
	rows.append(_ic_row(main, 15, seen))
	_ic_click(helper, main, at.call(14.5, 14.5))
	helper.right_click(main, at.call(30.5, 22.5))
	runner.check(sim_orders.call("enter") == 1, "IC1 step 16 took effect")
	rows.append(_ic_row(main, 16, seen))
	var builder_box: Array[Vector2] = _ic_box(Iso.world_to_plane(Vector2(6.5, 12.5)), Iso.world_to_plane(Vector2(6.5, 12.5)), 30.0)
	helper.pointer(main, builder_box[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_Q)
	helper.pointer(main, builder_box[1], MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders._placement_kind.is_empty() and not main.orders._sub_grid, "IC1 step 17 a card key during the drag pressed nothing")
	helper.build_key(main, "frc_supply_center")
	runner.check(not main.orders._placement_kind.is_empty(), "IC1 step 17 took effect")
	rows.append(_ic_row(main, 17, seen))
	_ic_esc(main)
	_ic_esc(main)
	runner.check(main.orders._placement_kind.is_empty() and not main.orders._sub_grid and main.orders.selected_ids == [ids.builder], "IC1 step 18 took effect")
	rows.append(_ic_row(main, 18, seen))
	_ic_click(helper, main, at.call(15.5, 6.5))
	runner.check(main.orders.inspected_id == ids.enemy, "IC1 step 19 took effect")
	rows.append(_ic_row(main, 19, seen, true))
	_ic_click(helper, main, at.call(6.5, 12.5))
	helper.right_click(main, at.call(35.0, 9.0))
	runner.check(sim_orders.call("gather") == 1, "IC1 step 20 took effect")
	rows.append(_ic_row(main, 20, seen))
	BaseScene.tick(main)
	rows.append(_ic_row(main, 21, seen) + "|tick=%d" % main.driver.pump.live().tick())
	var first: int = _ic_first_difference(rows, IcRows.IC1_ROWS)
	runner.check(first == -1, "IC1 row %d matches the chain recorded 2026-11-14, got %s" % [first, rows[first] if first >= 0 and first < rows.size() else "no row"])
	main.free()
	return true

func test_offline_driver_stamps_like_the_scene(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.adopt(Skirmish.create(false))
	var unit: int = driver.pump.live().spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	driver.pump.live().start_match([1, 2] as Array[int])
	var tick: int = driver.pump.live().snapshot().tick
	var first: Dictionary = driver.submit({"type": "stop", "entity_ids": [unit]})
	var refused: Dictionary = driver.submit({"type": "attack", "entity_ids": [unit], "target_id": 999999})
	var second: Dictionary = driver.submit({"type": "stop", "entity_ids": [unit]})
	driver.flush()
	var queued: Array = driver.pump.live().snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "stop")
	var stamps: Array = queued.map(func(command: Dictionary) -> Array: return [command.tick, command.player, command.sequence])
	runner.check(first.ok and refused.ok and second.ok and stamps == [[tick, 1, 0], [tick, 1, 1]] and driver.record().commands.size() == 2, "OD1 offline driver stamps tick, player and sequence like main._submit")
	driver.step()
	driver.drain()
	var answers: Array = driver.take_answers().map(func(answer: Dictionary) -> Array: return [answer.command.type, answer.command.sequence, answer.ok, not answer.error.is_empty()])
	runner.check(answers == [["stop", 0, true, false], ["attack", 1, false, true], ["stop", 1, true, false]], "OD1 the next step answers all three in order, got %s" % [answers])
	return true

func test_sb1_idle_offline_ticks_take_no_snapshot(runner) -> bool:
	var main = await _setup(runner)
	main.driver.adopt(Skirmish.create())
	main._refresh()
	Profiler.reset()
	Profiler.enabled = true
	for i in 300: BaseScene.tick(main)
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 300, "RB7 300 idle offline ticks take no snapshot and one view state each, got %d and %d" % [snapshots, views])
	main.free()
	return true

func test_offline_driver_no_tick_hash_rows_after_the_end(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.adopt(Skirmish.create(true, "ai"))
	for i in 59: driver.step()
	driver.drain()
	var live = driver.pump.live()
	var state: Dictionary = live.snapshot()
	for object: Dictionary in state.entities + state.buildings:
		if object.owner == 2: live.remove_object(object.id)
	driver.step()
	driver.drain()
	runner.check(driver.over() and live.tick() == 60, "TH fixture: the match ends at tick 60, tick %d" % live.tick())
	for i in 40:
		driver.submit({"type": "stop", "entity_ids": [state.entities[0].id]})
		driver.step()
		driver.drain()
	var ticks: Array = Array(driver.record().tick_hashes).map(func(row: String) -> String: return row.get_slice("\t", 0))
	runner.check(live.tick() == 60 and ticks == ["30", "60"], "TH offline rows stop at the end: only ticks 30 and 60, got %s at tick %d" % [ticks, live.tick()])
	return true

func test_offline_driver_bot_memory_on_simulation(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.adopt(Skirmish.create())
	while driver.pump.live().tick() < Skirmish.next_decision(Skirmish.FIRST_WAVE_TICK, 2): driver.pump.live().step()
	driver.step()
	runner.check(driver.pump.live().has_meta(Skirmish.BOT_META) and not driver.has_meta(Skirmish.BOT_META), "OD2 bot memory lives on the simulation, not the driver")
	return true

func test_sb1_submit_takes_no_snapshot(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.adopt(Skirmish.create(false))
	var unit: int = driver.pump.live().spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	driver.pump.live().start_match([1, 2] as Array[int])
	var tick: int = driver.pump.live().tick()
	Profiler.reset()
	Profiler.enabled = true
	driver.submit({"type": "stop", "entity_ids": [unit]})
	driver.submit({"type": "attack", "entity_ids": [unit], "target_id": 999999})
	driver.submit({"type": "stop", "entity_ids": [unit]})
	var snapshots: int = Profiler.calls(&"snapshot")
	Profiler.enabled = false
	Profiler.reset()
	driver.flush()
	var queued: Array = driver.pump.live().snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "stop")
	var stamps: Array = queued.map(func(command: Dictionary) -> Array: return [command.tick, command.player, command.sequence])
	runner.check(snapshots == 0, "RB3 offline submit takes no snapshot, got %d" % snapshots)
	runner.check(stamps == [[tick, 1, 0], [tick, 1, 1]], "OD1 stamps survive the snapshot-free submit")
	return true

func _mouse(main, plane: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	event.button_index = button
	event.pressed = pressed
	return event

func test_orders_turn_input_into_payloads(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var orders = main.orders
	orders.selected_ids.clear()
	var box: Array[Vector2] = _ic_box(Iso.world_to_plane(Vector2(10.5, 10.5)), Iso.world_to_plane(Vector2(11.5, 10.5)), 30.0)
	orders.handle(_mouse(main, box[0], MOUSE_BUTTON_LEFT, true))
	orders.handle(_mouse(main, box[1], MOUSE_BUTTON_LEFT, false))
	var ground := Vector2(12.5, 13.5)
	var before: int = _pending(main, "move")
	orders.handle(_mouse(main, Iso.world_to_plane(ground), MOUSE_BUTTON_RIGHT, true))
	main.driver.flush()
	var moves: Array = main.driver.pump.live().snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "move")
	var payload_ok: bool = moves.size() == before + 1 and moves[-1].entity_ids == orders.selected_ids and Vector2(moves[-1].target[0], moves[-1].target[1]).distance_to(ground) <= 1e-3
	runner.check(orders.selected_ids == [ids.infantry, ids.tank] and payload_ok, "OR1 orders own the selection and emit the move payload")
	main.free()
	return true

func test_hud_reads_only_state_and_orders(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = barracks
	var produce: Control = main.get_node("HUD/Economy/Card")
	produce.hide()
	main.hud.refuse("Choose one builder")
	main.stepped_results.append({"ok": false, "error": "Not yours", "player": 2, "tick": 5, "sequence": 0})
	var view: Dictionary = sim.view_state()
	main._take_results(view)
	main.hud.update_hud(view, main._hud_selection(), main.local_player, main.local_player)
	var line: String = (main.get_node("HUD/Hud/RefusalLine").find_child("Text", true, false) as Label).text if main.get_node("HUD/Hud/RefusalLine").visible else ""
	runner.check(produce.visible and _panel_text(main, "Name") == Registry.kind("usa_barracks").display_name and main.hud.refusal == "Choose one builder" and line == "Choose one builder", "HU1 the HUD shows the selection and keeps the local hint on the line, got '%s'" % line)
	runner.check(main.hud.refusal != "Not yours" and not BaseScene.hud_text(main).contains("Not yours"), "HU1 _take_results ignores player 2's stepped result, got '%s'" % main.hud.refusal)
	main.free()
	return true

func _free_cell(sim, builder: int, kind: String) -> Vector2i:
	var start: Vector2i = Vector2i(sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.id == builder)[0].position[0], 0)
	for y in range(4, 40):
		for x in range(start.x - 10, start.x + 10):
			if sim.preview_build(1, builder, kind, Vector2i(x, y)).ok: return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_sb1_economy_input_reads_shown(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	var builder: int = sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 1)[0].id
	var cell: Vector2i = _free_cell(sim, builder, "usa_power_plant")
	var pile: Dictionary = sim.snapshot().sources[0]
	main.orders.selected_ids.assign([builder])
	main._refresh()
	Profiler.reset()
	Profiler.enabled = true
	helper.build_key(main, "usa_power_plant")
	var spot: Vector2 = Iso.world_to_plane(Vector2(cell) + Vector2(0.25, 0.25))
	helper.hover(main, spot)
	helper.pointer(main, spot, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, spot, MOUSE_BUTTON_LEFT, false)
	helper.right_click(main, Iso.world_to_plane(Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5)))
	helper.key(main, KEY_F)
	var click: Vector2 = Iso.world_to_plane(Vector2(13.5, 13.5))
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, false)
	helper.produce_key(main, "usa_rifle_infantry")
	helper.right_click(main, Iso.world_to_plane(Vector2(16.5, 10.5)))
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0, "RB1 economy input takes no snapshot, got %d snapshots" % snapshots)
	runner.check(views == 0, "RB1 economy input builds no view state, got %d" % views)
	runner.check(main.orders.selected_building_id == barracks and _pending(main, "build") == 1 and _pending(main, "produce") == 1 and _pending(main, "set_rally") == 1, "RB1 one build, produce and set_rally, got %s" % str(sim.snapshot().pending_commands.map(func(c: Dictionary) -> String: return c.type)))
	main.free()
	return true

func test_sb1_combat_input_reads_shown(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var plane: Vector2 = Iso.world_to_plane(Vector2(11.5, 10.5)) + Vector2(0, -8)
	Profiler.reset()
	Profiler.enabled = true
	helper.right_click(main, Iso.world_to_plane(Vector2(19.5, 11.5)))
	helper.right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8))
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(19.5, 11.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(19.5, 11.5)), MOUSE_BUTTON_LEFT, false)
	helper.key(main, KEY_S)
	var double := InputEventMouseButton.new()
	double.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	double.button_index = MOUSE_BUTTON_LEFT
	double.double_click = true
	double.pressed = true
	main._unhandled_input(double)
	double.pressed = false
	main._unhandled_input(double)
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0, "RB2 combat input takes no snapshot, got %d snapshots" % snapshots)
	runner.check(views == 0, "RB2 combat input builds no view state, got %d" % views)
	runner.check(_pending(main, "move") == 1 and _pending(main, "attack") == 1 and _pending(main, "attack_move") == 1 and _pending(main, "stop") == 1, "RB2 one move, attack, attack_move and stop")
	runner.check(main.orders.selected_ids == [ids.tank], "RB2 double-click selects the tank, got %s" % str(main.orders.selected_ids))
	main.free()
	return true

func test_sb1_pick_of_unit_dead_since_shown(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.driver.pump.live().remove_object(ids.infantry)
	runner.check(main.orders._matching_ids(ids.infantry, true).has(ids.infantry), "RB4 the shown view still picks the unit")
	var double := InputEventMouseButton.new()
	double.position = main.get_node("WorldView").get_global_transform_with_canvas() * (Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8))
	double.button_index = MOUSE_BUTTON_LEFT
	double.double_click = true
	double.pressed = true
	main._unhandled_input(double)
	double.pressed = false
	main._unhandled_input(double)
	BaseScene.publish(main)
	runner.check(not main.orders.selected_ids.has(ids.infantry), "RB4 pick of a unit dead since the shown view does not error")
	main.orders.selected_ids.assign([ids.infantry])
	helper.key(main, KEY_S)
	runner.check(_pending(main, "stop") == 0, "RB4 the shown view no longer holds the unit, so its card has no Stop: nothing sent")
	BaseScene.tick(main)
	runner.check(main.hud.refusal.is_empty(), "RB4 and nothing to refuse, got '%s'" % main.hud.refusal)
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	var pending: int = _pending(main, "stop")
	helper.key(main, KEY_S)
	runner.check(_pending(main, "stop") == pending + 1, "RB4 a mixed selection keeps its stop")
	main.free()
	return true

func test_sb1_result_uses_shown_team(runner) -> bool:
	var main = await _setup(runner)
	var first = Simulation.new()
	first.add_player(1, 0, "human", 1)
	var second = Simulation.new()
	second.add_player(1, 0, "human", 7)
	main.driver.adopt(first)
	main._refresh()
	main.driver.adopt(second)
	runner.check(main._result_text({"status": "won", "winner": 7}) == "Defeat", "RB6 the result reads the shown team")
	main._refresh()
	runner.check(main._result_text({"status": "won", "winner": 7}) == "Victory", "RB6 a refresh shows the new team")
	main.free()
	return true

func test_sb1_setup_shown_allows_input(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	runner.check(not main.shown_over(), "RB9 a running match is not over")
	var view: Dictionary = main.shown_state.duplicate()
	view.match = view.match.duplicate()
	view.match.status = "setup"
	main._show(view)
	main.orders.selected_ids.clear()
	var box: Array[Vector2] = _ic_box(Iso.world_to_plane(Vector2(10.5, 10.5)), Iso.world_to_plane(Vector2(11.5, 10.5)), 30.0)
	main.orders.handle(_mouse(main, box[0], MOUSE_BUTTON_LEFT, true))
	main.orders.handle(_mouse(main, box[1], MOUSE_BUTTON_LEFT, false))
	runner.check(not main.shown_over() and not main.orders.selected_ids.is_empty(), "RB9 a setup-phase view still selects")
	main.free()
	return true

func _error_cues(main) -> int:
	return main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "error").size()

func _off_map_move(ids: Dictionary) -> Dictionary:
	return {"type": "move", "entity_ids": [ids.tank], "target": [-5.0, -5.0]}

func test_sb2_refusal_next_step(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var moves: int = _pending(main, "move")
	main._submit(_off_map_move(ids))
	main.driver.flush()
	runner.check(main.hud.refusal == "" and _pending(main, "move") == moves, "RA1 a refused move shows nothing at submit, got '%s'" % main.hud.refusal)
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "Target outside map" and _error_cues(main) == 1, "RA1 the refusal and one beep arrive with the next step, got '%s' and %d" % [main.hud.refusal, _error_cues(main)])
	BaseScene.slab_clear(runner, main, "RA1")
	main.free()
	return true

func test_sb2_refusal_survives_accepted_result(runner) -> bool:
	for processing: bool in [false, true]:
		for refused_first: bool in [false, true]:
			var main = await _setup(runner)
			var ids: Dictionary = _arena(main)
			if processing:
				main.set_process(true)
				await runner.process_frame
			var stop := {"type": "stop", "entity_ids": [ids.tank]}
			for payload: Dictionary in ([_off_map_move(ids), stop] if refused_first else [stop, _off_map_move(ids)]): main._submit(payload)
			BaseScene.tick(main)
			if processing:
				await runner.process_frame
				await runner.process_frame
			runner.check(main.hud.refusal == "Target outside map" and BaseScene.hud_text(main).contains("Target outside map"), "RA3 an accepted result keeps the refusal (processing %s, refused first %s), got '%s'" % [processing, refused_first, main.hud.refusal])
			main.free()
	return true

func test_one_line_one_beep_per_drain(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._submit(_off_map_move(ids))
	main._submit({"type": "stop", "entity_ids": [999]})
	BaseScene.tick(main)
	var text: String = BaseScene.hud_text(main)
	runner.check(main.hud.refusal == "Missing entity or wrong owner" and text.count("Missing entity or wrong owner") == 1 and not text.contains("Target outside map"), "RN4 two refusals in one drain show the second once, got '%s'" % main.hud.refusal)
	runner.check(_error_cues(main) == 1, "RN4 two refusals in one drain beep once, got %d" % _error_cues(main))
	main.free()
	return true

func test_due_failure_beeps_once(runner) -> bool:
	var main = await _setup(runner)
	main.driver.adopt(Fixture.make_world())
	main._refresh()
	for i in 2: main._submit({"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [8, 4]})
	var beeps: int = 0
	for i in 4:
		BaseScene.tick(main)
		beeps += _error_cues(main)
	var line: Control = main.get_node("HUD/Hud/RefusalLine")
	var text: String = (line.find_child("Text", true, false) as Label).text
	runner.check(line.visible and not text.is_empty() and text == main.hud.refusal, "RN7 an own due-time failure shows on the line, got '%s'" % text)
	runner.check(beeps == 1, "RN7 the due-time failure beeps once (the sound director's), got %d" % beeps)
	main.free()
	return true

func test_no_refusal_over_a_card(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var live = main.driver.pump.live()
	for object: Dictionary in live.snapshot().entities + live.snapshot().buildings:
		if object.owner == 2: live.remove_object(object.id)
	BaseScene.tick(main)
	runner.check(main.shown_over(), "RN8 fixture: the match is won")
	main._submit(_off_map_move(ids))
	main.refuse("Choose one builder", "")
	main.refuse("Target outside map")
	var beeps: int = 0
	for i in 2:
		BaseScene.tick(main)
		beeps += _error_cues(main)
	runner.check(main.hud.refusal.is_empty() and not main.get_node("HUD/Hud/RefusalLine").visible and beeps == 0, "RN8 under the result card nothing refuses on the line or beeps, got '%s' and %d" % [main.hud.refusal, beeps])
	main.free()
	main = await _setup(runner)
	var world: Dictionary = _frozen_arena(main)
	main.driver.submit(_off_map_move(world.ids))
	world.pump.fail_next = true
	BaseScene.tick(main)
	runner.check(main.frozen(), "RN8 fixture: the pump failed")
	main.refuse("Target outside map")
	BaseScene.tick(main)
	runner.check(main.hud.refusal.is_empty() and not main.get_node("HUD/Hud/RefusalLine").visible and _error_cues(main) == 0, "RN8 under the freeze card nothing refuses on the line or beeps, got '%s' and %d" % [main.hud.refusal, _error_cues(main)])
	main.free()
	return true

func test_sb2_restart_drops_held_answer(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._submit(_off_map_move(ids))
	main._restart()
	BaseScene.tick(main)
	runner.check(main.hud.refusal.is_empty() and not BaseScene.hud_text(main).contains("Target outside map") and _error_cues(main) == 0, "RA4 a restart drops the held answer, got '%s'" % main.hud.refusal)
	main.free()
	return true

func test_sb2_answer_waits_for_unpause(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._submit(_off_map_move(ids))
	main._pause.open()
	runner.check(main.menu_open(), "RA5 fixture: the menu holds the match")
	BaseScene.tick(main)
	BaseScene.tick(main)
	runner.check(main.hud.refusal.is_empty(), "RA5 the answer waits behind the menu, got '%s'" % main.hud.refusal)
	main._pause.close()
	BaseScene.tick(main)
	var errors: int = _error_cues(main)
	runner.check(main.hud.refusal == "Target outside map" and BaseScene.hud_text(main).count("Target outside map") == 1 and errors == 1, "RA5 the answer arrives once on resume, got '%s' and %d beeps" % [main.hud.refusal, errors])
	BaseScene.tick(main)
	errors += _error_cues(main)
	runner.check(errors == 1, "RA5 one beep in total, got %d" % errors)
	main.free()
	return true

func test_sb3_submit_queues(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._submit({"type": "stop", "entity_ids": [ids.tank]})
	runner.check(main.driver.queued().size() == 1 and main.driver.pump.live().snapshot().pending_commands.is_empty(), "SB3 an offline submit waits in the driver queue, got %d queued" % main.driver.queued().size())
	BaseScene.tick(main)
	runner.check(main.driver.queued().is_empty() and main.driver.pump.live().last_sequence(1) == 0, "SB3 the next job issues it as sequence 0, got %d" % main.driver.pump.live().last_sequence(1))
	main.free()
	return true

func _replayed_digest(main, recorded: Array[Dictionary]) -> String:
	var oracle = Skirmish.create(true, "human", main.factions, main.map_path, main.starts)
	var pending: Array = recorded.duplicate()
	for tick in main.driver.record().tick:
		while not pending.is_empty() and pending[0].tick == tick: oracle.issue_command(pending.pop_front())
		oracle.step()
	return StateHash.digest(oracle.snapshot())

func test_sb3_match_log_equals_recorder(runner) -> bool:
	var main = await _setup(runner)
	var stop := {"type": "stop", "entity_ids": [1]}
	for i in 300:
		if i == 10: main.driver.submit(stop)
		if i == 20: main.driver.submit({"type": "move", "entity_ids": [1], "target": [-5.0, -5.0]})
		if i == 30: main.driver.submit(stop)
		BaseScene.tick(main)
	var recorded: Array[Dictionary] = main.driver.record().commands
	var own: int = recorded.filter(func(command: Dictionary) -> bool: return command.player == 1).size()
	runner.check(own == 2 and recorded.size() > own, "SB3 fixture: two accepted own orders and the bot's, got %d of %d" % [own, recorded.size()])
	runner.check(main.driver.match_log().commands == Lockstep.log_lines(recorded), "SB3 the offline match log equals the recorder's commands")
	runner.check(_replayed_digest(main, recorded) == main.driver.record().digest, "SB3 a replay of the recorded commands reaches the recorded digest")
	main.free()
	return true

func test_sb3_restart_drops_old_notes(runner) -> bool:
	for posted: bool in [false, true]:
		var main = await _setup(runner)
		var ids: Dictionary = _arena(main)
		main._submit(_off_map_move(ids))
		if posted: main._physics_process(1.0 / 30.0)
		main._restart()
		BaseScene.tick(main)
		runner.check(main.hud.refusal.is_empty() and not BaseScene.hud_text(main).contains("Target outside map") and _error_cues(main) == 0 and main.driver.queued().is_empty() and main.driver.current().tick == 1, "SB3 a restart shows nothing from the old match (posted %s), got '%s', %d beeps, tick %d" % [posted, main.hud.refusal, _error_cues(main), main.driver.current().tick])
		main.free()
	return true

func test_sb3_paused_posts_nothing(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	main._ensure_sound()
	main._pause.open()
	var tick: int = main.driver.current().tick
	var consumed: Array[int] = main._sound.director.consumed_ticks().duplicate()
	for i in 10: BaseScene.tick(main)
	runner.check(main.driver.current().tick == tick and main.driver.pump.live().tick() == tick and main._sound.director.consumed_ticks() == consumed, "SB3 a paused match posts and drains nothing, got tick %d" % main.driver.pump.live().tick())
	main.free()
	return true

func test_sb3_over_stops_refreshing(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	main.set_process(true)
	main.driver.pump.live().remove_object(3)
	main.driver.pump.live().remove_object(4)
	BaseScene.tick(main)
	var results: int = main.stepped_results.size()
	Profiler.reset()
	Profiler.enabled = true
	for i in 9: BaseScene.tick(main)
	var refreshes: int = Profiler.calls(&"refresh.hud")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(main.driver.over() and refreshes == 0 and views == 0 and main.stepped_results.size() == results, "SB3 a finished match neither posts nor refreshes, got %d refreshes, %d views, %d results" % [refreshes, views, main.stepped_results.size() - results])
	main.free()
	return true

func test_sb3_process_drains(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._ensure_sound()
	var tick: int = main.driver.current().tick
	var collected: int = main._sound.director.collected_ticks().size()
	main._submit(_off_map_move(ids))
	main._physics_process(1.0 / 30.0)
	main._physics_process(1.0 / 30.0)
	runner.check(main.driver.current().tick == tick and main.shown_state.tick == tick and main.hud.refusal.is_empty() and _error_cues(main) == 0 and main._sound.director.collected_ticks().size() == collected, "SB3 physics frames post but show nothing before a drain, got '%s'" % main.hud.refusal)
	main._process(0.0)
	var ticks: Array[int] = main._sound.director.consumed_ticks().slice(-2)
	runner.check(ticks == [tick + 1, tick + 2] and main.driver.current().tick == tick + 2 and main.shown_state.tick == tick + 2, "SB3 _process drains both notes and shows the last tick, got %s and shown %d" % [ticks, main.shown_state.tick])
	runner.check(main.hud.refusal == "Target outside map" and BaseScene.hud_text(main).contains("Target outside map") and _error_cues(main) == 1, "SB3 _process delivers the refusal to the HUD once, got '%s' and %d beeps" % [main.hud.refusal, _error_cues(main)])
	main.free()
	return true

func test_sb3_refusal_waits_in_queue(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main._ensure_sound()
	main._submit(_off_map_move(ids))
	var queued: Array = main.driver.queued()
	runner.check(queued.size() == 1 and queued[0].type == "move" and queued[0].target == [-5.0, -5.0] and not queued[0].has("sequence") and main.hud.refusal.is_empty() and _error_cues(main) == 0, "SB3 a refusable order waits unissued in the queue, got %s" % [queued])
	main._physics_process(1.0 / 30.0)
	runner.check(main.hud.refusal.is_empty() and _error_cues(main) == 0, "SB3 the refusal stays silent until the drain, got '%s'" % main.hud.refusal)
	main._drain_notes()
	var errors: int = _error_cues(main)
	runner.check(main.hud.refusal == "Target outside map" and main.driver.queued().is_empty() and errors == 1, "SB3 one tick and drain bring exactly one refusal and beep, got '%s' and %d" % [main.hud.refusal, errors])
	BaseScene.tick(main)
	errors += _error_cues(main)
	runner.check(errors == 1, "SB3 one beep in total, got %d" % errors)
	main.free()
	return true

func test_sb3_one_view_per_tick(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	Profiler.reset()
	Profiler.enabled = true
	for i in 10: BaseScene.tick(main)
	var views: int = Profiler.calls(&"view_state")
	var refreshes: int = Profiler.calls(&"refresh.hud")
	Profiler.reset()
	main._refresh()
	var refresh_views: int = Profiler.calls(&"view_state")
	var bare_refreshes: int = Profiler.calls(&"refresh.hud")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(views == 10 and refreshes == 10, "SB3 ten ticks build one view per posted job and refresh ten times, got %d views and %d refreshes" % [views, refreshes])
	runner.check(refresh_views == 0 and bare_refreshes == 1, "SB3 a refresh shows the slot and builds no view, got %d views" % refresh_views)
	main.free()
	return true

func test_sb3_record_reads_live_without_queue(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	for i in 20: BaseScene.tick(main)
	main.driver.submit({"type": "stop", "entity_ids": [ids.tank]})
	var live = main.driver.pump.live()
	var state: Dictionary = live.snapshot()
	var record: Dictionary = main.driver.record()
	runner.check(record.tick == 20 and record.digest == StateHash.digest(state) and record.match == state.match, "SB3 record() is the live tick, digest and match, got %s" % [record])
	var played: Dictionary = main.playtest_match()
	runner.check(played.end_tick == record.tick and played.end_digest == record.digest and played.result == main._result_text(state.match), "SB3 the playtest record takes driver.record(), got %d %s" % [played.end_tick, played.end_digest])
	runner.check(main.driver.queued().size() == 1 and live.snapshot().pending_commands.is_empty() and played.commands.size() == main.driver.match_log().commands.size(), "SB3 a queued order stays out of the record and its log")
	main.driver.step()
	var stepped: Dictionary = main.playtest_match()
	runner.check(stepped.end_tick == 21 and main.driver.current().tick == 20 and stepped.end_digest == StateHash.digest(live.snapshot()), "SB3 a posted, undrained job is in the record, got tick %d" % stepped.end_tick)
	runner.check(stepped.commands.size() == played.commands.size() + 1 and stepped.commands[-1].contains("stop"), "SB3 the record's log holds the order its digest contains, got %s" % [stepped.commands.slice(played.commands.size())])
	main.driver.drain()
	runner.check(main.driver.match_log().commands == stepped.commands, "SB3 the drain adds nothing to the log")
	main.free()
	return true

func test_ph_refused_post_keeps_queue_and_preview(runner) -> bool:
	var main = await _setup(runner)
	var driver = main.driver
	for i in 5: BaseScene.tick(main)
	var builder: int = driver.pump.live().snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 1 and u.kind == "usa_builder")[0].id
	var req := {"player": 1, "builder_id": builder, "kind": "usa_power_plant", "origin": Vector2i(10, 10)}
	var other := {"player": 1, "builder_id": builder, "kind": "usa_power_plant", "origin": Vector2i(14, 10)}
	var logs: Array[String] = []
	driver.log_error = func(line: String) -> void: logs.append(line)
	driver.submit({"type": "stop", "entity_ids": [1]})
	driver.request_preview(req)
	driver.pump.stop()
	var kept_tick: int = driver.pump.live().tick()
	var kept_sequence: int = driver.pump.live().last_sequence(1)
	BaseScene.tick(main)
	runner.check(driver.pump.live().tick() == kept_tick and driver.pump.live().last_sequence(1) == kept_sequence, "PH a refused post issues and steps nothing, got tick %d sequence %d" % [driver.pump.live().tick(), driver.pump.live().last_sequence(1)])
	var types := func() -> Array: return driver.queued().map(func(c: Dictionary) -> String: return c.type)
	runner.check(types.call() == ["stop"], "PH a refused post keeps the queued order, got %s" % [types.call()])
	runner.check(driver.get("_preview_request") == req, "PH a refused post keeps the preview request")
	runner.check(driver.notice() == "" and driver.failure() == "" and not main.get_node("HUD/ResultPanel").visible and logs.is_empty(), "PH a stop() from outside is no failure: no notice, no card, nothing logged, got '%s' %s" % [driver.failure(), logs])
	driver.submit({"type": "move", "entity_ids": [1], "target": [12.5, 12.5]})
	runner.check(types.call() == ["stop", "move"], "PH a submit after the refusal queues behind, got %s" % [types.call()])
	driver.request_preview(other)
	BaseScene.tick(main)
	runner.check(driver.get("_preview_request") == other, "PH a newer request replaces the kept one")
	driver.request_preview({})
	runner.check(driver.get("_preview_request").is_empty() and driver.preview_answer().is_empty(), "PH an empty request clears request and answer")
	main.free()
	return true

func _frozen_arena(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var ids := {"infantry": sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry"), "tank": sim.spawn(1, Vector2(11.5, 10.5), "usa_tank"), "builder": sim.spawn(1, Vector2(12.5, 12.5), "usa_builder"), "enemy": sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")}
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	var pump = FailingPump.new(main.driver.pump.live())
	main.driver.pump.stop()
	main.driver._last = pump.start()
	main.driver.pump = pump
	var logs: Array[String] = []
	main.driver.log_error = func(line: String) -> void: logs.append(line)
	var copied: Array[String] = []
	main.get_node("HUD/ResultPanel").copy_text = func(text: String) -> void: copied.append(text)
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	main._refresh()
	return {"ids": ids, "pump": pump, "logs": logs, "copied": copied}

func _freeze_shown(main) -> bool:
	var parts: bool = FREEZE_PARTS.all(func(path: String) -> bool: return main.get_node(path).visible) and main.get_node(CHANGE_SETUP).visible
	return main.get_node("HUD/ResultPanel").visible and main.get_node(OUTCOME).text == "Match stopped" and parts and not main.get_node(PLAY_AGAIN).visible

func _push_key(main, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := _enter(code)
		event.pressed = pressed
		main.get_viewport().push_input(event)

func _helper_on() -> Dictionary:
	var saved := {"audio": AudioSettings.path, "dir": PlaytestSession.dir}
	AudioSettings.path = "user://test-freeze-settings-%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(AudioSettings.path)
	PlaytestSettings.save_enabled(true)
	PlaytestSession.dir = freeze_sessions
	PlaytestSession.current = null
	PlaytestSession.last_filed = ""
	return saved

func _helper_off(saved: Dictionary) -> void:
	DirAccess.remove_absolute(AudioSettings.path)
	WargridTestRunner.remove_dir(freeze_sessions)
	PlaytestSession.dir = saved.dir
	PlaytestSession.current = null
	PlaytestSession.last_filed = ""
	AudioSettings.path = saved.audio

func _filed_end(main) -> String:
	return str(main._playtest._session.data.matches[-1].get("end", ""))

func test_freeze_card_on_a_failed_pump(runner) -> bool:
	var main = await _setup(runner)
	var world: Dictionary = _frozen_arena(main)
	var ids: Dictionary = world.ids
	BaseScene.tick(main)
	runner.check(not main.get_node("HUD/ResultPanel").visible and world.logs.is_empty(), "FN1 fixture: a healthy tick shows no card")
	main.driver.submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	world.pump.fail_next = true
	BaseScene.tick(main)
	runner.check(_freeze_shown(main), "FN1 the frame that meets the failure shows the freeze card")
	runner.check(not main.get_node("HUD/Hud/Notice").visible, "FN1 the top-centre notice stays hidden")
	runner.check(world.logs.size() == 1 and world.logs[0] == "SIM PUMP FAILED " + world.pump.failure(), "FN1 the failure is logged once, got %s" % [world.logs])
	for i in 3: BaseScene.tick(main)
	runner.check(world.logs.size() == 1, "FN1 later frames log nothing more, got %d" % world.logs.size())
	var types := func() -> Array: return main.driver.queued().map(func(c: Dictionary) -> String: return c.type)
	runner.check(types.call() == ["move"], "FN1 the refused post keeps the queued move, got %s" % [types.call()])
	runner.check(main.driver.match_log().get("end", "") == "sim pump failed: " + world.pump.failure(), "FN1 the match log ends with the failure, got '%s'" % main.driver.match_log().get("end", ""))
	main._reshow()
	var refusal: String = main.hud.refusal
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	_push_key(main, KEY_S)
	# U today, F once Task 9 moves Unload; either would refuse with several units selected.
	for code: Key in [KEY_U, KEY_F]: _push_key(main, code)
	main.orders.selected_ids.assign([ids.builder])
	main._reshow()
	for code: Key in [KEY_Q, KEY_Q]: _push_key(main, code)
	runner.check(types.call() == ["move"] and not main.orders.busy() and not main.orders._sub_grid and main.hud.refusal == refusal, "FN1 keys behind the card reach no order, got %s busy %s refusal '%s'" % [types.call(), main.orders.busy(), main.hud.refusal])
	runner.check(_freeze_shown(main) and _focus_owner(main) == main.get_node(COPY), "FN1 the card stays up with the focus on Copy report")
	main.get_node(COPY).pressed.emit()
	main._reshow()
	runner.check(main.get_node(COPY).text == "Report copied" and _focus_owner(main) == main.get_node(COPY) and _freeze_shown(main), "FN1 a refresh after the copy keeps Report copied and the focus")
	main.free()
	return true

func test_freeze_leave_reaches_the_launcher(runner) -> bool:
	for way: String in ["Back to menu", "Esc then Leave match"]:
		var saved: Dictionary = _helper_on()
		var main = await _setup(runner)
		var scenes: Array[String] = []
		main.change_scene = func(path: String) -> void: scenes.append(path)
		var world: Dictionary = _frozen_arena(main)
		main.orders.selected_ids.assign([world.ids.builder])
		main._reshow()
		for code: Key in [KEY_Q, KEY_Q]: _push_key(main, code)
		runner.check(main._playtest.is_active() and main.orders.busy() and not main.orders.selected_ids.is_empty(), "FN2 %s fixture: helper on, a unit selected, a placement armed" % way)
		world.pump.fail_next = true
		BaseScene.tick(main)
		runner.check(_freeze_shown(main), "FN2 %s: the freeze card is up" % way)
		if way == "Back to menu": main.get_node(CHANGE_SETUP).pressed.emit()
		else:
			main._show_esc_chip()
			runner.check(main.get_node("HUD/MenuChip").find_child("EscChip", true, false).modulate.a == 1.0, "FN2 the Esc chip shows under the freeze card")
			_push_key(main, KEY_ESCAPE)
			runner.check(main._pause.visible, "FN2 one Esc opens the pause menu over the freeze card")
			main._pause.leave_requested.emit()
		runner.check(scenes == [main.LAUNCHER_SCENE], "FN2 %s reaches the launcher, got %s" % [way, scenes])
		runner.check(_filed_end(main).begins_with("sim pump failed: post job returned no note"), "FN2 %s files the failure as the end, got '%s'" % [way, _filed_end(main)])
		main.free()
		_helper_off(saved)
	return true

func test_failure_first_met_while_leaving(runner) -> bool:
	var saved: Dictionary = _helper_on()
	var main = await _setup(runner)
	main.change_scene = func(_path: String) -> void: pass
	var world: Dictionary = _frozen_arena(main)
	BaseScene.tick(main)
	runner.check(main.driver.failure() == "" and not main.frozen(), "FN3 fixture: the pump is healthy before leaving")
	world.pump.fail_next = true
	main._pause.leave_requested.emit()
	runner.check(main.driver.record().digest == "", "FN3 record() falls back once the query fails")
	runner.check(_filed_end(main).begins_with("sim pump failed: query job returned no note"), "FN3 the failure met while filing is the filed end, got '%s'" % _filed_end(main))
	runner.check(world.logs.size() == 1, "FN3 logged once, got %s" % [world.logs])
	main.free()
	_helper_off(saved)
	return true

func test_freeze_card_copy_and_layout(runner) -> bool:
	var warn: Color = ThemeDB.get_project_theme().get_color(&"warn", &"Tokens")
	var build: String = PlaytestSettings.build_id()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = Scene.instantiate()
		port.add_child(main)
		main.set_physics_process(false)
		main.set_process(false)
		await runner.process_frame
		var world: Dictionary = _frozen_arena(main)
		world.pump.fail_next = true
		BaseScene.tick(main)
		await runner.process_frame
		await runner.process_frame
		runner.check(_freeze_shown(main), "FN4 the freeze card is up at %s" % size)
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var card_node: PanelContainer = main.get_node(CARD)
		var card: Rect2 = card_node.get_global_rect()
		runner.check(screen.encloses(card) and card.get_center().distance_to(screen.get_center()) <= 1.0, "FN4 the card is centred inside %s, got %s" % [size, card])
		var styles: Array = [card_node.get_theme_stylebox("panel")]
		for path: String in [COPY, CHANGE_SETUP]:
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: styles.append(main.get_node(path).get_theme_stylebox(state))
		runner.check(styles.all(func(style: StyleBox) -> bool: return not style is StyleBoxFlat or [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT].all(func(corner: int) -> bool: return (style as StyleBoxFlat).get_corner_radius(corner) == 0)), "FN4 square corners on the card and every button state at %s" % size)
		var mark: Control = main.get_node(OUTCOME + "/Mark")
		runner.check(mark.self_modulate == warn, "FN4 the mark is drawn in warn at %s, got %s" % [size, mark.self_modulate])
		var content: Rect2 = card.grow(-24.0)
		var copy: Rect2 = main.get_node(COPY).get_global_rect()
		var setup: Rect2 = main.get_node(CHANGE_SETUP).get_global_rect()
		runner.check(copy.end.x <= setup.position.x and absf(setup.end.x - content.end.x) <= 1.0 and content.encloses(copy) and content.encloses(setup), "FN4 Copy report left of Back to menu, both right-aligned in the card at %s, got %s %s in %s" % [size, copy, setup, content])
		var cut: Array = main.get_node(CARD).find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree() and not content.encloses(label.get_global_rect()))
		runner.check(cut.is_empty() and content.encloses(mark.get_global_rect()), "FN4 no label cut and the mark inside the card at %s, got %s" % [size, cut.map(func(label: Label) -> String: return label.name)])
		runner.check(main.get_node(CHANGE_SETUP).theme_type_variation == &"PrimaryButton" and main.get_node(COPY).theme_type_variation == &"", "FN4 Back to menu is the primary button, Copy report the secondary at %s" % size)
		runner.check(_focus_owner(main) == main.get_node(COPY), "FN4 Copy report holds the focus at %s" % size)
		var above: float = main.get_node(CHANGE_SETUP).get_global_rect().position.y - main.get_node("HUD/ResultPanel/Center/Card/Box/Footer").get_global_rect().end.y
		runner.check(absf(above - 24.0) <= 1.0, "FN4 24 px between the footer and the buttons at %s, got %.0f" % [size, above])
		var footer: String = ResultPanel.footer_text(build, "skirmish")
		runner.check(footer == "Version %s · skirmish" % build and main.get_node("HUD/ResultPanel/Center/Card/Box/Footer/Version").text == footer and main.get_node("HUD/ResultPanel/Center/Card/Box/Footer/Code").text == "GAME ERROR", "FN4 the footer reads the version and map at %s" % size)
		main.get_node(COPY).pressed.emit()
		var report: String = ResultPanel.report_text(world.pump.failure(), build, "skirmish", main.driver.current().tick)
		var lines: PackedStringArray = report.split("\n")
		runner.check(world.copied == [report] and lines.has("error: " + world.pump.failure()) and lines.has("version: " + build) and lines.has("map: skirmish") and lines.has("tick: %d" % main.driver.current().tick), "FN4 Copy report copies the report once at %s, got %s" % [size, world.copied])
		runner.check(main.get_node(COPY).text == "Report copied" and main.get_node("HUD/ResultPanel/Center/Card/Box/Footer/Version").text == footer, "FN4 the button reads Report copied, the footer unchanged at %s" % size)
		_push_enter(main)
		runner.check(is_same(main.driver.pump, world.pump) and main.driver.failure() == world.pump.failure() and _freeze_shown(main) and world.copied.size() == 2, "FN4 Enter on Copy report copies again and never restarts at %s, copies %d" % [size, world.copied.size()])
		main.driver.adopt(Skirmish.create(false))
		runner.check(main.driver.failure() == "" and main.driver.notice() == "" and not main.frozen(), "FN4 a new world clears the failure at %s" % size)
		port.queue_free()
	runner.check(ResultPanel.footer_text("b", "dry_wells") == "Version b · Dry Wells", "FN4 the footer prints the launcher's map name, got '%s'" % ResultPanel.footer_text("b", "dry_wells"))
	var won = await _setup(runner)
	_arena(won)
	_victory(won)
	runner.check(won.get_node(OUTCOME).text == "Victory" and FREEZE_PARTS.all(func(path: String) -> bool: return not won.get_node(path).visible) and won.get_node(PLAY_AGAIN).visible, "FN4 the Victory card shows none of the freeze parts")
	won.free()
	return true

func _push_shift_tab(main) -> void:
	for pressed: bool in [true, false]:
		var event := _enter(KEY_TAB)
		event.shift_pressed = true
		event.pressed = pressed
		main.get_viewport().push_input(event)

func _in_card(main) -> bool:
	var focus: Control = _focus_owner(main)
	return focus != null and main.get_node(CARD).is_ancestor_of(focus)

func test_freeze_card_keeps_the_focus(runner) -> bool:
	var main = await _setup(runner)
	main.change_scene = func(_path: String) -> void: pass
	var world: Dictionary = _frozen_arena(main)
	main.orders.selected_ids.assign([world.ids.builder])
	main._reshow()
	var menu: GridContainer = main.find_child("Card", true, false)
	runner.check(menu.visible and menu.get_child(0).get_meta("action") == "build", "FN5 fixture: the builder's Build cell is up")
	var field := LineEdit.new()
	main.get_node("HUD").add_child(field)
	field.grab_focus()
	world.pump.fail_next = true
	BaseScene.tick(main)
	runner.check(_freeze_shown(main) and _focus_owner(main) == field, "FN5 fixture: a text field keeps the focus when the card comes up")
	field.release_focus()
	field.free()
	main._reshow()
	runner.check(_focus_owner(main) == main.get_node(COPY), "FN5 a refresh after the field lets go grabs Copy report")
	for path: String in [COPY, CHANGE_SETUP]:
		for code: Key in [KEY_TAB, KEY_BACKTAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			main.get_node(path).grab_focus()
			if code == KEY_BACKTAB: _push_shift_tab(main)
			else: _push_key(main, code)
			runner.check(_in_card(main), "FN5 %s from %s stays in the card, got %s" % [OS.get_keycode_string(code), path.get_file(), _focus_owner(main)])
	var refusal: String = main.hud.refusal
	runner.check((menu.get_child(0) as Button).focus_mode == Control.FOCUS_NONE, "FN5 a cell takes no focus, so Enter cannot press it behind the card")
	var gestures: int = main.orders.gestures
	(menu.get_child(0) as Button).pressed.emit()
	main.hud.cell_pressed.emit("usa_power_plant", false)
	# The freeze card's own hook would clear an armed ghost at once, so the arm count is what shows it.
	runner.check(main.orders.gestures == gestures and not main.orders._sub_grid, "FN5 Build and a build cell pressed behind the card open and arm nothing")
	main.orders._cancel_entry(1)
	main.orders._cancel_build()
	runner.check(main.driver.queued().is_empty() and not main.orders.busy() and main.hud.refusal == refusal, "FN5 build and queue buttons behind the card order nothing, got %s busy %s refusal '%s'" % [main.driver.queued(), main.orders.busy(), main.hud.refusal])
	main.free()
	return true

func test_freeze_flush_keeps_the_queue(runner) -> bool:
	var main = await _setup(runner)
	var world: Dictionary = _frozen_arena(main)
	main.driver.submit({"type": "stop", "entity_ids": [world.ids.tank]})
	world.pump.fail_next = true
	main.driver.flush()
	runner.check(main.driver.queued().size() == 1 and main.driver.failure().begins_with("query job returned no note") and world.logs.size() == 1 and main.frozen(), "FN6 a failed flush keeps its order and reads the failure, got %s '%s' %s" % [main.driver.queued(), main.driver.failure(), world.logs])
	main.free()
	return true

# Mid-screen, clear of every HUD surface, so these checks read the resolver and not the routing.
func _centre(runner, main, plane: Vector2) -> Vector2:
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = plane
	camera.force_update_scroll()
	await runner.process_frame
	return main.get_node("WorldView").get_global_transform_with_canvas() * plane

func _screen_button(main, at: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = at
	main._unhandled_input(event)

func _map_click(runner, main, plane: Vector2, shift: bool = false) -> void:
	var at: Vector2 = await _centre(runner, main, plane)
	_screen_button(main, at, MOUSE_BUTTON_LEFT, true, shift)
	_screen_button(main, at, MOUSE_BUTTON_LEFT, false, shift)

func _map_drag(runner, main, centre: Vector2, half: Vector2, shift: bool = false) -> void:
	var at: Vector2 = await _centre(runner, main, centre)
	_screen_button(main, at - half, MOUSE_BUTTON_LEFT, true, shift)
	var motion := InputEventMouseMotion.new()
	motion.position = at + half
	main._unhandled_input(motion)
	_screen_button(main, at + half, MOUSE_BUTTON_LEFT, false, shift)

static func _clicked(main) -> int:
	if main.orders.selected_ids.size() == 1: return main.orders.selected_ids[0]
	return main.orders.selected_building_id if main.orders.selected_building_id != -1 else main.orders.inspected_id

func _pick_scene(runner) -> Array:
	var main = await _setup(runner)
	var world: Dictionary = ViewTests.pick_world(runner)
	main.driver.adopt(world.sim)
	main._refresh()
	return [main, world]

func test_hover_equals_click(runner) -> bool:
	var scene: Array = await _pick_scene(runner)
	var main = scene[0]
	for row: Array in scene[1].rows:
		main.orders.reset()
		main._refresh()
		var at: Vector2 = await _centre(runner, main, row[1])
		var motion := InputEventMouseMotion.new()
		motion.position = at
		main._unhandled_input(motion)
		var hovered: int = main.get_node("WorldView").hovered_id()
		await _map_click(runner, main, row[1])
		runner.check(hovered == row[3] and _clicked(main) == row[3], "PK2 %s: hover %d and click %d both name %d" % [row[0], hovered, _clicked(main), row[3]])
	main.free()
	return true

func test_click_results(runner) -> bool:
	var scene: Array = await _pick_scene(runner)
	var main = scene[0]
	var rows: Array = scene[1].rows
	var sim = main.driver.pump.live()
	sim._buildings[rows[6][3]].completed = false
	BaseScene.publish(main)
	var own: int = rows[0][3]
	await _map_click(runner, main, rows[0][1])
	runner.check(main.orders.selected_ids == [own] and main.orders.inspected_id == -1, "PK3 an own unit selects")
	await _map_click(runner, main, rows[1][1])
	runner.check(main.orders.inspected_id == rows[1][3] and main.orders.selected_ids.is_empty(), "PK3 an enemy unit inspects and clears the own selection, got %s %d" % [main.orders.selected_ids, main.orders.inspected_id])
	main.orders.selected_ids.assign([own])
	await _map_click(runner, main, rows[7][1])
	runner.check(main.orders.selected_building_id == rows[7][3] and main.orders.selected_ids.is_empty() and main.orders.inspected_id == -1, "PK3 an own building selects and clears the units")
	await _map_click(runner, main, rows[6][1])
	runner.check(main.orders.inspected_id == rows[6][3] and main.orders.selected_building_id == -1, "PK3 an enemy site inspects, got %d" % main.orders.inspected_id)
	await _map_click(runner, main, rows[8][1])
	for i in 3: BaseScene.publish(main)
	runner.check(main.orders.inspected_id == rows[8][3] and main.get_node("WorldView")._inspected_id == rows[8][3], "PK3 a pile inspects and stays inspected over three refreshes, got %d" % main.orders.inspected_id)
	main.orders.selected_ids.assign([own])
	await _map_click(runner, main, rows[9][1])
	runner.check(main.orders.selected_ids.is_empty() and main.orders.selected_building_id == -1 and main.orders.inspected_id == -1, "PK3 ground deselects")
	await _map_drag(runner, main, rows[8][1], Vector2(40, 40))
	runner.check(main.orders.inspected_id == -1 and main.orders.selected_ids.is_empty(), "PK3 a drag over a pile selects no pile, got %d" % main.orders.inspected_id)
	main.free()
	return true

func test_shift_toggles_on_the_map(runner) -> bool:
	var scene: Array = await _pick_scene(runner)
	var main = scene[0]
	var rows: Array = scene[1].rows
	var own: int = rows[0][3]
	var other: int = rows[4][3]
	main.orders.selected_ids.assign([other])
	await _map_click(runner, main, rows[0][1], true)
	var both: Array[int] = [own, other]
	both.sort()
	runner.check(main.orders.selected_ids == both, "PK4 Shift-click on an unselected own unit adds it, got %s" % [main.orders.selected_ids])
	await _map_click(runner, main, rows[0][1], true)
	runner.check(main.orders.selected_ids == [other], "PK4 Shift-click on a selected own unit removes it, got %s" % [main.orders.selected_ids])
	await _map_drag(runner, main, Iso.world_to_plane(Vector2(10.5, 10.5)), Vector2(30, 30), true)
	runner.check(main.orders.selected_ids == both, "PK4 Shift-drag adds, got %s" % [main.orders.selected_ids])
	await _map_click(runner, main, rows[7][1], true)
	runner.check(main.orders.selected_building_id == rows[7][3] and main.orders.selected_ids.is_empty(), "PK4 Shift-click on an own building with units selected leaves the building only, got %d %s" % [main.orders.selected_building_id, main.orders.selected_ids])
	main.free()
	return true

# Window-sized events through the port, as the platform sends them; the port scales them to the logical layout.
static func _push(port: SubViewport, event: InputEventMouse, logical: Vector2) -> void:
	event.position = logical * Vector2(port.size) / Vector2(port.size_2d_override)
	event.global_position = event.position
	port.push_input(event)

static func _push_button(port: SubViewport, at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	_push(port, event, at)

static func _push_click(port: SubViewport, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]: _push_button(port, at, button, pressed)

static func _push_move(port: SubViewport, at: Vector2) -> void:
	_push(port, InputEventMouseMotion.new(), at)

static func _frames(runner) -> void:
	for i in 3: await runner.process_frame

static func _world_at(main, screen: Vector2) -> Vector2:
	return Iso.plane_to_world(main.get_node("WorldView").get_global_transform_with_canvas().affine_inverse() * screen)

# A 64-cell world with one own tank far off screen selected, so the panel and the slab show; the camera on the centre.
func _routing_scene(runner, overlays, size: Array, zoom: float = 1.0, pan: Vector2 = Vector2.ZERO) -> Array:
	var port: SubViewport = BaseScene.sized_port(runner, size[0], size[1])
	# A window gets this when the pointer enters it; without it a port never hit-tests motion against the GUI.
	port.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	var main = await overlays._scene(runner, Scene, port)
	var sim = Fixture.make_world(10000, Vector2i(64, 64))
	var keeper: int = sim.spawn(1, Vector2(60.5, 4.5), "usa_tank")
	main.driver.adopt(sim)
	main.orders.selected_ids.assign([keeper])
	main._refresh()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = Iso.world_to_plane(Vector2(32, 32)) + pan
	camera.zoom = Vector2.ONE * zoom
	camera.force_update_scroll()
	await _frames(runner)
	return [port, main, keeper]

func _spawn_at(runner, main, screen: Vector2) -> int:
	var id: int = main.driver.pump.live().spawn(1, _world_at(main, screen), "usa_tank")
	runner.check(id != -1, "MR fixture: a tank spawns under %s" % screen)
	return id

static func _rect_of(main, path: String) -> Rect2:
	return main.get_node(path).get_global_rect()

func _unchanged(runner, main, before: Array, label: String) -> void:
	var now: Array = [main.orders.selected_ids.duplicate(), main.orders.selected_building_id, main.orders.inspected_id]
	runner.check(now == before and main.driver.queued().is_empty() and _pending(main) == 0, "%s changes no selection and sends no command, got %s against %s, %d queued" % [label, now, before, main.driver.queued().size()])

func test_hud_blocks_the_map(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for size: Array in [BaseScene.HUD_SIZES[0], BaseScene.HUD_SIZES[2], BaseScene.HUD_SIZES[3]]:
		var scene: Array = await _routing_scene(runner, overlays, size)
		var port: SubViewport = scene[0]
		var main = scene[1]
		var at := "%s" % [size[0]]
		var checklist: Control = main.get_node("HUD/Playtest/Checklist")
		_push_move(port, Vector2(100, 300))
		runner.check(port.get_mouse_position().is_equal_approx(Vector2(100, 300)), "MR1 %s fixture: a window event lands at its logical point, got %s" % [at, port.get_mouse_position()])
		runner.check(checklist.is_visible_in_tree() and main.get_node("HUD/Economy").is_visible_in_tree() and main.get_node("HUD/Hud/SelectionPanel").is_visible_in_tree(), "MR1 %s fixture: the checklist, the slab and the panel show" % at)
		var before: Array = [main.orders.selected_ids.duplicate(), -1, -1]
		var slab: Rect2 = _rect_of(main, "HUD/Economy")
		var panel: Rect2 = _rect_of(main, "HUD/Hud/SelectionPanel")
		var spots: Array = [["the strip", _rect_of(main, "HUD/Hud/TopStrip").get_center()], ["the panel", panel.get_center()], ["the panel's padding", panel.position + Vector2(6, 4)], ["the slab's padding", slab.position + Vector2(6, 4)], ["the slab's bottom padding", slab.end - Vector2(4, 3)], ["the checklist", checklist.get_global_rect().position + Vector2(4, 4)]]
		for spot: Array in spots:
			main.orders.selected_ids.assign(before[0])
			_push_click(port, spot[1])
			_push_click(port, spot[1], MOUSE_BUTTON_RIGHT)
			await _frames(runner)
			_unchanged(runner, main, before, "MR1 %s: a left and a right click on %s" % [at, spot[0]])
		_push_click(port, _rect_of(main, "HUD/MenuChip").get_center())
		await _frames(runner)
		runner.check(main._pause.visible, "MR1 %s: the Menu chip opens the menu" % at)
		_unchanged(runner, main, before, "MR1 %s: a click on the Menu chip" % at)
		main._pause.close()
		_push_click(port, _rect_of(main, "HUD/Playtest/Chip").get_center())
		await _frames(runner)
		runner.check(not checklist.visible, "MR1 %s: the Playtest chip toggles the checklist" % at)
		_unchanged(runner, main, before, "MR1 %s: a click on the Playtest chip" % at)
		checklist.show()
		await _frames(runner)
		for spot: Array in [["the slab", slab.position + Vector2(6, 4)], ["the checklist", checklist.get_global_rect().position + Vector2(4, 4)], ["the panel", panel.get_center()], ["the strip", _rect_of(main, "HUD/Hud/TopStrip").get_center()]]:
			_push_button(port, spot[1], MOUSE_BUTTON_WHEEL_UP, true)
			_push_button(port, spot[1], MOUSE_BUTTON_WHEEL_UP, false)
			runner.check(main.get_node("Camera2D").zoom.x == 1.0, "MR1 %s: the wheel over %s leaves the zoom, got %.1f" % [at, spot[0], main.get_node("Camera2D").zoom.x])
		var ground := Vector2(size[1].x / 2.0, 300)
		runner.check(main.get_node("WorldView").resolve_pick(main.get_node("WorldView").get_global_transform_with_canvas().affine_inverse() * ground).tier == "ground", "MR1 %s fixture: open ground at %s" % [at, ground])
		_push_button(port, ground, MOUSE_BUTTON_WHEEL_UP, true)
		_push_button(port, ground, MOUSE_BUTTON_WHEEL_UP, false)
		runner.check(main.get_node("Camera2D").zoom.x == 2.0, "MR1 %s: the wheel over open ground zooms" % at)
		main.get_node("Camera2D").zoom = Vector2.ONE
		main.get_node("Camera2D").force_update_scroll()
		_push_click(port, ground)
		await _frames(runner)
		runner.check(main.orders.selected_ids.is_empty(), "MR1 %s: a click on open ground beside them deselects" % at)
		main.orders.selected_ids.assign(before[0])
		main.refuse("Target outside map", "")
		main._reshow()
		await _frames(runner)
		var line: Rect2 = _rect_of(main, "HUD/Hud/RefusalLine")
		runner.check(main.get_node("HUD/Hud/RefusalLine").is_visible_in_tree(), "MR1 %s fixture: the refusal line shows" % at)
		_push_click(port, line.get_center(), MOUSE_BUTTON_RIGHT)
		await _frames(runner)
		runner.check(_pending(main, "move") == 1, "MR1 %s: a right-click on ground under the refusal line sends a move" % at)
		_push_click(port, line.get_center())
		await _frames(runner)
		runner.check(main.orders.selected_ids.is_empty(), "MR1 %s: a left click under the refusal line deselects" % at)
		port.free()
	overlays._end(saved)
	return true

func test_entering_the_hud_clears_hover(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _routing_scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var view = main.get_node("WorldView")
	var panel: Rect2 = _rect_of(main, "HUD/Hud/SelectionPanel")
	var slab: Rect2 = _rect_of(main, "HUD/Economy")
	var near := Vector2(panel.end.x + 80, panel.position.y - 40)
	var edge := Vector2(slab.position.x + 100, slab.position.y + 6)
	var tank: int = _spawn_at(runner, main, near)
	var under: int = _spawn_at(runner, main, edge)
	BaseScene.publish(main)
	await _frames(runner)
	_push_move(port, near + Vector2(0, -8))
	runner.check(view.hovered_id() == tank, "MR2 the tank on the map is hovered, got %d" % view.hovered_id())
	_push_move(port, panel.get_center())
	runner.check(view.hovered_id() == -1, "MR2 moving onto the panel clears the hover, got %d" % view.hovered_id())
	_push_move(port, edge + Vector2(0, -12))
	runner.check(view.hovered_id() == under, "MR2 fixture: the tank just under the slab is hovered above its edge, got %d" % view.hovered_id())
	_push_move(port, edge + Vector2(0, -3))
	runner.check(slab.has_point(edge + Vector2(0, -3)) and view.hovered_id() == -1, "MR2 the pointer on the slab hovers nothing, not the tank under its edge, got %d" % view.hovered_id())
	port.free()
	overlays._end(saved)
	return true

func test_drag_across_a_panel(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for camera: Array in [[1.0, Vector2.ZERO], [2.0, Vector2(-90, 40)]]:
		var scene: Array = await _routing_scene(runner, overlays, BaseScene.HUD_SIZES[0], camera[0], camera[1])
		var port: SubViewport = scene[0]
		var main = scene[1]
		var at := "zoom %.0f" % camera[0]
		var panel: Rect2 = _rect_of(main, "HUD/Hud/SelectionPanel")
		var above: int = _spawn_at(runner, main, Vector2(panel.end.x - 60, panel.position.y - 30))
		var under: int = _spawn_at(runner, main, Vector2(panel.end.x - 60, panel.position.y + 20))
		BaseScene.publish(main)
		await _frames(runner)
		var start := Vector2(panel.end.x + 40, panel.position.y - 70)
		var end: Vector2 = panel.get_center()
		runner.check(main.get_viewport().get_visible_rect().has_point(end) and panel.has_point(end), "MR3 %s fixture: the release point is on the panel, inside the view" % at)
		_push_button(port, start, MOUSE_BUTTON_LEFT, true)
		for step in range(1, 6): _push_move(port, start.lerp(end, step / 5.0))
		var box: ReferenceRect = main.get_node("HUD/SelectionBox")
		runner.check(box.visible and Rect2(box.position, box.size).is_equal_approx(Rect2(start, end - start).abs()), "MR3 %s: the box follows over the panel, got %s" % [at, Rect2(box.position, box.size)])
		_push_button(port, end, MOUSE_BUTTON_LEFT, false)
		await _frames(runner)
		runner.check(main.orders.selected_ids == [above] and not box.visible, "MR3 %s: the release on the panel applies the box, the tank under the panel skipped, got %s (above %d, under %d)" % [at, main.orders.selected_ids, above, under])
		port.free()
	var scene: Array = await _routing_scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var panel: Rect2 = _rect_of(main, "HUD/Hud/SelectionPanel")
	var beside: int = _spawn_at(runner, main, Vector2(panel.end.x + 2, panel.position.y + 28))
	BaseScene.publish(main)
	await _frames(runner)
	var press := Vector2(panel.end.x + 2, panel.position.y + 20)
	runner.check(main.get_node("WorldView").resolve_pick(main.get_node("WorldView").get_global_transform_with_canvas().affine_inverse() * (press - Vector2(4, 0))).id == beside, "MR3 fixture: the tank beside the panel reaches under the release point")
	_push_button(port, press, MOUSE_BUTTON_LEFT, true)
	_push_move(port, press - Vector2(4, 0))
	_push_button(port, press - Vector2(4, 0), MOUSE_BUTTON_LEFT, false)
	await _frames(runner)
	runner.check(main.orders.selected_ids == [scene[2]] and main.orders.inspected_id == -1, "MR3 a press just outside the panel released 4 px inside it selects nothing, got %s" % [main.orders.selected_ids])
	port.free()
	overlays._end(saved)
	return true

func test_card_takes_a_click_after_a_drag(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(false)
	var port: SubViewport = BaseScene.sized_port(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var main = await overlays._scene(runner, Scene, port)
	_arena(main)
	await _frames(runner)
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_push_button(port, Vector2(640, 300), MOUSE_BUTTON_LEFT, true)
	runner.check(main.orders.is_selecting(), "MR4 fixture: a press on the map starts a drag")
	_victory(main)
	await _frames(runner)
	var at: Vector2 = main.get_node(CHANGE_SETUP).get_global_rect().get_center()
	_push_move(port, at)
	_push_click(port, at)
	await _frames(runner)
	runner.check(scenes == [main.LAUNCHER_SCENE], "MR4 a drag cut short by the match ending leaves the result card's buttons live, got %s" % [scenes])
	port.free()
	overlays._end(saved)
	return true

func test_releases_on_a_panel_are_the_huds(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _routing_scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var panel: Vector2 = _rect_of(main, "HUD/Hud/SelectionPanel").get_center()
	var map: Vector2 = _rect_of(main, "HUD/Hud/SelectionPanel").end + Vector2(40, -140)
	main.orders.arm_attack_move()
	_push_button(port, map, MOUSE_BUTTON_LEFT, true)
	_push_move(port, panel)
	_push_button(port, panel, MOUSE_BUTTON_LEFT, false)
	await _frames(runner)
	runner.check(_pending(main, "attack_move") == 0 and main.orders._attack_move_mode, "MR5 an attack-move press on the map released on the panel sends nothing and stays armed")
	_push_click(port, map)
	runner.check(_pending(main, "attack_move") == 1, "MR5 fixture: the next click on the map attack-moves")
	main.orders.selected_ids.assign([1])
	main._refresh()
	main.orders.press_cell("usa_power_plant")
	await _frames(runner)
	var forecast: Control = main.get_node("HUD/Hud/TopStrip")
	runner.check(not main.orders._placement_kind.is_empty() and forecast.find_child("CreditsArrow", true, false).is_visible_in_tree(), "MR5 fixture: a placement is armed and the strip forecasts it")
	_push_move(port, map)
	var ghost: Array = main.get_node("WorldView")._preview_cells.duplicate()
	_push_move(port, panel)
	runner.check(not ghost.is_empty() and main.get_node("WorldView")._preview_cells == ghost, "MR5 the ghost stays where it was while the pointer is on a panel")
	_push_button(port, map, MOUSE_BUTTON_LEFT, true)
	_push_button(port, panel, MOUSE_BUTTON_LEFT, false)
	_push_click(port, forecast.get_global_rect().get_center())
	await _frames(runner)
	runner.check(_pending(main, "build") == 0 and not main.orders._placement_kind.is_empty(), "MR5 a placement released on the panel or clicked on the previewing strip builds nothing, got %d" % _pending(main, "build"))
	port.free()
	overlays._end(saved)
	return true

func _duo_world(main) -> Dictionary:
	var seats: Array[Dictionary] = [{"seat": 1, "team": 1, "controller": "human", "credits": 1111, "faction": "usa"}, {"seat": 2, "team": 2, "controller": "human", "credits": 2222, "faction": "frc"}]
	var sim = MapData.create(MapData.load(Skirmish.MAP_PATH), seats)
	var source: int = sim.add_supply_source(Vector2i(8, 8), 10)
	var ids := {"source": source, "one": sim.spawn(1, Vector2(20.5, 10.5), "usa_builder"), "two": sim.spawn(2, Vector2(24.5, 10.5), "usa_builder"), "stacked": sim.spawn(1, Vector2(22.5, 20.5), "usa_builder"), "rival": sim.spawn(2, Vector2(23.3, 20.5), "usa_builder"), "collector": sim.spawn(1, Vector2(12.5, 10.5), "usa_collector")}
	sim.start_match([1, 2] as Array[int])
	Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(2, 10))
	ids["barracks"] = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(2, 16))
	Fixture.send(sim, {"type": "set_rally", "building_id": ids.barracks, "target": [20.5, 14.5]})
	Fixture.send(sim, {"type": "gather", "entity_ids": [ids.collector], "source_id": source})
	for i in 900:
		sim.step()
		if Fixture.object(sim, ids.collector).collection.phase.ends_with("_depot"): break
	main.driver.adopt(sim)
	main.orders.selected_ids.clear()
	main._refresh()
	return ids

func test_view_player_changes_display_reads_only(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _duo_world(main)
	var sim = main.driver.pump.live()
	var view = main.get_node("WorldView")
	var strip: Node = main.get_node("HUD/Hud/TopStrip")
	runner.check(Fixture.object(sim, ids.collector).collection.phase.ends_with("_depot"), "VP2 fixture: the collector is on its way to the drop-off, got " + str(Fixture.object(sim, ids.collector).collection))

	Fixture.send(sim, {"type": "move", "entity_ids": [ids.one], "target": [12.5, 14.5]})
	Fixture.send(sim, {"type": "move", "player": 2, "entity_ids": [ids.two], "target": [16.5, 14.5]})
	Fixture.steps(sim, 2)
	view.set_show_destinations(true)
	BaseScene.publish(main)
	runner.check(main.view_player == 1 and strip.find_child("Credits", true, false).text == "1111", "VP2 fixture: the strip starts on player 1")
	runner.check(view.order_marks().has(Iso.world_to_plane(Vector2(12.5, 14.5))) and not view.order_marks().has(Iso.world_to_plane(Vector2(16.5, 14.5))), "VP2 player 1's marks first, got " + str(view.order_marks()))
	main.orders.selected_ids.assign([ids.one])
	main.view_player = 2
	BaseScene.publish(main)
	var swatch: ColorRect = strip.find_child("Swatch", true, false)
	runner.check(strip.find_child("Credits", true, false).text == "2222" and swatch.color == View.owner_color(2, false) and swatch.color != View.owner_color(1, false), "VP2 the strip shows player 2's credits and swatch, got %s" % strip.find_child("Credits", true, false).text)
	runner.check(not strip.find_child("PowerGroup", true, false).visible, "VP2 the strip reads player 2's faction (no power)")
	runner.check(view.order_marks() == [Iso.world_to_plane(Vector2(16.5, 14.5))], "VP2 order marks show player 2's units only, got " + str(view.order_marks()))
	main._reset_camera()
	runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(main.driver.first_note.starts[2]) + Vector2(0.5, 0.5)), "VP2 the camera resets onto player 2's start")
	var at := Vector2(76, 688)
	var one: int = view._rows.index_of(ids.stacked)
	var rival: int = view._rows.index_of(ids.rival)
	var front: Callable = func(i: int) -> Variant: return WorldBatch.sort_key(WorldBatch.kind_info(view._kind_of(i))[1], view._drawn_position(i), view._rows.id[i])
	runner.check(view._pick_bounds(one).has_point(at) and view._pick_bounds(rival).has_point(at) and front.call(rival) > front.call(one), "VP2 fixture: the click lies in both units and the rival is drawn in front")
	runner.check(view.resolve_pick(at) == {"tier": "unit", "id": ids.stacked}, "VP2 a pick still puts player 1's unit first, got " + str(view.resolve_pick(at)))
	main.orders._move(Vector2(20.5, 10.5))
	var moves: Array = (sim.snapshot().pending_commands + main.driver.queued()).filter(func(command: Dictionary) -> bool: return command.type == "move")
	runner.check(moves.size() == 1 and moves[0].has("player") and moves[0].player == 1, "VP2 an order still carries player 1, got " + str(moves))
	main.orders.selected_ids.clear()
	BaseScene.publish(main)
	var labels: Array = _build_labels(main)
	runner.check(labels.any(func(text: String) -> bool: return text.contains("Supply Depot")) and not labels.any(func(text: String) -> bool: return text.contains("Supply Cache")), "VP2 the build sub-grid keeps player 1's faction, got " + str(labels))
	main.orders.selected_ids.assign([ids.collector])
	BaseScene.publish(main)
	runner.check(_panel_text(main, "RightLabel") == "TO SUPPLY DEPOT" and HudModel.drop_off("frc") != "SUPPLY DEPOT", "VP2 the collector names its owner's drop-off, got '%s'" % _panel_text(main, "RightLabel"))
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = ids.barracks
	main.view_player = 1
	BaseScene.publish(main)
	runner.check(view.rally_marker() == [20.5, 14.5], "VP2 fixture: the rally marker shows for player 1")
	main.view_player = 2
	BaseScene.publish(main)
	runner.check(view.rally_marker().is_empty(), "VP2 the rally marker follows view_player")
	main.free()
	return true

func _click_control(main, control: Control) -> void:
	var at: Vector2 = main.get_viewport().get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event)

func _accept_keys(runner, main, label: String) -> void:
	for code: Key in [KEY_SPACE, KEY_ENTER]: _push_key(main, code)
	var focus: Control = _focus_owner(main)
	runner.check(focus == null or not main.get_node("HUD/Economy").is_ancestor_of(focus), "SF1 after a click on %s no slab button keeps the focus, got %s" % [label, focus])

func test_slab_buttons_take_no_focus(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = barracks
	main._refresh()
	await runner.process_frame
	var count = func(type: String) -> int: return main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == type).size()
	_click_control(main, main.get_node("HUD/Economy/Card/Q"))
	runner.check(count.call("produce") == 1, "SF1 fixture: a click on a produce cell queues one unit")
	_accept_keys(runner, main, "a produce button")
	runner.check(count.call("produce") == 1, "SF1 Space and Enter after a click on a produce button queue nothing more, got %d" % count.call("produce"))
	BaseScene.tick(main)
	await runner.process_frame
	var now: Control = BaseScene.now_row(main)
	runner.check(now != null, "SF1 fixture: NOW shows")
	if now != null: _click_control(main, now)
	runner.check(count.call("cancel_production") == 1, "SF1 fixture: a click on NOW cancels it")
	_accept_keys(runner, main, "NOW")
	runner.check(count.call("cancel_production") == 1, "SF1 Space and Enter after a click on NOW cancel nothing more, got %d" % count.call("cancel_production"))
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1 and unit.kind == "usa_builder")[0].id
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([builder])
	main._refresh()
	await runner.process_frame
	BaseScene.new().key(main, HudModel.BUILD_KEY)
	await runner.process_frame
	var item: Control = main.find_child("Card", true, false).get_child(0)
	_click_control(main, item)
	runner.check(not main.orders._placement_kind.is_empty(), "SF1 fixture: a click on a build item arms placement")
	main.orders._clear_placement()
	_accept_keys(runner, main, "a build item")
	runner.check(main.orders._placement_kind.is_empty(), "SF1 Space and Enter after a click on a build item arm nothing, got '%s'" % main.orders._placement_kind)
	main.free()
	return true

func test_drag_box_ends_with_the_match(runner) -> bool:
	var helper = BaseScene.new()
	for ending: String in ["victory", "freeze"]:
		var main = await _setup(runner)
		main.change_scene = func(_path: String) -> void: pass
		var world: Dictionary = _frozen_arena(main) if ending == "freeze" else {}
		if ending == "victory": _arena(main)
		var from: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5))
		helper.pointer(main, from, MOUSE_BUTTON_LEFT, true)
		var motion := InputEventMouseMotion.new()
		motion.position = main.get_node("WorldView").get_global_transform_with_canvas() * from + Vector2(60, 40)
		main._unhandled_input(motion)
		var box: Control = main.get_node("HUD/SelectionBox")
		runner.check(main.orders.is_selecting() and box.visible, "SE1 fixture (%s): a drag on the map shows its box" % ending)
		if ending == "victory": _victory(main)
		else:
			world.pump.fail_next = true
			BaseScene.tick(main)
		runner.check(main.shown_over() if ending == "victory" else main.frozen(), "SE1 fixture (%s): the card is up" % ending)
		var zoom: Vector2 = main.get_node("Camera2D").zoom
		main.change_zoom(1)
		runner.check(not main.orders.is_selecting() and not box.visible and not main.orders.busy() and main.get_node("Camera2D").zoom != zoom, "SE1 the %s card ends the drag: no box, zoom free, got selecting %s box %s busy %s" % [ending, main.orders.is_selecting(), box.visible, main.orders.busy()])
		main.free()
	return true

static func start_unit_id(main) -> int:
	var state: Dictionary = main.driver.pump.live().snapshot()
	var kind: String = Registry.faction(HudModel.player(state, main.local_player).faction).start_unit
	var ids: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == main.local_player and unit.kind == kind).map(func(unit: Dictionary) -> int: return unit.id)
	ids.sort()
	return ids[0] if not ids.is_empty() else -1

func test_match_starts_with_builder_selected(runner) -> bool:
	var main = await _setup(runner)
	var camera: Camera2D = main.get_node("Camera2D")
	var start: int = start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids == [start], "SS1 offline: the first view selects the start builder %d, got %s" % [start, main.orders.selected_ids])
	runner.check(main.get_node("HUD/Economy/Card").is_visible_in_tree(), "SS1 offline: its card shows")
	runner.check(main._sound._unit_voice.stream == null, "SS1 offline: the start selection plays no voice")
	var at: Vector2 = camera.position
	main._reset_camera()
	runner.check(camera.position == at, "SS1 offline: the camera stays at the start view, got %s against %s" % [at, camera.position])
	main.orders.selected_ids.clear()
	BaseScene.tick(main)
	runner.check(main.orders.selected_ids.is_empty(), "SS2 a deselect holds: later views select nothing, got %s" % str(main.orders.selected_ids))
	main._restart()
	start = start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids == [start], "SS2 rematch: the restart selects the new start builder %d, got %s" % [start, main.orders.selected_ids])
	main.driver.pump.live().remove_object(start)
	BaseScene.tick(main)
	runner.check(main.orders.selected_ids.is_empty() and not main.get_node("HUD/Economy/Card").is_visible_in_tree(), "SS7 the start builder dying in the first step: nothing selected, no card, got %s" % str(main.orders.selected_ids))
	var screen: Script = main.get_script()
	var factions: Dictionary = screen.factions
	screen.factions = {1: "frc", 2: "usa"}
	main._restart()
	screen.factions = factions
	start = start_unit_id(main)
	runner.check(start != -1 and main.orders.selected_ids == [start] and main.driver.pump.live().snapshot().entities.any(func(unit: Dictionary) -> bool: return unit.id == start and unit.kind == "frc_builder"), "SS8 an FRC start selects its Laborer %d, got %s" % [start, main.orders.selected_ids])
	main.free()
	await _start_waits_for_orders(runner)
	return true

# Only a seat that takes orders gets the start selection; it waits for the first view that does.
func _start_waits_for_orders(runner) -> void:
	for holder: String in ["note", "result", "freeze"]:
		var main = await _setup(runner)
		if holder == "note": main.get_node("HUD/Playtest/MarkerDialog").show()
		elif holder == "result": _victory(main)
		else:
			_frozen_arena(main).pump.fail_next = true
			BaseScene.tick(main)
		var start: int = start_unit_id(main)
		runner.check(start != -1, "SS9 fixture: the seat under the %s owns a start builder" % holder)
		runner.check(not main.orders.takes_orders(), "SS9 fixture: the %s holds the match" % holder)
		main.orders.reset()
		main._reshow()
		runner.check(main.orders.selected_ids.is_empty(), "SS9 a start view under the %s selects nothing, got %s" % [holder, main.orders.selected_ids])
		if holder == "note":
			main.get_node("HUD/Playtest/MarkerDialog").hide()
			main._reshow()
			runner.check(main.orders.selected_ids == [start], "SS9 the note closed, the next view selects the start builder %d, got %s" % [start, main.orders.selected_ids])
		main.free()

func test_offline_bot_row_marked(runner) -> bool:
	var main = await _setup(runner)
	_arena(main)
	for object: Dictionary in main.driver.pump.live().snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 2): main.driver.pump.live().remove_object(object.id)
	for object: Dictionary in main.driver.pump.live().snapshot().buildings.filter(func(building: Dictionary) -> bool: return building.owner == 2): main.driver.pump.live().remove_object(object.id)
	BaseScene.tick(main)
	var cells: Array = main.get_node(TABLE).get_children()
	runner.check(cells.size() == 12, "T26 offline keeps one row per player and no group rows, got %d cells" % cells.size())
	if cells.size() == 12: runner.check(cells[4].text.begins_with("P1 ") and cells[4].text.ends_with(" (you)") and cells[8].text.begins_with("P2 ") and cells[8].text.ends_with(" (bot)"), "T26 the offline bot row is marked, got '%s' and '%s'" % [cells[4].text, cells[8].text])
	main.free()
	return true
