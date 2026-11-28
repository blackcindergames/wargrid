extends PanelContainer

const Model = preload("res://scripts/match/faction_guide_model.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const UnitGlyphs = preload("res://scripts/presentation/unit_glyphs.gd")
const GAME_THEME = preload("res://ui/game_theme.tres")
signal back_requested
const STATS: Array = [["COST", "cost"], ["TIME", "time"], ["HEALTH", "health"], ["SPEED", "speed"], ["RANGE", "range"], ["VISION", "vision"]]
const CLASSES := {"infantry": "Infantry", "vehicle": "Vehicle", "air": "Aircraft"}
const NOTE := "Counters: who wins a straight fight when both sides spend the same credits; close fights are not listed. Range, splash, crushing and groups are not counted. The Rotary Gun Tank is counted once its guns spin up (1.6 s); FRC units with their base weapon, before salvage upgrades. Speed in cells a second; range and vision in cells."
var faction: String = Model.FACTIONS[0]
var yours: String = ""
var selected: String = ""
var _tabs: Dictionary = {}
var _hint: Label
var _title: Label
var _yours_mark: Label
var _roster: VBoxContainer
var _card: VBoxContainer

func _init() -> void:
	name = "FactionGuide"
	theme = GAME_THEME
	theme_type_variation = &"HudSmallPanel"
	custom_minimum_size = Vector2(1000, 0)
	var margin := MarginContainer.new()
	for side: Array in [["left", 12], ["top", 8], ["right", 12], ["bottom", 8]]: margin.add_theme_constant_override("margin_" + side[0], side[1])
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	page.add_child(_head())
	var line := HBoxContainer.new()
	_title = _label("", &"HudTitle")
	_yours_mark = _label("your faction", &"HudHint")
	line.add_child(_title)
	line.add_child(_yours_mark)
	page.add_child(line)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	page.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 240
	_roster = VBoxContainer.new()
	_roster.name = "Roster"
	_roster.add_theme_constant_override("separation", 4)
	left.add_child(_roster)
	left.add_child(_label("Click a unit, or ↑ ↓", &"HudHint"))
	body.add_child(left)
	var card_panel := PanelContainer.new()
	card_panel.theme_type_variation = &"HudSmallPanel"
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]: card_margin.add_theme_constant_override("margin_" + side, 12)
	card_panel.add_child(card_margin)
	_card = VBoxContainer.new()
	_card.name = "Card"
	_card.add_theme_constant_override("separation", 8)
	card_margin.add_child(_card)
	body.add_child(card_panel)
	var note: Label = _label(NOTE, &"HudHint")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 976
	page.add_child(note)
	show_faction(faction, yours)

# Random picks open on USA with nothing marked yours.
func show_faction(shown: String, own: String = yours) -> void:
	faction = shown if Model.FACTIONS.has(shown) else Model.FACTIONS[0]
	yours = own
	for id: String in _tabs: (_tabs[id] as Button).set_pressed_no_signal(id == faction)
	_title.text = Registry.faction(faction).display_name
	_yours_mark.visible = faction == yours
	for child: Node in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	for kind: String in Model.roster(faction): _roster.add_child(_roster_row(kind, group))
	select(Model.roster(faction)[0])

func select(kind: String) -> void:
	selected = kind
	for row: Button in _roster.get_children(): row.set_pressed_no_signal(row.name == kind)
	for child: Node in _card.get_children():
		_card.remove_child(child)
		child.queue_free()
	_fill_card(kind)

func _select_once(kind: String) -> void:
	if selected != kind: select(kind)

func focus_tab() -> void:
	(_tabs[faction] as Button).grab_focus()

func _head() -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.name = "Back"
	back.theme_type_variation = &"HudSmallButton"
	back.text = "‹ Back"
	back.pressed.connect(back_requested.emit)
	head.add_child(back)
	var heading: Label = _label("FACTION GUIDE", &"HudTitle")
	heading.add_theme_font_size_override("font_size", 14)
	head.add_child(heading)
	for id: String in Model.FACTIONS:
		var tab := Button.new()
		tab.name = "Tab_" + id
		tab.theme_type_variation = &"HudSmallToggle"
		tab.toggle_mode = true
		tab.text = Registry.faction(id).short_name
		tab.custom_minimum_size.x = 64
		tab.pressed.connect(func() -> void: show_faction(id))
		_tabs[id] = tab
		head.add_child(tab)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_hint = _label("Esc: back", &"HudHint")
	head.add_child(_hint)
	return head

func _roster_row(kind: String, group: ButtonGroup) -> Button:
	var row := Button.new()
	row.name = kind
	row.theme_type_variation = &"HudSmallToggle"
	row.toggle_mode = true
	row.button_group = group
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.icon = UnitGlyphs.texture(kind)
	row.expand_icon = true
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("icon_max_width", 32)
	row.text = "%s\n%s · %d" % [Registry.kind(kind).display_name, _class_words(kind), Registry.kind(kind).cost]
	row.pressed.connect(select.bind(kind))
	row.focus_entered.connect(_select_once.bind(kind))
	return row

func _fill_card(kind: String) -> void:
	var row: Dictionary = Registry.kind(kind)
	var facts: Dictionary = Model.facts(kind)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_glyph(kind, 48))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	var title: Label = _label(row.display_name, &"HudTitle")
	title.name = "Name"
	title.add_theme_font_size_override("font_size", 16)
	names.add_child(title)
	names.add_child(_label(_class_words(kind) + (" · %d per order" % row.quantity if row.get("quantity", 1) > 1 else ""), &"HudHint"))
	head.add_child(names)
	_card.add_child(head)
	var stats := GridContainer.new()
	stats.columns = STATS.size()
	stats.add_theme_constant_override("h_separation", 24)
	for stat: Array in STATS: stats.add_child(_label(stat[0], &"HudLabel"))
	for stat: Array in STATS: stats.add_child(_label(facts[stat[1]], &"HudNumber"))
	_card.add_child(stats)
	var trained: Label = _label("Trained at %s%s" % [facts.trained_at, " · needs " + facts.needs if not facts.needs.is_empty() else ""], &"HudSmallLabel")
	trained.name = "Trained"
	_card.add_child(trained)
	_card.add_child(HSeparator.new())
	if Model.is_worker(kind):
		_card.add_child(_label(" · ".join(["Builds your base", "Gathers supplies"].filter(func(job: String) -> bool: return Registry.is_builder(kind) if job.begins_with("Builds") else not Registry.collects(kind).is_empty())), &"HudSmallLabel"))
		return
	_card.add_child(_counter_grid(Model.counters(kind)))

# Row labels on the left of all three faction columns, so every column reads under Beats and Weak against (owner's note on layout A).
func _counter_grid(counters: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Counters"
	grid.columns = 1 + Model.FACTIONS.size()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(Control.new())
	for id: String in Model.FACTIONS:
		var head: Label = _label(Registry.faction(id).short_name + (" · you" if id == yours else ""), &"HudTitle" if id == yours else &"HudLabel")
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(head)
	for part: Array in [["BEATS", "beats"], ["WEAK AGAINST", "weak"]]:
		var verb: Label = _label(part[0], &"HudLabel")
		verb.name = part[1].capitalize()
		verb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(verb)
		for id: String in Model.FACTIONS: grid.add_child(_unit_list(counters[part[1]][id]))
	return grid

func _unit_list(kinds: Array) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	if kinds.is_empty(): list.add_child(_label("–", &"HudHint"))
	for kind: String in kinds:
		var line := HBoxContainer.new()
		line.add_child(_glyph(kind, 20))
		line.add_child(_label(Registry.kind(kind).display_name, &"HudRow"))
		list.add_child(line)
	return list

func _glyph(kind: String, edge: float) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = UnitGlyphs.texture(kind)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(edge, edge)
	return glyph

static func _class_words(kind: String) -> String:
	return CLASSES.get(Registry.kind(kind)["class"], "")

func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	# The mock-up's titles and names sit a deliberate step above the HUD's 12 px.
	if GAME_THEME.has_font_size(&"font_size", variation): label.add_theme_font_size_override("font_size", GAME_THEME.get_font_size(&"font_size", variation))
	return label
