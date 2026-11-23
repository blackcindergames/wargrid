extends PanelContainer

# Production strip round (user, 2026-11-23): its own slab ending 8 left of Menu, one chip per producer (`HudModel.strip_chips`).
signal producer_pressed(id: int, jump: bool)

const HudModel = preload("res://scripts/match/hud_model.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const UnitGlyphs = preload("res://scripts/presentation/unit_glyphs.gd")
const ControlGroups = preload("res://scripts/match/control_groups.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
# Chip C: an 18 px glyph stacked over a 40 x 4 bar.
const CHIP: Vector2 = Vector2(48, 26)
const BAR: Vector2 = Vector2(40, 4)
const GLYPH: float = 18.0
# The owner's pick after trying both (user, 2026-11-23): count column, glyph and a 4 x 20 bar side by side.
const UPRIGHT_CHIP: Vector2 = Vector2(42, 26)
# Wide enough for one digit at 12 px, kept while the count hides, so a chip never changes width.
const COUNT_WIDTH: float = 9.0
# Under the count while other kinds follow the current run (user, 2026-11-23).
const THEN_MARK: Vector2 = Vector2(4, 6)
const UPRIGHT_BAR: Vector2 = Vector2(4, 20)
const TIP_DELAY_MSEC: int = 250
# The round's idle grey (strip.html `--idle`).
const IDLE: Color = Color("#7b8d99")
# The owner's one-time hint (user, 2026-11-23), remembered in the settings file once gone.
const HINT := "Your busy buildings: click one to select it, double-click to go there"
const HINT_MSEC: int = 10000
const HINT_SECTION := "hints"
const HINT_KEY := "strip_seen"
const HINT_UNREAD: float = -2.0
const HINT_GONE: float = -1.0

# Upright by default (user, 2026-11-23); F7 (`orders._debug_key`) flips to the stacked chip for the session.
static var upright: bool = true

var now_msec: Callable = Time.get_ticks_msec
var helpers: Array[Control] = []
var _row: HBoxContainer
var _more: Button
var _tip: PanelContainer
var _chips: Array = []
# The records as given, so a bar-length switch redraws from the true progress.
var _source: Array = []
var _tip_words: Array = []
var _folded: Array = []
var _selected: int = -1
var _colour: Color
var _looks: Dictionary = {}
var _hovered: Control = null
var _hover_since: int = -1
var _tip_open: bool = false
var _pressed_id: int = -1
var _pressed_at: int = 0
# The match screen's menu or an unfocused window: the hint's time stands still.
var covered: Callable = func() -> bool: return false
# An online notice takes the top centre, so the hint steps aside, its time paused.
var notice_up: bool = false:
	set(up):
		if up == notice_up: return
		notice_up = up
		_show_hint()
		_show_tip()
var _hint: PanelContainer
# HINT_UNREAD until the strip first shows, then the msec of visible time left, or HINT_GONE.
var _hint_left: float = HINT_UNREAD

func _init() -> void:
	name = "ProductionStrip"
	theme_type_variation = &"HudSlab"
	# With the 1 px border the chips sit 4 from the slab's edge, 4 apart.
	var slab := get_theme_stylebox("panel", &"HudSlab").duplicate() as StyleBoxFlat
	slab.content_margin_left = 3
	slab.content_margin_right = 3
	slab.content_margin_top = 0
	slab.content_margin_bottom = 0
	add_theme_stylebox_override("panel", slab)
	custom_minimum_size.y = 32
	set_anchors_preset(PRESET_TOP_RIGHT)
	grow_horizontal = GROW_DIRECTION_BEGIN
	offset_top = 8
	offset_bottom = 8
	visible = false
	mouse_exited.connect(func() -> void: _tip_open = false)
	_row = HBoxContainer.new()
	_row.name = "Chips"
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 4)
	add_child(_row)
	_build_looks()
	_build_more()
	_build_hint()
	_build_tip()

func _build_looks() -> void:
	for look: Array in [["normal", "btn", "btn", 0], ["hover", "panel2", "muted", 1], ["selected", "panel2", "sel", 1]]:
		var style := StyleBoxFlat.new()
		style.bg_color = get_theme_color(look[1], &"Tokens")
		style.border_color = get_theme_color(look[2], &"Tokens")
		style.set_border_width_all(look[3])
		_looks[look[0]] = style
	_looks.warn = get_theme_color("warn", &"Tokens")
	# Hard edges, as the fill's: an anti-aliased track edge blurs a pixel past the fill's.
	_looks.track = StyleBoxFlat.new()
	_looks.track.anti_aliasing = false
	_looks.track.bg_color = get_theme_color("well", &"Tokens")
	_looks.hollow = StyleBoxFlat.new()
	_looks.hollow.anti_aliasing = false
	_looks.hollow.draw_center = false
	_looks.hollow.border_color = IDLE
	_looks.hollow.set_border_width_all(1)

# `+N`: muted, as wide as its words, a hover list of the folded producers; no click.
func _build_more() -> void:
	_more = _button("More")
	_more.mouse_default_cursor_shape = CURSOR_HELP
	_more.custom_minimum_size = Vector2(0, CHIP.y)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: _more.add_theme_color_override(state, get_theme_color("muted", &"Tokens"))
	var padded := _looks.normal.duplicate() as StyleBoxFlat
	padded.content_margin_left = 8
	padded.content_margin_right = 8
	var hovered := _looks.hover.duplicate() as StyleBoxFlat
	hovered.content_margin_left = 8
	hovered.content_margin_right = 8
	for state: String in ["normal", "pressed"]: _more.add_theme_stylebox_override(state, padded)
	for state: String in ["hover", "hover_pressed"]: _more.add_theme_stylebox_override(state, hovered)

func _button(button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.focus_mode = FOCUS_NONE
	button.theme_type_variation = &"HudButton"
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	# Pass, so the slab hears the pointer leave it from a chip and closes the card rule.
	button.mouse_filter = MOUSE_FILTER_PASS
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	button.visible = false
	_row.add_child(button)
	return button

# Top-level and mouse-transparent, built before the chip card so the card draws over it.
func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = &"HudSlab"
	_hint.top_level = true
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	_hint.visible = false
	var style := get_theme_stylebox("panel", &"HudSlab").duplicate() as StyleBoxFlat
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_hint.add_theme_stylebox_override("panel", style)
	add_child(_hint)
	var text := Label.new()
	text.name = "Text"
	text.theme_type_variation = &"HudHint"
	text.text = HINT
	_hint.add_child(text)

# Top-level, so the slab neither sizes nor sorts it.
func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.name = "Tip"
	_tip.theme_type_variation = &"HudSlab"
	_tip.top_level = true
	_tip.mouse_filter = MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 4)
	_tip.add_child(lines)
	for part: Array in [["Tag", &"HudLabel", "ALSO PRODUCING"], ["Name", &"HudRow", ""], ["Text", &"HudHint", ""]]:
		var label := Label.new()
		label.name = part[0]
		label.theme_type_variation = part[1]
		label.text = part[2]
		lines.add_child(label)

func _chip(index: int) -> Button:
	if index + 1 < _row.get_child_count(): return _row.get_child(index + 1)
	var chip: Button = _button("Chip%d" % index)
	chip.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	chip.pressed.connect(_press.bind(chip))
	var glyph := TextureRect.new()
	glyph.name = "Glyph"
	glyph.mouse_filter = MOUSE_FILTER_IGNORE
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glyph.size = Vector2(GLYPH, GLYPH)
	chip.add_child(glyph)
	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = MOUSE_FILTER_IGNORE
	chip.add_child(track)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	track.add_child(fill)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = &"HudNumber"
	# The HUD's smallest size (FS1); the owner asked for about 11.
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", get_theme_color("muted", &"Tokens"))
	count.mouse_filter = MOUSE_FILTER_IGNORE
	count.custom_minimum_size.x = COUNT_WIDTH
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.visible = false
	chip.add_child(count)
	var mark := Control.new()
	mark.name = "Then"
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	mark.size = THEN_MARK
	mark.visible = false
	var muted: Color = get_theme_color("muted", &"Tokens")
	mark.draw.connect(func() -> void: mark.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(THEN_MARK.x, THEN_MARK.y / 2.0), Vector2(0, THEN_MARK.y)]), muted))
	chip.add_child(mark)
	_shape(chip)
	return chip

# Stacked: glyph 1 from the top, the bar 2 under it, the count right of the glyph; upright: count, glyph and bar in columns (2 | 9 | 2 | 18 | 4 | 4 | 3), the count top-aligned with the glyph.
# The mark sits centred under the count, its bottom on the glyph's.
func _shape(chip: Button) -> void:
	chip.custom_minimum_size = UPRIGHT_CHIP if upright else CHIP
	var glyph: Control = chip.get_node("Glyph")
	var track: Control = chip.get_node("Track")
	glyph.position = Vector2(13, 4) if upright else Vector2(15, 1)
	track.position = Vector2(35, 3) if upright else Vector2(4, 21)
	track.size = UPRIGHT_BAR if upright else BAR
	var count: Vector2 = Vector2(2, 4) if upright else Vector2(38, 0)
	(chip.get_node("Count") as Control).position = count
	(chip.get_node("Then") as Control).position = Vector2(count.x + floorf((COUNT_WIDTH - THEN_MARK.x) / 2.0), glyph.position.y + GLYPH - THEN_MARK.y)

func set_upright(on: bool) -> void:
	upright = on
	for i: int in range(1, _row.get_child_count()): _shape(_row.get_child(i))
	_chips = []
	show_chips(_source, _selected, _colour)

# F38: an unchanged view returns here, progress compared in drawn pixels; a changed one touches only what differs.
func show_chips(chips: Array, selected: int, colour: Color) -> void:
	var length: float = UPRIGHT_BAR.y if upright else BAR.x
	var drawn: Array = chips.map(func(chip: Dictionary) -> Dictionary: return chip.merged({"fraction": roundf(chip.fraction * length) / length}, true))
	_source = chips
	if drawn == _chips and selected == _selected and colour == _colour: return
	_chips = drawn
	_selected = selected
	_colour = colour
	var split: Array = HudModel.strip_split(drawn)
	_folded = split[0]
	# The owner's rule (user, 2026-11-23): nothing in production, no strip.
	visible = drawn.any(_busy)
	_follow_hint()
	_more.visible = not _folded.is_empty()
	var count: String = "+%d" % _folded.size()
	if _more.visible and _more.text != count: _more.text = count
	var shown: Array = split[1]
	for i: int in shown.size(): _fill(_chip(i), shown[i])
	for i: int in range(shown.size() + 1, _row.get_child_count()): _row.get_child(i).visible = false
	if _tip.visible: _show_tip()

func _fill(chip: Button, record: Dictionary) -> void:
	chip.visible = true
	chip.set_meta("chip", record)
	var idle: bool = record.look == "idle"
	var glyph: TextureRect = chip.get_node("Glyph")
	var texture: Texture2D = UnitGlyphs.texture(record.unit)
	if glyph.texture != texture: glyph.texture = texture
	var tint: Color = IDLE / Color(UnitGlyphs.COLOUR) if idle else Color.WHITE
	if glyph.self_modulate != tint: glyph.self_modulate = tint
	_style(chip.get_node("Track"), "panel", _looks.hollow if idle else _looks.track)
	var fill: ColorRect = chip.get_node("Track/Fill")
	var tone: Color = _looks.warn if record.look in ["slowed", "blocked"] else _colour
	if fill.color != tone: fill.color = tone
	_progress(fill, record.fraction)
	# The current run, as NEXT's ×N: a number beside a glyph counts that unit (user, 2026-11-23).
	var count: Label = chip.get_node("Count")
	count.visible = not record.runs.is_empty()
	if count.visible and count.text != str(record.runs[0].count): count.text = str(record.runs[0].count)
	(chip.get_node("Then") as Control).visible = record.runs.size() > 1
	var look: StyleBox = _looks.selected if record.id == _selected else _looks.normal
	for state: String in ["normal", "pressed"]: _style(chip, state, look)
	for state: String in ["hover", "hover_pressed"]: _style(chip, state, _looks.selected if record.id == _selected else _looks.hover)

static func _busy(record: Dictionary) -> bool:
	return record.look != "idle"

# Whole pixels from the track's bottom (upright) or left edge: a fractional edge rendered a pixel off the track's.
func _progress(fill: Control, fraction: float) -> void:
	var bar: Vector2 = UPRIGHT_BAR if upright else BAR
	var length: float = roundf(fraction * (bar.y if upright else bar.x))
	var rect := Rect2(0, bar.y - length, bar.x, length) if upright else Rect2(0, 0, length, bar.y)
	if fill.position != rect.position: fill.position = rect.position
	if fill.size != rect.size: fill.size = rect.size

# Each override write re-themes the control, so only a change may touch it.
static func _style(control: Control, state: String, style: StyleBox) -> void:
	if not control.has_theme_stylebox_override(state) or control.get_theme_stylebox(state) != style: control.add_theme_stylebox_override(state, style)

func _hover(control: Control, entered: bool) -> void:
	if not entered and _hovered != control: return
	_hovered = control if entered else null
	if entered: _hover_since = now_msec.call()
	_show_tip()

# The hint counts only frames it is seen in: shown, uncovered.
func _process(delta: float) -> void:
	if _hovered != null and not _tip.visible: _show_tip()
	if not _hint.visible: return
	if not covered.call(): _hint_left -= delta * 1000.0
	if _hint_left <= 0.0: _end_hint()
	else: _place_hint()

# The setting is read once, on the strip's first appearance; a hidden strip hides the hint, which waits.
func _follow_hint() -> void:
	if visible and _hint_left == HINT_UNREAD:
		var config := ConfigFile.new()
		_hint_left = HINT_GONE if config.load(AudioSettings.path) == OK and config.get_value(HINT_SECTION, HINT_KEY, false) == true else float(HINT_MSEC)
	_show_hint()

func _show_hint() -> void:
	var was: bool = _hint.visible
	_hint.visible = visible and _hint_left >= 0.0 and not notice_up
	if not _hint.visible: return
	if not was: _hint.reset_size()
	_place_hint()

func _end_hint() -> void:
	_hint_left = HINT_GONE
	_hint.visible = false
	save_hint_seen()

# Also for the capture tools, so their pictures show no hint.
static func save_hint_seen() -> void:
	var config := ConfigFile.new()
	config.load(AudioSettings.path)
	config.set_value(HINT_SECTION, HINT_KEY, true)
	config.save(AudioSettings.path)

# 8 under the strip, right-aligned with it, stepping left of a playtest helper.
func _place_hint() -> void:
	var strip: Rect2 = get_global_rect()
	var at: Vector2 = _clear_of_helpers(Rect2(Vector2(strip.end.x - _hint.size.x, strip.end.y + 8.0), _hint.size)).position
	if _hint.global_position != at: _hint.global_position = at

func _clear_of_helpers(at: Rect2) -> Rect2:
	for helper: Control in helpers:
		if helper.is_visible_in_tree() and at.intersects(helper.get_global_rect()): at.position.x = maxf(8.0, helper.get_global_rect().position.x - 8.0 - at.size.x)
	return at

# The decided tooltip rules: after 250 ms, at once on a neighbour while one is open, gone on a click or leaving.
func _show_tip() -> void:
	# Steps aside for an online notice, as the hint does.
	var shown: bool = _hovered != null and _hovered.is_visible_in_tree() and _hover_since >= 0 and not notice_up and (_tip_open or now_msec.call() - _hover_since >= TIP_DELAY_MSEC)
	_tip.visible = shown
	if not shown: return
	_tip_open = true
	var folded: bool = _hovered == _more
	var record: Dictionary = {} if folded else _hovered.get_meta("chip")
	var words: Array = [folded, "" if folded else Registry.kind(record.kind).display_name, "\n".join(_folded.map(HudModel.strip_hidden_line)) if folded else HudModel.strip_tip(record) + "\n" + HudModel.STRIP_HINT]
	# Each resize lays the card out again, so only new words may.
	if words != _tip_words:
		_tip_words = words
		var lines: Node = _tip.get_node("Lines")
		lines.get_node("Tag").visible = folded
		lines.get_node("Name").visible = not folded
		(lines.get_node("Name") as Label).text = words[1]
		(lines.get_node("Text") as Label).text = words[2]
		_tip.reset_size()
	_place_tip()

# 8 under the strip, from the chip's left, inside the screen and 8 left of a playtest helper it would cover.
func _place_tip() -> void:
	var chip: Rect2 = _hovered.get_global_rect()
	var at: Vector2 = _clear_of_helpers(Rect2(Vector2(clampf(chip.position.x, 8.0, get_viewport_rect().size.x - 8.0 - _tip.size.x), get_global_rect().end.y + 8.0), _tip.size)).position
	if _tip.global_position != at: _tip.global_position = at

# Two presses on one chip within the control groups' double tap also glide there.
func _press(chip: Button) -> void:
	# Under a menu, a result or the freeze card the click ends nothing and arms no double click.
	if covered.call(): return
	_hover_since = -1
	_tip_open = false
	_show_tip()
	var id: int = chip.get_meta("chip").id
	var now: int = now_msec.call()
	var jump: bool = id == _pressed_id and now - _pressed_at <= ControlGroups.DOUBLE_TAP_MSEC
	_pressed_id = -1 if jump else id
	_pressed_at = now
	if _hint_left >= 0.0: _end_hint()
	producer_pressed.emit(id, jump)

func reset() -> void:
	_pressed_id = -1
	_hovered = null
	_tip_open = false
	_show_tip()
