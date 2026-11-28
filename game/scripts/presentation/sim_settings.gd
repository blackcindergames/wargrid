extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const SECTION := "simulation"

# Tests show the row and take the stored request on a native build.
static var available_in_tests: bool = false

# Only the threaded Web export reads the setting; native keeps the environment switch.
static func available() -> bool:
	return available_in_tests or (OS.has_feature("web") and OS.has_feature("threads"))

static func load_worker() -> bool:
	var config := ConfigFile.new()
	if config.load(AudioSettings.path) != OK: return true
	var value: Variant = config.get_value(SECTION, "worker", true)
	return value if value is bool else true

static func save_worker(on: bool) -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	config.set_value(SECTION, "worker", on)
	config.save(AudioSettings.path)

# The next pump's request: the stored bool where the row exists, otherwise null for the pump's own switch.
static func request() -> Variant:
	return load_worker() if available() else null
