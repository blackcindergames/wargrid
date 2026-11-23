@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const LAUNCHER: String = "res://scenes/launcher.tscn"
const HudTests = preload("res://tests/test_hud.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const CameraTests = preload("res://tests/test_camera_keys.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ControlGroups = preload("res://scripts/match/control_groups.gd")

class FakeTransport extends RefCounted:
	var patient: bool = false
	var frames := PackedStringArray()
	var close_calls: int = 0
	func poll() -> PackedStringArray:
		var out := frames
		frames = PackedStringArray()
		return out
	func send_text(_text: String) -> void: pass
	func closed() -> bool: return close_calls > 0
	func silent(_now: int) -> bool: return false
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

func cases() -> Array[Callable]:
	return [test_esc_toggles_and_defers_to_cancel, test_offline_pauses_sim, test_offline_leave_and_quit, test_online_keeps_running, test_online_leave_confirm, test_online_leave_cancel, test_online_leave_text_and_focus, test_quit_hidden_on_web, test_menu_layout, test_controls_list_shows_every_row, test_controls_list_keys_work, test_controls_list_layout]

var helper_scratch: String = "user://test-pause-settings-%d.cfg" % OS.get_process_id()

func _helper_off() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = helper_scratch
	DirAccess.remove_absolute(helper_scratch)
	PlaytestSettings.save_enabled(false)
	return saved

func _helper_restore(saved: String) -> void:
	DirAccess.remove_absolute(helper_scratch)
	AudioSettings.path = saved

func _esc(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main._input(event)

# A match starts with its builder selected (3-6): the first Esc deselects it through the orders, the second opens the menu.
func _open_menu(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main._input(event)
	main._unhandled_input(event)
	_esc(main)

func _scene(runner, packed, parent = null):
	var main = packed.instantiate()
	(parent if parent != null else runner.root).add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return main

func _online(runner):
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var lockstep = Lockstep.new(1, seats)
	var main = Skirmish.instantiate()
	main.setup(transport, lockstep, 1)
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return {"main": main, "transport": transport, "lockstep": lockstep}

func _click(main, name: String) -> void:
	for button: Button in main.get_node("HUD/PauseMenu").find_children("*", "Button", true, false):
		if button.text == name and button.is_visible_in_tree():
			button.pressed.emit()
			return
	assert(false, "no visible button " + name)

func test_esc_toggles_and_defers_to_cancel(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var menu: Control = main.get_node("HUD/PauseMenu")
	runner.check(not menu.visible, "E1 menu hidden by default")
	main.orders.selected_ids.assign([1])
	_esc(main)
	runner.check(not menu.visible, "E1 Esc with a selection leaves the menu closed (unhandled input clears it)")
	main.orders.selected_ids.clear()
	main.orders._attack_move_mode = true
	_esc(main)
	runner.check(not menu.visible, "E1 Esc in attack-move mode leaves the menu closed")
	main.orders._attack_move_mode = false
	main.free()
	main = await _scene(runner, Skirmish)
	menu = main.get_node("HUD/PauseMenu")
	BaseScene.new().install_world(main)
	main.orders.selected_ids.assign([main.driver.pump.live().snapshot().entities[0].id])
	main.orders._enter_placement("usa_barracks")
	runner.check(not main.orders._placement_kind.is_empty(), "E1 fixture: placement entered")
	_esc(main)
	runner.check(not menu.visible, "E1 Esc during placement leaves the menu closed")
	main.orders._clear_placement()
	main.orders.selected_ids.clear()
	_esc(main)
	runner.check(menu.visible and main.menu_open(), "E1 Esc with nothing to cancel opens the menu")
	_esc(main)
	runner.check(not menu.visible, "E1 second Esc closes it")
	main.free()
	return true

func test_offline_pauses_sim(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	BaseScene.tick(main)
	var tick: int = main.driver.pump.live().tick()
	runner.check(tick > 0, "E2 fixture: sim advances while closed")
	_open_menu(main)
	for i in 5: BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() == tick, "E2 tick frozen while the menu is open")
	_click(main, "Resume")
	runner.check(not main.menu_open(), "E2 Resume closes the menu")
	BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() == tick + 1, "E2 tick advances after Resume")
	main.free()
	return true

func test_offline_leave_and_quit(runner) -> bool:
	var saved: String = _helper_off()
	var main = await _scene(runner, Skirmish)
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_open_menu(main)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER], "E3 offline leave goes straight to the launcher, got " + str(scenes))
	_helper_restore(saved)
	main.free()
	return true

func test_online_keeps_running(runner) -> bool:
	var online: Dictionary = await _online(runner)
	var main = online.main
	for tick in range(4, 40): online.transport.frames.append(Wire.encode(Wire.tick_message(2, tick, [], null)))
	BaseScene.tick(main)
	_esc(main)
	runner.check(main.menu_open(), "E4 online menu opens")
	var tick: int = main.driver.pump.live().tick()
	for i in 6: BaseScene.tick(main)
	runner.check(main.driver.pump.live().tick() > tick, "E4 online sim keeps stepping while the menu is open")
	main.free()
	return true

func test_online_leave_confirm(runner) -> bool:
	var saved: String = _helper_off()
	var online: Dictionary = await _online(runner)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_esc(main)
	_click(main, "Back to main menu")
	runner.check(scenes.is_empty() and online.transport.close_calls == 0, "E5 asking does not leave yet")
	runner.check(main.get_node("HUD/PauseMenu").is_confirming(), "E5 confirmation shown")
	_click(main, "Leave")
	runner.check(online.transport.close_calls == 1, "E5 leave closes the transport once")
	runner.check(online.lockstep.status().begins_with("ended"), "E5 lockstep ended for this client, got " + online.lockstep.status())
	runner.check(scenes == [LAUNCHER], "E5 launcher scene requested")
	_helper_restore(saved)
	main.free()
	return true

func test_online_leave_cancel(runner) -> bool:
	var online: Dictionary = await _online(runner)
	var main = online.main
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	_esc(main)
	_click(main, "Back to main menu")
	_click(main, "Cancel")
	runner.check(scenes.is_empty() and online.transport.close_calls == 0 and online.lockstep.status() != "ended_relay", "E6 cancel keeps the match")
	runner.check(main.menu_open() and not main.get_node("HUD/PauseMenu").is_confirming(), "E6 back on the main menu list")
	_click(main, "Back to main menu")
	_esc(main)
	runner.check(main.menu_open() and not main.get_node("HUD/PauseMenu").is_confirming(), "E6 Esc in the confirmation returns to the list")
	main.free()
	return true

func test_online_leave_text_and_focus(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var transport := FakeTransport.new()
		var seats: Array[int] = [1, 2]
		var lockstep = Lockstep.new(1, seats)
		var main = Skirmish.instantiate()
		main.setup(transport, lockstep, 1)
		port.add_child(main)
		main.set_process(false)
		main.set_physics_process(false)
		await runner.process_frame
		var scenes: Array[String] = []
		main.change_scene = func(path: String) -> void: scenes.append(path)
		_esc(main)
		_click(main, "Back to main menu")
		await runner.process_frame
		await runner.process_frame
		var menu: Control = main.get_node("HUD/PauseMenu")
		var question: Label = menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())[0]
		runner.check(question.text == "Leave the match? Your opponent wins and the room closes.", "E9 the leave question says what happens, got '%s'" % question.text)
		runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(question.get_global_rect()) and question.get_global_rect().size.y > 0.0, "E9 the question sits inside %s, rect %s" % [size, question.get_global_rect()])
		var cancel: Button = menu.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "Cancel")[0]
		runner.check(main.get_viewport().gui_get_focus_owner() == cancel, "E9 Cancel has the focus")
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		for pressed: bool in [true, false]:
			enter.pressed = pressed
			main.get_viewport().push_input(enter.duplicate())
		runner.check(transport.close_calls == 0 and scenes.is_empty() and not menu.is_confirming(), "E9 Enter on the confirmation does not leave, calls %d" % transport.close_calls)
		port.queue_free()
	return true

func test_quit_hidden_on_web(runner) -> bool:
	for web in [false, true]:
		var menu = PauseMenu.new(web)
		var texts: Array = menu.find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)
		runner.check(texts.has("Quit") != web, "E7 Quit present only off the web (web=%s)" % web)
		menu.free()
	return true

func test_menu_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = await _scene(runner, Skirmish, port)
		_open_menu(main)
		BaseScene.select_own_unit(main)
		await runner.process_frame
		await runner.process_frame
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "E8 the viewport really is %s, got %s" % [size, main.get_viewport().get_visible_rect().size])
		var menu: Control = main.get_node("HUD/PauseMenu")
		var buttons: Array = menu.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.is_visible_in_tree())
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has("HUD/MenuChip") and panels.has("HUD/Hud/TopStrip") and panels.has("HUD/Hud/SelectionPanel"), "E8 the list holds the Menu chip, the strip and the selection panel at %s, got %s" % [size, panels.keys()])
		var hud: Array = panels.values()
		var quality: Button = menu.find_child("Quality", true, false)
		runner.check(quality != null and quality.is_visible_in_tree() and buttons.has(quality), "E8 quality toggle is visible")
		var neon: Button = menu.find_child("Neon", true, false)
		runner.check(neon != null and neon.is_visible_in_tree() and buttons.has(neon), "E8 the Neon toggle is visible at %s" % size)
		var smooth: Button = menu.find_child("Smooth", true, false)
		runner.check(smooth != null and smooth.is_visible_in_tree() and buttons.has(smooth), "E8 the Smooth toggle is visible at %s" % size)
		var destinations: Button = menu.find_child("Destinations", true, false)
		runner.check(destinations != null and destinations.is_visible_in_tree() and buttons.has(destinations), "E8 the Destinations toggle is visible at %s" % size)
		var playtest: Button = menu.find_child("Playtest", true, false)
		runner.check(playtest != null and playtest.is_visible_in_tree() and buttons.has(playtest), "E8 the Playtest toggle is visible at %s" % size)
		var sliders: Array = menu.find_children("*", "Range", true, false).filter(func(slider: Range) -> bool: return slider.is_visible_in_tree())
		var labels: Array = menu.find_child("Volume", true, false).find_children("*Label", "Label", true, false)
		runner.check(sliders.size() == 3 and labels.size() == 4, "E8 menu has 3 sliders and their labels, got %d and %d" % [sliders.size(), labels.size()])
		var values: Array = menu.find_child("Volume", true, false).find_children("*Value", "Label", true, false)
		runner.check(values.size() == 3, "E8 menu shows a value for each slider, got %d" % values.size())
		for control: Control in sliders + labels + values:
			var rect: Rect2 = control.get_global_rect()
			runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "E8 %s inside %s" % [control.name, size])
			for other in hud: runner.check(not rect.intersects(other), "E8 %s clear of HUD text at %s" % [control.name, size])
			for button: Control in buttons: runner.check(not rect.intersects(button.get_global_rect()), "E8 %s clear of %s at %s" % [control.name, button.name, size])
		for i in buttons.size():
			var rect: Rect2 = buttons[i].get_global_rect()
			runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "E8 button %d inside %s" % [i, size])
			for other in hud: runner.check(not rect.intersects(other), "E8 button %d clear of HUD text at %s" % [i, size])
			for j in range(i + 1, buttons.size()): runner.check(not rect.intersects(buttons[j].get_global_rect()), "E8 buttons %d and %d apart at %s" % [i, j, size])
		port.free()
	return true

const PROBES: Array[String] = ["pan", "home", "last_attack", "grid", "build", "back", "attack_move", "stop", "unload", "recall", "save", "add", "esc", "mute", "perf"]
const MODIFIERS := {KEY_MASK_SHIFT: "Shift", KEY_MASK_CTRL: "Ctrl", KEY_MASK_META: "Cmd", KEY_MASK_ALT: "Alt"}

static func _event(press: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = press & KEY_CODE_MASK
	event.keycode = press & KEY_CODE_MASK
	event.pressed = true
	event.shift_pressed = press & KEY_MASK_SHIFT != 0
	event.ctrl_pressed = press & KEY_MASK_CTRL != 0
	event.meta_pressed = press & KEY_MASK_META != 0
	event.alt_pressed = press & KEY_MASK_ALT != 0
	return event

static func _rows() -> Array:
	var rows: Array = []
	for section: Array in PauseMenu.controls(): rows.append_array(section[1])
	return rows

static func _expected_texts() -> Array:
	var expected: Array = []
	for section: Array in PauseMenu.controls():
		expected.append(section[0])
		for row: Array in section[1]: expected.append_array([row[1], row[2]])
	return expected

static func _shown_texts(list: Control) -> Array:
	return list.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)

# Written apart from controls(), so dropping a gesture or a qualifier from the table fails here.
const REQUIRED_MOUSE: Array = [["Left-click", "Select a unit"], ["Drag", "box"], ["Shift+click", "Add or remove"], ["Double-click", "on screen"], ["Alt+double-click", "on the map"], ["Right-click", "Move, attack"], ["Right-click", "with a rally point"], ["Left-click", "right-click cancels"], ["Wheel", "Zoom"], ["Screen edge", "Pan"]]
const REQUIRED_WORDS := {"attack_move": "armed units", "last_attack": "own or allied base"}

func test_controls_list_shows_every_row(runner) -> bool:
	var menu = PauseMenu.new(false)
	var list: Control = menu.find_child("Controls", true, false)
	runner.check(list != null, "CL1 the menu holds a Controls list")
	if list == null:
		menu.free()
		return true
	var shown: Array = _shown_texts(list)
	runner.check(shown == _expected_texts(), "CL1 the list shows every section title, key and line in order, got %s" % [shown])
	var mouse: Array = _rows().filter(func(row: Array) -> bool: return row[3].is_empty())
	for pair: Array in REQUIRED_MOUSE:
		runner.check(mouse.filter(func(row: Array) -> bool: return row[1] == pair[0] and row[2].contains(pair[1])).size() == 1, "CL1 one pointer row %s says '%s', got %s" % [pair[0], pair[1], mouse.map(func(row: Array) -> String: return "%s: %s" % [row[1], row[2]])])
	runner.check(mouse.size() == REQUIRED_MOUSE.size(), "CL1 the pointer rows are the required ones, got %d" % mouse.size())
	for probe: String in REQUIRED_WORDS:
		var rows: Array = _rows().filter(func(row: Array) -> bool: return row[0] == probe)
		runner.check(rows.size() == 1 and rows[0][2].contains(REQUIRED_WORDS[probe]), "CL1 the %s row says '%s', got %s" % [probe, REQUIRED_WORDS[probe], rows])
	for row: Array in _rows():
		var presses: Array = row[3]
		if row[0] == "pan" or presses.is_empty(): continue
		var press: int = presses[0]
		var names: Array = MODIFIERS.keys().filter(func(mask: int) -> bool: return press & mask != 0).map(func(mask: int) -> String: return MODIFIERS[mask])
		var key: String = "Esc" if press == KEY_ESCAPE else HudModel.key_label(press & KEY_CODE_MASK)
		runner.check(row[1].contains(key) and names.all(func(name: String) -> bool: return row[1].contains(name)), "CL1 '%s' names its first press %s %s" % [row[1], names, key])
	menu.free()
	var main = await _scene(runner, Skirmish)
	var list_in_match: Control = main.get_node("HUD/PauseMenu").find_child("Controls", true, false)
	# AZERTY after the menu was built, as a layout switch before a rematch.
	HudModel.layout_label = func(physical: Key) -> Key: return {KEY_Q: KEY_A, KEY_A: KEY_Q, KEY_W: KEY_Z, KEY_Z: KEY_W}.get(physical, physical)
	_open_menu(main)
	var expected: Array = _expected_texts()
	shown = _shown_texts(list_in_match)
	HudModel.layout_label = HudModel._platform_label
	runner.check(main.menu_open() and shown == expected and expected.has("A"), "CL1 opening the menu re-reads the layout's labels, got %s, want %s" % [shown, expected])
	main.free()
	return true

func _press(main, press: int) -> void:
	main.get_viewport().push_input(_event(press))

func _sent_count(main, type: String) -> int:
	return (main.driver.pump.live().snapshot().pending_commands + main.driver.queued()).filter(func(command: Dictionary) -> bool: return command.type == type).size()

func _base_shot(main, target: int) -> void:
	var tick: int = main.shown_state.tick + 1
	var events: Array[Dictionary] = [{"type": "shot", "tick": tick, "attacker_id": 9, "target_id": target, "damage": 1, "splash": false}]
	var results: Array[Dictionary] = []
	main._sound.director.collect_step(tick, events, results)
	main._refresh()

# Each key row is pressed through the match's own input path; a key the list names but the input code does not bind fails here.
func test_controls_list_keys_work(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = HudTests.new()._slab_world(runner, main, true)
	var camera: Camera2D = main.get_node("Camera2D")
	var orders = main.orders
	HudTests._prerequisites(main)
	var probed: Array[String] = []
	var placed: Array[String] = []
	for row: Array in _rows():
		var id: String = row[0]
		var presses: Array = row[3]
		var label: String = "CL2 %s (%s)" % [row[1], row[2]]
		runner.check(id.is_empty() == presses.is_empty(), "%s: a row has presses exactly when it has a probe id" % label)
		if id.is_empty(): continue
		probed.append(id)
		for press: int in presses:
			orders.reset()
			HudTests._select(main, [])
			camera.position = CameraTests.AWAY
			match id:
				"grid":
					var name: String = OS.get_keycode_string(press)
					var action: String = ""
					for builder: int in [ids.builder, ids.frc_builder, ids.usa_builder]:
						HudTests._select(main, [builder])
						orders._sub_grid = true
						main._refresh()
						var cell: Button = main.get_node("HUD/Economy/Card/" + name)
						action = str(cell.get_meta("action")) if cell.is_visible_in_tree() else ""
						if not action.is_empty() and not HudModel.COMMANDS.has(action): break
					if HudModel.COMMANDS.has(action):
						runner.check(PROBES.has(action), "%s: %s's command %s has its own probe" % [label, name, action])
						continue
					_press(main, press)
					if action.is_empty():
						runner.check(orders._placement_kind.is_empty() and orders._sub_grid, "%s: %s on a well arms nothing, got '%s'" % [label, name, orders._placement_kind])
					else:
						runner.check(orders._placement_kind == action, "%s: %s places the shown %s, got '%s'" % [label, name, action, orders._placement_kind])
						placed.append(name)
				"build":
					HudTests._select(main, [ids.builder])
					_press(main, press)
					runner.check(orders._sub_grid, "%s opens the build cells" % label)
				"back":
					HudTests._select(main, [ids.builder])
					orders._sub_grid = true
					main._refresh()
					_press(main, press)
					runner.check(not orders._sub_grid, "%s closes the build cells" % label)
				"attack_move":
					HudTests._select(main, ids.tanks)
					_press(main, press)
					runner.check(orders._attack_move_mode, "%s arms attack move" % label)
				"stop":
					HudTests._select(main, ids.tanks)
					var stops: int = _sent_count(main, "stop")
					_press(main, press)
					runner.check(_sent_count(main, "stop") == stops + 1, "%s sends a stop" % label)
				"unload":
					HudTests._select(main, [], ids.hub)
					var unloads: int = _sent_count(main, "unload")
					_press(main, press)
					runner.check(_sent_count(main, "unload") == unloads + 1, "%s sends an unload" % label)
				"recall":
					var slot: int = ControlGroups.KEYS.find(press & KEY_CODE_MASK)
					var tanks: Array[int] = []
					tanks.assign(ids.tanks)
					orders.groups.save(slot, tanks)
					HudTests._select(main, [ids.infantry])
					_press(main, press)
					runner.check(orders.selected_ids == tanks, "%s: %s selects group %d, got %s" % [label, HudModel.key_label(press & KEY_CODE_MASK), slot + 1, orders.selected_ids])
					_press(main, press)
					runner.check(camera.position != CameraTests.AWAY, "%s: a second press centres on the group" % label)
				"save":
					var slot: int = ControlGroups.KEYS.find(press & KEY_CODE_MASK)
					HudTests._select(main, ids.tanks)
					_press(main, press)
					runner.check(orders.groups.ids(slot) == ids.tanks, "%s: %s saves group %d, got %s" % [label, _event(press).as_text(), slot + 1, orders.groups.ids(slot)])
				"add":
					var slot: int = ControlGroups.KEYS.find(press & KEY_CODE_MASK)
					var infantry: Array[int] = [ids.infantry]
					orders.groups.save(slot, infantry)
					HudTests._select(main, ids.tanks)
					_press(main, press)
					runner.check(orders.groups.ids(slot).size() == 3, "%s: %s adds to group %d, got %s" % [label, _event(press).as_text(), slot + 1, orders.groups.ids(slot)])
				"pan":
					var actions: Array = ["ui_left", "ui_right", "ui_up", "ui_down"].filter(func(action: String) -> bool: return InputMap.event_is_action(_event(press), action))
					runner.check(actions.size() == 1, "%s: %s is one pan action, got %s" % [label, _event(press).as_text(), actions])
					if actions.size() != 1: continue
					Input.action_press(actions[0])
					main._process(0.1)
					Input.action_release(actions[0])
					runner.check(camera.position != CameraTests.AWAY, "%s: %s pans" % [label, actions[0]])
				"home":
					_press(main, press)
					runner.check(camera.position != CameraTests.AWAY, "%s moves the camera" % label)
				"last_attack":
					_base_shot(main, ids.factory)
					_press(main, press)
					runner.check(camera.position != CameraTests.AWAY, "%s jumps to the hit factory" % label)
				"esc":
					HudTests._select(main, ids.tanks)
					_press(main, press)
					runner.check(orders.selected_ids.is_empty() and not main.menu_open(), "%s first backs out of the selection" % label)
					_press(main, press)
					runner.check(main.menu_open(), "%s then opens the menu" % label)
					_press(main, press)
				"mute":
					var muted: bool = AudioServer.is_bus_mute(0)
					_press(main, press)
					runner.check(AudioServer.is_bus_mute(0) != muted, "%s toggles the mute" % label)
					_press(main, press)
					runner.check(AudioServer.is_bus_mute(0) == muted, "%s again restores it" % label)
				"perf":
					var shown: bool = main._perf.visible
					_press(main, press)
					runner.check(main._perf.visible != shown, "%s toggles the overlay" % label)
					_press(main, press)
	runner.check(probed == PROBES, "CL2 every key row has its probe and every probe its row, got %s" % [probed])
	runner.check(placed == ["Q", "W", "E", "R", "A"], "CL2 the grid keys place every builder's buildings, got %s" % [placed])
	main.free()
	return true

func test_controls_list_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = await _scene(runner, Skirmish, port)
		_open_menu(main)
		BaseScene.select_own_unit(main)
		await runner.process_frame
		await runner.process_frame
		var menu: Control = main.get_node("HUD/PauseMenu")
		var list: Control = menu.find_child("Controls", true, false)
		runner.check(list != null and list.is_visible_in_tree(), "CL3 the Controls list shows with the menu at %s" % size)
		if list == null:
			port.free()
			continue
		var hud: Dictionary = BaseScene.hud_panels(main)
		var others: Array = menu.find_children("*", "Button", true, false) + menu.find_child("Volume", true, false).find_children("*", "Control", true, false)
		var settings: Array = others.filter(func(control: Control) -> bool: return control.is_visible_in_tree() and not list.is_ancestor_of(control))
		var box: Rect2 = list.get_global_rect()
		runner.check(view.encloses(box), "CL3 the list %s inside %s" % [box, size])
		for path: String in hud: runner.check(not box.intersects(hud[path]), "CL3 the list clear of %s at %s" % [path, size])
		for control: Control in settings: runner.check(not box.intersects(control.get_global_rect()), "CL3 the list clear of %s at %s" % [control.name, size])
		for label: Label in list.find_children("*", "Label", true, false):
			runner.check(box.encloses(label.get_global_rect()) and label.size.x >= label.get_minimum_size().x - 0.5, "CL3 '%s' whole inside the list at %s, rect %s" % [label.text, size, label.get_global_rect()])
		menu.confirm_leave = true
		_click(main, "Back to main menu")
		runner.check(not list.is_visible_in_tree(), "CL3 the leave question hides the list at %s" % size)
		_click(main, "Cancel")
		runner.check(list.is_visible_in_tree(), "CL3 Cancel shows it again at %s" % size)
		port.free()
	return true
