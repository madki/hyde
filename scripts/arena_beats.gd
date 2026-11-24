class_name ArenaBeats
extends Node
## The beat queue: plays a move back to the player one beat at a time.
##
## The engine works a move out at once. The table turns its answer into an ordered list of
## beats with `add` (and the helpers after it), then calls `run`. While the queue runs, input
## is locked: no click or key reaches the rest of the table. Each beat changes at most one
## shown value (`shown`) or one card, and points at it; when the last is done the queue
## compares what is shown with the engine (`source`), snaps any difference to the engine and
## logs it as an error, unlocks input and emits `emptied`.
##
## A beat is a Callable that takes no arguments and returns when it is done: it may `await`.
## It waits only through this queue, with `wait` or with a tween made by `tween`, never on a
## timer of its own, so that it is played faster when the player hurries:
##
##   beats.add(func() -> void:
##       shown.set_value("plays", 2)
##       await beats.wait(ArenaPace.MARK))
##
## Hurrying: a click or a key during the queue plays the rest at ArenaPace.HURRY times the
## speed; held down for ArenaPace.HOLD_TO_SKIP it skips to the end of the move. A choice
## (`add_choice`) stops both: nothing is skipped past it, and input is let through while the
## player chooses. ArenaPace.speed (the setting) multiplies all of it.

## The queue has begun to play: input is locked.
signal started
## The last beat is done and the check has been made: input is free again.
signal emptied
## The check at the end found these differences ({key: [shown, engine]}) and corrected them.
signal corrected(differences: Dictionary)
## The player hurried the queue, or held on to skip to the end of the move.
signal hurried
signal skipped

## The keys held down to read every number (ArenaViews). Holding one is looking, not
## hurrying: it neither hurries nor skips a move, and is no press where the table waits for one.
const LOOK_KEYS: Array[Key] = [KEY_SHIFT, KEY_TAB]

## The numbers the table shows, moved only by beats.
var shown := ArenaShown.new()
## Returns what RulesView.table() holds now, for the check at the end. Unset, there is no check.
var source := Callable()

var _queue: Array[Dictionary] = []
## Where `add_next` puts a beat: after those it has already put there during this beat.
var _next_at := 0
var _running := false
var _choosing := false
var _hurrying := false
var _skipping := false
var _tweens: Array[Tween] = []
## How long the click or key that hurried the queue has been held, or -1 when it is not held.
var _held := -1.0


func _ready() -> void:
	set_process(false)
	# Input is locked even while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


## True while the queue plays and the player cannot act.
func is_locked() -> bool:
	return _running and not _choosing


func is_running() -> bool:
	return _running


func is_hurrying() -> bool:
	return _hurrying


func is_skipping() -> bool:
	return _skipping


## How many times faster than ArenaPace's times the queue plays now.
func rate() -> float:
	var r := ArenaPace.speed
	if _skipping:
		r *= ArenaPace.SKIP
	elif _hurrying:
		r *= ArenaPace.HURRY
	return r


## Adds a beat at the end of the queue.
func add(beat: Callable) -> void:
	_queue.append({"call": beat, "choice": false})


## Adds a beat to play next, right after the one playing now (after any others added with
## add_next during it, in the order they were added). For a signal sent from a beat whose
## answer must be seen at once: the line's tally after a card joins, say.
func add_next(beat: Callable) -> void:
	_queue.insert(_next_at, {"call": beat, "choice": false})
	_next_at += 1


## Adds a beat that waits for the player to choose (a card of the reward, say). Hurrying and
## skipping stop before it, and input is let through until it returns.
func add_choice(beat: Callable) -> void:
	_queue.append({"call": beat, "choice": true})


## Adds a beat that does nothing for `seconds`.
func add_wait(seconds: float) -> void:
	add(func() -> void: await wait(seconds))


## Adds a beat that moves one shown value and then waits `seconds` (a mark's time by default).
func add_set(key: String, value: Variant, seconds: float = ArenaPace.MARK) -> void:
	add(func() -> void:
		shown.set_value(key, value)
		await wait(seconds))


## Adds a beat that calls `call` (which must not wait) and goes straight on.
func add_call(call: Callable) -> void:
	add(func() -> void: call.call())


## Plays the queue to its end. Calling it while it plays does nothing: beats added meanwhile
## are played in their turn. It may be awaited.
func run() -> void:
	if _running:
		return
	_running = true
	_hurrying = false
	_skipping = false
	started.emit()
	while not _queue.is_empty():
		var beat: Dictionary = _queue.pop_front()
		_next_at = 0
		if beat.choice:
			_hurrying = false
			_skipping = false
			_held = -1.0
			_set_rate()
			_choosing = true
		await (beat.call as Callable).call()
		_choosing = false
	_next_at = 0
	_check()
	_running = false
	_hurrying = false
	_skipping = false
	_held = -1.0
	set_process(false)
	_tweens.clear()
	emptied.emit()


## A tween that plays at the queue's rate, and keeps up with it if the player hurries while it
## plays. Give it at least one step.
func tween() -> Tween:
	var t := create_tween()
	t.set_speed_scale(rate())
	_tweens = _tweens.filter(func(old: Tween) -> bool: return old.is_valid())
	_tweens.append(t)
	return t


## Waits `seconds` at the queue's rate: `await beats.wait(ArenaPace.MARK)`.
func wait(seconds: float) -> Signal:
	var t := tween()
	t.tween_interval(maxf(seconds, 0.001))
	return t.finished


## Plays the rest of the queue faster, as a click does.
func hurry() -> void:
	if not is_locked() or _hurrying:
		return
	_hurrying = true
	_set_rate()
	hurried.emit()


## Skips to the end of the move (or to the next choice), as a held click does.
func skip() -> void:
	if not is_locked() or _skipping:
		return
	_hurrying = true
	_skipping = true
	_set_rate()
	skipped.emit()


func _set_rate() -> void:
	var r := rate()
	for t in _tweens:
		if t.is_valid():
			t.set_speed_scale(r)


func _input(event: InputEvent) -> void:
	if not is_locked():
		return
	var pressed := false
	var released := false
	var button := event as InputEventMouseButton
	var key := event as InputEventKey
	var touch := event as InputEventScreenTouch
	if button:
		pressed = button.pressed
		released = not button.pressed
	elif key:
		if key.echo or key.keycode in LOOK_KEYS:
			get_viewport().set_input_as_handled()
			return
		pressed = key.pressed
		released = not key.pressed
	elif touch:
		pressed = touch.pressed
		released = not touch.pressed
	else:
		return # the pointer may move: the cards under it are only looked at
	get_viewport().set_input_as_handled()
	if pressed:
		hurry()
		_held = 0.0
		set_process(true)
	elif released:
		_held = -1.0
		set_process(false)


func _process(delta: float) -> void:
	if _held < 0.0 or not is_locked():
		return
	_held += delta
	if _held >= ArenaPace.HOLD_TO_SKIP:
		skip()
		_held = -1.0
		set_process(false)


## The check at the end of a move: what is shown must be what the engine holds.
func _check() -> void:
	if not source.is_valid():
		return
	var table: Dictionary = source.call()
	var off := shown.differences(table)
	if off.is_empty():
		return
	for key: String in off:
		push_error("The table showed %s = %s at the end of a move, the engine has %s: corrected."
				% [key, var_to_str(off[key][0]), var_to_str(off[key][1])])
		shown.set_value(key, off[key][1])
	corrected.emit(off)
