@warning_ignore_start("untyped_declaration")
extends RefCounted

const LabLook = preload("res://scripts/lab/lab_look.gd")
const LabView = preload("res://scripts/lab/lab_view.gd")
const LabArmy = preload("res://scripts/lab/lab_army.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const LabMarks = preload("res://scripts/lab/lab_marks.gd")
const LabDragBox = preload("res://scripts/lab/lab_drag_box.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const AbVariants = preload("res://scripts/lab/ab_variants.gd")
const SelectionLab = preload("res://scripts/lab/selection_lab.gd")
const LabPanel = preload("res://scripts/lab/lab_panel.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const SCENE = preload("res://scenes/art_lab.tscn")
const PANEL_SLOTS: Array[Rect2] = [Rect2(0, 664, 408, 136), Rect2(416, 664, 408, 136)]

const ROLES: Array[StringName] = [&"bg", &"btn", &"panel2", &"quiet", &"well", &"line", &"text", &"muted", &"hint", &"sel", &"amber", &"you", &"enemy", &"ally"]
const A_HEX := {"bg": "121c24", "btn": "223241", "panel2": "26384a", "quiet": "16212a", "well": "0c141a", "line": "2e3f4b", "text": "eef3f5", "muted": "93a5b0", "hint": "93a5b0", "sel": "60e5ed", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const B_HEX := {"bg": "172731", "btn": "223640", "panel2": "2b4453", "quiet": "1a2c37", "well": "121f28", "line": "40535d", "text": "f1f5f7", "muted": "b7c4cc", "hint": "96a5ae", "sel": "67deeb", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const SLOT_ONE_HEX: Array[String] = ["628ffa", "d6120c", "4ad49b", "f8e425", "0e92a7", "7242fe", "ec8600", "f79cef"]

func cases() -> Array[Callable]:
	return [test_token_sets, test_palette_a, test_bar_rules, test_number_font, test_palette_a_view, test_frozen_army, test_view_copy, test_fixture_on_screen, test_mark_geometry, test_edge_faces, test_framed_bars, test_drag_rules, test_new_questions_switch, test_no_labels_in_window, test_held_boxes, test_session_only_as_main, test_round_trip_to_old_question, test_key_interactions, test_opponent_skips_ally, test_live_view_selection]

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

func test_mark_geometry(runner) -> bool:
	var infantry: PackedVector2Array = LabMarks.unit_diamond("usa_rifle_infantry", Vector2.ZERO)
	runner.check(infantry == PackedVector2Array([Vector2(0, -5), Vector2(10, 0), Vector2(0, 5), Vector2(-10, 0)]), "LB9 infantry diamond corners")
	var weapon: Dictionary = CombatDefinitions.weapon(Registry.kind("usa_tank").get("weapon", ""))
	runner.check(weapon.get("damage_type") == "armor_piercing", "LB9 usa_tank carries an armour-piercing weapon")
	runner.check(LabMarks.unit_diamond("usa_tank", Vector2.ZERO)[1].x == 19.0, "LB9 armour-piercing vehicle half width 19")
	runner.check(LabMarks.unit_diamond("usa_builder", Vector2.ZERO)[1].x == 16.0, "LB9 builder half width 16")
	var moved: PackedVector2Array = LabMarks.unit_diamond("usa_rifle_infantry", Vector2(3, 4))
	runner.check(moved[0] == Vector2(3, -1), "LB9 the diamond sits on its plane point")
	var ticks: PackedVector2Array = LabMarks.hover_ticks(infantry)
	runner.check(ticks.size() == 16, "LB9 hover ticks are 8 segments")
	var edge: float = infantry[0].distance_to(infantry[1])
	for i in 8:
		runner.check(absf(ticks[2 * i].distance_to(ticks[2 * i + 1]) - 0.32 * edge) < 1e-4, "LB9 tick %d is 0.32 of the edge" % i)
		runner.check(infantry.has(ticks[2 * i]), "LB9 tick %d starts at a corner" % i)
	return true

func test_edge_faces(runner) -> bool:
	var faces: Array[PackedVector2Array] = LabMarks.edge_faces(Vector2i(24, 24))
	runner.check(faces.size() == 2 and faces[0].size() == 4 and faces[1].size() == 4, "LB10 two 4-point faces")
	var lit: PackedVector2Array = faces[0]
	var shaded: PackedVector2Array = faces[1]
	runner.check(lit[0] == Iso.world_to_plane(Vector2(0, 24)) and lit[1] == Iso.world_to_plane(Vector2(24, 24)), "LB10 lit top edge is the south-west map edge")
	runner.check(lit[2] == lit[1] + Vector2(0, 24) and lit[3] == lit[0] + Vector2(0, 24), "LB10 lit bottom hangs 24 px lower")
	runner.check(shaded[0] == Iso.world_to_plane(Vector2(24, 0)) and shaded[1] == Iso.world_to_plane(Vector2(24, 24)), "LB10 shaded top edge is the south-east map edge")
	runner.check(shaded[2] == shaded[1] + Vector2(0, 24) and shaded[3] == shaded[0] + Vector2(0, 24), "LB10 shaded bottom hangs 24 px lower")
	return true

func _model(army, rule: int, hovered: int) -> Dictionary:
	return {state = army.state, selected = army.selected, hovered = hovered, rule = rule, preview = [] as Array[int], dragging = false, map_size = LabArmy.MAP_SIZE}

func _bar_ids(model: Dictionary) -> Array:
	var ids: Array = LabMarks.bars(model).map(func(bar: Dictionary) -> int: return bar.id)
	ids.sort()
	return ids

func test_framed_bars(runner) -> bool:
	var rects: Dictionary = LabMarks.bar_rects(Vector2(10, 10), 0.5)
	runner.check(rects.fill == Rect2(10, 10, 12, 3), "LB11 fill rect")
	runner.check(rects.track == Rect2(9, 9, 26, 5), "LB11 track rect")
	runner.check(rects.frame == Rect2(8, 8, 28, 7), "LB11 frame rect")
	var army = LabArmy.new()
	var damaged: Array = army.state.entities.filter(func(row: Dictionary) -> bool: return row.hp < row.max_hp).map(func(row: Dictionary) -> int: return row.id)
	var expected: Array = damaged + [army.hovered]
	expected.sort()
	var under_damaged: Array = _bar_ids(_model(army, 0, army.hovered))
	runner.check(under_damaged == expected, "LB11 rule 0 shows the 48 damaged units plus the hovered enemy")
	for id: int in army.selected:
		var row: Dictionary = _row(army.state, id)
		if row.hp == row.max_hp: runner.check(not under_damaged.has(id), "LB11 rule 0 hides healthy selected %d" % id)
	expected = army.selected + [army.hovered]
	expected.sort()
	runner.check(_bar_ids(_model(army, 1, army.hovered)) == expected, "LB11 rule 1 shows the 10 selected plus the hovered")
	expected = damaged + [army.hovered]
	for id: int in army.selected:
		if not expected.has(id): expected.append(id)
	expected.sort()
	runner.check(_bar_ids(_model(army, 2, army.hovered)) == expected, "LB11 rule 2 shows the union")
	var enemy: Array = LabMarks.bars(_model(army, 0, army.hovered)).filter(func(bar: Dictionary) -> bool: return _row(army.state, bar.id).get("owner") == 2)
	runner.check(not enemy.is_empty() and enemy[0].frame == Color("d6120c"), "LB11 an owner 2 frame is palette A red")
	var hovered_bar: Array = LabMarks.bars(_model(army, 1, army.hovered)).filter(func(bar: Dictionary) -> bool: return bar.id == army.hovered)
	var row: Dictionary = _row(army.state, army.hovered)
	var top_left: Vector2 = View.WorldBatch.pick_extent(row.kind).position + Iso.world_to_plane(Vector2(row.position[0], row.position[1])) + Vector2(0, -10)
	runner.check(hovered_bar.size() == 1 and hovered_bar[0].rects.fill.position == top_left and hovered_bar[0].fill == View.health_color(1.0), "LB11 a unit bar sits 10 px above its pick box, filled by health colour")
	runner.check(_bar_ids(_model(army, 0, 999999)) == _bar_ids(_model(army, 0, -1)) and _bar_ids(_model(army, 0, -1)).size() == 48, "LB11 a missing hovered id adds no bar")
	var drawn: Array = []
	for on_top in [false, true]:
		var marks = LabMarks.new()
		marks.on_top = on_top
		var model: Dictionary = _model(army, 2, army.hovered)
		model.preview = army.selected.slice(0, 3)
		marks.model = model
		runner.root.add_child(marks)
		drawn.append(marks)
	var drag = LabDragBox.new()
	drag.showing = true
	drag.box = Rect2(10, 10, 40, 30)
	runner.root.add_child(drag)
	drawn.append(drag)
	for style in 3:
		drag.style = style
		await runner.process_frame
	for node: Node in drawn: node.free()
	return true

func test_drag_rules(runner) -> bool:
	runner.check(not LabDragBox.past_threshold(Vector2.ZERO, Vector2(5.9, 0)), "LB12 5.9 px is not a drag")
	runner.check(LabDragBox.past_threshold(Vector2.ZERO, Vector2(6.0, 0)), "LB12 6 px is a drag")
	var start: Array[int] = [5]
	runner.check(LabMarks.preview_ids([3, 5, 7] as Array[int], start, true) == ([3, 7] as Array[int]), "LB12 Shift preview drops the start selection")
	runner.check(LabMarks.preview_ids([3, 5, 7] as Array[int], start, false) == ([3, 5, 7] as Array[int]), "LB12 plain preview is the picked set")
	runner.check(LabMarks.release_selection([7, 3] as Array[int], start, true) == ([3, 5, 7] as Array[int]), "LB12 Shift release adds to the start selection, sorted")
	runner.check(LabMarks.release_selection([7, 3] as Array[int], start, false) == ([3, 7] as Array[int]), "LB12 plain release is the picked set, sorted")
	runner.check(start == ([5] as Array[int]), "LB12 the start selection is left unchanged")
	var drag = LabDragBox.new()
	drag.box = Rect2(Vector2(50, 40), Vector2(10, 20) - Vector2(50, 40))
	var up_left: Rect2 = drag.box
	drag.box = Rect2(Vector2(10, 20), Vector2(50, 40) - Vector2(10, 20))
	runner.check(up_left == drag.box and drag.box == Rect2(10, 20, 40, 20), "LB12 an up-left drag gives the same box as down-right")
	runner.check(drag.mouse_filter == Control.MOUSE_FILTER_IGNORE, "LB12 the drag box ignores the mouse")
	drag.free()
	return true

func _lab(runner):
	var lab = SCENE.instantiate()
	runner.root.add_child(lab)
	await runner.process_frame
	return lab

func _go(lab, question: StringName) -> void:
	while lab.current_question() != question: lab._unhandled_input(_key(KEY_BRACKETRIGHT))

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func _press(lab, code: Key) -> void:
	lab._unhandled_input(_key(code))

func _button(at: Vector2, pressed: bool, shift: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	event.shift_pressed = shift
	return event

func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event

func _frames(runner, count: int = 2) -> void:
	for i in count: await runner.process_frame

func _marks(lab) -> Dictionary:
	return lab.selection_lab._over.model

func _panel_bg(panel) -> Color:
	return panel.find_child("Panel", true, false).get_theme_stylebox("panel").bg_color

func _screen_rect(lab, plane: Rect2) -> Rect2:
	var xform: Transform2D = lab._view.get_global_transform_with_canvas()
	return Rect2(xform * plane.position, xform * plane.end - xform * plane.position)

func _own_rows(state: Dictionary) -> Array:
	return state.entities.filter(func(row: Dictionary) -> bool: return row.owner == LabArmy.OWN)

func test_new_questions_switch(runner) -> bool:
	var lab = await _lab(runner)
	var selection = lab.selection_lab
	var counts := {&"token_set": 2, &"health_bar": 3, &"value_size": 2, &"drag_box": 3}
	runner.check(AbVariants.P2_3A.size() == 4 and AbVariants.QUESTIONS.slice(4, 8) == AbVariants.P2_3A and AbVariants.QUESTIONS[-1] == &"sand_tone", "LB13 the four new questions sit before sand_tone")
	for question: StringName in AbVariants.P2_3A:
		runner.check(lab.variants.variant_count(question) == counts[question], "LB13 %s has %d variants" % [question, counts[question]])
		_go(lab, question)
		for choice in counts[question]:
			lab.variants.set_variant(question, choice)
			lab._show(lab._current)
			await _frames(runner)
			match question:
				&"token_set":
					for slot in 2:
						var set_name: StringName = [&"a", &"b"][slot ^ choice]
						var panel = selection._panels[slot]
						runner.check(panel.visible and is_equal_approx(panel.panel_rect().position.x, LabPanel.PANEL_X[slot]), "LB13 token_set %d: panel %d shown in slot %d" % [choice, slot, slot])
						runner.check(panel.labels()[0].text == String(set_name).to_upper() and _panel_bg(panel) == LabLook.tokens(set_name).bg, "LB13 token_set %d: slot %d shows set %s with its letter" % [choice, slot, set_name])
						runner.check(panel.number_labels()[0].label_settings.font_size == 13, "LB13 token_set numbers at 13")
				&"health_bar": runner.check(_marks(lab).rule == choice, "LB13 health_bar %d: the marks follow rule %d" % [choice, choice])
				&"value_size":
					runner.check(selection._panels[0].number_labels()[0].label_settings.font_size == LabLook.VALUE_SIZES[choice], "LB13 value_size %d: numbers at %d" % [choice, LabLook.VALUE_SIZES[choice]])
					runner.check(not selection._panels[1].visible and selection._panels[0].labels()[0].text != "A" and _panel_bg(selection._panels[0]) == LabLook.tokens(&"a").bg, "LB13 value_size: one panel, set A, no letter")
				&"drag_box":
					runner.check(selection._drag.style == choice, "LB13 drag_box %d: the drag box style follows" % choice)
					_press(lab, KEY_D)
					runner.check(_marks(lab).preview.is_empty() == (choice == 2), "LB13 drag_box %d: preview ticks only off the green baseline" % choice)
					for i in 3: _press(lab, KEY_D)
	lab.free()
	return true

func test_no_labels_in_window(runner) -> bool:
	var lab = await _lab(runner)
	for question: StringName in AbVariants.P2_3A:
		_go(lab, question)
		for choice in lab.variants.variant_count(question):
			lab.variants.set_variant(question, choice)
			lab._show(lab._current)
			var text: String = lab.status_text()
			for label: String in AbVariants.LABELS[question]:
				runner.check(not text.contains(label), "LB14 %s %d hides the label '%s'" % [question, choice, label])
			runner.check(not text.contains("today") and not text.contains("Zero Hour"), "LB14 %s %d names no source" % [question, choice])
			runner.check(text.contains("variant %s" % "ABC"[choice]) and text.contains(lab.selection_lab.status_line()), "LB14 %s %d shows the letter and the lab line" % [question, choice])
	lab.free()
	return true

func test_held_boxes(runner) -> bool:
	var lab = await _lab(runner)
	var selection = lab.selection_lab
	_go(lab, &"drag_box")
	var army: Array = _own_rows(selection._army.state)
	var points: Array = army.map(func(row: Dictionary) -> Vector2: return Iso.world_to_plane(Vector2(row.position[0], row.position[1])))
	var hovered: int = selection._army.hovered
	for zoom in 3:
		var label := "zoom %s" % lab.ZOOMS[lab.zoom_index]
		_press(lab, KEY_D)
		await _frames(runner)
		var box: Rect2 = SelectionLab.HELD_BOXES[1]
		runner.check(points.filter(func(at: Vector2) -> bool: return box.has_point(at)).size() >= 5, "LB15 %s: box 1 holds at least 5 own units" % label)
		runner.check(not _marks(lab).preview.is_empty() and _marks(lab).dragging and selection._drag.showing, "LB15 %s: box 1 shows its preview" % label)
		runner.check(_marks(lab).hovered == hovered and not _marks(lab).preview.has(hovered), "LB15 %s: the hovered enemy gets no ticks while a box is held" % label)
		runner.check(selection._drag.box.is_equal_approx(_screen_rect(lab, box)) and selection._drag.box.size.is_equal_approx(box.size * lab.ZOOMS[lab.zoom_index]), "LB15 %s: the held box stays on its plane rect" % label)
		_press(lab, KEY_D)
		box = SelectionLab.HELD_BOXES[2]
		var off_map: bool = false
		for corner: Vector2 in [box.position, box.end, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y)]:
			if not _on_map(Iso.plane_to_world(corner)): off_map = true
		runner.check(off_map and selection._drag.showing, "LB15 %s: box 2 reaches off the map" % label)
		_press(lab, KEY_D)
		var preview: Array = _marks(lab).preview
		runner.check(not preview.is_empty() and selection._army.selected.all(func(id: int) -> bool: return not preview.has(id)), "LB15 %s: box 3 (Shift) previews only units not yet selected" % label)
		_press(lab, KEY_D)
		runner.check(not selection._drag.showing and not _marks(lab).dragging, "LB15 %s: D wraps to no box" % label)
		lab.cycle_zoom()
	lab.free()
	return true

func test_session_only_as_main(runner) -> bool:
	var window: Window = runner.root
	var before := [window.size, window.content_scale_size, window.unresizable]
	var lab = await _lab(runner)
	runner.check([window.size, window.content_scale_size, window.unresizable] == before, "LB16 a lab inside the runner leaves the window alone")
	for question: StringName in AbVariants.P2_3A:
		runner.check(lab.variants.variant(question) == 0, "LB16 %s starts on variant A outside a session" % question)
	runner.check(lab.current_question() == &"biome", "LB16 the lab starts on the first question")
	lab._start_session()
	# The headless display server always reports unresizable as false, so only size and scale are checked.
	runner.check(lab.current_question() == &"token_set" and window.content_scale_size == Vector2i(1280, 800), "LB16 a session starts on token_set at a 1280x800 content scale")
	window.size = before[0]
	window.content_scale_size = before[1]
	window.unresizable = before[2]
	lab.free()
	return true

func test_round_trip_to_old_question(runner) -> bool:
	var lab = await _lab(runner)
	var selection = lab.selection_lab
	var view = lab._view
	var camera_before: Vector2 = lab._camera.position
	var ground_before: Color = view._terrain._colors.ground
	_go(lab, &"token_set")
	_press(lab, KEY_G)
	await _frames(runner)
	runner.check(view.selected_unit_lines().is_empty() and _marks(lab).selected.size() == 10, "LB17 the lab holds 10 selected but the view draws no production diamond")
	runner.check(view._batch.palette_a and not view._smooth and selection._canvas.visible and not lab._ground.visible and not lab._top.visible, "LB17 token_set shows palette A, the canvas and no ab overlays")
	runner.check(view._terrain._colors.ground == LabLook.DARK_GROUND and view._visuals == null, "LB17 G gives the dark ground; the frozen army draws no fight effects")
	_press(lab, KEY_BRACKETLEFT)
	runner.check(lab.current_question() == &"owner_palette" and view._terrain._colors.ground == ground_before, "LB17 one step back the old question's ground returns")
	for i in 3: _press(lab, KEY_BRACKETLEFT)
	await _frames(runner)
	runner.check(lab.current_question() == &"biome" and lab._ground.visible and lab._top.visible, "LB17 back on biome the ab overlays and fog show")
	runner.check(not selection._canvas.visible and not selection._panels[0].visible and not selection._panels[1].visible and not selection._drag.visible and not selection._over.visible, "LB17 canvas, panels, drag box and marks are hidden")
	runner.check(not view._batch.palette_a and view._smooth and view._visuals == lab._visuals, "LB17 today's owner colours, interpolation and effects are back")
	runner.check(view._terrain._colors.ground == ground_before and lab._camera.position == camera_before, "LB17 the biome ground and the camera are back")
	runner.check(view._state.tick == lab.fight.simulation.tick() and view._state.map.size[0] == 40, "LB17 the live fight is shown")
	var quality: int = lab.quality
	_press(lab, KEY_TAB)
	_press(lab, KEY_Q)
	_press(lab, KEY_O)
	runner.check(lab.variants.is_b(&"biome") and lab.quality != quality and lab.variants.opponent_owner == 3, "LB17 AB7's Tab, Q and O behave as before")
	_go(lab, &"token_set")
	var enemy_owners: Array = _marks(lab).state.entities.map(func(row: Dictionary) -> int: return row.owner)
	runner.check(lab.variants.opponent_owner == 4 and enemy_owners.has(4) and enemy_owners.count(3) == 12, "LB17 entering with opponent owner 3 steps the enemy to owner 4, off the ally's colour")
	lab.free()
	return true

func test_key_interactions(runner) -> bool:
	var lab = await _lab(runner)
	var selection = lab.selection_lab
	var view = lab._view
	_go(lab, &"token_set")
	for code in [KEY_P, KEY_G, KEY_D]: _press(lab, code)
	var line: String = selection.status_line()
	runner.check(line == "panel many (P) | ground dark (G) | box 1 (D) | view frozen (V)", "LB18 P, G and D change the lab line: %s" % line)
	_press(lab, KEY_BRACKETRIGHT)
	runner.check(selection.status_line() == line, "LB18 ] into health_bar keeps panel, ground and box")
	for i in 3: _press(lab, KEY_D)
	selection.pointer(_button(Vector2(300, 300), true), view)
	selection.pointer(_motion(Vector2(400, 380)), view)
	runner.check(selection._drag.showing and selection._dragging, "LB18 a drag shows its box")
	_press(lab, KEY_BRACKETRIGHT)
	runner.check(not selection._dragging and not selection._drag.showing and lab.current_question() == &"value_size", "LB18 ] mid-drag ends the drag")
	_go(lab, &"health_bar")
	_press(lab, KEY_V)
	line = selection.status_line()
	runner.check(line.ends_with("view live (V)") and view._state.map.size[0] == 40 and _marks(lab).map_size == Vector2i(40, 40), "LB18 V in health_bar shows the live fight")
	for question: StringName in AbVariants.P2_3A:
		_go(lab, question)
		line = selection.status_line()
		var count: int = lab.variants.variant_count(question)
		for i in count:
			_press(lab, KEY_TAB)
			runner.check(lab.variants.variant(question) == (i + 1) % count and selection.status_line() == line, "LB18 Tab %d in %s cycles the variant and keeps P, G, D, V" % [i + 1, question])
	_go(lab, &"health_bar")
	_press(lab, KEY_V)
	_go(lab, &"value_size")
	runner.check(not selection.key(KEY_V) and selection.status_line().ends_with("view frozen (V)"), "LB18 V outside health_bar does nothing")
	var label: Label = selection._panels[0].labels()[0]
	_press(lab, KEY_Q)
	runner.check(lab.quality == GraphicsSettings.LOW and selection._panels[0].labels()[0] == label, "LB18 Q changes quality and leaves the panel")
	_press(lab, KEY_Z)
	await _frames(runner)
	var zoom: float = lab.ZOOMS[lab.zoom_index]
	runner.check(selection._over.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE * zoom), "LB18 Z scales the marks with the view")
	runner.check(selection._drag.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "LB18 Z leaves the drag box in screen pixels")
	_press(lab, KEY_SPACE)
	var tick: int = lab.fight.simulation.tick()
	await _frames(runner, 4)
	runner.check(lab.paused and lab.fight.simulation.tick() == tick and _marks(lab).state.tick == selection._army.state.tick, "LB18 Space pauses the live fight; the frozen army stays")
	_press(lab, KEY_SPACE)
	_press(lab, KEY_D)
	selection.pointer(_button(Vector2(10, 10), true), view)
	selection.pointer(_button(Vector2(10, 10), false), view)
	runner.check(_marks(lab).selected.is_empty(), "LB18 a click on empty ground clears the selection")
	_press(lab, KEY_R)
	runner.check(selection._held == 0 and _marks(lab).selected == selection._army.selected and lab.fight.simulation.tick() <= 1, "LB18 R restarts the fight, drops the box and brings the fixture selection back")
	_go(lab, &"biome")
	var before := [lab.question_index, lab.variants.variant(&"biome"), lab.quality, lab.zoom_index, lab.variants.opponent_owner, lab.paused, selection.status_line()]
	for code in [KEY_P, KEY_G, KEY_D, KEY_V]: _press(lab, code)
	runner.check([lab.question_index, lab.variants.variant(&"biome"), lab.quality, lab.zoom_index, lab.variants.opponent_owner, lab.paused, selection.status_line()] == before, "LB18 P, G, D and V do nothing in the old questions")
	_go(lab, &"drag_box")
	await _frames(runner)
	var edge_box: Rect2 = _screen_rect(lab, SelectionLab.HELD_BOXES[2])
	for corners: Array in [[edge_box.position, edge_box.end], [edge_box.end, edge_box.position]]:
		selection.pointer(_button(corners[0], true), view)
		selection.pointer(_motion(corners[1]), view)
		var preview: Array = _marks(lab).preview
		var owners: Array = _marks(lab).state.entities.filter(func(row: Dictionary) -> bool: return preview.has(row.id)).map(func(row: Dictionary) -> int: return row.owner)
		runner.check(selection._drag.showing and not preview.is_empty() and owners.all(func(owner: int) -> bool: return owner == LabArmy.OWN), "LB18 a drag across the map edge previews own units only (from %s)" % corners[0])
		selection.pointer(_button(corners[1], false), view)
		runner.check(not selection._drag.showing and _marks(lab).selected == preview, "LB18 the release selects the previewed units")
	var own: Dictionary = _own_rows(_marks(lab).state)[5]
	var own_screen: Vector2 = view.get_global_transform_with_canvas() * (Iso.world_to_plane(Vector2(own.position[0], own.position[1])) + Vector2(0, -4))
	selection.pointer(_button(own_screen, true), view)
	selection.pointer(_button(own_screen + Vector2(3, 3), false), view)
	runner.check(_marks(lab).selected == ([own.id] as Array[int]), "LB18 a click under 6 px selects the own unit under the pointer")
	lab.free()
	return true

func test_opponent_skips_ally(runner) -> bool:
	var lab = await _lab(runner)
	_go(lab, &"health_bar")
	_press(lab, KEY_O)
	runner.check(lab.variants.opponent_owner == 4, "LB19 O steps from owner 2 past the ally to 4")
	var owners := {}
	for row: Dictionary in _marks(lab).state.entities: owners[row.id] = row.owner
	var enemy: Array = LabMarks.bars(_marks(lab)).filter(func(bar: Dictionary) -> bool: return owners.get(bar.id) == 4)
	runner.check(not enemy.is_empty() and enemy[0].frame == Color("f8e425"), "LB19 an enemy bar frame is owner 4's palette A yellow")
	lab.variants.opponent_owner = 8
	_press(lab, KEY_O)
	runner.check(lab.variants.opponent_owner == 2, "LB19 O wraps from 8 to 2")
	_go(lab, &"owner_palette")
	_press(lab, KEY_TAB)
	runner.check(lab._view._batch.bright_owners, "LB19 owner_palette B turns Neon on")
	_go(lab, &"health_bar")
	_press(lab, KEY_TAB)
	runner.check(not lab._view._batch.bright_owners, "LB19 Neon stays off in the new questions, also after Tab re-applies the variants")
	for i in 2: _press(lab, KEY_BRACKETLEFT)
	runner.check(lab.current_question() == &"owner_palette" and lab._view._batch.bright_owners, "LB19 back on owner_palette Neon returns")
	lab.free()
	return true

func test_live_view_selection(runner) -> bool:
	var lab = await _lab(runner)
	var selection = lab.selection_lab
	var army = selection._army
	_go(lab, &"health_bar")
	_press(lab, KEY_V)
	var live: Dictionary = _marks(lab).state
	var own: Array = _own_rows(live).map(func(row: Dictionary) -> int: return row.id)
	var picked: Array = _marks(lab).selected
	runner.check(picked.size() == 10 and picked.all(func(id: int) -> bool: return own.has(id)), "LB20 the live view selects 10 own live units")
	runner.check(picked == SelectionLab.live_pick(live) and _marks(lab).hovered == -1, "LB20 the live view picks by the fixture rule and clears hover")
	var full: Array[int] = [1, 2, 3, 4, 5, 6]
	var rows: Array = []
	for id in range(1, 13): rows.append({id = id, owner = LabArmy.OWN, hp = 10 if full.has(id) else 5, max_hp = 10})
	rows.append({id = 13, owner = LabArmy.ENEMY, hp = 10, max_hp = 10})
	runner.check(SelectionLab.live_pick({entities = rows}) == ([1, 2, 3, 4, 5, 7, 8, 9, 10, 11] as Array[int]), "LB20 live_pick takes 5 full and 5 damaged own units")
	runner.check(SelectionLab.live_pick({entities = rows.slice(0, 4)}) == ([1, 2, 3, 4] as Array[int]), "LB20 live_pick falls back to the first own units")
	_press(lab, KEY_V)
	runner.check(_marks(lab).selected == army.selected and _marks(lab).hovered == army.hovered, "LB20 V back restores the frozen selection and hover")
	_press(lab, KEY_V)
	_press(lab, KEY_BRACKETRIGHT)
	runner.check(_marks(lab).selected == army.selected and _marks(lab).hovered == army.hovered and _marks(lab).map_size == LabArmy.MAP_SIZE, "LB20 leaving health_bar from the live view restores the frozen selection")
	lab.free()
	return true
