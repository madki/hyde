class_name ArenaNumbers
extends Control
## The round's numbers, drawn across the arena's page, each in its zone of ArenaLayout:
## everything a play changes about the round. Top left the night and the round with the
## night's title, and under them the target and the round's score; top right the sovereigns,
## a pile of coins with the count; in the centre the restraint gauge and under it the hand
## readout, one written line (a name, chips × mult, and the total once it is counted) with
## the stored restraint as ink drops at the line's end; at the foot the plays and discards
## left as tallies.
##
## It works out no rule. `show_table` puts up what RulesView.table() gives, at once,
## and `show_choice` the readout of RulesView.preview() for the chosen cards. Everything else
## is a call that moves one thing in its own time and returns the Tween doing it, so that a
## beat can wait for it (`await numbers.tick_chips(15).finished`):
##
## - `count_target(to)`, `count_score(to)`, `strike_target()`: the round's two numbers.
## - `name_hand(name, chips, mult)`, `tick_chips(by)`, `tick_mult(by)`, `pulse_chips()`,
##   `pulse_mult()`, `land_total()`, `send_total(score_to)`, `clear_readout()`: a play's
##   scoring, from the hand being named to the total joining the round's score.
## - `set_plays(n)`, `set_discards(n)`: a tally mark is drawn or rubbed out.
## - `set_stored(n)`, `fly_drop(by)`: ink drops come and go; one flies into the mult.
## - `count_sov(to)`.
## - `restraint`: the restraint gauge (scripts/arena_restraint.gd) lies in its own zone and
##   is driven through its own calls.
## - `mult_place()`, `sov_place()`, `plays_place()`, `heading_place()`, `heading_rect()`:
##   where things are, on the page.
##
## The times are the constants below, from the pace of the table; `speed` scales them all
## (hurrying).
##
## A debug build runs every call once with the C key (`demo`).

## Times, in seconds, at a speed of 1.
const TICK_TIMES: Array[float] = [0.30, 0.20, 0.14] ## a tick: the first five of a play, the next five, the rest
const MARK_TIME := 0.35 ## a tally mark, a drop, the strike
const LAND_TIME := 0.6 ## chips and mult become one total
const TRAVEL_TIME := 0.2 ## the total travels to the score...
const COUNT_IN_TIME := 0.3 ## ...and the score counts it in
const COUNT_TIME := 0.6 ## a number counts from one value to another
const PULSE_TIME := 0.3
const DROP_TIME := 0.45 ## a drop flies into the mult

## Text sizes.
const HEAD_SIZE := 13
const LABEL_SIZE := 11
const NUMBER_SIZE := 20
const READOUT_SIZE := 30
const NAME_SIZE := 22
const REASON_SIZE := 16
## The most coins drawn in the sovereigns' pile.
const COINS := 14
## Room kept for the stored drops at the end of the readout's line, and from one to the next.
const DROPS_ROOM := 100.0
const DROP_PITCH := 19.0

const PENCIL := Color(0.015, 0.025, 0.035)
## The numbers are cream, the brightest thing on the board; a tick lights them in the colour
## of the man who scores, and they return to cream.
const CREAM := Color(0.93, 0.87, 0.74)
const CYAN := Color(0.36, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.34, 0.78)
const DROP_INK := Color(0.42, 0.13, 0.44)
const DROP_SHINE := Color(0.8, 0.55, 0.8)
## The small words (TARGET, SCORE, sovereigns): cream too, a little back, to read on slate and on ink.
const LABEL := Color(0.93, 0.87, 0.74, 0.62)
const GOLD := Color(0.78, 0.64, 0.33)
const GOLD_DARK := Color(0.42, 0.31, 0.12)
const COIN_EDGE := Color(0.07, 0.05, 0.04)
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

## Changes the hand of the lines a little while keeping the look.
@export var rng_seed := 11
## The C key runs `demo` in a debug build.
@export var debug_keys := true

## Who scores: the colour a tick lights in.
var is_jekyll := true
## How fast every call plays: 1 at the usual pace, 3 to hurry.
var speed := 1.0

## The restraint gauge, laid out in its zone.
var restraint := ArenaRestraint.new()

var _marks := Control.new()
var _text := Control.new()
var _heavy := FontVariation.new()
var _slanted := FontVariation.new()
var _tweens: Array[Tween] = []

# What is shown. Numbers are floats so that they can count.
var _heading := ""
var _title := ""
var _target := 0.0
var _score := 0.0
var _strike := 0.0
var _plays := 0.0
var _discards := 0.0
var _stored := 0.0
var _sov := 0.0
# The readout: a name or a reason, then chips × mult, or the total once they have landed.
var _name := ""
var _note := ""
var _reason := ""
var _numbers := false
var _chips := 0.0
var _mult := 0.0
var _chips_glow := 0.0
var _mult_glow := 0.0
var _chips_pop := 0.0
var _mult_pop := 0.0
var _merge := 0.0
var _total := 0
var _travel := -1.0 ## -1 while the total is not on its way
var _fly := -1.0 ## -1 while no drop is flying
var _ticks := 0
## Where the readout's line begins, from the page's left: set when a hand is put up, so that
## the line is centred then and does not shift as its numbers grow.
var _line_left := 0.0
## The most plays and discards the tallies have shown: they are centred for that many.
var _plays_most := 0.0
var _discards_most := 0.0
## Before a drink: this many drops outlined, as the restraint would be stored. Before a dose
## of salt: the stored drops struck through.
var _ghost_drops := 0
var _struck := false
## The chosen play would spend the stored drops: they lean towards the mult.
var _lean := false


func _init() -> void:
	# The engine's own font, as on the cards and the gauge, until the game has its two faces.
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1
	_slanted.base_font = ThemeDB.fallback_font
	_slanted.variation_embolden = 0.5
	_slanted.variation_transform = Transform2D(Vector2(1.0, 0.22), Vector2(0.0, 1.0), Vector2.ZERO)
	_marks.material = LINE_MATERIAL
	_marks.draw.connect(_draw_marks)
	_text.draw.connect(_draw_text)
	restraint.name = "Restraint"
	for child: Control in [_marks, restraint, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


func _process(_delta: float) -> void:
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid() and t.is_running())
	_redraw()
	if _tweens.is_empty():
		set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_keys and OS.is_debug_build() and key and key.pressed and not key.echo and key.keycode == KEY_C:
		demo()


# --- From the engine ---------------------------------------------------------------------

## Puts up a table as RulesView.table() gives it, at once: the night, the round's numbers,
## the tallies, the stored restraint, the gauge, the sovereigns, and the readout of
## `table.play` (the chosen cards).
func show_table(table: Dictionary) -> void:
	_stop()
	var night: Dictionary = table.night
	set_night(night.no, night.title, night.round, night.scene)
	is_jekyll = table.stance == "jekyll"
	_target = table.target
	_score = table.score
	_strike = 1.0 if table.score >= table.target else 0.0
	_plays = table.plays
	_discards = table.discards
	_plays_most = maxf(_plays, 1.0)
	_discards_most = maxf(_discards, 1.0)
	_stored = table.restraint.stored
	_sov = table.sov
	restraint.show_table(table)
	restraint.snap()
	show_choice(table.play)


## The readout of the chosen cards, as RulesView.preview() gives it: null for none chosen.
## An allowed hand shows its name and its base (the hand's own chips and mult, without the
## cards'); one that is not allowed shows the reason in place of the name.
func show_choice(play: Variant) -> void:
	clear_readout()
	if play == null:
		return
	var p: Dictionary = play
	if not p.ok:
		_reason = p.reason
		_redraw()
		return
	var ev: Dictionary = p.ev
	var base_mult: Dictionary = ev.mult_parts[0]
	var note := ""
	if str(base_mult.label).ends_with(", hunted"):
		note = "(hunted)"
	show_hand(ev.name, ev.parts[0].v, base_mult.v, note)


## Puts a hand's name and two numbers in the readout at once. `note` is written small after
## the name, as "(hunted)".
func show_hand(hand_name: String, chips: int, mult: int, note: String = "") -> void:
	_stop_readout()
	_name = hand_name
	_note = note
	_reason = ""
	_numbers = true
	_chips = chips
	_mult = mult
	_merge = 0.0
	_travel = -1.0
	var r := ArenaLayout.readout(size)
	_line_left = r.position.x + maxf((r.size.x - _line().end) * 0.5, 0.0)
	_redraw()


## Empties the readout.
func clear_readout() -> void:
	_stop_readout()
	_name = ""
	_note = ""
	_reason = ""
	_numbers = false
	_merge = 0.0
	_travel = -1.0
	_ticks = 0
	_redraw()


# --- The round's numbers -----------------------------------------------------------------

## The heading: "NIGHT 2 · ROUND 1", or "NIGHT 2 · SCENE" in the night's scene, with the
## night's title under it.
func set_night(night_no: int, title: String, round_no: int, scene: bool) -> void:
	_heading = "NIGHT %d · %s" % [night_no, "SCENE" if scene else "ROUND %d" % round_no]
	_title = title
	_redraw()


## The target counts to `to`.
func count_target(to: int) -> Tween:
	return _count("_target", to, COUNT_TIME)


## The round's score counts to `to`.
func count_score(to: int) -> Tween:
	return _count("_score", to, COUNT_TIME)


## The target is struck through and the score underlined (or both rubbed out, with false).
func strike_target(struck: bool = true) -> Tween:
	var t := _tween()
	t.tween_property(self, "_strike", 1.0 if struck else 0.0, MARK_TIME)
	return t


## The plays left: a tally mark is drawn, or rubbed out.
func set_plays(n: int) -> Tween:
	_plays_most = maxf(_plays_most, n)
	return _count("_plays", n, MARK_TIME, Tween.TRANS_LINEAR)


## The discards left: a tally mark is drawn, or rubbed out.
func set_discards(n: int) -> Tween:
	_discards_most = maxf(_discards_most, n)
	return _count("_discards", n, MARK_TIME, Tween.TRANS_LINEAR)


## The stored restraint: drops come or go, at the end of the readout's line.
func set_stored(n: int) -> Tween:
	return _count("_stored", n, MARK_TIME, Tween.TRANS_LINEAR)


## The marks before a drink or a dose of salt: `outlined` drops drawn faint after the stored
## (what a drink would store), and the stored drops `struck` through (what salt would lose).
func preview_stored(outlined: int, struck: bool) -> void:
	_ghost_drops = outlined
	_struck = struck
	_redraw()


## The stored drops lean towards the mult: the chosen play would spend them.
func lean_stored(on: bool) -> void:
	_lean = on
	_redraw()


## The sovereigns count to `to`.
func count_sov(to: int) -> Tween:
	return _count("_sov", to, COUNT_TIME)


# --- A play's scoring --------------------------------------------------------------------

## The hand is named: its name and base go up and both numbers pulse once.
func name_hand(hand_name: String, chips: int, mult: int, note: String = "") -> Tween:
	show_hand(hand_name, chips, mult, note)
	var t := _tween()
	_pulse(t, "_chips_pop")
	_pulse(t, "_mult_pop")
	return t


## Chips tick up by `by`, lit for a moment in the scorer's colour. The first five ticks of a
## play are slower than the next.
func tick_chips(by: int) -> Tween:
	return _tick("_chips", by)


## Mult ticks up by `by`.
func tick_mult(by: int) -> Tween:
	return _tick("_mult", by)


func pulse_chips() -> Tween:
	var t := _tween()
	_pulse(t, "_chips_pop")
	return t


func pulse_mult() -> Tween:
	var t := _tween()
	_pulse(t, "_mult_pop")
	return t


## One stored drop flies from the line's end into the mult, and the mult ticks up by `by`.
func fly_drop(by: int) -> Tween:
	if _stored < 1.0:
		return _tick("_mult", by)
	var t := _tween()
	_stored = ceilf(_stored) - 1.0
	_fly = 0.0
	t.tween_property(self, "_fly", 1.0, DROP_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "_fly", -1.0, 0.0)
	_tick_into(t, "_mult", by)
	return t


## The total is written after chips × mult, in the scorer's colour.
func land_total() -> Tween:
	_total = roundi(_chips) * roundi(_mult)
	var t := _tween()
	t.tween_property(self, "_merge", 1.0, LAND_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	return t


## The total travels to the round's score, which then counts up to `score_to`. The readout
## is empty afterwards.
func send_total(score_to: int) -> Tween:
	if _merge < 1.0:
		_total = roundi(_chips) * roundi(_mult)
		_merge = 1.0
	_travel = 0.0
	var t := _tween()
	t.tween_property(self, "_travel", 1.0, TRAVEL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(clear_readout)
	t.tween_property(self, "_score", float(score_to), COUNT_IN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return t


# --- Running each call once (debug) ------------------------------------------------------

## Plays a made-up play on a new run, through every call once, and waits for it. `stop_at`
## leaves it at one moment: "rest", "reason", "choice", "scoring", "total", or "" for the end.
func demo(stop_at: String = "") -> void:
	var run := Rules.new_run({}, 1)
	var table := RulesView.table(run)
	show_table(table)
	_target = 0.0
	await count_target(table.target).finished
	if stop_at == "rest":
		return
	var ids: Array = []
	for card: Dictionary in table.hand:
		ids.append(card.id)
	# The best play of five or fewer cards from the hand, and a choice that is not allowed.
	var best: Dictionary = {}
	var refused: Dictionary = {}
	for mask in range(1, 1 << ids.size()):
		var chosen: Array = []
		for i in ids.size():
			if mask & (1 << i):
				chosen.append(ids[i])
		var p := RulesView.preview(run, chosen)
		if not p.ok:
			if refused.is_empty() or chosen.size() <= 5:
				refused = p
		elif best.is_empty() or p.ev.score > best.ev.score:
			best = p
	# A round well on its way, so that the play crosses the target; two stored drops.
	await count_score(roundi(table.target * 0.8) - 1).finished
	await set_stored(2).finished
	if not refused.is_empty():
		show_choice(refused)
		if stop_at == "reason":
			return
		await get_tree().create_timer(1.2 / speed).timeout
	show_choice(best)
	if stop_at == "choice":
		return
	await get_tree().create_timer(1.0 / speed).timeout
	var ev: Dictionary = best.ev
	await set_plays(table.plays - 1).finished
	await name_hand(ev.name, ev.parts[0].v, ev.mult_parts[0].v).finished
	for part: Dictionary in ev.parts.slice(1):
		await tick_chips(part.v).finished
	if stop_at == "scoring":
		return
	for part: Dictionary in ev.mult_parts.slice(1):
		await tick_mult(part.v).finished
	await fly_drop(2).finished
	await fly_drop(2).finished
	await land_total().finished
	if stop_at == "total":
		return
	var score_to := roundi(_score) + _total
	await send_total(score_to).finished
	if score_to >= roundi(_target):
		await strike_target().finished
	await set_discards(table.discards - 1).finished
	await count_sov(table.sov + 3).finished


# --- Inside ------------------------------------------------------------------------------

func _tween() -> Tween:
	var t := create_tween().set_speed_scale(speed)
	_tweens.append(t)
	set_process(true)
	return t


func _count(property: String, to: float, time: float, trans: Tween.TransitionType = Tween.TRANS_CUBIC) -> Tween:
	var t := _tween()
	t.tween_property(self, property, to, time).set_ease(Tween.EASE_OUT).set_trans(trans)
	return t


func _tick(property: String, by: int) -> Tween:
	var t := _tween()
	_tick_into(t, property, by)
	return t


func _tick_into(t: Tween, property: String, by: int) -> void:
	var time: float = TICK_TIMES[mini(floori(_ticks / 5.0), TICK_TIMES.size() - 1)]
	_ticks += 1
	var glow := property + "_glow"
	var pop := property + "_pop"
	var to: float = roundf(get(property)) + by
	t.tween_callback(func() -> void:
		set(glow, 1.0)
		set(pop, 0.18))
	t.tween_property(self, property, to, time * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(self, pop, 0.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(self, glow, 0.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## A number swells a little and settles, alongside whatever `t` is doing at that step.
func _pulse(t: Tween, pop: String) -> void:
	t.parallel().tween_method(func(v: float) -> void: set(pop, 0.25 * sin(v * PI)), 0.0, 1.0, PULSE_TIME)


func _stop() -> void:
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	_chips_glow = 0.0
	_mult_glow = 0.0
	_chips_pop = 0.0
	_mult_pop = 0.0
	_fly = -1.0


func _stop_readout() -> void:
	_chips_glow = 0.0
	_mult_glow = 0.0
	_chips_pop = 0.0
	_mult_pop = 0.0


func _redraw() -> void:
	_marks.queue_redraw()
	_text.queue_redraw()


func _lay_out() -> void:
	for child: Control in [_marks, _text]:
		child.size = size
	var gauge := ArenaLayout.restraint(size)
	restraint.position = gauge.position
	restraint.size = gauge.size
	_redraw()


func _man() -> Color:
	return CYAN if is_jekyll else MAGENTA


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


# --- Where things are --------------------------------------------------------------------

## The middle of the readout's mult, on the page: where what is paid into it travels to.
func mult_place() -> Vector2:
	return get_global_transform() * _mult_middle()


## The sovereigns' pile, on the page.
func sov_place() -> Vector2:
	return get_global_transform() * _pile_at()


## The last mark of the plays' tally, on the page.
func plays_place() -> Vector2:
	return get_global_transform() * Vector2(_tally_left(0) + 4.0 + maxf(_plays - 1.0, 0.0) * 8.0, _tally_top(0) + 12.0)


## Where the round's heading is written, on the page: its middle, and all of it with the
## target and the score under it.
func heading_place() -> Vector2:
	var r := ArenaLayout.heading(size)
	return get_global_transform() * (r.position + Vector2(90.0, 14.0))


func heading_rect() -> Rect2:
	return get_global_transform() * ArenaLayout.heading(size)


func _baseline() -> float:
	var r := ArenaLayout.readout(size)
	return r.position.y + r.size.y * 0.5 + READOUT_SIZE * 0.36


## Where each piece of the readout's line begins, from the line's own start: the dash, the
## chips, the × sign, the mult, the = sign, the total, and the line's end without the total.
func _line() -> Dictionary:
	var x := _slanted.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE).x
	var out := {"note": x}
	if _note != "":
		x += _slanted.get_string_size(" " + _note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	out.dash = x + 10.0
	x += 44.0
	out.chips = x
	x += _number_width(_thousands(roundi(_chips))) + 9.0
	out.times = x
	x += 25.0
	out.mult = x
	out.mult_w = _number_width(str(roundi(_mult)))
	x += out.mult_w
	out.end = x
	out.equals = x + 12.0
	out.total = x + 38.0
	return out


func _number_width(text: String) -> float:
	return _heavy.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, READOUT_SIZE).x


func _mult_middle() -> Vector2:
	var line := _line()
	if not _numbers:
		return ArenaLayout.readout(size).get_center()
	return Vector2(_line_left + line.mult + line.mult_w * 0.5, _baseline() - READOUT_SIZE * 0.35)


func _drop_at(i: int) -> Vector2:
	var r := ArenaLayout.readout(size)
	return Vector2(r.end.x - DROPS_ROOM + 10.0 + i * DROP_PITCH, _baseline() - 9.0)


## Where the target's and the score's numbers begin, and their baseline.
func _target_at() -> Vector2:
	var r := ArenaLayout.heading(size)
	return r.position + Vector2(58.0, 45.0)


func _score_at() -> Vector2:
	var r := ArenaLayout.heading(size)
	return r.position + Vector2(208.0, 45.0)


## The foot of the sovereigns' pile: the coins are heaped up from here.
func _pile_at() -> Vector2:
	var r := ArenaLayout.sovereigns(size)
	return Vector2(r.get_center().x, r.position.y + 40.0)


## The tallies lie in the lower part of the controls' zones, under the words written there.
func _tally_zone(i: int) -> Rect2:
	return ArenaLayout.controls_play(size) if i == 0 else ArenaLayout.controls_discard(size)


func _tally_top(i: int) -> float:
	return _tally_zone(i).end.y - 28.0


func _tally_left(i: int) -> float:
	var most := _plays_most if i == 0 else _discards_most
	var groups := floorf((most - 1.0) / 5.0)
	var last := int(most - 1.0) % 5
	var width := groups * 44.0 + (30.0 if last == 4 else 4.0 + last * 8.0)
	return _tally_zone(i).get_center().x - width * 0.5


# --- Drawing -----------------------------------------------------------------------------

## The pencil and the chalk: the stroke between target and score, the strike and the
## underline, and the tally marks.
func _draw_marks() -> void:
	var pencil := Pencil.new(rng_seed)
	pencil.colour = Color(CREAM, 0.85)
	var target_at := _target_at()
	var score_at := _score_at()
	# The stroke that parts the target from the score.
	var part_x := score_at.x - 62.0
	pencil.stroke(PackedVector2Array([Vector2(part_x + 1.0, target_at.y - 17.0), Vector2(part_x, target_at.y + 3.0)]),
			1.3, 0.4, 0.2)
	# The target struck through, then the score underlined.
	if _strike > 0.0:
		var width := _heavy.get_string_size(_thousands(roundi(_target)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE).x
		var first := clampf(_strike * 2.0, 0.0, 1.0)
		var from := target_at + Vector2(-4.0, -6.0)
		pencil.stroke(PackedVector2Array([from, from.lerp(target_at + Vector2(width + 4.0, -9.0), first)]), 2.2, 0.5)
		var second := clampf(_strike * 2.0 - 1.0, 0.0, 1.0)
		if second > 0.0:
			var score_w := _heavy.get_string_size(_thousands(roundi(_score)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE).x
			var under := score_at + Vector2(-3.0, 5.0)
			pencil.stroke(PackedVector2Array([under, under.lerp(score_at + Vector2(score_w + 3.0, 4.0), second)]), 2.0, 0.5)
	for i in 2:
		_tally(pencil, _tally_left(i), _tally_top(i), _plays if i == 0 else _discards)
	pencil.draw(_marks)


## Tally marks in fives, the fifth across the other four. The last mark is drawn (or rubbed
## out) from the top down as the count passes a whole number.
func _tally(pencil: Pencil, left: float, top: float, level: float) -> void:
	var bottom := top + 24.0
	for k in ceili(level):
		var part := clampf(level - k, 0.0, 1.0)
		var group := floori(k / 5.0)
		var x0 := left + group * 44.0
		var from: Vector2
		var to: Vector2
		if k % 5 == 4:
			from = Vector2(x0 - 4.0, bottom - 3.0)
			to = Vector2(x0 + 30.0, top + 4.0)
		else:
			from = Vector2(x0 + 2.0 + (k % 5) * 8.0, top)
			to = Vector2(x0 + 2.0 + (k % 5) * 8.0 + 1.5, bottom)
		pencil.stroke(PackedVector2Array([from, from.lerp(to, part)]), 3.0, 0.5, 0.0, 0.3)


## The words and the numbers, the sovereigns and the stored drops.
func _draw_text() -> void:
	var c := _text
	var head := ArenaLayout.heading(size)
	# The night and the round, and the night's title after them on the same line.
	var at := head.position + Vector2(0.0, 18.0)
	c.draw_string(_heavy, at, _heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HEAD_SIZE, CREAM)
	var head_w := _heavy.get_string_size(_heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HEAD_SIZE).x + 8.0
	c.draw_string(_slanted, at + Vector2(head_w, 0.0), _title, HORIZONTAL_ALIGNMENT_LEFT, head.size.x - head_w, HEAD_SIZE - 1, LABEL)

	var target_at := _target_at()
	c.draw_string(_heavy, Vector2(head.position.x, target_at.y - 2.0), "TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, LABEL)
	c.draw_string(_heavy, target_at, _thousands(roundi(_target)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE,
			CREAM.darkened(0.25 * _strike))
	var score_at := _score_at()
	c.draw_string(_heavy, Vector2(score_at.x - 50.0, score_at.y - 2.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, LABEL)
	var score_colour := CREAM.lerp(_man(), 0.6) if _travel >= 1.0 else CREAM
	c.draw_string(_heavy, score_at, _thousands(roundi(_score)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE, score_colour)

	_draw_sovereigns()
	_draw_readout()

	for i in ceili(_stored):
		_drop(_drop_at(i) + (Vector2(-5.0, -9.0) if _lean else Vector2.ZERO), clampf(_stored - i, 0.0, 1.0))
	for i in _ghost_drops:
		c.draw_arc(_drop_at(ceili(_stored) + i), 7.0, 0.0, TAU, 16, Color(CREAM, 0.75), 1.4)
	if _struck and _stored >= 1.0:
		c.draw_line(_drop_at(0) + Vector2(-10.0, 4.0), _drop_at(ceili(_stored) - 1) + Vector2(10.0, -4.0),
				CREAM, 2.0)
	if _fly >= 0.0:
		var from := _drop_at(roundi(_stored))
		var to := _mult_middle()
		var mid := (from + to) * 0.5 + Vector2(0.0, -26.0)
		var drop_at := from.lerp(mid, _fly).lerp(mid.lerp(to, _fly), _fly)
		_drop(drop_at, 1.0 - _fly * 0.6)


## The sovereigns: a heap of coins, one for each up to COINS, and the count under it.
func _draw_sovereigns() -> void:
	var c := _text
	var r := ArenaLayout.sovereigns(size)
	var foot := _pile_at()
	var held := roundi(_sov)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# Heaped in rows from the bottom up, each row a coin shorter: 5, 4, 3, 2.
	var k := 0
	for row in 4:
		var in_row := 5 - row
		for i in in_row:
			var jitter := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.5, 1.5))
			var tilt := rng.randf_range(-0.5, 0.5)
			if k < mini(held, COINS):
				_coin(foot + Vector2((i - (in_row - 1) * 0.5) * 18.0, -row * 9.0) + jitter, tilt)
			k += 1
	var count := str(held)
	var count_w := _heavy.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE).x
	var word := "sovereign" if held == 1 else "sovereigns"
	var word_w := _slanted.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	var left := r.get_center().x - (count_w + 6.0 + word_w) * 0.5
	var base := r.end.y - 22.0
	c.draw_string(_heavy, Vector2(left, base), count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE, CREAM)
	c.draw_string(_slanted, Vector2(left + count_w + 6.0, base - 1.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, LABEL)


## One coin of the heap, seen a little from above.
func _coin(at: Vector2, tilt: float) -> void:
	var c := _text
	c.draw_set_transform(at, tilt * 0.4, Vector2(1.0, 0.72))
	c.draw_circle(Vector2(0.0, 3.4), 10.4, COIN_EDGE)
	c.draw_circle(Vector2(0.0, 2.6), 9.2, GOLD_DARK)
	c.draw_circle(Vector2.ZERO, 10.4, COIN_EDGE)
	c.draw_circle(Vector2.ZERO, 9.2, GOLD)
	c.draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 20, GOLD_DARK, 1.1)
	c.draw_set_transform(Vector2.ZERO, 0.0)


func _draw_readout() -> void:
	var c := _text
	var r := ArenaLayout.readout(size)
	var base := _baseline()
	if _reason != "":
		# A long reason is wrapped: the zone has the height for two lines, about the place of one.
		var width := r.size.x - DROPS_ROOM
		var one := _slanted.get_string_size(_reason, HORIZONTAL_ALIGNMENT_LEFT, -1.0, REASON_SIZE).y
		var all := _slanted.get_multiline_string_size(_reason, HORIZONTAL_ALIGNMENT_CENTER, width, REASON_SIZE, 2).y
		c.draw_multiline_string(_slanted, Vector2(r.position.x, base - 5.0 - (all - one) * 0.5), _reason,
				HORIZONTAL_ALIGNMENT_CENTER, width, REASON_SIZE, 2, CREAM)
		return
	if not _numbers:
		return
	var line := _line()
	var left := _line_left
	c.draw_string(_slanted, Vector2(left, base - 2.0), _name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE, CREAM)
	if _note != "":
		c.draw_string(_slanted, Vector2(left + line.note, base - 2.0), " " + _note,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, MAGENTA)
	c.draw_string(_heavy, Vector2(left + line.dash, base - 4.0), "—", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, LABEL)
	_number(_thousands(roundi(_chips)), Vector2(left + line.chips, base), HORIZONTAL_ALIGNMENT_LEFT, 1.0 + _chips_pop,
			CREAM.lerp(_man(), _chips_glow))
	c.draw_string(_heavy, Vector2(left + line.times, base - 3.0), "×", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, LABEL)
	_number(str(roundi(_mult)), Vector2(left + line.mult, base), HORIZONTAL_ALIGNMENT_LEFT, 1.0 + _mult_pop,
			CREAM.lerp(_man(), _mult_glow))
	# The total is written after them as it is counted, and travels from there to the score.
	if _merge > 0.0 and _travel < 1.0:
		var a := clampf(_merge * 2.0, 0.0, 1.0)
		var total_at := Vector2(left + line.total, base)
		var grow := 1.0 + 0.2 * sin(_merge * PI)
		if _travel >= 0.0:
			total_at = total_at.lerp(_score_at(), _travel)
			grow = lerpf(1.0, float(NUMBER_SIZE) / READOUT_SIZE, _travel)
		else:
			c.draw_string(_heavy, Vector2(left + line.equals, base - 3.0), "=", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22,
					Color(LABEL, LABEL.a * a))
		_number(_thousands(_total), total_at, HORIZONTAL_ALIGNMENT_LEFT, grow, Color(CREAM.lerp(_man(), 0.85), a))


## A readout number with its baseline at `at`, aligned at `at` (right edge, left edge or
## middle), scaled about its own middle by `scale_by`.
func _number(text: String, at: Vector2, align: HorizontalAlignment, scale_by: float, colour: Color) -> void:
	var w := _heavy.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, READOUT_SIZE).x
	var left := at.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		left -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		left -= w * 0.5
	var middle := Vector2(left + w * 0.5, at.y - READOUT_SIZE * 0.35)
	_text.draw_set_transform(middle, 0.0, Vector2(scale_by, scale_by))
	_text.draw_string(_heavy, Vector2(left, at.y) - middle, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, READOUT_SIZE, colour)
	_text.draw_set_transform(Vector2.ZERO, 0.0)


## An ink drop: a rounded blot, narrowing to a point at the top, with a pale shine and a
## cream rim, so that it is seen on his ink as on the slate.
func _drop(at: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	var s := amount
	var points := PackedVector2Array()
	var rim := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		var p := Vector2(sin(a), -cos(a)) * 7.0 * s
		# Pull the top into a point.
		p.y -= maxf(0.0, -cos(a)) * 6.0 * s * (1.0 - absf(sin(a)))
		points.append(at + p)
		rim.append(at + p + p.normalized() * 1.6)
	_text.draw_colored_polygon(rim, Color(CREAM, 0.9))
	_text.draw_colored_polygon(points, DROP_INK)
	_text.draw_circle(at + Vector2(-2.0, -1.5) * s, 1.4 * s, DROP_SHINE)
