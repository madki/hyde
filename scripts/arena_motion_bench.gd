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
## Cards (travel):
##   D  deal: cards from the draw pile to the hand, face down, turning over as they arrive
##   X  two cards from the hand to the discards       P  the top discard back to the hand
##   C  three hand cards laid in the centre under a caption, held, then sent to the discards
##   N  a card drawn into the centre, shown, then sent to the hand
##   K  a hand card pushed into the middle of the draw pile (the pile riffles)
##   R  the discards turned over into a new draw pile    T  the first hand card turns over
##   G  between rounds: the corner holds the whole deck, or the two piles again
## Card moments (the three patterns):
##   1  four of his Roots join the deck (his first arrival)    2  one card joins (a reward)
##   3  Hyde brings two Fog from the draw pile    4  Jekyll brings two from the discards
##   5  none brought
##   6  the first hand card changes side (stained if paper, turned if ink)
##   7  a card in the draw pile changes side    8  a card in the discards changes side
##      (7 and 8 go paper to ink and ink to paper by turns)
##   9  the rescue converts the first Paper Root in the hand
## A click or a key during a move hurries it; holding one skips to its end.
##
## For a screenshot: `tools/shot.sh /abs/out.png res://scenes/arena_motion_bench.tscn
## [--hyde] [--run=<key letters>] [--at=<seconds>]` runs those keys' actions one after the
## other and takes the shot that many seconds after the last has begun. `--selftest` (headless, under a time limit) checks the queue and quits.

const CREAM := Color(0.93, 0.88, 0.75)
const DIM := Color(0.93, 0.88, 0.75, 0.6)
## The values the bench's left column shows, with their labels.
const SHOWN := [["score", "Score"], ["plays", "Plays"], ["discards", "Discards"],
		["restraint/meter", "Restraint"], ["chips", "Chips"], ["mult", "Mult"]]

@onready var _ink: ArenaInk = $Ink

var beats := ArenaBeats.new()
## What the made-up engine holds now: RulesView.table()'s shape, the parts the bench uses.
var engine := {"score": 0, "plays": 4, "discards": 3, "restraint": {"meter": 1, "limit": 5},
		"draw_count": 30, "discard_count": 0}
## Sample cards, as RulesView.table().hand gives them: [paper name, ink name, chips].
const SAMPLES := [["Composure", "Fog", 1], ["Kindness", "Appetite", 1], ["Scruple", "Pride", 2]]

var travel := ArenaTravel.new()
var piles := ArenaPiles.new()
var stage := ArenaStage.new()
var moments: ArenaCardMoments
var _hand: Array[ArenaCard] = []
var _next_id := 1
## Which way 7 and 8 go next: true for paper to ink.
var _to_ink := {"draw": true, "discards": false}
## The last caption each moment showed, and the longest a caption was on the page, for the
## self-test.
var _moment_ends := 0

var _is_jekyll := true
var _labels := {}
var _status: Label
var _settings: Label
var _presses := 0
var _press_button := Button.new()


func _ready() -> void:
	add_child(beats)
	add_child(stage)
	add_child(piles)
	add_child(travel)
	stage.beats = beats
	piles.bind(beats, travel)
	travel.beats = beats
	moments = ArenaCardMoments.new(beats, travel, piles, stage)
	moments.joined.connect(func(_c: Array) -> void: _moment_ends += 1)
	moments.brought.connect(func(_c: Array) -> void: _moment_ends += 1)
	moments.side_changed.connect(func(_b: Dictionary, _a: Dictionary, _n: ArenaCard) -> void:
		_moment_ends += 1)
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
	beats.shown.snap_to(engine, ["score", "plays", "discards", "restraint/meter", "draw_count",
			"discard_count"])
	beats.shown.set_value("deck_count", 40)
	beats.shown.set_value("chips", 0)
	beats.shown.set_value("mult", 0)
	_show_status()
	_show_settings()

	if Shot.has_arg("selftest"):
		await _selftest()
		get_tree().quit()
		return
	# The keys of --run one after the other, each once the last has played; the last is not
	# waited on, so that --at can catch it on its way.
	var keys := Shot.arg("run").to_upper()
	for i in keys.length():
		if i > 0 and beats.is_running():
			await beats.emptied
		_act(keys.unicode_at(i))
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
		KEY_D:
			_deal(5)
		KEY_X:
			_discard(2)
		KEY_P:
			_from_discards()
		KEY_C:
			_to_centre(3)
		KEY_N:
			_draw_to_centre()
		KEY_K:
			_push_into_draw()
		KEY_R:
			_reshuffle()
		KEY_T:
			_turn_first()
		KEY_G:
			if not beats.is_running():
				piles.deck_mode = not piles.deck_mode
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			if not beats.is_running():
				_moment(keycode - KEY_0)
				beats.run()


# --- Card moments ------------------------------------------------------------------------------

## The twin of a sample card, as the engine would give it: the other side of the same Root.
func _twin(data: Dictionary) -> Dictionary:
	for s: Array in SAMPLES:
		if data.name == s[0] or data.name == s[1]:
			var ink: bool = not data.ink
			return {"id": data.id, "name": s[1] if ink else s[0], "ink": ink,
					"chips": s[2] + (1 if ink else 0)}
	return data


func _root(name: String) -> Dictionary:
	var data := _sample()
	for s: Array in SAMPLES:
		if name == s[0] or name == s[1]:
			data.name = name
			data.ink = name == s[1]
			data.chips = s[2] + (1 if data.ink else 0)
	return data


## The bench's stand-in hand takes cards that have arrived in the centre, and closes up.
func _take_into_hand(nodes: Array) -> void:
	for card: ArenaCard in nodes:
		_hand.append(card)
	var last: Signal
	for i in _hand.size():
		last = travel.fly(_hand[i], _hand_slot(i, _hand.size()), _hand_turn(i, _hand.size()),
				1.0, ArenaTravel.UP, ArenaPace.TRAVEL, ArenaPace.travel_start(maxi(0, i - _hand.size() + nodes.size())))
	await last


## Bench set-up, not a move: puts n cards on the discards at once, if there are fewer.
func _ensure_discards(n: int) -> void:
	if int(engine.discard_count) < n:
		engine.discard_count = n
		beats.shown.set_value("discard_count", n)


func _moment(which: int) -> void:
	var ink_from := Vector2(930.0, 200.0)
	match which:
		1:
			var cards := [_root("Fog"), _root("Fog"), _root("Appetite"), _root("Pride")]
			_count_in(cards.size())
			moments.join_deck(cards, ArenaCaptions.joins("arrival", []), ink_from)
		2:
			var card := _root("Kindness")
			_count_in(1)
			moments.join_deck([card], ArenaCaptions.joins("reward", [card.name]), Vector2(628.0, 70.0))
		3:
			var cards := [_root("Fog"), _root("Fog")]
			engine.draw_count -= 2
			moments.bring_to_hand("Hyde", cards, "draw", _take_into_hand)
		4:
			_ensure_discards(2)
			var cards := [_root("Composure"), _root("Scruple")]
			engine.discard_count -= 2
			moments.bring_to_hand("Jekyll", cards, "discards", _take_into_hand)
		5:
			moments.bring_to_hand("Hyde", [], "draw", _take_into_hand)
		6, 9:
			var at := -1
			for i in _hand.size():
				if which == 6 or not (_hand[i].get_meta("data") as Dictionary).ink:
					at = i
					break
			if at < 0:
				return
			var card := _hand[at]
			var before: Dictionary = card.get_meta("data")
			var after := _twin(before)
			var change := "convert" if which == 9 else ("stain" if not before.ink else "turn")
			moments.change_side(before, after, "hand", ArenaCaptions.changes(change, before.name, after.name),
					card, _hand_slot(at, _hand.size()), _hand_turn(at, _hand.size()))
		7, 8:
			var where := "draw" if which == 7 else "discards"
			if where == "discards":
				_ensure_discards(1)
			var to_ink: bool = _to_ink[where]
			_to_ink[where] = not to_ink
			var before := _root("Kindness" if to_ink else "Fog")
			var after := _twin(before)
			moments.change_side(before, after, where,
					ArenaCaptions.changes("stain" if to_ink else "turn", before.name, after.name))


## Cards joining: into the deck between rounds, else into the draw pile.
func _count_in(n: int) -> void:
	if piles.deck_mode:
		beats.shown.set_value("deck_count", int(beats.shown.value("deck_count", 0)))
	else:
		engine.draw_count += n


# --- Cards -------------------------------------------------------------------------------------

## The data of a new sample card, as the engine would give it.
func _sample() -> Dictionary:
	var s: Array = SAMPLES[_next_id % SAMPLES.size()]
	var ink := _next_id % 4 == 1
	var data := {"id": _next_id, "name": s[1] if ink else s[0], "ink": ink, "chips": s[2] + (1 if ink else 0)}
	_next_id += 1
	return data


## The centre of the i-th of n cards in the bench's stand-in hand.
func _hand_slot(i: int, n: int) -> Vector2:
	return Vector2(628.0 + (i - (n - 1) * 0.5) * 90.0, 458.0 + absf(i - (n - 1) * 0.5) * 2.0)


func _hand_turn(i: int, n: int) -> float:
	return (i - (n - 1) * 0.5) * 1.5


## A beat: the hand closes up or opens to make room, every card to its place.
func _add_relay() -> void:
	beats.add(func() -> void:
		var last: Signal
		for i in _hand.size():
			last = travel.fly(_hand[i], _hand_slot(i, _hand.size()), _hand_turn(i, _hand.size()))
		if not _hand.is_empty():
			await last)


func _deal(n: int) -> void:
	if beats.is_running():
		return
	n = mini(n, mini(8 - _hand.size(), int(engine.draw_count)))
	if n <= 0:
		return
	var datas: Array = []
	for i in n:
		datas.append(_sample())
	engine.draw_count -= n
	beats.add(func() -> void:
		var cards: Array = []
		var to: Array = []
		var turns: Array = []
		var size := _hand.size() + n
		for i in n:
			var card := piles.take("draw", datas[i])
			cards.append(card)
			to.append(_hand_slot(_hand.size() + i, size))
			turns.append(_hand_turn(_hand.size() + i, size))
		_hand.append_array(cards)
		await travel.fly_group(cards, to, turns, 1.0, ArenaTravel.UP))
	_add_relay()
	beats.run()


func _discard(n: int) -> void:
	if beats.is_running() or _hand.is_empty():
		return
	n = mini(n, _hand.size())
	var cards: Array = _hand.slice(0, n)
	engine.discard_count += n
	beats.add(func() -> void:
		for card: ArenaCard in cards:
			_hand.erase(card)
		await piles.put("discards", cards))
	_add_relay()
	beats.run()


func _from_discards() -> void:
	if beats.is_running() or int(engine.discard_count) == 0 or _hand.size() >= 8:
		return
	engine.discard_count -= 1
	var data := _sample()
	beats.add(func() -> void:
		var card := piles.take("discards", data)
		_hand.append(card)
		await travel.fly(card, _hand_slot(_hand.size() - 1, _hand.size()),
				_hand_turn(_hand.size() - 1, _hand.size()), 1.0, ArenaTravel.UP))
	_add_relay()
	beats.run()


func _to_centre(n: int) -> void:
	if beats.is_running() or _hand.is_empty():
		return
	n = mini(n, _hand.size())
	var cards: Array = _hand.slice(_hand.size() - n)
	engine.discard_count += n
	beats.add(func() -> void:
		for card: ArenaCard in cards:
			_hand.erase(card)
		stage.show_caption("A group of %d is held in the centre." % n)
		await stage.lay(travel, cards))
	_add_relay()
	beats.add_wait(ArenaPace.HOLD)
	beats.add(func() -> void:
		await stage.clear_caption()
		await piles.put("discards", cards))
	beats.run()


func _draw_to_centre() -> void:
	if beats.is_running() or int(engine.draw_count) == 0 or _hand.size() >= 8:
		return
	engine.draw_count -= 1
	var data := _sample()
	var card_box := [null]
	beats.add(func() -> void:
		var card := piles.take("draw", data)
		card_box[0] = card
		stage.show_caption("%s is drawn." % data.name)
		await stage.lay(travel, [card]))
	beats.add_wait(ArenaPace.HOLD)
	beats.add(func() -> void:
		var card: ArenaCard = card_box[0]
		_hand.append(card)
		stage.clear_caption()
		await travel.fly(card, _hand_slot(_hand.size() - 1, _hand.size()),
				_hand_turn(_hand.size() - 1, _hand.size())))
	_add_relay()
	beats.run()


func _push_into_draw() -> void:
	if beats.is_running() or _hand.is_empty():
		return
	var card: ArenaCard = _hand[0]
	engine.draw_count += 1
	beats.add(func() -> void:
		_hand.erase(card)
		await piles.put("draw", [card], true))
	_add_relay()
	beats.run()


func _reshuffle() -> void:
	if beats.is_running() or int(engine.discard_count) == 0:
		return
	engine.draw_count += engine.discard_count
	engine.discard_count = 0
	beats.add(func() -> void: await piles.reshuffle())
	beats.run()


func _turn_first() -> void:
	if beats.is_running() or _hand.is_empty():
		return
	beats.add(func() -> void: await travel.turn_over(_hand[0], not _hand[0].face_up))
	beats.run()


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
	engine.score = score + total + (15 if wrong else 0)
	engine.plays = maxi(0, plays - 1)
	engine.restraint.meter = mini(5, meter + 1)

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
	var help := _label(Vector2(50.0, 448.0), 10)
	help.modulate = DIM
	help.text = "B a move  E one the engine ends otherwise\nS speed  F reduce flashes" \
			+ "\nD deal  X discard  P discard to hand\nC to the centre  N draw to the centre" \
			+ "\nK into the draw pile  R reshuffle\nT turn over  G between rounds" \
			+ "\n1 four join  2 one joins  3 brought from draw" \
			+ "\n4 from the discards  5 none  6 side in the hand" \
			+ "\n7 side in the draw pile  8 in the discards  9 rescue" \
			+ "\nClick or key in a move: hurry; hold: skip"


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
	# 6. Cards travel between the piles, the hand and the centre, and the counts follow.
	for keycode in [KEY_D, KEY_X, KEY_C, KEY_N, KEY_P, KEY_K, KEY_R, KEY_T]:
		_act(keycode)
		if beats.is_running():
			await beats.emptied
		_expect(beats.shown.differences(engine).is_empty(),
				"counts match after %s: %s" % [OS.get_keycode_string(keycode), str(beats.shown.differences(engine))])
	_expect(_hand.size() == 1 and _hand[0].face_up == false, "the hand holds 1, turned down")
	_expect(int(engine.discard_count) == 0 and piles.discard_pile.count == 0, "the discards are empty after R")
	_expect(piles.draw_pile.count == int(engine.draw_count), "the draw pile shows its count")
	# 7. The card moments: each runs, ends with its signal, and leaves the counts right.
	for which in range(1, 10):
		var ends := _moment_ends
		var hand_before := _hand.size()
		var first: Dictionary = _hand[0].get_meta("data") if not _hand.is_empty() else {}
		_moment(which)
		if not beats.is_running():
			beats.run()
		beats.skip()
		if beats.is_running():
			await beats.emptied
		_expect(_moment_ends == ends + 1 or which == 9 and first.get("ink", true),
				"moment %d sends its signal at its end" % which)
		_expect(beats.shown.differences(engine).is_empty(),
				"counts match after moment %d: %s" % [which, str(beats.shown.differences(engine))])
		if which == 3 or which == 4:
			_expect(_hand.size() == hand_before + 2, "moment %d brings two to the hand" % which)
		if which == 6:
			var now: Dictionary = _hand[0].get_meta("data")
			_expect(now.name == _twin(first).name and _hand[0].title == now.name,
					"the hand card ends as its twin (%s to %s)" % [first.name, now.name])
	_expect(travel.get_children().all(func(c: Node) -> bool: return c in _hand),
			"no card is left lying on the travel layer")
	# A caption stays at least a second at speed 1, unhurried.
	var shown_for := 0.0
	_moment(5)
	beats.run()
	while beats.is_running():
		if stage.caption() != "":
			shown_for += get_process_delta_time()
		await get_tree().process_frame
	_expect(shown_for >= ArenaPace.CAPTION_MIN - 0.05, "a caption stays a second (%.2f s)" % shown_for)
	_expect(ArenaCaptions.brings("Hyde", ["Fog", "Fog"]) == "Hyde brings two Fog."
			and ArenaCaptions.brings("Jekyll", ["Composure", "Scruple"]) == "Jekyll brings a Composure and a Scruple."
			and ArenaCaptions.changes("stain", "Kindness", "Appetite") == "The draught stains a Kindness. It is an Appetite now."
			and ArenaCaptions.joins("breakout", ["Fog", "Pride"]) == "He breaks out. A Fog and a Pride join the deck."
			and ArenaCaptions.joins("dawn", ["Appetite", "Appetite"]) == "Dawn. Two Appetite join the deck."
			and ArenaCaptions.joins("no_paper", ["Appetite"]) == "Nothing is left to stain. An Appetite joins the deck.",
			"the captions read as doc-3's tables")
	print("SELFTEST PASS" if _fails.is_empty() else "SELFTEST FAILED: %s" % str(_fails))


class _Catcher:
	extends Node
	var seen := 0

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key and key.pressed and key.keycode == KEY_X:
			seen += 1
