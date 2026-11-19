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
const THEME_PATH: String = "res://ui/launcher_theme.tres"
const TOKENS: Dictionary = {"bg": "#121c24", "btn": "#223241", "panel2": "#26384a", "quiet": "#16212a", "well": "#0c141a", "line": "#2e3f4b", "text": "#eef3f5", "muted": "#93a5b0", "sel": "#60e5ed", "amber": "#f7c871", "warn": "#f47b6c"}
const TYPE_SCALE: Array[int] = [12, 13, 14, 16, 24, 30]
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const SMALL: int = 12

func cases() -> Array[Callable]:
	return [test_theme_tokens, test_type_scale, test_no_rounding_or_shadow, test_match_surfaces_keep_their_size, test_hud_reads_only_its_input, test_side_effects_live_in_the_screen]

# The match scene's economy column: the screen adds BuildMenu, skirmish.tscn the rest.
static func _economy() -> VBoxContainer:
	var economy := VBoxContainer.new()
	for part: Control in [GridContainer.new(), Button.new(), Button.new(), VBoxContainer.new()]: economy.add_child(part)
	for i in 4: economy.get_child(i).name = ["BuildMenu", "Produce", "CancelBuild", "Queue"][i]
	return economy

func test_hud_reads_only_its_input(runner) -> bool:
	# Untyped load: at HEAD the two-argument _init would make a typed Hud.new() fail the whole runner.
	var script: GDScript = load("res://scripts/match/hud.gd")
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
	runner.check(status.text.contains("Credits: 10000") and status.text.contains(Registry.kind("usa_builder").display_name + " #1"), "HN1 the Status fixture fills from the view and the selection alone, got '%s'" % status.text)
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
