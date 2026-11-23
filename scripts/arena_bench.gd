class_name ArenaBench
## Drives the arena from the command line, for stills and for a check without a window:
##
## - `--keys=<keys>`: makes moves, one key after another, each when the move before it is
##   over: 1 to 9 and 0 choose the card at that place, P plays, D discards, N passes, Q drinks,
##   S takes salt, X lets the chosen cards go, B plays the best hand the rules find, and Z
##   leaves nothing to play (the cards that can be played go to the discards, and no discard
##   is left), so that N can pass.
## - `--set=<name>:<value>,...`: numbers and names of the run to change before its first
##   round is shown, for looking at a moment that is far into a run: `restraint`, `stored`,
##   `plays`, `discards`, `score`, `sov`, `salt`, `stance`, `hyde_arrived` (0 or 1), and
##   `night` and `round` (from 0), which begin that round anew.
## - `--at=<seconds>`: with `--shot`, the still is taken this long into the last key's move
##   (or into the deal, without keys) instead of when it is over.
## - `--fast`: every move is played back at once.
## - `--selftest[=<moves>]`: plays that many moves (300 by default) at random, played back at
##   once, and checks after each that the table shows what the engine holds. Prints
##   SELFTEST PASS or FAIL and quits.
##
##   godot --headless --path . res://scenes/arena.tscn -- --selftest --seed=5


static func run_if_requested(arena: Node) -> void:
	if Shot.has_arg("selftest"):
		await _selftest(arena)
		return
	if not Shot.has_arg("shot") and not Shot.has_arg("keys"):
		return
	var at := float(Shot.arg("at")) if Shot.has_arg("at") else -1.0
	var keys := Shot.arg("keys")
	if Shot.has_arg("fast") or (Shot.has_arg("shot") and at < 0.0):
		ArenaPace.speed = ArenaPace.SKIP
	var tree := arena.get_tree()
	for i in keys.length():
		await _idle(arena)
		if at >= 0.0 and i == keys.length() - 1:
			ArenaPace.speed = 1.0
		_press(arena, keys[i])
		await tree.process_frame
	if at >= 0.0:
		if keys == "":
			await tree.process_frame
		await tree.create_timer(at).timeout
	else:
		await _idle(arena)


## Changes the run as `--set` asks. Call before the run's first round is shown.
static func apply_set(run: RulesRun) -> void:
	if not Shot.has_arg("set"):
		return
	var values := {}
	for part in Shot.arg("set").split(",", false):
		var pair := part.split(":")
		if pair.size() == 2:
			values[pair[0]] = pair[1]
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


static func _change(run: RulesRun, name: String, value: String) -> void:
	if name == "stance":
		run.stance = value
	elif name == "hyde_arrived":
		run.hyde_arrived = value == "1"
	elif name in ["night", "round", "restraint", "stored", "plays", "discards", "score", "sov", "salt"]:
		run.set(name, int(value))


static func _idle(arena: Node) -> void:
	while not arena.is_idle():
		await arena.settled


static func _press(arena: Node, key: String) -> void:
	var hand: ArenaHand = arena.t.hand
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
		var hand_ids: Array = t.hand.ids()
		var want: Array = run.hand.duplicate()
		hand_ids.sort()
		want.sort()
		if hand_ids != want:
			errors.append("move %d: the hand shows %s, the engine holds %s" % [i, hand_ids, want])
		if t.piles.draw_pile.count != run.draw.size() or t.piles.discard_pile.count != run.discard.size():
			errors.append("move %d: the piles show %d and %d, the engine holds %d and %d" % [i,
					t.piles.draw_pile.count, t.piles.discard_pile.count, run.draw.size(), run.discard.size()])
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
	for line in errors.slice(0, 20):
		print("  ", line)
	print("moves made: ", made)
	print("SELFTEST %s" % ("PASS" if errors.is_empty() else "FAIL (%d)" % errors.size()))
	arena.get_tree().quit(0 if errors.is_empty() else 1)
