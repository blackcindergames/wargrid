@warning_ignore_start("untyped_declaration")
extends RefCounted

const LabLook = preload("res://scripts/lab/lab_look.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const View = preload("res://scripts/presentation/world_view.gd")

const ROLES: Array[StringName] = [&"bg", &"btn", &"panel2", &"quiet", &"well", &"line", &"text", &"muted", &"hint", &"sel", &"amber", &"you", &"enemy", &"ally"]
const A_HEX := {"bg": "121c24", "btn": "223241", "panel2": "26384a", "quiet": "16212a", "well": "0c141a", "line": "2e3f4b", "text": "eef3f5", "muted": "93a5b0", "hint": "93a5b0", "sel": "60e5ed", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const B_HEX := {"bg": "172731", "btn": "223640", "panel2": "2b4453", "quiet": "1a2c37", "well": "121f28", "line": "40535d", "text": "f1f5f7", "muted": "b7c4cc", "hint": "96a5ae", "sel": "67deeb", "amber": "f7c871", "you": "628ffa", "enemy": "d6120c", "ally": "69ceaa"}
const SLOT_ONE_HEX: Array[String] = ["628ffa", "d6120c", "4ad49b", "f8e425", "0e92a7", "7242fe", "ec8600", "f79cef"]

func cases() -> Array[Callable]:
	return [test_token_sets, test_palette_a, test_bar_rules, test_number_font]

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
