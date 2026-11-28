class_name ArenaSymbols
extends Control
## The three symbols and the line, each in its zone of the arena's page (ArenaLayout).
##
## Cloak, Quill and Cane are three gauges, one under another at the top of the left column,
## each between brackets on a slip of cream stock that reads on the slate and on Hyde's ink
## alike, beginning at the column's left edge and as wide as its marks need. A gauge reads
## from left to right: Habit as ink tallies, the symbol's Root's drawing in chalk, Craving as ink pips
## (two places; a third shows only while Craving rolls over), a bar, and Temper as pencil
## tallies. A side with nothing on it has a dash. Under the top rule, in the centre, lies the line, as
## a banner: Paper Roots as pencil tallies to the left of a centre mark, Ink Roots as ink
## tallies to the right, both at one pitch so the longer side is the side ahead, with the two
## counts at the banner's ends.
##
## Resting the pointer on a gauge opens its ledger to the right of the column: what each of
## its three gauges pays now (from the run's numbers, `set_dials`), how each is earned, how
## many Paper and Ink Roots of it the deck holds, and what one of each is worth now. When a gauge changes, what changed is written there too for a moment, by name
## ("Craving 2"), level with the gauge; not while `show_numbers(true)` (a held key, whose own
## sheet gives every number) is on.
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
## - `flash(sym)`: the drawing pulses.
## - `set_pay(sym, row, words, pulse)`: a gauge that pays ("temper" or "habit"): its tallies
##   pulse by `pulse` and "Temper 2" stands beside it, as strong as `words` (each 0 to 1). The
##   beat that pays drives both, through the beat queue. `pay_place(sym, row)` is where its
##   mark lands, `pay_from(sym)` where its mult leaves from.
## - `set_line(paper, ink)`: the line's bar is shared out again: one slot changes side, or
##   slots are gained or lost. `line_across(to_ink)` and `line_gain(ink)` are the two moves named.
## - `line_check(centre)`: the line grows to `centre` (in this control's coordinates) and,
##   if it holds, the larger side is underlined and the line shrinks back; returns true. If
##   ink is ahead, the ink floods across the paper side and stays; returns false.
##   `line_reset()` puts it back.
##
## The ghost marks of a play (doc: what the play will do) are still: `show_preview(p)` takes
## RulesView.preview(), or set them one by one with `ghost_craving`, `ghost_rollover`,
## `ghost_temper` and `set_lock`. `clear_ghosts()` takes them all away.

const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")
## Each gauge shows its Root's drawing in chalk: the drawing's clear lines and an outline round
## its shapes, baked from the sheet the card's picture comes from (studio/card_picture_bake.gd,
## laid out as a card's picture is), and printed grainy and a little broken.
const DRAWING_MATERIAL: ShaderMaterial = preload("res://shaders/chalk_drawing_material.tres")
const PICTURES := {
	"lamp": preload("res://art/gauge_pictures/cloak.png"),
	"heart": preload("res://art/gauge_pictures/quill.png"),
	"mirror": preload("res://art/gauge_pictures/cane_hand.png"),
}

const SYMS: Array[String] = ["lamp", "heart", "mirror"]

## A gauge: its height, the gap between two (and so the step from one to the next under it,
## GAUGE_STEP), and the room inside it, from left to right: the
## bracket's, the drawing's, each pip's (three are kept, the third for a rollover and the lock),
## and the least room each side's tallies are given. The drawing is fitted in a box SKETCH_BOX
## large around its middle, a little wider than its room, as its edges are mostly clear.
const GAUGE_H := 32.0
const GAUGE_GAP := 6.0
const GAUGE_STEP := GAUGE_H + GAUGE_GAP
const PAD := 9.0
const SKETCH_W := 22.0
const SKETCH_BOX := Vector2(26.0, 27.0)
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
## The line's banner: half its length and height, and the room a count takes at each end.
## Between the counts is the bar, one slot to a Root: Paper's from the left, Ink's from the
## right. A slot narrower than LINE_SLOT_MIN keeps no tally of its own; only every so many do.
## The middle is marked: Ink past it is Ink ahead. Ink within LINE_NEAR of Paper is marked too.
const LINE_HALF := 180.0
const LINE_H := 15.0
const LINE_COUNT := 88.0
const LINE_NOTCH := 11.0
const LINE_MARK_H := 8.0
const LINE_SLOT_MIN := 5.0
const LINE_NEAR := 2
## How much larger the line is drawn at the centre of the page.
const GROW_SCALE := 1.6
## The ledger's width (its height is its lines'), how far right of the column it and a
## change's number stand, the room inside its edge, the size of its words and of its head, the
## room between two of its parts, and how long the pointer rests on a gauge before it opens.
const LEDGER := Vector2(440.0, 0.0)
const LEDGER_GAP := 8.0
const LEDGER_PAD := 10.0
const LEDGER_SIZE := 14
const LEDGER_HEAD := 15
const LEDGER_STEP := 6.0
## The room between two lines of the ledger's words, over their size.
const LEDGER_LEADING := 4.0
const LEDGER_REST := 0.15
## The size a change's number is written at, and from one line of them to the next.
const NOTE_SIZE := 15
const NOTE_STEP := 17.0

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

## The gauges are night surfaces: lines and labels in chalk, Hyde's marks in his light.
const SURFACE := Palette.NIGHT_2
const FRAME := Palette.CHALK_2
const MARK := Palette.CHALK
const INK := Palette.HYDE
## Each gauge's own colour: its tallies, its ghosts, its words and its line in the ledger.
const TEMPER := Palette.TEMPER
const HABIT := Palette.HABIT
## The size of the words a gauge that pays stands beside it.
const PAY_SIZE := 15
## The gap between a paying gauge's slip and its words, and how far past their end the middle
## of what it pays sets off.
const PAY_GAP := 8.0
const PAY_FROM := 52.0

## Changes the lines and the tags' edges a little while keeping the look.
@export var rng_seed := 11

## What is shown of each symbol, see _blank().
var _s := {}
var _paper := 0
var _ink := 0
var _paper_shown := 0.0
var _ink_shown := 0.0
## The line's counts are lit for a moment when they change.
var _line_note := {"paper": 0.0, "ink": 0.0, "edge": 0.0}
var _note_fade := {} # "lamp/craving": the Tween that fades that note
var _grow := 0.0
var _centre := Vector2.ZERO
var _lead := 0.0
var _flood := 0.0
var _lock := 0.0
var _numbers := false
var _hover := ""
## The gauge under the pointer whose ledger opens when the pointer has rested (LEDGER_REST).
var _pending := ""
var _rest := Timer.new()
## The numbers the run plays by, for what each gauge pays: the game's own until set_dials.
var _dials := RulesDials.new()
## The column as it is laid out now (see _measure): each gauge's places by its symbol (`y` is
## the height of its middle), and the tallies' pitch and group gap.
var _g := {}
var _pitch := TALLY_PITCH
var _gap := TALLY_GAP
## Things on their way from one mark to another: {from, to, t, from_colour, to_colour, line}.
var _travel: Array[Dictionary] = []

var _back := Control.new()
var _drawings := Control.new()
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
	_drawings.material = DRAWING_MATERIAL
	_drawings.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_back.draw.connect(_draw_back)
	_drawings.draw.connect(_draw_drawings)
	_lines.draw.connect(_draw_lines)
	_fills.draw.connect(_draw_fills)
	_text.draw.connect(_draw_text)
	for child: Control in [_back, _drawings, _lines, _fills, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	_rest.one_shot = true
	_rest.wait_time = LEDGER_REST
	_rest.timeout.connect(_rested)
	add_child(_rest)
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
		"pay": "", "pay_words": 0.0, "pay_pulse": 0.0, # a gauge that pays, and how strongly it shows
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


## The numbers the run plays by (`run.dials`): the ledger says from them what each gauge pays.
func set_dials(dials: RulesDials) -> void:
	_dials = dials
	_text.queue_redraw()


## True while a held key shows every number on a sheet of its own (ArenaViews): the gauges
## then show no ledger and no change's number.
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


## Joins the three pips, outlines the next Habit tally, and puts a slip at the gauge's right
## end that names the Ink Root that would join.
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
## Habit tally, and the pips are left empty. The drawing pulses and Habit's number shows.
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


## Tame the Other: each filled pip travels into Temper and becomes a tally there. The pips are
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
		var mover := _traveller(_pip_at(sym, k), _tally_at(sym, "temper", int(s.temper) + i), INK, MARK, false)
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


## The drawing pulses.
func flash(sym: String) -> void:
	var s: Dictionary = _s[sym]
	await _tween(FLASH_TIME, func(t: float) -> void: s.flash = sin(t * PI))


## A gauge that pays: its tallies pulse by `pulse` and its name and value stand beside it, as
## strong as `words` (each 0 to 1). Both 0 put it back.
func set_pay(sym: String, row: String, words: float, pulse: float) -> void:
	var s: Dictionary = _s[sym]
	s.pay = row if words > 0.0 or pulse > 0.0 else ""
	s.pay_words = words
	s.pay_pulse = pulse
	# Craving's number would stand on the words' line and read as part of them: it goes, and
	# does not come back when they fade.
	if words > 0.0 and s.note.craving > 0.0:
		_end_note(sym, "craving")
		s.note.craving = 0.0
	_redraw()


## Where a gauge's mark lands, on the page: the middle of its side's tallies.
func pay_place(sym: String, row: String) -> Vector2:
	_measure()
	var n := maxi(int(_s[sym][row]), 1)
	var first := _tally_at(sym, row, 0)
	var last := _tally_at(sym, row, n - 1)
	return get_global_transform() * first.lerp(last, 0.5)


## Where what a gauge pays leaves from, on the page: just past the words it stands beside it,
## clear of the column's edge.
func pay_from(sym: String) -> Vector2:
	_measure()
	var words := _heavy.get_string_size(_pay_words(sym), HORIZONTAL_ALIGNMENT_LEFT, -1.0, PAY_SIZE).x
	return get_global_transform() * Vector2(_pay_x(sym) + words + PAY_FROM, _y(sym))


## What a paying gauge says beside it: "Temper 2".
func _pay_words(sym: String) -> String:
	var s: Dictionary = _s[sym]
	return "" if s.pay == "" else "%s %d" % [str(s.pay).capitalize(), int(s[s.pay])]


## Where a paying gauge's words begin: just right of its slip.
func _pay_x(sym: String) -> float:
	return _gauge_rect(sym).end.x + PAY_GAP


func _grow_tallies(sym: String, row: String, n: int) -> void:
	var s: Dictionary = _s[sym]
	var key := row + "_shown"
	var from: float = s[key]
	s[row] = n
	_note(sym, row)
	if is_equal_approx(from, float(n)):
		return
	await _tween(TALLY_TIME * maxf(1.0, absf(n - from)), func(t: float) -> void: s[key] = lerpf(from, float(n), t))


## Writes a gauge's number right of the column, level with the gauge, for a moment.
func _note(sym: String, row: String) -> void:
	var note: Dictionary = _s[sym].note
	note[row] = 1.0
	_redraw()
	_end_note(sym, row)
	var tw := create_tween()
	_note_fade[sym + "/" + row] = tw
	tw.tween_interval(NOTE_TIME)
	tw.tween_method(func(a: float) -> void:
		note[row] = a
		_text.queue_redraw(), 1.0, 0.0, 0.4)


# A note's fading is stopped where it is.
func _end_note(sym: String, row: String) -> void:
	var tw: Tween = _note_fade.get(sym + "/" + row)
	if tw and tw.is_valid():
		tw.kill()


# --- The line's movements -------------------------------------------------------------------


## Shares the bar out again as `paper` against `ink`: one slot changes side when one side
## loses one and the other gains it, else the slots are re-divided, each narrowing or widening
## while the new ones arrive (or the lost ones leave) at the side's end, by the meeting edge.
func set_line(paper: int, ink: int) -> void:
	if paper == _paper - 1 and ink == _ink + 1:
		await line_across(true)
	elif paper == _paper + 1 and ink == _ink - 1:
		await line_across(false)
	else:
		await _share(paper, ink)


## The slot at the meeting edge changes side: a paper Root to ink (a stain), or with `to_ink`
## false an ink Root to paper (a turn). Its colour and tally change as the edge moves one slot.
func line_across(to_ink: bool) -> void:
	if (_paper if to_ink else _ink) < 1:
		return
	await _share(_paper - 1 if to_ink else _paper + 1, _ink + 1 if to_ink else _ink - 1)


func _share(paper: int, ink: int) -> void:
	var p0 := _paper_shown
	var i0 := _ink_shown
	_paper = paper
	_ink = ink
	_line_lit(p0 != paper, i0 != ink)
	await _tween(TRAVEL_TIME, func(t: float) -> void:
		_paper_shown = lerpf(p0, float(paper), t)
		_ink_shown = lerpf(i0, float(ink), t))


## One side gains a Root: a slot at its end, by the meeting edge.
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
		_light(side)
	if paper or ink:
		_light("edge")


## A part of the line lit for a moment: a side's count, or the meeting edge.
func _light(part: String) -> void:
	_line_note[part] = 1.0
	var tw := create_tween()
	tw.tween_interval(NOTE_TIME)
	tw.tween_method(func(a: float) -> void:
		_line_note[part] = a
		_back.queue_redraw()
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
	for child: Control in [_back, _drawings, _lines, _fills, _text]:
		child.queue_redraw()


# --- Where things are -----------------------------------------------------------------------


func _lay_out() -> void:
	for child: Control in [_back, _drawings, _lines, _fills, _text]:
		child.size = size
	_redraw()


## Lays the column out in its zone: the gauges one under another from the zone's top left,
## each as wide as its marks need, and the tallies drawn closer when the widest gauge would be
## wider than the zone.
func _measure() -> void:
	var zone := ArenaLayout.symbols(size)
	var fixed := PAD + 5.0 + SKETCH_W + 6.0 + PIP_PITCH * 3.0 + 3.0 + 6.0 + PAD
	var widths: Array[float] = []
	var sides: Array[Vector2] = []
	for squeeze: float in [1.0, 0.85, 0.7, 0.58, 0.48]:
		_pitch = TALLY_PITCH * squeeze
		_gap = TALLY_GAP * squeeze
		widths.clear()
		sides.clear()
		var widest := 0.0
		for sym in SYMS:
			var side := Vector2(_side_width(sym, "habit"), _side_width(sym, "temper"))
			sides.append(side)
			widths.append(fixed + side.x + side.y)
			widest = maxf(widest, fixed + side.x + side.y)
		if widest <= zone.size.x:
			break
	var x := zone.position.x
	for i in 3:
		var y := zone.position.y + GAUGE_H * 0.5 + i * GAUGE_STEP
		var habit_x := x + PAD + 2.0
		var sketch_x := habit_x + sides[i].x + 3.0 + SKETCH_W * 0.5
		var pips_x := sketch_x + SKETCH_W * 0.5 + 6.0 + PIP_PITCH * 0.5
		var bar_x := pips_x + PIP_PITCH * 2.5 + 3.0
		_g[SYMS[i]] = {
			"rect": Rect2(x, y - GAUGE_H * 0.5, widths[i], GAUGE_H), "y": y,
			"habit_x": habit_x, "sketch_x": sketch_x, "pips_x": pips_x, "bar_x": bar_x,
			"temper_x": bar_x + 6.0, "habit_w": sides[i].x, "temper_w": sides[i].y,
		}


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


## Where what stands beside the column begins: the ledger, and a change's number.
func _beside_x() -> float:
	return ArenaLayout.symbols(size).end.x + LEDGER_GAP


## The height of the middle of a symbol's gauge.
func _y(sym: String) -> float:
	return _g[sym].y


## The middle of a symbol's drawing, on the page: where what its gauges pay comes from.
func sketch_place(sym: String) -> Vector2:
	_measure()
	return get_global_transform() * Vector2(_g[sym].sketch_x, _y(sym))


## The middle of a symbol's k-th pip (0 to 2), drawn together as `join` rises.
func _pip_at(sym: String, k: int) -> Vector2:
	var join: float = _s[sym].join
	var x: float = _g[sym].pips_x + k * PIP_PITCH + (1 - k) * join * (PIP_PITCH - PIP_R * 1.6)
	return Vector2(x, _y(sym))


## The x of the n-th tally from where a row starts, at a pitch and a group gap.
static func _tally_x(n: int, pitch: float, gap: float) -> float:
	return (n / 5) * (pitch * 4.0 + gap) + (n % 5) * pitch


## The top end of a side's n-th tally on a gauge.
func _tally_top(sym: String, row: String, n: int) -> Vector2:
	var x: float = _g[sym][row + "_x"] + _tally_x(n % TALLY_ROW, _pitch, _gap)
	if _side_count(sym, row) > TALLY_ROW:
		return Vector2(x, _y(sym) - TALLY_H_TWO - 1.5 + (n / TALLY_ROW) * (TALLY_H_TWO + 3.0))
	return Vector2(x, _y(sym) - TALLY_H * 0.5)


## The middle of a side's n-th tally: where something travelling to it lands.
func _tally_at(sym: String, row: String, n: int) -> Vector2:
	return _tally_top(sym, row, mini(n, TALLY_MAX - 1)) + Vector2(0.0, _tally_h(sym, row) * 0.5)


## Half the bar between the two counts.
static func _bar_half() -> float:
	return LINE_HALF - LINE_COUNT


## One Root's slot on the bar, as wide as the bar shared between all the Roots shown.
func _line_pitch() -> float:
	return _bar_half() * 2.0 / maxf(_paper_shown + _ink_shown, 1.0)


## Where Paper's share meets Ink's, in the line's own coordinates.
func _line_edge() -> float:
	return -_bar_half() + _line_pitch() * _paper_shown


## The middle of a side's n-th slot, counted from that side's end of the bar, in the line's
## own coordinates.
func _line_mark(n: int, ink: bool) -> Vector2:
	var x := -_bar_half() + (n + 0.5) * _line_pitch()
	return Vector2(-x if ink else x, 0.0)


## Ink is near: within LINE_NEAR of Paper, or ahead.
func _line_near() -> bool:
	return _paper - _ink <= LINE_NEAR and _paper + _ink > 0


## The banner's middle at home: its zone's middle.
func _line_home() -> Vector2:
	return ArenaLayout.balance(size).get_center()


## The line's banner at home, on the page: where a hover on it is caught.
func line_rect() -> Rect2:
	return get_global_transform() * Rect2(_line_home() - Vector2(LINE_HALF, LINE_H), Vector2(LINE_HALF, LINE_H) * 2.0)


## The line's banner, in the line's own coordinates: a strip whose two ends are cut to a notch.
static func _banner() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-LINE_HALF, -LINE_H), Vector2(LINE_HALF, -LINE_H),
			Vector2(LINE_HALF - LINE_NOTCH, 0.0), Vector2(LINE_HALF, LINE_H), Vector2(-LINE_HALF, LINE_H),
			Vector2(-LINE_HALF + LINE_NOTCH, 0.0)])


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


## A gauge's ledger opens once the pointer has rested on it, so that crossing the column does
## not flash one ledger after another; it closes as soon as the pointer leaves the gauge.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := ""
		for sym in SYMS:
			if _gauge_rect(sym).has_point(event.position):
				over = sym
		if over == _hover and over != "":
			return
		if _hover != "":
			hover_symbol("")
		_pending = over
		if over == "":
			_rest.stop()
		else:
			_rest.start()


func _rested() -> void:
	if _pending != "":
		hover_symbol(_pending)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_pending = ""
		_rest.stop()
		if _hover != "":
			hover_symbol("")


# --- Drawing --------------------------------------------------------------------------------


## The gauges' slips with their shadows and their pulse, the slip of a rollover's card, and
## the line's banner.
func _draw_back() -> void:
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		var flash: float = maxf(s.flash, s.pay_pulse)
		_slip(_gauge_rect(sym), SURFACE.lerp(Palette.NIGHT_3, flash))
		if s.ghost_roll:
			_slip(_roll_slip(sym), SURFACE)
	_back.draw_set_transform_matrix(_line_xform())
	var banner := _banner()
	_back.draw_colored_polygon(banner, SURFACE)
	# The bar: Paper's share from the left, Ink's from the right, meeting at the edge.
	var h := _bar_half()
	var edge := _line_edge()
	var top := -LINE_H + 2.0
	var tall := LINE_H * 2.0 - 4.0
	if _paper_shown > 0.0:
		_back.draw_rect(Rect2(-h, top, edge + h, tall), Palette.JEKYLL_DEEP)
	if _ink_shown > 0.0:
		_back.draw_rect(Rect2(edge, top, h - edge, tall), Palette.HYDE_DEEP)
	# The edge lit for a moment when the share changes.
	var lit: float = _line_note.edge
	if lit > 0.01 and _paper_shown + _ink_shown > 0.0:
		_back.draw_rect(Rect2(edge - 1.5, top - 1.0, 3.0, tall + 2.0), Color(Palette.CHALK, 0.9 * lit))
	banner.append(banner[0])
	_back.draw_polyline(banner, Palette.RULE, 1.5)
	# The middle's notches, above and below the bar: Ink past them is Ink ahead. Heavier
	# while Ink is near.
	var near := _line_near()
	var notch := 6.0 if near else 4.0
	var colour := Palette.CHALK if near else Color(Palette.CHALK, 0.7)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(0.0, side * (LINE_H - 2.0))
		var out := side * (LINE_H + notch + 1.0)
		_back.draw_colored_polygon(PackedVector2Array([tip, Vector2(notch * 0.8, out), Vector2(-notch * 0.8, out)]), colour)
	_back.draw_set_transform_matrix(Transform2D.IDENTITY)


## A night surface with its square rule border.
func _slip(r: Rect2, colour: Color) -> void:
	_back.draw_rect(r, colour)
	_back.draw_rect(r, Palette.RULE, false, 1.5)


## The words on the slip of a rollover's card, and the slip: at the gauge's right end, level
## with it, so that it lies on no other gauge.
func _roll_words(sym: String) -> String:
	return "Habit %d  +1 %s" % [int(_s[sym].habit) + 1, RulesConfig.ROOT[sym].ink]


func _roll_slip(sym: String) -> Rect2:
	var w := _slanted.get_string_size(_roll_words(sym), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x + 12.0
	var r := _gauge_rect(sym)
	return Rect2(r.end.x + 3.0, r.get_center().y - 8.0, w, 16.0)


## Each symbol's Root's drawing in chalk, pulled toward Hyde's light while it flashes.
func _draw_drawings() -> void:
	for sym in SYMS:
		var drawn: Texture2D = PICTURES[sym]
		var g: Dictionary = _g[sym]
		var box := Rect2(Vector2(g.sketch_x, g.y) - SKETCH_BOX * 0.5, SKETCH_BOX)
		_drawings.draw_texture_rect(drawn, ArenaCardPictures.drawing_box(drawn, box), false,
				MARK.lerp(INK, float(_s[sym].flash) * 0.6))


## Every pencil line: the brackets, the pips' rims, the tallies, the ghosts, the
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
		frame.colour = FRAME
		var top := r.position.y + 5.0
		var bottom := r.end.y - 5.0
		frame.stroke(PackedVector2Array([Vector2(r.position.x + 8.5, top), Vector2(r.position.x + 4.0, top),
				Vector2(r.position.x + 4.0, bottom), Vector2(r.position.x + 8.5, bottom)]), 1.9, 0.3)
		frame.stroke(PackedVector2Array([Vector2(r.end.x - 8.5, top), Vector2(r.end.x - 4.0, top),
				Vector2(r.end.x - 4.0, bottom), Vector2(r.end.x - 8.5, bottom)]), 1.9, 0.3)
		var bar_x: float = g.bar_x
		frame.stroke(PackedVector2Array([Vector2(bar_x, g.y - 9.0), Vector2(bar_x + 0.4, g.y + 9.0)]), 1.4, 0.3)
		# A side with no mark on it, and none coming, has a dash.
		frame.colour = _faint(FRAME, 0.55)
		for row: String in ["habit", "temper"]:
			var coming: bool = s.ghost_roll if row == "habit" else int(s.ghost_temper) > 0
			if s[row + "_shown"] < 0.01 and not coming:
				var x: float = g[row + "_x"]
				frame.stroke(PackedVector2Array([Vector2(x + 2.0, g.y + 0.5), Vector2(x + 9.0, g.y)]), 1.5, 0.3)
		frame.draw(_lines)
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
			rims.colour = _faint(INK if ghost else FRAME, present * (1.0 if ghost else 0.8))
			rims.stroke(_circle(_pip_at(sym, k), PIP_R, 12), 2.0 if ghost else 1.4, 0.25)
		if s.ghost_roll:
			# The three pips joined by a loop round them.
			rims.colour = _faint(HABIT, 0.8)
			var mid := _pip_at(sym, 1)
			rims.stroke(_ellipse(mid, Vector2(PIP_PITCH + PIP_R + 2.5, PIP_R + 3.5), 24), 1.4, 0.4)
		rims.draw(_lines)
		_draw_tallies(sym, "habit", seed_base + 10, HABIT)
		_draw_tallies(sym, "temper", seed_base + 60, TEMPER)
		var ghosts := Pencil.new(seed_base + 120)
		ghosts.colour = _faint(HABIT, 0.45)
		if s.ghost_roll and int(s.habit) < TALLY_MAX:
			ghosts.stroke(_tally_path(sym, "habit", int(s.habit), 1.0), 1.5, 0.3)
		for n_ghost in int(s.ghost_temper):
			var n: int = int(s.temper) + n_ghost
			if n < TALLY_MAX:
				ghosts.colour = _faint(TEMPER, 0.45)
				ghosts.stroke(_tally_path(sym, "temper", n, 1.0), 1.5, 0.3)
		if _lock > 0.01:
			ghosts.colour = _faint(INK, 0.4)
			_lock_path(ghosts, _pip_at(sym, 2) + Vector2(0.0, -3.0), _lock)
		ghosts.draw(_lines)
	_lines.draw_set_transform_matrix(_line_xform())
	if _line_near():
		var line := Pencil.new(rng_seed * 1000 + 900)
		line.colour = MARK
		line.stroke(PackedVector2Array([Vector2(0.0, -LINE_H + 2.0), Vector2(0.3, LINE_H - 2.0)]), 2.4, 0.3)
		line.draw(_lines)
	_draw_line_side(false, _paper_shown, rng_seed * 1000 + 1000)
	_draw_line_side(true, _ink_shown, rng_seed * 1000 + 3000)
	if _lead > 0.01:
		var under := Pencil.new(rng_seed * 1000 + 950)
		under.colour = MARK
		var y := LINE_H + 6.0
		var edge := _line_edge()
		for ink: bool in [false, true]:
			var count := _ink if ink else _paper
			if count < maxi(_paper, _ink):
				continue
			# From the meeting edge out along the side's share.
			var end := lerpf(edge, _bar_half() if ink else -_bar_half(), _lead)
			under.stroke(PackedVector2Array([Vector2(edge, y), Vector2(end, y + 0.5)]), 3.2, 0.5)
		under.draw(_lines)
	_lines.draw_set_transform_matrix(Transform2D.IDENTITY)


## A side's tallies on a gauge, the newest partly drawn while it comes; brighter and heavier
## while the gauge pays.
func _draw_tallies(sym: String, row: String, pencil_seed: int, colour: Color) -> void:
	var s: Dictionary = _s[sym]
	var shown: float = s[row + "_shown"]
	var whole := floori(shown)
	var count := mini(ceili(shown), TALLY_MAX)
	var pulse: float = s.pay_pulse if s.pay == row else 0.0
	for n in count:
		var pencil := Pencil.new(pencil_seed + n)
		pencil.colour = colour.lerp(Palette.CHALK, pulse * 0.5)
		var part := 1.0 if n < whole else shown - whole
		pencil.stroke(_tally_path(sym, row, n, part), 1.7 + 1.3 * pulse, 0.25)
		pencil.draw(_lines)


## One side's tallies on the bar, one in the middle of each of its slots; the newest partly
## drawn while its slot arrives or leaves. Where the slots are too narrow for one each, only
## every so many keep theirs, and the count at the end says the number.
func _draw_line_side(ink: bool, shown: float, pencil_seed: int) -> void:
	var p := _line_pitch()
	var every := maxi(1, ceili(LINE_SLOT_MIN / p))
	var whole := floori(shown)
	for n in ceili(shown):
		if (n + 1) % every != 0:
			continue
		var pencil := Pencil.new(pencil_seed + n)
		pencil.colour = MARK
		var x := _line_mark(n, ink).x
		var part := 1.0 if n < whole else shown - whole
		var from := Vector2(x, -LINE_MARK_H)
		var to := Vector2(x + 0.4, LINE_MARK_H)
		pencil.stroke(PackedVector2Array([from, from.lerp(to, clampf(part, 0.05, 1.0))]),
				minf(1.8, p * every * 0.3), 0.25)
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
		# The ink spreads from the middle over the paper side, as much of it as is banner.
		var w := LINE_HALF * _flood
		var spread := PackedVector2Array([Vector2(-w, -LINE_H), Vector2(0.0, -LINE_H), Vector2(0.0, LINE_H),
				Vector2(-w, LINE_H)])
		for part in Geometry2D.intersect_polygons(spread, _banner()):
			_fills.draw_colored_polygon(part, Color(Palette.HYDE_DEEP, 0.92))
		_fills.draw_set_transform_matrix(Transform2D.IDENTITY)


## The numbers when they show, the slip of a rollover's card, the line's counts, and the
## ledger.
func _draw_text() -> void:
	var edge := Color(Palette.OUTLINE, 0.85)
	for sym in SYMS:
		var s: Dictionary = _s[sym]
		var g: Dictionary = _g[sym]
		var r: Rect2 = g.rect
		for row: String in ["habit", "temper"]:
			if int(s[row]) > TALLY_MAX:
				var end := _tally_top(sym, row, TALLY_MAX - 1) + Vector2(4.0, TALLY_H_TWO - 1.0)
				_text.draw_string(_heavy, end, "+%d" % (int(s[row]) - TALLY_MAX), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Palette.CHALK_2)
		# What changed on a gauge, by name, for a moment after: right of the column and level
		# with the gauge, on the page's own ground. In the gauge's own order, one line each
		# about the gauge's middle: side by side, two would reach the line's banner. Not while
		# a rollover's slip stands at the gauge's end: on a wide gauge the two would cross.
		if not _numbers and not s.ghost_roll:
			var lit: Array[String] = []
			var named: bool = s.pay != "" and s.pay_words > 0.01
			for row: String in ["habit", "craving", "temper"]:
				# A gauge whose words stand at its slip is named there, not twice. Craving's
				# number would stand on their line and read as part of them: it is left out.
				if s.note[row] > 0.01 and not (named and (row == s.pay or row == "craving")):
					lit.append(row)
			var base := r.get_center().y + _heavy.get_ascent(NOTE_SIZE) * 0.36 - (lit.size() - 1) * NOTE_STEP * 0.5
			for i in lit.size():
				var note: float = s.note[lit[i]]
				var words := "%s %d" % [lit[i].capitalize(), int(s[lit[i]])]
				var at := Vector2(_beside_x(), base + i * NOTE_STEP)
				_text.draw_string_outline(_heavy, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NOTE_SIZE, 4, Color(edge, edge.a * note))
				var colour: Color = {"habit": HABIT, "temper": TEMPER}.get(lit[i], Palette.CHALK)
				_text.draw_string(_heavy, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NOTE_SIZE, Color(colour, note))
		_draw_pay(sym, edge)
		if s.ghost_roll:
			var slip := _roll_slip(sym)
			_text.draw_string(_slanted, slip.position + Vector2(0.0, 12.0), _roll_words(sym), HORIZONTAL_ALIGNMENT_CENTER,
					slip.size.x, 11, HABIT)
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
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, paper_px, Palette.CHALK)
	# Ink's count in Hyde's light while Ink is near.
	_text.draw_string(_heavy, xf * Vector2(LINE_HALF - LINE_NOTCH - 5.0, 0.0) + Vector2(-ink_w, drop), ink_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, ink_px, INK if _line_near() else Palette.CHALK)
	if _hover != "" and not _numbers:
		_draw_ledger(_hover)


## The words of a gauge that pays ("Temper 2"), just right of its slip and level with it, in
## the gauge's colour.
func _draw_pay(sym: String, edge: Color) -> void:
	var s: Dictionary = _s[sym]
	var a: float = s.pay_words
	if s.pay == "" or a <= 0.01 or _numbers:
		return
	var words := _pay_words(sym)
	var colour := TEMPER if s.pay == "temper" else HABIT
	var at := Vector2(_pay_x(sym), _gauge_rect(sym).get_center().y + _heavy.get_ascent(PAY_SIZE) * 0.36)
	_text.draw_string_outline(_heavy, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PAY_SIZE, 4, Color(edge, edge.a * a))
	_text.draw_string(_heavy, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PAY_SIZE, Color(colour, a))


## A symbol's ledger, to the right of the column, its top at the readout's, so that it lies
## under the line's banner and not on it, and above the hand: what its three
## gauges pay now, how each is earned, and its two Roots in the deck with their worth.
func _draw_ledger(sym: String) -> void:
	var parts := _ledger_parts(sym)
	var inner := LEDGER.x - LEDGER_PAD * 2.0
	var height := LEDGER_PAD * 2.0
	for part: Dictionary in parts:
		part.lines = _wrap(part.font, part.text, part.size, inner)
		height += float(part.gap) + (part.lines as PackedStringArray).size() * (part.size + LEDGER_LEADING)
	# At the readout's top whichever gauge is hovered: lower, the hand would cover its foot.
	var top := ArenaLayout.readout(size).position.y
	var box := Rect2(Vector2(_beside_x(), top), Vector2(LEDGER.x, height))
	box.position = box.position.clamp(Vector2.ZERO, (size - box.size).max(Vector2.ZERO))
	_text.draw_rect(box, SURFACE)
	_text.draw_rect(box, Palette.RULE, false, 1.5)
	var x := box.position.x + LEDGER_PAD
	var y := box.position.y + LEDGER_PAD
	for part: Dictionary in parts:
		var gap: float = part.gap
		y += gap
		if part.rule:
			var at := y - gap * 0.5
			_text.draw_line(Vector2(x, at), Vector2(box.end.x - LEDGER_PAD, at), Palette.RULE, 1.0)
		var font: Font = part.font
		var px: int = part.size
		for line in part.lines as PackedStringArray:
			_text.draw_string(font, Vector2(x, y + font.get_ascent(px)), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, part.colour)
			y += px + LEDGER_LEADING


## Words broken into lines no wider than `width`, at word ends.
static func _wrap(font: Font, text: String, px: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > width:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## The ledger's words, from the top down, each {text, font, size, colour, gap (the room over
## it), rule (a rule in that room)}. Every number is the run's: the gauges from the table,
## what they pay from the dials.
func _ledger_parts(sym: String) -> Array[Dictionary]:
	var s: Dictionary = _s[sym]
	var d := _dials
	var root: Dictionary = RulesConfig.ROOT[sym]
	var paper: String = root.paper
	var ink: String = root.ink
	var out: Array[Dictionary] = []
	var add := func(text: String, font: Font, px: int, colour: Color, gap: float, rule: bool = false) -> void:
		out.append({"text": text, "font": font, "size": px, "colour": colour, "gap": gap, "rule": rule})
	add.call("%s: %s (Paper), %s (Ink)" % [root.label, paper, ink], _heavy, LEDGER_HEAD, Palette.CHALK, 0.0)
	var habit := int(s.habit)
	if habit > 0:
		add.call("Habit %d, Hyde's. Each %s: +%d chips. +%d mult for each %s played." % [habit, ink,
				d.habit_chips * habit, d.habit_mult * habit, ink], _heavy, LEDGER_SIZE, HABIT, LEDGER_STEP)
	else:
		add.call("Habit 0: pays nothing yet.", _heavy, LEDGER_SIZE, HABIT, LEDGER_STEP)
	var craving := int(s.craving)
	var pays := "Each %s: +%d chips." % [ink, d.craving_chips * craving] if craving > 0 else "Pays nothing yet."
	add.call("Craving %d of %d. %s At %d it becomes a Habit, and a new %s joins the deck." % [craving, d.craving_cap,
			pays, d.craving_cap, ink], _heavy, LEDGER_SIZE, Palette.CHALK, LEDGER_STEP)
	var temper := int(s.temper)
	if temper > 0:
		add.call("Temper %d, Jekyll's. Each %s: +%d chips. +%d mult once a play." % [temper, paper,
				d.temper_chips * temper, d.temper_mult * temper], _heavy, LEDGER_SIZE, TEMPER, LEDGER_STEP)
	else:
		add.call("Temper 0: pays nothing yet.", _heavy, LEDGER_SIZE, TEMPER, LEDGER_STEP)
	var rise: String = RulesConfig.HANDS.hyde.stirring.name
	var turn: String = RulesConfig.HANDS.jekyll.sublimation.name
	add.call("Craving rises as Hyde plays %s in any hand from %s up. %s (%s with %s) turns it into Temper." % [ink,
			rise, turn, paper, ink], _slanted, LEDGER_SIZE, Palette.CHALK_2, LEDGER_STEP * 2.0, true)
	add.call("%d %s in the deck, %d chips each" % [s.paper, paper, s.paper_chips], _slanted, LEDGER_SIZE, Palette.CHALK_2,
			LEDGER_STEP * 2.0, true)
	add.call("%d %s in the deck, %d chips each" % [s.ink, ink, s.ink_chips], _slanted, LEDGER_SIZE, Palette.CHALK_2, 0.0)
	return out


# --- Shapes ---------------------------------------------------------------------------------


## A colour as drawn faintly on the night surface: `a` 0 is the surface, 1 the colour itself.
static func _faint(colour: Color, a: float) -> Color:
	return SURFACE.lerp(colour, clampf(a, 0.0, 1.0))


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
	pencil.colour = _faint(FRAME, a)
	pencil.stroke(_rect_path(Rect2(at + Vector2(-4.5, 0.0), Vector2(9.0, 8.0))), 1.4, 0.15)
	pencil.stroke(_arc(at, Vector2(3.0, 4.0), PI, TAU, 8), 1.4, 0.15)
