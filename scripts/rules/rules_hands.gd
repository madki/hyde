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
## (the symbols of the active Roots).
static func evaluate(run: RulesRun, cards: Array) -> Dictionary:
	var d := run.dials
	var st: String = run.stance
	var res := {
		"ok": false, "reason": "", "kind": "", "key": "", "row": "", "name": "",
		"chips": 0, "mult": 1, "score": 0, "parts": [], "mult_parts": [],
		"adds_restraint": false, "turns": [], "temper_gain": {}, "craving_on": {}, "breeds": [],
		"no_craving": false, "spends_stored": false, "cheque": false, "draws": 0, "scoring": [],
		"lit": {"lamp": false, "heart": false, "mirror": false},
	}
	if cards.is_empty():
		res.reason = "Choose cards for a hand."
		return res
	if cards.size() > d.max_play:
		res.reason = "A hand is up to five cards."
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
	var most: int = run.dials.max_play
	var top := {}
	# Cards of one kind score alike, so of the plays that hold the same kinds only the first
	# is read. The first is also the one that would win a tie.
	var seen := {}
	var codes: Array[int] = []
	for c: RulesCard in hand:
		codes.append(_kind_code(c))
	for m in range(1, 1 << n):
		var bits := 0
		var sign := 0
		for i in n:
			if m & (1 << i):
				bits += 1
				sign += codes[i]
		if bits > most:
			continue
		if not filter.is_valid():
			if seen.has(sign):
				continue
			seen[sign] = true
		var sel: Array = []
		for i in n:
			if m & (1 << i):
				sel.append(hand[i])
		var ev := evaluate(run, sel)
		if not ev.ok:
			continue
		if filter.is_valid() and not filter.call(ev, sel):
			continue
		var key: float = int(ev.score) - bits * 0.001
		if top.is_empty() or key > float(top.key):
			var ids: Array = []
			for c: RulesCard in sel:
				ids.append(c.id)
			top = {"key": key, "ev": ev, "ids": ids}
	return top


# A number that adds up to a different total for every different set of card kinds (up to
# 7 of a kind): 3 bits for each of the 11 kinds.
static func _kind_code(c: RulesCard) -> int:
	if c.is_factor():
		return 1 << (3 * (6 + RulesConfig.FACTORS.find(c.kind)))
	return 1 << (3 * (RulesConfig.ROOTS.find(c.sym) + (3 if c.ink else 0)))


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
	var order := Rules.sort_by(ink, func(c: RulesCard) -> Array: return [RulesConfig.ROOTS.find(c.sym), c.id])
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
	return res


static func _has_sym(cards: Array, sym: String) -> bool:
	for c: RulesCard in cards:
		if c.sym == sym:
			return true
	return false
