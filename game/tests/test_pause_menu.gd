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
const OnlineTests = preload("res://tests/test_online_scene.gd")
const SeatFixture = preload("res://tests/seat_fixture.gd")

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
	func refused() -> bool: return false
	func silent(_now: int) -> bool: return false
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

func cases() -> Array[Callable]:
	return [test_esc_toggles_and_defers_to_cancel, test_offline_pauses_sim, test_offline_leave_and_quit, test_online_keeps_running, test_online_leave_confirm, test_online_leave_cancel, test_online_leave_text_and_focus, test_online_quit_asks_first, test_menu_buttons, test_faction_guide_page, test_pages_and_back, test_playtest_switch, test_pages_layout, test_mouse_rows_in_button_order, test_controls_list_shows_every_row, test_controls_list_digits_and_platform_words, test_controls_list_keys_work, test_defeated_host_leave_question, test_host_questions_after_friend_left, test_2v2_guest_questions, test_2v2_questions_layout]

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
	_click(main, "Leave match")
	runner.check(scenes == [LAUNCHER], "E3 offline leave goes straight to the launcher, got " + str(scenes))
	main.free()
	main = await _scene(runner, Skirmish)
	var quits: Array[int] = [0]
	main.quit = func() -> void: quits[0] += 1
	_open_menu(main)
	_click(main, "Quit")
	runner.check(quits[0] == 1, "E3 offline Quit quits at once, got %d quits" % quits[0])
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
	_click(main, "Leave match")
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
	_click(main, "Leave match")
	_click(main, "Cancel")
	runner.check(scenes.is_empty() and online.transport.close_calls == 0 and online.lockstep.status() != "ended_relay", "E6 cancel keeps the match")
	runner.check(main.menu_open() and not main.get_node("HUD/PauseMenu").is_confirming(), "E6 back on the main menu list")
	_click(main, "Leave match")
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
		_click(main, "Leave match")
		await runner.process_frame
		await runner.process_frame
		var menu: Control = main.get_node("HUD/PauseMenu")
		var question: Label = menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())[0]
		runner.check(question.text == "Leave the match? Your opponent wins and the room closes.", "E9 the leave question says what happens, got '%s'" % question.text)
		runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(question.get_global_rect()) and question.get_global_rect().size.y > 0.0, "E9 the question sits inside %s, rect %s" % [size, question.get_global_rect()])
		await _confirm_on_one_line(runner, main, Rect2(Vector2.ZERO, Vector2(size)), "E9 1v1 leave at %s" % size, [PauseMenu.LEAVE_QUESTION])
		var cancel: Button = menu.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "Cancel")[0]
		runner.check(main.get_viewport().gui_get_focus_owner() == cancel, "E9 Cancel has the focus")
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		for pressed: bool in [true, false]:
			enter.pressed = pressed
			main.get_viewport().push_input(enter.duplicate())
		runner.check(transport.close_calls == 0 and scenes.is_empty() and not menu.is_confirming(), "E9 Enter on the confirmation does not leave, calls %d" % transport.close_calls)
		_click(main, "Quit")
		await _confirm_on_one_line(runner, main, Rect2(Vector2.ZERO, Vector2(size)), "E9 1v1 quit at %s" % size, [PauseMenu.QUIT_QUESTION])
		port.queue_free()
	return true

func test_online_quit_asks_first(runner) -> bool:
	var saved: String = _helper_off()
	var online: Dictionary = await _online(runner)
	var main = online.main
	var quits: Array[int] = [0]
	main.quit = func() -> void: quits[0] += 1
	var menu: Control = main.get_node("HUD/PauseMenu")
	_esc(main)
	_click(main, "Quit")
	var question: Label = menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())[0]
	runner.check(quits[0] == 0 and online.transport.close_calls == 0 and menu.is_confirming(), "Q1 online Quit asks first")
	runner.check(question.text == "Quit the game? Your opponent wins and the room closes.", "Q1 the quit question says what happens, got '%s'" % question.text)
	_click(main, "Cancel")
	runner.check(quits[0] == 0 and main.menu_open() and not menu.is_confirming(), "Q1 Cancel keeps the game")
	_click(main, "Leave match")
	runner.check(menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())[0].text.begins_with("Leave the match?"), "Q1 Leave match asks its own question after a cancelled Quit")
	_click(main, "Cancel")
	_click(main, "Quit")
	_click(main, "Quit")
	runner.check(quits[0] == 1, "Q1 confirming quits once, got %d" % quits[0])
	_helper_restore(saved)
	main.free()
	return true

const MENU_BUTTONS: Array[String] = ["Resume", "Settings", "Controls", "Faction guide", "Leave match", "Quit"]

func test_menu_buttons(runner) -> bool:
	for web: bool in [false, true]:
		var menu = PauseMenu.new(web)
		var texts: Array = menu.find_child("Menu", true, false).find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)
		var want: Array = MENU_BUTTONS.slice(0, 5) if web else MENU_BUTTONS
		runner.check(texts == want, "M1 web=%s: the menu holds only %s, got %s" % [web, want, texts])
		menu.free()
	return true

static func _shown(menu: Control, part: String) -> bool:
	var node: Control = menu.find_child(part, true, false)
	return node != null and node.is_visible_in_tree()

# P21: the guide opens on your faction, tabs switch it, a roster row fills the card with counters by enemy name; no text under 12 px.
func test_faction_guide_page(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var menu: Control = main.get_node("HUD/PauseMenu")
	_open_menu(main)
	menu.faction = "china"
	_click(main, "Faction guide")
	await runner.process_frame
	var guide: Control = menu.find_child("FactionGuide", true, false)
	runner.check(guide.faction == "china" and guide.find_child("Tab_china", true, false).button_pressed and _shown(guide, "Roster"), "G1 the guide opens on your faction's tab, got %s" % guide.faction)
	runner.check(guide.selected == "china_rifle_infantry" and guide.find_child("Name", true, false).text == "Militia", "G1 the first roster row is shown, got %s" % guide.selected)
	var sizes: Array = []
	for id: String in ["usa", "china", "frc"]:
		guide.find_child("Tab_" + id, true, false).pressed.emit()
		for row: Button in guide.find_child("Roster", true, false).get_children():
			row.pressed.emit()
			await runner.process_frame
			if not sizes.has(guide.size): sizes.append(guide.size)
	runner.check(sizes.size() == 1, "G1 the guide keeps one size on every tab and unit, got %s" % [sizes])
	guide.find_child("Tab_usa", true, false).pressed.emit()
	await runner.process_frame
	runner.check(guide.faction == "usa" and not guide.find_child("Tab_china", true, false).button_pressed and guide.find_child("Roster", true, false).get_child_count() == 6, "G1 the USA tab shows USA's six units")
	(guide.find_child("Roster", true, false).get_node("usa_rocket_infantry") as Button).pressed.emit()
	await runner.process_frame
	var words: Array = guide.find_child("Counters", true, false).find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	runner.check(words.has("BEATS") and words.has("WEAK AGAINST") and words.has("Medium Tank") and words.has("China · you") and words.has("Militia"), "G1 the Rocket Trooper's card names the Medium Tank under Beats, columns marked yours, got %s" % [words])
	var strip: Array = guide.find_child("DamageAgainst", true, false).get_children().map(func(label: Label) -> String: return label.text)
	runner.check(strip == ["DAMAGE AGAINST", "Infantry", "Barely", "Light vehicles", "Half", "Tanks", "Full", "Buildings", "Half"], "G1 the Rocket Trooper's damage strip reads the armour table, got %s" % [strip])
	guide.find_child("Tab_frc", true, false).pressed.emit()
	await runner.process_frame
	var empty: Array = guide.find_child("Counters", true, false).find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	runner.check(empty.count("None cleanly. Closest:") == 3 and empty.has("Rifleman") and not empty.has("–"), "G1 the Insurgent's empty Weak against names the closest unit per faction, got %s" % [empty])
	guide.find_child("Tab_china", true, false).pressed.emit()
	(guide.find_child("Roster", true, false).get_node("china_builder") as Button).pressed.emit()
	await runner.process_frame
	runner.check(guide.find_child("Counters", true, false) == null and guide.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "Builds your base"), "G1 the Bulldozer shows no counters, only what it does")
	var small: Array = guide.find_children("*", "Control", true, false).filter(func(control: Control) -> bool: return (control is Label or control is Button) and control.get_theme_font_size(&"font_size") < 12)
	runner.check(small.is_empty(), "G1 no text under 12 px, got %s" % [small.map(func(control: Control) -> String: return control.name)])
	main.free()
	return true

func test_pages_and_back(runner) -> bool:
	var main = await _scene(runner, Skirmish)
	var menu: Control = main.get_node("HUD/PauseMenu")
	_open_menu(main)
	var focus: Control = main.get_viewport().gui_get_focus_owner()
	runner.check(focus is Button and (focus as Button).text == "Resume", "M2 Resume has the focus on open, got %s" % focus)
	for page: Array in [["Settings", "SettingsPage"], ["Controls", "ControlsPage"], ["Faction guide", "FactionGuide"]]:
		for way: String in ["Esc", "‹ Back"]:
			_click(main, page[0])
			runner.check(_shown(menu, page[1]) and not _shown(menu, "Menu"), "M2 %s replaces the menu with its page" % page[0])
			if way == "Esc": _esc(main)
			else: _click(main, way)
			runner.check(main.menu_open() and _shown(menu, "Menu") and not _shown(menu, page[1]), "M2 %s on the %s page returns to the menu" % [way, page[0]])
	_esc(main)
	runner.check(not main.menu_open(), "M2 Esc on the menu resumes")
	main.free()
	return true

func test_playtest_switch(runner) -> bool:
	var saved: String = _helper_off()
	var menu = PauseMenu.new(false)
	runner.root.add_child(menu)
	var seen: Array[bool] = []
	menu.playtest_changed.connect(func(on: bool) -> void: seen.append(on))
	var switch: CheckButton = menu.find_child("Playtest", true, false)
	runner.check(switch != null and not switch.button_pressed, "M3 the Playtest switch starts off")
	switch.button_pressed = true
	runner.check(seen == [true] and PlaytestSettings.enabled(), "M3 the switch saves and emits, got %s" % [seen])
	PlaytestSettings.save_enabled(false)
	menu.open()
	runner.check(not switch.button_pressed and seen == [true], "M3 opening the menu re-reads the stored setting without a signal")
	menu.free()
	_helper_restore(saved)
	return true

static func _leaves(page: Control) -> Array:
	return page.find_children("*", "Control", true, false).filter(func(control: Control) -> bool: return control.is_visible_in_tree() and (control is Label or control is BaseButton or control is Range))

# The brief's three sizes and the ultrawide one: each page 16 px inside the view, its words whole and apart.
func test_pages_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var inner := Rect2(Vector2.ZERO, Vector2(size)).grow(-16.0)
		var port := BaseScene.sized_port(runner, pair[0], size)
		var main = await _scene(runner, Skirmish, port)
		main.get_node("HUD/PauseMenu").confirm_leave = true
		_open_menu(main)
		for step: Array in [["", "Menu"], ["Settings", "SettingsPage"], ["‹ Back", "Menu"], ["Controls", "ControlsPage"], ["‹ Back", "Menu"], ["Faction guide", "FactionGuide"], ["‹ Back", "Menu"], ["Leave match", "Confirm"]]:
			if not step[0].is_empty(): _click(main, step[0])
			await runner.process_frame
			await runner.process_frame
			var page: Control = main.get_node("HUD/PauseMenu").find_child(step[1], true, false)
			var at: String = "%s at %s" % [step[1], size]
			runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "L1 the viewport really is %s" % size)
			runner.check(page.is_visible_in_tree() and inner.encloses(page.get_global_rect()), "L1 %s: the panel %s 16 px inside the view" % [at, page.get_global_rect()])
			var leaves: Array = _leaves(page)
			var bad: Array = []
			for i: int in leaves.size():
				var rect: Rect2 = leaves[i].get_global_rect()
				if not page.get_global_rect().encloses(rect) or leaves[i].size.x < leaves[i].get_minimum_size().x - 0.5: bad.append("%s cut %s" % [leaves[i].name, rect])
				for j: int in range(i + 1, leaves.size()):
					if rect.intersects(leaves[j].get_global_rect()): bad.append("%s over %s" % [leaves[i].name, leaves[j].name])
			runner.check(leaves.size() >= 3 and bad.is_empty(), "L1 %s: %d words and controls whole and apart, got %s" % [at, leaves.size(), bad.slice(0, 4)])
			if step[1] == "SettingsPage":
				runner.check(leaves.filter(func(control: Control) -> bool: return control is Range).size() == 3 and leaves.filter(func(control: Control) -> bool: return control is CheckButton).size() == 5, "L1 %s: three volume sliders, four switches and Mute" % at)
				var switches: Array = leaves.filter(func(control: Control) -> bool: return control is CheckButton and control.name != "Mute")
				runner.check(switches.all(func(control: Control) -> bool: return control.size.y == 22.0), "L1 %s: the switches are 22 px high as in the mock-up, got %s" % [at, switches.map(func(control: Control) -> float: return control.size.y)])
				runner.check(page.find_child("Volume", true, false).get_theme_constant("h_separation") == 24, "L1 %s: the sliders sit 24 px from their words" % at)
			if step[1] == "ControlsPage":
				var titles: Array = leaves.filter(func(control: Control) -> bool: return control is Label and control.theme_type_variation == &"HudLabel")
				var gaps: Array = []
				for title: Label in titles:
					var above: Array = leaves.filter(func(control: Control) -> bool: return control is Label and control.get_parent() == title.get_parent() and control.get_global_rect().end.y <= title.get_global_rect().position.y)
					if not above.is_empty(): gaps.append(title.get_global_rect().position.y - above.map(func(control: Control) -> float: return control.get_global_rect().end.y).max())
				runner.check(gaps.size() == 3 and gaps.all(func(gap: float) -> bool: return is_equal_approx(gap, 12.0)), "L1 %s: 12 px above each later section title, got %s" % [at, gaps])
		port.free()
	return true

const PAD_ROWS: Array = [["Two-finger swipe", "Pan (trackpad)"], ["Pinch", "Zoom (trackpad)"]]
const MOUSE_ROWS: Array = [["Left-click", "Select a unit or a building"], ["Left-drag", "Select the units in a box"], ["Shift+click", "Add or remove a unit"], ["Double-click", "Select that kind on screen"], ["Alt+double-click", "Select that kind on the map"], ["Left-click", "Place the building (right-click cancels)"], ["Right-click", "Move, attack, gather or enter"], ["Right-click", "Set the rally point (factory or barracks selected)"], ["Right-click", "Cancel the last queued of that unit (on its button)"], ["Right-drag", "Pan, faster the farther you drag"], ["Middle-drag", "Drag the map along"], ["Wheel", "Zoom"]]

func test_mouse_rows_in_button_order(runner) -> bool:
	for mac: bool in [false, true]:
		var mouse: Array = PauseMenu.controls(false, mac)[0]
		var rows: Array = mouse[1].map(func(row: Array) -> Array: return [row[1], row[2]])
		var want: Array = MOUSE_ROWS + (PAD_ROWS if mac else [])
		runner.check(mouse[0] == "Mouse" and rows == want, "CL4 mac=%s: the Mouse rows in button order, got %s" % [mac, rows])
	return true

const PROBES: Array[String] = ["pan", "home", "last_attack", "grid", "build", "back", "attack_move", "stop", "unload", "ping", "recall", "save", "add", "esc", "mute", "perf"]
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
const REQUIRED_MOUSE: Array = [["Left-click", "Select a unit"], ["Left-drag", "box"], ["Shift+click", "Add or remove"], ["Double-click", "on screen"], ["Alt+double-click", "on the map"], ["Right-click", "Move, attack"], ["Right-click", "Set the rally point"], ["Right-click", "Cancel the last queued of that unit (on its button)"], ["Click or right-click", "Cancel the unit in production"], ["Left-click", "right-click cancels"], ["Right-drag", "faster the farther"], ["Middle-drag", "Drag the map"], ["Wheel", "Zoom"], ["Screen edge", "Pan"], ["Top-right production icons", "Click: select its building"]]
static var mac_mouse: Array = [["Two-finger swipe", "Pan (trackpad)"], ["Pinch", "Zoom (trackpad)"]] if OS.has_feature("macos") or OS.has_feature("web_macos") else []
const REQUIRED_WORDS := {"attack_move": "armed units", "last_attack": "your or an ally's base", "esc": "then the menu"}

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
	for pair: Array in REQUIRED_MOUSE + mac_mouse:
		runner.check(mouse.filter(func(row: Array) -> bool: return row[1] == pair[0] and row[2].contains(pair[1])).size() == 1, "CL1 one pointer row %s says '%s', got %s" % [pair[0], pair[1], mouse.map(func(row: Array) -> String: return "%s: %s" % [row[1], row[2]])])
	runner.check(mouse.size() == REQUIRED_MOUSE.size() + mac_mouse.size(), "CL1 the pointer rows are the required ones, got %d" % mouse.size())
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
	var chip: String = (main.hud._card.get_child(0).get_node("Chip") as Label).text
	HudModel.layout_label = HudModel._platform_label
	runner.check(chip == "A", "CL1 opening the menu re-reads the card's chips too, got '%s'" % chip)
	runner.check(main.menu_open() and shown == expected and expected.has("A"), "CL1 opening the menu re-reads the layout's labels, got %s, want %s" % [shown, expected])
	main.free()
	return true

func test_controls_list_digits_and_platform_words(runner) -> bool:
	HudModel.layout_label = func(physical: Key) -> Key: return {KEY_1: KEY_AMPERSAND, KEY_9: KEY_SEMICOLON}.get(physical, physical)
	var recall: Array = []
	for section: Array in PauseMenu.controls(false, true): recall.append_array(section[1].filter(func(row: Array) -> bool: return row[0] == "recall"))
	HudModel.layout_label = HudModel._platform_label
	runner.check(recall.size() == 1 and recall[0][1] == "1-9", "CL1 the group digits keep their number on a layout that moves them, got %s" % [recall])
	for platform: Array in [[false, false, false], [false, true, true], [true, false, false], [true, true, true]]:
		var save: Array = _save_row(PauseMenu.controls(platform[0], platform[1]))
		var text: String = "%s %s" % [save[1], save[2]]
		runner.check(text.contains("Cmd") == platform[2], "CL1 web %s mac %s: Cmd named only on a Mac, got '%s'" % [platform[0], platform[1], text])
		runner.check(save[3].has(KEY_1 | KEY_MASK_META) and save[3].has(KEY_1 | KEY_MASK_CTRL) and save[3].has(KEY_1 | KEY_MASK_SHIFT | KEY_MASK_CTRL), "CL1 web %s mac %s: every save binding is still pressed by CL2" % [platform[0], platform[1]])
	runner.check(_save_row(PauseMenu.controls(true, false))[1].begins_with("Shift+Ctrl+") and _save_row(PauseMenu.controls(false, false))[1].begins_with("Ctrl+"), "CL1 a browser leads with Shift+Ctrl, a desktop with Ctrl")
	return true

static func _save_row(sections: Array) -> Array:
	for section: Array in sections:
		for row: Array in section[1]:
			if row[0] == "save": return row
	return []

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
				"ping":
					# Only a match with a human teammate takes the key (Q7), so it is pressed in a 2v2 from the guest's seat.
					var team: Dictionary = await HudTests.new()._ping_match(runner)
					_press(team.main, press)
					runner.check(team.main.orders.get("ping_armed") == true, "%s arms the ping with a human teammate" % label)
					HudTests.new()._end_ping_match(team)
				"recall":
					var slot: int = ControlGroups.KEYS.find(press & KEY_CODE_MASK)
					var tanks: Array[int] = []
					tanks.assign(ids.tanks)
					orders.groups.save(slot, tanks)
					HudTests._select(main, [ids.infantry])
					_press(main, press)
					runner.check(orders.selected_ids == tanks, "%s: %s selects group %d, got %s" % [label, HudModel.key_label(press & KEY_CODE_MASK), slot + 1, orders.selected_ids])
					_press(main, press)
					main._process(main.GLIDE_MAX_SECONDS)
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
					main._process(main.GLIDE_MAX_SECONDS)
					runner.check(camera.position != CameraTests.AWAY, "%s moves the camera" % label)
				"last_attack":
					_base_shot(main, ids.factory)
					_press(main, press)
					main._process(main.GLIDE_MAX_SECONDS)
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

const HOST_LEAVE: String = "Leave the match? You run the bots. Leaving ends the match for your friend."
const HOST_QUIT: String = "Quit the game? You run the bots. Quitting ends the match for your friend."
const GUEST_LEAVE: String = "Leave the match? The match ends for your friend too."
const GUEST_QUIT: String = "Quit the game? The match ends for your friend too."
const OUT_LEAVE: String = "Leave the match? Your friend plays on against the bots."
const OUT_QUIT: String = "Quit the game? Your friend plays on against the bots."

func _question(main) -> String:
	var shown: Array = main.get_node("HUD/PauseMenu").find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())
	return shown[0].text if not shown.is_empty() else ""

# The questions as the menu asks them: [Leave match, Quit].
func _asked(main) -> Array:
	main._pause.open()
	_click(main, "Leave match")
	var leave: String = _question(main)
	_click(main, "Cancel")
	_click(main, "Quit")
	var quit: String = _question(main)
	_click(main, "Cancel")
	main._pause.close()
	return [leave, quit]

func _team_match(runner, online_tests, seat: int, parent: Node = null) -> Dictionary:
	var online: Dictionary = await online_tests._online(runner, seat, true, parent)
	online_tests._peer_packets(online.transport, 3 - seat, 4, 60)
	online_tests._run(online.main, 8)
	return online

func test_defeated_host_leave_question(runner) -> bool:
	var online_tests = OnlineTests.new()
	var before: Array = online_tests._statics()
	var online: Dictionary = await _team_match(runner, online_tests, 1)
	var main = online.main
	SeatFixture.defeat(main.driver.pump.live(), 1)
	online_tests._run(main, 2)
	runner.check(online.lockstep.status() == "running" and not main.driver.pump.live().survivors().has(1), "T26 fixture: the host is out and the match runs, got %s" % online.lockstep.status())
	var asked: Array = _asked(main)
	runner.check(asked == [HOST_LEAVE, HOST_QUIT], "T26 the defeated host is told leaving ends the match for the friend, got %s" % [asked])
	main.free()
	online_tests._restore_statics(before)
	return true

func test_host_questions_after_friend_left(runner) -> bool:
	var online_tests = OnlineTests.new()
	var before: Array = online_tests._statics()
	var online: Dictionary = await _team_match(runner, online_tests, 1)
	var main = online.main
	SeatFixture.defeat(main.driver.pump.live(), 2)
	online.lockstep.receive('{"type":"left","seat":2,"after_tick":40}')
	online_tests._run(main, 40)
	runner.check(online.lockstep.status() == "running" and online.lockstep.left_seat() == 2, "T26 fixture: the guest is out and gone, the host plays on, got %s" % online.lockstep.status())
	var asked: Array = _asked(main)
	runner.check(asked == ["Leave the match? Your friend already left.", "Quit the game? Your friend already left."], "T26 the host alone is told the friend already left, got %s" % [asked])
	main.free()
	online_tests._restore_statics(before)
	return true

func test_2v2_guest_questions(runner) -> bool:
	var online_tests = OnlineTests.new()
	var before: Array = online_tests._statics()
	var online: Dictionary = await _team_match(runner, online_tests, 2)
	var main = online.main
	var asked: Array = _asked(main)
	runner.check(asked == [GUEST_LEAVE, GUEST_QUIT], "T26 the playing guest is told the match ends for the friend too, got %s" % [asked])
	SeatFixture.defeat(main.driver.pump.live(), 2)
	online_tests._run(main, 2)
	asked = _asked(main)
	runner.check(asked == [OUT_LEAVE, OUT_QUIT], "T26 the defeated guest is told the friend plays on, got %s" % [asked])
	main.free()
	online_tests._restore_statics(before)
	return true

# The owner's 2v2 match: a wrapped question read badly, so each is one line in one label, the box widening to fit.
func _confirm_on_one_line(runner, main, screen: Rect2, label: String, texts: Array) -> void:
	await runner.process_frame
	await runner.process_frame
	var box: Control = main.get_node("HUD/PauseMenu").find_child("Confirm", true, false)
	var shown: Array = box.find_children("*", "Label", true, false).filter(func(each: Label) -> bool: return each.is_visible_in_tree())
	var question: Label = shown[0]
	runner.check(shown.size() == 1 and question.text in texts and question.get_line_count() == 1, "%s: one question label on one line, got %d labels, '%s' on %d lines" % [label, shown.size(), question.text, question.get_line_count()])
	runner.check(screen.grow(-16.0).encloses(box.get_global_rect()) and box.get_global_rect().encloses(question.get_global_rect()) and question.size.x >= question.get_minimum_size().x, "%s: the box fits its question inside the 16 px margin, rect %s box %s" % [label, question.get_global_rect(), box.get_global_rect()])

func test_2v2_questions_layout(runner) -> bool:
	var online_tests = OnlineTests.new()
	var before: Array = online_tests._statics()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		for seat: int in [1, 2, 3]:
			var port := BaseScene.sized_port(runner, pair[0], size)
			var online: Dictionary = await _team_match(runner, online_tests, mini(seat, 2), port)
			var main = online.main
			if seat == 3:
				SeatFixture.defeat(main.driver.pump.live(), 2)
				online_tests._run(main, 2)
			for button: String in ["Leave match", "Quit"]:
				main._pause.open()
				_click(main, button)
				await _confirm_on_one_line(runner, main, screen, "T26 seat %d %s at %s" % [seat, button, size], [HOST_LEAVE, HOST_QUIT, GUEST_LEAVE, GUEST_QUIT, OUT_LEAVE, OUT_QUIT])
				_click(main, "Cancel")
				main._pause.close()
			port.queue_free()
	online_tests._restore_statics(before)
	return true
