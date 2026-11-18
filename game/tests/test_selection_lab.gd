@warning_ignore_start("untyped_declaration")
extends RefCounted

const LabLook = preload("res://scripts/lab/lab_look.gd")
const LabView = preload("res://scripts/lab/lab_view.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const PANEL_SLOTS: Array[Rect2] = [Rect2(0, 664, 408, 136), Rect2(416, 664, 408, 136)]

const ROLES: Array[StringName] = [&"bg", &"btn", &"panel2", &"quiet", &"well", &"line", &"text", &"muted", &"hint", &"sel", &"amber", &"you", &"enemy", &"ally"]
const A_HEX := {"bg": "121c24", "btn": "223241", "panel2": "26384a", "quiet": "16212a", "well": "0c141a", "line": "2e3f4b", "text": "eef3f5", "muted": "93a5b0", "hint": "93a5b0", "sel": "60e5ed", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const B_HEX := {"bg": "172731", "btn": "223640", "panel2": "2b4453", "quiet": "1a2c37", "well": "121f28", "line": "40535d", "text": "f1f5f7", "muted": "b7c4cc", "hint": "96a5ae", "sel": "67deeb", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const SLOT_ONE_HEX: Array[String] = ["628ffa", "d6120c", "4ad49b", "f8e425", "0e92a7", "7242fe", "ec8600", "f79cef"]

func cases() -> Array[Callable]:
	return [test_token_sets, test_palette_a, test_bar_rules, test_number_font, test_palette_a_view, test_frozen_army, test_view_copy, test_fixture_on_screen]

func test_token_sets(runner) -> bool:
	var a: Dictionary = LabLook.tokens(&"a")
	var b: Dictionary = LabLook.tokens(&"b")
	runner.check(a.size() == 14 and b.size() == 14, "LB1 each token set has 14 roles")
	for role in ROLES:
		runner.check(a[role] == Color(A_HEX[String(role)]), "LB1 set A role %s" % role)
		runner.check(b[role] == Color(B_HEX[String(role)]), "LB1 set B role %s" % role)
	runner.check(LabLook.derived_b(&"panel2").to_html(false) == "2b4453", "LB1 derived panel2")
	runner.check(LabLook.derived_b(&"quiet").to_html(false) == "1a2c37", "LB1 derived quiet")
	runner.check(LabLook.derived_b(&"well").to_html(false) == "121f28", "LB1 derived well")
	for tokens: Dictionary in [a, b]:
		var order: Array[float] = [tokens.well.ok_hsl_l, tokens.bg.ok_hsl_l, tokens.quiet.ok_hsl_l, tokens.panel2.ok_hsl_l]
		runner.check(order[0] < order[1] and order[1] < order[2] and order[2] < order[3], "LB1 lightness order well < bg < quiet < panel2")
	for role in [&"you", &"enemy", &"ally"]:
		runner.check(a[role] == b[role], "LB1 %s equal across sets" % role)
	runner.check(LabLook.SLOT_MAP.size() == 12, "LB1 slot map has 12 rows")
	return true

func test_palette_a(runner) -> bool:
	var one: PackedColorArray = LabLook.owner_colors_a(1)
	runner.check(one[0] == Color("628ffa") and one[6] == Color("628ffa"), "LB2 owner 1 slots 0 and 6 are palette A blue")
	runner.check(one[1] == Color("628ffa").darkened(0.25), "LB2 owner 1 slot 1 is darkened 0.25")
	runner.check(one[2] == Color("1c2e39") and one[3] == Color("0e1b23"), "LB2 sides are the round 6 sides")
	var plain: PackedColorArray = Palette.owner_colors(1)
	for slot in [4, 5, 7]:
		runner.check(one[slot] == plain[slot], "LB2 slot %d comes from Palette" % slot)
	for owner in range(1, 9):
		runner.check(LabLook.owner_colors_a(owner)[0] == Color(SLOT_ONE_HEX[owner - 1]), "LB2 owner %d slot 0" % owner)
	runner.check(LabLook.owner_colors_a(0) == Palette.owner_colors(0), "LB2 owner 0 is Palette's")
	runner.check(LabLook.owner_colors_a(99) == Palette.owner_colors(99), "LB2 unknown owner is Palette's")
	return true

func test_bar_rules(runner) -> bool:
	var rules := LabLook.RULES
	runner.check(rules.size() == 3, "LB3 three rules")
	runner.check(LabLook.bar_shown(0, false, false, 5, 10), "LB3 damaged or hovered shows a damaged unselected unit")
	runner.check(LabLook.bar_shown(0, false, true, 10, 10), "LB3 damaged or hovered shows a hovered healthy unit")
	runner.check(not LabLook.bar_shown(0, true, false, 10, 10), "LB3 damaged or hovered hides a selected healthy unit")
	runner.check(LabLook.bar_shown(1, true, false, 10, 10), "LB3 selected or hovered shows a selected healthy unit")
	runner.check(LabLook.bar_shown(1, false, true, 10, 10), "LB3 selected or hovered shows a hovered healthy unit")
	runner.check(not LabLook.bar_shown(1, false, false, 5, 10), "LB3 selected or hovered hides a damaged unselected unit")
	for selected in [false, true]:
		for hovered in [false, true]:
			for damaged in [false, true]:
				var hp: int = 5 if damaged else 10
				runner.check(LabLook.bar_shown(2, selected, hovered, hp, 10) == View.shows_health(selected, hp, 10, hovered), "LB3 selected, damaged or hovered equals production (sel %s hov %s dmg %s)" % [selected, hovered, damaged])
	return true

func test_number_font(runner) -> bool:
	var plain: Font = load("res://fonts/PublicSans-Bold.ttf")
	for weight in [600, 700]:
		for size in [13, 14]:
			var font: Font = LabLook.font(weight)
			var ones: float = font.get_string_size("1111111", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var eights: float = font.get_string_size("8888888", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			runner.check(ones == eights, "LB4 weight %d size %d digits share one width" % [weight, size])
	var plain_ones: float = plain.get_string_size("1111111", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var plain_eights: float = plain.get_string_size("8888888", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	runner.check(plain_ones != plain_eights, "LB4 the plain font has proportional digits, so tnum does the work")
	var first: FontVariation = LabLook.font(700)
	var second: FontVariation = LabLook.font(700)
	runner.check(first == second, "LB4 fonts are cached per weight and spacing")
	return true

func test_palette_a_view(runner) -> bool:
	var army = LabArmy.new()
	var view = LabView.new()
	runner.root.add_child(view)
	view.set_state(LabArmy.view_copy(army.state), [] as Array[int])
	await runner.process_frame
	view.set_palette_a(true)
	runner.check(view._batch.colors.has(Color("628ffa")), "LB5 palette A on draws A's owner 1 blue")
	runner.check(not view._batch.colors.has(Palette.OWNER_BASE[0]), "LB5 palette A on drops today's owner 1 blue")
	view.set_palette_a(false)
	runner.check(not view._batch.colors.has(Color("628ffa")), "LB5 palette A off drops A's blue")
	runner.check(view._batch.colors.has(Palette.OWNER_BASE[0]), "LB5 palette A off draws today's blue again")
	var plain = View.new()
	runner.root.add_child(plain)
	plain.set_state(LabArmy.view_copy(army.state), [] as Array[int])
	await runner.process_frame
	runner.check(plain._batch.colors.has(Palette.OWNER_BASE[0]) and not plain._batch.colors.has(Color("628ffa")), "LB5 a plain WorldView still draws today's blue")
	view.free()
	plain.free()
	return true

func _fraction(row: Dictionary) -> float:
	return float(row.hp) / float(row.max_hp)

func _row(state: Dictionary, id: int) -> Dictionary:
	for row: Dictionary in state.entities:
		if row.id == id: return row
	return {}

func test_frozen_army(runner) -> bool:
	var army = LabArmy.new()
	var rows: Array = army.state.entities
	runner.check(rows.size() == 120, "LB6 120 units")
	var owners := {1: 0, 2: 0, 3: 0}
	var damaged := {1: 0, 2: 0}
	var light := {1: 0, 2: 0}
	for row: Dictionary in rows:
		owners[row.owner] += 1
		var side: int = 2 if row.owner == 2 else 1
		var f: float = _fraction(row)
		if row.hp < row.max_hp: damaged[side] += 1
		if row.hp < row.max_hp and f >= 0.9:
			light[side] += 1
			runner.check(f <= 0.99, "LB6 light damage stays at 99 % or less")
		if row.owner == 2 and f < 0.9: runner.check(f < 0.33, "LB6 enemy %d below 90 %% is below 33 %%" % row.id)
		if row.owner != 2 and f < 0.9: runner.check(f >= 0.33, "LB6 own or ally %d below 90 %% is at 33 %% or more" % row.id)
	runner.check(owners[1] == 48 and owners[3] == 12 and owners[2] == 60, "LB6 owners 48 / 12 / 60")
	runner.check(damaged[1] == 24 and damaged[2] == 24, "LB6 24 damaged per side, 48 in all")
	runner.check(light[1] == 8 and light[2] == 8, "LB6 8 per side at 90-99 %, 16 in all")
	runner.check(army.selected.size() == 10, "LB6 ten selected")
	var full: int = 0
	for id: int in army.selected:
		var row: Dictionary = _row(army.state, id)
		runner.check(row.get("owner") == 1, "LB6 selected %d is owner 1" % id)
		if row.get("hp") == row.get("max_hp"): full += 1
	runner.check(full == 5, "LB6 five selected at full health, five damaged")
	var hovered: Dictionary = _row(army.state, army.hovered)
	runner.check(hovered.get("owner") == 2 and hovered.get("hp") == hovered.get("max_hp"), "LB6 hovered is a healthy enemy")
	var plants: Array = army.state.buildings.filter(func(b: Dictionary) -> bool: return b.owner == 1 and b.kind == "usa_power_plant" and b.completed)
	runner.check(plants.size() == 1 and plants[0].id == army.building_id, "LB6 one completed owner 1 power plant")
	runner.check(LabArmy.new().state == army.state, "LB6 two fixtures give equal state")
	return true

func test_view_copy(runner) -> bool:
	var army = LabArmy.new()
	var copy: Dictionary = LabArmy.view_copy(army.state)
	runner.check(copy.entities.size() == 120 and copy.entities.all(func(row: Dictionary) -> bool: return row.hp == row.max_hp), "LB7 every copied unit at full health")
	runner.check(copy.buildings.all(func(row: Dictionary) -> bool: return row.hp == row.max_hp), "LB7 every copied building at full health")
	runner.check(army.state.entities.filter(func(row: Dictionary) -> bool: return row.hp < row.max_hp).size() == 48, "LB7 the input keeps its 48 damaged rows")
	return true

func _screen(world: Vector2) -> Vector2:
	return Iso.world_to_plane(world) - Iso.world_to_plane(LabArmy.CAMERA_FOCUS) + Vector2(640, 400)

func _on_map(world: Vector2) -> bool:
	return world.x >= 0 and world.y >= 0 and world.x < LabArmy.MAP_SIZE.x and world.y < LabArmy.MAP_SIZE.y

func test_fixture_on_screen(runner) -> bool:
	var army = LabArmy.new()
	for row: Dictionary in army.state.entities:
		runner.check(_on_map(Vector2(row.position[0], row.position[1])), "LB8 unit %d inside the map" % row.id)
	var marked: Array[int] = army.selected.duplicate()
	marked.append(army.hovered)
	for id: int in marked:
		var row: Dictionary = _row(army.state, id)
		var at: Vector2 = _screen(Vector2(row.position[0], row.position[1]))
		runner.check(Rect2(0, 0, 1280, 800).has_point(at), "LB8 marked %d on screen" % id)
		for slot: Rect2 in PANEL_SLOTS:
			runner.check(not slot.has_point(at), "LB8 marked %d outside panel %s" % [id, slot])
	var panel: Rect2 = PANEL_SLOTS[0]
	var edge_under_panel: bool = false
	for i in 241:
		if panel.has_point(_screen(Vector2(i / 10.0, 24.0))): edge_under_panel = true
	runner.check(edge_under_panel, "LB8 the south-west map edge passes under the panel")
	var canvas_under_panel: bool = false
	for x in range(0, 408, 8):
		for y in range(664, 800, 8):
			var plane: Vector2 = Vector2(x, y) - Vector2(640, 400) + Iso.world_to_plane(LabArmy.CAMERA_FOCUS)
			if not _on_map(Iso.plane_to_world(plane)): canvas_under_panel = true
	runner.check(canvas_under_panel, "LB8 the panel also covers canvas off the map")
	return true
