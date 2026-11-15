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
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const ViewRows = preload("res://tests/test_view_rows.gd")
const IcRows = preload("res://tests/input_script_rows.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const Hud = preload("res://scripts/match/hud.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const OUTCOME: String = "HUD/ResultPanel/Center/Card/Box/Outcome"
const PLAY_AGAIN: String = "HUD/ResultPanel/Center/Card/Box/Buttons/PlayAgain"
const CHANGE_SETUP: String = "HUD/ResultPanel/Center/Card/Box/Buttons/ChangeSetup"

func cases() -> Array[Callable]:
	return [test_skirmish_ready_and_tick, test_combat_context_input, test_match_hud_and_restart, test_combat_view, test_hud_layout_and_focus, test_hud_build_line, test_enemy_selection_read_only, test_rally_input_and_marker, test_supply_pile_labels, test_attack_move_hint_and_rejection, test_selection_prunes_dead, test_order_marks_own_only, test_health_bar_clear_of_boxes, test_result_panel_layout, test_result_panel_keys, test_enter_in_text_field_keeps_match, test_change_setup_leaves, test_result_panel_unit, test_play_again_routes_by_driver, test_silent_keys_explain, test_hud_strings_use_display_names, test_hud_font_size_is_shared, test_defence_attack_scene, test_enter_unload_scene, test_right_click_pile_gathers, test_right_click_pile_in_launcher_flow, test_frc_laborer_right_click_pile, test_one_snapshot_per_refresh, test_refresh_waits_for_next_frame, test_auto_pick_samples_present_time, test_hud_summaries_are_pinned, test_input_script_offline, test_offline_driver_stamps_like_the_scene, test_sb1_submit_takes_no_snapshot, test_sb1_economy_input_reads_shown, test_sb1_combat_input_reads_shown, test_sb1_pick_of_unit_dead_since_shown, test_sb1_result_uses_shown_team, test_sb1_setup_shown_allows_input, test_sb1_idle_offline_ticks_take_no_snapshot, test_offline_driver_bot_memory_on_simulation, test_orders_turn_input_into_payloads, test_hud_reads_only_state_and_orders]

func _setup(runner):
	var main = Scene.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func _pending(main, type: String = "") -> int:
	return main.driver.sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return type.is_empty() or command.type == type).size()

func _arena(main) -> Dictionary:
	var sim = Skirmish.create(false)
	var ids := {"infantry": sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry"), "tank": sim.spawn(1, Vector2(11.5, 10.5), "usa_tank"), "enemy": sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")}
	sim.start_match([1, 2] as Array[int])
	main.driver.sim = sim
	main.orders.selected_ids.assign([ids.infantry, ids.tank])
	main._refresh()
	return ids

func test_skirmish_ready_and_tick(runner) -> bool:
	var main = await _setup(runner)
	for path in ["WorldView", "Camera2D", "HUD/Status", "HUD/ResultPanel", "HUD/Economy/Produce"]:
		runner.check(main.has_node(path), "K2 node " + path)
	runner.check(main.driver.sim.snapshot() == Skirmish.create().snapshot(), "K2 exact scenario")
	main._physics_process(0.0)
	runner.check(main.driver.sim.snapshot().tick == 1, "K2 one physics callback is one tick")
	runner.check(main.driver.sim.snapshot().buildings.all(func(b: Dictionary) -> bool: return b.owner != 2 or b.kind != "usa_power_plant"), "K2 the opponent has not built before its decision tick")
	main._process(0.1)
	main._refresh()
	runner.check(main.driver.sim.snapshot().tick == 1, "K2 _process and _refresh never step")
	while main.driver.sim.snapshot().tick <= Skirmish.next_decision(0, 2) and main.driver.sim.snapshot().tick < 40: main._physics_process(0.0)
	var state: Dictionary = main.driver.sim.snapshot()
	runner.check(state.tick == Skirmish.next_decision(0, 2) + 1 and state.buildings.size() == 3 and state.buildings[2].owner == 2 and state.buildings[2].kind == "usa_power_plant", "K2 the opponent's first command lands on its seat's decision tick")
	for building: Dictionary in main.driver.sim.snapshot().buildings: main.driver.sim.remove_object(building.id)
	main._physics_process(0.0)
	var frozen: Dictionary = main.driver.sim.snapshot()
	main._physics_process(0.0)
	runner.check(frozen.match.status == "draw" and main.driver.sim.snapshot() == frozen, "K2 terminal match stays frozen")
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
	var group: Array = main.driver.sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "attack")
	runner.check(group[0].entity_ids == [ids.infantry, ids.tank] and group[0].target_id == ids.enemy, "K3 mixed infantry and tank is one group command")
	main.orders.selected_ids.assign([1, ids.infantry])
	var pending: int = _pending(main)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	runner.check(_pending(main) == pending + 1 and _pending(main, "move") == 0 and main.hud.note.is_empty(), "K3 an unarmed member no longer rejects the click")
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
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("Credits") and text.contains("Battle Tank #" + str(ids.tank)) and text.contains("HP 480/480") and text.contains("guard"), "K4 credits, kind, HP and order in the HUD")
	var setup: Dictionary = main.driver.sim.view_state()
	setup.match.status = "setup"
	main.hud._refresh_hud(setup)
	runner.check(main.get_node(OUTCOME).text.is_empty() and not main.get_node("HUD/ResultPanel").visible, "K4 the setup phase shows no result")
	main.driver.sim.remove_object(3)
	main.driver.sim.remove_object(4)
	main._physics_process(0.0)
	runner.check(main.get_node(OUTCOME).text == "Victory" and main.get_node(PLAY_AGAIN).visible and not main.get_node(PLAY_AGAIN).disabled, "K4 victory and restart button")
	main.driver.sim._players[main.local_player].team = 7
	main._refresh()
	runner.check(main.hud._result_text({"status": "won", "winner": 7}) == "Victory" and main.hud._result_text({"status": "won", "winner": main.local_player}) == "Defeat", "K4 result compares the winning team id with the local team")
	var before: Dictionary = main.driver.sim.snapshot()
	main._submit({"type": "move", "entity_ids": [ids.tank], "target": [12.5, 12.5]})
	main._unhandled_input(InputEventKey.new())
	runner.check(main.driver.sim.snapshot() == before and main.hud.note == "Match ended", "K4 terminal match accepts no orders")
	main.orders._placement_kind = "usa_power_plant"
	main.orders._attack_move_mode = true
	main.driver._sequence = 7
	main.hud.note = "old"
	main.hud._last_result_tick = 99
	main.hud._last_result_sequence = 99
	main.orders._selecting = true
	main.orders._dragged = true
	main.get_node("Camera2D").position = Vector2(500, 500)
	main.get_node("Camera2D").zoom = Vector2.ONE * 2.0
	main.get_node(PLAY_AGAIN).pressed.emit()
	runner.check(main.driver.sim.snapshot() == Skirmish.create().snapshot() and main.orders.selected_ids.is_empty() and main.orders._placement_kind.is_empty() and not main.orders._attack_move_mode and main.driver._sequence == 0 and main.hud.note.is_empty() and main.get_node("Camera2D").zoom == Vector2.ONE and not main.get_node("HUD/ResultPanel").visible and main.hud._last_result_tick == -1 and main.hud._last_result_sequence == -1 and not main.orders._selecting and not main.orders._dragged and main.get_node("Camera2D").position != Vector2(500, 500) and main.get_node("WorldView")._preview_cells.is_empty(), "K4 restart leaves nothing from the old match")
	main.orders.selected_ids.assign([1])
	main._submit({"type": "move", "entity_ids": [1], "target": [6.5, 14.5]})
	runner.check(main.hud.note.is_empty() and _pending(main, "move") == 1, "K4 first order after restart is valid")
	for loser in [[1, "Defeat"], [-1, "Draw"]]:
		var other = await _setup(runner)
		if loser[0] == 1:
			other.driver.sim.remove_object(2)
		else:
			other.driver.sim.remove_object(2)
			other.driver.sim.remove_object(3)
			other.driver.sim.remove_object(4)
		other._physics_process(0.0)
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
	var status: Label = main.get_node("HUD/Status")
	var economy: Control = main.get_node("HUD/Economy")
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons sit below every status line")
	var view = main.get_node("WorldView")
	runner.check(view.focus_targets().is_empty(), "K5 no focus before an order")
	main._unhandled_input(_right_click(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)))
	main._physics_process(0.0)
	runner.check(view.focus_targets() == {ids.enemy: true}, "K5 explicit attack target is marked strongly, got " + str(view.focus_targets()))
	main.orders.selected_ids.clear()
	main._refresh()
	runner.check(view.focus_targets().is_empty(), "K5 focus shows only for the selection")
	main.orders.inspected_id = ids.enemy
	main._refresh()
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons below an inspected enemy line")
	var pile: Dictionary = _pile_world(main)
	main.orders.selected_ids.assign([pile.waiting])
	main._refresh()
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "K5 buttons below a queued collector line")
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
	main.driver.sim = sim
	main.orders.selected_ids.clear()
	main._refresh()
	return {"source": source, "docked": first, "waiting": second}

func test_hud_build_line(runner) -> bool:
	var main = await _setup(runner)
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("1-9: menu") and text.contains("U: unload") and not text.contains("1/2/3"), "H1 skirmish build line, got " + text)
	var base_helper = BaseScene.new()
	var base = await base_helper.setup(runner)
	var base_text: String = base.get_node("HUD/Status").text
	runner.check(base_text.contains("1-9: menu") and base_text.contains("U: unload") and not base_text.contains("1/2/3"), "H1 base scene shares the menu hint")
	base.free()
	main.free()
	return true

func test_enemy_selection_read_only(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	var enemy_point: Vector2 = Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	var text: String = main.get_node("HUD/Status").text
	runner.check(main.orders.inspected_id == ids.enemy and main.orders.selected_ids.is_empty(), "E1 left-click selects the enemy read-only and replaces own selection")
	runner.check(text.contains("Enemy (P2) Battle Tank #%d HP 480/480" % ids.enemy), "E1 enemy line, got " + text)
	runner.check(text.contains("HP 480/480 | guard"), "E1 idle enemy shows its mode, got " + text)
	var before: Dictionary = main.driver.sim.snapshot()
	helper.key(main, KEY_E)
	helper.key(main, KEY_A)
	helper.key(main, KEY_S)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_RIGHT, true)
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 12.5)), MOUSE_BUTTON_RIGHT, true)
	runner.check(main.driver.sim.snapshot() == before and not main.orders._attack_move_mode and main.orders.inspected_id == ids.enemy, "E1 E, A, S and right-clicks send nothing")
	var own_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, own_point, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_ids == [ids.infantry] and main.orders.inspected_id == -1, "E1 own click selects own unit and clears inspection")
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, enemy_point, MOUSE_BUTTON_LEFT, false)
	main.driver.sim.remove_object(ids.enemy)
	main._refresh()
	runner.check(main.orders.inspected_id == -1, "E1 dead enemy clears inspection")
	main.free()
	return true

func test_rally_input_and_marker(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.sim = sim
	main.orders.selected_ids.clear()
	helper.sync_sequence(main)
	main._refresh()
	var view = main.get_node("WorldView")
	runner.check(view.rally_marker().is_empty(), "R1 no marker without a selection")
	var click: Vector2 = Iso.world_to_plane(Vector2(13.5, 13.5))
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, click, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_building_id == barracks and view.rally_marker() == [16.5, 13.5], "R1 marker shows the default rally while selected")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 14.5)), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "set_rally")
	runner.check(orders.size() == 1 and orders[0].building_id == barracks and orders[0].target == [20.5, 14.5], "R1 right-click on ground issues set_rally for that cell")
	main._physics_process(0.0)
	runner.check(view.rally_marker() == [20.5, 14.5], "R1 marker follows the new rally")
	helper.key(main, KEY_ESCAPE)
	runner.check(view.rally_marker().is_empty(), "R1 marker absent when deselected")
	var reactor: int = Fixture.build(runner, sim, "usa_power_plant", Vector2i(20, 20))
	main.orders.selected_building_id = reactor
	main.orders.selected_ids.assign([reactor])
	main._refresh()
	runner.check(view.rally_marker().is_empty(), "R1 no marker for a reactor, which cannot take a rally")
	main.free()
	return true

func test_supply_pile_labels(runner) -> bool:
	var main = await _setup(runner)
	var pile: Dictionary = _pile_world(main)
	var view = main.get_node("WorldView")
	var source: Dictionary = Fixture.object(main.driver.sim, pile.source)
	runner.check(Fixture.object(main.driver.sim, pile.docked).collection.phase in ["loading"] and Fixture.object(main.driver.sim, pile.waiting).collection.phase == "waiting_source", "S1 fixture: one collector docked, one waiting")
	runner.check(view.pile_lines(source) == PackedStringArray(["Boxes %d" % source.boxes, "docked 1 · waiting 1"]), "S1 pile label, got " + str(view.pile_lines(source)))
	var points: PackedVector2Array = view.pile_text_points(source)
	runner.check(points.size() == 2 and points[1].y - points[0].y >= ThemeDB.fallback_font.get_height(UiStyle.FONT_SIZE), "S1 pile lines are a full text height apart, got " + str(points))
	main.orders.selected_ids.assign([pile.waiting])
	main._refresh()
	runner.check(main.get_node("HUD/Status").text.contains("waiting_source (1st in line)"), "S1 waiting collector shows its place in line")
	main.orders.selected_ids.assign([pile.docked])
	main._refresh()
	var text: String = main.get_node("HUD/Status").text
	runner.check(text.contains("| loading") and not text.contains("in line"), "S1 docked collector shows its phase only")
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
	main.driver.sim.remove_object(ids.infantry)
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
	main.driver.sim.remove_object(ids.tank)
	main._refresh()
	runner.check(main.orders.selected_ids == [ids.infantry], "H4 selection keeps only live ids, got " + str(main.orders.selected_ids))
	main.free()
	return true

func test_order_marks_own_only(runner) -> bool:
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	Fixture.send(main.driver.sim, {"type": "move", "entity_ids": [ids.tank], "target": [12.5, 14.5]})
	Fixture.send(main.driver.sim, {"type": "move", "player": 2, "entity_ids": [ids.enemy], "target": [16.5, 14.5]})
	Fixture.steps(main.driver.sim, 2)
	main._refresh()
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
	main.driver.sim.remove_object(3)
	main.driver.sim.remove_object(4)
	main._physics_process(0.0)

func _enter(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func test_result_panel_layout(runner) -> bool:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var main = Scene.instantiate()
		port.add_child(main)
		main.set_physics_process(false)
		main.set_process(false)
		await runner.process_frame
		_arena(main)
		_victory(main)
		var panel = main.get_node("HUD/ResultPanel")
		panel.show_result("Victory", "Your friend wants to play again", true)
		await runner.process_frame
		await runner.process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var card: Rect2 = main.get_node("HUD/ResultPanel/Center/Card").get_global_rect()
		var outcome: Label = main.get_node(OUTCOME)
		var status: Label = main.get_node("HUD/ResultPanel/Center/Card/Box/Status")
		var again: Rect2 = main.get_node(PLAY_AGAIN).get_global_rect()
		var setup: Rect2 = main.get_node(CHANGE_SETUP).get_global_rect()
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "R1 the viewport really is %s" % size)
		runner.check(panel.visible and outcome.text == "Victory" and status.visible and status.text == "Your friend wants to play again", "R1 realistic texts shown at %s" % size)
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
		runner.check(is_equal_approx(main.get_node("HUD/ResultPanel/Center/Card").size.y, tall), "R1 the card keeps its height without a status line at %s (user, 2026-11-15)" % size)
		panel.show_result("Victory", "Waiting for your friend…", false)
		await runner.process_frame
		var waiting: StyleBox = main.get_node("HUD/ResultPanel/Center/Card/Box/Buttons/PlayAgain").get_theme_stylebox("disabled")
		runner.check(waiting is StyleBoxFlat and (waiting as StyleBoxFlat).bg_color.is_equal_approx(Color("#666a6c")), "R1 a waiting Play again is grey, not amber, at %s" % size)
		port.queue_free()
	return true

func test_result_panel_keys(runner) -> bool:
	for code in [KEY_ENTER, KEY_KP_ENTER]:
		var main = await _setup(runner)
		_arena(main)
		_victory(main)
		runner.check(main.get_node("HUD/ResultPanel").visible, "R2 fixture: the panel is up")
		var arena_sim = main.driver.sim
		main._input(_enter(code))
		runner.check(not is_same(main.driver.sim, arena_sim) and not main.get_node("HUD/ResultPanel").visible, "R2 key %s restarts" % code)
		main.free()
	var main = await _setup(runner)
	_arena(main)
	_victory(main)
	var kept = main.driver.sim
	main._pause.open()
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.sim, kept) and main.get_node("HUD/ResultPanel").visible, "R2 Enter with the pause menu open does nothing")
	main._pause.close()
	main._playtest._form.show()
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.sim, kept) and main._playtest._form.visible, "R2 Enter with the playtest form open keeps the match and the form")
	main._playtest._form.hide()
	main._input(_enter(KEY_ESCAPE))
	runner.check(main._pause.visible and is_same(main.driver.sim, kept), "R2 Esc with the panel up opens the pause menu")
	main.free()
	var live = await _setup(runner)
	var live_sim = live.driver.sim
	live._input(_enter(KEY_ENTER))
	runner.check(is_same(live.driver.sim, live_sim), "R2 Enter during a running match does nothing")
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
	var sim_before = main.driver.sim
	var field := LineEdit.new()
	main.get_node("HUD").add_child(field)
	field.grab_focus()
	runner.check(main.get_viewport().gui_get_focus_owner() == field, "R6 fixture: the text field has focus")
	main.get_viewport().push_input(InputEventMouseMotion.new())
	runner.check(not main.get_viewport().is_input_handled(), "R6 fixture: flag clear")
	main._input(_enter(KEY_ENTER))
	runner.check(is_same(main.driver.sim, sim_before) and main.get_node("HUD/ResultPanel").visible, "R6 Enter in a text field does not restart")
	runner.check(not main.get_viewport().is_input_handled(), "R6 the Enter event is not swallowed")
	field.release_focus()
	field.queue_free()
	main._input(_enter(KEY_ENTER))
	runner.check(not is_same(main.driver.sim, sim_before), "R6 Enter without text focus restarts")
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
	online.sim = real.sim
	main.driver = online
	main.hud._refresh_hud(real.sim.view_state())
	var status: Label = main.get_node("HUD/ResultPanel/Center/Card/Box/Status")
	runner.check(main.get_node(PLAY_AGAIN).disabled and status.text == "Your friend left", "R5 the panel shows the driver's line and can_play_again")
	main._play_again()
	runner.check(online.plays == 1, "R5 a driver that cannot restart gets play_again, got %d" % online.plays)
	var offline := StubDriver.new(true)
	main.driver = offline
	main._play_again()
	runner.check(offline.plays == 0 and offline.sim != null and offline.started == 1, "R5 a restartable driver restarts, starts once and never gets play_again, started %d" % offline.started)
	main.driver = real
	main.free()
	return true

func test_silent_keys_explain(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var ids: Dictionary = _arena(main)
	main.orders.selected_ids.assign([ids.infantry])
	var before: Dictionary = main.driver.sim.snapshot()
	helper.key(main, KEY_1)
	runner.check(main.orders._placement_kind.is_empty() and main.driver.sim.snapshot() == before and main.hud.note == "Choose one builder", "P4 build key without a builder says why, got '%s'" % main.hud.note)
	main.hud.note = ""
	main.orders.selected_ids.clear()
	helper.key(main, KEY_E)
	runner.check(main.driver.sim.snapshot() == before and main.hud.note == "Select a production building", "P4 E without a building says why, got '%s'" % main.hud.note)
	main.free()
	return true

func _hud_texts(main) -> Array[String]:
	var texts: Array[String] = [main.get_node("HUD/Status").text, main.get_node("HUD/Economy/Produce").text, main.get_node("HUD/Economy/CancelBuild").text]
	for group: String in ["BuildMenu", "Queue"]:
		for button in main.get_node("HUD/Economy/" + group).get_children(): texts.append(button.text)
	return texts

func test_hud_strings_use_display_names(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.sim = sim
	main.orders.selected_building_id = barracks
	BaseScene.sync_sequence(main)
	main._refresh()
	main.orders._produce_selected()
	main.orders._produce_selected()
	main._physics_process(0.0)
	await runner.process_frame
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "N1 produce button names the unit, got " + main.get_node("HUD/Economy/Produce").text)
	runner.check(main.get_node("HUD/Economy/Queue").get_child_count() == 2, "N1 fixture: two queue entries")
	var shown: Array[String] = _hud_texts(main)
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1 and unit.kind == "usa_builder")[0].id
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([builder])
	main.orders._enter_placement("usa_power_plant")
	runner.check(main.get_node("HUD/Status").text.contains("Place: Power Plant"), "N1 placement line names the building")
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
	var barracks: int = Fixture.build(runner, main.driver.sim, "usa_barracks", Vector2i(12, 12))
	main.orders.selected_building_id = barracks
	main.orders._produce_selected()
	main._physics_process(0.0)
	await runner.process_frame
	var controls: Array = [main.get_node("HUD/Status"), main.get_node("HUD/Economy/Produce"), main.get_node("HUD/Economy/CancelBuild")]
	controls.append_array(main.get_node("HUD/Economy/BuildMenu").get_children())
	controls.append_array(main.get_node("HUD/Economy/Queue").get_children())
	runner.check(controls.size() >= 4, "FS1 fixture: status, buttons and a queue entry")
	for control in controls: runner.check(control.get_theme_font_size("font_size") == UiStyle.FONT_SIZE, "FS1 %s uses the shared HUD size" % control.name)
	runner.check(UiStyle.FONT_SIZE < 16, "FS1 HUD text is smaller than the engine default")
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
	main.driver.sim = sim
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = defence
	main._refresh()
	helper.pointer(main, Iso.world_to_plane(Vector2(15.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "defence_attack")
	runner.check(orders.size() == 1 and orders[0].building_id == defence and orders[0].target_id == enemy and main.hud.note.is_empty(), "DA5 right-click on an enemy in reach submits defence_attack")
	helper.pointer(main, Iso.world_to_plane(Vector2(30.5, 30.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	runner.check(main.hud.note == "Target out of range" and sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "defence_attack").size() == 1, "DA5 out of reach shows Target out of range, got " + main.hud.note + " " + str(distant))
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
	main.driver.sim = sim
	main.orders.selected_ids.assign([rifle])
	main._refresh()
	var orders = func(type: String) -> Array: return sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == type)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var enters: Array = orders.call("enter")
	runner.check(enters.size() == 1 and enters[0].entity_ids == [rifle] and enters[0].target_id == hub and main.hud.note.is_empty(), "TU1 right-click on an own hub submits enter")
	helper.pointer(main, Iso.world_to_plane(Vector2(20.5, 10.5)) + Vector2(0, -8), MOUSE_BUTTON_RIGHT, true)
	var attacks: Array = orders.call("attack")
	runner.check(attacks.size() == 1 and attacks[0].target_id == enemy_hub and orders.call("enter").size() == 1, "TU1 right-click on an enemy hub still attacks")
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = hub
	main._refresh()
	helper.key(main, KEY_U)
	var unloads: Array = orders.call("unload")
	runner.check(unloads.size() == 1 and unloads[0].target_id == hub, "TU1 U with the hub selected submits unload")
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([rifle])
	main._refresh()
	helper.key(main, KEY_U)
	runner.check(orders.call("unload").size() == 1 and main.hud.note == "Select a container", "TU1 U without a container says why, got '%s'" % main.hud.note)
	var hub_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8)
	sim._entities[rifle].container_id = hub
	sim._entities[rifle].position = [10.5, 10.5]
	main._refresh()
	runner.check(main._view.pick_object(hub_point) == hub, "TU1 clicking an occupied hub picks the hub, not an occupant")
	var status: Label = main.get_node("HUD/Status")
	runner.check(Rect2(status.global_position, status.get_minimum_size()).end.x <= main.get_viewport().get_visible_rect().size.x, "TU1 the hint line keeps the status inside the viewport")
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
		main.driver.sim = sim
		main.orders.selected_ids.assign([unit])
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(Vector2(21.5, 9.5)), MOUSE_BUTTON_RIGHT, true)
		var orders: Array = sim.snapshot().pending_commands
		runner.check(orders.size() == 1 and orders[0].type == "gather" and orders[0].source_id == pile and orders[0].entity_ids == [unit], "K10 right-click on a pile sends %s to gather" % kind)
		main.free()
	return true

func test_right_click_pile_in_launcher_flow(runner) -> bool:
	var helper = BaseScene.new()
	for faction in ["frc", "china", "usa"]:
		var main = await _setup(runner)
		var sim = Skirmish.create(true, "ai", {1: faction, 2: "usa"})
		main.driver.sim = sim
		var pile: Dictionary = sim.snapshot().sources[0]
		var collector: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), faction + ("_builder" if faction == "frc" else "_collector"))
		var centre := Vector2(pile.origin[0] + 2.0, pile.origin[1] + 2.5)
		main.orders.selected_ids.assign([collector])
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(centre), MOUSE_BUTTON_RIGHT, true)
		runner.check(_pending(main, "gather") == 1, "K11 %s collector right-click on the pile gathers, pending %s" % [faction, str(sim.snapshot().pending_commands)])
		var bystander: int = sim.spawn(1, centre, "usa_collector")
		var gathers: int = _pending(main, "gather")
		main._refresh()
		helper.pointer(main, Iso.world_to_plane(centre) + Vector2(0, -26), MOUSE_BUTTON_RIGHT, true)
		runner.check(_pending(main, "gather") == gathers + 1 and bystander > 0, "K12 %s right-click on a pile with an own helicopter hovering over it still gathers, pending %s err %s" % [faction, str(sim.snapshot().pending_commands.map(func(c: Dictionary) -> String: return c.type)), main.hud.note])
		main.free()
	return true

func test_frc_laborer_right_click_pile(runner) -> bool:
	var helper = BaseScene.new()
	var main = await _setup(runner)
	var sim = Skirmish.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.sim = sim
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
	helper.sync_sequence(main)
	main._refresh()
	helper.pointer(main, click, MOUSE_BUTTON_RIGHT, true)
	var orders: Array = sim.snapshot().pending_commands.filter(func(c: Dictionary) -> bool: return c.type == "gather")
	runner.check(orders.size() == 1 and orders[0].entity_ids == laborers and orders[0].source_id == pile.id, "K13 several laborers, one of them building, right-click the pile gathers, got %s err %s" % [str(sim.snapshot().pending_commands), main.hud.note])
	Fixture.steps(sim, 3)
	runner.check(sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.id in laborers and u.collection.enabled).size() == laborers.size(), "K13 every laborer, including the builder, starts collecting")
	main.orders.selected_ids.assign([laborers[0]])
	main._refresh()
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
	main.driver.sim = sim
	main.orders.selected_building_id = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	Profiler.reset()
	Profiler.enabled = true
	main._refresh()
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 1, "RF2 a skirmish refresh with a production building selected takes no snapshot and one view state, got %d and %d" % [snapshots, views])
	runner.check(main.get_node("HUD/Economy/Produce").text == "Produce Rifleman (E)", "RF2 produce label unchanged")
	main.free()
	return true

func test_refresh_waits_for_next_frame(runner) -> bool:
	var main = await _setup(runner)
	main.set_process(true)
	await runner.process_frame
	main._physics_process(0.0)
	runner.check(main.driver.sim.tick() == 1 and main._view._state.tick == 0, "RF3 a step does not refresh in its own frame")
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
	main._physics_process(0.0)
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

const HUD_TEXTS: Array[String] = ["Rifleman #49 HP 156/180 | attack -> #31\n", "Supply Helicopter #45 HP 300/300 | waiting_source (3rd in line)\n", "Supply Helicopter #11 HP 300/300 | lead_source\n", "Bulldozer #1 HP 250/250\n", "Enemy (P2) Rifleman #19 HP 180/180 | guard\n", "Enemy (P2) Headquarters #4 HP 5000/5000\n"]

func _ids_where(units: Array, test: Callable) -> Array[int]:
	var ids: Array[int] = []
	for unit: Dictionary in units:
		if test.call(unit): ids.append(unit.id)
	return ids

func test_hud_summaries_are_pinned(runner) -> bool:
	var main = await _setup(runner)
	var sim = ViewRows.skirmish_sim()
	main.driver.sim = sim
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
	for id: int in [firing[0], waiting[-1], working[0], plain[0]]:
		main.orders.selected_ids.assign([id])
		texts.append(main.hud._selected_summary(view))
	main.orders.selected_ids.clear()
	for id: int in [enemy_unit[0], enemy_building[0]]:
		main.orders.inspected_id = id
		texts.append(main.hud._enemy_summary(view))
	runner.check(texts == HUD_TEXTS, "HUD1 pinned summary texts, got " + str(texts))
	main.free()
	return true

func _ic_row(main, step: int, seen: Array, status: bool = false) -> String:
	var pending: Array = main.driver.sim.snapshot().pending_commands
	var added: PackedStringArray = []
	for command: Dictionary in pending.slice(mini(seen[0], pending.size())): added.append(JSON.stringify(command))
	seen[0] = pending.size()
	var row: String = "%d|sel=%s|bld=%d|insp=%d|place=%s|pend=%s|am=%s|esc=%s|menu=%s|perf=%s|%s" % [step, main.orders.selected_ids, main.orders.selected_building_id, main.orders.inspected_id, main.orders._placement_kind, main.orders._pending_placement, main.orders._attack_move_mode, main._escape_pending(), main.menu_open(), main._perf.visible, ";".join(added)]
	return row + "|" + main.get_node("HUD/Status").text if status else row

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
	main.driver.sim = sim
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
	helper.key(main, KEY_U)
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
	main._physics_process(0.0)
	rows.append(_ic_row(main, 21, seen) + "|tick=%d" % main.driver.sim.tick())
	var first: int = _ic_first_difference(rows, IcRows.IC1_ROWS)
	runner.check(first == -1, "IC1 row %d matches the chain recorded 2026-11-14, got %s" % [first, rows[first] if first >= 0 and first < rows.size() else "no row"])
	main.free()
	return true

func test_offline_driver_stamps_like_the_scene(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.sim = Skirmish.create(false)
	var unit: int = driver.sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	driver.sim.start_match([1, 2] as Array[int])
	var tick: int = driver.sim.snapshot().tick
	var first: Dictionary = driver.submit({"type": "stop", "entity_ids": [unit]})
	var refused: Dictionary = driver.submit({"type": "attack", "entity_ids": [unit], "target_id": 999999})
	var second: Dictionary = driver.submit({"type": "stop", "entity_ids": [unit]})
	var queued: Array = driver.sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "stop")
	var stamps: Array = queued.map(func(command: Dictionary) -> Array: return [command.tick, command.player, command.sequence])
	runner.check(first.ok and not refused.ok and second.ok and stamps == [[tick, 1, 0], [tick, 1, 1]] and driver.recorder.commands().size() == 2, "OD1 offline driver stamps tick, player and sequence like main._submit")
	return true

func test_sb1_idle_offline_ticks_take_no_snapshot(runner) -> bool:
	var main = await _setup(runner)
	main.driver.sim = Skirmish.create()
	main._refresh()
	Profiler.reset()
	Profiler.enabled = true
	for i in 300: main._physics_process(0.0)
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 300, "RB7 300 idle offline ticks take no snapshot and one view state each, got %d and %d" % [snapshots, views])
	main.free()
	return true

func test_offline_driver_bot_memory_on_simulation(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.sim = Skirmish.create()
	while driver.sim.tick() < Skirmish.next_decision(Skirmish.ATTACK_TICK, 2): driver.sim.step()
	driver.step(func() -> void: pass)
	runner.check(driver.sim.has_meta(Skirmish.BOT_META) and not driver.has_meta(Skirmish.BOT_META), "OD2 bot memory lives on the simulation, not the driver")
	return true

func test_sb1_submit_takes_no_snapshot(runner) -> bool:
	var driver = OfflineDriver.new(1)
	driver.sim = Skirmish.create(false)
	var unit: int = driver.sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	driver.sim.start_match([1, 2] as Array[int])
	var tick: int = driver.sim.tick()
	Profiler.reset()
	Profiler.enabled = true
	driver.submit({"type": "stop", "entity_ids": [unit]})
	driver.submit({"type": "attack", "entity_ids": [unit], "target_id": 999999})
	driver.submit({"type": "stop", "entity_ids": [unit]})
	var snapshots: int = Profiler.calls(&"snapshot")
	Profiler.enabled = false
	Profiler.reset()
	var queued: Array = driver.sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "stop")
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
	var moves: Array = main.driver.sim.snapshot().pending_commands.filter(func(command: Dictionary) -> bool: return command.type == "move")
	var payload_ok: bool = moves.size() == before + 1 and moves[-1].entity_ids == orders.selected_ids and Vector2(moves[-1].target[0], moves[-1].target[1]).distance_to(ground) <= 1e-3
	runner.check(orders.selected_ids == [ids.infantry, ids.tank] and payload_ok, "OR1 orders own the selection and emit the move payload")
	main.free()
	return true

func test_hud_reads_only_state_and_orders(runner) -> bool:
	var main = await _setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.sim = sim
	main.orders.selected_building_id = barracks
	var produce: Button = main.get_node("HUD/Economy/Produce")
	produce.hide()
	var hud = Hud.new(main.get_node("HUD"), main)
	hud.note = "Choose one builder"
	main.stepped_results.append({"ok": false, "error": "Not yours", "player": 2, "tick": 5, "sequence": 0})
	hud._refresh_hud(sim.view_state())
	var status: String = main.get_node("HUD/Status").text
	runner.check(produce.visible and status.contains("%s #%d" % [Registry.kind("usa_barracks").display_name, barracks]) and hud.note == "Choose one builder" and status.contains("Choose one builder"), "HU1 the HUD shows the selection and keeps the local note")
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
	main.driver.sim = sim
	helper.sync_sequence(main)
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
	helper.key(main, KEY_U)
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
	main.driver.sim.remove_object(ids.infantry)
	runner.check(main.orders._matching_ids(ids.infantry, true).has(ids.infantry), "RB4 the shown view still picks the unit")
	var double := InputEventMouseButton.new()
	double.position = main.get_node("WorldView").get_global_transform_with_canvas() * (Iso.world_to_plane(Vector2(10.5, 10.5)) + Vector2(0, -8))
	double.button_index = MOUSE_BUTTON_LEFT
	double.double_click = true
	double.pressed = true
	main._unhandled_input(double)
	double.pressed = false
	main._unhandled_input(double)
	main._refresh()
	runner.check(not main.orders.selected_ids.has(ids.infantry), "RB4 pick of a unit dead since the shown view does not error")
	main.orders.selected_ids.assign([ids.infantry])
	helper.key(main, KEY_S)
	main._physics_process(0.0)
	runner.check(main.hud.note.contains("Missing entity or wrong owner"), "RB4 the simulation refuses it, got '%s'" % main.hud.note)
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
	main.driver.sim = first
	main._refresh()
	main.driver.sim = second
	runner.check(main.hud._result_text({"status": "won", "winner": 7}) == "Defeat", "RB6 the result reads the shown team")
	main._refresh()
	runner.check(main.hud._result_text({"status": "won", "winner": 7}) == "Victory", "RB6 a refresh shows the new team")
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
