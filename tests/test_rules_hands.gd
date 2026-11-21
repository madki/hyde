extends "res://tests/case.gd"
## Reading a play: which hand it is, its chips, mult and score, and plays that are not allowed.


# A run set up for one reading. `state` may hold: stance "hyde", craving / habit / temper
# (a number a symbol), stored, inst (instruments), hunted (night 2's scene).
func _run_with(state: Dictionary) -> RulesRun:
	var run := fresh()
	if state.get("stance", "jekyll") == "hyde":
		as_hyde(run)
	for gauge: String in ["craving", "habit", "temper"]:
		for sym: String in state.get(gauge, {}):
			run[gauge][sym] = state[gauge][sym]
	run.stored = state.get("stored", 0)
	run.instruments = state.get("inst", [])
	if state.get("hunted", false):
		run.night = 1
		run.round = 2
	return run


func _read(run: RulesRun, list: String) -> Array:
	var e := Rules.evaluate(run, cards(list))
	return [e.name, e.chips, e.mult]


func test_score_table() -> void:
	var hyde := {"stance": "hyde"}
	# [state, the play, hand, chips, mult, score, what else the reading must say]
	var rows := [
		[{}, "P:lamp P:heart P:mirror F:cup F:lock", "Lucid Mind", 120, 7, 840, {"adds_restraint": false}],
		[{}, "P:lamp", "Spark", 30, 2, 60, {"adds_restraint": true}],
		[{}, "P:lamp P:lamp", "Rumination", 55, 2, 110, {"adds_restraint": true}],
		[{}, "P:lamp P:lamp P:heart", "Good Work", 75, 3, 225, {}],
		[{}, "P:lamp P:lamp P:lamp P:heart", "Dogma", 100, 3, 300, {}],
		[{}, "P:lamp P:lamp P:heart P:mirror", "Lucid Mind", 115, 5, 575, {}],
		[{}, "P:lamp P:heart P:mirror F:pen F:pen", "Lucid Mind", 120, 17, 2040, {"adds_restraint": true}],
		[{}, "P:lamp P:heart F:cup F:cup", "Good Work", 80, 7, 560, {}],
		[{"temper": {"heart": 2}}, "P:lamp P:heart F:cane", "Good Work", 145, 9, 1305, {}],
		[{"temper": {"lamp": 2, "heart": 2, "mirror": 2}}, "P:lamp P:heart P:mirror F:pen F:cane", "Lucid Mind", 255, 25, 6375, {}],
		[{"temper": {"lamp": 3}}, "P:lamp P:lamp P:lamp F:cane F:cane", "Dogma", 360, 13, 4680, {}],
		[{}, "F:cup F:eye", "Passing Thought", 10, 1, 10, {"adds_restraint": true, "draws": 1}],
		[{}, "F:lock", "Passing Thought", 10, 1, 10, {"adds_restraint": false}],
		[{"craving": {"lamp": 2}}, "P:lamp I:lamp F:cup", "Sublimation", 85, 10, 850, {"temper_gain": {"lamp": 2}, "adds_restraint": false}],
		[{}, "P:heart I:heart", "Sublimation", 55, 4, 220, {"temper_gain": {"heart": 0}, "adds_restraint": false}],
		[{"temper": {"lamp": 2}, "craving": {"lamp": 1}, "habit": {"lamp": 1}}, "P:lamp I:lamp F:cane", "Sublimation", 165, 12, 1980, {"temper_gain": {"lamp": 1}}],
		[{"inst": ["saucers"], "craving": {"lamp": 2}}, "P:lamp I:lamp I:lamp", "Sublimation", 90, 10, 900, {"temper_gain": {"lamp": 2}}],
		[{"inst": ["saucers"], "craving": {"lamp": 2, "heart": 1}}, "P:lamp I:lamp P:heart I:heart F:cup", "Sublimation", 125, 14, 1750, {"temper_gain": {"lamp": 2, "heart": 1}}],
		[{"stance": "hyde", "stored": 3}, "I:lamp I:lamp F:cup F:eye", "Fixation", 110, 11, 1210, {"craving_on": {"lamp": 1}, "draws": 1, "spends_stored": true}],
		[hyde, "I:lamp", "Stirring", 35, 3, 105, {"craving_on": {"lamp": 1}, "adds_restraint": false}],
		[hyde, "I:lamp I:heart", "Lapse", 55, 3, 165, {"craving_on": {"lamp": 1, "heart": 1}}],
		[hyde, "I:lamp I:heart I:mirror", "Turmoil", 85, 4, 340, {"craving_on": {"lamp": 1, "heart": 1, "mirror": 1}}],
		[hyde, "I:lamp I:lamp I:heart", "Fixation", 80, 5, 400, {"craving_on": {"lamp": 1, "heart": 1}}],
		[hyde, "I:lamp I:lamp I:heart I:mirror", "Fixation", 95, 5, 475, {"craving_on": {"lamp": 1, "heart": 1, "mirror": 1}}],
		[{"stance": "hyde", "habit": {"lamp": 1}}, "I:lamp I:lamp I:lamp", "Mania", 150, 10, 1500, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "craving": {"lamp": 2}}, "I:lamp I:lamp", "Fixation", 105, 5, 525, {"breeds": ["lamp"]}],
		[{"stance": "hyde", "habit": {"lamp": 2}}, "I:lamp I:lamp I:lamp I:lamp F:pen", "Mania", 250, 23, 5750, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "habit": {"lamp": 2}, "hunted": true}, "I:lamp I:lamp I:lamp I:lamp F:pen", "Mania", 250, 20, 5000, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "habit": {"heart": 1}}, "I:lamp I:heart F:cane", "Lapse", 110, 6, 660, {"craving_on": {"lamp": 1, "heart": 2}}],
		[{"stance": "hyde", "craving": {"lamp": 2}}, "I:lamp F:cane", "Stirring", 100, 5, 500, {"craving_on": {"lamp": 2}, "breeds": ["lamp"]}],
		[hyde, "I:lamp I:heart F:cane F:lock", "Lapse", 90, 5, 450, {"craving_on": {}, "no_craving": true, "breeds": []}],
		[{"stance": "hyde", "inst": ["hcane"]}, "I:lamp I:lamp I:lamp", "Mania", 105, 11, 1155, {"craving_on": {"lamp": 1}}],
		[hyde, "F:cup F:eye", "Passing Thought", 10, 1, 10, {"craving_on": {}, "no_craving": true, "draws": 1, "spends_stored": false}],
	]
	eq(rows.size(), 33, "33 rows")
	for i in rows.size():
		var row: Array = rows[i]
		var run := _run_with(row[0])
		var e := Rules.evaluate(run, cards(row[1]))
		var label := "row %d (%s)" % [i + 1, row[1]]
		ok(e.ok, label + " is allowed")
		eq([e.name, e.chips, e.mult, e.score], [row[2], row[3], row[4], row[5]], label)
		for k: String in row[6]:
			eq(e[k], row[6][k], "%s: %s" % [label, k])
		var chips := 0
		for p: Dictionary in e.parts:
			chips += int(p.v)
		var mult := 0
		for p: Dictionary in e.mult_parts:
			mult += int(p.v)
		eq([chips, mult], [e.chips, e.mult], label + ": the parts add up")


func test_plays_not_allowed() -> void:
	var saucers := {"inst": ["saucers"]}
	var rows := [
		[{"stance": "hyde"}, "P:lamp"],  # a Paper Root in Hyde's stance
		[{}, "I:lamp"],  # an Ink Root without its Paper twin
		[{}, "P:heart I:lamp"],  # the wrong twin
		[{}, "P:lamp I:lamp P:heart"],  # a Sublimation with a second Paper Root
		[{}, "P:lamp I:lamp F:cup F:eye"],  # a Sublimation with two Factors
		[{}, "P:lamp I:lamp I:lamp"],  # two Ink Roots without the saucers
		[saucers, "P:lamp I:lamp I:heart"],  # Appetite has no Kindness beside it
	]
	for row: Array in rows:
		var e := Rules.evaluate(_run_with(row[0]), cards(row[1]))
		ok(not e.ok, row[1] + " is refused")
		ok(e.reason != "", row[1] + " is refused with a reason")
		eq([e.score, e.name], [0, ""], row[1] + " scores nothing")
	var run := fresh()
	ok(not Rules.evaluate(run, []).ok and Rules.evaluate(run, []).reason != "", "no cards")
	ok(not Rules.evaluate(run, cards("P:lamp P:lamp P:lamp P:heart P:heart P:heart")).ok, "six cards")


func test_worked_examples() -> void:
	var run := fresh()
	var ev := Rules.evaluate(run, cards("P:lamp P:heart P:mirror F:cup F:lock"))
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.adds_restraint], ["Lucid Mind", 120, 7, 840, false], "night 1 Lucid Mind")
	as_hyde(run)
	run.stored = 3
	ev = Rules.evaluate(run, cards("I:lamp I:lamp F:cup F:eye"))
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.craving_on.lamp, ev.draws], ["Fixation", 110, 11, 1210, 1, 1], "Hyde's first Fixation")
	run.stance = "jekyll"
	run.stored = 0
	run.craving.lamp = 2
	ev = Rules.evaluate(run, cards("P:lamp I:lamp F:cup"))
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.temper_gain.lamp, ev.adds_restraint], ["Sublimation", 85, 10, 850, 2, false], "Sublimation at 2 Craving")
	run.craving.lamp = 0
	run.temper = {"lamp": 2, "heart": 2, "mirror": 2}
	ev = Rules.evaluate(run, cards("P:lamp P:heart P:mirror F:pen F:cane"))
	eq([ev.name, ev.chips, ev.mult, ev.score], ["Lucid Mind", 255, 25, 6375], "late Lucid Mind")


func test_hand_types_and_precedence() -> void:
	var run := fresh()
	eq(_read(run, "P:lamp"), ["Spark", 30, 2], "Spark")
	eq(_read(run, "P:lamp P:lamp"), ["Rumination", 55, 2], "Rumination")
	eq(_read(run, "P:lamp P:heart"), ["Good Work", 60, 3], "Good Work")
	eq(_read(run, "P:lamp P:lamp P:lamp"), ["Dogma", 85, 3], "Dogma")
	eq(_read(run, "P:lamp P:heart P:mirror"), ["Lucid Mind", 100, 5], "Lucid Mind")
	eq(_read(run, "P:lamp P:lamp P:heart"), ["Good Work", 75, 3], "A A B is Good Work for Jekyll, all three Roots score")
	eq(_read(run, "P:lamp P:lamp P:lamp P:heart"), ["Dogma", 100, 3], "A A A B is Dogma")
	eq(_read(run, "P:lamp P:lamp P:heart P:mirror"), ["Lucid Mind", 115, 5], "A A B C is Lucid Mind")
	eq(_read(run, "P:lamp P:lamp P:lamp P:heart P:mirror"), ["Lucid Mind", 130, 5], "A A A B C is Lucid Mind, over Dogma")
	eq(_read(run, "P:lamp P:lamp P:heart P:heart"), ["Good Work", 90, 3], "A A B B is Good Work, over Rumination")
	eq(_read(run, "P:lamp P:lamp P:lamp P:lamp P:lamp"), ["Dogma", 115, 3], "five alike is still Dogma")
	eq(_read(run, "F:cup"), ["Passing Thought", 10, 1], "Passing Thought")
	eq(_read(run, "F:cup F:eye F:lock"), ["Passing Thought", 10, 1], "Passing Thought of three Factors scores one")
	as_hyde(run)
	eq(_read(run, "I:lamp"), ["Stirring", 35, 3], "Stirring")
	eq(_read(run, "I:lamp I:lamp"), ["Fixation", 65, 5], "Fixation")
	eq(_read(run, "I:lamp I:heart"), ["Lapse", 55, 3], "Lapse")
	eq(_read(run, "I:lamp I:lamp I:lamp"), ["Mania", 105, 7], "Mania")
	eq(_read(run, "I:lamp I:heart I:mirror"), ["Turmoil", 85, 4], "Turmoil")
	eq(_read(run, "I:lamp I:lamp I:heart"), ["Fixation", 80, 5], "A A B is Fixation for Hyde")
	eq(_read(run, "I:lamp I:lamp I:heart I:mirror"), ["Fixation", 95, 5], "A A B C is Fixation, not Turmoil")
	eq(_read(run, "I:lamp I:lamp I:lamp I:heart I:mirror"), ["Mania", 135, 7], "A A A B C is Mania, over Fixation and Turmoil")
	eq(_read(run, "I:lamp I:lamp I:lamp I:lamp"), ["Mania", 120, 7], "four alike is Mania")
	eq(_read(run, "F:eye"), ["Passing Thought", 10, 1], "Hyde's Passing Thought")
	# Every card in a hand scores its chips, and A A B marks both symbols.
	var e := Rules.evaluate(run, cards("I:lamp I:lamp I:heart"))
	eq(e.craving_on, {"lamp": 1, "heart": 1}, "Craving on each symbol present, once")
	eq(e.lit, {"lamp": true, "heart": true, "mirror": false}, "the symbols of the active Roots")
	ok(not Rules.evaluate(run, cards("P:lamp")).ok, "Hyde cannot play Jekyll's Roots")
	ok(not Rules.evaluate(run, cards("I:lamp P:lamp")).ok, "nor a mix")
	ok(not Rules.evaluate(run, []).ok and not Rules.evaluate(run, cards("I:lamp I:lamp I:lamp I:lamp I:lamp I:lamp")).ok, "one to five cards")
	run.stance = "jekyll"
	ok(not Rules.evaluate(run, cards("I:lamp")).ok, "Jekyll cannot play an Ink Root alone")
	ok(not Rules.evaluate(run, cards("I:lamp P:heart")).ok, "nor beside the wrong twin")
	ok(not Rules.evaluate(run, cards("I:lamp F:cup")).ok, "nor with only a Factor")


func test_common_factors() -> void:
	var run := fresh()
	var e := Rules.evaluate(run, cards("P:lamp P:heart F:cup F:cup"))
	eq([e.chips, e.mult], [80, 7], "two Good Cheer stack: +4 mult")
	run.unlocked.pen = true
	run.unlocked.cane = true
	e = Rules.evaluate(run, cards("P:lamp P:heart P:mirror F:pen F:pen"))
	eq([e.chips, e.mult, e.score], [120, 17, 2040], "two Reason on a Lucid Mind: +12 mult")
	e = Rules.evaluate(run, cards("P:lamp P:lamp P:lamp F:pen"))
	eq(e.mult, 5, "Reason on a Dogma counts one different Root")
	run.temper.heart = 2
	e = Rules.evaluate(run, cards("P:lamp P:heart F:cane"))
	eq([e.chips, e.mult], [30 + 15 + 45 + 10 + 45, 3 + 4 + 2], "Vigour scores the best Root again (Kindness at Temper 2) and adds 2")
	e = Rules.evaluate(run, cards("P:lamp P:heart F:cane F:cane"))
	eq([e.chips, e.mult], [30 + 15 + 45 + 20 + 90, 3 + 4 + 4], "two Vigour: twice again, +4 mult")
	run.temper.heart = 0
	e = Rules.evaluate(run, cards("P:heart P:lamp P:mirror F:cane"))
	ok(e.parts.any(func(p: Dictionary) -> bool: return p.label == "Composure again"), "ties on chips go Lamp, Heart, Mirror")
	eq(Rules.evaluate(run, cards("P:lamp F:lock")).adds_restraint, false, "Resolve: no restraint")
	eq(Rules.evaluate(run, cards("F:lock")).adds_restraint, false, "Resolve works in a Passing Thought")
	eq(Rules.evaluate(run, cards("F:cup")).adds_restraint, true, "a Passing Thought is a play")
	eq(Rules.evaluate(run, cards("F:eye F:eye")).draws, 2, "Curiosity works in a Passing Thought")
	as_hyde(run)
	e = Rules.evaluate(run, cards("I:lamp F:cup F:cup"))
	eq([e.chips, e.mult], [20 + 15 + 20 + 50, 3], "Glee adds 25 chips each")
	e = Rules.evaluate(run, cards("I:lamp I:lamp I:lamp I:lamp F:pen"))
	eq(e.mult, 7 + 8, "Alibi: 2 mult for each Root in the largest matching set")
	e = Rules.evaluate(run, cards("I:lamp I:lamp I:heart F:pen"))
	eq(e.mult, 5 + 4, "Alibi counts the largest set only")
	run.habit.heart = 1
	e = Rules.evaluate(run, cards("I:lamp I:heart F:cane"))
	eq([e.chips, e.mult, e.craving_on], [25 + 15 + 30 + 10 + 30, 3 + 1 + 2, {"lamp": 1, "heart": 2}], "Restlessness: best Root again, +2 mult, 1 more Craving on it")
	e = Rules.evaluate(run, cards("I:lamp I:heart F:cane F:lock"))
	eq([e.craving_on, e.no_craving, e.breeds], [{}, true, []], "Cunning: no Craving at all")
	e = Rules.evaluate(run, cards("F:cup F:eye"))
	eq([e.score, e.spends_stored], [10, false], "no bonus in a Passing Thought")


func test_hunted() -> void:
	var run := as_hyde(at(fresh({}, 27), 1, 2))
	var mult := func(list: String) -> int: return Rules.evaluate(run, cards(list)).mult
	eq([mult.call("I:lamp"), mult.call("I:lamp I:lamp"), mult.call("I:lamp I:heart"), mult.call("I:lamp I:lamp I:lamp"), mult.call("I:lamp I:heart I:mirror")],
			[2, 3, 2, 4, 2], "hunted: 2 / 3 / 2 / 4 / 2")
	eq(Rules.evaluate(run, cards("I:lamp I:lamp I:heart I:mirror")).name, "Fixation", "precedence is unchanged while hunted")
	run.habit.lamp = 2
	run.stored = 1
	eq(mult.call("I:lamp I:lamp"), 3 + 4 + 2, "only the base is halved")
	run.round = 1
	eq(mult.call("I:lamp I:lamp"), 5 + 4 + 2, "and only in the scene")
	run.round = 2
	run.stance = "jekyll"
	eq(Rules.evaluate(run, cards("P:lamp P:heart P:mirror")).mult, 5, "Jekyll is not hunted")


func test_glass_saucers() -> void:
	var run := at(fresh(), 1, 0)
	run.hyde_arrived = true
	run.craving.lamp = 2
	run.craving.heart = 1
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:lamp")).ok, "two need the saucers")
	run.instruments.append("saucers")
	var e := Rules.evaluate(run, cards("P:lamp I:lamp I:lamp"))
	eq([e.ok, e.chips, e.mult, e.temper_gain], [true, 25 + 15 + 35 + 15, 2 + 6 + 2, {"lamp": 2}], "two Fog at 2 Craving: +6 then +2, Temper +2 once")
	eq(e.turns.size(), 2, "both turn")
	e = Rules.evaluate(run, cards("P:lamp I:lamp P:heart I:heart F:cup"))
	eq([e.ok, e.chips, e.mult, e.temper_gain], [true, 25 + 15 + 15 + 35 + 25 + 10, 2 + 6 + 4 + 2, {"lamp": 2, "heart": 1}], "two twin pairs and a Factor")
	ok(Rules.evaluate(run, cards("P:lamp P:lamp I:lamp I:lamp")).ok, "two pairs of one symbol")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:heart")).ok, "each of his needs its own twin")
	ok(not Rules.evaluate(run, cards("P:lamp P:heart I:lamp I:lamp")).ok, "no spare Paper Root")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:lamp I:lamp")).ok, "never three")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:lamp F:cup F:eye")).ok, "still one Factor")
	# The Ink Roots resolve Lamp before Heart before Mirror, whatever the order of the play.
	var mixed := cards("I:heart P:heart I:lamp P:lamp")
	e = Rules.evaluate(run, mixed)
	eq(e.turns, [mixed[2].id, mixed[0].id], "Fog resolves before Appetite")


func test_reading_changes_nothing() -> void:
	var run := as_hyde(fresh({}, 4))
	run.stored = 2
	run.craving.lamp = 2
	var before := run.copy()
	Rules.evaluate(run, cards("I:lamp I:lamp F:cane"))
	Rules.best(run)
	eq(run, before, "evaluate and best leave the run and its generator alone")
