class_name ArenaMeans
extends Control
## The two ways to change the man at the table, and the instruments held: four small parts
## of the arena's page, each in its own zone of ArenaLayout, all drawn by this one element,
## which lies over the whole page and takes the pointer only on its parts.
##
## - The laboratory's instruments (`whose` "lab" in the rules' config): round medallions of
##   cream stock under the top rule at the left, each with its name under it. Room for three.
## - His instruments (`whose` "his"): seals of dark wax at the right, named the same way.
## - The draught, just above the lower rule at the left: the flask, open with its draught in
##   it when it can be drunk and corked when it cannot, and beside it in words what the next
##   drink costs (his first arrival, or a stain).
## - The salt, just above the lower rule at the right: one paper, open when a dose can be
##   taken now and folded shut when it cannot, with the doses held written beside it.
##
## Nothing but the medallions and the seals has stock under it: the flask, the paper and the
## words are drawn light, to read on Jekyll's slate and on Hyde's ink alike.
##
## Hovering the flask or the salt shows what it will do, or why it is refused, in a note
## over it, and before use marks what will change: hovering salt that can be taken outlines
## the paper as spent. What lies outside this element (the restraint as stored drops, the
## stored drops struck through) is for the arena to mark: `preview_changed` says which to
## show. Hovering an instrument shows its name and what it does in a note under it. Nothing
## asks "are you sure".
##
## Pressing the flask or the salt only sends `drink_pressed` or `salt_pressed`, and only when
## it can be used. What a drink and a dose do is the arena's.
##
## Nothing here works out a rule, and nothing moves at rest. `show_table(table, dials)` takes
## RulesView.table() and sets everything at once. The beats of a move then drive it, each call
## a coroutine to `await` that returns when its movement is over:
##
## - `tip_flask()`: the flask tips and empties, and stands up again empty.
## - `set_draught(draught)`: the flask is filled again and corked or uncorked, and the words
##   name the next drink's cost; `draught` is the table's {ok, why, cost}.
## - `open_paper()`: the paper is opened, its salt poured, and it is gone: doses −1.
## - `set_salt(salt)`: the paper unfolds or folds shut; `salt` is the table's {doses, ok, why}.
## - `set_instruments(keys)`: an instrument new to the list is laid in its place, one gone is
##   taken away.
## - `hop(key)`: an instrument hops (The Cane, on his Mania). `glint(key)`: a light crosses it
##   (the Cheque book, when it pays). `spot(key)` is the point just over it, on the page.

## The pointer is over the flask or the salt, and it can be used: "drink" or "salt". "" when it
## leaves, or over one that is refused. For the arena: "drink" outlines the restraint as
## stored drops; "salt" strikes the stored drops through.
signal preview_changed(kind: String)
signal drink_pressed
signal salt_pressed

const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

## A medallion's or a seal's radius, the distance from one's middle to the next, and how far
## under the zone's top and inside its outer side the first one's edge lies.
const ROUND_R := 34.0
const ROUND_PITCH := 76.0
const ROUND_INSET := Vector2(8.0, 6.0)
## An instrument's sketch is drawn this much smaller than it was sketched, to lie in the round.
const SKETCH_SCALE := 0.82
const NAME_SIZE := 11
## The flask is sketched about its round body's middle, with this radius and this neck, and
## drawn this much smaller.
const BULB_R := 25.0
const NECK_W := 12.0
const NECK_H := 23.0
const FLASK_SCALE := 0.55
## Where the draught's words begin, from the zone's left.
const WORDS_LEFT := 54.0
## The paper's size, and how far its middle lies inside the zone's right side.
const PAPER_SIZE := 28.0
const PAPER_FROM_RIGHT := 106.0
## The note of a hover.
const NOTE_W := 240.0
const NOTE_SIZE := 13
const NOTE_GAP := 8.0

## Seconds for each movement.
const TIP_TIME := 0.45
## How far the flask tips, in radians.
const TIP_ANGLE := 1.9
const POUR_TIME := 0.55
const RIGHT_TIME := 0.35
const FILL_TIME := 0.4
const CORK_TIME := 0.3
const OPEN_TIME := 0.35
const SPEND_TIME := 0.45
const FOLD_TIME := 0.3
const LAY_TIME := 0.35
const HOP_TIME := 0.4
const GLINT_TIME := 0.6

const PENCIL := Color(0.015, 0.025, 0.035)
const INK := Color(0.27, 0.07, 0.26)
const CREAM := Color(0.87, 0.81, 0.67)
const NOTE_CREAM := Color(0.95, 0.91, 0.80)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
## What is drawn and written straight on the page, and the same when it is refused.
const CHALK := Color(0.95, 0.9, 0.78)
const CHALK_DIM := Color(0.95, 0.9, 0.78, 0.55)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)
## A seal's wax, the part the die pressed flat, and what the die left raised.
const WAX := Color(0.36, 0.1, 0.33)
const WAX_PRESSED := Color(0.25, 0.06, 0.24)
const WAX_LINE := Color(0.9, 0.74, 0.86)
## The draught in the flask, and its cork.
const DRAUGHT := Color(0.62, 0.1, 0.14)
const CORK := Color(0.78, 0.6, 0.4)
const SALT := Color(0.99, 0.98, 0.95)

## Changes the lines and the edges a little while keeping the look.
@export var rng_seed := 23

var _dials: RulesDials = RulesDials.new()
var _draught := {"ok": false, "why": "", "cost": "first"}
var _salt := {"doses": 0, "ok": false, "why": ""}
var _keys: Array[String] = []

## How the flask is drawn: how far it has tipped (0 upright, 1 on its side), how full it is,
## how far the cork is in (0 out, 1 in).
var _tip := 0.0
var _level := 1.0
var _cork := 0.0
## How open the paper is (0 folded shut, 1 open), and how far it has gone while a dose is
## taken (0 there, 1 gone).
var _open := 0.0
var _spend := 0.0
## Each held instrument as drawn, in the order of `_keys`: {key, in (0 to 1), hop, glint}.
var _slots: Array[Dictionary] = []

## What the pointer is over: "", "flask", "salt", or "inst<n>" for the n-th of `_keys`.
var _hover := ""

var _back := Control.new()
var _fills := Control.new()
var _lines := Control.new()
var _text := Control.new()
var _heavy := FontVariation.new()
var _slanted := FontVariation.new()


func _init() -> void:
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1
	_slanted.base_font = ThemeDB.fallback_font
	_slanted.variation_embolden = 0.4
	_slanted.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.2, 1.0), Vector2.ZERO)
	_lines.material = LINE_MATERIAL
	_back.draw.connect(_draw_back)
	_fills.draw.connect(_draw_fills)
	_lines.draw.connect(_draw_lines)
	_text.draw.connect(_draw_text)
	for child: Control in [_back, _fills, _lines, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


# --- Setting it at once ---------------------------------------------------------------------


## Shows the draught, the salt and the instruments of a table, as RulesView.table() gives it,
## at once. `dials` are the run's, for the instruments' words.
func show_table(table: Dictionary, dials: RulesDials = null) -> void:
	if dials:
		_dials = dials
	var draught: Dictionary = table.draught
	_draught = {"ok": draught.ok, "why": draught.why, "cost": draught.cost}
	var salt: Dictionary = table.salt
	_salt = {"doses": int(salt.doses), "ok": salt.ok, "why": salt.why}
	_tip = 0.0
	_level = 1.0
	_cork = 0.0 if _draught.ok else 1.0
	_open = 1.0 if _salt.ok else 0.0
	_spend = 0.0
	_keys.clear()
	_slots.clear()
	var held: Array = table.instruments
	for i in mini(held.size(), RulesConfig.MAX_INSTRUMENTS):
		_keys.append(held[i])
		_slots.append(_slot(held[i], 1.0))
	_redraw()
	_hovered(_hover if _part_exists(_hover) else "")


## Shows a part's note as if the pointer were over it, for screenshots: "flask", "salt", an
## instrument's key, or "" for none.
func hover(part: String) -> void:
	var i := _keys.find(part)
	_hovered("inst%d" % i if i >= 0 else part)


## The point just over an instrument, on the page: where what it gives rises from. For one
## that is not held, the middle of his instruments' zone.
func spot(key: String) -> Vector2:
	var i := _keys.find(key)
	if i < 0:
		return get_global_transform() * ArenaLayout.instruments_right(size).get_center()
	return get_global_transform() * (_centre_of(i) + Vector2(0.0, -ROUND_R - 6.0))


# --- Movements ------------------------------------------------------------------------------


## The flask tips over and empties, then stands up again, empty.
func tip_flask() -> void:
	_cork = 0.0
	await _tween(TIP_TIME, func(t: float) -> void: _tip = t)
	await _tween(POUR_TIME, func(t: float) -> void: _level = 1.0 - t)
	await _tween(RIGHT_TIME, func(t: float) -> void: _tip = 1.0 - t)


## The flask is filled for the next drink and corked or uncorked as `draught` ({ok, why, cost}
## of the table) says; the words name the next drink's cost.
func set_draught(draught: Dictionary) -> void:
	var was_ok: bool = _draught.ok
	_draught = {"ok": draught.ok, "why": draught.why, "cost": draught.cost}
	if _level < 1.0:
		var from := _level
		await _tween(FILL_TIME, func(t: float) -> void: _level = lerpf(from, 1.0, t))
	if was_ok != _draught.ok or _cork != (0.0 if _draught.ok else 1.0):
		var from := _cork
		var to := 0.0 if _draught.ok else 1.0
		await _tween(CORK_TIME, func(t: float) -> void: _cork = lerpf(from, to, t))
	_redraw()
	_hovered(_hover)


## The paper is opened, its salt poured out, and it is gone. Doses −1.
func open_paper() -> void:
	if _salt.doses <= 0:
		return
	var from := _open
	if from < 1.0:
		await _tween(OPEN_TIME, func(t: float) -> void: _open = lerpf(from, 1.0, t))
	await _tween(SPEND_TIME, func(t: float) -> void: _spend = t)
	_salt.doses -= 1
	_spend = 0.0
	_redraw()


## The paper unfolds or folds shut as `salt` ({doses, ok, why} of the table) says.
func set_salt(salt: Dictionary) -> void:
	_salt = {"doses": int(salt.doses), "ok": salt.ok, "why": salt.why}
	var from := _open
	var to := 1.0 if _salt.ok else 0.0
	if from != to:
		await _tween(FOLD_TIME, func(t: float) -> void: _open = lerpf(from, to, t))
	_redraw()
	_hovered(_hover)


## Lays the instruments of `keys` in their places: a new one is laid down, one no longer held
## is taken away, the rest stay where they are.
func set_instruments(keys: Array) -> void:
	var going: Array[int] = []
	for i in _keys.size():
		if not keys.has(_keys[i]):
			going.append(i)
	if not going.is_empty():
		_hovered("")
		await _tween(LAY_TIME, func(t: float) -> void:
			for i in going:
				_slots[i].in = 1.0 - t)
	var kept: Array[String] = []
	for key in _keys:
		if keys.has(key):
			kept.append(key)
	var coming: Array[String] = []
	for key: String in keys:
		if not kept.has(key) and kept.size() + coming.size() < RulesConfig.MAX_INSTRUMENTS:
			coming.append(key)
	_keys = kept + coming
	_slots.clear()
	for key in _keys:
		_slots.append(_slot(key, 0.0 if coming.has(key) else 1.0))
	_redraw()
	if not coming.is_empty():
		await _tween(LAY_TIME, func(t: float) -> void:
			for i in _keys.size():
				if coming.has(_keys[i]):
					_slots[i].in = t)
	_hovered(_hover if _part_exists(_hover) else "")


## An instrument hops in its place.
func hop(key: String) -> void:
	var i := _keys.find(key)
	if i < 0:
		return
	var slot := _slots[i]
	await _tween(HOP_TIME, func(t: float) -> void: slot.hop = sin(t * PI))


## A light crosses an instrument.
func glint(key: String) -> void:
	var i := _keys.find(key)
	if i < 0:
		return
	var slot := _slots[i]
	await _tween(GLINT_TIME, func(t: float) -> void: slot.glint = t)
	slot.glint = 0.0
	_redraw()


# --- The pointer ----------------------------------------------------------------------------


func _has_point(point: Vector2) -> bool:
	return _part_at(point) != ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _part_at(event.position)
		if over != _hover:
			_hovered(over)
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var part := _part_at(button.position)
		if part == "flask" and _draught.ok:
			accept_event()
			drink_pressed.emit()
		elif part == "salt" and _salt.ok:
			accept_event()
			salt_pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hovered("")


func _part_at(point: Vector2) -> String:
	if _flask_zone().has_point(point):
		return "flask"
	if _salt_zone().has_point(point):
		return "salt"
	for i in _slots.size():
		# The medallion or the seal, and its name under it.
		var c := _centre_of(i)
		if point.distance_to(c) <= ROUND_R + 3.0 or Rect2(c.x - ROUND_R, c.y, ROUND_R * 2.0, ROUND_R + 30.0).has_point(point):
			return "inst%d" % i
	return ""


func _part_exists(part: String) -> bool:
	return not part.begins_with("inst") or int(part.substr(4)) < _keys.size()


## What the pointer is over changes: the note, the marks and the cursor follow.
func _hovered(part: String) -> void:
	var kind := _preview_kind()
	_hover = part
	var now := _preview_kind()
	var usable: bool = (part == "flask" and _draught.ok) or (part == "salt" and _salt.ok)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
	_redraw()
	if now != kind:
		preview_changed.emit(now)


func _preview_kind() -> String:
	if _hover == "flask" and _draught.ok:
		return "drink"
	if _hover == "salt" and _salt.ok:
		return "salt"
	return ""


# --- Words ----------------------------------------------------------------------------------


## The next drink's cost, as it is written beside the flask: short, to end before the hand's
## first card, which rises beside it.
func _cost_words() -> String:
	if _draught.cost == "first":
		return "He arrives: %d Roots join" % RulesConfig.FIRST_ARRIVAL.size()
	return "Stains a Paper Root"


## The doses held, as they are written beside the paper.
func _doses_words() -> String:
	return "SALT ×%d" % int(_salt.doses)


## The note a hover shows, as lines: [text, colour, heavy].
func _note_lines() -> Array:
	match _hover:
		"flask":
			if not _draught.ok:
				return [["The draught: corked.", PENCIL, true], [_draught.why, PENCIL, false]]
			var cost := "He arrives for the first time: %d of his Roots join the deck." \
					% RulesConfig.FIRST_ARRIVAL.size() if _draught.cost == "first" \
					else "One of Jekyll's Paper Roots is stained."
			return [["Drink: the restraint is stored.", INK, true], [cost, INK, false]]
		"salt":
			if not _salt.ok:
				return [["The salt: folded shut.", PENCIL, true], [_salt.why, PENCIL, false]]
			return [["Take a dose: Jekyll has the table.", PENCIL, true],
					["The stored restraint is lost.", PENCIL, false]]
	if _hover.begins_with("inst") and _part_exists(_hover):
		var key := _keys[int(_hover.substr(4))]
		var colour := INK if _his(key) else PENCIL
		return [[RulesConfig.INSTRUMENTS[key].name, colour, true], [RulesConfig.instrument_text(key, _dials), colour, false]]
	return []


## True for an instrument of his: a seal at the right. The laboratory's are medallions at the left.
static func _his(key: String) -> bool:
	return RulesConfig.INSTRUMENTS[key].whose == "his"


# --- Where things are -----------------------------------------------------------------------


func _slot(key: String, laid: float) -> Dictionary:
	return {"key": key, "in": laid, "hop": 0.0, "glint": 0.0}


## The middle of the i-th held instrument: the laboratory's in a row from the left of their
## zone, his in a row from the right of theirs.
func _centre_of(i: int) -> Vector2:
	var his := _his(_slots[i].key)
	var nth := 0
	for j in i:
		if _his(_slots[j].key) == his:
			nth += 1
	var along := ROUND_INSET.x + ROUND_R + nth * ROUND_PITCH
	if his:
		var zone := ArenaLayout.instruments_right(size)
		return Vector2(zone.end.x - along, zone.position.y + ROUND_INSET.y + ROUND_R)
	var zone := ArenaLayout.instruments_left(size)
	return Vector2(zone.position.x + along, zone.position.y + ROUND_INSET.y + ROUND_R)


## Where an instrument is drawn: its place, lifted by a hop, dropped in while laid.
func _slot_xform(i: int) -> Transform2D:
	var s: Dictionary = _slots[i]
	var laid: float = s.get("in", 1.0)
	var hop_by: float = s.get("hop", 0.0)
	var lift := Vector2(0.0, -14.0 * hop_by - 18.0 * (1.0 - laid))
	var turn := 0.08 * hop_by - 0.12 * (1.0 - laid)
	return Transform2D(turn, _centre_of(i) + lift)


func _flask_zone() -> Rect2:
	return ArenaLayout.draught(size)


func _salt_zone() -> Rect2:
	return ArenaLayout.salt(size)


## The middle of the flask's round body: the flask stands on the foot of its zone.
func _bulb_at() -> Vector2:
	var zone := _flask_zone()
	return Vector2(zone.position.x + 20.0, zone.end.y - 4.0 - BULB_R * FLASK_SCALE)


## The flask's frame: the bulb's middle, about which it tips to the right.
func _flask_xform() -> Transform2D:
	return Transform2D(_tip * TIP_ANGLE, Vector2(FLASK_SCALE, FLASK_SCALE), 0.0, _bulb_at())


## The middle of the paper of salt.
func _paper_at() -> Vector2:
	var zone := _salt_zone()
	return Vector2(zone.end.x - PAPER_FROM_RIGHT, zone.get_center().y)


func _tween(seconds: float, apply: Callable) -> void:
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(t: float) -> void:
		apply.call(t)
		_redraw(), 0.0, 1.0, seconds)
	await tw.finished


func _redraw() -> void:
	for child: Control in [_back, _fills, _lines, _text]:
		child.queue_redraw()


func _lay_out() -> void:
	for child: Control in [_back, _fills, _lines, _text]:
		child.size = size
	_redraw()


# --- Drawing --------------------------------------------------------------------------------


## The medallions' stock and the seals' wax with their shadows, and the note's card.
func _draw_back() -> void:
	var rng := RandomNumberGenerator.new()
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		# Its edge is its own, wherever in the row it lies.
		rng.seed = rng_seed + hash(s.key)
		var laid: float = s.in
		_back.draw_set_transform_matrix(_slot_xform(i))
		if _his(s.key):
			_card(_back, _blob(rng, ROUND_R + 1.0, 3.2, 7), Color(WAX, laid), Color(SHADOW, SHADOW.a * laid))
			_back.draw_colored_polygon(_blob(rng, ROUND_R - 7.0, 0.6, 3), Color(WAX_PRESSED, laid))
		else:
			_card(_back, _blob(rng, ROUND_R, 0.5, 3), Color(CREAM, laid), Color(SHADOW, SHADOW.a * laid))
		_back.draw_set_transform_matrix(Transform2D.IDENTITY)
	var lines := _note_lines()
	if not lines.is_empty():
		var box := _note_rect(lines)
		_back.draw_rect(Rect2(box.position + Vector2(3.0, 4.0), box.size), SHADOW)
		_back.draw_rect(box, NOTE_CREAM)


func _card(item: CanvasItem, edge: PackedVector2Array, colour: Color, shadow: Color = SHADOW) -> void:
	var under := PackedVector2Array()
	for p in edge:
		under.append(p + Vector2(3.0, 4.0))
	item.draw_colored_polygon(under, shadow)
	item.draw_colored_polygon(edge, colour)


## Where the note of what the pointer is over lies: over the flask or the salt, under an
## instrument's name, and always inside the page.
func _note_rect(lines: Array) -> Rect2:
	var height := 14.0
	for line: Array in lines:
		height += _note_line_height(line)
	var at: Vector2
	if _hover == "flask":
		at = _flask_zone().position + Vector2(0.0, -height - NOTE_GAP)
	elif _hover == "salt":
		at = Vector2(_salt_zone().end.x - NOTE_W, _salt_zone().position.y - height - NOTE_GAP)
	elif _his(_keys[int(_hover.substr(4))]):
		var zone := ArenaLayout.instruments_right(size)
		at = Vector2(zone.end.x - NOTE_W, zone.end.y + 4.0)
	else:
		var zone := ArenaLayout.instruments_left(size)
		at = Vector2(zone.position.x, zone.end.y + 4.0)
	return Rect2(at, Vector2(NOTE_W, height))


## How tall one of the note's lines is, wrapped to the note's width.
func _note_line_height(line: Array) -> float:
	var font: Font = _heavy if line[2] else _slanted
	return font.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - 20.0, NOTE_SIZE).y + 2.0


## The draught in the flask, the salt in the open paper, a glint's light.
func _draw_fills() -> void:
	var r := BULB_R * FLASK_SCALE
	if _level > 0.01:
		# The liquid lies level in the page whatever the flask's tilt: the flask's outline, as
		# it stands on the page, is cut by a level line, and what lies under it is the draught.
		var body := _flask_xform() * _bulb_path()
		var centre := _bulb_at()
		# Full, it reaches above the bulb's middle; tipped, no higher than the flask's mouth.
		var mouth_y := (_flask_xform() * Vector2(0.0, -BULB_R - NECK_H)).y
		var full := maxf(centre.y - r * 0.5, mouth_y if _tip > 0.5 else -INF)
		var top := lerpf(centre.y + r, full, _level)
		var under := PackedVector2Array([Vector2(centre.x - 100.0, top), Vector2(centre.x + 100.0, top),
				Vector2(centre.x + 100.0, top + 100.0), Vector2(centre.x - 100.0, top + 100.0)])
		for liquid in Geometry2D.intersect_polygons(body, under):
			_fills.draw_colored_polygon(liquid, Color(DRAUGHT, 0.9))
	# The draught pouring out while the flask lies over.
	if _tip > 0.8 and _level > 0.02 and _level < 0.99:
		var mouth := _flask_xform() * Vector2(0.0, -BULB_R - NECK_H)
		var floor_y := _bulb_at().y + r + 2.0
		_fills.draw_line(mouth, Vector2(mouth.x + 1.0, floor_y), Color(DRAUGHT, 0.7 * _level + 0.2), 2.0)
		_fills.draw_circle(Vector2(mouth.x + 1.0, floor_y), 2.0 + 2.0 * (1.0 - _level), Color(DRAUGHT, 0.7))
	if _salt.doses > 0:
		var heap := _open * (1.0 - _spend * 1.6)
		var c := _paper_at()
		if heap > 0.05:
			# A small mound of salt on the open paper.
			var mound := PackedVector2Array()
			for a in 9:
				var x := lerpf(-7.0, 7.0, a / 8.0)
				mound.append(c + Vector2(x, 4.0 - 7.0 * heap * (1.0 - pow(x / 7.0, 2.0))))
			_fills.draw_colored_polygon(mound, Color(SALT, 0.95))
		if _spend > 0.0:
			for g in 7:
				var fall := fposmod(_spend * 1.4 + g * 0.13, 1.0)
				_fills.draw_circle(c + Vector2(-6.0 + g * 2.0, 6.0 + fall * 14.0), 1.2, Color(SALT, 1.0 - fall))
	var round_edge := _circle(Vector2.ZERO, ROUND_R - 1.0, 24)
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		if s.glint <= 0.0:
			continue
		_fills.draw_set_transform_matrix(_slot_xform(i))
		var x := lerpf(-ROUND_R * 1.3, ROUND_R * 1.3, s.glint)
		var light := sin(s.glint * PI)
		# A slanting bar of light, as much of it as lies on the round.
		var bar := PackedVector2Array([Vector2(x - 10.0, -ROUND_R), Vector2(x + 2.0, -ROUND_R),
				Vector2(x - 6.0, ROUND_R), Vector2(x - 18.0, ROUND_R)])
		for lit in Geometry2D.intersect_polygons(bar, round_edge):
			_fills.draw_colored_polygon(lit, Color(1.0, 0.98, 0.88, 0.75 * light))
		if absf(x - 4.0) < ROUND_R - 8.0:
			_fills.draw_circle(Vector2(x - 4.0, -6.0), 4.0 * light, Color(1.0, 1.0, 0.95, light))
		_fills.draw_set_transform_matrix(Transform2D.IDENTITY)


## Every line: the flask and its cork, the paper, the instruments, and the mark of a hover.
func _draw_lines() -> void:
	var base := rng_seed * 1000
	# The flask.
	var flask := Pencil.new(base + 1)
	flask.colour = CHALK if _draught.ok else Color(CHALK, 0.8)
	_lines.draw_set_transform_matrix(_flask_xform())
	flask.stroke(_bulb_path(), 3.0, 0.5)
	flask.stroke(PackedVector2Array([Vector2(-NECK_W * 0.5 - 2.0, -BULB_R - NECK_H - 1.0),
			Vector2(NECK_W * 0.5 + 2.0, -BULB_R - NECK_H - 1.0)]), 2.6, 0.3)
	flask.stroke(PackedVector2Array([Vector2(-BULB_R * 0.55, -BULB_R * 0.1), Vector2(-BULB_R * 0.35, -BULB_R * 0.5)]), 1.6, 0.2)
	if _cork > 0.01:
		var rise := (1.0 - _cork) * -16.0
		var cork := Pencil.new(base + 2)
		cork.colour = Color(CORK, _cork)
		var top := -BULB_R - NECK_H + rise
		cork.stroke(PackedVector2Array([Vector2(-NECK_W * 0.5 + 0.5, top + 6.0), Vector2(-NECK_W * 0.5 - 1.5, top - 6.0),
				Vector2(NECK_W * 0.5 + 1.5, top - 6.0), Vector2(NECK_W * 0.5 - 0.5, top + 6.0)]), 2.6, 0.2)
		for h in 3:
			cork.stroke(PackedVector2Array([Vector2(-3.5 + h * 3.5, top - 4.0), Vector2(-4.5 + h * 3.5, top + 4.0)]), 1.6, 0.1)
		cork.draw(_lines)
	flask.draw(_lines)
	_lines.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The paper: open with salt in it, or folded shut; with no dose left, only its place.
	var paper := Pencil.new(base + 100)
	var c := _paper_at()
	if _salt.doses > 0:
		paper.colour = Color(CHALK, (1.0 - _spend) * (1.0 if _salt.ok or _open > 0.0 else 0.8))
		_paper_path(paper, c, _open)
	else:
		paper.colour = Color(CHALK, 0.4)
		var h := PAPER_SIZE * 0.4
		_dashed(paper, _rect_path(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)), 4.0, 4.0, 1.1)
	paper.draw(_lines)
	# Hovering salt that can be taken: the paper it will spend is outlined, and struck.
	if _hover == "salt" and _salt.ok and _salt.doses > 0:
		var mark := Pencil.new(base + 200)
		mark.colour = CHALK
		var h := PAPER_SIZE * 0.5 + 4.0
		_dashed(mark, _rect_path(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)), 4.0, 3.0, 1.5)
		mark.stroke(PackedVector2Array([c + Vector2(-h + 2.0, h - 2.0), c + Vector2(h - 2.0, -h + 2.0)]), 1.8, 0.3)
		mark.draw(_lines)
	# The instruments: a ruled ring on a medallion, the die's ring on a seal, and its sketch.
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var his := _his(s.key)
		var sketch := Pencil.new(base + 400 + hash(s.key) % 97)
		sketch.colour = Color(WAX_LINE if his else PENCIL, s.in)
		_lines.draw_set_transform_matrix(_slot_xform(i))
		if his:
			sketch.stroke(_circle(Vector2.ZERO, ROUND_R - 8.5, 26), 1.0, 0.3)
		else:
			sketch.stroke(_circle(Vector2.ZERO, ROUND_R - 2.5, 30), 1.8, 0.3)
			sketch.stroke(_circle(Vector2.ZERO, ROUND_R - 5.5, 28), 0.8, 0.2)
		sketch.draw(_lines)
		var drawing := Pencil.new(base + 600 + hash(s.key) % 97)
		drawing.colour = sketch.colour
		_lines.draw_set_transform_matrix(_slot_xform(i).scaled_local(Vector2(SKETCH_SCALE, SKETCH_SCALE)))
		_instrument(drawing, s.key)
		drawing.draw(_lines)
		_lines.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _hover.begins_with("inst") and _part_exists(_hover):
		var ring := Pencil.new(base + 500)
		ring.colour = CHALK
		ring.stroke(_circle(_centre_of(int(_hover.substr(4))), ROUND_R + 4.0, 30), 1.4, 0.3)
		ring.draw(_lines)
	elif _hover == "flask" or _hover == "salt":
		# A line under the part the pointer is on: bright when it can be used.
		var ring := Pencil.new(base + 510)
		var usable: bool = _draught.ok if _hover == "flask" else _salt.ok
		var zone := _flask_zone() if _hover == "flask" else _salt_zone()
		var from := zone.position.x if _hover == "flask" else _paper_at().x - PAPER_SIZE * 0.5 - 4.0
		var to := from + _words_width() + WORDS_LEFT if _hover == "flask" else zone.end.x
		ring.colour = CHALK if usable else CHALK_DIM
		ring.stroke(PackedVector2Array([Vector2(from, zone.end.y + 1.0), Vector2(to, zone.end.y)]), 1.6, 0.3)
		ring.draw(_lines)


## How wide the draught's words are.
func _words_width() -> float:
	return maxf(_slanted.get_string_size(_cost_words(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x,
			_heavy.get_string_size("DRAUGHT  corked", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x)


## The instruments' names, the draught's words and the doses held, and the hover's note.
func _draw_text() -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var name: String = RulesConfig.INSTRUMENTS[s.key].name
		var c := _centre_of(i)
		var width := ROUND_PITCH - 4.0
		var at := Vector2(c.x - width * 0.5, c.y + ROUND_R + 8.0 + _heavy.get_ascent(NAME_SIZE))
		_text.draw_multiline_string_outline(_heavy, at, name, HORIZONTAL_ALIGNMENT_CENTER, width, NAME_SIZE, 2, 5,
				Color(OUTLINE, OUTLINE.a * s.in))
		_text.draw_multiline_string(_heavy, at, name, HORIZONTAL_ALIGNMENT_CENTER, width, NAME_SIZE, 2, Color(CHALK, s.in))
	# The draught: its name, "corked" when it is, and what the next drink costs.
	var zone := _flask_zone()
	var at := zone.position + Vector2(WORDS_LEFT, 19.0)
	_write(_heavy, at, "DRAUGHT", 14, CHALK if _draught.ok else CHALK_DIM)
	if not _draught.ok:
		var past := _heavy.get_string_size("DRAUGHT  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
		_write(_slanted, at + Vector2(past, 0.0), "corked", 12, CHALK_DIM)
	_write(_slanted, at + Vector2(0.0, 17.0), _cost_words(), 12, CHALK if _draught.ok else CHALK_DIM)
	# The salt: the doses held, and under them why none can be taken now.
	zone = _salt_zone()
	var left := _paper_at().x + PAPER_SIZE * 0.5 + 10.0
	var doses: int = _salt.doses
	var why := "" if _salt.ok else ("no doses" if doses == 0 else "shut")
	_write(_heavy, Vector2(left, zone.position.y + (19.0 if why != "" else 27.0)), _doses_words(), 14,
			CHALK if _salt.ok else CHALK_DIM)
	if why != "":
		_write(_slanted, Vector2(left, zone.position.y + 36.0), why, 12, CHALK_DIM)
	var note := _note_lines()
	if note.is_empty():
		return
	var box := _note_rect(note)
	_text.draw_rect(box, PENCIL, false, 1.0)
	var y := box.position.y + 7.0
	for line: Array in note:
		var font: Font = _heavy if line[2] else _slanted
		_text.draw_multiline_string(font, Vector2(box.position.x + 10.0, y + font.get_ascent(NOTE_SIZE)), line[0],
				HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - 20.0, NOTE_SIZE, -1, line[1])
		y += _note_line_height(line)


## Words written straight on the page: light, with a dark edge, to read on slate and on ink.
func _write(font: Font, at: Vector2, words: String, font_size: int, colour: Color) -> void:
	_text.draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, Color(OUTLINE, OUTLINE.a * colour.a))
	_text.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)


# --- Shapes ---------------------------------------------------------------------------------


## A round's outline, about its own middle: a circle of radius `r` with an edge `rough`
## pixels uneven, in `lobes` slow waves and a little at random, as cut stock or pressed wax.
static func _blob(rng: RandomNumberGenerator, r: float, rough: float, lobes: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var phase := rng.randf_range(0.0, TAU)
	var steps := 36
	for k in steps:
		var a := TAU * k / steps
		var reach := r + rough * 0.7 * sin(a * lobes + phase) + rng.randf_range(-rough, rough) * 0.3
		out.append(Vector2(cos(a), sin(a)) * reach)
	return out


## The flask's outline in its own frame (the bulb's middle at the origin): the round body and
## the neck rising from it, as one closed path.
static func _bulb_path() -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := NECK_W * 0.5
	var start := asin(half / BULB_R)
	out.append(Vector2(half, -BULB_R - NECK_H))
	var steps := 26
	for k in steps + 1:
		var a := -PI * 0.5 + start + (TAU - start * 2.0) * k / steps
		out.append(Vector2(cos(a), sin(a)) * BULB_R)
	out.append(Vector2(-half, -BULB_R - NECK_H))
	return out


## A paper of salt around `c`: open, a square with its folds pressed flat; shut, folded into a
## packet with its flap down.
func _paper_path(pencil: Pencil, c: Vector2, open: float) -> void:
	var h := PAPER_SIZE * 0.5
	if open >= 0.5:
		# Unfolded: the paper lies as a diamond, its creases pressed flat, the salt on it.
		var w := h * lerpf(0.8, 1.0, (open - 0.5) * 2.0)
		var corners := PackedVector2Array([c + Vector2(0.0, -w), c + Vector2(w, 0.0), c + Vector2(0.0, w), c + Vector2(-w, 0.0)])
		var path := corners.duplicate()
		path.append(corners[0] + Vector2(0.5, 0.5))
		pencil.stroke(path, 1.5, 0.25)
		for k in 4:
			pencil.stroke(PackedVector2Array([corners[k], corners[k].lerp(c, 0.45)]), 0.8, 0.1)
		return
	# Folded shut: a small square packet, its flap down.
	var w := h * lerpf(0.72, 0.8, open * 2.0)
	pencil.stroke(_rect_path(Rect2(c - Vector2(w, w), Vector2(w, w) * 2.0)), 1.5, 0.25)
	pencil.stroke(PackedVector2Array([c + Vector2(-w, -w), c + Vector2(0.0, w * 0.35), c + Vector2(w, -w)]), 1.4, 0.2)
	pencil.stroke(PackedVector2Array([c + Vector2(-w, w), c + Vector2(-w * 0.2, w * 0.2)]), 0.9, 0.1)
	pencil.stroke(PackedVector2Array([c + Vector2(w, w), c + Vector2(w * 0.2, w * 0.2)]), 0.9, 0.1)


## The placeholder sketch of an instrument, about its card's middle.
func _instrument(pencil: Pencil, key: String) -> void:
	match key:
		"spirit":
			# A spirit lamp: a squat glass font, its wick holder, and a small flame.
			pencil.stroke(_ellipse(Vector2(0, 12), Vector2(17, 12), 22), 1.8, 0.4)
			pencil.stroke(PackedVector2Array([Vector2(-15, 22), Vector2(15, 22)]), 1.6, 0.3)
			pencil.stroke(_rect_path(Rect2(-4, -6, 8, 6)), 1.5, 0.2)
			pencil.stroke(_arc(Vector2(0, -15), Vector2(4, 8), PI * 0.15, PI * 1.85, 14), 1.4, 0.3)
		"notebook":
			# A notebook, closed, with its band and the edge of its pages.
			pencil.stroke(_rect_path(Rect2(-16, -22, 32, 44)), 1.8, 0.4)
			pencil.stroke(PackedVector2Array([Vector2(-12, -22), Vector2(-12, 22)]), 1.2, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(8, -22), Vector2(8, 22)]), 1.4, 0.3)
			for k in 3:
				pencil.stroke(PackedVector2Array([Vector2(-7, -10 + k * 7), Vector2(4, -10 + k * 7)]), 0.9, 0.2)
		"balance":
			# A balance: its post and foot, the beam, two pans on their strings.
			pencil.stroke(PackedVector2Array([Vector2(0, -20), Vector2(0, 22)]), 1.8, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(-10, 22), Vector2(10, 22)]), 1.8, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(-22, -16), Vector2(22, -18)]), 1.6, 0.3)
			for side: float in [-1.0, 1.0]:
				var x := 20.0 * side
				pencil.stroke(PackedVector2Array([Vector2(x, -17), Vector2(x - 7, 4)]), 0.9, 0.2)
				pencil.stroke(PackedVector2Array([Vector2(x, -17), Vector2(x + 7, 4)]), 0.9, 0.2)
				pencil.stroke(_arc(Vector2(x, 4), Vector2(9, 5), 0.0, PI, 10), 1.5, 0.2)
		"saucers":
			# Two glass saucers, one resting on the other.
			pencil.stroke(_ellipse(Vector2(0, 10), Vector2(24, 7), 24), 1.7, 0.3)
			pencil.stroke(_ellipse(Vector2(0, 10), Vector2(13, 3.5), 16), 1.0, 0.2)
			pencil.stroke(_ellipse(Vector2(-3, -6), Vector2(20, 6), 22), 1.6, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(-14, -9), Vector2(-8, -10)]), 0.9, 0.2)
		"hcane":
			# A heavy stick with a crook.
			pencil.stroke(PackedVector2Array([Vector2(-14, 26), Vector2(8, -14)]), 2.4, 0.4)
			pencil.stroke(_arc(Vector2(14, -14), Vector2(6, 7), PI, TAU + 0.6, 12), 2.4, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(-16, 22), Vector2(-12, 26)]), 1.4, 0.2)
		"cheque":
			# A cheque book, open on its first cheque, a signature across it.
			pencil.stroke(_rect_path(Rect2(-26, -14, 52, 28)), 1.7, 0.3)
			pencil.stroke(PackedVector2Array([Vector2(-14, -14), Vector2(-14, 14)]), 1.0, 0.2)
			pencil.stroke(PackedVector2Array([Vector2(-10, -6), Vector2(20, -6)]), 0.9, 0.2)
			var sign := PackedVector2Array()
			for k in 13:
				sign.append(Vector2(-6 + k * 2.0, 6 + sin(k * 1.3) * 3.0))
			pencil.stroke(sign, 1.3, 0.2)
		_:
			pencil.stroke(_circle(Vector2.ZERO, 16.0, 16), 1.6, 0.3)


## Strokes `path` as dashes of `on` pixels with `off` pixels between.
static func _dashed(pencil: Pencil, path: PackedVector2Array, on: float, off: float, width: float) -> void:
	var dash := PackedVector2Array()
	var along := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		var d := 0.0
		while d <= length:
			if fposmod(along + d, on + off) < on:
				dash.append(a.lerp(b, d / length))
			elif dash.size() > 0:
				pencil.stroke(dash, width, 0.1)
				dash = PackedVector2Array()
			d += 1.0
		along += length
	pencil.stroke(dash, width, 0.1)


static func _circle(c: Vector2, r: float, steps: int) -> PackedVector2Array:
	return _ellipse(c, Vector2(r, r), steps)


static func _ellipse(c: Vector2, r: Vector2, steps: int) -> PackedVector2Array:
	return _arc(c, r, -PI * 0.5, PI * 1.5 + 0.25, steps)


static func _arc(c: Vector2, r: Vector2, from: float, to: float, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps + 1:
		var a := lerpf(from, to, float(k) / steps)
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


static func _rect_path(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
			r.position + Vector2(0.0, -1.0)])
