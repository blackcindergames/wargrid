extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const JoinLink = preload("res://scripts/join_link.gd")
const SECTION := "launcher"
# Picked when the match starts; never reaches the simulation.
const RANDOM := MatchSettings.RANDOM

static func load_picks() -> Dictionary:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	var default_map: String = MatchSettings.PLAY_MAPS.keys()[0]
	var factions: Dictionary = Registry.Factions.FACTIONS.merged({RANDOM: true})
	return {
		"faction": _valid(config, "faction", factions, Registry.Factions.DEFAULT_FACTION),
		"bots": _valid_bots(config, factions),
		"map": _valid(config, "map", MatchSettings.PLAY_MAPS, default_map),
	}

# Files from before P20 hold one bot_faction; the M9 team_bot keys are ignored.
static func _valid_bots(config: ConfigFile, factions: Dictionary) -> Array[String]:
	var bots: Array[String] = [_valid(config, "bot_faction", factions, Registry.Factions.DEFAULT_FACTION)]
	var stored: Variant = config.get_value(SECTION, "bots", [])
	if stored is Array and not stored.is_empty() and stored.all(func(id: Variant) -> bool: return id is String and factions.has(id)): bots.assign(stored)
	return bots

static func save_picks(picks: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	for key: String in picks: config.set_value(SECTION, key, picks[key])
	config.save(AudioSettings.path)

static func fullscreen() -> bool:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	var stored: Variant = config.get_value(SECTION, "fullscreen", false)
	return stored if stored is bool else false

static func save_fullscreen(on: bool) -> void:
	save_picks({"fullscreen": on})

# Test builds only: a relay typed in Settings; ws:// stays allowed for a local relay.
static func relay() -> String:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	var stored: Variant = config.get_value(SECTION, "relay", "")
	return stored if stored is String and not stored.is_empty() else JoinLink.DEFAULT_RELAY

static func save_relay(url: String) -> void:
	save_picks({"relay": url})

static func _valid(config: ConfigFile, key: String, ids: Dictionary, fallback: String) -> String:
	var stored: Variant = config.get_value(SECTION, key, fallback)
	return stored if stored is String and ids.has(stored) else fallback
