extends "res://tests/case.gd"
## The player that searches a tree of the round's moves before it chooses.


func _player(spec: String, run: RulesRun, run_seed: int) -> SimTree:
	var player: SimTree = SimPlayer.make(spec)
	player.begin(run, run_seed)
	return player


func test_keys() -> void:
	var run := fresh({}, 2)
	deal(run, "P:lamp P:lamp P:lamp P:heart P:mirror F:cup F:eye F:lock")
	var moves := SimRollout.moves(run, 3)
	var names := SimTree.keys(run, moves)
	eq(names.size(), moves.size(), "a name for every move")
	var seen := {}
	for i in moves.size():
		ok(not seen.has(names[i]), "no two moves of one name: %s" % names[i])
		seen[names[i]] = true
		if moves[i].t == "play":
			ok(names[i].begins_with("play:%s:" % moves[i].key), "a play is named by its hand")
	eq(names[0], "play:%s:0" % moves[0].key, "the best play of its hand comes first")
	ok(seen.has("discard:rest") and not seen.has("discard:dead"), "with no dead card, the discard of the rest")
	# A dead card, and the draught.
	run = at(fresh({}, 2), 0, 1)
	deal(run, "P:lamp P:heart I:mirror F:cup P:lamp P:heart P:lamp P:heart")
	names = SimTree.keys(run, SimRollout.moves(run))
	ok(names.has("discard:dead") and names.has("discard:rest") and names.has("drink"), "the dead cards, the rest and the draught")
	# Nothing to play.
	run = as_hyde(at(fresh({}, 2), 0, 2))
	deal(run, "P:lamp P:heart P:mirror P:lamp")
	names = SimTree.keys(run, SimRollout.moves(run))
	ok(names.has("discard:all") and names.has("salt"), "the whole hand, and the salt")


func test_plain_place_is_the_plainest_players() -> void:
	var run := fresh({}, 3)
	var greedy := SimPlayer.make("greedy")
	greedy.begin(run, 3)
	var made := 0
	var met := 0
	while run.phase != "end" and made < 120:
		made += 1
		if run.phase != "play":
			greedy.between(run)
			continue
		var plain := SimRollout.plain_move(run)
		var moves := SimRollout.moves(run)
		var mine: Dictionary = moves[SimTree.plain_place(run, moves, SimTree.keys(run, moves))]
		eq(mine.t, plain.t, "the kind of move the plainest player makes")
		if plain.t == "discard":
			eq(mine.ids, plain.ids, "and its cards in the way")
		elif plain.t == "play":
			eq(mine.score, moves[0].score, "and its best play")
		met += 1
		SimMoves.apply(run, plain)
	ok(met > 10, "over the choices of a run")


func test_choose() -> void:
	var run := at(fresh({}, 12), 0, 1)
	var before := run.to_dict()
	var player := _player("tree?visits=40", run, 12)
	eq([player.visits, player.top, player.explore], [40, SimTree.TOP, SimTree.EXPLORE], "the numbers of its name")
	var move := player.choose(run)
	eq(run.to_dict(), before, "choosing leaves the run as it was")
	var options: Array = move.options
	ok(options.size() > 1, "it gives the moves it weighed")
	eq(options.size(), SimRollout.moves(run, player.top).size(), "every one of them")
	eq([move.t, move.ids], [options[0].t, options[0].ids], "and makes the first of them")
	for o: Dictionary in options:
		ok(float(o.value) >= 0.0 and float(o.value) <= 1.0, "each with its mean")
		eq(o.keys(), ["t", "ids", "key", "value"], "an option's keys")
	ok(SimMoves.apply(run.copy(), move).ok, "the move is allowed")
	# The visits.
	var given := player.first_visits()
	var sum := 0
	var most := 0
	for n in given:
		sum += n
		most = maxi(most, n)
		ok(n >= mini(player.least, 40 / given.size()), "every move is visited, and more than once")
	eq([sum, player.root.visits], [40, 40], "the visits of its name, and no more")
	var moves := SimRollout.moves(run, player.top)
	for i in moves.size():
		if moves[i].t == move.t and moves[i].ids == move.ids:
			ok(given[i] >= SimTree.ENOUGH * most, "the move made was visited enough")
	# The tree goes below the first move.
	var deep := false
	for key: Variant in player.root.kids:
		deep = deep or not (player.root.kids[key] as SimTree.Branch).kids.is_empty()
	ok(deep, "a branch below a first move")
	# One seed, one choice.
	var again := _player("tree?visits=40", run, 12).choose(run)
	eq(again, move, "one seed gives the same choice")
	# It does not read the order of the draw pile.
	var turned := run.copy()
	turned.draw.reverse()
	turned.seed = run.seed + 1
	eq(_player("tree?visits=40", turned, 12).choose(turned), move, "whatever order the draw pile has")
	# A weight of its name is its own, not everyone's.
	var keen: SimTree = SimPlayer.make("tree?visits=2&line=0.5")
	eq([keen.weights.line, SimValue.weights.line == 0.5], [0.5, false], "a weight of its name is its own")


func test_one_move_is_not_searched() -> void:
	var run := as_hyde(at(fresh({}, 2), 0, 2))
	deal(run, "P:lamp P:heart P:mirror P:lamp")
	run.discards = 0
	run.salt = 0
	var moves := SimRollout.moves(run)
	eq(moves.size(), 1, "one move")
	var player := _player("tree?visits=40", run, 2)
	var move := player.choose(run)
	eq([move.t, player.root.visits], [moves[0].t, 0], "made without a visit")


func test_the_last_play_wins_the_round_when_it_can() -> void:
	var run := fresh({}, 7)
	deal(run, "P:lamp P:lamp P:lamp P:heart P:mirror F:cup F:eye F:lock")
	var plays := RulesHands.plays(run)
	run.plays = 1
	run.discards = 0
	run.score = Rules.target(run) - int(plays[0].score)
	var move := _player("tree?visits=60", run, 7).choose(run)
	var after := run.copy()
	SimMoves.apply(after, move)
	eq([move.t, after.history.size(), after.history[-1].how if not after.history.is_empty() else ""], ["play", 1, "won"], "the play that wins the round")


func test_between_and_below() -> void:
	if not ResourceLoader.exists(SimRollout.PERSONA):
		return
	var player: SimTree = SimPlayer.make("tree.pendulum")
	ok((player.dawns.get_script() as Script).resource_path.ends_with("persona.gd"), "the persona of its name between rounds")
	ok((player.below.get_script() as Script).resource_path.ends_with("greedy.gd"), "the plainest player below the tree")
	ok(player.dawns != player.below, "two players, not one")
	player = SimPlayer.make("tree.pendulum?below=persona")
	ok((player.below.get_script() as Script).resource_path.ends_with("persona.gd"), "the persona below the tree when it is asked for")
	var run := fresh({}, 5)
	player = _player("tree.pendulum?visits=20", run, 5)
	win_scene(run)
	eq(run.phase, "result", "a round won")
	player.between(run)
	ok(run.phase != "result", "it leaves the phase between rounds")
