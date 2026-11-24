class_name ArenaMeans
extends Control
## The two ways to change the man at the table, for the top right of the arena's page: the
## flask of the draught and the papers of salt, with the instruments held above them.
##
## That corner lies under Hyde's ink, so everything here sits on cream tags and card stock.
##
## - The flask, on its tag: open with its draught in it when it can be drunk, corked when it
##   cannot. The tag names what the next drink costs (his first arrival, or a stain) at all times.
## - The salt, on its tag: one paper a dose, open when a dose can be taken now, folded shut
##   when it cannot, with the doses held written under them.
## - The instruments: up to three cards of stock in a row, an empty place drawn faint.
##
## Hovering the flask or the salt shows what it will do, or why it is refused, in a note under
## the tags, and before use marks what will change (doc: before a drink or a dose): hovering
## salt that can be taken outlines one paper as spent. What lies outside this element (the
## restraint as stored drops, the stored drops struck through) is for the arena to mark on
## the left column: `preview_changed` says which to show. Hovering an instrument shows its name
## and what it does. Nothing asks "are you sure".
##
## Pressing the flask or the salt only sends `drink_pressed` or `salt_pressed`, and only when
## it can be used. What a drink and a dose do is the arena's.
##
## Nothing here works out a rule, and nothing moves at rest. `show_table(table, dials)` takes
## RulesView.table() and sets everything at once. The beats of a move then drive it, each call
## a coroutine to `await` that returns when its movement is over:
##
## - `tip_flask()`: the flask tips and empties, and stands up again empty.
## - `set_draught(draught)`: the flask is filled again and corked or uncorked, and the tag
##   names the next drink's cost; `draught` is the table's {ok, why, cost}.
## - `open_paper()`: one paper is opened, its salt poured, and it is gone: doses −1.
## - `set_salt(salt)`: the papers unfold or fold shut; `salt` is the table's {doses, ok, why}.
## - `set_instruments(keys)`: an instrument new to the list is laid in its place, one gone is
##   taken away.
## - `hop(key)`: an instrument hops (The Cane, on his Mania). `glint(key)`: a light crosses it
##   (the Cheque book, when it pays).

## The pointer is over the flask or the salt, and it can be used: "drink" or "salt". "" when it
## leaves, or over one that is refused. For the left column: "drink" outlines the restraint as
## stored drops; "salt" strikes the stored drops through.
signal preview_changed(kind: String)
signal drink_pressed
signal salt_pressed

const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

## The element's size. The note a hover shows lies under it, outside this size.
const SIZE := Vector2(244.0, 246.0)
## The instruments: three places in a row along the top.
const SLOT_SIZE := Vector2(72.0, 72.0)
const SLOT_GAP := 10.0
const SLOT_TOP := 4.0
## The two tags under them.
const FLASK_TAG := Rect2(4.0, 92.0, 112.0, 150.0)
const SALT_TAG := Rect2(128.0, 92.0, 112.0, 150.0)
## Inside the flask's tag: the middle of the flask's round body and its radius.
const BULB_AT := Vector2(46.0, 80.0)
const BULB_R := 25.0
const NECK_W := 12.0
const NECK_H := 23.0
## Inside the salt's tag: the middle of the papers, a paper's size and their pitch.
const PAPERS_AT := Vector2(56.0, 74.0)
const PAPER_SIZE := 28.0
const PAPER_PITCH := Vector2(34.0, 36.0)
const PAPERS_A_ROW := 3
## Papers drawn at most; beyond that only the number says how many.
const PAPERS_MAX := 6
## The note under the tags.
const NOTE_TOP := 252.0
const NOTE_W := 260.0
const NOTE_SIZE := 13

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
const LABEL := Color(0.33, 0.28, 0.27)
## The draught in the flask, and its cork.
const DRAUGHT := Color(0.52, 0.08, 0.12)
const CORK := Color(0.56, 0.40, 0.25)
const SALT := Color(0.99, 0.98, 0.95)

## Changes the lines and the tags' edges a little while keeping the look.
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
## How open the papers are (0 folded shut, 1 open); how far the spent paper has gone (0 there,
## 1 gone); how many papers are drawn, a fraction while one is going.
var _open := 0.0
var _spend := 0.0
var _papers_shown := 0.0
## Each place's instrument as drawn: {key, in (0 to 1), hop, glint}.
var _slots: Array[Dictionary] = [{}, {}, {}]

## What the pointer is over: "", "flask", "salt", or "inst0" to "inst2".
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
	custom_minimum_size = SIZE


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
	_papers_shown = float(_salt.doses)
	_keys.clear()
	_slots = [{}, {}, {}]
	var held: Array = table.instruments
	for i in mini(held.size(), RulesConfig.MAX_INSTRUMENTS):
		_keys.append(held[i])
		_slots[i] = _slot(held[i], 1.0)
	_redraw()
	_hovered(_hover)


## Shows a part's note as if the pointer were over it, for screenshots: "flask", "salt", an
## instrument's key, or "" for none.
func hover(part: String) -> void:
	var i := _keys.find(part)
	_hovered("inst%d" % i if i >= 0 else part)


# --- Movements ------------------------------------------------------------------------------


## The flask tips over and empties, then stands up again, empty.
func tip_flask() -> void:
	_cork = 0.0
	await _tween(TIP_TIME, func(t: float) -> void: _tip = t)
	await _tween(POUR_TIME, func(t: float) -> void: _level = 1.0 - t)
	await _tween(RIGHT_TIME, func(t: float) -> void: _tip = 1.0 - t)


## The flask is filled for the next drink and corked or uncorked as `draught` ({ok, why, cost}
## of the table) says; the tag names the next drink's cost.
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
	_hovered(_hover)


## One paper is opened, its salt poured out, and it is gone. Doses −1.
func open_paper() -> void:
	if _salt.doses <= 0:
		return
	var from := _open
	if from < 1.0:
		await _tween(OPEN_TIME, func(t: float) -> void: _open = lerpf(from, 1.0, t))
	await _tween(SPEND_TIME, func(t: float) -> void: _spend = t)
	_salt.doses -= 1
	_papers_shown = float(_salt.doses)
	_spend = 0.0
	_redraw()


## The papers unfold or fold shut as `salt` ({doses, ok, why} of the table) says.
func set_salt(salt: Dictionary) -> void:
	_salt = {"doses": int(salt.doses), "ok": salt.ok, "why": salt.why}
	_papers_shown = float(_salt.doses)
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
	_slots = [{}, {}, {}]
	for i in _keys.size():
		_slots[i] = _slot(_keys[i], 0.0 if coming.has(_keys[i]) else 1.0)
	_redraw()
	if not coming.is_empty():
		await _tween(LAY_TIME, func(t: float) -> void:
			for i in _keys.size():
				if coming.has(_keys[i]):
					_slots[i].in = t)
	_hovered(_hover)


## An instrument hops in its place.
func hop(key: String) -> void:
	var i := _keys.find(key)
	if i < 0:
		return
	await _tween(HOP_TIME, func(t: float) -> void: _slots[i].hop = sin(t * PI))


## A light crosses an instrument.
func glint(key: String) -> void:
	var i := _keys.find(key)
	if i < 0:
		return
	await _tween(GLINT_TIME, func(t: float) -> void: _slots[i].glint = t)
	_slots[i].glint = 0.0
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
	if FLASK_TAG.has_point(point):
		return "flask"
	if SALT_TAG.has_point(point):
		return "salt"
	for i in _keys.size():
		if _slot_rect(i).has_point(point):
			return "inst%d" % i
	return ""


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


## The next drink's cost as the tag writes it, in two short lines.
func _cost_lines() -> Array[String]:
	if _draught.cost == "first":
		return ["He arrives:", "%d of his Roots join" % RulesConfig.FIRST_ARRIVAL.size()]
	return ["Stains a", "Paper Root"]


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
	if _hover.begins_with("inst"):
		var key := _keys[int(_hover.substr(4))]
		var colour := _colour_of(key)
		return [[RulesConfig.INSTRUMENTS[key].name, colour, true], [RulesConfig.instrument_text(key, _dials), colour, false]]
	return []


func _colour_of(key: String) -> Color:
	return INK if RulesConfig.INSTRUMENTS[key].whose == "his" else PENCIL


# --- Where things are -----------------------------------------------------------------------


func _slot(key: String, laid: float) -> Dictionary:
	return {"key": key, "in": laid, "hop": 0.0, "glint": 0.0}


## The i-th instrument's place, right-aligned along the top.
func _slot_rect(i: int) -> Rect2:
	var row := SLOT_SIZE.x * 3.0 + SLOT_GAP * 2.0
	var left := (SIZE.x - row) * 0.5
	return Rect2(Vector2(left + i * (SLOT_SIZE.x + SLOT_GAP), SLOT_TOP), SLOT_SIZE)


## Where an instrument's card is drawn: its place, lifted by a hop, dropped in while laid.
func _slot_xform(i: int) -> Transform2D:
	var s: Dictionary = _slots[i]
	var r := _slot_rect(i)
	var laid: float = s.get("in", 1.0)
	var hop_by: float = s.get("hop", 0.0)
	var lift := Vector2(0.0, -14.0 * hop_by - 18.0 * (1.0 - laid))
	var turn := 0.08 * hop_by - 0.12 * (1.0 - laid)
	return Transform2D(turn, r.get_center() + lift)


## The middle of the k-th paper in the salt's tag.
func _paper_at(k: int) -> Vector2:
	var shown := clampi(ceili(_papers_shown), 1, PAPERS_MAX)
	var rows := ceili(float(shown) / PAPERS_A_ROW)
	@warning_ignore("integer_division")
	var row := k / PAPERS_A_ROW
	var in_row := mini(shown - row * PAPERS_A_ROW, PAPERS_A_ROW)
	var x := ((k % PAPERS_A_ROW) - (in_row - 1) * 0.5) * PAPER_PITCH.x
	var y := (row - (rows - 1) * 0.5) * PAPER_PITCH.y
	return SALT_TAG.position + PAPERS_AT + Vector2(x, y)


## The flask's frame: the bulb's middle, about which it tips to the right, staying on its tag.
func _flask_xform() -> Transform2D:
	return Transform2D(_tip * TIP_ANGLE, FLASK_TAG.position + BULB_AT)


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


## The tags and the instruments' cards with their shadows, and the note's card.
func _draw_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for r: Rect2 in [FLASK_TAG, SALT_TAG]:
		_card(_back, _ragged(r, rng), CREAM)
	for i in 3:
		var edge := _ragged(Rect2(-SLOT_SIZE * 0.5, SLOT_SIZE), rng)
		if _slots[i].is_empty():
			continue
		var laid: float = _slots[i].in
		_back.draw_set_transform_matrix(_slot_xform(i))
		_card(_back, edge, Color(CREAM, laid), Color(SHADOW, SHADOW.a * laid))
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


func _note_rect(lines: Array) -> Rect2:
	var height := 14.0
	for line: Array in lines:
		height += _note_line_height(line)
	return Rect2(Vector2(SIZE.x - 4.0 - NOTE_W, NOTE_TOP), Vector2(NOTE_W, height))


## How tall one of the note's lines is, wrapped to the note's width.
func _note_line_height(line: Array) -> float:
	var font: Font = _heavy if line[2] else _slanted
	return font.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - 20.0, NOTE_SIZE).y + 2.0


## The draught in the flask, the salt in the open papers, a glint's light.
func _draw_fills() -> void:
	if _level > 0.01:
		# The liquid lies level in the page whatever the flask's tilt: the flask's outline, as
		# it stands on the page, is cut by a level line, and what lies under it is the draught.
		var body := _flask_xform() * _bulb_path()
		var centre := FLASK_TAG.position + BULB_AT
		# Full, it reaches above the bulb's middle; tipped, no higher than the flask's mouth.
		var mouth_y := (_flask_xform() * Vector2(0.0, -BULB_R - NECK_H)).y
		var full := maxf(centre.y - BULB_R * 0.5, mouth_y if _tip > 0.5 else -INF)
		var top := lerpf(centre.y + BULB_R, full, _level)
		var under := PackedVector2Array([Vector2(centre.x - 100.0, top), Vector2(centre.x + 100.0, top),
				Vector2(centre.x + 100.0, top + 100.0), Vector2(centre.x - 100.0, top + 100.0)])
		for liquid in Geometry2D.intersect_polygons(body, under):
			_fills.draw_colored_polygon(liquid, Color(DRAUGHT, 0.85))
	# The draught pouring out while the flask lies over.
	if _tip > 0.8 and _level > 0.02 and _level < 0.99:
		var mouth := _flask_xform() * Vector2(0.0, -BULB_R - NECK_H)
		var floor_y := FLASK_TAG.position.y + BULB_AT.y + BULB_R + 8.0
		_fills.draw_line(mouth, Vector2(mouth.x + 2.0, floor_y), Color(DRAUGHT, 0.7 * _level + 0.2), 3.0)
		_fills.draw_circle(Vector2(mouth.x + 2.0, floor_y), 3.0 + 3.0 * (1.0 - _level), Color(DRAUGHT, 0.6))
	var shown := mini(ceili(_papers_shown), PAPERS_MAX)
	for k in shown:
		var spent := k == shown - 1 and _spend > 0.0
		var heap := _open * (1.0 - (_spend * 1.6 if spent else 0.0))
		if heap > 0.05:
			var c := _paper_at(k)
			# A small mound of salt on the open paper.
			var mound := PackedVector2Array()
			for a in 9:
				var x := lerpf(-7.0, 7.0, a / 8.0)
				mound.append(c + Vector2(x, 4.0 - 7.0 * heap * (1.0 - pow(x / 7.0, 2.0))))
			_fills.draw_colored_polygon(mound, Color(SALT, 0.95))
		if spent:
			var c := _paper_at(k)
			for g in 7:
				var fall := fposmod(_spend * 1.4 + g * 0.13, 1.0)
				_fills.draw_circle(c + Vector2(-6.0 + g * 2.0, 6.0 + fall * 22.0), 1.2, Color(SALT, 1.0 - fall))
	for i in 3:
		var s: Dictionary = _slots[i]
		if s.is_empty() or s.glint <= 0.0:
			continue
		_fills.draw_set_transform_matrix(_slot_xform(i))
		var x := lerpf(-SLOT_SIZE.x * 0.7, SLOT_SIZE.x * 0.7, s.glint)
		var light := sin(s.glint * PI)
		_fills.draw_colored_polygon(PackedVector2Array([
				Vector2(x - 10.0, -SLOT_SIZE.y * 0.5), Vector2(x + 2.0, -SLOT_SIZE.y * 0.5),
				Vector2(x - 6.0, SLOT_SIZE.y * 0.5), Vector2(x - 18.0, SLOT_SIZE.y * 0.5)]),
				Color(1.0, 0.98, 0.88, 0.75 * light))
		_fills.draw_circle(Vector2(x - 4.0, -6.0), 4.0 * light, Color(1.0, 1.0, 0.95, light))
		_fills.draw_set_transform_matrix(Transform2D.IDENTITY)


## Every pencil line: the flask and its cork, the papers, the instruments and the empty places.
func _draw_lines() -> void:
	var base := rng_seed * 1000
	# The flask.
	var flask := Pencil.new(base + 1)
	flask.colour = PENCIL
	_lines.draw_set_transform_matrix(_flask_xform())
	flask.stroke(_bulb_path(), 2.4, 0.5)
	flask.stroke(PackedVector2Array([Vector2(-NECK_W * 0.5 - 2.0, -BULB_R - NECK_H - 1.0),
			Vector2(NECK_W * 0.5 + 2.0, -BULB_R - NECK_H - 1.0)]), 1.8, 0.3)
	flask.stroke(PackedVector2Array([Vector2(-BULB_R * 0.55, -BULB_R * 0.1), Vector2(-BULB_R * 0.35, -BULB_R * 0.5)]), 1.0, 0.2)
	if _cork > 0.01:
		var rise := (1.0 - _cork) * -16.0
		var cork := Pencil.new(base + 2)
		cork.colour = Color(CORK.darkened(0.5), _cork)
		var top := -BULB_R - NECK_H + rise
		cork.stroke(PackedVector2Array([Vector2(-NECK_W * 0.5 + 0.5, top + 6.0), Vector2(-NECK_W * 0.5 - 1.5, top - 6.0),
				Vector2(NECK_W * 0.5 + 1.5, top - 6.0), Vector2(NECK_W * 0.5 - 0.5, top + 6.0)]), 1.8, 0.2)
		for h in 3:
			cork.stroke(PackedVector2Array([Vector2(-3.5 + h * 3.5, top - 4.0), Vector2(-4.5 + h * 3.5, top + 4.0)]), 1.0, 0.1)
		cork.draw(_lines)
	flask.draw(_lines)
	_lines.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The papers: open with salt in them, or folded shut.
	var shown := mini(ceili(_papers_shown), PAPERS_MAX)
	for k in shown:
		var paper := Pencil.new(base + 100 + k)
		var c := _paper_at(k)
		var spent := k == shown - 1 and _spend > 0.0
		var a := 1.0 - (_spend if spent else 0.0)
		paper.colour = _faint(PENCIL, a)
		_paper_path(paper, c, _open)
		paper.draw(_lines)
	# Hovering salt that can be taken: the paper it will spend is outlined, and struck.
	if _hover == "salt" and _salt.ok and shown > 0:
		var mark := Pencil.new(base + 200)
		mark.colour = INK
		var c := _paper_at(shown - 1)
		var h := PAPER_SIZE * 0.5 + 4.0
		_dashed(mark, _rect_path(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)), 4.0, 3.0, 1.5)
		mark.stroke(PackedVector2Array([c + Vector2(-h + 2.0, h - 2.0), c + Vector2(h - 2.0, -h + 2.0)]), 1.8, 0.3)
		mark.draw(_lines)
	# The instruments, and the places still empty.
	for i in 3:
		var s: Dictionary = _slots[i]
		if s.is_empty():
			var empty := Pencil.new(base + 300 + i)
			empty.colour = Color(CREAM, 0.45)
			var r := _slot_rect(i).grow(-3.0)
			_dashed(empty, _rect_path(r), 5.0, 5.0, 1.1)
			empty.draw(_lines)
			continue
		var sketch := Pencil.new(base + 400 + i * 20)
		sketch.colour = Color(_colour_of(s.key), s.in)
		_lines.draw_set_transform_matrix(_slot_xform(i))
		_instrument(sketch, s.key)
		sketch.draw(_lines)
		_lines.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _hover.begins_with("inst"):
		var ring := Pencil.new(base + 500)
		ring.colour = _colour_of(_keys[int(_hover.substr(4))])
		ring.stroke(_rect_path(_slot_rect(int(_hover.substr(4))).grow(3.0)), 1.4, 0.3)
		ring.draw(_lines)
	elif _hover == "flask" or _hover == "salt":
		var ring := Pencil.new(base + 510)
		var usable: bool = _draught.ok if _hover == "flask" else _salt.ok
		ring.colour = INK if usable else Color(PENCIL, 0.6)
		ring.stroke(_rect_path((FLASK_TAG if _hover == "flask" else SALT_TAG).grow(3.0)), 1.4, 0.3)
		ring.draw(_lines)


## The tags' headings, the flask's cost and the doses held, and the hover's note.
func _draw_text() -> void:
	var at := FLASK_TAG.position
	_text.draw_string(_heavy, at + Vector2(10.0, 20.0), "DRAUGHT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PENCIL)
	if not _draught.ok:
		_text.draw_string(_slanted, at + Vector2(0.0, 40.0), "corked", HORIZONTAL_ALIGNMENT_RIGHT,
				FLASK_TAG.size.x - 8.0, 11, LABEL)
	var lines := _cost_lines()
	var colour := INK if _draught.ok else LABEL
	_text.draw_string(_slanted, at + Vector2(0.0, 122.0), lines[0], HORIZONTAL_ALIGNMENT_CENTER, FLASK_TAG.size.x, 12, colour)
	_text.draw_string(_slanted, at + Vector2(0.0, 138.0), lines[1], HORIZONTAL_ALIGNMENT_CENTER, FLASK_TAG.size.x, 12, colour)
	at = SALT_TAG.position
	_text.draw_string(_heavy, at + Vector2(10.0, 20.0), "SALT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PENCIL)
	if not _salt.ok:
		_text.draw_string(_slanted, at + Vector2(0.0, 20.0), "shut", HORIZONTAL_ALIGNMENT_RIGHT,
				SALT_TAG.size.x - 8.0, 11, LABEL)
	var doses: int = _salt.doses
	var held := "no doses" if doses == 0 else ("1 dose" if doses == 1 else "%d doses" % doses)
	_text.draw_string(_heavy, at + Vector2(0.0, 138.0), held, HORIZONTAL_ALIGNMENT_CENTER, SALT_TAG.size.x, 13,
			PENCIL if _salt.ok else LABEL)
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


# --- Shapes ---------------------------------------------------------------------------------


## A colour as drawn faintly on the cream: `a` 0 is the cream, 1 the colour itself.
static func _faint(colour: Color, a: float) -> Color:
	return CREAM.lerp(colour, clampf(a, 0.0, 1.0))


## A rectangle's outline with its edges a little uneven, as torn card.
static func _ragged(r: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var pieces := maxi(2, int(a.distance_to(b) / 14.0))
		var inward := (b - a).normalized().orthogonal()
		for k in pieces:
			out.append(a.lerp(b, float(k) / pieces) + inward * rng.randf_range(-1.2, 1.2))
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
