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
const MEDIUM: String = "china_light_vehicle"
const ROTARY: String = "china_tank"
const MILITIA: String = "china_rifle_infantry"
const DOZER: String = "china_builder"
const TRUCK: String = "china_collector"

func cases() -> Array[Callable]:
	return [test_strip_order, test_strip_busy_only_kinds, test_strip_looks, test_strip_last_made_glyph, test_strip_fold, test_strip_tip_words, test_strip_click_selects, test_strip_double_click_glides, test_strip_holds_through_a_forecast, test_strip_blocks_the_map, test_strip_more_list, test_strip_layout, test_strip_chip_looks, test_strip_unchanged_refresh, test_strip_upright_bars, test_strip_upright_key_skips_typing, test_strip_reset_forgets_last_made, test_strip_tip_neighbour_rule, test_strip_click_ends_modes, test_strip_click_needs_orders_and_an_own_producer]

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
	runner.check(lines == ["Bulldozer · 3s · QUEUE 1 / 9", "Idle", "Medium Tank · 4s · QUEUE 4 / 9", "Medium Tank · Exit blocked · QUEUE 1 / 9"], "PS6 chip cards: unit, seconds left and queue, or Idle, got %s" % [lines])
	var hidden: Array = chips.map(HudModel.strip_hidden_line)
	runner.check(hidden == ["Headquarters · Bulldozer 3s", "Barracks · idle", "Vehicle Factory · Medium Tank 4s", "Vehicle Factory · Medium Tank · Exit blocked"], "PS6 +N list lines, got %s" % [hidden])
	runner.check(HudModel.STRIP_HINT == "Click: select · Double-click: go there", "PS6 the hint line")
	return true

# Every China producer (HudTests._queue_world plus the HQ), more Barracks and factories when `extra`, nothing selected.
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
	main.hud.update_hud(view, HudTests._armed("china_power_plant"), 1, 1)
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
	runner.check(tip.is_visible_in_tree() and text == "NOT ON THE STRIP\nHeadquarters · Bulldozer 1s\nSupply Depot · Supply Truck 6s\nBarracks · idle", "PS11 the list names the hidden producers in order, got '%s'" % text)
	runner.check(main.hud.blocks(_centre(more)), "PS11 `+3` blocks the map")
	_end(world)
	return true

# HUD headless layout at every HUD size, stacked and upright, with the most chips (eight and `+N`) and the widest held forecast; FRC has no power slab.
func test_strip_layout(runner) -> bool:
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
				main.hud.update_hud(view, HudTests._armed(faction[0] + "_barracks"), 1, 1)
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
				runner.check(chips.size() == 8 and _more(main).is_visible_in_tree() and chips.all(func(chip: Control) -> bool: return chip.size == (Vector2(34, 26) if upright else Vector2(48, 26)) and rect.grow(-1.0).encloses(chip.get_global_rect())), "PS12 %s: eight 48 or 34 x 26 chips and `+N` inside the slab" % at)
				# The chip beside Menu: its card would sit under the Playtest chip.
				HudTests._move(port, _centre(chips.back()))
				now[0] += 1000
				await _frames(runner)
				var tip: Rect2 = _tip(main).get_global_rect()
				runner.check(_tip(main).is_visible_in_tree() and view_rect.encloses(tip) and not tip.intersects(main.get_node("HUD/Playtest/Chip").get_global_rect()) and tip.position.y >= rect.end.y, "PS12 %s: the chip card under the strip, inside the view, clear of the Playtest chip, got %s" % [at, tip])
				HudTests._move(port, Vector2(size.x / 2.0, 300.0))
				await _frames(runner)
		_strip(main).set_upright(false)
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
	runner.check(fill.color == main.hud.panel_edge() and is_equal_approx(fill.anchor_right, 0.42), "PS13 busy: the owner colour at 42 %%, got %s %.2f" % [fill.color, fill.anchor_right])
	var hollow: StyleBoxFlat = barracks.get_node("Track").get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(hollow != null and not hollow.draw_center and hollow.border_width_left == 1 and is_zero_approx((barracks.get_node("Track/Fill") as Control).anchor_right), "PS13 idle: a 1 px outline track, empty")
	runner.check(barracks.get_node("Glyph").self_modulate != Color.WHITE and factory.get_node("Glyph").self_modulate == Color.WHITE, "PS13 idle glyph darker than busy")
	_queues(main, {ids.factory: [MEDIUM]}, 600)
	await _frames(runner)
	runner.check(fill.color == token.call("warn") and is_equal_approx(fill.anchor_right, 0.42), "PS13 slowed: warn at 42 %%, got %s" % [fill.color])
	var view: Dictionary = main.driver.current().view
	HudModel.building(view, ids.factory).queue[0].work = Economy.unit(MEDIUM).ticks * 1000
	HudModel.player(view, 1).work_rate = 1000
	main._show(view)
	await _frames(runner)
	runner.check(fill.color == token.call("warn") and is_equal_approx(fill.anchor_right, 1.0), "PS13 exit blocked: a full warn bar, got %s %.2f" % [fill.color, fill.anchor_right])
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
	runner.check(is_equal_approx(fill.anchor_right, 0.84), "PS14 fixture: the factory's bar moves to 84 %%, got %.2f" % fill.anchor_right)
	runner.check(layout.call() == before and churn[0] == 0, "PS14 production advancing moves only the bars, got %d signals" % churn[0])
	main.free()
	return true

# The owner's experiment (chip C note): F7 draws each chip as the glyph beside a 4 x 20 bar, 34 wide; F7 again restores 48.
func test_strip_upright_bars(runner) -> bool:
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
	key.call()
	await _frames(runner)
	var chip: Button = _chip_of(main, ids.factory)
	runner.check(chip != null and chip.size == Vector2(34, 26) and (chip.get_node("Track") as Control).size == Vector2(4, 20), "PS15 F7: 34 x 26 chips with a 4 x 20 bar, got %s" % [chip.size if chip != null else Vector2.ZERO])
	if chip != null:
		var fill: Control = chip.get_node("Track/Fill")
		runner.check(is_equal_approx(fill.anchor_top, 0.58) and fill.anchor_right == 1.0, "PS15 the upright bar fills from the bottom, got top %.2f right %.2f" % [fill.anchor_top, fill.anchor_right])
		runner.check(chip.get_node("Glyph").get_global_rect().end.x <= (chip.get_node("Track") as Control).get_global_rect().position.x, "PS15 the glyph beside the bar")
	key.call()
	await _frames(runner)
	chip = _chip_of(main, ids.factory)
	runner.check(chip != null and chip.size == Vector2(48, 26) and (chip.get_node("Track") as Control).size == Vector2(40, 4), "PS15 F7 again restores the stacked chip, got %s" % [chip.size if chip != null else Vector2.ZERO])
	_end(world)
	return true

# F7 goes through `orders` like F3, so a focused playtest field keeps the key.
func test_strip_upright_key_skips_typing(runner) -> bool:
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
	runner.check(chip != null and chip.size == Vector2(48, 26), "PS16 F7 while typing in the note leaves the chips stacked, got %s" % [chip.size if chip != null else Vector2.ZERO])
	_strip(main).set_upright(false)
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
	main._show(main.driver.current().view)
	main.orders.selected_ids.assign([1])
	main.orders.selected_building_id = -1
	main._reshow()
	var dialog: Control = main.get_node("HUD/Playtest/MarkerDialog")
	dialog.visible = true
	main.hud.producer_pressed.emit(ids.factory, true)
	dialog.visible = false
	runner.check(main.orders.selected_ids == [1] and main.orders.selected_building_id == -1 and main.glide_seconds_left() == 0.0, "PS20 with the note holding the match a chip click changes nothing, got %s %d" % [main.orders.selected_ids, main.orders.selected_building_id])
	for other: Array in [["an enemy factory", enemy], ["an own site", site]]:
		main.hud.producer_pressed.emit(other[1], false)
		runner.check(main.orders.selected_ids == [1] and main.orders.selected_building_id == -1, "PS20 %s is never selected, got %s %d" % [other[0], main.orders.selected_ids, main.orders.selected_building_id])
	_end(world)
	return true
