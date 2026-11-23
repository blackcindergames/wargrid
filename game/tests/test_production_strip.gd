@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const STRIP: String = "HUD/Hud/ProductionStrip"
const ProductionStrip = preload("res://scripts/match/production_strip.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const HINT: String = "Your busy buildings: click one to select it, double-click to go there"
const MEDIUM: String = "china_light_vehicle"
const ROTARY: String = "china_tank"
const MILITIA: String = "china_rifle_infantry"
const DOZER: String = "china_builder"
const TRUCK: String = "china_collector"

func cases() -> Array[Callable]:
	return [test_strip_order, test_strip_busy_only_kinds, test_strip_looks, test_strip_last_made_glyph, test_strip_fold, test_strip_tip_words, test_strip_click_selects, test_strip_double_click_glides, test_strip_holds_through_a_forecast, test_strip_blocks_the_map, test_strip_more_list, test_strip_layout, test_strip_chip_looks, test_strip_unchanged_refresh, test_strip_upright_bars, test_strip_upright_key_skips_typing, test_strip_reset_forgets_last_made, test_strip_tip_neighbour_rule, test_strip_click_ends_modes, test_strip_click_needs_orders_and_an_own_producer, test_strip_bar_stays_in_its_track, test_strip_queue_count, test_strip_hides_while_nothing_is_made, test_strip_hint_once, test_strip_hint_layout, test_strip_tip_names_the_runs, test_strip_hidden_under_the_pointer, test_strip_click_under_the_freeze_card, test_strip_card_steps_aside_for_a_notice]

static func _entry(kind: String, work: int = 0) -> Dictionary:
	return {"id": 1, "kind": kind, "paid_cost": 800, "work": work}

static func _building(id: int, kind: String, queue: Array = [], owner: int = 1, completed: bool = true) -> Dictionary:
	return {"id": id, "kind": kind, "owner": owner, "completed": completed, "queue": queue}

static func _view(buildings: Array, rate: int = 1000) -> Dictionary:
	return {"buildings": buildings, "players": [{"id": 1, "credits": 0, "work_rate": rate}]}

static func _ids(chips: Array) -> Array:
	return chips.map(func(chip: Dictionary) -> int: return chip.id)

static func _ticks(kind: String) -> int:
	return Economy.unit(kind).ticks * 1000

# Strip round order B (user, 2026-11-23): Headquarters, Supply Depot, Barracks, Vehicle Factory, then by age; only finished own producers.
func test_strip_order(runner) -> bool:
	var view: Dictionary = _view([_building(5, "china_factory", [_entry(MEDIUM)]), _building(3, "china_barracks", [_entry(MILITIA)]), _building(9, "china_barracks"),
		_building(2, "china_command_center", [_entry(DOZER)]), _building(4, "china_supply_center", [_entry(TRUCK)]), _building(7, "china_factory"), _building(6, "china_power_plant"),
		_building(10, "china_factory", [_entry(MEDIUM)], 2), _building(11, "china_factory", [], 1, false), _building(1, "china_barracks")])
	var got: Array = _ids(HudModel.strip_chips(view, 1, {}))
	runner.check(got == [2, 4, 1, 3, 9, 5, 7], "PS1 kind order then age, no power plant, enemy or site: [2, 4, 1, 3, 9, 5, 7], got %s" % [got])
	return true

# Strip round default: Headquarters and Supply Depot chips only while they produce; an idle Barracks or Vehicle Factory keeps its chip.
func test_strip_busy_only_kinds(runner) -> bool:
	var idle: Dictionary = _view([_building(2, "china_command_center"), _building(4, "china_supply_center"), _building(3, "china_barracks"), _building(5, "china_factory")])
	runner.check(_ids(HudModel.strip_chips(idle, 1, {})) == [3, 5], "PS2 a resting HQ and Supply Depot have no chip, the idle Barracks and factory keep theirs, got %s" % [_ids(HudModel.strip_chips(idle, 1, {}))])
	var frc: Dictionary = _view([_building(2, "frc_command_center"), _building(4, "frc_supply_center", [_entry("frc_builder")]), _building(3, "frc_barracks")])
	runner.check(_ids(HudModel.strip_chips(frc, 1, {})) == [4, 3], "PS2 FRC: the producing Supply Cache shows, its resting HQ does not, got %s" % [_ids(HudModel.strip_chips(frc, 1, {}))])
	return true

# Idle a hollow bar, busy the progress, slowed (work_rate under 1000) and blocked (work done, still queued) in warn, blocked full.
func test_strip_looks(runner) -> bool:
	var half: int = roundi(_ticks(MEDIUM) * 0.5)
	var rows: Array = [["busy", 1000, [_entry(MEDIUM, half)], "busy", 0.5], ["idle", 1000, [], "idle", 0.0], ["slowed", 600, [_entry(MEDIUM, half)], "slowed", 0.5],
		["blocked", 1000, [_entry(MEDIUM, _ticks(MEDIUM)), _entry(ROTARY)], "blocked", 1.0], ["blocked under low power", 600, [_entry(MEDIUM, _ticks(MEDIUM))], "blocked", 1.0]]
	for row: Array in rows:
		var chips: Array = HudModel.strip_chips(_view([_building(5, "china_factory", row[2])], row[1]), 1, {})
		var chip: Dictionary = chips[0] if chips.size() == 1 else {}
		runner.check(chip.get("look") == row[3] and is_equal_approx(chip.get("fraction", -1.0), row[4]), "PS3 %s: look %s at %.1f, got %s" % [row[0], row[3], row[4], chip])
	return true

# An idle military producer shows its last-made unit; one that made none shows the first unit of its card (the Q cell).
func test_strip_last_made_glyph(runner) -> bool:
	var last: Dictionary = {}
	var busy: Array = HudModel.strip_chips(_view([_building(5, "china_factory", [_entry(ROTARY), _entry(MEDIUM)]), _building(3, "china_barracks")]), 1, last)
	runner.check(busy.map(func(chip: Dictionary) -> String: return chip.unit) == [MILITIA, ROTARY], "PS4 busy shows the unit in production, a never-used Barracks its Q cell's Militia, got %s" % [busy])
	var rested: Array = HudModel.strip_chips(_view([_building(5, "china_factory"), _building(3, "china_barracks"), _building(7, "china_factory")]), 1, last)
	runner.check(rested.map(func(chip: Dictionary) -> String: return chip.unit) == [MILITIA, ROTARY, MEDIUM], "PS4 the factory rests on its last-made Rotary Gun Tank, a new one on its Q cell's Medium Tank, got %s" % [rested])
	return true

# Overflow B: eight chips, then `+N` at the left; the front of the order folds first.
func test_strip_fold(runner) -> bool:
	var buildings: Array = [_building(1, "china_command_center", [_entry(DOZER)]), _building(2, "china_supply_center", [_entry(TRUCK)])]
	for id: int in range(3, 7): buildings.append(_building(id, "china_barracks"))
	for id: int in range(7, 12): buildings.append(_building(id, "china_factory"))
	var split: Array = HudModel.strip_split(HudModel.strip_chips(_view(buildings), 1, {}))
	runner.check(split.size() == 2 and _ids(split[0]) == [1, 2, 3] and _ids(split[1]) == [4, 5, 6, 7, 8, 9, 10, 11], "PS5 eleven producers: HQ, depot and the first Barracks fold, eight stay, got %s" % [split.map(_ids)])
	var eight: Array = HudModel.strip_split(HudModel.strip_chips(_view(buildings.slice(3)), 1, {}))
	runner.check(eight.size() == 2 and eight[0].is_empty() and eight[1].size() == 8, "PS5 eight producers fold nothing, got %s" % [eight.map(_ids)])
	return true

# The chip's hover card and the `+N` list words (strip round pictures `state-hover`, `state-more`).
func test_strip_tip_words(runner) -> bool:
	var chips: Array = HudModel.strip_chips(_view([_building(1, "china_command_center", [_entry(DOZER, _ticks(DOZER) - 90000)]), _building(5, "china_factory", [_entry(MEDIUM, _ticks(MEDIUM) - 120000), _entry(MEDIUM), _entry(ROTARY), _entry(MEDIUM)]),
		_building(3, "china_barracks"), _building(7, "china_factory", [_entry(MEDIUM, _ticks(MEDIUM))])]), 1, {})
	var lines: Array = chips.map(HudModel.strip_tip)
	runner.check(lines == ["Bulldozer · 3s · QUEUE 1 / 9", "Idle", "Medium Tank ×2 · 4s, then Rotary Gun Tank · +1 more · QUEUE 4 / 9", "Medium Tank · Exit blocked · QUEUE 1 / 9"], "PS6 chip cards: the current run, its seconds, the run after it, the entries past that and the queue, or Idle, got %s" % [lines])
	var hidden: Array = chips.map(HudModel.strip_hidden_line)
	runner.check(hidden == ["Headquarters · Bulldozer 3s", "Barracks · idle", "Vehicle Factory · Medium Tank 4s", "Vehicle Factory · Medium Tank · Exit blocked"], "PS6 +N list lines, got %s" % [hidden])
	runner.check(HudModel.STRIP_HINT == "Click: select it · Double-click: go there", "PS6 the hint line")
	return true

# Every China producer (HudTests._queue_world plus the HQ, which makes a Bulldozer), more Barracks and factories when `extra`, nothing selected.
func _world(runner, port: SubViewport = null, extra: int = 0) -> Array:
	var overlays = OverlayTests.new()
	var saved: String = overlays._begin()
	if port == null: port = BaseScene.sized_port(runner, Vector2i(1280, 720), Vector2i(1280, 720))
	var main = await overlays._scene(runner, Skirmish, port)
	var ids: Dictionary = HudTests.new()._queue_world(main)
	HudTests._add_hq(main, ids)
	ids.more = []
	for i in extra: ids.more.append(Fixture.add_completed(main.driver.pump.live(), 1, "china_barracks" if i < 2 else "china_factory", Vector2i(2 + 3 * (i % 4), 26 + 3 * floori(i / 4.0))))
	BaseScene.publish(main)
	HudTests._select(main, [])
	# The strip shows only while something is produced: the HQ makes a Bulldozer.
	_queues(main, {ids.hq: [DOZER]})
	await _frames(runner)
	return [overlays, saved, port, main, ids]

static func _end(world: Array) -> void:
	world[2].free()
	world[0]._end(world[1])

# Queues on the shown view only, `kinds` per building id; the first entry has worked 42 %.
static func _queues(main, queues: Dictionary, rate: int = 1000) -> void:
	var view: Dictionary = main.driver.current().view
	var next: int = 900
	for id: int in queues:
		var entries: Array = []
		for i in queues[id].size():
			entries.append({"id": next, "kind": queues[id][i], "paid_cost": 800, "work": 126000 if i == 0 else 0})
			next += 1
		HudModel.building(view, id).queue = entries
	HudModel.player(view, 1).work_rate = rate
	main._show(view)

static func _frames(runner) -> void:
	for i in 3: await runner.process_frame

static func _strip(main) -> Control:
	return main.get_node_or_null(STRIP)

static func _chips(main) -> Array:
	var row: Node = main.get_node_or_null(STRIP + "/Chips")
	if row == null: return []
	return row.get_children().filter(func(chip: Control) -> bool: return chip.name != "More" and chip.is_visible_in_tree())

static func _chip_of(main, id: int) -> Button:
	for chip: Button in _chips(main):
		if chip.get_meta("chip", {}).get("id", -1) == id: return chip
	return null

static func _more(main) -> Button:
	return main.get_node_or_null(STRIP + "/Chips/More") as Button

static func _tip(main) -> Control:
	return main.get_node_or_null(STRIP + "/Tip")

static func _clock(main, at: Array) -> void:
	if _strip(main) != null: _strip(main).now_msec = func() -> int: return at[0]

static func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

# A click selects that producer and leaves the camera; a placement armed before the click ends quietly.
func test_strip_click_selects(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var camera: Camera2D = main.get_node("Camera2D")
	var now: Array = [0]
	_clock(main, now)
	var before: Vector2 = camera.position
	var barracks: Button = _chip_of(main, ids.barracks)
	runner.check(barracks != null, "PS7 fixture: the idle Barracks has a chip")
	if barracks == null:
		_end(world)
		return true
	HudTests._click_in(port, _centre(barracks))
	await _frames(runner)
	runner.check(main.orders.selected_building_id == ids.barracks and main.orders.selected_ids.is_empty(), "PS7 a click on the Barracks chip selects the Barracks, got %d %s" % [main.orders.selected_building_id, main.orders.selected_ids])
	runner.check(camera.position == before and main.glide_seconds_left() == 0.0, "PS7 a single click leaves the camera, got %s glide %.2f" % [camera.position, main.glide_seconds_left()])
	main.orders.selected_ids.assign([1])
	main.orders.selected_building_id = -1
	main.orders._placement_kind = "china_power_plant"
	main._reshow()
	now[0] = 5000
	HudTests._click_in(port, _centre(_chip_of(main, ids.factory)))
	await _frames(runner)
	runner.check(main.orders.selected_building_id == ids.factory and main.orders._placement_kind.is_empty() and main.hud.refusal.is_empty(), "PS7 a click during a placement ends it without a refusal and selects the factory, got %d '%s' '%s'" % [main.orders.selected_building_id, main.orders._placement_kind, main.hud.refusal])
	_end(world)
	return true

# A second click on the same chip within 0.667 s (the control-group double tap) glides the camera there.
func test_strip_double_click_glides(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var camera: Camera2D = main.get_node("Camera2D")
	var now: Array = [0]
	_clock(main, now)
	var factory: Dictionary = HudModel.building(main.shown_state, ids.factory)
	var landing: Vector2 = main._landing(Vector2(factory.origin[0], factory.origin[1]) + Vector2(Registry.kind(factory.kind).footprint) / 2.0)
	camera.position = Vector2(-300, 200)
	var chip: Button = _chip_of(main, ids.factory)
	if chip == null:
		runner.check(false, "PS8 fixture: the factory has a chip")
		_end(world)
		return true
	HudTests._click_in(port, _centre(chip))
	now[0] = 667
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	runner.check(main.glide_seconds_left() > 0.0, "PS8 a second click within 0.667 s glides, got %.2f s left" % main.glide_seconds_left())
	main.glide_camera(1.0)
	runner.check(camera.position.is_equal_approx(landing) and main.orders.selected_building_id == ids.factory, "PS8 the glide lands on the factory %s with it selected, got %s" % [landing, camera.position])
	camera.position = Vector2(-300, 200)
	now[0] = 700
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	runner.check(main.glide_seconds_left() == 0.0, "PS8 a third click straight after a double starts a new pair")
	now[0] = 1500
	HudTests._click_in(port, _centre(chip))
	now[0] = 2168
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	runner.check(main.glide_seconds_left() == 0.0, "PS8 a second click after 0.668 s is a single click")
	now[0] = 3000
	HudTests._click_in(port, _centre(_chip_of(main, ids.barracks)))
	now[0] = 3100
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	runner.check(main.glide_seconds_left() == 0.0 and main.orders.selected_building_id == ids.factory, "PS8 clicks on two chips are two single clicks")
	_end(world)
	return true

# Anchor C (user, 2026-11-23): the strip ends 8 left of Menu, so the held forecast slabs never move it.
func test_strip_holds_through_a_forecast(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	_queues(main, {ids.factory: [MEDIUM]})
	await _frames(runner)
	var rest: Rect2 = _strip(main).get_global_rect() if _strip(main) != null else Rect2()
	var slabs: Rect2 = main.get_node("HUD/Hud/TopStrip").get_global_rect()
	var view: Dictionary = main.driver.current().view
	HudModel.player(view, 1).merge({"power_demand": 14, "power_supply": 10}, true)
	main.hud.update_hud(view, HudTests._placement("china_power_plant"), 1, 1)
	await _frames(runner)
	var held: Rect2 = main.get_node("HUD/Hud/TopStrip").get_global_rect()
	runner.check(held.size.x > slabs.size.x, "PS9 fixture: the slabs grow to their held forecast, %s to %s" % [slabs, held])
	runner.check(rest.size.x > 0.0 and _strip(main).get_global_rect() == rest, "PS9 the strip keeps its rect %s while the slabs hold, got %s" % [rest, _strip(main).get_global_rect() if _strip(main) != null else Rect2()])
	_end(world)
	return true

# A HUD surface: the map under it takes no click.
func test_strip_blocks_the_map(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var strip: Control = _strip(main)
	runner.check(strip != null and main.hud.blocks(_centre(strip)), "PS10 the strip blocks the map under it")
	if strip == null:
		_end(world)
		return true
	main.orders.selected_ids.assign([1])
	main._reshow()
	# The slab's edge between the border and the first chip: no chip takes it.
	var edge := Vector2(strip.get_global_rect().position.x + 2.0, strip.get_global_rect().get_center().y)
	HudTests._click_in(port, edge)
	await _frames(runner)
	runner.check(main.orders.selected_ids == [1] and main.orders.selected_building_id == -1, "PS10 a click on the strip's edge keeps the selection, got %s %d" % [main.orders.selected_ids, main.orders.selected_building_id])
	_end(world)
	return true

# Overflow B: `+3` at the left end, the HQ, depot and first Barracks hidden, listed on hover after 250 ms.
func test_strip_more_list(runner) -> bool:
	var world: Array = await _world(runner, null, 7)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var now: Array = [0]
	_clock(main, now)
	_queues(main, {ids.hq: [DOZER], ids.depot: [TRUCK]})
	await _frames(runner)
	var more: Button = _more(main)
	var chips: Array = _chips(main)
	runner.check(more != null and more.is_visible_in_tree() and more.text == "+3", "PS11 eleven producers show `+3`, got '%s'" % [more.text if more != null else ""])
	runner.check(chips.size() == 8 and more != null and chips.all(func(chip: Control) -> bool: return chip.get_global_rect().position.x > more.get_global_rect().end.x), "PS11 eight chips, all right of `+3`, got %d" % chips.size())
	if more == null:
		_end(world)
		return true
	HudTests._move(port, _centre(more))
	await _frames(runner)
	runner.check(not _tip(main).is_visible_in_tree(), "PS11 the list waits 250 ms")
	now[0] = 250
	await _frames(runner)
	var tip: Control = _tip(main)
	var text: String = "\n".join(tip.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text))
	runner.check(tip.is_visible_in_tree() and text == "ALSO PRODUCING\nHeadquarters · Bulldozer 1s\nSupply Depot · Supply Truck 6s\nBarracks · idle", "PS11 the list names the hidden producers in order, got '%s'" % text)
	runner.check(main.hud.blocks(_centre(more)), "PS11 `+3` blocks the map")
	_end(world)
	return true

# HUD headless layout at every HUD size, stacked and upright, with the most chips (eight and `+N`) and the widest held forecast; FRC has no power slab.
func test_strip_layout(runner) -> bool:
	# The default stays whatever the game ships, so a later case still sees it.
	var was: bool = ProductionStrip.upright
	for pair: Array in BaseScene.HUD_SIZES:
		var size: Vector2i = pair[1]
		var view_rect := Rect2(Vector2.ZERO, Vector2(size))
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var world: Array = await _world(runner, port, 7)
		var main = world[3]
		var ids: Dictionary = world[4]
		var now: Array = [0]
		_clock(main, now)
		_queues(main, {ids.hq: [DOZER], ids.depot: [TRUCK], ids.factory: [MEDIUM, MEDIUM]})
		for upright: bool in [false, true]:
			_strip(main).set_upright(upright)
			for faction: Array in [["usa", 14, 10], ["frc", 0, 0]]:
				var view: Dictionary = main.driver.current().view
				HudModel.player(view, 1).merge({"faction": faction[0], "power_demand": faction[1], "power_supply": faction[2]}, true)
				main.hud.update_hud(view, HudTests._placement(faction[0] + "_barracks"), 1, 1)
				await _frames(runner)
				var at: String = "%s at %s%s" % [faction[0], size, " upright" if upright else ""]
				var strip: Control = _strip(main)
				runner.check(strip != null and strip.is_visible_in_tree(), "PS12 %s: the strip shows" % at)
				if strip == null: break
				var rect: Rect2 = strip.get_global_rect()
				var menu: Rect2 = main.get_node("HUD/MenuChip").get_global_rect()
				runner.check(is_equal_approx(rect.end.x, menu.position.x - 8.0) and rect.position.y == 8.0 and rect.size.y == 32.0 and view_rect.encloses(rect), "PS12 %s: 32 high at y 8, ending 8 left of Menu (%.0f), got %s" % [at, menu.position.x - 8.0, rect])
				if pair[0] == Vector2i(1280, 720) and faction[0] == "usa":
					var gap: float = rect.position.x - main.get_node("HUD/Hud/TopStrip").get_global_rect().end.x
					print("PS12 free gap at 1280x720%s between the held power slab and eight chips plus `+N`: %.1f px" % [" upright" if upright else "", gap])
					runner.check(gap >= 0.0, "PS12 the held power slab ends left of the strip at 1280x720, gap %.1f" % gap)
				for other: Array in [["the held slabs", main.get_node("HUD/Hud/TopStrip").get_global_rect()], ["Menu", menu], ["the Playtest chip", main.get_node("HUD/Playtest/Chip").get_global_rect()]]:
					runner.check(not rect.intersects(other[1]), "PS12 %s: clear of %s %s, got %s" % [at, other[0], other[1], rect])
				var chips: Array = _chips(main)
				runner.check(chips.size() == 8 and _more(main).is_visible_in_tree() and chips.all(func(chip: Control) -> bool: return chip.size == (Vector2(42, 26) if upright else Vector2(48, 26)) and rect.grow(-1.0).encloses(chip.get_global_rect())), "PS12 %s: eight 48 or 42 x 26 chips and `+N` inside the slab" % at)
				# The chip beside Menu: its card would sit under the Playtest chip.
				HudTests._move(port, _centre(chips.back()))
				now[0] += 1000
				await _frames(runner)
				var tip: Rect2 = _tip(main).get_global_rect()
				runner.check(_tip(main).is_visible_in_tree() and view_rect.encloses(tip) and not tip.intersects(main.get_node("HUD/Playtest/Chip").get_global_rect()) and tip.position.y >= rect.end.y, "PS12 %s: the chip card under the strip, inside the view, clear of the Playtest chip, got %s" % [at, tip])
				HudTests._move(port, Vector2(size.x / 2.0, 300.0))
				await _frames(runner)
		_strip(main).set_upright(was)
		_end(world)
	return true

# Selected chip: panel2 fill and a 1 px sel inset; bars: owner colour, warn when slowed or blocked (full), a hollow track when idle.
func test_strip_chip_looks(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	HudTests._select(main, [], ids.factory)
	_queues(main, {ids.factory: [MEDIUM]})
	await _frames(runner)
	var factory: Button = _chip_of(main, ids.factory)
	var barracks: Button = _chip_of(main, ids.barracks)
	if factory == null or barracks == null:
		runner.check(false, "PS13 fixture: factory and Barracks chips")
		_end(world)
		return true
	var token := func(name: String) -> Color: return main.hud.get_theme_color(name, &"Tokens")
	var picked: StyleBoxFlat = factory.get_theme_stylebox("normal") as StyleBoxFlat
	runner.check(picked != null and picked.bg_color == token.call("panel2") and picked.border_color == token.call("sel") and picked.border_width_left == 1, "PS13 the selected producer's chip: panel2 fill, 1 px sel inset")
	var plain: StyleBoxFlat = barracks.get_theme_stylebox("normal") as StyleBoxFlat
	runner.check(plain != null and plain.bg_color == token.call("btn") and plain.border_width_left == 0, "PS13 an unselected chip: btn fill, no frame")
	var fill: ColorRect = factory.get_node("Track/Fill")
	runner.check(fill.color == main.hud.panel_edge() and fill.size == Vector2(4, 8), "PS13 busy: the owner colour, 8 of 20 px at 42 %%, got %s %s" % [fill.color, fill.size])
	var hollow: StyleBoxFlat = barracks.get_node("Track").get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(hollow != null and not hollow.draw_center and hollow.border_width_left == 1 and is_zero_approx((barracks.get_node("Track/Fill") as Control).size.y), "PS13 idle: a 1 px outline track, empty")
	runner.check(barracks.get_node("Glyph").self_modulate != Color.WHITE and factory.get_node("Glyph").self_modulate == Color.WHITE, "PS13 idle glyph darker than busy")
	_queues(main, {ids.factory: [MEDIUM]}, 600)
	await _frames(runner)
	runner.check(fill.color == token.call("warn") and fill.size == Vector2(4, 8), "PS13 slowed: warn at 42 %%, got %s" % [fill.color])
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, ids.factory).queue[0].work = Economy.unit(MEDIUM).ticks * 1000
	HudModel.player(view, 1).work_rate = 1000
	main._show(view)
	await _frames(runner)
	runner.check(fill.color == token.call("warn") and fill.size == Vector2(4, 20), "PS13 exit blocked: a full warn bar, got %s %s" % [fill.color, fill.size])
	_end(world)
	return true

# F38 (UL1 style): an unchanged refresh does no layout work on the strip; production advancing moves only the bars.
func test_strip_unchanged_refresh(runner) -> bool:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = HudTests.new()._queue_world(main)
	HudTests._add_hq(main, ids)
	_queues(main, {ids.hq: [DOZER], ids.factory: [MEDIUM, ROTARY]})
	await _frames(runner)
	var strip: Control = _strip(main)
	if strip == null:
		runner.check(false, "PS14 fixture: the strip exists")
		main.free()
		return true
	var watched: Array = [strip] + strip.find_children("*", "Control", true, false).filter(func(part: Control) -> bool: return part.name != "Fill")
	var layout: Callable = func() -> Array: return watched.map(func(part: Control) -> Array: return [part.get_instance_id(), part.visible, part.get_global_rect(), part.get_children().map(func(child: Node) -> int: return child.get_instance_id())])
	var before: Array = layout.call()
	var churn: Array = [0]
	for part: Control in watched:
		part.resized.connect(func() -> void: churn[0] += 1)
		part.theme_changed.connect(func() -> void: churn[0] += 1)
		if part is Container: (part as Container).sort_children.connect(func() -> void: churn[0] += 1)
	main._reshow()
	main._reshow()
	await _frames(runner)
	runner.check(layout.call() == before and churn[0] == 0, "PS14 two unchanged refreshes keep the strip's nodes and rects and resize, re-theme and re-sort nothing, got %d signals" % churn[0])
	var advanced: Dictionary = main.driver.current().view.duplicate(true)
	HudModel.building(advanced, ids.factory).queue[0].work = 252000
	main._show(advanced)
	await _frames(runner)
	var fill: Control = _chip_of(main, ids.factory).get_node("Track/Fill")
	runner.check(fill.size == Vector2(4, 17), "PS14 fixture: the factory's bar moves to 84 %%, got %s" % fill.size)
	runner.check(layout.call() == before and churn[0] == 0, "PS14 production advancing moves only the bars, got %d signals" % churn[0])
	var chip: Button = _chip_of(main, ids.factory)
	var clock: Array = [0]
	strip.now_msec = func() -> int: return clock[0]
	chip.mouse_entered.emit()
	clock[0] = 1000
	strip._process(0.0)
	await _frames(runner)
	runner.check(strip.get_node("Tip").visible, "PS14 fixture: the factory's card is open")
	var open: Array = layout.call()
	churn[0] = 0
	var record: Dictionary = chip.get_meta("chip")
	# 84.3 %: the same 17 px bar and the same 2s.
	var ticked: Dictionary = advanced.duplicate(true)
	HudModel.building(ticked, ids.factory).queue[0].work = 253000
	main._reshow()
	main._show(ticked)
	await _frames(runner)
	runner.check(layout.call() == open and churn[0] == 0 and is_same(chip.get_meta("chip"), record), "PS14 with the card open, a refresh and a tick drawing the same bar and seconds fill nothing and lay nothing out, got %d signals" % churn[0])
	main.free()
	return true

# Upright by default (user, 2026-11-23): count | glyph | 4 x 20 bar, 42 wide; F7 flips to the stacked 48 px chip and back.
func test_strip_upright_bars(runner) -> bool:
	var was: bool = ProductionStrip.upright
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	_queues(main, {ids.factory: [MEDIUM]})
	await _frames(runner)
	var key := func() -> void:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F7
		event.keycode = KEY_F7
		event.pressed = true
		world[2].push_input(event, true)
	for step: String in ["default", "F7", "F7 again"]:
		if step != "default":
			key.call()
			await _frames(runner)
		var upright: bool = step != "F7"
		var chip: Button = _chip_of(main, ids.factory)
		if chip == null:
			runner.check(false, "PS15 %s: the factory has a chip" % step)
			continue
		var track: Control = chip.get_node("Track")
		var fill: Control = track.get_node("Fill")
		if upright:
			runner.check(chip.size == Vector2(42, 26) and track.size == Vector2(4, 20) and fill.position == Vector2(0, 12) and fill.size == Vector2(4, 8), "PS15 %s: 42 x 26, a 4 x 20 bar filled 8 px from the bottom, got %s %s %s" % [step, chip.size, fill.position, fill.size])
			var count: Rect2 = (chip.get_node("Count") as Control).get_global_rect()
			var glyph: Rect2 = (chip.get_node("Glyph") as Control).get_global_rect()
			runner.check(count.end.x <= glyph.position.x and glyph.end.x <= track.get_global_rect().position.x, "PS15 %s: count, glyph and bar side by side, got %s %s %s" % [step, count, glyph, track.get_global_rect()])
		else:
			runner.check(chip.size == Vector2(48, 26) and track.size == Vector2(40, 4) and fill.position == Vector2.ZERO and fill.size == Vector2(17, 4), "PS15 %s: the stacked 48 x 26 chip, a 40 x 4 bar filled 17 px, got %s %s %s" % [step, chip.size, fill.position, fill.size])
	_strip(main).set_upright(was)
	_end(world)
	return true

# F7 goes through `orders` like F3, so a focused playtest field keeps the key.
func test_strip_upright_key_skips_typing(runner) -> bool:
	var was: bool = ProductionStrip.upright
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	_queues(main, {ids.factory: [MEDIUM]})
	var field: LineEdit = world[0]._field(main, "Answer_" + world[0]._questions()[0].id)
	field.grab_focus()
	await _frames(runner)
	runner.check(main._typing(), "PS16 fixture: the playtest answer field has the focus")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F7
	event.keycode = KEY_F7
	event.pressed = true
	world[2].push_input(event, true)
	await _frames(runner)
	var chip: Button = _chip_of(main, ids.factory)
	runner.check(chip != null and chip.size == Vector2(42, 26), "PS16 F7 while typing in the note leaves the chips upright, got %s" % [chip.size if chip != null else Vector2.ZERO])
	_strip(main).set_upright(was)
	_end(world)
	return true

# A rematch's producers start without a last-made unit: an idle factory shows its Q cell's unit again.
func test_strip_reset_forgets_last_made(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	_queues(main, {ids.factory: [ROTARY]})
	_queues(main, {ids.factory: []})
	await _frames(runner)
	runner.check(_chip_of(main, ids.factory).get_meta("chip").unit == ROTARY, "PS17 fixture: the idle factory shows its last-made Rotary Gun Tank")
	main.hud.reset()
	_queues(main, {ids.factory: []})
	await _frames(runner)
	runner.check(_chip_of(main, ids.factory).get_meta("chip").unit == MEDIUM, "PS17 after a reset the idle factory shows its Q cell's Medium Tank, got %s" % [_chip_of(main, ids.factory).get_meta("chip").unit])
	_end(world)
	return true

# Tooltip rules: a neighbour's card opens at once while one is open; leaving the strip makes the next one wait again.
func test_strip_tip_neighbour_rule(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var now: Array = [0]
	_clock(main, now)
	var factory: Button = _chip_of(main, ids.factory)
	var barracks: Button = _chip_of(main, ids.barracks)
	HudTests._move(port, _centre(barracks))
	now[0] = 300
	await _frames(runner)
	runner.check(_tip(main).visible, "PS18 fixture: the Barracks card is open")
	HudTests._move(port, _centre(factory))
	await _frames(runner)
	var name: Label = _tip(main).get_node("Lines/Name")
	runner.check(_tip(main).visible and name.text == "Vehicle Factory", "PS18 moving to the next chip opens its card at once, got %s '%s'" % [_tip(main).visible, name.text])
	HudTests._move(port, Vector2(640, 300))
	await _frames(runner)
	HudTests._move(port, _centre(factory))
	await _frames(runner)
	runner.check(not _tip(main).visible, "PS18 after leaving the strip the card waits again")
	now[0] = 550
	await _frames(runner)
	runner.check(_tip(main).visible, "PS18 and opens after 250 ms")
	_end(world)
	return true

# A chip click ends attack move and the build sub-grid, as it ends a placement.
func test_strip_click_ends_modes(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	for mode: String in ["attack move", "sub-grid"]:
		main.orders.selected_ids.assign([1])
		main.orders.selected_building_id = -1
		if mode == "attack move": main.orders._set_attack_move(true)
		else: main.orders._sub_grid = true
		main._reshow()
		HudTests._click_in(port, _centre(_chip_of(main, ids.factory)))
		await _frames(runner)
		runner.check(main.orders.selected_building_id == ids.factory and not main.orders._attack_move_mode and not main.orders._sub_grid, "PS19 a chip click during %s ends it and selects the factory, got %d %s %s" % [mode, main.orders.selected_building_id, main.orders._attack_move_mode, main.orders._sub_grid])
	_end(world)
	return true

# No orders while the note holds the match, and only an own finished building is selected.
func test_strip_click_needs_orders_and_an_own_producer(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	var live = main.driver.pump.live()
	var enemy: int = Fixture.add_completed(live, 2, "china_factory", Vector2i(26, 2))
	var site: int = Fixture.add_completed(live, 1, "china_barracks", Vector2i(20, 12))
	BaseScene.publish(main)
	HudModel.building(main.driver.current().view, site).completed = false
	_queues(main, {ids.hq: [DOZER]})
	main.orders.selected_ids.assign([1])
	main.orders.selected_building_id = -1
	main._reshow()
	var dialog: Control = main.get_node("HUD/Playtest/MarkerDialog")
	dialog.visible = true
	await _frames(runner)
	HudTests._click_in(world[2], _centre(_chip_of(main, ids.factory)))
	await _frames(runner)
	dialog.visible = false
	runner.check(main.orders.selected_ids == [1] and main.orders.selected_building_id == -1 and main.glide_seconds_left() == 0.0, "PS20 with the note holding the match a chip click changes nothing, got %s %d" % [main.orders.selected_ids, main.orders.selected_building_id])
	runner.check(_hint_shown(main) and not _hint_saved(), "PS20 and the click under the note leaves the one-time hint")
	for other: Array in [["an enemy factory", enemy], ["an own site", site]]:
		main.hud.producer_pressed.emit(other[1], false)
		runner.check(main.orders.selected_ids == [1] and main.orders.selected_building_id == -1, "PS20 %s is never selected, got %s %d" % [other[0], main.orders.selected_ids, main.orders.selected_building_id])
	_end(world)
	return true

# The fill stays inside its track: upright it keeps the track's bottom and grows up, stacked it keeps the left edge, round(fraction x length) long.
func test_strip_bar_stays_in_its_track(runner) -> bool:
	var was: bool = ProductionStrip.upright
	for pair: Array in [BaseScene.HUD_SIZES[0], BaseScene.HUD_SIZES[2]]:
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], pair[1])
		var world: Array = await _world(runner, port)
		var main = world[3]
		var ids: Dictionary = world[4]
		var ticks: int = _ticks(MEDIUM)
		for upright: bool in [false, true]:
			_strip(main).set_upright(upright)
			var bad: Array = []
			var works: Array = [0.0, 0.01, 0.33, 0.5, 0.99, 1.0].map(func(f: float) -> int: return roundi(f * ticks))
			for step: int in range(0, ticks + 1, 1000): works.append(step)
			for work: int in works:
				_queues(main, {ids.factory: [MEDIUM]})
				var view: Dictionary = main.driver.current().view
				HudModel.building(view, ids.factory).queue[0].work = work
				main._show(view)
				await runner.process_frame
				var track: Control = _chip_of(main, ids.factory).get_node("Track")
				var fill: Control = track.get_node("Fill")
				var outer: Rect2 = track.get_global_rect()
				var inner: Rect2 = fill.get_global_rect()
				var fraction: float = minf(1.0, float(work) / ticks)
				var length: float = roundf(fraction * (outer.size.y if upright else outer.size.x))
				var held: bool = outer.encloses(inner) and (is_equal_approx(inner.end.y, outer.end.y) and is_equal_approx(inner.size.y, length) and is_equal_approx(inner.size.x, outer.size.x) if upright else is_equal_approx(inner.position.x, outer.position.x) and is_equal_approx(inner.size.x, length) and is_equal_approx(inner.size.y, outer.size.y))
				if not held: bad.append([snappedf(fraction, 0.001), outer, inner])
			var edge: StyleBoxFlat = _chip_of(main, ids.factory).get_node("Track").get_theme_stylebox("panel") as StyleBoxFlat
			var hollow: StyleBoxFlat = _chip_of(main, ids.barracks).get_node("Track").get_theme_stylebox("panel") as StyleBoxFlat
			runner.check(edge != null and not edge.anti_aliasing and hollow != null and hollow != edge and not hollow.anti_aliasing, "PS21 %s: the busy and the idle (hollow) tracks draw hard edges like the fill" % ("upright" if upright else "stacked"))
			runner.check(bad.is_empty(), "PS21 %s at %s: the fill stays in its track at its length, got %d off: %s" % ["upright" if upright else "stacked", pair[0], bad.size(), bad.slice(0, 4)])
		_strip(main).set_upright(was)
		_end(world)
	return true

# The owner's pick (user, 2026-11-23): the count is the current run (as NEXT's ×N), small (12 px, the HUD's floor) in its column, a 4 x 6 mark under it
# while other kinds follow, bottom-aligned with the glyph; neither when idle, chips as wide as before.
func test_strip_queue_count(runner) -> bool:
	var was: bool = ProductionStrip.upright
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	var four_three: Array = [MEDIUM, MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY, ROTARY]
	for upright: bool in [false, true]:
		_strip(main).set_upright(upright)
		var mode: String = "upright" if upright else "stacked"
		for row: Array in [[four_three, "4", true], [[MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM], "7", false], [[MEDIUM, ROTARY, MEDIUM], "1", true], [[MEDIUM], "1", false], [[], "", false]]:
			_queues(main, {ids.hq: [DOZER], ids.factory: row[0]})
			await _frames(runner)
			var chip: Button = _chip_of(main, ids.factory)
			var count: Label = chip.get_node_or_null("Count") if chip != null else null
			var mark: Control = chip.get_node_or_null("Then") if chip != null else null
			var shown: String = count.text if count != null and count.is_visible_in_tree() else ""
			var marked: bool = mark != null and mark.is_visible_in_tree()
			runner.check(shown == row[1] and marked == row[2], "PS22 %s: %s shows '%s'%s, got '%s' mark %s" % [mode, row[0], row[1], " and the mark" if row[2] else ", no mark", shown, marked])
			runner.check(chip != null and chip.size == (Vector2(42, 26) if upright else Vector2(48, 26)), "PS22 %s, %d queued: the chip keeps its width, got %s" % [mode, row[0].size(), chip.size if chip != null else Vector2.ZERO])
			if count == null or not count.is_visible_in_tree(): continue
			var box: Rect2 = count.get_global_rect()
			var glyph: Rect2 = (chip.get_node("Glyph") as Control).get_global_rect()
			var track: Rect2 = (chip.get_node("Track") as Control).get_global_rect()
			runner.check(chip.get_global_rect().encloses(box) and not box.intersects(track) and not box.intersects(glyph), "PS22 %s: the count inside the chip, clear of the glyph and the bar, got %s glyph %s" % [mode, box, glyph])
			if upright: runner.check(box.position.x < glyph.position.x and is_equal_approx(box.position.y, glyph.position.y), "PS22 upright: the count in its own column left of the glyph, top-aligned with it, got %s glyph %s" % [box, glyph])
			runner.check(count.get_theme_font_size("font_size") == 12 and count.get_theme_color("font_color") == main.hud.get_theme_color("muted", &"Tokens"), "PS22 %s: 12 px muted" % mode)
			if not marked: continue
			var at: Rect2 = mark.get_global_rect()
			var baseline: float = box.position.y + count.get_theme_font("font").get_ascent(12)
			runner.check(at.size == Vector2(4, 6) and chip.get_global_rect().encloses(at) and at.position.x >= box.position.x and at.end.x <= box.end.x and at.position.y >= baseline and is_equal_approx(at.end.y, glyph.end.y) and not at.intersects(glyph) and not at.intersects(track),
				"PS22 %s: a 4 x 6 mark in the count's column under its digits (baseline %.1f), its bottom on the glyph's, clear of glyph and bar, got %s count %s glyph %s" % [mode, baseline, at, box, glyph])
	_strip(main).set_upright(was)
	_end(world)
	return true

# The owner's rule (user, 2026-11-23): with nothing in production the strip is gone, also for a selected producer; one unit in production brings it back.
func test_strip_hides_while_nothing_is_made(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	var strip: Control = _strip(main)
	var spot: Vector2 = _centre(strip)
	HudTests._select(main, [], ids.factory)
	_queues(main, {ids.hq: []})
	await _frames(runner)
	runner.check(not strip.is_visible_in_tree() and not main.hud.blocks(spot), "PS23 all idle, the factory selected: no strip and the map takes clicks there")
	var watched: Array = [strip] + strip.find_children("*", "Control", true, false)
	var churn: Array = [0]
	for part: Control in watched:
		part.resized.connect(func() -> void: churn[0] += 1)
		part.visibility_changed.connect(func() -> void: churn[0] += 1)
		if part is Container: (part as Container).sort_children.connect(func() -> void: churn[0] += 1)
	main._reshow()
	main._reshow()
	await _frames(runner)
	runner.check(churn[0] == 0, "PS23 unchanged refreshes while hidden do no layout work, got %d signals" % churn[0])
	_queues(main, {ids.factory: [MEDIUM]})
	await _frames(runner)
	var barracks: Button = _chip_of(main, ids.barracks)
	runner.check(strip.is_visible_in_tree() and main.hud.blocks(spot) and barracks != null and barracks.get_meta("chip").look == "idle", "PS23 one unit in production shows the strip, the idle Barracks hollow beside it")
	_queues(main, {ids.factory: []})
	await _frames(runner)
	runner.check(not strip.is_visible_in_tree(), "PS23 the last one finished hides the strip again")
	_end(world)
	return true

# The owner's pick (user, 2026-11-23): the chip card names the current run, then the next one, then how many follow, keeping QUEUE n / 9.
func test_strip_tip_names_the_runs(runner) -> bool:
	var rows: Array = [[[MEDIUM, MEDIUM, MEDIUM, MEDIUM, ROTARY, ROTARY, ROTARY], "Medium Tank ×4 · 6s, then Rotary Gun Tank ×3 · QUEUE 7 / 9"], [[MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM, MEDIUM], "Medium Tank ×7 · 6s · QUEUE 7 / 9"],
		[[MEDIUM, ROTARY, MEDIUM], "Medium Tank · 6s, then Rotary Gun Tank · +1 more · QUEUE 3 / 9"]]
	for row: Array in rows:
		var entries: Array = []
		for i in row[0].size(): entries.append({"id": i, "kind": row[0][i], "paid_cost": 800, "work": 126000 if i == 0 else 0})
		var got: String = HudModel.strip_tip(HudModel.strip_chips(_view([_building(5, "china_factory", entries)]), 1, {})[0])
		runner.check(got == row[1], "PS26 %s reads '%s', got '%s'" % [row[0], row[1], got])
	# The widest card a Barracks can show stays one line inside the smallest view.
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	var trooper: String = "china_rocket_infantry"
	var view: Dictionary = main.driver.current().view
	var queue: Array = []
	for i in 9: queue.append({"id": 950 + i, "kind": trooper if i < 4 or i == 7 else MILITIA, "paid_cost": 300, "work": Economy.unit(trooper).ticks * 1000 if i == 0 else 0})
	HudModel.building(view, ids.barracks).queue = queue
	main._show(view)
	var now: Array = [0]
	_clock(main, now)
	await _frames(runner)
	HudTests._move(world[2], _centre(_chip_of(main, ids.barracks)))
	now[0] = 1000
	await _frames(runner)
	var text: Label = _tip(main).get_node("Lines/Text")
	var line: String = text.text.get_slice("\n", 0)
	var tip: Rect2 = _tip(main).get_global_rect()
	print("PS26 widest chip card at 1280x720: %.0f px for '%s'" % [tip.size.x, line])
	runner.check(line == "Anti-Tank Trooper ×4 · Exit blocked, then Militia ×3 · +2 more · QUEUE 9 / 9" and text.text.count("\n") == 1 and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(tip), "PS26 the widest card, one line inside the view, got '%s' %s" % [line, tip])
	_end(world)
	return true

# Gemini review: the whole strip hidden under the pointer gets its exits from the engine (a hidden control drops the hover), so the card never
# pops up away from the pointer later and the next hover waits its 250 ms again.
func test_strip_hidden_under_the_pointer(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var now: Array = [0]
	_clock(main, now)
	_queues(main, {ids.hq: [DOZER], ids.factory: [MEDIUM]})
	await _frames(runner)
	HudTests._move(port, _centre(_chip_of(main, ids.factory)))
	now[0] = 300
	await _frames(runner)
	runner.check(_tip(main).visible, "PS27 fixture: the factory's card is open")
	_queues(main, {ids.hq: [], ids.factory: []})
	await _frames(runner)
	runner.check(not _strip(main).is_visible_in_tree() and not _tip(main).visible, "PS27 fixture: nothing in production, strip and card gone")
	HudTests._move(port, Vector2(640, 400))
	await _frames(runner)
	_queues(main, {ids.factory: [MEDIUM]})
	now[0] = 2000
	await _frames(runner)
	runner.check(_strip(main).is_visible_in_tree() and not _tip(main).visible, "PS27 the strip back with the pointer on the map: no card")
	HudTests._move(port, _centre(_chip_of(main, ids.factory)))
	await _frames(runner)
	runner.check(not _tip(main).visible, "PS27 the next hover waits again")
	now[0] = 2250
	await _frames(runner)
	runner.check(_tip(main).visible, "PS27 and opens after 250 ms")
	_end(world)
	return true

# Gemini review: under the freeze card (or a result, or the menu) a chip click ends no hint and arms no double click.
func test_strip_click_under_the_freeze_card(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var now: Array = [0]
	_clock(main, now)
	var chip: Button = _chip_of(main, ids.factory)
	main.driver._failure = "test freeze"
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	main.driver._failure = ""
	runner.check(_hint_shown(main) and not _hint_saved(), "PS28 a click under the freeze card leaves the hint")
	now[0] = 100
	HudTests._click_in(port, _centre(chip))
	await _frames(runner)
	runner.check(main.orders.selected_building_id == ids.factory and main.glide_seconds_left() == 0.0, "PS28 the first click after it is a single click, got %d glide %.2f" % [main.orders.selected_building_id, main.glide_seconds_left()])
	_end(world)
	return true

# Opus review: the chip card steps aside for an online notice, as the hint does, and comes back once it goes.
func test_strip_card_steps_aside_for_a_notice(runner) -> bool:
	var world: Array = await _world(runner)
	var port: SubViewport = world[2]
	var main = world[3]
	var ids: Dictionary = world[4]
	var now: Array = [0]
	_clock(main, now)
	HudTests._move(port, _centre(_chip_of(main, ids.factory)))
	now[0] = 300
	await _frames(runner)
	runner.check(_tip(main).visible, "PS29 fixture: the card is open")
	main.hud.update_hud(main.shown_state, HudTests._placement("", false, "Waiting for the other player"), 1, 1)
	await _frames(runner)
	runner.check(main.get_node("HUD/Hud/Notice").is_visible_in_tree() and not _tip(main).visible, "PS29 a notice up: the card hides")
	main._reshow()
	await _frames(runner)
	runner.check(_tip(main).visible, "PS29 the notice gone, the card is back under the pointer")
	_end(world)
	return true

static func _hint(main) -> Control:
	return main.get_node_or_null(STRIP + "/Hint")

static func _hint_shown(main) -> bool:
	var hint: Control = _hint(main)
	return hint != null and hint.is_visible_in_tree() and (hint.get_node("Text") as Label).text == HINT

static func _hint_saved() -> bool:
	var config := ConfigFile.new()
	return config.load(AudioSettings.path) == OK and config.get_value("hints", "strip_seen", false) == true

# The owner's one-time hint (user, 2026-11-23): shown on the strip's first appearance, gone for good on a chip click or after 10 s of
# visible time; a strip hide, the menu or an unfocused window pause it (coordinator's call, owner-reversible).
func test_strip_hint_once(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[3]
	var ids: Dictionary = world[4]
	runner.check(_hint_shown(main) and not _hint_saved(), "PS24 the strip's first appearance shows the hint")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.3)
	config.save(AudioSettings.path)
	HudTests._click_in(world[2], _centre(_chip_of(main, ids.factory)))
	await _frames(runner)
	config = ConfigFile.new()
	config.load(AudioSettings.path)
	runner.check(not _hint_shown(main) and _hint_saved() and config.get_value("audio", "music", 0.0) == 0.3, "PS24 a chip click ends it and saves hints/strip_seen beside the other settings")
	var fresh = ProductionStrip.new()
	world[2].add_child(fresh)
	fresh.show_chips(HudModel.strip_chips(main.shown_state, 1, {}) + [{"id": 99, "kind": "china_factory", "rank": 3, "unit": MEDIUM, "look": "busy", "fraction": 0.5, "queue": 1, "runs": [{"kind": MEDIUM, "count": 1}], "left": "5s"}], -1, Color.WHITE)
	await _frames(runner)
	runner.check(fresh.is_visible_in_tree() and not fresh.get_node("Hint").is_visible_in_tree(), "PS24 a fresh strip with the setting saved shows no hint")
	_end(world)
	world = await _world(runner)
	main = world[3]
	ids = world[4]
	var strip: Control = _strip(main)
	# The frames would add their own deltas to the hand-driven ones.
	strip.set_process(false)
	runner.check(_hint_shown(main), "PS24 fixture: a new machine shows the hint again")
	strip._process(6.0)
	_queues(main, {ids.hq: []})
	await _frames(runner)
	runner.check(not _hint_shown(main) and not _hint_saved(), "PS24 the strip hiding hides the hint without ending it")
	strip._process(20.0)
	_queues(main, {ids.hq: [DOZER]})
	await _frames(runner)
	strip._process(3.0)
	runner.check(_hint_shown(main), "PS24 back with the strip, hidden time not counted: 9 s visible, still shown")
	strip._process(1.5)
	runner.check(not _hint_shown(main) and _hint_saved(), "PS24 after 10 s of visible time it goes for good")
	_end(world)
	world = await _world(runner)
	main = world[3]
	strip = _strip(main)
	strip.set_process(false)
	main._pause.open()
	strip._process(20.0)
	main._pause.close()
	main._focused = false
	strip._process(20.0)
	main._focused = true
	main.driver._failure = "test freeze"
	strip._process(20.0)
	main.driver._failure = ""
	strip._process(9.0)
	runner.check(_hint_shown(main), "PS24 time under the open menu, in an unfocused window or under the freeze card is not counted")
	strip._process(1.5)
	runner.check(not _hint_shown(main), "PS24 and 10 s of uncovered time end it")
	_end(world)
	return true

# Under the strip, right-aligned with it, clear of the Playtest chip, Menu and the slabs, inside the view; the map under it takes clicks.
func test_strip_hint_layout(runner) -> bool:
	for pair: Array in BaseScene.HUD_SIZES.slice(0, 3):
		var size: Vector2i = pair[1]
		var port: SubViewport = BaseScene.sized_port(runner, pair[0], size)
		var world: Array = await _world(runner, port, 7)
		var main = world[3]
		var ids: Dictionary = world[4]
		_queues(main, {ids.hq: [DOZER], ids.depot: [TRUCK]})
		await _frames(runner)
		var at: String = "at %s" % pair[0]
		runner.check(_hint_shown(main), "PS25 %s: the hint shows" % at)
		var hint: Rect2 = _hint(main).get_global_rect()
		var strip: Rect2 = _strip(main).get_global_rect()
		runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(hint) and hint.position.y >= strip.end.y and hint.end.x <= strip.end.x, "PS25 %s: under the strip, not right of it, inside the view, got %s strip %s" % [at, hint, strip])
		for other: String in ["HUD/Playtest/Chip", "HUD/MenuChip", "HUD/Hud/TopStrip", STRIP]:
			runner.check(not hint.intersects(main.get_node(other).get_global_rect()), "PS25 %s: clear of %s, got %s" % [at, other, hint])
		# An online notice takes the top centre; the hint steps aside (hidden, its time paused) while one shows.
		var notice: String = "Waiting for the other player. " + "The relay holds the match until both seats answer again. ".repeat(3)
		main.hud.update_hud(main.shown_state, HudTests._placement("", false, notice), 1, 1)
		await _frames(runner)
		var shown: Rect2 = main.get_node("HUD/Hud/Notice").get_global_rect()
		runner.check(main.get_node("HUD/Hud/Notice").is_visible_in_tree() and not (_hint(main).is_visible_in_tree() and _hint(main).get_global_rect().intersects(shown)), "PS25 %s: the hint never meets a long notice %s" % [at, shown])
		_strip(main).set_process(false)
		_strip(main)._process(20.0)
		_strip(main).set_process(true)
		main._reshow()
		await _frames(runner)
		runner.check(_hint_shown(main) and not _hint_saved(), "PS25 %s: the hint is back once the notice goes, the 20 s under it not counted" % at)
		runner.check(not main.hud.blocks(hint.get_center()), "PS25 %s: the hint blocks nothing" % at)
		HudTests._move(port, hint.get_center())
		await _frames(runner)
		var hovered: Control = main.get_viewport().gui_get_hovered_control()
		runner.check(hovered == null, "PS25 %s: the pointer on the hint is on the map, no control takes it, got %s" % [at, hovered])
		_end(world)
	return true
