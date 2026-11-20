@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scenes/skirmish.tscn")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const FocusCardView = preload("res://scripts/playtest/focus_card_view.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Hud = preload("res://scripts/match/hud.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Orders = preload("res://scripts/match/orders.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const LOW: String = "LOW POWER · DEFENCES OFF"
const MINUS: String = "\u2212"
const THEME_PATH: String = "res://ui/launcher_theme.tres"
const TOKENS: Dictionary = {"bg": "#121c24", "btn": "#223241", "panel2": "#26384a", "quiet": "#16212a", "well": "#0c141a", "line": "#2e3f4b", "text": "#eef3f5", "muted": "#93a5b0", "sel": "#60e5ed", "amber": "#f7c871", "warn": "#f47b6c"}
const TYPE_SCALE: Array[int] = [12, 13, 14, 16, 24, 30]
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const SMALL: int = 12

func cases() -> Array[Callable]:
	return [test_theme_tokens, test_type_scale, test_no_rounding_or_shadow, test_match_surfaces_keep_their_size, test_hud_reads_only_its_input, test_side_effects_live_in_the_screen, test_power_reads_used_over_available, test_forecast_forms, test_swatch_slot_colour, test_strip_anchor_without_tick, test_strip_patches_values, test_chip_stack, test_esc_chip_only_when_esc_opens_the_menu, test_menu_chip_opens_the_menu, test_online_notice_top_centre, test_stack_follows_size_changes, test_slab_rect, test_slab_china_with_overlays, test_armed_button_look, test_slab_order_buttons, test_slab_queue_cap, test_build_buttons_by_selection_and_price, test_key_labels, test_floor_follows_a_resize, test_panel_states_layout, test_panel_values, test_panel_edge_colours, test_kind_rows, test_roster_fits, test_row_click_narrows_and_shift_removes, test_rows_hold_under_the_pointer, test_row_bar_is_the_health_sum, test_row_hover, test_rows_footer, test_collector_label_table, test_idle_header, test_rebuild_count]

# The match scene's economy column as skirmish.tscn has it; the Hud adds the rest.
static func _economy() -> VBoxContainer:
	var economy := VBoxContainer.new()
	for part: Control in [Button.new(), Button.new(), VBoxContainer.new()]: economy.add_child(part)
	for i in 3: economy.get_child(i).name = ["Produce", "CancelBuild", "Queue"][i]
	return economy

func test_hud_reads_only_its_input(runner) -> bool:
	var script: GDScript = Hud
	var named: bool = script.get_script_method_list().any(func(method: Dictionary) -> bool: return method.name == "update_hud")
	runner.check(named, "HN1 hud.gd has update_hud")
	if not named: return true
	var parent := Control.new()
	runner.root.add_child(parent)
	var hud = script.new()
	parent.add_child(hud)
	var status := Label.new()
	parent.add_child(status)
	var economy := _economy()
	parent.add_child(economy)
	hud.setup(economy, status)
	var ids: Array[int] = [1]
	var selection: Dictionary = {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": "", "resume_id": -1, "notice": "", "production_kind": "", "bright_owners": false, "over": false, "esc_opens_menu": true, "attack_move": false}
	hud.update_hud(Fixture.make_world().view_state(), selection, 1, 1)
	runner.check(hud.name == "Hud" and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.anchor_right == 1.0 and hud.anchor_bottom == 1.0, "HN1 the Hud is a full-rect node that ignores the mouse")
	var panel_name: String = _part(hud, "SelectionPanel", "Name").text
	runner.check(_part(hud, "TopStrip", "Credits").text == "10000" and panel_name == Registry.kind("usa_builder").display_name, "HN1 the strip and the selection panel fill from the view and the selection alone, got '%s'" % panel_name)
	runner.check(hud.menu_kinds == Registry.kind("usa_builder").builds and economy.get_node("BuildMenu").get_child_count() == hud.menu_kinds.size(), "HN1 the builder's menu fills, got %s" % [hud.menu_kinds])
	var sim = Fixture.make_world()
	var tank: int = sim.spawn(1, Vector2(8.5, 8.5), "usa_tank")
	var other: int = sim.spawn(1, Vector2(10.5, 8.5), "china_builder")
	for case: Array in [[tank, "usa_builder", "a tank keeps the start unit's menu"], [other, "china_builder", "another faction's builder brings its own menu"]]:
		ids.assign([case[0]])
		hud.update_hud(sim.view_state(), selection, 1, 1)
		runner.check(hud.menu_kinds == Registry.kind(case[1]).builds, "HN1 %s, got %s" % [case[2], hud.menu_kinds])
	parent.free()
	return true

func test_side_effects_live_in_the_screen(runner) -> bool:
	var main = await BaseScene.new().setup(runner)
	runner.check(main.hud.has_signal("menu_chosen") and main.hud.has_signal("produce_pressed") and main.hud.has_signal("cancel_build_pressed"), "HN2 the Hud speaks through its signals")
	if not main.hud.has_signal("menu_chosen"):
		main.free()
		return true
	main.driver.adopt(Fixture.make_world(50000))
	var sim = main.driver.pump.live()
	Fixture.build(runner, sim, "usa_power_plant", Vector2i(5, 5))
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 4))
	BaseScene.publish(main)
	main.orders.inspected_id = barracks
	main._refresh()
	runner.check(main.get_node("WorldView")._inspected_id == barracks, "HN2 the screen hands the inspected id to the view")
	main.orders.selected_ids.assign([1])
	main._refresh()
	var builds: Array = Registry.kind("usa_builder").builds
	runner.check(main.orders.menu == builds, "HN2 the screen copies the builder's menu to orders, got %s" % [main.orders.menu])
	var chosen: Array[int] = []
	main.hud.menu_chosen.connect(func(index: int) -> void: chosen.append(index))
	main.get_node("HUD/Economy/BuildMenu").get_child(0).pressed.emit()
	runner.check(chosen == [0] and main.orders._placement_kind == builds[0], "HN2 build button 0 emits menu_chosen(0) and arms placement, got %s '%s'" % [chosen, main.orders._placement_kind])
	main.orders.reset()
	main.orders.selected_building_id = barracks
	main._refresh()
	var produced: Array[int] = [0]
	main.hud.produce_pressed.connect(func() -> void: produced[0] += 1)
	main.get_node("HUD/Economy/Produce").pressed.emit()
	var queued: Array = main.driver.queued()
	runner.check(produced[0] == 1 and queued.size() == 1 and queued[0].type == "produce" and queued[0].building_id == barracks, "HN2 Produce queues the barracks' unit through produce_pressed, got %s" % [queued])
	BaseScene.tick(main)
	Fixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [8, 12]})
	BaseScene.tick(main)
	var site: int = sim.snapshot().buildings.back().id
	main.orders.selected_building_id = site
	main._refresh()
	var cancelled: Array[int] = [0]
	main.hud.cancel_build_pressed.connect(func() -> void: cancelled[0] += 1)
	main.get_node("HUD/Economy/CancelBuild").pressed.emit()
	queued = main.driver.queued()
	runner.check(cancelled[0] == 1 and queued.size() == 1 and queued[0].type == "cancel_build" and queued[0].building_id == site, "HN2 Cancel construction cancels the site through cancel_build_pressed, got %s" % [queued])
	main.free()
	return true

func _theme() -> Theme:
	return ThemeDB.get_project_theme()

func test_theme_tokens(runner) -> bool:
	runner.check(ProjectSettings.get_setting("gui/theme/custom") == THEME_PATH, "TH1 the project theme setting is the launcher theme, got %s" % ProjectSettings.get_setting("gui/theme/custom"))
	var theme: Theme = _theme()
	runner.check(theme != null and theme.resource_path == THEME_PATH, "TH1 the project theme is %s" % THEME_PATH)
	if theme == null: return true
	runner.check(theme.get_color_list(&"Tokens").size() == TOKENS.size(), "TH1 Tokens holds the %d tokens, got %s" % [TOKENS.size(), theme.get_color_list(&"Tokens")])
	for token: String in TOKENS:
		var got: String = "#" + theme.get_color(token, &"Tokens").to_html(false)
		runner.check(theme.has_color(token, &"Tokens") and got == TOKENS[token], "TH1 token %s is %s, got %s" % [token, TOKENS[token], got])
	for ground: String in ["btn", "bg", "panel2"]:
		var ratio: float = _contrast(theme.get_color(&"warn", &"Tokens"), theme.get_color(ground, &"Tokens"))
		runner.check(ratio >= 4.5, "TH1 warn text on %s meets AA 4.5:1, got %.2f" % [ground, ratio])
	return true

static func _contrast(a: Color, b: Color) -> float:
	var high: float = maxf(_luminance(a), _luminance(b))
	var low: float = minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)

static func _luminance(color: Color) -> float:
	var linear: Array[float] = []
	for channel: float in [color.r, color.g, color.b]: linear.append(channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

func test_type_scale(runner) -> bool:
	var theme: Theme = _theme()
	runner.check(theme.default_font_size in TYPE_SCALE, "TH2 the default size %d is on the scale" % theme.default_font_size)
	for type: StringName in theme.get_font_size_type_list():
		for item: StringName in theme.get_font_size_list(type):
			runner.check(theme.get_font_size(item, type) in TYPE_SCALE, "TH2 %s/%s %d is on the scale" % [type, item, theme.get_font_size(item, type)])
	var tnum: int = TextServerManager.get_primary_interface().name_to_tag("tnum")
	for type: String in ["HudNumber", "HudCredits", "HudSmallNumber"]:
		var font: Font = theme.get_font(&"font", type)
		runner.check(font is FontVariation and (font as FontVariation).opentype_features.get(tnum, 0) == 1, "TH2 %s font is a FontVariation with tnum on" % type)
		var label := Label.new()
		label.theme_type_variation = type
		runner.root.add_child(label)
		label.text = "111"
		var ones: float = label.get_minimum_size().x
		label.text = "888"
		var eights: float = label.get_minimum_size().x
		runner.check(ones > 0.0 and is_equal_approx(ones, eights), "TH2 %s measures 111 and 888 alike, got %.2f and %.2f" % [type, ones, eights])
		label.free()
	var number := Label.new()
	number.theme_type_variation = &"HudSmallNumber"
	runner.root.add_child(number)
	var small: Font = number.get_theme_font("font")
	runner.check(small is FontVariation and (small as FontVariation).base_font.resource_path.ends_with("PublicSans-Regular.ttf") and number.get_theme_font_size("font_size") == SMALL, "TH2 HudSmallNumber is regular weight at %d px, got %d" % [SMALL, number.get_theme_font_size("font_size")])
	number.free()
	var check := CheckBox.new()
	check.theme_type_variation = &"HudSmallCheck"
	runner.root.add_child(check)
	runner.check(check.get_theme_font("font").resource_path.ends_with("PublicSans-Regular.ttf"), "TH2 HudSmallCheck labels are regular weight, got %s" % check.get_theme_font("font").resource_path)
	check.free()
	var button := Button.new()
	button.theme_type_variation = &"HudSmallButton"
	runner.root.add_child(button)
	runner.check(button.get_theme_color("font_pressed_color") != button.get_theme_color("font_color") and button.get_theme_color("font_color").is_equal_approx(Color(0.875, 0.875, 0.875)), "TH2 a pressed HudSmallButton reads apart from a normal one, normal %s" % button.get_theme_color("font_color"))
	button.free()
	var field := LineEdit.new()
	field.theme_type_variation = &"HudSmallField"
	runner.root.add_child(field)
	runner.check(field.get_theme_color("font_color").is_equal_approx(Color(0.875, 0.875, 0.875)), "TH2 HudSmallField text keeps Godot's default grey, got %s" % field.get_theme_color("font_color"))
	field.free()
	var hud_button := Button.new()
	hud_button.theme_type_variation = &"HudButton"
	hud_button.text = "Stop (S)"
	runner.root.add_child(hud_button)
	runner.check(hud_button.get_combined_minimum_size().y == 32.0, "TH2 a HudButton is 32 px high, got %s" % hud_button.get_combined_minimum_size().y)
	hud_button.free()
	return true

func test_no_rounding_or_shadow(runner) -> bool:
	var theme: Theme = _theme()
	for type: StringName in theme.get_stylebox_type_list():
		for item: StringName in theme.get_stylebox_list(type):
			var style := theme.get_stylebox(item, type) as StyleBoxFlat
			if style == null: continue
			var limit: int = 0 if String(type).begins_with("Hud") else 2
			runner.check(_radius(style) <= limit and style.shadow_size == 0, "TH3 %s/%s radius %d at most %d, shadow %d" % [type, item, _radius(style), limit, style.shadow_size])
	var panel := ResultPanel.new()
	runner.root.add_child(panel)
	var card: StyleBox = panel.get_node("Center/Card").get_theme_stylebox("panel")
	runner.check(card is StyleBoxFlat and _radius(card) == 0, "TH3 the result card is square")
	for path: String in ["Center/Card/Box/Buttons/PlayAgain", "Center/Card/Box/Buttons/ChangeSetup"]:
		var button: Button = panel.get_node(path)
		for state: String in BUTTON_STATES:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			runner.check(style == null or (_radius(style) == 0 and style.shadow_size == 0), "TH3 %s %s is square" % [button.name, state])
	panel.free()
	var focus_card := FocusCardView.new(FocusCards.load_cards())
	runner.root.add_child(focus_card)
	for control: Control in _controls(focus_card):
		for item: String in _drawn_styles(control):
			var style := control.get_theme_stylebox(item) as StyleBoxFlat
			runner.check(style == null or (_radius(style) == 0 and style.shadow_size == 0), "TH3 focus card %s %s is square, no shadow" % [control.name, item])
	focus_card.free()
	return true

static func _radius(style: StyleBoxFlat) -> int:
	return maxi(maxi(style.corner_radius_top_left, style.corner_radius_top_right), maxi(style.corner_radius_bottom_left, style.corner_radius_bottom_right))

static func _drawn_styles(control: Control) -> Array[String]:
	if control is BaseButton: return BUTTON_STATES
	if control is LineEdit: return ["normal", "focus", "read_only"]
	if control is PanelContainer: return ["panel"]
	return []

# Internal children (an OptionButton's popup, scroll bars) are the engine's, not this game's surfaces.
static func _controls(root: Control) -> Array[Control]:
	var found: Array[Control] = [root]
	for child: Node in root.get_children():
		if child is Control: found.append_array(_controls(child))
	return found

static func _text_controls(root: Control) -> Array[Control]:
	return _controls(root).filter(func(control: Control) -> bool: return control is Label or control is BaseButton or control is LineEdit or control is TextEdit)

func _check_small(runner, root: Control, view: Rect2, label: String) -> void:
	var controls: Array[Control] = _text_controls(root)
	runner.check(not controls.is_empty(), "TH5 %s has text controls" % label)
	for control: Control in controls:
		# A local override is a deliberate step on the scale, such as the focus card's 30 px title.
		if not control.has_theme_font_size_override("font_size"): runner.check(control.get_theme_font_size("font_size") == SMALL, "TH5 %s %s is %d px, got %d" % [label, control.name, SMALL, control.get_theme_font_size("font_size")])
		var shown: Rect2 = _clip(control).get_global_rect()
		if control.is_visible_in_tree(): runner.check(view.encloses(shown), "TH5 %s %s inside the view, rect %s" % [label, control.name, shown])

# Rows scrolled out of a ScrollContainer are clipped, so the container is what must fit the view.
static func _clip(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node is Control:
		if node is ScrollContainer: return node
		node = node.get_parent()
	return control

func test_match_surfaces_keep_their_size(runner) -> bool:
	var overlay = OverlayTests.new()
	var saved: String = overlay._begin()
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	runner.root.add_child(port)
	var view := Rect2(Vector2.ZERO, Vector2(port.size))
	var main = await overlay._scene(runner, Skirmish, port)
	overlay._camera(main)
	main.orders.selected_ids.assign([overlay._own_unit(main)])
	main._refresh()
	main.get_node("HUD/Playtest").open_marker()
	main.get_node("HUD/PerfOverlay").toggle()
	await runner.process_frame
	await runner.process_frame
	runner.check(main.get_node("HUD/PerfOverlay").theme_type_variation == &"HudSmallNumber" and main.get_node("HUD/Status").theme_type_variation == &"HudSmallNumber", "TH5 the F3 overlay and the status line print tabular digits")
	for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog", "HUD/PerfOverlay"]:
		var surface: Control = main.get_node(path)
		runner.check(surface.is_visible_in_tree(), "TH5 %s is shown" % path)
		_check_small(runner, surface, view, path)
	# The slab left the 12 px surfaces at Task 9 (owner question 4): its sizes are the type scale's.
	for control: Control in _text_controls(main.get_node("HUD/Economy")):
		runner.check(control.get_theme_font_size("font_size") in TYPE_SCALE, "TH5 HUD/Economy %s is on the type scale, got %d" % [control.name, control.get_theme_font_size("font_size")])
		if control.is_visible_in_tree(): runner.check(view.encloses(_clip(control).get_global_rect()), "TH5 HUD/Economy %s inside the view" % control.name)
	_square_rows(runner, ["Produce", "CancelBuild", "QueueMore"].map(func(path: String) -> Button: return main.get_node("HUD/Economy/" + path)), "TH5")
	main.get_node("HUD/PauseMenu").open()
	await runner.process_frame
	_check_small(runner, main.get_node("HUD/PauseMenu"), view, "HUD/PauseMenu")
	port.free()
	var card_port := SubViewport.new()
	card_port.size = Vector2i(1280, 720)
	runner.root.add_child(card_port)
	var focus_card := FocusCardView.new(FocusCards.load_cards())
	card_port.add_child(focus_card)
	focus_card.visible = true
	await runner.process_frame
	_check_small(runner, focus_card, view, "focus card")
	var popup: PopupMenu = focus_card.get_node("Box/Picker").get_popup()
	runner.check(popup.get_theme_font_size("font_size") == SMALL, "TH5 the focus card picker's list is %d px, got %d" % [SMALL, popup.get_theme_font_size("font_size")])
	card_port.free()
	overlay._end(saved)
	return true

static func _part(hud: Node, box: String, part: String) -> Control:
	return hud.get_node(box).find_child(part, true, false)

static func _token(name: String) -> Color:
	return ThemeDB.get_project_theme().get_color(name, &"Tokens")

static func _colour(label: Label) -> Color:
	return label.get_theme_color("font_color")

static func _strip_view(credits: int, used: int, available: int, faction: String = "usa") -> Dictionary:
	var view: Dictionary = Fixture.make_world(credits).view_state()
	view.players[0].merge({"power_demand": used, "power_supply": available, "faction": faction}, true)
	return view

static func _armed(kind: String, bright: bool = false, notice: String = "") -> Dictionary:
	var ids: Array[int] = []
	return {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": kind, "resume_id": -1, "notice": notice, "production_kind": "", "bright_owners": bright, "over": false, "esc_opens_menu": true, "attack_move": false}

func _bare_hud(runner) -> Hud:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	runner.root.add_child(port)
	var hud := Hud.new()
	port.add_child(hud)
	hud.setup(null, null)
	return hud

func _show(runner, hud: Hud, view: Dictionary, kind: String = "", player: int = 1, bright: bool = false) -> void:
	hud.update_hud(view, _armed(kind, bright), player, player)
	await runner.process_frame

static func _texts(hud: Node, box: String) -> Array:
	return ["Credits", "Power", "LowPower"].map(func(part: String) -> String: return _part(hud, box, part).text if _part(hud, box, part).is_visible_in_tree() else "")

func test_power_reads_used_over_available(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	await _show(runner, hud, _strip_view(4800, 8, 10))
	var power: Label = _part(hud, "TopStrip", "Power")
	var low: Label = _part(hud, "TopStrip", "LowPower")
	runner.check(power.text == "8 / 10" and _colour(power) == _token("text") and not low.is_visible_in_tree(), "TS1 8 used of 10 reads 8 / 10 in text, no low power, got '%s'" % power.text)
	await _show(runner, hud, _strip_view(4800, 12, 10))
	runner.check(power.text == "12 / 10" and _colour(power) == _token("warn"), "TS1 12 used of 10 reads 12 / 10 in warn, got '%s'" % power.text)
	runner.check(low.is_visible_in_tree() and low.text == LOW and _colour(low) == _token("warn"), "TS1 low power names its effect in warn, got '%s'" % low.text)
	await _show(runner, hud, _strip_view(4800, 8, 10))
	var before: Array = _texts(hud, "TopStrip")
	await _show(runner, hud, _strip_view(4800, 8, 10), "china_defence")
	runner.check(_texts(hud, "TopStrip") == before, "TS1 arming a building never changes the strip, got %s" % [_texts(hud, "TopStrip")])
	hud.get_parent().free()
	return true

func _no_arrow_or_short(runner, hud: Hud, label: String) -> void:
	for found: Node in hud.find_children("*", "Label", true, false):
		var text: String = (found as Label).text
		if (found as Label).is_visible_in_tree(): runner.check(not text.contains("→") and not text.contains("short"), "TS2 %s: no arrow and no 'short' in '%s'" % [label, text])

func test_forecast_forms(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var card: Control = hud.get_node("Forecast")
	await _show(runner, hud, _strip_view(4800, 8, 10), "china_defence")
	var credits: Label = _part(hud, "Forecast", "Credits")
	var power: Label = _part(hud, "Forecast", "Power")
	var low: Label = _part(hud, "Forecast", "LowPower")
	runner.check(_part(hud, "TopStrip", "Credits").text == "4800" and card.visible and _part(hud, "Forecast", "Title").text == "AFTER PURCHASE", "TS2 a Rotary Gun Tower armed: the strip keeps 4800 and the card shows")
	runner.check(credits.text == "3600" and _colour(credits) == _token("text"), "TS2 credits after purchase 3600 in text, got '%s'" % credits.text)
	runner.check(power.text == "11 / 10" and _colour(power) == _token("warn") and low.is_visible_in_tree() and low.text == LOW and _colour(low) == _token("warn"), "TS2 power after purchase 11 / 10 and low power in warn, got %s" % [_texts(hud, "Forecast")])
	_no_arrow_or_short(runner, hud, "tower")
	await _show(runner, hud, _strip_view(4800, 8, 10), "usa_power_plant")
	runner.check(credits.text == "4000" and power.text == "8 / 15" and _colour(power) == _token("text") and not low.is_visible_in_tree(), "TS2 a Power Plant armed reads 4000 and 8 / 15, no low power, got %s" % [_texts(hud, "Forecast")])
	await _show(runner, hud, _strip_view(10650, 8, 10))
	runner.check(_part(hud, "TopStrip", "Credits").text == "10650" and not card.visible, "TS2 five-digit credits print plain, nothing armed hides the card, got '%s'" % _part(hud, "TopStrip", "Credits").text)
	await _show(runner, hud, _strip_view(500, 8, 10), "china_defence")
	runner.check(credits.text == MINUS + "700" and _colour(credits) == _token("warn"), "TS2 the shortfall reads −700 with U+2212 in warn, got '%s'" % credits.text)
	_no_arrow_or_short(runner, hud, "shortfall")
	for armed: String in ["", "frc_barracks"]:
		await _show(runner, hud, _strip_view(4800, 0, 0, "frc"), armed)
		var shown: Array = ["PowerLabel", "Power", "LowPower"].filter(func(part: String) -> bool: return _part(hud, "TopStrip", part).is_visible_in_tree() or _part(hud, "Forecast", part).is_visible_in_tree())
		runner.check(shown.is_empty() and _part(hud, "TopStrip", "Credits").is_visible_in_tree(), "TS2 FRC uses no power, so no power group (armed '%s'), shown %s" % [armed, shown])
	runner.check(credits.text == "4300" and card.visible, "TS2 FRC's card keeps its credits, got '%s'" % credits.text)
	hud.get_parent().free()
	await _forecast_follows_the_placement(runner)
	return true

func _forecast_follows_the_placement(runner) -> void:
	var helper = BaseScene.new()
	var main = await helper.setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	var card: Control = main.get_node("HUD/Hud/Forecast")
	helper.key(main, KEY_1)
	runner.check(card.visible, "TS2 arming a building shows the card")
	helper.key(main, KEY_ESCAPE)
	runner.check(not card.visible, "TS2 cancelling the placement hides the card")
	helper.key(main, KEY_1)
	helper.hover(main, Iso.world_to_plane(Vector2(8.25, 4.25)))
	helper.pointer(main, Iso.world_to_plane(Vector2(8.25, 4.25)), MOUSE_BUTTON_LEFT, false)
	BaseScene.tick(main)
	runner.check(main.orders._placement_kind.is_empty() and not card.visible, "TS2 placing the building hides the card")
	main.free()
	var skirmish = SkirmishTests.new()
	main = await skirmish._setup(runner)
	skirmish._arena(main)
	main.orders._placement_kind = "usa_power_plant"
	main._refresh()
	runner.check(main.get_node("HUD/Hud/Forecast").visible, "TS2 the arena shows the card while armed")
	skirmish._victory(main)
	runner.check(main.shown_over() and main.orders._placement_kind.is_empty() and not main.get_node("HUD/Hud/Forecast").visible, "TS2 the match ending clears the placement and hides the card")
	main.free()
	var online: Dictionary = await OverlayTests.new()._online(runner)
	main = online.main
	main.orders._placement_kind = "usa_power_plant"
	main._refresh()
	runner.check(main.get_node("HUD/Hud/Forecast").visible, "TS2 online: the card shows while armed")
	main.driver._finished = true
	main._refresh()
	runner.check(main.orders._placement_kind.is_empty() and not main.get_node("HUD/Hud/Forecast").visible, "TS2 an online lockstep ending clears the placement and hides the card")
	main.free()

func test_swatch_slot_colour(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var swatch: ColorRect = _part(hud, "TopStrip", "Swatch")
	for row: Array in [[1, false], [2, false], [1, true]]:
		var view: Dictionary = _strip_view(4800, 8, 10)
		view.players[0].id = row[0]
		await _show(runner, hud, view, "", row[0], row[1])
		runner.check(swatch.color == View.owner_color(row[0], row[1]), "TS3 player %d (bright %s) gets its owner colour, got %s" % [row[0], row[1], swatch.color])
	hud.update_hud(_strip_view(4800, 8, 10), _armed(""), 2, 1)
	runner.check(swatch.color == View.owner_color(2), "TS3 the swatch follows the viewed player, not the seat, got %s" % swatch.color)
	var box: Rect2 = swatch.get_global_rect()
	var gap: float = _part(hud, "TopStrip", "CreditsLabel").get_global_rect().position.x - box.end.x
	runner.check(box.size == Vector2(8, 8) and is_equal_approx(gap, 8.0), "TS3 the swatch is 8x8, 8 px left of CREDITS, got %s gap %.1f" % [box.size, gap])
	hud.get_parent().free()
	return true

func test_strip_anchor_without_tick(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view_rect := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await OverlayTests.new()._scene(runner, Skirmish, port)
		main.hud.update_hud(_strip_view(500, 8, 10), _armed("china_defence"), 1, 1)
		await runner.process_frame
		var strip: Rect2 = main.get_node("HUD/Hud/TopStrip").get_global_rect()
		var card: Rect2 = main.get_node("HUD/Hud/Forecast").get_global_rect()
		runner.check(strip.position == Vector2(8, 8) and strip.size.y == 32.0 and view_rect.encloses(strip), "TS4 the strip sits at (8, 8), 32 high, inside the view at %s, got %s" % [size, strip])
		runner.check(card.position == Vector2(8, 48) and view_rect.encloses(card) and not card.intersects(strip), "TS4 the longest card sits at (8, 48) inside the view, clear of the strip at %s, got %s" % [size, card])
		main.hud.update_hud(_strip_view(4800, 12, 10), _armed(""), 1, 1)
		await runner.process_frame
		strip = main.get_node("HUD/Hud/TopStrip").get_global_rect()
		runner.check(view_rect.encloses(strip) and strip.size.y == 32.0, "TS4 the strip with low power stays 32 high inside the view at %s, got %s" % [size, strip])
		var text: String = BaseScene.hud_text(main)
		runner.check(not text.contains("Tick") and not text.contains("You are"), "TS4 no tick and no seat line in the HUD at %s" % size)
		port.free()
	return true

func test_strip_patches_values(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	await _show(runner, hud, _strip_view(500, 8, 10), "china_defence")
	var credits: Label = _part(hud, "Forecast", "Credits")
	var strip_credits: Label = _part(hud, "TopStrip", "Credits")
	for row: Array in [[500, MINUS + "700", "warn"], [1000, MINUS + "200", "warn"], [1500, "300", "text"]]:
		await _show(runner, hud, _strip_view(row[0], 8, 10), "china_defence")
		runner.check(strip_credits.text == str(row[0]) and credits.text == row[1] and _colour(credits) == _token(row[2]), "TS5 %d credits patch the strip and the card to %s in %s, got '%s'" % [row[0], row[1], row[2], credits.text])
	runner.check(_part(hud, "TopStrip", "Credits") == strip_credits and _part(hud, "Forecast", "Credits") == credits, "TS5 patching values keeps the same labels")
	var changes: Array[int] = [0]
	for box: String in ["TopStrip", "Forecast"]:
		for part: String in ["Credits", "Power", "LowPower"]: _part(hud, box, part).theme_changed.connect(func() -> void: changes[0] += 1)
	for i in 2: await _show(runner, hud, _strip_view(1500, 12, 10), "china_defence")
	changes[0] = 0
	await _show(runner, hud, _strip_view(1500, 12, 10), "china_defence")
	runner.check(changes[0] == 0, "TS5 an unchanged update touches no label theme, got %d theme changes" % changes[0])
	hud.get_parent().free()
	return true

static func _longest_card() -> Dictionary:
	var longest: Dictionary = {}
	for card: Dictionary in FocusCards.load_cards():
		if JSON.stringify(card).length() > JSON.stringify(longest).length(): longest = card
	return longest

static func _frames(runner) -> void:
	for i in 3: await runner.process_frame

static func _rect(main, path: String) -> Rect2:
	return main.get_node(path).get_global_rect()

static func _right_edge(runner, rect: Rect2, right: float, top: float, label: String) -> void:
	runner.check(is_equal_approx(rect.end.x, right) and is_equal_approx(rect.position.y, top), "%s: right edge %.1f, top %.1f, got %s" % [label, right, top, rect])

# F3 against every open helper surface and the slab top minus 8 (gate A, user 2026-11-19).
static func _f3_clear(runner, main, view: Rect2, floor_y: float, label: String) -> void:
	var f3: Rect2 = _rect(main, "HUD/PerfOverlay")
	runner.check(view.encloses(f3) and f3.end.y <= floor_y - 8.0, "CH1 %s: F3 inside the view and above the slab top minus 8 (%.0f), got %s" % [label, floor_y - 8.0, f3])
	for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog"]:
		if main.get_node(path).visible: runner.check(not f3.intersects(_rect(main, path)), "CH1 %s: F3 clear of %s, F3 %s, panel %s" % [label, path.get_file(), f3, _rect(main, path)])

func test_chip_stack(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var right: float = size.x - 8.0
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		overlays._camera(main)
		var overlay = main.get_node("HUD/Playtest")
		var chip: Button = overlay.get_node("Chip")
		main.get_node("HUD/PerfOverlay").toggle()
		await _frames(runner)
		var at: String = " at %s" % size
		var menu: Rect2 = _rect(main, "HUD/MenuChip")
		_right_edge(runner, menu, right, 8.0, "CH1 Menu" + at)
		runner.check(menu.size.y == 32.0 and chip.visible and chip.get_global_rect().size.y == 32.0, "CH1 Menu and Playtest are 32 high%s, got %s and %s" % [at, menu, chip.get_global_rect()])
		_right_edge(runner, chip.get_global_rect(), right, 48.0, "CH1 Playtest" + at)
		runner.check(chip.find_child("Label", true, false).text == "PLAYTEST" and chip.find_child("Count", true, false).text == "0 / %d" % _longest_card().try.size(), "CH1 the chip reads PLAYTEST and ticked over total%s" % at)
		# The slab now always hands its top; the stack's own rules below start from an empty floor.
		overlay.set_floor(size.y)
		await _frames(runner)
		var checklist: Rect2 = _rect(main, "HUD/Playtest/Checklist")
		runner.check(overlay.get_node("Checklist").visible, "CH1 the helper opens the checklist at the start%s" % at)
		_right_edge(runner, checklist, right, 88.0, "CH1 checklist" + at)
		_right_edge(runner, _rect(main, "HUD/PerfOverlay"), right, checklist.end.y + 8.0, "CH1 F3 below the checklist" + at)
		chip.pressed.emit()
		await _frames(runner)
		runner.check(not overlay.get_node("Checklist").visible, "CH1 a press on the chip closes the checklist%s" % at)
		_right_edge(runner, _rect(main, "HUD/PerfOverlay"), right, 88.0, "CH1 F3 with nothing open" + at)
		chip.pressed.emit()
		await _frames(runner)
		runner.check(overlay.get_node("Checklist").visible, "CH1 a second press opens it again%s" % at)
		overlay.open_marker()
		await _frames(runner)
		var form: Rect2 = _rect(main, "HUD/Playtest/MarkerDialog")
		runner.check(overlay.get_node("MarkerDialog").visible and not form.intersects(checklist) and view.encloses(form), "CH1 checklist and note form both shown, disjoint, the form inside the view%s, form %s checklist %s" % [at, form, checklist])
		_right_edge(runner, form, right, checklist.end.y + 8.0, "CH1 the form below the checklist" + at)
		_right_edge(runner, _rect(main, "HUD/PerfOverlay"), right, form.end.y + 8.0, "CH1 F3 below the form" + at)
		_f3_clear(runner, main, view, size.y, "no slab" + at)
		overlay.cancel_marker()
		for slab: Array in [[204, "China builder"], [282, "nine queued, collapsed"], [462, "nine queued, open"]]:
			await _f3_rule(runner, main, view, size.y - slab[0], slab[1] + at)
		overlay.set_floor(size.y)
		overlay.set_active(false)
		await _frames(runner)
		runner.check(not chip.visible and not overlay.get_node("Checklist").visible, "CH1 helper off: no chip, no checklist%s" % at)
		_right_edge(runner, _rect(main, "HUD/PerfOverlay"), right, 48.0, "CH1 helper off: F3 under Menu" + at)
		port.free()
	overlays._end(saved)
	return true

# The stack does not fit above these slab tops, so F3 and the form go beside the panels.
func _f3_rule(runner, main, view: Rect2, floor_y: float, label: String) -> void:
	var overlay = main.get_node("HUD/Playtest")
	overlay.set_floor(floor_y)
	await _frames(runner)
	var checklist: Rect2 = _rect(main, "HUD/Playtest/Checklist")
	runner.check(checklist.end.y <= floor_y - 8.0 and checklist.position.y == 88.0, "CH1 %s: the checklist stops 8 above the slab top %.0f, got %s" % [label, floor_y, checklist])
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), checklist.position.x - 8.0, 88.0, "CH1 %s: F3 left of the checklist" % label)
	_f3_clear(runner, main, view, floor_y, label)
	overlay.open_marker()
	await _frames(runner)
	var form: Rect2 = _rect(main, "HUD/Playtest/MarkerDialog")
	_right_edge(runner, form, checklist.position.x - 8.0, 88.0, "CH1 %s: the form left of the checklist" % label)
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), form.end.x, form.end.y + 8.0, "CH1 %s: F3 under the form" % label)
	_f3_clear(runner, main, view, floor_y, label + ", form left")
	overlay.toggle_checklist()
	await _frames(runner)
	form = _rect(main, "HUD/Playtest/MarkerDialog")
	var f3: Rect2 = _rect(main, "HUD/PerfOverlay")
	_right_edge(runner, form, view.size.x - 8.0, 88.0, "CH1 %s, checklist closed: the form under the chip" % label)
	if form.end.y + 8.0 + f3.size.y <= floor_y - 8.0: _right_edge(runner, f3, view.size.x - 8.0, form.end.y + 8.0, "CH1 %s, checklist closed: F3 below the form" % label)
	_f3_clear(runner, main, view, floor_y, label + ", checklist closed, form open")
	overlay.set_floor(form.end.y + 8.0 + f3.size.y + 7.0)
	await _frames(runner)
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), form.position.x - 8.0, 88.0, "CH1 %s, checklist closed: F3 left of the form when it does not fit below" % label)
	_f3_clear(runner, main, view, form.end.y + 8.0 + f3.size.y + 7.0, label + ", F3 left of the form")
	overlay.set_floor(form.end.y + f3.size.y + 16.0)
	await _frames(runner)
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), view.size.x - 8.0, form.end.y + 8.0, "CH1 %s, checklist closed: F3 below the form when it just fits" % label)
	overlay.set_floor(floor_y)
	overlay.cancel_marker()
	await _frames(runner)
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), view.size.x - 8.0, 88.0, "CH1 %s, nothing open: F3 under the chip" % label)
	overlay.toggle_checklist()
	await _frames(runner)

# `frame`: a real frame runs the screen's `_process`, which keeps the chip current between views.
func _esc_matches_chip(runner, main, label: String, shown: bool, frame: bool = false) -> void:
	if frame:
		main.set_process(true)
		await runner.process_frame
		main.set_process(false)
	else: main._show_esc_chip()
	var esc: Control = main.get_node("HUD/MenuChip").find_child("EscChip", true, false)
	var promised: bool = esc.visible
	runner.check(promised == shown, "CH2 %s: the Esc chip %s" % [label, "shows" if shown else "hides"])
	OverlayTests.new()._key(runner, KEY_ESCAPE)
	var pause: Control = main.get_node("HUD/PauseMenu")
	runner.check(pause.visible == promised, "CH2 %s: Esc %s the menu, as the chip said" % [label, "opened" if pause.visible else "did not open"])
	if pause.visible: pause.close()
	main._show_esc_chip()

func test_esc_chip_only_when_esc_opens_the_menu(runner) -> bool:
	var overlays = OverlayTests.new()
	var helper = BaseScene.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	var main = await overlays._scene(runner, Skirmish)
	overlays._camera(main)
	var own: int = overlays._own_unit(main)
	var enemy: int = main.driver.pump.live().snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 2)[0].id
	await _esc_matches_chip(runner, main, "nothing pending", true)
	main.orders.selected_ids.assign([own])
	main._refresh()
	await _esc_matches_chip(runner, main, "a selection", false)
	await _esc_matches_chip(runner, main, "after Esc backed out of the selection", true)
	main.orders._placement_kind = "usa_power_plant"
	main._refresh()
	await _esc_matches_chip(runner, main, "an armed placement", false)
	main.orders.inspected_id = enemy
	main._refresh()
	await _esc_matches_chip(runner, main, "an inspected enemy", false)
	helper.pointer(main, Vector2.ZERO, MOUSE_BUTTON_LEFT, true)
	await _esc_matches_chip(runner, main, "a drag", false)
	main.get_node("HUD/Playtest").open_marker()
	await _esc_matches_chip(runner, main, "the note form open, after a frame", false, true)
	await _frames(runner)
	var field: LineEdit = main.get_node("HUD/Playtest/Checklist").find_children("*", "LineEdit", true, false)[0]
	runner.check(field.is_visible_in_tree(), "CH2 fixture: the checklist and its field are shown")
	field.grab_focus()
	await _esc_matches_chip(runner, main, "focus in a checklist field, after a frame", false, true)
	await _esc_matches_chip(runner, main, "the field let go", true)
	main.orders.selected_ids.assign([own])
	overlays._end_offline(main)
	main.get_viewport().gui_release_focus()
	await _esc_matches_chip(runner, main, "the match ended with a selection held", true)
	main.free()
	overlays._end(saved)
	return true

static func _click(runner, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		runner.root.push_input(event)

func test_menu_chip_opens_the_menu(runner) -> bool:
	var skirmish = SkirmishTests.new()
	var main = await skirmish._setup(runner)
	skirmish._arena(main)
	var chip: Button = main.get_node("HUD/MenuChip")
	var pause: Control = main.get_node("HUD/PauseMenu")
	runner.check(chip.theme_type_variation == &"HudChip" and chip.focus_mode == Control.FOCUS_NONE and chip.find_child("Label", true, false).text == "Menu", "CH3 Menu is a HudChip that takes no focus")
	_click(runner, chip.get_global_rect().get_center())
	runner.check(pause.visible, "CH3 a click on Menu opens the pause menu")
	pause.close()
	skirmish._victory(main)
	await runner.process_frame
	runner.check(main.shown_over() and main.get_node("HUD/ResultPanel").visible, "CH3 fixture: the Victory card is up")
	_click(runner, chip.get_global_rect().get_center())
	runner.check(pause.visible, "CH3 a click on Menu over the Victory card opens the pause menu")
	main.free()
	return true

# A notice wider than the cap wraps, so it grows down instead of across the chips.
func _notice_clear(runner, main, label: String, others: Array, lines: int = 1) -> Rect2:
	var notice: Rect2 = _rect(main, "HUD/Hud/Notice")
	var view: Rect2 = main.get_viewport().get_visible_rect()
	var text: Rect2 = _rect(main, "HUD/Hud/Notice/Text")
	runner.check(absf(notice.get_center().x - view.size.x / 2.0) <= 1.0 and notice.position.y == 48.0 and view.encloses(notice) and notice.size.x <= 600.0 and notice.encloses(text), "CH4 %s: the notice is centred at top 48, at most 600 wide, its text inside, got %s" % [label, notice])
	var one_line: bool = notice.size.y == 28.0
	runner.check(one_line == (lines == 1) and (main.get_node("HUD/Hud/Notice/Text") as Label).get_line_count() == lines, "CH4 %s: %d line(s), 28 high for one, got %s" % [label, lines, notice])
	for path: String in others:
		var node: Control = main.get_node(path)
		runner.check(node.is_visible_in_tree() and not notice.intersects(node.get_global_rect()), "CH4 %s: the notice clears %s, notice %s, other %s" % [label, path.get_file(), notice, node.get_global_rect()])
	return notice

func test_online_notice_top_centre(runner) -> bool:
	var overlays = OverlayTests.new()
	var online = OnlineTests.new()
	var saved: String = overlays._begin()
	var bare: Hud = _bare_hud(runner)
	await _show(runner, bare, _strip_view(4800, 8, 10))
	var quiet: Control = bare.get_node("Notice")
	runner.check(not quiet.visible and quiet.mouse_filter == Control.MOUSE_FILTER_IGNORE and quiet.get_node("Text").mouse_filter == Control.MOUSE_FILTER_IGNORE, "CH4 no notice: hidden, and it never catches the mouse")
	bare.get_parent().free()
	var waiting: Dictionary = await online._online(runner, 2)
	var main = waiting.main
	main.orders._placement_kind = "usa_power_plant"
	online._run(main, 12)
	var label: Label = main.get_node("HUD/Hud/Notice").find_child("Text", true, false)
	runner.check(main.driver.notice() == "Waiting for player 1" and label.is_visible_in_tree() and label.text == "Waiting for player 1" and _colour(label) == _token("muted"), "CH4 the waiting notice shows in muted, got '%s'" % label.text)
	runner.check(main.get_node("HUD/Hud/Forecast").visible and main.orders.busy(), "CH4 fixture: a building armed while the notice shows")
	runner.check(not main.get_node("HUD/Status").text.contains("Waiting") and BaseScene.hud_text(main).contains("Waiting for player 1"), "CH4 the notice left HUD/Status")
	var chips: Array = ["HUD/Hud/TopStrip", "HUD/MenuChip", "HUD/Playtest/Chip"]
	for strip: Array in [[8, "the longest card"], [12, "low power in the strip"]]:
		main.hud.update_hud(_strip_view(500, strip[0], 10), _armed("china_defence", false, main.driver.notice()), 1, 1)
		await _frames(runner)
		_notice_clear(runner, main, strip[1], chips + ["HUD/Hud/Forecast"])
	runner.check(_part(main.hud, "Forecast", "Credits").text == MINUS + "700" and _part(main.hud, "TopStrip", "LowPower").is_visible_in_tree(), "CH4 fixture: the card's longest form and the strip's low power")
	main.free()
	await _ended_notice(runner, online, 1, func(lockstep, _transport) -> void: lockstep.receive('{"type":"left","seat":2,"after_tick":3}'), "Opponent left before the start (a different map or version, or their game tab was hidden)")
	await _ended_notice(runner, online, 2, func(_lockstep, transport) -> void: transport.frames.append(OnlineTests.Wire.encode(OnlineTests.Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"}))), "Desync", 2)
	DirAccess.remove_absolute("user://desync/desync-seat2.json")
	var closed: Dictionary = await online._online(runner, 2)
	online._end_match(closed)
	closed.transport.is_closed = true
	online._run(closed.main, 2)
	runner.check(closed.main.shown_over() and closed.main.driver.notice() == "Connection to relay lost", "CH4 fixture: a won match, then the relay is lost")
	runner.check(not closed.main.get_node("HUD/Hud/Notice").visible and not BaseScene.hud_text(closed.main).contains("Connection to relay lost"), "CH4 under the result card the notice hides (the card says why)")
	closed.main.free()
	overlays._end(saved)
	return true

# The match ending clears an armed building, so an ended match's notice meets only the strip and the chips.
func _ended_notice(runner, online, seat: int, end: Callable, words: String, lines: int = 1) -> void:
	var ended: Dictionary = await online._online(runner, seat)
	var main = ended.main
	main.orders._placement_kind = "usa_power_plant"
	end.call(ended.lockstep, ended.transport)
	online._run(main, 12)
	await _frames(runner)
	var label: Label = main.get_node("HUD/Hud/Notice").find_child("Text", true, false)
	runner.check(main.driver.over() and label.is_visible_in_tree() and label.text.begins_with(words), "CH4 %s: the ended match shows its notice, got '%s'" % [words, label.text])
	runner.check(not main.get_node("HUD/Hud/Forecast").visible and not main.orders.busy(), "CH4 %s: the ending cleared the armed building" % words)
	runner.check(not main.get_node("HUD/Status").text.contains(words) and BaseScene.hud_text(main).contains(words), "CH4 %s: the notice left HUD/Status" % words)
	_notice_clear(runner, main, words, ["HUD/Hud/TopStrip", "HUD/MenuChip", "HUD/Playtest/Chip", "HUD/Playtest/Checklist"], lines)
	main.free()

func test_stack_follows_size_changes(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await overlays._scene(runner, Skirmish)
	overlays._camera(main)
	var overlay = main.get_node("HUD/Playtest")
	var perf: Label = main.get_node("HUD/PerfOverlay")
	var list: Control = overlay.get_node("Checklist")
	perf.toggle()
	overlay.open_marker()
	overlay.set_floor(720.0)
	await _frames(runner)
	var before: Rect2 = list.get_global_rect()
	runner.check(list.visible and not list.find_child("Saved", true, false).visible, "CH1 fixture: the checklist open, nothing saved yet")
	(list.find_children("*", "CheckBox", true, false)[0] as CheckBox).button_pressed = true
	await _frames(runner)
	var grown: Rect2 = list.get_global_rect()
	var form: Rect2 = _rect(main, "HUD/Playtest/MarkerDialog")
	runner.check(list.find_child("Saved", true, false).visible and grown.size.y > before.size.y, "CH1 fixture: the first tick shows Saved and the checklist grows, %s to %s" % [before, grown])
	_right_edge(runner, form, 1272.0, grown.end.y + 8.0, "CH1 the form follows the grown checklist")
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), 1272.0, form.end.y + 8.0, "CH1 F3 follows the form")
	overlay.cancel_marker()
	await _frames(runner)
	var f3: Rect2 = _rect(main, "HUD/PerfOverlay")
	overlay.set_floor(grown.end.y + f3.size.y + 24.0)
	await _frames(runner)
	_right_edge(runner, _rect(main, "HUD/PerfOverlay"), 1272.0, grown.end.y + 8.0, "CH1 F3 just fits below the checklist")
	perf.extra = func() -> String: return "Cmd latency p95 0 ms | RTT p95 0 ms"
	perf.refresh_text()
	await _frames(runner)
	var taller: Rect2 = _rect(main, "HUD/PerfOverlay")
	runner.check(taller.size.y > f3.size.y, "CH1 fixture: the net line makes F3 taller, %s to %s" % [f3, taller])
	_right_edge(runner, taller, grown.position.x - 8.0, 88.0, "CH1 F3 grown past the floor moves beside the checklist")
	main.free()
	overlays._end(saved)
	return true

static func _queued(main, type: String) -> Array:
	return main.driver.queued().filter(func(command: Dictionary) -> bool: return command.type == type)

static func _shown(main, path: String) -> bool:
	var node: Node = main.get_node_or_null("HUD/Economy/" + path)
	return node != null and (node as CanvasItem).is_visible_in_tree()

static func _select(main, ids: Array, building: int = -1, inspected: int = -1) -> void:
	main.orders.selected_ids.assign(ids)
	main.orders.selected_building_id = building
	main.orders.inspected_id = inspected
	main._refresh()

# Own China units and buildings beside the fixture's USA builder (id 1); `loaded` puts a rifleman in the hub and one in the car.
func _slab_world(runner, main, loaded: bool, credits: int = 50000) -> Dictionary:
	var sim = Fixture.make_world(credits)
	sim.add_player(2, 1000)
	var ids := {"usa_builder": 1}
	ids.builder = sim.spawn(1, Vector2(6.5, 6.5), "china_builder")
	ids.frc_builder = sim.spawn(1, Vector2(6.5, 8.5), "frc_builder")
	ids.tanks = [sim.spawn(1, Vector2(8.5, 6.5), "china_tank"), sim.spawn(1, Vector2(9.5, 6.5), "china_tank")]
	ids.infantry = sim.spawn(1, Vector2(10.5, 6.5), "china_rifle_infantry")
	ids.collectors = [sim.spawn(1, Vector2(8.5, 9.5), "china_collector"), sim.spawn(1, Vector2(9.5, 9.5), "china_collector")]
	ids.enemy = sim.spawn(2, Vector2(28.5, 28.5), "usa_tank")
	ids.pile = sim.add_supply_source(Vector2i(26, 4), 10)
	ids.factory = Fixture.add_completed(sim, 1, "china_factory", Vector2i(14, 14))
	ids.barracks = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(20, 14))
	ids.plant = Fixture.add_completed(sim, 1, "china_power_plant", Vector2i(24, 20))
	ids.hub = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(18, 4))
	ids.car = sim.spawn(1, Vector2(12.5, 4.5), "usa_light_vehicle")
	if loaded:
		Fixture.load_unit(runner, sim, sim.spawn(1, Vector2(17.5, 4.5), "frc_rifle_infantry"), ids.hub)
		Fixture.load_unit(runner, sim, sim.spawn(1, Vector2(12.5, 5.5), "usa_rifle_infantry"), ids.car)
	main.driver.adopt(sim)
	main._refresh()
	return ids

# The slab's content rect: padding 8, 12 on the left (hud-v5-layout "Command card").
static func _content(main) -> Rect2:
	return _rect(main, "HUD/Economy").grow_individual(-12.0, -8.0, -8.0, -8.0)

# "No label cut": every shown label inside its row and the slab's content rect.
func _contained(runner, main, view: Rect2, label: String) -> void:
	var content: Rect2 = _content(main)
	for control: Control in _controls(main.get_node("HUD/Economy")):
		if not control.is_visible_in_tree() or control.name == "Economy": continue
		var rect: Rect2 = control.get_global_rect()
		runner.check(view.encloses(rect) and content.grow(0.5).encloses(rect), "SL2 %s: %s inside the slab content %s and the view, got %s" % [label, control.name, content, rect])
		if control is Label and control.get_parent() is Button: runner.check(control.get_parent().get_global_rect().grow(0.5).encloses(rect), "SL2 %s: %s inside its row" % [label, control.name])
	for button: Node in main.get_node("HUD/Economy/BuildMenu").get_children():
		if (button as Button).is_visible_in_tree():
			var name_end: float = button.get_global_rect().position.x + 12.0 + button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			runner.check(name_end <= button.get_node("Price").get_global_rect().position.x, "SL2 %s: '%s' ends before its price" % [label, button.text])

func test_slab_rect(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		main.hud._show_notice("Waiting for player 1")
		await _frames(runner)
		var slab: Rect2 = _rect(main, "HUD/Economy")
		var at: String = " at %s" % size
		runner.check(absf(slab.position.x - (size.x - 432.0)) <= 1.0 and is_equal_approx(slab.size.x, 432.0) and is_equal_approx(slab.end.y, size.y) and view.encloses(slab), "SL1 the slab is x W-432, 432 wide, bottom on H, inside the view%s, got %s" % [at, slab])
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has("HUD/Hud/TopStrip") and panels.has("HUD/MenuChip") and panels.has("HUD/Hud/Notice"), "SL1 fixture: strip, Menu and a notice shown%s" % at)
		for path: String in panels:
			if path != "HUD/Economy" and path != "HUD/Status": runner.check(not slab.intersects(panels[path]), "SL1 the slab clears %s%s" % [path, at])
		var chip: Control = main.get_node("HUD/Playtest/Chip")
		runner.check(chip.is_visible_in_tree() and not slab.intersects(chip.get_global_rect()), "SL1 the Playtest chip shown and clear of the slab%s" % at)
		var rows: Array = main.get_node("HUD/Economy").get_children().filter(func(row: Control) -> bool: return row.visible)
		var first: Rect2 = (rows[0] as Control).get_global_rect()
		var last: Rect2 = (rows.back() as Control).get_global_rect()
		runner.check(is_equal_approx(first.position.x, slab.position.x + 12.0) and is_equal_approx(first.end.x, slab.end.x - 8.0) and is_equal_approx(first.position.y, slab.position.y + 8.0) and is_equal_approx(last.end.y, slab.end.y - 8.0), "SL1 rows sit inside 8 px padding, 12 on the left%s, first %s last %s slab %s" % [at, first, last, slab])
		runner.check(is_equal_approx(main._playtest._floor, slab.position.y), "SL1 the helper's floor is the slab top%s, got %s" % [at, main._playtest._floor])
		port.free()
	overlays._end(saved)
	return true

# A window resize moves the bottom-anchored slab without resizing it and brings no new view.
func test_floor_follows_a_resize(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	var port: SubViewport = BaseScene.sized_port(runner, Vector2i(1280, 800), Vector2i(1280, 800))
	var main = await overlays._scene(runner, Skirmish, port)
	overlays._camera(main)
	main.get_node("HUD/PerfOverlay").toggle()
	main.get_node("HUD/Playtest").open_marker()
	for pair: Array in [[Vector2i(1280, 720), Vector2i(1280, 720)], [Vector2i(3440, 1440), Vector2i(1720, 720)], [Vector2i(1280, 800), Vector2i(1280, 800)]]:
		port.size = pair[0]
		port.size_2d_override = pair[1]
		await _frames(runner)
		var slab: Rect2 = _rect(main, "HUD/Economy")
		runner.check(is_equal_approx(slab.end.y, pair[1].y) and is_equal_approx(main._playtest._floor, slab.position.y), "SL1 resized to %s with no new view: the floor follows the slab top %.0f, got %s" % [pair[1], slab.position.y, main._playtest._floor])
		for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog", "HUD/PerfOverlay"]: runner.check(not _rect(main, path).intersects(slab), "SL1 resized to %s: %s clear of the slab" % [pair[1], path.get_file()])
	port.free()
	overlays._end(saved)
	return true

# A nine-entry queue on the factory, set on the shown view only.
static func _nine(main, factory: int) -> void:
	var entries: Array = []
	for i in 9: entries.append({"id": 900 + i, "kind": ["china_tank", "china_light_vehicle"][i % 2], "paid_cost": 800, "work": 336000 if i == 0 else 0})
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, factory).queue = entries
	main._show(view)

func test_slab_china_with_overlays(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		overlays._camera(main)
		var ids: Dictionary = _slab_world(runner, main, false)
		var overlay = main.get_node("HUD/Playtest")
		main.get_node("HUD/PerfOverlay").toggle()
		overlay.open_marker()
		var states: Array = [["a lone China builder", [ids.builder], -1, "BuildMenu"], ["own tanks", ids.tanks, -1, "Orders"], ["nine queued, collapsed", [], ids.factory, "QueueMore"], ["nine queued, open", [], ids.factory, "QueueMore"]]
		for state: Array in states:
			var label: String = "%s at %s" % [state[0], size]
			_select(main, state[1], state[2])
			if state[2] != -1: _nine(main, ids.factory)
			if state[0].ends_with("open"): main.get_node("HUD/Economy/QueueMore").pressed.emit()
			await _frames(runner)
			runner.check(_shown(main, state[3]), "SL2 %s: %s shown" % [label, state[3]])
			if state[0].ends_with("open"): runner.check(main.get_node("HUD/Economy/QueueMore").text == "Show fewer", "SL2 %s: Show fewer showing" % label)
			_contained(runner, main, view, label)
			var slab: Rect2 = _rect(main, "HUD/Economy")
			var checklist: Rect2 = _rect(main, "HUD/Playtest/Checklist")
			for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog", "HUD/PerfOverlay"]:
				var rect: Rect2 = _rect(main, path)
				runner.check(main.get_node(path).is_visible_in_tree() and view.encloses(rect) and not rect.intersects(slab), "SL2 %s: %s shown, inside the view and clear of the slab, %s slab %s" % [label, path.get_file(), rect, slab])
				if path != "HUD/Playtest/Checklist": runner.check(not rect.intersects(checklist), "SL2 %s: %s clear of the checklist" % [label, path.get_file()])
			if state[2] == -1: continue
			var boxes: Array[Node] = overlay.get_node("Checklist").find_children("*", "CheckBox", true, false)
			var item: CheckBox = boxes.back()
			var scroll: ScrollContainer = overlay.get_node("Checklist").find_children("*", "ScrollContainer", true, false)[0]
			scroll.ensure_control_visible(item)
			await _frames(runner)
			var ticked: bool = item.button_pressed
			_click_in(port, item.get_global_rect().get_center())
			runner.check(item.button_pressed != ticked, "SL2 %s: the last checklist item takes a click" % label)
			var cancelled: Array[int] = []
			var record := func(id: int) -> void: cancelled.append(id)
			main.hud.entry_cancelled.connect(record)
			var rows: Array = main.get_node("HUD/Economy/Queue").get_children().filter(func(row: Control) -> bool: return row.visible)
			_click_in(port, (rows.back() as Control).get_global_rect().get_center())
			main.hud.entry_cancelled.disconnect(record)
			runner.check(cancelled == [int(str(rows.back().name))], "SL2 %s: the last queue button takes a click, got %s" % [label, cancelled])
		port.free()
	overlays._end(saved)
	return true

static func _click_in(port: Viewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		port.push_input(event, true)

static func _square_rows(runner, buttons: Array, label: String) -> void:
	for button: Button in buttons: runner.check(button.theme_type_variation == &"HudButton" and button.get_combined_minimum_size().y == 32.0, "%s %s is a 32 px HudButton, got %s %s" % [label, button.name, button.theme_type_variation, button.get_combined_minimum_size()])

# Every menu a slab can show: each faction's builds, and what each of those and the start building produce.
static func _every_menu() -> Array:
	var menus: Array = []
	for faction: String in Registry.Factions.FACTIONS:
		var row: Dictionary = Registry.faction(faction)
		var builds: Array = Registry.kind(row.start_unit).get("builds", [])
		menus.append(builds)
		for kind: String in builds + [row.start_building]: menus.append(Registry.kind(kind).get("produces", []))
	return menus

static func _look(main, path: String) -> StringName:
	return (main.get_node("HUD/Economy/" + path) as Button).theme_type_variation

func test_armed_button_look(runner) -> bool:
	var helper = BaseScene.new()
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true)
	for builder: int in [ids.usa_builder, ids.builder, ids.frc_builder]:
		_select(main, [builder])
		var buttons: Array = main.get_node("HUD/Economy/BuildMenu").get_children()
		runner.check(buttons.size() == main.hud.menu_kinds.size() and not buttons.is_empty(), "SL3 fixture: builder %d shows its menu" % builder)
		for i in buttons.size():
			(buttons[i] as Button).pressed.emit()
			var looks: Array = buttons.map(func(button: Button) -> StringName: return button.theme_type_variation)
			var expected: Array = range(buttons.size()).map(func(j: int) -> StringName: return &"HudButtonArmed" if j == i else &"HudButton")
			runner.check(main.orders._placement_kind == main.hud.menu_kinds[i] and looks == expected, "SL3 builder %d arming %s: only its button armed, got %s" % [builder, main.hud.menu_kinds[i], looks])
			main.orders._clear_placement()
		runner.check(buttons.all(func(button: Button) -> bool: return button.theme_type_variation == &"HudButton"), "SL3 builder %d: cleared, every button plain" % builder)
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 20.5))
	_select(main, ids.tanks)
	var arms: Array = [["the A key", func() -> void: helper.key(main, KEY_A)], ["the button", func() -> void: main.hud.attack_move_pressed.emit()]]
	var disarms: Array = [["Esc", func() -> void: helper.key(main, KEY_ESCAPE)], ["a right-click", func() -> void: helper.pointer(main, ground, MOUSE_BUTTON_RIGHT, true)]]
	for arm: Array in arms:
		for disarm: Array in disarms:
			(arm[1] as Callable).call()
			var armed: StringName = _look(main, "Orders/AttackMove")
			(disarm[1] as Callable).call()
			runner.check(armed == &"HudButtonArmed" and _look(main, "Orders/AttackMove") == &"HudButton" and not main.orders._attack_move_mode, "SL3 armed by %s then %s: %s, then plain" % [arm[0], disarm[0], armed])
			main.orders.selected_ids.assign(ids.tanks)
	for stop: Array in [["the S key", func() -> void: helper.key(main, KEY_S)], ["the Stop button", func() -> void: main.hud.stop_pressed.emit()]]:
		var before: int = _queued(main, "stop").size()
		helper.key(main, KEY_A)
		var armed: StringName = _look(main, "Orders/AttackMove")
		(stop[1] as Callable).call()
		runner.check(armed == &"HudButtonArmed" and _queued(main, "stop").size() == before + 1 and not main.orders._attack_move_mode and _look(main, "Orders/AttackMove") == &"HudButton", "SL3 armed, then %s: one stop, mode off, plain" % stop[0])
	_select(main, [ids.car])
	for unload: Array in [["the F key", func() -> void: helper.key(main, KEY_F)], ["the Unload button", func() -> void: main.hud.unload_pressed.emit()]]:
		var before: int = _queued(main, "unload").size()
		helper.key(main, KEY_A)
		var armed: StringName = _look(main, "Orders/AttackMove")
		(unload[1] as Callable).call()
		runner.check(armed == &"HudButtonArmed" and _queued(main, "unload").size() == before + 1 and not main.orders._attack_move_mode and _look(main, "Orders/AttackMove") == &"HudButton", "SL3 a loaded car armed, then %s: one unload, mode off, plain" % unload[0])
	main.free()
	return true

const HINTS: Array[String] = ["1-9: menu", "U: unload", "Right: context/move", "Esc: cancel", "A: attack-move click"]

func test_slab_order_buttons(runner) -> bool:
	var helper = BaseScene.new()
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true)
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 20.5))
	_select(main, ids.tanks)
	await _frames(runner)
	var attack: Button = main.get_node("HUD/Economy/Orders/AttackMove")
	var stop: Button = main.get_node("HUD/Economy/Orders/Stop")
	var unload: Button = main.get_node("HUD/Economy/Orders/Unload")
	runner.check(attack.is_visible_in_tree() and attack.text == "Attack move (%s)" % HudModel.key_label(KEY_A) and attack.text == "Attack move (A)" and stop.is_visible_in_tree() and stop.text == "Stop (S)", "SL4 tanks: Attack move (A) and Stop (S), got '%s' '%s'" % [attack.text, stop.text])
	runner.check([attack, stop, unload].all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE), "SL4 the order buttons take no focus")
	_click(runner, stop.get_global_rect().get_center())
	var stops: Array = _queued(main, "stop")
	runner.check(stops.size() == 1 and stops[0].entity_ids == ids.tanks, "SL4 a click on Stop submits one stop with the selection, got %s" % [stops])
	for code: Key in [KEY_SPACE, KEY_ENTER]: SkirmishTests.new()._push_key(main, code)
	runner.check(_queued(main, "stop").size() == 1, "SL4 Space and Enter after the click submit no second stop")
	runner.check(attack.theme_type_variation == &"HudButton" and not main._hud_selection(main.shown_state).attack_move, "SL4 before the press: plain, not armed")
	_click(runner, attack.get_global_rect().get_center())
	runner.check(attack.theme_type_variation == &"HudButtonArmed" and main.orders._attack_move_mode and main._hud_selection(main.shown_state).attack_move, "SL4 a click on Attack move arms it")
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)
	var moves: Array = _queued(main, "attack_move")
	runner.check(moves.size() == 1 and moves[0].entity_ids == ids.tanks, "SL4 the next ground click submits one attack_move, got %s" % [moves])
	for host: Array in [["a loaded Tunnel Hub", [], ids.hub], ["a loaded Scout Car", [ids.car], -1]]:
		_select(main, host[1], host[2])
		await _frames(runner)
		var before: int = _queued(main, "unload").size()
		runner.check(unload.is_visible_in_tree() and unload.text == "Unload (F)", "SL4 %s: Unload (F) shown" % host[0])
		_click(runner, unload.get_global_rect().get_center())
		var unloads: Array = _queued(main, "unload")
		var target: int = host[2] if host[2] != -1 else ids.car
		runner.check(unloads.size() == before + 1 and unloads.back().target_id == target, "SL4 %s: a click on Unload submits one unload, got %s" % [host[0], unloads])
	var none: Array = [["an inspected enemy", [], -1, ids.enemy], ["a pile", [], -1, ids.pile], ["an own Power Plant", [], ids.plant, -1], ["nothing", [], -1, -1], ["a lone builder", [ids.builder], -1, -1], ["collectors alone", ids.collectors, -1, -1], ["a builder with a collector", [ids.builder, ids.collectors[0]], -1, -1]]
	for case: Array in none:
		_select(main, case[1], case[2], case[3])
		runner.check(not _shown(main, "Orders/AttackMove") and not _shown(main, "Orders/Stop"), "SL4 %s: no Attack move and no Stop" % case[0])
	_select(main, [ids.builder, ids.infantry])
	runner.check(_shown(main, "Orders/AttackMove") and _shown(main, "Orders/Stop") and not _shown(main, "BuildMenu"), "SL4 a builder with an armed unit: the order row, no build menu")
	var both: Array = []
	for case: Array in [[ids.tanks, -1], [[ids.car], -1], [[], ids.hub], [[], ids.factory], [[], ids.barracks], [[], ids.plant], [[], -1], [[ids.usa_builder], -1], [[ids.builder], -1], [[ids.frc_builder], -1], [[ids.builder, ids.infantry], -1], [ids.collectors, -1], [[ids.builder, ids.collectors[0]], -1]]:
		_select(main, case[0], case[1])
		if _shown(main, "Orders") and _shown(main, "BuildMenu"): both.append(case)
	runner.check(both.is_empty(), "SL4 the order row and the build menu never show together (the 8 px gap between them is unreachable), got %s" % [both])
	var text: String = BaseScene.hud_text(main)
	runner.check(HINTS.all(func(hint: String) -> bool: return not text.contains(hint)) and main.find_child("Hints", true, false) == null, "SL4 no key-hint text and no Hints node, got " + text)
	_select(main, [ids.builder])
	main.get_node("HUD/Economy/BuildMenu").get_child(0).pressed.emit()
	main.orders.arm_attack_move()
	runner.check(main.orders.busy() and not _shown(main, "Orders/AttackMove") and not _shown(main, "Orders/Stop") and not main.orders._attack_move_mode, "SL4 a placement armed: no order row, and a direct arm does nothing")
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)
	runner.check(_queued(main, "build").size() == 1 and _queued(main, "attack_move").size() == 1, "SL4 the next click places the building and submits no attack_move")
	main.orders.reset()
	main.free()
	await _loaded_rule(runner)
	await _note_form_holds(runner)
	await _crosshair(runner)
	return true

func _loaded_rule(runner) -> void:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_select(main, [], ids.hub)
	runner.check(not _shown(main, "Orders/Unload") and not _shown(main, "Orders"), "SL4 an empty Tunnel Hub: no Unload")
	_select(main, [ids.car])
	runner.check(not _shown(main, "Orders/Unload") and _shown(main, "Orders/AttackMove"), "SL4 an empty Scout Car with no own unit inside anything: no Unload")
	main.free()

func _note_form_holds(runner) -> void:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await overlays._scene(runner, Skirmish)
	overlays._camera(main)
	var ids: Dictionary = _slab_world(runner, main, false)
	_select(main, ids.tanks)
	main.get_node("HUD/Playtest").open_marker()
	main.orders.stop_selected()
	main.orders.arm_attack_move()
	runner.check(main._playtest.holds_match() and _queued(main, "stop").is_empty() and not main.orders._attack_move_mode, "SL4 the note form holds the match: Stop and Attack move do nothing")
	main.free()
	overlays._end(saved)

# Each step leaves the cursor it set last; no check runs while the recorder is in place.
func _crosshair(runner) -> void:
	var helper = BaseScene.new()
	var skirmish = SkirmishTests.new()
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await overlays._scene(runner, Skirmish)
	overlays._camera(main)
	var ids: Dictionary = _slab_world(runner, main, true)
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 20.5))
	var shapes: Array[int] = []
	var seen: Array = []
	Orders.set_cursor = func(shape: int) -> void: shapes.append(shape)
	var steps: Array = [
		["left-click submit", ids.tanks, func() -> void:
			helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
			helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)],
		["Esc", ids.tanks, func() -> void: helper.key(main, KEY_ESCAPE)],
		["a right-click", ids.tanks, func() -> void: helper.pointer(main, ground, MOUSE_BUTTON_RIGHT, true)],
		["S", ids.tanks, func() -> void: helper.key(main, KEY_S)],
		["F", [ids.car], func() -> void: helper.key(main, KEY_F)],
		["the Stop button", ids.tanks, func() -> void: main.hud.stop_pressed.emit()],
		["the Unload button", [ids.car], func() -> void: main.hud.unload_pressed.emit()],
		["a placement armed", [ids.builder], func() -> void: main.get_node("HUD/Economy/BuildMenu").get_child(0).pressed.emit()],
		["orders.reset()", ids.tanks, func() -> void: main.orders.reset()],
		["the pause menu opened by Menu, a frame later", ids.tanks, func() -> void:
			main._pause.open()
			main._process(0.0)],
		["the note form, a frame later", ids.tanks, func() -> void:
			main._playtest.open_marker()
			main._process(0.0)],
		["the whole selection dying", ids.tanks, func() -> void:
			for id: int in ids.tanks: main.driver.pump.live().remove_object(id)
			BaseScene.publish(main)]]
	for step: Array in steps:
		main.orders._clear_placement()
		main._pause.close()
		main._playtest.cancel_marker()
		_select(main, step[1])
		helper.key(main, KEY_A)
		seen.append([step[0], shapes.back() if not shapes.is_empty() else -1, main.orders._attack_move_mode, true])
		(step[2] as Callable).call()
		seen.append([step[0], shapes.back(), main.orders._attack_move_mode, false])
	_select(main, [ids.infantry])
	helper.key(main, KEY_A)
	main.free()
	seen.append(["the match freed", shapes.back(), false, false])
	var won = await skirmish._setup(runner)
	skirmish._arena(won)
	helper.key(won, KEY_A)
	seen.append(["the match end", shapes.back(), won.orders._attack_move_mode, true])
	skirmish._victory(won)
	seen.append(["the match end", shapes.back(), won.orders._attack_move_mode, false])
	won.free()
	var frozen = await skirmish._setup(runner)
	var world: Dictionary = skirmish._frozen_arena(frozen)
	helper.key(frozen, KEY_A)
	seen.append(["the freeze card", shapes.back(), frozen.orders._attack_move_mode, true])
	world.pump.fail_next = true
	BaseScene.tick(frozen)
	seen.append(["the freeze card", shapes.back(), frozen.orders._attack_move_mode, false])
	frozen.free()
	Orders.set_cursor = Input.set_default_cursor_shape
	overlays._end(saved)
	for entry: Array in seen:
		var expected: int = Input.CURSOR_CROSS if entry[3] else Input.CURSOR_ARROW
		runner.check(entry[1] == expected and entry[2] == entry[3], "SL4 %s %s: cursor %d, armed %s, got %s" % ["armed before" if entry[3] else "after", entry[0], expected, entry[3], entry])

static func _queue_of(main, factory: int, count: int, first_work: int = 336000) -> void:
	var entries: Array = []
	for i in count: entries.append({"id": 900 + i, "kind": "china_tank", "paid_cost": 800, "work": first_work if i == 0 else 0})
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, factory).queue = entries
	main._show(view)

static func _visible_texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text)

func test_slab_queue_cap(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_select(main, [], ids.factory)
	var queue: Control = main.get_node("HUD/Economy/Queue")
	var header: Control = main.get_node("HUD/Economy/QueueHeader")
	var more: Button = main.get_node("HUD/Economy/QueueMore")
	runner.check(not header.visible and queue.get_child_count() == 0, "SL5 no entries: no QUEUE header")
	for count in range(1, 6):
		_queue_of(main, ids.factory, count)
		var rows: Array = queue.get_children()
		var digits: Array = _visible_texts(main.get_node("HUD/Economy")).filter(func(text: String) -> bool: return text.length() > 1 and text[0].is_valid_int() and text[1] == ".")
		runner.check(rows.size() == count and rows.all(func(row: Control) -> bool: return row.visible) and not more.visible, "SL5 %d entries: all shown, no Show more" % count)
		runner.check(header.visible and header.get_node("Title").text == "QUEUE" and header.get_node("Waiting").visible == (count > 1) and header.get_node("Waiting").text == "%d waiting" % (count - 1), "SL5 %d entries: QUEUE and %d waiting" % [count, count - 1])
		runner.check(digits.is_empty(), "SL5 %d entries: no numbered row, got %s" % [count, digits])
		runner.check(rows[0].get_node("Percent").visible and rows[0].get_node("Track").visible and rows.slice(1).all(func(row: Control) -> bool: return not row.get_node("Percent").visible and not row.get_node("Track").visible), "SL5 %d entries: only the first shows its percent and line" % count)
		runner.check(rows[0].get_node("Track/Bar").color == View.owner_color(1, main._view.bright_owners()) and rows[0].get_node("Cancel").text == "×", "SL5 the line is the own colour and the × is the cancel sign")
	for count: int in [6, 9]:
		_queue_of(main, ids.factory, count)
		var shown: int = queue.get_children().filter(func(row: Control) -> bool: return row.visible).size()
		runner.check(shown == 4 and queue.get_child_count() == count and more.visible and more.text == "Show %d more queued" % (count - 4), "SL5 %d entries: 4 shown and '%s'" % [count, more.text])
	_square_rows(runner, queue.get_children() + [more], "SL5")
	more.pressed.emit()
	runner.check(queue.get_children().all(func(row: Control) -> bool: return row.visible) and more.text == "Show fewer" and queue.get_child_count() == 9, "SL5 a press shows all nine and Show fewer")
	more.pressed.emit()
	runner.check(queue.get_children().filter(func(row: Control) -> bool: return row.visible).size() == 4 and more.text == "Show 5 more queued", "SL5 a second press collapses")
	more.pressed.emit()
	main.orders.selected_building_id = ids.barracks
	_queue_of(main, ids.barracks, 9)
	runner.check(more.text == "Show 5 more queued", "SL5 open, then another building with nine: collapsed")
	_select(main, [], ids.factory)
	_queue_of(main, ids.factory, 9)
	more.pressed.emit()
	_queue_of(main, ids.factory, 5)
	_queue_of(main, ids.factory, 7)
	runner.check(more.text == "Show 3 more queued" and queue.get_child_count() == 7, "SL5 open, then down to 5: collapsed")
	await _frames(runner)
	var cancelled: Array[int] = []
	main.hud.entry_cancelled.connect(func(id: int) -> void: cancelled.append(id))
	var row: Control = queue.get_child(2)
	_click(runner, row.get_global_rect().get_center())
	runner.check(cancelled == [902], "SL5 a press on the middle of a row cancels that entry, got %s" % [cancelled])
	main.free()
	return true

func test_build_buttons_by_selection_and_price(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false, 500)
	for case: Array in [["nothing", [], true], ["a lone builder", [ids.builder], true], ["own tanks", ids.tanks, false], ["collectors alone", ids.collectors, false], ["a builder with a tank", [ids.builder, ids.tanks[0]], false], ["a builder with a collector", [ids.builder, ids.collectors[0]], false], ["two builders", [ids.builder, ids.frc_builder], false]]:
		_select(main, case[1])
		runner.check(_shown(main, "BuildMenu") == case[2], "SL6 %s: build menu %s" % [case[0], "shown" if case[2] else "hidden"])
		if case[1].has(ids.tanks[0]): runner.check(_shown(main, "Orders/AttackMove"), "SL6 %s: the order row instead" % case[0])
	for builder: int in [ids.usa_builder, ids.builder, ids.frc_builder]:
		_select(main, [builder])
		for button: Node in main.get_node("HUD/Economy/BuildMenu").get_children():
			(button as Button).pressed.emit()
			runner.check(main.orders.busy() and main.hud.refusal.is_empty(), "SL6 builder %d: %s arms its placement" % [builder, (button as Button).text])
			main.orders._clear_placement()
	_select(main, [], ids.factory)
	runner.check(_shown(main, "BuildMenu") and main.hud.menu_kinds == Registry.kind("china_factory").produces, "SL6 a selected factory shows its produces")
	var menu: GridContainer = main.get_node("HUD/Economy/BuildMenu")
	var font: Font = menu.get_theme_font("font", &"HudButton")
	var font_size: int = menu.get_theme_font_size("font_size", &"HudButton")
	var widest: float = 0.0
	for kinds: Array in _every_menu():
		for i in kinds.size(): widest = maxf(widest, font.get_string_size(HudModel.menu_label(i, kinds[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	runner.check(menu.columns * (widest + 24.0) + (menu.columns - 1) * 4.0 <= 412.0, "SL6 %d columns fit the widest label of every build and produce menu (%.1f px)" % [menu.columns, widest])
	_select(main, [ids.builder])
	await _frames(runner)
	var tower: Button = main.get_node("HUD/Economy/BuildMenu").get_child(4)
	var cheap: Button = main.get_node("HUD/Economy/BuildMenu").get_child(2)
	var price: Label = tower.get_node("Price")
	var buttons: Array = main.get_node("HUD/Economy/BuildMenu").get_children()
	runner.check(buttons.all(func(button: Button) -> bool: return button.alignment == HORIZONTAL_ALIGNMENT_LEFT and button.text == HudModel.menu_name(button.get_index(), main.hud.menu_kinds[button.get_index()]) and button.get_node("Price").horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT), "SL6 every button: its menu name left, a right-aligned Price")
	runner.check(tower.text == "5: Rotary Gun Tower" and price.text == "$1200" and _colour(price) == _token("warn"), "SL6 credits 500: the tower's $1200 in warn, got '%s' '%s'" % [tower.text, price.text])
	runner.check(cheap.get_node("Price").text == "$500" and _colour(cheap.get_node("Price")) == _token("text"), "SL6 the affordable barracks' price in text")
	runner.check(tower.get_global_rect().encloses(price.get_global_rect()), "SL6 the price sits inside its button")
	var rebuilds: int = main.hud.rebuilds
	var node_id: int = price.get_instance_id()
	for credits: Array in [[1200, "text"], [499, "warn"]]:
		var view: Dictionary = main.driver.current().view
		HudModel.player(view, 1).credits = credits[0]
		main._show(view)
		runner.check(_colour(price) == _token(credits[1]) and main.hud.rebuilds == rebuilds and tower.get_node("Price").get_instance_id() == node_id, "SL6 credits %d: the price in %s, patched in place" % [credits[0], credits[1]])
	main.free()
	return true

func test_key_labels(runner) -> bool:
	var headless: Array = HudModel.ORDER_KEYS.values().map(func(code: Key) -> String: return HudModel.key_label(code))
	runner.check(headless == ["A", "S", "F", "E"], "KL1 headless labels are the physical keys, got %s" % [headless])
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true)
	HudModel.layout_label = func(physical: Key) -> Key: return {KEY_A: KEY_Q, KEY_F: KEY_G, KEY_E: KEY_R}.get(physical, physical)
	main.hud.reset()
	_select(main, [ids.car])
	var texts: Array = [main.get_node("HUD/Economy/Orders/AttackMove").text, main.get_node("HUD/Economy/Orders/Stop").text, main.get_node("HUD/Economy/Orders/Unload").text]
	_select(main, [], ids.barracks)
	texts.append(main.get_node("HUD/Economy/Produce").text)
	HudModel.layout_label = HudModel._platform_label
	main.free()
	runner.check(texts.slice(0, 3) == ["Attack move (Q)", "Stop (S)", "Unload (G)"] and texts[3].ends_with("(R)"), "KL1 the buttons print the layout's labels, got %s" % [texts])
	return true

const SITE_PERCENT: int = 62

# Turns a building of the shown view into a site at `percent`, paused when `builder` is null.
static func _site(view: Dictionary, id: int, builder: Variant, percent: int = SITE_PERCENT) -> void:
	var site: Dictionary = HudModel.building(view, id)
	site.merge({"completed": false, "work": Economy.building(site.kind).ticks * 10 * percent, "builder_id": builder}, true)

# The panel's fifteen states in one world; player 3 is player 1's teammate.
func _panel_world(main) -> Dictionary:
	var sim = Fixture.make_world(50000)
	sim.add_player(2, 1000)
	sim.add_player(3, 1000, "human", 1)
	var ids := {}
	ids.tank = sim.spawn(1, Vector2(8.5, 6.5), "china_light_vehicle")
	ids.enemy = sim.spawn(2, Vector2(28.5, 28.5), "usa_tank")
	ids.ally = sim.spawn(3, Vector2(4.5, 28.5), "usa_tank")
	ids.depot = Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(2, 10))
	ids.defence = Fixture.add_completed(sim, 1, "china_defence", Vector2i(8, 10))
	ids.plant = Fixture.add_completed(sim, 1, "china_power_plant", Vector2i(10, 10))
	ids.factory = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(14, 10))
	ids.site = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(20, 10))
	ids.paused = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(24, 10))
	ids.enemy_building = Fixture.add_completed(sim, 2, "usa_power_plant", Vector2i(2, 18))
	ids.enemy_site = Fixture.add_completed(sim, 2, "usa_factory", Vector2i(8, 18))
	ids.ally_building = Fixture.add_completed(sim, 3, "usa_factory", Vector2i(14, 18))
	ids.ally_site = Fixture.add_completed(sim, 3, "usa_barracks", Vector2i(20, 18))
	ids.hq = Fixture.add_completed(sim, 1, "usa_command_center", Vector2i(2, 24))
	ids.pile = sim.add_supply_source(Vector2i(26, 2), 142)
	ids.empty = sim.add_supply_source(Vector2i(26, 21), 0)
	ids.collector = sim.spawn(1, Vector2(12.5, 28.5), "usa_collector")
	main.driver.adopt(sim)
	var view: Dictionary = main.driver.current().view
	_site(view, ids.site, 1)
	for id: int in [ids.paused, ids.enemy_site, ids.ally_site]: _site(view, id, null)
	main._refresh()
	return ids

# [label, selected ids, building, inspected, height, short owner] (spec "Selection panel" table).
static func _panel_cases(ids: Dictionary) -> Array:
	return [["one unit", [ids.tank], -1, -1, 62, 0], ["own building", [], ids.depot, -1, 62, 0], ["own offline defence", [], ids.defence, -1, 62, 1],
		["power plant", [], ids.plant, -1, 86, 0], ["factory", [], ids.factory, -1, 84, 0], ["own site", [], ids.site, -1, 86, 0], ["own paused site", [], ids.paused, -1, 86, 0],
		["enemy unit", [], -1, ids.enemy, 62, 0], ["enemy building", [], -1, ids.enemy_building, 62, 0], ["enemy site", [], -1, ids.enemy_site, 86, 0],
		["allied unit", [], -1, ids.ally, 62, 0], ["allied building", [], -1, ids.ally_building, 62, 0], ["allied site", [], -1, ids.ally_site, 86, 0],
		["pile", [], -1, ids.pile, 62, 0], ["empty pile", [], -1, ids.empty, 62, 0]]

# Shows a selection on the current view, with `short` owner's demand above its supply.
static func _panel_select(main, case: Array) -> void:
	main.orders.selected_ids.assign(case[1])
	main.orders.selected_building_id = case[2]
	main.orders.inspected_id = case[3]
	var view: Dictionary = main.driver.current().view
	if case[5] != 0:
		view = view.duplicate()
		view.players = view.players.map(func(row: Dictionary) -> Dictionary: return row.merged({"power_demand": row.power_supply + 1}, true) if row.id == case[5] else row)
	main._show(view)

# Shows `id` as an own collector waiting at the drop-off, with the viewer playing `faction`.
static func _waiting_collector(main, id: int, faction: String) -> void:
	var view: Dictionary = main.driver.current().view.duplicate()
	var units: RefCounted = view.units
	var i: int = units.index_of(id)
	if not units.phases.has("waiting_depot"): units.phases.append("waiting_depot")
	units.phase[i] = units.phases.find("waiting_depot")
	units.flags[i] |= ViewRows.COLLECTING
	view.players = view.players.map(func(row: Dictionary) -> Dictionary: return row.merged({"faction": faction}, true) if row.id == 1 else row)
	main.orders.selected_ids.assign([id])
	main.orders.selected_building_id = -1
	main.orders.inspected_id = -1
	main._show(view)

static func _pick(main, ids: Array, building: int, inspected: int) -> void:
	_panel_select(main, ["", ids, building, inspected, 0, 0])

static func _panel_part(main, part: String) -> Control:
	return main.get_node("HUD/Hud/SelectionPanel").find_child(part, true, false)

func _panel_contained(runner, main, panel: Rect2, label: String) -> void:
	var content: Rect2 = panel.grow_individual(-16.0, -12.0, -16.0, -12.0)
	for control: Control in _controls(main.get_node("HUD/Hud/SelectionPanel")):
		if not control is Label or not control.is_visible_in_tree(): continue
		var rect: Rect2 = control.get_global_rect()
		runner.check(content.grow(0.5).encloses(rect) and (control.get_parent() as Control).get_global_rect().grow(0.5).encloses(rect), "SP1 %s: %s inside its row and the panel content %s, got %s" % [label, control.name, content, rect])
	var right: Control = _panel_part(main, "RightLabel")
	if right.is_visible_in_tree(): runner.check(not _panel_part(main, "Name").get_global_rect().intersects(right.get_global_rect()), "SP1 %s: the name and the right label do not meet" % label)

func test_panel_states_layout(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var ids: Dictionary = _panel_world(main)
		var refusal := Rect2((size.x - 416.0) / 2.0, size.y - 204.0, 416.0, 28.0)
		for case: Array in _panel_cases(ids):
			_panel_select(main, case)
			await _frames(runner)
			var at: String = "%s at %s" % [case[0], size]
			var panel_node: Control = main.get_node_or_null("HUD/Hud/SelectionPanel")
			runner.check(panel_node != null and panel_node.is_visible_in_tree(), "SP1 %s: the panel shows" % at)
			if panel_node == null: break
			var panel: Rect2 = panel_node.get_global_rect()
			runner.check(absf(panel.position.x) <= 0.5 and is_equal_approx(panel.size.x, 408.0) and absf(panel.end.y - size.y) <= 0.5 and absf(panel.size.y - case[4]) <= 1.0 and view.encloses(panel), "SP1 %s: x 0, 408 wide, bottom on H, %d high, inside the view, got %s" % [at, case[4], panel])
			var others: Dictionary = {"the strip": _rect(main, "HUD/Hud/TopStrip"), "the refusal line": refusal}
			if main.get_node("HUD/Economy").is_visible_in_tree(): others["the slab"] = _rect(main, "HUD/Economy")
			for other: String in others: runner.check(not panel.intersects(others[other]), "SP1 %s: clear of %s" % [at, other])
			_panel_contained(runner, main, panel, at)
		for longest: Array in [["usa", "WAITING AT SUPPLY DEPOT"], ["frc", "WAITING AT SUPPLY CACHE"]]:
			_waiting_collector(main, ids.collector, longest[0])
			await _frames(runner)
			var at: String = "collector %s at %s" % [longest[0], size]
			var panel: Rect2 = _rect(main, "HUD/Hud/SelectionPanel")
			runner.check(_panel_texts(main).Name == "Supply Helicopter" and _panel_texts(main).RightLabel == longest[1] and absf(panel.size.y - 62.0) <= 1.0, "SP1 %s: the longest name beside %s, 62 high, got %s %.1f" % [at, longest[1], _panel_texts(main), panel.size.y])
			_panel_contained(runner, main, panel, at)
		_pick(main, [], -1, -1)
		await _frames(runner)
		runner.check(not main.get_node("HUD/Hud/SelectionPanel").is_visible_in_tree(), "SP1 nothing selected hides the panel at %s" % size)
		port.free()
	overlays._end(saved)
	return true

static func _panel_texts(main) -> Dictionary:
	var texts := {}
	for part: String in ["Name", "RightLabel", "Health", "Percent", "Key", "Value", "Footer"]:
		var label: Label = _panel_part(main, part)
		texts[part] = label.text if label != null and label.is_visible_in_tree() else ""
	return texts

static func _fill(main, bar: String) -> Color:
	return (_panel_part(main, bar).get_node("Fill") as ColorRect).color

func test_panel_values(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _panel_world(main)
	var view: Dictionary = main.driver.current().view
	view.units.hp[view.units.index_of(ids.tank)] = 179500
	_pick(main, [ids.tank], -1, -1)
	runner.check(_panel_texts(main).Name == "Medium Tank" and _panel_texts(main).Health == "180 / 400", "SP2 a Medium Tank at 179500 reads 180 / 400, got %s" % _panel_texts(main))
	_pick(main, [], ids.plant, -1)
	runner.check(_panel_texts(main).Key == "POWER" and _panel_texts(main).Value == "+10", "SP2 a China Power Plant reads POWER +10, got %s" % _panel_texts(main))
	_pick(main, [], ids.site, -1)
	runner.check(_panel_texts(main).Percent == "62 %" and _panel_texts(main).RightLabel == "UNDER CONSTRUCTION" and _fill(main, "Progress") == View.owner_color(1), "SP2 an own site at 62 %% reads 62 %% with the owner-coloured fill, got %s" % _panel_texts(main))
	_pick(main, [], ids.paused, -1)
	var right: Label = _panel_part(main, "RightLabel")
	runner.check(right.text == "PAUSED · NO BUILDER" and _colour(right) == _token("muted") and _colour(right) != _token("amber") and _fill(main, "Progress") == _token("muted"), "SP2 the paused site reads PAUSED · NO BUILDER in muted with a muted fill, got '%s' %s" % [right.text, _fill(main, "Progress")])
	_pick(main, [], -1, ids.enemy_site)
	runner.check(_panel_texts(main).RightLabel == "UNDER CONSTRUCTION" and _panel_texts(main).Percent == "62 %" and _fill(main, "Progress") == View.owner_color(2), "SP2 an enemy site with no builder is never paused, got %s" % _panel_texts(main))
	_pick(main, [], ids.hq, -1)
	runner.check(_panel_texts(main).Health == "5000 / 5000", "SP2 a full Headquarters reads 5000 / 5000, got %s" % _panel_texts(main))
	for pile: Array in [[ids.pile, "10650"], [ids.empty, "Empty"]]:
		_pick(main, [], -1, pile[0])
		runner.check(_panel_texts(main).Name == "Supply Pile" and _panel_texts(main).Key == "CREDITS LEFT" and _panel_texts(main).Value == pile[1] and _panel_texts(main).Health.is_empty(), "SP2 the pile reads CREDITS LEFT %s, got %s" % [pile[1], _panel_texts(main)])
	main.free()
	return await _offline_label(runner)

# OFFLINE · LOW POWER for any owner's powered defence while that owner is short (director round, user 2026-11-19).
func _offline_label(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var sim = Fixture.make_world(50000)
	sim.add_player(2, 1000)
	var tower: int = Fixture.add_completed(sim, 1, "china_defence", Vector2i(8, 10))
	var depot: int = Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(12, 10))
	var battery: int = Fixture.add_completed(sim, 2, "usa_defence", Vector2i(20, 20))
	main.driver.adopt(sim)
	_pick(main, [], tower, -1)
	await _frames(runner)
	var right: Label = _panel_part(main, "RightLabel")
	var height: float = main.get_node("HUD/Hud/SelectionPanel").size.y
	runner.check(right.is_visible_in_tree() and right.text == "OFFLINE · LOW POWER" and _colour(right) == _token("warn") and absf(height - 62.0) <= 1.0, "SP2 an own short defence reads OFFLINE · LOW POWER in warn, 62 high, got '%s' %s %.1f" % [right.text, _colour(right), height])
	_pick(main, [], -1, battery)
	runner.check(_panel_texts(main).RightLabel == "OFFLINE · LOW POWER", "SP2 an inspected enemy defence whose owner is short reads offline, got %s" % _panel_texts(main))
	_pick(main, [], depot, -1)
	runner.check(_panel_texts(main).RightLabel.is_empty(), "SP2 a short owner's unpowered building has no label, got %s" % _panel_texts(main))
	Fixture.add_completed(sim, 1, "china_power_plant", Vector2i(2, 2))
	BaseScene.publish(main)
	_pick(main, [], tower, -1)
	runner.check(_panel_texts(main).RightLabel.is_empty() and _colour(right) != _token("warn"), "SP2 a power plant evens it: no label, got %s" % _panel_texts(main))
	main.free()
	return true

func test_panel_edge_colours(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _panel_world(main)
	for case: Array in [[[ids.tank], -1, View.owner_color(1), "own"], [[], ids.enemy, View.owner_color(2), "enemy"], [[], ids.ally, View.owner_color(3), "allied"], [[], ids.pile, _token("line"), "pile"]]:
		_pick(main, case[0], -1, case[1])
		runner.check(main.hud.panel_edge() == case[2], "SP3 the %s edge is %s, got %s" % [case[3], case[2], main.hud.panel_edge()])
	runner.check(View.owner_color(3) != View.owner_color(1) and View.owner_color(3) != View.owner_color(2), "SP3 fixture: the ally's slot colour is its own")
	_pick(main, [ids.tank], -1, -1)
	main._pause.neon_changed.emit(true)
	var body: Color = Palette.owner_colors(1, main._view._batch.bright_owners)[0]
	runner.check(main._view._batch.bright_owners and body != View.owner_color(1) and main.hud.panel_edge() == body, "SP3 Neon on live: the edge is the body colour the batch draws, got %s against %s" % [main.hud.panel_edge(), body])
	main._pause.neon_changed.emit(false)
	main.free()
	return true

const ROSTERS: Dictionary = {
	"usa": ["usa_light_vehicle", "usa_tank", "usa_rifle_infantry", "usa_rocket_infantry", "usa_collector", "usa_builder"],
	"china": ["china_light_vehicle", "china_tank", "china_rifle_infantry", "china_rocket_infantry", "china_collector", "china_builder"],
	"frc": ["frc_light_vehicle", "frc_tank", "frc_rifle_infantry", "frc_rocket_infantry", "frc_builder"],
}
const RULE: String = "Click a kind: select only that kind · Shift-click: deselect it"

# Spawns [kind, count] groups for player 1 on a grid, shows them selected, and returns the ids per kind.
static func _rows_world(main, groups: Array) -> Dictionary:
	var sim = Fixture.make_world(50000, Vector2i(48, 48))
	sim.add_player(2, 1000)
	var ids := {}
	var at: int = 0
	for group: Array in groups:
		var kind_ids: Array[int] = []
		for n in group[1]:
			kind_ids.append(sim.spawn(1, Vector2(8.5 + at % 24, 8.5 + floorf(at / 24.0)), group[0]))
			at += 1
		ids[group[0]] = kind_ids
	main.driver.adopt(sim)
	_pick(main, _all(ids), -1, -1)
	return ids

static func _all(ids: Dictionary) -> Array[int]:
	var every: Array[int] = []
	for kind: String in ids: every.append_array(ids[kind])
	every.sort()
	return every

static func _many(main, part: String) -> Control:
	return main.get_node_or_null("HUD/Hud/SelectionPanel/Box/Many/" + part)

static func _row_names(main) -> Array:
	var rows: Control = _many(main, "Rows")
	return [] if rows == null else rows.get_children().filter(func(row: Control) -> bool: return row.visible).map(func(row: Control) -> String: return str(row.name))

static func _row(main, kind: String) -> Button:
	return _many(main, "Rows/Row_" + kind) as Button

static func _panel_height(main) -> float:
	return main.get_node("HUD/Hud/SelectionPanel").size.y

static func _rows_height(kinds: int) -> float:
	return [76.0, 98.0, 128.0, 128.0, 158.0, 158.0][kinds - 1]

func test_kind_rows(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _rows_world(main, [["usa_builder", 1], ["usa_rifle_infantry", 1], ["usa_tank", 1]])
	await _frames(runner)
	runner.check(_row_names(main) == ["Row_usa_tank", "Row_usa_rifle_infantry", "Row_usa_builder"], "KR1 three USA kinds in roster order, got %s" % [_row_names(main)])
	var header: Label = _many(main, "Header") as Label
	runner.check(header != null and header.is_visible_in_tree() and header.text == "3 selected · 3 kinds", "KR1 header 3 selected · 3 kinds, got '%s'" % (header.text if header != null else "none"))
	if header == null:
		main.free()
		return true
	var first: Rect2 = _row(main, "usa_tank").get_global_rect()
	var second: Rect2 = _row(main, "usa_rifle_infantry").get_global_rect()
	var third: Rect2 = _row(main, "usa_builder").get_global_rect()
	runner.check(first.size == Vector2(186, 26) and second.size == Vector2(186, 26) and is_equal_approx(second.position.x - first.position.x, 190.0) and is_equal_approx(second.position.y, first.position.y) and is_equal_approx(third.position.x, first.position.x) and is_equal_approx(third.position.y - first.position.y, 30.0), "KR1 two columns of 186x26 rows, 4 apart, got %s %s %s" % [first, second, third])
	for faction: String in ROSTERS:
		var groups: Array = []
		for kind: String in ROSTERS[faction]: groups.append([kind, 1])
		groups.reverse()
		_rows_world(main, groups)
		var expected: Array = ROSTERS[faction].map(func(kind: String) -> String: return "Row_" + kind)
		runner.check(_row_names(main) == expected, "KR1 %s roster order %s, got %s" % [faction, expected, _row_names(main)])
	_rows_world(main, [["china_tank", 12]])
	await _frames(runner)
	runner.check(header.text == "12 selected · 1 kind" and _row_names(main) == ["Row_china_tank"] and absf(_panel_height(main) - 76.0) <= 1.0 and not _many(main, "Footer").is_visible_in_tree(), "KR1 twelve of one kind: one row, 76 high, no footer, got '%s' %s %.1f" % [header.text, _row_names(main), _panel_height(main)])
	runner.check(ids.size() == 3, "KR1 fixture")
	main.free()
	return true

# Every visible label inside the panel's content rect and its parent; a row's name and count never meet.
func _rows_contained(runner, main, label: String) -> void:
	var panel: Rect2 = _rect(main, "HUD/Hud/SelectionPanel")
	_panel_contained(runner, main, panel, label)
	for row: Node in _many(main, "Rows").get_children():
		var name_rect: Rect2 = (row.get_node("Name") as Control).get_global_rect()
		var count_rect: Rect2 = (row.get_node("Count") as Control).get_global_rect()
		runner.check(not name_rect.intersects(count_rect), "KR2 %s: %s name and count do not meet, got %s %s" % [label, row.name, name_rect, count_rect])

func test_roster_fits(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var refusal := Rect2((size.x - 416.0) / 2.0, size.y - 204.0, 416.0, 28.0)
		for faction: String in ROSTERS:
			var roster: Array = ROSTERS[faction]
			var groups: Array = roster.map(func(kind: String) -> Array: return [kind, 120 if kind.ends_with("rifle_infantry") else (2 if not Registry.collects(kind).is_empty() else 1)])
			_rows_world(main, groups)
			await _frames(runner)
			var at: String = "%s at %s" % [faction, size]
			var panel: Rect2 = _rect(main, "HUD/Hud/SelectionPanel")
			var header: Label = _many(main, "Header") as Label
			runner.check(header != null and header.text.ends_with(" · 2 idle collectors"), "KR2 %s: the header counts two idle collectors, got '%s'" % [at, header.text if header != null else "none"])
			if header == null: break
			runner.check(absf(panel.size.y - _rows_height(roster.size())) <= 1.0 and view.encloses(panel) and _many(main, "Footer").is_visible_in_tree(), "KR2 %s: %d kinds make %.0f high with the footer, inside the view, got %s" % [at, roster.size(), _rows_height(roster.size()), panel])
			runner.check(not panel.intersects(refusal) and not panel.intersects(_rect(main, "HUD/Economy")), "KR2 %s: clear of the refusal line and the slab" % at)
			_rows_contained(runner, main, at)
		port.free()
	overlays._end(saved)
	return true

func _port_scene(runner) -> Array:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var port: SubViewport = BaseScene.sized_port(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var main = await overlays._scene(runner, Skirmish, port)
	return [overlays, saved, port, main]

static func _end_port(scene: Array) -> void:
	scene[2].free()
	scene[0]._end(scene[1])

static func _move(port: Viewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	port.push_input(motion, true)

static func _press(port: Viewport, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	port.push_input(event, true)

static func _row_click(port: Viewport, row: Control, shift: bool) -> void:
	var at: Vector2 = row.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.position = at
		event.global_position = at
		port.push_input(event, true)

func test_row_click_narrows_and_shift_removes(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _rows_world(main, [["usa_tank", 2], ["usa_rifle_infantry", 3], ["usa_rocket_infantry", 1]])
	await _frames(runner)
	var clicks: Array = []
	if main.hud.has_signal("row_clicked"): main.hud.row_clicked.connect(func(kind: String, shift: bool) -> void: clicks.append([kind, shift]))
	var row: Control = _row(main, "usa_rifle_infantry")
	runner.check(row != null, "KR3 the rifle row shows")
	if row == null:
		_end_port(scene)
		return true
	_row_click(port, row, false)
	await _frames(runner)
	runner.check(clicks == [["usa_rifle_infantry", false]] and main.orders.selected_ids == ids.usa_rifle_infantry, "KR3 a click narrows to the riflemen, got %s %s" % [clicks, main.orders.selected_ids])
	_pick(main, _all(ids), -1, -1)
	_move(port, Vector2(900, 200))
	await _frames(runner)
	_row_click(port, _row(main, "usa_tank"), true)
	await _frames(runner)
	var rest: Array[int] = ids.usa_rifle_infantry + ids.usa_rocket_infantry
	rest.sort()
	runner.check(clicks.back() == ["usa_tank", true] and main.orders.selected_ids == rest, "KR3 a shift-click removes the tanks, got %s %s" % [clicks, main.orders.selected_ids])
	_pick(main, _all(ids), -1, -1)
	_move(port, Vector2(900, 200))
	await _frames(runner)
	var count: int = clicks.size()
	var rifles: Control = _row(main, "usa_rifle_infantry")
	_press(port, rifles.get_global_rect().get_center(), true)
	_move(port, Vector2(900, 200))
	_press(port, Vector2(900, 200), false)
	await _frames(runner)
	runner.check(clicks.size() == count and main.orders.selected_ids == _all(ids), "KR3 a press dragged off the row and released outside changes nothing, got %s %s" % [clicks, main.orders.selected_ids])
	_press(port, rifles.get_global_rect().get_center(), true)
	_press(port, _row(main, "usa_tank").get_global_rect().get_center(), false)
	await _frames(runner)
	runner.check(clicks.size() == count and main.orders.selected_ids == _all(ids), "KR3 a press on one row released on another changes nothing, got %s %s" % [clicks, main.orders.selected_ids])
	_row_click(port, rifles, false)
	runner.check(clicks.size() == count, "KR3 the click is emitted after the row's input, not inside it")
	await _frames(runner)
	runner.check(clicks.size() == count + 1, "KR3 the deferred click arrives on the next frame")
	_end_port(scene)
	return true

func test_rows_hold_under_the_pointer(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _rows_world(main, [["usa_tank", 1], ["usa_rifle_infantry", 2]])
	await _frames(runner)
	var tank_row: Control = _row(main, "usa_tank")
	runner.check(tank_row != null, "KR4 the tank row shows")
	if tank_row == null:
		_end_port(scene)
		return true
	_move(port, tank_row.get_global_rect().get_center())
	await _frames(runner)
	var sim = main.driver.pump.live()
	sim.remove_object(ids.usa_tank[0])
	BaseScene.publish(main)
	await _frames(runner)
	var held: Button = _row(main, "usa_tank")
	var name_label: Label = held.get_node("Name") if held != null else null
	runner.check(held != null and (held.get_node("Count") as Label).text == "0" and _colour(name_label) == _token("muted") and is_zero_approx((held.get_node("Track/Bar") as Control).anchor_right), "KR4 the last tank died under the pointer: its row holds at 0, muted, empty bar")
	runner.check(_many(main, "Footer").is_visible_in_tree() and absf(_panel_height(main) - 98.0) <= 1.0, "KR7 a held 0-count row beside one live kind keeps the footer, got %.1f" % _panel_height(main))
	if held == null:
		_end_port(scene)
		return true
	var before: Array[int] = main.orders.selected_ids.duplicate()
	_row_click(port, held, false)
	await _frames(runner)
	runner.check(main.orders.selected_ids == before, "KR4 a click on the held row changes nothing, got %s" % [main.orders.selected_ids])
	_move(port, _row(main, "usa_rifle_infantry").get_global_rect().get_center())
	await _frames(runner)
	BaseScene.publish(main)
	runner.check(_row(main, "usa_tank") != null, "KR4 moving to the next row keeps the hold")
	sim.remove_object(ids.usa_rifle_infantry[1])
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(main.orders.selected_ids.size() == 1 and _row_names(main) == ["Row_usa_tank", "Row_usa_rifle_infantry"] and _many(main, "Header").is_visible_in_tree(), "KR4 one unit left: the rows hold, got %s" % [_row_names(main)])
	_move(port, _many(main, "Header").get_global_rect().get_center())
	await _frames(runner)
	runner.check(_row(main, "usa_tank") != null, "KR4 the pointer on the header keeps the hold")
	_move(port, Vector2(900, 200))
	await _frames(runner)
	runner.check(not _many(main, "Header").is_visible_in_tree() and _panel_texts(main).Name == "Rifleman" and absf(_panel_height(main) - 62.0) <= 1.0, "KR4 the pointer left through the header, no new view: the one-unit panel shows, got %s %.1f" % [_panel_texts(main), _panel_height(main)])
	main.hud.reset()
	runner.check(main.hud._last.is_empty() and main.hud._counts.is_empty(), "KR4 reset drops the held rows and the last inputs")
	BaseScene.publish(main)
	sim.remove_object(ids.usa_rifle_infantry[0])
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(not main.get_node("HUD/Hud/SelectionPanel").is_visible_in_tree(), "KR4 nothing left: the panel hides")
	_end_port(scene)
	return true

func test_row_bar_is_the_health_sum(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _rows_world(main, [["usa_tank", 2], ["usa_rifle_infantry", 1]])
	var view: Dictionary = main.driver.current().view
	view.units.hp[view.units.index_of(ids.usa_tank[0])] = 240000
	_pick(main, _all(ids), -1, -1)
	var row: Button = _row(main, "usa_tank")
	runner.check(row != null, "KR5 the tank row shows")
	if row != null:
		var bar: ColorRect = row.get_node("Track/Bar")
		runner.check(is_equal_approx(bar.anchor_right, 0.75) and bar.color == View.health_color(0.75) and (row.get_node("Count") as Label).text == "2", "KR5 one tank at half: the bar is 720 / 960 in the health colour, got %.3f %s" % [bar.anchor_right, bar.color])
	main.free()
	return true

func test_row_hover(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	_rows_world(main, [["usa_tank", 1], ["usa_rifle_infantry", 2]])
	await _frames(runner)
	var hovered: Button = _row(main, "usa_tank")
	var other: Button = _row(main, "usa_rifle_infantry")
	runner.check(hovered != null and other != null, "KR6 both rows show")
	if hovered == null or other == null:
		_end_port(scene)
		return true
	_move(port, hovered.get_global_rect().get_center())
	await _frames(runner)
	var look: StyleBoxFlat = hovered.get_theme_stylebox("hover") as StyleBoxFlat
	var plain: StyleBoxFlat = other.get_theme_stylebox("normal") as StyleBoxFlat
	runner.check(hovered.is_hovered() and hovered.get_draw_mode() == BaseButton.DRAW_HOVER and look != null and look.bg_color == _token("panel2") and look.border_color == _token("muted") and look.border_width_left == 1 and look.border_width_top == 1 and look.border_width_right == 1 and look.border_width_bottom == 1, "KR6 the hovered row: panel2 with a 1 px muted inset")
	runner.check(hovered.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "KR6 the hovered row shows the pointing hand")
	var inner: Rect2 = hovered.get_global_rect().grow(-1.0)
	var track: Rect2 = (hovered.get_node("Track") as Control).get_global_rect()
	runner.check(inner.encloses(track) and is_equal_approx(track.size.y, 3.0) and is_equal_approx(track.end.y, inner.end.y), "KR6 the hovered row's track sits inside the 1 px frame, got %s in %s" % [track, inner])
	var flush: Rect2 = (other.get_node("Track") as Control).get_global_rect()
	runner.check(is_equal_approx(flush.size.x, 186.0) and is_equal_approx(flush.end.y, other.get_global_rect().end.y), "KR6 an unhovered row's track runs the full width at the bottom, got %s" % flush)
	runner.check(not other.is_hovered() and other.get_draw_mode() == BaseButton.DRAW_NORMAL and plain != null and plain.bg_color == _token("btn") and plain.border_width_left == 0 and plain.border_width_top == 0, "KR6 an unhovered row has no inset")
	_end_port(scene)
	return true

func test_rows_footer(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	_rows_world(main, [["usa_tank", 1], ["usa_rifle_infantry", 2]])
	await _frames(runner)
	var footer: Label = _many(main, "Footer") as Label
	runner.check(footer != null and footer.is_visible_in_tree() and footer.text == RULE and footer.theme_type_variation == &"HudHint" and absf(_panel_height(main) - 98.0) <= 1.0, "KR7 two kinds: the footer reads the rule, 98 high, got %.1f" % _panel_height(main))
	if footer == null:
		main.free()
		return true
	var six: Array = ROSTERS.china.map(func(kind: String) -> Array: return [kind, 1])
	_rows_world(main, six)
	await _frames(runner)
	runner.check(footer.is_visible_in_tree() and absf(_panel_height(main) - 158.0) <= 1.0, "KR7 six kinds: 158 high, got %.1f" % _panel_height(main))
	_rows_world(main, [["usa_tank", 3]])
	await _frames(runner)
	runner.check(not footer.is_visible_in_tree() and absf(_panel_height(main) - 76.0) <= 1.0, "KR7 one kind: no footer, 76 high, got %.1f" % _panel_height(main))
	main.free()
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], pair[1])
		var at_size = await overlays._scene(runner, Skirmish, port)
		_rows_world(at_size, [["usa_tank", 1], ["usa_rifle_infantry", 2]])
		await _frames(runner)
		var content: Rect2 = _rect(at_size, "HUD/Hud/SelectionPanel").grow_individual(-16.0, -12.0, -16.0, -12.0)
		var rect: Rect2 = _many(at_size, "Footer").get_global_rect()
		runner.check(content.grow(0.5).encloses(rect) and rect.size.x <= 376.0, "KR7 at %s the footer lies inside the panel content %s, got %s" % [pair[1], content, rect])
		port.free()
	overlays._end(saved)
	return true

# Synthetic unit rows for the label table; `collection` only when a phase is given.
static func _unit_row(id: int, owner: int, kind: String, phase: String = "", collecting: bool = false, status: String = "idle", extra: Dictionary = {}) -> Dictionary:
	var unit := {"id": id, "owner": owner, "kind": kind, "hp": 300000, "max_hp": 300000, "position": [4.5, 4.5], "status": status}
	if not phase.is_empty(): unit.collection = {"enabled": collecting, "phase": phase, "target_id": null}
	return unit.merged(extra)

# Shows `units` on a bare Hud and returns the one-unit panel's right label, "" when hidden.
func _label_on(runner, hud: Hud, units: Array, ids: Array, sources: Array = [], buildings: Array = [], faction: String = "usa", inspected: int = -1) -> String:
	var view: Dictionary = _strip_view(0, 0, 0, faction)
	view.units = ViewRows.from_units(units)
	view.sources = sources
	view.buildings = buildings
	var selection: Dictionary = _armed("")
	selection.ids.assign(ids)
	selection.inspected_id = inspected
	hud.update_hud(view, selection, 1, 1)
	await runner.process_frame
	var right: Label = hud.get_node("SelectionPanel").find_child("RightLabel", true, false)
	return right.text if right.is_visible_in_tree() else ""

const LABELS: Array = [["flying_source", "TO PILE"], ["lead_source", "TO PILE"], ["waiting_source", "WAITING AT PILE"], ["loading", "LOADING"], ["flying_depot", "TO SUPPLY DEPOT"], ["lead_depot", "TO SUPPLY DEPOT"], ["waiting_depot", "WAITING AT SUPPLY DEPOT"], ["unloading", "UNLOADING"]]

func test_collector_label_table(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var full: Array = [{"id": 30, "boxes": 4}]
	var empty: Array = [{"id": 30, "boxes": 0}]
	for row: Array in LABELS:
		var got: String = await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", row[0], true)], [5], full)
		runner.check(got == row[1], "CL1 collecting, %s reads %s, got '%s'" % [row[0], row[1], got])
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "idle", true)], [5], full) == "WAITING AT PILE", "CL1 collecting and idle while a pile holds boxes (busy-dock retry) reads WAITING AT PILE")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "idle", true)], [5], empty) == "IDLE", "CL1 collecting and idle with no pile holding boxes reads IDLE")
	for status: String in ["moving", "path_pending"]:
		runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "idle", false, status)], [5], full) == "MOVING", "CL1 not collecting, %s reads MOVING" % status)
	var site: Array = [{"id": 9, "owner": 1, "kind": "frc_barracks", "completed": false, "builder_id": 5}]
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "idle")], [5], full, site) == "BUILDING", "CL1 the named builder of a site reads BUILDING")
	var done: Array = [{"id": 9, "owner": 1, "kind": "frc_barracks", "completed": true, "builder_id": 5}]
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "idle")], [5], full, done) == "IDLE", "CL1 a finished building's builder reads IDLE")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "idle", false, "contained", {"container_id": 7})], [5], full) == "", "CL1 a collector inside a transport has no label")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "idle")], [5], full) == "IDLE", "CL1 not collecting, nothing else reads IDLE")
	await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "loading", true)], [5])
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "seeking", true)], [5]) == "LOADING", "CL1 seeking holds the previous label")
	await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "seeking", true)], [])
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "seeking", true)], [5]) == "", "CL1 seeking after a deselect and reselect has no label")
	await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "loading", true)], [5])
	hud.reset()
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "seeking", true)], [5]) == "", "CL1 seeking after a restart has no label")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "flying_depot", true)], [5], full, [], "frc") == "TO SUPPLY CACHE", "CL1 FRC reads TO SUPPLY CACHE")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "waiting_depot", true)], [5], full, [], "frc") == "WAITING AT SUPPLY CACHE", "CL1 FRC reads WAITING AT SUPPLY CACHE")
	var enemy: String = await _label_on(runner, hud, [_unit_row(5, 2, "china_collector", "loading", true)], [], full, [], "usa", 5)
	var enemy_view: Dictionary = _strip_view(0, 0, 0)
	enemy_view.units = ViewRows.from_units([_unit_row(5, 2, "china_collector", "idle")])
	var enemy_ids: Array[int] = [5]
	runner.check(HudModel.collector_labels(enemy_view, enemy_ids, 1, "usa", {}).is_empty(), "CL1 collector_labels skips another owner's collector")
	runner.check(enemy == "" and (hud.get_node("SelectionPanel").find_child("Name", true, false) as Label).text == "Supply Truck", "CL1 an inspected enemy collector shows no label, got '%s'" % enemy)
	hud.get_parent().free()
	return true

func _header_on(runner, hud: Hud, units: Array) -> String:
	var ids: Array = units.map(func(unit: Dictionary) -> int: return unit.id)
	await _label_on(runner, hud, units, ids)
	var header: Label = hud.get_node_or_null("SelectionPanel/Box/Many/Header")
	return header.text if header != null and header.is_visible_in_tree() else ""

func test_idle_header(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var tanks: Array = range(4).map(func(n: int) -> Dictionary: return _unit_row(10 + n, 1, "china_tank"))
	var working: Array = range(4).map(func(n: int) -> Dictionary: return _unit_row(20 + n, 1, "china_collector", "loading", true))
	var idle: Array = [_unit_row(30, 1, "china_collector", "idle"), _unit_row(31, 1, "china_collector", "idle")]
	var one: String = await _header_on(runner, hud, tanks + working + idle.slice(0, 1))
	runner.check(one == "9 selected · 2 kinds · 1 idle collector", "CL3 one idle collector, got '%s'" % one)
	var two: String = await _header_on(runner, hud, tanks + working.slice(0, 3) + idle)
	runner.check(two == "9 selected · 2 kinds · 2 idle collectors", "CL3 two idle collectors, got '%s'" % two)
	var none: String = await _header_on(runner, hud, tanks + working)
	runner.check(none == "8 selected · 2 kinds", "CL3 none idle: no suffix, got '%s'" % none)
	hud.get_parent().free()
	return true

static func _health_sum(view: Dictionary, ids: Array) -> float:
	var hp: int = 0
	var most: int = 0
	for id: int in ids:
		hp += view.units.hp[view.units.index_of(id)]
		most += view.units.max_hp[view.units.index_of(id)]
	return float(hp) / most

static func _panel_nodes(main) -> Array:
	return _controls(main.get_node("HUD/Hud/SelectionPanel")).map(func(node: Control) -> int: return node.get_instance_id())

func test_rebuild_count(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _rows_world(main, [["usa_tank", 3], ["usa_rifle_infantry", 2]])
	var sim = main.driver.pump.live()
	var enemies: Array[int] = [sim.spawn(2, Vector2(12.5, 12.5), "usa_tank"), sim.spawn(2, Vector2(13.5, 12.5), "usa_tank")]
	main._show(sim.view_state())
	var rebuilds: int = main.hud.rebuilds
	var nodes: Array = _panel_nodes(main)
	var start: int = sim.view_state().units.hp[sim.view_state().units.index_of(ids.usa_tank[0])]
	for tick in 60:
		sim.step()
		main._show(sim.view_state())
	var view: Dictionary = sim.view_state()
	var hurt: bool = false
	for id: int in _all(ids): hurt = hurt or view.units.hp[view.units.index_of(id)] < view.units.max_hp[view.units.index_of(id)]
	runner.check(hurt and _all(ids).all(func(id: int) -> bool: return view.units.index_of(id) != -1) and enemies.size() == 2 and start > 0, "HN3 fixture: the fight hurt a selected unit and killed none")
	runner.check(main.hud.rebuilds == rebuilds and _panel_nodes(main) == nodes, "HN3 60 fight ticks with one selection rebuild nothing, got %d after %d" % [main.hud.rebuilds, rebuilds])
	var tank_row: Button = _row(main, "usa_tank")
	if tank_row != null:
		runner.check(is_equal_approx((tank_row.get_node("Track/Bar") as Control).anchor_right, _health_sum(view, ids.usa_tank)), "HN3 the tank bar follows the fight")
	view.units.hp[view.units.index_of(ids.usa_tank[1])] = 100000
	view.players[0].credits += 500
	main._show(view)
	var bar: float = (tank_row.get_node("Track/Bar") as Control).anchor_right if tank_row != null else -1.0
	runner.check(main.hud.rebuilds == rebuilds and _panel_nodes(main) == nodes and (main.get_node("HUD/Hud/TopStrip").find_child("Credits", true, false) as Label).text == str(view.players[0].credits) and is_equal_approx(bar, _health_sum(view, ids.usa_tank)), "HN3 credit and health changes patch the strip and the bar in place, no rebuild, got %d %.3f" % [main.hud.rebuilds, bar])
	for change: Array in [ids.usa_tank, ids.usa_rifle_infantry, _all(ids)]:
		var before: int = main.hud.rebuilds
		_pick(main, change, -1, -1)
		runner.check(main.hud.rebuilds == before + 1, "HN3 a selection change adds one rebuild, got %d after %d" % [main.hud.rebuilds, before])
	main.free()
	return true
