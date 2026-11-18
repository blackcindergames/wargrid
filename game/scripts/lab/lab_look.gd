extends RefCounted

const Palette = preload("res://scripts/presentation/palette.gd")
const WorldView = preload("res://scripts/presentation/world_view.gd")

# hud-v5-layout.md token table; `hint` is lab-only and equals `muted` in A, so A's look is unchanged.
const SET_A := {
	&"bg": Color("121c24"), &"btn": Color("223241"), &"panel2": Color("26384a"), &"quiet": Color("16212a"),
	&"well": Color("0c141a"), &"line": Color("2e3f4b"), &"text": Color("eef3f5"), &"muted": Color("93a5b0"),
	&"hint": Color("93a5b0"), &"sel": Color("60e5ed"), &"amber": Color("f7c871"),
	&"you": Color("628ffa"), &"enemy": Color("d6120c"), &"ally": Color("69ceaa"),
}
# design-answers-2026-11-08.md:769 investigation; panel2, quiet and well are not in it and are derived below.
const SET_B_SOURCE := {
	&"bg": Color("172731"), &"btn": Color("223640"), &"line": Color("40535d"), &"text": Color("f1f5f7"),
	&"muted": Color("b7c4cc"), &"hint": Color("96a5ae"), &"sel": Color("67deeb"), &"amber": Color("f7c871"),
	&"you": Color("628ffa"), &"enemy": Color("d6120c"), &"ally": Color("69ceaa"),
}
const DERIVED_ROLES: Array[StringName] = [&"panel2", &"quiet", &"well"]
# map-art-shapes.md P2.3a, Palette A (slots 1-8) and the round 6 sides.
const PALETTE_A: Array[Color] = [
	Color("628ffa"), Color("d6120c"), Color("4ad49b"), Color("f8e425"),
	Color("0e92a7"), Color("7242fe"), Color("ec8600"), Color("f79cef"),
]
const SIDE_A := Color("1c2e39")
const SIDE_DARK_A := Color("0e1b23")

# map-art-shapes.md P2.3a: white marks sit on this under-stroke, 2 px wider.
const UNDER_STROKE := Color(14 / 255.0, 18 / 255.0, 22 / 255.0, 0.78)
const EDGE_HEIGHT := 24.0
const EDGE_SIDE := Color("425463")
const CANVAS := Color("08090a")
const DARK_GROUND := Color("7b7566")

const RULES: Array[StringName] = [&"damaged_or_hovered", &"selected_or_hovered", &"selected_damaged_or_hovered"]
const VALUE_SIZES: Array[int] = [14, 13]

const FONT_FILES := {400: "PublicSans-Regular", 600: "PublicSans-SemiBold", 700: "PublicSans-Bold"}
static var _fonts: Dictionary = {}

static func tokens(set_name: StringName) -> Dictionary:
	if set_name == &"a": return SET_A.duplicate()
	var result: Dictionary = SET_B_SOURCE.duplicate()
	for role in DERIVED_ROLES: result[role] = derived_b(role)
	return result

# B slot = B slab's OKHSL hue and saturation, lightness = slab lightness + (A slot lightness - A bg lightness).
static func derived_b(role: StringName) -> Color:
	var slab: Color = SET_B_SOURCE[&"bg"]
	var lightness: float = slab.ok_hsl_l + SET_A[role].ok_hsl_l - SET_A[&"bg"].ok_hsl_l
	return Color(Color.from_ok_hsl(slab.ok_hsl_h, slab.ok_hsl_s, lightness).to_html(false))

static func owner_colors_a(owner: int) -> PackedColorArray:
	if owner < 1 or owner > PALETTE_A.size(): return Palette.owner_colors(owner)
	var plain: PackedColorArray = Palette.owner_colors(owner)
	var base: Color = PALETTE_A[owner - 1]
	return PackedColorArray([base, base.darkened(0.25), SIDE_A, SIDE_DARK_A, plain[4], plain[5], base, plain[7]])

static func bar_shown(rule: int, selected: bool, hovered: bool, hp: int, max_hp: int) -> bool:
	match rule:
		0: return hovered or hp < max_hp
		1: return selected or hovered
		_: return WorldView.shows_health(selected, hp, max_hp, hovered)

static func font(weight: int, spacing: int = 0) -> FontVariation:
	var key: Array = [weight, spacing]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = load("res://fonts/%s.ttf" % FONT_FILES[weight])
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]
