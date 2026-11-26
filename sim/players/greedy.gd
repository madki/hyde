extends SimPlayer
## The plainest player, and the one the others are measured against. It plays the
## highest-scoring allowed play, discards its dead cards when it cannot win the round with
## what it holds, never drinks or takes salt of its own will, takes the first reward and
## buys nothing.


func choose(run: RulesRun) -> Dictionary:
	var plays := SimMoves.plays(run)
	var options: Array = []
	for p: Dictionary in plays:
		options.append({"t": "play", "ids": p.ids, "key": p.ev.key, "value": p.ev.score})
	var top: int = 0 if plays.is_empty() else int(plays[0].ev.score)
	if run.discards > 0 and run.score + top < Rules.target(run):
		# With nothing to play the whole hand is in the way.
		var away: Array = SimMoves.dead(run) if not plays.is_empty() else run.hand.duplicate()
		away = away.slice(0, run.dials.max_discard)
		if not away.is_empty():
			options.push_front({"t": "discard", "ids": away, "key": "", "value": top})
			return {"t": "discard", "ids": away, "options": options}
	if plays.is_empty():
		return {"t": "pass", "ids": [], "options": options}
	return {"t": "play", "ids": plays[0].ids, "options": options}


func between(run: RulesRun) -> void:
	SimMoves.leave(run, 0)
