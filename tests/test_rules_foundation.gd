extends "res://tests/case.gd"
## The seeded generator, the starting state, card chips, and saving a run as JSON.


func test_generator_matches_reference_values() -> void:
	# Each value times 2^32, which is a whole number.
	var want := {
		1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403, 1207330352],
		77: [1827943904, 181332479, 2989326142, 2086917005, 497196720, 3548107640],
		2147483646: [4267670024, 1636768646, 1630072450, 4289807666, 2606587044, 1121516213],
		-5: [2078107854, 227493659, 4033117029, 3420415754, 4193201262, 3638068775],
	}
	var seed_after := {1: -1895507009, 77: -1895506933, 2147483646: 251976636, -5: -1895507015}
	for s: int in want:
		var run := RulesRun.new()
		run.seed = RulesRng.wrap_seed(s)
		var got: Array = []
		for i in 6:
			got.append(int(RulesRng.next(run) * 4294967296.0))
		eq(got, want[s], "first 6 values for seed %d" % s)
		eq(run.seed, seed_after[s], "the seed after them, for seed %d" % s)
	eq(RulesRng.wrap_seed(4294967296 + 7), 7, "a seed wraps into 32 bits")
	eq(RulesRng.wrap_seed(2147483648), -2147483648, "and is kept signed")


func test_shuffle_matches_reference() -> void:
	var run := RulesRun.new()
	run.seed = 42
	var a: Array = range(1, 17)
	RulesRng.shuffle(run, a)
	eq(a, [13, 8, 1, 16, 5, 2, 4, 15, 11, 14, 6, 3, 9, 12, 7, 10], "a shuffle of 16 ids")
	eq(run.seed, 1703683461, "the seed after it")
	var r := fresh({}, 1)
	eq([r.hand, r.draw, r.seed], [[8, 1, 6, 9, 12, 2, 4, 10], [5, 11, 3, 7], -1327612536], "the first deal of seed 1")


func test_new_run() -> void:
	var run := fresh()
	var kinds := {}
	for c: RulesCard in run.cards:
		var k: String = c.kind if c.t == "factor" else ("ink " if c.ink else "paper ") + str(c.sym)
		kinds[k] = int(kinds.get(k, 0)) + 1
	eq(kinds, {"paper lamp": 3, "paper heart": 3, "paper mirror": 2, "cup": 2, "eye": 1, "lock": 1}, "the 12 starting cards")
	eq([run.stance, run.restraint, run.stored, run.salt, run.sov, run.hyde_arrived, run.instruments],
			["jekyll", 0, 0, 3, 0, false, []], "Jekyll's stance, restraint 0, 3 salt, 0 sovereigns, no instruments")
	var zero := {"lamp": 0, "heart": 0, "mirror": 0}
	eq([run.craving, run.habit, run.temper], [zero, zero, zero], "every gauge 0")
	eq([run.night, run.round, run.phase, run.plays, run.discards, run.score], [0, 0, "play", 4, 3, 0], "round 1 of night 1, 4 plays, 3 discards")
	eq([run.hand.size(), run.draw.size(), run.discard.size()], [8, 4, 0], "8 cards dealt of 12")
	eq(Rules.line_info(run), {"ink": 0, "paper": 8, "total": 12, "cushion": 8, "over": false}, "the line")
	eq([Rules.target(run), Rules.limit(run)], [1000, 5], "target 1,000, limit 5")
	var again := fresh()
	eq(again, run, "the same seed gives the same run")
	ok(not same(fresh({}, 2).hand, run.hand), "another seed gives another deal")


func test_card_chips() -> void:
	var run := fresh()
	var paper := loose("P:lamp")
	var ink := loose("I:heart")
	eq([Rules.chips_of(run, paper), Rules.chips_of(run, ink), Rules.chips_of(run, loose("F:cup"))], [15, 15, 10], "bare cards")
	run.temper.lamp = 2
	eq(Rules.chips_of(run, paper), 15 + 15 * 2, "Paper: 15 + 15 x Temper")
	eq(Rules.chips_of(run, loose("P:heart")), 15, "of its own symbol only")
	run.craving.heart = 2
	run.habit.heart = 3
	eq(Rules.chips_of(run, ink), 15 + 10 * 2 + 15 * 3, "Ink: 15 + 10 x Craving + 15 x Habit")
	eq(Rules.chips_of(run, ink, 0), 15 + 15 * 3, "at a given Craving")
	eq(Rules.chips_of(run, loose("F:pen")), 10, "a Factor is 10")
	eq([Rules.name_of(paper, "hyde"), Rules.name_of(ink, "jekyll"), Rules.name_of(loose("F:lock"), "jekyll"), Rules.name_of(loose("F:lock"), "hyde")],
			["Composure", "Appetite", "Resolve", "Cunning"], "a Root keeps its name, a Factor takes the name of the man at the table")


func test_config() -> void:
	var d := RulesDials.make({"craving_cap": 2})
	eq([d.craving_cap, d.restraint_limit, RulesDials.new().craving_cap], [2, 5, 3], "a run's numbers can be changed without touching the game's own")
	var scenes: Array = []
	for n in 5:
		scenes.append(RulesConfig.targets(d, n)[2])
	eq(scenes, [2200, 5500, 13000, 26000, 40000], "the scenes' targets")
	eq(RulesConfig.targets(d, 0), [1000, 1500, 2200], "night 1")


func test_json_round_trip() -> void:
	var run := fresh({}, 3)
	run.restraint = 2
	run.craving.lamp = 1
	var text := Rules.to_json(run)
	var back := Rules.from_json(text)
	eq(back, run, "the run comes back the same, with ints still ints")
	eq(typeof(back.cards[0].id), TYPE_INT, "a card id is an int")
	eq(typeof(back.hand[0]), TYPE_INT, "a pile holds ints")
	eq(typeof(back.seed), TYPE_INT, "the seed is an int")
	eq(back.last, null, "nothing stays nothing")
	var half := Rules.from_json(Rules.to_json(fresh({"target_scale": 0.5})))
	eq(half.dials.target_scale, 0.5, "a number that is not whole stays as it is")
	eq(Rules.from_json("not a run"), null, "text that is not a run gives nothing")
	eq(Rules.from_json("[1, 2]"), null, "nor does other JSON")
	# The run read back plays on like the first.
	var a := Rules.play(run, [run.hand[0]])
	var b := Rules.play(back, [back.hand[0]])
	eq(b, a, "the same play gives the same result")
	eq(back, run, "and the same run")


func test_numbers_that_cannot_be_used() -> void:
	var bad := {"restraint_limt": 3, "craving_cap": 0, "plays": -1, "hand_size": "ten", "max_play": 2.5, "target_scale": 0}
	var wrong := RulesDials.problems(bad)
	eq(wrong.size(), 6, "a misspelt name, a zero cap, a negative, a text, a fraction and a zero scale cannot be used")
	eq(RulesDials.problems({"target_scale": NAN, "plays": INF, "salt_price": -INF, "glee_chips": NAN}).size(), 4, "nor can a number that is not one, or is without end")
	eq(RulesDials.problems({"discards": 0, "craving_cap": 1, "target_scale": 2, "salt_start": 5.0}), {}, "these can")
	# One of them goes through make, which reports it as an error (printed below) and leaves it out.
	var d := RulesDials.make({"craving_cap": 0, "plays": 2})
	eq([d.craving_cap, d.plays], [3, 2], "a number that cannot be used keeps the game's own value")
	d = RulesDials.make({"discards": 0, "craving_cap": 1, "target_scale": 2, "salt_start": 5.0})
	eq([d.discards, d.craving_cap, d.target_scale, d.salt_start], [0, 1, 2.0, 5], "numbers that can be used are taken")
	# A cap of 1: every point of Craving rolls over at once.
	var run := as_hyde(at(fresh({"craving_cap": 1}, 3), 1, 0))
	var h := deal(run, "I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp P:heart")
	Rules.play(run, [h[0].id])
	eq([run.craving.lamp, run.habit.lamp], [0, 1], "a cap of 1 plays")


func test_whole_scale_survives_json() -> void:
	var run := fresh({"target_scale": 2.0}, 3)
	var back := Rules.from_json(Rules.to_json(run))
	eq(typeof(back.dials.target_scale), TYPE_FLOAT, "the scale is still a float")
	eq(back, run, "and the run comes back the same")
	run.night = 1
	eq(Rules.target(run), 6000, "night 2's first target, doubled")


func test_json_that_is_not_a_run() -> void:
	for text: String in [
		'{"cards":1,"dials":2}', '{"v":1,"cards":[],"dials":{}}', '{}', 'null', '3',
		'{"v":2,"dials":{},"cards":[],"draw":[],"hand":[],"discard":[],"instruments":[]}',
	]:
		eq(Rules.from_json(text), null, "refused: " + text)
	var data := fresh({}, 3).to_dict()
	var bad: Dictionary = data.duplicate(true)
	bad.cards[0] = {"id": 1, "t": "root", "sym": "spade", "ink": false}
	eq(Rules.from_json(JSON.stringify(bad)), null, "a card of no known symbol")
	bad = data.duplicate(true)
	bad.hand[0] = "one"
	eq(Rules.from_json(JSON.stringify(bad)), null, "a pile that holds something other than ids")
	bad = data.duplicate(true)
	bad.craving.erase("lamp")
	eq(Rules.from_json(JSON.stringify(bad)), null, "a gauge with a symbol missing")
	# A save from before a number existed takes the game's own value for it.
	var old: Dictionary = data.duplicate(true)
	old.dials.erase("salt_rise")
	var run := Rules.from_json(JSON.stringify(old))
	ok(run != null and run.dials.salt_rise == 1, "a number the save lacks keeps the game's own value")


func test_saves_that_cannot_be_played() -> void:
	var data := fresh({}, 3).to_dict()
	var changes := {
		"a night that does not exist": func(d: Dictionary) -> void: d.night = 7,
		"a round that does not exist": func(d: Dictionary) -> void: d.round = 3,
		"a negative number": func(d: Dictionary) -> void: d.salt = -1,
		"a phase that does not exist": func(d: Dictionary) -> void: d.phase = "shop",
		"a stance that does not exist": func(d: Dictionary) -> void: d.stance = "utterson",
		"a hand card that is not in the deck": func(d: Dictionary) -> void: d.hand[0] = 999,
		"a card in two piles": func(d: Dictionary) -> void: d.draw[0] = d.hand[0],
		"a card in no pile during a round": func(d: Dictionary) -> void: d.draw.pop_back(),
		"two cards with one id": func(d: Dictionary) -> void: d.cards[1].id = d.cards[0].id,
		"a card newer than the newest id": func(d: Dictionary) -> void: d.uid = 3,
		"an instrument that does not exist": func(d: Dictionary) -> void: d.instruments.append("wand"),
		"a negative gauge": func(d: Dictionary) -> void: d.habit.lamp = -1,
		"a laboratory with no shelf": func(d: Dictionary) -> void: d.phase = "lab",
		"an alley with no offers": func(d: Dictionary) -> void: d.phase = "alley",
		"a result with no round": func(d: Dictionary) -> void: d.phase = "result",
		"an offer of an unknown card": func(d: Dictionary) -> void: d.offer = ["joker"],
		"stats that are not a record": func(d: Dictionary) -> void: d.stats = 3,
	}
	for what: String in changes:
		var bad: Dictionary = data.duplicate(true)
		changes[what].call(bad)
		eq(Rules.from_json(JSON.stringify(bad)), null, "refused: " + what)
	ok(Rules.from_json(JSON.stringify(data)) != null, "the save they were made from loads")
	# What a run does not have is left out, and what a save lacks keeps its starting value.
	var odd: Dictionary = data.duplicate(true)
	odd["script"] = null
	odd["extra"] = 5
	odd.stats.erase("passes")
	odd.unlocked.erase("cane")
	var run := Rules.from_json(JSON.stringify(odd))
	ok(run != null and run.get_script() == RulesRun, "a save cannot take the run's script away")
	eq([run.stats.passes, run.unlocked.cane, run.night, run.hand], [0, false, 0, data.hand], "missing counts and locks start as in a new run")
	run.discards = 0
	deal(run, "I:lamp I:lamp I:heart")
	ok(Rules.pass_play(run).ok and run.stats.passes == 1, "and the run plays on")
	# Every phase of a whole run saves and loads.
	var seen := {}
	run = fresh({}, 33)
	var guard := 0
	while guard < 200:
		guard += 1
		seen[run.phase] = true
		var back := Rules.from_json(Rules.to_json(run))
		if back == null or not same(back, run):
			_fail("a run in the phase %s does not load back the same" % run.phase)
		match run.phase:
			"play":
				run.restraint = 0
				win_scene(run)
			"result":
				Rules.continue_result(run, 0)
			"lab":
				run.sov += 6
				Rules.buy_card(run, 0)
				Rules.buy_card(run, 1)
				Rules.leave_lab(run)
			"alley":
				Rules.alley_leave(run)
			"end":
				break
	eq(seen.size(), Rules.PHASES.size(), "a run saves and loads in every phase")
