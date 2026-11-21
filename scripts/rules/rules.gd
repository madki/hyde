class_name Rules
## The card game's rules, as pure logic with no nodes. A run is plain data: a Dictionary of
## numbers, strings, Arrays and Dictionaries, so it can be saved as JSON (to_json, from_json)
## and replayed from its seed and its moves. Every function takes the run first.
##
## The run: `seed` (the generator's state) and `seed0`, `night` (0 to 4), `round` (0 to 2, the
## scene is 2), `phase` ("play", "result", "lab", "alley", "end"), `stance` ("jekyll" or
## "hyde"), `restraint`, `stored`, `salt`, `doses_bought`, `sov`, `hyde_arrived`, `unlocked`,
## `instruments`, the gauges `craving`, `habit` and `temper` (a number a symbol), `cards`
## (each {id, t: "root", sym, ink} or {id, t: "factor", kind}), the piles `draw`, `hand` and
## `discard` (card ids; the top of the draw pile is its end), the round's `score`, `plays`
## and `discards`, and between rounds `last`, `offer`, `shop`, `alley`, `dawn`, `ending`
## ("hyde", "double", "myself") and `ended_by`.
##
## A move returns {ok: true, ...} or {ok: false, reason}. The names and numbers are in
## RulesConfig, the reading of a play in RulesHands, what a table shows in RulesView.

const PHASES: Array[String] = ["play", "result", "alley", "lab", "end"]


# ---------- a run ----------

## A new run, dealt and ready for its first play. `changes` replaces numbers of
## RulesConfig.NUMBERS. With no seed, a random one is taken.
static func new_run(changes: Dictionary = {}, seed_value: Variant = null) -> Dictionary:
	var d := RulesConfig.dials(changes)
	var s0: int = RulesRng.wrap_seed(randi() % 2147483647 if seed_value == null else int(seed_value))
	var run := {
		"v": 1, "dials": d, "seed": s0, "seed0": s0, "uid": 0,
		"night": 0, "round": 0, "stance": "jekyll",
		"restraint": 0, "stored": 0, "salt": d.salt_start, "doses_bought": 0, "sov": 0,
		"craving": {"lamp": 0, "heart": 0, "mirror": 0},
		"habit": {"lamp": 0, "heart": 0, "mirror": 0},
		"temper": {"lamp": 0, "heart": 0, "mirror": 0},
		"cards": [], "draw": [], "hand": [], "discard": [],
		"score": 0, "plays": 0, "discards": 0,
		"hyde_arrived": false, "unlocked": {"pen": false, "cane": false},
		"instruments": [], "phase": "play",
		"last": null, "offer": null, "alley": null, "shop": null, "dawn": null,
		"ending": null, "ended_by": null,
		"log": [], "history": [],
		"stats": {
			"rescues": 0, "converted": 0, "breakouts": 0, "turns": 0, "temper": 0,
			"hyde_hands": 0, "jekyll_hands": 0, "best": 0, "best_name": "",
			"drinks": 0, "stains": 0, "salts": 0, "bred": 0, "struck": 0, "passes": 0,
		},
	}
	for key in RulesConfig.STARTING_DECK:
		run.cards.append(make_card(run, key, false))
	start_round(run)
	return run


## The run as JSON text.
static func to_json(run: Dictionary) -> String:
	return JSON.stringify(run)


## A run read back from to_json's text, or {} if the text is not one. JSON has one kind of
## number, so every whole number is made an int again.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("cards") or not data.has("dials"):
		return {}
	return _whole_numbers(data)


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

static func night_of(run: Dictionary) -> Dictionary:
	return RulesConfig.NIGHTS[run.night]


static func night_count() -> int:
	return RulesConfig.NIGHTS.size()


static func is_scene(run: Dictionary) -> bool:
	return int(run.round) == 2


## The twist in force now: the night's, in its scene only. "" for none.
static func twist_now(run: Dictionary) -> String:
	return night_of(run).twist if is_scene(run) else ""


## The score this round must reach.
static func target(run: Dictionary) -> int:
	return RulesConfig.targets(run.dials, run.night)[run.round]


static func has_inst(run: Dictionary, key: String) -> bool:
	return run.instruments.has(key)


## The restraint limit of this night's scene (`scene` true) or of its ordinary rounds.
static func limit_for(run: Dictionary, scene: bool) -> int:
	var d: Dictionary = run.dials
	var most: int = int(d.restraint_limit) + (int(d.balance_bonus) if has_inst(run, "balance") else 0)
	if scene and night_of(run).twist == "tight":
		most = maxi(1, most - int(d.tight_drop))
	return most


## The restraint limit of this round.
static func limit(run: Dictionary) -> int:
	return limit_for(run, is_scene(run))


## How many Ink Roots one Sublimation may turn.
static func turn_cap(run: Dictionary) -> int:
	return 2 if has_inst(run, "saucers") else 1


## The card with this id, or {} if the deck has none.
static func card(run: Dictionary, id: int) -> Dictionary:
	for c: Dictionary in run.cards:
		if c.id == id:
			return c
	return {}


static func is_root(c: Dictionary) -> bool:
	return c.t == "root"


static func is_ink(c: Dictionary) -> bool:
	return c.t == "root" and c.ink


static func is_paper(c: Dictionary) -> bool:
	return c.t == "root" and not c.ink


static func is_factor(c: Dictionary) -> bool:
	return c.t == "factor"


## A Root has one name for good. A Factor is named by whoever has the table.
static func name_of(c: Dictionary, stance: String) -> String:
	if c.t == "root":
		return RulesConfig.ROOT[c.sym].ink if c.ink else RulesConfig.ROOT[c.sym].paper
	return RulesConfig.FACTOR[c.kind].ink if stance == "hyde" else RulesConfig.FACTOR[c.kind].paper


## The name of a symbol's Root or of a Factor, on its ink or its paper side.
static func key_name(key: String, ink: bool) -> String:
	var entry: Dictionary = RulesConfig.ROOT[key] if RulesConfig.ROOT.has(key) else RulesConfig.FACTOR[key]
	return entry.ink if ink else entry.paper


## The chips a card is worth now. `craving`, if given, is used in place of its symbol's.
static func chips_of(run: Dictionary, c: Dictionary, craving: int = -1) -> int:
	var d: Dictionary = run.dials
	if c.t == "factor":
		return d.factor_chips
	if c.ink:
		var points: int = run.craving[c.sym] if craving < 0 else craving
		return int(d.root_chips) + int(d.craving_chips) * points + int(d.habit_chips) * int(run.habit[c.sym])
	return int(d.root_chips) + int(d.temper_chips) * int(run.temper[c.sym])


## How many Roots of a side the deck holds, of one symbol or ("") of all.
static func count_roots(run: Dictionary, ink: bool, sym: String = "") -> int:
	var n := 0
	for c: Dictionary in run.cards:
		if c.t == "root" and c.ink == ink and (sym == "" or c.sym == sym):
			n += 1
	return n


## The line: the run is lost when Ink Roots outnumber Paper Roots at the end of a round.
## A tie holds, and Factors count for neither side.
static func line_info(run: Dictionary) -> Dictionary:
	var ink := count_roots(run, true)
	var paper := count_roots(run, false)
	return {"ink": ink, "paper": paper, "total": run.cards.size(), "cushion": paper - ink, "over": ink > paper}


## A new card with the next id. It is not put in the deck.
static func make_card(run: Dictionary, key: String, ink: bool) -> Dictionary:
	run.uid = int(run.uid) + 1
	if RulesConfig.ROOT.has(key):
		return {"id": run.uid, "t": "root", "sym": key, "ink": ink}
	return {"id": run.uid, "t": "factor", "kind": key}


## Adds a new card to the deck. During a round it goes into the draw pile at a random place.
static func add_card(run: Dictionary, key: String, ink: bool, mid_round: bool) -> Dictionary:
	var c := make_card(run, key, ink)
	run.cards.append(c)
	if mid_round:
		var draw: Array = run.draw
		draw.insert(RulesRng.below(run, draw.size() + 1), c.id)
	return c


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
static func draw_one(run: Dictionary) -> int:
	if run.draw.is_empty():
		if run.discard.is_empty():
			return -1
		run.draw = RulesRng.shuffle(run, run.discard)
		run.discard = []
	var id: int = run.draw.pop_back()
	run.hand.append(id)
	return id


static func refill(run: Dictionary) -> void:
	while run.hand.size() < int(run.dials.hand_size):
		if draw_one(run) < 0:
			break


## Begins the round `run.night` and `run.round` point at: shuffles the whole deck, deals, and
## applies what comes before the first play (night 4's forced shift, walking in full).
static func start_round(run: Dictionary) -> void:
	var d: Dictionary = run.dials
	run.score = 0
	run.plays = d.plays
	run.discards = int(d.discards) + (1 if has_inst(run, "spirit") else 0)
	var ids: Array = []
	for c: Dictionary in run.cards:
		ids.append(c.id)
	run.draw = RulesRng.shuffle(run, ids)
	run.hand = []
	run.discard = []
	run.phase = "play"
	run.log = []
	run.offer = null
	run.alley = null
	run.shop = null
	run.dawn = null
	refill(run)
	# Night 4: the scene begins as Hyde, whoever ended round 2. The shift stains nothing.
	if twist_now(run) == "window" and run.stance == "jekyll":
		var ev := _arrive(run, "window")
		ev.brought = _bring_roots(run)
		run.log.append(ev)
	# Walking in full: Jekyll enters with the meter at or over this round's limit, and he
	# breaks out before the first play.
	if run.stance == "jekyll" and int(run.restraint) >= limit(run):
		var ev := _break_out(run, "walkedin")
		ev.brought = _bring_roots(run)


# ---------- the two stances ----------

static func _pile_count(run: Dictionary, sym: String, ink: bool) -> int:
	var n := 0
	for pile: Array in [run.draw, run.discard]:
		for id: int in pile:
			var c := card(run, id)
			if c.t == "root" and c.sym == sym and c.ink == ink:
				n += 1
	return n


static func _hand_has(run: Dictionary, sym: String, ink: bool) -> bool:
	for id: int in run.hand:
		var c := card(run, id)
		if c.t == "root" and c.sym == sym and c.ink == ink:
			return true
	return false


# Moves one such Root into the hand: from the draw pile, or from the discards if the draw
# pile has none. Each pile is searched from its end. Returns its id, or -1.
static func _pull(run: Dictionary, sym: String, ink: bool) -> int:
	for pile: Array in [run.draw, run.discard]:
		var i := pile.size() - 1
		while i >= 0:
			var c := card(run, pile[i])
			if c.t == "root" and c.sym == sym and c.ink == ink:
				pile.remove_at(i)
				run.hand.append(c.id)
				return c.id
			i -= 1
	return -1


# Whoever arrives brings up to two of his Roots into the hand.
# Hyde: a matching pair if the piles hold one (most Habit, then most copies there);
# otherwise one each of two symbols (one he already holds first, then most Habit).
# Jekyll: one each of two symbols (one his hand lacks first, then one whose Ink twin he holds).
# Remaining ties go Lamp, Heart, Mirror.
static func _bring_roots(run: Dictionary) -> Array:
	var out: Array = []
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
				return [-int(run.habit[s]), -_pile_count(run, s, true), roots.find(s)])
			out.append(_pull(run, pairs[0], true))
			out.append(_pull(run, pairs[0], true))
			return out
		avail = sort_by(avail, func(s: String) -> Array:
			return [-int(_hand_has(run, s, true)), -int(run.habit[s]), roots.find(s)])
	else:
		avail = sort_by(avail, func(s: String) -> Array:
			return [int(_hand_has(run, s, false)), -int(_hand_has(run, s, true)), roots.find(s)])
	for sym: String in avail.slice(0, 2):
		out.append(_pull(run, sym, ink))
	return out


# A stain: one Paper Root becomes its Ink twin for good, where it lies. The draw pile is
# looked in first, then the discards, then the hand. If one of his three Roots has no copy
# anywhere in the deck and its twin is in that pile, that twin goes first. With no Paper
# Root anywhere, one Ink Root of a random symbol joins the draw pile.
static func _stain_one(run: Dictionary) -> Dictionary:
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
		var taken: Dictionary = {}
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
		return {"id": taken.id, "sym": taken.sym, "from": pool[0], "added": false}
	var added: String = roots[RulesRng.below(run, roots.size())]
	add_card(run, added, true, true)
	return {"id": null, "sym": added, "from": "none", "added": true}


## His symbols with the fewest Ink Roots in the deck: the ones a breakout adds a copy of.
static func lowest_two(run: Dictionary) -> Array:
	var roots := RulesConfig.ROOTS
	return sort_by(roots, func(s: String) -> Array: return [count_roots(run, true, s), roots.find(s)]) \
			.slice(0, int(run.dials.breakout_roots))


# Jekyll to Hyde, by any road: "drink", "window" (night 4's scene), "breakout" or "walkedin".
# Does everything but bring his two Roots, because a breakout that wins the round brings none.
static func _arrive(run: Dictionary, how: String) -> Dictionary:
	var ev := {
		"t": "shift", "to": "hyde", "how": how, "stored": 0, "lost_restraint": 0, "first": false,
		"brought": [], "stained": null, "added": [],
	}
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
		for sym in RulesConfig.FIRST_ARRIVAL:
			add_card(run, sym, true, true)
	elif how == "drink":
		ev.stained = _stain_one(run)
		run.stats.stains += 1
	# A breakout adds a copy of each of his two lowest-count Roots, counted after any
	# first-arrival cards.
	if how == "breakout" or how == "walkedin":
		for sym: String in lowest_two(run):
			add_card(run, sym, true, true)
			ev.added.append(sym)
	return ev


static func _break_out(run: Dictionary, how: String) -> Dictionary:
	var ev := _arrive(run, how)
	run.stats.breakouts += 1
	run.log.append(ev)
	return ev


## Whether the draught can be drunk now: {ok, why}.
static func can_drink(run: Dictionary) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if run.stance != "jekyll":
		return {"ok": false, "why": "He already has the table."}
	if int(run.night) == 0 and int(run.round) == 0:
		return {"ok": false, "why": "The draught does not exist yet."}
	if twist_now(run) == "last":
		return {"ok": false, "why": "No draught works in this scene."}
	return {"ok": true, "why": ""}


## Whether a dose of salt can be taken now: {ok, why}.
static func can_salt(run: Dictionary) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if run.stance != "hyde":
		return {"ok": false, "why": "You are yourself."}
	var from: int = run.dials.salt_from
	if int(run.night) * 3 + int(run.round) < from:
		@warning_ignore("integer_division")
		var night: int = from / 3 + 1
		return {"ok": false, "why": "The salt comes with the scene." if from == 2 else "The salt comes on night %d." % night}
	if twist_now(run) == "last":
		return {"ok": false, "why": "No salt works in this scene."}
	if int(run.salt) <= 0:
		return {"ok": false, "why": "No doses left."}
	return {"ok": true, "why": ""}


## What the next drink costs: "first" (his first four Roots join) or "stain".
static func drink_cost(run: Dictionary) -> String:
	return "stain" if run.hyde_arrived else "first"


## Jekyll to Hyde. The meter is stored, his first Roots join or a Paper Root is stained,
## and he brings two Roots.
static func drink(run: Dictionary) -> Dictionary:
	var c := can_drink(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	run.stats.drinks += 1
	var ev := _arrive(run, "drink")
	ev.brought = _bring_roots(run)
	run.log.append(ev)
	return {"ok": true, "ev": ev}


## Hyde to Jekyll. One dose is spent, restraint is 0, stored restraint is lost, and Jekyll
## brings two Roots.
static func take_salt(run: Dictionary) -> Dictionary:
	var c := can_salt(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	run.salt -= 1
	run.stats.salts += 1
	var ev := {"t": "shift", "to": "jekyll", "how": "salt", "stored": 0, "lost_stored": run.stored, "first": false, "brought": []}
	run.stance = "jekyll"
	run.restraint = 0
	run.stored = 0
	ev.brought = _bring_roots(run)
	run.log.append(ev)
	return {"ok": true, "ev": ev}


# ---------- playing ----------

## Reads a play without making it: see RulesHands.evaluate.
static func evaluate(run: Dictionary, cards: Array) -> Dictionary:
	return RulesHands.evaluate(run, cards)


## The highest-scoring allowed play in the hand: see RulesHands.best.
static func best(run: Dictionary, filter: Callable = Callable()) -> Dictionary:
	return RulesHands.best(run, filter)


# One to any number of different card ids, all in the hand.
static func _in_hand(run: Dictionary, ids: Array) -> bool:
	if ids.is_empty():
		return false
	var seen := {}
	for id: int in ids:
		if seen.has(id) or not run.hand.has(id):
			return false
		seen[id] = true
	return true


static func _to_discards(run: Dictionary, ids: Array) -> void:
	for id: int in ids:
		run.hand.erase(id)
		run.discard.append(id)


## Plays these cards of the hand. Returns {ok, ev (the reading), events, stance (who played),
## phase (after the play)}.
static func play(run: Dictionary, ids: Array) -> Dictionary:
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
	var d: Dictionary = run.dials
	var st: String = run.stance
	var out := {"ok": true, "ev": ev, "events": [], "stance": st, "phase": ""}
	var stats: Dictionary = run.stats
	# 1. The score.
	run.plays -= 1
	run.score += int(ev.score)
	var entry := {"t": "play", "who": st, "name": ev.name, "key": ev.key, "chips": ev.chips, "mult": ev.mult, "score": ev.score, "notes": []}
	if int(ev.score) > int(stats.best):
		stats.best = ev.score
		stats.best_name = ev.name
	# 2. What the play does.
	if st == "hyde":
		stats.hyde_hands += 1
		if ev.kind == "hand":
			if int(run.stored) > 0:
				entry.notes.append("stored restraint paid +%d mult" % (int(run.stored) * int(d.restraint_pay)))
				run.stored = 0
			for sym in RulesConfig.ROOTS:
				if not ev.craving_on.has(sym):
					continue
				run.craving[sym] += int(ev.craving_on[sym])
				# Rollover: the Habit rises and a copy joins the draw pile.
				while int(run.craving[sym]) >= int(d.craving_cap):
					run.craving[sym] -= int(d.craving_cap)
					run.habit[sym] += 1
					add_card(run, sym, true, true)
					stats.bred += 1
					out.events.append({"t": "breed", "sym": sym, "habit": run.habit[sym]})
					entry.notes.append("%s became a Habit and left a copy" % RulesConfig.ROOT[sym].ink)
				out.events.append({"t": "craving", "sym": sym, "n": run.craving[sym]})
			if ev.no_craving:
				entry.notes.append("no Craving")
			if has_inst(run, "cheque"):
				run.sov += 1
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
				out.events.append({"t": "turn", "sym": sym, "gain": gain, "temper": run.temper[sym]})
				entry.notes.append("%s turned to %s%s" % [RulesConfig.ROOT[sym].ink, RulesConfig.ROOT[sym].paper, ", Temper +%d" % gain if gain > 0 else ""])
		elif ev.adds_restraint:
			run.restraint += 1
			out.events.append({"t": "restraint", "n": run.restraint})
		else:
			entry.notes.append("no restraint")
	# 3. The played cards leave. What stays in hand now is what a rescue may convert.
	_to_discards(run, ids)
	var held: Array = run.hand.duplicate()
	refill(run)
	for i in int(ev.draws):
		draw_one(run)
	run.log.append(entry)
	_settle(run, st, int(ev.score), str(ev.name), held, out)
	out.phase = run.phase
	return out


# The end of a play: the breakout, the win, and the last play that falls short.
static func _settle(run: Dictionary, st: String, last_score: int, last_name: String, held: Array, out: Dictionary) -> void:
	if st == "jekyll" and int(run.restraint) >= limit(run):
		var bo := _break_out(run, "breakout")
		out.events.append({"t": "breakout", "ev": bo})
		if int(run.score) >= target(run):
			# Won, in his stance: he brings no Roots.
			_end_round(run, {"how": "won", "broke_out": true})
			return
		bo.brought = _bring_roots(run)
	if int(run.score) >= target(run):
		_end_round(run, {"how": "won"})
		return
	if int(run.plays) <= 0:
		_rescue(run, last_score, last_name, held)


## Throws away 1 to 5 cards of the hand and refills it. Uses one of the round's discards.
static func discard(run: Dictionary, ids: Array) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	if int(run.discards) <= 0:
		return {"ok": false, "reason": "No discards left."}
	if not _in_hand(run, ids):
		return {"ok": false, "reason": "Choose cards to discard."}
	if ids.size() > int(run.dials.max_play):
		return {"ok": false, "reason": "Discard up to five cards."}
	run.discards -= 1
	_to_discards(run, ids)
	refill(run)
	run.log.append({"t": "discard", "n": ids.size()})
	return {"ok": true}


## Whether the hand holds anything the man at the table can play: a Factor or a Root of his.
static func has_play(run: Dictionary) -> bool:
	var ink: bool = run.stance == "hyde"
	for id: int in run.hand:
		var c := card(run, id)
		if c.t == "factor" or c.ink == ink:
			return true
	return false


## Whether the play can be passed: {ok, why}. Only with nothing to play and no discards left.
static func can_pass(run: Dictionary) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "why": "Not now."}
	if has_play(run):
		return {"ok": false, "why": "A card in hand can be played."}
	if int(run.discards) > 0:
		return {"ok": false, "why": "Discard first."}
	return {"ok": true, "why": ""}


## Passes a play. It uses a play and scores nothing, and as Jekyll it adds restraint.
static func pass_play(run: Dictionary) -> Dictionary:
	var c := can_pass(run)
	if not c.ok:
		return {"ok": false, "reason": c.why}
	var st: String = run.stance
	var out := {"ok": true, "events": [], "stance": st, "passed": true, "phase": ""}
	run.plays -= 1
	run.stats.passes += 1
	if st == "jekyll":
		run.restraint += 1
		out.events.append({"t": "restraint", "n": run.restraint})
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
static func plan_rescue(run: Dictionary, prior: int, last: int, held_ids: Array, breaks_out: bool) -> Dictionary:
	var goal := target(run)
	var papers: Array = []
	for id: int in held_ids:
		var c := card(run, id)
		if not c.is_empty() and is_paper(c):
			papers.append(c)
	var pool := sort_by(papers, func(c: Dictionary) -> Array:
		return [int(run.temper[c.sym]), RulesConfig.ROOTS.find(c.sym), c.id])
	var k := 0
	while prior + last * (1 << k) < goal and k < pool.size():
		k += 1
	var reached: int = prior + last * (1 << k)
	# Roots that join with him if this is also his first arrival, or if the play also
	# fills the meter.
	var extra: int = (0 if run.hyde_arrived else RulesConfig.FIRST_ARRIVAL.size()) + (int(run.dials.breakout_roots) if breaks_out else 0)
	var li := line_info(run)
	var ink: int = int(li.ink) + k + extra
	var paper: int = int(li.paper) - k
	var ids: Array = []
	for c: Dictionary in pool.slice(0, k):
		ids.append(c.id)
	return {
		"k": k, "ids": ids, "pool": pool.size(), "factor": 1 << k, "score": reached, "ok": reached >= goal,
		"ink": ink, "paper": paper, "over": ink > paper,
	}


static func _rescue(run: Dictionary, last_score: int, last_name: String, held: Array) -> void:
	var prior: int = int(run.score) - last_score
	var plan := plan_rescue(run, prior, last_score, held, false)
	var names: Array = []
	for id: int in plan.ids:
		var c := card(run, id)
		names.append([RulesConfig.ROOT[c.sym].paper, RulesConfig.ROOT[c.sym].ink])
		c.ink = true
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
		for sym in RulesConfig.FIRST_ARRIVAL:
			add_card(run, sym, true, false)
	var was: String = run.stance
	var lost: int = run.restraint
	run.stance = "hyde"
	run.restraint = 0
	run.stored = 0
	run.stats.rescues += 1
	_end_round(run, {"how": "rescued", "first": first, "lost_restraint": lost, "was": was, "rescue": info})


## Gives up the run: it ends as Mr Hyde. A convenience, not a rule.
static func give_up(run: Dictionary) -> Dictionary:
	if run.phase != "play":
		return {"ok": false, "reason": "Not now."}
	_end_round(run, {"how": "lost", "reason": "gaveup"})
	return {"ok": true}


# ---------- the end of a round ----------

static func _end_round(run: Dictionary, res: Dictionary) -> void:
	var d: Dictionary = run.dials
	res.night = run.night
	res.round = run.round
	res.score = run.score
	res.target = target(run)
	res.stance = run.stance
	if res.how == "won":
		# A rescued round pays nothing.
		res.plays_left = run.plays
		res.pay = int(d.round_pay) + int(d.unused_play_pay) * int(run.plays)
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
		return
	# The line is checked at the end of every round, never at dawn.
	if li.over:
		run.ending = "hyde"
		run.ended_by = "line"
		run.phase = "end"
		return
	if int(run.night) == night_count() - 1 and is_scene(run):
		run.ending = "double" if run.stance == "hyde" else "myself"
		run.ended_by = "scene"
		run.phase = "end"
		return
	# An ordinary round won in Jekyll's stance: one of three different cards, or none.
	if not is_scene(run) and res.how == "won" and run.stance == "jekyll":
		run.offer = _pick_offers(run, int(d.reward_cards))
	run.phase = "result"


## Leaves the result of a round, taking the offered card at index `pick` (null: none). Next
## comes the next round, or after a scene the dawn.
static func continue_result(run: Dictionary, pick: Variant = null) -> Dictionary:
	if run.phase != "result":
		return {"ok": false, "reason": "Not now."}
	if run.offer != null and pick != null and int(pick) >= 0 and int(pick) < run.offer.size():
		run.cards.append(make_card(run, run.offer[int(pick)], false))
	run.offer = null
	if not is_scene(run):
		run.round += 1
		start_round(run)
	else:
		_enter_dawn(run)
	return {"ok": true}


# ---------- what is on offer ----------

## The Factors that can appear in a reward or on the laboratory's shelf.
static func unlocked_factors(run: Dictionary) -> Array:
	var out: Array = []
	for k in RulesConfig.FACTORS:
		if int(RulesConfig.FACTOR[k].unlock) == 0 or run.unlocked[k]:
			out.append(k)
	return out


# Different cards for a reward: the three Paper Roots and every unlocked Factor, by weight,
# drawn one at a time without putting any back.
static func _pick_offers(run: Dictionary, n: int) -> Array:
	var d: Dictionary = run.dials
	var pool: Array = []
	for s in RulesConfig.ROOTS:
		pool.append([s, int(d.reward_root_weight)])
	for k: String in unlocked_factors(run):
		pool.append([k, int(d.reward_factor_weight)])
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
static func salt_cost(run: Dictionary, where: String) -> int:
	var d: Dictionary = run.dials
	return int(d.salt_price) + int(d.salt_rise) * int(run.doses_bought) + (int(d.alley_markup) if where == "alley" else 0)


## His Root with the most Habit. Ties go to the most Craving, then the fewest Ink copies in
## the deck, then Lamp, Heart, Mirror.
static func highest_habit(run: Dictionary) -> String:
	var roots := RulesConfig.ROOTS
	return sort_by(roots, func(s: String) -> Array:
		return [-int(run.habit[s]), -int(run.craving[s]), count_roots(run, true, s), roots.find(s)])[0]


# ---------- dawn ----------

# Dawn: his unasked Roots join and the night's Factor unlocks. Then one place only, by who
# has the table: the laboratory for Jekyll, the back alley for Hyde.
static func _enter_dawn(run: Dictionary) -> void:
	var night := night_of(run)
	run.dawn = {
		"no": int(run.night) + 1, "brings": null, "unlocks": null,
		"last": int(run.night) + 1 >= night_count() - 1, "as_hyde": run.stance == "hyde",
	}
	var sym: String = highest_habit(run) if night.brings == "habit" else night.brings
	if sym != "":
		add_card(run, sym, true, false)
		add_card(run, sym, true, false)
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
static func _lab_factor(run: Dictionary) -> String:
	var night := night_of(run)
	if night.unlocks != "":
		return night.unlocks
	for k: String in ["pen", "cane"]:
		if not run.unlocked[k]:
			continue
		var held := false
		for c: Dictionary in run.cards:
			if c.t == "factor" and c.kind == k:
				held = true
		if not held:
			return k
	var keys := unlocked_factors(run)
	return keys[RulesRng.below(run, keys.size())]


static func _open_lab(run: Dictionary) -> void:
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


static func _open_alley(run: Dictionary) -> void:
	run.shop = null
	var options: Array = []
	for k in RulesConfig.HIS_INSTRUMENTS:
		if not has_inst(run, k):
			options.append(k)
	run.alley = {"habit": null, "inst": null, "options": options, "bought": 0}
	run.phase = "alley"


static func _next_night(run: Dictionary) -> void:
	run.night += 1
	run.round = 0
	start_round(run)


# ---------- the back alley ----------

## One Habit, free, once: on a symbol with an Ink Root in the deck. It breeds no copy and
## leaves the Craving where it was.
static func alley_habit(run: Dictionary, sym: String) -> Dictionary:
	if run.phase != "alley" or run.alley.habit != null or not RulesConfig.ROOT.has(sym) or count_roots(run, true, sym) == 0:
		return {"ok": false, "reason": "Not on offer."}
	run.habit[sym] += int(run.dials.alley_habit)
	run.alley.habit = sym
	return {"ok": true}


## One of his instruments, free, once, if a slot is free.
static func alley_instrument(run: Dictionary, key: String) -> Dictionary:
	if run.phase != "alley" or run.alley.inst != null or not run.alley.options.has(key):
		return {"ok": false, "reason": "Not on offer."}
	if run.instruments.size() >= RulesConfig.MAX_INSTRUMENTS:
		return {"ok": false, "reason": "Three instruments held. Drop one first."}
	run.instruments.append(key)
	run.alley.inst = key
	return {"ok": true}


## A dose of salt from the street chemist.
static func alley_salt(run: Dictionary) -> Dictionary:
	if run.phase != "alley":
		return {"ok": false, "reason": "Not now."}
	var price := salt_cost(run, "alley")
	if int(run.sov) < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.salt += 1
	run.doses_bought += 1
	run.alley.bought += 1
	return {"ok": true}


## Leaves the back alley: the next night begins.
static func alley_leave(run: Dictionary) -> Dictionary:
	if run.phase != "alley":
		return {"ok": false, "reason": "Not now."}
	_next_night(run)
	return {"ok": true}


# ---------- the laboratory ----------

## Buys the card at this place of the shelf: one copy joins the deck.
static func buy_card(run: Dictionary, index: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var shelf: Array = run.shop.cards
	if index < 0 or index >= shelf.size() or shelf[index].sold:
		return {"ok": false, "reason": "Sold."}
	var o: Dictionary = shelf[index]
	if int(run.sov) < int(o.price):
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= int(o.price)
	o.sold = true
	run.cards.append(make_card(run, o.key, false))
	return {"ok": true}


## Buys the instrument at this place of the shelf.
static func buy_instrument(run: Dictionary, index: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var shelf: Array = run.shop.instruments
	if index < 0 or index >= shelf.size() or shelf[index].sold:
		return {"ok": false, "reason": "Sold."}
	var o: Dictionary = shelf[index]
	if run.instruments.size() >= RulesConfig.MAX_INSTRUMENTS:
		return {"ok": false, "reason": "Three instruments held. Drop one first."}
	if int(run.sov) < int(o.price):
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= int(o.price)
	o.sold = true
	run.instruments.append(o.key)
	return {"ok": true}


## Drops a held instrument. Only at dawn, in either place.
static func drop_instrument(run: Dictionary, key: String) -> Dictionary:
	if run.phase != "lab" and run.phase != "alley":
		return {"ok": false, "reason": "Instruments are dropped at dawn."}
	if not has_inst(run, key):
		return {"ok": false, "reason": "Not held."}
	run.instruments.erase(key)
	return {"ok": true}


## A dose of salt from the laboratory.
static func buy_salt(run: Dictionary) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var price := salt_cost(run, "lab")
	if int(run.sov) < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.salt += 1
	run.doses_bought += 1
	return {"ok": true}


## What it costs to strike this card from the deck.
static func strike_price(c: Dictionary) -> int:
	return RulesConfig.STRIKE_INK if is_ink(c) else RulesConfig.STRIKE_PAPER


## Removes a card from the deck for good, in the laboratory.
static func strike(run: Dictionary, id: int) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	var c := card(run, id)
	if c.is_empty():
		return {"ok": false, "reason": "No such card."}
	var price := strike_price(c)
	if int(run.sov) < price:
		return {"ok": false, "reason": "Not enough sovereigns."}
	run.sov -= price
	run.cards.erase(c)
	run.stats.struck += 1
	return {"ok": true}


## Leaves the laboratory: the next night begins.
static func leave_lab(run: Dictionary) -> Dictionary:
	if run.phase != "lab":
		return {"ok": false, "reason": "Not now."}
	_next_night(run)
	return {"ok": true}
