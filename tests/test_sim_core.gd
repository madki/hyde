extends "res://tests/case.gd"
## The sims' core: a player's moves, the run loop, and the batches on disk.


func _line(seed_value: int, dials: Dictionary = {}, give: Array = []) -> Dictionary:
	var line := SimGame.play_run(SimPlayer.make("greedy"), seed_value, dials, give)
	line.erase("ms")
	return line


func test_one_seed_one_run() -> void:
	var a := _line(7)
	var b := _line(7)
	eq(a, b, "one seed gives the same line twice")
	ok(JSON.stringify(a) != JSON.stringify(_line(8)), "and another seed another run")
	ok(a.by != "guard" and a.by != "illegal" and a.ending != "", "the run ends by the rules")
	ok(not a.rounds.is_empty() and not a.moves.is_empty(), "with its rounds and moves")
	eq(a.rounds[0].keys(), ["n", "r", "how", "used", "score", "target", "stance", "ink", "paper", "sov"], "a round's keys")
	eq(a.moves[0].keys(), ["n", "r", "who", "t", "key", "score", "gap", "lead"], "a move's keys")
	eq(SimStore.whole(JSON.parse_string(JSON.stringify(a))), a, "the line is plain data")
	# An instrument held from the start counts from the first round.
	var with := _line(7, {}, ["spirit"])
	eq(with.inst, ["spirit"], "give: the instrument is held")
	# One player plays run after run.
	var player := SimPlayer.make("greedy")
	var first := SimGame.play_run(player, 7)
	SimGame.play_run(player, 8)
	var again := SimGame.play_run(player, 7)
	first.erase("ms")
	again.erase("ms")
	eq([first, again], [a, a], "a player that has played other runs makes the same run")


func test_dials_change_the_run() -> void:
	var line := _line(7, {"target_scale": 0.2, "first_night_scale": 0.2, "plays": 6})
	ok(SimGame.cleared(line) > SimGame.cleared(_line(7)), "lower targets and more plays clear more rounds")


func test_hide() -> void:
	var run := fresh({}, 5)
	var draw: Array = run.draw.duplicate()
	var hand: Array = run.hand.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var orders := {}
	for i in 20:
		var copy := run.copy()
		SimMoves.hide(copy, rng)
		eq([copy.hand, copy.draw.size(), copy.discard], [hand, draw.size(), run.discard], "hide leaves the hand and the count of the draw pile")
		var sorted_copy: Array = copy.draw.duplicate()
		var sorted_run: Array = draw.duplicate()
		sorted_copy.sort()
		sorted_run.sort()
		eq(sorted_copy, sorted_run, "and the cards the draw pile holds")
		ok(copy.seed != run.seed, "the copy has a generator of its own")
		orders[str(copy.draw)] = true
	ok(orders.size() > 1, "the copy's draw pile is shuffled")
	eq([run.draw, run.hand], [draw, hand], "the run itself is as it was")
	# The same generator hides the same way.
	var a := run.copy()
	var b := run.copy()
	b.draw.reverse()
	rng.seed = 3
	SimMoves.hide(a, rng)
	rng.seed = 3
	SimMoves.hide(b, rng)
	eq([a.draw, a.seed], [b.draw, b.seed], "whatever order the pile had")


func test_plays() -> void:
	var run := fresh({}, 2)
	deal(run, "P:lamp P:lamp P:lamp P:heart P:heart F:cup F:cup F:eye")
	var plays := SimMoves.plays(run)
	var kinds := {}
	var last := 1 << 30
	for p: Dictionary in plays:
		var names: Array = []
		for id: int in p.ids:
			var c := Rules.card(run, id)
			names.append(c.key() + ("!" if c.ink else ""))
		names.sort()
		ok(not kinds.has(str(names)), "a set of card kinds comes once: %s" % str(names))
		kinds[str(names)] = true
		ok(p.ev.ok and int(p.ev.score) <= last, "allowed, and best first")
		last = p.ev.score
	# 0 to 3 Cloaks, 0 to 2 Quills, 0 to 2 Chalices, 0 or 1 Hourglass: 72 sets, less the empty one and
	# the 14 of six cards or more.
	eq(plays.size(), 57, "every set of kinds of up to five cards")
	var best := Rules.best(run)
	eq([plays[0].ids, plays[0].ev.score], [best.ids, best.ev.score], "the first is the rules' best play")
	# Hyde cannot play Jekyll's Roots.
	as_hyde(run)
	deal(run, "P:lamp P:heart I:lamp I:lamp F:cup")
	for p: Dictionary in SimMoves.plays(run):
		for id: int in p.ids:
			ok(not Rules.card(run, id).is_paper(), "no play of his holds a Paper Root")


func test_dead_and_apply() -> void:
	var run := fresh({}, 2)
	var h := deal(run, "P:lamp I:lamp I:heart F:cup P:mirror")
	eq(SimMoves.dead(run), [h[2].id], "Jekyll's dead card: his Root with no twin to turn beside")
	as_hyde(run)
	eq(SimMoves.dead(run), [h[0].id, h[4].id], "Hyde's dead cards: Jekyll's Roots")
	run = fresh({}, 2)
	h = deal(run, "P:lamp P:heart F:eye F:cup P:lamp P:heart P:mirror P:mirror")
	ok(SimMoves.apply(run, {"t": "play", "ids": [h[0].id, h[1].id]}).ok, "apply: a play")
	eq(run.plays, run.dials.plays - 1, "made through the rules")
	ok(SimMoves.apply(run, {"t": "discard", "ids": [run.hand[0]]}).ok, "apply: a discard")
	ok(not SimMoves.apply(run, {"t": "drink", "ids": []}).ok, "apply: no draught in the first round")
	ok(not SimMoves.apply(run, {"t": "salt", "ids": []}).ok, "apply: no salt as Jekyll")
	ok(not SimMoves.apply(run, {"t": "pass", "ids": []}).ok, "apply: no pass with a card to play")
	ok(not SimMoves.apply(run, {"t": "dance", "ids": []}).ok, "apply: no such move")


func test_greedy() -> void:
	var player := SimPlayer.make("greedy")
	var run := fresh({}, 2)
	player.begin(run, 2)
	var h := deal(run, "P:lamp P:mirror P:mirror I:lamp I:heart I:heart F:cup F:eye")
	var before := run.to_dict()
	var move := player.choose(run)
	eq(run.to_dict(), before, "choosing changes nothing")
	eq([move.t, move.ids], ["discard", [h[4].id, h[5].id]], "short of the target, it discards its dead cards")
	eq(move.options[0].t, "discard", "and says so first among its options")
	run.discards = 0
	move = player.choose(run)
	eq([move.t, move.ids], ["play", Rules.best(run).ids], "with no discards it plays the best play")
	eq(move.options[0].keys(), ["t", "ids", "key", "value"], "an option's keys")
	eq([move.options[0].key, move.options[0].value], [Rules.best(run).ev.key, Rules.best(run).ev.score], "the best first")
	run.discards = 1
	run.score = Rules.target(run) - 1
	eq(player.choose(run).t, "play", "it plays when the play wins the round")
	# Nothing to play: the hand goes, and with no discards the play is passed.
	run = as_hyde(fresh({}, 2))
	player.begin(run, 2)
	deal(run, "P:lamp P:heart P:mirror")
	eq(player.choose(run).t, "discard", "nothing to play: it discards")
	run.discards = 0
	eq(player.choose(run).t, "pass", "and passes with no discards")


func test_player_names() -> void:
	eq(SimPlayer.parse("greedy"), {"file": "greedy", "variant": "", "params": {}}, "a file")
	eq(SimPlayer.parse("persona.dance"), {"file": "persona", "variant": "dance", "params": {}}, "a file and a variant")
	eq(SimPlayer.parse("rollout.dance?samples=8&deep=true&how=fast&w=0.5"),
			{"file": "rollout", "variant": "dance", "params": {"samples": 8, "deep": true, "how": "fast", "w": 0.5}}, "and its numbers")
	var p := SimPlayer.make("greedy.plain?x=1")
	eq([p.name, p.variant, p.params], ["greedy.plain?x=1", "plain", {"x": 1}], "a player keeps its name")


func test_batches_on_disk() -> void:
	var kept := SimStore.root
	SimStore.root = "user://sim_test_%d" % Time.get_ticks_usec()
	var wanted := SimStore.new_manifest("greedy", {"plays": 5}, [], 0, 2)
	eq(SimStore.find(wanted), "", "nothing on disk yet")
	eq(SimStore.batches(), [] as Array[String], "and no batches")
	var name := SimStore.batch_name("greedy", {"plays": 5}, [], 0, 2)
	eq(name, "greedy__plays-5__0-2", "a batch's name")
	eq(SimStore.batch_name("rollout.dance?samples=8", {}, ["spirit", "balance"], 0, 9), "rollout.dance_samples_8__give-spirit+balance__0-9", "and a safe one")
	var dir := SimStore.batch_dir(name)
	ok(dir.begins_with(SimStore.root + "/" + RulesConfig.RULES_VERSION + "/"), "a batch lies under the rules' version")
	SimStore.make_dir(dir)
	ok(FileAccess.file_exists(SimStore.root + "/.gdignore"), "the root holds a .gdignore")
	var lines: Array = [_line(0, {"plays": 5}), _line(1, {"plays": 5})]
	ok(SimStore.write_lines(dir + "/runs.jsonl", lines), "the runs are written")
	eq(SimStore.find(wanted), "", "a batch with no manifest is not one")
	var m := wanted.duplicate(true)
	m.runs = 2
	m.commit = "abc"
	m.seconds = 1.5
	ok(SimStore.write_manifest(dir, m), "the manifest is written")
	eq(SimStore.find(wanted), dir, "a batch on disk is found, and is not played again")
	eq(SimStore.batches(), [dir] as Array[String], "it is listed")
	eq(SimStore.batches(RulesConfig.RULES_VERSION), [dir] as Array[String], "under its version")
	eq(SimStore.batches("0000"), [] as Array[String], "and under no other")
	var back := SimStore.load(dir)
	eq(back.runs, lines, "the runs read back as they were written")
	eq(back.manifest, m, "and the manifest")
	for k: String in ["rules_version", "rules_hash", "player_hash", "commit", "dirty", "player", "dials", "seeds", "runs", "started", "seconds", "godot"]:
		ok(back.manifest.has(k), "the manifest has %s" % k)
	# Other runs are not the same batch.
	eq(SimStore.find(SimStore.new_manifest("greedy", {"plays": 5}, [], 0, 3)), "", "other seeds")
	eq(SimStore.find(SimStore.new_manifest("greedy", {}, [], 0, 2)), "", "other dials")
	eq(SimStore.find(SimStore.new_manifest("greedy.x", {"plays": 5}, [], 0, 2)), "", "another player")
	eq(SimStore.find(SimStore.new_manifest("greedy", {"plays": 5}, ["spirit"], 0, 2)), "", "other instruments")
	var other := wanted.duplicate(true)
	other.rules_hash = "0"
	eq(SimStore.find(other), "", "other rules")
	ok(not SimStore.is_stale(m, other), "which is not the same batch grown old")
	ok(SimStore.write_lines(dir + "/runs.jsonl", [lines[0]]), "a batch cut short")
	ok(not SimStore.is_whole(dir), "is not whole")
	eq(SimStore.find(wanted), "", "and is not found")
	ok(SimStore.write_lines(dir + "/runs.jsonl", lines) and SimStore.is_whole(dir), "with its runs back it is")
	var old := m.duplicate(true)
	old.player_hash = "0"
	ok(SimStore.write_manifest(dir, old), "a batch played by other scripts of the player")
	eq(SimStore.find(wanted), "", "is not found")
	ok(SimStore.is_stale(SimStore.manifest(dir), wanted), "and is known to be this batch grown old")
	old.erase("player_hash")
	ok(SimStore.is_stale(old, wanted) and not SimStore.same_runs(old, wanted), "so is one that names no scripts")
	ok(not SimStore.is_stale(m, wanted) and not SimStore.is_stale({}, wanted), "the batch itself is not, nor is no batch")
	eq(SimStore.player_hash("greedy"), SimStore.player_hash("persona.dance"), "one hash for the players of the scripts")
	ok(SimStore.player_hash("persona.found-dance") != SimStore.player_hash("persona.dance"), "and another for a persona of the file of found ones")
	eq(SimStore.rules_hash().length(), 16, "the rules' hash")
	# Tidy up.
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(dir.get_base_dir())
	DirAccess.remove_absolute(SimStore.root + "/.gdignore")
	DirAccess.remove_absolute(SimStore.root)
	ok(not DirAccess.dir_exists_absolute(SimStore.root), "the test leaves nothing behind")
	SimStore.root = kept
