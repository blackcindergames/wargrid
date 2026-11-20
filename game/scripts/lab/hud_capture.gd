extends SceneTree

const LabCapture = preload("res://scripts/lab/lab_capture.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const BaseScene = preload("res://tests/test_base_scene.gd")
const HudTests = preload("res://tests/test_hud.gd")
const OverlayTests = preload("res://tests/test_playtest_overlay.gd")
const SkirmishTests = preload("res://tests/test_skirmish_scene.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const View = preload("res://scripts/presentation/world_view.gd")

const SETTLE_FRAMES: int = 3
const FRAME_CAP: int = 6000
const LONGEST: String = "Footprint covers ground unit or destination"
const ROWS: Array = [["china_tank", 20], ["china_light_vehicle", 20], ["china_rifle_infantry", 10], ["china_rocket_infantry", 34], ["china_collector", 12]]

var _hud := HudTests.new()
var _overlays := OverlayTests.new()
var _skirmish := SkirmishTests.new()
var _base := BaseScene.new()
var _main: Node
var _port: SubViewport
var _saved: String = ""
var _begun: bool = false
var _frames: int = 0
var _failed: bool = false
var _problems: PackedStringArray = []

func shots() -> Array[Dictionary]:
	var one: Array = [BaseScene.HUD_SIZES[0]]
	return [
		_shot("slab", _slab_armed.bind(4800, "china_defence"), "AFTER PURCHASE"),
		_shot("slab-attack-armed", _slab_attack, ""),
		_shot("slab-army", _slab_army, ""),
		_shot("slab-builder", _slab_pick.bind("builder", 50000), "$1200"),
		_shot("slab-poor", _slab_pick.bind("builder", 500), "$500"),
		_shot("queue", _queue.bind(false), "QUEUE"),
		_shot("queue-open", _queue.bind(true), "QUEUE"),
		_shot("unload", _unload, ""),
		_shot("offline", _offline, "OFFLINE · LOW POWER"),
		_shot("sites", _panel.bind("", "paused", ""), "PAUSED · NO BUILDER"),
		_shot("sites-enemy", _panel.bind("", "", "enemy_site"), "UNDER CONSTRUCTION"),
		_shot("sites-factory", _panel.bind("", "factory", ""), "Right-click ground: rally point"),
		_shot("pile", _panel.bind("", "", "pile"), "CREDITS LEFT"),
		_shot("pile-empty", _panel.bind("", "", "empty"), "Empty"),
		_shot("core-one", _panel.bind("tank", "", ""), "Medium Tank"),
		_shot("core-plant", _panel.bind("", "plant", ""), "POWER"),
		_shot("core-enemy", _core_enemy, "Battle Tank"),
		_shot("core-site", _panel.bind("", "site", ""), "UNDER CONSTRUCTION"),
		_shot("rows-footer", _rows_held, "Click a kind"),
		_shot("rows-one", _rows.bind([["china_tank", 12]]), "12 selected · 1 kind"),
		_shot("rows-six", _rows.bind(_six_kinds()), "6 kinds", one),
		_shot("collector-header", _rows.bind([["china_tank", 8], ["china_collector", 1]]), "1 idle collector"),
		_shot("collector-depot", _collector.bind("usa"), "WAITING AT SUPPLY DEPOT"),
		_shot("collector-cache", _collector.bind("frc"), "WAITING AT SUPPLY CACHE"),
		_shot("collector-no-depot", _no_depot, "NO SUPPLY DEPOT"),
		_shot("refusal", _refusal, "Insufficient credits"),
		_shot("refusal-longest", _refusal_longest, LONGEST),
		_shot("strip", _strip.bind(8), "4800"),
		_shot("low-power", _strip.bind(12), "LOW POWER · DEFENCES OFF"),
		_shot("forecast-short", _slab_armed.bind(500, "china_defence"), HudTests.MINUS + "700"),
		_shot("forecast-plant", _slab_armed.bind(4800, "usa_power_plant"), "8 / 15"),
		_shot("forecast-frc", _slab_armed.bind(4800, "frc_barracks", "frc"), "AFTER PURCHASE"),
		_shot("chips-menu-free", _menu_chip.bind(false), "Esc"),
		_shot("chips-menu-held", _menu_chip.bind(true), ""),
		_shot("chips", _chips_worst.bind(false), "PLAYTEST"),
		_shot("chips-f3", _chips_f3, "PLAYTEST"),
		_shot("chips-f3-rule", _chips_worst.bind(true), "PLAYTEST"),
		_shot("chips-checklist", _chips_checklist, "1 / "),
		_shot("chips-form", _chips_form, "PLAYTEST"),
		_shot("chips-off", _chips_off, "Menu"),
		_shot("notice", _notice, "Waiting for player"),
		_shot("freeze", _freeze.bind(false), "Match stopped"),
		_shot("freeze-copied", _freeze.bind(true), "Match stopped"),
	]

static func _shot(stem: String, setup: Callable, expect: String, sizes: Array = BaseScene.HUD_SIZES) -> Dictionary:
	return {stem = stem, setup = setup, expect = expect, sizes = sizes}

static func _six_kinds() -> Array:
	return HudTests.ROSTERS.china.map(func(kind: String) -> Array: return [kind, 120 if kind.ends_with("rifle_infantry") else 2])

# The test helpers report through `runner.check`; a false one means the state was not reached.
func check(condition: bool, message: String) -> void:
	if not condition: _problems.append(message)

func _watch(cap: int) -> void:
	_frames += 1
	if _frames > cap: _fail("frame cap %d reached" % cap)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --path game --script res://scripts/lab/hud_capture.gd -- OUTPUT_DIR")
		quit(1)
		return
	process_frame.connect(_watch.bind(FRAME_CAP))
	_run(args[0])

func _run(directory: String) -> void:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("cannot create %s" % directory)
		return
	await process_frame
	var count: int = 0
	for shot: Dictionary in shots():
		for pair: Array in shot.sizes:
			var window: Vector2i = pair[0]
			var stem: String = "%s-%dx%d" % [shot.stem, window.x, window.y]
			# Scratch settings and a fresh session per shot: the owner's files stay untouched, and a ticked item never leaks into the next picture.
			_saved = _overlays._begin(true, HudTests._longest_card().id)
			_begun = true
			_port = BaseScene.sized_port(self, window, pair[1])
			_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			await (shot.setup as Callable).call()
			# The screen's `_process` keeps the chip current; it stays off here.
			_main._show_esc_chip()
			await _settle()
			if not shot.expect.is_empty() and not BaseScene.hud_text(_main).contains(shot.expect): check(false, "no '%s' on the HUD" % shot.expect)
			if not _problems.is_empty():
				_fail("%s: %s" % [stem, "; ".join(_problems)])
				return
			var image: Image = _port.get_texture().get_image()
			if LabCapture._blank(image):
				_fail("%s is blank" % stem)
				return
			var path: String = directory.path_join(stem + ".png")
			if image.save_png(path) != OK:
				_fail("cannot save %s" % path)
				return
			print("saved ", path)
			count += 1
			_port.free()
			_overlays._end(_saved)
			_begun = false
	print("CAPTURE DONE %d shots" % count)
	quit(0)

func _settle() -> void:
	for i in SETTLE_FRAMES: await process_frame

func _scene() -> void:
	_main = await _overlays._scene(self, Skirmish, _port)
	_overlays._camera(_main)
	var overlay: Node = _main.get_node("HUD/Playtest")
	if overlay.get_node("Checklist").visible: overlay.toggle_checklist()

func _adopt(sim: RefCounted) -> void:
	_main.driver.adopt(sim)
	_main._reset_camera()
	_main._refresh()

func _economy(credits: int, used: int, available: int, faction: String = "") -> void:
	var row: Dictionary = HudModel.player(_main.driver.current().view, 1)
	row.merge({"credits": credits, "power_demand": used, "power_supply": available}, true)
	if not faction.is_empty(): row.faction = faction
	_main._refresh()

func _slab_world(credits: int, loaded: bool = false) -> Dictionary:
	await _scene()
	var ids: Dictionary = _hud._slab_world(self, _main, loaded, credits)
	_main._reset_camera()
	return ids

func _slab_pick(key: String, credits: int) -> void:
	var ids: Dictionary = await _slab_world(credits)
	HudTests._select(_main, ids[key] if ids[key] is Array else [ids[key]])

func _slab_armed(credits: int, kind: String, faction: String = "") -> void:
	var ids: Dictionary = await _slab_world(credits)
	_economy(credits, 0 if faction == "frc" else 8, 0 if faction == "frc" else 10, faction)
	var builder: int = {"china": ids.builder, "usa": ids.usa_builder, "frc": ids.frc_builder}[kind.get_slice("_", 0)]
	HudTests._select(_main, [builder])
	var index: int = _main.hud.menu_kinds.find(kind)
	check(index != -1, "%s not in the builder's menu %s" % [kind, _main.hud.menu_kinds])
	if index != -1: _main.get_node("HUD/Economy/BuildMenu").get_child(index).pressed.emit()

func _slab_attack() -> void:
	await _slab_pick("tanks", 50000)
	_base.key(_main, KEY_A)
	check(_main.orders._attack_move_mode, "attack move armed")

func _slab_army() -> void:
	await _slab_pick("tanks", 50000)
	check(HudTests._shown(_main, "Orders/AttackMove") and not HudTests._shown(_main, "BuildMenu"), "the order row alone, no build menu")

func _queue(open: bool) -> void:
	var ids: Dictionary = await _slab_world(50000)
	HudTests._select(_main, [], ids.factory)
	HudTests._nine(_main, ids.factory)
	if open: _main.get_node("HUD/Economy/QueueMore").pressed.emit()
	await _settle()
	var row: Button = _main.get_node("HUD/Economy/Queue").get_child(2)
	HudTests._move(_port, row.get_global_rect().get_center())
	await _settle()
	check(row.is_hovered(), "the pointer is on a waiting queue row")

func _unload() -> void:
	var ids: Dictionary = await _slab_world(50000, true)
	HudTests._select(_main, [ids.car])
	var unload: Button = _main.get_node("HUD/Economy/Orders/Unload")
	check(unload.is_visible_in_tree() and unload.text.begins_with("Unload ("), "Unload shown for the loaded Scout Car")

func _offline() -> void:
	await _scene()
	var sim: RefCounted = Fixture.make_world(50000)
	sim.add_player(2, 1000)
	var tower: int = Fixture.add_completed(sim, 1, "china_defence", Vector2i(8, 10))
	_adopt(sim)
	HudTests._pick(_main, [], tower, -1)

func _panel_ids() -> Dictionary:
	await _scene()
	var ids: Dictionary = _hud._panel_world(_main)
	_main._reset_camera()
	return ids

func _panel(unit: String, building: String, inspected: String) -> void:
	var ids: Dictionary = await _panel_ids()
	HudTests._pick(_main, [ids[unit]] if not unit.is_empty() else [], ids.get(building, -1), ids.get(inspected, -1))

func _core_enemy() -> void:
	await _panel("", "", "enemy")
	check(_main.hud.panel_edge() == View.owner_color(2), "the enemy's edge colour")

func _rows(groups: Array) -> Dictionary:
	await _scene()
	var ids: Dictionary = HudTests._rows_world(_main, groups)
	_main._reset_camera()
	return ids

# Militia die under the pointer and hold at 0; the pointer then moves on to the Rotary Gun Tank row.
func _rows_held() -> void:
	var ids: Dictionary = await _rows(ROWS)
	await _settle()
	HudTests._move(_port, HudTests._row(_main, "china_rifle_infantry").get_global_rect().get_center())
	await _settle()
	for id: int in ids.china_rifle_infantry: _main.driver.pump.live().remove_object(id)
	BaseScene.publish(_main)
	await _settle()
	HudTests._move(_port, HudTests._row(_main, "china_tank").get_global_rect().get_center())
	await _settle()
	BaseScene.publish(_main)
	var held: Button = HudTests._row(_main, "china_rifle_infantry")
	check(held != null and (held.get_node("Count") as Label).text == "0", "the Militia row holds at 0")

func _collector(faction: String) -> void:
	var ids: Dictionary = await _panel_ids()
	HudTests._waiting_collector(_main, ids.collector, faction)

func _no_depot() -> void:
	await _scene()
	var sim: RefCounted = Fixture.make_world(50000)
	sim.add_supply_source(Vector2i(24, 4), 200)
	var truck: int = sim.spawn(1, Vector2(12.5, 8.5), "usa_collector")
	_adopt(sim)
	HudTests._waiting_collector(_main, truck, "usa")
	var units: RefCounted = _main.shown_state.units
	if not units.phases.has("idle"): units.phases.append("idle")
	units.phase[units.index_of(truck)] = units.phases.find("idle")
	_main._show(_main.shown_state)

func _refusal() -> void:
	var ids: Dictionary = await _slab_world(500)
	HudTests._select(_main, [], ids.factory)
	_main.refuse("Insufficient credits", false)

func _refusal_longest() -> void:
	await _rows(HudTests.ROSTERS.china.map(func(kind: String) -> Array: return [kind, 1]))
	_main.refuse(LONGEST, false)

func _strip(used: int) -> void:
	await _scene()
	_economy(4800, used, 10)

func _menu_chip(held: bool) -> void:
	await _scene()
	if held: BaseScene.select_own_unit(_main)
	_main._show_esc_chip()
	var esc: Control = _main.get_node("HUD/MenuChip").find_child("EscChip", true, false)
	check(esc.modulate.a == (0.0 if held else 1.0), "the Esc chip %s" % ("faded" if held else "shown"))

func _f3() -> void:
	_main.get_node("HUD/PerfOverlay").toggle()

func _chips_worst(f3: bool) -> void:
	var ids: Dictionary = await _slab_world(50000)
	HudTests._select(_main, [], ids.factory)
	HudTests._nine(_main, ids.factory)
	var overlay: Node = _main.get_node("HUD/Playtest")
	overlay.toggle_checklist()
	overlay.open_marker()
	if f3: _f3()

func _chips_f3() -> void:
	await _scene()
	_f3()

func _chips_checklist() -> void:
	var ids: Dictionary = await _slab_world(50000)
	HudTests._select(_main, [], ids.plant)
	var list: Node = _main.get_node("HUD/Playtest/Checklist")
	_main.get_node("HUD/Playtest").toggle_checklist()
	(list.find_children("*", "CheckBox", true, false)[0] as CheckBox).button_pressed = true
	_f3()

func _chips_form() -> void:
	await _scene()
	var overlay: Node = _main.get_node("HUD/Playtest")
	overlay.toggle_checklist()
	overlay.open_marker()
	_f3()

func _chips_off() -> void:
	await _scene()
	_main.get_node("HUD/Playtest").set_active(false)
	_f3()

# An online match still waiting has no units to select, so the notice goes on an offline slab as test_slab_rect does.
func _notice() -> void:
	await _slab_pick("tanks", 50000)
	_main.hud._show_notice("Waiting for player 2")

func _freeze(copied: bool) -> void:
	await _scene()
	var world: Dictionary = _skirmish._frozen_arena(_main)
	HudTests._select(_main, [world.ids.builder])
	world.pump.fail_next = true
	BaseScene.tick(_main)
	await _settle()
	if not copied: return
	_main.get_node(SkirmishTests.COPY).pressed.emit()
	check(_main.get_node(SkirmishTests.COPY).text == "Report copied" and world.copied.size() == 1, "Copy report copied once into the stub")

func _fail(message: String) -> void:
	if _failed: return
	_failed = true
	printerr("hud_capture: ", message)
	if is_instance_valid(_port): _port.free()
	if _begun: _overlays._end(_saved)
	quit(1)
