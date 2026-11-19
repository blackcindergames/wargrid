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
const Iso = preload("res://scripts/presentation/isometric.gd")
const LOW: String = "LOW POWER · DEFENCES OFF"
const MINUS: String = "\u2212"
const THEME_PATH: String = "res://ui/launcher_theme.tres"
const TOKENS: Dictionary = {"bg": "#121c24", "btn": "#223241", "panel2": "#26384a", "quiet": "#16212a", "well": "#0c141a", "line": "#2e3f4b", "text": "#eef3f5", "muted": "#93a5b0", "sel": "#60e5ed", "amber": "#f7c871", "warn": "#f47b6c"}
const TYPE_SCALE: Array[int] = [12, 13, 14, 16, 24, 30]
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const SMALL: int = 12

func cases() -> Array[Callable]:
	return [test_theme_tokens, test_type_scale, test_no_rounding_or_shadow, test_match_surfaces_keep_their_size, test_hud_reads_only_its_input, test_side_effects_live_in_the_screen, test_power_reads_used_over_available, test_forecast_forms, test_swatch_slot_colour, test_strip_anchor_without_tick, test_strip_patches_values]

# The match scene's economy column: the screen adds BuildMenu, skirmish.tscn the rest.
static func _economy() -> VBoxContainer:
	var economy := VBoxContainer.new()
	for part: Control in [GridContainer.new(), Button.new(), Button.new(), VBoxContainer.new()]: economy.add_child(part)
	for i in 4: economy.get_child(i).name = ["BuildMenu", "Produce", "CancelBuild", "Queue"][i]
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
	var selection: Dictionary = {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": "", "resume_id": -1, "notice": "", "production_kind": "", "bright_owners": false, "over": false}
	hud.update_hud(Fixture.make_world().view_state(), selection, 1, 1)
	runner.check(hud.name == "Hud" and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.anchor_right == 1.0 and hud.anchor_bottom == 1.0, "HN1 the Hud is a full-rect node that ignores the mouse")
	runner.check(_part(hud, "TopStrip", "Credits").text == "10000" and status.text.contains(Registry.kind("usa_builder").display_name + " #1"), "HN1 the strip and the Status fixture fill from the view and the selection alone, got '%s'" % status.text)
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
	for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog", "HUD/PerfOverlay", "HUD/Economy"]:
		var surface: Control = main.get_node(path)
		runner.check(path == "HUD/Economy" or surface.is_visible_in_tree(), "TH5 %s is shown" % path)
		_check_small(runner, surface, view, path)
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

static func _armed(kind: String, bright: bool = false) -> Dictionary:
	var ids: Array[int] = []
	return {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": kind, "resume_id": -1, "notice": "", "production_kind": "", "bright_owners": bright, "over": false}

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
