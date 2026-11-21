extends "res://tests/case.gd"
## The two stances: drink, stain, salt, who brings which Roots, restraint and the breakout.


func _roots(run: Dictionary, brought: Array) -> Array:
	var out: Array = []
	for id: int in brought:
		out.append(Rules.card(run, id))
	return out


func test_first_drink() -> void:
	var run := fresh({}, 5)
	ok(not Rules.can_drink(run).ok, "no draught in round 1 of night 1")
	ok(not Rules.drink(run).ok and run.stance == "jekyll", "so a drink is refused")
	at(run, 0, 1)
	run.restraint = 3
	ok(Rules.can_drink(run).ok and Rules.drink_cost(run) == "first", "the draught arrives in round 2")
	var r := Rules.drink(run)
	eq([run.stance, run.stored, run.restraint, run.cards.size(), ink_n(run, "lamp"), ink_n(run, "heart"), ink_n(run, "mirror"), paper_n(run)],
			["hyde", 3, 0, 16, 2, 1, 1, 8], "first arrival: 2 Fog, 1 Appetite, 1 Pride, and nothing stained")
	eq([r.ev.first, r.ev.stained, r.ev.brought.size()], [true, null, 2], "he brings two Roots")
	var b := _roots(run, r.ev.brought)
	ok(b[0].ink and b[1].ink and b[0].sym == "lamp" and b[1].sym == "lamp", "a matching pair when the piles hold one: the two Fog")
	eq(run.hand.size(), 10, "the hand may go over 8")
	ok(not Rules.can_salt(run).ok, "no salt before the scene of night 1")
	ok(not Rules.can_drink(run).ok, "and no drink while he has the table")
	var fix := Rules.best(run)
	eq([fix.ev.name, fix.ev.spends_stored], ["Fixation", true], "his first hand carries the stored restraint")
	ok(fix.ev.mult_parts.any(func(p: Dictionary) -> bool: return p.label == "stored restraint" and p.v == 6), "2 mult a point")
	Rules.play(run, fix.ids)
	eq(run.stored, 0, "spent once")
	ok(run.hand.size() <= 8 + int(fix.ev.draws) and run.hand.size() >= 8, "no refill until the hand is under 8")


func test_stored_restraint_and_salt() -> void:
	# The stored restraint waits through a Passing Thought and is lost to salt.
	var run := at(fresh({}, 6), 0, 2)
	run.restraint = 2
	Rules.drink(run)
	var h := deal(run, "F:cup I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp")
	Rules.play(run, [h[0].id])
	eq(run.stored, 2, "a Passing Thought does not spend it")
	ok(Rules.can_salt(run).ok, "salt works in the scene")
	var r := Rules.take_salt(run)
	eq([run.stance, run.stored, run.restraint, run.salt, r.ev.lost_stored], ["jekyll", 0, 0, 2, 2], "salt: one dose, restraint 0, the store is lost")
	var br := _roots(run, r.ev.brought)
	ok(br.size() == 2 and not br[0].ink and not br[1].ink and br[0].sym != br[1].sym, "Jekyll brings two different Paper Roots")
	ok(not Rules.take_salt(run).ok, "no salt while Jekyll has the table")
	# It also waits from round to round.
	run = at(fresh({}, 6), 0, 1)
	run.restraint = 4
	Rules.drink(run)
	run.score = Rules.target(run) - 1
	h = deal(run, "F:cup I:lamp I:lamp P:heart P:heart P:mirror P:lamp P:lamp")
	Rules.play(run, [h[0].id])
	Rules.continue_result(run)
	eq([run.round, run.stance, run.stored, run.restraint], [2, "hyde", 4, 0], "the stance and the store carry over to the next round")
	# No doses, no salt.
	run.salt = 0
	ok(not Rules.can_salt(run).ok, "salt needs a dose")


func test_second_drink_stains() -> void:
	var run := at(fresh({}, 7), 0, 2)
	Rules.drink(run)
	Rules.take_salt(run)
	eq([Rules.drink_cost(run), paper_n(run), ink_n(run), run.cards.size()], ["stain", 8, 4, 16], "before the second drink")
	run.restraint = 1
	var r := Rules.drink(run)
	eq([paper_n(run), ink_n(run), run.cards.size(), run.stored], [7, 5, 16, 1], "the second drink stains one Paper Root: 7 to 5, same deck")
	ok(r.ev.stained != null and r.ev.stained.from == "draw" and Rules.card(run, r.ev.stained.id).ink, "it is taken from the draw pile and is ink now")
	eq([run.stats.stains, run.stats.drinks, run.stats.salts], [1, 2, 1], "counted")


func test_stain_order() -> void:
	# A Root of his with no copy left goes first; draw pile, then discards, then hand.
	var run := at(fresh({}, 8), 0, 2)
	Rules.drink(run)
	Rules.take_salt(run)
	run.cards = run.cards.filter(func(c: Dictionary) -> bool: return not (c.t == "root" and c.ink and c.sym == "mirror"))
	var live := func(id: int) -> bool: return not Rules.card(run, id).is_empty()
	run.draw = run.draw.filter(live)
	run.hand = run.hand.filter(live)
	run.discard = run.discard.filter(live)
	# Make sure every Scruple is in the draw pile.
	for c: Dictionary in run.cards:
		if c.t == "root" and not c.ink and c.sym == "mirror" and run.hand.has(c.id):
			run.hand.erase(c.id)
			run.draw.append(c.id)
	var r := Rules.drink(run)
	eq([r.ev.stained.sym, ink_n(run, "mirror")], ["mirror", 1], "no Pride in the deck: a Scruple is stained first")
	# A draw pile with no Paper Root: the discards are next.
	Rules.take_salt(run)
	var is_paper := func(id: int) -> bool: return Rules.is_paper(Rules.card(run, id))
	var not_paper := func(id: int) -> bool: return not Rules.is_paper(Rules.card(run, id))
	var papers: Array = (run.draw + run.hand + run.discard).filter(is_paper)
	run.draw = run.draw.filter(not_paper)
	run.hand = run.hand.filter(not_paper)
	run.discard = run.discard.filter(not_paper) + papers
	r = Rules.drink(run)
	eq(r.ev.stained.from, "discard", "then the discards")
	# Neither pile holds one: the hand is last.
	Rules.take_salt(run)
	papers = (run.draw + run.hand + run.discard).filter(is_paper)
	run.draw = run.draw.filter(not_paper)
	run.discard = run.discard.filter(not_paper)
	run.hand = run.hand.filter(not_paper) + papers
	r = Rules.drink(run)
	eq(r.ev.stained.from, "hand", "then the hand")
	ok(run.hand.has(r.ev.stained.id) and Rules.card(run, r.ev.stained.id).ink, "the Root changes where it lies")
	# No Paper Root anywhere: one of his Roots is added instead.
	run.salt = 1
	Rules.take_salt(run)
	for c: Dictionary in run.cards:
		if c.t == "root":
			c.ink = true
	var n: int = run.cards.size()
	r = Rules.drink(run)
	eq([r.ev.stained.added, r.ev.stained.id, run.cards.size()], [true, null, n + 1], "no Paper Root left: a random Ink Root joins instead")
	ok(run.cards[-1].ink and (run.draw.has(run.cards[-1].id) or run.hand.has(run.cards[-1].id)), "it joins the draw pile, from where he may bring it")


func test_arrivals_with_a_choice() -> void:
	var run := at(fresh({}, 10), 1, 0)
	run.hyde_arrived = true
	# Hyde, no pair in the piles: two different.
	push(run, "I:lamp")
	push(run, "I:heart")
	push(run, "I:mirror")
	Rules.start_round(run)
	deal(run, "P:lamp P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror")
	run.restraint = 0
	var r := Rules.drink(run)  # stains one, then pulls
	var br := _roots(run, r.ev.brought)
	ok(br.size() == 2 and br.all(func(c: Dictionary) -> bool: return c.ink), "Hyde pulls two of his")
	# Jekyll: symbols the hand lacks come first.
	var run2 := at(fresh({}, 11), 0, 2)
	Rules.drink(run2)
	deal(run2, "P:lamp P:lamp I:lamp I:lamp F:cup F:eye F:lock F:cup")
	r = Rules.take_salt(run2)
	var syms: Array = _roots(run2, r.ev.brought).map(func(c: Dictionary) -> String: return c.sym)
	syms.sort()
	eq(syms, ["heart", "mirror"], "Jekyll pulls the symbols his hand lacks")


# A run in Hyde's or Jekyll's stance whose piles hold what `extra` adds, with this hand.
func _table(stance: String, extra: String, hand: String) -> Dictionary:
	var run := at(fresh({}, 40), 1, 0)
	run.hyde_arrived = true
	for spec in extra.split(" "):
		push(run, spec)
	Rules.start_round(run)
	run.stance = stance
	deal(run, hand)
	return run


func _brought(run: Dictionary) -> Array:
	return _roots(run, Rules._bring_roots(run)).map(func(c: Dictionary) -> String: return ("I:" if c.ink else "P:") + str(c.sym))


func test_who_brings_what() -> void:
	var papers := "P:lamp P:lamp P:lamp P:heart P:heart P:heart P:mirror P:mirror"
	# Hyde: a matching pair, by most Habit, then most copies in the piles, then Lamp, Heart, Mirror.
	var run := _table("hyde", "I:lamp I:lamp I:heart I:heart I:mirror I:mirror I:mirror", papers)
	eq(_brought(run), ["I:mirror", "I:mirror"], "with no Habit, the pair with the most copies")
	run = _table("hyde", "I:lamp I:lamp I:heart I:heart I:mirror I:mirror I:mirror", papers)
	run.habit.heart = 1
	eq(_brought(run), ["I:heart", "I:heart"], "the pair with the most Habit comes before that")
	run = _table("hyde", "I:lamp I:lamp I:heart I:heart I:mirror I:mirror", papers)
	eq(_brought(run), ["I:lamp", "I:lamp"], "all else equal: Lamp, Heart, Mirror")
	eq(run.hand.size(), 10, "the two join the hand")
	# A pair counts across the draw pile and the discards.
	run = _table("hyde", "I:lamp I:heart I:heart I:mirror", papers)
	var one := -1
	for id: int in run.draw:
		var c := Rules.card(run, id)
		if c.t == "root" and c.ink and c.sym == "heart":
			one = id
	run.draw.erase(one)
	run.discard.append(one)
	eq(_brought(run), ["I:heart", "I:heart"], "a pair split between the draw pile and the discards")
	# Hyde, no pair: a symbol he already holds first, then the most Habit.
	run = _table("hyde", "I:lamp I:heart I:heart I:mirror", "I:heart P:lamp P:lamp P:lamp P:heart P:heart P:mirror P:mirror")
	run.habit.mirror = 1
	eq(_brought(run), ["I:heart", "I:mirror"], "no pair: the symbol he holds, then the one with the most Habit")
	run = _table("hyde", "I:lamp I:heart I:mirror", papers)
	eq(_brought(run), ["I:lamp", "I:heart"], "no pair, nothing held, no Habit: Lamp, then Heart")
	run = _table("hyde", "I:mirror", papers)
	eq(_brought(run), ["I:mirror"], "only one of his in the piles: he brings one")
	# Jekyll: a symbol his hand lacks first, then a symbol whose Ink twin he holds.
	run = _table("jekyll", "I:mirror I:lamp", "P:lamp I:mirror F:cup F:cup F:eye F:lock I:lamp P:lamp")
	eq(_brought(run), ["P:mirror", "P:heart"], "Jekyll: the symbols he lacks, the one whose Ink twin he holds first")
	run = _table("jekyll", "P:lamp P:heart P:mirror I:lamp", "P:lamp P:heart P:mirror I:mirror F:cup F:cup F:eye F:lock")
	eq(_brought(run), ["P:mirror", "P:lamp"], "he holds all three: the twin he can turn, then Lamp")
	run = _table("jekyll", "I:lamp", "F:cup F:cup F:eye F:lock I:lamp")
	eq(_brought(run), ["P:lamp", "P:heart"], "he holds none: the twin first, then Lamp, Heart, Mirror")
	# From the discards when the draw pile has no copy.
	run = _table("jekyll", "I:lamp", "F:cup F:cup F:eye F:lock I:lamp")
	var moved: Array = run.draw.filter(func(id: int) -> bool: return Rules.card(run, id).get("sym", "") == "lamp")
	for id: int in moved:
		run.draw.erase(id)
		run.discard.append(id)
	eq(_brought(run), ["P:lamp", "P:heart"], "a Root comes from the discards when the draw pile has none")
	ok(not run.discard.has(run.hand[-2]), "and it leaves the discards")


func test_breakout() -> void:
	var run := at(fresh({}, 12), 0, 1)
	run.restraint = 4
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	var r := Rules.play(run, [h[0].id])  # a Spark: fills the meter, nowhere near the target
	eq([run.stance, run.restraint, run.stored, run.phase, run.plays], ["hyde", 0, 0, "play", 3], "breakout: his stance, meter empty, nothing stored, the round goes on")
	eq([ink_n(run, "lamp"), ink_n(run, "heart"), ink_n(run, "mirror"), paper_n(run)], [2, 2, 2, 8], "first arrival by breakout: his four, then one each of his two lowest-count Roots")
	eq(run.hand.size(), 10, "he brings two Roots: a hand of 10")
	var bo: Dictionary = r.events.filter(func(x: Dictionary) -> bool: return x.t == "breakout")[0].ev
	eq([bo.first, bo.added, bo.lost_restraint, bo.brought.size()], [true, ["heart", "mirror"], 5, 2], "the breakout record")
	eq(run.stats.breakouts, 1, "counted")
	# A later breakout adds two, lowest counts first.
	run.stance = "jekyll"
	run.restraint = 4
	run.plays = 3
	push(run, "I:heart")
	h = deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])
	eq([ink_n(run, "lamp"), ink_n(run, "heart"), ink_n(run, "mirror")], [3, 3, 3], "two lowest-count: Fog and Pride")


func test_breakout_on_the_winning_play() -> void:
	var run := at(fresh({}, 13), 0, 0)
	run.restraint = 4
	run.score = 900
	var h := deal(run, "P:lamp P:heart P:mirror F:cup F:lock P:lamp P:heart P:mirror")
	var r := Rules.play(run, ids(h.slice(0, 4)))  # Lucid Mind with Good Cheer, no Resolve
	eq(r.ev.score, 770, "the play scores 770")
	eq([run.phase, run.last.how, run.last.stance, run.last.pay, run.offer, run.sov], ["result", "won", "hyde", 3 + 3, null, 6], "won as Hyde: paid, and no card offered")
	eq([ink_n(run), paper_n(run), run.hyde_arrived], [6, 8, true], "his Roots still arrived: 6 Ink Roots to 8 Paper Roots")
	eq(r.phase, "result", "the play reports the phase it left")


func test_restraint_limits() -> void:
	# Resolve and Sublimation add nothing; the Balance holds one more; night 3's scene two fewer.
	var run := at(fresh({}, 14), 0, 1)
	run.restraint = 4
	var h := deal(run, "P:lamp F:lock P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.stance, run.restraint], ["jekyll", 4], "Resolve: restraint stays")
	eq(Rules.limit(run), 5, "limit 5")
	run.instruments.append("balance")
	eq(Rules.limit(run), 6, "Balance: 6")
	at(run, 2, 2)
	eq(Rules.limit(run), 4, "night 3's scene with the Balance: 4")
	eq(Rules.limit_for(run, false), 6, "and 6 in its ordinary rounds")
	run.instruments = []
	eq(Rules.limit(run), 3, "night 3's scene: 3")
	eq(Rules.limit_for(run, false), 5, "and 5 in its ordinary rounds")
	run.round = 1
	eq([Rules.limit(run), Rules.limit_for(run, true)], [5, 3], "an ordinary round of night 3 knows the scene's lower limit")
	# Hyde's plays add none.
	run = at(as_hyde(fresh({}, 14)), 0, 1)
	first_arrival(run)
	h = deal(run, "I:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	Rules.play(run, [h[0].id])
	eq(run.restraint, 0, "Hyde's plays add no restraint")


func test_walking_in_full() -> void:
	var run := fresh({}, 15)
	run.night = 2
	run.round = 2
	run.restraint = 3
	run.hyde_arrived = true
	push(run, "I:lamp")
	Rules.start_round(run)
	eq([run.stance, run.restraint, run.stored, run.phase, ink_n(run), run.plays], ["hyde", 0, 0, "play", 3, 4], "night 3's scene entered at 3: he breaks out before the first play, with two Roots")
	ok(run.log.any(func(e: Dictionary) -> bool: return e.t == "shift" and e.how == "walkedin"), "logged")
	eq(run.hand.size(), 10, "and he brings two Roots")
	# Under the limit nothing happens.
	run = fresh({}, 15)
	run.night = 2
	run.round = 2
	run.restraint = 2
	Rules.start_round(run)
	eq([run.stance, run.restraint], ["jekyll", 2], "entered at 2: Jekyll keeps the table")
	# After the Balance is dropped: 5 of 6 in the meter is full at a limit of 5.
	run = fresh({}, 15)
	run.night = 1
	run.round = 1
	run.restraint = 5
	Rules.start_round(run)
	eq([run.stance, run.hyde_arrived, ink_n(run), paper_n(run)], ["hyde", true, 6, 8], "walking in full as his first arrival: his four and two more")
