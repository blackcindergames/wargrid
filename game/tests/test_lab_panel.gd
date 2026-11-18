@warning_ignore_start("untyped_declaration")
extends RefCounted

const LabLook = preload("res://scripts/lab/lab_look.gd")
const LabPanel = preload("res://scripts/lab/lab_panel.gd")
# hud-v5-layout.md "Heights per state"; pile is one key-value line after the 2026-11-17 answer.
const HEIGHTS := {&"one": 62, &"many": 136, &"building": 86, &"enemy": 62, &"pile": 62, &"low_power": 62}

func cases() -> Array[Callable]:
	return [test_panel_states_fit, test_widest_text, test_panel_heights, test_panel_tokens]

func _shown(runner, state: StringName, set_name: StringName, size: int, slot: int = 0, letter: String = "") -> Control:
	var hud: Control = LabPanel.new()
	runner.root.add_child(hud)
	hud.show_state(state, LabLook.tokens(set_name), size, slot, letter)
	await runner.process_frame
	await runner.process_frame
	return hud

func _rect(node: Control) -> Rect2:
	return node.get_global_rect()

func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(0.01).encloses(inner)

func _slabs(hud: Control) -> Array[Control]:
	var result: Array[Control] = []
	for name in ["Panel", "Strip", "Ally", "Letter", "StripLetter"]:
		var node: Control = hud.find_child(name, true, false)
		if node != null: result.append(node)
	return result

func _label_with(hud: Control, text: String) -> Label:
	for label: Label in hud.labels():
		if label.text == text: return label
	return null

func test_panel_states_fit(runner) -> bool:
	for state: StringName in LabPanel.STATES:
		for size: int in LabLook.VALUE_SIZES:
			for set_name: StringName in [&"a", &"b"]:
				var huds: Array[Control] = [await _shown(runner, state, set_name, size, 0, "A"), await _shown(runner, state, set_name, size, 1, "B")]
				var tag := "%s %d %s" % [state, size, set_name]
				for slot in 2:
					var hud: Control = huds[slot]
					var other: Control = huds[1 - slot]
					runner.check(not hud.labels().is_empty(), "LP1 %s slot %d builds labels" % [tag, slot])
					for label: Label in hud.labels():
						var minimum: Vector2 = label.get_minimum_size()
						runner.check(minimum.x <= label.size.x + 0.5 and minimum.y <= label.size.y + 0.5, "LP1 %s slot %d label '%s' not cut (%s in %s)" % [tag, slot, label.text, minimum, label.size])
						var holder: Control = null
						for slab in _slabs(hud):
							if slab.is_ancestor_of(label): holder = slab
						runner.check(holder != null and _inside(_rect(label), _rect(holder)), "LP1 %s slot %d label '%s' inside its slab" % [tag, slot, label.text])
					var screen := Rect2(Vector2.ZERO, LabPanel.SCREEN)
					runner.check(_inside(hud.panel_rect(), screen) and _inside(hud.strip_rect(), screen), "LP1 %s slot %d panel and strip on screen" % [tag, slot])
					runner.check(is_equal_approx(hud.panel_rect().end.y, 800.0), "LP1 %s slot %d panel bottom on y 800" % [tag, slot])
					var letter: Control = hud.find_child("Letter", true, false)
					var strip_letter: Control = hud.find_child("StripLetter", true, false)
					runner.check(strip_letter != null and _rect(strip_letter).position.x > hud.strip_rect().end.x and _rect(hud.find_child("Strip", true, false)).encloses(Rect2(hud.strip_rect().position.x, _rect(strip_letter).position.y, 1, _rect(strip_letter).size.y)), "LP1 %s slot %d strip letter beside its strip" % [tag, slot])
					runner.check(letter != null and _inside(_rect(letter), screen), "LP1 %s slot %d letter tag on screen" % [tag, slot])
					for slab in _slabs(other):
						runner.check(letter != null and not _rect(letter).intersects(_rect(slab)), "LP1 %s slot %d letter tag clear of slot %d %s" % [tag, slot, 1 - slot, slab.name])
				runner.check(not huds[0].panel_rect().intersects(huds[1].panel_rect()), "LP1 %s panels apart" % tag)
				runner.check(not huds[0].strip_rect().intersects(huds[1].strip_rect()), "LP1 %s strips apart" % tag)
				runner.check(huds[1].find_child("Ally", true, false) == null, "LP1 %s slot 1 has no ally chip" % tag)
				for hud in huds: hud.free()
	return true

func test_widest_text(runner) -> bool:
	var many: Control = await _shown(runner, &"many", &"b", 14)
	for name in ["Anti-Tank Trooper", "Rotary Gun Tank"]:
		var label: Label = _label_with(many, name)
		runner.check(label != null, "LP2 row %s exists" % name)
		if label == null: continue
		var count: Label = label.get_parent().get_child(1)
		var row: Control = label
		while not row.get_parent() is GridContainer: row = row.get_parent()
		runner.check(count in many.number_labels(), "LP2 row %s count is a Numbers label" % name)
		var name_end: float = _rect(label).position.x + label.get_minimum_size().x
		var count_start: float = _rect(count).end.x - count.get_minimum_size().x
		runner.check(is_equal_approx(_rect(row).size.x, 186.0), "LP2 row %s is 186 wide" % name)
		runner.check(_inside(_rect(label), _rect(row)) and _inside(_rect(count), _rect(row)), "LP2 row %s name and count inside 186" % name)
		runner.check(count_start - name_end >= 4.0, "LP2 row %s keeps 4 px between name and count (%.1f)" % [name, count_start - name_end])
	many.free()
	var low: Control = await _shown(runner, &"low_power", &"b", 14)
	var chip: Control = low.find_child("Ally", true, false)
	runner.check(chip != null and low.strip_rect().end.x <= LabPanel.SCREEN.x - 8.0 - chip.size.x - 8.0, "LP2 low power strip clears the ally chip")
	runner.check(_label_with(low, "LOW POWER") != null, "LP2 low power strip shows LOW POWER")
	low.free()
	var building: Control = await _shown(runner, &"building", &"b", 14)
	var widest: Label = _label_with(building, "1,240 / 2,000")
	runner.check(widest != null and _inside(_rect(widest), building.panel_rect()) and widest.get_minimum_size().x <= widest.size.x + 0.5, "LP2 building holds 1,240 / 2,000")
	building.free()
	return true

func test_panel_heights(runner) -> bool:
	for state: StringName in LabPanel.STATES:
		var small: Control = await _shown(runner, state, &"a", 13)
		var large: Control = await _shown(runner, state, &"a", 14)
		var h13: float = small.panel_rect().size.y
		var h14: float = large.panel_rect().size.y
		runner.check(absf(h13 - HEIGHTS[state]) <= 2.0, "LP3 %s at 13 is %.0f, v5 %d" % [state, h13, HEIGHTS[state]])
		runner.check(absf(h14 - h13) <= 4.0, "LP3 %s at 14 is %.0f, at 13 %.0f" % [state, h14, h13])
		small.free()
		large.free()
	return true

func test_panel_tokens(runner) -> bool:
	var b: Control = await _shown(runner, &"one", &"b", 13)
	var panel: PanelContainer = b.find_child("Panel", true, false)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(style != null and style.bg_color == Color("172731"), "LP4 panel fill is B bg")
	runner.check(style != null and style.border_color == Color("40535d") and style.border_width_top == 1 and style.border_width_right == 1 and style.border_width_left == 0, "LP4 panel border is 1 px B line top and right")
	var edge: ColorRect = b.find_child("Edge", true, false)
	runner.check(edge != null and edge.color == Color("628ffa") and is_equal_approx(edge.size.x, 4.0) and is_equal_approx(_rect(edge).position.x, b.panel_rect().position.x), "LP4 left edge is 4 px you")
	var value: Label = _label_with(b, "180 / 400")
	runner.check(value != null and value.label_settings.font_color == Color("b7c4cc"), "LP4 cur / max is B muted")
	runner.check(value in b.number_labels() and value.label_settings.font_size == 13, "LP4 cur / max is a Numbers label at 13")
	var track: ColorRect = b.find_child("Track", true, false)
	runner.check(track != null and track.color == Color("121f28"), "LP4 bar track is B well")
	for label: Label in b.labels():
		var font := label.label_settings.font as FontVariation
		var tnum: int = TextServerManager.get_primary_interface().name_to_tag("tnum")
		runner.check(font != null and font.opentype_features.get(tnum, 0) == 1, "LP4 label '%s' has tabular numbers" % label.text)
	b.free()
	var a: Control = await _shown(runner, &"one", &"a", 13)
	var value_a: Label = _label_with(a, "180 / 400")
	runner.check(value_a != null and value_a.label_settings.font_color == Color("93a5b0"), "LP4 cur / max is A muted")
	a.free()
	return true
