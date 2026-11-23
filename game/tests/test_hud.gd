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
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
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
	return [test_theme_tokens, test_type_scale, test_no_rounding_or_shadow, test_match_surfaces_keep_their_size, test_hud_reads_only_its_input, test_side_effects_live_in_the_screen, test_power_reads_used_over_available, test_forecast_forms, test_hover_previews_the_purchase, test_build_button_hover_inset, test_swatch_slot_colour, test_strip_anchor_without_tick, test_strip_patches_values, test_strip_holds_while_on_the_card, test_strip_skips_refused_purchases, test_chip_stack, test_esc_chip_only_when_esc_opens_the_menu, test_menu_chip_keeps_its_width, test_menu_chip_opens_the_menu, test_online_notice_top_centre, test_stack_follows_size_changes, test_slab_rect, test_slab_china_with_overlays, test_armed_button_look, test_slab_order_buttons, test_slab_buttons_hold_still, test_queue_tiles_merge_adjacent_waiting, test_queue_tile_click_cancels_newest_of_run, test_queue_tiles_keep_entry_ids, test_queue_tiles_hold_under_pointer, test_queue_hold_keeps_progress, test_queue_fresh_after_kind_rows, test_queue_more_counts_hidden, test_cells_count_without_a_bar, test_queue_full_at_9, test_right_click_cell_cancels_newest_of_kind, test_queue_cancels_in_one_frame, test_factory_panel_fixed_152, test_unload_row_above_the_orders, test_unload_needs_its_own_rider, test_card_by_selection, test_card_click_equals_key, test_card_lattice, test_cell_names_fit, test_cell_costs_by_credits, test_blocked_cells, test_blocked_press_equals_key, test_build_click_sounds, test_cell_card_timing, test_open_cell_card_waits_for_a_change, test_cell_card_lines, test_prerequisite_hint, test_counter_lines_match_damage, test_counter_line_on_the_cell_card, test_right_labels_on_the_name_line, test_key_labels, test_floor_follows_a_resize, test_panel_states_layout, test_panel_values, test_panel_edge_colours, test_owner_colours_contrast, test_side_band_contrast, test_panel_edge_is_the_body_colour, test_kind_rows, test_six_kinds_at_most, test_roster_fits, test_row_click_narrows_and_shift_removes, test_rows_hold_under_the_pointer, test_rows_let_go_when_the_pointer_leaves_the_window, test_fresh_selection_over_the_panel_drops_the_hold, test_row_bar_is_the_health_sum, test_row_hover, test_rows_footer, test_collector_label_table, test_no_drop_off_label, test_collector_labels_in_a_mixed_army, test_idle_header, test_rebuild_count, test_unchanged_refresh_keeps_layout, test_refusal_line_place, test_refusal_timer_and_replace, test_accepted_answer_clears, test_placement_refusal_after_the_click_only, test_local_hints_on_the_line, test_esc_placement_layer, test_esc_attack_move_layer, test_esc_sub_grid_layer, test_esc_selection_layer, test_esc_inspection_layer, test_esc_layers_in_order, test_esc_in_the_frame_of_a_card_key, test_esc_and_back_in_one_frame, test_esc_during_a_drag_with_the_sub_grid_open, test_esc_as_the_builder_dies]

# The match scene's economy column as skirmish.tscn has it; the Hud adds the rest.
static func _economy() -> VBoxContainer:
	var economy := VBoxContainer.new()
	var cancel := Button.new()
	cancel.name = "CancelBuild"
	economy.add_child(cancel)
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
	var economy := _economy()
	parent.add_child(economy)
	hud.setup(economy)
	var ids: Array[int] = [1]
	var selection: Dictionary = {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": "", "resume_id": -1, "notice": "", "bright_owners": false, "over": false, "esc_opens_menu": true, "attack_move": false}
	hud.update_hud(Fixture.make_world().view_state(), selection, 1, 1)
	runner.check(hud.name == "Hud" and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.anchor_right == 1.0 and hud.anchor_bottom == 1.0, "HN1 the Hud is a full-rect node that ignores the mouse")
	var panel_name: String = _part(hud, "SelectionPanel", "Name").text
	runner.check(_part(hud, "TopStrip", "Credits").text == "10000" and panel_name == Registry.kind("usa_builder").display_name, "HN1 the strip and the selection panel fill from the view and the selection alone, got '%s'" % panel_name)
	runner.check(_actions(economy) == ["build"], "HN1 the builder's card fills from the selection, got %s" % [_actions(economy)])
	var sim = Fixture.make_world()
	var tank: int = sim.spawn(1, Vector2(8.5, 8.5), "usa_tank")
	var other: int = sim.spawn(1, Vector2(10.5, 8.5), "china_builder")
	for case: Array in [[tank, false, ["attack_move", "stop"], "a tank's card"], [other, true, Registry.kind("china_builder").builds + ["back"], "another faction's builder brings its own sub-grid"]]:
		ids.assign([case[0]])
		selection.sub_grid = case[1]
		hud.update_hud(sim.view_state(), selection, 1, 1)
		runner.check(_actions(economy) == case[2], "HN1 %s, got %s" % [case[3], _actions(economy)])
	parent.free()
	return true

func test_side_effects_live_in_the_screen(runner) -> bool:
	var main = await BaseScene.new().setup(runner)
	runner.check(main.hud.has_signal("cell_pressed") and main.hud.has_signal("cancel_build_pressed"), "HN2 the Hud speaks through its signals")
	if not main.hud.has_signal("cell_pressed"):
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
	var chosen: Array[String] = []
	main.hud.cell_pressed.connect(func(action: String) -> void: chosen.append(action))
	_cell(main, "build").pressed.emit()
	_cell(main, "usa_power_plant").pressed.emit()
	runner.check(chosen == ["build", "usa_power_plant"] and main.orders._placement_kind == "usa_power_plant", "HN2 Build, then the Power Plant cell emit cell_pressed and arm placement, got %s '%s'" % [chosen, main.orders._placement_kind])
	main.orders.reset()
	main.orders.selected_building_id = barracks
	main._refresh()
	BaseScene.new().key(main, KEY_E)
	runner.check(main.driver.queued().is_empty() and not main.has_node("HUD/Economy/Produce"), "HN2 no Produce button and E produces nothing (dropped, user 2026-11-20), got %s" % [main.driver.queued()])
	_cell(main, "usa_rifle_infantry").pressed.emit()
	var queued: Array = main.driver.queued()
	runner.check(chosen.back() == "usa_rifle_infantry" and queued.size() == 1 and queued[0].type == "produce" and queued[0].building_id == barracks and queued[0].unit_kind == "usa_rifle_infantry", "HN2 the barracks' Rifleman cell queues one through cell_pressed, got %s" % [queued])
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
	runner.check(main.get_node("HUD/PerfOverlay").theme_type_variation == &"HudSmallNumber", "TH5 the F3 overlay prints tabular digits")
	for path: String in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog", "HUD/PerfOverlay"]:
		var surface: Control = main.get_node(path)
		runner.check(surface.is_visible_in_tree(), "TH5 %s is shown" % path)
		_check_small(runner, surface, view, path)
	# The slab left the 12 px surfaces at Task 9 (owner question 4): its sizes are the type scale's.
	for control: Control in _text_controls(main.get_node("HUD/Economy")):
		runner.check(control.get_theme_font_size("font_size") in TYPE_SCALE, "TH5 HUD/Economy %s is on the type scale, got %d" % [control.name, control.get_theme_font_size("font_size")])
		if control.is_visible_in_tree(): runner.check(view.encloses(_clip(control).get_global_rect()), "TH5 HUD/Economy %s inside the view" % control.name)
	_square_rows(runner, ["CancelBuild"].map(func(path: String) -> Button: return main.get_node("HUD/Economy/" + path)), "TH5")
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
	return {"ids": ids, "building_id": -1, "inspected_id": -1, "placement_kind": kind, "resume_id": -1, "notice": notice, "bright_owners": bright, "over": false, "esc_opens_menu": true, "attack_move": false}

# Placement closes the moment its builder is gone, so an armed placement needs a selected one.
func _select_new_builder(main) -> void:
	var builder: int = main.driver.pump.live().spawn(main.local_player, Vector2(9.5, 10.5), "usa_builder")
	BaseScene.publish(main)
	main.orders.selected_ids.assign([builder])

func _bare_hud(runner) -> Hud:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	runner.root.add_child(port)
	var hud := Hud.new()
	port.add_child(hud)
	hud.setup(null)
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
	hud.get_parent().free()
	return true

func _no_arrow_glyph_or_label(runner, hud: Hud, label: String) -> void:
	for found: Node in hud.find_children("*", "Label", true, false):
		var text: String = (found as Label).text
		if (found as Label).is_visible_in_tree(): runner.check(not text.contains("→") and not text.contains("short") and not text.contains("PREVIEW"), "TS2 %s: no arrow glyph, no 'short' and no PREVIEW in '%s'" % [label, text])

# A forecast shows as an arrow on a slab whose number changes.
static func _forecasting(hud: Node) -> bool:
	return ["CreditsArrow", "PowerArrow"].any(func(part: String) -> bool: return _part(hud, "TopStrip", part).is_visible_in_tree())

static func _border(slab: Control) -> Color:
	return (slab.get_theme_stylebox("panel") as StyleBoxFlat).border_color

static func _slabs(hud: Node) -> Array[Control]:
	return [hud.get_node("TopStrip/CreditsGroup"), hud.get_node("TopStrip/PowerGroup")]

static func _gap(left: Control, right: Control) -> float:
	return right.get_global_rect().position.x - left.get_global_rect().end.x

# One strip form: [credits, after or "", coin, power, power after or "", low power, credits frame, power frame].
static func _form(hud: Node) -> Array:
	var shown: Callable = func(part: String) -> bool: return _part(hud, "TopStrip", part).is_visible_in_tree()
	var text: Callable = func(part: String) -> String: return (_part(hud, "TopStrip", part) as Label).text if shown.call(part) else ""
	var slabs: Array[Control] = _slabs(hud)
	return [text.call("Credits"), text.call("CreditsAfter"), shown.call("Coin"), text.call("Power"), text.call("PowerAfter"), shown.call("LowPower"), _border(slabs[0]) == _token("sel"), _border(slabs[1]) == _token("sel")]

# Top strip round (user, 2026-11-22): today's number, a drawn arrow and the forecast; the sel frame on each slab whose number changes; no PREVIEW.
# LOW POWER preview (3-5): the words only when the purchase flips power low; already low, the numbers alone turn warn.
func test_forecast_forms(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	await _show(runner, hud, _strip_view(4800, 8, 10), "china_defence")
	var credits: Label = _part(hud, "TopStrip", "Credits")
	var after: Label = _part(hud, "TopStrip", "CreditsAfter")
	var arrow: Control = _part(hud, "TopStrip", "CreditsArrow")
	var coin: Control = _part(hud, "TopStrip", "Coin")
	var power: Label = _part(hud, "TopStrip", "Power")
	var power_after: Label = _part(hud, "TopStrip", "PowerAfter")
	var low: Label = _part(hud, "TopStrip", "LowPower")
	var slabs: Array[Control] = _slabs(hud)
	runner.check(hud.find_child("Preview", true, false) == null and hud.find_child("Delta", true, false) == null, "TS2 no Preview label and no Delta number")
	runner.check(_form(hud) == ["4800", "3600", false, "8 / 10", "11 / 10", true, true, true], "TS2 a Rotary Gun Tower armed: 4800 → 3600, 8 / 10 → 11 / 10 with LOW POWER, both slabs framed, got %s" % [_form(hud)])
	runner.check(_colour(credits) == _token("text") and _colour(after) == _token("text") and _colour(power) == _token("text") and _colour(power_after) == _token("warn") and low.text == LOW and _colour(low) == _token("warn"), "TS2 today's numbers in text, the low-power forecast and its words in warn")
	runner.check(arrow.get_global_rect().size == Vector2(12, 8) and is_equal_approx(arrow.get_global_rect().get_center().y, slabs[0].get_global_rect().get_center().y) and is_equal_approx(_gap(credits, arrow), 8.0) and is_equal_approx(_gap(arrow, after), 8.0), "TS2 the drawn 12 x 8 arrow sits centred, 8 px from each number, got %s gaps %.1f %.1f" % [arrow.get_global_rect(), _gap(credits, arrow), _gap(arrow, after)])
	_no_arrow_glyph_or_label(runner, hud, "tower")
	await _show(runner, hud, _strip_view(4800, 8, 10), "usa_power_plant")
	runner.check(_form(hud) == ["4800", "4000", false, "8 / 10", "8 / 15", false, true, true] and _colour(power_after) == _token("text"), "TS2 a Power Plant armed: 4800 → 4000 and 8 / 10 → 8 / 15, no low power, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(4800, 8, 10), "china_light_vehicle")
	runner.check(_form(hud) == ["4800", "4000", false, "8 / 10", "", false, true, false], "TS2 a unit: only the credits slab forecasts and takes the frame, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(10650, 8, 10))
	runner.check(_form(hud) == ["10650", "", false, "8 / 10", "", false, false, false] and not _forecasting(hud), "TS2 nothing armed: 10650 and 8 / 10, no arrow, line borders, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(4800, 12, 10))
	runner.check(_form(hud) == ["4800", "", false, "12 / 10", "", true, false, false] and _colour(power) == _token("warn"), "TS2 low power at rest: 12 / 10 in warn with its words, no frame, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(4800, 12, 10), "china_defence")
	runner.check(_form(hud) == ["4800", "3600", false, "12 / 10", "15 / 10", false, true, true] and _colour(power) == _token("warn") and _colour(power_after) == _token("warn"), "TS2 already low: 12 / 10 → 15 / 10 both in warn, no LOW POWER words, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(4800, 12, 10), "china_light_vehicle")
	runner.check(_form(hud) == ["4800", "4000", false, "12 / 10", "", false, true, false] and _colour(power) == _token("warn"), "TS2 already low, a unit changes no power: 12 / 10 in warn, no LOW POWER words while it forecasts, got %s" % [_form(hud)])
	await _show(runner, hud, _strip_view(500, 8, 10), "china_defence")
	runner.check(_form(hud) == ["500", MINUS + "700", true, "8 / 10", "11 / 10", true, true, true], "TS2 short: 500 → −700 (U+2212) with the coin, power still forecasts, got %s" % [_form(hud)])
	runner.check(_colour(credits) == _token("text") and _colour(after) == _token("warn") and coin.get_global_rect().size == Vector2(15, 15) and is_equal_approx(_gap(after, coin), 4.0), "TS2 short: the forecast in warn, the 15 px coin 4 px after it, got %s gap %.1f" % [coin.get_global_rect(), _gap(after, coin)])
	await _show(runner, hud, _strip_view(4800, 8, 10), "china_defence")
	runner.check(_form(hud)[1] == "3600" and not _form(hud)[2] and _colour(after) == _token("text"), "TS2 affordable again: the forecast in text, no coin, got %s" % [_form(hud)])
	_no_arrow_glyph_or_label(runner, hud, "shortfall")
	for armed: String in ["", "frc_barracks"]:
		await _show(runner, hud, _strip_view(4800, 0, 0, "frc"), armed)
		runner.check(not slabs[1].is_visible_in_tree() and slabs[0].is_visible_in_tree() and hud.get_node("TopStrip").get_global_rect() == slabs[0].get_global_rect(), "TS2 FRC uses no power: the credits slab alone (armed '%s')" % armed)
	runner.check(_form(hud).slice(0, 3) == ["4800", "4300", false] and _border(slabs[0]) == _token("sel"), "TS2 FRC forecasts its credits, got %s" % [_form(hud)])
	Registry.add_test_kind("test_free_building", {"display_name": "Free", "cost": 0, "produces": []})
	await _show(runner, hud, _strip_view(4800, 8, 10), "test_free_building")
	Registry.clear_test_kinds()
	runner.check(_form(hud) == ["4800", "", false, "8 / 10", "", false, false, false], "TS2 a free building without power changes no number: no arrow, no frame, got %s" % [_form(hud)])
	hud.get_parent().free()
	await _forecast_follows_the_placement(runner)
	return true

func _forecast_follows_the_placement(runner) -> void:
	var helper = BaseScene.new()
	var main = await helper.setup(runner)
	main.driver.adopt(Fixture.make_world())
	main.orders.selected_ids.assign([1])
	main._refresh()
	_sub_grid(main, 1)
	main.hud.now_msec = func() -> int: return 0
	_cell(main, "usa_power_plant").mouse_entered.emit()
	main.hud.now_msec = func() -> int: return 1000
	main.hud._process(0.0)
	var card: Control = main.get_node("HUD/Hud/CellCard")
	var said: Array = card.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text)
	runner.check(card.visible and _forecasting(main.hud) and said == ["Power Plant", "800 · 10 s"], "TS2 no forecast on the cell card (3-4): the strip forecasts, the card reads its name and cost · time alone, got %s" % [said])
	_cell(main, "usa_power_plant").mouse_exited.emit()
	helper.build_key(main, "usa_power_plant")
	runner.check(_forecasting(main.hud), "TS2 arming a building shows the preview")
	helper.key(main, KEY_ESCAPE)
	runner.check(not _forecasting(main.hud), "TS2 cancelling the placement ends the preview")
	helper.build_key(main, "usa_power_plant")
	helper.hover(main, Iso.world_to_plane(Vector2(8.25, 4.25)))
	helper.pointer(main, Iso.world_to_plane(Vector2(8.25, 4.25)), MOUSE_BUTTON_LEFT, false)
	BaseScene.tick(main)
	runner.check(main.orders._placement_kind.is_empty() and not _forecasting(main.hud), "TS2 placing the building ends the preview")
	main.free()
	var skirmish = SkirmishTests.new()
	main = await skirmish._setup(runner)
	skirmish._arena(main)
	_select_new_builder(main)
	main.orders._placement_kind = "usa_power_plant"
	main._refresh()
	runner.check(_forecasting(main.hud), "TS2 the arena previews while armed")
	skirmish._victory(main)
	runner.check(main.shown_over() and main.orders._placement_kind.is_empty() and not _forecasting(main.hud), "TS2 the match ending clears the placement and ends the preview")
	main.free()
	var online: Dictionary = await OverlayTests.new()._online(runner)
	main = online.main
	_select_new_builder(main)
	main.orders._placement_kind = "usa_power_plant"
	main._refresh()
	runner.check(_forecasting(main.hud), "TS2 online: the strip previews while armed")
	main.driver._finished = true
	main._refresh()
	runner.check(main.orders._placement_kind.is_empty() and not _forecasting(main.hud), "TS2 an online lockstep ending clears the placement and ends the preview")
	main.free()

# The forecast's cost read off the strip: today's credits less the forecast; "" while the credits slab forecasts nothing.
static func _delta(main) -> String:
	if not _part(main.hud, "TopStrip", "CreditsArrow").is_visible_in_tree(): return ""
	var after: String = (_part(main.hud, "TopStrip", "CreditsAfter") as Label).text.replace(MINUS, "-")
	return str(int((_part(main.hud, "TopStrip", "Credits") as Label).text) - int(after))

# Strip preview follow-ups (user 2026-11-20): hovering a build or unit button previews it; an armed building returns on exit.
func test_hover_previews_the_purchase(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_sub_grid(main, ids.builder)
	var tower: Button = _cell(main, "china_defence")
	var plant: String = str(Registry.kind("china_power_plant").cost)
	var rebuilds: int = main.hud.rebuilds
	tower.mouse_entered.emit()
	runner.check(_delta(main) == "1200" and main.orders._placement_kind.is_empty(), "TS6 hovering the tower forecasts its 1200 without arming, got '%s'" % _delta(main))
	var view: Dictionary = main.driver.current().view
	HudModel.player(view, 1).credits = 3000
	main._show(view)
	runner.check(_form(main.hud).slice(0, 2) == ["3000", "1800"], "TS6 the pointer resting on the tower: the forecast follows a credit change, 3000 → 1800, got %s" % [_form(main.hud)])
	tower.mouse_exited.emit()
	runner.check(_delta(main) == "" and main.hud.rebuilds == rebuilds, "TS6 off the tower: no preview, and hovering rebuilt nothing, got '%s'" % _delta(main))
	_cell(main, "china_power_plant").pressed.emit()
	runner.check(_delta(main) == plant, "TS6 fixture: the first building armed previews %s, got '%s'" % [plant, _delta(main)])
	tower.mouse_entered.emit()
	runner.check(_delta(main) == "1200", "TS6 hovering the tower while armed forecasts the tower, got '%s'" % _delta(main))
	tower.mouse_exited.emit()
	runner.check(_delta(main) == plant, "TS6 off the tower while armed: back to the armed building, got '%s'" % _delta(main))
	main.orders._clear_placement()
	tower.mouse_entered.emit()
	_select(main, [], ids.factory)
	runner.check(_delta(main) == "" and tower.get_meta("action") == "", "TS6 the hovered cell turned a well by a selection change ends the preview, got '%s'" % _delta(main))
	_sub_grid(main, ids.builder)
	runner.check(_delta(main) == "" and tower.get_meta("action") == "china_defence", "TS6 the sub-grid back under a resting pointer brings no stale preview, got '%s'" % _delta(main))
	# The factory's Supply Depot, so its unit is refused for nothing and forecasts.
	Fixture.add_completed(main.driver.pump.live(), 1, "china_supply_center", Vector2i(6, 26))
	BaseScene.publish(main)
	_select(main, [], ids.factory)
	var power: String = _part(main.hud, "TopStrip", "Power").text
	_cell(main, "china_light_vehicle").mouse_entered.emit()
	runner.check(_delta(main) == str(Registry.kind("china_light_vehicle").cost) and _part(main.hud, "TopStrip", "Power").text == power and not _part(main.hud, "TopStrip", "PowerArrow").is_visible_in_tree(), "TS6 hovering a unit forecasts its cost and leaves the power, got '%s' '%s'" % [_delta(main), _part(main.hud, "TopStrip", "Power").text])
	_select(main, ids.tanks)
	runner.check(_delta(main) == "", "TS6 the item cell turned Attack Move under the pointer ends the preview, got '%s'" % _delta(main))
	for pair: Array in [[ids.tanks, "A", "attack_move"], [ids.tanks, "S", "stop"], [[ids.builder], "Q", "build"]]:
		_select(main, pair[0])
		var command: Button = main.get_node("HUD/Economy/Card/" + pair[1])
		command.mouse_entered.emit()
		runner.check(command.get_meta("action") == pair[2] and _delta(main) == "" and not _forecasting(main.hud), "TS6 hovering the %s command cell previews nothing, got '%s'" % [pair[2], _delta(main)])
		command.mouse_exited.emit()
	main.free()
	var skirmish = SkirmishTests.new()
	main = await skirmish._setup(runner)
	skirmish._arena(main)
	_sub_grid(main, OnlineTests.new()._builder(main, 1))
	_cell(main, "usa_power_plant").mouse_entered.emit()
	runner.check(_forecasting(main.hud), "TS6 fixture: a build cell hovered in the arena previews it")
	skirmish._victory(main)
	runner.check(main.shown_over() and not _forecasting(main.hud), "TS6 the match ending under a hovered build cell ends the preview")
	main.free()
	var online_tests = OnlineTests.new()
	var online: Dictionary = await online_tests._online(runner, 1)
	main = online.main
	online_tests._peer_packets(online.transport, 2, 4, 12)
	online_tests._run(main, 8)
	_sub_grid(main, online_tests._builder(main, 1))
	main.driver._finished = true
	main._refresh()
	var item: Button = _cell(main, "usa_power_plant")
	runner.check(item != null and not main.shown_over() and not main.frozen(), "TS6 fixture: an online ending without a card leaves the card up")
	if item != null: item.mouse_entered.emit()
	runner.check(not _forecasting(main.hud), "TS6 an ending without a card: hovering a build cell previews nothing")
	main.free()
	return true

# Gate C (user, 2026-11-20): the queue rows' hover inset; the armed look keeps its own.
func test_build_button_hover_inset(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_sub_grid(main, ids.builder)
	var plant: Button = _cell(main, "china_power_plant")
	var plain: StyleBoxFlat = main.hud.get_theme_stylebox("hover", &"HudButton") as StyleBoxFlat
	for look: String in ["hover", "pressed", "hover_pressed"]:
		var style: StyleBoxFlat = plant.get_theme_stylebox(look) as StyleBoxFlat
		runner.check(style != null and style.border_color == _token("muted") and style.border_width_left == 1 and style.border_width_bottom == 1 and style.bg_color == plain.bg_color, "SL9 a build cell's %s look is the queue rows' 1 px muted inset" % look)
	runner.check(plant.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "SL9 a ready cell takes the pointing hand")
	plant.pressed.emit()
	var armed: StyleBoxFlat = plant.get_theme_stylebox("hover") as StyleBoxFlat
	runner.check(plant.theme_type_variation == &"HudButtonArmed" and armed.border_color == _token("sel") and armed.border_width_left == 2, "SL9 the armed build cell keeps its cyan look under the pointer")
	runner.check(plant.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "SL9 an armed cell keeps the pointing hand")
	var well: Button = main.get_node("HUD/Economy/Card/S")
	var fill: StyleBoxFlat = well.get_theme_stylebox("normal") as StyleBoxFlat
	runner.check(fill.bg_color == Color("#0f1820") and fill.border_color == _token("line") and fill.border_width_left == 1 and fill.border_width_bottom == 1 and well.get_theme_stylebox("hover") == fill, "SL9 a well: the page's #0f1820 with a 1 px line outline (3-14), no hover look")
	runner.check(well.mouse_default_cursor_shape == Control.CURSOR_ARROW, "SL9 a well keeps the arrow")
	main.orders._clear_placement()
	main._refresh()
	runner.check((plant.get_theme_stylebox("hover") as StyleBoxFlat).border_color == _token("muted"), "SL9 disarmed, the inset comes back")
	main.free()
	return true

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
		var widths: Dictionary = {}
		for faction: Array in [["usa", 8, 10, "usa_factory"], ["frc", 0, 0, "frc_factory"]]:
			var rest: Array = await _strip_rects(runner, main, _strip_view(500, faction[1], faction[2], faction[0]), "")
			var strip: Rect2 = rest[0]
			widths[faction[0]] = strip.size.x
			runner.check(strip.position == Vector2(8, 8) and strip.size.y == 32.0 and view_rect.encloses(strip) and rest[1].position == Vector2(8, 8), "TS4 %s: the strip and its credits slab sit at (8, 8), 32 high, inside the view at %s, got %s" % [faction[0], size, rest])
			if faction[0] == "usa": runner.check(rest[2].position == Vector2(rest[1].end.x + 8.0, 8.0) and rest[2].size.y == 32.0 and strip.end == rest[2].end, "TS4 usa: the power slab 8 px right of credits, 32 high, ending the strip at %s, got %s" % [size, rest])
			else: runner.check(rest[2] == Rect2() and strip == rest[1], "TS4 frc: the credits slab alone at %s, got %s" % [size, rest])
			var rich: Array = await _strip_rects(runner, main, _strip_view(50000, faction[1], faction[2], faction[0]), "")
			runner.check(rich[1].size.x > rest[1].size.x and rich[1].position == rest[1].position, "TS4 %s at rest the credits slab hugs its number: 50000 wider than 500 at %s, got %s %s" % [faction[0], size, rich[1], rest[1]])
			if faction[0] == "usa":
				var low: Array = await _strip_rects(runner, main, _strip_view(500, faction[1] + 4, faction[2], faction[0]), "")
				runner.check(low[2].size.x > rest[2].size.x and low[1] == rest[1], "TS4 usa at rest the power slab hugs its words: low power wider, credits unmoved at %s, got %s %s" % [size, low[2], rest[2]])
			var held: Array = []
			for state: Array in [["a short preview", _strip_view(500, faction[1], faction[2], faction[0]), faction[3]], ["low power while armed", _strip_view(4800, faction[1] + 4, faction[2], faction[0]), faction[0] + "_barracks"], ["a five-digit preview with low power", _strip_view(99999, faction[1] + 4, faction[2], faction[0]), faction[3]], ["armed at 500", _strip_view(500, faction[1], faction[2], faction[0]), faction[0] + "_barracks"]]:
				var now: Array = await _strip_rects(runner, main, state[1], state[2])
				if held.is_empty():
					held = now
					runner.check(now[1].size.x > rest[1].size.x and view_rect.encloses(now[0]) and now[0].position == Vector2(8, 8), "TS4 %s armed: the slabs grow to their widest forecast, inside the view at %s, got %s rest %s" % [faction[0], size, now, rest])
				runner.check(now == held, "TS4 %s, %s keeps the held slabs %s at %s, got %s" % [faction[0], state[0], held, size, now])
		runner.check(widths.frc < widths.usa, "TS4 FRC, with no power group, gets a narrower strip at %s, got %s" % [size, widths])
		var text: String = BaseScene.hud_text(main)
		runner.check(not text.contains("Tick") and not text.contains("You are"), "TS4 no tick and no seat line in the HUD at %s" % size)
		port.free()
	return true

func _strip_rects(runner, main, view: Dictionary, kind: String) -> Array:
	main.hud.update_hud(view, _armed(kind), 1, 1)
	await runner.process_frame
	return _strip_now(main)

# [the strip, the credits slab, the power slab or an empty rect while it hides].
static func _strip_now(main) -> Array:
	var power: Control = main.get_node("HUD/Hud/TopStrip/PowerGroup")
	return [main.get_node("HUD/Hud/TopStrip").get_global_rect(), main.get_node("HUD/Hud/TopStrip/CreditsGroup").get_global_rect(), power.get_global_rect() if power.is_visible_in_tree() else Rect2()]

# Shape D (user, 2026-11-22): from entering the card until leaving it, or while a building is armed, no slab changes its rect.
func test_strip_holds_while_on_the_card(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _slab_world(runner, main, false, 1500)
	# The factory then lacks only credits, the one refusal that forecasts.
	_prerequisites(main)
	_sub_grid(main, ids.builder)
	var map := Vector2(900, 200)
	_move(port, map)
	await _frames(runner)
	var rest: Array = _strip_now(main)
	var held: Array = []
	for row: Array in [["china_power_plant", "500", false], ["china_defence", "300", false], ["china_factory", MINUS + "500", true], ["china_barracks", "1000", false]]:
		var cell: Button = _cell(main, row[0])
		_move(port, cell.get_global_rect().get_center())
		await _frames(runner)
		runner.check(cell.is_hovered() and _form(main.hud).slice(0, 3) == ["1500", row[1], row[2]], "TS7 the pointer on %s forecasts 1500 → %s (coin %s), got %s" % [row[0], row[1], row[2], _form(main.hud)])
		if held.is_empty(): held = _strip_now(main)
		runner.check(_strip_now(main) == held, "TS7 on %s the slabs keep their held rects %s, got %s" % [row[0], held, _strip_now(main)])
	runner.check(held[1].size.x > rest[1].size.x and held[2].size.x > rest[2].size.x and held[1].position == rest[1].position, "TS7 entering the card grows both slabs to their widest forecast, rest %s held %s" % [rest, held])
	var plant: Rect2 = _cell(main, "china_power_plant").get_global_rect()
	var well: Button = main.get_node("HUD/Economy/Card/S")
	for spot: Array in [["the gap between two cells", Vector2(plant.end.x + 2.0, plant.get_center().y)], ["a well", well.get_global_rect().get_center()]]:
		_move(port, spot[1])
		await _frames(runner)
		runner.check(_strip_now(main) == held and not _forecasting(main.hud), "TS7 the pointer on %s: nothing forecasts, the slabs hold, got %s" % [spot[0], _strip_now(main)])
	_move(port, map)
	await _frames(runner)
	runner.check(_strip_now(main) == rest, "TS7 the pointer left the card from a well: both slabs hug again, got %s rest %s" % [_strip_now(main), rest])
	_move(port, plant.get_center())
	_press(port, plant.get_center(), true)
	_press(port, plant.get_center(), false)
	await _frames(runner)
	_move(port, map)
	await _frames(runner)
	runner.check(main.orders._placement_kind == "china_power_plant" and _strip_now(main) == held, "TS7 a building armed by a click holds the slabs off the card, got '%s' %s" % [main.orders._placement_kind, _strip_now(main)])
	BaseScene.new().key(main, KEY_ESCAPE)
	await _frames(runner)
	runner.check(main.orders._placement_kind.is_empty() and _strip_now(main) == rest, "TS7 Esc cancels the building: the slabs hug again, got %s rest %s" % [_strip_now(main), rest])
	port.notify_mouse_entered()
	_move(port, plant.get_center())
	await _frames(runner)
	runner.check(_strip_now(main) == held, "TS7 fixture: back on the card the slabs hold, got %s" % [_strip_now(main)])
	# As a real window leave: the card gets `mouse_exited`, the mouse position stays on it.
	port.notify_mouse_exited()
	await _frames(runner)
	runner.check(_strip_now(main) == rest, "TS7 the pointer leaving the window from the card lets the slabs hug again, got %s rest %s" % [_strip_now(main), rest])
	_end_port(scene)
	return true

# Only a credits shortfall forecasts a refused purchase (TS round B); a missing prerequisite or a full queue previews nothing.
func test_strip_skips_refused_purchases(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _slab_world(runner, main, false, 1500)
	_sub_grid(main, ids.builder)
	_move(port, Vector2(900, 200))
	await _frames(runner)
	var rest: Array = _form(main.hud)
	var factory: Button = _cell(main, "china_factory")
	_move(port, factory.get_global_rect().get_center())
	await _frames(runner)
	runner.check(factory.is_hovered() and (factory.get_meta("blocked") as Dictionary).get("cause") == "prerequisite", "TS7 fixture: the Vehicle Factory lacks its Supply Depot, got %s" % [factory.get_meta("blocked")])
	runner.check(_form(main.hud) == rest and not _forecasting(main.hud), "TS7 a prerequisite-blocked cell forecasts nothing, got %s rest %s" % [_form(main.hud), rest])
	Fixture.add_completed(main.driver.pump.live(), 1, "china_supply_center", Vector2i(6, 26))
	BaseScene.publish(main)
	_select(main, [], ids.factory)
	_queue_of(main, ids.factory, 9)
	_move(port, Vector2(900, 200))
	await _frames(runner)
	rest = _form(main.hud)
	var tank: Button = _cell(main, "china_tank")
	_move(port, tank.get_global_rect().get_center())
	await _frames(runner)
	runner.check(tank.is_hovered() and (tank.get_meta("blocked") as Dictionary).get("cause") == "queue", "TS7 fixture: the factory's queue is full, got %s" % [tank.get_meta("blocked")])
	runner.check(_form(main.hud) == rest and not _forecasting(main.hud), "TS7 a queue-full cell forecasts nothing, got %s rest %s" % [_form(main.hud), rest])
	_end_port(scene)
	return true

func test_strip_patches_values(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	await _show(runner, hud, _strip_view(500, 8, 10), "china_defence")
	var credits: Label = _part(hud, "TopStrip", "Credits")
	var after: Label = _part(hud, "TopStrip", "CreditsAfter")
	for row: Array in [[500, MINUS + "700", "warn", true], [1000, MINUS + "200", "warn", true], [1500, "300", "text", false]]:
		await _show(runner, hud, _strip_view(row[0], 8, 10), "china_defence")
		runner.check(credits.text == str(row[0]) and after.text == row[1] and _colour(after) == _token(row[2]) and _form(hud)[2] == row[3], "TS5 %d credits patch the forecasting strip to %s in %s, coin %s, got %s" % [row[0], row[1], row[2], row[3], _form(hud)])
	runner.check(_part(hud, "TopStrip", "Credits") == credits and _part(hud, "TopStrip", "CreditsAfter") == after, "TS5 patching values keeps the same labels")
	var changes: Array[int] = [0]
	for part: String in ["Credits", "CreditsAfter", "Power", "PowerAfter", "LowPower"]: _part(hud, "TopStrip", part).theme_changed.connect(func() -> void: changes[0] += 1)
	for slab: Control in _slabs(hud) + [hud.get_node("TopStrip")]: slab.theme_changed.connect(func() -> void: changes[0] += 1)
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
	var promised: bool = esc.modulate.a == 1.0
	runner.check(esc.visible and promised == shown and (promised or esc.modulate.a == 0.0), "CH2 %s: the Esc chip %s" % [label, "shows" if shown else "fades out"])
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
	await _esc_matches_chip(runner, main, "the start builder selected", false)
	await _esc_matches_chip(runner, main, "nothing pending", true)
	main.orders.selected_ids.assign([own])
	main._refresh()
	await _esc_matches_chip(runner, main, "a selection", false)
	await _esc_matches_chip(runner, main, "after Esc backed out of the selection", true)
	main.orders.selected_ids.assign([own])
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

func _esc_main(runner, overlays):
	var main = await overlays._scene(runner, Skirmish)
	overlays._camera(main)
	return main

# What one Esc may change: the layer it backs out of, and nothing under it.
func _esc_state(runner, main, label: String, placement: String, sub_grid: bool, selected: Array, menu: bool) -> void:
	var orders = main.orders
	runner.check(orders._placement_kind == placement and orders._sub_grid == sub_grid and orders.selected_ids == selected and main._pause.visible == menu and not orders._attack_move_mode, "ES %s: placement '%s', sub-grid %s, selected %s, menu %s; got '%s', %s, %s, %s, attack move %s" % [label, placement, sub_grid, selected, menu, orders._placement_kind, orders._sub_grid, orders.selected_ids, main._pause.visible, orders._attack_move_mode])

func test_esc_placement_layer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var start: Array = main.orders.selected_ids.duplicate()
	BaseScene.new().build_key(main, "usa_power_plant")
	_esc_state(runner, main, "placement armed", "usa_power_plant", true, start, false)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "Esc over an armed placement leaves the sub-grid open and the builder selected", "", true, start, false)
	main.free()
	overlays._end(saved)
	return true

func test_esc_attack_move_layer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var rows: RefCounted = main.shown_state.units
	var at: int = rows.index_of(main.orders.selected_ids[0])
	main.orders.selected_ids.append(main.driver.pump.live().spawn(1, Vector2(rows.x[at] + 1.0, rows.y[at]), "usa_tank"))
	BaseScene.publish(main)
	var start: Array = main.orders.selected_ids.duplicate()
	main.orders.arm_attack_move()
	runner.check(main.orders._attack_move_mode, "ES attack move fixture: armed")
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "Esc over an armed attack move keeps the selection and opens no menu", "", false, start, false)
	main.free()
	overlays._end(saved)
	return true

func test_esc_sub_grid_layer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var start: Array = main.orders.selected_ids.duplicate()
	BaseScene.new().key(main, HudModel.BUILD_KEY)
	_esc_state(runner, main, "sub-grid open", "", true, start, false)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "Esc over the sub-grid closes it and keeps the builder selected", "", false, start, false)
	runner.check(main.get_node("HUD/Economy/Card").is_visible_in_tree() and _cell(main, "build") != null, "ES sub-grid closed: the root card's Build cell is back")
	main.free()
	overlays._end(saved)
	return true

func test_esc_selection_layer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	runner.check(main.orders.selected_ids.size() == 1, "ES start fixture: the start builder is selected")
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "first Esc of a match deselects the start builder", "", false, [], false)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "second Esc opens the menu", "", false, [], true)
	main.free()
	overlays._end(saved)
	return true

func test_esc_inspection_layer(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var enemy: int = main.driver.pump.live().snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 2)[0].id
	main.orders.selected_ids.clear()
	main.orders.inspected_id = enemy
	main._refresh()
	overlays._key(runner, KEY_ESCAPE)
	runner.check(main.orders.inspected_id == -1 and not main._pause.visible, "ES Esc over an inspected enemy drops the inspection and opens no menu")
	overlays._key(runner, KEY_ESCAPE)
	runner.check(main._pause.visible, "ES the next Esc opens the menu")
	main.free()
	overlays._end(saved)
	return true

func test_esc_layers_in_order(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var start: Array = main.orders.selected_ids.duplicate()
	BaseScene.new().build_key(main, "usa_power_plant")
	var steps: Array = [
		["placement", "", true, start, false],
		["sub-grid", "", false, start, false],
		["selection", "", false, [], false],
		["menu", "", false, [], true]]
	var chip: Control = main.get_node("HUD/MenuChip").find_child("EscChip", true, false)
	for step: Array in steps:
		main._show_esc_chip()
		var promised: bool = chip.modulate.a == 1.0
		overlays._key(runner, KEY_ESCAPE)
		_esc_state(runner, main, "one Esc over the %s layer" % step[0], step[1], step[2], step[3], step[4])
		runner.check(promised == step[4], "ES the Esc chip before the %s layer says %s" % [step[0], "menu" if promised else "back out"])
	main.free()
	overlays._end(saved)
	return true

func test_esc_in_the_frame_of_a_card_key(runner) -> bool:
	var overlays = OverlayTests.new()
	var helper = BaseScene.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var start: Array = main.orders.selected_ids.duplicate()
	helper.key(main, HudModel.BUILD_KEY)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "Q then Esc before any view: both land, in order", "", false, start, false)
	overlays._key(runner, KEY_ESCAPE)
	helper.key(main, HudModel.BUILD_KEY)
	_esc_state(runner, main, "Esc then Q before any view: the deselect stands, Q opens nothing", "", false, [], false)
	runner.check(main.hud.refusal == "Select a Bulldozer", "ES Esc then Q refuses with the builder's name, got '%s'" % main.hud.refusal)
	overlays._key(runner, KEY_ESCAPE)
	runner.check(main._pause.visible, "ES the Esc after that refused Q opens the menu")
	main.free()
	overlays._end(saved)
	return true

func test_esc_and_back_in_one_frame(runner) -> bool:
	var overlays = OverlayTests.new()
	var helper = BaseScene.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var start: Array = main.orders.selected_ids.duplicate()
	helper.key(main, HudModel.BUILD_KEY)
	overlays._key(runner, KEY_ESCAPE)
	helper.key(main, KEY_V)
	_esc_state(runner, main, "Esc then V: one layer, V finds no Back to press", "", false, start, false)
	helper.key(main, HudModel.BUILD_KEY)
	helper.key(main, KEY_V)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "V then Esc: two layers, no menu", "", false, [], false)
	main.free()
	overlays._end(saved)
	return true

func test_esc_during_a_drag_with_the_sub_grid_open(runner) -> bool:
	var overlays = OverlayTests.new()
	var helper = BaseScene.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var from: Vector2 = main.get_node("WorldView").get_global_transform_with_canvas().affine_inverse() * Vector2(300, 300)
	helper.key(main, HudModel.BUILD_KEY)
	helper.pointer(main, from, MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = main.get_node("WorldView").get_global_transform_with_canvas() * from + Vector2(60, 40)
	main._unhandled_input(motion)
	var box: Control = main.get_node("HUD/SelectionBox")
	runner.check(main.orders._sub_grid and main.orders.is_selecting() and box.visible, "ES drag fixture: sub-grid open, drag box shown")
	overlays._key(runner, KEY_ESCAPE)
	runner.check(not main.orders.is_selecting() and not box.visible and not main._pause.visible, "ES Esc during a drag cancels the drag and opens no menu")
	_esc_state(runner, main, "Esc during a drag cancels it as before the sub-grid layer: the selection goes and the sub-grid closes with it", "", false, [], false)
	helper.pointer(main, from, MOUSE_BUTTON_LEFT, false)
	runner.check(main.orders.selected_ids.is_empty() and not box.visible, "ES the release after the cancelled drag selects nothing")
	main.free()
	overlays._end(saved)
	return true

func test_esc_as_the_builder_dies(runner) -> bool:
	var overlays = OverlayTests.new()
	var helper = BaseScene.new()
	var saved: String = overlays._begin()
	var main = await _esc_main(runner, overlays)
	var builder: int = main.orders.selected_ids[0]
	helper.key(main, HudModel.BUILD_KEY)
	main.driver.pump.live().remove_object(builder)
	overlays._key(runner, KEY_ESCAPE)
	_esc_state(runner, main, "Esc in the step the builder died closes the sub-grid and keeps the selection until the next view", "", false, [builder], false)
	BaseScene.publish(main)
	_esc_state(runner, main, "the next view drops the dead builder", "", false, [], false)
	overlays._key(runner, KEY_ESCAPE)
	runner.check(main._pause.visible, "ES with nothing left the next Esc opens the menu")
	main.free()
	overlays._end(saved)
	return true

# The Esc key chip fades, so Menu neither shifts nor shrinks when a selection takes Esc's first job.
func test_menu_chip_keeps_its_width(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	var main = await overlays._scene(runner, Skirmish)
	var chip: Control = main.get_node("HUD/MenuChip")
	var esc: Label = chip.find_child("EscChip", true, false)
	main.orders.selected_ids.clear()
	main._refresh()
	await _frames(runner)
	var free_rect: Rect2 = chip.get_global_rect()
	var free_x: float = chip.find_child("Label", true, false).get_global_rect().position.x
	runner.check(is_equal_approx(esc.modulate.a, 1.0) and BaseScene.hud_text(main).contains("Esc"), "MW1 fixture: nothing pending, the Esc chip is drawn and read")
	main.orders.selected_ids.assign([overlays._own_unit(main)])
	main._refresh()
	await _frames(runner)
	var held_rect: Rect2 = chip.get_global_rect()
	var held_x: float = chip.find_child("Label", true, false).get_global_rect().position.x
	runner.check(held_rect == free_rect and is_equal_approx(held_x, free_x), "MW1 Menu keeps its rect and label x with a selection, got %s x %.2f, without %s x %.2f" % [held_rect, held_x, free_rect, free_x])
	runner.check(free_rect.size.x == 88.0, "MW1 Menu is 88 wide (the drawn 86.75 on whole pixels), got %.2f" % free_rect.size.x)
	runner.check(esc.modulate.a == 0.0 and esc.mouse_filter == Control.MOUSE_FILTER_IGNORE and not BaseScene.hud_text(main).contains("Esc"), "MW1 with a selection the Esc chip is transparent, takes no clicks and is not read")
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
	var count: int = (main.get_node("HUD/Hud/Notice/Text") as Label).get_line_count()
	# lines 0: wraps to two or more; the count follows the OS save path in the text.
	var lines_ok: bool = count >= 2 if lines == 0 else count == lines
	runner.check(one_line == (lines == 1) and lines_ok, "CH4 %s: %d line(s) (0 = two or more), 28 high for one, got %s with %d" % [label, lines, notice, count])
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
	_select_new_builder(main)
	main.orders._placement_kind = "usa_power_plant"
	online._run(main, 12)
	var label: Label = main.get_node("HUD/Hud/Notice").find_child("Text", true, false)
	runner.check(main.driver.notice() == "Waiting for player 1" and label.is_visible_in_tree() and label.text == "Waiting for player 1" and _colour(label) == _token("muted"), "CH4 the waiting notice shows in muted, got '%s'" % label.text)
	runner.check(_forecasting(main.hud) and main.orders.busy(), "CH4 fixture: a building armed while the notice shows")
	runner.check(BaseScene.hud_text(main).count("Waiting for player 1") == 1, "CH4 the notice shows once")
	var chips: Array = ["HUD/Hud/TopStrip", "HUD/MenuChip", "HUD/Playtest/Chip"]
	for strip: Array in [[12, "low power in the strip"], [8, "the longest preview"]]:
		main.hud.update_hud(_strip_view(500, strip[0], 10), _armed("china_defence", false, main.driver.notice()), 1, 1)
		await _frames(runner)
		_notice_clear(runner, main, strip[1], chips)
	runner.check(_form(main.hud) == ["500", MINUS + "700", true, "8 / 10", "11 / 10", true, true, true], "CH4 fixture: the forecast's longest form, short with the coin and low power, got %s" % [_form(main.hud)])
	main.free()
	await _ended_notice(runner, online, 1, func(lockstep, _transport) -> void: lockstep.receive('{"type":"left","seat":2,"after_tick":3}'), "Opponent left before the start (a different map or version, or their game tab was hidden)")
	await _ended_notice(runner, online, 2, func(_lockstep, transport) -> void: transport.frames.append(OnlineTests.Wire.encode(OnlineTests.Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"}))), "Desync", 0)
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
	runner.check(not _forecasting(main.hud) and not main.orders.busy(), "CH4 %s: the ending cleared the armed building" % words)
	runner.check(BaseScene.hud_text(main).count(words) == 1, "CH4 %s: the notice shows once" % words)
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

# Every prerequisite `_slab_world` lacks, so no build or factory cell there is blocked by one.
static func _prerequisites(main) -> void:
	var sim = main.driver.pump.live()
	for row: Array in [["usa_power_plant", Vector2i(17, 26)], ["usa_supply_center", Vector2i(2, 22)], ["china_supply_center", Vector2i(6, 26)], ["frc_supply_center", Vector2i(10, 26)], ["frc_barracks", Vector2i(14, 26)]]:
		Fixture.add_completed(sim, 1, row[0], row[1])
	BaseScene.publish(main)

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
	for cell: Node in _cells(main):
		if (cell as Control).is_visible_in_tree() and (cell.get_node("Cost") as Control).visible:
			runner.check(cell.get_node("Cost").get_global_rect().end.x <= cell.get_node("Chip").get_global_rect().position.x, "SL2 %s: cell %s's cost ends before its chip" % [label, cell.name])

func test_slab_rect(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		# Nothing selected shows no card (3-6), so the start builder's card fills the slab.
		BaseScene.select_own_unit(main)
		main.hud._show_notice("Waiting for player 1")
		await _frames(runner)
		var slab: Rect2 = _rect(main, "HUD/Economy")
		var at: String = " at %s" % size
		runner.check(absf(slab.position.x - (size.x - 432.0)) <= 1.0 and is_equal_approx(slab.size.x, 432.0) and is_equal_approx(slab.end.y, size.y) and view.encloses(slab), "SL1 the slab is x W-432, 432 wide, bottom on H, inside the view%s, got %s" % [at, slab])
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has("HUD/Hud/TopStrip") and panels.has("HUD/MenuChip") and panels.has("HUD/Hud/Notice"), "SL1 fixture: strip, Menu and a notice shown%s" % at)
		for path: String in panels:
			if path != "HUD/Economy": runner.check(not slab.intersects(panels[path]), "SL1 the slab clears %s%s" % [path, at])
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
	BaseScene.select_own_unit(main)
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
	for i in 9: entries.append({"id": 900 + i, "kind": ["china_tank", "china_light_vehicle"][i % 2], "paid_cost": 800, "work": 126000 if i == 0 else 0})
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
		var states: Array = [["a lone China builder", [ids.builder], -1, "Card"], ["own tanks", ids.tanks, -1, "Card"], ["nine queued", [], ids.factory, "Card"]]
		for state: Array in states:
			var label: String = "%s at %s" % [state[0], size]
			_select(main, state[1], state[2])
			if state[2] != -1: _nine(main, ids.factory)
			await _frames(runner)
			runner.check(_shown(main, state[3]), "SL2 %s: %s shown" % [label, state[3]])
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
			var tiles: Array = _tiles(main)
			if not tiles.is_empty(): _click_in(port, (tiles.back() as Control).get_global_rect().get_center())
			main.hud.entry_cancelled.disconnect(record)
			runner.check(not tiles.is_empty() and cancelled == [Array(tiles.back().get_meta("ids")).back()], "SL2 %s: the last queue tile takes a click, got %s" % [label, cancelled])
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
	_prerequisites(main)
	for builder: int in [ids.usa_builder, ids.builder, ids.frc_builder]:
		_sub_grid(main, builder)
		var kind: String = main.shown_state.units.kinds[main.shown_state.units.kind[main.shown_state.units.index_of(builder)]]
		var buttons: Array = Registry.kind(kind).builds.map(func(build: String) -> Button: return _cell(main, build))
		runner.check(not buttons.is_empty() and not buttons.has(null), "SL3 fixture: builder %d shows its sub-grid" % builder)
		if buttons.has(null): continue
		for i in buttons.size():
			(buttons[i] as Button).pressed.emit()
			var looks: Array = buttons.map(func(button: Button) -> StringName: return button.theme_type_variation)
			var expected: Array = range(buttons.size()).map(func(j: int) -> StringName: return &"HudButtonArmed" if j == i else &"HudButton")
			runner.check(main.orders._placement_kind == buttons[i].get_meta("action") and looks == expected, "SL3 builder %d arming %s: only its cell armed, got %s" % [builder, buttons[i].get_meta("action"), looks])
			main.orders._clear_placement()
		runner.check(buttons.all(func(button: Button) -> bool: return button.theme_type_variation == &"HudButton"), "SL3 builder %d: cleared, every cell plain" % builder)
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 20.5))
	_select(main, ids.tanks)
	var arms: Array = [["the A key", func() -> void: helper.key(main, KEY_A)], ["the cell", func() -> void: _cell(main, "attack_move").pressed.emit()]]
	var disarms: Array = [["Esc", func() -> void: helper.key(main, KEY_ESCAPE)], ["a right-click", func() -> void: helper.pointer(main, ground, MOUSE_BUTTON_RIGHT, true)]]
	for arm: Array in arms:
		for disarm: Array in disarms:
			(arm[1] as Callable).call()
			var armed: StringName = _look(main, "Card/A")
			(disarm[1] as Callable).call()
			runner.check(armed == &"HudButtonArmed" and _look(main, "Card/A") == &"HudButton" and not main.orders._attack_move_mode, "SL3 armed by %s then %s: %s, then plain" % [arm[0], disarm[0], armed])
			main.orders.selected_ids.assign(ids.tanks)
	for stop: Array in [["the S key", func() -> void: helper.key(main, KEY_S)], ["the Stop cell", func() -> void: _cell(main, "stop").pressed.emit()]]:
		var before: int = _queued(main, "stop").size()
		helper.key(main, KEY_A)
		var armed: StringName = _look(main, "Card/A")
		(stop[1] as Callable).call()
		runner.check(armed == &"HudButtonArmed" and _queued(main, "stop").size() == before + 1 and not main.orders._attack_move_mode and _look(main, "Card/A") == &"HudButton", "SL3 armed, then %s: one stop, mode off, plain" % stop[0])
	_select(main, [ids.car])
	for unload: Array in [["the F key", func() -> void: helper.key(main, KEY_F)], ["the Unload cell", func() -> void: _cell(main, "unload").pressed.emit()]]:
		var before: int = _queued(main, "unload").size()
		helper.key(main, KEY_A)
		var armed: StringName = _look(main, "Card/A")
		(unload[1] as Callable).call()
		runner.check(armed == &"HudButtonArmed" and _queued(main, "unload").size() == before + 1 and not main.orders._attack_move_mode and _look(main, "Card/A") == &"HudButton", "SL3 a loaded car armed, then %s: one unload, mode off, plain" % unload[0])
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
	var attack: Button = main.get_node("HUD/Economy/Card/A")
	var stop: Button = main.get_node("HUD/Economy/Card/S")
	var unload: Button = main.get_node("HUD/Economy/Card/F")
	runner.check(attack.is_visible_in_tree() and attack.get_meta("action") == "attack_move" and stop.is_visible_in_tree() and stop.get_meta("action") == "stop", "SL4 tanks: Attack Move on A and Stop on S")
	runner.check(_cells(main).all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE), "SL4 the cells take no focus")
	_click(runner, stop.get_global_rect().get_center())
	var stops: Array = _queued(main, "stop")
	runner.check(stops.size() == 1 and stops[0].entity_ids == ids.tanks, "SL4 a click on Stop submits one stop with the selection, got %s" % [stops])
	for code: Key in [KEY_SPACE, KEY_ENTER]: SkirmishTests.new()._push_key(main, code)
	runner.check(_queued(main, "stop").size() == 1, "SL4 Space and Enter after the click submit no second stop")
	runner.check(attack.theme_type_variation == &"HudButton" and not main._hud_selection().attack_move, "SL4 before the press: plain, not armed")
	_click(runner, attack.get_global_rect().get_center())
	runner.check(attack.theme_type_variation == &"HudButtonArmed" and main.orders._attack_move_mode and main._hud_selection().attack_move, "SL4 a click on Attack move arms it")
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)
	var moves: Array = _queued(main, "attack_move")
	runner.check(moves.size() == 1 and moves[0].entity_ids == ids.tanks, "SL4 the next ground click submits one attack_move, got %s" % [moves])
	for host: Array in [["a loaded Tunnel Hub", [], ids.hub], ["a loaded Scout Car", [ids.car], -1]]:
		_select(main, host[1], host[2])
		await _frames(runner)
		var before: int = _queued(main, "unload").size()
		runner.check(unload.is_visible_in_tree() and unload.get_meta("action") == "unload", "SL4 %s: Unload on F" % host[0])
		_click(runner, unload.get_global_rect().get_center())
		var unloads: Array = _queued(main, "unload")
		var target: int = host[2] if host[2] != -1 else ids.car
		runner.check(unloads.size() == before + 1 and unloads.back().target_id == target, "SL4 %s: a click on Unload submits one unload, got %s" % [host[0], unloads])
	var none: Array = [["an inspected enemy", [], -1, ids.enemy], ["a pile", [], -1, ids.pile], ["an own Power Plant", [], ids.plant, -1], ["nothing", [], -1, -1], ["a lone builder", [ids.builder], -1, -1]]
	for case: Array in none:
		_select(main, case[1], case[2], case[3])
		runner.check(_cell(main, "attack_move") == null and _cell(main, "stop") == null, "SL4 %s: no Attack Move and no Stop" % case[0])
	for case: Array in [["collectors alone", ids.collectors], ["a builder with a collector", [ids.builder, ids.collectors[0]]]]:
		_select(main, case[1])
		runner.check(_cell(main, "attack_move") == null and _cell(main, "stop") != null, "SL4 %s, no weapon: Stop without Attack Move (as Zero Hour's Supply Truck)" % case[0])
	_select(main, [ids.builder, ids.infantry])
	runner.check(_cell(main, "attack_move") != null and _cell(main, "stop") != null and _cell(main, "build") == null, "SL4 a builder with an armed unit: the order cells, no Build")
	var both: Array = []
	for case: Array in [[ids.tanks, -1], [[ids.car], -1], [[], ids.hub], [[], ids.factory], [[], ids.barracks], [[], ids.plant], [[], -1], [[ids.usa_builder], -1], [[ids.builder], -1], [[ids.frc_builder], -1], [[ids.builder, ids.infantry], -1], [ids.collectors, -1], [[ids.builder, ids.collectors[0]], -1]]:
		_select(main, case[0], case[1])
		if _cell(main, "stop") != null and _cell(main, "build") != null: both.append(case)
	runner.check(both.is_empty(), "SL4 the order cells and Build never show together, got %s" % [both])
	var text: String = BaseScene.hud_text(main)
	runner.check(HINTS.all(func(hint: String) -> bool: return not text.contains(hint)) and main.find_child("Hints", true, false) == null, "SL4 no key-hint text and no Hints node, got " + text)
	_sub_grid(main, ids.builder)
	_cell(main, "china_power_plant").pressed.emit()
	main.orders.arm_attack_move()
	runner.check(main.orders.busy() and _cell(main, "attack_move") == null and _cell(main, "stop") == null and not main.orders._attack_move_mode, "SL4 a placement armed: no order cells, and a direct arm does nothing")
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
	runner.check(_cell(main, "unload") == null and not _shown(main, "Card"), "SL4 an empty Tunnel Hub: no Unload, no card")
	_select(main, [ids.car])
	runner.check(_cell(main, "unload") == null and _cell(main, "attack_move") != null, "SL4 an empty Scout Car with no own unit inside anything: no Unload")
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
	var mixed: Array = ids.tanks + [ids.infantry]
	_select(main, mixed)
	for shift: bool in [false, true]: main.hud.row_clicked.emit("china_tank", shift)
	runner.check(main.orders.selected_ids == mixed, "SL4 the note form holds the match: a kind-row click and Shift-click keep the selection, got %s" % [main.orders.selected_ids])
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
		["the Stop cell", ids.tanks, func() -> void: _cell(main, "stop").pressed.emit()],
		["the Unload cell", [ids.car], func() -> void: _cell(main, "unload").pressed.emit()],
		["a placement armed", ids.tanks, func() -> void:
			_sub_grid(main, ids.builder)
			_cell(main, "china_power_plant").pressed.emit()],
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

static func _queue_of(main, factory: int, count: int, first_work: int = 126000) -> void:
	var entries: Array = []
	for i in count: entries.append({"id": 900 + i, "kind": "china_tank", "paid_cost": 800, "work": first_work if i == 0 else 0})
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, factory).queue = entries
	main._show(view)

static func _visible_texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text)

const MEDIUM: String = "china_light_vehicle"
const ROTARY: String = "china_tank"
const QUEUE_PATH: String = "HUD/Hud/SelectionPanel/Box/Body/Queue"

# Every China producer with its prerequisites, so the simulation takes their orders; the factory selected.
func _queue_world(main, credits: int = 50000) -> Dictionary:
	var sim = Fixture.make_world(credits)
	sim.add_player(2, 1000)
	var ids := {}
	ids.plant = Fixture.add_completed(sim, 1, "china_power_plant", Vector2i(24, 20))
	ids.depot = Fixture.add_completed(sim, 1, "china_supply_center", Vector2i(20, 4))
	ids.factory = Fixture.add_completed(sim, 1, "china_factory", Vector2i(14, 14))
	ids.barracks = Fixture.add_completed(sim, 1, "china_barracks", Vector2i(8, 20))
	# A finished unit needs its producer's rally point, which `add_completed` leaves out.
	for producer: int in [ids.factory, ids.barracks]: Fixture.send(sim, {"type": "set_rally", "building_id": producer, "target": [12.5, 12.5]})
	sim.step()
	main.driver.adopt(sim)
	_select(main, [], ids.factory)
	return ids

# Entries 900, 901, ... of `kinds` on the shown view only; the first has worked 42 %.
static func _queue_kinds(main, building: int, kinds: Array, first_work: int = 126000) -> void:
	var entries: Array = []
	for i in kinds.size(): entries.append({"id": 900 + i, "kind": kinds[i], "paid_cost": 800, "work": first_work if i == 0 else 0})
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, building).queue = entries
	main._show(view)

static func _tile_row(main) -> Control:
	return main.get_node_or_null(QUEUE_PATH)

# The shown tiles that hold entries, left to right; the `+N more` tile is apart.
static func _tiles(main) -> Array:
	var row: Control = _tile_row(main)
	if row == null: return []
	return row.get_children().filter(func(tile: Node) -> bool: return str(tile.name).begins_with("Tile") and (tile as Control).is_visible_in_tree())

static func _tile_ids(main) -> Array:
	return _tiles(main).map(func(tile: Node) -> Array: return Array(tile.get_meta("ids", [])))

static func _more(main) -> Control:
	var row: Control = _tile_row(main)
	return row.get_node_or_null("More") if row != null else null

static func _shown_text(owner: Node, part: String) -> String:
	var label: Label = owner.get_node_or_null(part) as Label if owner != null else null
	return label.text if label != null and label.is_visible_in_tree() else ""

static func _sim_queue(main, building: int) -> Array:
	return Fixture.object(main.driver.pump.live(), building).queue.map(func(entry: Dictionary) -> int: return entry.id)

static func _own_credits(main) -> int:
	return HudModel.player(main.driver.pump.live().view_state(), 1).credits

static func _right_click_in(port: Viewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		port.push_input(event, true)

static func _has_digit(text: String) -> bool:
	for character: String in text:
		if character.is_valid_int(): return true
	return false

# Produces `kinds` at the selected factory through its cells and lets one tick take them.
static func _produce(main, kinds: Array) -> void:
	for kind: String in kinds: main.orders.press_cell(kind)
	BaseScene.tick(main)

static func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

# P2.3b T8 (3-3, 3-11): the entry in production has a tile of its own; adjacent waiting entries of one kind share one with ×N.
func test_queue_tiles_merge_adjacent_waiting(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	var queues: Array = [
		["a run of each kind after the one in production", [MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY], [[900], [901, 902], [903, 904]], ["", "×2", "×2"]],
		["a Rotary Gun Tank between two Medium Tanks", [MEDIUM, ROTARY, MEDIUM], [[900], [901], [902]], ["", "", ""]],
		["the entry in production never shares its tile", [MEDIUM, MEDIUM], [[900], [901]], ["", ""]]]
	for case: Array in queues:
		_queue_kinds(main, ids.factory, case[1])
		await _frames(runner)
		var tiles: Array = _tiles(main)
		runner.check(_tile_ids(main) == case[2], "QT1 %s: tiles %s, got %s" % [case[0], case[2], _tile_ids(main)])
		runner.check(tiles.map(func(tile: Node) -> String: return _shown_text(tile, "Count")) == case[3], "QT1 %s: counts %s, got %s" % [case[0], case[3], tiles.map(func(tile: Node) -> String: return _shown_text(tile, "Count"))])
		for i in tiles.size():
			var tile: Control = tiles[i]
			var kind: String = case[1][case[2][i][0] - 900]
			var chip: String = HudModel.key_label(HudModel.CELL_KEYS[HudModel.role(kind)])
			runner.check(_shown_text(tile, "Name") == Registry.kind(kind).display_name and _shown_text(tile, "Chip") == chip, "QT1 %s: tile %d names %s with its cell's %s chip, got '%s' '%s'" % [case[0], i + 1, Registry.kind(kind).display_name, chip, _shown_text(tile, "Name"), _shown_text(tile, "Chip")])
			var track: Control = tile.get_node_or_null("Track")
			runner.check((_shown_text(tile, "Now") == "NOW") == (i == 0) and track != null and track.is_visible_in_tree() == (i == 0), "QT1 %s: NOW and the bar on the tile in production only, tile %d" % [case[0], i + 1])
		var row: Control = _tile_row(main)
		var digits: Array = _visible_texts(row).filter(func(text: String) -> bool: return _has_digit(text) and not text.begins_with("×")) if row != null else ["no queue row"]
		runner.check(digits.is_empty(), "QT1 %s: no digits but the ×N counts, got %s" % [case[0], digits])
	_end_port(scene)
	return true

# A click cancels the newest stored entry of the tile's run, so the older entries keep their places.
func test_queue_tile_click_cancels_newest_of_run(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_produce(main, [MEDIUM, MEDIUM, MEDIUM, ROTARY])
	await _frames(runner)
	var queue: Array = _sim_queue(main, ids.factory)
	runner.check(queue.size() == 4 and _tile_ids(main) == [[queue[0]], [queue[1], queue[2]], [queue[3]]], "QT2 fixture: four entries in three tiles, got %s %s" % [queue, _tile_ids(main)])
	if _tiles(main).size() != 3:
		_end_port(scene)
		return true
	var credits: int = _own_credits(main)
	_move(port, _centre(_tiles(main)[1]))
	await _frames(runner)
	_click_in(port, _centre(_tiles(main)[1]))
	var sent: Array = _queued(main, "cancel_production")
	runner.check(sent.size() == 1 and sent[0].production_id == queue[2] and sent[0].building_id == ids.factory, "QT2 a click on the ×2 tile cancels its newest entry %d, got %s" % [queue[2], sent])
	BaseScene.tick(main)
	await _frames(runner)
	runner.check(_sim_queue(main, ids.factory) == [queue[0], queue[1], queue[3]] and _own_credits(main) == credits + 800, "QT2 the older entries keep their order and one 800 comes back, got %s %d" % [_sim_queue(main, ids.factory), _own_credits(main) - credits])
	runner.check(_tile_ids(main) == [[queue[0]], [queue[1]], [queue[3]]] and _shown_text(_tiles(main)[1], "Count") == "", "QT2 still under the pointer, the tile keeps its place with its one entry left, got %s" % [_tile_ids(main)])
	_click_in(port, _centre(_tiles(main)[1]))
	runner.check(_queued(main, "cancel_production").size() == 1 and _queued(main, "cancel_production")[0].production_id == queue[1], "QT2 a second click cancels the entry left, got %s" % [_queued(main, "cancel_production")])
	_click_in(port, _centre(_tiles(main)[0]))
	runner.check(_queued(main, "cancel_production").back().production_id == queue[0], "QT2 a click on the NOW tile cancels the entry in production")
	_end_port(scene)
	return true

# A unit finishing under the pointer: NOW and the bar move to the next entry's tile; the emptied tile offers no cancel, never another entry.
func test_queue_tiles_keep_entry_ids(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_produce(main, [MEDIUM, MEDIUM, MEDIUM])
	await _frames(runner)
	var queue: Array = _sim_queue(main, ids.factory)
	var tiles: Array = _tiles(main)
	runner.check(queue.size() == 3 and tiles.size() == 2, "QT3 fixture: three entries in two tiles, got %s %s" % [queue, _tile_ids(main)])
	if tiles.size() != 2:
		_end_port(scene)
		return true
	_move(port, _centre(tiles[0]))
	await _frames(runner)
	var sim = main.driver.pump.live()
	for step in 2000:
		if _sim_queue(main, ids.factory).size() < 3: break
		sim.step()
	for step in 60: sim.step()
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(_sim_queue(main, ids.factory) == [queue[1], queue[2]], "QT3 fixture: the unit in production finished under the pointer, got %s" % [_sim_queue(main, ids.factory)])
	runner.check(_tile_ids(main) == [[], [queue[1], queue[2]]], "QT3 the tiles hold their places; the finished one keeps no entry, got %s" % [_tile_ids(main)])
	var gone: Button = _tiles(main)[0]
	var next: Button = _tiles(main)[1]
	var producing: Dictionary = HudModel.building(main.driver.current().view, ids.factory).queue[0]
	var fraction: float = float(producing.work) / (Economy.unit(producing.kind).ticks * 1000)
	var bar: ColorRect = next.get_node("Track/Bar")
	runner.check(fraction > 0.0 and next.get_node("Now").is_visible_in_tree() and next.get_node("Track").is_visible_in_tree() and is_equal_approx(bar.anchor_right, fraction), "QT3 NOW and the bar follow the entry in production to the next tile at %.3f, got %s %.3f" % [fraction, next.get_node("Now").is_visible_in_tree(), bar.anchor_right])
	runner.check(not gone.get_node("Now").is_visible_in_tree() and not gone.get_node("Track").is_visible_in_tree() and gone.disabled and _shown_text(gone, "Chip") != "×" and gone.tooltip_text.is_empty(), "QT3 the hovered, emptied tile drops NOW, its bar and its ×, got chip '%s'" % _shown_text(gone, "Chip"))
	_click_in(port, _centre(gone))
	runner.check(_queued(main, "cancel_production").is_empty(), "QT3 a click on the emptied tile sends no cancel, got %s" % [_queued(main, "cancel_production")])
	_click_in(port, _centre(next))
	runner.check(_queued(main, "cancel_production").back().production_id == queue[2], "QT3 a click on the run's tile cancels its stored newest entry %d" % queue[2])
	_end_port(scene)
	return true

# As the kind rows: the tiles regroup only once the pointer leaves their row (`_holding`).
func test_queue_tiles_hold_under_pointer(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_queue_kinds(main, ids.factory, [MEDIUM, MEDIUM, ROTARY])
	await _frames(runner)
	var tiles: Array = _tiles(main)
	runner.check(_tile_ids(main) == [[900], [901], [902]], "QT4 fixture: three tiles, got %s" % [_tile_ids(main)])
	if tiles.size() != 3:
		_end_port(scene)
		return true
	var rects: Array = _rects(tiles)
	_move(port, _centre(tiles[1]))
	await _frames(runner)
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, ids.factory).queue = [{"id": 901, "kind": MEDIUM, "paid_cost": 800, "work": 3000}, {"id": 902, "kind": ROTARY, "paid_cost": 800, "work": 0}, {"id": 903, "kind": ROTARY, "paid_cost": 800, "work": 0}]
	main._show(view)
	await _frames(runner)
	runner.check(_tile_ids(main) == [[], [901], [902]] and _rects(_tiles(main)) == rects and _shown_text(_tiles(main)[2], "Count") == "", "QT4 a finished unit and a new one under the pointer: the three tiles hold, got %s" % [_tile_ids(main)])
	_move(port, _centre(tiles[2]))
	await _frames(runner)
	runner.check(_tile_ids(main) == [[], [901], [902]], "QT4 moving to the next tile keeps the hold")
	_move(port, Vector2((tiles[1] as Control).get_global_rect().end.x + 2.0, _centre(tiles[1]).y))
	await _frames(runner)
	runner.check(_tile_ids(main) == [[], [901], [902]], "QT4 the gap between two tiles keeps the hold")
	_move(port, Vector2(900, 200))
	await _frames(runner)
	runner.check(_tile_ids(main) == [[901], [902, 903]] and _shown_text(_tiles(main)[1], "Count") == "×2", "QT4 the pointer left the row, no new view: the tiles regroup, got %s" % [_tile_ids(main)])
	_move(port, _centre(_tiles(main)[0]))
	await _frames(runner)
	_queue_kinds(main, ids.barracks, ["china_rifle_infantry", "china_rocket_infantry"])
	_select(main, [], ids.barracks)
	await _frames(runner)
	runner.check(_tile_ids(main) == [[900], [901]] and _shown_text(_tiles(main)[0], "Name") == Registry.kind("china_rifle_infantry").display_name, "QT4 another building selected under the pointer shows its own queue, got %s" % [_tile_ids(main)])
	_end_port(scene)
	return true

# The NOW tile's bar is the only progress display, so it moves under a held pointer too; a hold never keeps an empty row or another selection's tiles.
func test_queue_hold_keeps_progress(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_queue_kinds(main, ids.factory, [MEDIUM, MEDIUM])
	await _frames(runner)
	var tiles: Array = _tiles(main)
	runner.check(tiles.size() == 2, "QT11 fixture: two tiles, got %s" % [_tile_ids(main)])
	if tiles.size() != 2:
		_end_port(scene)
		return true
	var bar: ColorRect = (tiles[0] as Node).get_node("Track/Bar")
	runner.check(is_equal_approx(bar.anchor_right, 0.42) and bar.color == View.owner_color(1, main._view.bright_owners()), "QT11 the NOW bar fills 42 %% in the own colour, got %.2f %s" % [bar.anchor_right, bar.color])
	_move(port, _centre(tiles[1]))
	await _frames(runner)
	_queue_kinds(main, ids.factory, [MEDIUM, MEDIUM], 252000)
	await _frames(runner)
	runner.check(_tile_ids(main) == [[900], [901]] and is_equal_approx(bar.anchor_right, 0.84), "QT11 under the pointer the NOW bar follows progress to 84 %%, got %.2f %s" % [bar.anchor_right, _tile_ids(main)])
	_queue_kinds(main, ids.factory, [])
	_move(port, Vector2(900, 200))
	await _frames(runner)
	_move(port, _centre(_tile_row(main).get_node("Empty")))
	await _frames(runner)
	_queue_kinds(main, ids.factory, [MEDIUM])
	await _frames(runner)
	runner.check(_tile_ids(main) == [[900]], "QT13 an empty row under the pointer shows the new entry at once, got %s" % [_tile_ids(main)])
	_end_port(scene)
	return true

# A control group can bring the factory back while the pointer rests where its tiles were, on the kind rows.
func test_queue_fresh_after_kind_rows(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _panel_world(main)
	_select(main, [], ids.factory)
	_queue_kinds(main, ids.factory, ["usa_tank", "usa_tank"])
	await _frames(runner)
	var tiles: Array = _tiles(main)
	runner.check(tiles.size() == 2, "QT12 fixture: two tiles, got %s" % [_tile_ids(main)])
	if tiles.size() != 2:
		_end_port(scene)
		return true
	var old: Rect2 = (tiles[0] as Control).get_global_rect()
	_select(main, [ids.tank, ids.collector])
	await _frames(runner)
	_move(port, Vector2(old.get_center().x, old.end.y - 8.0))
	await _frames(runner)
	runner.check(port.gui_get_hovered_control() != null, "QT12 fixture: the pointer on the kind rows inside the tiles' old rect, got %s" % port.gui_get_hovered_control())
	_queue_kinds(main, ids.factory, ["usa_light_vehicle"])
	_select(main, [], ids.factory)
	await _frames(runner)
	runner.check(_tile_ids(main) == [[900]] and _shown_text(_tiles(main)[0], "Name") == Registry.kind("usa_light_vehicle").display_name, "QT12 the factory selected again under the pointer shows its new queue, got %s" % [_tile_ids(main)])
	_end_port(scene)
	return true

# Past four tiles: three and a muted `+N more` counting the hidden entries, no click, its tooltip listing them.
func test_queue_more_counts_hidden(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	var medium: String = Registry.kind(MEDIUM).display_name
	var rotary: String = Registry.kind(ROTARY).display_name
	var queues: Array = [
		["four tiles", [MEDIUM, ROTARY, MEDIUM, ROTARY], 4, ""],
		["five tiles", [MEDIUM, ROTARY, MEDIUM, ROTARY, MEDIUM], 3, "+2"],
		["the full mock-up queue", [MEDIUM, MEDIUM, ROTARY, MEDIUM, ROTARY, ROTARY, MEDIUM, MEDIUM, ROTARY], 3, "+6"]]
	for case: Array in queues:
		_queue_kinds(main, ids.factory, case[1])
		await _frames(runner)
		var more: Control = _more(main)
		runner.check(_tiles(main).size() == case[2] and (more != null and more.is_visible_in_tree()) != case[3].is_empty() and _shown_text(more, "Count") == case[3], "QT5 %s: %d tiles and '%s', got %d '%s'" % [case[0], case[2], case[3], _tiles(main).size(), _shown_text(more, "Count")])
	var more: Control = _more(main)
	if more == null or not more.is_visible_in_tree():
		_end_port(scene)
		return true
	runner.check(_shown_text(more, "Label") == "more" and _colour(more.get_node("Count")) == _token("muted") and _colour(more.get_node("Label")) == _token("muted"), "QT5 '+6' over 'more', both muted")
	var tip: String = "%s\n%s ×2\n%s ×2\n%s" % [medium, rotary, medium, rotary]
	runner.check(more.tooltip_text == tip, "QT5 the tooltip lists the hidden entries, got '%s'" % more.tooltip_text)
	runner.check(more.mouse_default_cursor_shape == Control.CURSOR_ARROW and _tiles(main).all(func(tile: Control) -> bool: return tile.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND), "QT5 the arrow on +N more, the hand on the tiles")
	var plain: StyleBox = more.get_theme_stylebox("normal")
	runner.check(["hover", "pressed", "hover_pressed"].all(func(look: String) -> bool: return more.get_theme_stylebox(look) == plain), "QT5 +N more has no hover or pressed look")
	var cancelled: Array[int] = []
	var record := func(id: int) -> void: cancelled.append(id)
	main.hud.entry_cancelled.connect(record)
	_click_in(port, _centre(more))
	main.hud.entry_cancelled.disconnect(record)
	runner.check(cancelled.is_empty() and _queued(main, "cancel_production").is_empty(), "QT5 a click on +N more cancels nothing, got %s" % [cancelled])
	_end_port(scene)
	return true

# No cell carries a progress bar, only the NOW tile; every cell counts its kind's queued entries.
func test_cells_count_without_a_bar(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_queue_kinds(main, ids.factory, [ROTARY, MEDIUM, ROTARY])
	await _frames(runner)
	var rotary: Button = _cell(main, ROTARY)
	var medium: Button = _cell(main, MEDIUM)
	runner.check(rotary.get_node_or_null("Bar") == null and medium.get_node_or_null("Bar") == null, "QT6 no cell carries a progress bar; only the NOW tile does")
	runner.check(_shown_text(rotary, "Count") == "×2" and _shown_text(medium, "Count") == "×1", "QT6 the cells count all queued of their kind, ×2 and ×1, got '%s' '%s'" % [_shown_text(rotary, "Count"), _shown_text(medium, "Count")])
	var count: Control = rotary.get_node_or_null("Count")
	if count != null:
		var cell: Rect2 = rotary.get_global_rect()
		var fill: StyleBoxFlat = (count as Label).get_theme_stylebox("normal") as StyleBoxFlat
		var rect: Rect2 = count.get_global_rect()
		if fill != null: rect = rect.grow_individual(fill.expand_margin_left, fill.expand_margin_top, fill.expand_margin_right, fill.expand_margin_bottom)
		runner.check(is_equal_approx(rect.size.y, 14.0) and is_equal_approx(rect.end.x, cell.end.x - 4.0) and is_equal_approx(rect.end.y, cell.end.y - 4.0) and fill != null and fill.bg_color == _token("well"), "QT6 the count's well box is 14 high, 4 from the bottom right, got %s in %s" % [rect, cell])
	_queue_kinds(main, ids.factory, [])
	await _frames(runner)
	runner.check(_shown_text(rotary, "Count") == "" and _shown_text(medium, "Count") == "", "QT6 nothing queued: no count")
	_end_port(scene)
	return true

# 9 is the simulation's cap (`simulation.gd`, ZH#21): two presses at 8 in one frame are both sent, the second refused.
func test_queue_full_at_9(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	runner.check(_shown_text(main.get_node("HUD/Hud/SelectionPanel"), "Box/Top/RightLabel") == "", "QT7 nothing queued: no queue label")
	_produce(main, [MEDIUM])
	runner.check(_shown_text(main.get_node("HUD/Hud/SelectionPanel"), "Box/Top/RightLabel") == "QUEUE 1 / 9", "QT7 one queued: QUEUE 1 / 9, got '%s'" % _shown_text(main.get_node("HUD/Hud/SelectionPanel"), "Box/Top/RightLabel"))
	_produce(main, [MEDIUM, MEDIUM, ROTARY, MEDIUM, ROTARY, ROTARY, MEDIUM])
	runner.check(_sim_queue(main, ids.factory).size() == 8, "QT7 fixture: eight queued")
	var before: int = _queued(main, "produce").size()
	main.orders.press_cell(MEDIUM)
	main.orders.press_cell(ROTARY)
	runner.check(_queued(main, "produce").size() == before + 2, "QT7 two presses at 8 in one frame: both sent")
	BaseScene.tick(main)
	await _frames(runner)
	runner.check(_sim_queue(main, ids.factory).size() == 9 and main.hud.refusal == "Production queue full", "QT7 the second is refused: Production queue full, got %d '%s'" % [_sim_queue(main, ids.factory).size(), main.hud.refusal])
	runner.check(_shown_text(main.get_node("HUD/Hud/SelectionPanel"), "Box/Top/RightLabel") == "QUEUE 9 / 9", "QT7 nine queued: QUEUE 9 / 9")
	_end_port(scene)
	return true

# OpenRA's rule (user, 2026-11-21): a right-click on a production cell cancels the newest entry of its kind; none queued, nothing sent.
func test_right_click_cell_cancels_newest_of_kind(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_produce(main, [MEDIUM, ROTARY, MEDIUM, ROTARY, MEDIUM])
	await _frames(runner)
	var queue: Array = _sim_queue(main, ids.factory)
	runner.check(queue.size() == 5, "QT8 fixture: five queued, got %s" % [queue])
	if queue.size() != 5:
		_end_port(scene)
		return true
	var produced: int = _queued(main, "produce").size()
	_right_click_in(port, _centre(_cell(main, MEDIUM)))
	runner.check(_queued(main, "cancel_production").map(func(command: Dictionary) -> int: return command.production_id) == [queue[4]], "QT8 a right-click on the Medium Tank cell cancels its newest entry %d, got %s" % [queue[4], _queued(main, "cancel_production")])
	_right_click_in(port, _centre(_cell(main, ROTARY)))
	runner.check(_queued(main, "cancel_production").back().production_id == queue[3], "QT8 a right-click on the Rotary Gun Tank cell cancels its newest entry %d" % queue[3])
	runner.check(_queued(main, "produce").size() == produced and _queued(main, "set_rally").is_empty(), "QT8 a right-click on a cell produces nothing and sets no rally point")
	BaseScene.tick(main)
	await _frames(runner)
	runner.check(_sim_queue(main, ids.factory) == [queue[0], queue[1], queue[2]], "QT8 the older entries keep their order, got %s" % [_sim_queue(main, ids.factory)])
	_select(main, [], ids.barracks)
	await _frames(runner)
	var sent: int = main.driver.queued().size()
	_right_click_in(port, _centre(_cell(main, "china_rifle_infantry")))
	runner.check(main.driver.queued().size() == sent, "QT8 none of the kind queued: a right-click sends nothing, got %s" % [main.driver.queued().slice(sent)])
	_end_port(scene)
	return true

# Same-tick: a tile click and a right-click on one entry, or two clicks on one tile, in one frame: one refund, then Missing production entry.
func test_queue_cancels_in_one_frame(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _queue_world(main)
	_produce(main, [ROTARY, MEDIUM, MEDIUM])
	await _frames(runner)
	var queue: Array = _sim_queue(main, ids.factory)
	runner.check(_tile_ids(main) == [[queue[0]], [queue[1], queue[2]]], "QT10 fixture: two tiles, got %s" % [_tile_ids(main)])
	if _tiles(main).size() != 2:
		_end_port(scene)
		return true
	_move(port, _centre(_tiles(main)[1]))
	await _frames(runner)
	for case: Array in [["a tile click and a right-click on its cell", func() -> void: _right_click_in(port, _centre(_cell(main, MEDIUM)))], ["two clicks on one tile", func() -> void: _click_in(port, _centre(_tiles(main)[1]))]]:
		var newest: int = _sim_queue(main, ids.factory).back()
		var credits: int = _own_credits(main)
		var before: int = _queued(main, "cancel_production").size()
		_click_in(port, _centre(_tiles(main)[1]))
		case[1].call()
		var sent: Array = _queued(main, "cancel_production").slice(before)
		runner.check(sent.size() == 2 and sent.all(func(command: Dictionary) -> bool: return command.production_id == newest), "QT10 %s: both sent for entry %d, got %s" % [case[0], newest, sent])
		BaseScene.tick(main)
		await _frames(runner)
		runner.check(_own_credits(main) == credits + 800 and main.hud.refusal == "Missing production entry", "QT10 %s: one refund, then Missing production entry, got %d '%s'" % [case[0], _own_credits(main) - credits, main.hud.refusal])
	_end_port(scene)
	return true

# hud-v5-layout "Selection panel" (P2.3b, 3-3): every own producer's panel is 152 high, the tiles one row of four 91 x 60.
func test_factory_panel_fixed_152(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var queues: Array = [["0 queued", [], 0], ["1 queued", [MEDIUM], 1], ["5 queued", [MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY], 3], ["9 queued", [MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY, MEDIUM, ROTARY, MEDIUM, ROTARY], 4]]
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var ids: Dictionary = _queue_world(main)
		var refusal := Rect2((408.0 + size.x - 432.0) / 2.0 - 208.0, size.y - 36.0, 416.0, 28.0)
		var heights: Array = []
		for queued: Array in queues:
			_queue_kinds(main, ids.factory, queued[1])
			await _frames(runner)
			var at: String = "%s at %s" % [queued[0], size]
			var panel: Rect2 = _rect(main, "HUD/Hud/SelectionPanel")
			runner.check(absf(panel.position.x) <= 0.5 and is_equal_approx(panel.size.x, 408.0) and absf(panel.end.y - size.y) <= 0.5 and absf(panel.size.y - 152.0) <= 1.0 and view.encloses(panel), "QT9 %s: x 0, 408 wide, bottom on H, 152 high, got %s" % [at, panel])
			heights.append(panel.size.y)
			for other: Array in [["the slab", _rect(main, "HUD/Economy")], ["the strip", _rect(main, "HUD/Hud/TopStrip")], ["the refusal line", refusal]]: runner.check(not panel.intersects(other[1]), "QT9 %s: clear of %s" % [at, other[0]])
			var content: Rect2 = panel.grow_individual(-16.0, -12.0, -16.0, -12.0)
			var shown: Array = _tiles(main)
			var more: Control = _more(main)
			if more != null and more.is_visible_in_tree(): shown.append(more)
			runner.check(shown.size() == queued[2] and (queued[1].size() < 9 or _shown_text(more, "Count") == "+4") and (queued[1].size() < 5 or _shown_text(shown[1], "Count") == "×2"), "QT9 %s: %d tiles, ×N and +N more as queued, got %s" % [at, queued[2], _tile_ids(main)])
			for i in shown.size():
				var tile: Rect2 = (shown[i] as Control).get_global_rect()
				runner.check(tile.size == Vector2(91, 60) and is_equal_approx(tile.position.x, panel.position.x + 16.0 + 95.0 * i) and is_equal_approx(tile.position.y, panel.position.y + 58.0) and content.grow(0.5).encloses(tile), "QT9 %s: tile %d 91 x 60 at x %.0f, 8 under the health row, inside the content, got %s" % [at, i + 1, panel.position.x + 16.0 + 95.0 * i, tile])
				for label: Label in (shown[i] as Node).find_children("*", "Label", true, false):
					if label.is_visible_in_tree(): runner.check(tile.grow(0.5).encloses(label.get_global_rect()) and label.get_global_rect().size.y < 43.0, "QT9 %s: tile %d's %s inside it, at most two lines, got %s" % [at, i + 1, label.name, label.get_global_rect()])
				var track: Control = (shown[i] as Node).get_node_or_null("Track")
				if track != null: runner.check(((shown[i] as Node).get_node("Name") as Control).get_global_rect().end.y <= track.get_global_rect().position.y, "QT9 %s: tile %d's name ends above its bar, got name %s, bar %s" % [at, i + 1, ((shown[i] as Node).get_node("Name") as Control).get_global_rect(), track.get_global_rect()])
			var empty: Label = _tile_row(main).get_node_or_null("Empty") if _tile_row(main) != null else null
			runner.check((empty != null and empty.is_visible_in_tree() and empty.text == "Nothing in production" and _colour(empty) == _token("muted") and content.grow(0.5).encloses(empty.get_global_rect())) == queued[1].is_empty(), "QT9 %s: muted Nothing in production exactly when empty" % at)
			var footer: Control = _panel_part(main, "Footer")
			runner.check(footer.is_visible_in_tree() and (shown.is_empty() or footer.get_global_rect().position.y >= (shown[0] as Control).get_global_rect().end.y) and content.grow(0.5).encloses(footer.get_global_rect()), "QT9 %s: the rally footer under the tiles, inside the content" % at)
			_panel_contained(runner, main, panel, at)
		_select(main, [], ids.barracks)
		await _frames(runner)
		runner.check(heights.min() == heights.max(), "QT9 the factory panel holds one height from 0 to 9 queued at %s, got %s" % [size, heights])
		runner.check(absf(_panel_height(main) - 152.0) <= 1.0, "QT9 the barracks' panel is 152 high too at %s, got %.1f" % [size, _panel_height(main)])
		port.free()
	overlays._end(saved)
	return true

static func _slab_buttons(main) -> Array:
	return _cells(main).filter(func(cell: Control) -> bool: return cell.is_visible_in_tree())

static func _rects(controls: Array) -> Array:
	return controls.map(func(control: Control) -> Rect2: return control.get_global_rect())

static func _all_shown(controls: Array) -> bool:
	return controls.all(func(control: Control) -> bool: return control.is_visible_in_tree())

# Gate B (user 2026-11-20): a queue change never moves a card cell under the pointer; P2.3b moved the queue into the panel.
func test_slab_buttons_hold_still(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_prerequisites(main)
	_select(main, [], ids.factory)
	await _frames(runner)
	var at: Vector2 = _cell(main, "china_light_vehicle").get_global_rect().get_center()
	var cancelled: Array[int] = []
	main.hud.entry_cancelled.connect(func(id: int) -> void: cancelled.append(id))
	_click(runner, at)
	_queue_of(main, ids.factory, 1, 0)
	await _frames(runner)
	_click(runner, at)
	runner.check(_queued(main, "produce").size() == 2 and cancelled.is_empty(), "SL8 two clicks on the Q cell at %s queue twice and cancel nothing, got %d produce, cancelled %s" % [at, _queued(main, "produce").size(), cancelled])
	_queue_of(main, ids.factory, 0)
	await _frames(runner)
	var buttons: Array = _slab_buttons(main)
	var still: Array = _rects(buttons)
	runner.check(buttons.size() == 12 and _all_shown(buttons), "SL8 fixture: the factory's card shown")
	for step: Array in [[1, "one queued"], [5, "five queued"], [6, "six queued"], [9, "nine queued"], [1, "back to one"], [0, "the unit finished, 1 to 0"]]:
		_queue_of(main, ids.factory, step[0])
		await _frames(runner)
		runner.check(_all_shown(buttons) and _rects(buttons) == still, "SL8 %s: the cells shown and holding their rects %s, got %s" % [step[1], still, _rects(buttons)])
	main.free()
	return true

# P2.3b: Unload takes F in Attack Move's row (hud-v5-layout "Cards per state"); Attack Move and Stop never move.
func test_unload_row_above_the_orders(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_select(main, [ids.car])
	await _frames(runner)
	var pair: Array = [main.get_node("HUD/Economy/Card/A"), main.get_node("HUD/Economy/Card/S")]
	var unload: Button = main.get_node("HUD/Economy/Card/F")
	var still: Array = _rects(pair)
	runner.check(_all_shown(pair) and unload.get_meta("action") == "", "SL8 fixture: an empty Scout Car shows Attack Move and Stop, F a well")
	var sim = main.driver.pump.live()
	var rider: int = sim.spawn(1, Vector2(12.5, 5.5), "usa_rifle_infantry")
	Fixture.load_unit(runner, sim, rider, ids.car)
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(unload.get_meta("action") == "unload" and is_equal_approx(unload.get_global_rect().position.y, (pair[0] as Control).get_global_rect().position.y), "SL8 a rider boards: Unload on F in Attack Move's row, got %s beside %s" % [unload.get_global_rect(), (pair[0] as Control).get_global_rect()])
	runner.check(_all_shown(pair) and _rects(pair) == still, "SL8 a rider boards: Attack Move and Stop hold their rects %s, got %s" % [still, _rects(pair)])
	sim.remove_object(rider)
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(unload.get_meta("action") == "" and _all_shown(pair) and _rects(pair) == still, "SL8 the rider gone: F a well again, Attack Move and Stop hold their rects %s, got %s" % [still, _rects(pair)])
	main.free()
	return true

func test_unload_needs_its_own_rider(runner) -> bool:
	var sim = Fixture.make_world()
	var empty: int = sim.spawn(1, Vector2(12.5, 4.5), "usa_light_vehicle")
	var loaded: int = sim.spawn(1, Vector2(14.5, 4.5), "usa_light_vehicle")
	var hub: int = Fixture.add_completed(sim, 1, "frc_defence", Vector2i(18, 4))
	Fixture.load_unit(runner, sim, sim.spawn(1, Vector2(14.5, 5.5), "usa_rifle_infantry"), loaded)
	var view: Dictionary = sim.view_state()
	var target := func(ids: Array[int]) -> int: return HudModel.unload_target(view, {"ids": ids, "building_id": -1}, 1)
	runner.check(target.call([empty] as Array[int]) == -1, "UR1 an empty Scout Car beside a loaded one has no Unload")
	runner.check(target.call([loaded] as Array[int]) == loaded, "UR1 the loaded Scout Car has Unload")
	runner.check(target.call([empty, loaded] as Array[int]) == -1, "UR1 two Scout Cars selected together have no Unload")
	Fixture.load_unit(runner, sim, sim.spawn(1, Vector2(17.5, 4.5), "frc_rifle_infantry"), hub)
	runner.check(HudModel.unload_target(sim.view_state(), {"ids": [empty] as Array[int], "building_id": -1}, 1) == -1, "UR1 a loaded hub does not load the empty Scout Car")
	return true

static func _cells(main) -> Array:
	return main.get_node("HUD/Economy/Card").get_children()

# The shown cells' actions in lattice order, wells left out.
static func _actions(economy: Node) -> Array:
	return economy.get_node("Card").get_children().filter(func(cell: Control) -> bool: return cell.is_visible_in_tree() and not str(cell.get_meta("action")).is_empty()).map(func(cell: Control) -> String: return cell.get_meta("action"))

# The shown card top-down, one entry per lattice position: its shown words, "" for a well; rows above the top row left out.
static func _card(main) -> Array:
	if not _shown(main, "Card"): return []
	return _cells(main).filter(func(cell: Control) -> bool: return cell.visible).map(func(cell: Control) -> String: return " ".join(cell.get_children().filter(func(label: Node) -> bool: return label is Label and (label as Label).visible and not (label as Label).text.is_empty()).map(func(label: Label) -> String: return label.text)))

static func _cell(main, action: String) -> Button:
	for cell: Button in _cells(main):
		if cell.is_visible_in_tree() and cell.get_meta("action") == action: return cell
	return null

# Opens the build sub-grid of a lone builder by its key.
static func _sub_grid(main, builder: int) -> void:
	_select(main, [builder])
	BaseScene.new().key(main, HudModel.BUILD_KEY)

const EIGHT_WELLS: Array = ["", "", "", "", "", "", "", ""]

# P2.3b T5: the card is HudModel.card() laid on the Q W E R / A S D F / Z X C V lattice, wells between.
func test_card_by_selection(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true, 500)
	var barracks: int = Fixture.add_completed(main.driver.pump.live(), 1, "china_barracks", Vector2i(24, 10))
	BaseScene.publish(main)
	var states: Array = [
		["a lone builder", [ids.builder], -1, -1, ["Q Build ›", "", "", ""] + EIGHT_WELLS],
		["two builders", [ids.builder, ids.frc_builder], -1, -1, ["Q Build ›", "", "", ""] + EIGHT_WELLS],
		["a builder with a tank", [ids.builder, ids.tanks[0]], -1, -1, ["A Attack Move", "S Stop", "", "", "", "", "", ""]],
		["collectors alone", ids.collectors, -1, -1, ["", "S Stop", "", "", "", "", "", ""]],
		["a loaded Scout Car", [ids.car], -1, -1, ["A Attack Move", "S Stop", "", "F Unload", "", "", "", ""]],
		["a loaded Tunnel Hub", [], ids.hub, -1, ["", "", "", "F Unload", "", "", "", ""]],
		["the China factory", [], ids.factory, -1, ["800 Q Medium Tank", "800 W Rotary Gun Tank", "", ""] + EIGHT_WELLS],
		["the China barracks", [], barracks, -1, ["300 Q Militia", "300 W Anti-Tank Trooper", "", ""] + EIGHT_WELLS],
		["nothing", [], -1, -1, []], ["an own Power Plant", [], ids.plant, -1, []], ["an inspected enemy", [], -1, ids.enemy, []], ["a pile", [], -1, ids.pile, []]]
	for case: Array in states:
		_select(main, case[1], case[2], case[3])
		runner.check(_card(main) == case[4], "CD1 %s: the card %s, got %s" % [case[0], case[4], _card(main)])
	_sub_grid(main, ids.builder)
	runner.check(_card(main) == ["1000 Q Power Plant", "1500 W Supply Depot", "500 E Barracks", "2000 R Vehicle Factory", "1200 A Rotary Gun Tower", "", "", "", "", "", "", "V Back"], "CD1 Build: the China sub-grid with Back on V, got %s" % [_card(main)])
	_sub_grid(main, ids.frc_builder)
	runner.check(_card(main) == ["", "1500 W Supply Cache", "500 E Barracks", "2500 R Vehicle Yard", "800 A Tunnel Hub", "", "", "", "", "", "", "V Back"], "CD1 Build: FRC's Q stays a well, got %s" % [_card(main)])
	# At 500 credits the Supply Cache cell is blocked and arms nothing.
	_set_credits(main, 1500)
	BaseScene.new().key(main, KEY_W)
	var armed: Array = _cells(main).filter(func(cell: Button) -> bool: return cell.theme_type_variation == &"HudButtonArmed").map(func(cell: Button) -> String: return str(cell.name))
	runner.check(_card(main).back() == "V Cancel" and armed == ["W"], "CD1 placement: only the armed cell cyan and Back reads Cancel, got %s %s" % [armed, _card(main).back()])
	main.orders._clear_placement()
	var view: Dictionary = main.driver.current().view
	_site(view, ids.factory, ids.builder)
	main._show(view)
	_select(main, [], ids.factory)
	runner.check(_card(main).is_empty() and _shown(main, "CancelBuild"), "CD1 an own site: no card, Cancel construction outside it")
	main.free()
	return true

# Click equals key: a cell press does what its key does; a well takes no click.
func test_card_click_equals_key(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true)
	_prerequisites(main)
	_select(main, [ids.builder])
	await _frames(runner)
	var well: Button = main.get_node("HUD/Economy/Card/W")
	_click(runner, well.get_global_rect().get_center())
	runner.check(main.driver.queued().is_empty() and not main.orders._sub_grid and well.mouse_filter == Control.MOUSE_FILTER_IGNORE, "CD2 a click on a well does nothing")
	_key_then_click(runner, main, _cell(main, "build"), "Build")
	runner.check(main.orders._sub_grid, "CD2 a click on Build opens the sub-grid")
	await _frames(runner)
	_key_then_click(runner, main, _cell(main, "china_power_plant"), "Power Plant")
	runner.check(main.orders._placement_kind == "china_power_plant", "CD2 a click on Power Plant arms it")
	_key_then_click(runner, main, _cell(main, "back"), "Cancel")
	runner.check(main.orders._placement_kind.is_empty() and main.orders._sub_grid, "CD2 a click on Cancel ends the placement, the sub-grid stays")
	_key_then_click(runner, main, _cell(main, "back"), "Back")
	runner.check(not main.orders._sub_grid and _cell(main, "build") != null, "CD2 a click on Back closes the sub-grid")
	_select(main, ids.collectors)
	await _frames(runner)
	_key_then_click(runner, main, _cell(main, "stop"), "Stop")
	runner.check(_queued(main, "stop").size() == 1 and _queued(main, "stop")[0].entity_ids == ids.collectors, "CD2 a click on the collectors' Stop sends one stop, got %s" % [_queued(main, "stop")])
	_select(main, [ids.car])
	await _frames(runner)
	_key_then_click(runner, main, _cell(main, "attack_move"), "Attack Move")
	runner.check(main.orders._attack_move_mode and _cell(main, "attack_move").theme_type_variation == &"HudButtonArmed", "CD2 a click on Attack Move arms it, the cell cyan")
	_key_then_click(runner, main, _cell(main, "unload"), "Unload")
	runner.check(_queued(main, "unload").size() == 1 and _queued(main, "unload")[0].target_id == ids.car and not main.orders._attack_move_mode, "CD2 a click on Unload unloads the car and disarms, got %s" % [_queued(main, "unload")])
	_select(main, [], ids.factory)
	await _frames(runner)
	_key_then_click(runner, main, _cell(main, "china_light_vehicle"), "Medium Tank")
	var made: Array = _queued(main, "produce")
	runner.check(made.size() == 1 and made[0].unit_kind == "china_light_vehicle" and made[0].building_id == ids.factory, "CD2 a click on the factory's Q cell queues a Medium Tank, got %s" % [made])
	main.free()
	return true

# Presses the cell by its key, rewinds the orders and the queue, then clicks it: both must leave the same.
static func _key_then_click(runner, main, cell: Button, what: String) -> void:
	var queued: int = main.driver.queued().size()
	var before: Array = _press_state(main, queued)
	BaseScene.new().key(main, HudModel.GRID_KEYS[cell.get_index()])
	var by_key: Array = _press_state(main, queued)
	main.orders.selected_ids.assign(before[0])
	main.orders.selected_building_id = before[1]
	main.orders._sub_grid = before[2]
	main.orders._placement_kind = before[3]
	main.orders._set_attack_move(before[4])
	main.driver.queued().resize(queued)
	main._refresh()
	_click(runner, cell.get_global_rect().get_center())
	var by_click: Array = _press_state(main, queued)
	runner.check(by_key != before and by_key == by_click, "CD2 %s: its key and its click do the same, got key %s click %s" % [what, by_key, by_click])

static func _press_state(main, queued: int) -> Array:
	var orders = main.orders
	return [orders.selected_ids.duplicate(), orders.selected_building_id, orders._sub_grid, orders._placement_kind, orders._attack_move_mode, main.driver.queued().slice(queued)]

# hud-v5-layout "Command card": cells at x W-420+104i, y H-196+64r, 100x60; the slab hugs from the top row, 8 above it.
func test_card_lattice(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await OverlayTests.new()._scene(runner, Skirmish, port)
		var ids: Dictionary = _slab_world(runner, main, true)
		for state: Array in [["the sub-grid", ids.builder, 3], ["a loaded Scout Car", ids.car, 2]]:
			var label: String = "%s at %s" % [state[0], size]
			if state[2] == 3: _sub_grid(main, state[1])
			else: _select(main, [state[1]])
			await _frames(runner)
			var shown: Array = _cells(main).filter(func(cell: Control) -> bool: return cell.is_visible_in_tree())
			var top: int = 3 - state[2]
			var placed: Array = []
			for cell: Control in shown:
				var at: int = HudModel.GRID_KEYS.find(OS.find_keycode_from_string(str(cell.name)))
				var want := Rect2(size.x - 420.0 + 104.0 * (at % 4), size.y - 196.0 + 64.0 * int(at / 4.0), 100.0, 60.0)
				if not cell.get_global_rect().is_equal_approx(want): placed.append([cell.name, cell.get_global_rect(), want])
				for part: Control in cell.get_children():
					if part.is_visible_in_tree() and not cell.get_global_rect().grow(0.5).encloses(part.get_global_rect()): placed.append([cell.name, part.name])
			runner.check(shown.size() == 4 * state[2] and placed.is_empty(), "CD3 %s: %d rows of cells on the lattice, every label inside its cell, got %s" % [label, state[2], placed])
			var slab: Rect2 = _rect(main, "HUD/Economy")
			runner.check(is_equal_approx(slab.position.y, size.y - 196.0 + 64.0 * top - 8.0) and is_equal_approx(slab.size.y, 12.0 + 64.0 * state[2]) and view.encloses(slab), "CD3 %s: the slab %.0f high, its top 8 above the top row, got %s" % [label, 12.0 + 64.0 * state[2], slab])
			var panels: Dictionary = BaseScene.hud_panels(main)
			for path: String in panels:
				if path != "HUD/Economy": runner.check(not slab.intersects(panels[path]), "CD3 %s: the slab clears %s" % [label, path])
		port.free()
	return true

# hud-v5-layout "Type scale": every name of every faction's builds and produces fits two lines of its cell.
func test_cell_names_fit(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var economy := _economy()
	hud.get_parent().add_child(economy)
	hud.setup(economy)
	var kinds: Array = []
	for menu: Array in _every_menu(): kinds.append_array(menu)
	var cut: Array = []
	for kind: String in kinds:
		var cell: Button = economy.get_node("Card/Q")
		hud._fill_cell(cell, kind, _armed(""), {})
		var name_label: Label = cell.get_node("Name")
		if name_label.get_line_count() > 2 or name_label.get_visible_line_count() < name_label.get_line_count() or name_label.position.y + name_label.get_combined_minimum_size().y > 60.0 - 2.0: cut.append(name_label.text)
	runner.check(kinds.size() > 20 and cut.is_empty(), "CD4 every one of %d names fits two lines inside its cell, got %s" % [kinds.size(), cut])
	hud.get_parent().free()
	return true

func test_cell_costs_by_credits(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false, 500)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	var tower: Button = _cell(main, "china_defence")
	var price: Label = tower.get_node("Cost")
	runner.check(price.text == "1200" and _colour(price) == _token("warn"), "SL6 credits 500: the tower's bare 1200 in warn, got '%s'" % price.text)
	runner.check(_cell(main, "china_barracks").get_node("Cost").text == "500" and _colour(_cell(main, "china_barracks").get_node("Cost")) == _token("text"), "SL6 the affordable barracks' 500 in text")
	var rebuilds: int = main.hud.rebuilds
	var node_id: int = price.get_instance_id()
	for credits: Array in [[1200, "text"], [499, "warn"]]:
		var view: Dictionary = main.driver.current().view
		HudModel.player(view, 1).credits = credits[0]
		main._show(view)
		runner.check(_colour(price) == _token(credits[1]) and main.hud.rebuilds == rebuilds and tower.get_node("Cost").get_instance_id() == node_id, "SL6 credits %d: the cost in %s, patched in place" % [credits[0], credits[1]])
	main.free()
	return true

# USA builder 1 with no Power Plant, a second USA builder and a USA factory without its Supply Depot.
static func _blocked_world(main, credits: int) -> Dictionary:
	var sim = Fixture.make_world(credits)
	var ids := {"builder": 1}
	ids.builders = [1, sim.spawn(1, Vector2(6.5, 4.5), "usa_builder")]
	ids.factory = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(14, 14))
	main.driver.adopt(sim)
	main._refresh()
	return ids

static func _set_credits(main, credits: int) -> void:
	var view: Dictionary = main.driver.current().view
	HudModel.player(view, 1).credits = credits
	main._show(view)

static func _text_width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x

# One blocked cell read whole: its reason, the quiet look with a muted name, the cost's tone and the coin 4 after the bare cost.
static func _blocked_look(runner, cell: Button, reason: String, cost_token: String, coin: bool, label: String) -> void:
	var found: String = cell.get_meta("blocked", {}).get("reason", "")
	runner.check(found == reason, "BC1 %s: reason '%s', got '%s'" % [label, reason, found])
	var fill: StyleBoxFlat = cell.get_theme_stylebox("normal") as StyleBoxFlat
	var blocked: bool = not reason.is_empty()
	runner.check(fill != null and (fill.bg_color == _token("quiet")) == blocked and (_colour(cell.get_node("Name")) == _token("muted")) == blocked, "BC1 %s: quiet fill and muted name only when blocked (%s), got %s" % [label, blocked, fill.bg_color if fill != null else null])
	var cost: Label = cell.get_node("Cost")
	if cost.visible: runner.check(_colour(cost) == _token(cost_token), "BC1 %s: the cost in %s, got %s" % [label, cost_token, _colour(cost)])
	var mark: Control = cell.get_node("Coin")
	runner.check(mark.is_visible_in_tree() == coin, "BC1 %s: the coin shown %s" % [label, coin])
	if not coin: return
	var at: Rect2 = mark.get_global_rect()
	var after: float = cost.get_global_rect().position.x + _text_width(cost) + 4.0
	runner.check(at.size == Vector2(15, 15) and absf(at.position.x - after) <= 0.5 and absf(at.get_center().y - (cell.get_global_rect().position.y + 14.0)) <= 0.5, "BC1 %s: the 15 px coin 4 after the bare cost on line 1 (x %.1f), got %s" % [label, after, at])

# Reasons in the simulation's order (prerequisite, queue, credits), the producer's prerequisite, the two-cause look, two builders.
func test_blocked_cells(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 1000)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	_blocked_look(runner, _cell(main, "usa_power_plant"), "", "text", false, "affordable Power Plant")
	_blocked_look(runner, _cell(main, "usa_supply_center"), "Needs Power Plant", "muted", false, "Supply Depot short and missing its Power Plant")
	_blocked_look(runner, _cell(main, "usa_factory"), "Needs Supply Depot", "muted", false, "Vehicle Factory short and missing its Supply Depot")
	_blocked_look(runner, _cell(main, "usa_defence"), "Needs Power Plant", "muted", false, "Missile Battery at its exact cost, missing its Power Plant")
	var sim = main.driver.pump.live()
	Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(20, 4))
	BaseScene.publish(main)
	_set_credits(main, 500)
	await _frames(runner)
	_blocked_look(runner, _cell(main, "usa_power_plant"), "300 credits short", "warn", true, "Power Plant short alone")
	_blocked_look(runner, _cell(main, "usa_supply_center"), "1500 credits short", "warn", true, "Supply Depot short alone")
	_blocked_look(runner, _cell(main, "usa_barracks"), "100 credits short", "warn", true, "Barracks short alone")
	_blocked_look(runner, _cell(main, "usa_factory"), "Needs Supply Depot", "muted", false, "Vehicle Factory with two causes")
	_select(main, [], ids.factory)
	await _frames(runner)
	_blocked_look(runner, _cell(main, "usa_light_vehicle"), "Needs Supply Depot", "muted", false, "a unit cell under its factory's missing Supply Depot")
	var depot: int = Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(20, 20))
	BaseScene.publish(main)
	_set_credits(main, 500)
	await _frames(runner)
	_blocked_look(runner, _cell(main, "usa_light_vehicle"), "200 credits short", "warn", true, "Scout Car short alone")
	_queue_of(main, ids.factory, 9)
	await _frames(runner)
	_blocked_look(runner, _cell(main, "usa_light_vehicle"), "Queue full", "muted", false, "a full queue before the credits")
	_set_credits(main, 50000)
	_queue_of(main, ids.factory, 9)
	_blocked_look(runner, _cell(main, "usa_tank"), "Queue full", "muted", false, "a full queue alone")
	var view: Dictionary = main.driver.current().view
	view.buildings = view.buildings.filter(func(found: Dictionary) -> bool: return found.id != depot)
	main._show(view)
	_blocked_look(runner, _cell(main, "usa_tank"), "Needs Supply Depot", "muted", false, "the prerequisite before a full queue")
	_select(main, ids.builders)
	await _frames(runner)
	var build: Button = _cell(main, "build")
	_blocked_look(runner, build, "Select one builder", "", false, "Build with two builders")
	runner.check(_card(main) == ["Q Build ›", "", "", ""] + EIGHT_WELLS, "BC1 two builders keep the Build cell and its chip, got %s" % [_card(main)])
	_select(main, [ids.builder])
	await _frames(runner)
	_blocked_look(runner, _cell(main, "build"), "", "", false, "Build with one builder")
	main.free()
	return true

static func _sounds(main) -> Array:
	main._show(main.driver.current().view)
	return main._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)

# A blocked cell's click does what its key does: nothing arms or is sent, the reason goes on the line with the reason's sound.
func test_blocked_press_equals_key(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 1000)
	var sim = main.driver.pump.live()
	var presses: Array = [
		["missing prerequisite", [ids.builder], -1, true, "usa_supply_center", "Needs Power Plant", ["error"]],
		["credits short", [ids.builder], -1, true, "usa_power_plant", "300 credits short", ["disabled"]],
		["queue full", [], ids.factory, false, "usa_tank", "Queue full", ["error"]],
		["two builders", ids.builders, -1, false, "build", "Select one builder", []]]
	for case: Array in presses:
		main.orders._clear_placement()
		if case[0] == "credits short":
			Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(20, 4))
			BaseScene.publish(main)
		if case[0] == "queue full": Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(20, 20))
		BaseScene.publish(main)
		_select(main, case[1], case[2])
		main.orders._sub_grid = case[3]
		if case[0] == "credits short": _set_credits(main, 500)
		if case[0] == "queue full": _queue_of(main, ids.factory, 9)
		main._reshow()
		await _frames(runner)
		var cell: Button = _cell(main, case[4])
		var before: Array = _press_state(main, 0)
		main.hud.clear_refusal()
		BaseScene.new().key(main, HudModel.GRID_KEYS[cell.get_index()])
		var by_key: Array = [_press_state(main, 0), main.hud.refusal, _sounds(main)]
		main.hud.clear_refusal()
		main._sound.last_requests().clear()
		_click(runner, cell.get_global_rect().get_center())
		var plain: Array = main._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)
		var by_click: Array = [_press_state(main, 0), main.hud.refusal, _sounds(main)]
		runner.check(by_key[0] == before and by_key[1] == case[5] and by_key[2] == case[6], "BC2 %s: the key arms and sends nothing, '%s' and %s, got %s" % [case[0], case[5], case[6], by_key])
		runner.check(by_click == by_key and plain.is_empty(), "BC2 %s: the click equals the key, no button click, got %s %s" % [case[0], by_click, plain])
	main.free()
	return true

# hud-v5-layout "Cell card": opens 250 ms after the pointer enters a cell, switches at once to a neighbour, closes on leaving and on a click.
func test_cell_card_timing(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 1000)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	var clock: Array[int] = [10000]
	main.hud.now_msec = func() -> int: return clock[0]
	var card: Control = main.get_node("HUD/Hud/CellCard")
	var plant: Button = _cell(main, "usa_power_plant")
	var depot: Button = _cell(main, "usa_supply_center")
	var name_of = func() -> String: return (card.find_child("Name", true, false) as Label).text
	plant.mouse_entered.emit()
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 no card the moment the pointer enters")
	clock[0] += 249
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 no card at 249 ms")
	clock[0] += 1
	main.hud._process(0.0)
	runner.check(card.visible and name_of.call() == "Power Plant", "CC1 the card opens at 250 ms, got %s '%s'" % [card.visible, name_of.call()])
	plant.mouse_exited.emit()
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 the card closes in the gap between cells")
	depot.mouse_entered.emit()
	main.hud._process(0.0)
	runner.check(card.visible and name_of.call() == "Supply Depot", "CC1 a neighbour's card opens at once, got %s '%s'" % [card.visible, name_of.call()])
	depot.mouse_exited.emit()
	main.get_node("HUD/Economy/Card").mouse_exited.emit()
	plant.mouse_entered.emit()
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 back on the card after leaving it, the wait starts again")
	clock[0] += 250
	main.hud._process(0.0)
	runner.check(card.visible, "CC1 then the card opens at 250 ms")
	depot.mouse_entered.emit()
	plant.mouse_exited.emit()
	main.hud._process(0.0)
	depot.pressed.emit()
	clock[0] += 1000
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 a click closes the card until the pointer enters a cell again")
	plant.mouse_entered.emit()
	clock[0] += 250
	main.hud._process(0.0)
	runner.check(card.visible, "CC1 fixture: the card is open before the reset")
	main.hud.reset()
	depot.mouse_entered.emit()
	main.hud._process(0.0)
	runner.check(not card.visible, "CC1 after a reset the next cell waits its 250 ms again")
	main.free()
	return true

# An open card is laid out when the hover or the view changes, not on every frame (plan Design, F38).
func test_open_cell_card_waits_for_a_change(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 1000)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	main.hud.now_msec = func() -> int: return 10000
	var card: Control = main.get_node("HUD/Hud/CellCard")
	_cell(main, "usa_power_plant").mouse_entered.emit()
	main.hud.now_msec = func() -> int: return 10250
	main.hud._process(0.0)
	var placed: Vector2 = card.position
	card.position = Vector2(-1.0, -1.0)
	main.hud._process(0.0)
	runner.check(card.visible and card.position == Vector2(-1.0, -1.0), "CC3 a frame leaves an open card alone, got %s %s" % [card.visible, card.position])
	main._reshow()
	runner.check(card.visible and card.position == placed, "CC3 a refresh lays it out again at %s, got %s" % [placed, card.position])
	main.free()
	return true

# The ready Build cell clicks, though within the press the same cell turns into the unaffordable Power Plant.
func test_build_click_sounds(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 500)
	_select(main, [ids.builder])
	await _frames(runner)
	var cell: Button = _cell(main, "build")
	main._sound.last_requests().clear()
	_click(runner, cell.get_global_rect().get_center())
	var cues: Array = main._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)
	runner.check(main.orders._sub_grid and _cell(main, "usa_power_plant") == cell and not (cell.get_meta("blocked") as Dictionary).is_empty(), "BC4 fixture: Build opened the sub-grid and its cell is now the blocked Power Plant")
	runner.check(cues == ["click"], "BC4 the Build click sounds, got %s" % [cues])
	main.free()
	return true

# Line 1 the name and muted cost · time, line 2 the reason in warn; 248 wide, 8 above the slab, left-aligned with its cell, clamped 8 from the edge.
func test_cell_card_lines(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin(true, _longest_card().id)
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var ids: Dictionary = _blocked_world(main, 1000)
		_sub_grid(main, ids.builder)
		main.refuse("Needs Power Plant", "")
		await _frames(runner)
		main.hud.now_msec = func() -> int: return 0
		var card: Control = main.get_node("HUD/Hud/CellCard")
		for case: Array in [["usa_power_plant", "Power Plant", "800 · 10 s", ""], ["usa_supply_center", "Supply Depot", "2000 · 10 s", "Needs Power Plant"], ["usa_factory", "Vehicle Factory", "2000 · 15 s", "Needs Supply Depot"], ["usa_defence", "Missile Battery", "1000 · 25 s", "Needs Power Plant"]]:
			var label: String = "%s at %s" % [case[1], size]
			var cell: Button = _cell(main, case[0])
			cell.mouse_entered.emit()
			main.hud.now_msec = func() -> int: return 1000
			main.hud._process(0.0)
			await _frames(runner)
			var lines: Array = card.find_child("Lines", true, false).get_children().filter(func(line: Control) -> bool: return line.visible).map(func(line: Control) -> String: return str(line.name))
			var reason: Label = card.find_child("Reason", true, false)
			var numbers: Label = card.find_child("Numbers", true, false)
			runner.check(lines == (["Head", "Reason"] if not case[3].is_empty() else ["Head"]), "CC2 %s: the lines in order, got %s" % [label, lines])
			runner.check((card.find_child("Name", true, false) as Label).text == case[1] and numbers.text == case[2] and _colour(numbers) == _token("muted"), "CC2 %s: line 1 '%s' then muted '%s', got '%s'" % [label, case[1], case[2], numbers.text])
			if not case[3].is_empty(): runner.check(reason.text == case[3] and _colour(reason) == _token("warn"), "CC2 %s: line 2 '%s' in warn, got '%s'" % [label, case[3], reason.text])
			var at: Rect2 = card.get_global_rect()
			var slab: Rect2 = _rect(main, "HUD/Economy")
			var left: float = clampf(cell.get_global_rect().position.x, 8.0, size.x - 8.0 - 248.0)
			var high: float = 36.0 if case[3].is_empty() else 56.0
			var checklist: Rect2 = _rect(main, "HUD/Playtest/Checklist")
			if Rect2(left, slab.position.y - 8.0 - high, 248.0, high).intersects(checklist): left = checklist.position.x - 8.0 - 248.0
			runner.check(at.size == Vector2(248, high) and is_equal_approx(at.position.x, left) and is_equal_approx(at.end.y, slab.position.y - 8.0), "CC2 %s: 248 x %.0f, x %.0f (its cell's, else 8 left of the checklist), 8 above the slab, got %s" % [label, high, left, at])
			runner.check(view.grow(-8.0).encloses(at), "CC2 %s: 8 inside the view, got %s" % [label, at])
			var panels: Dictionary = BaseScene.hud_panels(main)
			panels["HUD/Hud/RefusalLine"] = _rect(main, "HUD/Hud/RefusalLine")
			for path: String in panels: runner.check(not at.intersects(panels[path]), "CC2 %s: clear of %s %s" % [label, path, panels[path]])
			_clear_of_helpers(runner, main, at, label)
			cell.mouse_exited.emit()
			main.hud._process(0.0)
		await _factory_card_clear(runner, main, ids, view, size)
		port.free()
	overlays._end(saved)
	return true

# Nine queued and shown in full, with the helper's checklist open: the factory's Queue full card stays clear of it.
func _factory_card_clear(runner, main, ids: Dictionary, view: Rect2, size: Vector2i) -> void:
	Fixture.add_completed(main.driver.pump.live(), 1, "usa_supply_center", Vector2i(20, 20))
	BaseScene.publish(main)
	_select(main, [], ids.factory)
	_queue_of(main, ids.factory, 9)
	await _frames(runner)
	var label: String = "the factory's Queue full at %s" % size
	var cell: Button = _cell(main, "usa_tank")
	main.hud.now_msec = func() -> int: return 0
	cell.mouse_entered.emit()
	main.hud.now_msec = func() -> int: return 1000
	main.hud._process(0.0)
	await _frames(runner)
	var card: Control = main.get_node("HUD/Hud/CellCard")
	var at: Rect2 = card.get_global_rect()
	runner.check(card.visible and (card.find_child("Reason", true, false) as Label).text == "Queue full", "CC2 %s: the card shows the reason" % label)
	runner.check(view.grow(-8.0).encloses(at) and is_equal_approx(at.end.y, _rect(main, "HUD/Economy").position.y - 8.0), "CC2 %s: 8 inside the view, 8 above the slab, got %s" % [label, at])
	var panels: Dictionary = BaseScene.hud_panels(main)
	panels["HUD/Hud/RefusalLine"] = _rect(main, "HUD/Hud/RefusalLine")
	for path: String in panels: runner.check(not at.intersects(panels[path]), "CC2 %s: clear of %s %s" % [label, path, panels[path]])
	_clear_of_helpers(runner, main, at, label)
	cell.mouse_exited.emit()
	main.hud._process(0.0)
	var wall := Control.new()
	main.get_node("HUD").add_child(wall)
	wall.position = Vector2(0.0, at.position.y)
	wall.size = Vector2(at.end.x + 8.0, at.size.y)
	main.hud.helpers.append(wall)
	main.hud.now_msec = func() -> int: return 2000
	cell.mouse_entered.emit()
	main.hud.now_msec = func() -> int: return 3000
	main.hud._process(0.0)
	await _frames(runner)
	runner.check(card.visible and card.get_global_rect().position.x >= 8.0, "CC2 %s: a helper with no room left of it never pushes the card off the view, got %s" % [label, card.get_global_rect()])
	main.hud.helpers.erase(wall)
	wall.free()
	cell.mouse_exited.emit()
	main.hud._process(0.0)

static func _clear_of_helpers(runner, main, at: Rect2, label: String) -> void:
	runner.check(main.get_node("HUD/Playtest/Checklist").visible, "CC2 %s: fixture: the checklist is open" % label)
	for path: String in ["HUD/Playtest/Chip", "HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog"]:
		if main.get_node(path).visible: runner.check(not at.intersects(_rect(main, path)), "CC2 %s: clear of %s, card %s, panel %s" % [label, path.get_file(), at, _rect(main, path)])

# 3-10: hovering a cell blocked by a prerequisite frames that prerequisite's cell in sel; nothing else does.
func test_prerequisite_hint(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _blocked_world(main, 1000)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	var hinted = func() -> Array: return _cells(main).filter(func(cell: Control) -> bool: return cell.get_node("Hint").is_visible_in_tree()).map(func(cell: Control) -> String: return str(cell.name))
	for case: Array in [["usa_supply_center", ["Q"]], ["usa_factory", ["W"]], ["usa_defence", ["Q"]], ["usa_power_plant", []], ["usa_barracks", []]]:
		var cell: Button = _cell(main, case[0])
		cell.mouse_entered.emit()
		runner.check(hinted.call() == case[1], "PH1 hovering %s frames %s, got %s" % [case[0], case[1], hinted.call()])
		cell.mouse_exited.emit()
		runner.check(hinted.call().is_empty(), "PH1 leaving %s drops the frame" % case[0])
	var frame: StyleBoxFlat = main.get_node("HUD/Economy/Card/Q/Hint").get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(frame != null and not frame.draw_center and frame.border_color == _token("sel") and frame.border_width_top == 1 and frame.border_width_left == 1, "PH1 the hint is a 1 px sel frame")
	_cell(main, "usa_supply_center").mouse_entered.emit()
	await _frames(runner)
	var q: Button = main.get_node("HUD/Economy/Card/Q")
	runner.check(q.get_node("Hint").get_global_rect().is_equal_approx(q.get_global_rect()), "PH1 the frame covers its cell, got %s" % q.get_node("Hint").get_global_rect())
	_cell(main, "usa_supply_center").mouse_exited.emit()
	_select(main, [], ids.factory)
	await _frames(runner)
	_cell(main, "usa_light_vehicle").mouse_entered.emit()
	runner.check(hinted.call().is_empty(), "PH1 a factory's missing Supply Depot has no cell on its card: no frame, got %s" % [hinted.call()])
	main.free()
	return true

# Counter classes by armour, three representatives each from all rosters (plan Design "Counter line").
const COUNTER_CLASSES := {"infantry": ["usa_rifle_infantry", "china_rifle_infantry", "frc_rifle_infantry"], "light vehicles": ["usa_light_vehicle", "china_tank", "frc_light_vehicle"], "tanks": ["usa_tank", "china_light_vehicle", "frc_tank"]}
const INTENDED := HudModel.COUNTER_INTENDED
const COUNTER_VERBS: Array[String] = ["Beats", "Good against", "Weak against"]
const SPIN := " at full spin"

# combat.gd's sustained rate per tick: a clip's shots over its delays and reload, a ramp weapon at its last percent, FRC at its base tier, scaled by the target's armour.
static func _counter_rate(attacker: String, target: String) -> float:
	var row: Dictionary = Registry.kind(attacker)
	if row.get("weapon", "").is_empty(): return 0.0
	var weapon: Dictionary = Shared.WEAPONS[row.get("weapon_tiers", [row.weapon])[0]]
	var damage: float = weapon.damage * (weapon.ramp.percent[-1] / 100.0 if weapon.has("ramp") else 1.0)
	var rate: float = weapon.clip_size * damage / ((weapon.clip_size - 1) * weapon.delay_ticks + weapon.reload_ticks) if weapon.clip_size > 0 else damage / weapon.delay_ticks
	return rate * Shared.ARMOR[Registry.kind(target).armor][weapon.damage_type] / 100.0

# Equal credits on both sides: the time the attackers need to kill the targets (a squad's cost split over its quantity).
static func _counter_time(attacker: String, target: String) -> float:
	var rate: float = _counter_rate(attacker, target)
	if rate == 0.0: return INF
	return Registry.kind(target).max_hp * _unit_cost(attacker) / (rate * _unit_cost(target))

static func _unit_cost(kind: String) -> float:
	return Registry.kind(kind).cost / float(Registry.kind(kind).get("quantity", 1))

# [verb, rank]: Beats when every representative falls in at most half the time it needs against us, Good against when we win each, Weak against when each needs at most half ours; a lower rank is the stronger claim.
static func _counter_verdict(kind: String, against: String) -> Array:
	var ratios: Array = COUNTER_CLASSES[against].filter(func(other: String) -> bool: return other != kind).map(func(other: String) -> float: return _counter_time(kind, other) / _counter_time(other, kind))
	if ratios.max() <= 0.5: return ["Beats", ratios.max()]
	if ratios.max() < 1.0: return ["Good against", 1.0 + ratios.max()]
	if ratios.min() >= 2.0: return ["Weak against", 1.0 / ratios.min()]
	return ["", INF]

# The line the rule prints: the strongest true intended Beats or Good, then the strongest true intended Weak; none for unarmed kinds.
static func _counter_expected(kind: String) -> String:
	if Registry.kind(kind).get("weapon", "").is_empty() or not INTENDED.has(kind): return ""
	var claims: Array[String] = []
	for side: int in 2:
		var best: Array = ["", INF]
		for against: String in INTENDED[kind][side]:
			var verdict: Array = _counter_verdict(kind, against)
			# A strong claim measured at the ramp's last percent names it; a weak one holds at base damage too.
			if not verdict[0].is_empty() and (verdict[0] == "Weak against") == (side == 1) and verdict[1] < best[1]: best = ["%s %s%s" % [verdict[0], against, SPIN if side == 0 and _ramps(kind) else ""], verdict[1]]
		if not best[0].is_empty(): claims.append(best[0])
	return " · ".join(claims)

static func _ramps(kind: String) -> bool:
	var row: Dictionary = Registry.kind(kind)
	return Shared.WEAPONS[row.get("weapon_tiers", [row.weapon])[0]].has("ramp")

# The claims of a line the damage numbers refute.
static func _refuted(kind: String, line: String) -> Array:
	return Array(line.split(" · ", false)).filter(func(claim: String) -> bool: return not _claim_holds(kind, claim))

static func _claim_holds(kind: String, claim: String) -> bool:
	for verb: String in COUNTER_VERBS:
		var against: String = claim.trim_suffix(SPIN).trim_prefix(verb + " ")
		if against == claim or not COUNTER_CLASSES.has(against): continue
		var verdict: String = _counter_verdict(kind, against)[0]
		return verdict == verb or (verb == "Good against" and verdict == "Beats")
	return false

# The rule's verdicts the Zero Hour roles do not intend, and intended claims the numbers refute: the balance gaps for playtests (one STATUS finding).
static func _counter_gaps(kind: String) -> Array[String]:
	var gaps: Array[String] = []
	for against: String in COUNTER_CLASSES:
		var verb: String = _counter_verdict(kind, against)[0]
		var side: int = 1 if verb == "Weak against" else 0
		if not verb.is_empty() and not INTENDED[kind][side].has(against): gaps.append("true, not intended: %s %s" % [verb, against])
		for intended: int in 2:
			if INTENDED[kind][intended].has(against) and (verb.is_empty() or side != intended): gaps.append("intended, refuted: %s %s" % ["Weak against" if intended == 1 else "Strong against", against])
	return gaps

func test_counter_lines_match_damage(runner) -> bool:
	for kind: String in Registry.units():
		var line: String = HudModel.COUNTER_LINES.get(kind, "")
		var armed: bool = not Registry.kind(kind).get("weapon", "").is_empty()
		runner.check(not armed or INTENDED.has(kind), "CL1 %s has an intended row from its Zero Hour role" % kind)
		runner.check(line == _counter_expected(kind), "CL1 %s reads the rule's '%s', got '%s'" % [kind, _counter_expected(kind), line])
		runner.check(_refuted(kind, line).is_empty(), "CL1 every claim on %s's line holds, refuted %s" % [kind, _refuted(kind, line)])
		if armed and INTENDED.has(kind): print("CL1 %s '%s' gaps %s" % [kind, line, _counter_gaps(kind)])
	runner.check(not HudModel.COUNTER_LINES.keys().any(func(kind: String) -> bool: return Registry.is_builder(kind) or not Registry.collects(kind).is_empty()), "CL1 no line for builders and collectors")
	runner.check(_refuted("usa_rifle_infantry", "Weak against tanks") == ["Weak against tanks"], "CL1 the same check refutes a false fixture: Rifleman 'Weak against tanks'")
	runner.check(_refuted("usa_rocket_infantry", "Beats tanks · Weak against infantry").is_empty() and _refuted("usa_tank", "Good against light vehicles").is_empty(), "CL1 the check holds true claims, Good under a Beats verdict too")
	runner.check(HudModel.COUNTER_LINES.get("china_tank", "").begins_with("Good against infantry at full spin") and _counter_time("china_tank", "usa_rifle_infantry") * 3.0 > _counter_time("usa_rifle_infantry", "china_tank"), "CL1 the Rotary Gun Tank is good against infantry at its rotary gun's 300 % ramp; at base damage the Rifleman would win")
	await _no_counter_in_panels(runner)
	return true

# 3-12: the counter line sits on the cell card only, never in the one-unit or inspected-enemy panel.
func _no_counter_in_panels(runner) -> void:
	var main = await SkirmishTests.new()._setup(runner)
	var sim = Fixture.make_world(50000)
	sim.add_player(2, 1000)
	var own: int = sim.spawn(1, Vector2(8.5, 8.5), "usa_tank")
	var enemy: int = sim.spawn(2, Vector2(20.5, 20.5), "china_light_vehicle")
	main.driver.adopt(sim)
	for case: Array in [["the one-unit panel", [own], -1, "Battle Tank"], ["the inspected enemy's panel", [], enemy, "Medium Tank"]]:
		_pick(main, case[1], -1, case[2])
		await _frames(runner)
		var text: String = BaseScene.hud_text(main)
		runner.check(text.contains(case[3]) and not COUNTER_VERBS.any(func(verb: String) -> bool: return text.contains(verb)), "CL1 %s shows %s with no counter line, got '%s'" % [case[0], case[3], text.replace("\n", " | ")])
	main.free()

# HUD headless layout: a unit cell's card carries its counter line in text, line 2 when ready, line 3 under a reason, at every HUD_SIZES size;
# the Rotary Gun Tank's line, wider than the card, breaks between its claims.
func test_counter_line_on_the_cell_card(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await OverlayTests.new()._scene(runner, Skirmish, port)
		var ids: Dictionary = _blocked_world(main, 1000)
		var sim = main.driver.pump.live()
		Fixture.add_completed(sim, 1, "usa_supply_center", Vector2i(20, 20))
		Fixture.add_completed(sim, 1, "china_supply_center", Vector2i(26, 8))
		var china: int = Fixture.add_completed(sim, 1, "china_factory", Vector2i(26, 14))
		BaseScene.publish(main)
		var card: Control = main.get_node("HUD/Hud/CellCard")
		var rotary := "Good against infantry at full spin\nWeak against tanks"
		for case: Array in [["usa_tank", ids.factory, 1000, ["Head", "Counter"], "Beats light vehicles"], ["usa_tank", ids.factory, 500, ["Head", "Reason", "Counter"], "Beats light vehicles"], ["usa_light_vehicle", ids.factory, 1000, ["Head", "Counter"], "Weak against tanks"], ["china_tank", china, 1000, ["Head", "Counter"], rotary], ["china_tank", china, 500, ["Head", "Reason", "Counter"], rotary]]:
			var label: String = "%s at %d credits at %s" % [case[0], case[2], size]
			_select(main, [], case[1])
			_set_credits(main, case[2])
			await _frames(runner)
			var cell: Button = _cell(main, case[0])
			main.hud.now_msec = func() -> int: return 0
			cell.mouse_entered.emit()
			main.hud.now_msec = func() -> int: return 1000
			main.hud._process(0.0)
			await _frames(runner)
			var lines: Array = card.find_child("Lines", true, false).get_children().filter(func(line: Control) -> bool: return line.visible).map(func(line: Control) -> String: return str(line.name))
			var counter: Label = card.find_child("Counter", true, false)
			var words: String = case[4]
			runner.check(lines == case[3] and counter.is_visible_in_tree() and counter.text == words and _colour(counter) == _token("text"), "CL2 %s: lines %s, the counter line '%s' in text, got %s '%s'" % [label, case[3], words, lines, counter.text])
			var at: Rect2 = card.get_global_rect()
			var high: float = 16.0 + 20.0 * (case[3].size() + words.count("\n"))
			runner.check(at.size == Vector2(248, high) and is_equal_approx(at.end.y, _rect(main, "HUD/Economy").position.y - 8.0) and view.grow(-8.0).encloses(at), "CL2 %s: 248 x %.0f, 8 above the slab, 8 inside the view, got %s" % [label, high, at])
			var panels: Dictionary = BaseScene.hud_panels(main)
			panels["HUD/Hud/RefusalLine"] = _rect(main, "HUD/Hud/RefusalLine")
			for path: String in panels: runner.check(not at.intersects(panels[path]), "CL2 %s: clear of %s %s" % [label, path, panels[path]])
			counter.text = "unchanged"
			main._refresh()
			runner.check(counter.text == "unchanged", "CL2 %s: a refresh with the same words and width lays the counter line out once" % label)
			counter.text = words
			cell.mouse_exited.emit()
			main.hud._process(0.0)
		var counter: Label = card.find_child("Counter", true, false)
		for kind: String in HudModel.COUNTER_LINES:
			var claims: Array = Array(HudModel.COUNTER_LINES[kind].split(" · ")).map(func(claim: String) -> float: return counter.get_theme_font("font").get_string_size(claim, HORIZONTAL_ALIGNMENT_LEFT, -1, counter.get_theme_font_size("font_size")).x)
			runner.check(claims.max() <= 248.0 - 16.0, "CL2 each claim of %s fits the card's 232 px, widest %.1f at %s" % [kind, claims.max(), size])
		port.free()
	return true

# The button draws its name centred between its top and bottom content margins.
static func _name_centre(button: Button) -> float:
	var style: StyleBox = button.get_theme_stylebox("normal")
	var rect: Rect2 = button.get_global_rect()
	return rect.position.y + (style.get_margin(SIDE_TOP) + rect.size.y - style.get_margin(SIDE_BOTTOM)) / 2.0

static func _chip_ends_inside(runner, cell: Button, what: String) -> void:
	var box: Rect2 = cell.get_global_rect()
	var chip: Rect2 = (cell.get_node("Chip") as Control).get_global_rect()
	runner.check(chip.size.x >= 18.0 and is_equal_approx(chip.size.y, 18.0) and is_equal_approx(chip.end.x, box.end.x - 8.0) and chip.position.x >= box.position.x + 8.0, "SL7 %s: the chip ends 8 inside the right edge and stays in the cell, got %s in %s" % [what, chip, box])

func test_right_labels_on_the_name_line(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, false)
	_sub_grid(main, ids.builder)
	await _frames(runner)
	# hud-v5-layout "Item cell": padding 4 8; line 1, 20 high, the cost left and the 18 px chip right; the name 4 below it.
	var tower: Button = _cell(main, "china_defence")
	var cell: Rect2 = tower.get_global_rect()
	var cost: Rect2 = (tower.get_node("Cost") as Control).get_global_rect()
	var chip: Rect2 = (tower.get_node("Chip") as Control).get_global_rect()
	var words: Rect2 = (tower.get_node("Name") as Control).get_global_rect()
	runner.check(is_equal_approx(cost.position.x, cell.position.x + 8.0) and is_equal_approx(cost.get_center().y, cell.position.y + 14.0), "SL7 the cost starts 8 in and centres on line 1 (y %.1f), got %s" % [cell.position.y + 14.0, cost])
	runner.check(chip.size == Vector2(18, 18) and is_equal_approx(chip.end.x, cell.end.x - 8.0) and is_equal_approx(chip.get_center().y, cell.position.y + 14.0), "SL7 the 18 px chip ends 8 inside the right edge on line 1, got %s in %s" % [chip, cell])
	runner.check(is_equal_approx(words.position.y, cell.position.y + 28.0) and is_equal_approx(words.position.x, cell.position.x + 8.0) and words.size.x == 84.0, "SL7 the name 84 wide, 4 under line 1, got %s" % words)
	var back_cell: Button = main.get_node("HUD/Economy/Card/V")
	var back: Rect2 = (back_cell.get_node("Name") as Control).get_global_rect()
	runner.check(is_equal_approx(back.get_center().y, back_cell.get_global_rect().position.y + 42.0) and (back_cell.get_node("Name") as Label).get_theme_font_size("font_size") == 13, "SL7 a command's 13 px name centres in its 28 px line, got %s" % back)
	runner.check(back_cell.tooltip_text == "Back · V or Esc" and tower.tooltip_text.is_empty(), "SL7 Back's tooltip names Esc beside its V, other cells none, got '%s' '%s'" % [back_cell.tooltip_text, tower.tooltip_text])
	_chip_ends_inside(runner, main.get_node("HUD/Economy/Card/W"), "the widest letter W")
	var platform: Callable = HudModel.layout_label
	HudModel.layout_label = func(_physical: Key) -> Key: return KEY_APOSTROPHE
	main.hud.reset()
	main._refresh()
	await _frames(runner)
	_chip_ends_inside(runner, tower, "a layout's multi-character label")
	HudModel.layout_label = platform
	main.hud.reset()
	main._refresh()
	await _frames(runner)
	chip = (tower.get_node("Chip") as Control).get_global_rect()
	runner.check(chip.size == Vector2(18, 18) and is_equal_approx(chip.end.x, cell.end.x - 8.0), "SL7 back to a one-letter label the chip shrinks to 18 px at its right edge, got %s" % chip)
	_select(main, [], ids.factory)
	_queue_of(main, ids.factory, 3)
	await _frames(runner)
	var tile: Button = _tiles(main)[0] if not _tiles(main).is_empty() else null
	runner.check(tile != null, "SL7 the factory shows its NOW tile")
	if tile == null:
		main.free()
		return true
	for look: String in ["hover", "pressed", "hover_pressed"]:
		var style: StyleBoxFlat = tile.get_theme_stylebox(look) as StyleBoxFlat
		runner.check(style != null and style.bg_color == _token("panel2") and style.border_color == _token("muted") and style.border_width_left == 1 and style.border_width_top == 1 and style.border_width_right == 1 and style.border_width_bottom == 1, "SL7 a queue tile's %s look: panel2 with a 1 px muted inset" % look)
	var mark: Label = tile.get_node("Chip")
	var flush: Rect2 = (tile.get_node("Track") as Control).get_global_rect()
	tile.mouse_entered.emit()
	await _frames(runner)
	var track: Rect2 = (tile.get_node("Track") as Control).get_global_rect()
	runner.check(tile.get_global_rect().grow(-1.0).encloses(track) and is_equal_approx(track.size.y, 4.0) and is_equal_approx(track.end.y, tile.get_global_rect().end.y - 1.0), "SL7 the hovered NOW tile's 4 px track sits inside the 1 px frame, got %s in %s" % [track, tile.get_global_rect()])
	runner.check(mark.text == "\u00d7" and _colour(mark) == _token("text") and tile.tooltip_text == "Cancel · refunds 800", "SL7 the hovered tile's chip turns into × in text, its tooltip Cancel · refunds 800, got '%s' '%s'" % [mark.text, tile.tooltip_text])
	tile.mouse_exited.emit()
	await _frames(runner)
	runner.check((tile.get_node("Track") as Control).get_global_rect() == flush and mark.text == HudModel.key_label(KEY_W) and _colour(mark) == _token("muted"), "SL7 off the tile: the track full width again and the chip back to its muted W, got %s '%s'" % [(tile.get_node("Track") as Control).get_global_rect(), mark.text])
	main.free()
	return true

func test_key_labels(runner) -> bool:
	var headless: Array = HudModel.ORDER_KEYS.values().map(func(code: Key) -> String: return HudModel.key_label(code))
	runner.check(headless == ["A", "S", "F"], "KL1 headless labels are the physical keys, got %s" % [headless])
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _slab_world(runner, main, true)
	_select(main, [ids.car])
	var before: Array = _card(main)
	HudModel.layout_label = func(physical: Key) -> Key: return {KEY_A: KEY_Q, KEY_F: KEY_G}.get(physical, physical)
	main.hud.reset()
	_select(main, [ids.car])
	var texts: Array = _card(main)
	HudModel.layout_label = HudModel._platform_label
	main.free()
	runner.check(before == ["A Attack Move", "S Stop", "", "F Unload", "", "", "", ""] and texts == ["Q Attack Move", "S Stop", "", "G Unload", "", "", "", ""], "KL1 the chips print the layout's labels after a reset, got %s then %s" % [before, texts])
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
	return [["one unit", [ids.tank], -1, -1, 62, 0], ["own building", [], ids.depot, -1, 152, 0], ["own offline defence", [], ids.defence, -1, 62, 1],
		["power plant", [], ids.plant, -1, 86, 0], ["factory", [], ids.factory, -1, 152, 0], ["two kinds after the factory", [ids.tank, ids.collector], -1, -1, 98, 0],["own site", [], ids.site, -1, 86, 0], ["own paused site", [], ids.paused, -1, 86, 0],
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
		var refusal := Rect2((408.0 + size.x - 432.0) / 2.0 - 208.0, size.y - 36.0, 416.0, 28.0)
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

func test_owner_colours_contrast(runner) -> bool:
	var bg: Color = _token("bg")
	for owner in range(1, 9):
		var ratio: float = _contrast(Palette.owner_colors(owner)[0], bg)
		runner.check(ratio >= 3.0, "PA1 owner %d against bg is %.2f:1, at least 3:1" % [owner, ratio])
	return true

# map-art-shapes.md P2.4 bar: the side band carries the outline, at least 3:1 against each ground.
func test_side_band_contrast(runner) -> bool:
	for ground: Color in [Palette.SAND, Palette.ground(0).ground]:
		for side: Color in [Palette.OWNER_SIDE, Palette.OWNER_SIDE_DARK]:
			var ratio: float = _contrast(side, ground)
			runner.check(ratio >= 3.0, "PA3 side %s against ground %s is %.2f:1, at least 3:1" % [side.to_html(false), ground.to_html(false), ratio])
	return true

func test_panel_edge_is_the_body_colour(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _panel_world(main)
	for bright in [false, true]:
		main._pause.neon_changed.emit(bright)
		await runner.process_frame
		for case: Array in [[[ids.tank], -1, 1], [[], ids.enemy, 2]]:
			_pick(main, case[0], -1, case[1])
			var body: Color = Palette.owner_colors(case[2], bright)[0]
			runner.check(main.hud.panel_edge() == body and main._view._batch.colors.has(body), "PA2 owner %d edge is the colour the batch draws (Neon %s), edge %s, body %s" % [case[2], bright, main.hud.panel_edge(), body])
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

# A seventh kind needs the six-cell cap with `+N kinds` built first (hud-v5-layout.md, "Kind rows").
func test_six_kinds_at_most(runner) -> bool:
	var factions: Array = Registry.Factions.FACTIONS.keys()
	factions.sort()
	runner.check(factions == ["china", "frc", "usa"], "KC1 the definitions hold usa, china and frc, got %s" % [factions])
	for faction: String in factions:
		var count: int = _fielded_units(faction).size()
		runner.check(count > 0, "KC1 %s fields no selectable unit kinds; the roster read is broken" % faction)
		runner.check(count <= 6, "KC1 %s fields %d selectable unit kinds; past six, build the kind-row cap (`+N kinds`, docs/reference/hud-v5-layout.md \"Kind rows\") first" % [faction, count])
	return true

# The start unit, then every unit its builds and the start building produce or spawn.
static func _fielded_units(faction: String) -> Dictionary:
	var row: Dictionary = Registry.faction(faction)
	var kinds: Array = [row.get("start_unit", "")]
	for building: String in Registry.kind(kinds[0]).get("builds", []) + [row.get("start_building", "")]:
		kinds.append_array(Registry.kind(building).get("produces", []) + Registry.kind(building).get("spawns_on_complete", []))
	var found: Dictionary = {}
	for kind: String in kinds:
		if Registry.kind(kind).has("class"): found[kind] = true
	return found

func test_roster_fits(runner) -> bool:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var refusal := Rect2((408.0 + size.x - 432.0) / 2.0 - 208.0, size.y - 36.0, 416.0, 28.0)
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

func test_rows_let_go_when_the_pointer_leaves_the_window(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _rows_world(main, [["usa_tank", 1], ["usa_rifle_infantry", 2]])
	await _frames(runner)
	port.notify_mouse_entered()
	_move(port, _row(main, "usa_tank").get_global_rect().get_center())
	await _frames(runner)
	main.driver.pump.live().remove_object(ids.usa_tank[0])
	BaseScene.publish(main)
	await _frames(runner)
	runner.check(_row(main, "usa_tank") != null, "KR4b fixture: the dead tank's row holds under the pointer")
	# As a real window leave: the rows get `mouse_exited`, the mouse position stays inside the panel.
	port.notify_mouse_exited()
	await _frames(runner)
	runner.check(_row(main, "usa_tank") == null and _row_names(main) == ["Row_usa_rifle_infantry"], "KR4b the pointer leaving the window lets the rows go, got %s" % [_row_names(main)])
	_end_port(scene)
	return true

# Gate C (user, 2026-11-20): only a shrink holds the rows; a fresh drag released over the panel replaces them.
func test_fresh_selection_over_the_panel_drops_the_hold(runner) -> bool:
	var scene: Array = await _port_scene(runner)
	var port: SubViewport = scene[2]
	var main = scene[3]
	var ids: Dictionary = _rows_world(main, [["usa_tank", 3], ["usa_rifle_infantry", 2], ["usa_builder", 1]])
	var army: Array[int] = ids.usa_tank + ids.usa_rifle_infantry
	_pick(main, army, -1, -1)
	await _frames(runner)
	# On the header, not a row: a rebuilt row under the pointer would end the hover itself.
	_move(port, _many(main, "Header").get_global_rect().get_center())
	await _frames(runner)
	main.orders.selected_ids.assign(ids.usa_builder)
	main._reshow()
	await _frames(runner)
	runner.check(not _many(main, "Header").is_visible_in_tree() and _panel_texts(main).Name == "Bulldozer", "KR4c a drag from the army to one builder released over the panel shows the builder's panel at once, got %s" % [_panel_texts(main)])
	main.orders.selected_ids.assign(ids.usa_tank + ids.usa_rifle_infantry)
	main._reshow()
	await _frames(runner)
	runner.check(_row_names(main) == ["Row_usa_tank", "Row_usa_rifle_infantry"], "KR4c a fresh army over the panel shows only its own rows, got %s" % [_row_names(main)])
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
	var depot: Array = [{"id": 40, "owner": 1, "kind": "china_supply_center", "completed": true, "builder_id": null}]
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "idle", true)], [5], full, depot) == "WAITING AT PILE", "CL1 collecting and idle while a pile holds boxes (busy-dock retry) reads WAITING AT PILE")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "china_collector", "idle", true)], [5], empty, depot) == "IDLE", "CL1 collecting and idle with no pile holding boxes reads IDLE")
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
	runner.check(HudModel.collector_labels(enemy_view, enemy_ids, 1, {}).is_empty(), "CL1 collector_labels skips another owner's collector")
	runner.check(enemy == "" and (hud.get_node("SelectionPanel").find_child("Name", true, false) as Label).text == "Supply Truck", "CL1 an inspected enemy collector shows no label, got '%s'" % enemy)
	hud.get_parent().free()
	return true

func test_no_drop_off_label(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var full: Array = [{"id": 30, "boxes": 4}]
	var empty: Array = [{"id": 30, "boxes": 0}]
	var idle_truck: Array = [_unit_row(5, 1, "usa_collector", "idle", true)]
	var depot: Dictionary = {"id": 40, "owner": 1, "kind": "usa_supply_center", "completed": true, "builder_id": null}
	var depot_site: Dictionary = depot.merged({"completed": false, "builder_id": 6, "work": 0}, true)
	var enemy_depot: Dictionary = depot.merged({"id": 41, "owner": 2}, true)
	var barracks: Dictionary = {"id": 42, "owner": 1, "kind": "usa_barracks", "completed": true, "builder_id": null}
	runner.check(await _label_on(runner, hud, idle_truck, [5], full, [barracks]) == "NO SUPPLY DEPOT", "CL5 collecting and idle, owner has no finished drop-off, a pile holds boxes: NO SUPPLY DEPOT wins over WAITING AT PILE")
	var right: Label = hud.get_node("SelectionPanel").find_child("RightLabel", true, false)
	runner.check(not right.has_theme_color_override("font_color"), "CL5 NO SUPPLY DEPOT is muted like IDLE, no warn tint")
	runner.check(await _label_on(runner, hud, idle_truck, [5], empty) == "NO SUPPLY DEPOT", "CL5 collecting and idle, no drop-off and no pile holding boxes reads NO SUPPLY DEPOT")
	runner.check(await _label_on(runner, hud, idle_truck, [5], full, [depot_site]) == "NO SUPPLY DEPOT", "CL5 an unfinished own drop-off site is no drop-off")
	runner.check(await _label_on(runner, hud, idle_truck, [5], full, [enemy_depot]) == "NO SUPPLY DEPOT", "CL5 another owner's finished drop-off is no drop-off")
	runner.check(await _label_on(runner, hud, idle_truck, [5], full, [depot]) == "WAITING AT PILE", "CL5 with a finished own drop-off the busy-dock retry still reads WAITING AT PILE")
	runner.check(await _label_on(runner, hud, idle_truck, [5], empty, [depot]) == "IDLE", "CL5 with a finished own drop-off and no boxes left it reads IDLE")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "usa_collector", "flying_source", true)], [5], full) == "TO PILE", "CL5 only the idle phase reads NO SUPPLY DEPOT")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "usa_collector", "idle")], [5], full) == "IDLE", "CL5 a collector not collecting reads IDLE without a drop-off")
	runner.check(await _label_on(runner, hud, [_unit_row(5, 1, "frc_builder", "idle", true)], [5], full, [], "frc") == "NO SUPPLY CACHE", "CL5 FRC reads NO SUPPLY CACHE")
	var trucks: Array = [_unit_row(20, 1, "usa_collector", "idle", true), _unit_row(21, 1, "usa_collector", "idle", true), _unit_row(22, 1, "usa_collector", "loading", true), _unit_row(23, 1, "usa_tank")]
	await _label_on(runner, hud, trucks, [20, 21, 22, 23], full)
	var header: String = (hud.get_node("SelectionPanel/Box/Many/Header") as Label).text
	runner.check(header == "4 selected · 2 kinds · 2 idle collectors", "CL5 the header counts NO SUPPLY DEPOT rows as idle collectors while a pile holds boxes, got '%s'" % header)
	hud.get_parent().free()
	return true

func test_collector_labels_in_a_mixed_army(runner) -> bool:
	var states: Array = [["loading", true, "idle", {}, "LOADING"], ["flying_depot", true, "idle", {}, "TO SUPPLY DEPOT"], ["idle", true, "idle", {}, "WAITING AT PILE"], ["seeking", true, "idle", {}, "UNLOADING"], ["idle", false, "moving", {}, "MOVING"], ["idle", false, "idle", {}, "BUILDING"], ["idle", false, "idle", {}, "IDLE"], ["idle", false, "contained", {"container_id": 7}, ""]]
	var units: Array = []
	var buildings: Array = []
	var previous: Dictionary = {}
	var expected: Dictionary = {}
	for n in 32:
		var state: Array = states[n % states.size()]
		var id: int = 100 + n
		units.append(_unit_row(id, 1, "china_collector", state[0], state[1], state[2], state[3]))
		if state[0] == "seeking": previous[id] = state[4]
		if state[4] == "BUILDING": buildings.append({"id": 500 + n, "owner": 1, "kind": "china_barracks", "completed": false, "builder_id": id})
		expected[id] = state[4]
	for n in 25: buildings.append({"id": 600 + n, "owner": 1, "kind": "china_barracks", "completed": true, "builder_id": 100 + n})
	buildings.append({"id": 625, "owner": 1, "kind": "china_supply_center", "completed": true, "builder_id": null})
	for n in 86: units.append(_unit_row(200 + n, 1, "china_tank"))
	units.append(_unit_row(300, 2, "china_collector", "loading", true))
	units.append(_unit_row(301, 2, "china_tank"))
	var view: Dictionary = _strip_view(0, 0, 0, "usa")
	view.units = ViewRows.from_units(units)
	view.sources = [{"id": 30, "boxes": 0}, {"id": 31, "boxes": 4}]
	view.buildings = buildings
	var ids: Array[int] = []
	ids.assign(units.map(func(unit: Dictionary) -> int: return unit.id))
	var labels: Dictionary = HudModel.collector_labels(view, ids, 1, previous)
	runner.check(ids.size() == 120 and buildings.size() == 30 and labels == expected, "CL4 a mixed 120-unit selection with 32 collectors and 30 buildings gives each own collector its label, got %s" % labels)
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

# F38: a second refresh of the same state does no layout work (nodes, order, anchors, no resize or re-sort).
func test_unchanged_refresh_keeps_layout(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = _queue_world(main)
	_queue_kinds(main, ids.factory, [MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY, MEDIUM, ROTARY, MEDIUM, ROTARY])
	await _frames(runner)
	var watched: Array = ["HUD/Hud/SelectionPanel", QUEUE_PATH, "HUD/Hud/TopStrip", "HUD/Economy", "HUD/Economy/Card"].map(func(path: String) -> Control: return main.get_node(path))
	var layout: Callable = func() -> Array:
		var tiles: Array = _tile_row(main).get_children()
		return [tiles.map(func(tile: Control) -> Array: return [tile.get_instance_id(), tile.visible, tile.anchor_left, tile.anchor_right, tile.position, tile.size, tile.get_meta("ids", [])]), watched.map(func(node: Control) -> Array: return [node.get_global_rect(), node.get_children().map(func(child: Node) -> int: return child.get_instance_id())])]
	var before: Array = layout.call()
	var churn: Array = [0]
	for node: Control in watched:
		node.resized.connect(func() -> void: churn[0] += 1)
		if node is Container: (node as Container).sort_children.connect(func() -> void: churn[0] += 1)
	main._reshow()
	main._reshow()
	await _frames(runner)
	runner.check(_tiles(main).size() == 3 and _more(main).is_visible_in_tree(), "UL1 fixture: nine queued show three tiles and +N more")
	runner.check(layout.call() == before, "UL1 two unchanged refreshes keep the tile nodes, order, anchors and rects")
	runner.check(churn[0] == 0, "UL1 two unchanged refreshes resize and re-sort nothing, got %d signals" % churn[0])
	var advanced: Dictionary = main.driver.current().view.duplicate(true)
	HudModel.building(advanced, ids.factory).queue[0].work = 252000
	main._show(advanced)
	await _frames(runner)
	var bar: ColorRect = (_tiles(main)[0] as Node).get_node("Track/Bar")
	runner.check(is_equal_approx(bar.anchor_right, 0.84), "UL1 fixture: the advanced state moves the NOW bar to 84 %%, got %.2f" % bar.anchor_right)
	runner.check(layout.call() == before and churn[0] == 0, "UL1 a refresh with production advanced keeps the tile nodes, order and rects and resizes nothing, got %d signals" % churn[0])
	main.free()
	return true

static func _refusal_line(main) -> Control:
	return main.get_node_or_null("HUD/Hud/RefusalLine")

static func _line_shown(main) -> bool:
	var line: Control = _refusal_line(main)
	return line != null and line.is_visible_in_tree()

static func _line_text(main) -> String:
	var line: Control = _refusal_line(main)
	return (line.find_child("Text", true, false) as Label).text if line != null and _line_shown(main) else ""

func test_refusal_line_place(runner) -> bool:
	var overlays = OverlayTests.new()
	var skirmish = SkirmishTests.new()
	var saved: String = overlays._begin()
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var main = await overlays._scene(runner, Skirmish, port)
		var at: String = " at %s" % size
		main._submit(skirmish._off_map_move(skirmish._arena(main)))
		BaseScene.tick(main)
		await _frames(runner)
		var line: Control = _refusal_line(main)
		runner.check(_line_shown(main), "RN1 a refused move shows the line%s" % at)
		if line == null:
			port.free()
			break
		var rect: Rect2 = line.get_global_rect()
		var centre: float = (408.0 + size.x - 432.0) / 2.0
		runner.check(absf(rect.get_center().x - centre) <= 1.0 and absf(rect.end.y - (size.y - 8.0)) <= 0.5 and absf(rect.size.y - 28.0) <= 0.5, "RN1 spot B (gate B, user 2026-11-20): centred between the panel and the slab at %.0f, bottom H-8, 28 high%s, got %s" % [centre, at, rect])
		var square: ColorRect = line.find_child("Square", true, false)
		var text: Label = line.find_child("Text", true, false)
		runner.check(square != null and text != null and square.color == _token("warn") and square.size == Vector2(8, 8) and _colour(text) == _token("warn") and text.get_theme_font_size("font_size") == 13, "RN1 an 8x8 warn square and 13 px warn text%s" % at)
		if square == null or text == null:
			port.free()
			break
		runner.check(text.text == "Target outside map", "RN1 the raw words%s, got '%s'" % [at, text.text])
		var square_rect: Rect2 = square.get_global_rect()
		var text_rect: Rect2 = text.get_global_rect()
		runner.check(absf(square_rect.position.x - rect.position.x - 8.0) <= 0.5 and absf(text_rect.position.x - square_rect.end.x - 8.0) <= 0.5 and absf(rect.end.x - text_rect.end.x - 8.0) <= 0.5, "RN1 padding 8, gap 8, the width hugs%s, got %s %s %s" % [at, rect, square_rect, text_rect])
		var panels: Dictionary = BaseScene.hud_panels(main)
		runner.check(panels.has("HUD/Hud/RefusalLine") and panels.has("HUD/Hud/SelectionPanel"), "RN1 the no-overlap list holds the line and the selection panel%s, got %s" % [at, panels.keys()])
		for other: String in panels:
			if other != "HUD/Hud/RefusalLine" and panels.has("HUD/Hud/RefusalLine"): runner.check(not panels["HUD/Hud/RefusalLine"].intersects(panels[other]), "RN1 the line clears %s%s" % [other, at])
		var catches: Array = [line] + line.find_children("*", "Control", true, false)
		runner.check(catches.all(func(part: Control) -> bool: return part.mouse_filter == Control.MOUSE_FILTER_IGNORE), "RN1 the line never catches the mouse%s" % at)
		main.refuse("Footprint covers ground unit or destination", "")
		await _frames(runner)
		rect = line.get_global_rect()
		var tallest := Rect2(0, size.y - 158.0, 408.0, 158.0)
		runner.check(_line_text(main) == "Footprint covers ground unit or destination" and rect.size.x <= 416.0 and view.encloses(rect) and not rect.intersects(tallest), "RN1 the longest command text fits 416, inside the view and clear of the tallest panel%s, got %s" % [at, rect])
		var slab: Control = main.get_node("HUD/Economy")
		runner.check(slab.is_visible_in_tree() and not rect.intersects(slab.get_global_rect()), "RN1 the longest line clears the slab%s, slab %s" % [at, slab.get_global_rect()])
		runner.check(Rect2(408.0, 0.0, size.x - 432.0 - 408.0, size.y).encloses(rect) and absf(rect.get_center().x - centre) <= 1.0, "RN1 the longest line stays between the panel's 408 and the slab's W-432%s, got %s" % [at, rect])
		port.free()
	overlays._end(saved)
	return true

func test_refusal_timer_and_replace(runner) -> bool:
	var hud: Hud = _bare_hud(runner)
	var clock: Array[int] = [10000]
	hud.now_msec = func() -> int: return clock[0]
	var line: Control = hud.get_node("RefusalLine")
	var text: Label = line.find_child("Text", true, false)
	hud.refuse("A")
	for step: Array in [[12999, true], [13000, false]]:
		clock[0] = step[0]
		hud._process(0.0)
		runner.check(line.visible == step[1] and hud.refusal == "A", "RN2 refused at 10000: shown %s at %d, got %s" % [step[1], step[0], line.visible])
	clock[0] = 20000
	hud.refuse("A")
	clock[0] = 22000
	hud.refuse("B")
	for step: Array in [[24999, true], [25000, false]]:
		clock[0] = step[0]
		hud._process(0.0)
		runner.check(line.visible == step[1] and text.text == "B" and hud.refusal == "B", "RN2 B replaced A at 22000: shown %s at %d, got %s '%s'" % [step[1], step[0], line.visible, text.text])
	hud.get_parent().free()
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	var main = await overlays._scene(runner, Skirmish)
	main.hud.now_msec = func() -> int: return clock[0]
	clock[0] = 30000
	main.refuse("Target outside map", "")
	main._pause.open()
	var tick: int = main.driver.current().tick
	await _frames(runner)
	runner.check(_line_shown(main), "RN2 the line shows behind the open menu")
	clock[0] = 33000
	await _frames(runner)
	runner.check(not _line_shown(main) and main.driver.current().tick == tick and main.hud.refusal == "Target outside map", "RN2 the line expires on the clock while ticks stall, tick %d after %d" % [main.driver.current().tick, tick])
	main.free()
	overlays._end(saved)
	return true

func test_accepted_answer_clears(runner) -> bool:
	var skirmish = SkirmishTests.new()
	var main = await skirmish._setup(runner)
	var ids: Dictionary = skirmish._arena(main)
	var stop := {"type": "stop", "entity_ids": [ids.tank]}
	main._submit(skirmish._off_map_move(ids))
	BaseScene.tick(main)
	runner.check(_line_text(main) == "Target outside map", "RN3 fixture: a refusal on the line, got '%s'" % _line_text(main))
	main._submit(stop)
	runner.check(_line_text(main) == "Target outside map" and main.hud.refusal == "Target outside map", "RN3 a submit before its answer leaves the line, got '%s'" % _line_text(main))
	BaseScene.tick(main)
	runner.check(not _line_shown(main) and main.hud.refusal == "", "RN3 a drain with only an accepted answer clears it, got '%s'" % main.hud.refusal)
	for refused_first: bool in [true, false]:
		for payload: Dictionary in ([skirmish._off_map_move(ids), stop] if refused_first else [stop, skirmish._off_map_move(ids)]): main._submit(payload)
		BaseScene.tick(main)
		runner.check(_line_text(main) == "Target outside map" and main.hud.refusal == "Target outside map", "RN3 an accepted and a refused answer in one drain keep the refusal (refused first %s), got '%s'" % [refused_first, _line_text(main)])
		main._submit(stop)
		BaseScene.tick(main)
	main._submit(skirmish._off_map_move(ids))
	main._restart()
	ids = skirmish._arena(main)
	main.orders._open_build()
	main._submit({"type": "stop", "entity_ids": [ids.tank]})
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "" and not _line_shown(main), "RN3 after a restart dropped an unanswered order, the next accepted answer still clears a hint, got '%s'" % main.hud.refusal)
	main.free()
	return true

func test_placement_refusal_after_the_click_only(runner) -> bool:
	var helper = BaseScene.new()
	var main = await helper._placing(runner)
	var cell: Vector2 = Iso.world_to_plane(Vector2(4.25, 4.25))
	helper.hover(main, cell)
	BaseScene.tick(main)
	BaseScene.tick(main)
	helper.hover(main, cell)
	runner.check(main.orders._known_refused() and not _line_shown(main) and main.hud.refusal == "", "RN5 hovering a refused spot shows no line, got '%s'" % main.hud.refusal)
	helper.pointer(main, cell, MOUSE_BUTTON_LEFT, false)
	runner.check(_line_shown(main) and not main.hud.refusal.is_empty() and _line_text(main) == main.hud.refusal and main.orders._placement_kind == "usa_power_plant", "RN5 the click shows the line and keeps the placement, got '%s'" % _line_text(main))
	main.free()
	return true

func test_local_hints_on_the_line(runner) -> bool:
	var skirmish = SkirmishTests.new()
	var main = await skirmish._setup(runner)
	skirmish._arena(main)
	var builders: Array = [main.driver.pump.live().spawn(1, Vector2(12.5, 12.5), "usa_builder"), main.driver.pump.live().spawn(1, Vector2(13.5, 12.5), "usa_builder")]
	BaseScene.publish(main)
	_select(main, builders)
	BaseScene.new().key(main, HudModel.BUILD_KEY)
	BaseScene.tick(main)
	runner.check(_line_text(main) == "Select one builder" and main.hud.refusal == "Select one builder", "RN6 Build with two builders says so on the line, got '%s'" % _line_text(main))
	runner.check(skirmish._error_cues(main) == 0, "RN6 a local hint asks for no sound, got %d" % skirmish._error_cues(main))
	main.free()
	return true
