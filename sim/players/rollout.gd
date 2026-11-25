class_name SimRollout
extends SimPlayer
## A player that looks ahead before it chooses. At each choice it takes the moves worth
## trying, and for each one plays the rest of the round out `samples` times with a cheap
## player, on copies whose draw pile it has shuffled itself; it reads what each finished
## round is worth with SimValue, and makes the move with the best mean.
##
## The cheap player is the persona named as the variant (`rollout.dance`) when there is a
## persona player, and the plainest player otherwise. Between rounds it does what the cheap
## player does.
##
## Its numbers, all of which a name may change (`rollout?samples=24&top=4`):
## `samples`, the times a move is played out; `top`, how many of the best plays by score are
## tried whatever their hands; and any number of SimValue.weights by its name.

const SAMPLES := 12
const TOP := 3
## A round played out is stopped after this many moves, whatever the cheap player does.
const ROUND_GUARD := 60
const PERSONA := "res://sim/players/persona.gd"

var samples: int = SAMPLES
var top: int = TOP
var weights: Dictionary = {}
var cheap: SimPlayer

# The generator the copies are hidden with: seeded anew for each sample from the player's own.
var _deal := RandomNumberGenerator.new()


func setup(variant_name: String, with_params: Dictionary) -> void:
	samples = maxi(1, int(with_params.get("samples", SAMPLES)))
	top = maxi(1, int(with_params.get("top", TOP)))
	weights = SimValue.weights.duplicate()
	for key: String in weights:
		var given: Variant = with_params.get(key)
		if given is int or given is float:
			weights[key] = float(given)
	cheap = cheap_player(variant_name)


func begin(run: RulesRun, run_seed: int) -> void:
	super(run, run_seed)
	cheap.begin(run, run_seed)


func choose(run: RulesRun) -> Dictionary:
	var tried := moves(run, top)
	if tried.is_empty():
		return {"t": "pass", "ids": [], "options": []}
	# Every move meets the same shuffles, so that the luck of the draw does not tell them apart.
	var seeds: Array[int] = []
	for i in samples:
		seeds.append(rng.randi())
	var options: Array = []
	for i in tried.size():
		var move: Dictionary = tried[i]
		var mean := 0.0
		# With one move there is nothing to weigh.
		if tried.size() > 1:
			mean = _mean(run, move, seeds)
		var at := options.size()
		while at > 0 and mean > float(options[at - 1].value):
			at -= 1
		options.insert(at, {"t": move.t, "ids": move.ids, "key": move.key, "value": mean})
	return {"t": options[0].t, "ids": options[0].ids, "options": options}


func between(run: RulesRun) -> void:
	cheap.between(run)


# The mean worth of the round's end when this move is made now and the cheap player plays on.
func _mean(run: RulesRun, move: Dictionary, seeds: Array[int]) -> float:
	var sum := 0.0
	for s: int in seeds:
		var copy := run.copy_fast()
		_deal.seed = s
		SimMoves.hide(copy, _deal)
		if not apply(copy, move).get("ok", false):
			return 0.0
		if copy.phase != "play":
			# The move ends the round, whatever the draw pile holds.
			return SimValue.of(copy, weights)
		play_out(copy, cheap)
		sum += SimValue.of(copy, weights)
	return sum / seeds.size()


# ---------- for any player that searches ----------

## The moves worth trying at this choice, each {t, ids, key, score}: the `best` highest plays
## by score and the best play of every other hand (`key` is the hand's key, `score` what the
## play scores); the discards, when one is left (the cards the man at the table cannot play,
## and every card outside the best play); the draught and the salt when they are allowed;
## and the pass when nothing else is. Plays come first, best first.
static func moves(run: RulesRun, best: int = TOP) -> Array:
	var out: Array = []
	if run.phase != "play":
		return out
	var seen := {}
	var plays := RulesHands.plays(run)
	for i in plays.size():
		var p: Dictionary = plays[i]
		if i < best or not seen.has(p.key):
			out.append({"t": "play", "ids": p.ids, "key": p.key, "score": p.score})
		seen[p.key] = true
	if run.discards > 0 and not run.hand.is_empty():
		var most: int = run.dials.max_play
		# The cards in the way: all of the hand when nothing can be played.
		var dead: Array = SimMoves.dead(run) if not plays.is_empty() else run.hand.duplicate()
		dead = dead.slice(0, most)
		if not dead.is_empty():
			out.append({"t": "discard", "ids": dead, "key": "", "score": 0})
		if not plays.is_empty():
			# Everything but the best play, the dead cards first.
			var rest: Array = dead.duplicate()
			for id: int in run.hand:
				if rest.size() < most and not rest.has(id) and not (plays[0].ids as Array).has(id):
					rest.append(id)
			if rest.size() > dead.size():
				out.append({"t": "discard", "ids": rest, "key": "", "score": 0})
	if Rules.can_drink(run).ok:
		out.append({"t": "drink", "ids": [], "key": "", "score": 0})
	if Rules.can_salt(run).ok:
		out.append({"t": "salt", "ids": [], "key": "", "score": 0})
	if out.is_empty() or (plays.is_empty() and Rules.can_pass(run).ok):
		out.append({"t": "pass", "ids": [], "key": "", "score": 0})
	return out


## Makes a move on a copy as SimMoves.apply makes it, with the bare play of the rules.
static func apply(copy: RulesRun, move: Dictionary) -> Dictionary:
	if move.get("t", "") == "play":
		return Rules.play_fast(copy, move.get("ids", []))
	return SimMoves.apply(copy, move)


## The player below a search: the persona of this name when there is a persona player and a
## name is given, and the plainest player otherwise.
static func cheap_player(variant_name: String = "") -> SimPlayer:
	if variant_name != "" and ResourceLoader.exists(PERSONA):
		var persona := SimPlayer.make("persona." + variant_name)
		if persona != null:
			return persona
	return SimPlayer.make("greedy")


## Plays the round of a copy to its end with a cheap player. The copy must be hidden first.
static func play_out(copy: RulesRun, with: SimPlayer) -> void:
	var plainest: bool = (with.get_script() as Script).resource_path.get_file() == "greedy.gd"
	var night: int = copy.night
	var round_no: int = copy.round
	var made := 0
	while copy.phase == "play" and copy.night == night and copy.round == round_no and made < ROUND_GUARD:
		made += 1
		var move := plain_move(copy) if plainest else with.choose(copy)
		if not apply(copy, move).get("ok", false):
			return


## The plainest player's move, found with the rules' bare reading: what greedy chooses,
## without the options it weighs.
static func plain_move(run: RulesRun) -> Dictionary:
	var best := RulesHands.best_read(run)
	var score: int = 0 if best.is_empty() else int(best.ev.score)
	if run.discards > 0 and run.score + score < Rules.target(run):
		var away: Array = SimMoves.dead(run) if not best.is_empty() else run.hand.duplicate()
		away = away.slice(0, run.dials.max_play)
		if not away.is_empty():
			return {"t": "discard", "ids": away}
	if best.is_empty():
		return {"t": "pass", "ids": []}
	return {"t": "play", "ids": best.ids}
