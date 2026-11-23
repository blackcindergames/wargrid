@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")

func cases() -> Array[Callable]:
	return [test_process_pans_and_arrows_take_precedence, test_resize_drops_the_cached_pointer, test_band_pans_at_every_edge_over_a_panel, test_band_is_three_pixels_of_the_picture, test_picture_rect_at_3440, test_no_focus_no_pan, test_pointer_exit_stops_the_pan, test_drag_box_holds_the_camera, test_placement_pans_with_the_ghost_under_the_pointer, test_placement_ghost_stays_when_the_pointer_is_over_a_panel, test_h_in_placement_reruns_the_preview, test_step_is_capped, test_menu_and_result_hold_the_camera]

# A port with a builder and buildings, the camera mid-map, and the pointer entered but not yet moved.
func _scene(runner, overlays, size: Array) -> Array:
	var port: SubViewport = BaseScene.sized_port(runner, size[0], size[1])
	port.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	var main = await overlays._scene(runner, Skirmish, port)
	main.get_node("HUD/Playtest/Checklist").hide()
	var ids: Dictionary = HudTests.new()._slab_world(runner, main, false)
	main.orders.selected_ids.assign([ids.builder])
	main._refresh()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = Iso.world_to_plane(Vector2(32, 32))
	camera.force_update_scroll()
	await SkirmishTests._frames(runner)
	return [port, main, ids]

static func _at(view: Rect2, edge: Vector2i, along: float) -> Vector2:
	var near: Vector2 = view.position + Vector2.ONE
	var far: Vector2 = view.end - Vector2.ONE
	if edge.x != 0: return Vector2(near.x if edge.x < 0 else far.x, along)
	return Vector2(along, near.y if edge.y < 0 else far.y)

static func _goes(moved: Vector2, edge: Vector2i) -> bool:
	for axis in 2:
		if edge[axis] == 0 and not is_zero_approx(moved[axis]): return false
		if edge[axis] != 0 and moved[axis] * edge[axis] <= 0.0: return false
	return true

# The edge point level with the HUD panel nearest to that edge (it covers the point itself where the panel touches the edge).
static func _panel_point(main, view: Rect2, edge: Vector2i) -> Vector2:
	var best: Rect2 = Rect2()
	var gap: float = INF
	for rect: Rect2 in main.hud.blocking_rects():
		var apart: float = (rect.position.x - view.position.x if edge.x < 0 else view.end.x - rect.end.x) if edge.x != 0 else (rect.position.y - view.position.y if edge.y < 0 else view.end.y - rect.end.y)
		if apart < gap: best = rect; gap = apart
	return _at(view, edge, best.get_center().y if edge.x != 0 else best.get_center().x)

func _step(main, delta: float = 0.016) -> Vector2:
	var camera: Camera2D = main.get_node("Camera2D")
	var before: Vector2 = camera.position
	main.edge_scroll(delta)
	return camera.position - before

func test_band_pans_at_every_edge_over_a_panel(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for size: Array in BaseScene.HUD_SIZES:
		var scene: Array = await _scene(runner, overlays, size)
		var port: SubViewport = scene[0]
		var main = scene[1]
		var view: Rect2 = main.get_viewport().get_visible_rect()
		for edge: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var panel: Vector2 = _panel_point(main, view, edge)
			runner.check(main.hud.blocks(panel) or edge == Vector2i(0, -1), "ES1 %s fixture: a HUD panel covers the edge point %s at %s" % [size[0], edge, panel])
			var plain: Vector2 = _at(view, edge, (view.size.y if edge.x != 0 else view.size.x) / 2.0)
			for spot: Array in [["open ground", plain], ["a panel", panel]]:
				SkirmishTests._push_move(port, spot[1])
				var moved: Vector2 = _step(main)
				runner.check(_goes(moved, edge), "ES1 %s the %s edge over %s pans that way, got %s at %s" % [size[0], edge, spot[0], moved, spot[1]])
		SkirmishTests._push_move(port, view.get_center())
		runner.check(_step(main) == Vector2.ZERO, "ES1 %s the middle of the picture does not pan" % size[0])
		SkirmishTests._push_move(port, Vector2(view.position.x + 1.0, view.position.y + 1.0))
		var corner: Vector2 = _step(main)
		runner.check(corner.x < 0.0 and corner.y < 0.0, "ES1 %s a corner pans both ways, got %s" % [size[0], corner])
		port.free()
	overlays._end(saved)
	return true

func test_band_is_three_pixels_of_the_picture(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var view: Rect2 = main.get_viewport().get_visible_rect()
	var y: float = view.size.y / 2.0
	for row: Array in [[0.0, true], [2.0, true], [3.0, false], [view.end.x - 3.0, true], [view.end.x - 4.0, false]]:
		SkirmishTests._push_move(port, Vector2(row[0], y))
		var moved: Vector2 = _step(main)
		runner.check((moved.x != 0.0) == row[1], "ES2 the pointer at x=%s %s, got %s" % [row[0], "pans" if row[1] else "stays", moved])
	port.free()
	overlays._end(saved)
	return true

func test_picture_rect_at_3440(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[3])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var view: Rect2 = main.get_viewport().get_visible_rect()
	runner.check(view.size == Vector2(1720, 720), "ES3 fixture: the picture rect is 1720x720 logical at 3440x1440, got %s" % view)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(view.end.x - 1.0, 300)
	main._input(motion)
	runner.check(_step(main).x > 0.0, "ES3 the picture's right edge pans right")
	motion.position = Vector2(view.end.x - 8.0, 300)
	main._input(motion)
	runner.check(_step(main) == Vector2.ZERO, "ES3 eight logical pixels inside the picture does not pan")
	motion.position = Vector2(view.end.x + 40.0, 300)
	main._input(motion)
	runner.check(_step(main) == Vector2.ZERO, "ES3 a pointer in a bar past the picture does not pan")
	motion.position = Vector2(-40.0, 300)
	main._input(motion)
	runner.check(_step(main) == Vector2.ZERO, "ES3 a pointer in the left bar does not pan")
	port.free()
	overlays._end(saved)
	return true

func test_no_focus_no_pan(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	SkirmishTests._push_move(port, Vector2(1.0, 300))
	runner.check(_step(main).x < 0.0, "ES4 fixture: the left edge pans while focused")
	for pair: Array in [[Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_IN, "window"], [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_IN, "application"]]:
		main.notification(pair[0])
		runner.check(_step(main) == Vector2.ZERO, "ES4 a %s focus out stops the pan" % pair[2])
		main.notification(pair[1])
		runner.check(_step(main).x < 0.0, "ES4 a %s focus in resumes it, the pointer never moved" % pair[2])
	port.free()
	overlays._end(saved)
	return true

func test_pointer_exit_stops_the_pan(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	runner.check(_step(main) == Vector2.ZERO, "ES5 a pointer that never entered the window does not pan")
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	runner.check(_step(main).x > 0.0, "ES5 fixture: the right edge pans")
	main.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	runner.check(_step(main) == Vector2.ZERO, "ES5 the pointer leaving the window stops the pan")
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	runner.check(_step(main).x > 0.0, "ES5 the next motion inside resumes it")
	main.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(1400.0, 300)
	main._input(release)
	runner.check(_step(main) == Vector2.ZERO, "ES5 a captured release outside the window after the exit does not pan")
	port.free()
	overlays._end(saved)
	return true

func test_drag_box_holds_the_camera(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	SkirmishTests._push_move(port, Vector2(400, 300))
	SkirmishTests._push_button(port, Vector2(400, 300), MOUSE_BUTTON_LEFT, true)
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	runner.check(main.orders.is_selecting(), "ES6 fixture: the drag box is open")
	runner.check(_step(main) == Vector2.ZERO, "ES6 the right edge does not pan under a drag box")
	SkirmishTests._push_button(port, Vector2(1279.0, 300), MOUSE_BUTTON_LEFT, false)
	runner.check(not main.orders.is_selecting() and _step(main).x > 0.0, "ES6 after the release it pans again")
	port.free()
	overlays._end(saved)
	return true

func test_placement_pans_with_the_ghost_under_the_pointer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	main.orders.selected_ids.assign([scene[2].builder])
	BaseScene.new().build_key(main, "china_power_plant")
	runner.check(main.orders._placement_kind == "china_power_plant", "ES7 fixture: placement is armed")
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	var before: Vector2i = main.orders._preview_origin
	var moved: Vector2 = Vector2.ZERO
	for frame in 8: moved += _step(main, 0.05)
	var under := Vector2i(SkirmishTests._world_at(main, Vector2(1279.0, 300)).floor())
	runner.check(moved.x > 0.0, "ES7 the right edge pans during placement, got %s" % moved)
	runner.check(main.orders._preview_origin == under and under != before, "ES7 the ghost is re-run under the pointer, wanted %s (was %s), got %s" % [under, before, main.orders._preview_origin])
	runner.check(main.orders._placement_kind == "china_power_plant", "ES7 placement stays armed")
	port.free()
	overlays._end(saved)
	return true

func test_placement_ghost_stays_when_the_pointer_is_over_a_panel(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	main.orders.selected_ids.assign([scene[2].builder])
	BaseScene.new().build_key(main, "china_power_plant")
	SkirmishTests._push_move(port, Vector2(640, 360))
	var before: Vector2i = main.orders._preview_origin
	var panel: Vector2 = _panel_point(main, main.get_viewport().get_visible_rect(), Vector2i(1, 0))
	SkirmishTests._push_move(port, panel)
	var moved: Vector2 = Vector2.ZERO
	for frame in 8: moved += _step(main, 0.05)
	runner.check(main.hud.blocks(panel) and moved.x > 0.0, "ES13 fixture: the edge pans with the pointer over a panel, got %s" % moved)
	runner.check(main.orders._preview_origin == before, "ES13 the ghost does not follow the map under a panel, wanted %s, got %s" % [before, main.orders._preview_origin])
	port.free()
	overlays._end(saved)
	return true

func test_h_in_placement_reruns_the_preview(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	main.orders.selected_ids.assign([scene[2].builder])
	BaseScene.new().build_key(main, "china_power_plant")
	SkirmishTests._push_move(port, Vector2(640, 360))
	camera.position = Iso.world_to_plane(Vector2(48, 48))
	camera.force_update_scroll()
	main.orders.camera_moved()
	var before: Vector2i = main.orders._preview_origin
	BaseScene.new().key(main, KEY_H)
	main.glide_camera(1.0)
	var under := Vector2i(SkirmishTests._world_at(main, Vector2(640.0, 360.0)).floor())
	runner.check(main.orders._preview_origin == under and under != before, "ES8 H in placement re-runs the preview under the pointer, wanted %s (was %s), got %s" % [under, before, main.orders._preview_origin])
	runner.check(main.orders._placement_kind == "china_power_plant", "ES8 placement stays armed after H")
	port.free()
	overlays._end(saved)
	return true

func test_step_is_capped(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	var frame: Vector2 = _step(main, 0.016)
	runner.check(is_equal_approx(frame.x, 400.0 * 0.016), "ES9 a 16 ms frame moves 400 px/s, got %s" % frame)
	var hitch: Vector2 = _step(main, 2.0)
	runner.check(is_equal_approx(hitch.x, 20.0), "ES9 a 2 s hitch moves at most 20 px, got %s" % hitch)
	port.free()
	overlays._end(saved)
	return true

func test_menu_and_result_hold_the_camera(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	main._pause.open()
	runner.check(_step(main) == Vector2.ZERO, "ES10 the open menu holds the camera")
	main._pause.close()
	runner.check(_step(main).x > 0.0, "ES10 closing it frees the camera")
	main.shown_state = main.shown_state.duplicate(true)
	main.shown_state.match = {"status": "won", "winner": 1}
	runner.check(main.shown_over() and _step(main) == Vector2.ZERO, "ES10 a shown result holds the camera")
	main.shown_state = main.shown_state.duplicate(true)
	main.shown_state.match = {"status": "ongoing"}
	runner.check(not main.shown_over() and _step(main).x > 0.0, "ES10 fixture: an ongoing match pans again")
	main.driver._last.over = true
	runner.check(not main.shown_over() and main.driver.over() and _step(main) == Vector2.ZERO, "ES10 an ended room without a shown result holds the camera")
	main.driver._last.over = false
	main.driver._failure = "pump failed"
	runner.check(main.frozen() and _step(main) == Vector2.ZERO, "ES10 the freeze card holds the camera")
	port.free()
	overlays._end(saved)
	return true

func test_process_pans_and_arrows_take_precedence(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	var start: Vector2 = camera.position
	main._process(0.016)
	runner.check(is_equal_approx(camera.position.x - start.x, 400.0 * 0.016), "ES11 a frame through _process pans by the edge step, got %s" % (camera.position - start))
	Input.action_press("ui_right")
	start = camera.position
	main._process(0.016)
	runner.check(is_equal_approx(camera.position.x - start.x, 400.0 * 0.016), "ES11 Right held at the right edge moves one step, not two, got %s" % (camera.position - start))
	Input.action_release("ui_right")
	Input.action_press("ui_left")
	start = camera.position
	main._process(0.016)
	runner.check(is_equal_approx(camera.position.x - start.x, -400.0 * 0.016), "ES11 Left held at the right edge moves left, got %s" % (camera.position - start))
	main._pause.open()
	start = camera.position
	main._process(0.016)
	runner.check(camera.position == start, "ES11 Left held behind the open menu holds the camera, as edge scroll does, got %s" % (camera.position - start))
	main._pause.close()
	Input.action_release("ui_left")
	port.free()
	overlays._end(saved)
	return true

func test_resize_drops_the_cached_pointer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await _scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	runner.check(_step(main).x > 0.0, "ES12 fixture: the right edge pans")
	port.size = Vector2i(1920, 1080)
	runner.check(_step(main) == Vector2.ZERO, "ES12 a resize with a still pointer does not keep panning on the old coordinate")
	SkirmishTests._push_move(port, Vector2(1279.0, 300))
	runner.check(_step(main).x > 0.0, "ES12 the next motion resumes it")
	port.free()
	overlays._end(saved)
	return true
