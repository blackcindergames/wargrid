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
const JoinLink = preload("res://scripts/join_link.gd")
const HeadlessClient = preload("res://scripts/net/headless_client.gd")
const LOOPBACK := "wss://127.0.0.1:9/ws"
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const Credits = preload("res://scripts/presentation/credits.gd")
const DashedPanel = preload("res://scripts/presentation/dashed_panel.gd")
const MapPreview = preload("res://scripts/presentation/map_preview.gd")
const REGULAR := "res://fonts/PublicSans-Regular.ttf"
const CYAN := Color("#60e5ed")
const ACTION := Color("#f7c871")
const INK := Color("#1a1408")
const SWITCH_DARK := Color("#2b2b2b")
const SWITCH_GREY := Color("#808080")
const SWITCH_LIGHT := Color("#d4d4d4")
const PANEL := Color("#223241")
const WELL := Color("#0c141a")
const TEXT := Color("#eef3f5")
const LINE := Color("#2e3f4b")
const JOIN := "Pages/Play/JoinCard/Card/Box"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2576, 1145)]
# canvas_items + expand lays a window out at 720 logical px high; 2576x1145 becomes roundi(720 * 2576 / 1145) wide
const STRETCHED: Array[Array] = [[Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(2576, 1145), Vector2i(1620, 720)]]

func cases() -> Array[Callable]:
	return [test_picks_defaults, test_picks_fallback_per_field, test_picks_keep_other_sections, test_picks_bot_list_and_old_files, test_fullscreen_target, test_fullscreen_switch, test_this_build_line, test_graphics_group, test_graphics_shows_stored, test_graphics_mirror_esc_menu, test_no_selection_colour_on_switches, test_primary_button_is_amber_with_dark_ink, test_mute_is_a_switch, test_public_sans_font, test_launcher_effective_sizes, test_font_rendering, test_dropdown_arrow, test_control_heights, test_round4_minors, test_long_dropdown_text_keeps_a_gap, test_footer_error_hugs_text, test_waiting_bold_codes_and_dashed_slots, test_sidebar_switches_pages, test_aspect_expand_and_restore, test_layout_every_page, test_opens_on_bot_with_picks, test_toggle_friend, test_map_info_and_summary, test_own_faction_shared, test_start_saves_picks, test_offline_setup_seats_extra_bots, test_relay_in_settings, test_link_opens_join, test_lock_while_connecting, test_waiting_view, test_join_error_footer, test_join_takes_a_pasted_line, test_join_needs_code, test_relay_fields_follow, test_column_widths, test_player_rows_padded, test_footer_status_style, test_vertical_rhythm, test_waiting_two_columns, test_enter_submits_join_code, test_enter_joins_after_link, test_connecting_footers_fit, test_connecting_elapsed_and_cancel, test_lobby_countdown_and_expiry, test_hidden_host_survives_lobby, test_ticking_texts_through_process, test_default_focus, test_stray_enter_does_nothing, test_enter_after_faction_pick, test_click_targets_32, test_quit_button, test_invite_label, test_focus_differs_from_hover, test_focus_ring_fits, test_mode_row_two_modes, test_team_mode_shows_bot_rows, test_team_bot_factions_remembered, test_team_hello_carries_bots, test_team_changes_while_connecting, test_waiting_lists_bot_slots, test_waiting_edges_neon, test_start_sets_bot_factions_and_teams, test_version_mismatch_plain_line, test_team_layout_hud_sizes, test_guest_start_matches_host, test_lobby_one_click_bot_match, test_lobby_add_bot_up_to_starts, test_lobby_host_caps_bots, test_lobby_remove_bot, test_lobby_random_faction, test_lobby_code_at_host_game, test_lobby_settings_coalesced, test_lobby_friend_joins_and_leaves, test_lobby_start_request_when_full, test_lobby_guest_live_view, test_lobby_guest_change_lines, test_lobby_host_left, test_lobby_stop_hosting, test_lobby_countdown_resets, test_lobby_hour_cap, test_lobby_expiry_texts, test_lobby_changes_wait_for_open_lists, test_lobby_picks_both_ways, test_relay_reasons, test_prerelease_build_in_hello, test_join_lookalike_letters, test_lobby_guest_team_move_line, test_lobby_small_px, test_lobby_guest_random_resolved, test_lobby_copy_turns_copied, test_launcher_theme_stays_in_the_launcher, test_lobby_layout_sizes, test_join_card_placement, test_lobby_look_lines_up, test_start_pick_offline, test_start_pick_host_folds_guest, test_start_pick_guest_view, test_start_pick_guest_repicks, test_start_pick_closed_fits_hosting, test_start_pick_rejoin_adopts_nothing, test_start_pick_closed_count_line]

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
	runner.check(picks == {"faction": "usa", "bots": ["usa"], "map": "dry_wells"}, "L1 defaults without a file, got %s" % [picks])
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
	runner.check(picks == {"faction": "frc", "bots": ["usa"], "map": "dry_wells"}, "L2 bad fields fall back one by one, got %s" % [picks])
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
	runner.check(not after.has_section_key("launcher", "bots") and not after.has_section_key("launcher", "map"), "L3 absent keys stay absent")
	return true

func _picks_from(name: String, values: Dictionary) -> Dictionary:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for(name)
	var config := ConfigFile.new()
	for key: String in values: config.set_value("launcher", key, values[key])
	config.save(AudioSettings.path)
	var picks: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	return picks

func test_picks_bot_list_and_old_files(runner) -> bool:
	var old_m9: Dictionary = _picks_from("old-m9", {"bot_faction": "frc", "team_bot_1": "china", "team_bot_2": "gla"})
	runner.check(old_m9.bots == ["frc"], "L4a a pre-P20 file with bot_faction and M9 team_bot keys loads its one bot, got %s" % [old_m9])
	var listed: Dictionary = _picks_from("bot-list", {"bot_faction": "frc", "bots": ["china", "random", "usa"]})
	runner.check(listed.bots == ["china", "random", "usa"], "L4a the stored bot list wins, Random kept, got %s" % [listed])
	for bad: Variant in ["china", [], ["china", "gla"], [3]]:
		var picks: Dictionary = _picks_from("bad-bots", {"bot_faction": "china", "bots": bad})
		runner.check(picks.bots == ["china"], "L4a a bad bot list %s falls back to bot_faction, got %s" % [bad, picks])
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
	runner.check(launcher.get_node_or_null("Sidebar/Nav/Join") == null and launcher.get_node_or_null("Pages/Join") == null, "L5 Join is a mode on Play, not a sidebar page")
	for page_name: String in ["Settings", "Credits"]:
		var nav: Button = launcher.get_node_or_null("Sidebar/Nav/" + page_name)
		runner.check(nav != null, "L5 nav button %s exists" % page_name)
		if nav == null: continue
		nav.button_pressed = true
		runner.check(launcher.current_page == page_name and _visible_pages(launcher) == [page_name] and nav.button_pressed, "L5 %s shows only its page, got %s" % [page_name, _visible_pages(launcher)])
	var version: Label = launcher.get_node_or_null("Sidebar/Version")
	runner.check(version != null and str(ProjectSettings.get_setting("application/config/version")) in version.text, "L6 the sidebar shows the version")
	for link: Array in [["Impressum", "https://blackcindergames.com/impressum/"], ["Privacy", "https://blackcindergames.com/privacy/"]]:
		var button: LinkButton = launcher.get_node_or_null("Sidebar/Legal/Links/" + link[0])
		runner.check(button != null and button.text == link[0] and button.uri == link[1] and button.theme_type_variation == &"SidebarLink" and button.is_visible_in_tree(), "L6b the sidebar links %s to %s" % link)
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
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var content: Control = launcher.get_node_or_null("Pages")
		var sidebar: Control = launcher.get_node_or_null("Sidebar")
		runner.check(content != null and sidebar != null, "L8 sidebar and pages exist at %s" % size)
		for visit: Array in [["Play", "skirmish"], ["Settings", "skirmish"], ["Credits", "skirmish"], ["Play", "host"], ["Play", "join"]]:
			var page_name: String = visit[0]
			launcher.set_mode(visit[1])
			launcher.show_page(page_name)
			await runner.process_frame
			await runner.process_frame
			var label := "%s %s at %s (window %s)" % [page_name, visit[1], size, pair[0]]
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
	runner.check(_picked(launcher._own_selector()) == "china" and launcher.lobby_bots == ["frc"] and _picked(_row(launcher, 2, "Bot1").get_node("Faction")) == "frc" and launcher._map_id() == "ashfall", "L9a Play shows the remembered picks")
	runner.check(launcher.mode == "skirmish" and play.get_node("Footer/Start").visible and not play.get_node("ModeBar/Invite").visible, "L9a opens on Skirmish with Start only")
	launcher.free()
	return true

func test_toggle_friend(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "toggle", {})
	_restore(saved)
	var play: Control = launcher.get_node("Pages/Play")
	var skirmish: Button = play.get_node("ModeBar/Skirmish")
	var host: Button = play.get_node("ModeBar/Host")
	launcher.lobby_bots.clear()
	_host(launcher)
	runner.check(launcher.mode == "host" and launcher._transport != null and play.get_node("Footer/Start").disabled and play.get_node("Footer/CancelConnect").visible, "L9b Host game connects at once and locks Start")
	var friend: Control = _row(launcher, 2, "Friend")
	runner.check(friend.get_parent() is DashedPanel and friend.get_node("Who/Name").text == "Open" and friend.get_node("Who/Meta").text == "Your friend joins with the code", "L9b the friend's open row, dashed")
	runner.check(host.button_pressed and not skirmish.button_pressed, "L9b the Host game toggle is pressed")
	runner.check(_selection(host.get_theme_stylebox("pressed")) and skirmish.get_theme_stylebox("normal").bg_color == PANEL, "L9b the selected mode has the cyan frame, the others the panel colour")
	launcher._cancel()
	runner.check(launcher.mode == "skirmish" and _rows(launcher, 2) == ["Bot1"] and not play.get_node("ModeBar/Invite").visible and not play.get_node("Footer/Start").disabled, "L9b cancelling returns to the bot match")
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
	runner.check(launcher.get_node("Pages/Play/Body/MapColumn/MapInfo").text == launcher._map_info("dry_wells"), "L9c the map info shows under the map")
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
	_pick(launcher._own_selector(), "china")
	launcher.set_mode("join")
	runner.check(launcher.get_node(JOIN).find_children("*", "OptionButton", true, false).is_empty(), "L9d the Join game card asks for no faction")
	launcher.set_mode("skirmish")
	runner.check(_picked(launcher._own_selector()) == "china", "L9d your faction survives a visit to Join game")
	launcher.free()
	return true

func test_start_saves_picks(runner) -> bool:
	var saved: String = AudioSettings.path
	var before: Array = OnlineTests._statics()
	var launcher = await _launcher_with(runner, "saves", {"faction": "usa", "bot_faction": "usa", "map": "dry_wells"})
	launcher._set_own("china")
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "frc")
	_pick(launcher.get_node("Pages/Play/Body/MapColumn/Map"), "ashfall")
	launcher._add_bot()
	launcher._offline_setup()
	var stored: Dictionary = LauncherSettings.load_picks()
	var relaunched = Launcher.instantiate()
	runner.root.add_child(relaunched)
	await runner.process_frame
	var shown: Array = [relaunched.lobby_bots.duplicate(), _rows(relaunched, 2), relaunched.mode, _focused(relaunched) == relaunched.get_node("Pages/Play/Footer/Start")]
	_restore(saved)
	# The next case's match must not start on this case's picks.
	OnlineTests._restore_statics(before)
	runner.check(stored == {"faction": "china", "bots": ["frc", "random"], "map": "ashfall"}, "L9e a bot start saves faction, every bot and the map, got %s" % [stored])
	runner.check(shown == [["frc", "random"], ["Bot1", "Bot2"], "skirmish", true], "L9e a relaunch shows the bots last played on Skirmish with Start focused, got %s" % [shown])
	launcher.free()
	relaunched.free()
	return true

func test_offline_setup_seats_extra_bots(runner) -> bool:
	var saved: String = AudioSettings.path
	var before: Array = OnlineTests._statics()
	var launcher = await _launcher_with(runner, "offline_bots", {"faction": "usa", "bot_faction": "china", "map": "broken_crown"})
	launcher._offline_setup()
	var one: Array = [SkirmishMain.factions.duplicate(), SkirmishMain.starts.size()]
	launcher.lobby_bots = ["frc", "china", "usa"] as Array[String]
	# Seed 4 is a seed where free-for-all ids would place the seats differently.
	seed(4)
	launcher._offline_setup()
	var three: Array = [SkirmishMain.factions.duplicate(), SkirmishMain.starts.size()]
	var used: Array[int] = SkirmishMain.starts.duplicate()
	var teams: Array[int] = MatchSettings.starts("broken_crown", SkirmishMain.match_seed, MatchSettings.teams(1, 3))
	var free_for_all: Array[int] = MatchSettings.starts("broken_crown", SkirmishMain.match_seed, MatchSettings.teams(4))
	launcher.lobby_bots = ["frc", "china", "usa", "usa"] as Array[String]
	var errors: Array[String] = []
	launcher.log_error = func(line: String) -> void: errors.append(line)
	SkirmishMain.starts = [] as Array[int]
	var refused: bool = not launcher._offline_setup()
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(one == [{1: "usa", 2: "china"}, 2], "L9g the opening bot is the one opponent, got %s" % [one])
	runner.check(three == [{1: "usa", 2: "frc", 3: "china", 4: "usa"}, 4], "L9g three bots take seats 2 to 4 with four starts, got %s" % [three])
	runner.check(teams != free_for_all, "L9g fixture: this seed tells team starts from free-for-all starts, got %s" % [teams])
	runner.check(used == teams, "L9g the starts follow you on team 1 against the bots on team 2, got %s want %s" % [used, teams])
	runner.check(refused and errors.size() == 1 and SkirmishMain.starts.is_empty(), "L9h four bots on four starts are refused with one error and no start set, got %s %s" % [refused, errors])
	launcher.free()
	return true

const ONLINE := "Pages/Settings/Body/Playtest/Online"
const UNREACHABLE := "Can't reach the relay (%s). Check your connection and try again."

func test_relay_in_settings(runner) -> bool:
	var saved: String = AudioSettings.path
	for prerelease in [false, true]:
		var launcher = await _launcher_with(runner, "relay-settings", {}, prerelease)
		var online: Control = launcher.get_node_or_null(ONLINE)
		runner.check(launcher.get_node_or_null(MAP_COLUMN + "/Advanced") == null, "L9f Play has no Advanced fold")
		runner.check(online != null and online.visible == prerelease and online.get_node("OnlineHeader").text == "Online" and online.get_node("RelayHelp").get_index() == online.get_node("RelayUrl").get_index() - 1, "L9f Settings holds the Online group (header, help, relay field) in test builds only (%s)" % prerelease)
		launcher.free()
	AudioSettings.path = scratch_for("relay-saved")
	var dev = Launcher.instantiate()
	dev.prerelease = true
	runner.root.add_child(dev)
	await runner.process_frame
	var field: LineEdit = dev.get_node(ONLINE + "/RelayUrl")
	runner.check(field.text == JoinLink.DEFAULT_RELAY, "L9f the field starts on the default relay, got '%s'" % field.text)
	field.text = "ws://127.0.0.1:8787/ws"
	field.text_changed.emit(field.text)
	dev.free()
	var again = Launcher.instantiate()
	again.prerelease = true
	runner.root.add_child(again)
	await runner.process_frame
	runner.check(again.get_node(ONLINE + "/RelayUrl").text == "ws://127.0.0.1:8787/ws" and again._relay_url() == "ws://127.0.0.1:8787/ws", "L9f a test build restores the saved relay on start")
	again.free()
	var release = Launcher.instantiate()
	release.prerelease = false
	runner.root.add_child(release)
	await runner.process_frame
	runner.check(release._relay_url() == JoinLink.DEFAULT_RELAY, "L9f a release build ignores a saved relay")
	release.free()
	_restore(saved)
	return true

func _texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false): found.append(label.text)
	for rich: RichTextLabel in node.find_children("*", "RichTextLabel", true, false): found.append(rich.get_parsed_text())
	return found

func _nav_disabled(launcher) -> Array[bool]:
	var states: Array[bool] = []
	for page_name: String in LauncherScript.PAGES: states.append(launcher.get_node("Sidebar/Nav/" + page_name).disabled)
	return states

# The selected look is a filled box with a cyan edge; the focus ring is cyan too but unfilled.
func _selection(style: StyleBox) -> bool:
	return style is StyleBoxFlat and style.draw_center and style.border_color == CYAN and (style.border_width_left > 0 or style.border_width_top > 0)

func _drawn_selected(button: Button) -> bool:
	var styles: Dictionary = {BaseButton.DRAW_NORMAL: "normal", BaseButton.DRAW_PRESSED: "pressed", BaseButton.DRAW_HOVER: "hover", BaseButton.DRAW_DISABLED: "disabled", BaseButton.DRAW_HOVER_PRESSED: "hover_pressed"}
	return _selection(button.get_theme_stylebox(styles[button.get_draw_mode()]))

# Opens Join game with this code and presses Join game on the card.
func _join_with(launcher, code: String) -> void:
	launcher.show_page("Play")
	launcher.set_mode("join")
	launcher._set_relay(LOOPBACK)
	launcher.get_node(JOIN + "/Code").text = code
	launcher.get_node(JOIN + "/Buttons/Join").pressed.emit()
	launcher.set_process(false)

func _message(launcher) -> Label:
	return launcher.get_node(JOIN + "/Message")

func _mode_locks(launcher) -> Array:
	return ["Skirmish", "Host", "Join"].map(func(each: String) -> Array:
		var button: Button = launcher.get_node(MODE_BAR + "/" + each)
		return [button.disabled, button.tooltip_text])

func _host(launcher) -> Object:
	launcher._set_relay(LOOPBACK)
	launcher.show_page("Play")
	launcher.get_node("Pages/Play/ModeBar/Host").pressed.emit()
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
	runner.check(first.current_page == "Play" and first.mode == "join" and first.get_node(JOIN + "/Code").text == "ABC234" and first._transport == null, "L10a a join link opens Join game with the code and no connection, got %s %s" % [first.current_page, first.mode])
	runner.check(first.get_node("Pages/Play/JoinCard").visible and _message(first).text == LauncherScript.FROM_LINK and _focused(first) == first.get_node(JOIN + "/Buttons/Join"), "L10a the card says where the code came from and Join game has the focus")
	first.free()
	var again = Launcher.instantiate()
	again.search = "?code=ABC234"
	runner.root.add_child(again)
	await runner.process_frame
	runner.check(again.current_page == "Play" and again.mode == "skirmish", "L10b a stale link does not reopen Join game, got %s" % again.mode)
	runner.check(_picked(again._own_selector()) == "china" and again._map_id() == "ashfall", "L13 back to menu shows the remembered picks")
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
	runner.check(_nav_disabled(launcher) == [false, false, false] and launcher.get_node("Sidebar/Nav/Quit").disabled and not launcher.get_node(ONLINE + "/RelayUrl").editable, "L11 hosting keeps Play, Settings and Credits usable; Quit and the relay field lock, got %s" % [_nav_disabled(launcher)])
	var host: Button = launcher.get_node("Pages/Play/ModeBar/Host")
	runner.check(launcher.get_node("Sidebar/Nav/Quit").disabled and launcher.get_node("Pages/Play/Footer/CancelConnect").visible, "L11 Host game locks Quit; Cancel shows")
	runner.check(_mode_locks(launcher) == [[false, ""], [false, ""], [true, LauncherScript.STOP_FIRST]], "L11 Join game greys out with Stop hosting first; Skirmish stays a way out, got %s" % [_mode_locks(launcher)])
	runner.check(_drawn_selected(launcher.get_node("Sidebar/Nav/Play")) and _drawn_selected(launcher.get_node("Pages/Play/ModeBar/Host")), "L17 while connecting the Play nav and the Host game toggle still draw the selection")
	launcher._fail(reason)
	var play_status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(_nav_disabled(launcher) == [false, false, false] and launcher.current_page == "Play" and play_status.text == reason and play_status.theme_type_variation == &"FooterError" and launcher.mode == "host" and not host.disabled, "L11 a failure before welcome unlocks the nav, stays on Host game and shows the reason in red")
	var again: Button = launcher.get_node("Pages/Play/Footer/TryAgain")
	runner.check(again.visible and again.text == "Try again" and _focused(launcher) == again and not launcher.get_node("Pages/Play/Footer/CancelConnect").visible, "L11 Try again shows and takes the focus")
	again.pressed.emit()
	launcher.set_process(false)
	runner.check(launcher._transport != null and not again.visible and launcher.mode == "host", "L11 Try again opens the room again")
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234","settings":{}}')
	runner.check(play_status.text == LauncherScript.FRIEND_WAIT and play_status.theme_type_variation == &"FooterStatus", "L11 the new room replaces the red line, got '%s'" % play_status.text)
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._cancel()
	runner.check(_mode_locks(launcher) == [[false, ""], [false, ""], [false, ""]], "L11 a failure frees the modes again, got %s" % [_mode_locks(launcher)])
	launcher.set_mode("skirmish")
	runner.check(play_status.text == launcher._summary(), "M3 the next action on Play replaces the error")
	launcher.free()
	return true

func test_waiting_view(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "waiting", {"faction": "china", "map": "ashfall"})
	_restore(saved)
	var transport = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var play: Control = launcher.get_node("Pages/Play")
	runner.check(launcher.current_page == "Play" and _nav_disabled(launcher) == [false, false, false], "L12a welcome keeps the lobby page; the sidebar stays usable")
	runner.check(_drawn_selected(launcher.get_node("Sidebar/Nav/Play")), "L17 hosting draws the Play nav selected")
	for other: String in ["Settings", "Credits"]:
		runner.check(not _drawn_selected(launcher.get_node("Sidebar/Nav/" + other)), "L17 hosting leaves %s idle" % other)
	runner.check(play.get_node("ModeBar/Invite/Box/Code").text == "ABC 234" and launcher._copy_text() == "ABC234", "L12a the code shows in two halves in the mode row; Copy takes it whole")
	var you: Array[String] = _texts(_row(launcher, 1, "You"))
	runner.check("You" in you and "Host" in you and _picked(launcher._own_selector()) == "china", "L12a row 1 is You, the host, China, got %s" % [you])
	var friend: Array[String] = _texts(_row(launcher, 1, "Friend"))
	runner.check("Open" in friend and "Waiting for your friend…" in friend, "L12a the friend's row is open, got %s" % [friend])
	runner.check(launcher._map_id() == "ashfall" and play.get_node("Body/MapColumn/Map").visible and play.get_node("Body/MapColumn/MapInfo").text == launcher._map_info("ashfall"), "L12a the map stays a dropdown with its info")
	runner.check(play.get_node("Footer/Status").text == "Start match unlocks when your friend joins", "L12a the footer says who starts, no clock yet, got '%s'" % play.get_node("Footer/Status").text)
	play.get_node("Footer/Leave").pressed.emit()
	runner.check(transport.close_calls == 1 and launcher.current_page == "Play" and _nav_disabled(launcher) == [false, false, false], "L12b Stop hosting closes and unlocks")
	runner.check(play.get_node("Footer/Status").text == LauncherScript.HOSTING_STOPPED and play.get_node("Footer/Status").theme_type_variation == &"FooterStatus" and launcher.mode == "skirmish", "L12b Play says hosting stopped and goes back to Skirmish")
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	launcher._handle('{"type":"error","reason":"match is full"}')
	runner.check(launcher.current_page == "Play" and play.get_node("Footer/Status").text == "The relay refused the connection (match is full)." and launcher.mode == "host" and play.get_node("Body/MapColumn/Map").visible, "L12c a relay error while hosting stays on Host game with the reason")
	launcher.free()
	return true

func test_join_error_footer(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-error", {})
	_restore(saved)
	_join_with(launcher, "ABC234")
	runner.check(launcher._relay_url() == LOOPBACK, "L14 fixture: the relay is a loopback literal, so no DNS lookup starts")
	runner.check(_nav_disabled(launcher) == [false, false, false] and launcher.get_node("Sidebar/Nav/Quit").disabled, "L14 joining keeps the sidebar pages usable and locks Quit")
	runner.check(_mode_locks(launcher) == [[true, LauncherScript.LEAVE_FIRST], [true, LauncherScript.LEAVE_FIRST], [false, ""]], "L14 the other modes grey out with Leave first, got %s" % [_mode_locks(launcher)])
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._fail("Cannot connect to relay")
	runner.check(launcher.mode == "join" and _message(launcher).text == "Cannot connect to relay" and _message(launcher).theme_type_variation == &"JoinError" and _nav_disabled(launcher) == [false, false, false], "L14 the error shows under the code field, nav unlocked")
	for reason: Array in [["unknown match", LauncherScript.NO_GAME % "ABC234"], ["match full", LauncherScript.GAME_FULL]]:
		_join_with(launcher, "ABC234")
		launcher._transport = OnlineTests.FakeTransport.new()
		launcher._handle(Wire.encode({"type": "error", "reason": reason[0]}))
		runner.check(_message(launcher).text == reason[1] and _message(launcher).theme_type_variation == &"JoinError", "L14 the relay's '%s' reads '%s', got '%s'" % [reason[0], reason[1], _message(launcher).text])
		var field: LineEdit = launcher.get_node(JOIN + "/Code")
		runner.check(_focused(launcher) == field and field.get_selected_text() == "ABC234", "L14 a failed join focuses the code with all of it selected, got %s '%s'" % [_focused(launcher), field.get_selected_text()])
	launcher.free()
	return true

func test_join_takes_a_pasted_line(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-pasted", {})
	_restore(saved)
	_join_with(launcher, "join please: K7Q-4MX")
	var transport := OpenTransport.new()
	launcher._transport = transport
	launcher._process(0.0)
	runner.check(_hello(transport).get("match") == "K7Q4MX", "JL6 a pasted chat line joins with its code, got %s" % [_hello(transport)])
	launcher._cancel()
	launcher.free()
	return true

func test_join_needs_code(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-code", {})
	_restore(saved)
	for text: String in ["", "ABC", "ABC10O"]:
		_join_with(launcher, text)
		runner.check(launcher._transport == null and launcher.mode == "join" and _message(launcher).text == (LauncherScript.LOOKALIKE if text == "ABC10O" else LauncherScript.NEED_CODE), "L18 code '%s' does not connect and says what to enter, got '%s'" % [text, _message(launcher).text])
	for typed: String in ["abc234", "abc 234", "ABC-234"]:
		_join_with(launcher, typed)
		runner.check(launcher._transport != null and launcher.get_node("Sidebar/Nav/Quit").disabled, "L18 '%s' connects" % typed)
		launcher._transport = OnlineTests.FakeTransport.new()
		launcher._handle(Wire.encode({"type": "error", "reason": "unknown match"}))
		runner.check(_message(launcher).text == LauncherScript.NO_GAME % "ABC234", "L18 '%s' asked the relay for ABC234, got '%s'" % [typed, _message(launcher).text])
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
	var play: LineEdit = launcher.get_node(ONLINE + "/RelayUrl")
	runner.check(play.text == "wss://x.example/ws" and launcher._relay_url() == play.text and LauncherSettings.relay() == JoinLink.DEFAULT_RELAY, "M2 ?relay= fills the Settings field for this session without saving it, saved '%s'" % LauncherSettings.relay())
	play.text = "wss://z.example/ws"
	play.text_changed.emit(play.text)
	runner.check(launcher._relay_url() == "wss://z.example/ws", "M2 typing into the field reaches _relay_url(), which Join game uses too")
	play.text = "  "
	runner.check(launcher._relay_url() == JoinLink.DEFAULT_RELAY, "M2 an empty field means the default relay")
	launcher.free()
	LauncherSettings.save_relay("ws://127.0.0.1:8787/ws")
	LauncherScript.code_applied = false
	var linked = Launcher.instantiate()
	linked.prerelease = true
	linked.search = "?code=ABC234"
	runner.root.add_child(linked)
	await runner.process_frame
	runner.check(linked._relay_url() == JoinLink.DEFAULT_RELAY and LauncherSettings.relay() == "ws://127.0.0.1:8787/ws", "M2 a code link without relay= joins through the default relay; the saved one stays saved")
	_join_with(linked, "ABC234")
	linked.show_page("Settings")
	linked._unhandled_input(_esc())
	runner.check(linked._transport != null, "M2 Esc on another page leaves a connecting join alone")
	linked.show_page("Play")
	linked._unhandled_input(_esc())
	runner.check(linked._transport == null, "M2 Esc on Play cancels it")
	linked.free()
	_restore(saved)
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
	var build: Button = launcher.get_node("Pages/Play/ThisBuild")
	runner.check(not build.visible, "L15b ThisBuild is hidden while the switch is off")
	runner.check(build.get_index() + 1 == launcher.get_node("Pages/Play/Divider").get_index(), "L15b ThisBuild sits just above the divider")
	runner.check(build.theme_type_variation == &"FooterLink" and build.get_theme_stylebox("normal") is StyleBoxEmpty, "L15b ThisBuild is a line-style link")
	runner.check(not build.flat, "R4 ThisBuild leaves flat off, the link style alone makes it a line")
	var focus: StyleBox = build.get_theme_stylebox("focus")
	runner.check(focus is StyleBoxFlat and focus.border_width_left > 0, "R3 ThisBuild shows a visible focus outline")
	toggle.button_pressed = true
	runner.check(build.visible and build.text == "This build: " + title, "L15b ThisBuild names the first card when on, got %s" % build.text)
	toggle.button_pressed = false
	runner.check(not build.visible, "L15b ThisBuild hides again when switched off")
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
	return [port, launcher]

func _settle(runner, launcher, page_name: String, mode: String = "skirmish") -> void:
	launcher.set_mode(mode)
	launcher.show_page(page_name)
	await runner.process_frame
	await runner.process_frame

func test_column_widths(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("columns")
	var left: Dictionary = {"Play": "Body/Players", "Settings": "Body/Audio"}
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
			runner.check(page.size.x <= 985.0, "L19a %s page does not stretch with the window at %s, got %s" % [page_name, pair[1], page.size.x])
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
	LauncherSettings.save_picks({"map": "broken_crown"})
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	await _settle(runner, launcher, "Play", "host")
	var rows: Array[Control] = [_row(launcher, 1, "You").get_parent(), _row(launcher, 1, "Friend").get_parent(), _row(launcher, 2, "Bot1").get_parent()]
	for row: Control in rows:
		var margins: Vector2 = _inner_margins(row)
		runner.check(margins.x >= 10.0 and margins.y >= 4.0, "L19b row %s keeps 10 px inside left and 4 px right, got %s" % [row.name, margins])
		runner.check(absf(row.size.y - rows[0].size.y) < 1.0 and absf(row.size.x - rows[0].size.x) < 1.0, "L19b row %s has the size of the others, got %s and %s" % [row.name, row.size, rows[0].size])
		runner.check(row.size.y >= 49.0 and row.size.y <= 51.0, "L19b row %s is the round's 50 px high, got %s" % [row.name, row.size.y])
	built[1].free()
	built[0].free()
	_restore(saved)
	return true

const ERROR_STRIP := Color("#3b2a2d")

func test_footer_status_style(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "footer-style", {})
	_restore(saved)
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	var info_size: int = status.get_theme_font_size("font_size")
	runner.check(info_size == 14, "L19c the footer text is 14 px, got %s" % info_size)
	launcher._origin = "Play"
	launcher._fail("Cannot connect to relay")
	var style: StyleBox = status.get_theme_stylebox("normal")
	runner.check(style is StyleBoxFlat and style.bg_color == ERROR_STRIP and style.border_width_left > 0, "L19c a Play error uses the error strip")
	runner.check(status.get_theme_font_size("font_size") <= info_size, "L19c the error text is no larger than the footer text, got %s" % status.get_theme_font_size("font_size"))
	launcher._fail(LauncherScript.HOST_CANCELLED)
	var plain: StyleBox = status.get_theme_stylebox("normal")
	runner.check(not (plain is StyleBoxFlat and plain.bg_color == ERROR_STRIP), "L19c Hosting cancelled is plain info text")
	launcher.set_mode("host")
	runner.check(not (status.get_theme_stylebox("normal") is StyleBoxFlat and status.get_theme_stylebox("normal").bg_color == ERROR_STRIP), "L19c the next Play action drops the strip")
	_join_with(launcher, "")
	runner.check(_message(launcher).theme_type_variation == &"JoinError" and _message(launcher).get_theme_color("font_color") == Color("#f47b6c"), "L19c the missing-code line under the field is red")
	launcher.free()
	return true

func _text_top(label: Control) -> float:
	return label.get_global_rect().position.y + label.get_theme_stylebox("normal").get_margin(SIDE_TOP)

func test_vertical_rhythm(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("rhythm")
	var built: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var launcher = built[1]
	var rows: Array = [["skirmish", "Body/Players/Teams/List/Team1/Head", "Body/Players/Teams/List/Team1/You", "Body/Players/Teams/List/Team2/Head", 16.0, 26.0], ["skirmish", "Body/MapColumn/MapLabel", "Body/MapColumn/Map", "Body/MapColumn/Preview", 10.0, 14.0], ["join", "JoinCard/Card/Box/CodeLabel", "JoinCard/Card/Box/Code", "JoinCard/Card/Box/Message", 6.0, 10.0]]
	for row: Array in rows:
		await _settle(runner, launcher, "Play", row[0])
		var label: Control = launcher.get_node_or_null("Pages/Play/" + row[1])
		var control: Control = launcher.get_node_or_null("Pages/Play/" + row[2])
		var next: Control = launcher.get_node_or_null("Pages/Play/" + row[3])
		runner.check(label != null and control != null and next != null, "L19d rows exist: %s" % [row])
		if label == null or control == null or next == null: continue
		var inner: float = control.get_global_rect().position.y - label.get_global_rect().end.y
		var between: float = _text_top(next) - control.get_global_rect().end.y
		runner.check(inner >= 4.0 and inner <= 10.0, "L19d label to control is 4-10 px, got %s (%s)" % [inner, row[1]])
		runner.check(between >= row[4] and between <= row[5], "L19d control to next text is %s-%s px, got %s (%s)" % [row[4], row[5], between, row[3]])
	await _settle(runner, launcher, "Play")
	var gap_to_lobby: float = _text_top(launcher.get_node("Pages/Play/Body/Players/Teams/List/Team1/Head")) - launcher.get_node("Pages/Play/ModeBar").get_global_rect().end.y
	runner.check(gap_to_lobby >= 16.0 and gap_to_lobby <= 26.0, "L19d the mode row to the Team 1 label text is 16-26 px, got %s" % gap_to_lobby)
	built[1].free()
	built[0].free()
	AudioSettings.path = saved
	return true

func test_waiting_two_columns(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "waiting-columns", {"map": "broken_crown"})
	_restore(saved)
	_lobby_host(launcher)
	await runner.process_frame
	await runner.process_frame
	var code: Control = launcher.get_node(MODE_BAR + "/Invite/Box/Code")
	var copy: Control = launcher.get_node(MODE_BAR + "/Invite/Box/Copy")
	var map: Control = launcher.get_node(MAP_COLUMN)
	var left: Control = launcher.get_node(PLAYERS)
	runner.check(code.get_global_rect().end.x <= copy.get_global_rect().position.x and absf(code.get_global_rect().get_center().y - copy.get_global_rect().get_center().y) < 2.0, "L19e Copy sits beside the code on one row")
	runner.check(map.get_global_rect().position.x >= left.get_global_rect().end.x + 28.0, "L19e the map is in a second column")
	runner.check(map.size.x >= 370.0 and map.size.x <= 390.0, "L19e the map column is about 380 px wide, got %s" % map.size.x)
	runner.check(launcher.get_node("Pages/Play/Footer/Leave").text == "Stop hosting" and launcher.get_node("Pages/Play/Footer/Status").text.begins_with("Start match unlocks when your friend joins"), "L19e footer shows the wait and Stop hosting")
	launcher._transport = null
	launcher.free()
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
			checked += 1
			runner.check(not _selection(button.get_theme_stylebox(state)), "U1 %s draws no selection frame in its %s state" % [button.get_path(), state])
	runner.check(checked > 100, "U1 the sweep covered the controls, got %d state checks" % checked)
	for button: CheckButton in switches:
		var hover: StyleBox = button.get_theme_stylebox("hover")
		var hover_pressed: StyleBox = button.get_theme_stylebox("hover_pressed")
		runner.check(hover is StyleBoxFlat and hover.bg_color.get_luminance() > WELL.get_luminance() and hover.bg_color.get_luminance() < 0.3, "U1 %s hovers in a slightly lighter navy" % button.name)
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
		runner.check(_font_path(heavy) in [SEMIBOLD, BOLD, EXTRABOLD], "F1 %s uses a real Public Sans weight, got %s" % [type, _font_path(heavy)])
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
const MUTED := Color("#93a5b0")

func _font_path(font: Font) -> String:
	return font.base_font.resource_path if font is FontVariation else font.resource_path

func test_launcher_effective_sizes(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "type", {})
	_restore(saved)
	var theme: Theme = _launcher_theme()
	runner.check(launcher.theme == theme, "TH4 the launcher root carries the launcher theme")
	runner.check(theme.default_font_size == 14, "T1 the base size is the round's 14 px, got %s" % theme.default_font_size)
	for dropdown: OptionButton in _dropdowns(launcher):
		var path: String = str(dropdown.get_path())
		runner.check(_font_path(dropdown.get_theme_font("font")) == SEMIBOLD, "T1 %s value is SemiBold, got %s" % [path, _font_path(dropdown.get_theme_font("font"))])
		runner.check(dropdown.get_theme_color("font_color") == TEXT and dropdown.get_theme_color("font_hover_color") == TEXT, "T1 %s value is the text colour, not muted" % path)
	for side: String in ["Skirmish", "Host", "Join"]:
		var toggle: Button = launcher.get_node(MODE_BAR + "/" + side)
		runner.check(_font_path(toggle.get_theme_font("font")) == SEMIBOLD, "T1 %s is SemiBold" % side)
		runner.check(toggle.get_theme_color("font_color") == MUTED and toggle.get_theme_color("font_pressed_color") == TEXT, "T1 %s is muted off and bright on" % side)
	for nav: Button in launcher.get_node("Sidebar/Nav").get_children().filter(func(each: Node) -> bool: return each is Button):
		runner.check(_font_path(nav.get_theme_font("font")) == BOLD and nav.get_theme_color("font_color") == MUTED and nav.get_theme_color("font_pressed_color") == TEXT, "T1 nav %s is Bold, muted off and bright on" % nav.name)
	var weights: Dictionary = {"PageTitle": [EXTRABOLD, 30], "FieldLabel": [BOLD, 12], "PanelTitle": [BOLD, 13], "Logo": [EXTRABOLD, 24], "PrimaryButton": [EXTRABOLD, 16]}
	for type: String in weights:
		var font: Font = theme.get_font("font", type)
		runner.check(_font_path(font) == weights[type][0] and theme.get_font_size("font_size", type) == weights[type][1], "T1 %s is Public Sans %s at %s px" % [type, "ExtraBold" if weights[type][0] == EXTRABOLD else "Bold", weights[type][1]])
		var controls: Array = launcher.find_children("*", "Control", true, false).filter(func(each: Control) -> bool: return each.theme_type_variation == type)
		runner.check(not controls.is_empty(), "TH4 the launcher has %s controls" % type)
		for control: Control in controls: runner.check(control.get_theme_font_size("font_size") == weights[type][1], "TH4 %s %s reports %s px, got %s" % [type, control.name, weights[type][1], control.get_theme_font_size("font_size")])
	launcher.set_mode("join")
	await runner.process_frame
	await runner.process_frame
	var code: LineEdit = launcher.get_node(JOIN + "/Code")
	var code_size: int = code.get_theme_font_size("font_size")
	var code_style: StyleBox = code.get_theme_stylebox("normal")
	var text_height: float = code.get_theme_font("font").get_height(code_size)
	runner.check(code_size == 16 and _font_path(code.get_theme_font("font")) == EXTRABOLD, "TH4 the join code is ExtraBold 16 px, the round's code snapped to the type scale, got %s" % code_size)
	runner.check(code_style.get_margin(SIDE_TOP) + text_height + code_style.get_margin(SIDE_BOTTOM) <= code.size.y, "TH4 the join code's text fits the %.0f px field, text %.1f" % [code.size.y, text_height])
	runner.check(code.max_length == JoinLink.MAX_INPUT, "TH4 the join field takes what the parser reads, got max %d" % code.max_length)
	var text_width: float = code.get_theme_font("font").get_string_size("W".repeat(7), HORIZONTAL_ALIGNMENT_LEFT, -1, code_size).x
	runner.check(code_style.get_margin(SIDE_LEFT) + text_width + code_style.get_margin(SIDE_RIGHT) <= code.size.x, "TH4 the widest join code fits the %.0f px field across, text %.1f" % [code.size.x, text_width])
	var logo: Font = theme.get_font("font", "Logo")
	runner.check(logo is FontVariation and logo.spacing_glyph >= 1, "T1 the logo has letter spacing")
	runner.check(_font_path(theme.get_font("font", "CheckButton")) == REGULAR, "T1 switch labels stay Regular")
	runner.check(theme.get_font_size("font_size", "Tag") == 12, "L27 the tag is 12 px, got %s" % theme.get_font_size("font_size", "Tag"))
	var muted: Color = theme.get_color("font_color", "Subtitle")
	runner.check(muted == MUTED, "T1 muted text is #93a5b0 like --muted, got %s" % muted)
	launcher.free()
	return true

func _dropdowns(launcher) -> Array[OptionButton]:
	return [launcher._own_selector(), launcher.get_node(MAP_COLUMN + "/Map"), _row(launcher, 2, "Bot1").get_node("Faction")]

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
	for dropdown: OptionButton in _dropdowns(launcher):
		var path: String = str(dropdown.get_path())
		var arrow: Texture2D = dropdown.get_theme_icon("arrow")
		runner.check(arrow.resource_path == "res://ui/launcher_dropdown_arrow.svg" and arrow.get_size() == Vector2(10, 5), "T3 %s uses the launcher's 10x5 solid triangle, got %s %s" % [path, arrow.resource_path, arrow.get_size()])
		runner.check(dropdown.get_theme_constant("arrow_margin") == 12, "T3 %s leaves 12 px right of the arrow, on the spacing scale, got %s" % [path, dropdown.get_theme_constant("arrow_margin")])
	var game_arrow: Texture2D = load(GAME_THEME).get_icon("arrow", "OptionButton")
	var image: Image = load("res://ui/launcher_dropdown_arrow.svg").get_image()
	runner.check(game_arrow.resource_path == "res://ui/dropdown_arrow.svg" and game_arrow.get_image().get_pixel(5, 1) != image.get_pixel(5, 1), "T3 the match's dropdowns keep their own arrow colour, got %s" % game_arrow.resource_path)
	runner.check(image.get_pixel(5, 0).a > 0.9 and image.get_pixel(5, 4).a > 0.5 and image.get_pixel(0, 4).a < 0.1, "T3 the arrow points down: wide on top, a point at the bottom")
	launcher.free()
	return true

func test_control_heights(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "heights", {})
	_restore(saved)
	var heights: Dictionary = {"dropdown": launcher._own_selector(), "toggle": launcher.get_node(MODE_BAR + "/Skirmish"), "nav": launcher.get_node("Sidebar/Nav/Play"), "start": launcher.get_node("Pages/Play/Footer/Start")}
	var want: Dictionary = {"dropdown": [30.0, 36.0], "toggle": [34.0, 40.0], "nav": [38.0, 44.0], "start": [48.0, 48.0]}
	for each: String in heights:
		var height: float = heights[each].get_combined_minimum_size().y
		runner.check(height >= want[each][0] - 0.5 and height <= want[each][1] + 0.5, "T4 %s is %s-%s px high like the round, got %s" % [each, want[each][0], want[each][1], height])
	launcher.free()
	return true

func test_round4_minors(runner) -> bool:
	var theme: Theme = _launcher_theme()
	runner.check(_font_path(theme.get_font("font", "LineEdit")) == SEMIBOLD and theme.get_color("font_color", "LineEdit") == TEXT, "M1 LineEdit text is SemiBold in the text colour")
	for link_type: String in ["FooterLink", "SidebarLink"]:
		for state: String in ["focus_color", "pressed_color", "hover_pressed_color"]:
			runner.check(theme.get_color("font_" + state, link_type) == MUTED, "M2 %s font_%s stays muted like its normal state" % [link_type, state])
		runner.check(theme.get_stylebox("focus", link_type) == theme.get_stylebox("focus", "FooterLink"), "M2 %s focus uses the launcher focus ring" % link_type)
	runner.check(theme.get_color("font_focus_color", "FooterLink") == theme.get_color("font_color", "FooterLink"), "M2 FooterLink focus text matches its normal text")
	for pair: Array in [["Button", "normal"], ["OptionButton", "normal"], ["LineEdit", "normal"], ["Tag", "normal"], ["PlayerRow", "panel"]]:
		var style: StyleBox = theme.get_stylebox(pair[1], pair[0])
		runner.check(style is StyleBoxFlat and style.border_color.is_equal_approx(LINE) and style.border_width_left == 1, "M3 %s border is the round's --line #2e3f4b, got %s" % [pair[0], style.border_color if style is StyleBoxFlat else "no flat style"])
	for pair: Array in [["OptionButton", WELL], ["LineEdit", WELL], ["Button", PANEL], ["PlayerRow", PANEL]]:
		var fill: StyleBox = theme.get_stylebox("panel" if pair[0] == "PlayerRow" else "normal", pair[0])
		runner.check(fill is StyleBoxFlat and fill.bg_color.is_equal_approx(pair[1]), "M3 %s fills with the round's %s" % [pair[0], pair[1].to_html(false)])
	return true

func test_primary_button_is_amber_with_dark_ink(runner) -> bool:
	var theme: Theme = _launcher_theme()
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style: StyleBox = theme.get_stylebox(state, "PrimaryButton")
		runner.check(style is StyleBoxFlat and style.bg_color.h > 0.09 and style.bg_color.h < 0.13 and style.bg_color.s > 0.3 and style.border_width_bottom == 4, "P1 primary %s fill is amber over a 4 px shadow edge, got %s" % [state, style.bg_color if style is StyleBoxFlat else "no flat style"])
	runner.check(theme.get_stylebox("normal", "PrimaryButton").bg_color == ACTION, "P1 primary normal fill is #f7c871")
	runner.check(theme.get_stylebox("hover", "PrimaryButton").bg_color.get_luminance() > ACTION.get_luminance(), "P1 primary hover is lighter")
	runner.check(theme.get_stylebox("pressed", "PrimaryButton").bg_color.get_luminance() < ACTION.get_luminance(), "P1 primary pressed is darker")
	runner.check(theme.get_stylebox("disabled", "PrimaryButton").bg_color.is_equal_approx(Color("#34434d")) and theme.get_color("font_disabled_color", "PrimaryButton").is_equal_approx(Color("#8799a4")), "P1 primary disabled is the round's slate with grey text")
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
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
	await _settle(runner, launcher, "Play")
	for dropdown: OptionButton in [launcher._own_selector(), _row(launcher, 2, "Bot1").get_node("Faction")]:
		var path: String = dropdown.get_parent().get_parent().name
		var font: Font = dropdown.get_theme_font("font")
		var text_width: float = font.get_string_size(dropdown.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dropdown.get_theme_font_size("font_size")).x
		var arrow: float = dropdown.get_theme_icon("arrow").get_size().x
		var gap: float = dropdown.size.x - dropdown.get_theme_constant("arrow_margin") - arrow - (dropdown.get_theme_stylebox("normal").get_margin(SIDE_LEFT) + text_width)
		runner.check(dropdown.text == "Free Resistance Coalition" and gap >= 8.0, "M4 %s keeps 8 px between '%s' and the arrow at 1280x720, got %s" % [path, dropdown.text, gap])
	built[1].free()
	built[0].free()
	_restore(saved)
	return true

func test_footer_error_hugs_text(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "hug", {})
	_restore(saved)
	launcher._origin = "Play"
	launcher._fail("Cannot connect to relay")
	await runner.process_frame
	await runner.process_frame
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	var button: Control = launcher.get_node("Pages/Play/Footer/Start")
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
	var launcher = await _launcher_with(runner, "waiting-bold", {"map": "broken_crown"})
	_restore(saved)
	_lobby_host(launcher)
	var code: Label = launcher.get_node(MODE_BAR + "/Invite/Box/Code")
	runner.check(code.text == "ABC 234" and _font_path(code.get_theme_font("font")) == EXTRABOLD and code.get_theme_font_size("font_size") == 16, "F4 the code shows in Public Sans ExtraBold at 16 px")
	var row: Control = _row(launcher, 1, "Friend").get_parent()
	var style: StyleBox = row.get_theme_stylebox("panel")
	runner.check(row.get_script() == DashedPanel and style is StyleBoxFlat and style.border_width_left == 0 and style.border_width_top == 0, "F4 the open friend row draws a dashed outline instead of a solid border")
	runner.check(row.color.is_equal_approx(LINE), "F4 the dashes are the round's --line, got %s" % row.color)
	var corners: PackedVector2Array = DashedPanel.edges(Rect2(0, 0, 100, 40))
	runner.check(corners == PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 0), Vector2(100, 40), Vector2(100, 40), Vector2(0, 40), Vector2(0, 40), Vector2(0, 0)]), "F4 the dashed outline has four edges, got %s" % [corners])
	launcher._transport = null
	launcher.free()
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
	launcher.set_mode("join")
	launcher._set_relay(LOOPBACK)
	var code: LineEdit = launcher.get_node(JOIN + "/Code")
	code.text = ""
	code.text_submitted.emit("")
	launcher.set_process(false)
	runner.check(launcher._transport == null and _message(launcher).text == LauncherScript.NEED_CODE, "L19 Enter on an empty code does not connect and says what to enter")
	code.text = "ABC234"
	code.text_submitted.emit("ABC234")
	launcher.set_process(false)
	runner.check(launcher._transport != null and launcher.get_node("Sidebar/Nav/Quit").disabled, "L19 Enter on a valid code connects and locks Quit")
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
	runner.check(launcher.mode == "join" and launcher._transport != null, "L19b Enter joins on Join game opened by a link, without clicking the field")
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
	var own: String = _picked(launcher._own_selector())
	var bots: Array[String] = launcher.lobby_bots.duplicate()
	var map: String = launcher._map_id()
	runner.check(cancel.visible and cancel.text == "Cancel", "L20 busy Play shows the connect Cancel button")
	runner.check(launcher.get_viewport().gui_get_focus_owner() == cancel, "L20 busy Play moves focus to Cancel")
	launcher._show_connecting(launcher._connect_msec + 3200)
	runner.check(status.text == "Connecting… 3 s", "L20 Play shows whole seconds, got '%s'" % status.text)
	cancel.pressed.emit()
	runner.check(transport.close_calls == 1 and status.text == "Hosting cancelled" and not launcher.get_node("Sidebar/Nav/Quit").disabled and not cancel.visible and launcher.mode == "skirmish", "L20 Cancel closes, says Hosting cancelled, unlocks, goes back to Skirmish")
	runner.check(_picked(launcher._own_selector()) == own and launcher.lobby_bots == bots and launcher._map_id() == map, "L20 Own, bots and map are unchanged")
	runner.check(launcher.get_viewport().gui_get_focus_owner() == launcher.get_node("Pages/Play/Footer/Start"), "L20 Cancel hands focus back to Start match")
	status.text = "Idle"
	launcher.get_viewport().push_input(InputEventMIDI.new())
	runner.check(not launcher.get_viewport().is_input_handled(), "L20 fixture: handled flag clear")
	launcher._unhandled_input(_esc())
	runner.check(status.text == "Idle" and not launcher.get_viewport().is_input_handled(), "L20 Esc without a transport changes nothing and is not swallowed")
	_join_with(launcher, "ABC234")
	var join_transport := OnlineTests.FakeTransport.new()
	launcher._transport = join_transport
	var card_cancel: Button = launcher.get_node(JOIN + "/Buttons/Cancel")
	runner.check(_focused(launcher) == card_cancel and not card_cancel.disabled and launcher.get_node(JOIN + "/Buttons/Join").disabled, "L20 joining moves the focus to the card's Cancel and locks Join game")
	launcher._show_connecting(launcher._connect_msec + 3200)
	runner.check(_message(launcher).text == "Connecting… 3 s", "L20 the card counts the seconds under the field, got '%s'" % _message(launcher).text)
	launcher.get_node(JOIN + "/Code").text = "XYZ234"
	launcher._join()
	runner.check(launcher._transport == join_transport, "L20 a second Join while connecting keeps the first connection")
	launcher._unhandled_input(_esc())
	runner.check(join_transport.close_calls == 1 and _message(launcher).text == "Join cancelled" and launcher.mode == "join", "L20 Esc cancels a connecting join, reason under the field")
	_join_with(launcher, "ABC234")
	join_transport = OnlineTests.FakeTransport.new()
	launcher._transport = join_transport
	card_cancel.pressed.emit()
	runner.check(join_transport.close_calls == 1 and launcher.mode == "join", "L20 the card's Cancel while connecting cancels the connection and stays")
	card_cancel.pressed.emit()
	runner.check(launcher.mode == "skirmish", "L20 the card's Cancel when idle returns to Skirmish")
	var host = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	launcher._unhandled_input(_esc())
	runner.check(host.close_calls == 0 and launcher.current_page == "Play" and launcher._transport != null, "L20 Esc while hosting leaves the room open")
	launcher._transport = null
	launcher.free()
	return true

func test_connecting_footers_fit(runner) -> bool:
	var saved: String = AudioSettings.path
	var ported: Array = await _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	_restore(saved)
	var launcher = ported[1]
	launcher.set_mode("host")
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._set_busy(true)
	for shown: Array in [["Connecting… 12 s", false], ["Cannot connect to relay", true]]:
		var status: Label = launcher.get_node("Pages/Play/Footer/Status")
		launcher._show_status(status, shown[0], shown[1])
		await runner.process_frame
		await runner.process_frame
		runner.check(status.visible and status.text == shown[0] and status.size.x > 0.0, "L8 fixture: the footer shows '%s'" % shown[0])
		_overlap_free(runner, launcher.get_node("Pages/Play/Footer"), "busy footer, '%s'" % shown[0])
		var footer: Control = launcher.get_node("Pages/Play/Footer")
		for child: Control in [status, launcher.get_node("Pages/Play/Footer/CancelConnect")]:
			runner.check(footer.get_global_rect().encloses(child.get_global_rect()) and launcher.get_viewport().get_visible_rect().encloses(child.get_global_rect()), "L8 busy footer holds %s with '%s'" % [child.name, shown[0]])
	launcher._transport = null
	ported[0].free()
	return true

func _fake_clock_launcher(launcher, transport_clock: FakeClock) -> Object:
	launcher._clock = transport_clock.now
	launcher._set_relay(LOOPBACK)
	launcher.get_node("Pages/Play/ModeBar/Host").pressed.emit()
	var transport := RelayTransport.new(transport_clock.now)
	transport._sent_any = true
	transport._last_rx = transport_clock.usec
	launcher._transport = transport
	launcher._connect_msec = floori(transport_clock.usec / 1000.0)
	return transport

func test_lobby_countdown_and_expiry(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "countdown", {})
	_restore(saved)
	var transport = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var footer: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(transport.patient and footer.text == "Start match unlocks when your friend joins", "L21 welcome makes the transport patient; no clock while time is plenty, got '%s'" % footer.text)
	for case: Array in [[61_000, ""], [719_000, ""], [720_000, " · room closes in 3:00"], [721_000, " · room closes in 2:59"], [900_000, " · room closes in 0:00"], [1_000_000, " · room closes in 0:00"]]:
		launcher._show_status_if_changed(footer, launcher._timed(LauncherScript.FRIEND_WAIT, launcher._room_msec + 900_000, launcher._room_msec + case[0]))
		runner.check(footer.text == "Start match unlocks when your friend joins" + case[1], "L21 +%d ms reads '%s', got '%s'" % [case[0], case[1], footer.text])
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(status.text == LauncherScript.DID_NOT_JOIN and LauncherScript.DID_NOT_JOIN.ends_with(LauncherScript.NEW_CODE) and status.theme_type_variation == &"FooterError" and launcher.current_page == "Play" and launcher.mode == "host", "L21 lobby expired fails with the friend message in the error style")
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
	runner.check(status.text == UNREACHABLE % LOOPBACK and launcher.mode == "host", "L22 before welcome 6 s of silence reads as an unreachable relay, on Host game, got '%s'" % status.text)
	var transport = _fake_clock_launcher(launcher, clock)
	launcher._hello_sent = true
	launcher.set_process(false)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	clock.usec += 600_000_000
	launcher._process(0.0)
	runner.check(launcher._transport == transport and launcher.current_page == "Play" and transport.patient, "L22 after welcome 600 s of silence keeps the lobby")
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
	clock.usec += 721_000_000
	launcher._process(0.0)
	runner.check(status.text == "Start match unlocks when your friend joins · room closes in 2:59", "L23 _process shows the countdown in the last 3 minutes, got '%s'" % status.text)
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
	runner.check(_focused(launcher) == play.get_node("Footer/Start"), "L24 Play with a bot focuses Start, got %s" % _focused(launcher))
	_host(launcher)
	runner.check(_focused(launcher) == play.get_node("Footer/CancelConnect"), "L24 Host game moves focus to Cancel while connecting, got %s" % _focused(launcher))
	launcher._cancel()
	runner.check(_focused(launcher) == play.get_node("Footer/Start"), "L24 back on Skirmish the focus is on Start, got %s" % _focused(launcher))
	launcher.get_node(JOIN + "/Code").text = ""
	play.get_node("ModeBar/Join").pressed.emit()
	runner.check(_focused(launcher) == launcher.get_node(JOIN + "/Code"), "L24 Join game with an empty code focuses the code field, got %s" % _focused(launcher))
	launcher.get_node(JOIN + "/Code").text = "ABC234"
	launcher.set_mode("join")
	runner.check(_focused(launcher) == launcher.get_node(JOIN + "/Buttons/Join"), "L24 Join game with a code focuses Join game, got %s" % _focused(launcher))
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(launcher.current_page == "Play" and _focused(launcher) == launcher.get_node("Pages/Play/ModeBar/Invite/Box/Copy"), "L24 the code arriving focuses Copy, got %s" % _focused(launcher))
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
	for path: String in ["own", "bot", "map"]:
		var selector: OptionButton = {"own": launcher._own_selector(), "bot": _row(launcher, 2, "Bot1").get_node("Faction"), "map": launcher.get_node(MAP_COLUMN + "/Map")}[path]
		selector.select(1)
		selector.item_selected.emit(1)
		runner.check(_focused(launcher) == launcher.get_node("Pages/Play/Footer/Start") and started[0] == 0, "L25 picking in %s focuses Start without pressing it, got %s" % [path, _focused(launcher)])
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
	for view: Array in [["Play", "skirmish"], ["Play", "host"], ["Play", "join"], ["Settings", "skirmish"], ["Credits", "skirmish"]]:
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
		labels.append(launcher.get_node("Pages/Play/ModeBar/Invite/Box").tooltip_text)
		launcher.free()
	_restore(saved)
	runner.check(labels == [LauncherScript.INVITE_TIP, LauncherScript.INVITE_TIP_WEB], "L29 the code's tooltip follows the page, got %s" % [labels])
	return true

# The round's hover tints; null means the hover style has no fill.
const HOVER_FILLS: Dictionary = {"Button": Color("#26384a"), "OptionButton": Color("#16212a"), "NavButton": Color("#16212a"), "ToggleButton": Color("#26384a"), "PrimaryButton": Color("#fad48a"), "CheckButton": Color("#16212a"), "FooterLink": null}

func test_focus_differs_from_hover(runner) -> bool:
	var theme: Theme = _launcher_theme()
	for type: String in HOVER_FILLS:
		var focus: StyleBox = theme.get_stylebox("focus", type)
		var hover: StyleBox = theme.get_stylebox("hover", type)
		runner.check(focus is StyleBoxFlat and focus != hover, "L30 %s focus is its own style, not the hover style" % type)
		if not focus is StyleBoxFlat: continue
		var ring: StyleBoxFlat = focus
		runner.check(not ring.draw_center and ring.border_color == CYAN, "L30 %s focus is an unfilled cyan ring like the round's" % type)
		runner.check(ring.border_width_left == 2 and ring.border_width_top == 2 and ring.border_width_right == 2 and ring.border_width_bottom == 2, "L30 %s focus ring is 2 px on every side" % type)
		runner.check(ring.expand_margin_left == 3.0 and ring.expand_margin_top == 3.0 and ring.expand_margin_right == 3.0 and ring.expand_margin_bottom == 3.0, "L30 %s focus ring floats 3 px outside the button" % type)
		runner.check(ring.corner_radius_top_left <= 2 and ring.corner_radius_bottom_right <= 2, "L30 %s focus ring radius is at most 2, like the button" % type)
		var fill: Variant = HOVER_FILLS[type]
		var unchanged: bool = not hover is StyleBoxFlat if fill == null else hover is StyleBoxFlat and hover.bg_color.is_equal_approx(fill)
		runner.check(unchanged, "L30 %s hover is a background tint, %s" % [type, fill])
	return true

func test_focus_ring_fits(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("focus-ring-fits")
	var setup: Array = _port_with_launcher(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	_restore(saved)
	var launcher = setup[1]
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for page: Array in [["Play", "skirmish"], ["Play", "host"], ["Play", "join"], ["Settings", "skirmish"], ["Credits", "skirmish"]]:
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

const VERSION_LINE := "Your game is v%s; your friend’s is different. Both of you need the same version."

func _pick(selector: OptionButton, id: String) -> void:
	var index: int = _index_where(selector, func(item: String) -> bool: return item == id)
	selector.select(index)
	selector.item_selected.emit(index)

# Hosts a match with these bots and sends the hello through a transport that is already open.
func _host_team(launcher, bots: Array = ["china", "frc"]) -> Object:
	launcher._set_relay(LOOPBACK)
	launcher.lobby_bots.assign(bots)
	launcher.get_node(MODE_BAR + "/Host").pressed.emit()
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

# The start goes through the wire, so its numbers arrive as floats like the relay's; then the host's Start match.
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
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "modes", {})
	_restore(saved)
	var bar: Control = launcher.get_node(MODE_BAR)
	var toggles: Array = ["Skirmish", "Host", "Join"].map(func(each: String) -> String: return bar.get_node(each).text)
	runner.check(toggles == ["Skirmish", "Host game", "Join game"] and bar.get_node("ModeLabel").text == "Mode", "M7 the mode row is Mode: Skirmish, Host game, Join game, got %s" % [toggles])
	runner.check(launcher.get_node("Pages/Play/Subtitle").text == LauncherScript.SKIRMISH_SUBTITLE, "M7 Skirmish subtitle")
	var transport = _host(launcher)
	runner.check(launcher.mode == "host" and bar.get_node("Host").button_pressed and not bar.get_node("Skirmish").button_pressed and launcher.get_node("Pages/Play/Subtitle").text == LauncherScript.HOST_SUBTITLE, "M7 Host game selects the online mode")
	bar.get_node("Host").pressed.emit()
	runner.check(launcher.mode == "host" and bar.get_node("Host").button_pressed and is_same(launcher._transport, transport), "M7 pressing Host game again keeps it and its room")
	launcher._cancel()
	bar.get_node("Join").pressed.emit()
	var shown: Array = [launcher.get_node("Pages/Play/JoinCard").visible, launcher.get_node("Pages/Play/Body").visible, launcher.get_node("Pages/Play/Footer").visible]
	runner.check(launcher.mode == "join" and bar.get_node("Join").button_pressed and not bar.get_node("Host").button_pressed and shown == [true, false, false] and launcher.get_node("Pages/Play/Subtitle").text == LauncherScript.JOIN_SUBTITLE, "M7 Join game shows the card alone, got %s" % [shown])
	runner.check(launcher.get_node(JOIN + "/Title").text == "Join a game" and launcher.get_node(JOIN + "/Hint").text == "Enter the invite code from your friend." and launcher.get_node(JOIN + "/CodeLabel").text == "Invite code" and launcher.get_node(JOIN + "/Buttons/Cancel").text == "Cancel" and launcher.get_node(JOIN + "/Buttons/Join").text == "Join game", "M7 the card reads like the owner's dialog")
	await runner.process_frame
	await runner.process_frame
	var widths: Array = ["Skirmish", "Host", "Join"].map(func(each: String) -> float: return bar.get_node(each).size.x)
	runner.check(widths.all(func(width: float) -> bool: return absf(width - widths[0]) < 1.0), "M7 the three toggles share a width, got %s" % [widths])
	launcher.free()
	return true

func test_team_mode_shows_bot_rows(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "bot-rows", {"map": "broken_crown"})
	_restore(saved)
	launcher._add_bot()
	for mode: String in ["skirmish", "host"]:
		launcher.set_mode(mode)
		runner.check(_rows(launcher, 2) == ["Bot1", "Bot2"] and launcher.get_node(PLAYERS + "/Teams/List/Team2/Head").text == "Team 2", "M8 both modes list the enemy bots under Team 2, %s" % mode)
		for row: String in ["Bot1", "Bot2"]:
			var selector: OptionButton = _row(launcher, 2, row).get_node("Faction")
			runner.check(selector.item_count == 4 and selector.get_item_text(1) == "Free Resistance Coalition" and selector.get_item_text(3) == "Random", "M8 %s lists the factions by display name, Random last" % row)
	runner.check(_picked(_row(launcher, 2, "Bot2").get_node("Faction")) == "random", "M8 an added bot starts on Random")
	launcher.free()
	return true

func test_team_bot_factions_remembered(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("team-bots-defaults")
	var config := ConfigFile.new()
	config.set_value("launcher", "bot_faction", "gla")
	config.set_value("launcher", "faction", "random")
	config.save(AudioSettings.path)
	var fallback: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	runner.check(fallback.bots == ["usa"] and fallback.faction == "random", "M9 a bad stored bot falls back alone; Random is a valid pick, got %s" % [fallback])
	var before: Array = OnlineTests._statics()
	AudioSettings.path = scratch_for("team-bots")
	LauncherSettings.save_picks({"bot_faction": "frc", "map": "broken_crown"})
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	runner.check(launcher.lobby_bots == ["frc"], "M9 the opening bot is the remembered one")
	_host_team(launcher, ["china", "usa"])
	await _start_through_wire(runner, launcher, OnlineTests.new()._start_message_2v2(5))
	var picks: Dictionary = LauncherSettings.load_picks()
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(picks.bots == ["china", "usa"], "M9 the host's start remembers the bots it played, got %s" % [picks.bots])
	return true

func _bot_rows(settings: Dictionary) -> Array:
	return settings.get("bots", []).map(func(row: Dictionary) -> Array: return [row.player, row.faction])

func test_team_hello_carries_bots(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-hello", {"map": "ashfall"})
	_restore(saved)
	var team: Dictionary = _hello(_host_team(launcher)).get("settings", {})
	var plain: Dictionary = MatchSettings.for_map("ashfall")
	runner.check(team.get("map") == "ashfall" and team.get("map_hash") == plain.map_hash and _bot_rows(team) == [[3.0, "china"], [4.0, "frc"]], "M12 the hello carries the map and both bots, got %s" % [team])
	launcher._fail(LauncherScript.HOST_CANCELLED)
	var open: Object = _host_team(launcher, [])
	var friend: Dictionary = _hello(open).get("settings", {})
	runner.check(friend.get("map") == "ashfall" and friend.get("map_hash") == plain.map_hash and not friend.has("bots") and _players(friend).size() == 1, "M12 without bots the 1v1 hello carries no bots, got %s" % [friend])
	launcher._transport = null
	launcher.free()
	return true

func test_team_changes_while_connecting(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-connecting", {"map": "ashfall"})
	_restore(saved)
	var clock := FakeClock.new()
	launcher._clock = clock.now
	var transport = _host_team(launcher, ["frc", "random"])
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "china")
	clock.usec += 1_000_000
	launcher._process(0.0)
	runner.check(_row(launcher, 2, "Bot1").get_node("Faction") is OptionButton and launcher.get_node(MAP_COLUMN + "/Map").visible and _sent(transport, "settings").is_empty(), "M13 the setup stays editable while connecting and nothing goes before the welcome")
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234","settings":{}}')
	launcher._process(0.0)
	var sent: Array[Dictionary] = _sent(transport, "settings")
	runner.check(sent.size() == 1 and sent[0].settings.bots[0].faction == "china", "M13 a change made while connecting goes out after the welcome, got %s" % [sent])
	launcher._fail("Connection to relay lost")
	runner.check(launcher.lobby_bots == ["china", "random"], "M13 a failure keeps Random as picked, got %s" % [launcher.lobby_bots])
	launcher.free()
	return true

func test_waiting_lists_bot_slots(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-waiting", {"faction": "usa", "map": "broken_crown"})
	_restore(saved)
	_host_team(launcher, ["china", "frc"])
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(_rows(launcher, 1) == ["You", "Friend"] and _rows(launcher, 2) == ["Bot1", "Bot2"], "M14 the friend waits on your team against both bots")
	var want: Array = [["You", 1, Palette.OWNER_BASE[0]], ["Bot1", 2, Palette.OWNER_BASE[1]], ["Bot2", 2, Palette.OWNER_BASE[6]]]
	for row: Array in want:
		runner.check(_row(launcher, row[1], row[0]).get_node("Swatch").color == row[2], "M14 %s's swatch is the colour the match draws" % row[0])
	_friend_joins(launcher)
	runner.check(_row(launcher, 1, "Friend").get_node("Swatch").color == Palette.OWNER_BASE[4], "M14 the friend's swatch is the guest teal")
	launcher._cancel()
	_host_team(launcher, [])
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(_rows(launcher, 1) == ["You"] and _rows(launcher, 2) == ["Friend"], "M14 without bots the friend is the other team")
	launcher._transport = null
	launcher.free()
	return true

func test_waiting_edges_neon(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "team-waiting-neon", {"faction": "usa", "map": "broken_crown"})
	GraphicsSettings.save_neon(true)
	_host_team(launcher, ["china", "frc"])
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var swatches: Array = [_row(launcher, 1, "You"), _row(launcher, 2, "Bot1"), _row(launcher, 2, "Bot2")].map(func(row: Control) -> Color: return row.get_node("Swatch").color)
	var want: Array = [Palette.OWNER_BRIGHT[0], Palette.OWNER_BRIGHT[Palette.BOT_SLOTS[0][1]], Palette.OWNER_BRIGHT[Palette.BOT_SLOTS[1][1]]]
	runner.check(swatches == want, "M14 under Neon the swatches use the Neon hues the match will show, got %s want %s" % [swatches, want])
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
	var stored: Array = LauncherSettings.load_picks().bots
	var map: String = LauncherSettings.load_picks().map
	_restore(saved)
	OnlineTests._restore_statics(before)
	runner.check(got[0] == {3: "china", 4: "frc"} and got[1] == MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2)), "M18 the guest seats the host's bots on the host's team starts, got %s %s" % [got[0], got[1]])
	runner.check(stored == ["usa"] and map == "dry_wells", "M18 the guest remembers neither the host's bots nor its map, got %s %s" % [stored, map])
	return true

func _version_footer(runner, launcher, web: bool) -> Label:
	launcher.web = web
	_join_with(launcher, "ABC234")
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._handle('{"type":"error","reason":"build mismatch"}')
	await runner.process_frame
	await runner.process_frame
	return _message(launcher)

func test_version_mismatch_plain_line(runner) -> bool:
	var line: String = VERSION_LINE % ProjectSettings.get_setting("application/config/version")
	var seen: Array[String] = []
	for web: bool in [false, true]:
		var saved: String = AudioSettings.path
		var launcher = await _launcher_with(runner, "version", {})
		_restore(saved)
		var status: Label = await _version_footer(runner, launcher, web)
		runner.check(status.text == line and status.theme_type_variation == &"JoinError", "M16 the refused joiner reads the version line (web %s), got '%s'" % [web, status.text])
		runner.check(launcher.current_page == "Play" and launcher.mode == "join" and launcher._transport == null, "M16 the joiner stays on Join game, disconnected")
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
	LauncherSettings.save_picks({"map": "broken_crown"})
	for pair: Array in BaseScene.HUD_SIZES:
		var built: Array = _port_with_launcher(runner, pair[0], pair[1])
		var launcher = built[1]
		var size: Vector2i = pair[1]
		for mode: String in ["skirmish", "host"]:
			await _settle(runner, launcher, "Play", mode)
			_layout_ok(runner, launcher, launcher.get_node("Pages/Play"), "Play %s at %s" % [mode, size])
		var status: Label = await _version_footer(runner, launcher, false)
		var card: Rect2 = launcher.get_node("Pages/Play/JoinCard/Card").get_global_rect()
		runner.check(card.grow(0.5).encloses(status.get_global_rect()) and status.get_line_count() <= 2, "M17 the version line fits the card under the field at %s, got %s lines" % [size, status.get_line_count()])
		_layout_ok(runner, launcher, launcher.get_node("Pages/Play"), "Join game version line at %s" % size)
		built[1].free()
		built[0].free()
	_restore(saved)
	return true

const PLAYERS := "Pages/Play/Body/Players"
const MAP_COLUMN := "Pages/Play/Body/MapColumn"
const MODE_BAR := "Pages/Play/ModeBar"

func _rows(launcher, team: int) -> Array[String]:
	var names: Array[String] = []
	for row: Node in launcher.get_node("%s/Teams/List/Team%d" % [PLAYERS, team]).get_children():
		if row.name != "Head" and not row.is_queued_for_deletion(): names.append(str(row.name))
	return names

func _row(launcher, team: int, row_name: String) -> Control:
	return launcher.get_node("%s/Teams/List/Team%d/%s/Row" % [PLAYERS, team, row_name])

func _count_line(launcher) -> String:
	return launcher.get_node(PLAYERS + "/Count/Line").text

func _add_bot(launcher) -> Button:
	return launcher.get_node(PLAYERS + "/Count/AddBot")

# Opens the room through a transport that is already open, then the relay's welcome.
func _lobby_host(launcher, map: String = "broken_crown") -> Object:
	launcher.show_page("Play")
	_pick(launcher.get_node(MAP_COLUMN + "/Map"), map)
	var transport: Object = _host_team(launcher, launcher.lobby_bots.duplicate())
	launcher._handle(Wire.encode({"type": "welcome", "seat": 1, "match": "ABC234", "settings": _hello(transport).get("settings", {})}))
	return transport

func _friend_joins(launcher) -> void:
	launcher._handle('{"type":"joined","seat":2}')

# The friend joins, the host presses Start match and the relay's start comes back with the room's settings.
func _host_start(launcher) -> void:
	_friend_joins(launcher)
	launcher.get_node("Pages/Play/Footer/Start").pressed.emit()
	launcher._handle(Wire.encode({"type": "start", "seats": [1, 2], "delay": 4, "seed": 7, "settings": launcher._settings}))

func _lobby_guest(launcher, settings: Dictionary) -> Object:
	_join_with(launcher, "ABC234")
	var transport := OpenTransport.new()
	launcher._transport = transport
	launcher._hello_sent = true
	launcher._handle(Wire.encode({"type": "welcome", "seat": 2, "match": "ABC234", "settings": settings}))
	return transport

func _sent(transport, type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for text: String in transport.sent:
		var message: Dictionary = Wire.decode(text).message
		if message.get("type") == type: found.append(message)
	return found

func _cue(launcher) -> Label:
	return launcher.get_node(PLAYERS + "/Cue")

func _team_settings(map: String, factions: Array) -> Dictionary:
	var bots: Array = []
	for i in factions.size(): bots.append({"player": 3 + i, "faction": factions[i]})
	return MatchSettings.for_map(map, bots)

const GAME_THEME := "res://ui/game_theme.tres"
const LAUNCHER_THEME := "res://ui/launcher_theme.tres"
const ResultPanel = preload("res://scripts/match/result_panel.gd")

# The navy look is the launcher's own; the match keeps the project theme.
func test_launcher_theme_stays_in_the_launcher(runner) -> bool:
	runner.check(ProjectSettings.get_setting("gui/theme/custom") == GAME_THEME, "TM1 the project theme is the game's, got %s" % ProjectSettings.get_setting("gui/theme/custom"))
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "theme-scope", {})
	_restore(saved)
	var game: Theme = load(GAME_THEME)
	var navy: Theme = load(LAUNCHER_THEME)
	runner.check(launcher.theme == navy, "TM1 the launcher root carries the launcher theme, got %s" % launcher.theme)
	var panel := ResultPanel.new()
	runner.root.add_child(panel)
	await runner.process_frame
	var game_button := Button.new()
	panel.add_child(game_button)
	var launcher_button: Button = launcher.get_node("Pages/Play/Footer/CancelConnect")
	runner.check(game_button.get_theme_stylebox("normal") == game.get_stylebox("normal", "Button") and launcher_button.get_theme_stylebox("normal") == navy.get_stylebox("normal", "Button") and game_button.get_theme_stylebox("normal") != launcher_button.get_theme_stylebox("normal"), "TM1 a result-panel Button and a launcher Button resolve different normal styles")
	runner.check(game_button.get_theme_default_font_size() == game.default_font_size and launcher_button.get_theme_default_font_size() == navy.default_font_size, "TM1 each side keeps its default font size")
	var popup: PopupMenu = launcher.get_node(MAP_COLUMN + "/Map").get_popup()
	var confirm: ConfirmationDialog = launcher.get_node("Confirm")
	runner.check(popup.get_theme_stylebox("panel") == navy.get_stylebox("panel", "PopupMenu") and confirm.get_ok_button().get_theme_stylebox("normal") == navy.get_stylebox("normal", "Button"), "TM1 the launcher's dropdown popup and confirm dialog keep the navy look")
	runner.check(not Array(navy.get_type_list()).any(func(type: String) -> bool: return type.begins_with("Hud") or type == "Tokens") and game.has_color(&"warn", &"Tokens"), "TM1 the HUD entries and Tokens live in the game theme only")
	var launcher_only: Array[String] = ["NavButton", "SidebarLink", "SidebarVersion", "Logo", "PageTitle", "Subtitle", "FooterLink", "FooterStatus", "FooterError", "FooterRich", "PlayerRow", "OpenSlot", "OpenSlotGap", "MapPanel", "FieldLabel", "CreditsText", "ToggleButton", "HintRich", "PanelTitle"]
	var leaked: Array = Array(game.get_type_list()).filter(func(type: String) -> bool: return type in launcher_only)
	runner.check(leaked.is_empty(), "TM1 the game theme holds no launcher-only type, got %s" % [leaked])
	panel.free()
	launcher.free()
	return true

func test_lobby_one_click_bot_match(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-one-click", {"faction": "china", "bot_faction": "frc", "map": "broken_crown"})
	_restore(saved)
	var start: Button = launcher.get_node("Pages/Play/Footer/Start")
	runner.check(launcher.mode == "skirmish" and launcher.get_node(MODE_BAR + "/Skirmish").button_pressed and not launcher.get_node(MODE_BAR + "/Host").button_pressed, "LL1 Play opens on Skirmish")
	runner.check(_rows(launcher, 1) == ["You"] and _rows(launcher, 2) == ["Bot1"] and launcher.lobby_bots == ["frc"], "LL1 You on Team 1 against one remembered bot on Team 2, got %s %s %s" % [_rows(launcher, 1), _rows(launcher, 2), launcher.lobby_bots])
	runner.check(_focused(launcher) == start and not start.disabled and start.visible, "LL1 Start match is focused and enabled, one click from launch")
	runner.check(_picked(launcher._own_selector()) == "china" and _picked(_row(launcher, 2, "Bot1").get_node("Faction")) == "frc", "LL1 the rows show the remembered factions")
	runner.check(_row(launcher, 1, "You").get_node("Swatch").color == Palette.OWNER_BASE[0] and _row(launcher, 2, "Bot1").get_node("Swatch").color == Palette.OWNER_BASE[1], "LL1 swatches in the hues the offline match draws")
	launcher.free()
	return true

func test_lobby_add_bot_up_to_starts(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-add", {"map": "dry_wells"})
	_restore(saved)
	var full_line: String = "2 of 2 starts used · a bigger map fits more bots"
	runner.check(_count_line(launcher) == full_line and _add_bot(launcher).disabled and _add_bot(launcher).tooltip_text == full_line, "LL2 Dry Wells is full with one bot and says why, line and tooltip alike, got '%s'" % _count_line(launcher))
	runner.check(_add_bot(launcher).text == "+ Add enemy bot", "LL2 the button says it adds an enemy bot")
	_pick(launcher.get_node(MAP_COLUMN + "/Map"), "broken_crown")
	runner.check(_count_line(launcher) == "2 of 4 starts used" and not _add_bot(launcher).disabled and _add_bot(launcher).tooltip_text == "", "LL2 Broken Crown has room, no limit named, got '%s'" % _count_line(launcher))
	_add_bot(launcher).pressed.emit()
	_add_bot(launcher).pressed.emit()
	runner.check(launcher.lobby_bots.size() == 3 and _rows(launcher, 2) == ["Bot1", "Bot2", "Bot3"] and _rows(launcher, 1) == ["You"], "LL2 added bots join Team 2, got %s" % [_rows(launcher, 2)])
	runner.check(_count_line(launcher) == "4 of 4 starts used · a bigger map fits more bots" and _add_bot(launcher).disabled, "LL2 the button turns off at the start count, got '%s'" % _count_line(launcher))
	launcher._add_bot()
	runner.check(launcher.lobby_bots.size() == 3, "LL2 no bot past the start count")
	var map: OptionButton = launcher.get_node(MAP_COLUMN + "/Map")
	runner.check(map.is_item_disabled(_index_where(map, func(id: String) -> bool: return id == "dry_wells")) and not map.is_item_disabled(_index_where(map, func(id: String) -> bool: return id == "ashfall")), "LL2 maps with fewer starts than players are greyed")
	_host(launcher)
	var host_line: String = "3 of 4 starts used · 1 kept for your friend · a bigger map fits more bots"
	runner.check(launcher.lobby_bots == ["usa", "random"] and _count_line(launcher) == host_line and _add_bot(launcher).disabled and _add_bot(launcher).tooltip_text == host_line, "LL2 Host game keeps a start for the friend: the last bot makes room, got %s '%s'" % [launcher.lobby_bots, _count_line(launcher)])
	launcher.free()
	return true

func test_lobby_host_caps_bots(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-cap", {"map": "ashfall"})
	_restore(saved)
	for i in 4: _add_bot(launcher).pressed.emit()
	runner.check(launcher.lobby_bots.size() == 5 and not _add_bot(launcher).disabled, "LL2b fixture: Skirmish on Ashfall holds five bots with room for more")
	_host(launcher)
	var line: String = "3 of 8 starts used · 1 kept for your friend · online games take up to 2 bots"
	runner.check(launcher.lobby_bots.size() == 2 and _add_bot(launcher).disabled and _count_line(launcher) == line and _add_bot(launcher).tooltip_text == line, "LL2b Host game drops bots past two and says online games take two, got %s '%s'" % [launcher.lobby_bots, _count_line(launcher)])
	launcher._add_bot()
	runner.check(launcher.lobby_bots.size() == 2, "LL2b no third bot online")
	launcher._cancel()
	runner.check(launcher.mode == "skirmish" and launcher.lobby_bots.size() == 2 and not _add_bot(launcher).disabled, "LL2b Skirmish keeps the two bots and offers more")
	for i in 6: launcher._add_bot()
	runner.check(launcher.lobby_bots.size() == 7 and _add_bot(launcher).disabled, "LL2b offline takes up to starts - 1 bots, got %d" % launcher.lobby_bots.size())
	launcher.free()
	return true

func test_lobby_remove_bot(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-remove", {"map": "broken_crown"})
	_restore(saved)
	launcher.lobby_bots.assign(["china", "frc"])
	launcher._refresh_play()
	var remove: Button = _row(launcher, 2, "Bot1").get_node_or_null("Remove")
	runner.check(remove != null and remove.tooltip_text == "Remove bot" and remove.text == "" and remove.icon != null and remove.theme_type_variation == &"RemoveButton", "LL3 the bot row has an X with the tooltip Remove bot")
	if remove == null:
		launcher.free()
		return true
	runner.check(remove.get_theme_color("icon_normal_color").is_equal_approx(MUTED) and remove.get_theme_color("icon_hover_color").is_equal_approx(TEXT) and remove.get_theme_stylebox("normal") is StyleBoxEmpty and remove.get_theme_stylebox("hover") is StyleBoxFlat, "LL3 the X is grey at rest and brightens on a lighter square when hovered")
	runner.check(not remove.get_theme_color("icon_hover_color").is_equal_approx(Palette.OWNER_BASE[1]) and remove.get_theme_stylebox("hover").bg_color.h > 0.45 and remove.get_theme_stylebox("hover").bg_color.h < 0.75, "LL3 the hover keeps red for player colours and errors")
	remove.pressed.emit()
	runner.check(launcher.lobby_bots == ["frc"] and _rows(launcher, 2) == ["Bot1"] and _picked(_row(launcher, 2, "Bot1").get_node("Faction")) == "frc", "LL3 one click removes that bot, no confirm, got %s" % [launcher.lobby_bots])
	runner.check(_count_line(launcher) == "2 of 4 starts used", "LL3 the count follows, got '%s'" % _count_line(launcher))
	_row(launcher, 2, "Bot1").get_node("Remove").pressed.emit()
	runner.check(launcher.lobby_bots.is_empty() and launcher.get_node("Pages/Play/Footer/Start").disabled, "LL3 Skirmish without a bot cannot start")
	runner.check(_row(launcher, 1, "You").get_node_or_null("Remove") == null and _row(launcher, 1, "You").get_node("Action").custom_minimum_size.x == LauncherScript.ACTION_WIDTH, "LL3 your own row has no X but keeps the action column")
	launcher.free()
	return true

func test_lobby_random_faction(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-random", {"map": "broken_crown"})
	var own: OptionButton = launcher._own_selector()
	runner.check(own.get_item_text(own.item_count - 1) == "Random" and own.get_item_metadata(own.item_count - 1) == "random", "LL4 Random is the last faction")
	_pick(own, "random")
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "random")
	launcher._offline_setup()
	var picked: Array = SkirmishMain.factions.values()
	runner.check(picked.size() == 2 and picked.all(func(id: String) -> bool: return Registry.Factions.FACTIONS.has(id)), "LL4 Random turns into a real faction at the start, got %s" % [picked])
	var picks: Dictionary = LauncherSettings.load_picks()
	runner.check(picks.faction == "random" and picks.bots == ["random"], "LL4 Random is remembered as Random, got %s" % [picks])
	var transport = _lobby_host(launcher)
	var bots: Array = _hello(transport).get("settings", {}).get("bots", [])
	runner.check(bots.size() == 1 and Registry.Factions.FACTIONS.has(bots[0].faction), "LL4 the host resolves Random bots before the hello, got %s" % [bots])
	_host_start(launcher)
	var main = runner.root.get_tree().current_scene
	runner.check(main != launcher and Registry.Factions.FACTIONS.has(main.driver._own_faction), "LL4 the host's Random is a real faction in choose_faction, got %s" % main.driver._own_faction)
	main.free()
	await runner.process_frame
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func test_lobby_code_at_host_game(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-code", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	runner.check(launcher.get_node_or_null(MODE_BAR + "/GetCode") == null and launcher.get_node_or_null(PLAYERS + "/Locked") == null, "LL5 no Get invite code button and no fixed-setup line")
	var transport = _lobby_host(launcher)
	var hello: Dictionary = _hello(transport)
	runner.check(launcher.mode == "host" and hello.get("protocol") == 3 and hello.get("settings", {}).get("map") == "broken_crown", "LL5 Host game sends a protocol 3 hello with the setup at once, got %s" % [hello])
	var code: Label = launcher.get_node(MODE_BAR + "/Invite/Box/Code")
	runner.check(launcher.get_node(MODE_BAR + "/Invite").visible and code.text == "ABC 234" and launcher.get_node(MODE_BAR + "/Invite/Box/Label").text == "Invite code", "LL5 the welcome puts the code in the mode row with no extra press")
	runner.check(launcher.get_node(MODE_BAR + "/Invite/Box").tooltip_text == LauncherScript.INVITE_TIP and LauncherScript.INVITE_TIP.ends_with("under Join game."), "LL5 the code box explains itself in a tooltip that names Join game")
	runner.check(_mode_locks(launcher) == [[false, ""], [false, ""], [true, LauncherScript.STOP_FIRST]], "LL5 Join game greys out with Stop hosting first; Skirmish stays a way out, got %s" % [_mode_locks(launcher)])
	var bot: Control = _row(launcher, 2, "Bot1")
	runner.check(launcher.get_node(MAP_COLUMN + "/Map").visible and not launcher.get_node(MAP_COLUMN + "/MapName").visible and bot.get_node("Faction") is OptionButton and bot.get_node_or_null("Remove") != null and _add_bot(launcher).visible, "LL5 the host keeps changing the map and the bots")
	runner.check(transport.patient and launcher.get_node("Pages/Play/Footer/Start").disabled and _focused(launcher) == launcher.get_node(MODE_BAR + "/Invite/Box/Copy"), "LL5 waiting: patient, Start locked, Copy focused")
	_add_bot(launcher).pressed.emit()
	runner.check(launcher.lobby_bots.size() == 2 and code.text == "ABC 234" and launcher.get_node(MODE_BAR + "/Invite").visible, "LL5 the code stays through a change")
	launcher.get_node("Pages/Play/Footer/Leave").pressed.emit()
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(transport.close_calls == 1 and not launcher.get_node(MODE_BAR + "/Invite").visible and launcher.mode == "skirmish" and status.text == LauncherScript.HOSTING_STOPPED, "LL5 Stop hosting closes the room and goes back to Skirmish, got %s '%s'" % [launcher.mode, status.text])
	runner.check(launcher._map_id() == "broken_crown" and launcher.lobby_bots.size() == 2, "LL5 the map and the bots stay")
	launcher.free()
	return true

func test_lobby_settings_coalesced(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-coalesce", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	var clock := FakeClock.new()
	launcher._clock = clock.now
	var transport = _lobby_host(launcher)
	var rolls: Array[String] = ["usa", "china", "frc"]
	launcher._roll = func() -> String: return rolls.pop_front()
	var map: OptionButton = launcher.get_node(MAP_COLUMN + "/Map")
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	launcher._process(0.0)
	runner.check(_sent(transport, "settings").is_empty(), "LL16 nothing changed, nothing sent")
	clock.usec += 1_000_000
	_pick(map, "ashfall")
	launcher._process(0.0)
	var sent: Array[Dictionary] = _sent(transport, "settings")
	runner.check(sent.size() == 1 and sent[0].settings.map == "ashfall" and sent[0].settings.map_hash == MatchSettings.for_map("ashfall").map_hash and sent[0].settings.bots.size() == 1 and sent[0].settings.bots[0].faction == "china", "LL16 a map change sends the full snapshot, got %s" % [sent])
	runner.check(launcher._room_msec == floori(clock.usec / 1000.0), "LL16 the send restarts the room's countdown")
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "frc")
	_add_bot(launcher).pressed.emit()
	clock.usec += 700_000
	launcher._process(0.0)
	runner.check(_sent(transport, "settings").size() == 1, "LL16 changes within 0.75 s of a send wait")
	clock.usec += 50_000
	launcher._process(0.0)
	sent = _sent(transport, "settings")
	runner.check(sent.size() == 2 and sent[1].settings.bots.size() == 2 and sent[1].settings.bots[0].faction == "frc" and sent[1].settings.bots[1].player == 4, "LL16 then one send carries the latest snapshot, got %s" % [sent])
	runner.check(sent[1].settings.bots[1].faction == "usa" and sent[1].settings.bots[1].get("random", false) and not sent[1].settings.bots[0].has("random"), "LL16 a Random bot goes out rolled and marked random, got %s" % [sent[1].settings.bots])
	launcher._process(0.0)
	runner.check(_sent(transport, "settings").size() == 2, "LL16 one send per batch of changes")
	clock.usec += 800_000
	_pick(map, "broken_crown")
	launcher._process(0.0)
	sent = _sent(transport, "settings")
	runner.check(sent.size() == 3 and sent[2].settings.bots[1].faction == "usa" and rolls.size() == 2, "LL16 a Random bot keeps its roll across changes, got %s" % [sent])
	clock.usec += 800_000
	_pick(map, "ashfall")
	_pick(map, "broken_crown")
	clock.usec += 800_000
	launcher._process(0.0)
	runner.check(_sent(transport, "settings").size() == 3, "LL16 a change undone within the gap sends nothing")
	_friend_joins(launcher)
	launcher.get_node("Pages/Play/Footer/Start").pressed.emit()
	sent = _sent(transport, "settings")
	runner.check(sent.size() == 4 and sent[3].settings.bots[1].faction == "china" and _sent(transport, "start_request").size() == 1, "LL16 Start match re-rolls the Random bot before it asks, got %s" % [sent])
	runner.check(transport.order.refusals.is_empty(), "LL16 the fake relay refused nothing, got %s" % [transport.order.refusals])
	launcher._transport = null
	launcher.free()
	return true

func test_lobby_friend_joins_and_leaves(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-friend", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	var transport = _lobby_host(launcher)
	var start: Button = launcher.get_node("Pages/Play/Footer/Start")
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(not _cue(launcher).visible, "LL6 no cue before anything happened")
	launcher._on_start()
	runner.check(_sent(transport, "start_request").is_empty(), "LL6 Start match asks nothing before the friend joins")
	_friend_joins(launcher)
	var friend: Control = _row(launcher, 1, "Friend")
	runner.check(friend.get_node("Who/Name").text == "Your friend" and friend.get_node("Faction").text == "Picks at start" and not (friend.get_parent() is DashedPanel), "LL6 joined fills the friend's row, got %s" % [_texts(friend)])
	runner.check(_cue(launcher).visible and _cue(launcher).text == "Your friend joined", "LL6 a short cue says the friend joined, got '%s'" % _cue(launcher).text)
	runner.check(not start.disabled and _focused(launcher) == start and status.text.begins_with("Everyone is here. Start when you are ready"), "LL6 Start unlocks and takes the focus from Copy; the footer says who starts, got '%s' focus %s" % [status.text, _focused(launcher)])
	launcher._handle('{"type":"left","seat":2,"after_tick":3}')
	friend = _row(launcher, 1, "Friend")
	runner.check(launcher._transport == transport and transport.close_calls == 0 and friend.get_node("Who/Name").text == "Open" and launcher.get_node(MODE_BAR + "/Invite/Box/Code").text == "ABC 234", "LL9 the friend leaving reopens the row and keeps the room and the code, got %s" % [_texts(friend)])
	runner.check(_cue(launcher).text == "Your friend left" and start.disabled and status.text.begins_with("Start match unlocks when your friend joins"), "LL9 the cue says the friend left and Start locks again, got '%s' / '%s'" % [_cue(launcher).text, status.text])
	_friend_joins(launcher)
	runner.check(_row(launcher, 1, "Friend").get_node("Who/Name").text == "Your friend" and not start.disabled, "LL9 a second friend takes the same seat")
	launcher._transport = null
	launcher.free()
	return true

func test_lobby_start_request_when_full(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-start", {"faction": "china", "map": "broken_crown", "bots": ["china"]})
	var transport = _lobby_host(launcher)
	var start: Button = launcher.get_node("Pages/Play/Footer/Start")
	_friend_joins(launcher)
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "frc")
	_pick(launcher._own_selector(), "frc")
	start.pressed.emit()
	start.pressed.emit()
	var types: Array = transport.sent.map(func(text: String) -> String: return Wire.decode(text).message.type).filter(func(type: String) -> bool: return type in ["settings", "start_request"])
	runner.check(types == ["settings", "start_request"], "LL6 Start match sends the pending setup, then one start_request, got %s" % [types])
	runner.check(start.disabled and transport.order.refusals.is_empty(), "LL6 Start match turns off once asked; the fake relay refused nothing, got %s" % [transport.order.refusals])
	var bot: Control = _row(launcher, 2, "Bot1")
	runner.check(launcher.get_node(MAP_COLUMN + "/Map").disabled and _add_bot(launcher).disabled and bot.get_node("Faction").disabled and bot.get_node("Remove").disabled, "LL6c once asked, the map, + Add, the bot dropdowns and X lock")
	_pick(bot.get_node("Faction"), "usa")
	launcher._process(0.0)
	runner.check(_sent(transport, "settings").size() == 1 and transport.order.refusals.is_empty(), "LL6c a change after the ask sends no settings, got %d, refusals %s" % [_sent(transport, "settings").size(), transport.order.refusals])
	transport.frames.append('{"type":"left","seat":2,"after_tick":3}')
	launcher._process(0.0)
	runner.check(start.disabled and _row(launcher, 1, "Friend").get_node("Who/Name").text == "Open", "LL6b the friend leaving before the start reopens the row and locks Start")
	runner.check(not launcher.get_node(MAP_COLUMN + "/Map").disabled and not _row(launcher, 2, "Bot1").get_node("Faction").disabled, "LL6c the leave unlocks the setup again")
	_friend_joins(launcher)
	runner.check(not start.disabled, "LL6b the friend back, Start match is offered again (the relay ignored the early ask)")
	start.pressed.emit()
	runner.check(_sent(transport, "start_request").size() == 2 and transport.order.refusals.is_empty(), "LL6b the second Start match asks again, got %d asks, refusals %s" % [_sent(transport, "start_request").size(), transport.order.refusals])
	var scene_before = runner.root.get_tree().current_scene
	runner.check(launcher.is_inside_tree() and not launcher.is_queued_for_deletion() and runner.root.get_tree().current_scene == scene_before, "LL6 the lobby stays until the relay's start")
	transport.frames.append(Wire.encode({"type": "start", "seats": [1, 2], "delay": 4, "seed": 7, "settings": _sent(transport, "settings")[-1].settings}))
	transport.frames.append(Wire.encode(Wire.tick_message(2, 4, [], null)))
	launcher._process(0.0)
	var main = runner.root.get_tree().current_scene
	var opened: bool = main != null and main != launcher
	runner.check(opened and is_same(main.driver._lockstep, launcher._lockstep) and is_same(main.driver._transport, transport) and main.driver._own_faction == "frc", "LL6 the relay's start opens the match with its lockstep, the transport and the current pick")
	runner.check(SkirmishMain.factions == {3: "frc"} and launcher._lockstep.received_any(), "LL6 the match takes the sent setup and a frame after the start in the same batch reaches the lockstep, got %s" % [SkirmishMain.factions])
	if opened: main.free()
	await runner.process_frame
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func test_lobby_guest_live_view(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-guest", {"faction": "usa", "map": "dry_wells"})
	var transport = _lobby_guest(launcher, _team_settings("broken_crown", ["china", "frc"]))
	runner.check(launcher._lockstep == null and launcher.current_page == "Play" and launcher.get_node("Pages/Play/Subtitle").text == LauncherScript.GUEST_SUBTITLE, "LL7 the welcome shows the guest view at once")
	runner.check(_rows(launcher, 1) == ["Host", "You"] and _rows(launcher, 2) == ["Bot1", "Bot2"], "LL7 the guest sees the host's teams, got %s %s" % [_rows(launcher, 1), _rows(launcher, 2)])
	runner.check(_row(launcher, 1, "Host").get_node("Faction").text == "Picks at start" and _row(launcher, 2, "Bot1").get_node("Faction").text == "China", "LL7 host and bots read as text")
	runner.check(launcher._own_selector() != null and not launcher._own_selector().disabled and launcher.get_node(MAP_COLUMN + "/MapName").text == "Broken Crown" and not launcher.get_node(MAP_COLUMN + "/Map").visible, "LL7 only the guest's own faction is a dropdown; the host's map is text")
	runner.check(launcher.get_node(MAP_COLUMN + "/MapHint").text == LauncherScript.HINT_PICK and launcher.get_node("Pages/Play/Footer/Status").text == "Waiting for the host to start" and not launcher.get_node("Pages/Play/Footer/Start").visible, "LL7 guest lines say the host starts, no clock before a change; no Start, got '%s'" % launcher.get_node("Pages/Play/Footer/Status").text)
	runner.check(launcher.get_node(MODE_BAR + "/Join").button_pressed and _mode_locks(launcher) == [[true, LauncherScript.LEAVE_FIRST], [true, LauncherScript.LEAVE_FIRST], [false, ""]], "LL7 the mode row stays on Join game, the others greyed with Leave first, got %s" % [_mode_locks(launcher)])
	runner.check(launcher.get_node(MODE_BAR + "/Invite").visible and launcher.get_node(MODE_BAR + "/Invite/Box/Code").text == "ABC 234" and not launcher.get_node(MODE_BAR + "/Invite/Box/Copy").visible, "LL7 the guest reads Invite code ABC234 in the host's box, without Copy")
	runner.check(not launcher.get_node("Pages/Play/JoinCard").visible and not launcher.get_node(PLAYERS + "/Count").visible and launcher.get_node("Pages/Play/Footer/Leave").visible and transport.patient, "LL7 the card gives way to the lobby; no count line; Leave shows; patient")
	_pick(launcher._own_selector(), "frc")
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("ashfall", ["china", "frc"])}))
	runner.check(launcher.get_node(MAP_COLUMN + "/MapName").text == "Ashfall" and _cue(launcher).visible and _cue(launcher).text == "Host changed the map to Ashfall", "LL7 a change re-renders at once and names itself, got '%s'" % _cue(launcher).text)
	runner.check(_picked(launcher._own_selector()) == "frc" and launcher._own_pick == "frc", "LL7 the guest's own pick survives the change")
	transport.frames.append(Wire.encode({"type": "start", "seats": [1, 2], "delay": 4, "seed": 7, "settings": _team_settings("ashfall", ["china", "frc"])}))
	launcher._process(0.0)
	var main = runner.root.get_tree().current_scene
	var opened: bool = main != null and main != launcher
	runner.check(opened and is_same(main.driver._transport, transport) and main.driver._own_faction == "frc" and SkirmishMain.map_path == MatchSettings.map_path("ashfall"), "LL7 the relay's start opens the match on the host's latest map with the guest's pick")
	if opened: main.free()
	await runner.process_frame
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func test_lobby_guest_change_lines(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-guest-lines", {})
	_restore(saved)
	var transport = _lobby_guest(launcher, _team_settings("broken_crown", ["china"]))
	runner.check(not _cue(launcher).visible, "LL17 no change line on the welcome")
	var steps: Array[Array] = [
		[_team_settings("broken_crown", ["china", "frc"]), "Host added a bot"],
		[_team_settings("broken_crown", ["china"]), "Host removed a bot"],
		[_team_settings("broken_crown", ["usa"]), "Host changed a bot's faction"],
		[_team_settings("broken_crown", ["usa"]), "Host changed a bot's faction"],
		[_team_settings("ashfall", ["usa", "frc"]), "Host changed the setup"],
		[_team_settings("dry_wells", []), "Host changed the setup · you play against the host now"],
		[_team_settings("broken_crown", []), "Host changed the map to Broken Crown"],
	]
	for step: Array in steps:
		launcher._handle(Wire.encode({"type": "settings", "settings": step[0]}))
		runner.check(_cue(launcher).text == step[1], "LL17 '%s' after %s, got '%s'" % [step[1], step[0], _cue(launcher).text])
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", ["usa"])}))
	var random: Dictionary = _team_settings("broken_crown", ["usa"])
	random.bots[0]["random"] = true
	launcher._handle(Wire.encode({"type": "settings", "settings": random}))
	runner.check(_cue(launcher).text == "Host changed a bot's faction" and _row(launcher, 2, "Bot1").get_node("Faction").text == "Random", "LL17 a bot turned Random reads Random to the guest, not its roll, got '%s'" % _row(launcher, 2, "Bot1").get_node("Faction").text)
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", [])}))
	runner.check(_rows(launcher, 1) == ["Host"] and _rows(launcher, 2) == ["You"], "LL17 a 1v1 setup puts the guest on Team 2, got %s %s" % [_rows(launcher, 1), _rows(launcher, 2)])
	launcher._handle(Wire.encode({"type": "settings", "settings": {"map": "atlantis", "map_hash": "x"}}))
	runner.check(launcher._transport == null and transport.close_calls == 1 and launcher.get_node("Pages/Play/JoinCard").visible and _message(launcher).text == MatchSettings.NOT_IN_BUILD, "LL17 a setup this build cannot play ends the join with the reason, got '%s'" % _message(launcher).text)
	launcher.free()
	return true

func test_lobby_host_left(runner) -> bool:
	var saved: String = AudioSettings.path
	var guest = await _launcher_with(runner, "lobby-host-left", {})
	_restore(saved)
	_lobby_guest(guest, MatchSettings.for_map("dry_wells"))
	guest._handle('{"type":"error","reason":"host left"}')
	runner.check(guest._transport == null and guest.mode == "join" and guest.get_node("Pages/Play/JoinCard").visible and _message(guest).text == LauncherScript.HOST_GONE, "LL9 the host leaving sends the guest back to the Join game card, got %s '%s'" % [guest.mode, _message(guest).text])
	var transport = _lobby_guest(guest, MatchSettings.for_map("dry_wells"))
	transport.frames.append('{"type":"left","seat":1,"after_tick":3}')
	guest._process(0.0)
	runner.check(guest._transport == null and guest.get_node("Pages/Play/JoinCard").visible and _message(guest).text == LauncherScript.HOST_GONE, "LL9 a left for seat 1 reads the same, got '%s'" % _message(guest).text)
	_lobby_guest(guest, MatchSettings.for_map("dry_wells"))
	guest.get_node("Pages/Play/Footer/Leave").pressed.emit()
	runner.check(guest._transport == null and _message(guest).text == "You left the game" and _message(guest).theme_type_variation == &"Hint", "LL9 the guest's own Leave reads 'You left the game', got '%s'" % _message(guest).text)
	guest.free()
	return true

func test_lobby_stop_hosting(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-stop", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	var leave: Button = launcher.get_node("Pages/Play/Footer/Leave")
	var transport = _lobby_host(launcher)
	runner.check(leave.visible and leave.text == "Stop hosting", "LL10 hosting shows Stop hosting")
	leave.pressed.emit()
	runner.check(transport.close_calls == 1 and launcher._transport == null and not leave.visible, "LL10 without a friend Stop hosting closes at once")
	transport = _lobby_host(launcher)
	_friend_joins(launcher)
	var confirm: ConfirmationDialog = launcher.get_node("Confirm")
	leave.pressed.emit()
	runner.check(confirm.visible and transport.close_calls == 0 and confirm.title == "Stop hosting?" and confirm.ok_button_text == "Stop hosting", "LL10 with a friend in Stop hosting asks first, got '%s'" % confirm.title)
	confirm.get_cancel_button().pressed.emit()
	runner.check(launcher._transport != null and transport.close_calls == 0, "LL10 Cancel keeps the room")
	var skirmish: Button = launcher.get_node(MODE_BAR + "/Skirmish")
	skirmish.pressed.emit()
	runner.check(not skirmish.disabled and confirm.visible and transport.close_calls == 0 and launcher.mode == "host" and not skirmish.button_pressed, "LL10 with a friend in, a Skirmish click asks Stop hosting? and stays on Host game")
	confirm.get_cancel_button().pressed.emit()
	leave.pressed.emit()
	confirm.confirmed.emit()
	runner.check(transport.close_calls == 1 and launcher._transport == null and launcher.mode == "skirmish" and launcher.get_node(MAP_COLUMN + "/Map").visible and launcher.lobby_bots.size() == 1, "LL10 confirming Stop hosting closes the room and goes back to Skirmish with the setup")
	runner.check(not launcher.get_node(MODE_BAR + "/Host").disabled, "LL10 after Stop hosting the modes are free again")
	transport = _lobby_host(launcher)
	_friend_joins(launcher)
	skirmish.pressed.emit()
	confirm.confirmed.emit()
	runner.check(transport.close_calls == 1 and launcher._transport == null and launcher.mode == "skirmish" and skirmish.button_pressed, "LL10 confirming after a Skirmish click stops hosting and switches to Skirmish")
	transport = _lobby_host(launcher)
	skirmish.pressed.emit()
	runner.check(not confirm.visible and transport.close_calls == 1 and launcher.mode == "skirmish", "LL10 without a friend a Skirmish click stops hosting at once")
	_host(launcher)
	skirmish.pressed.emit()
	runner.check(launcher._transport == null and launcher.mode == "skirmish", "LL10 while connecting a Skirmish click cancels")
	transport = _lobby_host(launcher)
	_friend_joins(launcher)
	leave.pressed.emit()
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	runner.check(not confirm.visible and launcher._transport == null, "LL10 a room that ends while Stop hosting? is open closes the question too")
	launcher.free()
	return true

func test_lobby_countdown_resets(runner) -> bool:
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var launcher = await _launcher_with(runner, "lobby-clock", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	launcher._clock = clock.now
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	_lobby_host(launcher)
	launcher._process(0.0)
	runner.check(status.text == "Start match unlocks when your friend joins", "LL13 no clock while time is plenty, got '%s'" % status.text)
	clock.usec += 780_000_000
	launcher._process(0.0)
	runner.check(status.text == "Start match unlocks when your friend joins · room closes in 2:00", "LL13 the last 3 minutes show the clock, got '%s'" % status.text)
	_friend_joins(launcher)
	runner.check(status.text == "Everyone is here. Start when you are ready · room closes in 2:00", "LL13 a join keeps the clock, got '%s'" % status.text)
	clock.usec += 4_900_000
	launcher._process(0.0)
	runner.check(_cue(launcher).visible and _cue(launcher).text == "Your friend joined", "LL13 the joined cue stays for a few seconds")
	clock.usec += 200_000
	launcher._process(0.0)
	runner.check(not _cue(launcher).visible, "LL13 the joined cue clears after 5 s")
	_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "frc")
	launcher._process(0.0)
	runner.check(status.text == "Everyone is here. Start when you are ready", "LL13 a settings send restarts it, so the clock goes again, got '%s'" % status.text)
	launcher._transport = null
	launcher.free()
	var guest = await _launcher_with(runner, "lobby-clock-guest", {})
	_restore(saved)
	guest._clock = clock.now
	_lobby_guest(guest, MatchSettings.for_map("dry_wells"))
	var guest_status: Label = guest.get_node("Pages/Play/Footer/Status")
	guest._process(0.0)
	runner.check(guest_status.text == "Waiting for the host to start", "LL13 the guest shows no clock before the host's first change: the room's expiry ran before the join, got '%s'" % guest_status.text)
	clock.usec += 61_000_000
	guest._process(0.0)
	runner.check(guest_status.text == "Waiting for the host to start", "LL13 still no clock, got '%s'" % guest_status.text)
	guest._handle(Wire.encode({"type": "settings", "settings": MatchSettings.for_map("ashfall")}))
	runner.check(guest_status.text == "Waiting for the host to start", "LL13 a received settings starts the guest's clock, still plenty, got '%s'" % guest_status.text)
	clock.usec += 721_000_000
	guest._process(0.0)
	runner.check(guest_status.text == "Waiting for the host to start · room closes in 2:59", "LL13 the guest's last 3 minutes show the clock, got '%s'" % guest_status.text)
	guest._transport = null
	guest.free()
	return true

func test_lobby_hour_cap(runner) -> bool:
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var launcher = await _launcher_with(runner, "lobby-cap-clock", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	launcher._clock = clock.now
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	_lobby_host(launcher)
	_friend_joins(launcher)
	for i in 5:
		clock.usec += 600_000_000
		_pick(_row(launcher, 2, "Bot1").get_node("Faction"), "frc" if i % 2 == 0 else "china")
		launcher._process(0.0)
	clock.usec += 420_000_000
	launcher._process(0.0)
	runner.check(status.text.ends_with("room closes in 3:00"), "LL19 57 minutes in, the relay's hour cap is nearer than 15 minutes from the last change, got '%s'" % status.text)
	clock.usec += 180_000_000
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	runner.check(status.text == LauncherScript.ROOM_GONE + LauncherScript.NEW_CODE, "LL19 a room closed by the cap does not claim nothing changed, got '%s'" % status.text)
	launcher.free()
	return true

func test_lobby_expiry_texts(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-expiry", {"map": "broken_crown"})
	_restore(saved)
	var status: Label = launcher.get_node("Pages/Play/Footer/Status")
	_lobby_host(launcher)
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	runner.check(status.text == LauncherScript.DID_NOT_JOIN and status.theme_type_variation == &"FooterError" and launcher.mode == "host", "LL13 expiry without a friend reads '%s', got '%s'" % [LauncherScript.DID_NOT_JOIN, status.text])
	_lobby_host(launcher)
	_friend_joins(launcher)
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	runner.check(status.text == LauncherScript.ROOM_CLOSED_HOST, "LL13 expiry with the friend in reads '%s', got '%s'" % [LauncherScript.ROOM_CLOSED_HOST, status.text])
	_lobby_guest(launcher, MatchSettings.for_map("dry_wells"))
	launcher._handle('{"type":"error","reason":"lobby expired"}')
	runner.check(launcher.get_node("Pages/Play/JoinCard").visible and _message(launcher).text == LauncherScript.ROOM_CLOSED, "LL13 the guest's expiry reads '%s', got '%s'" % [LauncherScript.ROOM_CLOSED, _message(launcher).text])
	launcher.free()
	return true

func _popup_open(runner, selector: OptionButton) -> void:
	selector.grab_focus()
	selector.show_popup()
	await runner.process_frame

# A live change neither steals the focus nor rebuilds a row whose list is open; it lands when the list closes.
func test_lobby_changes_wait_for_open_lists(runner) -> bool:
	var saved: String = AudioSettings.path
	var guest = await _launcher_with(runner, "lobby-popup-guest", {})
	_restore(saved)
	_lobby_guest(guest, _team_settings("broken_crown", ["china"]))
	var leave: Button = guest.get_node("Pages/Play/Footer/Leave")
	leave.grab_focus()
	guest._handle(Wire.encode({"type": "settings", "settings": _team_settings("ashfall", ["china"])}))
	runner.check(_focused(guest) == leave, "LL18 a host change leaves the guest's focus where it was, got %s" % _focused(guest))
	var own: OptionButton = guest._own_selector()
	await _popup_open(runner, own)
	runner.check(own.get_popup().visible, "LL18 fixture: the guest's faction list is open")
	var map_name: Label = guest.get_node(MAP_COLUMN + "/MapName")
	guest._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", ["china"])}))
	runner.check(is_same(guest._own_selector(), own) and not own.is_queued_for_deletion() and own.get_popup().visible and map_name.text == "Ashfall", "LL18 the open list is not rebuilt under the pointer")
	own.get_popup().hide()
	await runner.process_frame
	runner.check(map_name.text == "Broken Crown" and _cue(guest).text == "Host changed the map to Broken Crown", "LL18 the change lands when the list closes, got '%s' / '%s'" % [map_name.text, _cue(guest).text])
	guest._transport = null
	guest.free()
	var host = await _launcher_with(runner, "lobby-popup-host", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	_lobby_host(host)
	var bot: OptionButton = _row(host, 2, "Bot1").get_node("Faction")
	await _popup_open(runner, bot)
	_friend_joins(host)
	runner.check(is_same(_row(host, 2, "Bot1").get_node("Faction"), bot) and _row(host, 1, "Friend").get_node("Who/Name").text == "Open", "LL18 the friend joining waits while a bot's list is open")
	bot.get_popup().hide()
	await runner.process_frame
	runner.check(_row(host, 1, "Friend").get_node("Who/Name").text == "Your friend" and not host.get_node("Pages/Play/Footer/Start").disabled, "LL18 and fills the row when it closes")
	host._transport = null
	host.free()
	return true

func _players(settings: Dictionary) -> Array:
	return settings.get("players", []).map(func(row: Dictionary) -> Array: return [int(row.player), row.faction])

# Factions visible both ways: the guest's pick reaches the host's row and snapshot; the host's pick reaches the guest.
func test_lobby_picks_both_ways(runner) -> bool:
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var launcher = await _launcher_with(runner, "lobby-picks-host", {"faction": "usa", "map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	launcher._clock = clock.now
	var transport = _lobby_host(launcher)
	runner.check(_players(_hello(transport).get("settings", {})) == [[1, "usa"]], "FP1 the hello carries the host's pick, got %s" % [_hello(transport).get("settings", {}).get("players")])
	_friend_joins(launcher)
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china"}}')
	runner.check(_row(launcher, 1, "Friend").get_node("Faction").text == "China", "FP1 the friend's pick shows in their row, got '%s'" % _row(launcher, 1, "Friend").get_node("Faction").text)
	clock.usec += 1_000_000
	launcher._process(0.0)
	var sent: Array[Dictionary] = _sent(transport, "settings")
	runner.check(sent.size() == 1 and _players(sent[-1].settings) == [[1, "usa"], [2, "china"]], "FP1 the host folds the pick into its next snapshot, got %s" % [sent])
	for bad: String in ['{"type":"pick","seat":2,"pick":{"faction":"zerg"}}', '{"type":"pick","seat":2,"pick":{}}']:
		runner.check(launcher._handle(bad) and launcher._transport == transport and transport.close_calls == 0, "FP1 the host stays in the room on %s" % bad)
		runner.check(_row(launcher, 1, "Friend").get_node("Faction").text == "China", "FP1 an unknown or missing faction is ignored: %s" % bad)
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"random"}}')
	runner.check(_row(launcher, 1, "Friend").get_node("Faction").text == "Random", "FP1 Random reads Random")
	_pick(launcher._own_selector(), "frc")
	clock.usec += 1_000_000
	launcher._process(0.0)
	sent = _sent(transport, "settings")
	runner.check(_players(sent[-1].settings) == [[1, "frc"], [2, "random"]], "FP1 the host's own change goes out too, got %s" % [sent[-1].settings.get("players")])
	launcher._handle('{"type":"left","seat":2,"after_tick":3}')
	clock.usec += 1_000_000
	launcher._process(0.0)
	runner.check(_players(_sent(transport, "settings")[-1].settings) == [[1, "frc"]], "FP1 a leave drops that seat's pick, got %s" % [_sent(transport, "settings")[-1].settings.get("players")])
	_friend_joins(launcher)
	runner.check(_row(launcher, 1, "Friend").get_node("Faction").text == "Picks at start", "FP1 a new friend starts without the old pick")
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china"}}')
	launcher.get_node("Pages/Play/Footer/Leave").pressed.emit()
	launcher.get_node("Confirm").confirmed.emit()
	transport = _lobby_host(launcher)
	_friend_joins(launcher)
	runner.check(_row(launcher, 1, "Friend").get_node("Faction").text == "Picks at start" and _players(_hello(transport).get("settings", {})).size() == 1, "FP1 a new room after Stop hosting keeps no old pick")
	launcher._transport = null
	launcher.free()
	var guest = await _launcher_with(runner, "lobby-picks-guest", {"faction": "usa"})
	_restore(saved)
	guest._clock = clock.now
	var room: Dictionary = _team_settings("broken_crown", ["china"])
	room["players"] = [{"player": 1, "faction": "frc"}]
	var guest_transport = _lobby_guest(guest, room)
	var picks: Array[Dictionary] = _sent(guest_transport, "pick")
	runner.check(picks.size() == 1 and picks[0].pick == {"faction": "usa"}, "FP2 the guest sends its pick on the welcome, got %s" % [picks])
	runner.check(_row(guest, 1, "Host").get_node("Faction").text == "Free Resistance Coalition", "FP2 the guest sees the host's pick, got '%s'" % _row(guest, 1, "Host").get_node("Faction").text)
	_pick(guest._own_selector(), "china")
	_pick(guest._own_selector(), "random")
	guest._process(0.0)
	runner.check(_sent(guest_transport, "pick").size() == 1, "FP2 own changes within 0.75 s wait")
	clock.usec += 800_000
	guest._process(0.0)
	picks = _sent(guest_transport, "pick")
	runner.check(picks.size() == 2 and picks[1].pick == {"faction": "random"}, "FP2 then the latest pick goes once, got %s" % [picks])
	room = room.duplicate(true)
	room.players[0].faction = "china"
	guest._handle(Wire.encode({"type": "settings", "settings": room}))
	runner.check(_cue(guest).text == "Host picked China" and _row(guest, 1, "Host").get_node("Faction").text == "China", "FP2 the host's change names itself, got '%s'" % _cue(guest).text)
	room = room.duplicate(true)
	room.players[0].faction = "random"
	guest._handle(Wire.encode({"type": "settings", "settings": room}))
	runner.check(_row(guest, 1, "Host").get_node("Faction").text == "Random", "FP2 the host's Random reads Random")
	runner.check(guest_transport.order.refusals.is_empty(), "FP2 the fake relay refused nothing, got %s" % [guest_transport.order.refusals])
	guest.get_node("Pages/Play/Footer/Leave").pressed.emit()
	guest_transport = _lobby_guest(guest, room)
	runner.check(_sent(guest_transport, "pick").size() == 1 and _sent(guest_transport, "pick")[0].pick == {"faction": "random"}, "FP2 a new room gets the same pick again, got %s" % [_sent(guest_transport, "pick")])
	guest._transport = null
	guest.free()
	return true

func test_relay_reasons(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "relay-reasons", {})
	_restore(saved)
	var busy: String = "The relay is busy. Try again in a minute."
	for case: Array in [["protocol mismatch", "The relay runs a different version. Try again later, or update Wargrid."], ["relay busy", busy], ["too many connections", busy], ["too many joins", busy], ["match full", LauncherScript.GAME_FULL], ["host left", LauncherScript.HOST_GONE], ["invalid message", "The relay refused the connection (invalid message)."]]:
		var got: String = launcher._relay_reason(case[0])
		runner.check(got == case[1] and got.left(1) == got.left(1).to_upper(), "RR1 '%s' reads '%s', got '%s'" % [case[0], case[1], got])
	runner.check(LauncherScript.NEW_CODE == " Press Try again for a new code." and LauncherScript.HOST_GONE.ends_with(" Ask them for a new code.") and LauncherScript.ROOM_GONE == "The room closed after an hour." and LauncherScript.HOST_CANCELLED == "Hosting cancelled" and LauncherScript.JOIN_CANCELLED == "Join cancelled", "RR1 every ending names the next step")
	launcher.free()
	return true

func test_prerelease_build_in_hello(runner) -> bool:
	var saved: String = AudioSettings.path
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	for prerelease: bool in [false, true]:
		var launcher = await _launcher_with(runner, "build-id", {}, prerelease)
		var transport = _host_team(launcher, [])
		var want: String = PlaytestSettings.build_id() if prerelease else version
		runner.check(_hello(transport).get("build") == want and launcher.get_node("Sidebar/Version").text == "v" + want, "BI1 the hello and the sidebar carry '%s' (prerelease %s), got %s / %s" % [want, prerelease, _hello(transport).get("build"), launcher.get_node("Sidebar/Version").text])
		runner.check(launcher._relay_reason("build mismatch") == VERSION_LINE % want, "BI1 the version line names '%s'" % want)
		launcher._transport = null
		launcher.free()
	var commits: Array[String] = []
	for commit: String in ["aaa111", "bbb222"]:
		var path: String = scratch_for("commit-" + commit)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(commit)
		file.close()
		commits.append(PlaytestSettings.hello_build("0.19.0-dev", path))
	var client = HeadlessClient.new()
	runner.check(client._hello().get("build") == PlaytestSettings.hello_build(), "BI1 the headless client's hello uses the same build rule, got %s" % client._hello().get("build"))
	client.free()
	runner.check(commits == ["0.19.0-dev+aaa111", "0.19.0-dev+bbb222"] and PlaytestSettings.hello_build("0.19.0") == "0.19.0", "BI1 test builds of two commits send different builds, so the relay's build mismatch keeps them apart; a release sends its version, got %s" % [commits])
	_restore(saved)
	return true

func test_join_lookalike_letters(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-lookalike", {})
	_restore(saved)
	for typed: String in ["ABCI34", "k7q 2x0"]:
		_join_with(launcher, typed)
		runner.check(launcher._transport == null and _message(launcher).text == "Codes never use O, 0, I or 1. Check the code with your friend." and _message(launcher).theme_type_variation == &"JoinError", "JL7 '%s' says which letters codes never use, got '%s'" % [typed, _message(launcher).text])
	_join_with(launcher, "hello")
	runner.check(_message(launcher).text == LauncherScript.NEED_CODE, "JL7 other text still asks for the code")
	launcher.free()
	return true

func test_lobby_guest_team_move_line(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-team-move", {})
	_restore(saved)
	_lobby_guest(launcher, _team_settings("broken_crown", []))
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", ["china"])}))
	runner.check(_cue(launcher).text == "Host added a bot · you are on the host’s team now" and _rows(launcher, 1) == ["Host", "You"], "LL20 a bot that moves the guest says so, got '%s'" % _cue(launcher).text)
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", ["china", "frc"])}))
	runner.check(_cue(launcher).text == "Host added a bot", "LL20 a bot that moves nobody says only that, got '%s'" % _cue(launcher).text)
	launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", [])}))
	runner.check(_cue(launcher).text == "Host removed a bot · you play against the host now" and _rows(launcher, 2) == ["You"], "LL20 back to a 1v1 says so, got '%s'" % _cue(launcher).text)
	launcher._transport = null
	launcher.free()
	return true

func test_lobby_small_px(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-small-px", {"map": "broken_crown", "bots": ["china", "frc", "usa"]})
	_restore(saved)
	var map: OptionButton = launcher.get_node(MAP_COLUMN + "/Map")
	var dry: int = _index_where(map, func(id: String) -> bool: return id == "dry_wells")
	runner.check(map.is_item_disabled(dry) and map.get_item_tooltip(dry) == "This map has 2 starts; your setup needs 4.", "PX1 a greyed map says why, got '%s'" % map.get_item_tooltip(dry))
	var meta: Label = _row(launcher, 1, "You").get_node("Who/Meta")
	runner.check(not meta.visible, "PX1 your own row has no Player line")
	_lobby_host(launcher)
	runner.check(_row(launcher, 1, "You").get_node("Who/Meta").text == "Host", "PX1 the host's own row still says Host")
	_friend_joins(launcher)
	launcher.get_node("Pages/Play/Footer/Start").pressed.emit()
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "Starting…", "PX1 after Start match the footer says Starting…, got '%s'" % launcher.get_node("Pages/Play/Footer/Status").text)
	launcher._transport = null
	launcher.free()
	var web = Launcher.instantiate()
	web.page = "https://x.example/"
	AudioSettings.path = scratch_for("lobby-web-copy")
	runner.root.add_child(web)
	await runner.process_frame
	_restore(saved)
	var copy: Button = web.get_node(MODE_BAR + "/Invite/Box/Copy")
	runner.check(copy.text == "Copy link", "PX1 on the web the segment reads Copy link, got '%s'" % copy.text)
	copy.pressed.emit()
	web.get_node(MODE_BAR + "/Invite/CopyReset").timeout.emit()
	runner.check(copy.text == "Copy link", "PX1 and returns to Copy link")
	web.free()
	return true

func test_lobby_guest_random_resolved(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-guest-random", {})
	var transport = _lobby_guest(launcher, MatchSettings.for_map("dry_wells"))
	_pick(launcher._own_selector(), "random")
	transport.frames.append(Wire.encode(OnlineTests.new()._start_message("dry_wells", 3)))
	launcher._process(0.0)
	var main = runner.root.get_tree().current_scene
	var faction: String = main.driver._own_faction if main != null and main != launcher else ""
	runner.check(Registry.Factions.FACTIONS.has(faction), "LL15 the guest's Random is a real faction at the hand-off, got '%s'" % faction)
	if main != null and main != launcher: main.free()
	await runner.process_frame
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func test_lobby_copy_turns_copied(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lobby-copy", {})
	_restore(saved)
	_lobby_host(launcher)
	var copy: Button = launcher.get_node(MODE_BAR + "/Invite/Box/Copy")
	runner.check(copy.text == "Copy code" and copy.icon == LauncherScript.COPY_ICON, "LL11 a Copy code segment with a copy icon")
	copy.pressed.emit()
	runner.check(copy.text == "Copied" and copy.icon == LauncherScript.CHECK_ICON, "LL11 Copy code turns into Copied with a check")
	var timer: Timer = launcher.get_node(MODE_BAR + "/Invite/CopyReset")
	runner.check(not timer.is_stopped() and is_equal_approx(timer.wait_time, 2.0), "LL11 for 2 s")
	timer.timeout.emit()
	runner.check(copy.text == "Copy code" and copy.icon == LauncherScript.COPY_ICON, "LL11 then back to Copy code")
	copy.pressed.emit()
	launcher.get_node("Pages/Play/Footer/Leave").pressed.emit()
	_lobby_host(launcher)
	runner.check(copy.text == "Copy code" and copy.icon == LauncherScript.COPY_ICON and timer.is_stopped(), "LL11 a new room starts on Copy code, not the old room's Copied")
	launcher._transport = null
	launcher.free()
	return true

const LARGE_WINDOW := [Vector2i(2030, 1680), Vector2i(1280, 1059)]

# The card sits a fixed gap under the Mode row, centred across the content area, at every window.
func test_join_card_placement(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("join-card")
	for pair: Array in BaseScene.HUD_SIZES.slice(0, 3) + [LARGE_WINDOW]:
		var built: Array = _port_with_launcher(runner, pair[0], pair[1])
		var launcher = built[1]
		await _settle(runner, launcher, "Play", "join")
		var card: Rect2 = launcher.get_node("Pages/Play/JoinCard/Card").get_global_rect()
		var bar: Rect2 = launcher.get_node(MODE_BAR).get_global_rect()
		var pages: Control = launcher.get_node("Pages")
		var area: Rect2 = pages.get_global_rect()
		var middle: float = area.position.x + (pages.get_theme_constant("margin_left") + area.size.x - pages.get_theme_constant("margin_right")) / 2.0
		var gap: float = card.position.y - bar.end.y
		runner.check(absf(gap - 48.0) <= 2.0, "JC1 the card sits 48 px under the Mode row at %s, got %s" % [pair[0], gap])
		runner.check(absf(card.get_center().x - middle) <= 2.0, "JC1 the card is centred across the content area at %s, got %s vs %s" % [pair[0], card.get_center().x, middle])
		built[1].free()
		built[0].free()
	_restore(saved)
	return true

# P20 HUD/menu rule: every lobby state fits 1280x720, 1280x800 and 1920x1080 without clipping, overlap or horizontal overflow.
func test_lobby_layout_sizes(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("lobby-layout")
	LauncherSettings.save_picks({"map": "broken_crown", "faction": "frc"})
	for pair: Array in BaseScene.HUD_SIZES.slice(0, 3):
		var states: Array[String] = ["skirmish picked", "guest picked", "skirmish 1 bot", "skirmish 3 bots", "skirmish 5 bots ashfall", "skirmish 7 bots ashfall", "host connecting", "host waiting", "friend in", "friend left", "host crown full", "host ashfall full", "host unreachable", "host unreachable default", "host closed", "join card", "join error", "guest view", "guest change"]
		var invite_rects: Array[Rect2] = []
		for state: String in states:
			var port := SubViewport.new()
			port.size = pair[0]
			port.size_2d_override = pair[1]
			port.size_2d_override_stretch = true
			runner.root.add_child(port)
			var launcher = Launcher.instantiate()
			launcher.prerelease = true
			port.add_child(launcher)
			await runner.process_frame
			match state:
				"skirmish picked":
					_click_start(launcher, 1)
					_click_start(launcher, 3, true)
				"guest picked": _lobby_guest(launcher, _team_settings("broken_crown", ["china"]).merged({"chosen": [{"player": 1, "start": 1}, {"player": 2, "start": 3}], "closed": [4]}))
				"skirmish 3 bots":
					launcher._add_bot()
					launcher._add_bot()
				"skirmish 5 bots ashfall", "skirmish 7 bots ashfall":
					_pick(launcher.get_node(MAP_COLUMN + "/Map"), "ashfall")
					for i in int(state.get_slice(" ", 1)) - launcher.lobby_bots.size(): launcher._add_bot()
				"host connecting": _host(launcher)
				"host waiting": _lobby_host(launcher)
				"friend in":
					_lobby_host(launcher)
					_friend_joins(launcher)
				"host crown full":
					launcher.lobby_bots.assign(["china", "frc"])
					_lobby_host(launcher)
				"host ashfall full":
					launcher.lobby_bots.assign(["china", "frc"])
					_lobby_host(launcher, "ashfall")
				"host unreachable":
					_host(launcher)
					launcher._fail(LauncherScript.UNREACHABLE % "ws://127.0.0.1:8787/ws")
				"host unreachable default":
					_host(launcher)
					launcher._fail(LauncherScript.UNREACHABLE % JoinLink.DEFAULT_RELAY)
				"host closed":
					_lobby_host(launcher)
					_friend_joins(launcher)
					launcher._handle('{"type":"error","reason":"lobby expired"}')
				"friend left":
					_lobby_host(launcher)
					_friend_joins(launcher)
					launcher._handle('{"type":"left","seat":2,"after_tick":3}')
				"join card": launcher.set_mode("join")
				"join error":
					_join_with(launcher, "ABC234")
					launcher._transport = OnlineTests.FakeTransport.new()
					launcher._handle(Wire.encode({"type": "error", "reason": "unknown match"}))
				"guest view": _lobby_guest(launcher, _team_settings("broken_crown", ["china", "frc"]))
				"guest change":
					_lobby_guest(launcher, _team_settings("broken_crown", ["china", "frc"]))
					launcher._handle(Wire.encode({"type": "settings", "settings": _team_settings("broken_crown", ["china", "usa"])}))
			await runner.process_frame
			await runner.process_frame
			var label := "%s at %s" % [state, pair[0]]
			var play: Control = launcher.get_node("Pages/Play")
			var joining: bool = state.begins_with("join")
			_layout_ok(runner, launcher, play, label)
			for path: String in ["Pages/Play/Body/Players", "Pages/Play/Body/MapColumn", PLAYERS + "/Teams/List/Team1", PLAYERS + "/Teams/List/Team2", MODE_BAR, JOIN, JOIN + "/Buttons"]:
				var node: Control = launcher.get_node(path)
				if node.is_visible_in_tree(): _overlap_free(runner, node, label)
			var view: Rect2 = launcher.get_viewport().get_visible_rect()
			var content: Rect2 = launcher.get_node("Pages").get_global_rect().grow(0.5)
			var wanted: Array[String] = ["Pages/Play/Footer/Status"]
			if joining: wanted.assign([JOIN + "/Code", JOIN + "/Buttons/Join", JOIN + "/Buttons/Cancel", JOIN + "/Message"])
			if not joining and not state.begins_with("guest"): wanted.append("Pages/Play/Footer/Start")
			if state == "host connecting": wanted.append("Pages/Play/Footer/CancelConnect")
			if state in ["host waiting", "friend in", "friend left", "host crown full", "host ashfall full", "guest view", "guest change"]: wanted.append(MODE_BAR + "/Invite")
			if state in ["friend in", "friend left", "guest change"]: wanted.append(PLAYERS + "/Cue")
			if state in ["host waiting", "friend in", "friend left"]: invite_rects.append(launcher.get_node(MODE_BAR + "/Invite").get_global_rect())
			for path: String in wanted:
				var rect: Rect2 = launcher.get_node(path).get_global_rect()
				runner.check(launcher.get_node(path).is_visible_in_tree() and view.encloses(rect) and content.encloses(rect), "LL12 %s fully visible, %s, got %s" % [path, label, rect])
			runner.check(play.get_combined_minimum_size().x <= content.size.x and play.get_global_rect().end.x <= content.end.x, "LL12 no horizontal overflow, %s: min %s, page %s, content %s" % [label, play.get_combined_minimum_size(), play.get_global_rect(), content])
			if not joining:
				var footer_top: float = launcher.get_node("Pages/Play/Divider").get_global_rect().position.y
				runner.check(launcher.get_node("Pages/Play/Body").get_global_rect().end.y <= footer_top + 0.5, "LL12 the lobby ends above the footer, %s" % label)
			for button: Button in play.find_children("*", "Button", true, false):
				if not button.is_visible_in_tree(): continue
				runner.check(button.get_combined_minimum_size().x <= button.size.x + 0.5 and button.get_combined_minimum_size().y <= button.size.y + 0.5, "LL12 %s is not clipped, %s" % [button.name, label])
			for text: Label in play.find_children("*", "Label", true, false):
				if not text.is_visible_in_tree() or text.text.is_empty(): continue
				var lines: int = text.get_line_count()
				var shown: bool = text.get_visible_line_count() >= lines and (text.autowrap_mode != TextServer.AUTOWRAP_OFF or text.get_minimum_size().x <= text.size.x + 0.5)
				runner.check(shown and view.encloses(text.get_global_rect().grow(-0.5)), "LL12 label %s '%s' is not clipped, %s" % [text.name, text.text.left(40), label])
			if state.ends_with("picked"):
				var preview: Control = launcher.get_node(MAP_COLUMN + "/Preview")
				var hint: Label = launcher.get_node(MAP_COLUMN + "/MapHint")
				runner.check(hint.is_visible_in_tree() and view.encloses(hint.get_global_rect()) and hint.get_global_rect().end.y <= launcher.get_node("Pages/Play/Divider").get_global_rect().position.y + 0.5, "LL12 the start hint shows above the footer, %s" % label)
				runner.check([1, 2, 3, 4].all(func(seat: int) -> bool: return Rect2(Vector2.ZERO, preview.size).grow(-MapPreview.HIT + 2.0).has_point(preview.point_of(seat))), "LL12 every start marker sits inside the preview, %s" % label)
			if state == "host crown full": runner.check(_count_line(launcher).ends_with("a bigger map fits more bots"), "LL12 fixture: the long count line, got '%s'" % _count_line(launcher))
			if state == "host ashfall full": runner.check(_count_line(launcher).ends_with("online games take up to 2 bots"), "LL12 fixture: the online cap line, got '%s'" % _count_line(launcher))
			if state.ends_with("bots ashfall"): runner.check(launcher.lobby_bots.size() == int(state.get_slice(" ", 1)), "LL12 fixture: %s, got %d bots" % [state, launcher.lobby_bots.size()])
			if state.begins_with("host unreachable"): runner.check(launcher.get_node("Pages/Play/Footer/TryAgain").is_visible_in_tree(), "LL12 fixture: Try again shows")
			if state == "host closed": runner.check(launcher.get_node("Pages/Play/Footer/Status").text == LauncherScript.ROOM_CLOSED_HOST, "LL12 fixture: the host's closed-room line")
			launcher._transport = null
			var main = runner.root.get_tree().current_scene
			if main != null and main != launcher and main.has_method("setup"): main.free()
			launcher.free()
			port.free()
		runner.check(invite_rects.size() == 3 and invite_rects.all(func(rect: Rect2) -> bool: return rect.is_equal_approx(invite_rects[0])), "LL12 the invite box keeps one rect while the friend comes and goes at %s, got %s" % [pair[0], invite_rects])
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func _faction_lefts(launcher) -> Array[float]:
	var lefts: Array[float] = []
	for team: int in [1, 2]:
		for row: String in _rows(launcher, team):
			var cell: Control = _row(launcher, team, row).get_node_or_null("Faction")
			if cell != null: lefts.append(cell.get_global_rect().position.x)
	return lefts

func _action_rights(launcher) -> Array[float]:
	var rights: Array[float] = []
	for team: int in [1, 2]:
		for row: String in _rows(launcher, team):
			var cell: Control = _row(launcher, team, row).get_child(_row(launcher, team, row).get_child_count() - 1)
			rights.append(cell.get_global_rect().end.x)
	return rights

func _same(values: Array) -> bool:
	return values.all(func(value: float) -> bool: return absf(value - values[0]) < 0.5)

# The look round's alignment rules at the three window sizes the round drew.
func test_lobby_look_lines_up(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("lobby-look")
	LauncherSettings.save_picks({"map": "broken_crown", "faction": "frc", "bots": ["china", "random"]})
	for pair: Array in BaseScene.HUD_SIZES.slice(0, 3):
		var built: Array = _port_with_launcher(runner, pair[0], pair[1])
		var launcher = built[1]
		var size: Vector2i = pair[0]
		await _settle(runner, launcher, "Play", "host")
		var lefts: Array[float] = _faction_lefts(launcher)
		runner.check(lefts.size() == 3 and _same(lefts), "LK1 the faction dropdowns of You and both bots start at one x at %s, got %s" % [size, lefts])
		runner.check(_rows(launcher, 1).size() + _rows(launcher, 2).size() == 4 and _same(_action_rights(launcher)), "LK1 every row, the open one too, ends in the same action column at %s, got %s" % [size, _action_rights(launcher)])
		var remove: Control = _row(launcher, 2, "Bot1").get_node("Remove")
		runner.check(absf(remove.size.x - LauncherScript.ACTION_WIDTH) < 0.5 and absf(remove.size.y - LauncherScript.ACTION_WIDTH) < 0.5, "LK1 the X sits in a 40 px square at %s, got %s" % [size, remove.size])
		_lobby_host(launcher)
		_friend_joins(launcher)
		await runner.process_frame
		await runner.process_frame
		lefts = _faction_lefts(launcher)
		runner.check(lefts.size() == 4 and _same(lefts), "LK1 with the friend in, text cells line up with your dropdown at %s, got %s" % [size, lefts])
		var invite: Control = launcher.get_node(MODE_BAR + "/Invite")
		var bar: Control = launcher.get_node(MODE_BAR)
		var copy_rect: Rect2 = invite.get_global_rect()
		launcher.get_node(MODE_BAR + "/Invite/Box/Copy").pressed.emit()
		await runner.process_frame
		await runner.process_frame
		var copied_rect: Rect2 = invite.get_global_rect()
		runner.check(copy_rect.is_equal_approx(copied_rect), "LK2 the invite box keeps one rect in Copy code and Copied at %s, got %s and %s" % [size, copy_rect, copied_rect])
		runner.check(absf(copy_rect.end.x - bar.get_global_rect().end.x) < 0.5 and absf(copy_rect.get_center().y - bar.get_global_rect().get_center().y) < 1.0, "LK2 the invite box sits at the Mode row's right end at %s, got %s in %s" % [size, copy_rect, bar.get_global_rect()])
		var copy: Button = launcher.get_node(MODE_BAR + "/Invite/Box/Copy")
		runner.check(copy.get_combined_minimum_size().x <= copy.size.x + 0.5, "LK2 Copied fits the Copy segment at %s" % size)
		launcher._transport = null
		launcher._fail(LauncherScript.HOST_CANCELLED)
		launcher.set_mode("join")
		await runner.process_frame
		await runner.process_frame
		var card: Rect2 = launcher.get_node("Pages/Play/JoinCard/Card").get_global_rect()
		var space: Rect2 = launcher.get_node("Pages/Play/JoinCard").get_global_rect()
		runner.check(absf(card.get_center().x - space.get_center().x) < 1.0 and space.position.y >= bar.get_global_rect().end.y, "LK3 the Join game card is centred under the Mode row at %s, got %s in %s" % [size, card, space])
		_layout_ok(runner, launcher, launcher.get_node("Pages/Play"), "join card at %s" % size)
		built[1].free()
		built[0].free()
	_restore(saved)
	OnlineTests._restore_statics(before)
	return true

func _click_start(launcher, seat: int, right: bool = false) -> void:
	var preview: Control = launcher.get_node(MAP_COLUMN + "/Preview")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = preview.point_of(seat)
	preview._gui_input(click)

func _marks(launcher) -> Array:
	var preview: Control = launcher.get_node(MAP_COLUMN + "/Preview")
	return [preview._colours, preview._closed]

func _tip(launcher, seat: int) -> String:
	var preview: Control = launcher.get_node(MAP_COLUMN + "/Preview")
	return preview._get_tooltip(preview.point_of(seat))

func _chosen(settings: Dictionary) -> Array:
	return settings.get("chosen", []).map(func(row: Dictionary) -> Array: return [int(row.player), int(row.start)])

func test_start_pick_offline(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "start-pick-offline", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	runner.check(launcher.get_node(MAP_COLUMN + "/MapHint").text == LauncherScript.HINT_PICK + LauncherScript.HINT_CLOSE and _tip(launcher, 3) == LauncherScript.TIP_FREE + LauncherScript.TIP_CLOSE, "SP1 the hint and a free start's tooltip say click to take, right-click to close")
	_click_start(launcher, 3)
	runner.check(launcher._spots == {1: 3} and _marks(launcher)[0] == {3: launcher._hue(1)} and _tip(launcher, 3) == LauncherScript.TIP_YOURS, "SP1 a click takes the start in your row's colour, got %s" % [_marks(launcher)])
	_click_start(launcher, 3)
	runner.check(launcher._spots.is_empty() and _marks(launcher)[0].is_empty(), "SP1 a second click gives it back")
	_click_start(launcher, 2)
	_click_start(launcher, 4, true)
	runner.check(launcher._closed == ([4] as Array[int]) and _marks(launcher)[1] == ([4] as Array[int]) and _tip(launcher, 4) == LauncherScript.TIP_CLOSED and _count_line(launcher) == "2 of 4 starts used · 1 closed", "SP1 a right-click closes a free start and the count names it, got '%s'" % _count_line(launcher))
	_click_start(launcher, 2, true)
	_click_start(launcher, 4)
	runner.check(launcher._spots == {1: 2} and launcher._closed == ([4] as Array[int]), "SP1 your own start does not close and a closed start cannot be taken")
	launcher._add_bot()
	runner.check(launcher.lobby_bots.size() == 2 and _add_bot(launcher).disabled, "SP1 the closed start counts against the bot cap")
	_click_start(launcher, 1, true)
	runner.check(launcher._closed == ([4] as Array[int]), "SP1 the last free start for a bot does not close")
	AudioSettings.path = scratch_for("start-pick-offline-picks")
	var set_up: bool = launcher._offline_setup()
	_restore(saved)
	runner.check(set_up and SkirmishMain.starts[0] == 2 and not SkirmishMain.starts.has(4) and SkirmishMain.starts.size() == 3, "SP1 the match starts you on 2 and nobody on the closed 4, got %s" % [SkirmishMain.starts])
	runner.check(MatchSettings.starts("broken_crown", SkirmishMain.match_seed, MatchSettings.teams(1, 2), SkirmishMain.placement) == SkirmishMain.starts, "SP1 a rematch keeps the picks, got %s" % [SkirmishMain.placement])
	_click_start(launcher, 4, true)
	runner.check(launcher._closed.is_empty(), "SP1 a right-click opens a closed start again")
	_click_start(launcher, 1, true)
	_pick(launcher.get_node(MAP_COLUMN + "/Map"), "ashfall")
	runner.check(launcher._spots.is_empty() and launcher._closed.is_empty() and _marks(launcher) == [{}, []], "SP1 a map change clears picks and closed starts")
	launcher.free()
	OnlineTests._restore_statics(before)
	return true

func test_start_pick_host_folds_guest(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var launcher = await _launcher_with(runner, "start-pick-host", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	launcher._clock = clock.now
	var transport = _lobby_host(launcher)
	_click_start(launcher, 1)
	_friend_joins(launcher)
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":1}}')
	runner.check(launcher._spots == {1: 1} and _row(launcher, 1, "Friend").get_node("Faction").text == "China", "SP2 a guest's clash with the host's start is refused, the faction still counts")
	for bad: String in ['{"type":"pick","seat":2,"pick":{"faction":"china","start":9}}', '{"type":"pick","seat":2,"pick":{"faction":"china","start":2.5}}', '{"type":"pick","seat":2,"pick":{"faction":"china","start":"3"}}']:
		launcher._handle(bad)
		runner.check(launcher._spots == {1: 1} and launcher._transport == transport, "SP2 a bad start is ignored and the room stays: %s" % bad)
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":3}}')
	runner.check(launcher._spots == {1: 1, 2: 3} and _marks(launcher)[0] == {1: launcher._hue(1), 3: launcher._hue(2)}, "SP2 the guest's start shows in their colour, got %s" % [_marks(launcher)])
	_click_start(launcher, 3)
	_click_start(launcher, 4, true)
	_click_start(launcher, 2, true)
	runner.check(launcher._spots == {1: 1, 2: 3} and launcher._closed == ([4] as Array[int]), "SP2 the host cannot take the guest's start and closes only while the friend and the bot fit, got %s" % [launcher._closed])
	clock.usec += 1_000_000
	launcher._process(0.0)
	var sent: Array[Dictionary] = _sent(transport, "settings")
	runner.check(_chosen(sent[-1].settings) == [[1, 1], [2, 3]] and MatchSettings.closed_starts(sent[-1].settings) == ([4] as Array[int]) and MatchSettings.refusal(Wire.decode(Wire.encode(sent[-1])).message.settings, 2).is_empty(), "SP2 the host folds the guest's start into valid settings, got %s" % [sent[-1].settings])
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":4}}')
	runner.check(launcher._spots == {1: 1, 2: 3}, "SP2 a closed start is refused")
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china"}}')
	runner.check(launcher._spots == {1: 1}, "SP2 a pick without a start gives the guest's start back")
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":2}}')
	launcher._handle('{"type":"left","seat":2,"after_tick":3}')
	runner.check(launcher._spots == {1: 1}, "SP2 a leave frees the guest's start")
	_friend_joins(launcher)
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":2}}')
	runner.check(launcher.lobby_bots.size() == 1 and launcher._bot_cap() == 1, "SP2 fixture: one bot, capped by the closed start")
	launcher.get_node("Pages/Play/Footer/Start").pressed.emit()
	launcher._handle('{"type":"pick","seat":2,"pick":{"faction":"china","start":3}}')
	_click_start(launcher, 3)
	runner.check(launcher._spots == {1: 1, 2: 2}, "SP2 after Start match no start changes")
	AudioSettings.path = scratch_for("start-pick-host-picks")
	var settings: Dictionary = launcher._settings
	var got: Array = await _start_through_wire(runner, launcher, {"type": "start", "seats": [1, 2], "delay": 4, "seed": 7, "settings": settings})
	_restore(saved)
	runner.check(got[1] == ([1, 2, 3] as Array[int]) and got[1] == MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 1), Wire.decode(Wire.encode({"type": "settings", "settings": settings})).message.settings), "SP2 the host's match seats both picks and the bot on the open start, got %s" % [got[1]])
	OnlineTests._restore_statics(before)
	return true

func test_start_pick_guest_view(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var guest = await _launcher_with(runner, "start-pick-guest", {"faction": "usa"})
	_restore(saved)
	guest._clock = clock.now
	var room: Dictionary = _team_settings("broken_crown", ["china"]).merged({"chosen": [{"player": 1, "start": 2}], "closed": [4]})
	var transport = _lobby_guest(guest, room)
	runner.check(guest.get_node(MAP_COLUMN + "/MapHint").text == LauncherScript.HINT_PICK and _marks(guest) == [{2: guest._hue(1)}, [4]], "SP3 the guest sees the host's start and the closed one, got %s" % [_marks(guest)])
	runner.check([_tip(guest, 1), _tip(guest, 2), _tip(guest, 4)] == [LauncherScript.TIP_FREE, LauncherScript.TIP_TAKEN, LauncherScript.TIP_CLOSED_GUEST], "SP3 the guest's tooltips name free, taken and closed starts")
	for click: Array in [[2, false], [4, false], [1, true]]: _click_start(guest, click[0], click[1])
	clock.usec += 1_000_000
	guest._process(0.0)
	runner.check(_sent(transport, "pick").size() == 1, "SP3 a taken or closed start, or a right-click, sends nothing")
	_click_start(guest, 1)
	clock.usec += 1_000_000
	guest._process(0.0)
	var picks: Array[Dictionary] = _sent(transport, "pick")
	runner.check(picks.size() == 2 and picks[1].pick == {"faction": "usa", "start": 1.0} and _marks(guest)[0] == {2: guest._hue(1)}, "SP3 a click asks the host for the start; the marker waits for the settings, got %s" % [picks])
	var taken: Dictionary = room.merged({"chosen": [{"player": 1, "start": 2}, {"player": 2, "start": 1}]}, true)
	guest._handle(Wire.encode({"type": "settings", "settings": taken}))
	runner.check(_marks(guest)[0] == {2: guest._hue(1), 1: guest._hue(2)} and _tip(guest, 1) == LauncherScript.TIP_YOURS and _cue(guest).text.is_empty(), "SP3 the settings place the guest's marker in its colour, without a cue for its own pick")
	_click_start(guest, 1)
	clock.usec += 1_000_000
	guest._process(0.0)
	runner.check(_sent(transport, "pick")[-1].pick == {"faction": "usa"}, "SP3 a click on the own marker gives it back")
	_click_start(guest, 3)
	clock.usec += 1_000_000
	guest._process(0.0)
	guest._handle(Wire.encode({"type": "settings", "settings": room.merged({"chosen": [{"player": 1, "start": 3}]}, true)}))
	runner.check(_marks(guest)[0] == {3: guest._hue(1)} and guest._own_start == 0 and _cue(guest).text == LauncherScript.STARTS_CHANGED, "SP3 a clash refused by the host puts the guest back where the settings say, got %s" % [_marks(guest)])
	guest._handle(Wire.encode({"type": "settings", "settings": room.merged({"closed": [1, 2]}, true)}))
	runner.check(guest._transport == null, "SP3 settings with too many closed starts are refused like other bad settings")
	OnlineTests._restore_statics(before)
	guest.free()
	return true

func test_start_pick_guest_repicks(runner) -> bool:
	var before: Array = OnlineTests._statics()
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var guest = await _launcher_with(runner, "start-pick-repick", {"faction": "usa"})
	_restore(saved)
	guest._clock = clock.now
	var room: Dictionary = _team_settings("broken_crown", ["china"])
	var transport = _lobby_guest(guest, room)
	_click_start(guest, 3)
	clock.usec += 1_000_000
	guest._process(0.0)
	guest._handle(Wire.encode({"type": "settings", "settings": room.merged({"chosen": [{"player": 2, "start": 3}]})}))
	guest._handle(Wire.encode({"type": "settings", "settings": _team_settings("ashfall", ["china"])}))
	var sent: int = _sent(transport, "pick").size()
	_click_start(guest, 3)
	clock.usec += 1_000_000
	guest._process(0.0)
	var picks: Array[Dictionary] = _sent(transport, "pick")
	runner.check(picks.size() == sent + 1 and picks[-1].pick.get("start") == 3.0, "SP4 after the host drops the guest's start, the same start can be asked for again, got %s" % [picks])
	guest._transport = null
	guest.free()
	OnlineTests._restore_statics(before)
	return true

func test_start_pick_closed_fits_hosting(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "start-pick-closed-host", {"map": "dry_wells", "bots": ["china"]})
	_restore(saved)
	launcher._remove_bot(0)
	_click_start(launcher, 2, true)
	runner.check(launcher._closed == ([2] as Array[int]), "SP5 fixture: Skirmish without a bot closes start 2")
	var transport = _host_team(launcher, [])
	var settings: Dictionary = Wire.decode(Wire.encode({"type": "settings", "settings": _hello(transport).get("settings", {})})).message.settings
	runner.check(MatchSettings.refusal(settings, 2).is_empty(), "SP5 Host game never sends settings a guest refuses, got '%s' for %s" % [MatchSettings.refusal(settings, 2), settings])
	launcher._transport = null
	launcher.free()
	return true

func test_start_pick_rejoin_adopts_nothing(runner) -> bool:
	var saved: String = AudioSettings.path
	var clock := FakeClock.new()
	var guest = await _launcher_with(runner, "start-pick-rejoin", {"faction": "usa"})
	_restore(saved)
	guest._clock = clock.now
	var transport = _lobby_guest(guest, _team_settings("broken_crown", ["china"]).merged({"chosen": [{"player": 2, "start": 3}]}))
	runner.check(guest._own_start == 0 and _sent(transport, "pick")[-1].pick == {"faction": "usa"}, "SP6 a new guest takes no start the room's last settings left for the guest before it, got %s" % [_sent(transport, "pick")])
	guest._transport = null
	guest.free()
	return true

func test_start_pick_closed_count_line(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "start-pick-reopen", {"map": "broken_crown", "bots": ["china"]})
	_restore(saved)
	_click_start(launcher, 4, true)
	launcher._add_bot()
	runner.check(_add_bot(launcher).disabled and _count_line(launcher) == "3 of 4 starts used · 1 closed · " + LauncherScript.REOPEN, "SP7 when a closed start holds back a bot, the count line says to open it, got '%s'" % _count_line(launcher))
	launcher.lobby_bots.append("usa")
	AudioSettings.path = scratch_for("start-pick-reopen-picks")
	var errors: Array[String] = []
	launcher.log_error = func(line: String) -> void: errors.append(line)
	runner.check(not launcher._offline_setup() and errors.size() == 1, "SP7 the offline start counts closed starts too, got %s" % [errors])
	_restore(saved)
	launcher.free()
	return true
