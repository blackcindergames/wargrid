@warning_ignore_start("untyped_declaration")
extends RefCounted

const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")

func cases() -> Array[Callable]:
	return [test_no_chip_on_two_actions, test_slot_same_role_all_factions, test_lone_builder_card, test_modified_keys_press_nothing, test_prune_closes_the_sub_grid, test_production_cells_by_role, test_q_nothing_selected_refuses, test_grid_keys_with_attack_move_armed, test_card_keys_in_one_frame, test_produce_key_as_the_producer_dies, test_unarmed_units_stop]

func _world(runner) -> Array:
	var main = await SkirmishTests.new()._setup(runner)
	var ids: Dictionary = HudTests.new()._slab_world(runner, main, true)
	return [main, ids]

func _key(main, code: Key, ctrl: bool = false, meta: bool = false, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	event.alt_pressed = alt
	main._unhandled_input(event)

static func _types(main) -> Array:
	return main.driver.queued().map(func(command: Dictionary) -> String: return command.type)

static func _errors(main) -> int:
	return main._sound.last_requests().filter(func(request: Dictionary) -> bool: return request.cue == "error").size()

static func _keys(cells: Array) -> Array:
	return cells.map(func(cell: Array) -> Key: return cell[0])

static func _unique(keys: Array) -> bool:
	for key: Key in keys:
		if key == KEY_NONE or keys.count(key) > 1: return false
	return true

func test_no_chip_on_two_actions(runner) -> bool:
	runner.check(_unique([HudModel.ORDER_KEYS.attack_move, HudModel.ORDER_KEYS.stop, HudModel.ORDER_KEYS.unload]), "CK1 a unit card's Attack Move, Stop and Unload keys differ")
	for faction: String in Registry.Factions.FACTIONS:
		var row: Dictionary = Registry.faction(faction)
		var builds: Array = Registry.kind(row.start_unit).builds
		var cards: Dictionary = {"builds": _keys(HudModel.kind_cells(builds)) + [HudModel.BACK_KEY]}
		for kind: String in builds + [row.start_building]:
			var produces: Array = Registry.kind(kind).get("produces", [])
			var keys: Array = _keys(HudModel.kind_cells(produces))
			if not Registry.kind(kind).get("contains", {}).is_empty(): keys.append(HudModel.ORDER_KEYS.unload)
			if not keys.is_empty(): cards[kind] = keys
		for card: String in cards: runner.check(_unique(cards[card]), "CK1 %s %s: every shown key has one action, got %s" % [faction, card, cards[card]])
	return true

func test_slot_same_role_all_factions(runner) -> bool:
	for faction: String in Registry.Factions.FACTIONS:
		var row: Dictionary = Registry.faction(faction)
		var kinds: Array = Registry.kind(row.start_unit).builds.duplicate()
		for building: String in kinds + [row.start_building]: kinds.append_array(Registry.kind(building).get("produces", []))
		for kind: String in kinds:
			var role: String = HudModel.role(kind)
			runner.check(HudModel.CELL_KEYS.has(role) and kind == "%s_%s" % [faction, role], "CK2 %s holds role '%s' with a cell, named after it" % [kind, role])
	var frc: Array = _keys(HudModel.kind_cells(Registry.kind("frc_builder").builds))
	runner.check(not frc.has(KEY_Q) and frc.has(KEY_W), "CK2 FRC's build Q stays empty, so Q means one role in every faction (3-13), got %s" % [frc])
	var pinned: Array = _keys(HudModel.kind_cells(["usa_power_plant", "usa_barracks", "usa_factory", "usa_builder", "china_collector", "usa_tank", "china_tank"]))
	runner.check(pinned == [KEY_Q, KEY_E, KEY_R, KEY_Q, KEY_Q, KEY_W, KEY_W], "CK2 Power Plant Q, Barracks E, Factory R, builder and collector Q, tanks W, got %s" % [pinned])
	return true

func test_lone_builder_card(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	HudTests._select(main, [1])
	_key(main, KEY_A)
	_key(main, KEY_S)
	runner.check(_types(main).is_empty() and not main.orders._attack_move_mode and not main.orders._sub_grid, "CK3 a lone builder's A and S do nothing, no stop sent, got %s" % [_types(main)])
	_key(main, KEY_Q)
	runner.check(main.orders._sub_grid and main.orders._placement_kind.is_empty(), "CK3 Q opens the build sub-grid")
	_key(main, KEY_S)
	runner.check(_types(main).is_empty() and main.orders._sub_grid and main.orders._placement_kind.is_empty(), "CK3 the sub-grid's S does nothing, got %s" % [_types(main)])
	_key(main, KEY_A)
	runner.check(main.orders._placement_kind == "usa_defence" and not main.orders._attack_move_mode, "CK3 the sub-grid's A places the defence, got '%s'" % main.orders._placement_kind)
	_key(main, KEY_W)
	runner.check(main.orders._placement_kind == "usa_supply_center", "CK3 another sub-grid cell re-arms, got '%s'" % main.orders._placement_kind)
	_key(main, HudModel.BACK_KEY)
	runner.check(main.orders._placement_kind.is_empty() and main.orders._sub_grid and main.orders.selected_ids == [1], "CK3 V cancels the placement back to the sub-grid")
	_key(main, HudModel.BACK_KEY)
	runner.check(not main.orders._sub_grid and main.orders.selected_ids == [1] and _types(main).is_empty(), "CK3 V again backs out to the builder's card")
	HudTests._select(main, [1])
	_key(main, KEY_Q)
	_key(main, KEY_Q)
	main.orders._clear_placement()
	runner.check(main.orders._sub_grid, "CK3 the sub-grid shows again after a placement ends (3-28)")
	HudTests._select(main, [1, world[1].builder])
	_key(main, KEY_Q)
	runner.check(not main.orders._sub_grid and main.orders._placement_kind.is_empty() and main.hud.refusal == "Choose one builder", "CK3 two builders: Q refuses with today's line until T7, got '%s'" % main.hud.refusal)
	main.free()
	return true

func test_modified_keys_press_nothing(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	HudTests._select(main, world[1].tanks)
	for mods: Array in [[true, false, false], [false, true, false], [false, false, true]]:
		for code: Key in [KEY_A, KEY_S]: _key(main, code, mods[0], mods[1], mods[2])
	runner.check(_types(main).is_empty() and not main.orders._attack_move_mode, "CK4 Ctrl, Cmd or Alt with A or S press no cell, got %s" % [_types(main)])
	HudTests._select(main, [1])
	_key(main, KEY_Q, true)
	_key(main, KEY_Q, false, true)
	runner.check(not main.orders._sub_grid, "CK4 Ctrl+Q and Cmd+Q do not open the sub-grid")
	main.free()
	return true

func test_prune_closes_the_sub_grid(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var selections: Dictionary = {"a tank": [[ids.tanks[0]], -1], "a building": [[], ids.barracks], "two builders": [[1, ids.builder], -1], "nothing": [[], -1], "another lone builder": [[ids.builder], -1]}
	for name: String in selections:
		HudTests._select(main, [1])
		_key(main, KEY_Q)
		HudTests._select(main, selections[name][0], selections[name][1])
		runner.check(main.orders._sub_grid == (name == "another lone builder"), "CK5 selecting %s: sub-grid open %s" % [name, main.orders._sub_grid])
	HudTests._select(main, [])
	HudTests._select(main, [1])
	_key(main, KEY_Q)
	runner.check(main.orders._sub_grid and main.orders._placement_kind.is_empty(), "CK5 fixture: the sub-grid open, nothing armed")
	main.driver.pump.live().remove_object(1)
	BaseScene.tick(main)
	runner.check(not main.orders._sub_grid and main.orders.selected_ids.is_empty(), "CK5 the builder removed: the sub-grid closes with the selection")
	_key(main, KEY_E)
	_key(main, HudModel.BACK_KEY)
	runner.check(_types(main).is_empty() and main.orders._placement_kind.is_empty(), "CK5 after the removal its keys press nothing, got %s" % [_types(main)])
	main.free()
	return true

func test_production_cells_by_role(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, [], ids.barracks)
	for code: Key in [KEY_Q, KEY_W, KEY_E]: _key(main, code)
	var kinds: Array = main.driver.queued().map(func(command: Dictionary) -> String: return command.unit_kind)
	runner.check(kinds == ["usa_rifle_infantry", "usa_rocket_infantry"], "CK6 barracks Q rifle, W rocket infantry, E nothing, got %s" % [kinds])
	HudTests._select(main, [], ids.factory)
	for code: Key in [KEY_Q, KEY_W]: _key(main, code)
	kinds = main.driver.queued().slice(2).map(func(command: Dictionary) -> String: return command.unit_kind)
	runner.check(kinds == ["china_light_vehicle", "china_tank"], "CK6 a factory listing its tank first still keys by role, got %s" % [kinds])
	HudTests._select(main, [], ids.hub)
	_key(main, KEY_F)
	runner.check(_types(main).count("unload") == 1 and main.driver.queued().back().target_id == ids.hub, "CK6 the loaded Tunnel Hub's F unloads")
	HudTests._select(main, [ids.infantry])
	_key(main, KEY_F)
	runner.check(_types(main).count("unload") == 1 and main.hud.refusal.is_empty(), "CK6 F without a container is not on the card: nothing, no line, got '%s'" % main.hud.refusal)
	runner.check(HudModel.card(main.shown_state, {"ids": [] as Array[int], "building_id": ids.barracks}, 2).is_empty(), "CK6 another seat's barracks shows no cells")
	main.free()
	var empty = await SkirmishTests.new()._setup(runner)
	var bare: Dictionary = HudTests.new()._slab_world(runner, empty, false)
	for chosen: Array in [[[bare.car], -1], [[], bare.hub]]:
		HudTests._select(empty, chosen[0], chosen[1])
		_key(empty, KEY_F)
	runner.check(_types(empty).is_empty() and empty.hud.refusal.is_empty(), "CK6 an empty Scout Car or Tunnel Hub has no Unload cell (hidden while empty): F sends nothing, got %s" % [_types(empty)])
	empty.free()
	return true

func test_q_nothing_selected_refuses(runner) -> bool:
	for faction: Array in [["usa", "Select a Bulldozer"], ["frc", "Select a Laborer"]]:
		var world: Array = await _world(runner)
		var main = world[0]
		HudModel.player(main.driver.current().view, 1).faction = faction[0]
		HudTests._select(main, [])
		_key(main, KEY_Q)
		runner.check(main.hud.refusal == faction[1] and main.orders._placement_kind.is_empty() and not main.orders._sub_grid and _types(main).is_empty(), "CK7 %s: Q with nothing selected says '%s', got '%s'" % [faction[0], faction[1], main.hud.refusal])
		BaseScene.tick(main)
		runner.check(_errors(main) == 1, "CK7 %s: the refusal beeps once, got %d" % [faction[0], _errors(main)])
		main.free()
	var world: Array = await _world(runner)
	var main = world[0]
	for inspected: String in ["enemy", "pile"]:
		HudTests._select(main, [], -1, world[1][inspected])
		_key(main, KEY_Q)
		BaseScene.tick(main)
		runner.check(main.hud.refusal.is_empty() and _errors(main) == 0 and not main.orders._sub_grid, "CK7 Q with the %s inspected has no card and no refusal, got '%s'" % [inspected, main.hud.refusal])
	main.free()
	return true

func test_grid_keys_with_attack_move_armed(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, ids.tanks)
	_key(main, KEY_A)
	_key(main, KEY_A)
	runner.check(main.orders._attack_move_mode and _types(main).is_empty(), "CK8 A with attack move armed keeps it armed")
	_key(main, KEY_S)
	runner.check(not main.orders._attack_move_mode and _types(main) == ["stop"], "CK8 S stops and disarms, got %s" % [_types(main)])
	HudTests._select(main, [ids.car])
	_key(main, KEY_A)
	_key(main, KEY_F)
	runner.check(not main.orders._attack_move_mode and _types(main) == ["stop", "unload"], "CK8 F unloads and disarms, got %s" % [_types(main)])
	HudTests._select(main, [1, ids.tanks[0]])
	_key(main, KEY_A)
	main.driver.pump.live().remove_object(ids.tanks[0])
	BaseScene.tick(main)
	_key(main, KEY_Q)
	runner.check(main.orders._sub_grid and main.orders.selected_ids == [1], "CK8 fixture: the tank gone, Q opened the lone builder's sub-grid")
	var helper = BaseScene.new()
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 12.5))
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)
	runner.check(not main.orders._attack_move_mode and _types(main).count("attack_move") == 0, "CK8 Q disarms attack move: a ground click after it sends none, got %s" % [_types(main)])
	main.free()
	return true

func test_unarmed_units_stop(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, [ids.collectors[0]])
	_key(main, KEY_A)
	_key(main, KEY_S)
	runner.check(_types(main) == ["stop"] and not main.orders._attack_move_mode, "CK11 a Supply Truck's A does nothing, S sends a stop, got %s" % [_types(main)])
	HudTests._select(main, [1, ids.collectors[0]])
	_key(main, KEY_S)
	runner.check(_types(main) == ["stop", "stop"], "CK11 a builder and a truck: S stops them, got %s" % [_types(main)])
	main.free()
	return true

func test_card_keys_in_one_frame(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	var helper = BaseScene.new()
	HudTests._select(main, ids.tanks)
	_key(main, KEY_A)
	var ground: Vector2 = Iso.world_to_plane(Vector2(12.5, 12.5))
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, ground, MOUSE_BUTTON_LEFT, false)
	_key(main, KEY_S)
	runner.check(_types(main) == ["attack_move", "stop"], "CK9 S in the frame an attack-move click was sent: both, in order, got %s" % [_types(main)])
	var sim = main.driver.pump.live()
	BaseScene.tick(main)
	var modes: Array = ids.tanks.map(func(id: int) -> String: return Fixture.object(sim, id).combat.mode)
	runner.check(modes == ["guard", "guard"], "CK9 the stop sent last wins the tick, got %s" % [modes])
	HudTests._select(main, [ids.car])
	_key(main, KEY_F)
	_key(main, KEY_F)
	runner.check(_types(main).count("unload") == 2, "CK9 F twice in a frame sends both")
	BaseScene.tick(main)
	runner.check(_contained(main) == 1, "CK9 the car empties; only the hub's rider stays inside, got %d" % _contained(main))
	HudTests._select(main, [], ids.hub)
	_key(main, KEY_F)
	sim.remove_object(ids.hub)
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "Cannot unload this container" and _errors(main) == 1, "CK9 F the step the hub dies: the sim refuses with one beep, got '%s' %d" % [main.hud.refusal, _errors(main)])
	for i in 8: Fixture.send(sim, {"type": "produce", "building_id": ids.barracks, "unit_kind": "usa_rifle_infantry"})
	BaseScene.tick(main)
	HudTests._select(main, [], ids.barracks)
	var queued: int = Fixture.object(sim, ids.barracks).queue.size()
	_key(main, KEY_Q)
	_key(main, KEY_Q)
	runner.check(queued == 8 and _types(main).count("produce") == 2, "CK9 two presses at 8 queued are both sent, queue %d" % queued)
	BaseScene.tick(main)
	runner.check(Fixture.object(sim, ids.barracks).queue.size() == 9 and main.hud.refusal == "Production queue full" and _errors(main) == 1, "CK9 the second is refused with a beep, got '%s' %d" % [main.hud.refusal, _errors(main)])
	main.free()
	return true

static func _contained(main) -> int:
	var units: RefCounted = main.shown_state.units
	return range(units.size()).filter(func(i: int) -> bool: return (units.flags[i] & ViewRows.CONTAINED) != 0).size()

func test_produce_key_as_the_producer_dies(runner) -> bool:
	var world: Array = await _world(runner)
	var main = world[0]
	var ids: Dictionary = world[1]
	HudTests._select(main, [], ids.barracks)
	_key(main, KEY_Q)
	main.driver.pump.live().remove_object(ids.barracks)
	BaseScene.tick(main)
	runner.check(main.hud.refusal == "Missing producer" and _errors(main) == 1 and main.orders.selected_building_id == -1, "CK10 a produce key the step its barracks dies: refused with a beep, the selection gone, got '%s'" % main.hud.refusal)
	_key(main, KEY_Q)
	runner.check(main.hud.refusal == HudModel.select_builder(main.shown_state, 1), "CK10 the next Q finds nothing selected, got '%s'" % main.hud.refusal)
	main.free()
	return true
