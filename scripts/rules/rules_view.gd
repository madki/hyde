class_name RulesView
## What a table shows before a move, and what a dawn's place offers, so that no rule is
## worked out in the UI. The queries only read: they do not change the run and do not move
## its generator on.
##
## table() and preview() are for a round. place() is for the dawn between two nights:
##
## place(run) is null outside the "lab" and "alley" phases. Otherwise, in both places:
##
## - `where`: "lab" (Jekyll has the table) or "alley" (Hyde has it).
## - `sov`: the purse.
## - `night`: {no, title}: the night that begins on leaving (`no` counted from 1).
## - `dawn`: {no, brings, brings_name, unlocks, unlocks_name, last}: what this dawn brought:
##   the symbol and name of the Ink Root two copies of which joined, and the kind and
##   (paper) name of the Factor that unlocked, each "" for none. `last`: no dawn follows it.
## - `held`: the instruments held, in order, each {key, name, text}. Any of them can be
##   dropped (Rules.drop_instrument). `slots`: how many can be held. `slots_free`.
## - `salt`: {doses, price, ok, why}: the doses held, and the next one's price here.
##
## Every offer has `ok` and `why`: whether the rules' own function would accept it now, and
## if not its refusal, a short sentence that can be shown as it is ("" when ok).
##
## In the laboratory only (the buying function in brackets):
##
## - `cards`: the shelf, each {index, key, t, name, text, price, sold, ok, why}
##   [Rules.buy_card(run, index)]. `t` is "root" or "factor"; every card here is on paper.
## - `instruments`: each {index, key, name, text, price, sold, ok, why}
##   [Rules.buy_instrument(run, index)].
## - `strike`: every card of the deck, in the deck's order, each {id, key, t, ink, name,
##   text, price, ok, why} [Rules.strike(run, id)]. `key` is the symbol or the Factor's
##   kind, `ink` is true for his Roots only.
## - salt: Rules.buy_salt(run). Leaving: Rules.leave_lab(run).
##
## In the back alley only:
##
## - `habit`: his free Habit, once: one entry for each symbol with an Ink Root in the deck,
##   each {sym, name, habit, adds, taken, ok, why} [Rules.alley_habit(run, sym)]. `name` is
##   the Ink Root's, `habit` the gauge now, `adds` what taking it adds.
## - `instruments`: his instruments on offer, free, one only, each {key, name, text, taken,
##   ok, why} [Rules.alley_instrument(run, key)].
## - `taken`: {habit, instrument}: the symbol and the key taken at this dawn, each "" for
##   none. Once one is taken, the others of its kind are refused ("Already taken.").
## - salt: Rules.alley_salt(run). Leaving: Rules.alley_leave(run).
##
## A text of a card is what a Factor does ("" for a Root), in the words of the man at the
## table, and like an instrument's it has the run's numbers in it.


## Everything the table draws from. With `chosen` (ids of hand cards), `play` holds the
## preview of playing them: see preview().
##
## - `draught`: {ok, why, cost}: whether it can be drunk, and what the next drink costs
##   ("first": his first four Roots join, "stain": one Paper Root is stained).
## - `salt`: {doses, ok, why, price_lab, price_alley}.
## - `line`: {ink, paper, total, cushion, over}: Ink Roots against Paper Roots.
## - `restraint`: {meter, limit, scene_limit, stored}: this round's limit and the scene's.
## - `symbols`: for each symbol {craving, habit, temper, paper, ink, paper_chips, ink_chips}:
##   the gauges, how many of each Root the deck holds, and what one is worth now.
## - `hand`: for each card {id, t, key, ink, name, chips, text, playable, turnable}: what a
##   Factor does, whether the man at the table can play the card, and for an Ink Root
##   whether Jekyll can turn it now.
## - `can_pass`: {ok, why}.
## - `night`: {no, title, round, scene, target, targets, twist, twist_text, twist_now,
##   dawn: {brings, brings_name, unlocks, unlocks_name, place, last, ends}}: the scene's
##   twist, known from round 1, and what the dawn after it brings.
## - `notebook`: null without the Notebook, else the top cards of the draw pile, next first
##   (three at most), each {id, name, ink}.
static func table(run: RulesRun, chosen: Array = []) -> Dictionary:
	var stance: String = run.stance
	var playing: bool = run.phase == "play"
	var drink := Rules.can_drink(run)
	var salt := Rules.can_salt(run)
	var symbols := {}
	for sym in RulesConfig.ROOTS:
		symbols[sym] = {
			"craving": run.craving[sym], "habit": run.habit[sym], "temper": run.temper[sym],
			"paper": Rules.count_roots(run, false, sym), "ink": Rules.count_roots(run, true, sym),
			"paper_chips": Rules.chips_of(run, RulesCard.make(0, sym, false)),
			"ink_chips": Rules.chips_of(run, RulesCard.make(0, sym, true)),
		}
	var hand: Array = []
	for id: int in run.hand:
		var c := Rules.card(run, id)
		var turnable: bool = stance == "jekyll" and Rules.is_ink(c) and Rules._hand_has(run, c.sym, false)
		hand.append({
			"id": id, "t": c.t, "key": c.key(), "ink": c.is_ink(),
			"name": Rules.name_of(c, stance), "chips": Rules.chips_of(run, c),
			"text": RulesConfig.factor_text(c.kind, stance, run.dials) if c.is_factor() else "",
			"playable": playing and (c.is_factor() or c.ink == (stance == "hyde") or turnable),
			"turnable": playing and turnable,
		})
	var notebook: Variant = null
	if Rules.has_inst(run, "notebook"):
		var next: Array = []
		var draw: Array = run.draw
		for i in mini(3, draw.size()):
			var c := Rules.card(run, draw[draw.size() - 1 - i])
			next.append({"id": c.id, "name": Rules.name_of(c, stance), "ink": Rules.is_ink(c)})
		notebook = next
	return {
		"phase": run.phase, "stance": stance, "score": run.score, "target": Rules.target(run),
		"plays": run.plays, "discards": run.discards, "sov": run.sov, "instruments": run.instruments.duplicate(),
		"draw_count": run.draw.size(), "discard_count": run.discard.size(),
		"draught": {"ok": drink.ok, "why": drink.why, "cost": Rules.drink_cost(run)},
		"salt": {
			"doses": run.salt, "ok": salt.ok, "why": salt.why,
			"price_lab": Rules.salt_cost(run, "lab"), "price_alley": Rules.salt_cost(run, "alley"),
		},
		"line": Rules.line_info(run),
		"restraint": {
			"meter": run.restraint, "limit": Rules.limit(run), "scene_limit": Rules.limit_for(run, true),
			"stored": run.stored,
		},
		"symbols": symbols,
		"hand": hand,
		"can_pass": Rules.can_pass(run),
		"night": _night(run),
		"notebook": notebook,
		"play": preview(run, chosen) if not chosen.is_empty() else null,
	}


static func _night(run: RulesRun) -> Dictionary:
	var night := Rules.night_of(run)
	var last_night: bool = run.night == Rules.night_count() - 1
	var brings: String = night.brings
	if brings == "habit":
		brings = Rules.highest_habit(run)
	var unlocks: String = night.unlocks
	return {
		"no": run.night + 1, "title": night.title, "round": run.round + 1, "scene": Rules.is_scene(run),
		"target": Rules.target(run), "targets": RulesConfig.targets(run.dials, run.night),
		"twist": night.twist, "twist_text": RulesConfig.twist_text(run.night, run.dials), "twist_now": Rules.twist_now(run) != "",
		"dawn": {
			# Two copies of this Ink Root join. For night 3 it is his highest-Habit Root as
			# the gauges stand now.
			"brings": brings, "brings_name": RulesConfig.ROOT[brings].ink if brings != "" else "",
			"by_habit": night.brings == "habit",
			"unlocks": unlocks, "unlocks_name": RulesConfig.FACTOR[unlocks].paper if unlocks != "" else "",
			# Where the dawn is spent if the scene ends in the present stance.
			"place": "" if last_night else ("alley" if run.stance == "hyde" else "lab"),
			"last": run.night == Rules.night_count() - 2,
			"ends": last_night,
		},
	}


## What the dawn's place offers: see the top of this file. Null when the run is in neither
## the laboratory nor the back alley.
static func place(run: RulesRun) -> Variant:
	var where: String = run.phase
	if where != "lab" and where != "alley":
		return null
	var held: Array = []
	for key: String in run.instruments:
		held.append(_instrument(run, key))
	var dawn: Dictionary = run.dawn if run.dawn != null else {}
	var brings: String = dawn.brings if dawn.get("brings") != null else ""
	var unlocks: String = dawn.unlocks if dawn.get("unlocks") != null else ""
	var next: int = mini(run.night + 1, Rules.night_count() - 1)
	var out := {
		"where": where, "sov": run.sov,
		"night": {"no": next + 1, "title": RulesConfig.NIGHTS[next].title},
		"dawn": {
			"no": dawn.get("no", run.night + 1),
			"brings": brings, "brings_name": RulesConfig.ROOT[brings].ink if brings != "" else "",
			"unlocks": unlocks, "unlocks_name": RulesConfig.FACTOR[unlocks].paper if unlocks != "" else "",
			"last": dawn.get("last", next == Rules.night_count() - 1),
		},
		"held": held, "slots": RulesConfig.MAX_INSTRUMENTS,
		"slots_free": maxi(0, RulesConfig.MAX_INSTRUMENTS - run.instruments.size()),
		"salt": _offer({"doses": run.salt, "price": Rules.salt_cost(run, where)}, Rules.can_buy_salt(run, where)),
	}
	if where == "lab":
		_lab(run, out)
	else:
		_alley(run, out)
	return out


static func _lab(run: RulesRun, out: Dictionary) -> void:
	var cards: Array = []
	var shelf: Array = run.shop.cards
	for i in shelf.size():
		var c := RulesCard.make(0, shelf[i].key, false)
		cards.append(_offer({
			"index": i, "key": c.key(), "t": c.t, "name": Rules.name_of(c, run.stance), "text": _card_text(run, c),
			"price": int(shelf[i].price), "sold": shelf[i].sold,
		}, Rules.can_buy_card(run, i)))
	var instruments: Array = []
	shelf = run.shop.instruments
	for i in shelf.size():
		var o := _instrument(run, shelf[i].key)
		o.merge({"index": i, "price": int(shelf[i].price), "sold": shelf[i].sold})
		instruments.append(_offer(o, Rules.can_buy_instrument(run, i)))
	var strike: Array = []
	for c: RulesCard in run.cards:
		strike.append(_offer({
			"id": c.id, "key": c.key(), "t": c.t, "ink": c.is_ink(), "name": Rules.name_of(c, run.stance),
			"text": _card_text(run, c), "price": Rules.strike_price(c),
		}, Rules.can_strike(run, c.id)))
	out.cards = cards
	out.instruments = instruments
	out.strike = strike


static func _alley(run: RulesRun, out: Dictionary) -> void:
	var taken_habit: String = run.alley.habit if run.alley.get("habit") != null else ""
	var taken_inst: String = run.alley.inst if run.alley.get("inst") != null else ""
	var habit: Array = []
	for sym in RulesConfig.ROOTS:
		if Rules.count_roots(run, true, sym) == 0:
			continue
		habit.append(_offer({
			"sym": sym, "name": RulesConfig.ROOT[sym].ink, "habit": run.habit[sym], "adds": run.dials.alley_habit,
			"taken": sym == taken_habit,
		}, Rules.can_alley_habit(run, sym)))
	var instruments: Array = []
	for key: String in run.alley.options:
		var o := _instrument(run, key)
		o.taken = key == taken_inst
		instruments.append(_offer(o, Rules.can_alley_instrument(run, key)))
	out.habit = habit
	out.instruments = instruments
	out.taken = {"habit": taken_habit, "instrument": taken_inst}


static func _instrument(run: RulesRun, key: String) -> Dictionary:
	return {"key": key, "name": RulesConfig.INSTRUMENTS[key].name, "text": RulesConfig.instrument_text(key, run.dials)}


static func _card_text(run: RulesRun, c: RulesCard) -> String:
	return RulesConfig.factor_text(c.kind, run.stance, run.dials) if c.is_factor() else ""


# An offer with the rules' answer ({ok, why}) put in.
static func _offer(o: Dictionary, can: Dictionary) -> Dictionary:
	o.ok = can.ok
	o.why = can.why
	return o


## What playing these hand cards would do. {ok: false, reason} if the play is not allowed.
## Otherwise:
##
## - `ev`: the reading (RulesHands.evaluate): the hand's name, chips, mult and score with
##   their parts and steps, `spends_stored`, `cheque`, `draws`, `no_craving`.
## - `base`: {chips, mult}: the hand's own chips and mult (rules 4.1; the mult halved when
##   hunted; 10 x 1 for a Passing Thought), without the cards' chips or any bonus.
## - `at_risk`: on the round's last play only, else null: the ids of the Paper Roots that
##   would stay in the hand, in the order a rescue would take them. `line_breaks_at`: the
##   place in that list (from 0) of the first Root whose loss would put his Roots ahead of
##   Jekyll's, counting his first arrival and a breakout on this play; -1 for none, or when
##   there is no list. Neither depends on the score.
## - `restraint`: {adds, to, limit, breaks_out}. `to` is the meter if he does not break out.
## - `breakout`: null, or {first, added}: whether it is his first arrival (his first four
##   Roots join) and the symbols of the two Ink Roots that join besides.
## - `craving`: for each symbol the play adds to: {adds, to, copies, habit_to}.
## - `turns`: for each Ink Root turned, in order: {id, sym, gain, temper_to}.
## - `best_root`: the id of the play's best Root (the active Root with the most chips, ties
##   going Lamp, Heart, Mirror), or -1 for a play without an active Root.
## - `score_to`, `target`, `meets_target`, `last_play`.
## - `result`: "goes_on", "won", "rescued" or "lost" (a rescue that cannot cover the round).
## - `rescue`: null, or for a last play that falls short {k, ids, names, pool, factor, score,
##   ok}: the held Paper Roots he would convert, in order, and the score that reaches.
## - `pay` and `offers_card`, for a round that is won.
## - `stance_to`: who has the table afterwards.
## - `line`: {ink, paper, over}: the line as it would stand after the play.
## - `ends_run`, `ending`, `ended_by`: whether the run would end there, and how ("line" when
##   the round is covered but his Roots outnumber Jekyll's).
##
## It is worked out by playing the cards on a copy of the run, so it cannot drift from the
## rules. Only what does not depend on chance is reported, and the copy is given another
## seed so that nothing of the real draws to come can show.
##
## A table that hides the score before a play does not draw `ev.score`, `score_to`,
## `meets_target`, `result`, `rescue`, `pay`, `offers_card`, `stance_to` (when it follows
## from a win or a rescue), `line`, `ends_run`, `ending` or `ended_by`. Everything else here
## does not depend on the score.
static func preview(run: RulesRun, ids: Array) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	var sim := run.copy()
	sim.seed = 0
	var res := Rules.play(sim, ids)
	if not res.ok:
		return {"ok": false, "reason": res.reason}
	var ev: Dictionary = res.ev
	var breakout: Variant = null
	var turns: Array = []
	for e: Dictionary in res.events:
		if e.t == "breakout":
			breakout = {"first": e.ev.first, "added": e.ev.added}
		elif e.t == "turn":
			turns.append({"id": ev.turns[turns.size()], "sym": e.sym, "gain": e.gain, "temper_to": e.temper})
	var adds: bool = run.stance == "jekyll" and ev.adds_restraint
	var craving := {}
	for sym: String in ev.craving_on:
		craving[sym] = {
			"adds": ev.craving_on[sym], "to": sim.craving[sym],
			"copies": int(sim.habit[sym]) - run.habit[sym], "habit_to": sim.habit[sym],
		}
	var ended: bool = sim.phase != "play"
	var last: Dictionary = sim.last if ended else {}
	var result := "goes_on"
	if ended:
		result = last.how
	var rescue: Variant = null
	if ended and last.has("rescue"):
		var info: Dictionary = last.rescue
		rescue = {
			"k": info.k, "ids": info.ids, "names": info.names, "pool": info.pool, "factor": info.factor,
			"score": sim.score, "ok": last.how == "rescued",
		}
	var active: Array = []
	for id: int in ids:
		var c := Rules.card(run, id)
		if c.is_root() and c.ink == (run.stance == "hyde"):
			active.append(c)
	var li := Rules.line_info(sim)
	var score_to: int = run.score + int(ev.score)
	var risk := _at_risk(run, ids) if run.plays == 1 else {"ids": null, "breaks_at": -1}
	return {
		"ok": true, "reason": "", "ev": ev,
		"base": {"chips": ev.steps[0].chips, "mult": ev.steps[0].mult},
		"at_risk": risk.ids, "line_breaks_at": risk.breaks_at,
		"restraint": {
			"adds": adds, "to": run.restraint + (1 if adds else 0), "limit": Rules.limit(run),
			"breaks_out": breakout != null,
		},
		"breakout": breakout,
		"craving": craving,
		"turns": turns,
		"best_root": -1 if active.is_empty() else RulesHands.best_root(run, active).id,
		"score_to": score_to, "target": Rules.target(run), "meets_target": score_to >= Rules.target(run),
		"last_play": run.plays == 1,
		"result": result,
		"rescue": rescue,
		"pay": last.get("pay", 0),
		"offers_card": sim.offer != null,
		"stance_to": sim.stance,
		"line": {"ink": li.ink, "paper": li.paper, "over": li.over},
		"ends_run": sim.phase == "end", "ending": sim.ending, "ended_by": sim.ended_by,
	}


# The Roots at risk on a last play, and where the line would break, as {ids, breaks_at}.
# The play is made on a copy that can neither win nor fall short, so what it shows is the
# table after the play and any breakout, before a rescue, whatever the score.
static func _at_risk(run: RulesRun, ids: Array) -> Dictionary:
	var sim := run.copy()
	sim.seed = 0
	sim.plays = 2
	sim.score = -(1 << 40)
	var held: Array = run.hand.filter(func(id: int) -> bool: return not ids.has(id))
	Rules.play(sim, ids)
	var pool: Array = Rules.rescue_pool(sim, held).map(func(c: RulesCard) -> int: return c.id)
	var li := Rules.line_info(sim)
	var ink: int = int(li.ink) + (0 if sim.hyde_arrived else RulesConfig.FIRST_ARRIVAL.size())
	var paper: int = li.paper
	var breaks_at := -1
	for i in pool.size():
		if ink + i + 1 > paper - i - 1:
			breaks_at = i
			break
	return {"ids": pool, "breaks_at": breaks_at}
