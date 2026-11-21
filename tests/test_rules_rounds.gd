extends "res://tests/case.gd"
## The rescue, the end of a round, pay, the line, the reward, and passing a play.


# Night 2, round 1 (target 3,000), he has arrived, Lamp Temper 1, one play left. The hand is
# two Kindness to play, and to hold: a Composure, a Scruple, a Cup, a Fog, an Appetite, an Eye.
func _rescue_table(prior: int) -> Array:
	var run := at(fresh({}, 16), 1, 0)
	run.hyde_arrived = true
	run.temper.lamp = 1
	first_arrival(run)
	run.plays = 1
	run.score = prior
	var h := deal(run, "P:heart P:heart P:lamp P:mirror F:cup I:lamp I:heart F:eye")
	return [run, h]


func test_rescue_plan() -> void:
	var t := _rescue_table(2000)
	var run: RulesRun = t[0]
	var h: Array = t[1]
	var ev := Rules.evaluate(run, [h[0], h[1]])
	eq(ev.score, 110, "Rumination 55 x 2")
	var before := run.copy()
	var plan := Rules.plan_rescue(run, 2000, 110, ids(h.slice(2)), false)
	# 2000 + 110 x 2^k >= 3000 needs k = 4, but only two Paper Roots are held.
	eq([plan.k, plan.pool, plan.ok, plan.score], [2, 2, false, 2440], "only held Paper Roots count: Factors and his Roots are ignored")
	plan = Rules.plan_rescue(run, 2800, 110, ids(h.slice(2)), false)
	eq([plan.k, plan.score, plan.ok, Rules.card(run, plan.ids[0]).sym, plan.factor], [1, 3020, true, "mirror", 2], "lowest Temper first: the Scruple before the tempered Composure")
	eq([plan.ink, plan.paper, plan.over], [5, 7, false], "the line as it would stand: 5 to 7")
	plan = Rules.plan_rescue(run, 2700, 110, ids(h.slice(2)), false)
	eq([plan.k, plan.score, plan.ok, plan.ids], [2, 2700 + 440, true, [h[3].id, h[2].id]], "x2 for each card, on the last play only")
	eq([plan.ink, plan.paper, plan.over], [6, 6, false], "6 to 6, and the tie holds")
	eq(run, before, "working it out changes nothing")


func test_rescue_three_priors() -> void:
	# Prior 2,800: he converts the Scruple.
	var t := _rescue_table(2800)
	var run: RulesRun = t[0]
	var h: Array = t[1]
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.phase, run.last.how, run.score, run.last.rescue.k, ink_n(run), paper_n(run)], ["result", "rescued", 3020, 1, 5, 7], "prior 2,800: 3,020, rescued at 5 to 7")
	eq([h[3].ink, h[2].ink], [true, false], "the Scruple is his, the Composure is not")
	# Prior 2,700: the Scruple, then the Composure.
	t = _rescue_table(2700)
	run = t[0]
	h = t[1]
	var before := Rules.line_info(run)
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.phase, run.last.how, run.score, run.stance, run.restraint, run.sov, run.offer], ["result", "rescued", 2700 + 440, "hyde", 0, 0, null], "rescued: his stance, no pay, no card")
	eq([Rules.line_info(run).ink, Rules.line_info(run).paper], [before.ink + 2, before.paper - 2], "two Paper Roots became his")
	eq([ink_n(run), paper_n(run)], [6, 6], "6 to 6, and the tie holds")
	eq([run.stats.rescues, run.stats.converted, run.last.rescue.k], [1, 2, 2], "counted")
	ok(h[2].ink and h[3].ink, "the held Composure and Scruple are ink now")
	eq(run.last.rescue.names, [["Scruple", "Pride"], ["Composure", "Fog"]], "in that order")
	# Prior 2,000: both are converted and 2,440 is still short.
	t = _rescue_table(2000)
	run = t[0]
	h = t[1]
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.phase, run.last.how, run.last.reason, run.score, run.ending, run.ended_by], ["end", "lost", "short", 2440, "hyde", "short"], "prior 2,000: 2,440 is short and the run ends")
	ok(h[2].ink and h[3].ink, "both were converted all the same")


func test_rescue_as_first_arrival() -> void:
	# The rescue as his first arrival; the line check after it; a round he cannot cover.
	var run := at(fresh({}, 17), 0, 0)  # target 1,000, he has not arrived
	run.plays = 1
	run.score = 900
	run.restraint = 2
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])  # Spark 30 x 2 = 60: 960 is short; one card makes 900 + 120
	eq([run.last.how, run.last.first, run.last.rescue.k, ink_n(run), paper_n(run), run.phase, run.score], ["rescued", true, 1, 5, 7, "result", 1020], "first arrival by rescue: his four join as well")
	eq([run.stance, run.restraint, run.stored, run.hyde_arrived, run.last.was], ["hyde", 0, 0, true, "jekyll"], "his stance, restraint 0, nothing stored")
	ok(h[4].ink != h[5].ink and not h[1].ink and not h[3].ink, "one Composure is converted, and nothing else")
	run = at(fresh({}, 17), 0, 0)
	run.plays = 1
	run.score = 700
	h = deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])  # 700 + 60 x 8 = 1,180 with three cards: 7 ink to 5 paper
	eq([run.last.how, run.last.rescue.k, run.score, ink_n(run), paper_n(run), run.phase, run.ending, run.ended_by], ["rescued", 3, 1180, 7, 5, "end", "hyde", "line"], "covered, but the converted Roots put him over the line")
	run = at(fresh({}, 17), 0, 0)
	run.plays = 1
	run.score = 0
	h = deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])  # 60 x 32 = 1,920 needs 5, and 5 are held
	eq([run.last.how, run.last.rescue.k, run.score], ["rescued", 5, 1920], "five cards cover it")
	eq([run.phase, run.ended_by], ["end", "line"], "and lose it at the line")
	run = at(fresh({}, 17), 0, 0)
	run.plays = 1
	run.score = 0
	h = deal(run, "P:lamp F:cup F:cup F:eye F:lock P:heart P:heart P:mirror")
	Rules.play(run, [h[0].id])  # three held: 60 x 8 = 480
	eq([run.phase, run.last.how, run.last.reason, run.ending, run.ended_by, run.score], ["end", "lost", "short", "hyde", "short", 480], "all held Roots converted and still short: the run ends")
	eq(run.hyde_arrived, false, "a rescue that fails is not an arrival")


func test_rescue_pool_is_what_was_held() -> void:
	# Cards drawn after the last play do not count: only Factors are held here.
	var run := at(fresh({}, 18), 0, 0)
	run.plays = 1
	run.score = 900
	var h := deal(run, "P:lamp F:cup F:cup F:eye F:lock")
	ok(run.draw.any(func(id: int) -> bool: return Rules.is_paper(Rules.card(run, id))), "the draw pile holds Paper Roots")
	Rules.play(run, [h[0].id])
	eq([run.phase, run.last.how, run.last.rescue.k, run.last.rescue.pool, run.score], ["end", "lost", 0, 0, 960], "no Paper Root was held, so nothing is converted")
	# Giving up ends the run.
	run = at(fresh({}, 18), 0, 1)
	eq(Rules.give_up(run).ok, true, "a run can be given up")
	eq([run.phase, run.ending, run.ended_by], ["end", "hyde", "gaveup"], "and ends as Mr Hyde")
	ok(not Rules.give_up(run).ok and not Rules.play(run, [1]).ok and not Rules.discard(run, [1]).ok and not Rules.drink(run).ok, "nothing more can be done")


func test_rescue_after_a_breakout() -> void:
	# A last play that fills the meter and falls short: he breaks out first, then the rescue
	# runs on what was held.
	var run := at(fresh({}, 19), 0, 1)  # target 1,500
	run.restraint = 4
	run.plays = 1
	run.score = 1300
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	var plan := Rules.plan_rescue(run, 1300, 60, ids(h.slice(1)), true)
	eq([plan.k, plan.ink, plan.paper, plan.over], [2, 2 + 4 + 2, 6, true], "the preview counts his arrival and the breakout")
	Rules.play(run, [h[0].id])
	eq([run.last.how, run.last.rescue.k, ink_n(run), paper_n(run), run.ended_by], ["rescued", 2, 8, 6, "line"], "breakout, then the rescue")
	eq(run.stats.breakouts, 1, "the breakout came first")


func test_rounds_pay_and_offers() -> void:
	var run := fresh({}, 20)
	var guard := 0
	while run.phase == "play" and guard < 8:
		guard += 1
		Rules.play(run, Rules.best(run).ids)
	eq([run.phase, run.last.how, run.last.stance], ["result", "won", "jekyll"], "best hands win round 1 as Jekyll")
	eq(run.last.pay, 3 + int(run.last.plays_left), "pay: 3 and 1 a play unused")
	eq(run.sov, run.last.pay, "paid in sovereigns")
	var offer: Array = run.offer
	ok(offer != null and offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "three different cards on offer")
	ok(offer.all(func(k: String) -> bool: return RulesConfig.ROOT.has(k) or ["cup", "eye", "lock"].has(k)), "Pen and Cane are not in the pool yet")
	ok(not Rules.play(run, [1]).ok and not Rules.drink(run).ok, "no play between rounds")
	var n: int = run.cards.size()
	var k: String = offer[0]
	Rules.continue_result(run, 0)
	eq([run.cards.size(), run.round, run.phase, run.offer], [n + 1, 1, "play", null], "the card is taken and round 2 begins")
	var got: RulesCard = run.cards[-1]
	ok((got.t == "root" and not got.ink and got.sym == k) if RulesConfig.ROOT.has(k) else (got.t == "factor" and got.kind == k), "it is the card offered, on paper")
	ok(run.hand.has(got.id) or run.draw.has(got.id), "and it is in the deck for the next deal")
	# The card can be left.
	run = fresh({}, 20)
	while run.phase == "play":
		Rules.play(run, Rules.best(run).ids)
	n = run.cards.size()
	Rules.continue_result(run)
	eq([run.cards.size(), run.round], [n, 1], "or none is taken")
	ok(not Rules.continue_result(run).ok, "there is no result to leave during a round")


func test_pay() -> void:
	# A scene won on its first play pays 3 + 3, and offers no card.
	var run := at(fresh({}, 22), 0, 2)
	win_scene(run)
	eq([run.phase, run.last.how, run.last.pay, run.last.plays_left, run.sov, run.offer], ["result", "won", 6, 3, 6, null], "scene won on its first play: 3 and 3 unused, no card")
	# Won on the last play: 3.
	run = at(fresh({}, 22), 0, 1)
	run.plays = 1
	win_scene(run)
	eq([run.last.pay, run.sov], [3, 3], "won on the last play: 3")
	ok(run.offer != null and run.offer.size() == 3, "an ordinary round won as Jekyll offers a card")
	# Won as Hyde: paid, no card.
	run = at(as_hyde(fresh({}, 22)), 0, 1)
	first_arrival(run)
	win_scene(run)
	eq([run.last.how, run.last.stance, run.last.pay, run.offer], ["won", "hyde", 6, null], "an ordinary round won as Hyde pays and offers no card")


func test_reward_pool() -> void:
	var first := {}
	var run := fresh({}, 1)
	for i in 3000:
		run.seed = i * 7919 + 1
		var offer := Rules._pick_offers(run, 3)
		ok(offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "three different cards")
		first[offer[0]] = int(first.get(offer[0], 0)) + 1
	eq(first.size(), 6, "the three Paper Roots and the three Factors there from the start")
	# Weights 3, 3, 3, 2, 2, 2 of 15: a Root 20% of the time, a Factor 13.3%.
	for k: String in first:
		var share: float = first[k] / 3000.0
		var want := 0.2 if RulesConfig.ROOT.has(k) else 2.0 / 15.0
		ok(absf(share - want) < 0.025, "%s comes first %.3f of the time, want about %.3f" % [k, share, want])
	run.unlocked.pen = true
	var seen := {}
	for i in 300:
		for k: String in Rules._pick_offers(run, 3):
			seen[k] = true
	ok(seen.has("pen") and not seen.has("cane"), "an unlocked Factor joins the pool, a locked one does not")
	eq(Rules._pick_offers(run, 99).size(), 7, "never more cards than the pool holds")


func test_the_line() -> void:
	# More Ink Roots than Paper Roots at the end of a round. A tie holds. Factors count for neither.
	var run := at(fresh({}, 21), 0, 1)
	run.hyde_arrived = true
	for i in 8:
		push(run, "I:lamp")
	Rules.start_round(run)
	eq([Rules.line_info(run).cushion, Rules.line_info(run).over], [0, false], "8 to 8 is not over")
	run.score = 1400
	var h := deal(run, "P:lamp P:heart P:mirror F:cup F:lock P:lamp P:heart P:mirror")
	Rules.play(run, ids(h.slice(0, 5)))
	eq([run.phase, run.last.how], ["result", "won"], "a tie survives the round")
	push(run, "I:lamp")
	Rules.continue_result(run)
	eq(Rules.line_info(run).over, true, "over the line during the scene")
	ok(run.phase == "play", "but the scene is played: the line is checked only at the end of a round")
	run.score = 2100
	h = deal(run, "P:lamp P:heart P:mirror F:cup F:lock P:lamp P:heart P:mirror")
	Rules.play(run, ids(h.slice(0, 5)))
	eq([run.phase, run.ending, run.ended_by, run.last.how], ["end", "hyde", "line", "won"], "won the scene and lost at the line")
	eq(run.history.size(), 2, "each round is kept in the run's history")


func test_passing_a_play() -> void:
	var run := as_hyde(at(fresh({}, 31), 0, 2))
	first_arrival(run)
	deal(run, "P:lamp P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror")
	eq([Rules.has_play(run), Rules.can_pass(run).ok], [false, false], "nothing of his in hand, but discards are left")
	ok(not Rules.pass_play(run).ok, "so the play cannot be passed yet")
	run.discards = 0
	ok(Rules.can_pass(run).ok, "no discards either: the play can be passed")
	var plays: int = run.plays
	var r := Rules.pass_play(run)
	eq([r.ok, run.plays, run.score, run.phase, run.restraint, run.stats.passes], [true, plays - 1, 0, "play", 0, 1], "it costs a play and scores nothing")
	var run2 := at(fresh({}, 31), 0, 1)
	run2.hyde_arrived = true
	deal(run2, "I:lamp I:lamp I:lamp I:heart I:heart I:heart I:mirror I:mirror")
	run2.discards = 0
	run2.restraint = 1
	ok(Rules.can_pass(run2).ok, "Jekyll with only his Roots in hand")
	Rules.pass_play(run2)
	eq(run2.restraint, 2, "a passed play adds restraint as Jekyll")
	var run3 := at(fresh({}, 31), 0, 1)
	deal(run3, "F:cup P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror")
	run3.discards = 0
	ok(not Rules.can_pass(run3).ok and not Rules.pass_play(run3).ok, "not while a card can be played")
	# A passed last play is rescued on the whole hand.
	var run4 := as_hyde(at(fresh({}, 31), 0, 1))
	first_arrival(run4)
	deal(run4, "P:lamp P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror")
	run4.discards = 0
	run4.plays = 1
	run4.score = 1499
	Rules.pass_play(run4)
	eq([run4.phase, run4.last.how, run4.last.rescue.k, run4.score], ["end", "lost", 8, 1499], "a pass scores 0, so no number of Roots can cover the round")
	# A passed play that fills the meter breaks out.
	var run5 := at(fresh({}, 31), 0, 1)
	run5.hyde_arrived = true
	deal(run5, "I:lamp I:lamp I:lamp I:heart I:heart I:heart I:mirror I:mirror")
	run5.discards = 0
	run5.restraint = 4
	Rules.pass_play(run5)
	eq([run5.stance, run5.restraint, run5.phase, run5.plays], ["hyde", 0, "play", 3], "a pass that fills the meter is a breakout")
