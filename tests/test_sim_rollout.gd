extends "res://tests/case.gd"
## The player that plays the round out before it chooses, and the worth it reads at the end.


func _player(spec: String, run: RulesRun, run_seed: int) -> SimPlayer:
	var player := SimPlayer.make(spec)
	player.begin(run, run_seed)
	return player


func _kinds(moves: Array) -> Array:
	var out: Array = []
	for m: Dictionary in moves:
		out.append(m.t)
	return out


func test_moves() -> void:
	var run := fresh({}, 2)
	var h := deal(run, "P:lamp P:lamp P:lamp P:heart P:mirror F:cup F:eye F:lock")
	var moves := SimRollout.moves(run, 3)
	var plays := RulesHands.plays(run)
	var keys := {}
	var n := 0
	for m: Dictionary in moves:
		if m.t == "play":
			keys[m.key] = true
			n += 1
	var all_keys := {}
	for p: Dictionary in plays:
		all_keys[p.key] = true
	for i in 3:
		eq([moves[i].t, moves[i].ids, moves[i].score], ["play", plays[i].ids, plays[i].score], "the best plays by score come first")
	eq(keys.size(), all_keys.size(), "a play of every hand that can be made")
	ok(n >= 3 and n <= 3 + all_keys.size(), "and no more than the best few and one of each other hand")
	ok(not _kinds(moves).has("drink"), "no draught in the first round")
	ok(not _kinds(moves).has("pass"), "no pass with a play in hand")
	# The discard of everything outside the best play.
	var away: Array = []
	for m: Dictionary in moves:
		if m.t == "discard":
			away.append(m.ids)
	eq(away.size(), 1, "with no dead card, one discard")
	for id: int in away[0]:
		ok(not (plays[0].ids as Array).has(id), "of cards outside the best play")
	# A dead card, the draught, and the salt.
	run = fresh({}, 2)
	run.round = 1
	Rules.start_round(run)
	h = deal(run, "P:lamp P:heart I:mirror F:cup P:lamp P:heart P:lamp P:heart")
	moves = SimRollout.moves(run)
	ok(_kinds(moves).has("drink"), "the draught when it is allowed")
	var dead_first := false
	for m: Dictionary in moves:
		if m.t == "discard":
			dead_first = dead_first or m.ids == [h[2].id]
	ok(dead_first, "the discard of the dead cards alone")
	run = fresh({}, 2)
	run.round = 2
	Rules.start_round(run)
	as_hyde(run)
	h = deal(run, "P:lamp P:heart P:mirror P:lamp")
	moves = SimRollout.moves(run)
	ok(_kinds(moves).has("salt"), "the salt when it is allowed")
	ok(not _kinds(moves).has("play"), "no play when the hand holds none")
	eq(moves[0], {"t": "discard", "ids": [h[0].id, h[1].id, h[2].id, h[3].id], "key": "", "score": 0}, "the whole hand is in the way")
	run.discards = 0
	ok(_kinds(SimRollout.moves(run)).has("pass"), "the pass when there is nothing to play or discard")
	for m: Dictionary in SimRollout.moves(run):
		ok(SimMoves.apply(run.copy(), m).ok, "every move is one the rules allow: %s" % m.t)


func test_plain_move_is_greedys() -> void:
	var greedy := SimPlayer.make("greedy")
	for run_seed: int in [3, 4]:
		var run := fresh({}, run_seed)
		greedy.begin(run, run_seed)
		var made := 0
		while run.phase != "end" and made < 200:
			made += 1
			if run.phase != "play":
				greedy.between(run)
				continue
			var move := greedy.choose(run)
			var plain := SimRollout.plain_move(run)
			eq([plain.t, plain.ids], [move.t, move.ids], "the plainest player's move, read bare")
			SimMoves.apply(run, move)


func test_play_out() -> void:
	var run := fresh({}, 6)
	var before := run.to_dict()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var copy := run.copy_fast()
	SimMoves.hide(copy, rng)
	SimRollout.play_out(copy, SimRollout.cheap_player())
	ok(copy.phase != "play", "the round of the copy is played to its end")
	eq(copy.history.size(), 1, "and no further")
	eq(run.to_dict(), before, "the run itself is as it was")
	if not ResourceLoader.exists(SimRollout.PERSONA):
		ok((SimRollout.cheap_player("dance").get_script() as Script).resource_path.ends_with("greedy.gd"), "with no persona player the cheap player is the plainest")


func test_value() -> void:
	var w := SimValue.weights
	var shares: float = w.alive + w.line + w.power + w.salt + w.sov + w.table
	ok(absf(shares - 1.0) < 0.000001, "the shares add up to 1")
	var run := fresh({}, 5)
	var first := SimValue.of(run)
	ok(first > 0.0 and first < 1.0, "a run that goes on is worth something between")
	win_scene(run)
	eq(run.phase, "result", "a round won")
	var won := SimValue.of(run)
	ok(won >= float(w.alive) and won < 1.0, "a round won is worth at least a run alive")
	eq(SimValue.next_round(run), {"night": 0, "round": 1}, "the round to come")
	# Each part moves the worth its own way.
	var better := run.copy()
	better.temper.lamp = 4
	ok(SimValue.jekyll_play(better) > SimValue.jekyll_play(run), "Temper makes his play")
	better.night = 3
	var plain := run.copy()
	plain.night = 3
	ok(SimValue.of(better) > SimValue.of(plain), "Temper against the target to come")
	var habit := plain.copy()
	habit.habit.heart = 3
	ok(SimValue.hyde_play(habit) > SimValue.hyde_play(plain), "Habit makes Hyde's play")
	ok(SimValue.hyde_play(habit, true) < SimValue.hyde_play(habit), "less when he is hunted")
	var poor := run.copy()
	poor.salt = 0
	poor.sov = 0
	ok(SimValue.of(poor) < SimValue.of(run), "salt and sovereigns")
	var stained := run.copy()
	for i in 3:
		push(stained, "I:lamp")
	ok(SimValue.parts(stained).line < SimValue.parts(run).line, "the lead on the line")
	var his := run.copy()
	his.stance = "hyde"
	ok(SimValue.parts(his).table < SimValue.parts(run).table, "who has the table before an ordinary round")
	# The numbers given are the ones guessed by.
	var other := w.duplicate()
	other.alive = 0.0
	ok(SimValue.of(run, other) < won, "the numbers can be given")
	# The ends.
	var lost := run.copy()
	Rules.continue_result(lost, null)
	Rules.give_up(lost)
	eq(SimValue.of(lost), 0.0, "a lost run is worth nothing")
	lost.ending = "myself"
	eq(SimValue.of(lost), 1.0, "a won run is worth everything")


func test_choose() -> void:
	var run := fresh({}, 12)
	run.round = 1
	Rules.start_round(run)
	var before := run.to_dict()
	var player := _player("rollout?samples=3", run, 12)
	eq([player.samples, player.top], [3, SimRollout.TOP], "the numbers of its name")
	var move := player.choose(run)
	eq(run.to_dict(), before, "choosing leaves the run as it was")
	var options: Array = move.options
	ok(options.size() > 1, "it gives the moves it weighed")
	eq([move.t, move.ids], [options[0].t, options[0].ids], "and makes the first of them")
	var last := 2.0
	for o: Dictionary in options:
		ok(float(o.value) >= 0.0 and float(o.value) <= 1.0 and float(o.value) <= last, "each with its mean, best first")
		last = o.value
		eq(o.keys(), ["t", "ids", "key", "value"], "an option's keys")
	ok(SimMoves.apply(run.copy(), move).ok, "the move is allowed")
	# One seed, one choice.
	var again := _player("rollout?samples=3", run, 12).choose(run)
	eq(again, move, "one seed gives the same choice")
	# It does not read the order of the draw pile.
	var turned := run.copy()
	turned.draw.reverse()
	turned.seed = run.seed + 1
	eq(_player("rollout?samples=3", turned, 12).choose(turned), move, "whatever order the draw pile has")
	# A weight of its name is its own, not everyone's.
	var keen := SimPlayer.make("rollout?samples=2&line=0.5")
	eq([keen.weights.line, SimValue.weights.line == 0.5], [0.5, false], "a weight of its name is its own")
