extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")

const LICENSED_DIR := "res://audio/licensed/sfx/"

# `sound` is the free file and the fallback; `licensed` names a gitignored pack file (tools/audio/licensed.py)
# with level and pitch baked in; `shares`: the cue it splits from, whose voice limit it counts against. `hold`: a licensed burst file replays at most once per that many ticks per shooter.
const CUES := {
	"rifle_burst": {"sound": "rifle_burst", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "burst": true, "licensed": "usa_rifle"},
	"frc_rifle": {"shares": "rifle_burst", "sound": "rifle_burst", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "burst": true, "licensed": "frc_rifle"},
	"carbine": {"sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "china_militia"},
	"usa_mg": {"shares": "carbine", "sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "usa_mg", "hold": 21},
	"frc_mg": {"shares": "carbine", "sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "frc_mg", "hold": 46},
	"china_rotary": {"shares": "carbine", "sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "china_rotary", "hold": 52},
	"china_rotary_tower": {"shares": "carbine", "sound": "carbine", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "china_rotary_tower", "hold": 62},
	"cannon": {"sound": "cannon", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "usa_cannon"},
	"china_cannon": {"shares": "cannon", "sound": "cannon", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "china_cannon"},
	"frc_cannon": {"shares": "cannon", "sound": "cannon", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "frc_cannon"},
	"launch": {"sound": "explosion", "limit": 4, "pitch": 1.5, "jitter": 0.0, "gain_db": -6.0, "ui": false, "licensed": "usa_launch"},
	"china_launch": {"shares": "launch", "sound": "explosion", "limit": 4, "pitch": 1.5, "jitter": 0.0, "gain_db": -6.0, "ui": false, "licensed": "china_launch"},
	"frc_launch": {"shares": "launch", "sound": "explosion", "limit": 4, "pitch": 1.5, "jitter": 0.0, "gain_db": -6.0, "ui": false, "licensed": "frc_launch"},
	"usa_battery": {"shares": "launch", "sound": "explosion", "limit": 4, "pitch": 1.5, "jitter": 0.0, "gain_db": -6.0, "ui": false, "licensed": "usa_battery"},
	"impact": {"sound": "explosion", "limit": 4, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false, "licensed": "impact"},
	"infantry_death": {"sound": "infantry_death", "limit": 3, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"vehicle_death": {"sound": "vehicle_death", "limit": 4, "pitch": 1.0, "jitter": 0.05, "gain_db": 0.0, "ui": false},
	"building": {"sound": "building_small", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": false},
	"placement": {"sound": "click", "limit": 2, "pitch": 0.8, "jitter": 0.0, "gain_db": 0.0, "ui": true},
	"click": {"sound": "click", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": true},
	"error": {"sound": "error", "limit": 2, "pitch": 1.0, "jitter": 0.0, "gain_db": 0.0, "ui": true},
	# Zero Hour's disabled click (HotKey.cpp:174-190); the click sped up, so it reads shorter.
	"disabled": {"sound": "click", "limit": 2, "pitch": 1.5, "jitter": 0.0, "gain_db": 0.0, "ui": true},
}

# No catch-all: a new weapon needs a row (spec section 2).
const SHOT_BY_WEAPON := {"rifle": "rifle_burst", "militia_gun": "carbine", "scout_gun": "usa_mg", "pickup_gun": "frc_mg", "tunnel_gun": "frc_mg", "rotary_gun": "china_rotary", "rotary_tower_gun": "china_rotary_tower", "cannon": "cannon", "pickup_cannon": "frc_cannon", "light_tank_gun": "frc_cannon", "light_tank_gun_plus": "frc_cannon", "rocket": "launch", "battery": "usa_battery", "pickup_rocket": "frc_launch"}
# Zero Hour gives every faction its own fire sound; these weapons are shared between factions here.
const SHOT_BY_FACTION := {"frc": {"rifle": "frc_rifle", "rocket": "frc_launch"}, "china": {"cannon": "china_cannon", "rocket": "china_launch"}}

static var _present: Dictionary = {}
const SHOT_BY_DAMAGE := {"small_arms": "carbine", "rapid_fire": "carbine", "gattling": "carbine", "armor_piercing": "cannon", "infantry_missile": "launch", "explosion": "launch"}

static func weapon_id(kind: String, tier: int) -> String:
	var row: Dictionary = Registry.kind(kind)
	var tiers: Array = row.get("weapon_tiers", [])
	return tiers[tier] if not tiers.is_empty() else row.get("weapon", "")

static func faction(kind: String) -> String:
	return kind.get_slice("_", 0)

static func shot_cue(weapon: String, side: String = "") -> String:
	var own: Dictionary = SHOT_BY_FACTION.get(side, {})
	if own.has(weapon): return own[weapon]
	if SHOT_BY_WEAPON.has(weapon): return SHOT_BY_WEAPON[weapon]
	return SHOT_BY_DAMAGE.get(Shared.WEAPONS.get(weapon, {}).get("damage_type", ""), "")

static func death_cue(kind: String, is_building: bool) -> String:
	if is_building: return "building"
	return "infantry_death" if Registry.kind(kind).get("armor", "") == "human" else "vehicle_death"

static func building_sound(kind: String) -> String:
	var row: Dictionary = Registry.kind(kind)
	if row.has("hole"): return "building_small"
	var footprint: Vector2i = row.get("footprint", Vector2i.ONE)
	return "building_large" if footprint.x * footprint.y >= 9 else "building_small"

# Tests pin the answer; null goes back to looking at the files.
static func assume(present: Variant) -> void:
	_present = {}
	if present == null: return
	for cue: String in CUES:
		if CUES[cue].has("licensed"): _present[CUES[cue].licensed] = present

static func licensed(cue: String) -> bool:
	var stem: String = CUES[cue].get("licensed", "")
	if stem.is_empty(): return false
	if not _present.has(stem): _present[stem] = ResourceLoader.exists(LICENSED_DIR + stem + ".wav")
	return _present[stem]

static func sound(cue: String) -> String:
	return "licensed/" + CUES[cue].licensed if licensed(cue) else CUES[cue].sound

static func pitch(cue: String) -> float:
	return 1.0 if licensed(cue) else CUES[cue].pitch

static func gain_db(cue: String) -> float:
	return 0.0 if licensed(cue) else CUES[cue].gain_db

static func limit_key(cue: String) -> String:
	return CUES[cue].get("shares", cue)

static func hold_ticks(cue: String) -> int:
	return CUES[cue].get("hold", 0) if licensed(cue) else 0

static func path(sound_name: String) -> String:
	if sound_name.begins_with("licensed/"): return LICENSED_DIR + sound_name.trim_prefix("licensed/") + ".wav"
	return "res://audio/sfx/%s.wav" % sound_name
