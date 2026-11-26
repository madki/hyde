extends Control
## The arena, where every round is played: a page of Dr Jekyll's night journal, its ruled
## border, Hyde's ink coming in from the right, and on it the table of the card game.
##
## The arena holds a run (RulesRun). Every move goes to the rules, which answer at once; the
## answer is then played back as beats (ArenaBeats), one thing at a time, and input waits
## until the last is done. The arena itself shows nothing of a move: it hands the move's
## events to the moment's script, `scripts/arena_moment_<move>.gd` (see ArenaTable), for the
## moves "round", "play", "discard", "pass", "drink" and "salt". A move with no script yet is
## still made: the table then shows its outcome at once.
##
## Keys: 1 to 9 and 0 choose cards, Enter plays (or passes), D discards, Q drinks, S takes
## salt, Esc lets the chosen cards go, and Shift (or Tab) held down shows every number. At a
## reward 1 to 3 take a card and 0 or Esc none. During a move a click or a key hurries it,
## and held down skips to its end.
##
## For a screenshot: `--seed=<n>` (the run's seed), `--ink=<0..100>` and
## `--volatility=<0..100>` (the page's ink), and `--keys=` to make moves first (see
## scripts/arena_bench.gd): `tools/shot.sh /abs/out.png res://scenes/arena.tscn --seed=3 --keys=12D`.
## `--zones` outlines and names every zone of the page's layout (ArenaLayout).

## A move has been played back to its end and input is open again.
signal settled

## How much of the page the ink covers, 0 to 100: the line's share (see `line_share`), or
## what `--ink` pins it at.
var ink_percent := 50.0:
	set(value):
		ink_percent = clampf(value, 0.0, 100.0)
		if _ink:
			_ink.percent = ink_percent
## How restless the ink is in Hyde's stance, 0 to 100.
var ink_volatility := 50.0:
	set(value):
		ink_volatility = clampf(value, 0.0, 100.0)
		if _ink:
			_ink.volatility = ink_volatility

## The table's parts, as the moments' scripts are handed them.
var t := ArenaTable.new()

@onready var _border: ArenaBorder = $Border
@onready var _ink: ArenaInk = $Ink
@onready var _hand: ArenaHand = $Hand
@onready var _numbers: ArenaNumbers = $Numbers
@onready var _symbols: ArenaSymbols = $Symbols
@onready var _means: ArenaMeans = $Means
@onready var _controls: ArenaControls = $Controls
@onready var _heading: ArenaHeading = $Heading

var _run: RulesRun
## The events of the round this table opens with.
var _opening: Array = []
var _beats := ArenaBeats.new()
var _busy := true


func _ready() -> void:
	if Shot.has_arg("ink"):
		ink_percent = float(Shot.arg("ink"))
	if Shot.has_arg("volatility"):
		ink_volatility = float(Shot.arg("volatility"))
	_take_run()
	_build()
	resized.connect(_lay_out)
	_lay_out()
	if Shot.has_arg("zones"):
		add_child(ArenaZones.new())
	_follow_line_from(RulesView.table(_run))
	_ink.set_ink(ink_percent, ink_volatility, _run.stance == "jekyll")
	_ink.snap_to_stance()
	_hand.max_chosen = _run.dials.max_play
	_hand.enabled = false
	_hand.chosen_changed.connect(_on_choice)
	_controls.lower(false)
	_controls.play_pressed.connect(_pressed.bind(play_chosen))
	_controls.discard_pressed.connect(_pressed.bind(discard_chosen))
	_controls.pass_pressed.connect(_pressed.bind(pass_play))
	_means.drink_pressed.connect(_pressed.bind(drink))
	_means.salt_pressed.connect(_pressed.bind(take_salt))
	for extra: String in ["ghosts", "previews", "twist", "views", "sound"]:
		var script := _script("res://scripts/arena_extra_%s.gd" % extra)
		if script:
			script.setup(t)
	# The run's own furniture, before its first round is dealt.
	var table := RulesView.table(_run)
	_symbols.set_dials(_run.dials)
	_symbols.show_table(table)
	_means.show_table(table, _run.dials)
	_start.call_deferred()
	await ArenaBench.run_if_requested(self)
	Shot.run_if_requested(self)


## True while no move is being played back and the player may act.
func is_idle() -> bool:
	return not _busy


## The run being played.
func run() -> RulesRun:
	return _run


## Plays the chosen cards.
func play_chosen() -> void:
	if not _busy:
		await do_move("play", Rules.play(_run, _hand.chosen()))


## Discards the chosen cards.
func discard_chosen() -> void:
	if not _busy:
		await do_move("discard", Rules.discard(_run, _hand.chosen()))


## Passes the play, when nothing can be played and no discard is left.
func pass_play() -> void:
	if not _busy:
		await do_move("pass", Rules.pass_play(_run))


## Drinks the draught.
func drink() -> void:
	if not _busy:
		await do_move("drink", Rules.drink(_run))


## Takes a dose of salt.
func take_salt() -> void:
	if not _busy:
		await do_move("salt", Rules.take_salt(_run))


## Plays back a move the rules have made: `result` is what they returned. One they refused
## ({ok: false}) changes nothing. Returns when the move is over and input is open again.
func do_move(move: String, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	_busy = true
	_hand.enabled = false
	_controls.lower()
	if not move in ["play", "discard"]:
		_hand.clear_chosen()
	if move != "play":
		_numbers.show_choice(null)
	t.move_begun.emit(move)
	t.after = RulesView.table(_run)
	t.unhandled = false
	var script := _script("res://scripts/arena_moment_%s.gd" % move)
	if script:
		script.add(t, result)
	else:
		t.unhandled = true
	if t.unhandled:
		_beats.add_call(t.catch_up)
	await _beats.run()
	await ArenaFirsts.show_due(t, result.events)
	if _run.phase != "play":
		# The round is over: the table stays as its end left it, and goes on.
		t.freshen()
		await _go_on()
		return
	t.sync()
	_busy = false
	_hand.enabled = true
	_controls.rise()
	settled.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if t.waiting_press and ((key and key.pressed and not key.echo) or (button and button.pressed)):
		get_viewport().set_input_as_handled()
		Sfx.play("button")
		t.pressed.emit()
		return
	if not key or not key.pressed or key.echo:
		return
	if _busy:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if _controls.can_pass():
				_pressed(pass_play)
			elif _controls.can_play():
				_pressed(play_chosen)
			else:
				Sfx.play("refuse")
		KEY_D:
			if _controls.can_discard():
				_pressed(discard_chosen)
			else:
				Sfx.play("refuse")
		KEY_Q:
			if Rules.can_drink(_run).ok:
				_pressed(drink)
			else:
				_means.refused()
		KEY_S:
			if Rules.can_salt(_run).ok:
				_pressed(take_salt)
			else:
				_means.refused()
		KEY_ESCAPE:
			_hand.put_back_all()
		KEY_0:
			_hand.press_at(9)
		_:
			if key.keycode >= KEY_1 and key.keycode <= KEY_9:
				_hand.press_at(key.keycode - KEY_1)
			else:
				return
	get_viewport().set_input_as_handled()


# The player pressed a control that may be used now: its sound, then `move`. Nothing while a
# move is being played back.
func _pressed(move: Callable) -> void:
	if _busy:
		return
	Sfx.play("button")
	move.call()


# Makes the parts that are not in the scene, in the order they lie on the page (the cards
# that travel on top), and hands every part to the table.
func _build() -> void:
	var stage := ArenaStage.new()
	var piles := ArenaPiles.new()
	var travel := ArenaTravel.new()
	add_child(stage)
	move_child(stage, _hand.get_index())
	add_child(piles)
	move_child(piles, _hand.get_index())
	add_child(travel)
	var notice := ArenaNotice.new()
	add_child(notice)
	add_child(_beats)
	add_child(ArenaDanger.new())
	_beats.source = func() -> Dictionary: return RulesView.table(_run)
	travel.beats = _beats
	stage.beats = _beats
	_heading.beats = _beats
	piles.bind(_beats, travel)
	t.run = _run
	t.arena = self
	t.beats = _beats
	t.travel = travel
	t.piles = piles
	t.stage = stage
	t.moments = ArenaCardMoments.new(_beats, travel, piles, stage)
	t.moments.notice = notice
	t.moments.freshen = t.freshen
	t.hand = _hand
	t.numbers = _numbers
	t.symbols = _symbols
	t.means = _means
	t.ink = _ink
	t.controls = _controls
	t.heading = _heading
	t.reward = ArenaReward.new()
	t.reward.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(t.reward)
	t.bind()
	t.shown.changed.connect(_follow_line)
	t.move_begun.connect(_follow_line_until_end)


# Gives every part that takes its place from the page's size that place.
func _lay_out() -> void:
	_border.rules = ArenaLayout.rules(size)


# The run this table plays, and the round it opens with. A run that comes back from a dawn's
# place (SceneFlow holds it, still at the place) leaves the place here, which begins the next
# night; otherwise a new run begins, and SceneFlow holds it from now on.
func _take_run() -> void:
	var held: RulesRun = SceneFlow.run
	if held != null and SceneFlow.PLACE_SCENES.has(held.phase):
		_run = held
		_opening = _leave_place().events
		return
	_run = Rules.new_run({}, int(Shot.arg("seed")) if Shot.has_arg("seed") else null)
	ArenaBench.apply_set(_run)
	SceneFlow.run = _run
	_opening = _run.events


# Leaves the dawn's place the run is at: the next night's first round begins. Returns what
# the rules answer.
func _leave_place() -> Dictionary:
	return Rules.leave_lab(_run) if _run.phase == "lab" else Rules.alley_leave(_run)


# The table's first round: the rules have begun it, and `_opening` holds its events.
func _start() -> void:
	do_move("round", {"ok": true, "events": _opening})


# The chosen cards changed: the readout, the marks on the cards and the controls follow.
func _on_choice(ids: Array) -> void:
	if _busy:
		return
	var table := RulesView.table(_run, ids)
	t.after = table
	_numbers.show_choice(table.play)
	_hand.show_table(table)
	_controls.show_table(table, ids.size())
	t.choice_changed.emit(table.play)


# The round is over: the reward's choice is made in the rules and the next round begins. At
# dawn the table stops and the run goes to the laboratory or the back alley: this table is
# then done, and the one made when the place is left plays the next night (see `_take_run`).
# After the run's end, which the round's last move has shown, the table stops if the ending
# screen has the run (SceneFlow.ended), and otherwise a new run begins.
func _go_on() -> void:
	var events: Array = []
	while _run.phase != "play" and _run.phase != "end":
		var result: Dictionary
		if _run.phase == "result":
			result = Rules.continue_result(_run, t.picked)
		elif _bench_drives():
			result = _leave_place()
		else:
			await _go_to_place(events)
			return
		events.append_array(result.events)
	if _run.phase == "end":
		# The ending screen has the run: no new run begins under it.
		if SceneFlow.ended == _run:
			return
		# No ending screen took it: a new run begins on a clean page.
		_run = Rules.new_run()
		SceneFlow.run = _run
		t.run = _run
		Sfx.hyde = _run.stance == "hyde"
		t.offered = []
		t.picked = null
		_symbols.line_reset()
		_follow_line_from(RulesView.table(_run))
		_ink.percent = ink_percent
		_hand.clear()
		for node in t.travel.get_children():
			node.queue_free()
		events = _run.events
	await do_move("round", {"ok": true, "events": events})


# Dawn: what it brought (`events`, from the rules' leaving of the scene's result) is shown on
# the table, which then hands the run over to the dawn's place. Input stays closed.
func _go_to_place(events: Array) -> void:
	var script := _script("res://scripts/arena_moment_round.gd")
	if script and not events.is_empty():
		t.after = RulesView.table(_run)
		script.add(t, {"ok": true, "events": events})
		# His Roots that joined count on the line from here on.
		_beats.add_call(t.snap_shown)
		await _beats.run()
	await ArenaFirsts.show_due(t, events)
	await ArenaStory.dawn(t)
	SceneFlow.go_to_place()


# True when the bench drives this table from the command line (ArenaBench: a still, keys, the
# self-test). It cannot follow the run to another screen, so the dawn's places are then left
# at once and the table plays on.
func _bench_drives() -> bool:
	for name: String in ["shot", "keys", "quit", "selftest"]:
		if Shot.has_arg(name):
			return true
	return false


# The script at `path`, or null if there is none.
func _script(path: String) -> GDScript:
	return load(path) as GDScript if ResourceLoader.exists(path) else null


# --- The ink follows the line ---------------------------------------------------------------

## The ink covers the Ink Roots' share of the page, from the right: at an even line its edge
## stands on the page's fold. It never covers less than his margin, nor more than the most it
## takes before the run's end.
const LINE_SHARE_MIN := 4.0
const LINE_SHARE_MAX := 75.0
## A gain is a surge: the cover runs past its new share by this much and settles, in this long.
const LINE_OVERSHOOT := 4.0
const LINE_SURGE := 0.7
## How far into the surge the cover is furthest out, and the wet edge brightest.
const LINE_SURGE_PEAK := 0.4
const LINE_SURGE_LIT := 0.15
## A loss draws the ink back in this long, without running past.
const LINE_DRAW_BACK := 0.9

var _ink_tween: Tween
## The share the ink is going to, or has: a surge runs past it for a moment.
var _line_target := -1.0
## When the last surge began, in milliseconds: one that begins with it is not sounded again.
var _surge_sounded := -1000


## The ink's share for a line of `paper` Paper Roots against `ink` Ink Roots. With no Roots
## at all there is no balance to read, and the share is `held`.
static func line_share(paper: int, ink: int, held: float) -> float:
	if paper + ink <= 0:
		return held
	return clampf(100.0 * ink / float(paper + ink), LINE_SHARE_MIN, LINE_SHARE_MAX)


## Ink arriving from `point` (in global canvas coordinates) reaches the pool: the ink surges
## to the line's share as it is shown, past it and back, with its wet edge lit most at the
## point's height. Plays the surge even when the cover is already at that share.
func surge_from(point: Vector2) -> void:
	if Shot.has_arg("ink") or _run.phase == "end":
		return
	var page := _ink.paper.get_global_rect()
	var height := clampf((point.y - page.position.y) / maxf(page.size.y, 1.0), 0.0, 1.0)
	_surge(_shown_line_share(), height)


# A new run: the ink takes the line's share at once, unless `--ink` pins it.
func _follow_line_from(table: Dictionary) -> void:
	_stop_line()
	if not Shot.has_arg("ink"):
		ink_percent = line_share(int(table.line.paper), int(table.line.ink), ink_percent)
	_line_target = ink_percent


# A move is about to be played back. If it ends the run, the ink stops following the line
# for the rest of it: the ending has the page. A new run follows it again.
func _follow_line_until_end(_move: String) -> void:
	if _run.phase == "end":
		_stop_line()


# A shown value changed. When it is the line, as the ribbon shows it, the ink surges to a
# greater share and draws back to a smaller one; at once when the move is being played back
# at once. Not in the move that ends the run.
func _follow_line(key: String, _value: Variant) -> void:
	if not key.begins_with("line/") or Shot.has_arg("ink") or _run.phase == "end":
		return
	var share := _shown_line_share()
	if is_equal_approx(share, _line_target):
		return
	if share > _line_target:
		_surge(share, -1.0)
		return
	_stop_line()
	_line_target = share
	if _beats.rate() >= ArenaPace.SKIP:
		ink_percent = share
		return
	_ink_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ink_tween.tween_property(self, "ink_percent", share, LINE_DRAW_BACK)
	t.follow(_ink_tween)


# The line's share as the ribbon shows it.
func _shown_line_share() -> float:
	return line_share(int(t.shown.value("line/paper", 0)), int(t.shown.value("line/ink", 0)), ink_percent)


# The ink surges to `share`, past it and back, with the wet edge lit (brightest at `height`
# down the page, or all along it when that is negative) and the sound of ink dropping.
func _surge(share: float, height: float) -> void:
	_stop_line()
	_line_target = share
	if _beats.rate() >= ArenaPace.SKIP:
		ink_percent = share
		return
	# Surges that begin together (the line's two marks, ink arriving as it grows) sound once.
	if Time.get_ticks_msec() - _surge_sounded > 50:
		_beats.sound("ink_drop", 0.85 * Sfx.vary(0.04), 0.8)
	_surge_sounded = Time.get_ticks_msec()
	_ink_tween = create_tween()
	_ink_tween.tween_method(_surge_step.bind(ink_percent, share, height), 0.0, 1.0, LINE_SURGE)
	_ink_tween.tween_callback(_ink.light_edge.bind(0.0))
	t.follow(_ink_tween)


# One step of a surge, `done` of the way through it, from `from` to `share`.
func _surge_step(done: float, from: float, share: float, height: float) -> void:
	var peak := share + LINE_OVERSHOOT
	if done < LINE_SURGE_PEAK:
		ink_percent = lerpf(from, peak, ease(done / LINE_SURGE_PEAK, 0.4))
	else:
		ink_percent = lerpf(peak, share, smoothstep(LINE_SURGE_PEAK, 1.0, done))
	if ArenaPace.reduce_flashes:
		return
	var lit := smoothstep(0.0, LINE_SURGE_LIT, done) * (1.0 - smoothstep(LINE_SURGE_LIT * 2.0, 1.0, done))
	_ink.light_edge(lit, height)


# Stops the ink where it is, with its edge unlit.
func _stop_line() -> void:
	if _ink_tween:
		_ink_tween.kill()
	_ink.light_edge(0.0)
