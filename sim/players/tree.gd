class_name SimTree
extends SimPlayer
## A player that searches a tree of the moves of the round before it chooses. Each visit
## takes a copy of the run whose draw pile it has shuffled itself, goes down the tree by the
## usual rule (the branch with the best mean, plus a bonus for the little-visited), adds one
## branch where the tree ends, plays the rest of the round out with a cheap player, and
## reads what the finished round is worth with SimValue. Every branch on the way down is
## given that worth. It makes the move with the best mean among those visited enough.
##
## The hand a branch leads to is not the same from one shuffle to the next, so below the
## first move a branch is not a set of cards but a kind of move: the best play of a hand,
## the second best, the discard of the dead cards, the draught (`keys`).
##
## Between rounds it does what the persona named as the variant does (`tree.pendulum`), or
## the plainest player with no variant. Below the tree the plainest player plays, which is
## fast; `below=persona` puts the persona there too, at many times the cost.
##
## Its numbers, all of which a name may change (`tree.pendulum?visits=600&explore=0.2`):
## `visits`, the visits a choice is given; `top`, how many of the best plays by score are
## tried whatever their hands; `explore`, the size of the bonus for the little-visited;
## `widen`, how fast a branch below the first move is given more moves than the plainest
## player's (0: never); `least`, the visits every first move is given before the rule
## chooses, so that one unlucky shuffle does not rule a move out; and any number of SimValue.weights by its name.

const VISITS := 240
const TOP := 3
const EXPLORE := 0.05
const WIDEN := 0.5
const LEAST := 6
## A move is chosen only if it was visited this share of the most visited move's visits.
const ENOUGH := 0.5
## A visit is stopped after this many moves in the tree.
const DEPTH_GUARD := 40


## One branch of the tree: the visits it had, the sum of what they were worth, the times it
## could be chosen, and the branches below it by their keys.
class Branch:
	var visits := 0
	var sum := 0.0
	var seen := 0
	var kids := {}

	func mean() -> float:
		return sum / visits if visits > 0 else 0.0


var visits: int = VISITS
var top: int = TOP
var explore: float = EXPLORE
var widen: float = WIDEN
var least: int = LEAST
var weights: Dictionary = {}
## Who plays below the tree, and who makes the moves between rounds.
var below: SimPlayer
var dawns: SimPlayer
## The tree of the last choice, for whoever wants to look at it.
var root: Branch

# The generator the copies are hidden with: seeded anew for each visit from the player's own.
var _deal := RandomNumberGenerator.new()


func setup(variant_name: String, with_params: Dictionary) -> void:
	visits = maxi(1, int(with_params.get("visits", VISITS)))
	top = maxi(1, int(with_params.get("top", TOP)))
	explore = maxf(0.0, float(with_params.get("explore", EXPLORE)))
	widen = maxf(0.0, float(with_params.get("widen", WIDEN)))
	least = maxi(1, int(with_params.get("least", LEAST)))
	weights = SimValue.weights.duplicate()
	for key: String in weights:
		var given: Variant = with_params.get(key)
		if given is int or given is float:
			weights[key] = float(given)
	dawns = SimRollout.cheap_player(variant_name)
	# A player of its own below the tree: what it remembers of the copies is not the run's.
	below = SimRollout.cheap_player(variant_name if str(with_params.get("below", "")) == "persona" else "")
	SimRollout.unknown_params(with_params, ["visits", "top", "explore", "widen", "least", "below"] + weights.keys())


func begin(run: RulesRun, run_seed: int) -> void:
	super(run, run_seed)
	dawns.begin(run, run_seed)
	below.begin(run, run_seed)


func choose(run: RulesRun) -> Dictionary:
	var tried := SimRollout.moves(run, top)
	root = Branch.new()
	if tried.is_empty():
		return {"t": "pass", "ids": [], "options": []}
	var firsts: Array[Branch] = []
	for i in tried.size():
		firsts.append(Branch.new())
		root.kids[i] = firsts[i]
	# With one move there is nothing to weigh.
	if tried.size() > 1:
		# The nth visit of every first move meets the same shuffle, so that the luck of the
		# draw tells them apart as little as it can.
		var seeds: Array[int] = []
		for i in visits:
			var at := _pick_first(firsts)
			var first := firsts[at]
			while seeds.size() <= first.visits:
				seeds.append(rng.randi())
			var copy := run.copy_fast()
			_deal.seed = seeds[first.visits]
			SimMoves.hide(copy, _deal)
			var worth := _visit(copy, tried[at], first)
			root.visits += 1
			root.sum += worth
	# The best mean among the moves visited enough; a move little visited is not trusted.
	var most := 0
	for b in firsts:
		most = maxi(most, b.visits)
	var order: Array = []
	for i in tried.size():
		var b := firsts[i]
		var trusted: bool = b.visits >= ENOUGH * most
		order.append([0 if trusted else 1, -b.mean(), i])
	order.sort()
	var options: Array = []
	for o: Array in order:
		var move: Dictionary = tried[o[2]]
		options.append({"t": move.t, "ids": move.ids, "key": move.key, "value": firsts[o[2]].mean()})
	return {"t": options[0].t, "ids": options[0].ids, "options": options}


func between(run: RulesRun) -> void:
	dawns.between(run)


## The visits each move of the last choice was given, in the order of SimRollout.moves.
func first_visits() -> Array[int]:
	var out: Array[int] = []
	if root != null:
		for key: Variant in root.kids:
			out.append((root.kids[key] as Branch).visits)
	return out


# ---------- one visit ----------

# The first move to visit next: the earliest of those visited the fewest times while one has
# had fewer than `least`, and after that the one the usual rule names.
func _pick_first(firsts: Array[Branch]) -> int:
	var log_n := log(maxf(1.0, root.visits))
	var best := -1
	var fewest := least
	for i in firsts.size():
		if firsts[i].visits < fewest:
			fewest = firsts[i].visits
			best = i
	if best >= 0:
		return best
	var best_u := -1.0
	for i in firsts.size():
		var b := firsts[i]
		var u := b.mean() + explore * sqrt(log_n / b.visits)
		if u > best_u:
			best_u = u
			best = i
	return best


# Makes the first move on a hidden copy, goes down the tree to where it ends, plays the round
# out and gives every branch passed what the round's end is worth. Returns that worth.
func _visit(copy: RulesRun, move: Dictionary, first: Branch) -> float:
	var night: int = copy.night
	var round_no: int = copy.round
	var path: Array[Branch] = [first]
	var at := first
	var fresh: bool = first.visits == 0
	var ok: bool = SimRollout.apply(copy, move).get("ok", false)
	var depth := 0
	while ok and copy.phase == "play" and copy.night == night and copy.round == round_no:
		depth += 1
		if fresh or depth > DEPTH_GUARD:
			SimRollout.play_out(copy, below)
			break
		var here := SimRollout.moves(copy, top)
		var names := keys(copy, here)
		var pick := _pick(at, here, names, copy)
		var label: String = names[pick]
		var next: Branch = at.kids.get(label)
		if next == null:
			next = Branch.new()
			at.kids[label] = next
			fresh = true
		path.append(next)
		at = next
		ok = SimRollout.apply(copy, here[pick]).get("ok", false)
	var worth := SimValue.of(copy, weights) if ok else 0.0
	for b in path:
		b.visits += 1
		b.sum += worth
	return worth


# The place in `here` of the move to make below a branch. A branch starts with the plainest
# player's move alone and is given another as its visits grow; among the moves it has, the
# usual rule chooses.
func _pick(at: Branch, here: Array, names: Array[String], copy: RulesRun) -> int:
	var plain := plain_place(copy, here, names)
	if not at.kids.has(names[plain]):
		return plain
	var room: bool = at.kids.size() < 1 + int(widen * sqrt(at.visits))
	var best := -1
	var best_u := -1.0
	for i in here.size():
		var kid: Branch = at.kids.get(names[i])
		if kid == null:
			if room:
				return i
			continue
		# The times a branch could be chosen, not its parent's visits: a move that is seldom
		# there is not owed the visits of one that always is.
		kid.seen += 1
		var u := kid.mean() + explore * sqrt(log(kid.seen) / kid.visits) if kid.visits > 0 else 2.0
		if u > best_u:
			best_u = u
			best = i
	return best


# ---------- for whoever reads a tree ----------

## A name for each move of SimRollout.moves that says what kind of move it is, whatever the
## cards: "play:<hand>:<n>" for the nth best play of a hand, "discard:dead" for the cards the
## man at the table cannot play, "discard:rest" for everything outside the best play,
## "discard:all" with nothing to play, and "drink", "salt", "pass".
static func keys(run: RulesRun, moves: Array) -> Array[String]:
	var out: Array[String] = []
	var of_hand := {}
	var discards := 0
	var any_play := false
	for m: Dictionary in moves:
		if m.t == "discard":
			discards += 1
		elif m.t == "play":
			any_play = true
	var met := 0
	for m: Dictionary in moves:
		match m.t:
			"play":
				var n: int = of_hand.get(m.key, 0)
				of_hand[m.key] = n + 1
				out.append("play:%s:%d" % [m.key, n])
			"discard":
				met += 1
				if not any_play:
					out.append("discard:all")
				elif discards == 2:
					out.append("discard:dead" if met == 1 else "discard:rest")
				else:
					out.append("discard:rest" if SimMoves.dead(run).is_empty() else "discard:dead")
			_:
				out.append(str(m.t))
	return out


## The place in `moves` of the move the plainest player makes: its cards in the way when the
## best play does not win the round, and the best play otherwise.
static func plain_place(run: RulesRun, moves: Array, names: Array[String]) -> int:
	var best: int = int(moves[0].score) if moves[0].t == "play" else 0
	if run.discards > 0 and run.score + best < Rules.target(run):
		for i in names.size():
			if names[i] == "discard:dead" or names[i] == "discard:all":
				return i
	if moves[0].t == "play":
		return 0
	var passes := names.find("pass")
	return passes if passes >= 0 else 0
