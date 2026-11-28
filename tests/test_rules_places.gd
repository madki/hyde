extends "res://tests/case.gd"
## What a dawn's place offers: RulesView.place, against the rules' own buying functions.

const Golden := preload("res://tests/golden.gd")


# Dawn 1 in the laboratory: two Madness joined and the Scale unlocked.
func _lab(sov: int = 40) -> RulesRun:
	var run := at(fresh({}, 22), 0, 2)
	win_scene(run)
	Rules.continue_result(run)
	run.sov = sov
	return run


# Dawn 1 in the back alley, after his first arrival.
func _alley(sov: int = 20) -> RulesRun:
	var run := at(fresh({}, 23), 0, 2)
	run.restraint = 2
	Rules.drink(run)
	win_scene(run)
	Rules.continue_result(run)
	run.sov = sov
	return run


# Every offer of the record with the move that takes it, as [name, offer, move].
func _offers(p: Dictionary) -> Array:
	var out: Array = []
	if p.where == "lab":
		out.append(["salt", p.salt, func(r: RulesRun) -> Dictionary: return Rules.buy_salt(r)])
		for o: Dictionary in p.cards:
			out.append(["card %d" % o.index, o, func(r: RulesRun) -> Dictionary: return Rules.buy_card(r, o.index)])
		for o: Dictionary in p.instruments:
			out.append(["instrument %d" % o.index, o, func(r: RulesRun) -> Dictionary: return Rules.buy_instrument(r, o.index)])
		for o: Dictionary in p.strike:
			out.append(["strike %d" % o.id, o, func(r: RulesRun) -> Dictionary: return Rules.strike(r, o.id)])
	else:
		out.append(["salt", p.salt, func(r: RulesRun) -> Dictionary: return Rules.alley_salt(r)])
		for o: Dictionary in p.habit:
			out.append(["habit " + o.sym, o, func(r: RulesRun) -> Dictionary: return Rules.alley_habit(r, o.sym)])
		for o: Dictionary in p.instruments:
			out.append(["instrument " + o.key, o, func(r: RulesRun) -> Dictionary: return Rules.alley_instrument(r, o.key)])
	return out


# Reads the place, takes every offer on a copy of the run, and checks that the rules answer
# what the record said they would. Returns the record.
func _agrees(run: RulesRun, label: String) -> Dictionary:
	var before := run.copy()
	var p: Dictionary = RulesView.place(run)
	checks += 1
	if not same(run, before):
		_fail(label + ": reading the place changed the run")
	for offer: Array in _offers(p):
		var o: Dictionary = offer[1]
		var res: Dictionary = offer[2].call(run.copy())
		checks += 1
		if res.ok != o.ok or res.get("reason", "") != o.why:
			_fail("%s, %s: the record says %s, the rules answer %s" % [label, offer[0], JSON.stringify([o.ok, o.why]), JSON.stringify([res.ok, res.get("reason", "")])])
		if o.ok != (o.why == ""):
			_fail("%s, %s: a refusal has a reason, and only a refusal" % [label, offer[0]])
	return p


func _oks(list: Array) -> Array:
	return list.map(func(o: Dictionary) -> bool: return o.ok)


func _whys(list: Array) -> Array:
	return list.map(func(o: Dictionary) -> String: return o.why)


func test_no_place_during_a_night() -> void:
	var run := at(fresh({}, 22), 0, 2)
	eq(RulesView.place(run), null, "a round being played")
	win_scene(run)
	eq([run.phase, RulesView.place(run)], ["result", null], "a round's result")
	run = fresh({}, 5)
	Rules.give_up(run)
	eq([run.phase, RulesView.place(run)], ["end", null], "a run that has ended")
	run = _lab()
	Rules.leave_lab(run)
	eq([run.phase, RulesView.place(run)], ["play", null], "after leaving")


func test_laboratory() -> void:
	var run := _lab()
	var p := _agrees(run, "the laboratory")
	eq([p.where, p.sov, p.night, p.has("habit"), p.has("taken")], ["lab", 40, {"no": 2, "title": "Search for Mr Hyde"}, false, false], "the laboratory, the purse and the night to come")
	eq(p.dawn, {"no": 1, "brings": "heart", "brings_name": "Madness", "unlocks": "pen", "unlocks_name": "Balance", "last": false}, "what dawn 1 brought")
	eq([p.held, p.slots, p.slots_free], [[], 3, 3], "no instruments yet")
	eq(p.salt, {"doses": 3, "price": 3, "ok": true, "why": ""}, "salt")
	# The shelf.
	eq(p.cards.map(func(o: Dictionary) -> Array: return [o.index, o.key, o.price, o.sold]),
			run.shop.cards.map(func(o: Dictionary) -> Array: return [run.shop.cards.find(o), o.key, o.price, false]), "the shelf's cards, in order")
	var pen: Dictionary = p.cards[2]
	eq([pen.key, pen.t, pen.name, pen.text, pen.ok], ["pen", "factor", "Balance", "Adds 2 mult for each different Paper Root in the play.", true], "Balance, and what it does")
	var root: Dictionary = p.cards[0]
	eq([root.t, root.name, root.text], ["root", RulesConfig.ROOT[root.key].paper, ""], "a Paper Root has a name and no text")
	eq(p.instruments.map(func(o: Dictionary) -> Array: return [o.index, o.key, o.name, o.price, o.sold, o.ok]),
			[0, 1].map(func(i: int) -> Array:
				var k: String = run.shop.instruments[i].key
				return [i, k, RulesConfig.INSTRUMENTS[k].name, RulesConfig.INSTRUMENTS[k].price, false, true]), "the shelf's instruments")
	# The deck, to strike from.
	eq(p.strike.map(func(o: Dictionary) -> int: return o.id), ids(run.cards), "every card of the deck, in its order")
	var ink: Dictionary = p.strike.filter(func(o: Dictionary) -> bool: return o.ink)[0]
	var paper: Dictionary = p.strike.filter(func(o: Dictionary) -> bool: return o.t == "root" and not o.ink)[0]
	var cup: Dictionary = p.strike.filter(func(o: Dictionary) -> bool: return o.key == "cup")[0]
	eq([ink.key, ink.t, ink.name, ink.text, ink.price], ["heart", "root", "Madness", "", 8], "his Root: 8")
	eq([paper.key, paper.name, paper.price], ["lamp", "Piety", 4], "a Paper Root: 4")
	eq([cup.t, cup.ink, cup.name, cup.text, cup.price], ["factor", false, "Temperance", "Adds 2 mult.", 4], "a Factor: 4, with what it does")
	ok(_oks(p.strike).all(func(x: bool) -> bool: return x), "all can be struck with 40 sovereigns")


func test_laboratory_refusals() -> void:
	# An empty purse.
	var run := _lab(0)
	var p := _agrees(run, "an empty purse")
	eq([p.salt.ok, p.salt.why, _whys(p.cards), _whys(p.instruments)],
			[false, "Not enough sovereigns.", ["Not enough sovereigns.", "Not enough sovereigns.", "Not enough sovereigns."], ["Not enough sovereigns.", "Not enough sovereigns."]], "nothing without the sovereigns")
	ok(p.strike.all(func(o: Dictionary) -> bool: return not o.ok and o.why == "Not enough sovereigns."), "nor a strike")
	# Between the two strike prices.
	run.sov = 5
	p = _agrees(run, "5 sovereigns")
	ok(p.strike.all(func(o: Dictionary) -> bool: return o.ok != o.ink), "5 sovereigns strike a Paper Root or a Factor, not a Root of his")
	eq([_oks(p.cards), p.salt.ok], [[true, true, true], true], "and buy a card or a dose")
	# A full rack.
	run = _lab()
	run.instruments = ["hcane", "cheque", "spirit"]
	p = _agrees(run, "a full rack")
	eq([p.slots_free, _whys(p.instruments)], [0, ["3 instruments held. Drop one first.", "3 instruments held. Drop one first."]], "a full rack: no instrument can be bought")
	eq(p.held.map(func(o: Dictionary) -> Array: return [o.key, o.name, o.text]),
			[["hcane", "The Cane", "Spread Ruin gains 4 mult when he plays it."], ["cheque", "Cheque book", "Each of his hands from Indulge Vice up pays 1 sovereign."], ["spirit", "Spirit lamp", "One more discard a round."]], "the instruments held, with what they do")
	Rules.drop_instrument(run, "hcane")
	p = _agrees(run, "one dropped")
	eq([p.slots_free, _oks(p.instruments), p.held.size()], [1, [true, true], 2], "one dropped: a slot is free")
	# Sold.
	run = _lab()
	Rules.buy_card(run, 1)
	Rules.buy_instrument(run, 0)
	p = _agrees(run, "after buying")
	eq([p.sov, p.cards.map(func(o: Dictionary) -> Array: return [o.sold, o.ok, o.why])], [40 - 3 - int(run.shop.instruments[0].price), [[false, true, ""], [true, false, "Sold."], [false, true, ""]]], "a card bought is sold")
	eq([p.instruments.map(func(o: Dictionary) -> Array: return [o.sold, o.ok, o.why]), p.held.map(func(o: Dictionary) -> String: return o.key), p.slots_free],
			[[[true, false, "Sold."], [false, true, ""]], [run.shop.instruments[0].key], 2], "an instrument bought is sold, and held")
	eq(p.strike[-1].key, run.shop.cards[1].key, "the card bought can be struck")
	# Salt, and a strike.
	var n: int = p.strike.size()
	Rules.buy_salt(run)
	Rules.strike(run, p.strike[0].id)
	var q := _agrees(run, "after salt and a strike")
	eq([q.salt.doses, q.salt.price, q.strike.size(), q.strike[0].id], [4, 4, n - 1, p.strike[1].id], "a dose bought raises the price, and a struck card is gone")


func test_back_alley() -> void:
	var run := _alley()
	var p := _agrees(run, "the back alley")
	eq([p.where, p.sov, p.night.no, p.dawn.brings_name, p.dawn.unlocks_name, p.has("cards"), p.has("strike")], ["alley", 20, 2, "Madness", "Balance", false, false], "the back alley")
	eq(p.salt, {"doses": 3, "price": 5, "ok": true, "why": ""}, "the street chemist's price")
	eq(p.habit.map(func(o: Dictionary) -> Array: return [o.sym, o.name, o.habit, o.adds, o.taken, o.ok]),
			[["lamp", "Corruption", 0, 1, false, true], ["heart", "Madness", 0, 1, false, true], ["mirror", "Brutality", 0, 1, false, true]], "a Habit on any Root of his")
	eq(p.instruments.map(func(o: Dictionary) -> Array: return [o.key, o.name, o.text, o.taken, o.ok]),
			[["hcane", "The Cane", "Spread Ruin gains 4 mult when he plays it.", false, true], ["cheque", "Cheque book", "Each of his hands from Indulge Vice up pays 1 sovereign.", false, true]], "his two instruments")
	eq(p.taken, {"habit": "", "instrument": ""}, "nothing taken yet")
	# The Habit, once.
	Rules.alley_habit(run, "heart")
	p = _agrees(run, "the Habit taken")
	eq([p.taken, p.habit.map(func(o: Dictionary) -> Array: return [o.habit, o.taken, o.ok, o.why])],
			[{"habit": "heart", "instrument": ""}, [[0, false, false, "Already taken."], [1, true, false, "Already taken."], [0, false, false, "Already taken."]]], "the Habit is taken, and the others are gone")
	eq(_oks(p.instruments), [true, true], "the instruments are still on offer")
	# The instrument, once.
	Rules.alley_instrument(run, "cheque")
	p = _agrees(run, "the instrument taken")
	eq([p.taken, p.instruments.map(func(o: Dictionary) -> Array: return [o.key, o.taken, o.ok, o.why])],
			[{"habit": "heart", "instrument": "cheque"}, [["hcane", false, false, "Already taken."], ["cheque", true, false, "Already taken."]]], "the instrument is taken, and the other is gone")
	eq([p.held.map(func(o: Dictionary) -> String: return o.key), p.slots_free], [["cheque"], 2], "and it is held")
	# Salt.
	Rules.alley_salt(run)
	p = _agrees(run, "a dose bought")
	eq([p.sov, p.salt.doses, p.salt.price], [15, 4, 6], "a dose bought raises the price")


func test_back_alley_refusals() -> void:
	# An empty purse: the free offers stay.
	var run := _alley(0)
	var p := _agrees(run, "an empty purse")
	eq([p.salt.ok, p.salt.why, _oks(p.habit), _oks(p.instruments)], [false, "Not enough sovereigns.", [true, true, true], [true, true]], "no salt without the sovereigns, and the rest is free")
	# A full rack.
	run.instruments = ["spirit", "notebook", "balance"]
	p = _agrees(run, "a full rack")
	eq([p.slots_free, _whys(p.instruments), p.taken.instrument], [0, ["3 instruments held. Drop one first.", "3 instruments held. Drop one first."], ""], "a full rack: no slot for his")
	Rules.drop_instrument(run, "notebook")
	p = _agrees(run, "one dropped")
	eq([p.slots_free, _oks(p.instruments)], [1, [true, true]], "one dropped: his instrument fits")
	# No Habit on a symbol he has no Root of.
	run = _alley()
	for c: RulesCard in run.cards:
		if c.is_ink() and c.sym == "mirror":
			c.ink = false
	p = _agrees(run, "no Brutality")
	eq(p.habit.map(func(o: Dictionary) -> String: return o.sym), ["lamp", "heart"], "no Habit is offered on a symbol with no Ink Root in the deck")
	eq(Rules.alley_habit(run.copy(), "mirror"), {"ok": false, "reason": "No Root of his with that symbol."}, "and the rules refuse it")
	# An instrument of his already held is not on offer.
	run = at(fresh({}, 23), 0, 2)
	run.instruments = ["hcane"]
	Rules.drink(run)
	win_scene(run)
	Rules.continue_result(run)
	p = _agrees(run, "The Cane held")
	eq([p.instruments.map(func(o: Dictionary) -> String: return o.key), p.held[0].key], [["cheque"], "hcane"], "an instrument of his already held is not offered again")


func test_refusals_read_as_sentences() -> void:
	var run := _lab()
	var seen := {}
	var note := func(res: Dictionary) -> void:
		if not res.ok:
			seen[res.reason] = true
	for sov: int in [0, 40]:
		for rack: Array in [[], ["hcane", "cheque", "spirit"]]:
			for place: RulesRun in [_lab(sov), _alley(sov)]:
				place.instruments = rack.duplicate()
				for after: int in 2:
					if after == 1 and place.phase == "lab":
						Rules.buy_card(place, 0)
						Rules.drop_instrument(place, "hcane")
						Rules.buy_instrument(place, 0)
					elif after == 1:
						Rules.alley_habit(place, "lamp")
						Rules.drop_instrument(place, "hcane")
						Rules.alley_instrument(place, place.alley.options[0] if not place.alley.options.is_empty() else "")
					for offer: Array in _offers(_agrees(place, "sov %d, %d held, %s" % [sov, rack.size(), place.phase])):
						if not offer[1].ok:
							seen[offer[1].why] = true
	# What a page cannot offer is refused in words too.
	note.call(Rules.buy_card(run, 9))
	note.call(Rules.strike(run, 9999))
	note.call(Rules.alley_habit(run, "lamp"))
	note.call(Rules.alley_instrument(_alley(), "spirit"))
	note.call(Rules.alley_habit(_alley(), "cup"))
	note.call(Rules.drop_instrument(run, "spirit"))
	for why: String in seen:
		ok(why.length() > 3 and why.length() <= 40 and why[0] == why[0].to_upper() and why.ends_with(".") and not why.contains("{") and not why.contains("_"), "a short plain sentence: " + why)
	ok(seen.size() >= 7, "the refusals were met: %s" % JSON.stringify(seen.keys()))


func test_texts_have_the_runs_numbers() -> void:
	var run := at(fresh({"balance_bonus": 2, "hcane_mult": 6, "cheer_mult": 3, "glee_chips": 25, "alley_habit": 2, "alley_markup": 4}, 22), 0, 2)
	win_scene(run)
	Rules.continue_result(run)
	run.instruments = ["balance", "hcane"]
	var p := _agrees(run, "changed numbers, the laboratory")
	eq(p.held.map(func(o: Dictionary) -> String: return o.text), ["Restraint holds 2 more.", "Spread Ruin gains 6 mult when he plays it."], "the instruments' texts")
	eq(p.strike.filter(func(o: Dictionary) -> bool: return o.key == "cup")[0].text, "Adds 3 mult.", "a Factor's text, in Jekyll's words")
	run = at(fresh({"balance_bonus": 2, "hcane_mult": 6, "cheer_mult": 3, "glee_chips": 25, "alley_habit": 2, "alley_markup": 4}, 23), 0, 2)
	Rules.drink(run)
	win_scene(run)
	Rules.continue_result(run)
	run.sov = 20
	p = _agrees(run, "changed numbers, the back alley")
	eq([p.instruments[0].text, p.habit[0].adds, p.salt.price], ["Spread Ruin gains 6 mult when he plays it.", 2, 7], "his instrument's text, the Habit and the price")
	Rules.alley_habit(run, "lamp")
	eq(RulesView.place(run).habit[0].habit, 2, "the Habit taken")
	for o: Dictionary in p.instruments + p.held:
		ok(not o.text.contains("{"), "no braces left in " + o.text)


func test_later_dawns() -> void:
	# Dawn 4 is the last, and brings nothing.
	var run := fresh({}, 25)
	for i in 4:
		push(run, "P:lamp")
	at(run, 3, 2)
	run.stance = "jekyll"
	run.stored = 0
	win_scene(run)
	Rules.continue_result(run)
	var p := _agrees(run, "dawn 4")
	eq([p.where, p.night, p.dawn], ["lab", {"no": 5, "title": "The Last Night"},
			{"no": 4, "brings": "", "brings_name": "", "unlocks": "", "unlocks_name": "", "last": true}], "dawn 4: nothing joins, and the last night comes")
	# A run saved before a dawn was recorded still has a place.
	run.dawn = null
	p = _agrees(run, "no dawn recorded")
	eq(p.dawn, {"no": 4, "brings": "", "brings_name": "", "unlocks": "", "unlocks_name": "", "last": true}, "a run with no dawn recorded")


func test_places_over_the_golden_runs() -> void:
	var places := {"lab": 0, "alley": 0}
	for record: Dictionary in Golden.runs():
		var run := Golden.begin(record)
		for i in record.moves.size():
			if run.phase == "lab" or run.phase == "alley":
				places[run.phase] += 1
				_agrees(run, "seed %d before move %d" % [record.seed, i])
			elif RulesView.place(run) != null:
				_fail("seed %d before move %d: a place during a night" % [record.seed, i])
			Golden.apply(run, record.moves[i])
	ok(places.lab > 20 and places.alley > 20, "both places were met: %s" % JSON.stringify(places))
