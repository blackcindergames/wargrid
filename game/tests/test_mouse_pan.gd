@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const EdgeTests = preload("res://tests/test_edge_scroll.gd")
const Orders = preload("res://scripts/match/orders.gd")
const AT := Vector2(640, 300)

func cases() -> Array[Callable]:
	return [test_still_right_click_orders_on_release, test_right_drag_sends_nothing_and_keeps_selection, test_right_drag_keeps_placement, test_right_drag_keeps_attack_move, test_right_drag_pans_faster_further_out, test_middle_drag_grabs_the_map, test_drag_box_holds_right_and_middle, test_zoom_mid_grab_does_not_jump, test_lost_release_frees_the_next_click, test_open_menu_holds_order_and_grab]

func _drag(port: SubViewport, button: MouseButton, to: Vector2, release: bool = true) -> void:
	SkirmishTests._push_move(port, AT)
	SkirmishTests._push_button(port, AT, button, true)
	SkirmishTests._push_move(port, to)
	if release: SkirmishTests._push_button(port, to, button, false)

func test_still_right_click_orders_on_release(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var sent: int = main._unanswered
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(5, 3), false)
	runner.check(main._unanswered == sent, "MP1 a held right press sends nothing yet")
	SkirmishTests._push_button(port, AT + Vector2(5, 3), MOUSE_BUTTON_RIGHT, false)
	runner.check(main._unanswered == sent + 1, "MP1 the release within 8 px sends the order, sent %d" % (main._unanswered - sent))
	port.free()
	overlays._end(saved)
	return true

func test_right_drag_sends_nothing_and_keeps_selection(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var sent: int = main._unanswered
	var selected: Array[int] = main.orders.selected_ids.duplicate()
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(9, 0))
	runner.check(main._unanswered == sent and main.orders.selected_ids == selected and not selected.is_empty(), "MP2 a right-drag past 8 px sends nothing and keeps the selection")
	port.free()
	overlays._end(saved)
	return true

func test_right_drag_keeps_placement(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	BaseScene.new().build_key(main, "china_power_plant")
	runner.check(main.orders._placement_kind == "china_power_plant", "MP3 fixture: placement is armed")
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(0, 40))
	runner.check(main.orders._placement_kind == "china_power_plant", "MP3 a right-drag keeps the outline")
	_drag(port, MOUSE_BUTTON_RIGHT, AT)
	runner.check(main.orders._placement_kind.is_empty(), "MP3 a still right-click cancels placement")
	port.free()
	overlays._end(saved)
	return true

func test_right_drag_keeps_attack_move(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var shapes: Array[int] = []
	Orders.set_cursor = func(shape: int) -> void: shapes.append(shape)
	main.orders.selected_ids.assign(scene[2].tanks)
	main.orders.arm_attack_move()
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(-40, 0))
	runner.check(main.orders._attack_move_mode, "MP4 a right-drag keeps attack-move")
	runner.check(shapes == [Input.CURSOR_CROSS, Input.CURSOR_MOVE, Input.CURSOR_CROSS], "MP4 the scroll cursor shows while panning and the crosshair comes back, got %s" % [shapes])
	_drag(port, MOUSE_BUTTON_RIGHT, AT)
	runner.check(not main.orders._attack_move_mode, "MP4 a still right-click leaves attack-move")
	Orders.set_cursor = Input.set_default_cursor_shape
	port.free()
	overlays._end(saved)
	return true

func test_right_drag_pans_faster_further_out(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(100, 0), false)
	var start: Vector2 = camera.position
	main._process(0.016)
	var near: Vector2 = camera.position - start
	runner.check(near.is_equal_approx(Vector2(400.0 * 0.016 / camera.zoom.x, 0.0)), "MP5 100 px from the anchor pans at the arrow speed, got %s" % near)
	SkirmishTests._push_move(port, AT + Vector2(0, 200))
	start = camera.position
	main._process(0.016)
	var far: Vector2 = camera.position - start
	runner.check(far.is_equal_approx(Vector2(0.0, 800.0 * 0.016 / camera.zoom.x)), "MP5 200 px below pans down twice as fast, got %s" % far)
	main._pause.open()
	start = camera.position
	main._process(0.016)
	runner.check(camera.position == start, "MP5 the open menu holds the camera, got %s" % (camera.position - start))
	main._pause.close()
	SkirmishTests._push_button(port, AT + Vector2(0, 200), MOUSE_BUTTON_RIGHT, false)
	start = camera.position
	main._process(0.016)
	runner.check(camera.position == start, "MP5 the release stops the pan, got %s" % (camera.position - start))
	port.free()
	overlays._end(saved)
	return true

func test_middle_drag_grabs_the_map(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	var start: Vector2 = camera.position
	var sent: int = main._unanswered
	_drag(port, MOUSE_BUTTON_MIDDLE, AT + Vector2(40, 20))
	runner.check((camera.position - start).is_equal_approx(-Vector2(40, 20) / camera.zoom.x), "MP6 a middle-drag moves the map with the pointer, got %s" % (camera.position - start))
	var held: Vector2 = camera.position
	SkirmishTests._push_move(port, AT + Vector2(90, 90))
	runner.check(camera.position == held and main._unanswered == sent, "MP6 after the release the camera holds and nothing was sent")
	port.free()
	overlays._end(saved)
	return true

func test_drag_box_holds_right_and_middle(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	var start: Vector2 = camera.position
	var sent: int = main._unanswered
	SkirmishTests._push_move(port, AT)
	SkirmishTests._push_button(port, AT, MOUSE_BUTTON_LEFT, true)
	SkirmishTests._push_move(port, AT + Vector2(20, 20))
	SkirmishTests._push_button(port, AT + Vector2(20, 20), MOUSE_BUTTON_RIGHT, true)
	SkirmishTests._push_button(port, AT + Vector2(20, 20), MOUSE_BUTTON_MIDDLE, true)
	SkirmishTests._push_move(port, AT + Vector2(120, 60))
	main._process(0.016)
	runner.check(camera.position == start, "MP7 right and middle under a drag box hold the camera, got %s" % (camera.position - start))
	SkirmishTests._push_button(port, AT + Vector2(120, 60), MOUSE_BUTTON_LEFT, false)
	SkirmishTests._push_button(port, AT + Vector2(120, 60), MOUSE_BUTTON_MIDDLE, false)
	SkirmishTests._push_button(port, AT + Vector2(120, 60), MOUSE_BUTTON_RIGHT, false)
	runner.check(main._unanswered == sent, "MP7 a right press made under the box sends nothing after the box ends, sent %d" % (main._unanswered - sent))
	port.free()
	overlays._end(saved)
	return true

func test_zoom_mid_grab_does_not_jump(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	_drag(port, MOUSE_BUTTON_MIDDLE, AT + Vector2(40, 0), false)
	main.change_zoom(1)
	var start: Vector2 = camera.position
	SkirmishTests._push_move(port, AT + Vector2(80, 0))
	runner.check((camera.position - start).is_equal_approx(Vector2(-40, 0) / camera.zoom.x), "MP8 after a zoom the grab moves by the new motion only, got %s at zoom %s" % [camera.position - start, camera.zoom.x])
	SkirmishTests._push_button(port, AT + Vector2(80, 0), MOUSE_BUTTON_MIDDLE, false)
	port.free()
	overlays._end(saved)
	return true

func test_lost_release_frees_the_next_click(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var sent: int = main._unanswered
	_drag(port, MOUSE_BUTTON_RIGHT, AT + Vector2(50, 0), false)
	_drag(port, MOUSE_BUTTON_RIGHT, AT)
	runner.check(main._unanswered == sent + 1 and not main.mouse_pan.anchoring(), "MP9 after a lost release the next still right-click orders, sent %d" % (main._unanswered - sent))
	port.free()
	overlays._end(saved)
	return true

func test_open_menu_holds_order_and_grab(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var scene: Array = await EdgeTests.new()._scene(runner, overlays, BaseScene.HUD_SIZES[0])
	var port: SubViewport = scene[0]
	var main = scene[1]
	var camera: Camera2D = main.get_node("Camera2D")
	var sent: int = main._unanswered
	_drag(port, MOUSE_BUTTON_RIGHT, AT, false)
	main._pause.open()
	SkirmishTests._push_button(port, AT, MOUSE_BUTTON_RIGHT, false)
	runner.check(main._unanswered == sent, "MP10 a right release behind the open menu sends nothing, sent %d" % (main._unanswered - sent))
	main._pause.close()
	_drag(port, MOUSE_BUTTON_MIDDLE, AT, false)
	main._pause.open()
	var start: Vector2 = camera.position
	SkirmishTests._push_move(port, AT + Vector2(60, 30))
	runner.check(camera.position == start, "MP10 a middle grab holds behind the open menu, got %s" % (camera.position - start))
	main._pause.close()
	SkirmishTests._push_button(port, AT + Vector2(60, 30), MOUSE_BUTTON_MIDDLE, false)
	port.free()
	overlays._end(saved)
	return true
