class_name RulesHands
## Reading a play: which hand it is, what it scores, and what it would do. Nothing here
## changes the run or uses its generator.


## Reads a play of these cards (RulesCard, in the deck or not) for the man at the
## table. `ok` is false with a `reason` when the play is not allowed. Otherwise the result
## holds the hand (`kind`: "hand", "sublimation" or "thought"; `key`, `row`, `name`), `chips`,
## `mult` and `score` with their `parts` and `mult_parts`, and what the play will do:
## `adds_restraint`, `craving_on` (points a symbol), `breeds` (a symbol for each copy bred),
## `no_craving`, `turns` (ids of the Ink Roots turned, in order), `temper_gain` (a symbol),
## `spends_stored`, `cheque`, `draws`, `scoring` (ids of the cards that score) and `lit`
## (the symbols of the active Roots). `steps` is the score in the order a table performs it:
## see _steps.
static func evaluate(run: RulesRun, cards: Array) -> Dictionary:
	var d := run.dials
	var st: String = run.stance
	var res := {
		"ok": false, "reason": "", "kind": "", "key": "", "row": "", "name": "",
		"chips": 0, "mult": 1, "score": 0, "parts": [], "mult_parts": [], "steps": [],
		"adds_restraint": false, "turns": [], "temper_gain": {}, "craving_on": {}, "breeds": [],
		"no_craving": false, "spends_stored": false, "cheque": false, "draws": 0, "scoring": [],
		"lit": {"lamp": false, "heart": false, "mirror": false},
	}
	if cards.is_empty():
		res.reason = "Choose cards for a hand."
		return res
	if cards.size() > d.max_play:
		res.reason = "A hand is up to %d cards." % d.max_play
		return res
	var paper: Array = []
	var ink: Array = []
	var fac: Array = []
	var nf := {"cup": 0, "eye": 0, "lock": 0, "pen": 0, "cane": 0}
	var scoring: Array = []
	for c: RulesCard in cards:
		scoring.append(c.id)
		if c.is_factor():
			fac.append(c)
			nf[c.kind] += 1
		elif c.ink:
			ink.append(c)
		else:
			paper.append(c)
	res.scoring = scoring
	res.draws = nf.eye
	if st == "hyde" and not paper.is_empty():
		res.reason = "Jekyll's Roots cannot be played while Hyde has the table."
		return res
	if st == "jekyll" and not ink.is_empty():
		return _sublimation(run, res, paper, ink, fac)

	var active: Array = ink if st == "hyde" else paper
	res.ok = true
	if active.is_empty():
		# A Passing Thought: Factors only. One of them scores its chips, times 1. No bonus
		# applies and no Craving rises.
		var first: RulesCard = fac[0]
		var fchips: int = d.factor_chips
		res.kind = "thought"
		res.key = "thought"
		res.name = RulesConfig.THOUGHT_NAME
		res.chips = fchips
		res.mult = 1
		res.score = fchips
		res.parts.append({"label": _factor_name(first.kind, st), "v": fchips, "id": first.id})
		res.mult_parts.append({"label": RulesConfig.THOUGHT_NAME, "v": 1, "base": true})
		res.scoring = [first.id]
		res.adds_restraint = st == "jekyll" and nf.lock == 0
		res.no_craving = true
		res.steps = _steps(run, res, [], fac, fchips, 1, RulesConfig.THOUGHT_NAME)
		return res

	var cnt := {}
	for c: RulesCard in active:
		cnt[c.sym] = int(cnt.get(c.sym, 0)) + 1
		res.lit[c.sym] = true
	var different: int = cnt.size()
	var most := 0
	for k: String in cnt:
		most = maxi(most, cnt[k])
	# The hand is the one with the highest chips x mult that the Roots fit.
	var table: Dictionary = RulesConfig.HANDS[st]
	var fits: Array[String] = []
	if st == "hyde":
		fits.append("stirring")
		if different >= 2: fits.append("lapse")
		if different >= 3: fits.append("turmoil")
		if most >= 2: fits.append("fixation")
		if most >= 3: fits.append("mania")
	else:
		fits.append("spark")
		if most >= 2: fits.append("rumination")
		if different >= 2: fits.append("goodwork")
		if most >= 3: fits.append("dogma")
		if different >= 3: fits.append("lucid")
	var key: String = fits[0]
	for k in fits:
		if int(table[k].chips) * int(table[k].mult) > int(table[key].chips) * int(table[key].mult):
			key = k
	var def: Dictionary = table[key]
	res.kind = "hand"
	res.key = key
	res.row = def.row
	res.name = def.name
	var chips: int = def.chips
	var mult: int = def.mult
	var parts: Array = res.parts
	var mult_parts: Array = res.mult_parts
	parts.append({"label": def.name, "v": def.chips, "base": true})
	for c: RulesCard in active:
		var v := Rules.chips_of(run, c)
		chips += v
		parts.append({"label": Rules.name_of(c, st), "v": v, "id": c.id})
	for c: RulesCard in fac:
		chips += d.factor_chips
		parts.append({"label": _factor_name(c.kind, st), "v": d.factor_chips, "id": c.id})
	var top := best_root(run, active)
	var canes: int = nf.cane
	if canes > 0:
		var v := Rules.chips_of(run, top) * canes
		chips += v
		parts.append({"label": Rules.name_of(top, st) + " again", "v": v})

	if st == "hyde":
		var hunted := Rules.twist_now(run) == "hunted"
		if hunted:
			mult = int(ceil(mult / 2.0))
		mult_parts.append({"label": str(def.name) + ", hunted" if hunted else str(def.name), "v": mult, "base": true})
		if nf.cup > 0:
			var v: int = d.glee_chips * int(nf.cup)
			chips += v
			parts.append({"label": "Glee bonus", "v": v})
		var habit_bonus := 0
		for c: RulesCard in active:
			habit_bonus += d.habit_mult * run.habit[c.sym]
		if habit_bonus > 0:
			mult += habit_bonus
			mult_parts.append({"label": "Habit", "v": habit_bonus})
		if run.stored > 0:
			var b: int = run.stored * d.restraint_pay
			mult += b
			mult_parts.append({"label": "stored restraint", "v": b})
			res.spends_stored = true
		if nf.pen > 0:
			var b: int = d.pen_mult * most * int(nf.pen)
			mult += b
			mult_parts.append({"label": "Alibi", "v": b})
		if canes > 0:
			mult += d.cane_mult * canes
			mult_parts.append({"label": "Restlessness", "v": d.cane_mult * canes})
		if key == "mania" and Rules.has_inst(run, "hcane"):
			mult += d.hcane_mult
			mult_parts.append({"label": "The Cane", "v": d.hcane_mult})
		# Craving: 1 for each of his symbols in the play, 1 more on the best Root's symbol for
		# each Restlessness, none at all with Cunning.
		res.no_craving = nf.lock > 0
		if not res.no_craving:
			var on: Dictionary = res.craving_on
			for sym: String in cnt:
				on[sym] = 1
			if canes > 0:
				on[top.sym] += canes
			for sym in RulesConfig.ROOTS:
				if not on.has(sym):
					continue
				@warning_ignore("integer_division")
				var copies: int = (run.craving[sym] + int(on[sym])) / d.craving_cap
				for i in copies:
					res.breeds.append(sym)
		res.cheque = Rules.has_inst(run, "cheque")
	else:
		mult_parts.append({"label": def.name, "v": mult, "base": true})
		for sym in RulesConfig.ROOTS:
			if cnt.has(sym) and run.temper[sym] > 0:
				var b: int = d.temper_mult * run.temper[sym]
				mult += b
				mult_parts.append({"label": "Temper, " + str(RulesConfig.ROOT[sym].label), "v": b})
		if nf.cup > 0:
			mult += d.cheer_mult * int(nf.cup)
			mult_parts.append({"label": "Good Cheer", "v": d.cheer_mult * int(nf.cup)})
		if nf.pen > 0:
			var b: int = d.pen_mult * different * int(nf.pen)
			mult += b
			mult_parts.append({"label": "Reason", "v": b})
		if canes > 0:
			mult += d.cane_mult * canes
			mult_parts.append({"label": "Vigour", "v": d.cane_mult * canes})
		res.adds_restraint = nf.lock == 0
	res.chips = chips
	res.mult = mult
	res.score = chips * mult
	res.steps = _steps(run, res, active, fac, def.chips, mult_parts[0].v, mult_parts[0].label)
	return res


## The best Root of a play: the one with the most chips. Ties go Lamp, Heart, Mirror.
static func best_root(run: RulesRun, roots: Array) -> RulesCard:
	var top: RulesCard = null
	var top_chips := -1
	for c: RulesCard in roots:
		var v := Rules.chips_of(run, c)
		if v > top_chips or (v == top_chips and RulesConfig.ROOTS.find(c.sym) < RulesConfig.ROOTS.find(top.sym)):
			top = c
			top_chips = v
	return top


## The highest-scoring allowed play in the hand, as {key, ev, ids}, or {} if there is none.
## With the same score, fewer cards come first. `filter`, if given, is called with the reading
## and the cards and returns false to leave a play out.
static func best(run: RulesRun, filter: Callable = Callable()) -> Dictionary:
	var hand: Array = []
	for id: int in run.hand:
		hand.append(Rules.card(run, id))
	var n := hand.size()
	if not filter.is_valid():
		# Nothing is left out, so the play is found from the counts of its kinds, and only
		# that one is read in full.
		var found := _search(run, hand, false)
		if found == 0:
			return {}
		var cards := _of_mask(hand, found)
		var reading := evaluate(run, cards)
		return {"key": int(reading.score) - cards.size() * 0.001, "ev": reading, "ids": _ids(cards)}
	var top := {}
	var codes: Array[int] = []
	for c: RulesCard in hand:
		codes.append(_kind_code(c))
	# Every set of up to max_play hand cards, as a number with one bit a card, with the
	# total of its cards' kind codes. They are read in the order of those numbers.
	var sets := {}
	_add_sets(codes, run.dials.max_play, 0, 0, 0, sets)
	var masks: Array = sets.keys()
	masks.sort()
	# Cards of one kind score alike, so of the plays that hold the same kinds only the first
	# is read. The first is also the one that would win a tie.
	var seen := {}
	for m: int in masks:
		if not filter.is_valid():
			if seen.has(sets[m]):
				continue
			seen[sets[m]] = true
		var sel: Array = []
		for i in n:
			if m & (1 << i):
				sel.append(hand[i])
		var ev := evaluate(run, sel)
		if not ev.ok:
			continue
		if filter.is_valid() and not filter.call(ev, sel):
			continue
		var key: float = int(ev.score) - sel.size() * 0.001
		if top.is_empty() or key > float(top.key):
			var ids: Array = []
			for c: RulesCard in sel:
				ids.append(c.id)
			top = {"key": key, "ev": ev, "ids": ids}
	return top


# Adds to `out` every set of 1 to `left` more cards taken from place `from` on, on top of
# the set `mask` whose kind codes add up to `total`.
static func _add_sets(codes: Array[int], left: int, from: int, mask: int, total: int, out: Dictionary) -> void:
	for i in range(from, codes.size()):
		var with_card := mask | (1 << i)
		out[with_card] = total + codes[i]
		if left > 1:
			_add_sets(codes, left - 1, i + 1, with_card, total + codes[i], out)


# A number that adds up to a different total for every different set of card kinds (up to
# 31 of a kind): 5 bits for each of the 11 kinds.
static func _kind_code(c: RulesCard) -> int:
	if c.is_factor():
		return 1 << (5 * (6 + RulesConfig.FACTORS.find(c.kind)))
	return 1 << (5 * (RulesConfig.ROOTS.find(c.sym) + (3 if c.ink else 0)))


static func _factor_name(kind: String, stance: String) -> String:
	return RulesConfig.FACTOR[kind].ink if stance == "hyde" else RulesConfig.FACTOR[kind].paper


# A Sublimation: Paper Roots beside their Ink twins, and one Factor at most. One Ink Root
# turns, or two with the Glass saucers: one Paper Root and two of its twins, or two twin
# pairs. The Ink Roots resolve one at a time, Lamp before Heart before Mirror, each at the
# Craving its symbol has by then.
static func _sublimation(run: RulesRun, res: Dictionary, paper: Array, ink: Array, fac: Array) -> Dictionary:
	var d := run.dials
	var cap := Rules.turn_cap(run)
	if ink.size() > cap:
		res.reason = "A Sublimation turns one of his Roots." if cap == 1 else "A Sublimation turns two of his Roots at most."
		return res
	for c: RulesCard in ink:
		if not _has_sym(paper, c.sym):
			res.reason = "%s turns only beside %s." % [RulesConfig.ROOT[c.sym].ink, RulesConfig.ROOT[c.sym].paper]
			return res
	var spare := paper.size() > ink.size()
	for p: RulesCard in paper:
		if not _has_sym(ink, p.sym):
			spare = true
	if spare:
		res.reason = ("A Sublimation is one of Jekyll's Roots, its ink twin, and one Factor at most." if cap == 1
				else "A Sublimation is his Roots beside their paper twins, and one Factor at most.")
		return res
	if fac.size() > 1:
		res.reason = "A Sublimation holds one Factor at most."
		return res
	var def: Dictionary = RulesConfig.HANDS.jekyll.sublimation
	res.ok = true
	res.kind = "sublimation"
	res.key = "sublimation"
	res.row = def.row
	res.name = def.name
	var chips: int = def.chips
	var mult: int = def.mult
	var parts: Array = res.parts
	var mult_parts: Array = res.mult_parts
	parts.append({"label": def.name, "v": def.chips, "base": true})
	mult_parts.append({"label": def.name, "v": def.mult, "base": true})
	var seen := {}
	for c: RulesCard in paper:
		var v := Rules.chips_of(run, c)
		chips += v
		parts.append({"label": RulesConfig.ROOT[c.sym].paper, "v": v, "id": c.id})
		res.lit[c.sym] = true
		if not seen.has(c.sym):
			seen[c.sym] = true
			if run.temper[c.sym] > 0:
				var b: int = d.temper_mult * run.temper[c.sym]
				mult += b
				mult_parts.append({"label": "Temper, " + str(RulesConfig.ROOT[c.sym].label), "v": b})
	var now: Dictionary = run.craving.duplicate()
	var order := _in_order(ink)
	for c: RulesCard in order:
		var craving: int = now[c.sym]
		var v := Rules.chips_of(run, c, craving)
		var b: int = d.burst_mult + d.burst_craving_mult * craving
		chips += v
		parts.append({"label": RulesConfig.ROOT[c.sym].ink, "v": v, "id": c.id})
		mult += b
		mult_parts.append({"label": "turning " + str(RulesConfig.ROOT[c.sym].ink), "v": b})
		res.temper_gain[c.sym] = int(res.temper_gain.get(c.sym, 0)) + craving
		now[c.sym] = 0
		res.turns.append(c.id)
	if not fac.is_empty():
		var f: RulesCard = fac[0]
		chips += d.factor_chips
		parts.append({"label": RulesConfig.FACTOR[f.kind].paper, "v": d.factor_chips, "id": f.id})
		if f.kind == "cup":
			mult += d.cheer_mult
			mult_parts.append({"label": "Good Cheer", "v": d.cheer_mult})
		elif f.kind == "pen":
			var b: int = d.pen_mult * seen.size()
			mult += b
			mult_parts.append({"label": "Reason", "v": b})
		elif f.kind == "cane":
			var top := best_root(run, paper)
			var v := Rules.chips_of(run, top)
			chips += v
			parts.append({"label": str(RulesConfig.ROOT[top.sym].paper) + " again", "v": v})
			mult += d.cane_mult
			mult_parts.append({"label": "Vigour", "v": d.cane_mult})
	res.chips = chips
	res.mult = mult
	res.score = chips * mult
	res.steps = _steps(run, res, paper + ink, fac, def.chips, def.mult, def.name)
	return res


static func _has_sym(cards: Array, sym: String) -> bool:
	for c: RulesCard in cards:
		if c.sym == sym:
			return true
	return false


# ---------- the score, step by step ----------

# The score of an allowed play as the steps a table performs it in, one card at a time: the
# hand's base; each Root, by Lamp, Heart, Mirror (Paper before Ink, then by id), with its
# gauge bonus right after it; each Factor, by Cup, Eye, Lock, Pen, Cane (then by id), with
# its effect right after it; then stored restraint, one step a point, and The Cane.
#
# A step is {kind, id, of, sym, gauge, chips, mult, label, chips_to, mult_to}. `kind` is
# "base", "root", "gauge", "factor", "effect", "again", "stored" or "instrument". `id` is
# the card that acts (-1 for the base, stored restraint and The Cane); `of` is the Root an
# effect counts or an "again" repeats (-1 otherwise); `sym` is the Root's symbol ("" for none).
# `gauge` names a gauge step's source: "temper", "habit" or "burst". `chips` and `mult` are
# what the step adds (the base step's are the hand's own); `chips_to` and `mult_to` are the
# running totals after it, so the last step's are the play's chips and mult.
#
# - Temper fires once a symbol, after the first Paper Root of it; Habit after every Ink Root.
# - A Sublimation's Ink Root scores at the Craving its symbol has then, and its burst follows.
# - Reason gives one step for each different Paper symbol, Alibi one for each Ink Root of
#   the largest matching set, each naming that Root in `of`.
# - Vigour and Restlessness: an "again" step for the best Root, then their mult.
# - Curiosity, Impulse, Resolve and Cunning have an effect step that adds nothing.
# - A Passing Thought's base is the one Factor's chips times 1, and its Factors add nothing.
# - Hunted: the base step's mult is already halved.
static func _steps(run: RulesRun, res: Dictionary, roots: Array, fac: Array, base_chips: int, base_mult: int, base_label: String) -> Array:
	var d := run.dials
	var st: String = run.stance
	var thought: bool = res.kind == "thought"
	var sub: bool = res.kind == "sublimation"
	var out: Array = []
	_step(out, "base", -1, -1, "", base_chips, base_mult, base_label)
	var order := _in_order(roots)
	var now: Dictionary = run.craving.duplicate()
	var firsts: Array = []
	var cnt := {}
	for c: RulesCard in order:
		var name := Rules.name_of(c, st)
		if sub and c.ink:
			var craving: int = now[c.sym]
			_step(out, "root", c.id, -1, c.sym, Rules.chips_of(run, c, craving), 0, name)
			_step(out, "gauge", c.id, -1, c.sym, 0, d.burst_mult + d.burst_craving_mult * craving, "burst", "burst")
			now[c.sym] = 0
			continue
		_step(out, "root", c.id, -1, c.sym, Rules.chips_of(run, c), 0, name)
		cnt[c.sym] = int(cnt.get(c.sym, 0)) + 1
		if st == "hyde":
			var h: int = d.habit_mult * run.habit[c.sym]
			if h > 0:
				_step(out, "gauge", c.id, -1, c.sym, 0, h, "Habit", "habit")
		elif cnt[c.sym] == 1:
			firsts.append(c)
			if run.temper[c.sym] > 0:
				_step(out, "gauge", c.id, -1, c.sym, 0, d.temper_mult * run.temper[c.sym], "Temper", "temper")
	# The Roots Alibi counts: those of the largest matching set, first by Lamp, Heart, Mirror.
	var largest: Array = []
	if st == "hyde":
		for sym in RulesConfig.ROOTS:
			var alike: Array = []
			for c: RulesCard in order:
				if c.sym == sym:
					alike.append(c)
			if alike.size() > largest.size():
				largest = alike
	var active: Array = []
	for c: RulesCard in order:
		if c.ink == (st == "hyde"):
			active.append(c)
	var top: RulesCard = null if active.is_empty() else best_root(run, active)
	var factors := _in_order(fac)
	for f: RulesCard in factors:
		_step(out, "factor", f.id, -1, "", 0 if thought else d.factor_chips, 0, _factor_name(f.kind, st))
		match f.kind:
			"cup":
				if thought:
					pass
				elif st == "hyde":
					_step(out, "effect", f.id, -1, "", d.glee_chips, 0, "Glee")
				else:
					_step(out, "effect", f.id, -1, "", 0, d.cheer_mult, "Good Cheer")
			"eye":
				_step(out, "effect", f.id, -1, "", 0, 0, "draws 1 more")
			"lock":
				if st == "jekyll":
					_step(out, "effect", f.id, -1, "", 0, 0, "no restraint")
				elif not thought:
					_step(out, "effect", f.id, -1, "", 0, 0, "no Craving")
			"pen":
				for c: RulesCard in (largest if st == "hyde" else firsts):
					_step(out, "effect", f.id, c.id, c.sym, 0, d.pen_mult, _factor_name(f.kind, st))
			"cane":
				if top != null:
					_step(out, "again", f.id, top.id, top.sym, Rules.chips_of(run, top), 0, Rules.name_of(top, st) + " again")
					_step(out, "effect", f.id, -1, "", 0, d.cane_mult, _factor_name(f.kind, st))
	if st == "hyde" and not thought:
		for i in run.stored:
			_step(out, "stored", -1, -1, "", 0, d.restraint_pay, "stored restraint")
		if res.key == "mania" and Rules.has_inst(run, "hcane"):
			_step(out, "instrument", -1, -1, "", 0, d.hcane_mult, "The Cane")
	return out


# A sorted copy of Roots or of Factors: Roots by Lamp, Heart, Mirror, Paper before Ink,
# Factors by Cup, Eye, Lock, Pen, Cane, and cards that are alike by id.
static func _in_order(cards: Array) -> Array:
	var out: Array = []
	var ranks := PackedInt32Array()
	for c: RulesCard in cards:
		var rank: int = RulesConfig.FACTORS.find(c.kind) if c.kind != "" else RulesConfig.ROOTS.find(c.sym) * 2 + int(c.ink)
		var i := out.size()
		while i > 0 and (rank < ranks[i - 1] or (rank == ranks[i - 1] and c.id < int(out[i - 1].id))):
			i -= 1
		out.insert(i, c)
		ranks.insert(i, rank)
	return out


static func _step(out: Array, kind: String, id: int, of: int, sym: String, chips: int, mult: int, label: String, gauge: String = "") -> void:
	var chips_to := chips
	var mult_to := mult
	if not out.is_empty():
		chips_to += int(out[-1].chips_to)
		mult_to += int(out[-1].mult_to)
	out.append({
		"kind": kind, "id": id, "of": of, "sym": sym, "gauge": gauge, "chips": chips, "mult": mult,
		"label": label, "chips_to": chips_to, "mult_to": mult_to,
	})


# ---------- a play read from the counts of its kinds ----------
#
# What a play scores depends only on how many cards of each kind it holds, so a search can
# read it from eleven counts, without the labels, parts and steps a table shows. The counts
# are kept in the order of _TALLY: the Paper Roots (Lamp, Heart, Mirror), the Ink Roots, then
# the Factors (Cup, Eye, Lock, Pen, Cane). The numbers below are filled by _prepare for one
# run and read by _count_score; _count_score leaves what it found in the _r_ ones.

const _TALLY := {"lamp": 0, "heart": 1, "mirror": 2, "cup": 6, "eye": 7, "lock": 8, "pen": 9, "cane": 10}
const _KINDS := 11

static var _q_d: RulesDials
static var _q_hyde := false
static var _q_hunted := false
static var _q_hcane := false
static var _q_cap := 1
## Mult from stored restraint.
static var _q_stored := 0
## The chips of a Paper Root and of an Ink Root of each symbol.
static var _q_paper := PackedInt32Array([0, 0, 0])
static var _q_ink := PackedInt32Array([0, 0, 0])
## The mult a symbol's Temper gives, and its Habit for each Ink Root.
static var _q_temper := PackedInt32Array([0, 0, 0])
static var _q_habit := PackedInt32Array([0, 0, 0])
static var _q_craving := PackedInt32Array([0, 0, 0])

static var _r_kind := ""
static var _r_key := ""
static var _r_name := ""
static var _r_chips := 0
static var _r_mult := 0
## The place of the best Root's symbol, or -1.
static var _r_top := -1

## The hand a count of different symbols and a largest set make, by stance: [key, chips, mult, name].
static var _hand_cache := {}
static var _tally := PackedInt32Array()

# The search of a hand: its groups of like cards, the counts of the set being built, and the
# best set so far.
static var _w_groups: Array = []
static var _w_t := PackedInt32Array()
## How many of the groups, the first ones, are Ink Roots that Jekyll may only turn.
static var _w_inks := 0
static var _w_mask := 0
static var _w_key := 0.0
static var _w_all: Array = []
static var _w_keep := false


## Reads a play of these cards as evaluate does, but gives only what the play does, for a
## search that reads many: {ok: false} when the play is not allowed, and otherwise `ok`,
## `kind`, `key`, `name`, `chips`, `mult`, `score`, `adds_restraint`, `no_craving`, `craving_on`,
## `breeds`, `turns`, `temper_gain`, `spends_stored`, `cheque` and `draws`, each as evaluate
## gives it (`craving_on` and `temper_gain` list their symbols Lamp, Heart, Mirror).
static func read(run: RulesRun, cards: Array) -> Dictionary:
	_prepare(run)
	var t := _tally
	t.fill(0)
	for c: RulesCard in cards:
		if c.kind != "":
			t[_TALLY[c.kind]] += 1
		elif c.ink:
			t[_TALLY[c.sym] + 3] += 1
		else:
			t[_TALLY[c.sym]] += 1
	var score := _count_score(t)
	if score < 0:
		return {"ok": false}
	var d := _q_d
	var res := {
		"ok": true, "kind": _r_kind, "key": _r_key, "name": _r_name, "chips": _r_chips, "mult": _r_mult, "score": score,
		"adds_restraint": false, "no_craving": false, "craving_on": {}, "breeds": [], "turns": [],
		"temper_gain": {}, "spends_stored": false, "cheque": false, "draws": t[7],
	}
	if _r_kind == "thought":
		res.adds_restraint = not _q_hyde and t[8] == 0
		res.no_craving = true
	elif _r_kind == "sublimation":
		var inks: Array = []
		for c: RulesCard in cards:
			if c.kind == "" and c.ink:
				# Lamp before Heart before Mirror, then by id.
				var rank: int = _TALLY[c.sym] * 0x100000000 + c.id
				var i := inks.size()
				while i > 0 and rank < int(inks[i - 1][0]):
					i -= 1
				inks.insert(i, [rank, c.id])
		for e: Array in inks:
			res.turns.append(e[1])
		for i in 3:
			if t[3 + i] > 0:
				res.temper_gain[RulesConfig.ROOTS[i]] = _q_craving[i]
	elif _q_hyde:
		res.no_craving = t[8] > 0
		if not res.no_craving:
			var on: Dictionary = res.craving_on
			for i in 3:
				if t[3 + i] > 0:
					var sym: String = RulesConfig.ROOTS[i]
					var points: int = 1 + (t[10] if i == _r_top else 0)
					on[sym] = points
					@warning_ignore("integer_division")
					var copies: int = (_q_craving[i] + points) / d.craving_cap
					for j in copies:
						res.breeds.append(sym)
		res.spends_stored = run.stored > 0
		res.cheque = Rules.has_inst(run, "cheque")
	else:
		res.adds_restraint = t[8] == 0
	return res


## The highest-scoring allowed play in the hand, chosen as best chooses it, with the reading
## that read gives in place of evaluate's: {key, ev, ids}, or {} if there is none.
static func best_read(run: RulesRun) -> Dictionary:
	var hand := _hand_cards(run)
	var found := _search(run, hand, false)
	if found == 0:
		return {}
	var cards := _of_mask(hand, found)
	var reading := read(run, cards)
	return {"key": int(reading.score) - cards.size() * 0.001, "ev": reading, "ids": _ids(cards)}


## Every allowed play of the hand, once for each different set of card kinds (the plays best
## reads), best first: the highest score, then the fewest cards, then the cards that come
## first in the hand. Each is {ids, score, key}, `key` the hand's key. The first is best's.
static func plays(run: RulesRun) -> Array:
	var hand := _hand_cards(run)
	_search(run, hand, true)
	var found: Array = _w_all
	_w_all = []
	found.sort()
	var out: Array = []
	for e: Array in found:
		out.append({"ids": _ids(_of_mask(hand, e[2])), "score": -int(e[0]), "key": e[3]})
	return out


static func _hand_cards(run: RulesRun) -> Array:
	var hand: Array = []
	for id: int in run.hand:
		hand.append(Rules.card(run, id))
	return hand


# The cards of a set: those of the hand whose bit the number holds, in the hand's order.
static func _of_mask(hand: Array, mask: int) -> Array:
	var out: Array = []
	for i in hand.size():
		if mask & (1 << i):
			out.append(hand[i])
	return out


static func _ids(cards: Array) -> Array:
	var ids: Array = []
	for c: RulesCard in cards:
		ids.append(c.id)
	return ids


# The numbers of a run that a play's score is made of.
static func _prepare(run: RulesRun) -> void:
	var d := run.dials
	_q_d = d
	_q_hyde = run.stance == "hyde"
	_q_hunted = _q_hyde and Rules.twist_now(run) == "hunted"
	_q_hcane = Rules.has_inst(run, "hcane")
	_q_cap = Rules.turn_cap(run)
	_q_stored = run.stored * d.restraint_pay if run.stored > 0 else 0
	for i in 3:
		var sym: String = RulesConfig.ROOTS[i]
		var craving: int = run.craving[sym]
		var habit: int = run.habit[sym]
		var temper: int = run.temper[sym]
		_q_craving[i] = craving
		_q_paper[i] = d.root_chips + d.temper_chips * temper
		_q_ink[i] = d.root_chips + d.craving_chips * craving + d.habit_chips * habit
		_q_temper[i] = d.temper_mult * temper if temper > 0 else 0
		_q_habit[i] = d.habit_mult * habit
	if _tally.size() != _KINDS:
		_tally.resize(_KINDS)
		_w_t.resize(_KINDS)


# The score of the play with these counts for the run _prepare was given, or -1 if it is not
# allowed. Follows evaluate and _sublimation line for line.
static func _count_score(t: PackedInt32Array) -> int:
	var d := _q_d
	var np: int = t[0] + t[1] + t[2]
	var ni: int = t[3] + t[4] + t[5]
	var cup: int = t[6]
	var pen: int = t[9]
	var cane: int = t[10]
	var nf: int = cup + t[7] + t[8] + pen + cane
	var n: int = np + ni + nf
	if n == 0 or n > d.max_play:
		return -1
	var hyde := _q_hyde
	if hyde:
		if np > 0:
			return -1
	elif ni > 0:
		return _count_sublimation(t, np, ni, nf)
	if (ni if hyde else np) == 0:
		_r_kind = "thought"
		_r_key = "thought"
		_r_name = RulesConfig.THOUGHT_NAME
		_r_chips = d.factor_chips
		_r_mult = 1
		_r_top = -1
		return d.factor_chips
	var at := 3 if hyde else 0
	var a0: int = t[at]
	var a1: int = t[at + 1]
	var a2: int = t[at + 2]
	var different: int = (1 if a0 > 0 else 0) + (1 if a1 > 0 else 0) + (1 if a2 > 0 else 0)
	var most: int = maxi(a0, maxi(a1, a2))
	var def: Array = _hand_of(hyde, different, most)
	var worth := _q_ink if hyde else _q_paper
	var chips: int = int(def[1]) + a0 * worth[0] + a1 * worth[1] + a2 * worth[2] + d.factor_chips * nf
	# The best Root: the most chips, ties Lamp, Heart, Mirror.
	var top := -1
	var top_chips := -1
	if a0 > 0:
		top = 0
		top_chips = worth[0]
	if a1 > 0 and worth[1] > top_chips:
		top = 1
		top_chips = worth[1]
	if a2 > 0 and worth[2] > top_chips:
		top = 2
		top_chips = worth[2]
	if cane > 0:
		chips += top_chips * cane
	var mult: int = def[2]
	if hyde:
		if _q_hunted:
			mult = int(ceil(mult / 2.0))
		chips += d.glee_chips * cup
		mult += a0 * _q_habit[0] + a1 * _q_habit[1] + a2 * _q_habit[2] + _q_stored \
				+ d.pen_mult * most * pen + d.cane_mult * cane
		if _q_hcane and def[0] == "mania":
			mult += d.hcane_mult
	else:
		if a0 > 0:
			mult += _q_temper[0]
		if a1 > 0:
			mult += _q_temper[1]
		if a2 > 0:
			mult += _q_temper[2]
		mult += d.cheer_mult * cup + d.pen_mult * different * pen + d.cane_mult * cane
	_r_kind = "hand"
	_r_key = def[0]
	_r_name = def[3]
	_r_chips = chips
	_r_mult = mult
	_r_top = top
	return chips * mult


# A Sublimation's score from its counts, or -1.
static func _count_sublimation(t: PackedInt32Array, np: int, ni: int, nf: int) -> int:
	var d := _q_d
	if ni > _q_cap or np > ni or nf > 1:
		return -1
	var def: Dictionary = RulesConfig.HANDS.jekyll.sublimation
	var chips: int = def.chips
	var mult: int = def.mult
	var symbols := 0
	var top_chips := -1
	for i in 3:
		var papers: int = t[i]
		var inks: int = t[3 + i]
		if (papers > 0) != (inks > 0):
			return -1
		if papers == 0:
			continue
		symbols += 1
		chips += papers * _q_paper[i]
		mult += _q_temper[i]
		if _q_paper[i] > top_chips:
			top_chips = _q_paper[i]
		# The first of a symbol's Ink Roots turns at its Craving, the next at none.
		var craving: int = _q_craving[i]
		chips += _q_ink[i]
		mult += d.burst_mult + d.burst_craving_mult * craving
		if inks > 1:
			chips += (inks - 1) * (_q_ink[i] - d.craving_chips * craving)
			mult += (inks - 1) * d.burst_mult
	if nf == 1:
		chips += d.factor_chips
		if t[6] == 1:
			mult += d.cheer_mult
		elif t[9] == 1:
			mult += d.pen_mult * symbols
		elif t[10] == 1:
			chips += top_chips
			mult += d.cane_mult
	_r_kind = "sublimation"
	_r_key = "sublimation"
	_r_name = def.name
	_r_chips = chips
	_r_mult = mult
	_r_top = -1
	return chips * mult


# The hand that Roots of `different` symbols, the largest set of `most`, make: the one with
# the highest chips x mult that they fit, as [key, chips, mult, name].
static func _hand_of(hyde: bool, different: int, most: int) -> Array:
	var code: int = (16 if hyde else 0) + different * 4 + mini(most, 3)
	var got: Variant = _hand_cache.get(code)
	if got != null:
		return got
	var table: Dictionary = RulesConfig.HANDS.hyde if hyde else RulesConfig.HANDS.jekyll
	var fits: Array[String] = []
	if hyde:
		fits.append("stirring")
		if different >= 2: fits.append("lapse")
		if different >= 3: fits.append("turmoil")
		if most >= 2: fits.append("fixation")
		if most >= 3: fits.append("mania")
	else:
		fits.append("spark")
		if most >= 2: fits.append("rumination")
		if different >= 2: fits.append("goodwork")
		if most >= 3: fits.append("dogma")
		if different >= 3: fits.append("lucid")
	var key: String = fits[0]
	for k in fits:
		if int(table[k].chips) * int(table[k].mult) > int(table[key].chips) * int(table[key].mult):
			key = k
	var out: Array = [key, int(table[key].chips), int(table[key].mult), str(table[key].name)]
	_hand_cache[code] = out
	return out


# Looks through the hand's plays, one for each different set of card kinds, and returns the
# best as a number with one bit a hand card (0 for none): the highest score, then the fewest
# cards, then the lowest number, which is the play evaluate would be given first. Of the
# plays with the same kinds that is the one made of the first cards of each kind. With
# `keep`, every allowed play is also left in _w_all as [-score, cards, number, key].
static func _search(run: RulesRun, hand: Array, keep: bool) -> int:
	_prepare(run)
	var by_kind: Array = []
	by_kind.resize(_KINDS)
	for i in hand.size():
		var c: RulesCard = hand[i]
		var k: int = _TALLY[c.kind] if c.kind != "" else (_TALLY[c.sym] + (3 if c.ink else 0))
		if by_kind[k] == null:
			by_kind[k] = PackedInt64Array([0])
		var sets: PackedInt64Array = by_kind[k]
		# The set of the first cards of this kind, for each count of them.
		sets.append(sets[-1] | (1 << i))
		by_kind[k] = sets
	_w_groups = []
	_w_inks = 0
	if _q_hyde:
		# His stance plays none of Jekyll's Roots.
		for k in range(3, _KINDS):
			if by_kind[k] != null:
				_w_groups.append([k, by_kind[k]])
	else:
		# Jekyll plays Ink Roots only in a Sublimation, so they are chosen first, and with
		# any of them few other cards can follow.
		for k: int in [3, 4, 5, 0, 1, 2, 6, 7, 8, 9, 10]:
			if by_kind[k] != null:
				_w_groups.append([k, by_kind[k]])
				if k >= 3 and k < 6:
					_w_inks += 1
	_w_t.fill(0)
	_w_mask = 0
	_w_key = 0.0
	_w_all = []
	_w_keep = keep
	_walk(0, run.dials.max_play, 0, 0, _q_cap)
	_w_groups = []
	return _w_mask


# Takes none to all of the cards of group `at`, then of the groups after it. `left` more
# cards may be taken on top of the `size` taken, as the set `mask`; `turns` more Ink Roots
# while Jekyll has the table.
static func _walk(at: int, left: int, size: int, mask: int, turns: int) -> void:
	if at == _w_groups.size():
		if mask == 0:
			return
		var score := _count_score(_w_t)
		if score < 0:
			return
		var key: float = score - size * 0.001
		if _w_mask == 0 or key > _w_key or (key == _w_key and mask < _w_mask):
			_w_mask = mask
			_w_key = key
		if _w_keep:
			_w_all.append([-score, size, mask, _r_key])
		return
	if at == _w_inks and size > 0:
		# A Sublimation: no more Paper Roots than Ink Roots, and one Factor at most.
		left = mini(left, size + 1)
	var group: Array = _w_groups[at]
	var kind: int = group[0]
	var sets: PackedInt64Array = group[1]
	var most: int = mini(sets.size() - 1, left)
	if at < _w_inks:
		most = mini(most, turns)
		for n in most + 1:
			_w_t[kind] = n
			_walk(at + 1, left - n, size + n, mask | sets[n], turns - n)
	else:
		for n in most + 1:
			_w_t[kind] = n
			_walk(at + 1, left - n, size + n, mask | sets[n], turns)
	_w_t[kind] = 0
