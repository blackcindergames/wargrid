extends RefCounted

# map-art-shapes.md P2.3a, Palette A (slots 1-8) and the round 6 sides.
const OWNER_BASE: Array[Color] = [
	Color("628ffa"), Color("d6120c"), Color("4ad49b"), Color("f8e425"),
	Color("0e92a7"), Color("7242fe"), Color("ec8600"), Color("f79cef"),
]
const OWNER_SIDE := Color("1c2e39")
const OWNER_SIDE_DARK := Color("0e1b23")
# Owner 0 and unknown owners keep the neutral grey sides (ART_DIRECTION section 7, palette-proposal.json materials).
const SIDE := Color("3d515f")
const SIDE_DARK := Color("263842")
const MACHINE := Color("8098a5")
const OWNER_BRIGHT: Array[Color] = [
	Color("2f7bff"), Color("ff2f45"), Color("14d45a"), Color("ffe100"),
	Color("ff7a00"), Color("a040ff"), Color("00d8e8"), Color("ff4fb0"),
]
const SKIN := Color("d8c8ae")
const SHADOW := Color(0, 0, 0, 0.3)
const SMOKE := Color("2a2c2e")
const FALLBACK := Color("808080")
# Owner 0 is neutral supply: amber crates (palette-proposal.json, impact_heat_resources).
const NEUTRAL := Color("f7c871")
const SAND := Color("a88e5c")
const DEFAULT_BIOME := 1
const HEALTH_GREEN := Color("5cc85a")
const HEALTH_YELLOW := Color("e0d060")
const HEALTH_RED := Color("d8453a")

# Eight slots: the Shapes slots; bright swaps in the Neon hues.
static func owner_colors(owner: int, bright: bool = false) -> PackedColorArray:
	var owned: bool = owner >= 1 and owner <= OWNER_BASE.size()
	var base: Color = OWNER_BASE[owner - 1] if owned else (NEUTRAL if owner == 0 else FALLBACK)
	if bright and owned: base = OWNER_BRIGHT[owner - 1]
	return PackedColorArray([
		base, base.darkened(0.25), OWNER_SIDE if owned else SIDE, OWNER_SIDE_DARK if owned else SIDE_DARK,
		MACHINE, SMOKE, base, SKIN,
	])

# Cliffs read against the ground: top lighter, sides much darker.
static func ground_set(tone: Color) -> Dictionary:
	return {"ground": tone, "cliff_top": tone.lightened(0.15), "cliff_side": tone.darkened(0.4)}

static func ground(biome: int) -> Dictionary:
	if biome == 0:
		return {"ground": Color("7b7566"), "cliff_top": Color("968f7c"), "cliff_side": Color("4a463c")}
	return ground_set(SAND)
