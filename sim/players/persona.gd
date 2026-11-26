extends SimPlayer
## One weighted policy that plays a whole run, shaped by the numbers of a persona
## (sim/personas.gd): `persona.dance`, `persona.jekyll?drink_at=3`. A variant that is no
## persona of that file is looked up in SimPersonas.FOUND_PATH. With no variant it plays
## the default numbers.
##
## It sees what a player sees: the hand, the gauges, the deck's make-up. To weigh a discard
## it tries redraws on copies whose draw pile SimMoves.hide has shuffled.

## At the brink, drinks unless a play that does not fill the meter scores this share of
## the best play.
const SAFE_SHARE := 0.6
## A reward is taken, and a card bought, when it is worth more than this.
const REWARD_OVER := 0.5
const BUY_OVER := 0.7

## The persona's numbers, every key of SimPersonas.DEFAULTS.
var p: Dictionary = SimPersonas.numbers("")
# Hyde's hands played when he last took the table.
var _hyde_since := 0
# What the worth of a play is weighed by, read from a run by _look.
var _target := 0.0
var _cushion := 0
var _hyde := false
var _at_brink := false
var _w_turn := 0.0
var _w_temper := 0.0
var _w_break := 0.0
var _w_habit := 0.0
var _min_cushion := 0


func setup(variant_name: String, with_params: Dictionary) -> void:
	var found := SimPersonas.numbers(variant_name)
	if found.is_empty():
		# The runner stops a batch at this line.
		print("SIM FAILED: No such persona: %s" % variant_name)
	else:
		p = found
	for key: Variant in SimPersonas.change(p, with_params):
		print("SIM FAILED: No such number of a persona: %s" % key)


func begin(run: RulesRun, run_seed: int) -> void:
	super(run, run_seed)
	_hyde_since = 0


func choose(run: RulesRun) -> Dictionary:
	var all := _plays(run)
	var bare := _worths(run, all)
	var hyde: bool = run.stance == "hyde"
	var hyde_hands: int = run.stats.hyde_hands
	var need: int = Rules.target(run) - run.score
	# What a play is worth with the round in reach: one that wins it is worth far more.
	var full: Array[float] = []
	var win: float = Rules.target(run) * 10.0
	for i in all.size():
		full.append(bare[i] + (win if int(all[i].score) >= need else 0.0))
	var pick := _top(full)
	var options := _options(all, full)
	if not hyde:
		if _want_drink(run, all, bare, need):
			_hyde_since = hyde_hands
			return {"t": "drink", "ids": [], "options": options}
	elif _want_salt(run, hyde_hands):
		return {"t": "salt", "ids": [], "options": options}
	if pick < 0:
		# Nothing to play: the cards in the way go, or the play is passed.
		if run.discards > 0 and not run.hand.is_empty():
			var away: Array = _discards(run, [])[0]
			options.push_front({"t": "discard", "ids": away, "key": "", "value": 0.0})
			return {"t": "discard", "ids": away, "options": options}
		return {"t": "pass", "ids": [], "options": options}
	var score: int = all[pick].score
	if run.discards > 0 and score < need and not p.no_discard:
		var found := _try_discard(run, all[pick].ids, bare[pick])
		if not found.is_empty():
			options.push_front({"t": "discard", "ids": found.ids, "key": "", "value": found.value})
			return {"t": "discard", "ids": found.ids, "options": options}
	# A play of Jekyll's that fills the meter, or a last play that falls short, gives Hyde
	# the table.
	if not hyde and (_breaks(run, all[pick]) or (run.plays <= 1 and score < need)):
		_hyde_since = hyde_hands
	return {"t": "play", "ids": all[pick].ids, "options": options}


func between(run: RulesRun) -> void:
	match run.phase:
		"result": _reward(run)
		"lab": _lab(run)
		"alley": _alley(run)
		_: SimMoves.leave(run)


# ---------- at the table ----------

# Every play the persona weighs, best score first, as {ids, score, key, ev}. `ev` is
# RulesHands.read's, and is {} for a play that is worth its score and nothing else: only a
# Sublimation, a play of Hyde's that may breed, or one of Jekyll's at the brink is read.
func _plays(run: RulesRun) -> Array:
	var out: Array = []
	var no_turn: bool = p.no_turn
	var hyde: bool = run.stance == "hyde"
	var read_all: bool = _most_bred(run) > 0 if hyde else run.restraint + 1 >= Rules.limit(run)
	for found: Dictionary in RulesHands.plays(run):
		var turns: bool = found.key == "sublimation"
		if turns and no_turn:
			continue
		var ev := {}
		if turns or read_all:
			var cards: Array = []
			for id: int in found.ids:
				cards.append(run.card_of(id))
			ev = RulesHands.read(run, cards)
		out.append({"ids": found.ids, "score": int(found.score), "key": found.key, "ev": ev})
	return out


static func _urgency(cushion: int) -> int:
	return 4 if cushion <= 1 else (2 if cushion <= 3 else 1)


# Whether this play of Jekyll's fills the meter.
static func _breaks(run: RulesRun, play: Dictionary) -> bool:
	var ev: Dictionary = play.ev
	return not ev.is_empty() and run.stance == "jekyll" and ev.kind != "sublimation" and ev.adds_restraint \
			and run.restraint + 1 >= Rules.limit(run)


# Reads from the run what the worth of its plays is weighed by.
func _look(run: RulesRun) -> void:
	_target = Rules.target(run)
	_cushion = Rules.line_info(run).cushion
	_hyde = run.stance == "hyde"
	_at_brink = run.restraint + 1 >= Rules.limit(run)
	_w_turn = p.w_turn * _urgency(_cushion)
	_w_temper = p.w_temper
	_w_break = p.w_break
	_w_habit = p.w_habit
	_min_cushion = p.min_cushion


# What a play of the run last looked at is worth, before the round's target is thought of.
func _worth(ev: Dictionary) -> float:
	var v: float = ev.score
	if _hyde:
		var bred: int = ev.breeds.size()
		if bred > 0:
			v += _target * _w_habit * bred
			if _cushion - bred < _min_cushion:
				v -= _target * 2.0 * (_min_cushion - (_cushion - bred))
	elif ev.kind == "sublimation":
		var gain := 0
		for sym: String in ev.temper_gain:
			gain += int(ev.temper_gain[sym])
		v += _target * (_w_turn * ev.turns.size() + _w_temper * gain)
	elif _at_brink and ev.adds_restraint:
		v -= _target * _w_break
	return v


# What each play is worth, before the round's target is thought of.
func _worths(run: RulesRun, all: Array) -> Array[float]:
	var out: Array[float] = []
	_look(run)
	for play: Dictionary in all:
		out.append(float(play.score) if play.ev.is_empty() else _worth(play.ev))
	return out


# The worth of the best play of the run's hand, as _worths gives it, or 0 with no play or
# none worth anything. It reads only the plays that can be the best: the plays come highest
# score first, and only a Sublimation or a play that breeds is worth more than its score.
func _best_worth(run: RulesRun) -> float:
	_look(run)
	var best := 0.0
	var no_turn: bool = p.no_turn
	var over := 0.0
	if _hyde:
		over = _target * maxf(0.0, _w_habit) * _most_bred(run)
	for found: Dictionary in RulesHands.plays(run):
		var score: float = found.score
		var turns: bool = found.key == "sublimation"
		if turns:
			if no_turn:
				continue
		elif score + over <= best:
			if _hyde:
				break
			continue
		elif not _hyde and not _at_brink:
			best = score
			continue
		var cards: Array = []
		for id: int in found.ids:
			cards.append(run.card_of(id))
		best = maxf(best, _worth(RulesHands.read(run, cards)))
	return best


# No play of Hyde's from this hand breeds more copies than this.
static func _most_bred(run: RulesRun) -> int:
	var canes := 0
	var held := {}
	for id: int in run.hand:
		var c := run.card_of(id)
		if c.kind == "cane":
			canes += 1
		elif c.is_ink():
			held[c.sym] = true
	var most := 0
	for sym: String in held:
		@warning_ignore("integer_division")
		most += (run.craving[sym] + 1 + canes) / maxi(1, run.dials.craving_cap)
	return most


# The place of the highest worth, the first of them. -1 if there is none.
static func _top(values: Array[float]) -> int:
	var pick := -1
	for i in values.size():
		if pick < 0 or values[i] > values[pick]:
			pick = i
	return pick


# The plays weighed, the highest worth first, as a player's options.
static func _options(all: Array, values: Array[float]) -> Array:
	var order: Array = []
	for i in all.size():
		order.append([-values[i], i])
	order.sort()
	var out: Array = []
	for e: Array in order:
		var play: Dictionary = all[e[1]]
		out.append({"t": "play", "ids": play.ids, "key": play.key, "value": values[e[1]]})
	return out


func _want_drink(run: RulesRun, all: Array, bare: Array[float], need: int) -> bool:
	if not Rules.can_drink(run).ok:
		return false
	if p.scene_aware and Rules.twist_now(run) == "hunted":
		return false
	# His first four Roots join, or one of Jekyll's is stained.
	var after: int = Rules.line_info(run).cushion - (2 if run.hyde_arrived else 4)
	if p.drink_asap:
		return after >= int(p.drink_min_cushion) or not run.hyde_arrived
	for play: Dictionary in all:
		if int(play.score) >= need and not _breaks(run, play):
			return false
	if run.restraint + 1 >= Rules.limit(run) and p.forced_drink:
		# Is there a play worth making that does not fill the meter?
		var best := _top(bare)
		if best < 0:
			return true
		var safe := 0
		for play: Dictionary in all:
			if not _breaks(run, play):
				safe = maxi(safe, int(play.score))
		return safe < SAFE_SHARE * int(all[best].score)
	return run.restraint >= int(p.drink_at) and after >= int(p.drink_min_cushion)


func _want_salt(run: RulesRun, hyde_hands: int) -> bool:
	if not Rules.can_salt(run).ok:
		return false
	if p.scene_aware and Rules.twist_now(run) == "hunted":
		return true
	if Rules.line_info(run).cushion <= int(p.salt_cushion) and _has_fodder(run):
		return true
	if hyde_hands < _hyde_since:
		_hyde_since = hyde_hands
	return hyde_hands - _hyde_since >= int(p.hyde_stay) and run.stored == 0 and run.salt > int(p.salt_reserve)


# Whether some symbol has one of his Roots and its paper twin in the deck: a Root to turn.
static func _has_fodder(run: RulesRun) -> bool:
	for sym in RulesConfig.ROOTS:
		if Rules.count_roots(run, true, sym) > 0 and Rules.count_roots(run, false, sym) > 0:
			return true
	return false


# The discards worth trying beside a play of the cards `keep`: the dead Roots, and the
# cards the play leaves, the dead ones first, then Roots, then Factors.
func _discards(run: RulesRun, keep: Array) -> Array:
	var most: int = run.dials.max_discard
	var dead := SimMoves.dead(run)
	var out: Array = []
	if not dead.is_empty():
		out.append(dead.slice(0, most))
	var ranked: Array = [[], [], []]
	var count := 0
	for id: int in run.hand:
		if keep.has(id):
			continue
		count += 1
		ranked[0 if dead.has(id) else (1 if run.card_of(id).is_root() else 2)].append(id)
	if count > 0 and count != dead.size():
		out.append((ranked[0] + ranked[1] + ranked[2]).slice(0, most))
	return out


# The discard expected to give a hand worth more than the play held, by `discard_gain`:
# {ids, value}, or {} when the play is better kept.
func _try_discard(run: RulesRun, keep: Array, now: float) -> Dictionary:
	var samples: int = maxi(1, p.samples)
	var best := {}
	var most: float = now * p.discard_gain
	for ids: Array in _discards(run, keep):
		var sum := 0.0
		for k in samples:
			var copy := run.copy_fast()
			SimMoves.hide(copy, rng)
			Rules.discard(copy, ids)
			sum += _best_worth(copy)
		var expected := sum / samples
		if expected > most:
			most = expected
			best = {"ids": ids, "value": expected}
	return best


# ---------- between rounds ----------

# What a card is worth as a reward or on the shelf.
func _card_worth(run: RulesRun, key: String) -> float:
	var w: float = p.get("card_" + key, 0.0)
	if RulesConfig.ROOT.has(key):
		w += p.paper_w * _urgency(Rules.line_info(run).cushion)
		# Fill the thin symbol.
		w += 0.1 * (3 - mini(3, Rules.count_roots(run, false, key)))
	return w


func _reward(run: RulesRun) -> void:
	var pick: Variant = null
	var most := REWARD_OVER
	if run.offer != null:
		for i in run.offer.size():
			var w := _card_worth(run, run.offer[i])
			if w > most:
				most = w
				pick = i
	SimMoves.leave(run, pick)


func _lab(run: RulesRun) -> void:
	match p.buys:
		"salt": _buy_salt(run, "lab")
		"dearest": _buy_dearest(run)
		_: _lab_by_numbers(run)
	Rules.leave_lab(run)


func _lab_by_numbers(run: RulesRun) -> void:
	# Instruments first, dearest wish first.
	var tools: Array = run.shop.instruments
	for key: String in p.inst_pref:
		for i in tools.size():
			if tools[i].key == key and Rules.can_buy_instrument(run, i).ok:
				Rules.buy_instrument(run, i)
	_buy_salt(run, "lab")
	# Cards, dearest wish first.
	var shelf: Array = run.shop.cards
	var order: Array = []
	for i in shelf.size():
		order.append([-_card_worth(run, shelf[i].key), i])
	order.sort()
	for e: Array in order:
		if -float(e[0]) > BUY_OVER and Rules.can_buy_card(run, e[1]).ok:
			Rules.buy_card(run, e[1])
	# Strikes: his Roots while the line is near, the least Habit first, then the fewest.
	if p.strike_ink:
		while run.sov >= RulesConfig.STRIKE_INK and int(Rules.line_info(run).cushion) < int(p.strike_cushion):
			var his := _ink_root(run)
			if his == null:
				break
			Rules.strike(run, his.id)
	for kind: String in p.strike_kinds:
		for c: RulesCard in run.cards:
			if c.is_factor() and c.kind == kind:
				if Rules.can_strike(run, c.id).ok:
					Rules.strike(run, c.id)
				break


# The Root of his to strike: of the symbol with the least Habit, then the fewest copies.
static func _ink_root(run: RulesRun) -> RulesCard:
	var syms: Array = []
	for sym in RulesConfig.ROOTS:
		var n := Rules.count_roots(run, true, sym)
		if n > 0:
			syms.append([run.habit[sym], n, RulesConfig.ROOTS.find(sym), sym])
	if syms.is_empty():
		return null
	syms.sort()
	for c: RulesCard in run.cards:
		if c.is_ink() and c.sym == syms[0][3]:
			return c
	return null


# Salt up to the doses the persona holds when it leaves a place.
func _buy_salt(run: RulesRun, where: String) -> void:
	while run.salt < int(p.salt_target) and Rules.can_buy_salt(run, where).ok:
		if where == "lab":
			Rules.buy_salt(run)
		else:
			Rules.alley_salt(run)


# The dearest thing the laboratory sells that the purse can pay for, again and again:
# an instrument before a card before a dose of salt at one price.
func _buy_dearest(run: RulesRun) -> void:
	for guard in 50:
		var things: Array = []
		var tools: Array = run.shop.instruments
		for i in tools.size():
			if Rules.can_buy_instrument(run, i).ok:
				things.append([-int(tools[i].price), 0, i])
		var shelf: Array = run.shop.cards
		for i in shelf.size():
			if Rules.can_buy_card(run, i).ok:
				things.append([-int(shelf[i].price), 1, i])
		if Rules.can_buy_salt(run, "lab").ok:
			things.append([-Rules.salt_cost(run, "lab"), 2, 0])
		if things.is_empty():
			return
		things.sort()
		match things[0][1]:
			0: Rules.buy_instrument(run, things[0][2])
			1: Rules.buy_card(run, things[0][2])
			_: Rules.buy_salt(run)


func _alley(run: RulesRun) -> void:
	# The Habit, on the symbol with the most of his Roots, then the most Habit.
	var syms: Array = []
	for sym in RulesConfig.ROOTS:
		var n := Rules.count_roots(run, true, sym)
		if n > 0:
			syms.append([-n, -run.habit[sym], RulesConfig.ROOTS.find(sym), sym])
	if not syms.is_empty():
		syms.sort()
		Rules.alley_habit(run, syms[0][3])
	for key: String in p.alley_inst:
		if Rules.can_alley_instrument(run, key).ok:
			Rules.alley_instrument(run, key)
	if p.buys == "dearest":
		# Salt is all the alley sells.
		for guard in 50:
			if not Rules.can_buy_salt(run, "alley").ok:
				break
			Rules.alley_salt(run)
	else:
		_buy_salt(run, "alley")
	Rules.alley_leave(run)
