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
