@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const Overlay = preload("res://scripts/presentation/perf_overlay.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const PumpTests = preload("res://tests/test_sim_pump.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")

func cases() -> Array[Callable]:
	return [test_summary_math, test_f3_toggles_hidden_default, test_layout_clear_of_hud, test_step_and_counts_shown, test_skirmish_wired, test_split_share_shown, test_f3_toggles_during_placement, test_bot_line_offline_only, test_bot_line_beside_playtest_panels, test_sb5a_f3_shows_mode]

static func _initials(kind: String) -> String:
	var text: String = ""
	for word: String in kind.substr(kind.find("_") + 1).split("_"): text += word.left(1).to_upper()
	return text

# Per faction: every army producer with the longest unit it makes; the widest faction wins.
static func _worst_producers() -> String:
	var worst: String = ""
	for faction: String in ["usa", "china", "frc"]:
		var parts := PackedStringArray()
		for kind: String in Registry.buildings():
			if not kind.begins_with(faction + "_"): continue
			var names: Array = Registry.kind(kind).get("produces", []).filter(func(unit: String) -> bool: return not Registry.is_builder(unit) and Registry.collects(unit).is_empty()).map(func(unit: String) -> String: return Registry.kind(unit).display_name)
			names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
			if not names.is_empty(): parts.append("%s:%s" % [_initials(kind), names[0]])
		if " ".join(parts).length() > worst.length(): worst = " ".join(parts)
	return worst

static func _longest_name() -> String:
	var longest: String = ""
	for kind: String in Registry.units() + Registry.buildings():
		if Registry.kind(kind).display_name.length() > longest.length(): longest = Registry.kind(kind).display_name
	return longest

static func worst_bot_line() -> String:
	return "Bot 2 china | W99 late 999/60s | ready 999,999/999,999 | home 999i/999v | $999,999 | %s | ->%s#99999" % [_worst_producers(), _longest_name()]

func _scene(runner, packed, parent = null):
	var main = packed.instantiate()
	(parent if parent != null else runner.root).add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func _f3(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.keycode = KEY_F3
	event.pressed = true
	main._unhandled_input(event)

func test_summary_math(runner) -> bool:
	var samples := PackedFloat64Array()
	for i in range(1, 101): samples.append(float(i))
	var stats: Dictionary = Overlay.summarize(samples)
	runner.check(stats.p95 == 95.0 and stats.max == 100.0 and stats.last == 100.0, "PO1 p95/max/last of 1..100")
	var long := PackedFloat64Array()
	for i in range(1, 201): long.append(float(i))
	stats = Overlay.summarize(long)
	runner.check(stats.p95 == 194.0 and stats.max == 200.0 and stats.last == 200.0, "PO1 window keeps the last 120 samples (81..200)")
	runner.check(Overlay.summarize(PackedFloat64Array()).last == 0.0, "PO1 empty sample is zero")
	return true

func test_f3_toggles_hidden_default(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	runner.check(not overlay.visible, "PO2 hidden by default")
	_f3(main)
	runner.check(overlay.visible and overlay.text.contains("FPS"), "PO2 F3 shows overlay with text")
	_f3(main)
	runner.check(not overlay.visible, "PO2 second F3 hides it")
	main.free()
	return true

func test_layout_clear_of_hud(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = await _scene(runner, Skirmish, port)
		main.get_node("HUD/PerfOverlay").set_counts(300, 12, 123456)
		main.get_node("HUD/PerfOverlay").extra = func() -> String: return worst_bot_line()
		BaseScene.select_own_unit(main)
		_f3(main)
		await runner.process_frame
		var overlay: Label = main.get_node("HUD/PerfOverlay")
		var rect: Rect2 = overlay.get_global_rect()
		var viewport: Rect2 = main.get_viewport().get_visible_rect()
		runner.check(viewport.size == Vector2(size) and viewport.encloses(rect), "PO3 overlay inside the %s viewport, got %s, rect %s" % [size, viewport.size, rect])
		var hud: Dictionary = BaseScene.hud_panels(main)
		runner.check(hud.has("HUD/MenuChip") and hud.has("HUD/Hud/TopStrip") and hud.has("HUD/Hud/SelectionPanel"), "PO3 the list holds the Menu chip, the strip and the selection panel at %s, got %s" % [size, hud.keys()])
		for path: String in hud: runner.check(not rect.intersects(hud[path]), "PO3 overlay clear of %s at %s" % [path, size])
		port.free()
	return true

func test_step_and_counts_shown(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	_f3(main)
	BaseScene.tick(main)
	var snapshot: Dictionary = main.driver.pump.live().snapshot()
	main.get_node("HUD/PerfOverlay").refresh_text()
	var text: String = main.get_node("HUD/PerfOverlay").text
	runner.check(text.contains("Units %d | Buildings %d | Tick %d" % [snapshot.entities.size(), snapshot.buildings.size(), snapshot.tick]), "PO4 counts and tick from the live state")
	runner.check(main.get_node("HUD/PerfOverlay")._step_count == 1, "PO4 physics step was timed")
	main.free()
	return true

func test_skirmish_wired(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	runner.check(main.get_node("HUD/PerfOverlay") != null and not main.get_node("HUD/PerfOverlay").visible, "PO5 skirmish has the hidden overlay")
	main.free()
	return true

func test_split_share_shown(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	overlay.split_share = 0.97
	overlay.refresh_text()
	runner.check(overlay.text.contains("split 97%"), "PO6 split share shown")
	main.free()
	return true

func test_f3_toggles_during_placement(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	BaseScene.new().build_key(main, "usa_power_plant")
	var kind: String = main.orders._placement_kind
	var queued: int = main.driver.queued().size()
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	runner.check(not kind.is_empty(), "PO19 placement is active")
	_f3(main)
	var shown: bool = overlay.visible and main.orders._placement_kind == kind and main.driver.queued().size() == queued
	runner.check(shown, "PO19 F3 toggles the overlay during placement and keeps the placement")
	_f3(main)
	runner.check(not overlay.visible and main.orders._placement_kind == kind, "PO19 second F3 hides it, placement still active")
	main.free()
	return true

func test_bot_line_offline_only(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	for i in 31: BaseScene.tick(main)
	runner.check(not main.driver.show_bots and main.driver.bot_line().is_empty(), "PO20 a hidden overlay asks for no bot line, got '%s'" % main.driver.bot_line())
	_f3(main)
	runner.check(main.driver.show_bots, "PO20 F3 turns the bot lines on")
	for i in 31: BaseScene.tick(main)
	overlay.refresh_text()
	runner.check(overlay.text.contains("\nBot 2 "), "PO20 the open overlay shows the bot line, got '%s'" % overlay.text)
	_f3(main)
	runner.check(not main.driver.show_bots and main.driver.bot_line().is_empty(), "PO20 closing F3 turns them off and drops the stored line, got '%s'" % main.driver.bot_line())
	_f3(main)
	runner.check(not overlay.text.contains("Bot 2"), "PO20 reopening F3 shows no stale line before the first fresh one, got '%s'" % overlay.text)
	for i in 31: BaseScene.tick(main)
	overlay.refresh_text()
	runner.check(overlay.text.contains("\nBot 2 "), "PO20 a fresh line follows within 30 ticks of reopening, got '%s'" % overlay.text)
	main.free()
	var online = OnlineDriver.new(null, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)
	runner.check(not online.has_method("bot_line"), "PO20 the online driver has no bot line")
	return true

func test_bot_line_beside_playtest_panels(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true)
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = await _scene(runner, Skirmish, port)
		overlays._camera(main)
		var perf: Label = main.get_node("HUD/PerfOverlay")
		perf.extra = func() -> String: return worst_bot_line()
		var helper = main.get_node("HUD/Playtest")
		helper.set_floor(size.y - 462)
		helper.open_marker()
		perf.toggle()
		for i in 3: await runner.process_frame
		var rect: Rect2 = perf.get_global_rect()
		var view := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(view.encloses(rect), "PO21 F3 with the worst bot line inside the %s viewport beside the open checklist and form, got %s" % [size, rect])
		for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog"]:
			runner.check(main.get_node(path).visible and not rect.intersects(main.get_node(path).get_global_rect()), "PO21 F3 clear of %s at %s, F3 %s, panel %s" % [path.get_file(), size, rect, main.get_node(path).get_global_rect()])
		port.free()
	overlays._end(saved)
	return true

func test_sb5a_f3_shows_mode(runner) -> bool:
	var unit = Overlay.new()
	unit.mode = "inline-fallback"
	unit.refresh_text()
	runner.check(unit.text.split("\n")[0].ends_with("Sim: inline (fallback)"), "PO21 the fallback mode reads inline (fallback), got '%s'" % unit.text)
	unit.free()
	var main = await _scene(runner, Skirmish)
	var overlay: Label = main.get_node("HUD/PerfOverlay")
	_f3(main)
	var word: String = "worker" if SimPump.worker_wanted() else "inline"
	runner.check(overlay.text.split("\n")[0].contains("Sim: " + word), "PO21 the first line names the mode '%s', got '%s'" % [word, overlay.text])
	for i in 31: BaseScene.tick(main)
	overlay.refresh_text()
	runner.check(overlay.text.contains("\nBot 2 "), "PO21 the bot line stays below, got '%s'" % overlay.text)
	main.free()
	PumpTests.latch_for_test()
	main = await _scene(runner, Skirmish)
	overlay = main.get_node("HUD/PerfOverlay")
	_f3(main)
	var fallback: String = "Sim: inline (fallback)" if PumpTests.mode_after_latch() == "inline-fallback" else "Sim: inline"
	runner.check(overlay.text.split("\n")[0].contains(fallback), "PO21 after a failure the first line says '%s', got '%s'" % [fallback, overlay.text])
	SimPump.reset_process_latch_for_test()
	main.free()
	return true
