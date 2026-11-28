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


# The 33 rows of the rules' score table: [state, the play, hand, chips, mult, score, what
# else the reading must say].
func _score_rows() -> Array:
	var hyde := {"stance": "hyde"}
	return [
		[{}, "P:lamp P:heart P:mirror F:cup F:lock", "Master the Self", 120, 7, 840, {"adds_restraint": false}],
		[{}, "P:lamp", "Kindle Virtue", 30, 2, 60, {"adds_restraint": true}],
		[{}, "P:lamp P:lamp", "Strengthen Conviction", 55, 2, 110, {"adds_restraint": true}],
		[{}, "P:lamp P:lamp P:heart", "Weave Harmony", 75, 3, 225, {}],
		[{}, "P:lamp P:lamp P:lamp P:heart", "Impose Order", 100, 3, 300, {}],
		[{}, "P:lamp P:lamp P:heart P:mirror", "Master the Self", 115, 5, 575, {}],
		[{}, "P:lamp P:heart P:mirror F:pen F:pen", "Master the Self", 120, 17, 2040, {"adds_restraint": true}],
		[{}, "P:lamp P:heart F:cup F:cup", "Weave Harmony", 80, 7, 560, {}],
		[{"temper": {"heart": 2}}, "P:lamp P:heart F:cane", "Weave Harmony", 145, 9, 1305, {}],
		[{"temper": {"lamp": 2, "heart": 2, "mirror": 2}}, "P:lamp P:heart P:mirror F:pen F:cane", "Master the Self", 255, 25, 6375, {}],
		[{"temper": {"lamp": 3}}, "P:lamp P:lamp P:lamp F:cane F:cane", "Impose Order", 360, 13, 4680, {}],
		[{}, "F:cup F:eye", "Guard the Veil", 10, 1, 10, {"adds_restraint": true, "draws": 1}],
		[{}, "F:lock", "Guard the Veil", 10, 1, 10, {"adds_restraint": false}],
		[{"craving": {"lamp": 2}}, "P:lamp I:lamp F:cup", "Tame the Other", 85, 10, 850, {"temper_gain": {"lamp": 2}, "adds_restraint": false}],
		[{}, "P:heart I:heart", "Tame the Other", 55, 4, 220, {"temper_gain": {"heart": 0}, "adds_restraint": false}],
		[{"temper": {"lamp": 2}, "craving": {"lamp": 1}, "habit": {"lamp": 1}}, "P:lamp I:lamp F:cane", "Tame the Other", 165, 12, 1980, {"temper_gain": {"lamp": 1}}],
		[{"inst": ["saucers"], "craving": {"lamp": 2}}, "P:lamp I:lamp I:lamp", "Tame the Other", 90, 10, 900, {"temper_gain": {"lamp": 2}}],
		[{"inst": ["saucers"], "craving": {"lamp": 2, "heart": 1}}, "P:lamp I:lamp P:heart I:heart F:cup", "Tame the Other", 125, 14, 1750, {"temper_gain": {"lamp": 2, "heart": 1}}],
		[{"stance": "hyde", "stored": 3}, "I:lamp I:lamp F:cup F:eye", "Stoke Compulsion", 110, 11, 1210, {"craving_on": {"lamp": 1}, "draws": 1, "spends_stored": true}],
		[hyde, "I:lamp", "Indulge Vice", 35, 3, 105, {"craving_on": {"lamp": 1}, "adds_restraint": false}],
		[hyde, "I:lamp I:heart", "Sow Discord", 55, 3, 165, {"craving_on": {"lamp": 1, "heart": 1}}],
		[hyde, "I:lamp I:heart I:mirror", "Unchain the Beast", 85, 4, 340, {"craving_on": {"lamp": 1, "heart": 1, "mirror": 1}}],
		[hyde, "I:lamp I:lamp I:heart", "Stoke Compulsion", 80, 5, 400, {"craving_on": {"lamp": 1, "heart": 1}}],
		[hyde, "I:lamp I:lamp I:heart I:mirror", "Stoke Compulsion", 95, 5, 475, {"craving_on": {"lamp": 1, "heart": 1, "mirror": 1}}],
		[{"stance": "hyde", "habit": {"lamp": 1}}, "I:lamp I:lamp I:lamp", "Spread Ruin", 150, 10, 1500, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "craving": {"lamp": 2}}, "I:lamp I:lamp", "Stoke Compulsion", 105, 5, 525, {"breeds": ["lamp"]}],
		[{"stance": "hyde", "habit": {"lamp": 2}}, "I:lamp I:lamp I:lamp I:lamp F:pen", "Spread Ruin", 250, 23, 5750, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "habit": {"lamp": 2}, "hunted": true}, "I:lamp I:lamp I:lamp I:lamp F:pen", "Spread Ruin", 250, 20, 5000, {"craving_on": {"lamp": 1}}],
		[{"stance": "hyde", "habit": {"heart": 1}}, "I:lamp I:heart F:cane", "Sow Discord", 110, 6, 660, {"craving_on": {"lamp": 1, "heart": 2}}],
		[{"stance": "hyde", "craving": {"lamp": 2}}, "I:lamp F:cane", "Indulge Vice", 100, 5, 500, {"craving_on": {"lamp": 2}, "breeds": ["lamp"]}],
		[hyde, "I:lamp I:heart F:cane F:lock", "Sow Discord", 90, 5, 450, {"craving_on": {}, "no_craving": true, "breeds": []}],
		[{"stance": "hyde", "inst": ["hcane"]}, "I:lamp I:lamp I:lamp", "Spread Ruin", 105, 11, 1155, {"craving_on": {"lamp": 1}}],
		[hyde, "F:cup F:eye", "Guard the Veil", 10, 1, 10, {"craving_on": {}, "no_craving": true, "draws": 1, "spends_stored": false}],
	]


func test_score_table() -> void:
	var rows := _score_rows()
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



# The steps of a reading as [kind, chips, mult], and the ids of the cards in its root and
# factor steps.
static func _shape(e: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in e.steps:
		out.append([s.kind, s.chips, s.mult])
	return out


func test_score_table_steps() -> void:
	var rows := _score_rows()
	for i in rows.size():
		var row: Array = rows[i]
		var cs := cards(row[1])
		var e := Rules.evaluate(_run_with(row[0]), cs)
		check_steps(e, ids(cs), "row %d (%s)" % [i + 1, row[1]])
	# Four plays written out, beat by beat.
	var e := Rules.evaluate(_run_with(rows[0][0]), cards(rows[0][1]))
	eq(_shape(e), [
		["base", 55, 5], ["root", 15, 0], ["root", 15, 0], ["root", 15, 0],
		["factor", 10, 0], ["effect", 0, 2], ["factor", 10, 0], ["effect", 0, 0],
	], "row 1: Master the Self, three Roots, Temperance and its mult, Truth and its lock")
	eq(e.steps.map(func(s: Dictionary) -> String: return s.sym), ["", "lamp", "heart", "mirror", "", "", "", ""], "row 1: Cloak, Quill, Cane")
	eq(e.steps[-1].label, "no restraint", "row 1: Truth's effect")
	e = Rules.evaluate(_run_with(rows[13][0]), cards(rows[13][1]))
	eq(_shape(e), [
		["base", 25, 2], ["root", 15, 0], ["root", 35, 0], ["gauge", 0, 6], ["factor", 10, 0], ["effect", 0, 2],
	], "row 14: Tame the Other, Piety, Corruption and its burst, Temperance")
	eq([e.steps[2].id, e.steps[3].id, e.steps[3].gauge], [e.turns[0], e.turns[0], "burst"], "row 14: the burst follows the Corruption")
	eq([e.steps[-1].chips_to, e.steps[-1].mult_to], [85, 10], "row 14: 85 x 10")
	e = Rules.evaluate(_run_with(rows[18][0]), cards(rows[18][1]))
	eq(_shape(e), [
		["base", 35, 5], ["root", 15, 0], ["root", 15, 0], ["factor", 10, 0], ["effect", 25, 0],
		["factor", 10, 0], ["effect", 0, 0], ["stored", 0, 2], ["stored", 0, 2], ["stored", 0, 2],
	], "row 19: Stoke Compulsion, two Corruption, Indulgence and its 25, Impulse and its draw, three stored drops")
	eq(e.steps[6].label, "draws 1 more", "row 19: Impulse's effect")
	e = Rules.evaluate(_run_with(rows[25][0]), cards(rows[25][1]))
	eq(_shape(e), [["base", 35, 5], ["root", 35, 0], ["root", 35, 0]], "row 26: Stoke Compulsion, two Corruption at 35")


func test_steps_of_gauges_and_factors() -> void:
	# Temper fires once a symbol, after the first Paper Root of it.
	var run := _run_with({"temper": {"lamp": 2, "heart": 1}})
	var cs := cards("P:heart P:lamp P:lamp F:pen")
	var e := Rules.evaluate(run, cs)
	eq(_shape(e), [
		["base", 30, 3], ["root", 45, 0], ["gauge", 0, 4], ["root", 45, 0], ["root", 30, 0], ["gauge", 0, 2],
		["factor", 10, 0], ["effect", 0, 2], ["effect", 0, 2],
	], "Temper after the first Cloak and the first Quill; Balance once a symbol")
	eq([e.steps[2].id, e.steps[5].id], [cs[1].id, cs[0].id], "Temper names the Root it follows")
	eq([e.steps[7].of, e.steps[8].of], [cs[1].id, cs[0].id], "Balance names the Roots it counts")
	# Habit fires after every Ink Root; Obsession counts the largest set; Surrender repeats the best.
	run = _run_with({"stance": "hyde", "habit": {"heart": 1}, "craving": {"lamp": 1}})
	cs = cards("I:heart I:lamp I:heart F:cane F:pen")
	e = Rules.evaluate(run, cs)
	eq(_shape(e), [
		["base", 35, 5], ["root", 25, 0], ["root", 30, 0], ["gauge", 0, 1], ["root", 30, 0], ["gauge", 0, 1],
		["factor", 10, 0], ["effect", 0, 2], ["effect", 0, 2],
		["factor", 10, 0], ["again", 30, 0], ["effect", 0, 2],
	], "Habit after each Quill, Obsession on the two Quills, Surrender repeats a Root")
	eq([e.steps[7].of, e.steps[8].of], [cs[0].id, cs[2].id], "Obsession names the Roots of the largest set")
	eq(e.steps[10].of, cs[0].id, "Surrender names the best Root: the first Quill, at 30")
	# Hunted: the base already carries the halved mult.
	e = Rules.evaluate(_run_with({"stance": "hyde", "hunted": true}), cards("I:lamp I:lamp I:lamp"))
	eq(e.steps[0].mult, 4, "hunted: the base mult is halved")
	# The Cane after stored restraint.
	e = Rules.evaluate(_run_with({"stance": "hyde", "stored": 1, "inst": ["hcane"]}), cards("I:lamp I:lamp I:lamp"))
	eq(_shape(e).slice(-2), [["stored", 0, 2], ["instrument", 0, 4]], "stored restraint, then The Cane")
	# With the Glass saucers, the second Corruption scores and bursts at 0 Craving.
	e = Rules.evaluate(_run_with({"inst": ["saucers"], "craving": {"lamp": 2}}), cards("P:lamp I:lamp I:lamp"))
	eq(_shape(e), [["base", 25, 2], ["root", 15, 0], ["root", 35, 0], ["gauge", 0, 6], ["root", 15, 0], ["gauge", 0, 2]], "two Corruption turn")
	# Guard the Veil: its base is one Factor's chips; no Factor adds more.
	cs = cards("F:cup F:eye")
	e = Rules.evaluate(_run_with({}), cs)
	eq(_shape(e), [["base", 10, 1], ["factor", 0, 0], ["factor", 0, 0], ["effect", 0, 0]], "Guard the Veil")
	# A refused play has no steps.
	eq(Rules.evaluate(_run_with({}), cards("I:lamp")).steps, [], "a refused play has no steps")

func test_plays_not_allowed() -> void:
	var saucers := {"inst": ["saucers"]}
	var rows := [
		[{"stance": "hyde"}, "P:lamp"],  # a Paper Root in Hyde's stance
		[{}, "I:lamp"],  # an Ink Root without its Paper twin
		[{}, "P:heart I:lamp"],  # the wrong twin
		[{}, "P:lamp I:lamp P:heart"],  # Tame the Other with a second Paper Root
		[{}, "P:lamp I:lamp F:cup F:eye"],  # Tame the Other with two Factors
		[{}, "P:lamp I:lamp I:lamp"],  # two Ink Roots without the saucers
		[saucers, "P:lamp I:lamp I:heart"],  # Madness has no Reason beside it
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
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.adds_restraint], ["Master the Self", 120, 7, 840, false], "night 1 Master the Self")
	as_hyde(run)
	run.stored = 3
	ev = Rules.evaluate(run, cards("I:lamp I:lamp F:cup F:eye"))
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.craving_on.lamp, ev.draws], ["Stoke Compulsion", 110, 11, 1210, 1, 1], "Hyde's first Stoke Compulsion")
	run.stance = "jekyll"
	run.stored = 0
	run.craving.lamp = 2
	ev = Rules.evaluate(run, cards("P:lamp I:lamp F:cup"))
	eq([ev.name, ev.chips, ev.mult, ev.score, ev.temper_gain.lamp, ev.adds_restraint], ["Tame the Other", 85, 10, 850, 2, false], "Tame the Other at 2 Craving")
	run.craving.lamp = 0
	run.temper = {"lamp": 2, "heart": 2, "mirror": 2}
	ev = Rules.evaluate(run, cards("P:lamp P:heart P:mirror F:pen F:cane"))
	eq([ev.name, ev.chips, ev.mult, ev.score], ["Master the Self", 255, 25, 6375], "late Master the Self")


func test_hand_types_and_precedence() -> void:
	var run := fresh()
	eq(_read(run, "P:lamp"), ["Kindle Virtue", 30, 2], "Kindle Virtue")
	eq(_read(run, "P:lamp P:lamp"), ["Strengthen Conviction", 55, 2], "Strengthen Conviction")
	eq(_read(run, "P:lamp P:heart"), ["Weave Harmony", 60, 3], "Weave Harmony")
	eq(_read(run, "P:lamp P:lamp P:lamp"), ["Impose Order", 85, 3], "Impose Order")
	eq(_read(run, "P:lamp P:heart P:mirror"), ["Master the Self", 100, 5], "Master the Self")
	eq(_read(run, "P:lamp P:lamp P:heart"), ["Weave Harmony", 75, 3], "A A B is Weave Harmony for Jekyll, all three Roots score")
	eq(_read(run, "P:lamp P:lamp P:lamp P:heart"), ["Impose Order", 100, 3], "A A A B is Impose Order")
	eq(_read(run, "P:lamp P:lamp P:heart P:mirror"), ["Master the Self", 115, 5], "A A B C is Master the Self")
	eq(_read(run, "P:lamp P:lamp P:lamp P:heart P:mirror"), ["Master the Self", 130, 5], "A A A B C is Master the Self, over Impose Order")
	eq(_read(run, "P:lamp P:lamp P:heart P:heart"), ["Weave Harmony", 90, 3], "A A B B is Weave Harmony, over Strengthen Conviction")
	eq(_read(run, "P:lamp P:lamp P:lamp P:lamp P:lamp"), ["Impose Order", 115, 3], "five alike is still Impose Order")
	eq(_read(run, "F:cup"), ["Guard the Veil", 10, 1], "Guard the Veil")
	eq(_read(run, "F:cup F:eye F:lock"), ["Guard the Veil", 10, 1], "Guard the Veil of three Factors scores one")
	as_hyde(run)
	eq(_read(run, "I:lamp"), ["Indulge Vice", 35, 3], "Indulge Vice")
	eq(_read(run, "I:lamp I:lamp"), ["Stoke Compulsion", 65, 5], "Stoke Compulsion")
	eq(_read(run, "I:lamp I:heart"), ["Sow Discord", 55, 3], "Sow Discord")
	eq(_read(run, "I:lamp I:lamp I:lamp"), ["Spread Ruin", 105, 7], "Spread Ruin")
	eq(_read(run, "I:lamp I:heart I:mirror"), ["Unchain the Beast", 85, 4], "Unchain the Beast")
	eq(_read(run, "I:lamp I:lamp I:heart"), ["Stoke Compulsion", 80, 5], "A A B is Stoke Compulsion for Hyde")
	eq(_read(run, "I:lamp I:lamp I:heart I:mirror"), ["Stoke Compulsion", 95, 5], "A A B C is Stoke Compulsion, not Unchain the Beast")
	eq(_read(run, "I:lamp I:lamp I:lamp I:heart I:mirror"), ["Spread Ruin", 135, 7], "A A A B C is Spread Ruin, over Stoke Compulsion and Unchain the Beast")
	eq(_read(run, "I:lamp I:lamp I:lamp I:lamp"), ["Spread Ruin", 120, 7], "four alike is Spread Ruin")
	eq(_read(run, "F:eye"), ["Guard the Veil", 10, 1], "Hyde's Guard the Veil")
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
	eq([e.chips, e.mult], [80, 7], "two Temperance stack: +4 mult")
	run.unlocked.pen = true
	run.unlocked.cane = true
	e = Rules.evaluate(run, cards("P:lamp P:heart P:mirror F:pen F:pen"))
	eq([e.chips, e.mult, e.score], [120, 17, 2040], "two Scales on Master the Self: +12 mult")
	e = Rules.evaluate(run, cards("P:lamp P:lamp P:lamp F:pen"))
	eq(e.mult, 5, "Balance on Impose Order counts one different Root")
	run.temper.heart = 2
	e = Rules.evaluate(run, cards("P:lamp P:heart F:cane"))
	eq([e.chips, e.mult], [30 + 15 + 45 + 10 + 45, 3 + 4 + 2], "Resolve scores the best Root again (Reason at Temper 2) and adds 2")
	e = Rules.evaluate(run, cards("P:lamp P:heart F:cane F:cane"))
	eq([e.chips, e.mult], [30 + 15 + 45 + 20 + 90, 3 + 4 + 4], "two Resolve: twice again, +4 mult")
	run.temper.heart = 0
	e = Rules.evaluate(run, cards("P:heart P:lamp P:mirror F:cane"))
	ok(e.parts.any(func(p: Dictionary) -> bool: return p.label == "Piety again"), "ties on chips go Cloak, Quill, Cane")
	eq(Rules.evaluate(run, cards("P:lamp F:lock")).adds_restraint, false, "Truth: no restraint")
	eq(Rules.evaluate(run, cards("F:lock")).adds_restraint, false, "Truth works in Guard the Veil")
	eq(Rules.evaluate(run, cards("F:cup")).adds_restraint, true, "Guard the Veil is a play")
	eq(Rules.evaluate(run, cards("F:eye F:eye")).draws, 2, "Patience works in Guard the Veil")
	as_hyde(run)
	e = Rules.evaluate(run, cards("I:lamp F:cup F:cup"))
	eq([e.chips, e.mult], [20 + 15 + 20 + 50, 3], "Indulgence adds 25 chips each")
	e = Rules.evaluate(run, cards("I:lamp I:lamp I:lamp I:lamp F:pen"))
	eq(e.mult, 7 + 8, "Obsession: 2 mult for each Root in the largest matching set")
	e = Rules.evaluate(run, cards("I:lamp I:lamp I:heart F:pen"))
	eq(e.mult, 5 + 4, "Obsession counts the largest set only")
	run.habit.heart = 1
	e = Rules.evaluate(run, cards("I:lamp I:heart F:cane"))
	eq([e.chips, e.mult, e.craving_on], [25 + 15 + 30 + 10 + 30, 3 + 1 + 2, {"lamp": 1, "heart": 2}], "Surrender: best Root again, +2 mult, 1 more Craving on it")
	e = Rules.evaluate(run, cards("I:lamp I:heart F:cane F:lock"))
	eq([e.craving_on, e.no_craving, e.breeds], [{}, true, []], "Deceit: no Craving at all")
	e = Rules.evaluate(run, cards("F:cup F:eye"))
	eq([e.score, e.spends_stored], [10, false], "no bonus in Guard the Veil")


func test_hunted() -> void:
	var run := as_hyde(at(fresh({}, 27), 1, 2))
	var mult := func(list: String) -> int: return Rules.evaluate(run, cards(list)).mult
	eq([mult.call("I:lamp"), mult.call("I:lamp I:lamp"), mult.call("I:lamp I:heart"), mult.call("I:lamp I:lamp I:lamp"), mult.call("I:lamp I:heart I:mirror")],
			[2, 3, 2, 4, 2], "hunted: 2 / 3 / 2 / 4 / 2")
	eq(Rules.evaluate(run, cards("I:lamp I:lamp I:heart I:mirror")).name, "Stoke Compulsion", "precedence is unchanged while hunted")
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
	eq([e.ok, e.chips, e.mult, e.temper_gain], [true, 25 + 15 + 35 + 15, 2 + 6 + 2, {"lamp": 2}], "two Corruption at 2 Craving: +6 then +2, Temper +2 once")
	eq(e.turns.size(), 2, "both turn")
	e = Rules.evaluate(run, cards("P:lamp I:lamp P:heart I:heart F:cup"))
	eq([e.ok, e.chips, e.mult, e.temper_gain], [true, 25 + 15 + 15 + 35 + 25 + 10, 2 + 6 + 4 + 2, {"lamp": 2, "heart": 1}], "two twin pairs and a Factor")
	ok(Rules.evaluate(run, cards("P:lamp P:lamp I:lamp I:lamp")).ok, "two pairs of one symbol")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:heart")).ok, "each of his needs its own twin")
	ok(not Rules.evaluate(run, cards("P:lamp P:heart I:lamp I:lamp")).ok, "no spare Paper Root")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:lamp I:lamp")).ok, "never three")
	ok(not Rules.evaluate(run, cards("P:lamp I:lamp I:lamp F:cup F:eye")).ok, "still one Factor")
	# The Ink Roots resolve Cloak before Quill before Cane, whatever the order of the play.
	var mixed := cards("I:heart P:heart I:lamp P:lamp")
	e = Rules.evaluate(run, mixed)
	eq(e.turns, [mixed[2].id, mixed[0].id], "Corruption resolves before Madness")


func test_reading_changes_nothing() -> void:
	var run := as_hyde(fresh({}, 4))
	run.stored = 2
	run.craving.lamp = 2
	var before := run.copy()
	Rules.evaluate(run, cards("I:lamp I:lamp F:cane"))
	Rules.best(run)
	eq(run, before, "evaluate and best leave the run and its generator alone")


# The best play found the plain way: every subset of the hand, the first of the highest.
func _best_by_every_subset(run: RulesRun) -> Dictionary:
	var hand: Array = run.hand.map(func(id: int) -> RulesCard: return Rules.card(run, id))
	var top := {}
	for m in range(1, 1 << hand.size()):
		var sel: Array = []
		for i in hand.size():
			if m & (1 << i):
				sel.append(hand[i])
		if sel.size() > run.dials.max_play:
			continue
		var ev := Rules.evaluate(run, sel)
		if not ev.ok:
			continue
		var key: float = int(ev.score) - sel.size() * 0.001
		if top.is_empty() or key > float(top.key):
			top = {"key": key, "ids": ids(sel)}
	return top


func test_best_matches_every_subset() -> void:
	var specs := ["P:lamp", "P:heart", "P:mirror", "I:lamp", "I:heart", "I:mirror", "F:cup", "F:eye", "F:lock", "F:pen", "F:cane"]
	var r := 12345
	for n in 60:
		var run := at(fresh({}, n), 1, n % 3)
		if n % 2 == 1:
			as_hyde(run)
		if n % 5 == 0:
			run.instruments.append("saucers")
		var list: Array = []
		for i in 4 + n % 8:
			r = (r * 1103515245 + 12345) & 0x7fffffff
			list.append(specs[r % specs.size()])
		for sym in RulesConfig.ROOTS:
			r = (r * 1103515245 + 12345) & 0x7fffffff
			run.craving[sym] = r % 3
			run.habit[sym] = (r >> 4) % 3
			run.temper[sym] = (r >> 8) % 3
		deal(run, " ".join(list))
		var want := _best_by_every_subset(run)
		var got := Rules.best(run)
		eq([got.get("ids"), got.get("key")], [want.get("ids"), want.get("key")], "hand %d (%s)" % [n, " ".join(list)])


func test_best_with_a_large_hand() -> void:
	var run := as_hyde(at(fresh({}, 1), 1, 0))
	deal(run, "I:lamp I:lamp I:lamp I:heart I:heart I:mirror P:lamp P:heart F:cup F:cup F:eye F:lock F:pen F:cane I:lamp I:heart I:mirror P:mirror P:lamp P:heart F:cup F:eye I:lamp I:mirror")
	eq(run.hand.size(), 24, "a hand of 24")
	var t0 := Time.get_ticks_msec()
	var b := Rules.best(run)
	var took := Time.get_ticks_msec() - t0
	eq([b.ev.name, b.ids.size()], ["Spread Ruin", 5], "its best play is found")
	ok(took < 500, "without reading every subset of the hand (%d ms)" % took)
	# More than seven of a kind in one play, if the numbers allow it.
	run = as_hyde(at(fresh({"max_play": 8, "hand_size": 9}, 1), 1, 0))
	deal(run, "I:heart I:lamp I:lamp I:lamp I:lamp I:lamp I:lamp I:lamp I:lamp")
	b = Rules.best(run)
	eq([b.ev.name, b.ids.size()], ["Spread Ruin", 9 - 1], "eight alike are not taken for one of another kind")
