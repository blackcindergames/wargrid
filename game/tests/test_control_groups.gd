@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const LINE: String = "HUD/Hud/GroupLine"

func cases() -> Array[Callable]:
	return [test_save_and_select, test_double_tap_centres_on_the_centroid, test_shift_adds, test_one_group_per_unit, test_dead_and_contained_drop, test_building_and_nothing, test_no_build_alias, test_placement_ignores_digits, test_recall_disarms_and_closes, test_save_line, test_save_line_layout, test_reset_and_rematch, test_pan_guard_and_preview]

func _world(runner) -> Array:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = HudTests.new()._slab_world(runner, main, false)
	return [main, ids]

func _key(main, slot: int, ctrl: bool = false, meta: bool = false, shift: bool = false, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_1 + slot - 1
	event.keycode = event.physical_keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	event.shift_pressed = shift
	event.alt_pressed = alt
	main._unhandled_input(event)

static func _members(main, slot: int) -> Array:
	return Array(main.orders.groups.ids(slot - 1))

static func _line(main) -> Label:
	return main.get_node(LINE).find_child("Text", true, false)

static func _clock(main, at: Array) -> void:
	main.orders.groups.now_msec = func() -> int: return at[0]

func test_save_and_select(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	runner.check(_members(main, 1) == ids.tanks, "CG1 Ctrl+1 saves the selection, got %s" % [_members(main, 1)])
	HudTests._select(main, [ids.infantry])
	_key(main, 2, false, true)
	runner.check(_members(main, 2) == [ids.infantry], "CG1 Cmd+2 saves too, got %s" % [_members(main, 2)])
	HudTests._select(main, [ids.collectors[0]])
	_key(main, 3, true, false, true)
	runner.check(_members(main, 3) == [ids.collectors[0]], "CG1 Shift+Ctrl+3, the browser fallback, saves (3-18), got %s" % [_members(main, 3)])
	HudTests._select(main, [ids.collectors[1]])
	_key(main, 3, true, false, true)
	runner.check(_members(main, 3) == [ids.collectors[1]], "CG1 Shift+Ctrl+3 replaces like Ctrl+3, it does not add, got %s" % [_members(main, 3)])
	HudTests._select(main, [ids.infantry])
	_key(main, 1)
	runner.check(main.orders.selected_ids == ids.tanks and main.orders.selected_building_id == -1, "CG1 1 selects the group, got %s" % [main.orders.selected_ids])
	HudTests._select(main, [], ids.factory)
	_key(main, 1)
	runner.check(main.orders.selected_ids == ids.tanks and main.orders.selected_building_id == -1, "CG1 1 clears a selected building, got %s building %d" % [main.orders.selected_ids, main.orders.selected_building_id])
	HudTests._select(main, [], -1, ids.enemy)
	_key(main, 1)
	runner.check(main.orders.selected_ids == ids.tanks and main.orders.inspected_id == -1, "CG1 1 leaves an inspected enemy, got inspected %d" % main.orders.inspected_id)
	HudTests._select(main, [ids.infantry])
	_key(main, 5)
	runner.check(main.orders.selected_ids == [ids.infantry], "CG1 an empty group's key changes nothing, got %s" % [main.orders.selected_ids])
	_key(main, 1, false, false, false, true)
	runner.check(main.orders.selected_ids == [ids.infantry] and _members(main, 1) == ids.tanks, "CG1 Alt+1 does nothing (3-17), got %s" % [main.orders.selected_ids])
	main.free()
	return true

func test_double_tap_centres_on_the_centroid(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var camera: Camera2D = main.get_node("Camera2D")
	var now: Array = [0]
	_clock(main, now)
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	camera.position = Vector2(-200, 100)
	var centre: Vector2 = Iso.world_to_plane(Vector2(9.0, 6.5)).clamp(main._camera_bounds.position, main._camera_bounds.end)
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 one tap selects and does not move the camera, got %s" % camera.position)
	now[0] = 667
	_key(main, 1)
	runner.check(camera.position.is_equal_approx(centre), "CG2 a second tap within 0.667 s centres on the members' centroid %s, got %s" % [centre, camera.position])
	camera.position = Vector2(-200, 100)
	now[0] = 700
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 a third tap straight after a double starts a new pair, got %s" % camera.position)
	now[0] = 1500
	_key(main, 1)
	now[0] = 2168
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 a second tap after 0.668 s is a single tap, got %s" % camera.position)
	HudTests._select(main, [ids.infantry])
	_key(main, 2, true)
	now[0] = 3000
	_key(main, 1)
	_key(main, 2)
	now[0] = 3100
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 taps on different groups never pair, got %s" % camera.position)
	now[0] = 4000
	_key(main, 1)
	HudTests._select(main, [ids.collectors[0]])
	_key(main, 1, true)
	now[0] = 4100
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 a save over the group ends its pending tap, got %s" % camera.position)
	camera.position = Vector2(-200, 100)
	now[0] = 6000
	_key(main, 1)
	_key(main, 5)
	now[0] = 6100
	_key(main, 1)
	runner.check(camera.position == Vector2(-200, 100), "CG2 an empty group's key between two taps breaks the pair, got %s" % camera.position)
	main.free()
	return true

func test_shift_adds(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	HudTests._select(main, [ids.infantry])
	_key(main, 1, false, false, true)
	var all: Array = ids.tanks + [ids.infantry]
	all.sort()
	runner.check(_members(main, 1) == all and main.orders.selected_ids == [ids.infantry], "CG3 Shift+1 adds the selection and keeps it selected, got %s and %s" % [_members(main, 1), main.orders.selected_ids])
	HudTests._select(main, [])
	_key(main, 1, false, false, true)
	runner.check(_members(main, 1) == all and main.orders.selected_ids.is_empty(), "CG3 Shift+1 with nothing selected leaves the group, got %s" % [_members(main, 1)])
	_key(main, 4, false, false, true)
	runner.check(_members(main, 4).is_empty(), "CG3 Shift+4 of nothing saves nothing")
	main.free()
	return true

func test_one_group_per_unit(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks + [ids.infantry])
	_key(main, 1, true)
	HudTests._select(main, [ids.infantry, ids.collectors[0]])
	_key(main, 2, true)
	runner.check(_members(main, 1) == ids.tanks and _members(main, 2) == [ids.infantry, ids.collectors[0]], "CG4 saving moves a unit out of its old group, got %s and %s" % [_members(main, 1), _members(main, 2)])
	HudTests._select(main, [ids.tanks[0]])
	_key(main, 3, false, false, true)
	runner.check(_members(main, 1) == [ids.tanks[1]] and _members(main, 3) == [ids.tanks[0]], "CG4 Shift+N moves a unit out of its old group too, got %s and %s" % [_members(main, 1), _members(main, 3)])
	HudTests._select(main, [ids.tanks[1]])
	_key(main, 1, true)
	HudTests._select(main, [])
	_key(main, 1, true)
	runner.check(_members(main, 1).is_empty() and _members(main, 3) == [ids.tanks[0]], "CG4 Ctrl+1 with nothing selected clears group 1 alone, got %s and %s" % [_members(main, 1), _members(main, 3)])
	main.free()
	return true

func test_dead_and_contained_drop(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var sim = main.driver.pump.live()
	var camera: Camera2D = main.get_node("Camera2D")
	var now: Array = [0]
	_clock(main, now)
	var third: int = sim.spawn(1, Vector2(11.5, 8.5), "china_tank")
	var rifle: int = sim.spawn(1, Vector2(13.5, 4.5), "usa_rifle_infantry")
	BaseScene.publish(main)
	HudTests._select(main, ids.tanks + [third, rifle])
	_key(main, 1, true)
	sim.remove_object(ids.tanks[1])
	Fixture.load_unit(runner, sim, rifle, ids.car)
	BaseScene.publish(main)
	HudTests._select(main, [])
	camera.position = Vector2(-200, 100)
	_key(main, 1)
	var live: Array = [ids.tanks[0], third]
	runner.check(main.orders.selected_ids == live, "CG5 the recall drops a dead and a contained member, got %s" % [main.orders.selected_ids])
	runner.check(_members(main, 1) == live, "CG5 the group forgets them, got %s" % [_members(main, 1)])
	now[0] = 100
	_key(main, 1)
	var rows: RefCounted = main.shown_state.units
	var x: float = (rows.x[rows.index_of(live[0])] + rows.x[rows.index_of(live[1])]) / 2.0
	var y: float = (rows.y[rows.index_of(live[0])] + rows.y[rows.index_of(live[1])]) / 2.0
	var centre: Vector2 = Iso.world_to_plane(Vector2(x, y)).clamp(main._camera_bounds.position, main._camera_bounds.end)
	runner.check(camera.position.is_equal_approx(centre), "CG5 the centroid takes the live members only, wanted %s, got %s" % [centre, camera.position])
	sim.remove_object(live[0])
	sim.remove_object(live[1])
	BaseScene.publish(main)
	HudTests._select(main, [ids.collectors[0]])
	_key(main, 1)
	runner.check(main.orders.selected_ids == [ids.collectors[0]] and _members(main, 1).is_empty(), "CG5 a group with no live member selects nothing and changes nothing, got %s" % [main.orders.selected_ids])
	main.free()
	return true

func test_building_and_nothing(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	HudTests._select(main, [], ids.factory)
	_key(main, 1, true)
	_key(main, 1, false, true)
	runner.check(_members(main, 1) == ids.tanks and main.orders.selected_building_id == ids.factory, "CG6 Ctrl+1 and Cmd+1 with only a building selected leave the group, got %s" % [_members(main, 1)])
	_key(main, 1, false, false, true)
	runner.check(_members(main, 1) == ids.tanks, "CG6 Shift+1 with only a building leaves the group, got %s" % [_members(main, 1)])
	HudTests._select(main, [], -1, ids.enemy)
	_key(main, 1, true)
	runner.check(_members(main, 1) == ids.tanks, "CG6 Ctrl+1 over an inspected enemy leaves the group, got %s" % [_members(main, 1)])
	HudTests._select(main, [])
	_key(main, 1, true)
	runner.check(_members(main, 1).is_empty(), "CG6 Ctrl+1 with nothing selected clears the group, got %s" % [_members(main, 1)])
	main.free()
	return true

func test_no_build_alias(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._prerequisites(main)
	HudTests._select(main, [ids.usa_builder])
	for slot in range(1, 10):
		_key(main, slot)
		_key(main, slot, true)
		_key(main, slot, false, true)
	runner.check(not main.orders._sub_grid and main.orders._placement_kind.is_empty() and main.driver.queued().is_empty() and main.orders.selected_ids == [ids.usa_builder], "CG7 digits never open Build, arm a building or send a command (3-19), got sub-grid %s '%s' %s" % [main.orders._sub_grid, main.orders._placement_kind, main.driver.queued()])
	HudTests._select(main, [], ids.factory)
	for slot in range(1, 10): _key(main, slot)
	runner.check(main.driver.queued().is_empty(), "CG7 digits never queue a unit at a factory, got %s" % [main.driver.queued()])
	main.free()
	return true

func test_placement_ignores_digits(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	HudTests._prerequisites(main)
	HudTests._select(main, [ids.usa_builder])
	main.orders._sub_grid = true
	main.orders._enter_placement("usa_power_plant")
	HudTests._select(main, [ids.usa_builder])
	var kind: String = main.orders._placement_kind
	runner.check(kind == "usa_power_plant", "CG8 fixture: placement armed, got '%s'" % kind)
	_key(main, 1)
	runner.check(main.orders.selected_ids == [ids.usa_builder] and main.orders._placement_kind == kind, "CG8 a digit does nothing in placement, got %s '%s'" % [main.orders.selected_ids, main.orders._placement_kind])
	_key(main, 2, true)
	_key(main, 2, false, true)
	_key(main, 1, false, false, true)
	runner.check(_members(main, 2).is_empty() and _members(main, 1) == ids.tanks, "CG8 Ctrl, Cmd and Shift+digit change no group in placement, got %s and %s" % [_members(main, 1), _members(main, 2)])
	main.free()
	return true

func test_recall_disarms_and_closes(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._prerequisites(main)
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	HudTests._select(main, [ids.infantry])
	main.orders.arm_attack_move()
	runner.check(main.orders._attack_move_mode, "CG9 fixture: attack move armed")
	_key(main, 1)
	runner.check(not main.orders._attack_move_mode and main.orders.selected_ids == ids.tanks and main.driver.queued().is_empty(), "CG9 a recall disarms attack move and sends nothing, got %s" % [main.driver.queued()])
	HudTests._select(main, [ids.usa_builder])
	main.orders._sub_grid = true
	main._reshow()
	_key(main, 1)
	runner.check(not main.orders._sub_grid and main.orders.selected_ids == ids.tanks, "CG9 a recall closes the build sub-grid, got sub-grid %s" % main.orders._sub_grid)
	HudTests._select(main, [ids.usa_builder])
	_key(main, 3, true)
	main.orders._sub_grid = true
	main._reshow()
	_key(main, 3)
	runner.check(not main.orders._sub_grid and main.orders.selected_ids == [ids.usa_builder], "CG9 recalling the builder's own group closes its sub-grid, got sub-grid %s" % main.orders._sub_grid)
	var sim = main.driver.pump.live()
	var doomed: int = sim.spawn(1, Vector2(11.5, 8.5), "china_tank")
	BaseScene.publish(main)
	HudTests._select(main, [doomed])
	_key(main, 2, true)
	sim.remove_object(doomed)
	BaseScene.publish(main)
	HudTests._select(main, [ids.infantry])
	main.orders.arm_attack_move()
	_key(main, 2)
	runner.check(not main.orders._attack_move_mode and main.orders.selected_ids == [ids.infantry], "CG9 recalling an all-dead group disarms attack move and keeps the selection, got armed %s %s" % [main.orders._attack_move_mode, main.orders.selected_ids])
	HudTests._select(main, [ids.usa_builder])
	main.orders._sub_grid = true
	main._reshow()
	_key(main, 2)
	runner.check(not main.orders._sub_grid and main.orders.selected_ids == [ids.usa_builder] and main.driver.queued().is_empty(), "CG9 recalling an all-dead group closes the sub-grid and sends nothing, got sub-grid %s %s" % [main.orders._sub_grid, main.driver.queued()])
	main.free()
	return true

func test_save_line(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var now: Array = [10000]
	main.hud.now_msec = func() -> int: return now[0]
	runner.check(not main.get_node(LINE).visible, "CG10 no line before a save")
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	runner.check(main.get_node(LINE).visible and _line(main).text == "Group 1 · 2 units", "CG10 the line reads Group 1 · 2 units, got '%s'" % _line(main).text)
	now[0] = 11999
	main.hud._process(0.0)
	runner.check(main.get_node(LINE).visible, "CG10 the line stays for 2 s")
	now[0] = 12000
	main.hud._process(0.0)
	runner.check(not main.get_node(LINE).visible, "CG10 the line goes at 2 s")
	HudTests._select(main, [ids.infantry])
	_key(main, 7, true, true)
	runner.check(main.get_node(LINE).visible and _line(main).text == "Group 7 · 1 unit", "CG10 one unit reads singular, got '%s'" % _line(main).text)
	_key(main, 7, false, false, true)
	runner.check(_line(main).text == "Group 7 · 1 unit" and main.get_node(LINE).visible, "CG10 Shift+7 shows the line too, got '%s'" % _line(main).text)
	HudTests._select(main, ids.tanks)
	_key(main, 7, false, false, true)
	runner.check(_line(main).text == "Group 7 · 3 units", "CG10 Shift+7 counts the whole group, got '%s'" % _line(main).text)
	HudTests._select(main, ids.tanks)
	_key(main, 3, true)
	main.driver.pump.live().remove_object(ids.tanks[1])
	BaseScene.publish(main)
	HudTests._select(main, [ids.infantry])
	_key(main, 3, false, false, true)
	runner.check(_line(main).text == "Group 3 · 2 units", "CG10 Shift+3 counts only the live members, got '%s'" % _line(main).text)
	main.hud.reset()
	runner.check(not main.get_node(LINE).visible, "CG10 a reset hides the line")
	main.free()
	return true

func test_save_line_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await OverlayTests.new()._scene(runner, Skirmish, port)
		var ids: Dictionary = HudTests._blocked_world(main, 1000)
		HudTests._select(main, [ids.builder])
		main.hud.refuse("Not enough credits")
		_key(main, 1, true)
		await HudTests._frames(runner)
		var line: Rect2 = HudTests._rect(main, LINE)
		var at: String = " at %s" % size
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has(LINE) and panels.has("HUD/Hud/RefusalLine"), "CG11 the no-overlap list holds the save line and the refusal line%s, got %s" % [at, panels.keys()])
		runner.check(view.grow(-8.0).encloses(line) and absf(line.get_center().x - (408.0 + size.x - 432.0) / 2.0) <= 12.0, "CG11 the line sits inside the view, centred between the selection panel and the slab%s, got %s" % [at, line])
		for path: String in panels:
			if path != LINE: runner.check(not line.intersects(panels[path]), "CG11 the line clears %s%s" % [path, at])
		runner.check(line.size.y == 28.0, "CG11 the line is 28 high like the refusal line%s, got %s" % [at, line.size.y])
		runner.check(size.y - line.end.y <= 48.0, "CG11 the line sits at the bottom, its lower edge within 48 of the view's%s, got %s" % [at, line])
		port.free()
	return true

func test_reset_and_rematch(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, 1, true)
	HudTests._select(main, [ids.infantry])
	_key(main, 9, true)
	runner.check(_members(main, 1) == ids.tanks and _members(main, 9) == [ids.infantry], "CG12 fixture: two groups of distinct units, got %s and %s" % [_members(main, 1), _members(main, 9)])
	main.orders.reset()
	runner.check(_members(main, 1).is_empty() and _members(main, 9).is_empty(), "CG12 reset() clears every group, got %s and %s" % [_members(main, 1), _members(main, 9)])
	HudTests._select(main, ids.tanks)
	_key(main, 4, true)
	main._restart()
	runner.check(_members(main, 4).is_empty() and not main.get_node(LINE).visible, "CG12 a rematch clears the groups and the line, got %s" % [_members(main, 4)])
	main.free()
	return true

func test_pan_guard_and_preview(runner) -> bool:
	var main = await BaseScene.new().setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = Vector2(0, 256)
	main.orders._selecting = true
	main.pan_camera(Vector2.RIGHT, 0.5)
	runner.check(camera.position == Vector2(0, 256), "CG13 a drag box holds the camera, got %s" % camera.position)
	main.orders._selecting = false
	main.pan_camera(Vector2.RIGHT, 0.5)
	runner.check(camera.position == Vector2(200, 256), "CG13 an idle pan moves it, got %s" % camera.position)
	var base := BaseScene.new()
	base.build_key(main, "usa_power_plant")
	runner.check(main.orders._placement_kind == "usa_power_plant", "CG13 fixture: placement armed")
	var before: Vector2i = main.orders._preview_origin
	var zoom: Vector2 = camera.zoom
	main.pan_camera(Vector2.RIGHT, 0.5)
	main.change_zoom(1)
	var expected := Vector2i(Iso.plane_to_world(main.get_node("WorldView").get_local_mouse_position()).floor())
	runner.check(camera.position == Vector2(400, 256) and camera.zoom == zoom, "CG13 the camera pans during placement, the zoom stays, got %s zoom %s" % [camera.position, camera.zoom])
	runner.check(main.orders._preview_origin == expected and expected != before, "CG13 the ghost follows the pointer after the pan, wanted %s (was %s), got %s" % [expected, before, main.orders._preview_origin])
	main.centre_camera(Iso.plane_to_world(Vector2(-300, 100)))
	var again := Vector2i(Iso.plane_to_world(main.get_node("WorldView").get_local_mouse_position()).floor())
	runner.check(camera.position.is_equal_approx(Vector2(-300, 100)) and main.orders._preview_origin == again and again != expected, "CG13 centre_camera centres, and the ghost follows, got %s origin %s" % [camera.position, main.orders._preview_origin])
	main.centre_camera(Iso.plane_to_world(Vector2(100000, 100000)))
	runner.check(is_equal_approx(camera.position.y, main._camera_bounds.end.y) and camera.position.x <= main._camera_bounds.end.x, "CG13 centre_camera clamps like a pan, got %s" % camera.position)
	main.free()
	return true
