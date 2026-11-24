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
## salt, Esc lets the chosen cards go. At a reward 1 to 3 take a card and 0 or Esc none. During a move a click or a key hurries it, and held
## down skips to its end.
##
## For a screenshot: `--seed=<n>` (the run's seed), `--ink=<0..100>` and
## `--volatility=<0..100>` (the page's ink), and `--keys=` to make moves first (see
## scripts/arena_bench.gd): `tools/shot.sh /abs/out.png res://scenes/arena.tscn --seed=3 --keys=12D`.
## `--zones` outlines and names every zone of the page's layout (ArenaLayout).

## A move has been played back to its end and input is open again.
signal settled

## How much of the page the ink covers, 0 to 100.
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
@onready var _column: ArenaColumn = $Column
@onready var _symbols: ArenaSymbols = $Symbols
@onready var _means: ArenaMeans = $Means
@onready var _controls: ArenaControls = $Controls
@onready var _heading: ArenaHeading = $Heading

var _run: RulesRun
var _beats := ArenaBeats.new()
var _busy := true


func _ready() -> void:
	if Shot.has_arg("ink"):
		ink_percent = float(Shot.arg("ink"))
	if Shot.has_arg("volatility"):
		ink_volatility = float(Shot.arg("volatility"))
	_run = Rules.new_run({}, int(Shot.arg("seed")) if Shot.has_arg("seed") else null)
	ArenaBench.apply_set(_run)
	_build()
	resized.connect(_lay_out)
	_lay_out()
	if Shot.has_arg("zones"):
		add_child(ArenaZones.new())
	_ink.set_ink(ink_percent, ink_volatility, _run.stance == "jekyll")
	_ink.snap_to_stance()
	_hand.max_chosen = _run.dials.max_play
	_hand.enabled = false
	_hand.chosen_changed.connect(_on_choice)
	_controls.lower(false)
	_controls.play_pressed.connect(play_chosen)
	_controls.discard_pressed.connect(discard_chosen)
	_controls.pass_pressed.connect(pass_play)
	_means.drink_pressed.connect(drink)
	_means.salt_pressed.connect(take_salt)
	for extra: String in ["ghosts", "previews", "views"]:
		var script := _script("res://scripts/arena_extra_%s.gd" % extra)
		if script:
			script.setup(t)
	# The run's own furniture, before its first round is dealt.
	var table := RulesView.table(_run)
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
		_column.show_choice(null)
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
		t.pressed.emit()
		return
	if not key or not key.pressed or key.echo:
		return
	if _busy:
		# Enter is the table's own key: it must not reach the game's "next screen".
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if _controls.can_pass():
				pass_play()
			elif _controls.can_play():
				play_chosen()
		KEY_D:
			if _controls.can_discard():
				discard_chosen()
		KEY_Q:
			drink()
		KEY_S:
			take_salt()
		KEY_ESCAPE:
			_hand.clear_chosen()
		KEY_0:
			_hand.toggle_at(9)
		_:
			if key.keycode >= KEY_1 and key.keycode <= KEY_9:
				_hand.toggle_at(key.keycode - KEY_1)
			else:
				return
	get_viewport().set_input_as_handled()


# Makes the parts that are not in the scene, in the order they lie on the page (the cards
# that travel on top), and hands every part to the table.
func _build() -> void:
	var stage := ArenaStage.new()
	var piles := ArenaPiles.new()
	var travel := ArenaTravel.new()
	# The laid row is centred on the page, under the readout's line.
	stage.row_y = 372.0
	stage.table_left = 0.0
	stage.room_right = 0.0
	add_child(stage)
	move_child(stage, _hand.get_index())
	add_child(piles)
	move_child(piles, _hand.get_index())
	add_child(travel)
	add_child(_beats)
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
	t.hand = _hand
	t.column = _column
	t.symbols = _symbols
	t.means = _means
	t.ink = _ink
	t.controls = _controls
	t.heading = _heading
	t.reward = ArenaReward.new()
	t.reward.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(t.reward)
	t.bind()


# Gives every part that takes its place from the page's size that place.
func _lay_out() -> void:
	_border.rules = ArenaLayout.rules(size)


# The run's first round: Rules.new_run has begun it, and left its events on the run.
func _start() -> void:
	do_move("round", {"ok": true, "events": _run.events})


# The chosen cards changed: the readout, the marks on the cards and the controls follow.
func _on_choice(ids: Array) -> void:
	if _busy:
		return
	var table := RulesView.table(_run, ids)
	t.after = table
	_column.show_choice(table.play)
	_hand.show_table(table)
	_controls.show_table(table, ids.size())
	t.choice_changed.emit(table.play)


# The round is over: the reward's choice is made in the rules and the next round begins.
# Until the dawn's places have pages of their own, the laboratory and the back alley are left
# at once. After the run's end, which the round's last move has shown, a new run begins.
func _go_on() -> void:
	var events: Array = []
	while _run.phase != "play" and _run.phase != "end":
		var result: Dictionary
		match _run.phase:
			"result":
				result = Rules.continue_result(_run, t.picked)
			"lab":
				result = Rules.leave_lab(_run)
			_:
				result = Rules.alley_leave(_run)
		events.append_array(result.events)
	if _run.phase == "end":
		# The table has shown the run's end: a new run begins on a clean page.
		_run = Rules.new_run()
		t.run = _run
		t.offered = []
		t.picked = null
		_symbols.line_reset()
		_ink.percent = ink_percent
		_hand.clear()
		for node in t.travel.get_children():
			node.queue_free()
		events = _run.events
	await do_move("round", {"ok": true, "events": events})


# The script at `path`, or null if there is none.
func _script(path: String) -> GDScript:
	return load(path) as GDScript if ResourceLoader.exists(path) else null
