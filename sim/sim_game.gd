class_name SimGame
## Plays whole runs of the card game with a SimPlayer, and gives each as one line of data.

## A run that makes this many moves is ended, with `by: "guard"`.
const GUARD := 5000


## Plays one run to its end and returns its line for runs.jsonl:
## {seed, player, ending, by, night, round, rounds, moves, stats, inst, sov, salt, deck, ink,
## paper, temper, habit, ms}.
##
## `dials` is the changed numbers of RulesDials, `give` the keys of instruments held from the
## start. `ending` is the run's ("hyde", "double", "myself"; "" if it did not end) and `by`
## what ended it: the rules' own word, "guard", or "illegal" when the player made a move the
## rules refused. `night` and `round` are where it ended, from 0. `rounds` has one
## {n, r, how, used, score, target, stance, ink, paper, sov} for each round played (`used`:
## plays and passes made; `sov`: sovereigns held when it ended) and `moves` one
## {n, r, who, t, key, score} for each move at the table. `deck` is the count of cards, `ink`
## and `paper` the counts of Roots of each side, and `ms` the time the run took, the one
## number that differs when a seed is played again.
static func play_run(player: SimPlayer, run_seed: int, dials: Dictionary = {}, give: Array = []) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var run := Rules.new_run(dials, run_seed)
	if not give.is_empty():
		# Dealt again from the same seed, so that an instrument counts from the first round.
		for key: String in give:
			if RulesConfig.INSTRUMENTS.has(key) and not run.instruments.has(key):
				run.instruments.append(key)
		run.seed = run.seed0
		Rules.start_round(run)
	player.begin(run, run_seed)
	var moves: Array = []
	var rounds: Array = []
	var used := 0
	var made := 0
	var by := ""
	while run.phase != "end":
		if made >= GUARD:
			by = "guard"
			break
		made += 1
		if run.phase != "play":
			player.between(run)
			continue
		var night: int = run.night
		var round_no: int = run.round
		var who: String = run.stance
		var move := player.choose(run)
		var res := SimMoves.apply(run, move)
		if not res.get("ok", false):
			push_error("%s, seed %d: the rules refused %s: %s" % [player.name, run_seed, JSON.stringify({"t": move.get("t"), "ids": move.get("ids")}), res.get("reason", "")])
			by = "illegal"
			break
		var t: String = move.t
		var is_play := t == "play"
		moves.append({
			"n": night, "r": round_no, "who": who, "t": t,
			"key": res.ev.key if is_play else "", "score": int(res.ev.score) if is_play else 0,
		})
		if is_play or t == "pass":
			used += 1
		if run.phase != "play":
			var h: Dictionary = run.history[-1]
			rounds.append({
				"n": h.night, "r": h.round, "how": h.how, "used": used, "score": h.score,
				"target": h.target, "stance": h.stance, "ink": h.ink, "paper": h.paper, "sov": run.sov,
			})
			used = 0
	var line := Rules.line_info(run)
	return {
		"seed": run_seed, "player": player.name,
		"ending": run.ending if run.ending != null else "",
		"by": by if by != "" else str(run.ended_by),
		"night": run.night, "round": run.round, "rounds": rounds, "moves": moves,
		"stats": run.stats.duplicate(true), "inst": run.instruments.duplicate(),
		"sov": run.sov, "salt": run.salt, "deck": run.cards.size(), "ink": line.ink, "paper": line.paper,
		"temper": run.temper.duplicate(), "habit": run.habit.duplicate(),
		"ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.001),
	}


## Whether a run's line is a win: it ended as "myself" or "double", by the last scene.
static func won(line: Dictionary) -> bool:
	return line.get("ending", "") == "myself" or line.get("ending", "") == "double"


## The rounds of a run's line that were cleared: won or rescued.
static func cleared(line: Dictionary) -> int:
	var n := 0
	for r: Dictionary in line.get("rounds", []):
		if r.how != "lost":
			n += 1
	return n
