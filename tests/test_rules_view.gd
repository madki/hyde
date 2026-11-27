extends "res://tests/case.gd"
## What the table shows before a move: RulesView.table and RulesView.preview.

const Golden := preload("res://tests/golden.gd")


func _hand_card(view: Dictionary, id: int) -> Dictionary:
	for c: Dictionary in view.hand:
		if c.id == id:
			return c
	return {}


func test_chosen_cards() -> void:
	var run := at(fresh({}, 3), 0, 1)
	var h := deal(run, "P:lamp P:heart P:mirror F:cup F:lock I:lamp P:lamp P:heart")
	var p: Dictionary = RulesView.table(run, ids(h.slice(0, 5))).play
	eq([p.ok, p.ev.name, p.ev.chips, p.ev.mult, p.ev.score], [true, "Lucid Mind", 120, 7, 840], "the hand's name, chips, mult and score")
	eq(p.ev.parts.map(func(x: Dictionary) -> int: return x.v), [55, 15, 15, 15, 10, 10], "the parts of the chips")
	eq(p.ev.mult_parts.map(func(x: Dictionary) -> Array: return [x.label, x.v]), [["Lucid Mind", 5], ["Good Cheer", 2]], "the parts of the mult")
	p = RulesView.preview(run, [h[5].id])
	eq([p.ok, p.reason], [false, "Fog turns only beside Composure."], "a play that is not allowed, and why")
	eq(RulesView.table(run).play, null, "nothing chosen: no preview")
	ok(not RulesView.preview(run, []).ok and not RulesView.preview(run, [999]).ok, "the chosen cards must be in the hand")


func test_what_a_play_will_do() -> void:
	# Restraint.
	var run := at(fresh({}, 3), 0, 1)
	run.restraint = 2
	var h := deal(run, "P:lamp F:lock F:eye P:heart P:mirror I:lamp P:lamp P:heart")
	var p := RulesView.preview(run, [h[0].id])
	eq(p.restraint, {"adds": true, "to": 3, "limit": 5, "breaks_out": false}, "restraint goes to 3 of 5")
	eq([p.score_to, p.target, p.meets_target, p.result, p.last_play, p.stance_to], [60, 1500, false, "goes_on", false, "jekyll"], "the score it reaches, short of the target")
	p = RulesView.preview(run, [h[0].id, h[1].id, h[2].id])
	eq([p.restraint.adds, p.restraint.to, p.ev.draws], [false, 2, 1], "Resolve adds none, and Curiosity draws 1")
	# The breakout.
	run.restraint = 4
	p = RulesView.preview(run, [h[0].id])
	eq([p.restraint.breaks_out, p.breakout, p.stance_to, p.result], [true, {"first": true, "added": ["heart", "mirror"]}, "hyde", "goes_on"], "a breakout as his first arrival, and the round goes on")
	eq(p.line, {"ink": 7, "paper": 8, "over": false}, "the line after it: his four and two more join the Fog already there")
	run.score = 1450
	p = RulesView.preview(run, [h[0].id])
	eq([p.meets_target, p.result, p.stance_to, p.pay, p.offers_card, p.ends_run], [true, "won", "hyde", 6, false, false], "a breakout on the winning play: won in his stance, paid, no card")
	run.restraint = 0
	p = RulesView.preview(run, [h[0].id])
	eq([p.result, p.stance_to, p.pay, p.offers_card], ["won", "jekyll", 6, true], "won as Jekyll: a card is offered")
	# A Sublimation.
	run.score = 0
	run.craving.lamp = 2
	run.temper.lamp = 1
	p = RulesView.preview(run, [h[0].id, h[5].id])
	eq(p.turns, [{"id": h[5].id, "sym": "lamp", "gain": 2, "temper_to": 3}], "the Root it turns and the Temper gained")
	eq([p.restraint.adds, p.line], [false, {"ink": 0, "paper": 9, "over": false}], "no restraint, and the line moves")
	# Hyde: Craving, the rollover, the stored restraint, the Cheque book.
	run = at(as_hyde(fresh({}, 3)), 0, 2)
	first_arrival(run)
	run.craving.lamp = 2
	run.stored = 3
	run.instruments.append("cheque")
	h = deal(run, "I:lamp I:lamp I:heart F:lock F:eye P:heart P:mirror P:lamp")
	p = RulesView.preview(run, [h[0].id, h[1].id, h[2].id, h[4].id])
	eq(p.craving, {"lamp": {"adds": 1, "to": 0, "copies": 1, "habit_to": 1}, "heart": {"adds": 1, "to": 1, "copies": 0, "habit_to": 0}}, "the Craving it adds, and the rollover")
	eq([p.ev.spends_stored, p.ev.cheque, p.ev.draws, p.restraint.adds, p.line.ink], [true, true, 1, false, 5], "stored restraint spent, the Cheque book pays, Impulse draws, a copy joins")
	p = RulesView.preview(run, [h[0].id, h[3].id])
	eq([p.craving, p.ev.no_craving], [{}, true], "Cunning: no Craving")
	p = RulesView.preview(run, [h[3].id])
	eq([p.ev.name, p.ev.spends_stored, p.craving], ["Passing Thought", false, {}], "a Passing Thought spends nothing")


func test_last_play_that_falls_short() -> void:
	# Night 2, round 1, target 3,000: two Kindness for 110, holding a Composure (Temper 1) and a Scruple.
	var setup := func(prior: int) -> Array:
		var run := at(fresh({}, 16), 1, 0)
		run.hyde_arrived = true
		run.temper.lamp = 1
		first_arrival(run)
		run.plays = 1
		run.score = prior
		return [run, deal(run, "P:heart P:heart P:lamp P:mirror F:cup I:lamp I:heart F:eye")]
	var t: Array = setup.call(2800)
	var h: Array = t[1]
	var p := RulesView.preview(t[0], [h[0].id, h[1].id])
	eq([p.last_play, p.meets_target, p.result], [true, false, "rescued"], "a last play that falls short")
	eq([p.rescue.k, p.rescue.ids, p.rescue.names, p.rescue.score, p.rescue.ok, p.rescue.factor], [1, [h[3].id], [["Scruple", "Pride"]], 3020, true, 2], "which held Root he would take, and the score that reaches")
	eq([p.line, p.ends_run, p.stance_to, p.pay, p.offers_card], [{"ink": 5, "paper": 7, "over": false}, false, "hyde", 0, false], "rescued at 5 to 7: his stance, no pay, no card")
	t = setup.call(2000)
	h = t[1]
	p = RulesView.preview(t[0], [h[0].id, h[1].id])
	eq([p.result, p.rescue.k, p.rescue.pool, p.rescue.score, p.rescue.ok, p.ends_run, p.ending, p.ended_by], ["lost", 2, 2, 2440, false, true, "hyde", "short"], "it fails: both converted and still short")
	# Covered, but over the line.
	var run := at(fresh({}, 17), 0, 0)
	run.plays = 1
	run.score = 700
	h = deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	p = RulesView.preview(run, [h[0].id])
	eq([p.result, p.rescue.k, p.rescue.score, p.line, p.ends_run, p.ended_by], ["rescued", 3, 1180, {"ink": 7, "paper": 5, "over": true}, true, "line"], "it covers the round and crosses the line: his first arrival is counted")
	# The last play also fills the meter: the breakout comes first.
	run = at(fresh({}, 19), 0, 1)
	run.restraint = 4
	run.plays = 1
	run.score = 1300
	h = deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	p = RulesView.preview(run, [h[0].id])
	eq([p.restraint.breaks_out, p.breakout.first, p.result, p.rescue.k, p.line, p.ended_by], [true, true, "rescued", 2, {"ink": 8, "paper": 6, "over": true}, "line"], "breakout, then the rescue: 8 to 6")
	var before := run.copy()
	Rules.play(run, [h[0].id])
	eq([run.last.how, run.last.rescue.k, run.last.rescue.ids, ink_n(run), paper_n(run), run.ended_by], ["rescued", 2, p.rescue.ids, 8, 6, "line"], "and the play does what was shown")
	ok(not same(before, run), "the play changed the run")
	# A Sublimation as a last play raises a Temper before he chooses.
	run = at(fresh({}, 19), 1, 0)
	run.hyde_arrived = true
	run.craving.lamp = 2
	run.plays = 1
	run.score = 2000
	h = deal(run, "P:lamp I:lamp P:lamp P:heart F:cup F:eye F:lock F:cup")
	p = RulesView.preview(run, [h[0].id, h[1].id])
	eq([p.ev.score, p.result, p.rescue.ids, p.rescue.score, p.line], [600, "rescued", [h[3].id], 3200, {"ink": 1, "paper": 8, "over": false}], "he takes the Kindness, not the Composure just tempered, and the turned Fog counts as paper")
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.last.rescue.ids, ink_n(run), paper_n(run), run.score], [p.rescue.ids, 1, 8, 3200], "as the play then does")


func test_draught_and_salt() -> void:
	var run := fresh({}, 5)
	var v := RulesView.table(run)
	eq(v.draught, {"ok": false, "why": "The draught does not exist yet.", "cost": "first"}, "no draught in round 1 of night 1")
	eq(v.salt, {"doses": 3, "ok": false, "why": "You are yourself.", "price_lab": 3, "price_alley": 5}, "the doses held, and why none can be taken")
	at(run, 0, 1)
	v = RulesView.table(run)
	eq(v.draught, {"ok": true, "why": "", "cost": "first"}, "the first drink brings his first four Roots")
	Rules.drink(run)
	v = RulesView.table(run)
	eq([v.draught.ok, v.draught.cost, v.salt.ok, v.salt.why], [false, "stain", false, "The salt comes with the scene."], "the next drink stains; no salt before the scene")
	at(run, 0, 2)
	v = RulesView.table(run)
	eq([v.salt.ok, v.salt.doses], [true, 3], "salt works in the scene")
	Rules.take_salt(run)
	v = RulesView.table(run)
	eq([v.salt.doses, v.salt.ok, v.draught.ok, v.draught.cost], [2, false, true, "stain"], "a dose spent, and the next drink costs a stain")


func test_line_restraint_and_symbols() -> void:
	var run := at(fresh({}, 5), 2, 1)
	first_arrival(run)
	run.hyde_arrived = true
	run.restraint = 2
	run.craving.lamp = 2
	run.habit.lamp = 1
	run.temper.heart = 2
	var v := RulesView.table(run)
	eq(v.line, {"ink": 4, "paper": 8, "total": 16, "cushion": 4, "over": false}, "the line: Ink Roots against Paper Roots")
	eq(v.restraint, {"meter": 2, "limit": 5, "scene_limit": 3, "stored": 0}, "the meter, this round's limit, and the scene's lower limit on night 3")
	eq(v.symbols.lamp, {"craving": 2, "habit": 1, "temper": 0, "paper": 3, "ink": 2, "paper_chips": 15, "ink_chips": 50}, "the Lamp: gauges, Roots in the deck, and what one is worth")
	eq(v.symbols.heart, {"craving": 0, "habit": 0, "temper": 2, "paper": 3, "ink": 1, "paper_chips": 45, "ink_chips": 15}, "the Heart")
	eq([v.symbols.mirror.paper, v.symbols.mirror.ink], [2, 1], "the Mirror")
	run.instruments.append("balance")
	at(run, 2, 2)
	v = RulesView.table(run)
	eq([v.restraint.limit, v.restraint.scene_limit, v.night.scene, v.night.twist_now], [4, 4, true, true], "in the scene, with the Balance")
	eq([v.score, v.target, v.plays, v.discards, v.phase, v.stance], [0, 13000, 4, 3, "play", "jekyll"], "the round")


func test_hand() -> void:
	var run := at(fresh({}, 5), 0, 1)
	run.hyde_arrived = true
	run.temper.lamp = 1
	var h := deal(run, "P:lamp I:lamp I:heart F:cup P:mirror P:mirror F:lock F:eye")
	var v := RulesView.table(run)
	eq(v.hand.size(), 8, "every card of the hand")
	eq(_hand_card(v, h[0].id), {"id": h[0].id, "t": "root", "key": "lamp", "ink": false, "name": "Composure", "chips": 30, "text": "", "playable": true, "turnable": false}, "a Paper Root as Jekyll")
	eq([_hand_card(v, h[1].id).playable, _hand_card(v, h[1].id).turnable], [true, true], "a Fog beside a Composure can be turned")
	eq([_hand_card(v, h[2].id).playable, _hand_card(v, h[2].id).turnable, _hand_card(v, h[2].id).name], [false, false, "Appetite"], "an Appetite with no Kindness cannot")
	eq([_hand_card(v, h[3].id).name, _hand_card(v, h[3].id).playable, _hand_card(v, h[3].id).key, _hand_card(v, h[3].id).text], ["Good Cheer", true, "cup", "Adds 2 mult."], "a Factor, under Jekyll's name, and what it does")
	eq(v.can_pass.ok, false, "a card can be played, so no pass")
	run.stance = "hyde"
	v = RulesView.table(run)
	eq([_hand_card(v, h[0].id).playable, _hand_card(v, h[1].id).playable, _hand_card(v, h[1].id).turnable, _hand_card(v, h[3].id).name], [false, true, false, "Glee"], "as Hyde: his Roots and the Factors, under his names")
	# Nothing to play and no discards: the play can be passed.
	deal(run, "P:lamp P:lamp P:heart P:heart P:mirror P:mirror P:lamp P:heart")
	run.discards = 0
	v = RulesView.table(run)
	ok(v.can_pass.ok and v.hand.all(func(c: Dictionary) -> bool: return not c.playable), "nothing playable: pass")
	# Between rounds there is no hand.
	run.score = Rules.target(run) - 1
	run.discards = 1
	h = deal(run, "I:lamp F:lock P:heart P:mirror P:lamp P:heart F:cup F:eye")
	Rules.play(run, [h[0].id, h[1].id])
	v = RulesView.table(run)
	eq([v.phase, v.hand, v.draught.ok, v.salt.ok, v.can_pass.ok, RulesView.preview(run, [h[2].id]).ok], ["result", [], false, false, false, false], "between rounds: no hand and no moves of the table")


func test_a_card_on_offer_reads_as_in_the_hand() -> void:
	var run := at(fresh({}, 5), 0, 1)
	var h := deal(run, "P:heart P:lamp P:mirror F:cup F:lock P:heart P:lamp P:mirror")
	for temper in [0, 2]:
		run.temper.heart = temper
		var offered := RulesView.offer_entry(run, "heart", "jekyll")
		var held := RulesView.entry(run, Rules.card(run, h[0].id), "jekyll")
		eq([offered.chips, offered.name, offered.ink, offered.t], [held.chips, held.name, held.ink, held.t], "a Paper Root on offer is worth what one in the deck is, at Temper %d" % temper)
		eq(offered.chips, _hand_card(RulesView.table(run), h[0].id).chips, "and what the hand shows, at Temper %d" % temper)
	eq(RulesView.offer_entry(run, "heart", "jekyll").chips, 45, "Temper 2: 15 + 2 x 15")
	var factor := RulesView.offer_entry(run, "lock", "jekyll")
	eq([factor.t, factor.name, factor.chips, factor.text], ["factor", "Resolve", run.dials.factor_chips, RulesConfig.factor_text("lock", "jekyll", run.dials)], "a Factor on offer, under Jekyll's name")


func test_night_and_dawn() -> void:
	var run := fresh({}, 5)
	var n: Dictionary = RulesView.table(run).night
	eq([n.no, n.title, n.round, n.scene, n.target, n.targets], [1, "Story of the Door", 1, false, 1000, [1000, 1500, 2200]], "the night and its targets")
	eq([n.twist, n.twist_now], ["", false], "night 1 has no twist")
	eq(n.dawn, {"brings": "heart", "brings_name": "Appetite", "by_habit": false, "unlocks": "pen", "unlocks_name": "Reason", "place": "lab", "last": false, "ends": false}, "what dawn 1 brings")
	at(run, 1, 0)
	n = RulesView.table(run).night
	eq([n.twist, n.twist_now, n.twist_text != "", n.dawn.brings_name, n.dawn.unlocks_name], ["hunted", false, true, "Pride", "Vigour"], "the scene's twist is known from round 1")
	at(run, 2, 0)
	run.habit.mirror = 1
	as_hyde(run)
	n = RulesView.table(run).night
	eq([n.twist, n.dawn.brings, n.dawn.by_habit, n.dawn.unlocks, n.dawn.place], ["tight", "mirror", true, "", "alley"], "dawn 3 brings his highest-Habit Root, as the gauges stand; as Hyde it is spent in the alley")
	at(run, 3, 2)
	n = RulesView.table(run).night
	eq([n.twist_now, n.dawn.brings, n.dawn.last, n.dawn.ends], [true, "", true, false], "dawn 4 brings nothing and is the last")
	at(run, 4, 0)
	n = RulesView.table(run).night
	eq([n.twist, n.dawn.place, n.dawn.ends, n.targets], ["last", "", true, [24000, 30000, 40000]], "after the last night the run ends")


func test_notebook() -> void:
	var run := at(fresh({}, 5), 0, 1)
	eq(RulesView.table(run).notebook, null, "without the Notebook nothing of the draw pile is shown")
	run.instruments.append("notebook")
	var v := RulesView.table(run)
	var top: Array = run.draw.slice(-3)
	top.reverse()
	eq(v.notebook.map(func(c: Dictionary) -> int: return c.id), top, "the top 3 cards of the draw pile, next first")
	eq(v.draw_count, 4, "and how many it holds")
	var next_id: int = v.notebook[0].id
	Rules.discard(run, [run.hand[0]])
	eq(run.hand[-1], next_id, "the first of them is the next card drawn")
	run.draw = [run.draw[0]]
	eq(RulesView.table(run).notebook.size(), 1, "a short pile shows what it has")
	run.draw = []
	eq(RulesView.table(run).notebook, [], "an empty pile shows nothing")


func test_queries_change_nothing() -> void:
	for record: Dictionary in Golden.runs().slice(0, 30):
		var run := Golden.begin(record)
		for move: Array in record.moves:
			var before := run.copy()
			var chosen: Array = move[1] if move[0] == "play" or move[0] == "discard" else run.hand.slice(0, 3)
			RulesView.table(run, chosen)
			Rules.best(run)
			if not same(run, before):
				_fail("a query changed the run before move %s" % JSON.stringify(move))
			Golden.apply(run, move)
		checks += 1


func test_preview_matches_the_play_that_follows() -> void:
	var seen := {"plays": 0, "refused": 0, "breakout": 0, "rescued": 0, "lost": 0, "won": 0, "bred": 0, "turned": 0, "rescue after breakout": 0, "rescue as first arrival": 0, "line": 0}
	var runs := Golden.runs()
	for i in runs.size():
		var record: Dictionary = runs[i]
		var run := Golden.begin(record)
		for j in record.moves.size():
			var move: Array = record.moves[j]
			if move[0] != "play" or run.phase != "play":
				Golden.apply(run, move)
				continue
			var p := RulesView.preview(run, move[1])
			var was := run.copy()
			var accepted := Golden.apply(run, move)
			var where := "run %d move %d" % [i, j + 1]
			seen.plays += 1
			if not accepted or not p.ok:
				eq(p.ok, accepted, where + ": allowed or not")
				seen.refused += 1
				continue
			var ended: bool = run.phase != "play"
			var got := {
				"result": run.last.how if ended else "goes_on",
				"score": run.score,
				"breaks_out": run.stats.breakouts > was.stats.breakouts,
				"stance_to": run.stance,
				"line": [ink_n(run), paper_n(run)],
				"ends_run": run.phase == "end", "ending": run.ending, "ended_by": run.ended_by,
				"offers_card": run.offer != null,
				"pay": int(run.sov) - int(was.sov) - (1 if p.ev.cheque and p.ev.kind == "hand" else 0),
				"bred": int(run.stats.bred) - int(was.stats.bred),
				"turned": int(run.stats.turns) - int(was.stats.turns),
				"rescue": [run.last.rescue.k, run.last.rescue.ids] if ended and run.last.has("rescue") else null,
			}
			var copies := 0
			for sym: String in p.craving:
				copies += int(p.craving[sym].copies)
			var want := {
				"result": p.result,
				"score": p.rescue.score if p.rescue != null else p.score_to,
				"breaks_out": p.restraint.breaks_out,
				"stance_to": p.stance_to,
				"line": [p.line.ink, p.line.paper],
				"ends_run": p.ends_run, "ending": p.ending, "ended_by": p.ended_by,
				"offers_card": p.offers_card,
				"pay": p.pay,
				"bred": copies,
				"turned": p.turns.size(),
				"rescue": [p.rescue.k, p.rescue.ids] if p.rescue != null else null,
			}
			eq(got, want, where)
			if not p.restraint.breaks_out and not ended:
				eq(run.restraint, p.restraint.to, where + ": restraint")
			for sym: String in p.craving:
				eq([run.craving[sym], run.habit[sym]], [p.craving[sym].to, p.craving[sym].habit_to], where + ": Craving and Habit of the " + sym)
			for t: Dictionary in p.turns:
				ok(not Rules.card(run, t.id).ink, where + ": the Root is turned")
			if not p.turns.is_empty():
				var last_turn: Dictionary = p.turns[-1]
				eq(run.temper[last_turn.sym], last_turn.temper_to, where + ": Temper")
			eq(p.meets_target, p.score_to >= Rules.target(was), where + ": meets the target")
			if p.rescue != null:
				for id: int in p.rescue.ids:
					ok(Rules.card(run, id).ink and not Rules.card(was, id).ink, where + ": the Root he took is his now")
				if p.restraint.breaks_out:
					seen["rescue after breakout"] += 1
				if not was.hyde_arrived and p.rescue.ok:
					seen["rescue as first arrival"] += 1
			seen[p.result if ended else "plays"] += 1 if ended else 0
			seen.breakout += int(p.restraint.breaks_out)
			seen.bred += copies
			seen.turned += p.turns.size()
			seen.line += int(p.ended_by == "line")
			if fails > 20:
				return
	print("  previews checked against the play: %s" % JSON.stringify(seen))
	for k: String in seen:
		ok(seen[k] > 0, "the recorded runs hold a case of: " + k)


func test_texts_follow_the_numbers() -> void:
	var run := as_hyde(at(fresh({"max_play": 3, "max_discard": 3, "glee_chips": 30, "tight_drop": 1, "hcane_mult": 6, "balance_bonus": 2}, 5), 2, 0))
	var h := deal(run, "F:cup I:lamp I:lamp I:lamp I:lamp P:heart P:mirror P:lamp")
	eq(_hand_card(RulesView.table(run), h[0].id).text, "Adds 30 chips.", "Glee's text names the run's number")
	eq(RulesView.table(run).night.twist_text, "Restraint holds 1 fewer.", "so does the twist's")
	eq([RulesConfig.instrument_text("hcane", run.dials), RulesConfig.instrument_text("balance", run.dials)], ["His Mania gains 6 mult.", "Restraint holds 2 more."], "and an instrument's")
	eq(Rules.evaluate(run, h.slice(1, 5)).reason, "A hand is up to 3 cards.", "a play of too many cards")
	eq(Rules.discard(run, ids(h.slice(1, 5))).reason, "Discard up to 3 cards.", "a discard of too many")
	for kind in RulesConfig.FACTORS:
		for stance: String in ["jekyll", "hyde"]:
			ok(not RulesConfig.factor_text(kind, stance, run.dials).contains("{"), "%s's text for %s is filled in" % [kind, stance])
	for n in RulesConfig.NIGHTS.size():
		ok(not RulesConfig.twist_text(n, run.dials).contains("{"), "night %d's twist is filled in" % (n + 1))
	for key: String in RulesConfig.INSTRUMENTS:
		ok(not RulesConfig.instrument_text(key, run.dials).contains("{"), key + "'s text is filled in")
	# The targets handed out are the table's own to change.
	var targets: Array = RulesView.table(fresh()).night.targets
	targets.append(1)
	eq(RulesConfig.targets(RulesDials.new(), 0), [1500, 2250, 3300], "changing the targets handed out leaves the game's alone")


func test_no_reward_cards() -> void:
	var run := at(fresh({"reward_cards": 0}, 22), 0, 1)
	run.score = Rules.target(run) - 1
	var h := deal(run, "P:lamp F:lock P:heart P:mirror P:lamp P:heart F:cup F:eye")
	eq(RulesView.preview(run, [h[0].id, h[1].id]).offers_card, false, "with no reward cards the preview offers none")
	Rules.play(run, [h[0].id, h[1].id])
	eq([run.phase, run.last.how, run.offer], ["result", "won", null], "and the round won offers none")


# ---------- what the table shows with the score hidden ----------

# The preview of playing these cards, dealt into the hand of `run`.
func _preview(run: RulesRun, play: String, rest: String = "") -> Dictionary:
	var h := deal(run, play + (" " + rest if rest != "" else ""))
	return RulesView.preview(run, ids(h.slice(0, play.split(" ").size())))


func test_base_is_the_hands_own() -> void:
	var run := fresh()
	# Rules 4.1, Jekyll's column, and the Sublimation and the Passing Thought.
	var rows := [
		["P:lamp", 15, 2], ["P:lamp P:lamp", 25, 2], ["P:lamp P:heart", 30, 3], ["P:lamp P:lamp P:lamp", 40, 3],
		["P:lamp P:heart P:mirror", 55, 5], ["P:lamp I:lamp", 25, 2], ["F:cup F:eye", 10, 1],
	]
	run.temper = {"lamp": 2, "heart": 1, "mirror": 0}
	run.craving.lamp = 2
	for row: Array in rows:
		var extra := "" if row[0] == "P:lamp I:lamp" or row[0] == "F:cup F:eye" else " F:pen"
		var p := _preview(run, row[0] + extra)
		eq(p.base, {"chips": row[1], "mult": row[2]}, "Jekyll: %s" % row[0])
	# Hyde's column, and night 2's scene, where the hand's mult is halved.
	rows = [
		["I:lamp", 20, 3, 2], ["I:lamp I:lamp", 35, 5, 3], ["I:lamp I:heart", 25, 3, 2],
		["I:lamp I:lamp I:lamp", 60, 7, 4], ["I:lamp I:heart I:mirror", 40, 4, 2],
	]
	for hunted: bool in [false, true]:
		run = at(as_hyde(fresh()), 1, 2 if hunted else 0)
		run.habit.lamp = 2
		run.stored = 3
		for row: Array in rows:
			var p := _preview(run, row[0] + " F:pen")
			eq(p.base, {"chips": row[1], "mult": row[3] if hunted else row[2]}, "Hyde%s: %s" % [", hunted" if hunted else "", row[0]])


func test_roots_at_risk_only_on_the_last_play() -> void:
	var run := at(fresh({}, 17), 0, 0)
	var p := _preview(run, "P:lamp", "P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	eq([p.at_risk, p.line_breaks_at], [null, -1], "two plays left: nothing at risk")
	run.plays = 1
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	p = RulesView.preview(run, [h[0].id])
	var lamps := [h[4].id, h[5].id]
	var hearts := [h[1].id, h[2].id]
	lamps.sort()
	hearts.sort()
	eq(p.at_risk, lamps + hearts + [h[3].id], "the held Paper Roots by Lamp, Heart, Mirror; the cup and eye are not at risk")


func test_line_breaks_at_in_the_rules_scenarios() -> void:
	# Scenario 5: night 2, round 1, Lamp Temper 1, he has arrived; two Kindness for 110,
	# holding a Composure and a Scruple. In all three cases the line holds: 5 to 7, 6 to 6.
	for prior: int in [2800, 2700, 2000]:
		var run := at(fresh({}, 16), 1, 0)
		run.hyde_arrived = true
		run.temper.lamp = 1
		first_arrival(run)
		run.plays = 1
		run.score = prior
		var h := deal(run, "P:heart P:heart P:lamp P:mirror F:cup I:lamp I:heart F:eye")
		var p := RulesView.preview(run, [h[0].id, h[1].id])
		eq([p.at_risk, p.line_breaks_at], [[h[3].id, h[2].id], -1], "scenario 5, prior %d: the Scruple, then the Composure, and the line holds" % prior)
		Rules.play(run, [h[0].id, h[1].id])
		ok(run.ended_by != "line", "scenario 5, prior %d: the run does not end at the line" % prior)
	# Scenario 6: night 1, round 1, a Spark for 60 as his first arrival. The third Root
	# taken puts him over: 7 to 5.
	var cases := [
		[900, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye", 5, 1, false],
		[700, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye", 5, 3, true],
		[0, "P:lamp F:cup F:cup F:eye F:lock P:heart P:heart P:mirror", 3, 3, false],
	]
	for c: Array in cases:
		var run := at(fresh({}, 17), 0, 0)
		run.plays = 1
		run.score = c[0]
		var h := deal(run, c[1])
		var p := RulesView.preview(run, [h[0].id])
		eq([p.at_risk.size(), p.line_breaks_at], [c[2], 2], "scenario 6, prior %d: the third Root breaks the line" % c[0])
		Rules.play(run, [h[0].id])
		eq([run.last.rescue.k, run.ended_by == "line"], [c[3], c[4]], "scenario 6, prior %d: %d taken, %s" % [c[0], c[3], "over the line" if c[4] else "the line is not what ends it" if run.phase == "end" else "the line holds"])
	# A breakout on the last play counts too: his four and two more.
	var run := at(fresh({}, 19), 0, 1)
	run.restraint = 4
	run.plays = 1
	run.score = 1300
	var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
	var p := RulesView.preview(run, [h[0].id])
	eq(p.line_breaks_at, 1, "after a breakout as his first arrival, 6 to 8: the first Root taken makes 7 to 7, the second 8 to 6")


func test_hidden_fields_do_not_follow_the_score() -> void:
	# The same play with another score before it, or worth another score, shows the same.
	var shown := []
	for k: int in 3:
		var run := at(fresh({"root_chips": [15, 40, 90][k]}, 17), 0, 0)
		run.plays = 1
		run.score = [0, 900, 990][k]
		var h := deal(run, "P:lamp P:heart P:heart P:mirror P:lamp P:lamp F:cup F:eye")
		var p := RulesView.preview(run, [h[0].id, h[1].id])
		shown.append([p.base, p.at_risk, p.line_breaks_at])
	eq(shown[1], shown[0], "another score before the play")
	eq(shown[2], shown[0], "another score for the play")


func test_roots_at_risk_over_the_golden_runs() -> void:
	var seen := {"rescues": 0, "last plays": 0}
	for i in Golden.runs().size():
		var record: Dictionary = Golden.runs()[i]
		var run := Golden.begin(record)
		for j in record.moves.size():
			var move: Array = record.moves[j]
			if move[0] != "play" or run.phase != "play":
				Golden.apply(run, move)
				continue
			var p := RulesView.preview(run, move[1])
			if not p.ok:
				Golden.apply(run, move)
				continue
			var label := "run %d, move %d" % [i, j + 1]
			var last: bool = run.plays == 1
			if not last:
				if p.at_risk != null:
					_fail(label + ": at risk with plays left")
				checks += 1
				Golden.apply(run, move)
				continue
			seen["last plays"] += 1
			# Another score before the play changes neither field.
			var other := run.copy()
			other.score = 0 if run.score > 0 else Rules.target(run)
			var q := RulesView.preview(other, move[1])
			eq([q.base, q.at_risk, q.line_breaks_at], [p.base, p.at_risk, p.line_breaks_at], label + ": the same whatever the score")
			Golden.apply(run, move)
			if run.last != null and run.last.has("rescue") and run.last.round == run.round and run.last.night == run.night:
				var k: int = run.last.rescue.k
				seen.rescues += 1
				eq(run.last.rescue.ids, p.at_risk.slice(0, k), label + ": the rescue takes the Roots at risk, in order")
				if run.last.how == "rescued":
					var over: bool = run.last.ink > run.last.paper
					eq(over, p.line_breaks_at >= 0 and k > p.line_breaks_at, label + ": the line breaks where it was marked")
	ok(seen.rescues > 100 and seen["last plays"] > 300, "checked over the golden runs: %s" % JSON.stringify(seen))


func test_best_root() -> void:
	var run := at(fresh({}, 3), 0, 1)
	run.temper.heart = 1
	var h := deal(run, "P:lamp P:heart P:mirror F:cup I:lamp P:lamp P:heart P:mirror")
	eq(RulesView.preview(run, [h[0].id, h[1].id, h[2].id]).best_root, h[1].id, "the Root with the most chips")
	eq(RulesView.preview(run, [h[2].id, h[0].id]).best_root, h[0].id, "a tie goes Lamp, Heart, Mirror")
	eq(RulesView.preview(run, [h[0].id, h[4].id]).best_root, h[0].id, "in a Sublimation the Paper Root, not the one being turned")
	eq(RulesView.preview(run, [h[3].id]).best_root, -1, "none in a play without a Root")
	run = at(as_hyde(fresh({}, 3)), 0, 1)
	run.craving.mirror = 1
	h = deal(run, "I:lamp I:mirror P:lamp F:cup I:heart P:heart P:mirror P:lamp")
	eq(RulesView.preview(run, [h[0].id, h[1].id]).best_root, h[1].id, "as Hyde, his Root with the most chips")
