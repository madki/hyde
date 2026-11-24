extends RefCounted
## Base of every tests/test_*.gd: the checks, and helpers to set up a run of the card game.

var checks := 0
var fails := 0
var _loose := 9000


func ok(condition: bool, msg: String) -> void:
	checks += 1
	if not condition:
		_fail(msg)


## Passes when the two are the same all the way down. 1 and 1.0 are not the same.
func eq(got: Variant, want: Variant, msg: String) -> void:
	checks += 1
	if not same(got, want):
		_fail("%s: got %s, want %s" % [msg, JSON.stringify(got), JSON.stringify(want)])


func _fail(msg: String) -> void:
	fails += 1
	if fails < 60:
		print("  FAIL: " + msg)


static func same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Object:
		# A run or a card: the same when its plain data is the same.
		return b != null and a.has_method("to_dict") and same(a.to_dict(), b.to_dict())
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	return a == b


# ---------- readings ----------

## Checks what every reading's steps must hold: they add up to the reading, each running
## total follows from the one before, and every card of the play has exactly one root or
## factor step.
func check_steps(e: Dictionary, played: Array, label: String) -> void:
	var steps: Array = e.steps
	if steps.is_empty():
		_fail(label + ": no steps")
		checks += 1
		return
	var chips := 0
	var mult := 0
	var follows := true
	for s: Dictionary in steps:
		chips += int(s.chips)
		mult += int(s.mult)
		follows = follows and int(s.chips_to) == chips and int(s.mult_to) == mult
	ok(follows, label + ": each step's totals follow from the one before")
	eq([steps[-1].chips_to, steps[-1].mult_to, chips, mult], [e.chips, e.mult, e.chips, e.mult], label + ": the steps end on the reading's chips and mult")
	eq(steps[0].kind, "base", label + ": the base comes first")
	var seen := {}
	for s: Dictionary in steps:
		if s.kind == "root" or s.kind == "factor":
			seen[s.id] = int(seen.get(s.id, 0)) + 1
	var once := {}
	for id: int in played:
		once[id] = 1
	eq(seen, once, label + ": each card has one root or factor step")


# ---------- cards and runs ----------

## A card that is in no deck, for evaluate only. "P:lamp" is a Paper Root, "I:lamp" an Ink
## Root, "F:cup" a Factor.
func loose(spec: String) -> RulesCard:
	_loose += 1
	return _card(_loose, spec)


func cards(list: String) -> Array:
	var out: Array = []
	for spec in list.split(" "):
		out.append(loose(spec))
	return out


static func _card(id: int, spec: String) -> RulesCard:
	return RulesCard.make(id, spec.substr(2), spec[0] == "I")


static func _fits(c: RulesCard, spec: String) -> bool:
	var key := spec.substr(2)
	if spec[0] == "F":
		return c.t == "factor" and c.kind == key
	return c.t == "root" and c.sym == key and c.ink == (spec[0] == "I")


func fresh(dials: Dictionary = {}, seed_value: int = 1) -> RulesRun:
	return Rules.new_run(dials, seed_value)


## Puts a new card straight into the deck (not into any pile).
static func push(run: RulesRun, spec: String) -> RulesCard:
	run.uid += 1
	var c := _card(run.uid, spec)
	run.cards.append(c)
	return c


## Puts the hand back on the draw pile and deals exactly these cards, taking them from the
## piles or making them. Returns the cards.
static func deal(run: RulesRun, list: String) -> Array:
	run.draw.append_array(run.hand)
	run.hand = []
	var out: Array = []
	for spec in list.split(" "):
		var c: RulesCard = null
		for pile: Array in [run.draw, run.discard]:
			if c != null:
				break
			for i in pile.size():
				var x := Rules.card(run, pile[i])
				if _fits(x, spec):
					c = x
					pile.remove_at(i)
					break
		if c == null:
			c = push(run, spec)
		run.hand.append(c.id)
		out.append(c)
	return out


static func ids(cs: Array) -> Array:
	var out: Array = []
	for c: RulesCard in cs:
		out.append(c.id)
	return out


static func ink_n(run: RulesRun, sym: String = "") -> int:
	return Rules.count_roots(run, true, sym)


static func paper_n(run: RulesRun, sym: String = "") -> int:
	return Rules.count_roots(run, false, sym)


## Jumps to a round (both counted from 0) and deals it.
static func at(run: RulesRun, night: int, round_no: int) -> RulesRun:
	run.night = night
	run.round = round_no
	Rules.start_round(run)
	return run


static func as_hyde(run: RulesRun) -> RulesRun:
	run.stance = "hyde"
	run.hyde_arrived = true
	run.restraint = 0
	return run


## Puts his first four Roots in the deck and deals the round again.
static func first_arrival(run: RulesRun) -> void:
	for sym in RulesConfig.FIRST_ARRIVAL:
		push(run, "I:" + sym)
	Rules.start_round(run)


## Brings the round one point short of its target and wins it with a one-Root play that adds
## no restraint and no Craving.
static func win_scene(run: RulesRun) -> RulesRun:
	run.score = Rules.target(run) - 1
	var own := "P:lamp" if run.stance == "jekyll" else "I:lamp"
	var h := deal(run, own + " F:lock P:heart P:mirror P:lamp P:heart F:cup F:eye")
	Rules.play(run, [h[0].id, h[1].id])
	return run
