class_name Rules
## The card game's rules, as pure logic with no nodes. Every function takes the run first:
## a RulesRun, which holds the whole state and saves as JSON (to_json, from_json), so a run
## can be replayed from its seed and its moves.
##
## A move returns {ok: true, ...} or {ok: false, reason}. start_round, play, discard,
## pass_play, drink and take_salt (and continue_result, alley_leave and leave_lab, which start
## a round) also return `events`: what the move did, in the order the rules did it, so that a
## table can play it back card by card. Each event is a Dictionary with its type in `t`:
##
## - shuffle {ids}: the deck shuffled into the draw pile at a round's start (top last).
## - drawn {why, ids}: cards drawn to the hand, in order. `why` is "deal", "refill" or
##   "draws" (one more for each Curiosity or Impulse).
## - reshuffle {ids}: the discards turned into the draw pile, as it now lies (top last),
##   placed among the draws where it happened.
## - scored {score, to}: a play's score, and the round's after it.
## - stored_spent {n, mult}: his stored restraint paid into a play.
## - craving {sym, n}, breed {sym, habit, id, at}: Craving rose; a rollover's copy joined the
##   draw pile at place `at`.
## - cheque {sov}: the Cheque book paid 1.
## - turn {id, sym, gain, temper}: a Sublimation turned an Ink Root.
## - restraint {n}: the meter after a step.
## - discarded {why, ids}: cards from the hand to the discards ("play" or "discard").
## - shift {ev} (a drink, night 4's window, salt) and breakout {ev} (a breakout or walking in
##   full): the stance changes. `ev` is the shift's record (to, how, stored, lost_restraint,
##   lost_stored, first, added, stained, brought).
## - joined {why, cards: [{id, sym, at}]}: Ink Roots join the deck. `why` is "first" (his
##   first four), "breakout" (a breakout's two), "stain" (a drink with nothing left to
##   stain), "reward" (the card taken after a round, which may be any card: see `key`) or
##   "dawn" (the two the dawn brings). `at` is the place in the draw pile,
##   or -1 when the card goes into no pile.
## - stained {id, sym, from}: a Paper Root turned to ink where it lay.
## - brought {who, cards: [{id, sym, from}]}: Roots brought to the hand by whoever arrived,
##   each from "draw" or "discard".
## - rescue {prior, last, target, k}, then converted {id, sym, score} for each Root taken,
##   in order, with the round's score after it.
## - round_end {how, broke_out, pay, plays_left, score, target, stance, was, first, ink,
##   paper, over, offers_card, ending, ended_by}: the round won, rescued or lost, the line
##   as it then stands, and whether a card is offered. The piles are gathered.
##
## The names of things are in
## RulesConfig, the numbers in RulesDials, the reading of a play in RulesHands, and what a
## table shows in RulesView.

const PHASES: Array[String] = ["play", "result", "alley", "lab", "end"]


# ---------- a run ----------

## A new run, dealt and ready for its first play. `changes` replaces numbers of RulesDials.
## With no seed, a random one is taken.
static func new_run(changes: Dictionary = {}, seed_value: Variant = null) -> RulesRun:
	var run := RulesRun.new()
	run.dials = RulesDials.make(changes)
	run.seed = RulesRng.wrap_seed(randi() % 2147483647 if seed_value == null else int(seed_value))
	run.seed0 = run.seed
	run.salt = run.dials.salt_start
	for key in RulesConfig.STARTING_DECK:
		run.cards.append(make_card(run, key, false))
	start_round(run)
	return run


## The run as JSON text.
static func to_json(run: RulesRun) -> String:
	return JSON.stringify(run.to_dict())


## A run read back from to_json's text, or null if the text is not one. JSON has one kind
## of number, so every whole number is made an int again.
static func from_json(text: String) -> RulesRun:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data: Variant = _whole_numbers(json.data)
	if not RulesRun.is_run_data(data):
		return null
	return RulesRun.from_dict(data)


static func _whole_numbers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if f == floor(f) and absf(f) < 9.0e15 else f
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				a[i] = _whole_numbers(a[i])
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k: Variant in d:
				d[k] = _whole_numbers(d[k])
	return v


# ---------- small helpers ----------

static func night_of(run: RulesRun) -> Dictionary:
	return RulesConfig.NIGHTS[run.night]


static func night_count() -> int:
	return RulesConfig.NIGHTS.size()


static func is_scene(run: RulesRun) -> bool:
	return run.round == 2


## The twist in force now: the night's, in its scene only. "" for none.
static func twist_now(run: RulesRun) -> String:
	return night_of(run).twist if is_scene(run) else ""


## The score this round must reach.
static func target(run: RulesRun) -> int:
	return RulesConfig.targets(run.dials, run.night)[run.round]


static func has_inst(run: RulesRun, key: String) -> bool:
	return run.instruments.has(key)


## The restraint limit of this night's scene (`scene` true) or of its ordinary rounds.
static func limit_for(run: RulesRun, scene: bool) -> int:
	var d := run.dials
	var most: int = d.restraint_limit + (d.balance_bonus if has_inst(run, "balance") else 0)
	if scene and night_of(run).twist == "tight":
		most = maxi(1, most - d.tight_drop)
	return most


## The restraint limit of this round.
static func limit(run: RulesRun) -> int:
	return limit_for(run, is_scene(run))


## How many Ink Roots one Sublimation may turn.
static func turn_cap(run: RulesRun) -> int:
	return 2 if has_inst(run, "saucers") else 1


## The card with this id, or null if the deck has none.
static func card(run: RulesRun, id: int) -> RulesCard:
	for c: RulesCard in run.cards:
		if c.id == id:
			return c
	return null


static func is_root(c: RulesCard) -> bool:
	return c.is_root()


static func is_ink(c: RulesCard) -> bool:
	return c.is_ink()


static func is_paper(c: RulesCard) -> bool:
	return c.is_paper()


static func is_factor(c: RulesCard) -> bool:
	return c.is_factor()


## A Root has one name for good. A Factor is named by whoever has the table.
static func name_of(c: RulesCard, stance: String) -> String:
	if c.is_root():
		return RulesConfig.ROOT[c.sym].ink if c.ink else RulesConfig.ROOT[c.sym].paper
	return RulesConfig.FACTOR[c.kind].ink if stance == "hyde" else RulesConfig.FACTOR[c.kind].paper


## The name of a symbol's Root or of a Factor, on its ink or its paper side.
static func key_name(key: String, ink: bool) -> String:
	var entry: Dictionary = RulesConfig.ROOT[key] if RulesConfig.ROOT.has(key) else RulesConfig.FACTOR[key]
	return entry.ink if ink else entry.paper


## The chips a card is worth now. `craving`, if given, is used in place of its symbol's.
static func chips_of(run: RulesRun, c: RulesCard, craving: int = -1) -> int:
	var d := run.dials
	if c.is_factor():
		return d.factor_chips
	if c.ink:
		var points: int = run.craving[c.sym] if craving < 0 else craving
		return d.root_chips + d.craving_chips * points + d.habit_chips * run.habit[c.sym]
	return d.root_chips + d.temper_chips * run.temper[c.sym]


## How many Roots of a side the deck holds, of one symbol or ("") of all.
static func count_roots(run: RulesRun, ink: bool, sym: String = "") -> int:
	var n := 0
	for c: RulesCard in run.cards:
		if c.is_root() and c.ink == ink and (sym == "" or c.sym == sym):
			n += 1
	return n


## The line: the run is lost when Ink Roots outnumber Paper Roots at the end of a round.
## A tie holds, and Factors count for neither side.
static func line_info(run: RulesRun) -> Dictionary:
	var ink := count_roots(run, true)
	var paper := count_roots(run, false)
	return {"ink": ink, "paper": paper, "total": run.cards.size(), "cushion": paper - ink, "over": ink > paper}


## A new card with the next id. It is not put in the deck.
static func make_card(run: RulesRun, key: String, ink: bool) -> RulesCard:
	run.uid += 1
	return RulesCard.make(run.uid, key, ink)


## Adds a new card to the deck. During a round it goes into the draw pile at a random place:
## `place_of` gives it.
static func add_card(run: RulesRun, key: String, ink: bool, mid_round: bool) -> RulesCard:
	var c := make_card(run, key, ink)
	run.cards.append(c)
	if mid_round:
		var draw: Array = run.draw
		draw.insert(RulesRng.below(run, draw.size() + 1), c.id)
	return c


# A card that joins, as its events give it: {id, sym, at}, `at` its place in the draw pile
# just after it was put there (later cards put in may move it on).
static func _joined(run: RulesRun, c: RulesCard) -> Dictionary:
	return {"id": c.id, "sym": c.sym, "at": run.draw.find(c.id)}


## A sorted copy: by the list of numbers `keys` gives for each item, smallest first. Items
## with the same numbers keep their order.
static func sort_by(items: Array, keys: Callable) -> Array:
	var out: Array = []
	var ranks: Array = []
	for item: Variant in items:
		var k: Array = keys.call(item)
		var i := out.size()
		while i > 0 and _before(k, ranks[i - 1]):
			i -= 1
		out.insert(i, item)
		ranks.insert(i, k)
	return out


static func _before(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


# ---------- dealing ----------

## Draws the top card. An empty draw pile is first rebuilt from the shuffled discards.
## Returns the card's id, or -1 if there is nothing to draw.
## `why` names the draw in its event: "deal", "refill" or "draws".
static func draw_one(run: RulesRun, why: String = "refill") -> int:
	if run.draw.is_empty():
		if run.discard.is_empty():
			return -1
		run.draw = RulesRng.shuffle(run, run.discard)
		run.discard = []
		_emit(run, {"t": "reshuffle", "ids": run.draw.duplicate()})
	var id: int = run.draw.pop_back()
	run.hand.append(id)
	var last: Variant = run.events.back() if not run.events.is_empty() else null
	if last != null and last.t == "drawn" and last.why == why:
		last.ids.append(id)
	else:
		_emit(run, {"t": "drawn", "why": why, "ids": [id]})
	return id


static func refill(run: RulesRun, why: String = "refill") -> void:
	while run.hand.size() < run.dials.hand_size:
		if draw_one(run, why) < 0:
			break


# Starts the events of a move and returns the list.
static func _begin(run: RulesRun) -> Array:
	run.events = []
	return run.events


static func _emit(run: RulesRun, e: Dictionary) -> void:
	run.events.append(e)


## Begins the round `run.night` and `run.round` point at: shuffles the whole deck, deals, and
## applies what comes before the first play (night 4's forced shift, walking in full).
## Returns {ok, events}.
static func start_round(run: RulesRun) -> Dictionary:
	var events := _begin(run)
	var d := run.dials
	run.score = 0
	run.plays = d.plays
	run.discards = d.discards + (1 if has_inst(run, "spirit") else 0)
	var ids: Array = []
	for c: RulesCard in run.cards:
		ids.append(c.id)
	run.draw = RulesRng.shuffle(run, ids)
	_emit(run, {"t": "shuffle", "ids": run.draw.duplicate()})
	run.hand = []
	run.discard = []
	run.phase = "play"
	run.log = []
	run.offer = null
	run.alley = null
	run.shop = null
	run.dawn = null
	refill(run, "deal")
	# Night 4: the scene begins as Hyde, whoever ended round 2. The shift stains nothing.
	if twist_now(run) == "window" and run.stance == "jekyll":
		var ev := _arrive(run, "window")
		ev.brought = _bring_roots(run)
		run.log.append(ev)
	# Walking in full: Jekyll enters with the meter at or over this round's limit, and he
	# breaks out before the first play.
	if run.stance == "jekyll" and run.restraint >= limit(run):
		var ev := _break_out(run, "walkedin")
		ev.brought = _bring_roots(run)
	return {"ok": true, "events": events}


# ---------- the two stances ----------

static func _pile_count(run: RulesRun, sym: String, ink: bool) -> int:
	var n := 0
	for pile: Array in [run.draw, run.discard]:
		for id: int in pile:
			var c := card(run, id)
			if c.is_root() and c.sym == sym and c.ink == ink:
				n += 1
	return n


static func _hand_has(run: RulesRun, sym: String, ink: bool) -> bool:
	for id: int in run.hand:
		var c := card(run, id)
		if c.is_root() and c.sym == sym and c.ink == ink:
			return true
	return false


# Moves one such Root into the hand: from the draw pile, or from the discards if the draw
# pile has none. Each pile is searched from its end. Returns its id, or -1, and adds
# {id, sym, from} to `moved`.
static func _pull(run: RulesRun, sym: String, ink: bool, moved: Array) -> int:
	for named: Array in [["draw", run.draw], ["discard", run.discard]]:
		var pile: Array = named[1]
		var i := pile.size() - 1
		while i >= 0:
			var c := card(run, pile[i])
			if c.is_root() and c.sym == sym and c.ink == ink:
				pile.remove_at(i)
				run.hand.append(c.id)
				moved.append({"id": c.id, "sym": c.sym, "from": named[0]})
				return c.id
			i -= 1
	return -1


# Whoever arrives brings up to two of his Roots into the hand.
# Hyde: a matching pair if the piles hold one (most Habit, then most copies there);
# otherwise one each of two symbols (one he already holds first, then most Habit).
# Jekyll: one each of two symbols (one his hand lacks first, then one whose Ink twin he holds).
# Remaining ties go Lamp, Heart, Mirror.
static func _bring_roots(run: RulesRun) -> Array:
	var out: Array = []
	var moved: Array = []
	_emit(run, {"t": "brought", "who": run.stance, "cards": moved})
	var ink: bool = run.stance == "hyde"
	var roots := RulesConfig.ROOTS
	var avail: Array = []
	for sym in roots:
		if _pile_count(run, sym, ink) > 0:
			avail.append(sym)
	if ink:
		var pairs: Array = []
		for sym: String in avail:
			if _pile_count(run, sym, true) >= 2:
				pairs.append(sym)
		if not pairs.is_empty():
			pairs = sort_by(pairs, func(s: String) -> Array:
				return [-run.habit[s], -_pile_count(run, s, true), roots.find(s)])
			out.append(_pull(run, pairs[0], true, moved))
			out.append(_pull(run, pairs[0], true, moved))
			return out
		avail = sort_by(avail, func(s: String) -> Array:
			return [-int(_hand_has(run, s, true)), -run.habit[s], roots.find(s)])
	else:
		avail = sort_by(avail, func(s: String) -> Array:
			return [int(_hand_has(run, s, false)), -int(_hand_has(run, s, true)), roots.find(s)])
	for sym: String in avail.slice(0, 2):
		out.append(_pull(run, sym, ink, moved))
	return out


# A stain: one Paper Root becomes its Ink twin for good, where it lies. The draw pile is
# looked in first, then the discards, then the hand. If one of his three Roots has no copy
# anywhere in the deck and its twin is in that pile, that twin goes first. With no Paper
# Root anywhere, one Ink Root of a random symbol joins the draw pile.
static func _stain_one(run: RulesRun) -> Dictionary:
	var roots := RulesConfig.ROOTS
	var pools := [["draw", run.draw], ["discard", run.discard], ["hand", run.hand]]
	for pool: Array in pools:
		var papers: Array = []
		for id: int in pool[1]:
			var c := card(run, id)
			if is_paper(c):
				papers.append(c)
		if papers.is_empty():
			continue
		var missing := ""
		for sym in roots:
			if missing == "" and count_roots(run, true, sym) == 0 and RulesHands._has_sym(papers, sym):
				missing = sym
		var taken: RulesCard = null
		if missing != "":
			var i := papers.size() - 1
			while i >= 0:
				if papers[i].sym == missing:
					taken = papers[i]
					break
				i -= 1
		else:
			taken = papers[RulesRng.below(run, papers.size())]
		taken.ink = true
		_emit(run, {"t": "stained", "id": taken.id, "sym": taken.sym, "from": pool[0]})
		return {"id": taken.id, "sym": taken.sym, "from": pool[0], "added": false}
	var added: String = roots[RulesRng.below(run, roots.size())]
	var c := add_card(run, added, true, true)
	_emit(run, {"t": "joined", "why": "stain", "cards": [_joined(run, c)]})
	return {"id": null, "sym": added, "from": "none", "added": true}


## His symbols with the fewest Ink Roots in the deck: the ones a breakout adds a copy of.
static func lowest_two(run: RulesRun) -> Array:
	var roots := RulesConfig.ROOTS
	return sort_by(roots, func(s: String) -> Array: return [count_roots(run, true, s), roots.find(s)]) \
			.slice(0, run.dials.breakout_roots)


# Jekyll to Hyde, by any road: "drink", "window" (night 4's scene), "breakout" or "walkedin".
# Does everything but bring his two Roots, because a breakout that wins the round brings none.
static func _arrive(run: RulesRun, how: String) -> Dictionary:
	var ev := {
		"t": "shift", "to": "hyde", "how": how, "stored": 0, "lost_restraint": 0, "first": false,
		"brought": [], "stained": null, "added": [],
	}
	_emit(run, {"t": "breakout" if how == "breakout" or how == "walkedin" else "shift", "ev": ev})
	if how == "drink" or how == "window":
		run.stored = run.restraint
		ev.stored = run.stored
	else:
		# A breakout empties the meter and pays nothing.
		run.stored = 0
		ev.lost_restraint = run.restraint
	run.restraint = 0
	run.stance = "hyde"
	if not run.hyde_arrived:
		run.hyde_arrived = true
		ev.first = true
		var joined: Array = []
		for sym in RulesConfig.FIRST_ARRIVAL:
			joined.append(_joined(run, add_card(run, sym, true, true)))
		_emit(run, {"t": "joined", "why": "first", "cards": joined})
	elif how == "drink":
		ev.stained = _stain_one(run)
		if not ev.stained.added:
			run.stats.stains += 1
	# A breakout adds a copy of each of his two lowest-count Roots, counted after any
	# first-arrival cards.
	if how == "breakout" or how == "walkedin":
		var joined: Array = []
		for sym: String in lowest_two(run):
			joined.append(_joined(run, add_card(run, sym, true, true)))
			ev.added.append(sym)
		_emit(run, {"t": "joined", "why": "breakout", "cards": joined})
	return ev


static func _break_out(run: RulesRun, how: String) -> Dictionary:
	var ev := _arrive(run, how)
	run.stats.breakouts += 1
	run.log.append(ev)
	return ev


## Whether the draught can be drunk now: {ok, why}.
static func can_drink(run: RulesRun) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if run.stance != "jekyll":
		return {"ok": false, "why": "He already has the table."}
	if run.night == 0 and run.round == 0:
		return {"ok": false, "why": "The draught does not exist yet."}
	if twist_now(run) == "last":
		return {"ok": false, "why": "No draught works in this scene."}
	return {"ok": true, "why": ""}


## Whether a dose of salt can be taken now: {ok, why}.
static func can_salt(run: RulesRun) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if run.stance != "hyde":
		return {"ok": false, "why": "You are yourself."}
	var from: int = run.dials.salt_from
	if run.night * 3 + run.round < from:
		@warning_ignore("integer_division")
		var night: int = from / 3 + 1
		return {"ok": false, "why": "The salt comes with the scene." if from == 2 else "The salt comes on night %d." % night}
	if twist_now(run) == "last":
		return {"ok": false, "why": "No salt works in this scene."}
	if run.salt <= 0:
		return {"ok": false, "why": "No doses left."}
	return {"ok": true, "why": ""}


## What the next drink costs: "first" (his first four Roots join) or "stain".
static func drink_cost(run: RulesRun) -> String:
	return "stain" if run.hyde_arrived else "first"


## Jekyll to Hyde. The meter is stored, his first Roots join or a Paper Root is stained,
## and he brings two Roots.
static func drink(run: RulesRun) -> Dictionary:
	var c := can_drink(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	var events := _begin(run)
	run.stats.drinks += 1
	var ev := _arrive(run, "drink")
	ev.brought = _bring_roots(run)
	run.log.append(ev)
	return {"ok": true, "ev": ev, "events": events}


## Hyde to Jekyll. One dose is spent, restraint is 0, stored restraint is lost, and Jekyll
## brings two Roots.
static func take_salt(run: RulesRun) -> Dictionary:
	var c := can_salt(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	var events := _begin(run)
	run.salt -= 1
	run.stats.salts += 1
	var ev := {"t": "shift", "to": "jekyll", "how": "salt", "stored": 0, "lost_stored": run.stored, "first": false, "brought": []}
	_emit(run, {"t": "shift", "ev": ev})
	run.stance = "jekyll"
	run.restraint = 0
	run.stored = 0
	ev.brought = _bring_roots(run)
	run.log.append(ev)
	return {"ok": true, "ev": ev, "events": events}


# ---------- playing ----------

## Reads a play without making it: see RulesHands.evaluate.
static func evaluate(run: RulesRun, cards: Array) -> Dictionary:
	return RulesHands.evaluate(run, cards)


## The highest-scoring allowed play in the hand: see RulesHands.best.
static func best(run: RulesRun, filter: Callable = Callable()) -> Dictionary:
	return RulesHands.best(run, filter)


# One to any number of different card ids, all in the hand.
static func _in_hand(run: RulesRun, ids: Array) -> bool:
	if ids.is_empty():
		return false
	var seen := {}
	for id: int in ids:
		if seen.has(id) or not run.hand.has(id):
			return false
		seen[id] = true
	return true


static func _to_discards(run: RulesRun, ids: Array, why: String) -> void:
	_emit(run, {"t": "discarded", "why": why, "ids": ids.duplicate()})
	for id: int in ids:
		run.hand.erase(id)
		run.discard.append(id)


## Plays these cards of the hand. Returns {ok, ev (the reading), events, stance (who played),
## phase (after the play)}.
static func play(run: RulesRun, ids: Array) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	if not _in_hand(run, ids):
		return {"ok": false, "reason": "Choose cards for a hand."}
	var cards: Array = []
	for id: int in ids:
		cards.append(card(run, id))
	var ev := RulesHands.evaluate(run, cards)
	if not ev.ok:
		return {"ok": false, "reason": ev.reason}
	var d := run.dials
	var st: String = run.stance
	var out := {"ok": true, "ev": ev, "events": _begin(run), "stance": st, "phase": ""}
	var stats: Dictionary = run.stats
	# 1. The score.
	run.plays -= 1
	run.score += int(ev.score)
	_emit(run, {"t": "scored", "score": ev.score, "to": run.score})
	var entry := {"t": "play", "who": st, "name": ev.name, "key": ev.key, "chips": ev.chips, "mult": ev.mult, "score": ev.score, "notes": []}
	if int(ev.score) > int(stats.best):
		stats.best = ev.score
		stats.best_name = ev.name
	# 2. What the play does.
	if st == "hyde":
		stats.hyde_hands += 1
		if ev.kind == "hand":
			if run.stored > 0:
				entry.notes.append("stored restraint paid +%d mult" % (run.stored * d.restraint_pay))
				_emit(run, {"t": "stored_spent", "n": run.stored, "mult": run.stored * d.restraint_pay})
				run.stored = 0
			for sym in RulesConfig.ROOTS:
				if not ev.craving_on.has(sym):
					continue
				run.craving[sym] += int(ev.craving_on[sym])
				# Rollover: the Habit rises and a copy joins the draw pile.
				while run.craving[sym] >= d.craving_cap:
					run.craving[sym] -= d.craving_cap
					run.habit[sym] += 1
					var copy := add_card(run, sym, true, true)
					stats.bred += 1
					_emit(run, {"t": "breed", "sym": sym, "habit": run.habit[sym], "id": copy.id, "at": run.draw.find(copy.id)})
					entry.notes.append("%s became a Habit and left a copy" % RulesConfig.ROOT[sym].ink)
				_emit(run, {"t": "craving", "sym": sym, "n": run.craving[sym]})
			if ev.no_craving:
				entry.notes.append("no Craving")
			if has_inst(run, "cheque"):
				run.sov += 1
				_emit(run, {"t": "cheque", "sov": run.sov})
				entry.notes.append("Cheque book paid 1")
	else:
		stats.jekyll_hands += 1
		if ev.kind == "sublimation":
			for id: int in ev.turns:
				var c := card(run, id)
				var sym: String = c.sym
				var gain: int = run.craving[sym]
				run.temper[sym] += gain
				run.craving[sym] = 0
				c.ink = false
				stats.turns += 1
				stats.temper += gain
				_emit(run, {"t": "turn", "id": id, "sym": sym, "gain": gain, "temper": run.temper[sym]})
				entry.notes.append("%s turned to %s%s" % [RulesConfig.ROOT[sym].ink, RulesConfig.ROOT[sym].paper, ", Temper +%d" % gain if gain > 0 else ""])
		elif ev.adds_restraint:
			run.restraint += 1
			_emit(run, {"t": "restraint", "n": run.restraint})
		else:
			entry.notes.append("no restraint")
	# 3. The played cards leave. What stays in hand now is what a rescue may convert.
	_to_discards(run, ids, "play")
	var held: Array = run.hand.duplicate()
	refill(run)
	for i in int(ev.draws):
		draw_one(run, "draws")
	run.log.append(entry)
	_settle(run, st, int(ev.score), str(ev.name), held, out)
	out.phase = run.phase
	return out


# The end of a play: the breakout, the win, and the last play that falls short.
static func _settle(run: RulesRun, st: String, last_score: int, last_name: String, held: Array, out: Dictionary) -> void:
	if st == "jekyll" and run.restraint >= limit(run):
		var bo := _break_out(run, "breakout")
		if run.score >= target(run):
			# Won, in his stance: he brings no Roots.
			_end_round(run, {"how": "won", "broke_out": true})
			return
		bo.brought = _bring_roots(run)
	if run.score >= target(run):
		_end_round(run, {"how": "won"})
		return
	if run.plays <= 0:
		_rescue(run, last_score, last_name, held)


## Throws away 1 to 5 cards of the hand and refills it. Uses one of the round's discards.
static func discard(run: RulesRun, ids: Array) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	if run.discards <= 0:
		return {"ok": false, "reason": "No discards left."}
	if not _in_hand(run, ids):
		return {"ok": false, "reason": "Choose cards to discard."}
	if ids.size() > run.dials.max_play:
		return {"ok": false, "reason": "Discard up to %d cards." % run.dials.max_play}
	var events := _begin(run)
	run.discards -= 1
	_to_discards(run, ids, "discard")
	refill(run)
	run.log.append({"t": "discard", "n": ids.size()})
	return {"ok": true, "events": events}


## Whether the hand holds anything the man at the table can play: a Factor or a Root of his.
static func has_play(run: RulesRun) -> bool:
	var ink: bool = run.stance == "hyde"
	for id: int in run.hand:
		var c := card(run, id)
		if c.is_factor() or c.ink == ink:
			return true
	return false


## Whether the play can be passed: {ok, why}. Only with nothing to play and no discards left,
## or with an empty hand, which leaves nothing to discard either.
static func can_pass(run: RulesRun) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if has_play(run):
		return {"ok": false, "why": "A card in hand can be played."}
	if run.discards > 0 and not run.hand.is_empty():
		return {"ok": false, "why": "Discard first."}
	return {"ok": true, "why": ""}


## Passes a play. It uses a play and scores nothing, and as Jekyll it adds restraint.
static func pass_play(run: RulesRun) -> Dictionary:
	var c := can_pass(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	var st: String = run.stance
	var out := {"ok": true, "events": _begin(run), "stance": st, "passed": true, "phase": ""}
	run.plays -= 1
	run.stats.passes += 1
	if st == "jekyll":
		run.restraint += 1
		_emit(run, {"t": "restraint", "n": run.restraint})
	run.log.append({"t": "play", "who": st, "name": "No play", "key": "pass", "chips": 0, "mult": 0, "score": 0, "notes": ["nothing in hand could be played"]})
	_settle(run, st, 0, "No play", run.hand.duplicate(), out)
	out.phase = run.phase
	return out


# ---------- the rescue ----------

## The rescue of a last play that falls short, worked out but not applied. `prior` is the
## round's score before that play, `last` the play's score, `held_ids` the cards left in hand
## when its cards leave (before the refill), `breaks_out` whether that play also fills the
## meter. He converts held Paper Roots to their Ink twins, lowest Temper first, then Lamp,
## Heart, Mirror. Each one doubles the last play, and he stops when the target is met.
## Returns {k, ids, pool, factor, score, ok, ink, paper, over}: the Roots taken, the score
## reached and whether it covers the round, and the line as it would then stand.
static func plan_rescue(run: RulesRun, prior: int, last: int, held_ids: Array, breaks_out: bool) -> Dictionary:
	var goal := target(run)
	var pool := rescue_pool(run, held_ids)
	var k := 0
	while prior + last * (1 << k) < goal and k < pool.size():
		k += 1
	var reached: int = prior + last * (1 << k)
	# Roots that join with him if this is also his first arrival, or if the play also
	# fills the meter.
	var extra: int = (0 if run.hyde_arrived else RulesConfig.FIRST_ARRIVAL.size()) + (mini(run.dials.breakout_roots, RulesConfig.ROOTS.size()) if breaks_out else 0)
	var li := line_info(run)
	var ink: int = int(li.ink) + k + extra
	var paper: int = int(li.paper) - k
	var ids: Array = []
	for c: RulesCard in pool.slice(0, k):
		ids.append(c.id)
	return {
		"k": k, "ids": ids, "pool": pool.size(), "factor": 1 << k, "score": reached, "ok": reached >= goal,
		"ink": ink, "paper": paper, "over": ink > paper,
	}


## The Paper Roots among these held cards in the order a rescue takes them: lowest Temper
## first, then Lamp, Heart, Mirror (then by id). As RulesCard.
static func rescue_pool(run: RulesRun, held_ids: Array) -> Array:
	var papers: Array = []
	for id: int in held_ids:
		var c := card(run, id)
		if c != null and c.is_paper():
			papers.append(c)
	return sort_by(papers, func(c: RulesCard) -> Array:
		return [run.temper[c.sym], RulesConfig.ROOTS.find(c.sym), c.id])


static func _rescue(run: RulesRun, last_score: int, last_name: String, held: Array) -> void:
	var prior: int = run.score - last_score
	var plan := plan_rescue(run, prior, last_score, held, false)
	_emit(run, {"t": "rescue", "prior": prior, "last": last_score, "target": target(run), "k": plan.k})
	var names: Array = []
	for i in plan.ids.size():
		var c := card(run, plan.ids[i])
		names.append([RulesConfig.ROOT[c.sym].paper, RulesConfig.ROOT[c.sym].ink])
		c.ink = true
		_emit(run, {"t": "converted", "id": c.id, "sym": c.sym, "score": prior + last_score * (1 << (i + 1))})
	run.stats.converted += int(plan.k)
	var info := {
		"k": plan.k, "ids": plan.ids, "pool": plan.pool, "names": names, "factor": plan.factor,
		"hand": last_name, "hand_score": last_score, "scored": run.score, "prior": prior,
	}
	run.score = plan.score
	if not plan.ok:
		_end_round(run, {"how": "lost", "reason": "short", "rescue": info})
		return
	var first := false
	if not run.hyde_arrived:
		run.hyde_arrived = true
		first = true
		var joined: Array = []
		for sym in RulesConfig.FIRST_ARRIVAL:
			joined.append(_joined(run, add_card(run, sym, true, false)))
		_emit(run, {"t": "joined", "why": "first", "cards": joined})
	var was: String = run.stance
	var lost: int = run.restraint
	run.stance = "hyde"
	run.restraint = 0
	run.stored = 0
	run.stats.rescues += 1
	_end_round(run, {"how": "rescued", "first": first, "lost_restraint": lost, "was": was, "rescue": info})


## Gives up the run: it ends as Mr Hyde. A convenience, not a rule.
static func give_up(run: RulesRun) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	_end_round(run, {"how": "lost", "reason": "gaveup"})
	return {"ok": true}


# ---------- the end of a round ----------

static func _end_round(run: RulesRun, res: Dictionary) -> void:
	var d := run.dials
	res.night = run.night
	res.round = run.round
	res.score = run.score
	res.target = target(run)
	res.stance = run.stance
	if res.how == "won":
		# A rescued round pays nothing.
		res.plays_left = run.plays
		res.pay = d.round_pay + d.unused_play_pay * run.plays
		run.sov += int(res.pay)
	run.draw = []
	run.hand = []
	run.discard = []
	var li := line_info(run)
	res.ink = li.ink
	res.paper = li.paper
	run.last = res
	run.history.append({
		"night": run.night, "round": run.round, "how": res.how, "reason": res.get("reason", ""),
		"stance": run.stance, "score": res.score, "target": res.target, "ink": li.ink, "paper": li.paper,
	})
	run.offer = null
	if res.how == "lost":
		run.ending = "hyde"
		run.ended_by = res.reason
		run.phase = "end"
		_round_end(run, res)
		return
	# The line is checked at the end of every round, never at dawn.
	if li.over:
		run.ending = "hyde"
		run.ended_by = "line"
		run.phase = "end"
		_round_end(run, res)
		return
	if run.night == night_count() - 1 and is_scene(run):
		run.ending = "double" if run.stance == "hyde" else "myself"
		run.ended_by = "scene"
		run.phase = "end"
		_round_end(run, res)
		return
	# An ordinary round won in Jekyll's stance: one of three different cards, or none.
	if not is_scene(run) and res.how == "won" and run.stance == "jekyll":
		var offers := _pick_offers(run, d.reward_cards)
		if not offers.is_empty():
			run.offer = offers
	run.phase = "result"
	_round_end(run, res)


static func _round_end(run: RulesRun, res: Dictionary) -> void:
	_emit(run, {
		"t": "round_end", "how": res.how, "broke_out": res.get("broke_out", false),
		"pay": res.get("pay", 0), "plays_left": res.get("plays_left", 0),
		"score": res.score, "target": res.target, "stance": res.stance, "was": res.get("was", res.stance),
		"first": res.get("first", false), "ink": res.ink, "paper": res.paper, "over": res.ink > res.paper,
		"offers_card": run.offer != null, "ending": run.ending, "ended_by": run.ended_by,
	})


## Leaves the result of a round, taking the offered card at index `pick` (null: none). Next
## comes the next round, or after a scene the dawn.
## Returns {ok, events}: the card taken (joined, "reward"), then the next round's start or
## the Roots the dawn brings (joined, "dawn").
static func continue_result(run: RulesRun, pick: Variant = null) -> Dictionary:
	if run.phase != "result":
		return {"ok": false, "reason": "Not now."}
	var events: Array = []
	if run.offer != null and pick != null and int(pick) >= 0 and int(pick) < run.offer.size():
		var c := make_card(run, run.offer[int(pick)], false)
		run.cards.append(c)
		events.append({"t": "joined", "why": "reward", "cards": [{"id": c.id, "sym": c.sym, "key": c.key(), "at": -1}]})
	run.offer = null
	if not is_scene(run):
		run.round += 1
		events.append_array(start_round(run).events)
	else:
		_begin(run)
		_enter_dawn(run)
		events.append_array(run.events)
	return {"ok": true, "events": events}


# ---------- what is on offer ----------

## The Factors that can appear in a reward or on the laboratory's shelf.
static func unlocked_factors(run: RulesRun) -> Array:
	var out: Array = []
	for k in RulesConfig.FACTORS:
		if int(RulesConfig.FACTOR[k].unlock) == 0 or run.unlocked[k]:
			out.append(k)
	return out


# Different cards for a reward: the three Paper Roots and every unlocked Factor, by weight,
# drawn one at a time without putting any back.
static func _pick_offers(run: RulesRun, n: int) -> Array:
	var d := run.dials
	var pool: Array = []
	for s in RulesConfig.ROOTS:
		pool.append([s, d.reward_root_weight])
	for k: String in unlocked_factors(run):
		pool.append([k, d.reward_factor_weight])
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total := 0
		for e: Array in pool:
			total += int(e[1])
		var r := RulesRng.next(run) * total
		var i := 0
		while i < pool.size() - 1:
			r -= int(pool[i][1])
			if r < 0:
				break
			i += 1
		out.append(pool[i][0])
		pool.remove_at(i)
	return out


## The price of a dose of salt, in the laboratory ("lab") or the back alley ("alley").
static func salt_cost(run: RulesRun, where: String) -> int:
	var d := run.dials
	return d.salt_price + d.salt_rise * run.doses_bought + (d.alley_markup if where == "alley" else 0)


## His Root with the most Habit. Ties go to the most Craving, then the fewest Ink copies in
## the deck, then Lamp, Heart, Mirror.
static func highest_habit(run: RulesRun) -> String:
	var roots := RulesConfig.ROOTS
	return sort_by(roots, func(s: String) -> Array:
		return [-run.habit[s], -run.craving[s], count_roots(run, true, s), roots.find(s)])[0]


# ---------- dawn ----------

# Dawn: his unasked Roots join and the night's Factor unlocks. Then one place only, by who
# has the table: the laboratory for Jekyll, the back alley for Hyde.
static func _enter_dawn(run: RulesRun) -> void:
	var night := night_of(run)
	run.dawn = {
		"no": run.night + 1, "brings": null, "unlocks": null,
		"last": run.night + 1 >= night_count() - 1, "as_hyde": run.stance == "hyde",
	}
	var sym: String = highest_habit(run) if night.brings == "habit" else night.brings
	if sym != "":
		var joined: Array = []
		for i in 2:
			joined.append(_joined(run, add_card(run, sym, true, false)))
		_emit(run, {"t": "joined", "why": "dawn", "cards": joined})
		run.dawn.brings = sym
	if night.unlocks != "":
		run.unlocked[night.unlocks] = true
		run.dawn.unlocks = night.unlocks
	if run.stance == "hyde":
		_open_alley(run)
	else:
		_open_lab(run)


# The laboratory's Factor: the one that unlocked at this dawn; failing that, an unlocked Pen
# or Cane the deck has no copy of, Pen first; failing that, any unlocked Factor at random.
static func _lab_factor(run: RulesRun) -> String:
	var night := night_of(run)
	if night.unlocks != "":
		return night.unlocks
	for k: String in ["pen", "cane"]:
		if not run.unlocked[k]:
			continue
		var held := false
		for c: RulesCard in run.cards:
			if c.is_factor() and c.kind == k:
				held = true
		if not held:
			return k
	var keys := unlocked_factors(run)
	return keys[RulesRng.below(run, keys.size())]


static func _open_lab(run: RulesRun) -> void:
	run.alley = null
	var syms: Array = RulesRng.shuffle(run, RulesConfig.ROOTS.duplicate()).slice(0, 2)
	var free: Array = []
	for k in RulesConfig.LAB_INSTRUMENTS:
		if not has_inst(run, k):
			free.append(k)
	var inst: Array = RulesRng.shuffle(run, free).slice(0, 2)
	syms.append(_lab_factor(run))
	var shelf: Array = []
	for k: String in syms:
		shelf.append({"key": k, "price": RulesConfig.CARD_PRICE, "sold": false})
	var tools: Array = []
	for k: String in inst:
		tools.append({"key": k, "price": RulesConfig.INSTRUMENTS[k].price, "sold": false})
	run.shop = {"cards": shelf, "instruments": tools}
	run.phase = "lab"


static func _open_alley(run: RulesRun) -> void:
	run.shop = null
	var options: Array = []
	for k in RulesConfig.HIS_INSTRUMENTS:
		if not has_inst(run, k):
			options.append(k)
	run.alley = {"habit": null, "inst": null, "options": options, "bought": 0}
	run.phase = "alley"


static func _next_night(run: RulesRun) -> Array:
	run.night += 1
	run.round = 0
	return start_round(run).events


# ---------- the back alley ----------

## One Habit, free, once: on a symbol with an Ink Root in the deck. It breeds no copy and
## leaves the Craving where it was.
static func alley_habit(run: RulesRun, sym: String) -> Dictionary:
	if run.phase != "alley" or run.alley.habit != null or not RulesConfig.ROOT.has(sym) or count_roots(run, true, sym) == 0:
		return {"ok": false, "reason": "Not on offer."}
	run.habit[sym] += run.dials.alley_habit
	run.alley.habit = sym
	return {"ok": true}


## One of his instruments, free, once, if a slot is free.
static func alley_instrument(run: RulesRun, key: String) -> Dictionary:
	if run.phase != "alley" or run.alley.inst != null or not run.alley.options.has(key):
		return {"ok": false, "reason": "Not on offer."}
	if run.instruments.size() >= RulesConfig.MAX_INSTRUMENTS:
		return {"ok": false, "reason": "%d instruments held. Drop one first." % RulesConfig.MAX_INSTRUMENTS}
	run.instruments.append(key)
	run.alley.inst = key
	return {"ok": true}


## A dose of salt from the street chemist.
static func alley_salt(run: RulesRun) -> Dictionary:
	if run.phase != "alley":
		return {"ok": false, "reason": "Not now."}
	var price := salt_cost(run, "alley")
	if run.sov < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.salt += 1
	run.doses_bought += 1
	run.alley.bought += 1
	return {"ok": true}


## Leaves the back alley: the next night begins.
static func alley_leave(run: RulesRun) -> Dictionary:
	if run.phase != "alley":
		return {"ok": false, "reason": "Not now."}
	return {"ok": true, "events": _next_night(run)}


# ---------- the laboratory ----------

## Buys the card at this place of the shelf: one copy joins the deck.
static func buy_card(run: RulesRun, index: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var shelf: Array = run.shop.cards
	if index < 0 or index >= shelf.size() or shelf[index].sold:
		return {"ok": false, "reason": "Sold."}
	var o: Dictionary = shelf[index]
	if run.sov < int(o.price):
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= int(o.price)
	o.sold = true
	run.cards.append(make_card(run, o.key, false))
	return {"ok": true}


## Buys the instrument at this place of the shelf.
static func buy_instrument(run: RulesRun, index: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var shelf: Array = run.shop.instruments
	if index < 0 or index >= shelf.size() or shelf[index].sold:
		return {"ok": false, "reason": "Sold."}
	var o: Dictionary = shelf[index]
	if run.instruments.size() >= RulesConfig.MAX_INSTRUMENTS:
		return {"ok": false, "reason": "%d instruments held. Drop one first." % RulesConfig.MAX_INSTRUMENTS}
	if run.sov < int(o.price):
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= int(o.price)
	o.sold = true
	run.instruments.append(o.key)
	return {"ok": true}


## Drops a held instrument. Only at dawn, in either place.
static func drop_instrument(run: RulesRun, key: String) -> Dictionary:
	if run.phase != "lab" and run.phase != "alley":
		return {"ok": false, "reason": "Instruments are dropped at dawn."}
	if not has_inst(run, key):
		return {"ok": false, "reason": "Not held."}
	run.instruments.erase(key)
	return {"ok": true}


## A dose of salt from the laboratory.
static func buy_salt(run: RulesRun) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var price := salt_cost(run, "lab")
	if run.sov < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.salt += 1
	run.doses_bought += 1
	return {"ok": true}


## What it costs to strike this card from the deck.
static func strike_price(c: RulesCard) -> int:
	return RulesConfig.STRIKE_INK if c.is_ink() else RulesConfig.STRIKE_PAPER


## Removes a card from the deck for good, in the laboratory.
static func strike(run: RulesRun, id: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var c := card(run, id)
	if c == null:
		return {"ok": false, "reason": "No such card."}
	var price := strike_price(c)
	if run.sov < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.cards.erase(c)
	run.stats.struck += 1
	return {"ok": true}


## Leaves the laboratory: the next night begins.
static func leave_lab(run: RulesRun) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	return {"ok": true, "events": _next_night(run)}
