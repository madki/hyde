class_name SimMoves
## What a sim's player may do at the table, and how it may look ahead.


## Every allowed play of the hand, once for each different set of card kinds (cards of one
## kind score alike), as {ids, ev}: `ev` is the reading of RulesHands.evaluate. The highest
## score comes first; with the same score, fewer cards, then the earlier cards of the hand.
static func plays(run: RulesRun) -> Array:
	var hand: Array = []
	var codes: Array[int] = []
	for id: int in run.hand:
		var c := Rules.card(run, id)
		hand.append(c)
		codes.append(_kind_code(c))
	var n := hand.size()
	# Every set of up to max_play hand cards, as a number with one bit a card, with the total
	# of its cards' kind codes.
	var sets := {}
	_add_sets(codes, run.dials.max_play, 0, 0, 0, sets)
	var masks: Array = sets.keys()
	masks.sort()
	var seen := {}
	var found: Array = []
	for m: int in masks:
		if seen.has(sets[m]):
			continue
		seen[sets[m]] = true
		var sel: Array = []
		var ids: Array = []
		for i in n:
			if m & (1 << i):
				sel.append(hand[i])
				ids.append(hand[i].id)
		var ev := RulesHands.evaluate(run, sel)
		if ev.ok:
			found.append([-int(ev.score), ids.size(), found.size(), {"ids": ids, "ev": ev}])
	found.sort()
	var out: Array = []
	for f: Array in found:
		out.append(f[3])
	return out


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


## Makes a move of a player's shape, {t, ids}, through Rules, and returns what Rules returned
## ({ok, ...}, with a `reason` when it was refused).
static func apply(run: RulesRun, move: Dictionary) -> Dictionary:
	var ids: Array = move.get("ids", [])
	match move.get("t", ""):
		"play": return Rules.play(run, ids)
		"discard": return Rules.discard(run, ids)
		"drink": return Rules.drink(run)
		"salt": return Rules.take_salt(run)
		"pass": return Rules.pass_play(run)
	return {"ok": false, "reason": "No such move."}


## Makes a copy of a run fit to look ahead in: shuffles its draw pile with the player's own
## generator, and gives the copy a generator of its own, so that nothing the copy does next
## tells what the run will do. The hand, and the cards each pile holds, stay as they were.
static func hide(copy: RulesRun, rng: RandomNumberGenerator) -> void:
	var draw: Array = copy.draw
	# Sorted first, so that the order the run had leaves no trace in the order it gets.
	draw.sort()
	var i := draw.size() - 1
	while i > 0:
		var j := rng.randi_range(0, i)
		var t: Variant = draw[i]
		draw[i] = draw[j]
		draw[j] = t
		i -= 1
	copy.seed = RulesRng.wrap_seed(rng.randi())


## The ids of the hand's Roots the man at the table cannot play: Jekyll's Roots while Hyde
## has the table; for Jekyll, his Roots with no paper twin in the hand to turn them beside.
static func dead(run: RulesRun) -> Array:
	var hyde: bool = run.stance == "hyde"
	var paper := {}
	var roots: Array = []
	for id: int in run.hand:
		var c := Rules.card(run, id)
		if c.is_root():
			roots.append(c)
			if not c.ink:
				paper[c.sym] = true
	var out: Array = []
	for c: RulesCard in roots:
		if (hyde and not c.ink) or (not hyde and c.ink and not paper.has(c.sym)):
			out.append(c.id)
	return out


## Leaves phase "result", "lab" or "alley" by its plain way out. In "result", `pick` is the
## place of the offered card to take (null: none). Returns what Rules returned.
static func leave(run: RulesRun, pick: Variant = null) -> Dictionary:
	match run.phase:
		"result": return Rules.continue_result(run, pick if run.offer != null else null)
		"lab": return Rules.leave_lab(run)
		"alley": return Rules.alley_leave(run)
	return {"ok": false, "reason": "Not now."}
