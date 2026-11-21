extends "res://tests/case.gd"
## Dealing, discards, and what a play does to the gauges.


func test_dealing() -> void:
	var run := fresh({}, 2)
	eq([run.hand.size(), run.draw.size()], [8, 4], "a round deals 8")
	var h := deal(run, "P:lamp P:heart F:eye F:cup P:lamp P:heart P:mirror P:mirror")
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.hand.size(), run.discard.size(), run.plays], [8, 2, 3], "the hand refills to 8 after a play")
	ok(run.discard.has(h[0].id) and run.discard.has(h[1].id), "the played cards go to the discards")
	var r := Rules.discard(run, [run.hand[0], run.hand[1], run.hand[2]])
	eq([r.ok, run.hand.size(), run.discards, run.plays], [true, 8, 2, 3], "and after a discard, which uses a discard and no play")
	# 12 cards: 8 in hand, 5 thrown away, so the draw pile ran out and was rebuilt.
	eq(run.draw.size() + run.discard.size(), 4, "an empty draw pile is rebuilt from the discards")
	var all: Array = run.hand + run.draw + run.discard
	all.sort()
	eq(all, range(1, 13), "and every card is still in exactly one pile")
	# Curiosity draws one more after the refill.
	run = fresh({}, 2)
	h = deal(run, "P:lamp F:eye P:heart F:cup P:lamp P:heart P:mirror P:mirror")
	Rules.play(run, [h[0].id, h[1].id])
	eq(run.hand.size(), 9, "Curiosity: refill to 8, then 1 more")
	# A hand over 8 does not refill until it is under 8 again.
	run = fresh({}, 2)
	h = deal(run, "P:lamp P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror P:lamp P:heart")
	var pile: int = run.draw.size()
	Rules.play(run, [h[0].id])
	eq([run.hand.size(), run.draw.size()], [9, pile], "no refill while the hand is over 8")
	Rules.play(run, [h[1].id, h[3].id])
	eq([run.hand.size(), run.draw.size()], [8, pile - 1], "then it refills to 8")
	# Discards.
	run = fresh({}, 2)
	ok(not Rules.discard(run, []).ok, "a discard needs a card")
	ok(not Rules.discard(run, [999]).ok, "of the hand")
	ok(not Rules.discard(run, [run.hand[0], run.hand[0]]).ok, "each once")
	ok(not Rules.discard(run, run.hand.slice(0, 6)).ok, "five at most")
	eq(run.discards, 3, "a refused discard costs nothing")
	for i in 3:
		ok(Rules.discard(run, [run.hand[0]]).ok, "discard %d" % (i + 1))
	ok(not Rules.discard(run, [run.hand[0]]).ok, "three a round")
	run.instruments.append("spirit")
	Rules.start_round(run)
	eq(run.discards, 4, "the Spirit lamp gives one more")
	# Plays.
	ok(not Rules.play(run, []).ok and not Rules.play(run, [999]).ok and not Rules.play(run, [run.hand[0], run.hand[0]]).ok, "a play is cards of the hand, each once")
	eq(run.plays, 4, "a refused play costs nothing")


func test_empty_piles() -> void:
	var run := fresh({}, 3)
	# Nothing left to draw: the hand stays short.
	run.draw = []
	run.discard = []
	var h: Array = run.hand.duplicate()
	Rules.discard(run, [h[0]])
	eq(run.hand.size(), 8, "the thrown card is all there is, so it comes back")
	eq(Rules.draw_one(run), -1, "and then nothing is left to draw")


func test_craving_and_habit() -> void:
	var run := at(as_hyde(fresh()), 0, 2)
	push(run, "I:lamp")
	push(run, "I:lamp")
	Rules.start_round(run)
	var total: int = run.cards.size()
	var h := deal(run, "I:lamp I:lamp F:cup F:eye F:lock P:heart P:heart P:mirror")
	var r := Rules.play(run, ids(h.slice(0, 2)))
	eq([run.craving.lamp, run.habit.lamp, run.cards.size()], [1, 0, total], "one Fixation: 1 Craving")
	h = deal(run, "I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp P:lamp")
	Rules.play(run, ids(h.slice(0, 1)))
	eq([run.craving.lamp, run.habit.lamp], [2, 0], "second hand: 2 Craving")
	var e := Rules.evaluate(run, [h[1]])
	eq([e.chips, e.breeds], [20 + 15 + 20, ["lamp"]], "Craving is 10 chips a point on every card of that symbol, and the third breeds")
	run.plays = 3
	run.score = 0
	r = Rules.play(run, [h[1].id])
	eq([run.craving.lamp, run.habit.lamp, run.cards.size(), ink_n(run, "lamp")], [0, 1, total + 1, 3], "rollover: Craving wraps, Habit 1, one copy joins")
	ok(r.events.any(func(x: Dictionary) -> bool: return x.t == "breed" and x.sym == "lamp"), "the play reports the copy")
	var bred: Dictionary = run.cards[-1]
	ok(run.draw.has(bred.id) or run.hand.has(bred.id), "the copy went into the draw pile, from where the refill may draw it")
	e = Rules.evaluate(run, cards("I:lamp I:lamp I:lamp"))
	eq([e.chips, e.mult, e.score], [60 + 3 * 30, 7 + 3, 1500], "Habit: 15 chips and 1 mult on every card of that symbol")
	# Restlessness can push two points in one play.
	run.craving.lamp = 2
	run.plays = 2
	run.score = 0
	h = deal(run, "I:lamp F:cane P:heart P:heart P:mirror P:lamp P:lamp P:lamp")
	r = Rules.play(run, ids(h.slice(0, 2)))
	eq([r.ev.score, run.craving.lamp, run.habit.lamp], [(20 + 50 + 10 + 50) * (3 + 1 + 2), 1, 2], "2 + 2 Craving: one rollover, 1 left over")
	# Cunning holds the Craving still.
	run.plays = 2
	run.score = 0
	h = deal(run, "I:lamp F:lock P:heart P:heart P:mirror P:lamp P:lamp P:lamp")
	Rules.play(run, ids(h.slice(0, 2)))
	eq(run.craving.lamp, 1, "Cunning: Craving unchanged")


func test_rollover_scores_at_the_craving_it_found() -> void:
	var run := at(as_hyde(fresh({}, 5)), 0, 2)
	first_arrival(run)
	run.craving.lamp = 2
	eq([run.cards.size(), ink_n(run, "lamp")], [16, 2], "16 cards, 2 Fog")
	var h := deal(run, "I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp P:lamp")
	var r := Rules.play(run, ids(h.slice(0, 2)))
	eq([r.ev.name, r.ev.score, run.score], ["Fixation", 525, 525], "Fog, Fog at Craving 2 scores 525")
	eq([run.craving.lamp, run.habit.lamp, run.cards.size(), ink_n(run, "lamp"), run.stats.bred], [0, 1, 17, 3, 1], "then Craving 0, Habit 1, and the deck goes from 16 to 17 with 3 Fog")
	var bred: Dictionary = run.cards[-1]
	eq([bred.t, bred.sym, bred.ink], ["root", "lamp", true], "the copy is a Fog")
	ok(run.draw.has(bred.id) or run.hand.has(bred.id), "in the draw pile before the refill, so it can be drawn at once")
	# With the draw pile empty the copy is the first card of the refill.
	run = at(as_hyde(fresh({}, 5)), 0, 2)
	first_arrival(run)
	run.craving.lamp = 2
	h = deal(run, "I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp P:lamp")
	run.discard.append_array(run.draw)
	run.draw = []
	Rules.play(run, ids(h.slice(0, 2)))
	ok(run.hand.has(run.cards[-1].id), "the copy is drawn in the same refill")


func test_several_copies_in_one_play() -> void:
	var run := at(as_hyde(fresh({}, 6)), 1, 0)
	first_arrival(run)
	run.craving.lamp = 2
	var h := deal(run, "I:lamp F:cane F:cane F:cane P:heart P:heart P:mirror P:lamp")
	var e := Rules.evaluate(run, h.slice(0, 4))
	eq([e.craving_on, e.breeds], [{"lamp": 4}, ["lamp", "lamp"]], "2 Craving and 4 more: two copies")
	var n: int = run.cards.size()
	Rules.play(run, ids(h.slice(0, 4)))
	eq([run.craving.lamp, run.habit.lamp, run.cards.size() - n, ink_n(run, "lamp")], [0, 2, 2, 4], "a play that adds several points can breed more than one copy")
	# Row 30: Restlessness at Craving 2 leaves Craving 1, Habit 1.
	run = at(as_hyde(fresh({}, 6)), 1, 0)
	first_arrival(run)
	run.craving.lamp = 2
	h = deal(run, "I:lamp F:cane P:heart P:heart P:mirror P:lamp P:lamp P:heart")
	var r := Rules.play(run, ids(h.slice(0, 2)))
	eq([r.ev.name, r.ev.score, run.craving.lamp, run.habit.lamp, ink_n(run, "lamp")], ["Stirring", 500, 1, 1, 3], "Restlessness at Craving 2: Craving 1, Habit 1, a Fog joins")


func test_sublimation() -> void:
	var run := at(fresh(), 0, 2)
	first_arrival(run)
	run.hyde_arrived = true
	run.craving.lamp = 2
	run.restraint = 3
	var h := deal(run, "P:lamp I:lamp F:cup P:heart P:heart P:mirror P:lamp P:lamp")
	var before := Rules.line_info(run)
	eq([before.ink, before.paper], [4, 8], "4 against 8 before")
	var r := Rules.play(run, ids(h.slice(0, 3)))
	eq([run.temper.lamp, run.craving.lamp, run.restraint, h[1].ink], [2, 0, 3, false], "Sublimation: Temper +2, Craving 0, no restraint, the card is paper for good")
	eq([Rules.line_info(run).ink, Rules.line_info(run).paper], [3, 9], "one Root crosses the line: 3 against 9")
	eq(r.ev.score, 850, "and it scored the worked example")
	ok(r.events.any(func(x: Dictionary) -> bool: return x.t == "turn" and x.sym == "lamp" and x.gain == 2 and x.temper == 2), "the play reports the turn")
	eq(Rules.chips_of(run, h[0]), 45, "Temper is 15 chips on every Paper card of that symbol")
	var e := Rules.evaluate(run, cards("P:lamp P:lamp"))
	eq(e.mult, 2 + 4, "Temper mult counts once a symbol")
	e = Rules.evaluate(run, cards("P:lamp P:heart"))
	eq(e.mult, 3 + 4, "and only for symbols in the play")
	# At 0 Craving the card still turns, for 2 burst mult and no Temper.
	h = deal(run, "P:heart I:heart P:heart P:mirror P:lamp P:lamp F:eye F:lock")
	e = Rules.evaluate(run, [h[0], h[1]])
	eq([e.chips, e.mult, e.temper_gain.heart], [25 + 15 + 15, 2 + 2, 0], "Sublimation at 0 Craving")
	ok(not Rules.evaluate(run, [h[0], h[1], h[6], h[7]]).ok, "one Factor at most")
	ok(not Rules.evaluate(run, [h[0], h[1], h[2]]).ok, "one Paper Root only")
	ok(not Rules.evaluate(run, [h[0], h[1], h[3]]).ok, "no third Root")
	# Vigour scores the Paper Root again; Reason counts one different Root.
	run.unlocked.pen = true
	run.unlocked.cane = true
	run.craving.lamp = 1
	e = Rules.evaluate(run, cards("P:lamp I:lamp F:cane"))
	eq([e.chips, e.mult], [25 + 45 + 25 + 10 + 45, 2 + 4 + 4 + 2], "Sublimation with Vigour")
	e = Rules.evaluate(run, cards("P:lamp I:lamp F:pen"))
	eq(e.mult, 2 + 4 + 4 + 2, "Sublimation with Reason")
	# Curiosity draws in a Sublimation too.
	h = deal(run, "P:heart I:heart F:eye P:mirror P:lamp P:lamp P:heart F:lock")
	Rules.play(run, ids(h.slice(0, 3)))
	eq([run.hand.size(), h[1].ink, run.temper.heart, run.restraint], [9, false, 0, 3], "it turns, draws a card, and adds no Temper at 0 Craving")


func test_sublimation_with_saucers() -> void:
	var run := at(fresh(), 1, 0)
	run.hyde_arrived = true
	run.craving.lamp = 2
	run.craving.heart = 1
	run.instruments.append("saucers")
	var h := deal(run, "P:lamp I:lamp I:lamp P:heart P:heart P:mirror F:cup F:eye")
	var r := Rules.play(run, ids(h.slice(0, 3)))
	eq(r.ev.score, 900, "two Fog beside a Composure at Craving 2")
	eq([run.temper.lamp, run.craving.lamp, h[1].ink, h[2].ink, run.stats.turns], [2, 0, false, false, 2], "both turned, Temper +2")
	h = deal(run, "P:lamp I:lamp P:heart I:heart F:cup P:mirror P:mirror F:eye")
	run.craving.lamp = 2
	run.temper.lamp = 0
	r = Rules.play(run, ids(h.slice(0, 5)))
	eq([r.ev.score, run.temper.lamp, run.temper.heart, run.craving.lamp, run.craving.heart], [1750, 2, 1, 0, 0], "two twin pairs: each symbol's Craving becomes its Temper")


func test_passing_thought() -> void:
	var run := at(as_hyde(fresh({}, 7)), 0, 2)
	first_arrival(run)
	run.stored = 2
	run.craving.lamp = 1
	run.instruments.append("cheque")
	var h := deal(run, "F:cup F:eye I:lamp P:heart P:heart P:mirror P:lamp P:lamp")
	var r := Rules.play(run, [h[0].id, h[1].id])
	eq([r.ev.name, r.ev.score, run.score], ["Passing Thought", 10, 10], "one Factor's chips, times 1")
	eq([run.craving.lamp, run.stored, run.sov, run.restraint], [1, 2, 0, 0], "no Craving, the stored restraint is kept, and the Cheque book does not pay")
	eq(run.hand.size(), 9, "Impulse still draws")
	h = deal(run, "I:lamp F:cup P:heart P:heart P:mirror P:lamp P:lamp P:heart")
	Rules.play(run, [h[0].id])
	eq([run.stored, run.sov, run.craving.lamp], [0, 1, 2], "a Stirring spends the store, and the Cheque book pays 1")
	# As Jekyll it is a play like any other for restraint.
	run = at(fresh({}, 7), 0, 1)
	h = deal(run, "F:cup F:lock P:heart P:heart P:mirror P:lamp P:lamp P:heart")
	Rules.play(run, [h[0].id])
	eq(run.restraint, 1, "as Jekyll it adds 1 restraint")
	Rules.play(run, [h[1].id])
	eq(run.restraint, 1, "unless it holds Resolve")
