@warning_ignore_start("untyped_declaration")
extends RefCounted

const ViewCaps = preload("res://scripts/presentation/view_caps.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const Launcher = preload("res://scenes/launcher.tscn")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const EXPAND := Window.CONTENT_SCALE_ASPECT_EXPAND
const KEEP := Window.CONTENT_SCALE_ASPECT_KEEP

func cases() -> Array[Callable]:
	return [test_layout_for_table, test_caps_on_the_root_window, test_cap_writes_only_on_change, test_release_drops_a_queued_write, test_launcher_uncapped_round_trip]

func _save(root: Window) -> Array:
	return [root.size, root.content_scale_size, root.content_scale_aspect]

func _restore(root: Window, saved: Array) -> void:
	root.size = saved[0]
	root.content_scale_size = saved[1]
	root.content_scale_aspect = saved[2]

func _layout(root: Window) -> Array:
	return [root.content_scale_size, root.content_scale_aspect]

func _resize(runner, root: Window, size: Vector2i) -> void:
	root.size = size
	await runner.process_frame
	await runner.process_frame

func _match(runner):
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	runner.current_scene = main
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return main

func test_layout_for_table(runner) -> bool:
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(2880, 1200), Vector2i(1280, 800)]:
		runner.check(ViewCaps.layout_for(window) == {"size": Vector2i(1280, 720), "aspect": EXPAND}, "ST1 %s is 1280x720 expand, got %s" % [window, ViewCaps.layout_for(window)])
	runner.check(ViewCaps.layout_for(Vector2i(3840, 1080)) == {"size": Vector2i(1728, 720), "aspect": KEEP}, "ST1 3840x1080 caps at 1728x720 keep, got %s" % ViewCaps.layout_for(Vector2i(3840, 1080)))
	runner.check(ViewCaps.layout_for(Vector2i(1024, 768)) == {"size": Vector2i(1280, 800), "aspect": KEEP}, "ST1 1024x768 caps at 1280x800 keep, got %s" % ViewCaps.layout_for(Vector2i(1024, 768)))
	return true

func test_caps_on_the_root_window(runner) -> bool:
	var root: Window = runner.root
	var saved: Array = _save(root)
	var main = await _match(runner)
	for row: Array in [[Vector2i(2560, 1080), Vector2(1706, 720), EXPAND], [Vector2i(3440, 1440), Vector2(1720, 720), EXPAND], [Vector2i(3840, 1080), Vector2(1728, 720), KEEP], [Vector2i(1024, 768), Vector2(1280, 800), KEEP]]:
		await _resize(runner, root, row[0])
		runner.check(root.get_visible_rect().size == row[1] and root.content_scale_aspect == row[2], "ST2 a %s window shows %s with aspect %d, got %s aspect %d" % [row[0], row[1], row[2], root.get_visible_rect().size, root.content_scale_aspect])
		runner.check(main.get_viewport().get_visible_rect().size == row[1], "ST2 the match lays out at %s in a %s window" % [row[1], row[0]])
		var strip: Rect2 = main.get_node("HUD/Hud/TopStrip").get_global_rect()
		runner.check(strip.position == Vector2(8, 8) and Rect2(Vector2.ZERO, row[1]).encloses(strip), "ST2 the top strip stays at (8, 8) inside a %s window, got %s" % [row[0], strip])
	main.free()
	runner.check(_layout(root) == [Vector2i(1280, 720), EXPAND], "ST2 freeing the match writes 1280x720 expand, got %s" % [_layout(root)])
	var writes: int = ViewCaps.writes
	await _resize(runner, root, Vector2i(3840, 1080))
	runner.check(ViewCaps.writes == writes and _layout(root) == [Vector2i(1280, 720), EXPAND], "ST2 a resize after the match writes nothing, got %d writes, %s" % [ViewCaps.writes - writes, _layout(root)])
	_restore(root, saved)
	return true

func test_cap_writes_only_on_change(runner) -> bool:
	var root: Window = runner.root
	var saved: Array = _save(root)
	root.size = Vector2i(1280, 720)
	var main = await _match(runner)
	var writes: int = ViewCaps.writes
	await _resize(runner, root, Vector2i(3840, 1080))
	await _resize(runner, root, Vector2i(3840, 1080))
	runner.check(ViewCaps.writes - writes == 1, "ST3 the same size twice writes once, got %d" % (ViewCaps.writes - writes))
	for row: Array in [[Vector2i(2390, 1000), Vector2i(1280, 720)], [Vector2i(2410, 1000), Vector2i(1728, 720)], [Vector2i(2390, 1000), Vector2i(1280, 720)], [Vector2i(1590, 1000), Vector2i(1280, 800)], [Vector2i(2410, 1000), Vector2i(1728, 720)], [Vector2i(1280, 720), Vector2i(1280, 720)]]:
		writes = ViewCaps.writes
		await _resize(runner, root, row[0])
		runner.check(ViewCaps.writes - writes == 1 and root.content_scale_size == row[1], "ST3 a %s resize writes once to %s, got %d writes, %s" % [row[0], row[1], ViewCaps.writes - writes, root.content_scale_size])
	writes = ViewCaps.writes
	for frame in 5: await runner.process_frame
	runner.check(ViewCaps.writes == writes, "ST3 no write over the next five frames, got %d" % (ViewCaps.writes - writes))
	main.free()
	_restore(root, saved)
	return true

func test_release_drops_a_queued_write(runner) -> bool:
	var root: Window = runner.root
	var saved: Array = _save(root)
	root.size = Vector2i(1280, 720)
	var main = await _match(runner)
	root.size = Vector2i(3840, 1080)
	main.free()
	await runner.process_frame
	await runner.process_frame
	runner.check(_layout(root) == [Vector2i(1280, 720), EXPAND], "ST5 a cap write queued by a resize in the leaving frame never lands, got %s" % [_layout(root)])
	_restore(root, saved)
	return true

func test_launcher_uncapped_round_trip(runner) -> bool:
	var root: Window = runner.root
	var saved: Array = _save(root)
	var before := [SkirmishMain.factions, SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	for window: Vector2i in [Vector2i(1024, 768), Vector2i(3840, 1080)]:
		await _resize(runner, root, window)
		var layout: Dictionary = ViewCaps.layout_for(window)
		root.content_scale_size = layout.size
		root.content_scale_aspect = layout.aspect
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		runner.check(_layout(root) == [Vector2i(1280, 720), EXPAND], "ST4 the launcher in a %s window is 1280x720 expand, got %s" % [window, _layout(root)])
		launcher._offline_setup()
		launcher.free()
		var main = await _match(runner)
		runner.check(_layout(root) == [layout.size, layout.aspect], "ST4 the offline match in a %s window takes %s, got %s" % [window, layout, _layout(root)])
		main.free()
		root.content_scale_size = layout.size
		root.content_scale_aspect = layout.aspect
		var back = Launcher.instantiate()
		runner.root.add_child(back)
		await runner.process_frame
		runner.check(_layout(root) == [Vector2i(1280, 720), EXPAND], "ST4 back to the menu from a %s match is 1280x720 expand, got %s" % [window, _layout(root)])
		back.free()
	SkirmishMain.factions = before[0]
	SkirmishMain.map_path = before[1]
	SkirmishMain.starts = before[2]
	SkirmishMain.match_seed = before[3]
	_restore(root, saved)
	return true
