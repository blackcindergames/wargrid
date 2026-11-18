extends Control

const LabLook = preload("res://scripts/lab/lab_look.gd")
const WorldView = preload("res://scripts/presentation/world_view.gd")

const SCREEN := Vector2(1280, 800)
const STATES: Array[StringName] = [&"one", &"many", &"building", &"enemy", &"pile", &"low_power"]
# hud.js:44 KINDS: name, count, health percent.
const KINDS: Array = [
	["Medium Tank", 36, 82], ["Rotary Gun Tank", 24, 64], ["Militia", 24, 91],
	["Anti-Tank Trooper", 12, 45], ["Supply Truck", 12, 100], ["Bulldozer", 12, 100],
]
const PANEL_X: Array[float] = [0.0, 416.0]
const STRIP_Y: Array[float] = [8.0, 48.0]
const PANEL_WIDTH := 408.0
const ROW_SIZE := Vector2(186, 26)

var _tokens: Dictionary = {}
var _number_size: int = 13
var _labels: Array[Label] = []
var _numbers: Array[Label] = []
var _panel: PanelContainer
var _strip: PanelContainer

func show_state(state: StringName, tokens: Dictionary, number_size: int, slot: int, letter: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tokens = tokens
	_number_size = number_size
	_labels.clear()
	_numbers.clear()
	size = SCREEN
	_add_column(state, slot, letter)
	_strip = _top_strip(state == &"low_power")
	var strip_row := _row(8)
	strip_row.position = Vector2(8, STRIP_Y[slot])
	strip_row.add_child(_strip)
	if not letter.is_empty():
		var tag := _letter_tag(letter)
		tag.name = "StripLetter"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip_row.add_child(tag)
	add_child(strip_row)
	if slot == 0: add_child(_ally_chip())

func panel_rect() -> Rect2:
	return _panel.get_global_rect()

func strip_rect() -> Rect2:
	return _strip.get_global_rect()

func labels() -> Array[Label]:
	return _labels

func number_labels() -> Array[Label]:
	return _numbers

func _add_column(state: StringName, slot: int, letter: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = PANEL_X[slot]
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if not letter.is_empty(): column.add_child(_letter_tag(letter))
	_panel = _selection_panel(state)
	column.add_child(_panel)
	add_child(column)

func _letter_tag(letter: String) -> PanelContainer:
	var tag := _slab(_tokens.bg, 1, Vector4(4, 8, 4, 8))
	tag.name = "Letter"
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_child(_label(letter, LabLook.font(700), 12, _tokens.text))
	return tag

# hud-v5-layout.md "Selection panel": borders top and right, padding 12 16 measured from the outer edge.
func _selection_panel(state: StringName) -> PanelContainer:
	var panel := _slab(_tokens.bg, 0, Vector4(1, 1, 0, 0))
	panel.name = "Panel"
	panel.custom_minimum_size.x = PANEL_WIDTH
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.border_width_top = 1
	style.border_width_right = 1
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var edge := ColorRect.new()
	edge.name = "Edge"
	edge.color = _tokens.enemy if state == &"enemy" else _tokens.line if state == &"pile" else _tokens.you
	edge.custom_minimum_size.x = 4
	inner.add_child(edge)
	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.add_theme_constant_override("margin_top", 11)
	padding.add_theme_constant_override("margin_right", 15)
	padding.add_theme_constant_override("margin_bottom", 12)
	padding.add_child(_body(state))
	inner.add_child(padding)
	panel.add_child(inner)
	return panel

func _body(state: StringName) -> Control:
	match state:
		&"one": return _identity("Medium Tank", 180, 400)
		&"many": return _many()
		&"building": return _identity("Vehicle Factory", 1240, 2000, true)
		&"enemy": return _identity("Battle Tank", 312, 480)
		&"pile": return _pile()
	return _identity("Bulldozer", 250, 250)

# hud.js:155-158 identity, hud.js:182-185 site: name row, optional progress row, health row.
func _identity(unit_name: String, hp: int, max_hp: int, site: bool = false) -> VBoxContainer:
	var block := _stack(8)
	var name_row := _row(8)
	var title := _title(unit_name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(title)
	if site: name_row.add_child(_caps("UNDER CONSTRUCTION", _tokens.muted))
	block.add_child(name_row)
	if site: block.add_child(_bar_row(0.62, _tokens.you, "62 %"))
	var fraction: float = float(hp) / max_hp
	block.add_child(_bar_row(fraction, WorldView.health_color(fraction), "%s / %s" % [_grouped(hp), _grouped(max_hp)]))
	return block

func _bar_row(fraction: float, fill: Color, value: String) -> HBoxContainer:
	var row := _row(8)
	var bar := _bar(Vector2(160, 6), fraction, fill)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(_number(value, _tokens.muted))
	return row

func _many() -> VBoxContainer:
	var block := _stack(8)
	# hud.css .hd: the 14 px title sits in an 18 px header row, so it keeps its untrimmed height.
	block.add_child(_label("120 selected · 6 kinds", LabLook.font(700), 14, _tokens.text))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for kind: Array in KINDS: grid.add_child(_kind_row(kind[0], kind[1], kind[2] / 100.0))
	block.add_child(grid)
	return block

# hud.css .krow: padding 0 8 4, name flexes, count right-aligned in 28, 3 px bar on the bottom edge.
func _kind_row(kind: String, count: int, fraction: float) -> PanelContainer:
	var row := _slab(_tokens.btn, 0, Vector4.ZERO)
	row.custom_minimum_size = ROW_SIZE
	var stack := _stack(1)
	var line := _row(4)
	line.custom_minimum_size.y = 22
	var padded := MarginContainer.new()
	padded.add_theme_constant_override("margin_left", 8)
	padded.add_theme_constant_override("margin_right", 8)
	var label := _label(kind, LabLook.font(600), 13, _tokens.text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var number := _number(str(count), _tokens.text)
	number.custom_minimum_size.x = 28
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(number)
	padded.add_child(line)
	stack.add_child(padded)
	stack.add_child(_bar(Vector2(0, 3), fraction, WorldView.health_color(fraction)))
	row.add_child(stack)
	return row

# design-answers-2026-11-08.md:1112: the pile shows only CREDITS LEFT.
func _pile() -> VBoxContainer:
	var block := _stack(8)
	block.add_child(_title("Supply Pile"))
	var line := _row(8)
	var key := _caps("CREDITS LEFT", _tokens.muted)
	key.custom_minimum_size.x = 112
	line.add_child(key)
	line.add_child(_number("10,650", _tokens.text))
	block.add_child(line)
	return block

# hud.js:117-135 top strip; low_power is the Rotary Gun Tower forecast of hud-v5-layout.md.
func _top_strip(forecast: bool) -> PanelContainer:
	var strip := _slab(_tokens.bg, 1, Vector4(0, 8, 0, 8))
	strip.name = "Strip"
	strip.custom_minimum_size.y = 32
	var groups := _row(24)
	var credits := _row(8)
	credits.add_child(_caps("CREDITS", _tokens.muted))
	var credits_value := _label("4,800", LabLook.font(700), 16, _tokens.text)
	credits.add_child(_forecast(credits_value, "3,600", 16) if forecast else credits_value)
	groups.add_child(credits)
	var power := _row(8)
	power.add_child(_caps("POWER", _tokens.muted))
	power.add_child(_forecast(_number("8", _tokens.text), "11 / 10", _number_size) if forecast else _number("8 / 10", _tokens.text))
	if forecast: power.add_child(_caps("LOW POWER", _tokens.amber))
	groups.add_child(power)
	strip.add_child(groups)
	return strip

func _forecast(before: Label, after: String, font_size: int) -> HBoxContainer:
	# A word space at the value's size, as in hud.js `${value} → ${value}`.
	var value := _row(4)
	value.add_child(before)
	value.add_child(_label("→", LabLook.font(400), font_size, _tokens.hint))
	var after_label := _label(after, LabLook.font(700), font_size, _tokens.text)
	if font_size == _number_size: _numbers.append(after_label)
	value.add_child(after_label)
	return value

func _ally_chip() -> PanelContainer:
	var chip := _slab(_tokens.bg, 1, Vector4(0, 8, 0, 8))
	chip.name = "Ally"
	chip.custom_minimum_size.y = 32
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -8
	chip.offset_right = -8
	chip.offset_top = 8
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var line := _row(8)
	line.add_child(_caps("ALLY", _tokens.muted))
	var discs := _row(4)
	# hud.js:89-98: the ally's minimap dot, beside the palette A green it is judged against.
	for color: Color in [_tokens.ally, LabLook.PALETTE_A[2]]: discs.add_child(_disc(color))
	line.add_child(discs)
	chip.add_child(line)
	return chip

func _disc(color: Color) -> Panel:
	var disc := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	disc.add_theme_stylebox_override("panel", style)
	disc.custom_minimum_size = Vector2(8, 8)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return disc

# margins are top, right, bottom, left, measured from the outer edge as in hud.js slab().
func _slab(fill: Color, border: int, margins: Vector4) -> PanelContainer:
	var slab := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = _tokens.line
	style.set_border_width_all(border)
	style.content_margin_top = margins.x
	style.content_margin_right = margins.y
	style.content_margin_bottom = margins.z
	style.content_margin_left = margins.w
	slab.add_theme_stylebox_override("panel", style)
	return slab

func _bar(bar_size: Vector2, fraction: float, fill: Color) -> ColorRect:
	var track := ColorRect.new()
	track.name = "Track"
	track.color = _tokens.well
	track.custom_minimum_size = bar_size
	var bar := ColorRect.new()
	bar.color = fill
	bar.anchor_bottom = 1.0
	bar.anchor_right = fraction
	track.add_child(bar)
	return track

func _stack(separation: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", separation)
	return stack

func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row

# hud.css .nm: 14 px at line height 14, so the font's 4 px of leading is split above and below.
func _title(text: String) -> Label:
	return _label(text, _trimmed(LabLook.font(700), 2, 2), 14, _tokens.text)

# hud.css .lab: 12/700 uppercase, 0.1 em spacing, line height 14 against the font's 15.
func _caps(text: String, color: Color) -> Label:
	return _label(text, _trimmed(LabLook.font(700, 1), 0, 1), 12, color)

func _number(text: String, color: Color) -> Label:
	var label := _label(text, LabLook.font(700), _number_size, color)
	_numbers.append(label)
	return label

func _label(text: String, font: FontVariation, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_labels.append(label)
	return label

static func _trimmed(font: FontVariation, top: int, bottom: int) -> FontVariation:
	var trimmed: FontVariation = font.duplicate()
	trimmed.spacing_top = -top
	trimmed.spacing_bottom = -bottom
	return trimmed

static func _grouped(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(-3)
	return digits + result
