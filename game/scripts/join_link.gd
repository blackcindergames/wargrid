extends RefCounted

const DEFAULT_RELAY := "wss://relay.wargrid.blackcindergames.com/ws"
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const MAX_INPUT := 2048
const MAX_RELAY := 256

static func parse(search: String) -> Dictionary:
	var params := {}
	if search.length() > MAX_INPUT:
		return params
	for pair in search.trim_prefix("?").split("&", false):
		var parts := pair.split("=", true, 1)
		var key := parts[0].uri_decode()
		if not params.has(key):
			params[key] = parts[1].uri_decode() if parts.size() > 1 else ""
	return params

static func code(value: String) -> String:
	var upper := value.to_upper()
	if upper.length() != 6:
		return ""
	for character in upper:
		if not ALPHABET.contains(character):
			return ""
	return upper

static func relay(value: String) -> String:
	var valid := value.begins_with("wss://") and value.length() > 6 and value.length() <= MAX_RELAY and value[6] != "/" and not value.contains("@")
	return value if valid and not _has_whitespace(value) else ""

static func code_from(text: String) -> String:
	if text.length() > MAX_INPUT:
		return ""
	var tagged := RegEx.create_from_string("(?i)code=([A-Z0-9]+)").search(text)
	if tagged != null and not code(tagged.get_string(1)).is_empty():
		return code(tagged.get_string(1))
	# Upper case before any case: a code typed in capitals beats chat words, and a split code beats "thanks" or "please".
	var split := "(?<![A-Za-z0-9])([A-Z0-9]{3})[\\s\\x{00A0}\\x{2010}\\x{2013}\\x{2014}-]([A-Z0-9]{3})(?![A-Za-z0-9])"
	var whole := "(?<![A-Za-z0-9])([A-Z0-9]{6})(?![A-Za-z0-9])"
	for pattern: String in [whole, split, "(?i)" + split, "(?i)" + whole]:
		for token in RegEx.create_from_string(pattern).search_all(text):
			var found := code(token.get_string(1) + (token.get_string(2) if token.get_group_count() > 1 else ""))
			if not found.is_empty():
				return found
	return ""

# The field holds one code-shaped entry with O, 0, I or 1: a misread code, as codes never use them; words in a sentence do not count.
static func lookalike(text: String) -> bool:
	var entry := RegEx.create_from_string("(?i)^([A-Z0-9]{3})[\\s\\x{00A0}\\x{2010}\\x{2013}\\x{2014}-]?([A-Z0-9]{3})$").search(text.strip_edges())
	return entry != null and RegEx.create_from_string("(?i)[O0I1]").search(entry.get_string(1) + entry.get_string(2)) != null

static func link(base: String, match_code: String, relay_url: String) -> String:
	var url := base + "?code=" + match_code
	return url if relay_url == DEFAULT_RELAY else url + "&relay=" + relay_url.uri_encode()

static func _has_whitespace(value: String) -> bool:
	return RegEx.create_from_string("\\s").search(value) != null
