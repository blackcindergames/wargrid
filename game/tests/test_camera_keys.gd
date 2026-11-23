@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Scene = preload("res://scenes/skirmish.tscn")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const LINE: String = "HUD/Hud/AlertLine"
const AWAY := Vector2(-200, 100)

func cases() -> Array[Callable]:
	return [test_h_centres_on_the_headquarters, test_h_without_one, test_space_without_an_event, test_open_menu_holds_h_and_space, test_space_jumps_to_the_last_hit, test_space_prefers_own_and_survives_the_target, test_space_after_a_click_presses_nothing, test_keys_in_placement_and_sub_grid, test_alert_line_text_and_timer, test_alert_line_layout]

func _world(runner) -> Array:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = HudTests.new()._slab_world(runner, main, false)
	main.get_node("Camera2D").position = AWAY
	return [main, ids]

func _key(main, code: Key, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	main._unhandled_input(event)

static func _plane(main, world: Vector2) -> Vector2:
	return Iso.world_to_plane(world).clamp(main._camera_bounds.position, main._camera_bounds.end)

func _hit(main, target: int, id: int = 9, ahead: int = 1) -> void:
	var tick: int = main.shown_state.tick + ahead
	var events: Array[Dictionary] = [{"type": "shot", "tick": tick, "attacker_id": id, "target_id": target, "damage": 1, "splash": false}]
	var results: Array[Dictionary] = []
	main._sound.director.collect_step(tick, events, results)
	main._refresh()

func test_h_centres_on_the_headquarters(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var sim = main.driver.pump.live()
	var early: int = Fixture.add_completed(sim, 1, "usa_command_center", Vector2i(4, 4))
	var late: int = Fixture.add_completed(sim, 1, "usa_command_center", Vector2i(6, 14))
	BaseScene.publish(main)
	var camera: Camera2D = main.get_node("Camera2D")
	_key(main, KEY_H)
	var expected: Vector2 = _plane(main, Vector2(5.5, 5.5))
	runner.check(early < late and camera.position.is_equal_approx(expected) and expected != AWAY, "CK1 H centres on the lowest-id Headquarters (3 x 3 at 4,4), wanted %s, got %s" % [expected, camera.position])
	camera.position = AWAY
	_key(main, KEY_H, true)
	runner.check(camera.position == AWAY, "CK1 Ctrl+H does nothing, got %s" % camera.position)
	HudTests._select(main, world[1].tanks)
	_key(main, KEY_H)
	runner.check(camera.position.is_equal_approx(expected) and main.orders.selected_ids == world[1].tanks, "CK1 H leaves the selection alone, got %s" % [main.orders.selected_ids])
	main.free()
	return true

func test_h_without_one(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var sim = main.driver.pump.live()
	for found: Dictionary in main.shown_state.buildings: sim.remove_object(found.id)
	Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(4, 4))
	Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(20, 6))
	BaseScene.publish(main)
	var camera: Camera2D = main.get_node("Camera2D")
	var centre: Vector2 = _plane(main, Vector2(21.0, 7.0))
	_key(main, KEY_H)
	runner.check(camera.position.is_equal_approx(centre) and centre != AWAY, "CK2 without a Headquarters H centres on the costliest own building, the later 800 Power Plant over the 600 Barracks, wanted %s, got %s" % [centre, camera.position])
	var empty = await _world(runner)
	var bare = empty[0]
	for found: Dictionary in bare.shown_state.buildings: bare.driver.pump.live().remove_object(found.id)
	BaseScene.publish(bare)
	_key(bare, KEY_H)
	runner.check(bare.shown_state.buildings.is_empty() and bare.get_node("Camera2D").position == AWAY, "CK2 with no building H does nothing, got %s" % bare.get_node("Camera2D").position)
	bare.free()
	main.free()
	return true

func test_space_without_an_event(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var camera: Camera2D = main.get_node("Camera2D")
	_key(main, KEY_SPACE)
	runner.check(camera.position == AWAY, "CK3 Space before any attack does nothing, got %s" % camera.position)
	_hit(main, world[1].tanks[0])
	_key(main, KEY_SPACE)
	runner.check(camera.position == AWAY, "CK3 a shot at a unit is no base attack, got %s" % camera.position)
	_hit(main, world[1].factory, world[1].enemy, 2)
	var stored: Variant = main._sound.director.last_attack()
	runner.check(stored is Vector2 and stored.is_equal_approx(Vector2(15.5, 15.5)), "CK3 fixture: the factory hit is the stored destination, got %s" % [stored])
	_key(main, KEY_SPACE, true)
	runner.check(camera.position == AWAY, "CK3 Ctrl+Space does nothing, got %s" % camera.position)
	main.free()
	return true

func test_open_menu_holds_h_and_space(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var camera: Camera2D = main.get_node("Camera2D")
	_hit(main, world[1].factory, world[1].enemy, 2)
	main._pause.open()
	_key(main, KEY_SPACE)
	_key(main, KEY_H)
	runner.check(camera.position == AWAY, "CK3 H and Space do nothing behind the open menu, got %s" % camera.position)
	main._pause.close()
	_key(main, KEY_SPACE)
	runner.check(camera.position != AWAY, "CK3 closing the menu frees Space, got %s" % camera.position)
	main.free()
	return true

func test_space_jumps_to_the_last_hit(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var camera: Camera2D = main.get_node("Camera2D")
	_hit(main, ids.factory, ids.enemy)
	var factory_at: Vector2 = _plane(main, Vector2(15.5, 15.5))
	_key(main, KEY_SPACE)
	runner.check(camera.position.is_equal_approx(factory_at) and factory_at != AWAY, "CK4 Space jumps to the building hit, wanted %s, got %s" % [factory_at, camera.position])
	camera.position = AWAY
	_key(main, KEY_SPACE)
	runner.check(camera.position.is_equal_approx(factory_at), "CK4 Space works again, in the voice cooldown, no cycling, got %s" % camera.position)
	var later: Dictionary = main.shown_state.duplicate()
	later.tick = 100000
	main._sound.director.update(later)
	camera.position = AWAY
	_key(main, KEY_SPACE)
	runner.check(camera.position.is_equal_approx(factory_at), "CK4 a stored hit has no age limit, got %s" % camera.position)
	main.free()
	return true

func test_space_prefers_own_and_survives_the_target(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var camera: Camera2D = main.get_node("Camera2D")
	_hit(main, ids.factory, ids.enemy)
	var factory_at: Vector2 = _plane(main, Vector2(15.5, 15.5))
	main.driver.pump.live().remove_object(ids.factory)
	BaseScene.publish(main)
	_key(main, KEY_SPACE)
	runner.check(camera.position.is_equal_approx(factory_at), "CK5 the target died: Space still goes to the stored position, got %s" % camera.position)
	main.free()
	return await _space_after_a_kill_in_the_shot_step(runner)

# The hit reaches the director only after its building left both views, so only the row the pump attached to the shot can place it.
func _space_after_a_kill_in_the_shot_step(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var camera: Camera2D = main.get_node("Camera2D")
	var tick: int = main.shown_state.tick + 1
	var events: Array[Dictionary] = [{"type": "shot", "tick": tick, "attacker_id": ids.enemy, "target_id": ids.factory, "damage": 1, "splash": false}]
	SimPump._attach_targets(events, main.shown_state.buildings)
	main.driver.pump.live().remove_object(ids.factory)
	BaseScene.publish(main)
	var results: Array[Dictionary] = []
	main._sound.director.collect_step(tick, events, results)
	main._refresh()
	_key(main, KEY_SPACE)
	var factory_at: Vector2 = _plane(main, Vector2(15.5, 15.5))
	runner.check(events[0].has("target_building") and camera.position.is_equal_approx(factory_at), "CK5 a building gone from both views is still placed by the row its shot carried, got %s, want %s" % [camera.position, factory_at])
	main.free()
	return true

func test_space_after_a_click_presses_nothing(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	main.driver.adopt(sim)
	main.orders.selected_building_id = barracks
	main._refresh()
	await runner.process_frame
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = AWAY
	_hit(main, barracks)
	var scene := SkirmishTests.new()
	scene._click_control(main, main.get_node("HUD/Economy/Card/Q"))
	var produced: int = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "produce").size()
	scene._push_key(main, KEY_SPACE)
	var again: int = main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == "produce").size()
	var focus: Control = main.get_viewport().gui_get_focus_owner()
	runner.check(produced == 1 and again == 1 and focus == null, "CK6 a clicked cell never keeps the focus, so Space presses nothing (HD#36): %d then %d, focus %s" % [produced, again, focus])
	runner.check(camera.position != AWAY, "CK6 the Space reached the game and jumped, got %s" % camera.position)
	main.free()
	return true

func test_keys_in_placement_and_sub_grid(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var camera: Camera2D = main.get_node("Camera2D")
	_hit(main, ids.factory, ids.enemy)
	HudTests._select(main, [ids.builder])
	var base := BaseScene.new()
	base.key(main, HudModel.BUILD_KEY)
	runner.check(main.orders._sub_grid, "CK7 fixture: the sub-grid is open")
	_key(main, KEY_SPACE)
	runner.check(main.orders._sub_grid and camera.position != AWAY, "CK7 Space in the sub-grid moves the camera and keeps it open, got %s" % camera.position)
	camera.position = AWAY
	base.build_key(main, "usa_power_plant")
	var kind: String = main.orders._placement_kind
	_key(main, KEY_H)
	runner.check(kind != "" and main.orders._placement_kind == kind and camera.position != AWAY, "CK7 H in placement moves the camera and keeps placement, got '%s' %s" % [main.orders._placement_kind, camera.position])
	main.free()
	return true

func test_alert_line_text_and_timer(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var now: Array = [0]
	main.hud.now_msec = func() -> int: return now[0]
	var line: Control = main.get_node(LINE)
	var text: Label = line.find_child("Text", true, false)
	runner.check(not line.visible, "CK8 no alert line before a hit")
	_hit(main, ids.factory, ids.enemy)
	runner.check(line.visible and text.text == "Base under attack", "CK8 an own base hit shows its line, got '%s'" % text.text)
	now[0] = 3999
	main.hud._process(0.0)
	runner.check(line.visible, "CK8 the line stays 4 s")
	now[0] = 4000
	main.hud._process(0.0)
	runner.check(not line.visible, "CK8 the line is gone after 4 s")
	main.free()
	return true

func test_alert_line_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await OverlayTests.new()._scene(runner, Scene, port)
		var ids: Dictionary = HudTests._blocked_world(main, 1000)
		_hit(main, ids.factory)
		main.hud._show_notice("Waiting for player 1 to finish loading the map")
		await HudTests._frames(runner)
		var rect: Rect2 = HudTests._rect(main, LINE)
		var at: String = " at %s" % size
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has(LINE) and panels.has("HUD/Hud/Notice"), "CK9 the no-overlap list holds the alert line and the notice%s, got %s" % [at, panels.keys()])
		runner.check(rect.position.is_equal_approx(Vector2(8, 48)) and rect.size.y == 28.0, "CK9 the line sits at (8, 48), 28 high%s, got %s" % [at, rect])
		for path: String in panels:
			if path != LINE: runner.check(not rect.intersects(panels[path]), "CK9 the line clears %s%s" % [path, at])
		main.hud.alert("Allied base under attack")
		await HudTests._frames(runner)
		var longer: Rect2 = HudTests._rect(main, LINE)
		runner.check(longer.position.is_equal_approx(Vector2(8, 48)) and longer.size.y == 28.0 and longer.size.x > rect.size.x, "CK9 the allied text keeps the line's place and height and widens it%s, got %s then %s" % [at, rect, longer])
		for path: String in panels:
			if path != LINE: runner.check(not longer.intersects(panels[path]), "CK9 the allied line clears %s%s" % [path, at])
		port.free()
	return true
