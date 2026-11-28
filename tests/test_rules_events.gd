extends "res://tests/case.gd"
## A move's events: which cards moved and what happened, in the order the rules did it.

const Golden := preload("res://tests/golden.gd")


# The piles and the deck as plain data: the piles' ids in order, and for each card of the
# deck whether it is ink.
static func _state(run: RulesRun) -> Dictionary:
	var deck := {}
	for c: RulesCard in run.cards:
		deck[c.id] = c.is_ink()
	return {"draw": run.draw.duplicate(), "hand": run.hand.duplicate(), "discard": run.discard.duplicate(), "deck": deck}


static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


# Plays a move's events back on the state before it. Returns "" when they all fit, or what
# did not.
static func _replay(s: Dictionary, events: Array) -> String:
	var draw: Array = s.draw
	var hand: Array = s.hand
	var discard: Array = s.discard
	var deck: Dictionary = s.deck
	for e: Dictionary in events:
		match e.t:
			"shuffle":
				if _sorted(e.ids) != _sorted(deck.keys()):
					return "the shuffle is not the whole deck"
				draw.assign(e.ids)
				hand.clear()
				discard.clear()
			"drawn":
				for id: int in e.ids:
					if draw.is_empty() or draw.back() != id:
						return "drawn %d is not on top of the draw pile" % id
					hand.append(draw.pop_back())
			"reshuffle":
				if not draw.is_empty() or _sorted(e.ids) != _sorted(discard):
					return "the reshuffle is not the discards onto an empty draw pile"
				draw.assign(e.ids)
				discard.clear()
			"discarded":
				for id: int in e.ids:
					if not hand.has(id):
						return "discarded %d is not in the hand" % id
					hand.erase(id)
					discard.append(id)
			"breed":
				deck[e.id] = true
				draw.insert(e.at, e.id)
			"joined":
				for c: Dictionary in e.cards:
					if deck.has(c.id):
						return "joined %d is already in the deck" % c.id
					deck[c.id] = e.why != "reward"
					if c.at >= 0:
						draw.insert(c.at, c.id)
			"stained":
				if deck.get(e.id) != false or not s[e.from].has(e.id):
					return "stained %d is not a Paper Root in the %s" % [e.id, e.from]
				deck[e.id] = true
			"brought":
				for c: Dictionary in e.cards:
					var pile: Array = s[c.from]
					if not pile.has(c.id):
						return "brought %d is not in the %s" % [c.id, c.from]
					pile.erase(c.id)
					hand.append(c.id)
			"converted":
				if deck.get(e.id) != false or not hand.has(e.id):
					return "converted %d is not a held Paper Root" % e.id
				deck[e.id] = true
			"turn":
				deck[e.id] = false
			"round_end":
				draw.clear()
				hand.clear()
				discard.clear()
	return ""


func test_golden_runs_replay_from_events() -> void:
	var moves := 0
	var seen := {}
	for i in Golden.runs().size():
		var record: Dictionary = Golden.runs()[i]
		var run := Golden.begin(record)
		for j in record.moves.size():
			var before := _state(run)
			var res := Golden.make(run, record.moves[j])
			if not res.ok or not res.has("events"):
				continue
			for e: Dictionary in res.events:
				var key: String = e.t
				if e.has("why"):
					key += " " + str(e.why)
				elif e.t == "round_end":
					key += " " + str(e.how)
				elif e.t == "shift" or e.t == "breakout":
					key += " " + str(e.ev.how)
				seen[key] = int(seen.get(key, 0)) + 1
				if e.t == "brought":
					for c: Dictionary in e.cards:
						seen["brought from " + str(c.from)] = true
			var why := _replay(before, res.events)
			moves += 1
			if why != "" or not same(before, _state(run)):
				_fail("run %d, move %d %s: %s" % [i, j + 1, JSON.stringify(record.moves[j]), why if why != "" else "the piles differ after the events"])
				checks += 1
				break
			checks += 1
	ok(moves > 4000, "%d moves played back from their events" % moves)
	for key: String in [
		"shuffle", "drawn deal", "drawn refill", "drawn draws", "reshuffle", "discarded play", "discarded discard",
		"breed", "joined first", "joined breakout", "joined reward", "stained", "brought from draw", "brought from discard",
		"converted", "turn", "shift drink", "shift salt", "shift window", "breakout breakout", "breakout walkedin",
		"round_end won", "round_end rescued", "round_end lost", "scored", "stored_spent", "craving", "restraint", "cheque", "joined dawn",
	]:
		ok(seen.has(key), "the golden runs hold the event '%s'" % key)


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e.t)


func test_draws_deal_refill_and_eye() -> void:
	var run := fresh({}, 3)
	run.round = 1
	var r := Rules.start_round(run)
	eq(_types(r.events), ["shuffle", "drawn"], "a round starts with the shuffle and the deal")
	eq([r.events[1].why, r.events[1].ids], ["deal", run.hand], "the deal's ids, in the order drawn")
	var h := deal(run, "P:lamp F:eye P:heart P:heart P:mirror P:mirror P:lamp F:cup")
	var top: Array = run.draw.slice(-3)
	top.reverse()
	r = Rules.play(run, [h[0].id, h[1].id])
	var drawn: Array = r.events.filter(func(e: Dictionary) -> bool: return e.t == "drawn")
	eq(drawn.map(func(e: Dictionary) -> Array: return [e.why, e.ids]), [["refill", top.slice(0, 2)], ["draws", top.slice(2)]], "two refill the hand, one more for the Patience")
	r = Rules.discard(run, run.hand.slice(0, 2))
	eq(_types(r.events), ["discarded", "drawn"], "a discard: the cards leave, one is drawn (the hand held 9)")
	eq(r.events[0].why, "discard", "and says so")


func test_reshuffle_among_the_draws() -> void:
	var run := fresh({}, 4)
	run.round = 1
	Rules.start_round(run)
	# Leave one card in the draw pile: the second draw turns the discards over.
	while run.draw.size() > 1:
		run.discard.append(run.draw.pop_back())
	var last: int = run.draw[0]
	var r := Rules.discard(run, run.hand.slice(0, 2))
	eq(_types(r.events), ["discarded", "drawn", "reshuffle", "drawn"], "one drawn, the discards reshuffled, one more drawn")
	eq(r.events[1].ids, [last], "the last card of the old pile first")
	eq(r.events[2].ids.size(), run.draw.size() + 1, "the reshuffle shows the new draw pile")
	eq(r.events[3].ids, [r.events[2].ids[-1]], "and the next card comes off its top")


func test_breed_reports_the_copy() -> void:
	var run := at(as_hyde(fresh({}, 5)), 0, 2)
	run.craving.lamp = 2
	var h := deal(run, "I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup")
	var r := Rules.play(run, ids(h.slice(0, 2)))
	var breed: Array = r.events.filter(func(e: Dictionary) -> bool: return e.t == "breed")
	eq(breed.size(), 1, "one copy")
	var copy := Rules.card(run, breed[0].id)
	ok(copy != null and copy.ink and copy.sym == "lamp", "the copy's id is a new Corruption")
	eq([breed[0].sym, breed[0].habit], ["lamp", 1], "its symbol and the new Habit")
	eq(_types(r.events).slice(0, 4), ["scored", "breed", "craving", "discarded"], "bred before the cards leave")


func test_his_first_four_and_a_breakouts_two() -> void:
	var run := fresh({}, 6)
	run.round = 1
	Rules.start_round(run)
	run.restraint = 3
	var r := Rules.drink(run)
	eq(_types(r.events), ["shift", "joined", "brought"], "a first drink: the shift, his four join, he brings two")
	var joined: Dictionary = r.events[1]
	eq([joined.why, joined.cards.size()], ["first", 4], "his first four")
	for c: Dictionary in joined.cards:
		ok(Rules.card(run, c.id).ink, "joined %d is one of his" % c.id)
	var brought: Array = r.events[2].cards
	eq(brought.map(func(c: Dictionary) -> int: return c.id), r.ev.brought, "the ids brought")
	ok(brought.all(func(c: Dictionary) -> bool: return c.from == "draw" or c.from == "discard"), "each with its pile")
	# A breakout: the shift, his two, and two brought.
	run = fresh({}, 7)
	run.round = 1
	run.restraint = 4
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	r = Rules.play(run, [h[0].id])
	eq(_types(r.events), ["scored", "restraint", "discarded", "drawn", "breakout", "joined", "joined", "brought"], "a breakout as his first arrival")
	eq([r.events[5].why, r.events[6].why, r.events[6].cards.size()], ["first", "breakout", 2], "his four, then the breakout's two")


func test_stained_and_added() -> void:
	var run := fresh({}, 8)
	run.round = 1
	Rules.start_round(run)
	Rules.drink(run)
	run.stance = "jekyll"
	var r := Rules.drink(run)
	eq(_types(r.events), ["shift", "stained", "brought"], "a later drink stains one")
	var st: Dictionary = r.events[1]
	eq([st.id, st.sym, st.from], [r.ev.stained.id, r.ev.stained.sym, r.ev.stained.from], "the stained card's id and pile")
	# With no Paper Root left, one of his joins.
	for c: RulesCard in run.cards:
		if c.is_root():
			c.ink = true
	run.stance = "jekyll"
	r = Rules.drink(run)
	eq(_types(r.events), ["shift", "joined", "brought"], "nothing to stain: one joins")
	eq([r.events[1].why, r.events[1].cards.size()], ["stain", 1], "in place of the stain")


func test_salt_and_the_window() -> void:
	var run := at(as_hyde(fresh({}, 9)), 1, 0)
	var r := Rules.take_salt(run)
	eq(_types(r.events), ["shift", "brought"], "salt: the shift, Jekyll brings two")
	eq(r.events[1].who, "jekyll", "Jekyll's")
	run = fresh({}, 10)
	run.hyde_arrived = true
	run.restraint = 2
	first_arrival(run)
	r = at_events(run, 3, 2)
	eq(_types(r.events), ["shuffle", "drawn", "shift", "brought"], "night 4's scene: the deal, the shift, two brought")
	eq([r.events[2].ev.how, r.events[2].ev.stored], ["window", 2], "stored, nothing stained")


static func at_events(run: RulesRun, night: int, round_no: int) -> Dictionary:
	run.night = night
	run.round = round_no
	return Rules.start_round(run)


func test_walking_in_full_reports_a_breakout() -> void:
	var run := fresh({}, 15)
	run.restraint = 5
	var r := at_events(run, 1, 1)
	eq(_types(r.events), ["shuffle", "drawn", "breakout", "joined", "joined", "brought"], "walking in full as his first arrival")
	eq(r.events[2].ev.how, "walkedin", "named")


func test_converted_in_order() -> void:
	var run := at(fresh({}, 16), 1, 0)
	run.hyde_arrived = true
	run.temper.lamp = 1
	first_arrival(run)
	run.plays = 1
	run.score = 2700
	var h := deal(run, "P:heart P:heart P:lamp P:mirror F:cup I:lamp I:heart F:eye")
	var r := Rules.play(run, [h[0].id, h[1].id])
	var tail: Array = _types(r.events).slice(-4)
	eq(tail, ["rescue", "converted", "converted", "round_end"], "the rescue, each Root, then the round's end")
	var conv: Array = r.events.filter(func(e: Dictionary) -> bool: return e.t == "converted")
	eq(conv.map(func(e: Dictionary) -> Array: return [e.id, e.score]), [[h[3].id, 2700 + 220], [h[2].id, 2700 + 440]], "the Composure, then the Piety, with the score after each")
	var end: Dictionary = r.events[-1]
	eq([end.how, end.ink, end.paper, end.over, end.pay, end.offers_card, end.was], ["rescued", 6, 6, false, 0, false, "jekyll"], "rescued at 6 to 6, no pay, no card")


func test_round_end() -> void:
	var run := fresh({}, 11)
	run.round = 1
	Rules.start_round(run)
	run.score = Rules.target(run) - 1
	var h := deal(run, "P:lamp F:lock P:heart P:mirror P:lamp P:heart F:cup F:eye")
	var r := Rules.play(run, [h[0].id, h[1].id])
	var end: Dictionary = r.events[-1]
	eq([end.t, end.how, end.pay, end.plays_left, end.offers_card, end.over], ["round_end", "won", 3 + 3, 3, true, false], "won: the pay, a card offered, the line holds")
	r = Rules.continue_result(run, 0)
	eq(_types(r.events), ["joined", "shuffle", "drawn"], "the card taken joins, and the next round is dealt")
	ok(r.events[1].ids.has(r.events[0].cards[0].id), "the new card is shuffled in")
	# A line that breaks.
	run = fresh({}, 12)
	run.round = 1
	Rules.start_round(run)
	run.hyde_arrived = true
	for i in 9:
		push(run, "I:lamp")
	run.score = Rules.target(run) - 1
	h = deal(run, "P:lamp F:lock P:heart P:mirror P:lamp P:heart F:cup F:eye")
	r = Rules.play(run, [h[0].id, h[1].id])
	eq([r.events[-1].how, r.events[-1].over, r.events[-1].ending, r.events[-1].ended_by], ["won", true, "hyde", "line"], "won, but the line is broken")


func test_events_are_not_saved() -> void:
	var run := fresh({}, 13)
	ok(not run.to_dict().has("events"), "a run saves without its events")
