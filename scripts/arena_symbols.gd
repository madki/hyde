class_name ArenaSymbols
extends Control
## The three symbols and the line, each in its zone of the arena's page (ArenaLayout).
##
## Lamp, Heart and Mirror are three gauges in one row at the top, each between brackets on a
## slip of cream stock that reads on the slate and on Hyde's ink alike. A gauge reads from
## left to right: Habit as ink tallies, the symbol's small sketch, Craving as ink pips (two
## places; a third shows only while Craving rolls over), a bar, and Temper as pencil tallies.
## A side with nothing on it has a dash. Under the top rule lies the line, as a banner under
## its name: Paper Roots as pencil tallies to the left of a centre mark, Ink Roots as ink
## tallies to the right, both at one pitch so the longer side is the side ahead, with the two
## counts at the banner's ends.
##
## Hovering a gauge opens its ledger: that symbol in numbers, its three gauges, how many Paper
## and Ink Roots of it the deck holds, and what one of each is worth now. `show_numbers(true)`
## (a held key) opens all three. A gauge's number also shows under it whenever it changes.
##
## Nothing here works out a rule, and nothing moves at rest. Give it RulesView.table() with
## `show_table` to set it at once. The beats of a move then drive it, each call a coroutine to
## `await` that returns when its movement is over:
##
## - `set_craving(sym, n)`: pips fill or empty to n (0 to 2).
## - `rollover(sym, habit_to)`: the third pip appears, the three join and burn into one Habit
##   tally, the pips are left empty.
## - `turn(sym, temper_to)`: the filled pips travel into Temper, one tally each.
## - `set_habit(sym, n)`, `set_temper(sym, n)`: tallies drawn or taken away.
## - `flash(sym)`: the sketch pulses.
## - `set_line(paper, ink)`: the line moves one mark across, or gains or loses marks.
##   `line_across(to_ink)` and `line_gain(ink)` are the two moves named.
## - `line_check(centre)`: the line grows to `centre` (in this control's coordinates) and,
##   if it holds, the larger side is underlined and the line shrinks back; returns true. If
##   ink is ahead, the ink floods across the paper side and stays; returns false.
##   `line_reset()` puts it back.
##
## The ghost marks of a play (doc: what the play will do) are still: `show_preview(p)` takes
## RulesView.preview(), or set them one by one with `ghost_craving`, `ghost_rollover`,
## `ghost_temper` and `set_lock`. `clear_ghosts()` takes them all away.

const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

const SYMS: Array[String] = ["lamp", "heart", "mirror"]

## A gauge: its height, the gap between two, and the room inside it, from left to right: the
## bracket's, the sketch's, each pip's (three are kept, the third for a rollover and the lock),
## and the least room each side's tallies are given.
const GAUGE_H := 32.0
const GAUGE_GAP := 8.0
const PAD := 9.0
const SKETCH_W := 22.0
const SKETCH_SCALE := 0.4
const PIP_R := 5.0
const PIP_PITCH := 13.0
const SIDE_MIN := 14.0
## Tallies on a gauge: the distance between two marks and the gap between groups of five (both
## made smaller when the row would not fit its zone), how many stand in one row (a side with
## more has two rows), their height in one row and in two, and the most drawn (a number is
## written after them beyond that).
const TALLY_PITCH := 3.4
const TALLY_GAP := 3.6
const TALLY_ROW := 10
const TALLY_H := 15.0
const TALLY_H_TWO := 11.0
const TALLY_MAX := 20
## The line's banner: the height of its name above it, half its length and height, the room
## a count takes at each end, and the gap at the centre.
const LINE_NAME := "THE BALANCE"
const LINE_NAME_H := 18.0
const LINE_HALF := 180.0
const LINE_H := 15.0
const LINE_COUNT := 76.0
const LINE_NOTCH := 11.0
const LINE_GAP := 8.0
const LINE_MARK_H := 8.0
## How much larger the line is drawn at the centre of the page.
const GROW_SCALE := 1.6
## The ledger's size.
const LEDGER := Vector2(282.0, 76.0)

## Seconds for each movement.
const FILL_TIME := 0.3
const JOIN_TIME := 0.25
const TRAVEL_TIME := 0.45
const TALLY_TIME := 0.25
const FLASH_TIME := 0.5
const NOTE_TIME := 1.4
const GROW_TIME := 0.5
const HOLD_TIME := 0.9
const FLOOD_TIME := 0.7

const PENCIL := Color(0.015, 0.025, 0.035)
const INK := Color(0.27, 0.07, 0.26)
const CREAM := Color(0.87, 0.81, 0.67)
const CREAM_TEXT := Color(0.93, 0.89, 0.78)
const INK_WASH := Color(0.80, 0.70, 0.75)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const LABEL := Color(0.33, 0.28, 0.27)

## Changes the lines and the tags' edges a little while keeping the look.
@export var rng_seed := 11

## What is shown of each symbol, see _blank().
var _s := {}
var _paper := 0
var _ink := 0
var _paper_shown := 0.0
var _ink_shown := 0.0
## The line's counts are lit for a moment when they change.
var _line_note := {"paper": 0.0, "ink": 0.0}
var _grow := 0.0
var _centre := Vector2.ZERO
var _lead := 0.0
var _flood := 0.0
var _lock := 0.0
var _numbers := false
var _hover := ""
## The row as it is laid out now (see _measure): each gauge's places by its symbol, the
## tallies' pitch and group gap, and the height of the row's middle.
var _g := {}
var _pitch := TALLY_PITCH
var _gap := TALLY_GAP
var _row_y := 0.0
## Things on their way from one mark to another: {from, to, t, from_colour, to_colour, line}.
var _travel: Array[Dictionary] = []

var _back := Control.new()
var _lines := Control.new()
var _fills := Control.new()
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
	for sym in SYMS:
		_s[sym] = _blank()
	_lines.material = LINE_MATERIAL
	_back.draw.connect(_draw_back)
	_lines.draw.connect(_draw_lines)
	_fills.draw.connect(_draw_fills)
	_text.draw.connect(_draw_text)
	for child: Control in [_back, _lines, _fills, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	_measure()


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


func _blank() -> Dictionary:
	return {
		"craving": 0, "habit": 0, "temper": 0,
		"paper": 0, "ink": 0, "paper_chips": 0, "ink_chips": 0,
		"fill": [0.0, 0.0, 0.0], # how full each pip is drawn
		"third": 0.0, # how present the third pip is
		"join": 0.0, # how far the three pips have drawn together
		"habit_shown": 0.0, "temper_shown": 0.0, # tallies drawn; a fraction is one partly drawn
		"flash": 0.0,
		"note": {"craving": 0.0, "habit": 0.0, "temper": 0.0},
		"ghost_pips": 0, "ghost_roll": false, "ghost_temper": 0,
	}


# --- Setting it at once ---------------------------------------------------------------------


## Shows the symbols and the line of a table, as RulesView.table() gives it, at once.
func show_table(table: Dictionary) -> void:
	var symbols: Dictionary = table.symbols
	for sym in SYMS:
		var from: Dictionary = symbols[sym]
		var s: Dictionary = _s[sym]
		s.craving = clampi(int(from.craving), 0, 2)
		s.habit = int(from.habit)
		s.temper = int(from.temper)
		for k in 3:
			s.fill[k] = 1.0 if k < s.craving else 0.0
		s.third = 0.0
		s.join = 0.0
		s.habit_shown = float(s.habit)
		s.temper_shown = float(s.temper)
		set_roots(sym, from.paper, from.ink, from.paper_chips, from.ink_chips)
	var line: Dictionary = table.line
	_paper = int(line.paper)
	_ink = int(line.ink)
	_paper_shown = float(_paper)
	_ink_shown = float(_ink)
	_redraw()


## What the hover shows of a symbol besides its gauges: how many of its Roots the deck holds
## and what one of each is worth. It changes nothing that is drawn.
func set_roots(sym: String, paper: int, ink: int, paper_chips: int, ink_chips: int) -> void:
	var s: Dictionary = _s[sym]
	s.paper = paper
	s.ink = ink
	s.paper_chips = paper_chips
	s.ink_chips = ink_chips
	_text.queue_redraw()


## While true, every gauge shows its number beside it (a held key).
func show_numbers(on: bool) -> void:
	_numbers = on
	_redraw()


## Shows a symbol's detail as if it were hovered ("" for none): for screenshots.
func hover_symbol(sym: String) -> void:
	_hover = sym
	_text.queue_redraw()


# --- Ghost marks ----------------------------------------------------------------------------


## The ghost marks of a play, as RulesView.preview() gives it: the next pips of the Craving it
## adds, a rollover, the Temper an Ink Root turned brings, and the lock of a play that adds no
## Craving.
func show_preview(p: Dictionary) -> void:
	clear_ghosts()
	if not p.get("ok", false):
		return
	var craving: Dictionary = p.craving
	for sym: String in craving:
		var c: Dictionary = craving[sym]
		if int(c.copies) > 0:
			ghost_rollover(sym, true)
		else:
			ghost_craving(sym, int(c.adds))
	for t: Dictionary in p.turns:
		ghost_temper(t.sym, int(_s[t.sym].ghost_temper) + int(t.gain))
	set_lock(bool(p.ev.get("no_craving", false)))


## Outlines the next `adds` pips of a symbol.
func ghost_craving(sym: String, adds: int) -> void:
	_s[sym].ghost_pips = adds
	_redraw()


## Joins the three pips, outlines the next Habit tally, and hangs a slip under the gauge
## that names the Ink Root that would join.
func ghost_rollover(sym: String, on: bool) -> void:
	_s[sym].ghost_roll = on
	_redraw()


## Outlines the next `gain` Temper tallies.
func ghost_temper(sym: String, gain: int) -> void:
	_s[sym].ghost_temper = gain
	_redraw()


## A small lock after the pips: the play adds no Craving. It comes and goes in a moment.
func set_lock(on: bool) -> void:
	_tween(0.2, _set_lock.bind(_lock, 1.0 if on else 0.0))


func clear_ghosts() -> void:
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		s.ghost_pips = 0
		s.ghost_roll = false
		s.ghost_temper = 0
	if _lock > 0.0:
		set_lock(false)
	_redraw()


func _set_lock(t: float, from: float, to: float) -> void:
	_lock = lerpf(from, to, t)


# --- The gauges' movements ------------------------------------------------------------------


## The pips of a symbol fill or empty to `n` (0 to 2), and Craving's number shows.
func set_craving(sym: String, n: int) -> void:
	var s: Dictionary = _s[sym]
	n = clampi(n, 0, 2)
	var from: Array = s.fill.duplicate()
	var third: float = s.third
	s.craving = n
	_note(sym, "craving")
	await _tween(FILL_TIME, func(t: float) -> void:
		for k in 3:
			s.fill[k] = lerpf(from[k], 1.0 if k < n else 0.0, t)
		s.third = lerpf(third, 0.0, t))


## Craving reaches three: the third pip appears and fills, the three join and burn into one
## Habit tally, and the pips are left empty. The sketch pulses and Habit's number shows.
func rollover(sym: String, habit_to: int) -> void:
	var s: Dictionary = _s[sym]
	var from: Array = s.fill.duplicate()
	s.ghost_roll = false
	s.ghost_pips = 0
	_note(sym, "craving")
	await _tween(FILL_TIME, func(t: float) -> void:
		s.third = t
		for k in 3:
			s.fill[k] = lerpf(from[k], 1.0, t))
	await _tween(JOIN_TIME, func(t: float) -> void: s.join = t)
	var mover := _traveller(_pip_at(sym, 1), _tally_at(sym, "habit", int(s.habit_shown)), INK, INK, false)
	await _tween(TRAVEL_TIME, func(t: float) -> void:
		mover.t = t
		s.third = 1.0 - t
		s.join = 1.0 - t
		for k in 3:
			s.fill[k] = 1.0 - t)
	_travel.erase(mover)
	s.craving = 0
	await _grow_tallies(sym, "habit", habit_to)
	await flash(sym)


## Sublimation: each filled pip travels into Temper and becomes a tally there. The pips are
## left empty and Temper's number shows.
func turn(sym: String, temper_to: int) -> void:
	var s: Dictionary = _s[sym]
	s.ghost_temper = 0
	var gain := temper_to - int(s.temper)
	var filled: Array[int] = []
	for k in 3:
		if s.fill[k] > 0.5:
			filled.append(k)
	if gain <= 0 or filled.is_empty():
		await set_craving(sym, 0)
		await _grow_tallies(sym, "temper", temper_to)
		await flash(sym)
		return
	for i in gain:
		var k: int = filled[maxi(filled.size() - 1 - i, 0)]
		var mover := _traveller(_pip_at(sym, k), _tally_at(sym, "temper", int(s.temper) + i), INK, PENCIL, false)
		await _tween(TRAVEL_TIME, func(t: float) -> void:
			mover.t = t
			s.fill[k] = minf(s.fill[k], 1.0 - t))
		_travel.erase(mover)
		s.temper = int(s.temper) + 1
		_note(sym, "temper")
		await _tween(TALLY_TIME, func(t: float) -> void: s.temper_shown = float(s.temper) - 1.0 + t)
	for k in 3:
		s.fill[k] = 0.0
	s.craving = 0
	s.temper = temper_to
	s.temper_shown = float(temper_to)
	_note(sym, "craving")
	_redraw()


## Habit's tallies drawn or taken away to `n` (the alley's Habit, for one).
func set_habit(sym: String, n: int) -> void:
	await _grow_tallies(sym, "habit", n)


func set_temper(sym: String, n: int) -> void:
	await _grow_tallies(sym, "temper", n)


## The sketch pulses.
func flash(sym: String) -> void:
	var s: Dictionary = _s[sym]
	await _tween(FLASH_TIME, func(t: float) -> void: s.flash = sin(t * PI))


func _grow_tallies(sym: String, row: String, n: int) -> void:
	var s: Dictionary = _s[sym]
	var key := row + "_shown"
	var from: float = s[key]
	s[row] = n
	_note(sym, row)
	if is_equal_approx(from, float(n)):
		return
	await _tween(TALLY_TIME * maxf(1.0, absf(n - from)), func(t: float) -> void: s[key] = lerpf(from, float(n), t))


## Shows a gauge's number beside it for a moment.
func _note(sym: String, row: String) -> void:
	var note: Dictionary = _s[sym].note
	note[row] = 1.0
	_redraw()
	var tw := create_tween()
	tw.tween_interval(NOTE_TIME)
	tw.tween_method(func(a: float) -> void:
		note[row] = a
		_text.queue_redraw(), 1.0, 0.0, 0.4)


# --- The line's movements -------------------------------------------------------------------


## Moves the line to `paper` against `ink`: one mark across when one side loses one and the
## other gains it, else each side gains or loses its marks.
func set_line(paper: int, ink: int) -> void:
	if paper == _paper - 1 and ink == _ink + 1:
		await line_across(true)
	elif paper == _paper + 1 and ink == _ink - 1:
		await line_across(false)
	else:
		var p0 := _paper_shown
		var i0 := _ink_shown
		_paper = paper
		_ink = ink
		_line_lit(p0 != paper, i0 != ink)
		var steps := maxf(1.0, maxf(absf(paper - p0), absf(ink - i0)))
		await _tween(TALLY_TIME * minf(steps, 4.0), func(t: float) -> void:
			_paper_shown = lerpf(p0, float(paper), t)
			_ink_shown = lerpf(i0, float(ink), t))


## One mark leaves one side's end and crosses the centre to the other side's end: a paper
## mark to the ink side (a stain), or with `to_ink` false an ink mark to the paper side (a turn).
func line_across(to_ink: bool) -> void:
	var from_n := _paper - 1 if to_ink else _ink - 1
	if from_n < 0:
		return
	var from := _line_mark(from_n, not to_ink)
	var to := _line_mark(_ink if to_ink else _paper, to_ink)
	var mover := _traveller(from, to, PENCIL if to_ink else INK, INK if to_ink else PENCIL, true)
	if to_ink:
		_paper -= 1
		_paper_shown = float(_paper)
	else:
		_ink -= 1
		_ink_shown = float(_ink)
	_line_lit(true, true)
	await _tween(TRAVEL_TIME, func(t: float) -> void: mover.t = t)
	_travel.erase(mover)
	if to_ink:
		_ink += 1
	else:
		_paper += 1
	var shown := (_ink if to_ink else _paper) - 1.0
	await _tween(TALLY_TIME, func(t: float) -> void:
		if to_ink:
			_ink_shown = shown + t
		else:
			_paper_shown = shown + t)


## One side gains a mark at its end.
func line_gain(ink: bool) -> void:
	await set_line(_paper + (0 if ink else 1), _ink + (1 if ink else 0))


## The check at the end of a round. The line grows to `centre`. If it holds, the side ahead
## (both at a tie) is underlined in cream and the line goes back: true. If ink is ahead, the
## ink floods across the paper side and the line stays: false.
func line_check(centre: Vector2) -> bool:
	_centre = centre
	await _tween(GROW_TIME, func(t: float) -> void: _grow = t)
	if _ink > _paper:
		await _tween(FLOOD_TIME, func(t: float) -> void: _flood = t)
		return false
	await _tween(0.3, func(t: float) -> void: _lead = t)
	await get_tree().create_timer(HOLD_TIME).timeout
	await _tween(GROW_TIME, func(t: float) -> void:
		_grow = 1.0 - t
		_lead = 1.0 - t)
	return true


## Puts the line back in its place, without the flood.
func line_reset() -> void:
	_grow = 0.0
	_flood = 0.0
	_lead = 0.0
	_redraw()


func _line_lit(paper: bool, ink: bool) -> void:
	for side: String in ["paper", "ink"]:
		if (side == "paper" and not paper) or (side == "ink" and not ink):
			continue
		_line_note[side] = 1.0
		var tw := create_tween()
		tw.tween_interval(NOTE_TIME)
		tw.tween_method(func(a: float) -> void:
			_line_note[side] = a
			_text.queue_redraw(), 1.0, 0.0, 0.4)


# --- Time -----------------------------------------------------------------------------------


## Runs `apply` from 0 to 1 over `seconds`, redrawing as it goes; returns when it is done.
func _tween(seconds: float, apply: Callable) -> void:
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(t: float) -> void:
		apply.call(t)
		_redraw(), 0.0, 1.0, seconds)
	await tw.finished


func _traveller(from: Vector2, to: Vector2, from_colour: Color, to_colour: Color, on_line: bool) -> Dictionary:
	var mover := {"from": from, "to": to, "t": 0.0, "from_colour": from_colour, "to_colour": to_colour, "line": on_line}
	_travel.append(mover)
	return mover


func _redraw() -> void:
	_measure()
	for child: Control in [_back, _lines, _fills, _text]:
		child.queue_redraw()


# --- Where things are -----------------------------------------------------------------------


func _lay_out() -> void:
	for child: Control in [_back, _lines, _fills, _text]:
		child.size = size
	_redraw()


## Lays the row out in its zone: each gauge as wide as its marks need, the row centred, and
## the tallies drawn closer when the row would be wider than the zone.
func _measure() -> void:
	var zone := ArenaLayout.symbols(size)
	_row_y = zone.get_center().y
	var fixed := PAD + 5.0 + SKETCH_W + 6.0 + PIP_PITCH * 3.0 + 3.0 + 6.0 + PAD
	var widths: Array[float] = []
	var sides: Array[Vector2] = []
	for squeeze: float in [1.0, 0.85, 0.7, 0.58, 0.48]:
		_pitch = TALLY_PITCH * squeeze
		_gap = TALLY_GAP * squeeze
		widths.clear()
		sides.clear()
		var total := GAUGE_GAP * 2.0
		for sym in SYMS:
			var side := Vector2(_side_width(sym, "habit"), _side_width(sym, "temper"))
			sides.append(side)
			widths.append(fixed + side.x + side.y)
			total += fixed + side.x + side.y
		if total <= zone.size.x:
			break
	var row := GAUGE_GAP * 2.0
	for w in widths:
		row += w
	var x := zone.get_center().x - row * 0.5
	for i in 3:
		var habit_x := x + PAD + 2.0
		var sketch_x := habit_x + sides[i].x + 3.0 + SKETCH_W * 0.5
		var pips_x := sketch_x + SKETCH_W * 0.5 + 6.0 + PIP_PITCH * 0.5
		var bar_x := pips_x + PIP_PITCH * 2.5 + 3.0
		_g[SYMS[i]] = {
			"rect": Rect2(x, _row_y - GAUGE_H * 0.5, widths[i], GAUGE_H),
			"habit_x": habit_x, "sketch_x": sketch_x, "pips_x": pips_x, "bar_x": bar_x,
			"temper_x": bar_x + 6.0, "habit_w": sides[i].x, "temper_w": sides[i].y,
		}
		x += widths[i] + GAUGE_GAP


## The room a side's tallies take: those drawn, those a chosen play would add, and the
## number written after the most that are drawn.
func _side_width(sym: String, row: String) -> float:
	var s: Dictionary = _s[sym]
	var w := _tally_x(clampi(_side_count(sym, row), 1, TALLY_ROW) - 1, _pitch, _gap) + 3.0
	if int(s[row]) > TALLY_MAX:
		w += 18.0
	return maxf(w, SIDE_MIN)


## The marks a side has room for: those drawn, and those a chosen play would add.
func _side_count(sym: String, row: String) -> int:
	var s: Dictionary = _s[sym]
	var n := maxi(int(s[row]), ceili(s[row + "_shown"]))
	if row == "habit" and s.ghost_roll:
		n += 1
	if row == "temper":
		n += int(s.ghost_temper)
	return n


## The height of a side's tallies: shorter when they stand in two rows.
func _tally_h(sym: String, row: String) -> float:
	return TALLY_H_TWO if _side_count(sym, row) > TALLY_ROW else TALLY_H


func _gauge_rect(sym: String) -> Rect2:
	return _g[sym].rect


## The middle of a symbol's sketch, on the page: where what its gauges pay comes from.
func sketch_place(sym: String) -> Vector2:
	_measure()
	return get_global_transform() * Vector2(_g[sym].sketch_x, _row_y)


## The middle of a symbol's k-th pip (0 to 2), drawn together as `join` rises.
func _pip_at(sym: String, k: int) -> Vector2:
	var join: float = _s[sym].join
	var x: float = _g[sym].pips_x + k * PIP_PITCH + (1 - k) * join * (PIP_PITCH - PIP_R * 1.6)
	return Vector2(x, _row_y)


## The x of the n-th tally from where a row starts, at a pitch and a group gap.
static func _tally_x(n: int, pitch: float, gap: float) -> float:
	return (n / 5) * (pitch * 4.0 + gap) + (n % 5) * pitch


## The top end of a side's n-th tally on a gauge.
func _tally_top(sym: String, row: String, n: int) -> Vector2:
	var x: float = _g[sym][row + "_x"] + _tally_x(n % TALLY_ROW, _pitch, _gap)
	if _side_count(sym, row) > TALLY_ROW:
		return Vector2(x, _row_y - TALLY_H_TWO - 1.5 + (n / TALLY_ROW) * (TALLY_H_TWO + 3.0))
	return Vector2(x, _row_y - TALLY_H * 0.5)


## The middle of a side's n-th tally: where something travelling to it lands.
func _tally_at(sym: String, row: String, n: int) -> Vector2:
	return _tally_top(sym, row, mini(n, TALLY_MAX - 1)) + Vector2(0.0, _tally_h(sym, row) * 0.5)


## The line's pitch: one for both sides, so that the longer side is the side ahead.
func _line_pitch() -> float:
	var most := maxi(maxi(_paper, _ink), 1)
	var room := LINE_HALF - LINE_COUNT - LINE_GAP - 4.0
	return minf(8.0, room / (ceili(most / 5.0) * 5.6))


## The middle of the line's n-th mark on a side, in the line's own coordinates.
func _line_mark(n: int, ink: bool) -> Vector2:
	var p := _line_pitch()
	var x := LINE_GAP + p + _tally_x(n, p, p * 1.6)
	return Vector2(x if ink else -x, 0.0)


## The banner's middle at home, under the line's name.
func _line_home() -> Vector2:
	var zone := ArenaLayout.balance(size)
	return Vector2(zone.get_center().x, zone.position.y + LINE_NAME_H + (zone.size.y - LINE_NAME_H) * 0.5)


## From the line's own coordinates to this control's: at home, or grown to the centre.
func _line_xform() -> Transform2D:
	var ease_t := _grow
	var s := lerpf(1.0, GROW_SCALE, ease_t)
	return Transform2D(0.0, Vector2(s, s), 0.0, _line_home().lerp(_centre, ease_t))


func _has_point(point: Vector2) -> bool:
	for sym in SYMS:
		if _gauge_rect(sym).has_point(point):
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := ""
		for sym in SYMS:
			if _gauge_rect(sym).has_point(event.position):
				over = sym
		if over != _hover:
			hover_symbol(over)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		hover_symbol("")


# --- Drawing --------------------------------------------------------------------------------


## The gauges' slips with their shadows and their pulse, the slip of a rollover's card, and
## the line's banner.
func _draw_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		var flash: float = s.flash
		_slip(_gauge_rect(sym), rng, CREAM.lerp(Color(1.0, 0.96, 0.84), flash * 0.8))
		if s.ghost_roll:
			_slip(_roll_slip(sym), rng, CREAM)
	_back.draw_set_transform_matrix(_line_xform())
	# A banner: a strip whose two ends are cut to a notch.
	var banner := PackedVector2Array([Vector2(-LINE_HALF, -LINE_H), Vector2(LINE_HALF, -LINE_H),
			Vector2(LINE_HALF - LINE_NOTCH, 0.0), Vector2(LINE_HALF, LINE_H), Vector2(-LINE_HALF, LINE_H),
			Vector2(-LINE_HALF + LINE_NOTCH, 0.0)])
	var shadow := PackedVector2Array()
	for p in banner:
		shadow.append(p + Vector2(2.0, 3.0))
	_back.draw_colored_polygon(shadow, SHADOW)
	_back.draw_colored_polygon(banner, CREAM)
	_back.draw_rect(Rect2(0.0, -LINE_H + 2.0, LINE_HALF - LINE_COUNT, LINE_H * 2.0 - 4.0), INK_WASH)
	_back.draw_set_transform_matrix(Transform2D.IDENTITY)


## A slip of cream stock with its shadow.
func _slip(r: Rect2, rng: RandomNumberGenerator, colour: Color) -> void:
	var edge := _ragged(r, rng)
	var shadow := PackedVector2Array()
	for p in edge:
		shadow.append(p + Vector2(2.0, 3.0))
	_back.draw_colored_polygon(shadow, SHADOW)
	_back.draw_colored_polygon(edge, colour)


## The words on the slip of a rollover's card, and the slip, hung under the gauge.
func _roll_words(sym: String) -> String:
	return "+1 %s" % RulesConfig.ROOT[sym].ink


func _roll_slip(sym: String) -> Rect2:
	var w := _slanted.get_string_size(_roll_words(sym), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x + 12.0
	var r := _gauge_rect(sym)
	return Rect2(r.position.x + 10.0, r.end.y + 1.0, w, 16.0)


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


## Every pencil line: the brackets, the sketches, the pips' rims, the tallies, the ghosts, the
## lock and the line.
func _draw_lines() -> void:
	for i in 3:
		var sym := SYMS[i]
		var s: Dictionary = _s[sym]
		var g: Dictionary = _g[sym]
		var r: Rect2 = g.rect
		var seed_base := rng_seed * 1000 + i * 200
		# The two brackets, and the bar between the pips and Temper.
		var frame := Pencil.new(seed_base + 2)
		frame.colour = PENCIL
		var top := r.position.y + 5.0
		var bottom := r.end.y - 5.0
		frame.stroke(PackedVector2Array([Vector2(r.position.x + 8.5, top), Vector2(r.position.x + 4.0, top),
				Vector2(r.position.x + 4.0, bottom), Vector2(r.position.x + 8.5, bottom)]), 1.9, 0.3)
		frame.stroke(PackedVector2Array([Vector2(r.end.x - 8.5, top), Vector2(r.end.x - 4.0, top),
				Vector2(r.end.x - 4.0, bottom), Vector2(r.end.x - 8.5, bottom)]), 1.9, 0.3)
		var bar_x: float = g.bar_x
		frame.stroke(PackedVector2Array([Vector2(bar_x, _row_y - 9.0), Vector2(bar_x + 0.4, _row_y + 9.0)]), 1.4, 0.3)
		# A side with no mark on it, and none coming, has a dash.
		frame.colour = _faint(PENCIL, 0.55)
		for row: String in ["habit", "temper"]:
			var coming: bool = s.ghost_roll if row == "habit" else int(s.ghost_temper) > 0
			if s[row + "_shown"] < 0.01 and not coming:
				var x: float = g[row + "_x"]
				frame.stroke(PackedVector2Array([Vector2(x + 2.0, _row_y + 0.5), Vector2(x + 9.0, _row_y)]), 1.5, 0.3)
		frame.draw(_lines)
		var sketch := Pencil.new(seed_base)
		sketch.colour = PENCIL.lerp(INK, s.flash * 0.6)
		_sketch(sketch, sym, Vector2(g.sketch_x, _row_y), SKETCH_SCALE)
		sketch.draw(_lines)
		# The pips' rims: two always, the third while it is there.
		var rims := Pencil.new(seed_base + 1)
		for k in 3:
			var present: float = 1.0 if k < 2 else s.third
			var ghost: bool = k >= int(s.craving) and k < int(s.craving) + int(s.ghost_pips)
			if s.ghost_roll:
				ghost = k >= int(s.craving)
				present = 1.0
			if present <= 0.01:
				continue
			rims.colour = _faint(INK if ghost else PENCIL, present * (1.0 if ghost else 0.8))
			rims.stroke(_circle(_pip_at(sym, k), PIP_R, 12), 2.0 if ghost else 1.4, 0.25)
		if s.ghost_roll:
			# The three pips joined by a loop round them.
			rims.colour = _faint(INK, 0.8)
			var mid := _pip_at(sym, 1)
			rims.stroke(_ellipse(mid, Vector2(PIP_PITCH + PIP_R + 2.5, PIP_R + 3.5), 24), 1.4, 0.4)
		rims.draw(_lines)
		_draw_tallies(sym, "habit", seed_base + 10, INK)
		_draw_tallies(sym, "temper", seed_base + 60, PENCIL)
		var ghosts := Pencil.new(seed_base + 120)
		ghosts.colour = _faint(INK, 0.4)
		if s.ghost_roll and int(s.habit) < TALLY_MAX:
			ghosts.stroke(_tally_path(sym, "habit", int(s.habit), 1.0), 1.5, 0.3)
		for n_ghost in int(s.ghost_temper):
			var n: int = int(s.temper) + n_ghost
			if n < TALLY_MAX:
				ghosts.colour = _faint(PENCIL, 0.45)
				ghosts.stroke(_tally_path(sym, "temper", n, 1.0), 1.5, 0.3)
		if _lock > 0.01:
			_lock_path(ghosts, _pip_at(sym, 2) + Vector2(0.0, -3.0), _lock)
		ghosts.draw(_lines)
	_lines.draw_set_transform_matrix(_line_xform())
	var line := Pencil.new(rng_seed * 1000 + 900)
	line.colour = PENCIL
	line.stroke(PackedVector2Array([Vector2(0.0, -LINE_H - 3.0), Vector2(0.5, LINE_H + 3.0)]), 2.2, 0.4)
	line.draw(_lines)
	_draw_line_side(false, _paper_shown, rng_seed * 1000 + 1000)
	_draw_line_side(true, _ink_shown, rng_seed * 1000 + 3000)
	if _lead > 0.01:
		var under := Pencil.new(rng_seed * 1000 + 950)
		under.colour = CREAM_TEXT
		var y := LINE_H + 6.0
		for ink: bool in [false, true]:
			var count := _ink if ink else _paper
			if count < maxi(_paper, _ink):
				continue
			var end := _line_mark(maxi(count - 1, 0), ink).x
			end = lerpf(0.0, end + (4.0 if ink else -4.0), _lead)
			under.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(end, y + 0.5)]), 3.2, 0.5)
		under.draw(_lines)
	_lines.draw_set_transform_matrix(Transform2D.IDENTITY)


## A side's tallies on a gauge, the newest partly drawn while it comes.
func _draw_tallies(sym: String, row: String, pencil_seed: int, colour: Color) -> void:
	var shown: float = _s[sym][row + "_shown"]
	var whole := floori(shown)
	var count := mini(ceili(shown), TALLY_MAX)
	for n in count:
		var pencil := Pencil.new(pencil_seed + n)
		pencil.colour = colour
		var part := 1.0 if n < whole else shown - whole
		pencil.stroke(_tally_path(sym, row, n, part), 1.7, 0.25)
		pencil.draw(_lines)


## One side of the line: pencil marks to the left for paper, ink marks to the right.
func _draw_line_side(ink: bool, shown: float, pencil_seed: int) -> void:
	var p := _line_pitch()
	var whole := floori(shown)
	for n in ceili(shown):
		var pencil := Pencil.new(pencil_seed + n)
		pencil.colour = INK if ink else PENCIL
		var x := LINE_GAP + p
		var top := Vector2(x if ink else -x, -LINE_MARK_H)
		var path := _tally_path_at(top, n, p, p * 1.6, LINE_MARK_H * 2.0, 1.0 if ink else -1.0,
				1.0 if n < whole else shown - whole)
		pencil.stroke(path, 1.8, 0.25)
		pencil.draw(_lines)


## The ink blobs: filled pips, the things travelling, and the flood over the line.
func _draw_fills() -> void:
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		for k in 3:
			var fill: float = s.fill[k]
			if k == 2:
				fill = minf(fill, s.third)
			if fill > 0.01:
				_fills.draw_circle(_pip_at(sym, k), (PIP_R - 1.1) * fill, INK)
			var ghost: bool = (k >= int(s.craving) and k < int(s.craving) + int(s.ghost_pips)) \
					or (s.ghost_roll and k >= int(s.craving))
			if ghost and fill < 0.5:
				_fills.draw_circle(_pip_at(sym, k), PIP_R - 1.1, Color(INK, 0.16))
	for mover in _travel:
		var t: float = mover.t
		var from: Vector2 = mover.from
		var to: Vector2 = mover.to
		var lift := Vector2(0.0, -16.0 if not mover.line else -18.0)
		# Along a curve that lifts off the page between the two places.
		var bend := from.lerp(to, 0.5) + lift
		var at := from.lerp(bend, t).lerp(bend.lerp(to, t), t)
		if mover.line:
			at = _line_xform() * at
		var colour: Color = (mover.from_colour as Color).lerp(mover.to_colour, t)
		_fills.draw_circle(at, lerpf(PIP_R - 1.1, 2.4, t), colour)
	if _flood > 0.01:
		_fills.draw_set_transform_matrix(_line_xform())
		var w := LINE_HALF * _flood
		_fills.draw_rect(Rect2(-w, -LINE_H - 2.0, w, LINE_H * 2.0 + 4.0), Color(INK, 0.92))
		_fills.draw_set_transform_matrix(Transform2D.IDENTITY)


## The numbers when they show, the slip of a rollover's card, the line's name and counts,
## and the ledgers.
func _draw_text() -> void:
	var edge := Color(0.05, 0.035, 0.06, 0.85)
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		var g: Dictionary = _g[sym]
		var r: Rect2 = g.rect
		for row: String in ["habit", "temper"]:
			if int(s[row]) > TALLY_MAX:
				var end := _tally_top(sym, row, TALLY_MAX - 1) + Vector2(4.0, TALLY_H_TWO - 1.0)
				_text.draw_string(_heavy, end, "+%d" % (int(s[row]) - TALLY_MAX), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LABEL)
		# A gauge's number under it for a moment after it changes, on the page's own ground.
		if not _numbers and not s.ghost_roll:
			for row: String in ["craving", "habit", "temper"]:
				var note: float = s.note[row]
				if note <= 0.01:
					continue
				var x: float = g.pips_x + PIP_PITCH * 0.5 if row == "craving" else g[row + "_x"] + g[row + "_w"] * 0.5
				var at := Vector2(x - 20.0, r.end.y + 13.0)
				_text.draw_string_outline(_heavy, at, str(s[row]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, 4, Color(edge, edge.a * note))
				_text.draw_string(_heavy, at, str(s[row]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color(CREAM_TEXT, note))
		if s.ghost_roll:
			var slip := _roll_slip(sym)
			_text.draw_string(_slanted, slip.position + Vector2(0.0, 12.0), _roll_words(sym), HORIZONTAL_ALIGNMENT_CENTER,
					slip.size.x, 11, _faint(INK, 0.85))
	# The line's name over its banner, on the page's own ground: it stays at home.
	if _grow < 1.0:
		var home := _line_home()
		var name_at := Vector2(home.x - 100.0, home.y - LINE_H - 7.0)
		_text.draw_string_outline(_heavy, name_at, LINE_NAME, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 13, 4, Color(edge, edge.a * (1.0 - _grow)))
		_text.draw_string(_heavy, name_at, LINE_NAME, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 13, Color(CREAM_TEXT, 1.0 - _grow))
	# The line's counts, at the banner's two ends: each a little larger for a moment when it changes.
	var xf := _line_xform()
	var scale := xf.get_scale().x
	var drop := _heavy.get_ascent(int(round(13.0 * scale))) * 0.36
	var paper_text := "PAPER %d" % _paper
	var ink_text := "%d INK" % _ink
	var paper_px := int(round((13.0 + 2.0 * _line_note.paper) * scale))
	var ink_px := int(round((13.0 + 2.0 * _line_note.ink) * scale))
	var ink_w := _heavy.get_string_size(ink_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ink_px).x
	# Once the ink has flooded the paper's side, the paper's count is read through it.
	_text.draw_string(_heavy, xf * Vector2(-LINE_HALF + LINE_NOTCH + 5.0, 0.0) + Vector2(0.0, drop), paper_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, paper_px, PENCIL.lerp(INK_WASH, _flood))
	_text.draw_string(_heavy, xf * Vector2(LINE_HALF - LINE_NOTCH - 5.0, 0.0) + Vector2(-ink_w, drop), ink_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, ink_px, INK)
	if _numbers:
		for sym in SYMS:
			_draw_ledger(sym, true)
	elif _hover != "":
		_draw_ledger(_hover, false)


## A symbol's ledger, under its gauge: its gauges in numbers, and its two Roots in the deck
## with their worth. With `every`, the three ledgers stand side by side under the row.
func _draw_ledger(sym: String, every: bool) -> void:
	var s: Dictionary = _s[sym]
	var zone := ArenaLayout.symbols(size)
	var middle := _gauge_rect(sym).get_center().x
	if every:
		middle = zone.get_center().x + (SYMS.find(sym) - 1) * (LEDGER.x + 6.0)
	var box := Rect2(Vector2(middle - LEDGER.x * 0.5, zone.end.y + 14.0), LEDGER)
	box.position.x = clampf(box.position.x, 0.0, size.x - box.size.x)
	_text.draw_rect(Rect2(box.position + Vector2(3.0, 4.0), box.size), SHADOW)
	_text.draw_rect(box, Color(0.95, 0.91, 0.80))
	_text.draw_rect(box, PENCIL, false, 1.0)
	var x := box.position.x + 10.0
	var y := box.position.y + 19.0
	var names: Array = [RulesConfig.ROOT[sym].paper, RulesConfig.ROOT[sym].ink]
	_text.draw_string(_heavy, Vector2(x, y), "Habit %d   Craving %d   Temper %d" % [s.habit, s.craving, s.temper],
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 16.0, 13, PENCIL)
	_text.draw_string(_slanted, Vector2(x, y + 24.0), "%d %s in the deck, %d chips each" % [s.paper, names[0], s.paper_chips],
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 16.0, 12, PENCIL)
	_text.draw_string(_slanted, Vector2(x, y + 46.0), "%d %s in the deck, %d chips each" % [s.ink, names[1], s.ink_chips],
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 16.0, 12, INK)


# --- Shapes ---------------------------------------------------------------------------------


## A colour as drawn faintly on the cream: `a` 0 is the cream, 1 the colour itself.
static func _faint(colour: Color, a: float) -> Color:
	return CREAM.lerp(colour, clampf(a, 0.0, 1.0))


## The path of the n-th tally of a gauge's side, `part` of it drawn.
func _tally_path(sym: String, row: String, n: int, part: float) -> PackedVector2Array:
	var col := n % TALLY_ROW
	var path := _tally_path_at(Vector2.ZERO, col, _pitch, _gap, _tally_h(sym, row), 1.0, part)
	# The mark's own place already holds its distance along the row: draw the mark from there.
	var from := _tally_top(sym, row, n) - Vector2(_tally_x(col, _pitch, _gap), 0.0)
	for i in path.size():
		path[i] += from
	return path


## The n-th tally of a row that starts at `top` (its first mark's top end) and runs in
## direction `dir` (1 right, -1 left): a stroke down, or every fifth one a stroke across the four.
static func _tally_path_at(top: Vector2, n: int, pitch: float, gap: float, height: float, dir: float,
		part: float) -> PackedVector2Array:
	var from: Vector2
	var to: Vector2
	if n % 5 == 4:
		var start := _tally_x(n - 4, pitch, gap)
		from = top + Vector2(dir * (start - 2.5), height - 2.0)
		to = top + Vector2(dir * (start + pitch * 3.0 + 2.5), 2.0)
	else:
		var x := _tally_x(n, pitch, gap)
		from = top + Vector2(dir * x, 0.0)
		to = top + Vector2(dir * x + 0.4, height)
	return PackedVector2Array([from, from.lerp(to, clampf(part, 0.05, 1.0))])


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


## A small padlock at `at`, faint by `a`.
func _lock_path(pencil: Pencil, at: Vector2, a: float) -> void:
	pencil.colour = _faint(PENCIL, a)
	pencil.stroke(_rect_path(Rect2(at + Vector2(-4.5, 0.0), Vector2(9.0, 8.0))), 1.4, 0.15)
	pencil.stroke(_arc(at, Vector2(3.0, 4.0), PI, TAU, 8), 1.4, 0.15)


## The placeholder sketch of a symbol around `c`, as the page's own pencil drawings, `k` times
## the size it is written at below (its lines a little heavier than that would make them).
func _sketch(pencil: Pencil, sym: String, c: Vector2, k: float = 1.0) -> void:
	var w := lerpf(k, 1.0, 0.45)
	match sym:
		"lamp":
			# An oil lamp: a foot, a round fount, a collar, and a tall chimney with its flame.
			pencil.stroke(PackedVector2Array([c + Vector2(-18, 34) * k, c + Vector2(18, 34) * k]), 2.0 * w, 0.6 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-8, 33) * k, c + Vector2(-5, 22) * k, c + Vector2(5, 22) * k, c + Vector2(8, 33) * k]), 1.7 * w, 0.5 * k)
			pencil.stroke(_ellipse(c + Vector2(0, 11) * k, Vector2(16, 11) * k, 22), 1.9 * w, 0.6 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(8, 0) * k]), 1.7 * w, 0.4 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-5, -1) * k, c + Vector2(-9, -14) * k, c + Vector2(-6, -34) * k]), 1.6 * w, 0.5 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(5, -1) * k, c + Vector2(9, -14) * k, c + Vector2(6, -34) * k]), 1.6 * w, 0.5 * k)
			pencil.stroke(_arc(c + Vector2(0, -12) * k, Vector2(3, 7) * k, PI * 0.1, PI * 1.9, 14), 1.4 * w, 0.3 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-12, 9) * k, c + Vector2(-9, 15) * k]), 1.0 * w, 0.3 * k)
		"heart":
			# A heart as in an anatomy plate: the lobed body leaning left, the great vessels above.
			var body := PackedVector2Array()
			for step in 31:
				var t := TAU * step / 30.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				body.append(c + Vector2(x * 1.2, y * 1.2 + 8.0).rotated(-0.25) * k)
			pencil.stroke(body, 2.0 * w, 0.6 * k)
			pencil.stroke(_arc(c + Vector2(4, -16) * k, Vector2(9, 10) * k, PI, PI * 2.0, 12), 2.0 * w, 0.5 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-5, -15) * k, c + Vector2(-5, -30) * k]), 1.7 * w, 0.5 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(12, -15) * k, c + Vector2(14, -28) * k]), 1.7 * w, 0.5 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-2, -4) * k, c + Vector2(4, 12) * k, c + Vector2(2, 26) * k]), 1.0 * w, 0.4 * k)
		"mirror":
			# A hand mirror: an oval glass in its frame, a handle, and a glint.
			pencil.stroke(_ellipse(c + Vector2(0, -8) * k, Vector2(20, 25) * k, 30), 2.0 * w, 0.6 * k)
			pencil.stroke(_ellipse(c + Vector2(0, -8) * k, Vector2(16, 21) * k, 28), 1.2 * w, 0.4 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-4, 16) * k, c + Vector2(-4, 36) * k, c + Vector2(4, 36) * k, c + Vector2(4, 16) * k]), 1.8 * w, 0.5 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-9, -20) * k, c + Vector2(-3, -27) * k]), 1.3 * w, 0.3 * k)
			pencil.stroke(PackedVector2Array([c + Vector2(-10, -12) * k, c + Vector2(-6, -16) * k]), 1.0 * w, 0.3 * k)
