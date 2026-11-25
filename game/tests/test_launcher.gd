@warning_ignore_start("untyped_declaration")
extends RefCounted

const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Wire = preload("res://scripts/net/wire.gd")
const LOOPBACK := "wss://127.0.0.1:9/ws"
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const Credits = preload("res://scripts/presentation/credits.gd")
const DashedPanel = preload("res://scripts/presentation/dashed_panel.gd")
const REGULAR := "res://fonts/PublicSans-Regular.ttf"
const SELECTED := Color("#666a6c")
const ACTION := Color("#f7c871")
const INK := Color("#1a1408")
const SWITCH_DARK := Color("#2b2b2b")
const SWITCH_GREY := Color("#808080")
const SWITCH_LIGHT := Color("#d4d4d4")
const FIELD := Color(0.165, 0.165, 0.165)
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2576, 1145)]
# canvas_items + expand lays a window out at 720 logical px high; 2576x1145 becomes roundi(720 * 2576 / 1145) wide
const STRETCHED: Array[Array] = [[Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(2576, 1145), Vector2i(1620, 720)]]

func cases() -> Array[Callable]:
	return [test_picks_defaults, test_picks_fallback_per_field, test_picks_keep_other_sections, test_fullscreen_target, test_fullscreen_switch, test_this_build_line, test_graphics_group, test_graphics_shows_stored, test_graphics_mirror_esc_menu, test_no_selection_colour_on_switches, test_primary_button_is_amber_with_dark_ink, test_mute_is_a_switch, test_public_sans_font, test_launcher_effective_sizes, test_font_rendering, test_dropdown_arrow, test_control_heights, test_round4_minors, test_long_dropdown_text_keeps_a_gap, test_footer_error_hugs_text, test_waiting_bold_codes_and_dashed_slots, test_sidebar_switches_pages, test_aspect_expand_and_restore, test_layout_every_page, test_opens_on_bot_with_picks, test_toggle_friend, test_map_info_and_summary, test_own_faction_shared, test_start_saves_picks, test_advanced_only_prerelease, test_link_opens_join, test_lock_while_connecting, test_waiting_view, test_join_error_footer, test_join_needs_code, test_relay_fields_follow, test_column_widths, test_player_rows_padded, test_footer_status_style, test_vertical_rhythm, test_waiting_two_columns, test_enter_submits_join_code, test_enter_joins_after_link, test_connecting_footers_fit, test_connecting_elapsed_and_cancel, test_lobby_countdown_and_expiry, test_hidden_host_survives_lobby, test_ticking_texts_through_process, test_default_focus, test_stray_enter_does_nothing, test_enter_after_faction_pick, test_click_targets_32, test_quit_button, test_invite_label, test_focus_differs_from_hover, test_focus_ring_fits, test_mode_row_two_modes, test_team_mode_shows_bot_rows, test_team_bot_factions_remembered, test_team_mode_hides_small_maps, test_hidden_map_muted_line, test_team_hello_carries_bots, test_team_controls_locked_while_connecting, test_waiting_lists_bot_slots, test_waiting_edges_neon, test_start_sets_bot_factions_and_teams, test_version_mismatch_plain_line, test_team_layout_hud_sizes, test_guest_start_matches_host]

func _picked(selector: OptionButton) -> String:
	return selector.get_item_metadata(selector.selected)

func scratch_for(name: String) -> String:
	var scratch := "user://test-launcher-%s-%d.cfg" % [name, OS.get_process_id()]
	DirAccess.remove_absolute(scratch)
	return scratch

func _restore(saved: String) -> void:
	DirAccess.remove_absolute(AudioSettings.path)
	AudioSettings.path = saved

func test_picks_defaults(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("defaults")
	var picks: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	runner.check(picks == {"faction": "usa", "bot_faction": "usa", "map": "dry_wells"}, "L1 defaults without a file, got %s" % [picks])
	return true

func test_picks_fallback_per_field(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("fallback")
	var config := ConfigFile.new()
	config.set_value("launcher", "faction", "frc")
	config.set_value("launcher", "bot_faction", "gla")
	config.set_value("launcher", "map", 3)
	config.save(AudioSettings.path)
	var picks: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	runner.check(picks == {"faction": "frc", "bot_faction": "usa", "map": "dry_wells"}, "L2 bad fields fall back one by one, got %s" % [picks])
	return true

func test_picks_keep_other_sections(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("sections")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.5)
	config.set_value("playtest", "enabled", false)
	config.save(AudioSettings.path)
	LauncherSettings.save_picks({"faction": "china"})
	var after := ConfigFile.new()
	after.load(AudioSettings.path)
	_restore(saved)
	runner.check(after.get_value("audio", "music", null) == 0.5, "L3 audio survives")
	runner.check(after.get_value("playtest", "enabled", null) == false, "L3 playtest survives")
	runner.check(after.get_value("launcher", "faction", null) == "china", "L3 faction saved")
	runner.check(not after.has_section_key("launcher", "bot_faction") and not after.has_section_key("launcher", "map"), "L3 absent keys stay absent")
	return true

func test_fullscreen_target(runner) -> bool:
	var window := DisplayServer
	var rows: Array = [
		[false, window.WINDOW_MODE_MAXIMIZED, -1], [false, window.WINDOW_MODE_WINDOWED, -1],
		[false, window.WINDOW_MODE_FULLSCREEN, window.WINDOW_MODE_WINDOWED], [false, window.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, window.WINDOW_MODE_WINDOWED],
		[true, window.WINDOW_MODE_MAXIMIZED, window.WINDOW_MODE_FULLSCREEN], [true, window.WINDOW_MODE_WINDOWED, window.WINDOW_MODE_FULLSCREEN],
		[true, window.WINDOW_MODE_FULLSCREEN, -1],
	]
	for row: Array in rows:
		var got: int = LauncherScript.fullscreen_target(row[0], row[1])
		runner.check(got == row[2], "L16 fullscreen_target(on=%s, mode=%s) is %s, got %s" % [row[0], row[1], row[2], got])
	return true

func _visible_pages(launcher: Node) -> Array[String]:
	var shown: Array[String] = []
	for page_name: String in LauncherScript.PAGES:
		var page: Control = launcher.get_node_or_null("Pages/" + page_name)
		if page != null and page.visible: shown.append(page_name)
	return shown

func test_sidebar_switches_pages(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	runner.check(launcher.current_page == "Play" and _visible_pages(launcher) == ["Play"], "L5 opens on Play only, got %s" % [_visible_pages(launcher)])
	for page_name: String in ["Join", "Settings", "Credits"]:
		var nav: Button = launcher.get_node_or_null("Sidebar/Nav/" + page_name)
		runner.check(nav != null, "L5 nav button %s exists" % page_name)
		if nav == null: continue
		nav.button_pressed = true
		runner.check(launcher.current_page == page_name and _visible_pages(launcher) == [page_name] and nav.button_pressed, "L5 %s shows only its page, got %s" % [page_name, _visible_pages(launcher)])
	launcher.show_page("Waiting")
	runner.check(_visible_pages(launcher) == ["Waiting"] and launcher.get_node("Sidebar/Nav/Play").button_pressed, "L5 Waiting shows alone and presses Play")
	var version: Label = launcher.get_node_or_null("Sidebar/Version")
	runner.check(version != null and str(ProjectSettings.get_setting("application/config/version")) in version.text, "L6 the sidebar shows the version")
	launcher.free()
	return true

func test_aspect_expand_and_restore(runner) -> bool:
	var root: Window = runner.root.get_tree().root
	var base := [Vector2i(1280, 720), Window.CONTENT_SCALE_ASPECT_EXPAND]
	runner.check([root.content_scale_size, root.content_scale_aspect] == base, "L7 fixture: the root starts on 1280x720 expand, got %s %d" % [root.content_scale_size, root.content_scale_aspect])
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	runner.check([root.content_scale_size, root.content_scale_aspect] == base, "L7 the launcher keeps 1280x720 expand")
	launcher.free()
	runner.check([root.content_scale_size, root.content_scale_aspect] == base, "L7 leaving the tree keeps 1280x720 expand, got %s %d" % [root.content_scale_size, root.content_scale_aspect])
	return true

func _visible_controls(node: Node, found: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.visible:
			found.append(child)
			_visible_controls(child, found)

func _overlap_free(runner, node: Control, label: String) -> void:
	var rows: Array[Control] = []
	for child in node.get_children():
		if child is Control and child.visible: rows.append(child)
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			runner.check(not rows[i].get_global_rect().intersects(rows[j].get_global_rect()), "L8 %s: %s and %s do not overlap" % [label, rows[i].name, rows[j].name])

func test_layout_every_page(runner) -> bool:
	var saved: String = AudioSettings.path
	var scratch := "user://test-launcher-layout-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var layouts: Array[Array] = []
	for size in SIZES: layouts.append([size, size])
	layouts.append_array(STRETCHED)
	for pair in layouts:
		var size: Vector2i = pair[1]
		var port := SubViewport.new()
		port.size = pair[0]
		port.size_2d_override = size
		port.size_2d_override_stretch = true
		runner.root.add_child(port)
		runner.check(port.get_visible_rect().size == Vector2(size), "L8 fixture: the viewport lays out at %s, got %s" % [size, port.get_visible_rect().size])
		var launcher = Launcher.instantiate()
		launcher.prerelease = true
		port.add_child(launcher)
		var advanced: Button = launcher.get_node_or_null("Pages/Play/Body/Advanced/Toggle")
		if advanced != null: advanced.button_pressed = true
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var content: Control = launcher.get_node_or_null("Pages")
		var sidebar: Control = launcher.get_node_or_null("Sidebar")
		runner.check(content != null and sidebar != null, "L8 sidebar and pages exist at %s" % size)
		var visits: Array[String] = LauncherScript.PAGES.duplicate()
		visits.append("Play")
		for visit in visits.size():
			var page_name: String = visits[visit]
			launcher.set_opponent("friend" if visit == LauncherScript.PAGES.size() else "bot")
			launcher.show_page(page_name)
			await runner.process_frame
			await runner.process_frame
			var label := "%s at %s (window %s)" % [page_name, size, pair[0]]
			runner.check(sidebar.get_global_rect().position.y == 0.0 and absf(sidebar.get_global_rect().size.y - size.y) <= 1.0, "L8 sidebar spans the full height, %s" % label)
			runner.check(absf(content.get_global_rect().end.x - size.x) <= 1.0 and absf(content.get_global_rect().end.y - size.y) <= 1.0, "L8 content reaches the right and bottom edge, %s, got %s" % [label, content.get_global_rect()])
			runner.check(view.encloses(content.get_global_rect()) and not content.get_global_rect().intersects(sidebar.get_global_rect()), "L8 sidebar and content sit side by side inside the viewport, %s" % label)
			var controls: Array[Control] = []
			_visible_controls(launcher.get_node("Pages/" + page_name), controls)
			var inside: bool = true
			for control in controls:
				inside = inside and content.get_global_rect().grow(0.5).encloses(control.get_global_rect())
				if control.get_child_count() > 0: _overlap_free(runner, control, label)
			runner.check(controls.size() > 3 and inside, "L8 every visible control lies inside the content area, %s" % label)
			_overlap_free(runner, launcher.get_node("Pages/" + page_name), label)
		launcher.free()
		port.free()
	_restore(saved)
	return true

func _launcher_with(runner, name: String, picks: Dictionary, prerelease: bool = false):
	AudioSettings.path = scratch_for(name)
	LauncherSettings.save_picks(picks)
	var launcher = Launcher.instantiate()
	launcher.prerelease = prerelease
	runner.root.add_child(launcher)
	await runner.process_frame
	return launcher

func test_opens_on_bot_with_picks(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "opens", {"faction": "china", "bot_faction": "frc", "map": "ashfall"})
	_restore(saved)
	var play: Control = launcher.get_node("Pages/Play")
	runner.check(_picked(play.get_node("Body/Own")) == "china" and _picked(play.get_node("Body/Bot")) == "frc" and launcher._map_id() == "ashfall", "L9a Play shows the remembered picks")
	runner.check(launcher.opponent == "bot" and play.get_node("Footer/Start").visible and not play.get_node("Footer/Create").visible, "L9a opens on the bot with Start only")
	launcher.free()
	return true

func test_toggle_friend(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "toggle", {})
	_restore(saved)
	var play: Control = launcher.get_node("Pages/Play")
	var bot_toggle: Button = play.get_node("Body/Opponent/BotToggle")
	var friend_toggle: Button = play.get_node("Body/Opponent/FriendToggle")
	launcher.set_opponent("friend")
	runner.check(launcher.opponent == "friend" and not play.get_node("Body/Bot").visible and not play.get_node("Body/BotLabel").visible, "L9b friend hides the bot selector")
	runner.check(play.get_node("Body/OpenSlot").visible and play.get_node("Footer/Create").visible and not play.get_node("Footer/Start").visible, "L9b friend shows the open slot and Create")
	runner.check(play.get_node("Body/OpenSlot/Row/Hint").text == "Your friend picks their own faction.", "L9b open slot copy")
	runner.check(play.get_node("Footer/Status").text == "You get a link to send to your friend.", "L9b footer hint, got '%s'" % play.get_node("Footer/Status").text)
	runner.check(friend_toggle.button_pressed and not bot_toggle.button_pressed, "L9b the Friend toggle is pressed")
	runner.check(friend_toggle.get_theme_stylebox("pressed").bg_color == SELECTED and bot_toggle.get_theme_stylebox("normal").bg_color == FIELD, "L9b selected side grey, other side field colour")
	bot_toggle.pressed.emit()
	runner.check(launcher.opponent == "bot" and play.get_node("Body/Bot").visible and not play.get_node("Body/OpenSlot").visible and play.get_node("Footer/Start").visible, "L9b the Bot toggle returns to the bot")
	launcher.free()
	return true

func test_map_info_and_summary(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "info", {"faction": "usa", "bot_faction": "frc", "map": "dry_wells"})
	_restore(saved)
	for id: String in MatchSettings.PLAY_MAPS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MatchSettings.map_path(id)))
		runner.check(launcher._map_info(id) == "%d start positions · %d supply sources" % [data.starts.size(), data.sources.size()], "L9c map info for %s, got '%s'" % [id, launcher._map_info(id)])
	runner.check(launcher._summary() == "Dry Wells · United States vs Free Resistance Coalition bot", "L9c summary, got '%s'" % launcher._summary())
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == launcher._summary(), "L9c the footer shows the summary")
	runner.check(launcher.get_node("Pages/Play/Body/MapInfo").text == launcher._map_info("dry_wells"), "L9c the map info shows under the map")
	launcher.free()
	return true

func _index_where(selector: OptionButton, matches: Callable) -> int:
	for i in selector.item_count:
		if matches.call(selector.get_item_metadata(i)): return i
	return -1

func test_own_faction_shared(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "shared", {"faction": "usa"})
	_restore(saved)
	var play_own: OptionButton = launcher.get_node("Pages/Play/Body/Own")
	var join_own: OptionButton = launcher.get_node_or_null("Pages/Join/Body/Own")
	runner.check(join_own != null, "L9d Join has its own faction selector")
	if join_own == null:
		launcher.free()
		return true
	for id: String in ["china", "usa"]:
		var index: int = _index_where(join_own, func(item: String) -> bool: return item == id)
		join_own.select(index)
		join_own.item_selected.emit(index)
		runner.check(_picked(play_own) == id, "L9d Join's pick %s reaches Play" % id)
		var back: int = _index_where(play_own, func(item: String) -> bool: return item != id)
		play_own.select(back)
		play_own.item_selected.emit(back)
		runner.check(_picked(join_own) == _picked(play_own) and _picked(join_own) != id, "L9d Play's pick reaches Join")
	launcher.free()
	return true

func test_start_saves_picks(runner) -> bool:
	var saved: String = AudioSettings.path
	var before: Array = OnlineTests._statics()
	var launcher = await _launcher_with(runner, "saves", {"faction": "usa", "bot_faction": "usa", "map": "dry_wells"})
	launcher._set_own("china")
	launcher._select_id(launcher.get_node("Pages/Play/Body/Bot"), "frc")
	launcher._select_id(launcher.get_node("Pages/Play/Body/Map"), "ashfall")
	launcher._offline_setup()
	var stored: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	# The next case's match must not start on this case's picks.
	OnlineTests._restore_statics(before)
	runner.check(stored == {"faction": "china", "bot_faction": "frc", "map": "ashfall"}, "L9e a bot start saves all three, got %s" % [stored])
	launcher.free()
	return true

func test_advanced_only_prerelease(runner) -> bool:
	var saved: String = AudioSettings.path
	for prerelease in [false, true]:
		var launcher = await _launcher_with(runner, "advanced", {}, prerelease)
		launcher.set_opponent("friend")
		for page_name: String in ["Play", "Join"]:
			var fold: Control = launcher.get_node("Pages/%s/Body/Advanced" % page_name)
			runner.check(fold.visible == prerelease, "L9f %s fold visible == prerelease (%s)" % [page_name, prerelease])
			runner.check(fold.get_node("Toggle").text == "Advanced settings" and fold.get_node("Toggle/Tag").text == "TEST BUILDS ONLY", "L9f %s fold label and tag" % page_name)
		launcher.set_opponent("bot")
		runner.check(not launcher.get_node("Pages/Play/Body/Advanced").visible, "L9f Play bot hides the fold")
		launcher.free()
	_restore(saved)
	return true


func _texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false): found.append(label.text)
	for rich: RichTextLabel in node.find_children("*", "RichTextLabel", true, false): found.append(rich.get_parsed_text())
	return found

func _nav_disabled(launcher) -> Array[bool]:
	var states: Array[bool] = []
	for page_name: String in LauncherScript.NAV_PAGES: states.append(launcher.get_node("Sidebar/Nav/" + page_name).disabled)
	return states

func _drawn_selected(button: Button) -> bool:
	var styles: Dictionary = {BaseButton.DRAW_NORMAL: "normal", BaseButton.DRAW_PRESSED: "pressed", BaseButton.DRAW_HOVER: "hover", BaseButton.DRAW_DISABLED: "disabled", BaseButton.DRAW_HOVER_PRESSED: "hover_pressed"}
	var style: StyleBox = button.get_theme_stylebox(styles[button.get_draw_mode()])
	return style is StyleBoxFlat and style.bg_color == SELECTED

func _host(launcher) -> Object:
	launcher._set_relay(LOOPBACK)
	launcher.set_opponent("friend")
	launcher.get_node("Pages/Play/Footer/Create").pressed.emit()
	launcher.set_process(false)
	var transport := OnlineTests.FakeTransport.new()
	launcher._transport = transport
	return transport

func test_link_opens_join(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("link")
	LauncherSettings.save_picks({"faction": "china", "bot_faction": "frc", "map": "ashfall"})
	LauncherScript.code_applied = false
	var first = Launcher.instantiate()
	first.search = "?code=ABC234"
	runner.root.add_child(first)
	await runner.process_frame
	runner.check(first.current_page == "Join" and first.get_node("Pages/Join/Body/Code").text == "ABC234" and first._transport == null, "L10a a join link opens Join with the code and no connection, got %s" % first.current_page)
	first.free()
	var again = Launcher.instantiate()
	again.search = "?code=ABC234"
	runner.root.add_child(again)
	await runner.process_frame
	runner.check(again.current_page == "Play", "L10b a stale link does not reopen Join, got %s" % again.current_page)
	runner.check(_picked(again.get_node("Pages/Play/Body/Own")) == "china" and again._map_id() == "ashfall", "L13 back to menu shows the remembered picks")
	runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "L13 back to menu sets expand again")
	again.free()
	_restore(saved)
	return true

func test_lock_while_connecting(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lock", {})
	_restore(saved)
	var reason := "Connection to relay lost"
	_host(launcher)
	runner.check(launcher._relay_url() == LOOPBACK, "L11 fixture: the relay is a loopback literal, so no DNS lookup starts")
	runner.check(_nav_disabled(launcher) == [true, true, true, true], "L11 Create locks every nav button, got %s" % [_nav_disabled(launcher)])
	var friend_toggle: Button = launcher.get_node("Pages/Play/Body/Opponent/FriendToggle")
	runner.check(launcher.get_node("Sidebar/Nav/Play").disabled and friend_toggle.disabled, "L11 the Friend toggle locks with the nav")
	runner.check(_drawn_selected(launcher.get_node("Sidebar/Nav/Play")) and _drawn_selected(friend_toggle), "L17 while connecting the Play nav and the Friend toggle still draw the selection grey")
	launcher._fail(reason)
	var play_status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(_nav_disabled(launcher) == [false, false, false, false] and launcher.current_page == "Play" and play_status.text == reason and launcher.opponent == "friend", "L11 a failure before welcome unlocks the nav and shows the reason in Play's footer")
	var join_own: OptionButton = launcher.get_node("Pages/Join/Body/Own")
	var index: int = _index_where(join_own, func(item: String) -> bool: return item != _picked(join_own))
	join_own.select(index)
	join_own.item_selected.emit(index)
	runner.check(play_status.text == reason, "M3 changing Own from Join keeps the error in Play's footer, got '%s'" % play_status.text)
	launcher.set_opponent("bot")
	runner.check(play_status.text == launcher._summary(), "M3 the next action on Play replaces the error")
	launcher.free()
	return true

func test_waiting_view(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "waiting", {"faction": "china", "map": "ashfall"})
	_restore(saved)
	var transport = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var waiting: Control = launcher.get_node("Pages/Waiting")
	var own: String = Registry.faction("china").display_name
	runner.check(launcher.current_page == "Waiting" and _nav_disabled(launcher) == [true, true, true, true], "L12a welcome shows Waiting with the nav locked")
	runner.check(_drawn_selected(launcher.get_node("Sidebar/Nav/Play")), "L17 Waiting draws the Play nav in the selection grey")
	for other: String in ["Join", "Settings", "Credits"]:
		runner.check(not _drawn_selected(launcher.get_node("Sidebar/Nav/" + other)), "L17 Waiting leaves %s idle" % other)
	runner.check(waiting.get_node("Body/Left/Invite/Link").text == launcher._copy_text() and "Or tell them the code: ABC234" in _texts(waiting), "L12a link and code line")
	var one: Array[String] = _texts(waiting.get_node("Body/Left/One"))
	runner.check("You" in one and own in one and "READY" in one, "L12a row 1 is You, %s, READY, got %s" % [own, one])
	var two: Array[String] = _texts(waiting.get_node("Body/Left/Two"))
	runner.check("Open" in two and "waiting for your friend…" in two, "L12a row 2 is Open, got %s" % [two])
	var map_texts: Array[String] = _texts(waiting.get_node("Body/Right/Map"))
	runner.check(MatchSettings.PLAY_MAPS["ashfall"] in map_texts and launcher._map_info("ashfall") in map_texts, "L12a map name and info, got %s" % [map_texts])
	runner.check(waiting.get_node("Footer/Status").get_parsed_text() == "Match code ABC234 · closes in 15:00", "L12a footer shows the match code")
	await runner.process_frame
	await runner.process_frame
	var controls: Array[Control] = []
	_visible_controls(waiting, controls)
	var inside: bool = true
	for control in controls: inside = inside and launcher.get_node("Pages").get_global_rect().grow(0.5).encloses(control.get_global_rect())
	runner.check(controls.size() > 10 and inside, "L12a every Waiting control lies inside the content area")
	_overlap_free(runner, waiting.get_node("Body/Left"), "Waiting")
	waiting.get_node("Footer/Cancel").pressed.emit()
	runner.check(transport.close_calls == 1 and launcher.current_page == "Play" and _nav_disabled(launcher) == [false, false, false, false], "L12b Cancel closes and returns to Play unlocked")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "Match cancelled" and launcher.opponent == "friend", "L12b Play says Match cancelled and stays on Friend")
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	launcher._handle('{"type":"error","reason":"match is full"}')
	runner.check(launcher.current_page == "Play" and launcher.get_node("Pages/Play/Footer/Status").text == "match is full" and launcher.opponent == "friend", "L12c a relay error on Waiting returns to Play with the reason")
	launcher.free()
	return true

func test_join_error_footer(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-error", {})
	_restore(saved)
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	runner.check(launcher._relay_url() == LOOPBACK, "L14 fixture: the relay is a loopback literal, so no DNS lookup starts")
	launcher.get_node("Pages/Join/Body/Code").text = "ABC234"
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	launcher.set_process(false)
	runner.check(_nav_disabled(launcher) == [true, true, true, true], "L14 Join locks the nav")
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._fail("Cannot connect to relay")
	runner.check(launcher.current_page == "Join" and launcher.get_node("Pages/Join/Footer/Status").text == "Cannot connect to relay" and _nav_disabled(launcher) == [false, false, false, false], "L14 the error shows in Join's footer, nav unlocked")
	launcher.free()
	return true

func test_join_needs_code(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-code", {})
	_restore(saved)
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	var status: Label = launcher.get_node("Pages/Join/Footer/Status")
	for text: String in ["", "ABC", "ABC10O"]:
		launcher.get_node("Pages/Join/Body/Code").text = text
		launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
		launcher.set_process(false)
		runner.check(launcher._transport == null and launcher.current_page == "Join" and status.text == "Enter the 6-character match code", "L18 code '%s' does not connect and says what to enter, got '%s'" % [text, status.text])
	launcher.get_node("Pages/Join/Body/Code").text = "abc234"
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	launcher.set_process(false)
	runner.check(launcher._transport != null and _nav_disabled(launcher) == [true, true, true, true], "L18 a valid code (lower case typed) connects")
	launcher._transport = null
	launcher.free()
	return true

func test_relay_fields_follow(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("relay")
	LauncherScript.code_applied = false
	var launcher = Launcher.instantiate()
	launcher.prerelease = true
	launcher.search = "?relay=wss%3A%2F%2Fx.example%2Fws"
	runner.root.add_child(launcher)
	await runner.process_frame
	_restore(saved)
	var play: LineEdit = launcher.get_node("Pages/Play/Body/Advanced/RelayUrl")
	var join: LineEdit = launcher.get_node("Pages/Join/Body/Advanced/RelayUrl")
	runner.check(play.text == "wss://x.example/ws" and join.text == play.text and play.visible and join.visible, "M2 ?relay= fills and opens both folds")
	join.text = "wss://y.example/ws"
	join.text_changed.emit(join.text)
	runner.check(launcher._relay_url() == "wss://y.example/ws" and play.text == join.text, "M2 typing into Join's field reaches Play and _relay_url()")
	play.text = "wss://z.example/ws"
	play.text_changed.emit(play.text)
	runner.check(launcher._relay_url() == "wss://z.example/ws" and join.text == play.text, "M2 typing into Play's field reaches Join")
	launcher.free()
	return true

func test_fullscreen_switch(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("fullscreen-switch")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var fullscreen: CheckButton = launcher.get_node_or_null("Pages/Settings/Body/Audio/Fullscreen")
	runner.check(fullscreen != null and not fullscreen.button_pressed, "L15a Fullscreen exists and is off by default")
	var display: Label = launcher.get_node_or_null("Pages/Settings/Body/Audio/DisplayHeader")
	runner.check(display != null and display.text == "Display" and fullscreen != null and display.get_index() == fullscreen.get_index() - 1, "L15c Fullscreen sits under its own Display header")
	if fullscreen != null:
		fullscreen.button_pressed = true
		runner.check(LauncherSettings.fullscreen(), "L15a pressing Fullscreen saves true")
		fullscreen.button_pressed = false
		runner.check(not LauncherSettings.fullscreen(), "L15a releasing Fullscreen saves false")
	launcher.free()
	LauncherSettings.save_fullscreen(true)
	launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	runner.check(launcher.get_node("Pages/Settings/Body/Audio/Fullscreen").button_pressed, "L15a the stored value shows on the switch")
	launcher.free()
	_restore(saved)
	return true

func test_this_build_line(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("this-build")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var toggle: CheckButton = launcher.get_node("Pages/Settings/Body/Playtest/PlaytestSwitch")
	toggle.button_pressed = false
	var title: String = FocusCards.load_cards()[0].title
	runner.check(launcher.get_node_or_null("Pages/Settings/Body/Playtest/ThisBuild") == null, "L15b Settings no longer holds ThisBuild")
	for page_name: String in ["Play", "Join"]:
		var build: Button = launcher.get_node("Pages/%s/ThisBuild" % page_name)
		runner.check(not build.visible, "L15b %s ThisBuild is hidden while the switch is off" % page_name)
		runner.check(build.get_index() + 1 == launcher.get_node("Pages/%s/Divider" % page_name).get_index(), "L15b %s ThisBuild sits just above the divider" % page_name)
		runner.check(build.theme_type_variation == &"FooterLink" and build.get_theme_stylebox("normal") is StyleBoxEmpty, "L15b %s ThisBuild is a line-style link" % page_name)
		runner.check(not build.flat, "R4 %s ThisBuild leaves flat off, the link style alone makes it a line" % page_name)
		var focus: StyleBox = build.get_theme_stylebox("focus")
		runner.check(focus is StyleBoxFlat and focus.border_width_left > 0, "R3 %s ThisBuild shows a visible focus outline" % page_name)
	toggle.button_pressed = true
	for page_name: String in ["Play", "Join"]:
		var build: Button = launcher.get_node("Pages/%s/ThisBuild" % page_name)
		runner.check(build.visible and build.text == "This build: " + title, "L15b %s ThisBuild names the first card when on, got %s" % [page_name, build.text])
	toggle.button_pressed = false
	for page_name: String in ["Play", "Join"]:
		runner.check(not launcher.get_node("Pages/%s/ThisBuild" % page_name).visible, "L15b %s ThisBuild hides again when switched off" % page_name)
	launcher.free()
	_restore(saved)
	return true

func test_graphics_group(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("graphics")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var column: Control = launcher.get_node("Pages/Settings/Body/Playtest")
	var header: Label = column.get_node_or_null("GraphicsHeader")
	runner.check(header != null and header.text == "Graphics" and header.theme_type_variation == &"FieldLabel", "G1 Graphics has its own header in the page style")
	var quality: Control = column.get_node_or_null("Quality")
	var low: Button = column.get_node_or_null("Quality/Low")
	var high: Button = column.get_node_or_null("Quality/High")
	var neon: CheckButton = column.get_node_or_null("Neon")
	var smooth: CheckButton = column.get_node_or_null("Smooth")
	var destinations: CheckButton = column.get_node_or_null("Destinations")
	runner.check(quality != null and low != null and high != null and neon != null and smooth != null and destinations != null, "G1 the quality toggle and three switches exist")
	if quality == null or low == null or high == null or neon == null or smooth == null or destinations == null:
		launcher.free()
		_restore(saved)
		return true
	runner.check(header.get_index() + 1 == quality.get_index() and quality.get_index() + 1 == neon.get_index() and neon.get_index() + 1 == smooth.get_index() and smooth.get_index() + 1 == destinations.get_index(), "G1 the controls follow the header in order")
	runner.check(low.theme_type_variation == &"ToggleButton" and high.theme_type_variation == &"ToggleButton" and low.toggle_mode and high.toggle_mode, "F2 Quality is a Low|High toggle styled like Bot|Friend")
	runner.check(not low.button_pressed and high.button_pressed and not neon.button_pressed and smooth.button_pressed and not destinations.button_pressed, "G2 defaults read like the Esc menu: High, Neon off, Smooth on, Destinations off")
	runner.check(neon.text == "Neon colours" and smooth.text == "Smooth movement" and destinations.text == "Show unit destinations", "G2 the switches keep the Esc menu's labels, got %s | %s | %s" % [neon.text, smooth.text, destinations.text])
	low.pressed.emit()
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.LOW and low.button_pressed and not high.button_pressed, "G3 Quality to Low is stored and shown")
	low.pressed.emit()
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.LOW and low.button_pressed and not high.button_pressed, "G3 pressing the selected side keeps it selected")
	high.pressed.emit()
	runner.check(GraphicsSettings.load_quality() == GraphicsSettings.HIGH and high.button_pressed and not low.button_pressed, "G3 Quality back to High is stored and shown")
	neon.button_pressed = true
	runner.check(GraphicsSettings.load_neon(), "G3 Neon on is stored")
	neon.button_pressed = false
	runner.check(not GraphicsSettings.load_neon(), "G3 Neon off is stored")
	smooth.button_pressed = false
	runner.check(not GraphicsSettings.load_smooth(), "G3 Smooth off is stored")
	smooth.button_pressed = true
	runner.check(GraphicsSettings.load_smooth(), "G3 Smooth on is stored")
	destinations.button_pressed = true
	runner.check(GraphicsSettings.load_destinations(), "G3 Destinations on is stored")
	destinations.button_pressed = false
	runner.check(not GraphicsSettings.load_destinations(), "G3 Destinations off is stored")
	launcher.free()
	_restore(saved)
	return true

func test_graphics_shows_stored(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("graphics-stored")
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	GraphicsSettings.save_neon(true)
	GraphicsSettings.save_smooth(false)
	GraphicsSettings.save_destinations(true)
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var column: Control = launcher.get_node("Pages/Settings/Body/Playtest")
	var shown: Array = []
	for each: String in ["Quality/Low", "Quality/High", "Neon", "Smooth", "Destinations"]:
		var button: Button = column.get_node_or_null(each)
		shown.append(button.button_pressed if button != null else "missing")
	runner.check(shown == [true, false, true, false, true], "G4 stored values show on the controls, got %s" % [shown])
	launcher.free()
	_restore(saved)
	return true

func test_graphics_mirror_esc_menu(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("graphics-mirror")
	for stored: Array in [[GraphicsSettings.LOW, true, false, true], [GraphicsSettings.HIGH, false, true, false]]:
		GraphicsSettings.save_quality(stored[0])
		GraphicsSettings.save_neon(stored[1])
		GraphicsSettings.save_smooth(stored[2])
		GraphicsSettings.save_destinations(stored[3])
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		var menu = PauseMenu.new(false)
		var column: Control = launcher.get_node("Pages/Settings/Body/Playtest")
		var quality: String = "Low" if column.get_node("Quality/Low").button_pressed else "High"
		runner.check(menu.find_child("Quality", true, false).get_node(quality).button_pressed, "R2 launcher and Esc menu agree on Quality for %s" % [stored])
		for each: String in ["Neon", "Smooth", "Destinations"]:
			var control: CheckButton = column.get_node(each)
			runner.check(menu.find_child(each, true, false).button_pressed == control.button_pressed, "R2 launcher %s switch and Esc menu switch agree for %s" % [each, stored])
		menu.free()
		launcher.free()
	_restore(saved)
	return true

func _port_with_launcher(runner, window: Vector2i, size: Vector2i) -> Array:
	var port := SubViewport.new()
	port.size = window
	port.size_2d_override = size
	port.size_2d_override_stretch = true
	runner.root.add_child(port)
	var launcher = Launcher.instantiate()
	launcher.prerelease = true
	port.add_child(launcher)
	launcher._code = "K7Q2"
	launcher._fill_waiting()
	return [port, launcher]

func _settle(runner, launcher, page_name: String, opponent: String = "bot") -> void:
	launcher.set_opponent(opponent)
	launcher.show_page(page_name)
	await runner.process_frame
	await runner.process_frame

func test_column_widths(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("columns")
	var left: Dictionary = {"Play": "Body/Own", "Join": "Body/Code", "Settings": "Body/Audio", "Waiting": "Body/Left"}
	var seen: Dictionary = {}
	for pair in [[Vector2i(1280, 720), Vector2i(1280, 720)], STRETCHED[1]]:
		var built: Array = _port_with_launcher(runner, pair[0], pair[1])
		for page_name: String in left:
			await _settle(runner, built[1], page_name)
			var column: Control = built[1].get_node_or_null("Pages/%s/%s" % [page_name, left[page_name]])
			var width: float = column.size.x if column != null else -1.0
			runner.check(width >= 520.0 and width <= 570.0, "L19a %s left column is 520-570 px wide at %s, got %s" % [page_name, pair[1], width])
			if seen.has(page_name): runner.check(absf(width - seen[page_name]) < 1.0, "L19a %s left column keeps its width at %s, got %s then %s" % [page_name, pair[1], seen[page_name], width])
			seen[page_name] = width
			var page: Control = built[1].get_node("Pages/" + page_name)
			runner.check(page.size.x <= 961.0, "L19a %s page does not stretch with the window at %s, got %s" % [page_name, pair[1], page.size.x])
		built[1].free()
		built[0].free()
	AudioSettings.path = saved
	return true

func _inner_margins(row: Control) -> Vector2:
	var content: Control = row.get_child(0)
	return Vector2(content.get_global_rect().position.x - row.get_global_rect().position.x, row.get_global_rect().end.x - content.get_global_rect().end.x)

func test_player_rows_padded(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("rows")
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	await _settle(runner, launcher, "Waiting")
	var one: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left/One")
	var two: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left/Two")
	runner.check(one != null and two != null, "L19b both player rows exist")
	if one != null and two != null:
		for row: Control in [one, two]:
			var margins: Vector2 = _inner_margins(row)
			runner.check(margins.x >= 10.0 and margins.y >= 10.0, "L19b row %s keeps 10 px inside left and right, got %s" % [row.name, margins])
		runner.check(absf(one.size.y - two.size.y) < 1.0 and absf(one.size.x - two.size.x) < 1.0, "L19b both rows have the same size, got %s and %s" % [one.size, two.size])
	await _settle(runner, launcher, "Play", "friend")
	var slot: Control = launcher.get_node("Pages/Play/Body/OpenSlot")
	var slot_margins: Vector2 = _inner_margins(slot)
	runner.check(slot_margins.x >= 10.0 and slot_margins.y >= 10.0, "L19b the Play open slot keeps 10 px inside, got %s" % slot_margins)
	built[1].free()
	built[0].free()
	AudioSettings.path = saved
	return true

func test_footer_status_style(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "footer-style", {})
	_restore(saved)
	var info_size: int = launcher.get_node("Pages/Join/Footer/Status").get_theme_font_size("font_size")
	runner.check(info_size == 16, "L19c the footer text is 16 px, got %s" % info_size)
	var waiting_size: int = launcher.get_node("Pages/Waiting/Footer/Status").get_theme_font_size("normal_font_size")
	runner.check(waiting_size == 16, "L19c the Waiting footer text is 16 px, got %s" % waiting_size)
	var seen: Dictionary = {}
	for page_name: String in ["Play", "Join"]:
		launcher.show_page(page_name)
		launcher._origin = page_name
		launcher._fail("Cannot connect to relay")
		var status: Label = launcher.get_node("Pages/%s/Footer/Status" % page_name)
		var style: StyleBox = status.get_theme_stylebox("normal")
		runner.check(style is StyleBoxFlat and style.bg_color == Color(0.38, 0.27, 0.27) and style.border_width_left > 0, "L19c a %s error uses the error strip" % page_name)
		runner.check(status.get_theme_font_size("font_size") <= info_size, "L19c a %s error text is no larger than the footer text, got %s" % [page_name, status.get_theme_font_size("font_size")])
		seen[page_name] = status
	launcher._fail("Match cancelled")
	var plain: StyleBox = seen["Join"].get_theme_stylebox("normal")
	runner.check(not (plain is StyleBoxFlat and plain.bg_color == Color(0.38, 0.27, 0.27)), "L19c Match cancelled is plain info text")
	launcher.set_opponent("friend")
	var hint: StyleBox = seen["Play"].get_theme_stylebox("normal")
	runner.check(not (hint is StyleBoxFlat and hint.bg_color == Color(0.38, 0.27, 0.27)), "L19c the next Play action drops the strip")
	launcher.show_page("Join")
	launcher.get_node("Pages/Join/Body/Code").text = ""
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	var invalid: StyleBox = seen["Join"].get_theme_stylebox("normal")
	runner.check(invalid is StyleBoxFlat and invalid.bg_color == Color(0.38, 0.27, 0.27), "L19c the missing-code line uses the error strip")
	launcher.free()
	return true

func _text_top(label: Control) -> float:
	return label.get_global_rect().position.y + label.get_theme_stylebox("normal").get_margin(SIDE_TOP)

func test_vertical_rhythm(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("rhythm")
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	var rows: Array = [["Play", "bot", "Body/OwnLabel", "Body/Own", "Body/OpponentLabel"], ["Play", "bot", "Body/OpponentLabel", "Body/Opponent", "Body/BotLabel"], ["Join", "bot", "Body/CodeLabel", "Body/Code", "Body/CodeHint", 6.0, 10.0], ["Waiting", "bot", "Body/Left/InviteLabel", "Body/Left/Invite", "Body/Left/CodeHint", 6.0, 10.0]]
	for row: Array in rows:
		await _settle(runner, launcher, row[0], row[1])
		var label: Control = launcher.get_node_or_null("Pages/%s/%s" % [row[0], row[2]])
		var control: Control = launcher.get_node_or_null("Pages/%s/%s" % [row[0], row[3]])
		var next: Control = launcher.get_node_or_null("Pages/%s/%s" % [row[0], row[4]])
		var low: float = row[5] if row.size() > 5 else 20.0
		var high: float = row[6] if row.size() > 6 else 26.0
		runner.check(label != null and control != null and next != null, "L19d %s rows exist: %s" % [row[0], row])
		if label == null or control == null or next == null: continue
		var inner: float = control.get_global_rect().position.y - label.get_global_rect().end.y
		var between: float = _text_top(next) - control.get_global_rect().end.y
		runner.check(inner >= 6.0 and inner <= 10.0, "L19d %s: label to control is about 8 px, got %s (%s)" % [row[0], inner, row[2]])
		runner.check(between >= low and between <= high, "L19d %s: control to next text is %s-%s px, got %s (%s)" % [row[0], low, high, between, row[4]])
	await _settle(runner, launcher, "Waiting")
	var players: Label = launcher.get_node("Pages/Waiting/Body/Left/PlayersLabel")
	var waiting_gap: float = _text_top(players) - launcher.get_node("Pages/Waiting/Body/Left/CodeHint").get_global_rect().end.y
	runner.check(waiting_gap >= 20.0 and waiting_gap <= 26.0, "L19d Waiting: the code line to the Players label text is 20-26 px, got %s" % waiting_gap)
	await _settle(runner, launcher, "Join")
	var hint: Control = launcher.get_node("Pages/Join/Body/CodeHint")
	var gap: float = _text_top(launcher.get_node("Pages/Join/Body/OwnLabel")) - hint.get_global_rect().end.y
	runner.check(gap >= 20.0 and gap <= 26.0, "L19d Join: the code hint to the You label text is 20-26 px, got %s" % gap)
	await _settle(runner, launcher, "Play", "friend")
	var toggles: Control = launcher.get_node("Pages/Play/Body/Versus")
	var slot: Control = launcher.get_node("Pages/Play/Body/OpenSlot")
	var drawn_top: float = slot.get_global_rect().position.y - slot.get_theme_stylebox("panel").expand_margin_top
	runner.check(drawn_top - toggles.get_global_rect().end.y >= 20.0, "L19d the open slot is drawn 20 px or more under the Opponents toggles, got %s" % (drawn_top - toggles.get_global_rect().end.y))
	built[1].free()
	built[0].free()
	AudioSettings.path = saved
	return true

func test_waiting_two_columns(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("waiting-columns")
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	await _settle(runner, launcher, "Waiting")
	var invite: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left/Invite")
	var link: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left/Invite/Link")
	var copy: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left/Invite/Copy")
	var map: Control = launcher.get_node_or_null("Pages/Waiting/Body/Right/Map")
	var left: Control = launcher.get_node_or_null("Pages/Waiting/Body/Left")
	runner.check(invite != null and link != null and copy != null and map != null and left != null, "L19e Waiting has the invite row and a right-hand map panel")
	if invite != null and link != null and copy != null and map != null and left != null:
		runner.check(link.get_global_rect().end.x <= copy.get_global_rect().position.x and absf(link.get_global_rect().get_center().y - copy.get_global_rect().get_center().y) < 2.0, "L19e Copy sits beside the link field on one row")
		runner.check(map.get_global_rect().position.x >= left.get_global_rect().end.x + 30.0, "L19e the map panel is in a second column")
		runner.check(map.size.x >= 370.0 and map.size.x <= 390.0, "L19e the map panel is about 380 px wide, got %s" % map.size.x)
		runner.check(launcher.get_node("Pages/Waiting/Footer/Cancel").text == "Cancel match" and launcher.get_node("Pages/Waiting/Footer/Status").get_parsed_text() == "Match code K7Q2 · closes in 15:00", "L19e footer shows the match code and Cancel")
	built[1].free()
	built[0].free()
	AudioSettings.path = saved
	return true

const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]

func test_no_selection_colour_on_switches(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "no-selection-colour", {}, true)
	_restore(saved)
	var switches: Array[Node] = launcher.find_children("*", "CheckButton", true, false)
	runner.check(switches.size() >= 6, "U1 fixture: Playtest, Mute, Fullscreen and three Graphics switches exist, got %d" % switches.size())
	var checked: int = 0
	for button: BaseButton in launcher.find_children("*", "BaseButton", true, false):
		if button.theme_type_variation == &"NavButton" or button.theme_type_variation == &"ToggleButton": continue
		for state: String in BUTTON_STATES:
			var style: StyleBox = button.get_theme_stylebox(state)
			checked += 1
			runner.check(not (style is StyleBoxFlat and style.bg_color == SELECTED), "U1 %s draws no selection grey in its %s state" % [button.get_path(), state])
	runner.check(checked > 100, "U1 the sweep covered the controls, got %d state checks" % checked)
	for button: CheckButton in switches:
		var hover: StyleBox = button.get_theme_stylebox("hover")
		var hover_pressed: StyleBox = button.get_theme_stylebox("hover_pressed")
		runner.check(hover is StyleBoxFlat and hover.bg_color.r > FIELD.r and hover.bg_color.r < 0.3, "U1 %s hovers in a slightly lighter field colour" % button.name)
		runner.check(hover_pressed is StyleBoxFlat and hover_pressed.bg_color == hover.bg_color, "U1 %s looks the same hovered on or off" % button.name)
		runner.check(not (button.get_theme_stylebox("pressed") is StyleBoxFlat and button.get_theme_stylebox("pressed").bg_color.a > 0.0), "U1 %s has no fill when on" % button.name)
		var on: Texture2D = button.get_theme_icon("checked")
		var off: Texture2D = button.get_theme_icon("unchecked")
		runner.check(on != null and off != null and on != off and on.resource_path.begins_with("res://ui/") and off.resource_path.begins_with("res://ui/"), "U1 %s shows its state with the launcher's own knob icons" % button.name)
		var on_image: Image = on.get_image()
		var off_image: Image = off.get_image()
		runner.check(_close(on_image.get_pixel(1, 1), SWITCH_LIGHT) and _close(on_image.get_pixel(29, 11), SWITCH_DARK) and _close(on_image.get_pixel(11, 11), SWITCH_LIGHT), "U1b %s on: light track, dark knob on the right" % button.name)
		runner.check(_close(off_image.get_pixel(1, 1), SWITCH_DARK) and _close(off_image.get_pixel(0, 0), SWITCH_GREY) and _close(off_image.get_pixel(11, 11), SWITCH_GREY) and _close(off_image.get_pixel(29, 11), SWITCH_DARK), "U1b %s off: dark track, grey outline, grey knob on the left" % button.name)
	launcher.free()
	return true

func test_mute_is_a_switch(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "mute-switch", {})
	_restore(saved)
	launcher.show_page("Settings")
	await runner.process_frame
	await runner.process_frame
	var mute: Control = launcher.get_node("Pages/Settings/Body/Audio/Volume/Mute")
	var music: Control = launcher.get_node("Pages/Settings/Body/Audio/Volume/Music")
	runner.check(mute is CheckButton and mute.text == "Mute", "U2 Mute is a switch with the word Mute")
	runner.check(mute.size.x <= mute.get_combined_minimum_size().x + 1.0, "U2 Mute is not stretched across the column, got %s" % mute.size.x)
	runner.check(absf(mute.get_global_rect().position.x - music.get_global_rect().position.x) <= 1.0, "U2 Mute is left-aligned with the sliders")
	launcher.free()
	return true

func _launcher_theme() -> Theme:
	return load("res://ui/launcher_theme.tres")

func test_public_sans_font(runner) -> bool:
	var theme: Theme = _launcher_theme()
	var font: Font = theme.default_font
	runner.check(font is FontFile and font.resource_path == REGULAR, "F1 the launcher default font is Public Sans Regular, got %s" % [font.resource_path if font != null else "none"])
	runner.check(font != null and font.has_char(65) and font.get_string_size("Wargrid", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > 30.0, "F1 the ttf imports and measures text")
	for type: String in ["PageTitle", "FieldLabel", "PanelTitle"]:
		var heavy: Font = theme.get_font("font", type)
		runner.check(heavy is FontFile and heavy.resource_path in [SEMIBOLD, BOLD, EXTRABOLD], "F1 %s uses a real Public Sans weight, got %s" % [type, heavy.resource_path])
	var fake: int = 0
	for type: String in theme.get_font_type_list():
		for each: String in theme.get_font_list(type):
			var variation: Font = theme.get_font(each, type)
			if variation is FontVariation and variation.variation_embolden != 0.0: fake += 1
	runner.check(fake == 0, "F1 no fake bold left in the launcher theme, got %d" % fake)
	for file: String in ["PublicSans-Regular.ttf", "PublicSans-SemiBold.ttf", "PublicSans-Bold.ttf", "PublicSans-ExtraBold.ttf"]:
		runner.check(ResourceLoader.exists("res://fonts/" + file) and load("res://fonts/" + file) is FontFile, "F1 %s ships in game/fonts" % file)
	runner.check(FileAccess.file_exists("res://fonts/PublicSans-OFL.txt"), "F1 PublicSans-OFL.txt ships in game/fonts")
	return true

const SEMIBOLD := "res://fonts/PublicSans-SemiBold.ttf"
const BOLD := "res://fonts/PublicSans-Bold.ttf"
const EXTRABOLD := "res://fonts/PublicSans-ExtraBold.ttf"
const MUTED := Color(0.831, 0.831, 0.831)

func _font_path(font: Font) -> String:
	return font.base_font.resource_path if font is FontVariation else font.resource_path

func test_launcher_effective_sizes(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "type", {})
	_restore(saved)
	var theme: Theme = ThemeDB.get_project_theme()
	runner.check(launcher.theme == null, "TH4 the launcher carries no theme of its own")
	runner.check(theme.default_font_size == 16, "T1 the base size is 16 px on the type scale, got %s" % theme.default_font_size)
	for path: String in ["Pages/Play/Body/Own", "Pages/Play/Body/Map", "Pages/Play/Body/Bot", "Pages/Join/Body/Own"]:
		var dropdown: OptionButton = launcher.get_node(path)
		runner.check(_font_path(dropdown.get_theme_font("font")) == SEMIBOLD, "T1 %s value is SemiBold, got %s" % [path, _font_path(dropdown.get_theme_font("font"))])
		runner.check(dropdown.get_theme_color("font_color") == Color.WHITE and dropdown.get_theme_color("font_hover_color") == Color.WHITE, "T1 %s value is white, not muted" % path)
	for side: String in ["BotToggle", "FriendToggle"]:
		var toggle: Button = launcher.get_node("Pages/Play/Body/Opponent/" + side)
		runner.check(_font_path(toggle.get_theme_font("font")) == SEMIBOLD, "T1 %s is SemiBold" % side)
		runner.check(toggle.get_theme_color("font_color") == MUTED and toggle.get_theme_color("font_pressed_color") == Color.WHITE, "T1 %s is muted off and white on" % side)
	for nav: Button in launcher.get_node("Sidebar/Nav").get_children().filter(func(each: Node) -> bool: return each is Button):
		runner.check(_font_path(nav.get_theme_font("font")) == SEMIBOLD and nav.get_theme_color("font_color") == MUTED and nav.get_theme_color("font_pressed_color") == Color.WHITE, "T1 nav %s is SemiBold, muted off and white on" % nav.name)
	var weights: Dictionary = {"PageTitle": [EXTRABOLD, 30], "FieldLabel": [BOLD, 16], "PanelTitle": [BOLD, 16], "Logo": [EXTRABOLD, 24], "PrimaryButton": [EXTRABOLD, 16]}
	for type: String in weights:
		var font: Font = theme.get_font("font", type)
		runner.check(_font_path(font) == weights[type][0] and theme.get_font_size("font_size", type) == weights[type][1], "T1 %s is Public Sans %s at %s px" % [type, "ExtraBold" if weights[type][0] == EXTRABOLD else "Bold", weights[type][1]])
		var controls: Array = launcher.find_children("*", "Control", true, false).filter(func(each: Control) -> bool: return each.theme_type_variation == type)
		runner.check(not controls.is_empty(), "TH4 the launcher has %s controls" % type)
		for control: Control in controls: runner.check(control.get_theme_font_size("font_size") == weights[type][1], "TH4 %s %s reports %s px, got %s" % [type, control.name, weights[type][1], control.get_theme_font_size("font_size")])
	var code: LineEdit = launcher.get_node("Pages/Join/Body/Code")
	var code_size: int = code.get_theme_font_size("font_size")
	var code_style: StyleBox = code.get_theme_stylebox("normal")
	var text_height: float = code.get_theme_font("font").get_height(code_size)
	runner.check(code_size in [16, 24], "TH4 the join code is 16 or 24 px, got %s" % code_size)
	runner.check(code_style.get_margin(SIDE_TOP) + text_height + code_style.get_margin(SIDE_BOTTOM) <= code.custom_minimum_size.y, "TH4 the join code's text fits the %.0f px field, text %.1f" % [code.custom_minimum_size.y, text_height])
	var text_width: float = code.get_theme_font("font").get_string_size("W".repeat(code.max_length), HORIZONTAL_ALIGNMENT_LEFT, -1, code_size).x
	runner.check(code_style.get_margin(SIDE_LEFT) + text_width + code_style.get_margin(SIDE_RIGHT) <= code.custom_minimum_size.x, "TH4 the widest join code fits the %.0f px field across, text %.1f" % [code.custom_minimum_size.x, text_width])
	var logo: Font = theme.get_font("font", "Logo")
	runner.check(logo is FontVariation and logo.spacing_glyph >= 1, "T1 the logo has letter spacing like .wm")
	runner.check(_font_path(theme.get_font("font", "CheckButton")) == REGULAR, "T1 switch labels stay Regular")
	runner.check(theme.get_font_size("font_size", "Tag") == 12, "L27 the tag is 12 px, got %s" % theme.get_font_size("font_size", "Tag"))
	runner.check(launcher.get_node("Pages/Play/Body/Advanced/Toggle/Tag").get_theme_font_size("font_size") == 12, "L27 the advanced fold's tag reports 12 px")
	var muted: Color = theme.get_color("font_color", "Subtitle")
	runner.check(muted == MUTED, "T1 muted text is #d4d4d4 like --muted, got %s" % muted)
	launcher.free()
	return true

func test_font_rendering(runner) -> bool:
	for file: String in ["Regular", "SemiBold", "Bold", "ExtraBold"]:
		var font: FontFile = load("res://fonts/PublicSans-%s.ttf" % file)
		runner.check(font.hinting == TextServer.HINTING_NONE, "T2 Public Sans %s has no hinting, got %s" % [file, font.hinting])
		runner.check(font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_ONE_HALF, "T2 Public Sans %s positions glyphs at half pixels, got %s" % [file, font.subpixel_positioning])
		runner.check(font.antialiasing == TextServer.FONT_ANTIALIASING_GRAY and not font.multichannel_signed_distance_field, "T2 Public Sans %s is grayscale antialiased, no MSDF" % file)
	return true

func test_dropdown_arrow(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "arrow", {})
	_restore(saved)
	for path: String in ["Pages/Play/Body/Own", "Pages/Play/Body/Map", "Pages/Play/Body/Bot", "Pages/Join/Body/Own"]:
		var dropdown: OptionButton = launcher.get_node(path)
		var arrow: Texture2D = dropdown.get_theme_icon("arrow")
		runner.check(arrow.resource_path == "res://ui/dropdown_arrow.svg" and arrow.get_size() == Vector2(10, 5), "T3 %s uses the 10x5 solid triangle, got %s %s" % [path, arrow.resource_path, arrow.get_size()])
		runner.check(dropdown.get_theme_constant("arrow_margin") == 16, "T3 %s leaves 16 px right of the arrow, on the spacing scale, got %s" % [path, dropdown.get_theme_constant("arrow_margin")])
	var image: Image = load("res://ui/dropdown_arrow.svg").get_image()
	runner.check(image.get_pixel(5, 0).a > 0.9 and image.get_pixel(5, 4).a > 0.5 and image.get_pixel(0, 4).a < 0.1, "T3 the arrow points down: wide on top, a point at the bottom")
	launcher.free()
	return true

func test_control_heights(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "heights", {})
	_restore(saved)
	var dropdown: float = launcher.get_node("Pages/Play/Body/Own").get_combined_minimum_size().y
	runner.check(absf(dropdown - 45.0) <= 1.0, "T4 .dd is 11 + 21 + 11 + 2 border = 45 px high, got %s" % dropdown)
	var toggle: float = launcher.get_node("Pages/Play/Body/Opponent/BotToggle").get_combined_minimum_size().y
	runner.check(absf(toggle - 43.0) <= 1.0, "T4 .seg b is 11 + 21 + 11 = 43 px high, got %s" % toggle)
	var nav: float = launcher.get_node("Sidebar/Nav/Play").get_combined_minimum_size().y
	runner.check(absf(nav - 43.0) <= 1.0, "T4 .nav a is 11 + 21 + 11 = 43 px high, got %s" % nav)
	var start: float = launcher.get_node("Pages/Play/Footer/Start").get_combined_minimum_size().y
	runner.check(absf(start - 52.0) <= 1.0, "T4 .go is 14 + 24 + 14 = 52 px high, got %s" % start)
	launcher.free()
	return true

func test_round4_minors(runner) -> bool:
	var theme: Theme = _launcher_theme()
	for type: String in ["LineEdit"]:
		runner.check(_font_path(theme.get_font("font", type)) == SEMIBOLD and theme.get_color("font_color", type) == Color.WHITE, "M1 %s text is SemiBold and white like .in" % type)
	for state: String in ["focus_color", "pressed_color", "hover_pressed_color"]:
		runner.check(theme.get_color("font_" + state, "FooterLink") == MUTED, "M2 FooterLink font_%s stays muted like its normal state" % state)
	runner.check(theme.get_color("font_focus_color", "FooterLink") == theme.get_color("font_color", "FooterLink"), "M2 FooterLink focus text matches its normal text")
	var line := Color("#808080")
	for pair: Array in [["Button", "normal"], ["OptionButton", "normal"], ["LineEdit", "normal"], ["Tag", "normal"]]:
		var style: StyleBox = theme.get_stylebox(pair[1], pair[0])
		runner.check(style is StyleBoxFlat and style.border_color.is_equal_approx(line) and style.border_width_left == 1, "M3 %s border is the CSS --line #808080, got %s" % [pair[0], style.border_color if style is StyleBoxFlat else "no flat style"])
	return true

func test_primary_button_is_amber_with_dark_ink(runner) -> bool:
	var theme: Theme = _launcher_theme()
	for state: String in BUTTON_STATES:
		if state == "focus": continue
		var style: StyleBox = theme.get_stylebox(state, "PrimaryButton")
		runner.check(style is StyleBoxFlat and style.bg_color.h > 0.09 and style.bg_color.h < 0.13 and style.bg_color.s > 0.3, "P1 primary %s fill is amber, got %s" % [state, style.bg_color if style is StyleBoxFlat else "no flat style"])
	runner.check(theme.get_stylebox("normal", "PrimaryButton").bg_color == ACTION, "P1 primary normal fill is #f7c871")
	runner.check(theme.get_stylebox("hover", "PrimaryButton").bg_color.get_luminance() > ACTION.get_luminance(), "P1 primary hover is lighter")
	runner.check(theme.get_stylebox("pressed", "PrimaryButton").bg_color.get_luminance() < ACTION.get_luminance(), "P1 primary pressed is darker")
	runner.check(theme.get_stylebox("disabled", "PrimaryButton").bg_color.get_luminance() < ACTION.get_luminance() * 0.8, "P1 primary disabled is dimmed")
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		runner.check(theme.get_color(colour, "PrimaryButton") == INK, "P2 primary %s is the dark ink, got %s" % [colour, theme.get_color(colour, "PrimaryButton")])
	return true

func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func test_long_dropdown_text_keeps_a_gap(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("round4-gap")
	LauncherSettings.save_picks({"faction": "frc", "bot_faction": "frc", "map": "ashfall"})
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	for page_name: String in ["Play", "Join"]:
		await _settle(runner, launcher, page_name)
		for path: String in ["Own", "Bot"] if page_name == "Play" else ["Own"]:
			var dropdown: OptionButton = launcher.get_node("Pages/%s/Body/%s" % [page_name, path])
			var font: Font = dropdown.get_theme_font("font")
			var text_width: float = font.get_string_size(dropdown.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dropdown.get_theme_font_size("font_size")).x
			var arrow: float = dropdown.get_theme_icon("arrow").get_size().x
			var gap: float = dropdown.size.x - dropdown.get_theme_constant("arrow_margin") - arrow - (dropdown.get_theme_stylebox("normal").get_margin(SIDE_LEFT) + text_width)
			runner.check(dropdown.text == "Free Resistance Coalition" and gap >= 8.0, "M4 %s/%s keeps 8 px between '%s' and the arrow at 1280x720, got %s" % [page_name, path, dropdown.text, gap])
	built[1].free()
	built[0].free()
	_restore(saved)
	return true

func test_footer_error_hugs_text(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "hug", {})
	_restore(saved)
	launcher.show_page("Join")
	launcher._origin = "Join"
	launcher._fail("Cannot connect to relay")
	await runner.process_frame
	await runner.process_frame
	var status: Label = launcher.get_node("Pages/Join/Footer/Status")
	var button: Control = launcher.get_node("Pages/Join/Footer/Join")
	var font: Font = status.get_theme_font("font")
	var text_width: float = font.get_string_size(status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, status.get_theme_font_size("font_size")).x
	runner.check(status.size.x <= text_width + 40.0 and status.get_line_count() == 1, "F3 a short error strip hugs its text, strip %s for text %s" % [status.size.x, text_width])
	var long_text: String = "Your copy of Ashfall differs from the host's, so the match cannot start until both sides run the same build of the game; ask your friend to reload the page. " + "More detail. ".repeat(8)
	launcher._fail(long_text)
	await runner.process_frame
	await runner.process_frame
	runner.check(status.get_line_count() > 1, "F3 a long message wraps, got %d lines" % status.get_line_count())
	runner.check(status.get_global_rect().end.x <= button.get_global_rect().position.x and status.size.x > 400.0, "F3 the wrapped strip stays inside the footer's left area, got %s against the button at %s" % [status.get_global_rect(), button.get_global_rect().position.x])
	launcher._fail("Cannot connect to relay")
	await runner.process_frame
	await runner.process_frame
	runner.check(status.size.x <= text_width + 40.0 and status.get_line_count() == 1, "F3 a short message after a long one hugs again, got %s" % status.size.x)
	launcher.free()
	return true

func test_waiting_bold_codes_and_dashed_slots(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("waiting-bold")
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	await _settle(runner, launcher, "Waiting")
	var footer: Control = launcher.get_node("Pages/Waiting/Footer/Status")
	var hint: Control = launcher.get_node("Pages/Waiting/Body/Left/CodeHint")
	for each: Control in [footer, hint]:
		runner.check(each is RichTextLabel and each.bbcode_enabled and "[b][color=#ffffff]K7Q2[/color][/b]" in each.text, "F4 %s shows the code in bold, got %s" % [each.name, each.text if each is RichTextLabel else "not rich text"])
		runner.check(each is RichTextLabel and each.get_theme_font("bold_font").resource_path == BOLD, "F4 %s bold is real Public Sans Bold" % each.name)
	runner.check(launcher.get_node("Pages/Waiting/Body/Left/Invite/Link").get_theme_font("font").resource_path == SEMIBOLD, "F4 the invite link is Public Sans SemiBold like the other .in fields")
	var dashed: Array[Control] = [launcher.get_node("Pages/Waiting/Body/Left/Two"), launcher.get_node("Pages/Play/Body/OpenSlot")]
	for row: Control in dashed:
		var style: StyleBox = row.get_theme_stylebox("panel")
		runner.check(row.get_script() == DashedPanel and style is StyleBoxFlat and style.border_width_left == 0 and style.border_width_top == 0, "F4 %s draws a dashed outline instead of a solid border" % row.get_path())
	var corners: PackedVector2Array = DashedPanel.edges(Rect2(0, 0, 100, 40))
	runner.check(corners == PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 0), Vector2(100, 40), Vector2(100, 40), Vector2(0, 40), Vector2(0, 40), Vector2(0, 0)]), "F4 the dashed outline has four edges, got %s" % [corners])
	built[1].free()
	built[0].free()
	AudioSettings.path = saved
	return true

class FakeClock extends RefCounted:
	var usec: int = 1_000_000
	func now() -> int: return usec

func _esc() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event

func test_enter_submits_join_code(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "enter-join", {})
	_restore(saved)
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	var code: LineEdit = launcher.get_node("Pages/Join/Body/Code")
	code.text = ""
	code.text_submitted.emit("")
	launcher.set_process(false)
	runner.check(launcher._transport == null and launcher.get_node("Pages/Join/Footer/Status").text == "Enter the 6-character match code", "L19 Enter on an empty code does not connect and says what to enter")
	code.text = "ABC234"
	code.text_submitted.emit("ABC234")
	launcher.set_process(false)
	runner.check(launcher._transport != null and _nav_disabled(launcher) == [true, true, true, true], "L19 Enter on a valid code connects and locks the nav")
	launcher._transport = null
	launcher.free()
	return true

func test_enter_joins_after_link(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("enter-link")
	LauncherScript.code_applied = false
	var launcher = Launcher.instantiate()
	launcher.search = "?code=ABC234"
	runner.root.add_child(launcher)
	await runner.process_frame
	_restore(saved)
	launcher._set_relay(LOOPBACK)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	launcher.get_viewport().push_input(enter)
	launcher.get_viewport().push_input(_key(KEY_ENTER, false))
	launcher.set_process(false)
	runner.check(launcher.current_page == "Join" and launcher._transport != null, "L19b Enter joins on a Join page opened by a link, without clicking the field")
	launcher._transport = null
	launcher.free()
	return true

func test_connecting_elapsed_and_cancel(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "cancel", {"faction": "china", "map": "ashfall"})
	_restore(saved)
	var transport = _host(launcher)
	var cancel: Button = launcher.get_node("Pages/Play/Footer/CancelConnect")
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	var own: String = _picked(launcher.get_node("Pages/Play/Body/Own"))
	var bot: String = _picked(launcher.get_node("Pages/Play/Body/Bot"))
	var map: String = _picked(launcher.get_node("Pages/Play/Body/Map"))
	runner.check(cancel.visible and cancel.text == "Cancel", "L20 busy Play shows the connect Cancel button")
	runner.check(launcher.get_viewport().gui_get_focus_owner() == cancel, "L20 busy Play moves focus to Cancel")
	launcher._show_connecting(launcher._connect_msec + 3200)
	runner.check(status.text == "Connecting… 3 s", "L20 Play shows whole seconds, got '%s'" % status.text)
	cancel.pressed.emit()
	runner.check(transport.close_calls == 1 and status.text == "Match cancelled" and _nav_disabled(launcher) == [false, false, false, false] and not cancel.visible and launcher.opponent == "friend", "L20 Cancel closes, says Match cancelled, unlocks, keeps Friend")
	runner.check(_picked(launcher.get_node("Pages/Play/Body/Own")) == own and _picked(launcher.get_node("Pages/Play/Body/Bot")) == bot and _picked(launcher.get_node("Pages/Play/Body/Map")) == map, "L20 Own, Bot and Map are unchanged")
	runner.check(launcher.get_viewport().gui_get_focus_owner() == launcher.get_node("Pages/Play/Footer/Create"), "L20 Cancel hands focus back to Create")
	status.text = "Idle"
	launcher.get_viewport().push_input(InputEventMIDI.new())
	runner.check(not launcher.get_viewport().is_input_handled(), "L20 fixture: handled flag clear")
	launcher._unhandled_input(_esc())
	runner.check(status.text == "Idle" and not launcher.get_viewport().is_input_handled(), "L20 Esc without a transport changes nothing and is not swallowed")
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	launcher.get_node("Pages/Join/Body/Code").text = "ABC234"
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	launcher.set_process(false)
	var join_transport := OnlineTests.FakeTransport.new()
	launcher._transport = join_transport
	runner.check(launcher.get_node("Pages/Join/Footer/CancelConnect").visible, "L20 busy Join shows the connect Cancel button")
	launcher.get_node("Pages/Join/Body/Code").text = "XYZ234"
	launcher._join()
	runner.check(launcher._transport == join_transport, "L20 a second Join while connecting keeps the first connection")
	launcher._unhandled_input(_esc())
	runner.check(join_transport.close_calls == 1 and launcher.get_node("Pages/Join/Footer/Status").text == "Match cancelled" and launcher.current_page == "Join", "L20 Esc cancels a connecting Join, reason in Join's footer")
	var host = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	launcher._unhandled_input(_esc())
	runner.check(host.close_calls == 0 and launcher.current_page == "Waiting", "L20 Esc on Waiting leaves the lobby open")
	launcher._transport = null
	launcher.free()
	return true

func test_connecting_footers_fit(runner) -> bool:
	var saved: String = AudioSettings.path
	var ported: Array = await _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	_restore(saved)
	var launcher = ported[1]
	launcher.set_opponent("friend")
	launcher._set_busy(true)
	for page_name: String in ["Play", "Join"]:
		launcher.show_page(page_name)
		for shown: Array in [["Connecting… 12 s", false], ["Cannot connect to relay", true]]:
			var status: Label = launcher.get_node("Pages/%s/Footer/Status" % page_name)
			launcher._show_status(status, shown[0], shown[1])
			await runner.process_frame
			await runner.process_frame
			runner.check(status.visible and status.text == shown[0] and status.size.x > 0.0, "L8 fixture: %s footer shows '%s'" % [page_name, shown[0]])
			_overlap_free(runner, launcher.get_node("Pages/%s/Footer" % page_name), "%s busy footer, '%s'" % [page_name, shown[0]])
			var footer: Control = launcher.get_node("Pages/%s/Footer" % page_name)
			for child: Control in [status, launcher.get_node("Pages/%s/Footer/CancelConnect" % page_name)]:
				runner.check(footer.get_global_rect().encloses(child.get_global_rect()) and launcher.get_viewport().get_visible_rect().encloses(child.get_global_rect()), "L8 %s busy footer holds %s with '%s'" % [page_name, child.name, shown[0]])
	ported[0].free()
	return true

func _fake_clock_launcher(launcher, transport_clock: FakeClock) -> Object:
	launcher._clock = transport_clock.now
	launcher._set_relay(LOOPBACK)
	launcher.set_opponent("friend")
	launcher.get_node("Pages/Play/Footer/Create").pressed.emit()
	var transport := RelayTransport.new(transport_clock.now)
	transport._sent_any = true
	transport._last_rx = transport_clock.usec
	launcher._transport = transport
	launcher._connect_msec = floori(transport_clock.usec / 1000.0)
	launcher._welcome_msec = -1
	return transport

func test_lobby_countdown_and_expiry(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "countdown", {})
	_restore(saved)
	var transport = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var footer: RichTextLabel = launcher.get_node("Pages/Waiting/Footer/Status")
	runner.check(transport.patient and footer.get_parsed_text() == "Match code ABC234 · closes in 15:00", "L21 welcome makes the transport patient and starts the countdown, got '%s'" % footer.get_parsed_text())
	for case: Array in [[61_000, "13:59"], [900_000, "0:00"], [1_000_000, "0:00"]]:
		launcher._show_countdown(launcher._welcome_msec + case[0])
		runner.check(footer.get_parsed_text() == "Match code ABC234 · closes in " + case[1], "L21 +%d ms shows %s, got '%s'" % [case[0], case[1], footer.get_parsed_text()])
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(status.text == "Your friend did not join in time" and status.theme_type_variation == &"FooterError" and launcher.current_page == "Play", "L21 lobby expired fails with the friend message in the error style")
	launcher.free()
	return true

func test_hidden_host_survives_lobby(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "hidden", {})
	_restore(saved)
	var clock := FakeClock.new()
	_fake_clock_launcher(launcher, clock)
	launcher._hello_sent = true
	launcher.set_process(false)
	clock.usec += 6_000_000
	launcher._process(0.0)
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(status.text == "Connection to relay lost", "L22 before welcome 6 s of silence is a lost relay, got '%s'" % status.text)
	var transport = _fake_clock_launcher(launcher, clock)
	launcher._hello_sent = true
	launcher.set_process(false)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	clock.usec += 600_000_000
	launcher._process(0.0)
	runner.check(launcher.current_page == "Waiting" and transport.patient, "L22 after welcome 600 s of silence keeps the lobby")
	clock.usec += 301_000_000
	launcher._process(0.0)
	runner.check(status.text == "Connection to relay lost" and launcher.current_page == "Play", "L22 at 901 s the lobby reports a lost relay")
	launcher.free()
	return true

func test_ticking_texts_through_process(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "ticking", {})
	_restore(saved)
	var clock := FakeClock.new()
	_fake_clock_launcher(launcher, clock)
	launcher._hello_sent = true
	launcher.set_process(false)
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	clock.usec += 3_200_000
	launcher._process(0.0)
	runner.check(status.text == "Connecting… 3 s", "L23 _process moves the connecting text, got '%s'" % status.text)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	clock.usec += 1_000_000
	launcher._process(0.0)
	var footer: RichTextLabel = launcher.get_node("Pages/Waiting/Footer/Status")
	runner.check(footer.get_parsed_text() == "Match code ABC234 · closes in 14:59", "L23 _process moves the countdown, got '%s'" % footer.get_parsed_text())
	launcher.free()
	return true

func _key(code: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _focused(launcher) -> Control:
	return launcher.get_viewport().gui_get_focus_owner()

func _count_presses(button: BaseButton) -> Array[int]:
	var count: Array[int] = [0]
	for connection: Dictionary in button.pressed.get_connections(): button.pressed.disconnect(connection.callable)
	button.pressed.connect(func() -> void: count[0] += 1)
	return count

func test_default_focus(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "default-focus", {})
	_restore(saved)
	var play: Node = launcher.get_node("Pages/Play")
	var join: Node = launcher.get_node("Pages/Join")
	runner.check(_focused(launcher) == play.get_node("Footer/Start"), "L24 Play with a bot focuses Start, got %s" % _focused(launcher))
	play.get_node("Body/Opponent/FriendToggle").pressed.emit()
	runner.check(_focused(launcher) == play.get_node("Footer/Create"), "L24 the Friend toggle moves focus to Create, got %s" % _focused(launcher))
	play.get_node("Body/Opponent/BotToggle").pressed.emit()
	runner.check(_focused(launcher) == play.get_node("Footer/Start"), "L24 the Bot toggle moves focus to Start, got %s" % _focused(launcher))
	join.get_node("Body/Code").text = ""
	launcher.show_page("Join")
	runner.check(_focused(launcher) == join.get_node("Body/Code"), "L24 Join with an empty code focuses the code field, got %s" % _focused(launcher))
	join.get_node("Body/Code").text = "ABC234"
	launcher.show_page("Join")
	runner.check(_focused(launcher) == join.get_node("Footer/Join"), "L24 Join with a code focuses the Join button, got %s" % _focused(launcher))
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(launcher.current_page == "Waiting" and _focused(launcher) == launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy"), "L24 Waiting focuses Copy, got %s" % _focused(launcher))
	launcher._transport = null
	launcher.free()
	return true

func test_stray_enter_does_nothing(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "stray-enter", {})
	_restore(saved)
	var started: Array[int] = _count_presses(launcher.get_node("Pages/Play/Footer/Start"))
	var viewport: Viewport = launcher.get_viewport()
	viewport.push_input(_key(KEY_ENTER, false))
	viewport.push_input(_key(KEY_ENTER, true, true))
	viewport.push_input(_key(KEY_ENTER, false))
	runner.check(started[0] == 0 and launcher._transport == null, "L24 a release or echo from the previous screen's Enter does not start the match, pressed %d times" % started[0])
	viewport.push_input(_key(KEY_ENTER, true))
	viewport.push_input(_key(KEY_ENTER, false))
	runner.check(started[0] == 1, "L24 fixture: a full Enter press does start it, pressed %d times" % started[0])
	launcher.free()
	return true

func test_enter_after_faction_pick(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "enter-pick", {})
	_restore(saved)
	var started: Array[int] = _count_presses(launcher.get_node("Pages/Play/Footer/Start"))
	for path: String in ["Pages/Play/Body/Own", "Pages/Play/Body/Bot", "Pages/Play/Body/Map"]:
		var selector: OptionButton = launcher.get_node(path)
		selector.select(1)
		selector.item_selected.emit(1)
		runner.check(_focused(launcher) == launcher.get_node("Pages/Play/Footer/Start") and started[0] == 0, "L25 picking in %s focuses Start without pressing it, got %s" % [path, _focused(launcher)])
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	launcher.get_node("Pages/Join/Body/Code").text = "ABC234"
	var own: OptionButton = launcher.get_node("Pages/Join/Body/Own")
	own.select(1)
	own.item_selected.emit(1)
	runner.check(_focused(launcher) == launcher.get_node("Pages/Join/Footer/Join"), "L25 picking a faction on Join focuses Join, got %s" % _focused(launcher))
	launcher.get_viewport().push_input(_key(KEY_ENTER, true))
	launcher.get_viewport().push_input(_key(KEY_ENTER, false))
	runner.check(launcher._transport != null, "L25 Enter right after the pick joins")
	launcher.set_process(false)
	launcher._transport = null
	launcher.free()
	return true

func _small_targets(launcher: Node) -> Array[String]:
	var controls: Array[Control] = []
	_visible_controls(launcher, controls)
	var small: Array[String] = []
	for control in controls:
		if (control is BaseButton or control is OptionButton or control is LineEdit) and control.size.y < 32.0:
			small.append("%s %.1f" % [launcher.get_path_to(control), control.size.y])
	return small

func test_click_targets_32(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("targets")
	var setup: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	_restore(saved)
	var launcher = setup[1]
	for view: Array in [["Play", "bot"], ["Play", "friend"], ["Join", "bot"], ["Settings", "bot"], ["Credits", "bot"], ["Waiting", "bot"]]:
		await _settle(runner, launcher, view[0], view[1])
		var small: Array[String] = _small_targets(launcher)
		runner.check(small.is_empty(), "L26 every click target on %s (%s) is at least 32 px high, got %s" % [view[0], view[1], small])
	setup[1].free()
	setup[0].free()
	return true

func test_quit_button(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("quit")
	var desktop = Launcher.instantiate()
	desktop.web = false
	runner.root.add_child(desktop)
	await runner.process_frame
	_restore(saved)
	var quit: Button = desktop.get_node("Sidebar/Nav/Quit")
	var nav: Node = desktop.get_node("Sidebar/Nav")
	var calls: Array[int] = [0]
	desktop.quit = func() -> void: calls[0] += 1
	runner.check(quit.visible and quit.get_index() > nav.get_node("Credits").get_index() and not quit.toggle_mode, "L28 Quit shows after Credits off the web and is no toggle")
	quit.pressed.emit()
	runner.check(calls[0] == 1, "L28 pressing Quit calls quit once, got %d" % calls[0])
	desktop._set_relay(LOOPBACK)
	desktop._connect("")
	desktop.set_process(false)
	runner.check(quit.disabled, "L28 connecting locks Quit")
	desktop._transport = null
	desktop._fail("x")
	runner.check(not quit.disabled, "L28 a failure unlocks Quit")
	desktop.free()
	var web = Launcher.instantiate()
	web.web = true
	runner.root.add_child(web)
	await runner.process_frame
	runner.check(not web.get_node("Sidebar/Nav/Quit").visible, "L28 Quit is hidden on the web")
	web.free()
	return true

func test_invite_label(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("invite-label")
	var labels: Array[String] = []
	for page_url: String in ["", "https://wargrid-web-test.fly.dev/"]:
		var launcher = Launcher.instantiate()
		launcher.page = page_url
		runner.root.add_child(launcher)
		await runner.process_frame
		labels.append("%s|%s" % [launcher.get_node("Pages/Waiting/Body/Left/InviteLabel").text, launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").text])
		launcher.free()
	_restore(saved)
	runner.check(labels == ["Match code|Copy code", "Invite link|Copy link"], "L29 the label and Copy follow the page, got %s" % [labels])
	return true

const FOCUS_RING := Color("#e6e6e6")
# hover fills as shipped before the focus ring; null means the hover style has no fill
const HOVER_FILLS: Dictionary = {"Button": Color(0.22, 0.22, 0.22), "OptionButton": Color(0.22, 0.22, 0.22), "NavButton": Color(0.22, 0.22, 0.22), "ToggleButton": Color(0.22, 0.22, 0.22), "PrimaryButton": Color(0.98039216, 0.83137256, 0.5411765), "CheckButton": Color(0.22, 0.22, 0.22), "FooterLink": null}

func test_focus_differs_from_hover(runner) -> bool:
	var theme: Theme = _launcher_theme()
	for type: String in HOVER_FILLS:
		var focus: StyleBox = theme.get_stylebox("focus", type)
		var hover: StyleBox = theme.get_stylebox("hover", type)
		runner.check(focus is StyleBoxFlat and focus != hover, "L30 %s focus is its own style, not the hover style" % type)
		if not focus is StyleBoxFlat: continue
		var ring: StyleBoxFlat = focus
		runner.check(not ring.draw_center and ring.border_color == FOCUS_RING, "L30 %s focus is an unfilled #e6e6e6 ring" % type)
		runner.check(ring.border_width_left == 2 and ring.border_width_top == 2 and ring.border_width_right == 2 and ring.border_width_bottom == 2, "L30 %s focus ring is 2 px on every side" % type)
		runner.check(ring.expand_margin_left == 4.0 and ring.expand_margin_top == 4.0 and ring.expand_margin_right == 4.0 and ring.expand_margin_bottom == 4.0, "L30 %s focus ring floats 4 px outside the button" % type)
		runner.check(ring.corner_radius_top_left <= 2 and ring.corner_radius_bottom_right <= 2, "L30 %s focus ring radius is at most 2, like the button" % type)
		var fill: Variant = HOVER_FILLS[type]
		var unchanged: bool = not hover is StyleBoxFlat if fill == null else hover is StyleBoxFlat and hover.bg_color.is_equal_approx(fill)
		runner.check(unchanged, "L30 %s hover style is unchanged" % type)
	return true

func test_focus_ring_fits(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("focus-ring-fits")
	var setup: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	_restore(saved)
	var launcher = setup[1]
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for page: Array in [["Play", "bot"], ["Play", "friend"], ["Join", "bot"], ["Settings", "bot"], ["Credits", "bot"], ["Waiting", "bot"]]:
		await _settle(runner, launcher, page[0], page[1])
		var clipped: Array[String] = []
		for button: BaseButton in launcher.find_children("*", "BaseButton", true, false):
			var focus: StyleBox = button.get_theme_stylebox("focus")
			if button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE and focus is StyleBoxFlat and not view.encloses(button.get_global_rect().grow(focus.expand_margin_left)):
				clipped.append(str(launcher.get_path_to(button)))
		runner.check(clipped.is_empty(), "L30 every focus ring on %s (%s) stays inside the 1280x720 window, clipped: %s" % [page[0], page[1], clipped])
	setup[1].free()
	setup[0].free()
	return true

class OpenTransport extends OnlineTests.FakeTransport:
	func is_open() -> bool: return true

const TEAM_PLAY_MAPS: Array[String] = ["broken_crown", "ashfall"]
const VERSION_LINE := "Your friend’s game is a different version from yours (v%s)."

func _team_launcher(runner, name: String, picks: Dictionary):
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, name, picks)
	_restore(saved)
	launcher.set_opponent("team")
	return launcher

func _map_ids(launcher) -> Array[String]:
	var selector: OptionButton = launcher.get_node("Pages/Play/Body/Map")
	var ids: Array[String] = []
	for i in selector.item_count: ids.append(selector.get_item_metadata(i))
	return ids

func _pick(selector: OptionButton, id: String) -> void:
	var index: int = _index_where(selector, func(item: String) -> bool: return item == id)
	selector.select(index)
	selector.item_selected.emit(index)

# Creates a team match and sends the hello through a transport that is already open.
func _host_team(launcher, bots: Array = ["china", "frc"]) -> Object:
	launcher._set_relay(LOOPBACK)
	launcher.set_opponent("team")
	_pick(launcher.get_node("Pages/Play/Body/TeamBots/Bot3"), bots[0])
	_pick(launcher.get_node("Pages/Play/Body/TeamBots/Bot4"), bots[1])
	launcher.get_node("Pages/Play/Footer/Create").pressed.emit()
	launcher.set_process(false)
	var transport := OpenTransport.new()
	launcher._transport = transport
	launcher._process(0.0)
	return transport

func _hello(transport) -> Dictionary:
	for text: String in transport.sent:
		var message: Dictionary = Wire.decode(text).message
		if message.get("type") == "hello": return message
	return {}

# The start goes through the wire, so its numbers arrive as floats like the relay's.
func _start_through_wire(runner, launcher, message: Dictionary) -> Array:
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._seat = 1
	launcher._handle(Wire.encode(message))
	var got: Array = [SkirmishMain.factions, SkirmishMain.starts]
	var main = runner.root.get_tree().current_scene
	if main != null and main != launcher: got.append(main.driver.pump.live().snapshot())
	if main != null and main != launcher: main.free()
	await runner.process_frame
	return got

func test_mode_row_two_modes(runner) -> bool:
	var launcher = await _team_launcher(runner, "modes", {})
	launcher.set_opponent("bot")
	var play: Control = launcher.get_node("Pages/Play")
	var row: Control = play.get_node("Body/Opponent")
	var versus: Control = play.get_node("Body/Versus")
	var names: Array = row.get_children().map(func(each: Node) -> String: return each.name)
	var texts: Array = row.get_children().map(func(each: Button) -> String: return each.text)
	runner.check(names == ["BotToggle", "FriendToggle"] and texts == ["vs Bot", "vs Friend"], "M7 the mode row is vs Bot and vs Friend only, got %s %s" % [names, texts])
	runner.check(play.get_node("Body/OpponentLabel").text == "Mode" and not versus.visible, "M7 the row's label is Mode; no Opponents choice on the bot path")
	var none: Button = versus.get_node("NoneToggle")
	var bots: Button = versus.get_node("BotsToggle")
	row.get_node("FriendToggle").pressed.emit()
	runner.check(versus.visible and versus.get_node("Label").text == "Opponents" and none.text == "none" and bots.text == "2 bots", "M7 vs Friend shows Opponents: none, 2 bots, got '%s' '%s' '%s'" % [versus.get_node("Label").text, none.text, bots.text])
	runner.check(launcher.opponent == "friend" and none.button_pressed and not bots.button_pressed and not play.get_node("Body/TeamBots").visible and play.get_node("Subtitle").text == "Set up a match against a bot or a friend.", "M7 vs Friend opens on none, today's 1v1")
	bots.pressed.emit()
	runner.check(launcher.opponent == "team" and bots.button_pressed and not none.button_pressed and row.get_node("FriendToggle").button_pressed and not row.get_node("BotToggle").button_pressed, "M7 2 bots selects the team mode under vs Friend")
	runner.check(play.get_node("Footer/Create").visible and not play.get_node("Footer/Start").visible and play.get_node("Body/OpenSlot").visible and play.get_node("Body/TeamBots").visible and not play.get_node("Body/Bot").visible, "M7 2 bots creates a match with an open slot and the bot rows")
	runner.check(play.get_node("Subtitle").text == "Team up with a friend against two bots." and play.get_node("Footer/Status").text == LauncherScript.FRIEND_HINT, "M7 team subtitle and footer hint, got '%s'" % play.get_node("Subtitle").text)
	row.get_node("FriendToggle").pressed.emit()
	runner.check(launcher.opponent == "team" and row.get_node("FriendToggle").button_pressed, "M7 pressing vs Friend again keeps 2 bots")
	none.pressed.emit()
	runner.check(launcher.opponent == "friend" and none.button_pressed and not play.get_node("Body/TeamBots").visible, "M7 none goes back to the 1v1 path")
	await runner.process_frame
	await runner.process_frame
	runner.check(absf(row.get_node("BotToggle").size.x - row.get_node("FriendToggle").size.x) < 1.0 and absf(none.size.x - bots.size.x) < 1.0, "M7 each row's two toggles share its width, got %s %s" % [row.get_node("BotToggle").size.x, none.size.x])
	launcher.free()
	return true

func test_team_mode_shows_bot_rows(runner) -> bool:
	var launcher = await _team_launcher(runner, "bot-rows", {})
	var bots: Control = launcher.get_node("Pages/Play/Body/TeamBots")
	for mode: String in ["bot", "friend", "team"]:
		launcher.set_opponent(mode)
		runner.check(bots.visible == (mode == "team") and launcher.get_node("Pages/Play/Body/MapHidden").visible == (mode == "team"), "M8 the bot rows show on the team path only, %s" % mode)
	runner.check(bots.get_node("Label").text == "Enemy bots", "M8 the bot rows are headed Enemy bots")
	for path: String in ["Bot3", "Bot4"]:
		var selector: OptionButton = bots.get_node(path)
		runner.check(selector.item_count == 3 and selector.get_item_text(1) == "Free Resistance Coalition", "M8 %s lists the factions by display name" % path)
	launcher.free()
	return true

func test_team_bot_factions_remembered(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("team-bots-defaults")
	var defaults: Array[String] = LauncherSettings.load_team_bots()
	var config := ConfigFile.new()
	config.set_value("launcher", "team_bot_1", "china")
	config.set_value("launcher", "team_bot_2", "gla")
	config.save(AudioSettings.path)
	var fallback: Array[String] = LauncherSettings.load_team_bots()
	_restore(saved)
	runner.check(defaults == ["usa", "usa"], "M9 without a file both bots are the default faction, got %s" % [defaults])
	runner.check(fallback == ["china", "usa"], "M9 a bad stored bot falls back alone, got %s" % [fallback])
	var before: Array = OnlineTests._statics()
	AudioSettings.path = scratch_for("team-bots")
	LauncherSettings.save_picks({"team_bot_1": "frc", "team_bot_2": "china"})
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	launcher.set_opponent("team")
	var bots: Control = launcher.get_node("Pages/Play/Body/TeamBots")
	runner.check(bots.get_node("Bot3").item_count == 3 and _picked(bots.get_node("Bot3")) == "frc" and _picked(bots.get_node("Bot4")) == "china", "M9 the bot rows show the remembered picks")
	_host_team(launcher, ["china", "usa"])
	await _start_through_wire(runner, launcher, OnlineTests.new()._start_message_2v2(5))
	var stored: Array[String] = LauncherSettings.load_team_bots()
	var picks: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(stored == ["china", "frc"], "M9 the host's start remembers the bots it played, got %s" % [stored])
	runner.check(picks.bot_faction == "usa", "M9 the team bots leave the 1v1 bot pick alone, got %s" % picks.bot_faction)
	return true

func test_team_mode_hides_small_maps(runner) -> bool:
	var launcher = await _team_launcher(runner, "small-maps", {"map": "dry_wells"})
	for id: String in MatchSettings.PLAY_MAPS:
		var starts: int = JSON.parse_string(FileAccess.get_file_as_string(MatchSettings.map_path(id))).starts.size()
		runner.check((id in _map_ids(launcher)) == (starts >= 4), "M10 %s (%d starts) listed on the team path only with four or more" % [id, starts])
	runner.check(_map_ids(launcher) == TEAM_PLAY_MAPS, "M10 the team path lists %s, got %s" % [TEAM_PLAY_MAPS, _map_ids(launcher)])
	launcher.set_opponent("friend")
	runner.check(_map_ids(launcher) == MatchSettings.PLAY_MAPS.keys() and launcher._map_id() == "dry_wells", "M10 vs Friend lists every map and keeps the remembered one, got %s %s" % [_map_ids(launcher), launcher._map_id()])
	launcher.set_opponent("team")
	_pick(launcher.get_node("Pages/Play/Body/Map"), "ashfall")
	launcher.set_opponent("bot")
	runner.check(_map_ids(launcher) == MatchSettings.PLAY_MAPS.keys() and launcher._map_id() == "ashfall", "M10 a map picked on the team path stays picked, got %s" % launcher._map_id())
	launcher.set_opponent("team")
	runner.check(launcher._map_id() == "ashfall", "M10 a listed remembered map stays selected on the team path, got %s" % launcher._map_id())
	launcher.free()
	return true

func test_hidden_map_muted_line(runner) -> bool:
	var launcher = await _team_launcher(runner, "hidden-map", {"map": "dry_wells"})
	var line: Label = launcher.get_node("Pages/Play/Body/MapHidden")
	runner.check(line.visible and line.text == "Dry Wells has 2 start positions; team matches need 4.", "M11 the hidden remembered map gets the muted line, got '%s'" % line.text)
	runner.check(line.theme_type_variation == &"Hint" and launcher._map_id() == "broken_crown" and launcher.get_node("Pages/Play/Body/MapInfo").text == launcher._map_info("broken_crown"), "M11 muted, and the first team map is shown with its info")
	_pick(launcher.get_node("Pages/Play/Body/Map"), "ashfall")
	runner.check(line.text.is_empty(), "M11 picking a team map drops the line, got '%s'" % line.text)
	launcher.free()
	launcher = await _team_launcher(runner, "listed-map", {"map": "broken_crown"})
	runner.check(launcher.get_node("Pages/Play/Body/MapHidden").text.is_empty(), "M11 no line when the remembered map is listed")
	launcher.set_opponent("bot")
	runner.check(not launcher.get_node("Pages/Play/Body/MapHidden").visible, "M11 the line stays off the bot path")
	launcher.free()
	return true

func _bot_rows(settings: Dictionary) -> Array:
	return settings.get("bots", []).map(func(row: Dictionary) -> Array: return [row.player, row.faction])

func test_team_hello_carries_bots(runner) -> bool:
	var launcher = await _team_launcher(runner, "team-hello", {"map": "ashfall"})
	var team: Dictionary = _hello(_host_team(launcher)).get("settings", {})
	var plain: Dictionary = MatchSettings.for_map("ashfall")
	runner.check(team.get("map") == "ashfall" and team.get("map_hash") == plain.map_hash and _bot_rows(team) == [[3.0, "china"], [4.0, "frc"]], "M12 the team hello carries the map and both bots, got %s" % [team])
	launcher._fail(LauncherScript.CANCELLED)
	_host(launcher)
	var open := OpenTransport.new()
	launcher._transport = open
	launcher._process(0.0)
	var friend: Dictionary = _hello(open).get("settings", {})
	runner.check(friend == {"map": "ashfall", "map_hash": plain.map_hash}, "M12 vs Friend keeps the 1v1 hello, got %s" % [friend])
	launcher._transport = null
	launcher.free()
	return true

func test_team_controls_locked_while_connecting(runner) -> bool:
	var launcher = await _team_launcher(runner, "team-lock", {"map": "ashfall"})
	var transport = _host_team(launcher, ["frc", "china"])
	var paths: Array[String] = ["Body/Opponent/BotToggle", "Body/Opponent/FriendToggle", "Body/Versus/NoneToggle", "Body/Versus/BotsToggle", "Body/TeamBots/Bot3", "Body/TeamBots/Bot4"]
	var locked: Array = paths.map(func(path: String) -> bool: return launcher.get_node("Pages/Play/" + path).disabled)
	runner.check(locked == [true, true, true, true, true, true], "M13 connecting locks all four toggles and both bot pickers, got %s" % [locked])
	runner.check(_drawn_selected(launcher.get_node("Pages/Play/Body/Versus/BotsToggle")), "M13 the locked 2 bots toggle still draws the selection grey")
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var sent: Array = _hello(transport).get("settings", {}).get("bots", []).map(func(row: Dictionary) -> String: return Registry.faction(row.faction).display_name + " (bot)")
	var shown: Array = ["Three", "Four"].map(func(row: String) -> String: return launcher.get_node("Pages/Waiting/Body/Left/%s/Row/Who" % row).text)
	runner.check(sent == ["Free Resistance Coalition (bot)", "China (bot)"] and shown == sent, "M13 the waiting view shows the bots the hello sent, sent %s shown %s" % [sent, shown])
	launcher._fail("Connection to relay lost")
	locked = paths.map(func(path: String) -> bool: return launcher.get_node("Pages/Play/" + path).disabled)
	runner.check(locked == [false, false, false, false, false, false] and launcher.opponent == "team", "M13 a failure unlocks them and stays on the team path, got %s" % [locked])
	launcher.free()
	return true

func test_waiting_lists_bot_slots(runner) -> bool:
	var launcher = await _team_launcher(runner, "team-waiting", {"faction": "usa", "map": "broken_crown"})
	_host_team(launcher, ["china", "frc"])
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var left: Control = launcher.get_node("Pages/Waiting/Body/Left")
	runner.check(launcher.current_page == "Waiting" and left.get_node("PlayersLabel").text == "Your team" and left.get_node("BotsLabel").visible and left.get_node("BotsLabel").text == "Enemy bots", "M14 Waiting groups Your team and Enemy bots")
	runner.check(_texts(left.get_node("One")) == ["1", "You", "United States", "READY"] and "Open" in _texts(left.get_node("Two")), "M14 the host's row, then the open friend slot, got %s" % [_texts(left.get_node("One"))])
	var rows: Array = [["Three", ["3", "China (bot)", "READY"], Palette.OWNER_BASE[1]], ["Four", ["4", "Free Resistance Coalition (bot)", "READY"], Palette.OWNER_BASE[6]]]
	for row: Array in rows:
		var panel: Control = left.get_node(row[0])
		var edge: StyleBox = panel.get_theme_stylebox("panel")
		runner.check(panel.visible and _texts(panel) == row[1], "M14 bot slot %s reads %s, got %s" % [row[0], row[1], _texts(panel)])
		runner.check(edge is StyleBoxFlat and edge.border_color == row[2] and edge.border_width_left == 4, "M14 bot slot %s has its owner colour on the left edge" % row[0])
	var own: StyleBox = left.get_node("One").get_theme_stylebox("panel")
	runner.check(own is StyleBoxFlat and own.border_color == Palette.OWNER_BASE[0], "M14 your row has your colour on the left edge")
	launcher._cancel()
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var plain: StyleBox = left.get_node("One").get_theme_stylebox("panel")
	runner.check(left.get_node("PlayersLabel").text == "Players" and not left.get_node("BotsLabel").visible and not left.get_node("Three").visible and not left.get_node("Four").visible, "M14 a 1v1 Waiting view lists no bot slot")
	runner.check(plain is StyleBoxFlat and plain.border_color != Palette.OWNER_BASE[0], "M14 a 1v1 Waiting view keeps the plain row edge")
	launcher._transport = null
	launcher.free()
	return true

func test_waiting_edges_neon(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-waiting-neon", {"faction": "usa", "map": "broken_crown"})
	GraphicsSettings.save_neon(true)
	_host_team(launcher, ["china", "frc"])
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var left: Control = launcher.get_node("Pages/Waiting/Body/Left")
	var edges: Array = ["One", "Three", "Four"].map(func(row: String) -> Color: return (left.get_node(row).get_theme_stylebox("panel") as StyleBoxFlat).border_color)
	var want: Array = [Palette.OWNER_BRIGHT[0], Palette.OWNER_BRIGHT[Palette.BOT_SLOTS[0][1]], Palette.OWNER_BRIGHT[Palette.BOT_SLOTS[1][1]]]
	runner.check(edges == want, "M14 under Neon the Waiting edges use the Neon hues the match will show, got %s want %s" % [edges, want])
	launcher._transport = null
	launcher.free()
	_restore(saved)
	return true

func test_start_sets_bot_factions_and_teams(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-start", {})
	_restore(saved)
	AudioSettings.path = scratch_for("team-start-picks")
	var message: Dictionary = OnlineTests.new()._start_message_2v2(7)
	var got: Array = await _start_through_wire(runner, launcher, message)
	var keys: Array = got[0].keys().map(func(key: Variant) -> int: return typeof(key))
	runner.check(got[0] == {3: "china", 4: "frc"} and keys == [TYPE_INT, TYPE_INT], "M15 the start's bot factions reach the match with integer keys, got %s %s" % [got[0], keys])
	var team_starts: Array[int] = MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2))
	runner.check(got[1] == team_starts and got[1].size() == 4, "M15 the starts follow the teams, got %s, want %s" % [got[1], team_starts])
	var players: Array = got[2].players if got.size() > 2 else []
	var factions: Array = players.map(func(player: Dictionary) -> String: return player.get("faction", ""))
	runner.check(factions == ["", "", "china", "frc"] and got[2].match.status == "setup", "M15 the bots are seated with their factions, so setup can end, got %s" % [factions])
	launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	got = await _start_through_wire(runner, launcher, OnlineTests.new()._start_message("ashfall", 7))
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(got[0] == {} and got[1] == MatchSettings.starts("ashfall", 7), "M15 a 1v1 start passes no bot factions and the 1v1 starts, got %s %s" % [got[0], got[1]])
	return true

func test_guest_start_matches_host(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "guest-start", {"map": "dry_wells"})
	var message: Dictionary = OnlineTests.new()._start_message_2v2(7)
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._seat = 2
	launcher._handle(Wire.encode(message))
	var got: Array = [SkirmishMain.factions, SkirmishMain.starts]
	var main = runner.root.get_tree().current_scene
	if main != null and main != launcher: main.free()
	await runner.process_frame
	var stored: Array[String] = LauncherSettings.load_team_bots()
	var map: String = LauncherSettings.load_picks().map
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(got[0] == {3: "china", 4: "frc"} and got[1] == MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2)), "M18 the guest seats the host's bots on the host's team starts, got %s %s" % [got[0], got[1]])
	runner.check(stored == ["usa", "usa"] and map == "dry_wells", "M18 the guest remembers neither the host's bots nor its map, got %s %s" % [stored, map])
	return true

func _version_footer(runner, launcher, web: bool) -> Label:
	launcher.web = web
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	launcher.get_node("Pages/Join/Body/Code").text = "ABC234"
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	launcher.set_process(false)
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._handle('{"type":"error","reason":"build mismatch"}')
	await runner.process_frame
	await runner.process_frame
	return launcher.get_node("Pages/Join/Footer/Status")

func test_version_mismatch_plain_line(runner) -> bool:
	var line: String = VERSION_LINE % ProjectSettings.get_setting("application/config/version")
	var seen: Array[String] = []
	for web: bool in [false, true]:
		var saved: String = AudioSettings.path
		var launcher = await _launcher_with(runner, "version", {})
		_restore(saved)
		var status: Label = await _version_footer(runner, launcher, web)
		runner.check(status.text == line and status.theme_type_variation == &"FooterError", "M16 the refused joiner reads the version line (web %s), got '%s'" % [web, status.text])
		runner.check(launcher.current_page == "Join" and launcher._transport == null, "M16 the joiner stays on Join, disconnected")
		seen.append(status.text)
		launcher.free()
	runner.check(seen[0] == seen[1], "M16 browser and desktop read the same line")
	return true

func _layout_ok(runner, launcher, root: Control, label: String) -> void:
	var view: Rect2 = launcher.get_viewport().get_visible_rect()
	var content: Rect2 = launcher.get_node("Pages").get_global_rect().grow(0.5)
	var controls: Array[Control] = []
	_visible_controls(root, controls)
	var outside: Array[String] = []
	for control in controls:
		if not (content.encloses(control.get_global_rect()) and view.encloses(control.get_global_rect())): outside.append(str(control.name))
		if control.get_child_count() > 0: _overlap_free(runner, control, label)
	runner.check(controls.size() > 3 and outside.is_empty(), "M17 every visible control inside the content, %s, outside: %s page %s content %s" % [label, outside, root.get_global_rect(), content])
	_overlap_free(runner, root, label)

func test_team_layout_hud_sizes(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("team-layout")
	LauncherSettings.save_picks({"map": "dry_wells"})
	for pair: Array in BaseScene.HUD_SIZES:
		var built: Array = _port_with_launcher(runner, pair[0], pair[1])
		var launcher = built[1]
		var size: Vector2i = pair[1]
		for mode: String in ["bot", "friend", "team"]:
			for fold: bool in [false, true]:
				launcher.get_node("Pages/Play/Body/Advanced/Toggle").button_pressed = fold
				await _settle(runner, launcher, "Play", mode)
				_layout_ok(runner, launcher, launcher.get_node("Pages/Play"), "Play %s fold %s at %s" % [mode, fold, size])
		var body: Control = launcher.get_node("Pages/Play/Body")
		var line: Label = body.get_node("MapHidden")
		var info: Rect2 = body.get_node("MapInfo").get_global_rect()
		var map: Rect2 = body.get_node("Map").get_global_rect()
		# The grid puts the line one row below the info, beside the toggles: the Mode label makes that row 20 px taller than the info.
		var gap: float = line.get_global_rect().position.y - info.end.y
		runner.check(line.visible and not line.text.is_empty() and gap >= 0.0 and gap <= 30.0 and absf(line.get_global_rect().position.y - body.get_node("Opponent").get_global_rect().position.y) < 1.0 and absf(line.get_global_rect().position.x - map.position.x) < 1.0 and line.get_global_rect().end.x <= map.end.x + 0.5, "M17 the hidden-map line sits right under the map info in the map column at %s, gap %s, got %s" % [size, gap, line.get_global_rect()])
		runner.check(line.get_line_count() == 1 and line.size.x >= line.get_minimum_size().x, "M17 the hidden-map line shows whole on one line at %s" % size)
		var footer_top: float = launcher.get_node("Pages/Play/Divider").get_global_rect().position.y
		runner.check(body.get_node("TeamBots").get_global_rect().end.y <= footer_top, "M17 the bot rows end above the footer at %s" % size)
		launcher.get_node("Pages/Play/Body/Advanced/Toggle").button_pressed = false
		_host_team(launcher)
		launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
		await runner.process_frame
		await runner.process_frame
		var left: Control = launcher.get_node("Pages/Waiting/Body/Left")
		runner.check(launcher.current_page == "Waiting" and left.get_node("Three").visible and left.get_node("Four").visible, "M17 fixture: Waiting with both bot slots at %s" % size)
		_layout_ok(runner, launcher, launcher.get_node("Pages/Waiting"), "Waiting team at %s" % size)
		runner.check(left.get_node("Four").get_global_rect().end.y <= launcher.get_node("Pages/Waiting/Divider").get_global_rect().position.y, "M17 the last bot slot ends above the footer at %s" % size)
		launcher._cancel()
		var status: Label = await _version_footer(runner, launcher, false)
		var join: Rect2 = launcher.get_node("Pages/Join/Footer/Join").get_global_rect()
		runner.check(launcher.get_node("Pages/Join/Footer").get_global_rect().grow(0.5).encloses(status.get_global_rect()) and not status.get_global_rect().intersects(join) and status.get_line_count() == 1, "M17 the version line fits the Join footer beside the button on one line at %s, got %s lines" % [size, status.get_line_count()])
		_layout_ok(runner, launcher, launcher.get_node("Pages/Join"), "Join version line at %s" % size)
		built[1].free()
		built[0].free()
	_restore(saved)
	return true
