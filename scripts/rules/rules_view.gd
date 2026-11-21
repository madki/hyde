class_name RulesView
## What a table shows before a move, so that no rule is worked out in the UI. Both queries
## only read: they do not change the run and do not move its generator on.


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
## - `hand`: for each card {id, t, key, ink, name, chips, playable, turnable}: whether the
##   man at the table can play it, and for an Ink Root whether Jekyll can turn it now.
## - `can_pass`: {ok, why}.
## - `night`: {no, title, round, scene, target, targets, twist, twist_text, twist_now,
##   dawn: {brings, brings_name, unlocks, unlocks_name, place, last, ends}}: the scene's
##   twist, known from round 1, and what the dawn after it brings.
## - `notebook`: null without the Notebook, else the top cards of the draw pile, next first
##   (three at most), each {id, name, ink}.
static func table(run: Dictionary, chosen: Array = []) -> Dictionary:
	var stance: String = run.stance
	var playing: bool = run.phase == "play"
	var drink := Rules.can_drink(run)
	var salt := Rules.can_salt(run)
	var symbols := {}
	for sym in RulesConfig.ROOTS:
		symbols[sym] = {
			"craving": run.craving[sym], "habit": run.habit[sym], "temper": run.temper[sym],
			"paper": Rules.count_roots(run, false, sym), "ink": Rules.count_roots(run, true, sym),
			"paper_chips": Rules.chips_of(run, {"t": "root", "sym": sym, "ink": false}),
			"ink_chips": Rules.chips_of(run, {"t": "root", "sym": sym, "ink": true}),
		}
	var hand: Array = []
	for id: int in run.hand:
		var c := Rules.card(run, id)
		var turnable: bool = stance == "jekyll" and Rules.is_ink(c) and Rules._hand_has(run, c.sym, false)
		hand.append({
			"id": id, "t": c.t, "key": c.kind if c.t == "factor" else c.sym, "ink": c.t == "root" and c.ink,
			"name": Rules.name_of(c, stance), "chips": Rules.chips_of(run, c),
			"playable": playing and (c.t == "factor" or c.ink == (stance == "hyde") or turnable),
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


static func _night(run: Dictionary) -> Dictionary:
	var night := Rules.night_of(run)
	var last_night: bool = int(run.night) == Rules.night_count() - 1
	var brings: String = night.brings
	if brings == "habit":
		brings = Rules.highest_habit(run)
	var unlocks: String = night.unlocks
	return {
		"no": int(run.night) + 1, "title": night.title, "round": int(run.round) + 1, "scene": Rules.is_scene(run),
		"target": Rules.target(run), "targets": RulesConfig.targets(run.dials, run.night),
		"twist": night.twist, "twist_text": night.twist_text, "twist_now": Rules.twist_now(run) != "",
		"dawn": {
			# Two copies of this Ink Root join. For night 3 it is his highest-Habit Root as
			# the gauges stand now.
			"brings": brings, "brings_name": RulesConfig.ROOT[brings].ink if brings != "" else "",
			"by_habit": night.brings == "habit",
			"unlocks": unlocks, "unlocks_name": RulesConfig.FACTOR[unlocks].paper if unlocks != "" else "",
			# Where the dawn is spent if the scene ends in the present stance.
			"place": "" if last_night else ("alley" if run.stance == "hyde" else "lab"),
			"last": int(run.night) == Rules.night_count() - 2,
			"ends": last_night,
		},
	}


## What playing these hand cards would do. {ok: false, reason} if the play is not allowed.
## Otherwise:
##
## - `ev`: the reading (RulesHands.evaluate): the hand's name, chips, mult and score with
##   their parts, `spends_stored`, `cheque`, `draws`, `no_craving`.
## - `restraint`: {adds, to, limit, breaks_out}. `to` is the meter if he does not break out.
## - `breakout`: null, or {first, added}: whether it is his first arrival (his first four
##   Roots join) and the symbols of the two Ink Roots that join besides.
## - `craving`: for each symbol the play adds to: {adds, to, copies, habit_to}.
## - `turns`: for each Ink Root turned, in order: {id, sym, gain, temper_to}.
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
static func preview(run: Dictionary, ids: Array) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	var sim: Dictionary = run.duplicate(true)
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
			"copies": int(sim.habit[sym]) - int(run.habit[sym]), "habit_to": sim.habit[sym],
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
	var li := Rules.line_info(sim)
	var score_to: int = int(run.score) + int(ev.score)
	return {
		"ok": true, "reason": "", "ev": ev,
		"restraint": {
			"adds": adds, "to": int(run.restraint) + (1 if adds else 0), "limit": Rules.limit(run),
			"breaks_out": breakout != null,
		},
		"breakout": breakout,
		"craving": craving,
		"turns": turns,
		"score_to": score_to, "target": Rules.target(run), "meets_target": score_to >= Rules.target(run),
		"last_play": int(run.plays) == 1,
		"result": result,
		"rescue": rescue,
		"pay": last.get("pay", 0),
		"offers_card": sim.offer != null,
		"stance_to": sim.stance,
		"line": {"ink": li.ink, "paper": li.paper, "over": li.over},
		"ends_run": sim.phase == "end", "ending": sim.ending, "ended_by": sim.ended_by,
	}
