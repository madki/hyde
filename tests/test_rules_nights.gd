extends "res://tests/case.gd"
## Dawn, the laboratory, the back alley, the scenes' twists, and the endings.


func test_dawn_1_in_the_laboratory() -> void:
	var run := at(fresh({}, 22), 0, 2)
	win_scene(run)
	eq([run.phase, run.last.how, run.sov], ["result", "won", 6], "scene won on its first play: 3 and 3 unused")
	Rules.continue_result(run)
	eq([ink_n(run), paper_n(run)], [2, 8], "before he has arrived: 2 Ink Roots to 8 Paper Roots")
	run.sov = 40
	eq([run.phase, run.dawn.no, run.dawn.brings, run.dawn.unlocks, ink_n(run, "heart"), run.unlocked.pen, run.hyde_arrived],
			["lab", 1, "heart", "pen", 2, true, false], "dawn 1: two Appetite join and the Pen unlocks; then the laboratory")
	eq([run.alley, run.dawn.as_hyde, run.dawn.last], [null, false, false], "no back alley for Jekyll")
	var sh: Dictionary = run.shop
	eq([sh.cards.size(), sh.cards[2].key, sh.cards.map(func(o: Dictionary) -> int: return o.price)], [3, "pen", [3, 3, 3]], "the shelf: two Paper Roots and Reason, 3 sovereigns each")
	ok(RulesConfig.ROOT.has(sh.cards[0].key) and RulesConfig.ROOT.has(sh.cards[1].key) and sh.cards[0].key != sh.cards[1].key, "two different Paper Roots")
	eq(sh.instruments.size(), 2, "two instruments on offer")
	ok(sh.instruments[0].key != sh.instruments[1].key and sh.instruments.all(func(o: Dictionary) -> bool:
		return RulesConfig.LAB_INSTRUMENTS.has(o.key) and o.price == RulesConfig.INSTRUMENTS[o.key].price), "two of the laboratory's four, at their prices")
	var n: int = run.cards.size()
	Rules.buy_card(run, 0)
	Rules.buy_card(run, 2)
	eq([run.cards.size(), run.sov, Rules.buy_card(run, 0).ok], [n + 2, 34, false], "one copy of each")
	eq([run.cards[-1].t, run.cards[-1].kind, Rules.is_paper(run.cards[-2])], ["factor", "pen", true], "a Reason and a Paper Root joined the deck")
	eq([Rules.salt_cost(run, "lab"), Rules.salt_cost(run, "alley")], [3, 5], "salt costs 3, and the alley would charge 5")
	eq([Rules.buy_salt(run).ok, Rules.salt_cost(run, "lab"), Rules.salt_cost(run, "alley"), run.salt, run.sov], [true, 4, 6, 4, 31], "then 4 and 6 after one dose")
	Rules.buy_salt(run)
	eq([run.sov, Rules.salt_cost(run, "lab"), Rules.salt_cost(run, "alley")], [27, 5, 7], "and 1 more each time")
	var fog: RulesCard = run.cards.filter(Rules.is_ink)[0]
	var comp: RulesCard = run.cards.filter(Rules.is_paper)[0]
	var fac: RulesCard = run.cards.filter(Rules.is_factor)[0]
	eq([Rules.strike_price(fog), Rules.strike_price(comp), Rules.strike_price(fac)], [8, 4, 4], "strike: 8 for his, 4 for a Paper Root or a Factor")
	Rules.strike(run, fog.id)
	eq([run.sov, ink_n(run, "heart"), run.cards.size(), run.stats.struck], [19, 1, n + 1, 1], "struck")
	ok(not Rules.strike(run, fog.id).ok, "a card can be struck once")
	Rules.strike(run, comp.id)
	eq([run.sov, paper_n(run)], [15, 8], "a Paper Root for 4")
	Rules.buy_instrument(run, 0)
	eq([run.instruments, run.sov], [[sh.instruments[0].key], 15 - int(sh.instruments[0].price)], "instrument bought")
	ok(not Rules.buy_instrument(run, 0).ok, "once")
	ok(not Rules.alley_habit(run, "lamp").ok and not Rules.alley_salt(run).ok and not Rules.alley_leave(run).ok, "no back alley for Jekyll")
	run.sov = 2
	ok(not Rules.buy_card(run, 1).ok and not Rules.buy_salt(run).ok and not Rules.strike(run, fac.id).ok and not Rules.buy_instrument(run, 1).ok, "nothing without the sovereigns")
	Rules.leave_lab(run)
	eq([run.night, run.round, run.phase, run.stance, run.shop, run.dawn], [1, 0, "play", "jekyll", null, null], "night 2 begins, in the same stance")
	ok(Rules.unlocked_factors(run).has("pen") and not Rules.unlocked_factors(run).has("cane"), "Reason is in the reward pool, Vigour not yet")
	ok(not Rules.leave_lab(run).ok and not Rules.buy_salt(run).ok and not Rules.drop_instrument(run, run.instruments[0]).ok, "the laboratory is closed during a night")


func test_dawn_1_in_the_back_alley() -> void:
	var run := at(fresh({}, 23), 0, 2)
	run.restraint = 2
	Rules.drink(run)
	win_scene(run)
	Rules.continue_result(run)
	run.sov = 20
	eq([run.phase, run.shop, ink_n(run, "heart"), run.unlocked.pen, run.dawn.as_hyde], ["alley", null, 3, true, true], "ended as Hyde: the back alley, and no shelf")
	ok(not Rules.buy_card(run, 0).ok and not Rules.buy_salt(run).ok and not Rules.strike(run, run.cards[0].id).ok and not Rules.buy_instrument(run, 0).ok and not Rules.leave_lab(run).ok, "nothing of the laboratory is sold there")
	eq(run.alley.options, ["hcane", "cheque"], "his two instruments are on offer")
	var n: int = run.cards.size()
	run.craving.lamp = 2
	eq([Rules.alley_habit(run, "lamp").ok, run.habit.lamp, run.craving.lamp, run.cards.size(), Rules.alley_habit(run, "heart").ok], [true, 1, 2, n, false], "one Habit, free: no copy, Craving untouched, once")
	eq([Rules.alley_instrument(run, "hcane").ok, run.instruments, Rules.alley_instrument(run, "cheque").ok], [true, ["hcane"], false], "one of his instruments, free")
	eq([Rules.salt_cost(run, "alley"), Rules.alley_salt(run).ok, run.sov, run.salt, run.doses_bought, Rules.salt_cost(run, "alley")], [5, true, 15, 4, 1, 6], "street chemist: salt at 2 over the price, and it still raises the price")
	Rules.alley_leave(run)
	eq([run.night, run.round, run.phase, run.stance], [1, 0, "play", "hyde"], "straight to night 2, still Hyde")
	# The Cane: Mania gains 4.
	run.habit.lamp = 0
	run.craving.lamp = 0
	run.stored = 0
	eq(Rules.evaluate(run, cards("I:lamp I:lamp I:lamp")).mult, 11, "The Cane on a Mania")
	eq(Rules.evaluate(run, cards("I:lamp I:lamp")).mult, 5, "and not on a Fixation")


func test_alley_limits() -> void:
	var run := at(fresh({}, 23), 0, 2)
	Rules.drink(run)
	for c: RulesCard in run.cards:  # no Pride in the deck
		if c.t == "root" and c.ink and c.sym == "mirror":
			c.ink = false
	win_scene(run)
	Rules.continue_result(run)
	eq(run.phase, "alley", "the back alley")
	ok(not Rules.alley_habit(run, "mirror").ok and run.habit.mirror == 0, "no Habit for a symbol with no Ink Root in the deck")
	ok(not Rules.alley_habit(run, "cup").ok, "nor for anything but his symbols")
	# The Habit and the instrument can be declined.
	run.instruments = ["spirit", "notebook", "balance"]
	ok(not Rules.alley_instrument(run, "cheque").ok, "three instruments held: no slot for his")
	eq(Rules.drop_instrument(run, "notebook").ok, true, "an instrument can be dropped at dawn")
	ok(not Rules.drop_instrument(run, "notebook").ok, "once")
	eq([Rules.alley_instrument(run, "cheque").ok, run.instruments], [true, ["spirit", "balance", "cheque"]], "then his instrument fits")
	ok(not Rules.alley_instrument(run, "spirit").ok and not Rules.alley_instrument(run, "hcane").ok, "the alley has only his instruments, and gives one")
	run.sov = 4
	ok(not Rules.alley_salt(run).ok and run.salt == 3, "salt needs 5 sovereigns here")
	Rules.alley_leave(run)
	eq([run.night, run.habit, run.phase], [1, {"lamp": 0, "heart": 0, "mirror": 0}, "play"], "leaving with the Habit declined")
	# The laboratory: no more than 3 instruments either.
	run = at(fresh({}, 22), 0, 2)
	win_scene(run)
	Rules.continue_result(run)
	run.sov = 40
	run.instruments = ["hcane", "cheque", run.shop.instruments[1].key]
	ok(not Rules.buy_instrument(run, 0).ok and run.sov == 40, "three instruments held: none can be bought")
	Rules.drop_instrument(run, "hcane")
	ok(Rules.buy_instrument(run, 0).ok and run.instruments.size() == 3, "after dropping one it can")


func test_later_dawns() -> void:
	# The Factor a back-alley dawn missed is owed at the next laboratory without a new one.
	var run := at(fresh({}, 25), 0, 2)
	Rules.drink(run)
	win_scene(run)
	Rules.continue_result(run)
	Rules.alley_leave(run)  # dawn 1 in the alley: no Reason seen
	run.stance = "jekyll"
	at(run, 1, 2)
	win_scene(run)
	Rules.continue_result(run)
	eq([run.phase, run.dawn.brings, run.dawn.unlocks, run.shop.cards[2].key, ink_n(run, "mirror")], ["lab", "mirror", "cane", "cane", 3], "dawn 2: two Pride, the Cane unlocks, Vigour is on the shelf")
	Rules.leave_lab(run)
	at(run, 2, 2)
	run.restraint = 0
	win_scene(run)
	Rules.continue_result(run)
	eq([run.phase, run.shop.cards[2].key, run.dawn.unlocks], ["lab", "pen", null], "dawn 3: Reason, which the deck still lacks")
	run.sov = 3
	Rules.buy_card(run, 2)
	Rules.leave_lab(run)
	# Dawn 4: the deck lacks the Cane, so Vigour. It is the last dawn and nothing joins.
	for i in 4:
		push(run, "P:lamp")
	at(run, 3, 2)  # he comes through the window; give the table back to Jekyll
	run.stance = "jekyll"
	run.stored = 0
	var n: int = run.cards.size()
	win_scene(run)
	Rules.continue_result(run)
	eq([run.phase, run.dawn.no, run.dawn.brings, run.dawn.last, run.cards.size(), run.shop.cards[2].key], ["lab", 4, null, true, n, "cane"], "dawn 4: nothing joins, and Vigour is owed")
	run.sov = 3
	Rules.buy_card(run, 2)
	Rules.leave_lab(run)
	eq([run.night, run.round], [4, 0], "the last night")


func test_lab_factor_at_random() -> void:
	# With both the Pen and the Cane in the deck, dawn 3's Factor is any unlocked one.
	var seen := {}
	for s in 40:
		var run := at(fresh({}, 100 + s), 2, 2)
		run.unlocked.pen = true
		run.unlocked.cane = true
		push(run, "F:pen")
		push(run, "F:cane")
		Rules.start_round(run)
		win_scene(run)
		Rules.continue_result(run)
		seen[run.shop.cards[2].key] = true
		ok(run.shop.cards[0].key != run.shop.cards[1].key, "two different Paper Roots")
	eq(seen.size(), 5, "every unlocked Factor can turn up")


func test_dawn_3_brings_his_highest_habit() -> void:
	# Ties by Craving, then by fewest copies, then Lamp, Heart, Mirror.
	var run := at(fresh({}, 26), 2, 2)
	run.hyde_arrived = true
	run.habit = {"lamp": 1, "heart": 2, "mirror": 2}
	run.craving = {"lamp": 2, "heart": 1, "mirror": 1}
	push(run, "I:heart")
	push(run, "I:heart")
	push(run, "I:mirror")
	eq(Rules.highest_habit(run), "mirror", "Habit ties, Craving ties: the one with fewer copies")
	run.craving.heart = 2
	eq(Rules.highest_habit(run), "heart", "Habit ties: the one with more Craving")
	Rules.start_round(run)
	win_scene(run)
	Rules.continue_result(run)
	eq([run.dawn.brings, run.dawn.unlocks, ink_n(run, "heart"), run.dawn.last], ["heart", null, 4, false], "two Appetite join at dawn 3")
	run = fresh({}, 26)
	eq(Rules.highest_habit(run), "lamp", "all equal: Lamp")
	run.habit.mirror = 1
	eq(Rules.highest_habit(run), "mirror", "the most Habit comes first")


func test_the_window() -> void:
	# A free shift that stains nothing, stores the restraint and brings his Roots.
	var run := fresh({}, 28)
	run.night = 3
	run.round = 2
	run.restraint = 2
	run.hyde_arrived = true
	for sym in RulesConfig.FIRST_ARRIVAL:
		push(run, "I:" + sym)
	Rules.start_round(run)
	eq([run.stance, run.stored, run.restraint, paper_n(run), ink_n(run), run.stats.stains, run.stats.drinks], ["hyde", 2, 0, 8, 4, 0, 0], "the window scene begins as Hyde: nothing stained, restraint stored")
	ok(run.log[0].how == "window" and run.log[0].brought.size() >= 1 and run.hand.size() == 8 + run.log[0].brought.size(), "he brought up to two Roots from the piles")
	ok(Rules.can_salt(run).ok, "salt works in that scene")
	# Not yet arrived by night 4: his four come with the window.
	var run2 := fresh({}, 28)
	run2.night = 3
	run2.round = 2
	Rules.start_round(run2)
	eq([run2.stance, ink_n(run2), run2.hyde_arrived], ["hyde", 4, true], "a first arrival through the window")
	# Its ordinary rounds are not bent, and Hyde entering it stays as he is.
	var run3 := at(fresh({}, 28), 3, 1)
	eq(run3.stance, "jekyll", "the twist applies to the scene only")
	var run4 := as_hyde(fresh({}, 28))
	first_arrival(run4)
	run4.stored = 3
	at(run4, 3, 2)
	eq([run4.stance, run4.stored, run4.hand.size(), run4.log.size()], ["hyde", 3, 8, 0], "entered as Hyde: nothing happens")


func test_the_last_scene() -> void:
	var run := at(fresh({}, 29), 4, 2)
	ok(not Rules.can_drink(run).ok and not Rules.drink(run).ok, "no draught in the last scene")
	as_hyde(run)
	ok(not Rules.can_salt(run).ok and not Rules.take_salt(run).ok, "no salt in the last scene")
	run.round = 1
	ok(Rules.can_salt(run).ok, "both work in its ordinary rounds")
	run.stance = "jekyll"
	ok(Rules.can_drink(run).ok, "both work in its ordinary rounds (draught)")
	# A breakout can still happen there.
	run = at(fresh({}, 29), 4, 2)
	run.restraint = 4
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])
	eq([run.stance, run.restraint, run.phase, ink_n(run)], ["hyde", 0, "play", 6], "the last scene can still break out")


func test_endings() -> void:
	var run := at(fresh({}, 30), 4, 2)
	win_scene(run)
	eq([run.phase, run.ending, run.ended_by], ["end", "myself", "scene"], "This, Too, Was Myself")
	ok(not Rules.continue_result(run).ok, "nothing follows an ending")
	run = at(fresh({}, 30), 4, 2)
	as_hyde(run)
	first_arrival(run)
	win_scene(run)
	eq([run.phase, run.ending, run.ended_by], ["end", "double", "scene"], "The Double Life")
	run = at(fresh({}, 30), 4, 2)
	as_hyde(run)
	for i in 9:
		push(run, "I:lamp")
	Rules.start_round(run)
	win_scene(run)
	eq([run.phase, run.ending, run.ended_by], ["end", "hyde", "line"], "the line comes before the last scene")
	# A rescued last scene ends in his stance: The Double Life.
	run = at(fresh({}, 30), 4, 2)
	run.plays = 1
	run.score = 39900
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])
	eq([run.last.how, run.score, run.phase, run.ending, run.ended_by, ink_n(run), paper_n(run)], ["rescued", 40020, "end", "double", "scene", 5, 7], "a rescued last scene is The Double Life")
	# Night 5's ordinary rounds end nothing.
	run = at(fresh({}, 30), 4, 1)
	win_scene(run)
	eq([run.phase, run.ending], ["result", null], "an ordinary round of the last night goes on to the scene")
	Rules.continue_result(run)
	eq([run.night, run.round, run.phase], [4, 2, "play"], "the last scene")


func test_whole_run() -> void:
	# From the first deal to an ending: every round won at once, two Paper Roots bought at
	# each laboratory. He comes through the window on night 4 and keeps the table.
	var run := fresh({}, 33)
	var guard := 0
	var places: Array = []
	while run.phase != "end" and guard < 200:
		guard += 1
		match run.phase:
			"play":
				run.restraint = 0
				win_scene(run)
			"result":
				Rules.continue_result(run, 0)
			"lab":
				places.append("lab")
				run.sov += 6
				Rules.buy_card(run, 0)
				Rules.buy_card(run, 1)
				Rules.leave_lab(run)
			"alley":
				places.append("alley")
				Rules.alley_leave(run)
	eq([run.phase, run.ending, run.ended_by, run.night, run.round, run.history.size()], ["end", "double", "scene", 4, 2, 15], "15 rounds to The Double Life")
	eq(places, ["lab", "lab", "lab", "alley"], "a dawn after each of the first four scenes, one place each")
	eq([run.unlocked, run.hyde_arrived], [{"pen": true, "cane": true}, true], "both Factors unlocked on the way")
	ok(run.history.all(func(e: Dictionary) -> bool: return e.how == "won"), "every round was won")
