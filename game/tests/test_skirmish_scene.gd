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
var freeze_sessions: String = "user://test-freeze-playtests-%d" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_skirmish_ready_and_tick, test_combat_context_input, test_match_hud_and_restart, test_combat_view, test_hud_layout_and_focus, test_hud_build_line, test_enemy_selection_read_only, test_rally_input_and_marker, test_supply_pile_labels, test_attack_move_hint_and_rejection, test_selection_prunes_dead, test_order_marks_own_only, test_health_bar_clear_of_boxes, test_result_panel_layout, test_result_stats_from_sim, test_result_panel_focus, test_result_panel_keys, test_enter_in_text_field_keeps_match, test_change_setup_leaves, test_result_panel_unit, test_play_again_routes_by_driver, test_silent_keys_explain, test_hud_strings_use_display_names, test_hud_font_size_is_shared, test_defence_attack_scene, test_enter_unload_scene, test_right_click_pile_gathers, test_right_click_pile_in_launcher_flow, test_frc_laborer_right_click_pile, test_one_snapshot_per_refresh, test_refresh_waits_for_next_frame, test_auto_pick_samples_present_time, test_hud_summaries_are_pinned, test_input_script_offline, test_offline_driver_stamps_like_the_scene, test_sb1_submit_takes_no_snapshot, test_sb1_economy_input_reads_shown, test_sb1_combat_input_reads_shown, test_sb1_pick_of_unit_dead_since_shown, test_sb1_result_uses_shown_team, test_sb1_setup_shown_allows_input, test_sb1_idle_offline_ticks_take_no_snapshot, test_offline_driver_bot_memory_on_simulation, test_orders_turn_input_into_payloads, test_hud_reads_only_state_and_orders, test_sb2_refusal_next_step, test_sb2_refusal_survives_accepted_result, test_sb2_restart_drops_held_answer, test_sb2_answer_waits_for_unpause, test_sb3_submit_queues, test_sb3_match_log_equals_recorder, test_sb3_restart_drops_old_notes, test_sb3_paused_posts_nothing, test_sb3_over_stops_refreshing, test_sb3_process_drains, test_sb3_refusal_waits_in_queue, test_sb3_one_view_per_tick, test_sb3_record_reads_live_without_queue, test_ph_refused_post_keeps_queue_and_preview, test_freeze_card_on_a_failed_pump, test_freeze_leave_reaches_the_launcher, test_failure_first_met_while_leaving, test_freeze_card_copy_and_layout, test_freeze_card_keeps_the_focus, test_freeze_flush_keeps_the_queue]

func _setup(runner):
	var main = Scene.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
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
	for path in ["WorldView", "Camera2D", "HUD/Status", "HUD/ResultPanel", "HUD/Economy/Produce"]:
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
	for center in [Vector2(0, 256), Vector2(80, 320)]:
		for zoom in [0.5, 1.0, 2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			var before: int = _pending(main)
			helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
			runner.check(_pending(main) == before + 1 and _pending(main, "move") == 0, "K3 enemy right-click submits one attack at zoom " + str(zoom))
	var group: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "attack")
	runner.check(group[0].entity_ids == [ids.infantry, ids.tank] and group[0].target_id == ids.enemy, "K3 mixed infantry and tank is one group command")
	main.orders.selected_ids.assign([1, ids.infantry])
	var pending: int = _pending(main)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	runner.check(not main.orders._attack_move_mode and _pending(main) == pending, "K3 right-click cancels attack-move without an attack")
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	helper.key(main, KEY_A)
	main.orders.selected_ids.assign([1])
	helper.key(main, KEY_1)
	runner.check(not main.orders._attack_move_mode and main.orders._placement_kind == "usa_power_plant", "K3 placement clears a stale attack-move mode")
	helper.key(main, KEY_ESCAPE)
	main.orders.selected_ids.assign([1])
	main._refresh()
	helper.key(main, KEY_1)
	helper.key(main, KEY_A)
	runner.check(main.orders._placement_kind == "usa_power_plant" and not main.orders._attack_move_mode, "K3 placement mode consumes controls first")
	main.free()
	return true

func test_match_hud_and_restart(runner) -> bool:
	var main = await _setup(runner)
	runner.check(View.owner_color(1) != View.owner_color(2), "K4 owner colors differ")
	var ids: Dictionary = _arena(main)
	main.orders.selected_ids.assign([ids.tank])
	main._refresh()
	var credits: String = str(main._local_state(main.shown_state).credits)
	runner.check(main.get_node("HUD/Hud/TopStrip").find_child("Credits", true, false).text == credits and _panel_text(main, "Name") == "Battle Tank" and _panel_text(main, "Health") == "480 / 480", "K4 credits, kind and health in the HUD")
	var setup: Dictionary = main.driver.pump.live().view_state()
	setup.match.status = "setup"
	main._show_result(setup)
	runner.check(main.get_node(OUTCOME).text.is_empty() and not main.get_node("HUD/ResultPanel").visible, "K4 the setup phase shows no result")
	main.driver.pump.live().remove_object(3)
	main.driver.pump.live().remove_object(4)
	BaseScene.tick(main)
	runner.check(main.get_node(OUTCOME).text == "Victory" and main.get_node(PLAY_AGAIN).visible and not main.get_node(PLAY_AGAIN).disabled, "K4 victory and restart button")
	runner.check(not main.get_node("HUD/Status").text.contains("A: attack-move click"), "K4 the status line drops the order hints under a result")
	main.driver.pump.live()._players[main.local_player].team = 7
	BaseScene.publish(main)
	runner.check(main._result_text({"status": "won", "winner": 7}) == "Victory" and main._result_text({"status": "won", "winner": main.local_player}) == "Defeat", "K4 result compares the winning team id with the local team")
	var before: Array = main.driver.pump.live().snapshot().pending_commands
	main._submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	main._unhandled_input(InputEventKey.new())
	runner.check(main.driver.pump.live().snapshot().pending_commands == before, "K4 terminal match accepts no orders")
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "Match ended", "K4 terminal match accepts no orders, got '%s'" % main.hud.refusal)
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
	runner.check(main.driver.pump.live().snapshot() == Skirmish.create().snapshot() and main.orders.selected_ids.is_empty() and main.orders._placement_kind.is_empty() and not main.orders._attack_move_mode and main.hud.refusal.is_empty() and main.get_node("Camera2D").zoom == Vector2.ONE and not main.get_node("HUD/ResultPanel").visible and main._last_result_tick == -1 and main._last_result_sequence == -1 and not main.orders._selecting and not main.orders._dragged and main.get_node("Camera2D").position != Vector2(500, 500) and main.get_node("WorldView")._preview_cells.is_empty(), "K4 restart leaves nothing from the old match")
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
	main._unhandled_input(_right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)))
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

func _build_labels(main) -> Array:
	return main.get_node("HUD/Economy/BuildMenu").get_children().map(func(button: Button) -> String: return button.text)

func test_hud_build_line(runner) -> bool:
	var main = await _setup(runner)
	var labels: Array = _build_labels(main)
	var text: String = BaseScene.hud_text(main)
	runner.check(not labels.is_empty() and labels[0].begins_with("1: ") and not text.contains("1-9: menu") and not text.contains("U: unload"), "H1 the build buttons carry their keys and no key-hint line shows, got %s" % [labels])
	var base_helper = BaseScene.new()
	var base = await base_helper.setup(runner)
	runner.check(_build_labels(base) == labels, "H1 base scene shares the build buttons")
	base.free()
	var sim = Skirmish.create(false)
	var hub: int = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(10, 10))
	var rifle: int = sim.spawn(1, Vector2(9.5, 10.5), "frc_rifle_infantry")
	sim.start_match([1, 2] as Array[int])
	main.driver.adopt(sim)
	main.orders.selected_building_id = hub
	main._refresh()
	var unload: Button = main.get_node("HUD/Economy/Orders/Unload")
	runner.check(not unload.is_visible_in_tree(), "H1 no Unload while the hub is empty")
	Fixture.load_unit(runner, sim, rifle, hub)
	BaseScene.publish(main)
	runner.check(unload.is_visible_in_tree() and unload.text == "Unload (F)", "H1 a loaded hub shows Unload (F), got '%s'" % unload.text)
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
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 14.5)), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "set_rally")
	runner.check(orders.size() == 1 and orders[0].building_id == barracks and orders[0].target == [20.5, 14.5], "R1 right-click on ground issues set_rally for that cell")
	BaseScene.tick(main)
	runner.check(view.rally_marker() == [20.5, 14.5], "R1 marker follows the new rally")
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

func _right_click(main, plane: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event

func test_attack_move_hint_and_rejection(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var view = main.get_node("WorldView")
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
	runner.check(view.hints().size() == 1, "H3 attack-move click leaves one hint")
	main.orders.selected_ids.assign([ids.infantry])
	var before: int = view.hints().size()
	main.driver.pump.live().remove_object(ids.infantry)
	helper.pointer(main, Iso.world_to_plane(Vector2(8.5, 8.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(view.hints().size() == before, "H3 a second command replaces the marker, still one")
	main.orders.selected_ids.clear()
	view.add_hint(Vector2(1, 1), 0)
	helper.pointer(main, Iso.world_to_plane(Vector2(9.5, 9.5)), MOUSE_BUTTON_RIGHT, true)
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
	main.orders.selected_ids.assign([ids.infantry])
	var before: Dictionary = main.driver.pump.live().snapshot()
	helper.key(main, KEY_1)
	runner.check(main.orders._placement_kind.is_empty() and main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty() and main.hud.refusal == "Choose one builder", "P4 build key without a builder says why, got '%s'" % main.hud.refusal)
	main.hud.refusal = ""
	main.orders.selected_ids.clear()
	helper.key(main, KEY_E)
	runner.check(main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty() and main.hud.refusal == "Select a production building", "P4 E without a building says why, got '%s'" % main.hud.refusal)
	main.free()
	return true

func _hud_texts(main) -> Array[String]:
	var texts: Array[String] = [BaseScene.hud_text(main), main.get_node("HUD/Economy/Produce").text, main.get_node("HUD/Economy/CancelBuild").text]
	for group: String in ["BuildMenu", "Queue"]:
		for button in main.get_node("HUD/Economy/" + group).get_children(): texts.append(button.text)
	return texts

func test_hud_strings_use_display_names(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = barracks
	main._refresh()
	main.orders._produce_selected()
	main.orders._produce_selected()
	BaseScene.tick(main)
	await runner.process_frame
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "N1 produce button names the unit, got " + main.get_node("HUD/Economy/Produce").text)
	runner.check(main.get_node("HUD/Economy/Queue").get_child_count() == 2, "N1 fixture: two queue entries")
	var shown: Array[String] = _hud_texts(main)
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1 and unit.kind == "usa_builder")[0].id
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([builder])
	main.orders._enter_placement("usa_power_plant")
	var armed: Array = main.get_node("HUD/Economy/BuildMenu").get_children().filter(func(button: Button) -> bool: return button.theme_type_variation == &"HudButtonArmed")
	runner.check(armed.size() == 1 and armed[0].text.ends_with("Power Plant"), "N1 the armed button names the building, got %s" % [armed.map(func(button: Button) -> String: return button.text)])
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
	main.orders._produce_selected()
	BaseScene.tick(main)
	await runner.process_frame
	runner.check(main.get_node("HUD/Economy/Queue").get_child_count() == 1, "FS1 fixture: a queue entry, got %d" % main.get_node("HUD/Economy/Queue").get_child_count())
	runner.check(main.get_node("HUD/Status").get_theme_font_size("font_size") == 12, "FS1 HUD/Status is 12 px")
	var muted: Color = ThemeDB.get_project_theme().get_color(&"muted", &"Tokens")
	runner.check(main.get_node("HUD/Status").get_theme_color("font_color") != muted, "FS1 the status line has no backdrop, so it is not muted")
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
	helper.pointer(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "defence_attack")
	runner.check(orders.size() == 1 and orders[0].building_id == defence and orders[0].target_id == enemy and main.hud.refusal.is_empty(), "DA5 right-click on an enemy in reach submits defence_attack")
	helper.pointer(main, Iso.world_to_plane(Vector2(30.5, 30.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var enters: Array = orders.call("enter")
	runner.check(enters.size() == 1 and enters[0].entity_ids == [rifle] and enters[0].target_id == hub and main.hud.refusal.is_empty(), "TU1 right-click on an own hub submits enter")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var attacks: Array = orders.call("attack")
	runner.check(attacks.size() == 1 and attacks[0].target_id == enemy_hub and orders.call("enter").size() == 1, "TU1 right-click on an enemy hub still attacks")
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = hub
	main._refresh()
	helper.key(main, KEY_U)
	runner.check(orders.call("unload").is_empty(), "TU1 U no longer unloads")
	helper.key(main, KEY_F)
	var unloads: Array = orders.call("unload")
	runner.check(unloads.size() == 1 and unloads[0].target_id == hub, "TU1 F with the hub selected submits unload")
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([rifle])
	main._refresh()
	helper.key(main, KEY_F)
	runner.check(orders.call("unload").size() == 1 and main.hud.refusal == "Select a container", "TU1 F without a container says why, got '%s'" % main.hud.refusal)
	var hub_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	sim._entities[rifle].container_id = hub
	sim._entities[rifle].position = [10.5, 10.5]
	BaseScene.publish(main)
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
		helper.pointer(main, Iso.world_to_plane(Vector2(21.5, 9.5)), MOUSE_BUTTON_RIGHT, true)
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
		helper.pointer(main, Iso.world_to_plane(centre), MOUSE_BUTTON_RIGHT, true)
		runner.check(_pending(main, "gather") == 1, "K11 %s collector right-click on the pile gathers, pending %s" % [faction, str(sim.snapshot().pending_commands)])
		var bystander: int = sim.spawn(1, centre, "usa_collector")
		var gathers: int = _pending(main, "gather")
		BaseScene.publish(main)
		helper.pointer(main, Iso.world_to_plane(centre) + Vector2(0, -26), MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	main.driver.flush()
	var orders: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "gather")
	runner.check(orders.size() == 1 and orders[0].entity_ids == laborers and orders[0].source_id == pile.id, "K13 several laborers, one of them building, right-click the pile gathers, got %s err %s" % [str(sim.snapshot().pending_commands), main.hud.refusal])
	Fixture.steps(sim, 3)
	runner.check(sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.id in laborers and u.collection.enabled).size() == laborers.size(), "K13 every laborer, including the builder, starts collecting")
	main.orders.selected_ids.assign([laborers[0]])
	BaseScene.publish(main)
	helper.key(main, KEY_1)
	var ghost: String = main.orders._placement_kind
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	var gathers: int = _pending(main, "gather")
	runner.check(not ghost.is_empty() and main.orders._placement_kind.is_empty(), "K13 right-click with a build ghost cancels the ghost, ghost was " + ghost)
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
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
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "RF2 produce label unchanged")
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

const HUD_TEXTS: Array[String] = ["Rifleman · 156 / 180 · ", "Supply Helicopter · 300 / 300 · WAITING AT PILE", "Supply Helicopter · 300 / 300 · TO PILE", "Bulldozer · 250 / 250 · ", "Rifleman · 180 / 180 · ", "Headquarters · 5000 / 5000 · "]

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
	var row: String = "%d|sel=%s|bld=%d|insp=%d|place=%s|pend=%s|am=%s|esc=%s|menu=%s|perf=%s|%s" % [step, main.orders.selected_ids, main.orders.selected_building_id, main.orders.inspected_id, main.orders._placement_kind, main.orders._pending_placement, main.orders._attack_move_mode, main._escape_pending(), main.menu_open(), main._perf.visible, ";".join(added)]
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
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 10.5)), MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, at.call(15.5, 6.5), MOUSE_BUTTON_RIGHT, true)
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
	helper.key(main, KEY_1)
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
	helper.key(main, KEY_E)
	runner.check(sim_orders.call("produce") == 1, "IC1 step 12 took effect")
	rows.append(_ic_row(main, 12, seen, true))
	helper.pointer(main, Iso.world_to_plane(Vector2(26.5, 16.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(sim_orders.call("set_rally") == 1, "IC1 step 13 took effect")
	rows.append(_ic_row(main, 13, seen))
	_ic_click(helper, main, at.call(6.5, 12.5))
	helper.pointer(main, at.call(27.0, 13.0), MOUSE_BUTTON_RIGHT, true)
	runner.check(sim_orders.call("resume_build") == 1, "IC1 step 14 took effect")
	rows.append(_ic_row(main, 14, seen))
	_ic_click(helper, main, at.call(30.5, 22.5))
	helper.key(main, KEY_F)
	runner.check(sim_orders.call("unload") == 1, "IC1 step 15 took effect")
	rows.append(_ic_row(main, 15, seen))
	_ic_click(helper, main, at.call(14.5, 14.5))
	helper.pointer(main, at.call(30.5, 22.5), MOUSE_BUTTON_RIGHT, true)
	runner.check(sim_orders.call("enter") == 1, "IC1 step 16 took effect")
	rows.append(_ic_row(main, 16, seen))
	var builder_box: Array[Vector2] = _ic_box(Iso.world_to_plane(Vector2(6.5, 12.5)), Iso.world_to_plane(Vector2(6.5, 12.5)), 30.0)
	helper.pointer(main, builder_box[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_1)
	helper.pointer(main, builder_box[1], MOUSE_BUTTON_LEFT, false)
	runner.check(not main.orders._placement_kind.is_empty() and main.orders._pending_placement.is_empty(), "IC1 step 17 took effect")
	rows.append(_ic_row(main, 17, seen))
	_ic_esc(main)
	_ic_esc(main)
	runner.check(main.orders._placement_kind.is_empty() and main.orders.selected_ids.is_empty(), "IC1 step 18 took effect")
	rows.append(_ic_row(main, 18, seen))
	_ic_click(helper, main, at.call(15.5, 6.5))
	runner.check(main.orders.inspected_id == ids.enemy, "IC1 step 19 took effect")
	rows.append(_ic_row(main, 19, seen, true))
	_ic_click(helper, main, at.call(6.5, 12.5))
	helper.pointer(main, at.call(35.0, 9.0), MOUSE_BUTTON_RIGHT, true)
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

func test_offline_driver_bot_memory_on_simulation(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.adopt(Skirmish.create())
	while driver.pump.live().tick() < Skirmish.next_decision(Skirmish.ATTACK_TICK, 2): driver.pump.live().step()
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
	var produce: Button = main.get_node("HUD/Economy/Produce")
	produce.hide()
	main.hud.note = "Choose one builder"
	main.stepped_results.append({"ok": false, "error": "Not yours", "player": 2, "tick": 5, "sequence": 0})
	var view: Dictionary = sim.view_state()
	main._take_results(view)
	main.hud.update_hud(view, main._hud_selection(view), main.local_player, main.local_player)
	var status: String = main.get_node("HUD/Status").text
	runner.check(produce.visible and _panel_text(main, "Name") == Registry.kind("usa_barracks").display_name and main.hud.note == "Choose one builder" and status.contains("Choose one builder"), "HU1 the HUD shows the selection and keeps the local note")
	runner.check(main.hud.refusal != "Not yours" and not status.contains("Not yours"), "HU1 _take_results ignores player 2's stepped result, got '%s'" % main.hud.refusal)
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
	helper.key(main, KEY_1)
	var spot: Vector2 = Iso.world_to_plane(Vector2(cell) + Vector2(0.25, 0.25))
	helper.hover(main, spot)
	helper.pointer(main, spot, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, spot, MOUSE_BUTTON_LEFT, false)
	helper.pointer(main, Iso.world_to_plane(Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5)), MOUSE_BUTTON_RIGHT, true)
	helper.key(main, KEY_F)
	var click: Vector2 = Iso.world_to_plane(Vector2(13.5, 13.5))
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, false)
	helper.key(main, KEY_E)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 14.5)), MOUSE_BUTTON_RIGHT, true)
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
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_RIGHT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	helper.key(main, KEY_A)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_LEFT, false)
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
	BaseScene.tick(main)
	runner.check(main.hud.refusal.contains("Missing entity or wrong owner"), "RB4 the simulation refuses it, got '%s'" % main.hud.refusal)
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
	var oracle = Skirmish.create(true, "ai", main.factions, main.map_path, main.starts)
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
	_push_key(main, KEY_1)
	runner.check(types.call() == ["move"] and not main.orders.busy() and main.hud.refusal == refusal, "FN1 keys behind the card reach no order, got %s busy %s refusal '%s'" % [types.call(), main.orders.busy(), main.hud.refusal])
	runner.check(_freeze_shown(main) and _focus_owner(main) == main.get_node(COPY), "FN1 the card stays up with the focus on Copy report")
	main.get_node(COPY).pressed.emit()
	main._reshow()
	runner.check(main.get_node(COPY).text == "Report copied" and _focus_owner(main) == main.get_node(COPY) and _freeze_shown(main), "FN1 a refresh after the copy keeps Report copied and the focus")
	main.free()
	return true

func test_freeze_leave_reaches_the_launcher(runner) -> bool:
	for way: String in ["Back to menu", "Esc then Back to main menu"]:
		var saved: Dictionary = _helper_on()
		var main = await _setup(runner)
		var scenes: Array[String] = []
		main.change_scene = func(path: String) -> void: scenes.append(path)
		var world: Dictionary = _frozen_arena(main)
		main.orders.selected_ids.assign([world.ids.builder])
		main._reshow()
		_push_key(main, KEY_1)
		runner.check(main._playtest.is_active() and main.orders.busy() and not main.orders.selected_ids.is_empty(), "FN2 %s fixture: helper on, a unit selected, a placement armed" % way)
		world.pump.fail_next = true
		BaseScene.tick(main)
		runner.check(_freeze_shown(main), "FN2 %s: the freeze card is up" % way)
		if way == "Back to menu": main.get_node(CHANGE_SETUP).pressed.emit()
		else:
			main._show_esc_chip()
			runner.check(main.get_node("HUD/MenuChip").find_child("EscChip", true, false).visible, "FN2 the Esc chip shows under the freeze card")
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
	var menu: GridContainer = main.find_child("BuildMenu", true, false)
	runner.check(menu.get_child_count() > 0, "FN5 fixture: the builder's build buttons are up")
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
	menu.get_child(0).grab_focus()
	_push_enter(main)
	main.orders._produce_selected()
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
