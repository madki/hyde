extends Control
## A bench for the notice (scripts/arena_notice.gd): the sheet over a page that has the ink,
## the flask and the salt on it, with keys that show a notice of each kind. What the notices
## say here is the bench's own, made up to show the sheet; the arena writes its own.
##
## Keys: 1 Hyde's, with four cards. 2 Jekyll's, with one card. 3 Hyde's, with a before and an
## after side by side. 4 a plain note that rings the draught. 5 a plain note with no ring.
## 6 Jekyll's, with five cards over five (the most the sheet takes). 7 a plain note that rings
## the salt, at the page's other side. W switches whether a notice waits for the player
## (ArenaPace.wait_for_me), B whose page it is.
##
## For a screenshot: `tools/shot.sh /abs/out.png res://scenes/arena_notice_bench.tscn`, with
## `--show=<hyde|jekyll|change|ring|plain|most|salt>` for the notice (hyde by default),
## `--hyde` for his page under it, `--ink=<percent>` for how much of the page his ink takes,
## and `--wait=<seconds>` for when the still is taken after the notice is asked for (0.5 by
## default: it has come in).
##
## `--check` asks the notice the questions a still cannot answer, prints a line for each and
## NOTICE CHECK PASS or FAIL, and quits. It needs no window:
##
##   godot --headless --path . res://scenes/arena_notice_bench.tscn -- --check

const SHOWS := {
	KEY_1: "hyde", KEY_2: "jekyll", KEY_3: "change", KEY_4: "ring", KEY_5: "plain", KEY_6: "most",
	KEY_7: "salt",
}

@onready var _ink: ArenaInk = $Ink
@onready var _means: ArenaMeans = $Means
@onready var _notice: ArenaNotice = $Notice
@onready var _keys: Label = $Keys

var _run: RulesRun
var _jekyll := true
var _said := "-"


func _ready() -> void:
	_jekyll = not Shot.has_arg("hyde")
	_ink.set_ink(float(Shot.arg("ink")) if Shot.has_arg("ink") else 35.0, 50.0, _jekyll)
	_ink.snap_to_stance()
	_run = Rules.new_run()
	_means.show_table(RulesView.table(_run), _run.dials)
	_show_keys()
	if Shot.has_arg("check"):
		await _check()
		return
	if Shot.has_arg("shot"):
		_show(Shot.arg("show") if Shot.has_arg("show") else "hyde")
		await get_tree().create_timer(float(Shot.arg("wait")) if Shot.has_arg("wait") else 0.5).timeout
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if SHOWS.has(key.keycode):
		_show(SHOWS[key.keycode])
	elif key.keycode == KEY_W:
		ArenaPace.wait_for_me = not ArenaPace.wait_for_me
		_show_keys()
	elif key.keycode == KEY_B:
		_jekyll = not _jekyll
		_ink.set_ink(35.0, 50.0, _jekyll)


func _show(which: String) -> void:
	var began := Time.get_ticks_msec()
	await _notice.show_notice(_what(which))
	_said = "'%s' was up for %.2f s" % [which, (Time.get_ticks_msec() - began) / 1000.0]
	_show_keys()


# What each of the bench's notices says.
func _what(which: String) -> Dictionary:
	match which:
		"hyde":
			return {
				"title": "Hyde arrives",
				"lines": ["His four Roots join your deck.", "An Ink Root scores only while he has the table."],
				"cards": [_root("lamp", true), _root("heart", true), _root("mirror", true), _root("lamp", true)],
				"tone": "hyde",
			}
		"jekyll":
			return {
				"title": "Resolve joins your deck",
				"lines": ["It lies in your discards, and comes round with the next shuffle."],
				"cards": [_factor("lock")],
				"tone": "jekyll",
			}
		"change":
			return {
				"title": "He stains a Root",
				"lines": ["Kindness becomes Appetite: his to play, and no longer yours."],
				"cards": [_root("heart", false)],
				"after": [_root("heart", true)],
				"tone": "hyde",
			}
		"ring":
			return {
				"title": "The draught",
				"lines": ["Drink it and Hyde takes the table.", "The first drink brings his four Roots into your deck."],
				"tone": "plain",
				"at": _means.get_global_transform() * ArenaLayout.draught(_means.size),
			}
		"salt":
			return {
				"title": "Salt",
				"lines": ["A dose brings you back to yourself. It is shut while you are yourself."],
				"tone": "plain",
				"at": _means.get_global_transform() * ArenaLayout.salt(_means.size),
			}
		"most":
			return {
				"title": "Five Roots turn back at dawn",
				"lines": ["A first line.", "A second line, which is long enough to say what a third would otherwise have to.", "A third line."],
				"cards": [_root("lamp", true), _root("heart", true), _root("mirror", true), _root("lamp", true), _root("heart", true)],
				"after": [_root("lamp", false), _root("heart", false), _root("mirror", false), _root("lamp", false), _root("heart", false)],
				"tone": "jekyll",
			}
	return {
		"title": "A note in the margin",
		"lines": ["A plain note has no cards and points at nothing."],
	}


func _root(key: String, ink: bool) -> Dictionary:
	return {"id": key.length() + int(ink), "key": key, "ink": ink, "name": RulesConfig.ROOT[key]["ink" if ink else "paper"], "chips": 15}


func _factor(kind: String) -> Dictionary:
	return {"id": 3, "key": kind, "ink": false, "name": RulesConfig.FACTOR[kind].paper, "chips": 10,
			"text": RulesConfig.factor_text(kind, "jekyll", _run.dials)}


func _show_keys() -> void:
	_keys.text = "1 Hyde's   2 Jekyll's   3 before and after   4 rings the draught   5 plain   6 the most cards   7 rings the salt" \
			+ "\nW waits for me: %s   B page   last: %s" % ["yes" if ArenaPace.wait_for_me else "no", _said]


# ---------- the check ----------

# Sends a press of `code` (or a left click, with KEY_NONE) through the tree's input.
func _send(code: Key) -> void:
	var event: InputEvent
	if code == KEY_NONE:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(20.0, 20.0)
		event = click
	else:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		event = key
	Input.parse_input_event(event)
	# The event is handed out on the next frame; the notice then takes OUT to leave.
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check() -> void:
	var failed := [0] # in an array, so that the lambda counts in this one
	var say := func(ok: bool, what: String) -> void:
		print("  %s  %s" % ["ok  " if ok else "FAIL", what])
		if not ok:
			failed[0] += 1
	var what := _what("jekyll")
	var reached := [0]
	var mark := func() -> void: reached[0] += 1

	# A beat queue as the arena's: beats, then the notice as a choice, then a beat after it.
	var beats := ArenaBeats.new()
	add_child(beats)
	beats.add_wait(5.0)
	beats.add_wait(5.0)
	beats.add_choice(func() -> void: await _notice.show_notice(what))
	beats.add_call(mark)
	beats.run()
	await get_tree().process_frame
	beats.hurry()
	beats.skip()
	# Ten seconds of beats are skipped in a few frames; then the queue is at the notice.
	for i in 120:
		if _notice.showing:
			break
		await get_tree().process_frame
	await _wait(0.1)
	say.call(_notice.showing and reached[0] == 0, "a skipped move stops at the notice")
	say.call(not beats.is_skipping() and not beats.is_hurrying() and not beats.is_locked(),
			"the queue neither hurries nor skips there, and lets input through")
	await _send(KEY_SPACE)
	await _send(KEY_NONE)
	await _wait(0.05)
	say.call(_notice.showing and _notice.modulate.a > 0.0 and reached[0] == 0,
			"a press in its first %.2f s does not dismiss it" % ArenaNotice.DEAF)
	await _wait(ArenaNotice.DEAF)
	for code: Key in ArenaBeats.LOOK_KEYS + [KEY_ESCAPE, KEY_P, KEY_1]:
		await _send(code)
	await _wait(ArenaNotice.OUT + 0.1)
	say.call(_notice.showing and reached[0] == 0, "Shift, Tab and other keys do not dismiss it")
	await _wait(2.0)
	say.call(_notice.showing and reached[0] == 0, "it stays while nothing is pressed")
	await _send(KEY_SPACE)
	await _wait(ArenaNotice.OUT + 0.15)
	say.call(not _notice.showing and not _notice.visible and reached[0] == 1,
			"Space dismisses it, and the queue goes on")

	for code: Key in [KEY_ENTER, KEY_NONE]:
		_show("jekyll")
		await _wait(ArenaNotice.DEAF + 0.1)
		say.call(_notice.showing, "it is shown again")
		await _send(code)
		await _wait(ArenaNotice.OUT + 0.15)
		say.call(not _notice.showing, "%s dismisses it" % ("a click" if code == KEY_NONE else "Enter"))

	ArenaPace.wait_for_me = false
	var began := Time.get_ticks_msec()
	_show("hyde")
	await _wait(ArenaNotice.HOLD - 0.2)
	var still_up := _notice.showing
	await _notice.dismissed
	var took := (Time.get_ticks_msec() - began) / 1000.0
	say.call(still_up and took < ArenaNotice.HOLD + ArenaNotice.OUT + 0.3,
			"with wait_for_me off it leaves by itself (%.2f s)" % took)
	ArenaPace.wait_for_me = true

	ArenaNotice.pass_at_once = true
	began = Time.get_ticks_msec()
	await _notice.show_notice(what)
	say.call(not _notice.showing and Time.get_ticks_msec() - began < 20, "with pass_at_once on it returns at once")
	ArenaNotice.pass_at_once = false

	print("NOTICE CHECK %s" % ("PASS" if failed[0] == 0 else "FAIL (%d)" % failed[0]))
	get_tree().quit(0 if failed[0] == 0 else 1)
