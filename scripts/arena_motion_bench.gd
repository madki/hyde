extends Control
## A bench for the table's motion, away from the arena: the arena's page with the beat queue
## and made-up moves to look at. Nothing here is a rule: the "engine" is a dictionary the
## bench writes as a real engine would answer.
##
## Keys:
##   B  a made-up move: a play's beats (plays, scoring ticks, the total, the score, restraint)
##   E  the same move, but the engine ends on another score: the check corrects it and logs it
##   S  cycles the speed setting (1, 1.5, 2)      F  turns "reduce flashes" on or off
##   Shift  gives the table to the other man
## A click or a key during a move hurries it; holding one skips to its end.
##
## For a screenshot: `tools/shot.sh /abs/out.png res://scenes/arena_motion_bench.tscn
## [--hyde] [--run=<key letter>] [--at=<seconds>]` runs that key's action and takes the shot
## that many seconds later. `--selftest` (headless, under a time limit) checks the queue and quits.

const CREAM := Color(0.93, 0.88, 0.75)
const DIM := Color(0.93, 0.88, 0.75, 0.6)
## The values the bench's left column shows, with their labels.
const SHOWN := [["score", "Score"], ["plays", "Plays"], ["discards", "Discards"],
		["restraint/meter", "Restraint"], ["chips", "Chips"], ["mult", "Mult"]]

@onready var _ink: ArenaInk = $Ink

var beats := ArenaBeats.new()
## What the made-up engine holds now: RulesView.table()'s shape, the parts the bench uses.
var engine := {"score": 0, "plays": 4, "discards": 3, "restraint": {"meter": 1, "limit": 5}}

var _is_jekyll := true
var _labels := {}
var _status: Label
var _settings: Label
var _presses := 0
var _press_button := Button.new()


func _ready() -> void:
	add_child(beats)
	beats.source = func() -> Dictionary: return engine
	beats.shown.changed.connect(_on_shown)
	beats.started.connect(_show_status)
	beats.emptied.connect(_show_status)
	beats.hurried.connect(_show_status)
	beats.skipped.connect(_show_status)
	beats.corrected.connect(func(off: Dictionary) -> void:
		_status.text = "Corrected at the end: %s" % str(off))
	_build_column()
	_build_help()

	_is_jekyll = not Shot.has_arg("hyde")
	_ink.set_ink(60.0 if not _is_jekyll else 45.0, 50.0, _is_jekyll)
	_ink.snap_to_stance()
	beats.shown.snap_to(engine, ["score", "plays", "discards", "restraint/meter"])
	beats.shown.set_value("chips", 0)
	beats.shown.set_value("mult", 0)
	_show_status()
	_show_settings()

	if Shot.has_arg("selftest"):
		await _selftest()
		get_tree().quit()
		return
	if Shot.arg("run") != "":
		_act(Shot.arg("run").to_upper().unicode_at(0))
	if Shot.has_arg("at"):
		await get_tree().create_timer(float(Shot.arg("at"))).timeout
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_act(key.keycode)


func _act(keycode: int) -> void:
	match keycode:
		KEY_B:
			_made_up_play(false)
		KEY_E:
			_made_up_play(true)
		KEY_S:
			var i := ArenaPace.SPEEDS.find(ArenaPace.speed)
			ArenaPace.speed = ArenaPace.SPEEDS[(i + 1) % ArenaPace.SPEEDS.size()]
			_show_settings()
		KEY_F:
			ArenaPace.reduce_flashes = not ArenaPace.reduce_flashes
			_show_settings()
		KEY_SHIFT:
			_is_jekyll = not _is_jekyll
			_ink.is_jekyll = _is_jekyll


## A made-up play: the engine answers at once, then the table plays it back beat by beat.
## With `wrong`, the engine's score ends 15 higher than the beats count to.
func _made_up_play(wrong: bool) -> void:
	if beats.is_running():
		return
	var chips := 10
	var mult := 1
	var score: int = engine.score
	var meter: int = engine.restraint.meter
	var plays: int = engine.plays
	# The engine's answer, all at once.
	var ticks := [5, 5, 3, 3, 2, 2, 1, 1, 1, 1, 1, 1]
	var total_chips := chips
	for t: int in ticks:
		total_chips += t
	var total := total_chips * (mult + 2)
	engine = {"score": score + total + (15 if wrong else 0), "plays": maxi(0, plays - 1),
			"discards": engine.discards, "restraint": {"meter": mini(5, meter + 1), "limit": 5}}

	# The beats.
	beats.add_set("plays", maxi(0, plays - 1))
	beats.add_set("chips", chips, ArenaPace.tick(0))
	var running := chips
	for n in ticks.size():
		running += ticks[n]
		beats.add_set("chips", running, ArenaPace.tick(n + 1))
	beats.add_set("mult", mult + 1, ArenaPace.tick(ticks.size() + 1))
	beats.add_set("mult", mult + 2, ArenaPace.tick(ticks.size() + 2))
	beats.add_set("chips", total, ArenaPace.TOTAL_LANDS)
	beats.add_set("mult", 0, 0.0)
	beats.add(func() -> void:
		beats.shown.set_value("chips", 0)
		beats.shown.set_value("score", score + total)
		await beats.wait(ArenaPace.TOTAL_TRAVELS))
	beats.add_set("restraint/meter", mini(5, meter + 1))
	beats.run()


func _on_shown(key: String, value: Variant) -> void:
	if not _labels.has(key):
		return
	var label: Label = _labels[key]
	label.text = "%s  %s" % [label.get_meta("name"), str(value)]
	# Points at the value: a short flare, or with reduce flashes only the colour.
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0) if _is_jekyll
			else Color(1.0, 0.55, 0.9))
	var t := beats.tween()
	if ArenaPace.reduce_flashes:
		t.tween_interval(ArenaPace.FLARE_FALL)
	else:
		label.scale = Vector2.ONE
		t.tween_property(label, "scale", Vector2(1.15, 1.15), ArenaPace.FLARE_RISE)
		t.tween_property(label, "scale", Vector2.ONE, ArenaPace.FLARE_FALL)
	t.tween_callback(func() -> void: label.add_theme_color_override("font_color", CREAM))


func _show_status() -> void:
	if beats.is_skipping():
		_status.text = "Input locked: skipping to the end of the move"
	elif beats.is_hurrying():
		_status.text = "Input locked: hurried"
	elif beats.is_locked():
		_status.text = "Input locked: playing the move"
	else:
		_status.text = "Input free"


func _show_settings() -> void:
	_settings.text = "Speed %s    Reduce flashes %s" % [str(ArenaPace.speed),
			"on" if ArenaPace.reduce_flashes else "off"]


func _build_column() -> void:
	var y := 230.0
	for pair: Array in SHOWN:
		var label := _label(Vector2(50.0, y), 18)
		label.set_meta("name", pair[1])
		label.pivot_offset = Vector2(0.0, 12.0)
		_labels[pair[0]] = label
		y += 28.0
	_press_button.text = "Press me"
	_press_button.position = Vector2(50.0, y + 8.0)
	_press_button.pressed.connect(func() -> void:
		_presses += 1
		_press_button.text = "Pressed %d" % _presses)
	add_child(_press_button)
	_status = _label(Vector2(320.0, 50.0), 16)
	_settings = _label(Vector2(320.0, 74.0), 14)


func _build_help() -> void:
	var help := _label(Vector2(320.0, 100.0), 12)
	help.modulate = DIM
	help.text = "B a move   E a move the engine ends otherwise   S speed   F reduce flashes" \
			+ "\nClick or key during a move: hurry. Hold: skip to its end."


func _label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	add_child(label)
	return label


# --- The self-test: run headless with --selftest. --------------------------------------------

var _fails: Array[String] = []
var _unhandled_seen := 0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		printerr("SELFTEST FAIL: ", what)


func _selftest() -> void:
	# 1. Made-up beats play in order, one at a time, with input locked until the last is done.
	var order: Array[int] = []
	var overlap := [false]
	var inside := [false]
	for i in 5:
		beats.add(func() -> void:
			if inside[0]:
				overlap[0] = true
			inside[0] = true
			order.append(i)
			await beats.wait(0.05)
			inside[0] = false)
	_expect(not beats.is_locked(), "free before the run")
	beats.run()
	_expect(beats.is_locked(), "locked while the queue runs")
	await beats.emptied
	_expect(order == [0, 1, 2, 3, 4], "beats in order, got %s" % str(order))
	_expect(not overlap[0], "one beat at a time")
	_expect(not beats.is_locked(), "free after the last beat")

	# 2. Input is refused while it runs: a key press does not reach the table, and hurries.
	var catcher := _Catcher.new()
	add_child(catcher)
	beats.add_wait(0.3)
	beats.run()
	var press := InputEventKey.new()
	press.keycode = KEY_X
	press.pressed = true
	get_viewport().push_input(press)
	_expect(catcher.seen == 0, "a key during the queue does not reach the table")
	_expect(beats.is_hurrying(), "a key during the queue hurries it")
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await beats.emptied
	get_viewport().push_input(press)
	get_viewport().push_input(release)
	_expect(catcher.seen == 1, "a key after the queue reaches the table")

	# 3. Holding skips to the end of the move, with every shown value correct.
	beats.shown.snap_to(engine, ["score", "plays", "discards", "restraint/meter"])
	_made_up_play(false)
	var started := Time.get_ticks_msec()
	await get_tree().process_frame
	get_viewport().push_input(press)
	await get_tree().create_timer(ArenaPace.HOLD_TO_SKIP + 0.15).timeout
	_expect(beats.is_skipping() or not beats.is_running(), "held key skips")
	if beats.is_running():
		await beats.emptied
	get_viewport().push_input(release)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	_expect(took < 1.5, "the skipped move ends at once (took %.2f s)" % took)
	_expect(beats.shown.differences(engine).is_empty(), "shown values equal the engine after a skip")

	# 4. A value that differs at the end is corrected (and logged, as an error below).
	print("SELFTEST: one error about score is expected next.")
	var corrected := [{}]
	beats.corrected.connect(func(off: Dictionary) -> void: corrected[0] = off, CONNECT_ONE_SHOT)
	_made_up_play(true)
	beats.skip()
	await beats.emptied
	_expect(corrected[0].has("score"), "the score is corrected")
	_expect(beats.shown.value("score") == engine.score, "shown score snapped to the engine")

	# 5. The pace.
	_expect(ArenaPace.tick(0) == 0.30 and ArenaPace.tick(4) == 0.30 and ArenaPace.tick(5) == 0.20
			and ArenaPace.tick(10) == 0.14, "the scoring tick quickens after the fifth")
	print("SELFTEST PASS" if _fails.is_empty() else "SELFTEST FAILED: %s" % str(_fails))


class _Catcher:
	extends Node
	var seen := 0

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key and key.pressed and key.keycode == KEY_X:
			seen += 1
