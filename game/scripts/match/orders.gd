extends RefCounted

const Iso = preload("res://scripts/presentation/isometric.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const HudModel = preload("res://scripts/match/hud_model.gd")

var selected_ids: Array[int] = []
var selected_building_id: int = -1
var inspected_id: int = -1
var menu: Array = []
var _screen: Node
var _selecting: bool = false
var _dragged: bool = false
var _start: Vector2
var _start_selection: Array[int] = []
var _shift: bool = false
var _double: bool = false
var _ctrl: bool = false
var _alt: bool = false
var _placement_kind: String = ""
var _pending_placement: String = ""
var _preview_origin: Vector2i
var _preview_key: Array = []
var _attack_move_mode: bool = false
var _awaiting_build: String = ""
# Any submit, re-arm or Esc after the build click bumps this, so a late refusal reopens placement only over an untouched selection.
var gestures: int = 0
var _awaiting_from: Array = []
var _answer: Dictionary = {}
# Headless reads of the cursor shape stay at the arrow, so tests swap this for a recorder.
static var set_cursor: Callable = Input.set_default_cursor_shape

func _init(screen: Node) -> void:
	_screen = screen

func handle(event: InputEvent) -> void:
	if not takes_orders(): return
	if event.is_action_pressed("deselect"):
		inspected_id = -1
		gestures += 1
	var mouse := event as InputEventMouse
	var on_hud: bool = mouse != null and _screen.hud.blocks(mouse.position)
	_hover(event, on_hud)
	# A press that began on the map ends over a panel: only a drag goes on there, never a click, an order or the ghost.
	if on_hud and not _selecting: return
	if _placement_kind.is_empty() and _combat_input(event): return
	if _economy_keys(event): return
	if not _placement_kind.is_empty():
		_placement_input(event)
		return
	if _building_input(event): return
	_selection_input(event, on_hud)
	if not is_selecting() and not _pending_placement.is_empty():
		var pending: String = _pending_placement
		_pending_placement = ""
		_enter_placement(pending)

func takes_orders() -> bool:
	return not _screen.shown_over() and not _screen.frozen() and not _screen._playtest.holds_match()

# Every arm and disarm goes through here, so the crosshair never outlives the mode.
func _set_attack_move(on: bool) -> void:
	if on: gestures += 1
	_attack_move_mode = on
	set_cursor.call(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func arm_attack_move() -> void:
	if not takes_orders() or busy() or selected_ids.is_empty(): return
	_set_attack_move(true)
	_screen._reshow()

func stop_selected() -> void:
	if not takes_orders() or busy() or selected_ids.is_empty(): return
	_set_attack_move(false)
	_screen._submit({"type":"stop","entity_ids":selected_ids.duplicate()})

func busy() -> bool:
	return _selecting or not _placement_kind.is_empty()

func escape_pending() -> bool:
	return _attack_move_mode or inspected_id != -1 or _selecting or not selected_ids.is_empty() or not _placement_kind.is_empty() or selected_building_id != -1 or not _pending_placement.is_empty()

func reset() -> void:
	selected_ids.clear()
	selected_building_id = -1
	inspected_id = -1
	_placement_kind = ""
	_pending_placement = ""
	_set_attack_move(false)
	_awaiting_build = ""
	_answer = {}
	_selecting = false
	_dragged = false

func prune(state: Dictionary) -> void:
	if selected_building_id != -1 and _screen._building(state, selected_building_id).is_empty(): selected_building_id = -1
	selected_ids.assign(selected_ids.filter(func(id: int) -> bool: return state.units.index_of(id) != -1))
	if HudModel.inspected(state, inspected_id).is_empty(): inspected_id = -1

func view_selection() -> Array[int]:
	var ids: Array[int] = []
	if selected_building_id != -1: ids.append(selected_building_id)
	else: ids.assign(selected_ids)
	return ids

func is_selecting() -> bool:
	return _selecting

func _combat_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and not is_selecting():
		if event.physical_keycode == HudModel.ORDER_KEYS.attack_move and not selected_ids.is_empty():
			arm_attack_move()
			return true
		if event.physical_keycode == HudModel.ORDER_KEYS.stop and not selected_ids.is_empty():
			stop_selected()
			return true
	if _attack_move_mode and (event.is_action_pressed("deselect") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)):
		_set_attack_move(false)
		_screen._reshow()
		return true
	if _attack_move_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_set_attack_move(false)
			var target: Vector2 = _ground(event)
			_screen._submit({"type":"attack_move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and _order_defence(event):
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting() and not selected_ids.is_empty():
		var enemy: int = _screen._view.pick_target(_screen._view.make_canvas_position_local(event.position), _screen.local_player)
		if enemy != -1:
			_screen._submit({"type":"attack","entity_ids":selected_ids.duplicate(),"target_id":enemy})
			return true
	return false

func _hover(event: InputEvent, on_hud: bool) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = -1 if on_hud else _screen._view.resolve_pick(_screen._view.make_canvas_position_local(event.position)).id
		if hovered != _screen._view.hovered_id():
			_screen._view.set_hovered(hovered)
			_screen._reshow()

func _economy_keys(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	if event.physical_keycode == KEY_B: return true
	var index: int = event.physical_keycode - KEY_1
	if index >= 0 and index < menu.size():
		_menu_choose(index,true)
		return true
	if event.physical_keycode == HudModel.ORDER_KEYS.produce:
		if not is_selecting() and _placement_kind.is_empty(): _produce_selected()
		return true
	if event.physical_keycode == HudModel.ORDER_KEYS.unload:
		_unload_selected()
		return true
	return false

func _placement_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_screen._perf.toggle()
		return
	if event.is_action_pressed("deselect"):
		_clear_placement()
	elif event is InputEventMouseMotion:
		_update_preview(_screen._view.make_canvas_position_local(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _clear_placement()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _awaiting_build.is_empty():
			_update_preview(_screen._view.make_canvas_position_local(event.position))
			# As Zero Hour: a spot this view already knows is refused is never sent, so no order voice plays.
			if _known_refused():
				_screen.refuse(_answer.error)
				return
			_screen._submit({"type":"build","builder_id":_builder(),"building_kind":_placement_kind,"origin":[_preview_origin.x,_preview_origin.y]})
			_awaiting_build = _placement_kind
			_awaiting_from = [_builder(), gestures]
			if _screen.driver.closes_placement_on_click(): _clear_placement()

func answered(answer: Dictionary) -> void:
	if _awaiting_build.is_empty() or answer.command.get("type") != "build": return
	var kind: String = _awaiting_build
	_awaiting_build = ""
	var online: bool = _screen.driver.closes_placement_on_click()
	if answer.ok and not online: _clear_placement()
	# A gesture begun since the click keeps its release; reopening would turn it into a build.
	elif not answer.ok and online and not busy() and [_builder(), gestures] == _awaiting_from: _enter_placement(kind)

func _building_input(event: InputEvent) -> bool:
	if event.is_action_pressed("deselect"):
		selected_building_id = -1
		_pending_placement = ""
	if event is InputEventMouseButton:
		var plane: Vector2 = _screen._view.make_canvas_position_local(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_selecting():
			var source: int = _screen._view.pick_source(plane)
			if _context_order(source if source != -1 else _screen._view.pick_object(plane)) or _set_rally(plane): return true
	return false

func _selection_input(event: InputEvent, on_hud: bool) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_screen._perf.toggle()
	elif event.is_action_pressed("deselect"):
		selected_ids.clear()
		_selecting = false
		_screen._selection_box.hide()
		_screen._reshow()
	elif event is InputEventMouseMotion and _selecting:
		_update_drag(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_selecting = true
				_dragged = false
				_start = event.position
				_start_selection = selected_ids.duplicate()
				_shift = event.shift_pressed
				_double = event.double_click
				_ctrl = event.ctrl_pressed
				_alt = event.alt_pressed
			elif _selecting:
				_finish_selection(event.position, on_hud)
		elif event.pressed and not _selecting:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					if not selected_ids.is_empty():
						_move(Iso.plane_to_world(_screen._view.make_canvas_position_local(event.position)))
				MOUSE_BUTTON_WHEEL_UP:
					_screen.change_zoom(1)
				MOUSE_BUTTON_WHEEL_DOWN:
					_screen.change_zoom(-1)

func _update_drag(point: Vector2) -> void:
	_dragged = _dragged or _start.distance_to(point) >= 6.0
	var rect := Rect2(_start, point - _start).abs()
	_screen._selection_box.position = rect.position
	_screen._selection_box.size = rect.size
	_screen._selection_box.visible = _dragged

func _finish_selection(point: Vector2, on_hud: bool) -> void:
	_update_drag(point)
	_selecting = false
	_screen._selection_box.hide()
	# A click released on a panel belongs to the HUD, even when the press was just beside it.
	if not _dragged and on_hud:
		_screen._reshow()
		return
	var picked: Array[int] = []
	var plane: Vector2 = _screen._view.make_canvas_position_local(point)
	var pick: Dictionary = {"tier": "ground", "id": -1}
	if _dragged:
		var from: Vector2 = _screen._view.make_canvas_position_local(_start)
		picked = _screen._view.pick_entities(Rect2(from, plane - from), _screen.hud.blocking_rects())
	else:
		pick = _screen._view.resolve_pick(plane)
	var own: bool = _owner(pick) == _screen.local_player
	selected_building_id = pick.id if pick.tier == "building" and own else -1
	inspected_id = pick.id if pick.tier != "ground" and not own else -1
	if selected_building_id != -1 or inspected_id != -1: selected_ids.clear()
	else: _select_units(pick, picked)
	_screen._reshow()

# Shift-click toggles one own unit; Shift on ground or a drag keeps what was selected at the press.
func _select_units(pick: Dictionary, picked: Array[int]) -> void:
	if pick.tier == "unit" and _double and not _ctrl: picked = _matching_ids(pick.id, _alt)
	elif pick.tier == "unit" and _shift and _start_selection.has(pick.id): _start_selection.erase(pick.id)
	elif pick.tier == "unit": picked.append(pick.id)
	selected_ids.clear()
	if _shift: selected_ids.assign(_start_selection)
	for id in picked:
		if not selected_ids.has(id): selected_ids.append(id)
	selected_ids.sort()

func _owner(pick: Dictionary) -> int:
	if pick.tier == "ground": return -1
	var found: Dictionary = HudModel.inspected(_screen.shown_state, pick.id)
	return found.get("owner", 0)

func _matching_ids(id: int, whole_map: bool) -> Array[int]:
	var view_rect: Rect2 = _screen._view.get_global_transform_with_canvas().affine_inverse() * _screen.get_viewport().get_visible_rect()
	var picked: Array[int] = []
	var base: Dictionary = _unit(id)
	if base.is_empty(): return picked
	for other: int in _screen._view.pick_entities(Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6) if whole_map else view_rect):
		var candidate: Dictionary = _unit(other)
		if not candidate.is_empty() and candidate.kind == base.kind and not candidate.inside:
			picked.append(other)
	return picked

func _unit(id: int) -> Dictionary:
	var rows: RefCounted = _screen.shown_state.units
	var i: int = rows.index_of(id)
	if i == -1: return {}
	var record: Dictionary = HudModel.unit_record(rows, i)
	record["inside"] = (rows.flags[i] & ViewRows.CONTAINED) != 0
	return record

func _move(target: Vector2) -> void:
	_screen._submit({"type":"move","entity_ids":selected_ids.duplicate(),"target":[target.x,target.y]})

func _hint_point(payload: Dictionary) -> Variant:
	if payload.type != "resume_build":
		if payload.type in ["move", "attack_move", "set_rally"]: return Vector2(payload.target[0], payload.target[1])
		return null
	var building: Dictionary = _screen._building(_screen.shown_state,payload.building_id)
	if building.is_empty(): return null
	return Vector2(building.origin[0],building.origin[1]) + Vector2(Definitions.building(building.kind).footprint) / 2.0

func _menu_choose(index: int, from_key: bool) -> void:
	if not takes_orders(): return
	var kind: String = menu[index]
	if selected_building_id != -1: _screen._submit({"type":"produce","building_id":selected_building_id,"unit_kind":kind})
	elif from_key and is_selecting(): _pending_placement = kind
	else: _enter_placement(kind)

func _builder() -> int:
	if selected_ids.size() != 1: return -1
	var unit: Dictionary = _unit(selected_ids[0])
	return unit.id if not unit.is_empty() and Registry.is_builder(unit.kind) and unit.owner == _screen.local_player else -1

func _enter_placement(kind: String) -> void:
	gestures += 1
	_set_attack_move(false)
	if _builder() == -1:
		_screen.refuse("Choose one builder", false)
		_screen._reshow()
		return
	_placement_kind = kind
	selected_building_id = -1
	_preview_key = []
	_answer = {}
	_screen.driver.request_preview({})
	_update_preview(_screen._view.get_local_mouse_position())
	_screen._reshow()

func _clear_placement() -> void:
	_placement_kind = ""
	_screen.driver.request_preview({})
	var empty: Array[Vector2i] = []
	_screen._view.set_build_preview(empty,false)
	_screen._reshow()

func _update_preview(plane: Vector2) -> void:
	_preview_origin = Vector2i(Iso.plane_to_world(plane).floor())
	var key: Array = [_placement_kind,_preview_origin,_screen.shown_state.tick]
	if key == _preview_key: return
	_preview_key = key
	_screen._view.set_build_preview(Construction.cells(_placement_kind,_preview_origin),_answer.get("ok",false))
	_screen.driver.request_preview({"player":_screen.local_player,"builder_id":_builder(),"kind":_placement_kind,"origin":_preview_origin})

func show_preview(answer: Dictionary) -> void:
	if _placement_kind.is_empty(): return
	if answer.get("kind") == _placement_kind:
		_answer = answer
		if answer.origin == _preview_origin: _screen._view.set_build_preview(Construction.cells(_placement_kind,_preview_origin),answer.ok)
	# A still mouse asks again each tick, so a click is judged against the shown tick.
	if _preview_key.size() == 3 and _preview_key[2] != _screen.shown_state.tick:
		_preview_key[2] = _screen.shown_state.tick
		_screen.driver.request_preview({"player":_screen.local_player,"builder_id":_builder(),"kind":_placement_kind,"origin":_preview_origin})

func _known_refused() -> bool:
	return not _answer.is_empty() and not _answer.ok and _answer.origin == _preview_origin and _answer.tick == _screen.shown_state.tick

func _context_order(id: int) -> bool:
	if selected_ids.is_empty(): return false
	var state: Dictionary = _screen.shown_state
	for source: Dictionary in state.sources:
		if source.id != id: continue
		var collectors: bool = true
		for unit_id: int in selected_ids:
			var unit: Dictionary = _unit(unit_id)
			if not unit.is_empty() and Registry.collects(unit.kind).is_empty(): collectors = false
		if collectors: _screen._submit({"type":"gather","entity_ids":selected_ids.duplicate(),"source_id":id})
		else:
			_screen.refuse("Choose homogeneous collector selection", false)
			_screen._reshow()
		return true
	var building: Dictionary = _screen._building(state,id)
	if selected_ids != [id] and HudModel.is_container(state, id, _screen.local_player):
		_screen._submit({"type":"enter","entity_ids":selected_ids.filter(func(unit_id: int) -> bool: return unit_id != id),"target_id":id})
		return true
	if not building.is_empty() and building.owner == _screen.local_player and not building.completed:
		if _builder() != -1: _screen._submit({"type":"resume_build","builder_id":_builder(),"building_id":id})
		else:
			_screen.refuse("Choose one builder", false)
			_screen._reshow()
		return true
	return false

func _unload_selected() -> void:
	if not takes_orders() or busy(): return
	_set_attack_move(false)
	var state: Dictionary = _screen.shown_state
	var id: int = selected_building_id if selected_building_id != -1 else (selected_ids[0] if selected_ids.size() == 1 else -1)
	if not HudModel.is_container(state, id, _screen.local_player):
		_screen.refuse("Select a container", false)
		_screen._reshow()
		return
	_screen._submit({"type":"unload","target_id":id})

func _set_rally(plane: Vector2) -> bool:
	var building: Dictionary = _screen._building(_screen.shown_state,selected_building_id)
	if building.is_empty() or building.owner != _screen.local_player or not Registry.can_rally(building.kind): return false
	var cell: Vector2 = Iso.plane_to_world(plane).floor() + Vector2(.5,.5)
	_screen._submit({"type":"set_rally","building_id":building.id,"target":[cell.x,cell.y]})
	return true

func _produce_selected() -> void:
	if not takes_orders(): return
	var state: Dictionary = _screen.shown_state
	var building: Dictionary = _screen._building(state,selected_building_id)
	if building.is_empty():
		_screen.refuse("Select a production building", false)
		_screen._reshow()
		return
	_screen._submit({"type":"produce","building_id":building.id,"unit_kind":_screen._production_kind(building, state)})

func _cancel_entry(id: int) -> void:
	if not takes_orders(): return
	_screen._submit({"type":"cancel_production","building_id":selected_building_id,"production_id":id})

func _cancel_build() -> void:
	if not takes_orders(): return
	_screen._submit({"type":"cancel_build","building_id":selected_building_id})

func _ground(event: InputEventMouseButton) -> Vector2:
	return Iso.plane_to_world(_screen._view.make_canvas_position_local(event.position))

func _order_defence(event: InputEventMouseButton) -> bool:
	var building: Dictionary = _screen._building(_screen.shown_state, selected_building_id)
	if building.is_empty() or building.owner != _screen.local_player or not building.completed or building.get("combat") == null: return false
	var enemy: int = _screen._view.pick_target(_screen._view.make_canvas_position_local(event.position), _screen.local_player)
	if enemy == -1: return false
	_screen._submit({"type":"defence_attack","building_id":building.id,"target_id":enemy})
	return true
