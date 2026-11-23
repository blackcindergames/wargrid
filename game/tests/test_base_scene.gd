@warning_ignore_start("untyped_declaration")
extends RefCounted

const Base = preload("res://scenes/skirmish.tscn")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
# [window, logical]: what the match's stretch caps lay each window out at
const HUD_SIZES: Array[Array] = [[Vector2i(1280, 720), Vector2i(1280, 720)], [Vector2i(1280, 800), Vector2i(1280, 800)], [Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(3440, 1440), Vector2i(1720, 720)]]

const HUD_PANELS: Array[String] = ["HUD/Economy", "HUD/Hud/TopStrip", "HUD/MenuChip", "HUD/Hud/Notice", "HUD/Hud/RefusalLine", "HUD/Hud/GroupLine", "HUD/Hud/AlertLine", "HUD/Hud/SelectionPanel"]

# The no-overlap lists: each shown HUD panel by path, sized as the layout tests always read them.
static func hud_panels(main) -> Dictionary:
	var rects: Dictionary = {}
	for path: String in HUD_PANELS:
		var control: Control = main.get_node(path)
		if control.is_visible_in_tree(): rects[path] = Rect2(control.global_position, control.get_combined_minimum_size())
	return rects

# The no-overlap lists hold the selection panel only while something is selected.
static func select_own_unit(main) -> void:
	for unit: Dictionary in main.driver.pump.live().snapshot().entities:
		if unit.owner == main.local_player:
			main.orders.selected_ids.assign([unit.id])
			break
	main._refresh()

# The slab replaced "below the status": inside the view and clear of the strip (P2.3a1 Task 9).
static func slab_clear(runner, main, label: String) -> void:
	var slab: Rect2 = main.get_node("HUD/Economy").get_global_rect()
	var strip: Rect2 = main.get_node("HUD/Hud/TopStrip").get_global_rect()
	runner.check(main.get_viewport().get_visible_rect().encloses(slab) and not slab.intersects(strip), "%s: the slab inside the view and clear of the strip, slab %s strip %s" % [label, slab, strip])

static func sized_port(runner, window: Vector2i, logical: Vector2i) -> SubViewport:
	var port := SubViewport.new()
	port.size = window
	port.size_2d_override = logical
	port.size_2d_override_stretch = true
	runner.root.add_child(port)
	return port

func cases() -> Array[Callable]:
	return [test_base_ready,test_placement_input,test_production_ui,test_context_orders,test_execution_feedback,test_sb2_preview_cost,test_sb2_ghost_colour_after_step,test_sb2_red_ghost_click_refused_locally,test_sb2_red_answer_elsewhere_does_not_block,test_sb2_restart_drops_pending_preview,test_sb2_reenter_placement_ignores_old_answer,test_sb2_preview_waits_for_unpause,test_resume_status,test_queue_label,test_one_snapshot_per_refresh,test_ticks_take_no_snapshot,test_refresh_waits_for_next_frame,test_rejection_survives_two_steps,test_sb1_repaint_keeps_step_pending,test_sb2_placement_waits_for_build_answer,test_f23_placement_closes_when_builder_dies,test_f23_builder_dies_in_the_click_step,test_f23_builder_lost_after_an_earlier_refusal,test_ghost_funds_refusal_clicks_each_time,test_f33_red_ghost_refused_after_a_two_step_frame,test_preview_once_per_physics_step,test_build_menu_from_capabilities,test_build_menu_wraps_eleven,test_build_menu_quantity_label]

func _m3_world() -> Simulation:
	var sim: Simulation = Fixture.make_world()
	sim.add_supply_source(Vector2i(24, 4), 200)
	return sim

func install_world(main) -> void:
	main.driver.adopt(_m3_world())
	main._reset_camera()
	main._refresh()

func setup(runner):
	var main = Base.instantiate()
	runner.root.add_child(main)
	install_world(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

# Never `_process`: it pans, draws and auto-picks quality.
static func tick(main) -> void:
	main._physics_process(1.0 / 30.0)
	main._drain_notes()

static func hud_text(main: Node) -> String:
	var lines: PackedStringArray = []
	for label: Node in main.get_node("HUD").find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).modulate.a > 0.0: lines.append((label as Label).text)
	return "\n".join(lines)

# Shows a direct change to the live sim as a tick would, without stepping, sound or step results.
static func publish(main) -> void:
	var job := SimPump.Job.new()
	job.step = false
	main.driver.pump.post(job)
	main.driver.drain()
	main._refresh()

func key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	main._unhandled_input(event)

# Arms `kind` for the selected builder by key: Build first unless its sub-grid is open.
func build_key(main, kind: String) -> void:
	if not main.orders._sub_grid: key(main, HudModel.BUILD_KEY)
	key(main, HudModel.CELL_KEYS[HudModel.role(kind)])

func produce_key(main, kind: String) -> void:
	key(main, HudModel.CELL_KEYS[HudModel.role(kind)])

func pointer(main, plane: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	event.button_index = button
	event.pressed = pressed
	main._unhandled_input(event)

# Right-button actions fire on release (P17).
func right_click(main, plane: Vector2) -> void:
	pointer(main, plane, MOUSE_BUTTON_RIGHT, true)
	pointer(main, plane, MOUSE_BUTTON_RIGHT, false)

func hover(main, plane: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = main.get_node("WorldView").get_global_transform_with_canvas() * plane
	main._unhandled_input(event)

func test_base_ready(runner) -> bool:
	var main = await setup(runner)
	var state: Dictionary = main.driver.pump.live().snapshot()
	runner.check(state.map.size == [32,32] and state.entities.size() == 1 and state.entities[0].kind == "usa_builder" and state.entities[0].position == [4.5,4.5],"Bs1 authored builder map")
	runner.check(state.players.size() == 1 and state.players[0].credits == 10000 and state.sources.size() == 1 and state.sources[0].origin == [24,4] and state.sources[0].boxes == 200 and state.buildings.is_empty(),"Bs1 authored economy")
	tick(main)
	runner.check(main.driver.pump.live().snapshot().tick == state.tick + 1,"Bs1 one physics tick")
	key(main,KEY_B)
	runner.check(main.driver.pump.live().snapshot().terrain_cells.is_empty(),"Bs1 B cannot toggle terrain")
	runner.check(hud_text(main).contains("CREDITS") and main.get_node("HUD/Hud/TopStrip").find_child("Credits", true, false).text == str(main.shown_state.players[0].credits),"Bs1 economy HUD shows the player's credits")
	main.free()
	return true

func test_placement_input(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	var camera: Camera2D = main.get_node("Camera2D")
	var before: Dictionary = main.driver.pump.live().snapshot()
	for center in [Vector2(0,256),Vector2(80,320)]:
		for zoom in [.5,1.0,2.0]:
			camera.position = center
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			await runner.process_frame
			build_key(main,"usa_power_plant")
			hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
			runner.check(main.orders._placement_kind == "usa_power_plant" and main.get_node("WorldView")._preview_cells == [Vector2i(8,4),Vector2i(9,4),Vector2i(8,5),Vector2i(9,5)],"Bs2 transformed snapped preview")
			var position: Vector2 = camera.position
			main.pan_camera(Vector2.RIGHT,1.0)
			main.change_zoom(1)
			runner.check(camera.position != position and camera.zoom.x == zoom,"Bs2 placement pans the camera and holds the zoom")
			key(main,KEY_ESCAPE)
			runner.check(main.orders.selected_ids == [1] and main.orders._placement_kind.is_empty() and main.driver.pump.live().snapshot() == before and main.driver.queued().is_empty(),"Bs2 cancel no order spend preserves selection")
	build_key(main,"usa_power_plant")
	hover(main,Iso.world_to_plane(Vector2(4.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(4.25,4.25)),MOUSE_BUTTON_LEFT,false)
	tick(main)
	var refused: Dictionary = main.driver.pump.live().snapshot()
	var credits = func(state: Dictionary) -> Array: return state.players.map(func(player: Dictionary) -> int: return player.credits)
	runner.check(not main.orders._placement_kind.is_empty() and credits.call(refused) == credits.call(before) and refused.buildings == before.buildings and refused.pending_commands == before.pending_commands and not main.hud.refusal.is_empty(),"Bs2 invalid remains mode reason")
	runner.check(refused.tick == before.tick + 1,"Bs2 the refusal arrives with one step")
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,true)
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	main.driver.flush()
	var state: Dictionary = main.driver.pump.live().snapshot()
	runner.check(not main.orders._placement_kind.is_empty() and state.pending_commands.size() == 1,"Bs2 release exactly one build")
	if not state.pending_commands.is_empty(): runner.check(state.pending_commands[0].type == "build" and state.pending_commands[0].origin == [8,4] and state.pending_commands[0].builder_id == 1 and state.pending_commands[0].sequence == 0,"Bs2 envelope")
	tick(main)
	runner.check(main.orders._placement_kind.is_empty(),"Bs2 placement ends with the build's answer")
	# The Supply Depot cell needs a completed Power Plant, else it is blocked and arms nothing.
	Fixture.add_completed(main.driver.pump.live(),1,"usa_power_plant",Vector2i(20,20))
	publish(main)
	var queued: Dictionary = main.driver.pump.live().snapshot()
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,true)
	build_key(main,"usa_supply_center")
	runner.check(main.orders.is_selecting() and main.orders._placement_kind.is_empty(),"Bs2 placement key waits for gesture")
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,false)
	runner.check(not main.orders.is_selecting() and main.orders._placement_kind.is_empty(),"Bs2 a card key during a drag presses nothing")
	build_key(main,"usa_supply_center")
	runner.check(main.orders._placement_kind == "usa_supply_center","Bs2 the key after the selection arms the building")
	right_click(main, Iso.world_to_plane(Vector2(10,10)))
	runner.check(main.orders._placement_kind.is_empty() and main.orders.selected_ids == [1] and main.driver.pump.live().snapshot() == queued and main.driver.queued().is_empty(),"Bs2 right cancel preserves state")
	main.free()
	return true

func test_production_ui(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(50000))
	Fixture.build(runner,main.driver.pump.live(),"usa_power_plant",Vector2i(5,5))
	var depot: int = Fixture.build(runner,main.driver.pump.live(),"usa_supply_center",Vector2i(10,4))
	publish(main)
	pointer(main,Iso.world_to_plane(Vector2(11.5,5.5)),MOUSE_BUTTON_LEFT,true)
	pointer(main,Iso.world_to_plane(Vector2(11.5,5.5)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.orders.selected_building_id == depot and main.orders.selected_ids.is_empty() and main.get_node("WorldView")._selection.keys() == [depot],"Bs3 building selection outline")
	main.orders.selected_building_id = depot
	main._refresh()
	main.get_node("HUD/Economy/Card/Q").pressed.emit()
	produce_key(main,"usa_collector")
	runner.check(main.driver.queued().size() == 2,"Bs3 one command per produce")
	tick(main)
	var queue: Array = Fixture.object(main.driver.pump.live(),depot).queue
	if queue.size() == 2:
		await runner.process_frame
		var button: Control = queue_tile(main, queue[1].id)
		var viewport_point: Vector2 = button.get_global_rect().get_center() if button != null else Vector2.ZERO
		var press := InputEventMouseButton.new()
		press.position = runner.root.get_final_transform() * viewport_point
		press.global_position = press.position
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		Input.parse_input_event(press)
		await runner.process_frame
		tick(main)
		var release := InputEventMouseButton.new()
		release.position = press.position
		release.global_position = press.position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		await runner.process_frame
		var commands: Array = main.driver.queued()
		runner.check(commands.size() == 1 and commands[0].type == "cancel_production" and commands[0].production_id == queue[1].id,"Bs3 real GUI release after tick cancels exact entry once")
		tick(main)
		runner.check(Fixture.object(main.driver.pump.live(),depot).queue.size() == 1 and Fixture.object(main.driver.pump.live(),depot).queue[0].id == queue[0].id,"Bs3 stable cancel entry ID")
	else: runner.check(false,"Bs3 queue populated")
	runner.check(main.has_node("HUD/Economy/CancelBuild") and main.get_node("HUD/Economy/CancelBuild").mouse_filter == Control.MOUSE_FILTER_STOP,"Bs3 GUI consumes mouse")
	main.driver.pump.live().remove_object(depot)
	publish(main)
	runner.check(main.orders.selected_building_id == -1,"Bs3 removed selection cleared")
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,12]})
	tick(main)
	var foundation: int = main.driver.pump.live().snapshot().buildings.back().id
	main.orders.selected_building_id = foundation
	main._refresh()
	var credits: int = main.driver.pump.live().snapshot().players[0].credits
	main.get_node("HUD/Economy/CancelBuild").pressed.emit()
	runner.check(main.driver.queued().size() == 1 and main.driver.queued()[0].type == "cancel_build","Bs3 CancelBuild signal submits exactly once")
	tick(main)
	runner.check(Fixture.object(main.driver.pump.live(),foundation).is_empty() and main.driver.pump.live().snapshot().players[0].credits == credits + 800 and main.orders.selected_building_id == -1,"Bs3 CancelBuild refunds selected foundation")
	main.free()
	return true

func test_context_orders(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	var source: int = main.driver.pump.live().add_supply_source(Vector2i(24,4),8)
	var air: int = main.driver.pump.live().spawn(1,Vector2(2.5,2.5),"usa_collector")
	main.orders.selected_ids.assign([air])
	publish(main)
	right_click(main, Iso.world_to_plane(Vector2(25.5,5.5)))
	var pending: Array = main.driver.queued()
	runner.check(pending.size() == 1 and pending[0].type == "gather" and pending[0].source_id == source,"Bs4 collector context gather")
	main.orders.selected_ids.assign([1,air])
	var before: Dictionary = main.driver.pump.live().snapshot()
	right_click(main, Iso.world_to_plane(Vector2(25.5,5.5)))
	runner.check(main.driver.pump.live().snapshot() == before and main.driver.queued().size() == 1 and not main.hud.refusal.is_empty(),"Bs4 mixed context rejected")
	right_click(main, Iso.world_to_plane(Vector2(6.5,10.5)))
	runner.check(main.driver.queued().size() == 2 and main.driver.queued().back().type == "move","Bs4 mixed ordinary ground move")
	main.driver.adopt(Fixture.make_world())
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	main.driver.pump.live().step()
	Fixture.send(main.driver.pump.live(),{"type":"stop","entity_ids":[1]})
	main.driver.pump.live().step()
	main.orders.selected_ids.assign([1])
	publish(main)
	right_click(main, Iso.world_to_plane(Vector2(8.5,4.5)))
	var resumed: Array = main.driver.queued()
	runner.check(resumed.size() == 1 and resumed[0].type == "resume_build" and resumed[0].builder_id == 1 and resumed[0].building_id == 2,"Bs4 builder context resumes foundation")
	pointer(main,Iso.world_to_plane(Vector2(4.5,4.5)) + Vector2(0,-8),MOUSE_BUTTON_LEFT,true)
	var selecting: Dictionary = main.driver.pump.live().snapshot()
	right_click(main, Iso.world_to_plane(Vector2(8.5,4.5)))
	runner.check(main.orders.is_selecting() and main.driver.pump.live().snapshot() == selecting and main.driver.queued().size() == 1,"Bs4 context suppressed during active selection")
	key(main,KEY_ESCAPE)
	main.free()
	return true

func test_execution_feedback(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(800))
	main._submit({"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4],"tick":2})
	main._submit({"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[12,4],"tick":2})
	main.driver.flush()
	Fixture.steps(main.driver.pump.live(),3)
	publish(main)
	runner.check(hud_text(main).contains("Insufficient credits") and main.hud.refusal == "Insufficient credits","Bs5 due rejection visible")
	main._submit({"type":"stop","entity_ids":[999]})
	tick(main)
	var error: String = main.hud.refusal
	main._refresh()
	runner.check(not error.is_empty() and main.hud.refusal == error,"Bs5 immediate error persists refresh")
	main.driver.pump.live().add_player(2,0)
	var other: int = main.driver.pump.live().spawn(2,Vector2(2.5,2.5))
	Fixture.send(main.driver.pump.live(),{"type":"stop","entity_ids":[other],"player":2})
	tick(main)
	runner.check(main.hud.refusal == error,"Bs5 unrelated player result preserves immediate error")
	main._submit({"type":"stop","entity_ids":[1]})
	tick(main)
	runner.check(main.hud.refusal.is_empty() and not main.get_node("HUD/Hud/RefusalLine").visible,"Bs5 the accepted answer clears immediate error")
	main.free()
	return true

func _placing(runner) -> Variant:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	build_key(main,"usa_power_plant")
	return main

func test_sb2_preview_cost(runner) -> bool:
	var main = await _placing(runner)
	# navigation_builds counts only previews that need a full grid (construction.gd), so answers are counted by identity.
	var before: Dictionary = main.driver.preview_answer()
	for i in range(5): hover(main,Iso.world_to_plane(Vector2(8.25,4.25)) + Vector2(i * 0.1,0))
	runner.check(is_same(main.driver.preview_answer(),before),"Bs6 hovers without a step evaluate no preview")
	tick(main)
	var expected: bool = main.driver.pump.live().preview_build(1,1,"usa_power_plant",Vector2i(8,4)).ok
	runner.check(not is_same(main.driver.preview_answer(),before) and main.driver.preview_answer().kind == "usa_power_plant" and main.driver.preview_answer().origin == Vector2i(8,4) and main.driver.preview_answer().ok == expected,"Bs6 five hovers across one cell are answered once at the next step, got %s" % [main.driver.preview_answer()])
	before = main.driver.preview_answer()
	hover(main,Iso.world_to_plane(Vector2(12.25,4.25)))
	runner.check(main.get_node("WorldView")._preview_cells[0] == Vector2i(12,4) and is_same(main.driver.preview_answer(),before),"Bs6 a new cell moves the ghost at once without a preview")
	tick(main)
	runner.check(main.driver.preview_answer().get("origin") == Vector2i(12,4),"Bs6 a new cell is answered at the next step")
	key(main,KEY_ESCAPE)
	build_key(main,"usa_power_plant")
	runner.check(not main.get_node("WorldView")._preview_cells.is_empty(),"Bs6 re-entering placement redraws the preview")
	main.free()
	return true

func test_sb2_ghost_colour_after_step(runner) -> bool:
	var main = await _placing(runner)
	var view = main.get_node("WorldView")
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	runner.check(view._preview_cells[0] == Vector2i(8,4) and not view._preview_valid,"RP1 the ghost moves at once, refused before its first answer")
	tick(main)
	runner.check(view._preview_valid,"RP1 the free cell turns valid after the next step")
	hover(main,Iso.world_to_plane(Vector2(4.25,4.25)))
	runner.check(view._preview_cells[0] == Vector2i(4,4) and view._preview_valid,"RP1 the ghost moves at once in the last answer's colour")
	tick(main)
	runner.check(not view._preview_valid,"RP1 the builder's own cell turns refused after the next step")
	main.free()
	return true

func test_sb2_red_ghost_click_refused_locally(runner) -> bool:
	var main = await _placing(runner)
	var cell: Vector2 = Iso.world_to_plane(Vector2(4.25,4.25))
	hover(main,cell)
	tick(main)
	tick(main)
	pointer(main,cell,MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().is_empty() and main.orders._placement_kind == "usa_power_plant" and not main.hud.refusal.is_empty(),"RL1 a click on a red ghost sends nothing, says why and keeps placement, held %d note '%s'" % [main.driver.queued().size(), main.hud.refusal])
	tick(main)
	var errors: int = main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "error").size()
	runner.check(errors == 1,"RL1 the local refusal beeps once at the next step, got %d" % errors)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	tick(main)
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().size() == 1,"RL2 a click on a green ghost still sends, held %d" % main.driver.queued().size())
	main.free()
	return true

func test_sb2_red_answer_elsewhere_does_not_block(runner) -> bool:
	var main = await _placing(runner)
	hover(main,Iso.world_to_plane(Vector2(4.25,4.25)))
	tick(main)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().size() == 1,"RL3 a red answer for another cell does not block a click before the next step, held %d" % main.driver.queued().size())
	main.free()
	return true

func test_sb2_restart_drops_pending_preview(runner) -> bool:
	var main = await _placing(runner)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	main._restart()
	tick(main)
	runner.check(main.driver.preview_answer().is_empty() and main.get_node("WorldView")._preview_cells.is_empty(),"RP5 a restart drops the pending preview, got %s" % [main.driver.preview_answer()])
	main.free()
	return true

func test_sb2_reenter_placement_ignores_old_answer(runner) -> bool:
	var main = await _placing(runner)
	var view = main.get_node("WorldView")
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	tick(main)
	runner.check(view._preview_valid,"RP6 fixture: the first placement got a valid answer")
	key(main,KEY_ESCAPE)
	build_key(main,"usa_power_plant")
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	runner.check(not view._preview_valid and main.driver.preview_answer().is_empty(),"RP6 the old answer does not colour the new placement")
	tick(main)
	runner.check(view._preview_valid and main.driver.preview_answer().get("origin") == Vector2i(8,4),"RP6 only the new request is answered, got %s" % [main.driver.preview_answer()])
	main.free()
	return true

func test_sb2_preview_waits_for_unpause(runner) -> bool:
	var main = await _placing(runner)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	main._pause.open()
	for i in 3: tick(main)
	runner.check(main.driver.preview_answer().is_empty(),"RP7 a paused match answers no preview")
	main._pause.close()
	tick(main)
	runner.check(main.driver.preview_answer().get("origin") == Vector2i(8,4),"RP7 the preview is answered after unpause")
	main.free()
	return true

func test_resume_status(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]})
	main.driver.pump.live().step()
	Fixture.send(main.driver.pump.live(),{"type":"stop","entity_ids":[1]})
	main.driver.pump.live().step()
	main.orders.selected_ids.assign([1])
	publish(main)
	hover(main,Iso.world_to_plane(Vector2(8.5,4.5)))
	main._refresh()
	var hint: Label = main.get_node("HUD/Economy/ResumeHint")
	runner.check(hud_text(main).contains("Right-click: resume") and hint.is_visible_in_tree() and hint.text == "Right-click: resume","H6 resume hint shown in the slab while hovering")
	runner.check(hud_text(main).count("Right-click: resume") == 1,"H6 the resume hint shows once")
	slab_clear(runner,main,"H6")
	hover(main,Iso.world_to_plane(Vector2(20.5,20.5)))
	main._refresh()
	runner.check(not hud_text(main).contains("Right-click: resume") and not hint.is_visible_in_tree(),"H6 hint gone off the building")
	main.free()
	return true

const QUEUE_ROW: String = "HUD/Hud/SelectionPanel/Box/Body/Queue"

# The selected producer's shown queue tiles, left to right, `+N more` left out.
static func queue_tiles(main) -> Array:
	var row: Node = main.get_node_or_null(QUEUE_ROW)
	if row == null: return []
	return row.get_children().filter(func(tile: Node) -> bool: return str(tile.name).begins_with("Tile") and (tile as Control).is_visible_in_tree())

static func queue_tile(main, id: int) -> Control:
	for tile: Control in queue_tiles(main):
		if Array(tile.get_meta("ids", [])).has(id): return tile
	return null

static func shown_texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text)

# P2.3b T8: tiles carry no digits (3-3); the started entry's tile says NOW.
func test_queue_label(runner) -> bool:
	var main = await setup(runner)
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim,1,"usa_factory",Vector2i(12,12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = factory
	var view: Dictionary = main.driver.current().view
	HudModel.building(view,factory).queue = [{"id":10,"kind":"usa_tank","paid_cost":900,"work":270000},{"id":12,"kind":"usa_tank","paid_cost":900,"work":0}]
	main._show(view)
	await runner.process_frame
	var chip: String = HudModel.key_label(KEY_W)
	var started: Control = queue_tile(main,10)
	var waiting: Control = queue_tile(main,12)
	runner.check(started != null and shown_texts(started) == ["NOW",chip,"Battle Tank"],"Bs5 a started entry's tile shows NOW, its cell's key and its name, no percent, id or raw work, got %s" % [shown_texts(started) if started != null else []])
	runner.check(waiting != null and waiting != started and shown_texts(waiting) == [chip,"Battle Tank"],"Bs5 an unstarted entry's tile shows its key and name, no percent, got %s" % [shown_texts(waiting) if waiting != null else []])
	main.free()
	return true

func test_one_snapshot_per_refresh(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_building_id = 1
	Profiler.reset()
	Profiler.enabled = true
	main._refresh()
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 0, "RF1 a refresh takes no snapshot and no view state, got %d and %d" % [snapshots, views])
	main.free()
	return true

func test_ticks_take_no_snapshot(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	tick(main) # the bot's tick-0 decision takes one snapshot; RF6 counts the ticks between decisions
	Profiler.reset()
	Profiler.enabled = true
	for i in 10: tick(main)
	var snapshots: int = Profiler.calls(&"snapshot")
	var views: int = Profiler.calls(&"view_state")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(snapshots == 0 and views == 10, "RF6 ten ticks take no snapshot and ten view states, got %d and %d" % [snapshots, views])
	main.free()
	return true

func test_refresh_waits_for_next_frame(runner) -> bool:
	var main = await setup(runner)
	main.set_process(true)
	await runner.process_frame
	tick(main)
	runner.check(main.driver.pump.live().tick() == 1 and main._view._state.tick == 0,"RF5 a step does not refresh in its own frame")
	await runner.process_frame
	await runner.process_frame
	runner.check(main._view._state.tick == 1,"RF5 a later frame's _process refreshes")
	main.free()
	return true

func test_rejection_survives_two_steps(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(800))
	main.set_process(true)
	await runner.process_frame
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4],"tick":0})
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[12,4],"tick":0})
	tick(main)
	tick(main)
	await runner.process_frame
	await runner.process_frame
	runner.check(hud_text(main).contains("Insufficient credits"),"RF8 a rejection from the first of two steps reaches the HUD")
	main.free()
	return true

func test_sb1_repaint_keeps_step_pending(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(800))
	main.set_process(true)
	await runner.process_frame
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4],"tick":0})
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[12,4],"tick":0})
	tick(main)
	tick(main)
	var rows: RefCounted = main.shown_state.units
	var at: int = rows.index_of(1)
	hover(main,Iso.world_to_plane(Vector2(rows.x[at],rows.y[at])) + Vector2(0,-8))
	var director = main._sound.director
	runner.check(main._view.hovered_id() == 1,"RB5 fixture: the hover changed the hovered object")
	runner.check(main.stepped_results.size() > 0,"RB5 a repaint keeps the step's results unconsumed")
	runner.check(director.collected_ticks() == [1,2] and not director.consumed_ticks().has(1) and not director.consumed_ticks().has(2),"RB5 a repaint leaves the step's sound pending, got %s and %s" % [director.collected_ticks(),director.consumed_ticks()])
	await runner.process_frame
	await runner.process_frame
	runner.check(hud_text(main).contains("Insufficient credits"),"RB5 the rejection still reaches the HUD after a repaint")
	runner.check(director.consumed_ticks().count(1) == 1 and director.consumed_ticks().count(2) == 1,"RB5 each step's sound plays once, got %s" % [director.consumed_ticks()])
	runner.check(main._view._state.tick == main.driver.pump.live().tick(),"RB5 the deferred refresh shows the new tick")
	main.free()
	return true

# The card's item cells in lattice order, as "key cost name".
func _menu_texts(main) -> Array:
	return main.get_node("HUD/Economy/Card").get_children().filter(func(cell: Button) -> bool: return cell.is_visible_in_tree() and cell.get_node("Cost").visible).map(func(cell: Button) -> String: return "%s %s %s" % [cell.get_node("Chip").text, cell.get_node("Cost").text, cell.get_node("Name").text])

func test_f23_placement_closes_when_builder_dies(runner) -> bool:
	var main = await _placing(runner)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	tick(main)
	main.driver.pump.live().remove_object(1)
	publish(main)
	runner.check(main.orders._placement_kind.is_empty(),"F23 placement closes when its builder dies, still '%s'" % main.orders._placement_kind)
	runner.check(main.hud.refusal == "Builder lost","F23 the refusal after the builder dies reads Builder lost, got '%s'" % main.hud.refusal)
	hover(main,Iso.world_to_plane(Vector2(12.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(12.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().is_empty(),"F23 the click after the builder died queues nothing, held %d" % main.driver.queued().size())
	tick(main)
	runner.check(not hud_text(main).contains("Invalid builder_id") and main.driver.queued().is_empty(),"F23 no build for a dead builder is sent or refused, HUD '%s'" % main.hud.refusal)
	main.free()
	return true

func test_f23_builder_dies_in_the_click_step(runner) -> bool:
	var main = await _placing(runner)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	tick(main)
	tick(main)
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().size() == 1,"F23 fixture: the build click is queued, held %d" % main.driver.queued().size())
	main.driver.pump.live().remove_object(1)
	tick(main)
	runner.check(main.orders._placement_kind.is_empty(),"F23 placement closes after the refused build of a dead builder, still '%s' with '%s'" % [main.orders._placement_kind, main.hud.refusal])
	runner.check(main.hud.refusal == "Builder lost","F23 the refusal after a refused build of a dead builder reads Builder lost, got '%s'" % main.hud.refusal)
	var errors: int = main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "error").size()
	runner.check(errors == 1,"F23 one error cue for the refused build and the lost builder, got %d" % errors)
	main.free()
	return true

static func _errors(main) -> int:
	return main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "error").size()

func test_f23_builder_lost_after_an_earlier_refusal(runner) -> bool:
	var main = await _placing(runner)
	var red: Vector2 = Iso.world_to_plane(Vector2(4.25,4.25))
	hover(main,red)
	pointer(main,red,MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().size() == 1,"F23 fixture: the click on a not yet answered red spot is sent, held %d" % main.driver.queued().size())
	tick(main)
	runner.check(not main.hud.refusal.is_empty() and main.orders._placement_kind == "usa_power_plant" and _errors(main) == 1,"F23 fixture: the sim refuses it with one beep and placement stays, got '%s' '%s'" % [main.hud.refusal, main.orders._placement_kind])
	tick(main)
	main.driver.pump.live().remove_object(1)
	tick(main)
	runner.check(main.hud.refusal == "Builder lost" and _errors(main) == 1,"F23 a builder lost ticks after an earlier refusal still beeps once, got '%s' and %d" % [main.hud.refusal, _errors(main)])
	main.orders._awaiting_build = "usa_power_plant"
	main.orders.answered({"command":{"type":"build"},"ok":false,"error":"Insufficient credits"})
	main.orders.reset()
	runner.check(not main.orders._build_refused,"F23 reset() forgets a refusal's beep, so a rematch's first Builder lost is heard")
	main.free()
	return true

func test_ghost_funds_refusal_clicks_each_time(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(800))
	main.orders.selected_ids.assign([1])
	main._refresh()
	build_key(main,"usa_power_plant")
	Fixture.send(main.driver.pump.live(),{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[12,4],"tick":0})
	var spot: Vector2 = Iso.world_to_plane(Vector2(8.25,4.25))
	hover(main,spot)
	tick(main)
	tick(main)
	var answer: Dictionary = main.driver.preview_answer()
	runner.check(main.orders._placement_kind == "usa_power_plant" and answer.get("error","") == "Insufficient credits" and answer.get("tick",-1) == main.shown_state.tick,"F33b fixture: the ghost is known short of credits, got '%s' %s" % [main.orders._placement_kind, answer])
	var clicks: Array = []
	for i in 2:
		pointer(main,spot,MOUSE_BUTTON_LEFT,false)
		publish(main)
		clicks.append(main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "disabled").size())
	runner.check(main.driver.queued().is_empty() and clicks == [1,1],"F33b each click on a ghost known short of credits clicks disabled, like a credit-blocked cell, got %s" % [clicks])
	main.free()
	return true

func test_f33_red_ghost_refused_after_a_two_step_frame(runner) -> bool:
	var main = await _placing(runner)
	var cell: Vector2 = Iso.world_to_plane(Vector2(4.25,4.25))
	hover(main,cell)
	tick(main)
	tick(main)
	main._physics_process(1.0 / 30.0)
	main._physics_process(1.0 / 30.0)
	main._drain_notes()
	pointer(main,cell,MOUSE_BUTTON_LEFT,false)
	var answer: Dictionary = main.driver.preview_answer()
	runner.check(main.driver.queued().is_empty() and answer.get("tick",-1) == main.shown_state.tick and not answer.get("ok",true) and main.hud.refusal == answer.get("error",""),"F33 a click on a still red ghost after a two-step frame is refused on the spot, held %d, tick %d, answer %s" % [main.driver.queued().size(), main.shown_state.tick, main.driver.preview_answer()])
	main.free()
	return true

# The armed preview runs once per physics step, so a slow frame pays it up to max_physics_steps_per_frame times (guide 12).
func test_preview_once_per_physics_step(runner) -> bool:
	var main = await _placing(runner)
	var sim = main.driver.pump.live()
	Fixture.add_completed(sim,1,"usa_barracks",Vector2i(6,10))
	Fixture.add_completed(sim,1,"usa_barracks",Vector2i(10,10))
	publish(main)
	hover(main,Iso.world_to_plane(Vector2(8.25,10.25)))
	var first: int = sim.navigation_builds()
	tick(main)
	runner.check(sim.navigation_builds() == first + 1,"PV1 fixture: a Power Plant closing the gap between two barracks needs a full grid, got %d builds" % (sim.navigation_builds() - first))
	var before: int = sim.navigation_builds()
	for i in 4: main._physics_process(1.0 / 30.0)
	main._drain_notes()
	runner.check(sim.navigation_builds() - before == 4,"PV1 four physics steps and one drain cost four previews, got %d" % (sim.navigation_builds() - before))
	main.free()
	return true

func test_build_menu_from_capabilities(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(50000))
	Fixture.build(runner,main.driver.pump.live(),"usa_power_plant",Vector2i(5,5))
	Fixture.build(runner,main.driver.pump.live(),"usa_supply_center",Vector2i(10,4))
	var factory: int = Fixture.build(runner,main.driver.pump.live(),"usa_factory",Vector2i(14,4))
	main.orders.selected_ids.assign([1])
	publish(main)
	key(main,HudModel.BUILD_KEY)
	runner.check(_menu_texts(main) == ["Q 800 Power Plant","W 2000 Supply Depot","E 600 Barracks","R 2000 Vehicle Factory","A 1000 Missile Battery"],"M1 the builder's sub-grid lists its builds by role, got %s" % [_menu_texts(main)])
	main.orders.selected_ids.clear()
	main.orders.selected_building_id = factory
	main._refresh()
	runner.check(_menu_texts(main) == ["Q 700 Scout Car","W 900 Battle Tank"],"M2 the factory's card lists its produces by role, got %s" % [_menu_texts(main)])
	produce_key(main,"usa_tank")
	var pending: Array = main.driver.queued()
	runner.check(pending.size() == 1 and pending[0].type == "produce" and pending[0].unit_kind == "usa_tank","M3 the tank's cell key trains the tank")
	main.orders.selected_building_id = -1
	main.orders.selected_ids.assign([1])
	main._refresh()
	build_key(main,"usa_factory")
	runner.check(main.orders._placement_kind == "usa_factory","M4 Build then the factory's cell key places the factory")
	main.free()
	return true

# The fullest card, three rows, sits inside the slab with no cell over another (was: eleven menu buttons wrap).
func test_build_menu_wraps_eleven(runner) -> bool:
	var main = await setup(runner)
	main.orders.selected_ids.assign([1])
	main._refresh()
	key(main,HudModel.BUILD_KEY)
	await runner.process_frame
	await runner.process_frame
	var cells: Array = main.get_node("HUD/Economy/Card").get_children()
	runner.check(cells.size() == 12 and cells.all(func(cell: Control) -> bool: return cell.is_visible_in_tree()),"M5 twelve cells, the sub-grid's three rows")
	slab_clear(runner,main,"M5")
	for i in cells.size():
		runner.check(main.get_node("HUD/Economy").get_global_rect().encloses(cells[i].get_global_rect()),"M5 cell %d inside the slab" % i)
		for j in range(i + 1,cells.size()):
			runner.check(not cells[i].get_global_rect().intersects(cells[j].get_global_rect()),"M5 cells %d and %d do not overlap" % [i,j])
	main.free()
	return true

func test_build_menu_quantity_label(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world(50000))
	var barracks: int = Fixture.add_completed(main.driver.pump.live(),1,"china_barracks",Vector2i(10,10))
	main.orders.selected_building_id = barracks
	publish(main)
	await runner.process_frame
	runner.check(_menu_texts(main) == ["Q 300 Militia","W 300 Anti-Tank Trooper"],"M6 the Militia cell shows no squad size (user, 2026-11-23), got " + str(_menu_texts(main)))
	slab_clear(runner,main,"M6")
	main.free()
	return true

func test_sb2_placement_waits_for_build_answer(runner) -> bool:
	var main = await setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	build_key(main,"usa_power_plant")
	hover(main,Iso.world_to_plane(Vector2(4.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(4.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.orders._placement_kind == "usa_power_plant" and main.hud.refusal.is_empty(),"RA6 a refused click keeps placement and says nothing yet, got '%s'" % main.hud.refusal)
	pointer(main,Iso.world_to_plane(Vector2(4.25,4.25)),MOUSE_BUTTON_LEFT,false)
	runner.check(main.driver.queued().size() == 1,"RA6 a second click while the answer is pending is ignored, held %d" % main.driver.queued().size())
	tick(main)
	runner.check(main.orders._placement_kind == "usa_power_plant" and not main.hud.refusal.is_empty(),"RA6 the refusal keeps placement, got '%s'" % main.hud.refusal)
	hover(main,Iso.world_to_plane(Vector2(8.25,4.25)))
	pointer(main,Iso.world_to_plane(Vector2(8.25,4.25)),MOUSE_BUTTON_LEFT,false)
	var builds: int = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "build").size()
	runner.check(main.orders._placement_kind == "usa_power_plant" and builds == 1,"RA6 an accepted click keeps placement until its answer, builds %d" % builds)
	tick(main)
	runner.check(main.orders._placement_kind.is_empty(),"RA6 the accepted answer ends placement")
	main.free()
	return true
