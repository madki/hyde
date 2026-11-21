extends "res://tests/case.gd"
## The proof that these rules and the reference implementation are the same game: recorded
## runs replayed move for move. Also random play, saving mid-run, and changed numbers.

const Golden := preload("res://tests/golden.gd")


func test_golden_runs_replay() -> void:
	var runs := Golden.runs()
	ok(runs.size() >= 200, "at least 200 recorded runs (%d)" % runs.size())
	var moves := 0
	var same_runs := 0
	for i in runs.size():
		var record: Dictionary = runs[i]
		var run := Golden.begin(record)
		var first := Golden.digest(run)
		if first != record.first:
			_fail("run %d starts differently:\n    got  %s\n    want %s" % [i, first, record.first])
			checks += 1
			continue
		var broke := false
		for j in record.moves.size():
			var accepted := Golden.apply(run, record.moves[j])
			var text := Golden.digest(run)
			moves += 1
			if accepted != (record.oks[j] == "1") or Golden.fnv(text) != record.hashes[j]:
				_fail("run %d differs after move %d %s (%s):\n    got %s" % [i, j + 1, JSON.stringify(record.moves[j]), "accepted" if accepted else "refused", text])
				broke = true
				break
		checks += 1
		if broke:
			continue
		eq(Golden.digest(run), record.last, "run %d ends the same" % i)
		same_runs += 1
	eq(same_runs, runs.size(), "every recorded run replays with the same state after every move (%d moves)" % moves)


func test_golden_runs_cover_the_game() -> void:
	var endings := {}
	var phases := {}
	var starts := {}
	var dials := {}
	var names := {}
	for record: Dictionary in Golden.runs():
		var run := Golden.begin(record)
		starts[record.start.night if record.start != null else 0] = true
		for k: String in record.dials:
			dials["%s %s" % [k, record.dials[k]]] = true
		for move: Array in record.moves:
			phases[run.phase] = true
			names[move[0]] = true
			Golden.apply(run, move)
		phases[run.phase] = true
		if run.phase == "end":
			endings[run.ending] = int(endings.get(run.ending, 0)) + 1
	ok(endings.has("hyde") and endings.has("double") and endings.has("myself"), "the runs reach all three endings: %s" % JSON.stringify(endings))
	eq(phases.size(), Rules.PHASES.size(), "and every phase")
	ok(starts.has(0) and starts.has(1) and starts.has(2) and starts.has(3) and starts.has(4), "whole runs, and runs that start on nights 2 to 5")
	ok(dials.has("craving_cap 2") and dials.has("restraint_limit 3"), "runs with changed numbers")
	for name: String in ["play", "discard", "drink", "salt", "pass", "giveup", "continue", "habit", "inst", "asalt", "aleave", "card", "tool", "lsalt", "strike", "drop", "lleave"]:
		ok(names.has(name), "the runs make the move '%s'" % name)


func test_save_and_load_mid_run() -> void:
	var runs := Golden.runs()
	var tried := 0
	for i in range(0, runs.size(), 5):
		var record: Dictionary = runs[i]
		var run := Golden.begin(record)
		@warning_ignore("integer_division")
		var half: int = record.moves.size() / 2
		for j in half:
			Golden.apply(run, record.moves[j])
		var loaded := Rules.from_json(Rules.to_json(run))
		if not same(loaded, run):
			_fail("run %d comes back from JSON changed after %d moves" % [i, half])
		for j in range(half, record.moves.size()):
			Golden.apply(loaded, record.moves[j])
		eq(Golden.digest(loaded), record.last, "run %d, saved after %d moves and loaded, ends the same" % [i, half])
		tried += 1
	ok(tried >= 40, "tried on %d runs" % tried)


# ---------- random play: no broken state ----------

var _r := 0


func _rand() -> float:
	_r = (_r * 1103515245 + 12345) & 0x7fffffff
	return _r / float(0x7fffffff)


func _pick_n(items: Array, n: int) -> Array:
	var a := items.duplicate()
	var out: Array = []
	while out.size() < n and not a.is_empty():
		out.append(a.pop_at(int(_rand() * a.size())))
	return out


func _invariants(run: Dictionary, where: String) -> void:
	var d: Dictionary = run.dials
	var li := Rules.line_info(run)
	var all: Array = run.cards.map(func(c: Dictionary) -> int: return c.id)
	all.sort()
	var unique := {}
	for id: int in all:
		unique[id] = true
	ok(unique.size() == all.size(), where + ": card ids are unique")
	if run.phase == "play":
		var piles: Array = run.hand + run.draw + run.discard
		piles.sort()
		ok(piles == all, where + ": hand, draw pile and discards hold the deck exactly once")
		ok(run.plays > 0, where + ": a round in play has a play left")
		ok(run.score < Rules.target(run), where + ": a round in play is under its target")
		ok(run.stance != "jekyll" or run.restraint < Rules.limit(run), where + ": restraint under its limit while Jekyll plays")
		ok(run.hand.size() >= mini(d.hand_size, all.size()), where + ": the hand is full")
	else:
		ok(run.hand.is_empty() and run.draw.is_empty() and run.discard.is_empty(), where + ": no piles between rounds")
	for k in RulesConfig.ROOTS:
		ok(run.craving[k] >= 0 and run.craving[k] < d.craving_cap and run.habit[k] >= 0 and run.temper[k] >= 0, where + ": gauges in range")
	ok(run.restraint >= 0 and run.stored >= 0 and run.salt >= 0 and run.sov >= 0 and run.discards >= 0 and run.plays >= 0, where + ": nothing negative")
	ok(run.stance == "jekyll" or run.hyde_arrived, where + ": Hyde at the table has arrived")
	ok(run.stance == "hyde" or run.stored == 0, where + ": nothing stored while Jekyll has the table")
	var held := {}
	for k: String in run.instruments:
		held[k] = true
	ok(run.instruments.size() <= RulesConfig.MAX_INSTRUMENTS and held.size() == run.instruments.size(), where + ": instruments")
	ok((run.phase == "end") == (run.ending != null), where + ": an ending exactly when the run is over")
	ok(li.ink + li.paper + run.cards.filter(Rules.is_factor).size() == run.cards.size(), where + ": every card is a Root or a Factor")
	ok(typeof(run.score) == TYPE_INT, where + ": the score is a whole number")
	ok(Rules.PHASES.has(run.phase), where + ": a known phase")


func _random_run(seed_value: int, dials: Dictionary, start_night: int, check: bool = true) -> Dictionary:
	var run := Rules.new_run(dials, seed_value)
	if start_night > 0:
		Golden.start_on(run, start_night, seed_value % 3)
	_r = seed_value * 7919 + 13
	var steps := 0
	while run.phase != "end" and steps < 900:
		steps += 1
		var did := ""
		match run.phase:
			"play":
				var x := _rand()
				if x < 0.07 and Rules.can_drink(run).ok:
					Rules.drink(run)
					did = "drink"
				elif x < 0.16 and Rules.can_salt(run).ok:
					Rules.take_salt(run)
					did = "salt"
				elif x < 0.28 and run.discards > 0:
					Rules.discard(run, _pick_n(run.hand, 1 + int(_rand() * 5)))
					did = "discard"
				elif Rules.can_pass(run).ok:
					Rules.pass_play(run)
					did = "pass"
				elif not Rules.has_play(run):
					Rules.discard(run, _pick_n(run.hand, 5))
					did = "discard all"
				elif x < 0.75:
					var b := Rules.best(run)
					ok(not b.is_empty(), "seed %d: a playable hand has a best play" % seed_value)
					Rules.play(run, b.ids)
					did = "best"
				else:
					# A random allowed set of cards.
					var done := false
					for t in 30:
						var sel := _pick_n(run.hand, 1 + int(_rand() * 5))
						if Rules.evaluate(run, sel.map(func(id: int) -> Dictionary: return Rules.card(run, id))).ok:
							Rules.play(run, sel)
							done = true
							break
					if not done:
						Rules.play(run, Rules.best(run).ids)
					did = "random"
			"result":
				Rules.continue_result(run, int(_rand() * 3) if run.offer != null and _rand() < 0.8 else null)
				did = "continue"
			"alley":
				if _rand() < 0.7:
					Rules.alley_habit(run, RulesConfig.ROOTS[int(_rand() * 3)])
				if _rand() < 0.7 and not run.alley.options.is_empty():
					Rules.alley_instrument(run, run.alley.options[int(_rand() * run.alley.options.size())])
				if _rand() < 0.5:
					Rules.alley_salt(run)
				Rules.alley_leave(run)
				did = "alley"
			"lab":
				for i in 3:
					if _rand() < 0.6:
						Rules.buy_card(run, i)
				for i in 2:
					if _rand() < 0.5:
						Rules.buy_instrument(run, i)
				if _rand() < 0.6:
					Rules.buy_salt(run)
				if _rand() < 0.3:
					Rules.strike(run, run.cards[int(_rand() * run.cards.size())].id)
				if _rand() < 0.15 and not run.instruments.is_empty():
					Rules.drop_instrument(run, run.instruments[0])
				Rules.leave_lab(run)
				did = "lab"
		if check:
			_invariants(run, "seed %d step %d after %s" % [seed_value, steps, did])
		if fails > 40:
			break
	ok(run.phase == "end", "seed %d: the run ends" % seed_value)
	return run


func test_random_play() -> void:
	var settings := [
		{}, {"craving_cap": 2, "restraint_limit": 3}, {"target_scale": 0.5},
		{"target_scale": 0.2, "restraint_limit": 8}, {"target_scale": 0.2, "craving_cap": 5},
	]
	var endings := {"hyde": 0, "double": 0, "myself": 0}
	var nights := [0, 0, 0, 0, 0]
	for i in 500:
		if fails > 40:
			break
		var run := _random_run(1000 + i, settings[i % settings.size()], 1 + (i % 4) if i % 3 == 1 else 0)
		endings[run.ending] += 1
		nights[run.night] += 1
		if i % 10 == 0:
			eq(Rules.from_json(Rules.to_json(run)), run, "seed %d: the state survives JSON" % (1000 + i))
	print("  500 random runs: endings %s, last night reached %s" % [JSON.stringify(endings), JSON.stringify(nights)])
	ok(endings.hyde > 0 and nights[4] > 0, "runs end in more than one way and reach the last night")


func test_same_seed_same_run() -> void:
	var a := _random_run(77, {}, 0, false)
	var b := _random_run(77, {}, 0, false)
	eq(b, a, "a run is repeatable from its seed and its moves")
	var c := _random_run(78, {}, 0, false)
	ok(not same(c, a), "and another seed gives another run")


func test_number_dials() -> void:
	var run := as_hyde(fresh({"craving_cap": 2, "habit_chips": 20, "habit_mult": 2, "restraint_pay": 3}, 32))
	run.habit.lamp = 1
	run.stored = 2
	run.craving.lamp = 1
	var e := Rules.evaluate(run, cards("I:lamp I:lamp"))
	eq([e.chips, e.mult, e.breeds], [35 + 2 * (15 + 10 + 20), 5 + 4 + 6, ["lamp"]], "craving_cap, habit_chips, habit_mult, restraint_pay")
	run = fresh({"temper_chips": 10, "temper_mult": 3}, 32)
	run.temper.lamp = 2
	e = Rules.evaluate(run, cards("P:lamp P:heart"))
	eq([e.chips, e.mult], [30 + 35 + 15, 3 + 6], "temper_chips, temper_mult")
	run = fresh({"target_scale": 0.5}, 32)
	var scenes: Array = []
	for n in 5:
		run.night = n
		run.round = 2
		scenes.append(Rules.target(run))
	eq(scenes, [2200, 2750, 6500, 13000, 20000], "target_scale leaves night 1 alone")
	run = fresh({"restraint_limit": 3, "alley_markup": 4}, 32)
	eq([Rules.limit(run), Rules.salt_cost(run, "alley")], [3, 7], "restraint_limit, alley_markup")
	run = fresh({"plays": 2, "discards": 1, "hand_size": 6, "salt_start": 1}, 32)
	eq([run.plays, run.discards, run.hand.size(), run.salt], [2, 1, 6, 1], "plays, discards, hand_size, salt_start")
