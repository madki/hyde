class_name ArenaBench
## Drives the arena from the command line, for stills and for a check without a window:
##
## - `--keys=<keys>`: makes moves, one key after another, each when the move before it is
##   over: 1 to 9 and 0 choose the card at that place, P plays, D discards, N passes, Q drinks,
##   S takes salt, X lets the chosen cards go, B plays the best hand the rules find, and Z
##   leaves nothing to play (the cards that can be played go to the discards, and no discard
##   is left), so that N can pass. T holds Tab down (every number, as Shift does), K opens the piles' view at the draw pile's
##   section and L at the discards',
##   H presses the hint. At a reward 1 to 3 take that card and 0 none.
## - `--set=<name>:<value>,...`: numbers and names of the run to change before its first
##   round is shown, for looking at a moment that is far into a run: `restraint`, `stored`,
##   `plays`, `discards`, `score`, `sov`, `salt`, `stance`, `hyde_arrived` (0 or 1), and
##   `night` and `round` (from 0), which begin that round anew; `craving_lamp`, `habit_heart`,
##   `temper_mirror` and so on for a gauge; `inst:<key>` to hold an instrument (once for each).
## - `--hand=<card>,...`: the cards of the first hand, in place of those dealt: `lamp`,
##   `heart`, `mirror` for a Paper Root, with `*` after it for its Ink twin, and `cup`, `eye`,
##   `lock`, `pen`, `cane` for a Factor. A card the deck lacks is added to it.
## - `--time`: plays the last key's move at the usual speed and prints how long it took.
## - `--quit`: quits when the keys' moves are over (for a run without a window).
## - `--trace`: prints the readout after each step of a play, as the readout shows it.
## - `--at=<seconds>`: with `--shot`, the still is taken this long into the last key's move
##   (or into the deal, without keys) instead of when it is over.
## - `--fast`: every move is played back at once.
## - `--calm`: "reduce flashes" is on.
## - `--selftest[=<moves>]`: plays that many moves (300 by default) at random, played back at
##   once, and checks after each that the table shows what the engine holds. Prints
##   SELFTEST PASS or FAIL and quits.
##
## A notice (ArenaNotice) waits for a player, and none is here: every notice is passed at once,
## with any of these arguments. Only `--at` lets one be shown, in the move the still is taken
## in, so that the still can be of it. A page of the story (`--story`, see ArenaStory) is
## pressed on in the same way, wherever the bench waits for a move to be over.
##
##   godot --headless --path . res://scenes/arena.tscn -- --selftest --seed=5


static func run_if_requested(arena: Node) -> void:
	if Shot.has_arg("calm"):
		ArenaPace.reduce_flashes = true
	if Shot.has_arg("selftest"):
		ArenaNotice.pass_at_once = true
		await _selftest(arena)
		return
	if not Shot.has_arg("shot") and not Shot.has_arg("keys") and not Shot.has_arg("quit"):
		return
	var at := float(Shot.arg("at")) if Shot.has_arg("at") else -1.0
	var keys := Shot.arg("keys")
	# No player is here to acknowledge a notice; the move a still is taken in shows its own.
	ArenaNotice.pass_at_once = at < 0.0 or keys != ""
	if Shot.has_arg("fast") or (Shot.has_arg("shot") and at < 0.0):
		ArenaPace.speed = ArenaPace.SKIP
	var tree := arena.get_tree()
	var began := 0
	for i in keys.length():
		await _idle(arena, true)
		if (at >= 0.0 or Shot.has_arg("time")) and i == keys.length() - 1:
			ArenaPace.speed = 1.0
			ArenaNotice.pass_at_once = at < 0.0
		began = Time.get_ticks_msec()
		_press(arena, keys[i])
		await tree.process_frame
	if at >= 0.0:
		if keys == "":
			await tree.process_frame
		await tree.create_timer(at).timeout
	else:
		await _idle(arena, true)
	if Shot.has_arg("time"):
		print("the last move took %.2f s" % ((Time.get_ticks_msec() - began) / 1000.0))
	if Shot.has_arg("quit"):
		tree.quit()


## Changes the run as `--set` asks. Call before the run's first round is shown.
static func apply_set(run: RulesRun) -> void:
	var values := {}
	var held: Array[String] = []
	for part in Shot.arg("set").split(",", false):
		var pair := part.split(":")
		if pair.size() == 2 and pair[0] == "inst":
			held.append(pair[1])
		elif pair.size() == 2:
			values[pair[0]] = pair[1]
	# Held before the round begins anew, so that the round counts on them.
	for key in held:
		_change(run, "inst", key)
	var again := false
	for name: String in ["night", "round", "stance", "hyde_arrived", "restraint"]:
		if values.has(name):
			_change(run, name, values[name])
			again = again or name in ["night", "round"]
	if again:
		Rules.start_round(run)
	for name: String in values:
		if not name in ["night", "round"] and not (again and name in ["stance", "hyde_arrived", "restraint"]):
			_change(run, name, values[name])
	_deal_hand(run)


# Replaces the hand that was dealt with the cards `--hand` names, and has the round's events
# say so, so that the table deals them.
static func _deal_hand(run: RulesRun) -> void:
	if not Shot.has_arg("hand"):
		return
	run.draw.append_array(run.hand)
	run.hand = []
	for name in Shot.arg("hand").split(",", false):
		var ink := name.ends_with("*")
		var key := name.trim_suffix("*")
		var found := -1
		for id: int in run.draw:
			var c := Rules.card(run, id)
			if c.key() == key and c.is_ink() == ink:
				found = id
				break
		if found < 0:
			found = Rules.add_card(run, key, ink, false).id
		else:
			run.draw.erase(found)
		run.hand.append(found)
	run.events = [
		{"t": "shuffle", "ids": run.draw + run.hand},
		{"t": "drawn", "why": "deal", "ids": run.hand.duplicate()},
	]


static func _change(run: RulesRun, name: String, value: String) -> void:
	if name == "stance":
		run.stance = value
	elif name == "hyde_arrived":
		run.hyde_arrived = value == "1"
	elif name in ["night", "round", "restraint", "stored", "plays", "discards", "score", "sov", "salt"]:
		run.set(name, int(value))
	elif name == "inst":
		# A key the rules do not know cannot be held: the table would have no emblem for it.
		if RulesConfig.INSTRUMENTS.has(value):
			run.instruments.append(value)
		else:
			push_warning("--set=inst:%s: no such instrument. They are %s." % [value, ", ".join(RulesConfig.INSTRUMENTS.keys())])
	elif name.get_slice("_", 0) in ["craving", "habit", "temper"]:
		(run.get(name.get_slice("_", 0)) as Dictionary)[name.get_slice("_", 1)] = int(value)


# Waits until the player may act: a move, or a choice (`at_choice`). Without `at_choice` a
# choice is made on the way: a card of a reward is taken, the first.
static func _idle(arena: Node, at_choice: bool = false) -> void:
	var reward: ArenaReward = arena.t.reward
	while not arena.is_idle():
		if arena.t.story_up:
			# No player is here to read it: the page is pressed on, a press a frame.
			for child in arena.get_children():
				if child is StoryPage:
					child.press()
		elif reward.waiting:
			if at_choice:
				return
			reward.pick(0)
		elif arena.t.waiting_press:
			if at_choice:
				return
			arena.t.pressed.emit()
		await arena.get_tree().process_frame


static func _press(arena: Node, key: String) -> void:
	var hand: ArenaHand = arena.t.hand
	var reward: ArenaReward = arena.t.reward
	if reward.waiting:
		# At a reward: 1 to 3 take a card, anything else none.
		reward.pick(int(key) - 1 if key.is_valid_int() else -1)
		return
	if arena.t.waiting_press:
		arena.t.pressed.emit()
		return
	match key.to_upper():
		"P":
			arena.play_chosen()
		"D":
			arena.discard_chosen()
		"N":
			arena.pass_play()
		"Q":
			arena.drink()
		"S":
			arena.take_salt()
		"X":
			hand.clear_chosen()
		"T":
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			Input.parse_input_event(tab)
		"K", "L":
			for child in arena.get_children():
				if child is ArenaViews:
					child._open_pile("draw" if key.to_upper() == "K" else "discards")
		"H":
			for child in arena.get_children():
				if child is ArenaViews:
					child._show_a_hand()
		"Z":
			var run: RulesRun = arena.run()
			run.discards = 0
			for id: int in run.hand.duplicate():
				var c := Rules.card(run, id)
				if c.is_factor() or c.ink == (run.stance == "hyde"):
					run.hand.erase(id)
					run.discard.append(id)
			arena.t.catch_up()
		"B":
			var best: Dictionary = Rules.best(arena.run())
			for id: int in best.get("ids", []):
				hand.toggle(id)
			arena.play_chosen()
		"0":
			hand.toggle_at(9)
		_:
			if key.is_valid_int():
				hand.toggle_at(int(key) - 1)


# Plays moves at random through the arena and checks the table against the engine after each.
static func _selftest(arena: Node) -> void:
	ArenaPace.speed = ArenaPace.SKIP
	var moves := int(Shot.arg("selftest")) if Shot.arg("selftest") != "" else 300
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Shot.arg("seed")) if Shot.has_arg("seed") else 1
	var t: ArenaTable = arena.t
	var errors: Array[String] = []
	t.beats.corrected.connect(func(off: Dictionary) -> void:
		errors.append("shown values corrected: %s" % str(off.keys())))
	var made := {}
	for i in moves:
		await _idle(arena)
		var run: RulesRun = arena.run()
		# Before each move, the first too: a table opened on a run under way is checked as dealt.
		_check(arena, "move %d" % i, errors)
		var move := ""
		var before := Rules.to_json(run)
		var roll := rng.randf()
		if Rules.can_pass(run).ok:
			move = "pass"
			arena.pass_play()
		elif roll < 0.12 and Rules.can_drink(run).ok:
			move = "drink"
			arena.drink()
		elif roll < 0.2 and Rules.can_salt(run).ok:
			move = "salt"
			arena.take_salt()
		elif (roll < 0.4 or not Rules.has_play(run)) and run.discards > 0:
			move = "discard"
			var n := rng.randi_range(1, mini(3, run.hand.size()))
			for k in n:
				t.hand.toggle_at(rng.randi_range(0, run.hand.size() - 1))
			if t.hand.chosen().is_empty():
				t.hand.toggle_at(0)
			arena.discard_chosen()
		else:
			move = "play"
			var best: Dictionary = Rules.best(run)
			var ids: Array = best.get("ids", [])
			# Now and then a poor play, so that rounds are also lost and rescued.
			if ids.is_empty() or rng.randf() < 0.3:
				ids = []
				for id: int in run.hand:
					var c := Rules.card(run, id)
					if ids.is_empty() and (c.is_factor() or c.ink == (run.stance == "hyde")):
						ids.append(id)
			for id: int in ids:
				t.hand.toggle(id)
			arena.play_chosen()
		made[move] = int(made.get(move, 0)) + 1
		# A move the rules accept has changed the run before the call returns.
		if Rules.to_json(arena.run()) == before:
			errors.append("move %d: a %s of %s was refused" % [i, move, t.hand.chosen()])
			t.hand.clear_chosen()
	await _idle(arena)
	_check(arena, "the end", errors)
	for line in errors.slice(0, 20):
		print("  ", line)
	print("moves made: ", made)
	print("SELFTEST %s" % ("PASS" if errors.is_empty() else "FAIL (%d)" % errors.size()))
	arena.get_tree().quit(0 if errors.is_empty() else 1)


# Whether the idle table shows what the engine holds: the hand, both piles' counts, and the
# score and the plays and discards left. What differs is added to `errors`, under `at`.
static func _check(arena: Node, at: String, errors: Array[String]) -> void:
	var t: ArenaTable = arena.t
	var run: RulesRun = arena.run()
	if run.phase != "play":
		return
	var hand_ids: Array = t.hand.ids()
	var want: Array = run.hand.duplicate()
	hand_ids.sort()
	want.sort()
	if hand_ids != want:
		errors.append("%s: the hand shows %s, the engine holds %s" % [at, hand_ids, want])
	if t.piles.draw_pile.count != run.draw.size() or t.piles.discard_pile.count != run.discard.size():
		errors.append("%s: the piles show %d and %d, the engine holds %d and %d" % [at,
				t.piles.draw_pile.count, t.piles.discard_pile.count, run.draw.size(), run.discard.size()])
	for key: String in ["score", "plays", "discards"]:
		if int(t.shown.value(key, -1)) != int(run.get(key)):
			errors.append("%s: the %s shows %s, the engine holds %s" % [at, key, t.shown.value(key), run.get(key)])
