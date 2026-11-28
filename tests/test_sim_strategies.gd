extends "res://tests/case.gd"
## The report that groups runs into the strategies that win and the ways runs are lost.


func _move(who: String, t: String, key: String = "") -> Dictionary:
	return {"n": 0, "r": 0, "who": who, "t": t, "key": key, "score": 0}


# A run's line as runs.jsonl holds it, with what the strategies read.
func _run(seed_value: int, player: String, won: bool, moves: Array, more: Dictionary = {}) -> Dictionary:
	var run := {
		"seed": seed_value, "player": player, "ending": "double" if won else "hyde", "by": "scene" if won else "short",
		"night": 4 if won else 1, "round": 2, "moves": moves, "inst": [], "deck": 20, "ink": 2, "paper": 9,
		"temper": {"lamp": 1, "heart": 2, "mirror": 3}, "habit": {"lamp": 0, "heart": 0, "mirror": 1},
	}
	run.merge(more, true)
	return run


# Won runs of two plain kinds (Hyde's, with the cane and Spread Ruin; Jekyll's, with drinks and a
# long line), each a little different from the last by chance, and lost runs that end in
# two ways.
func _lines() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var out: Array = []
	for i in 30:
		var moves: Array = []
		var his := i % 2 == 0
		var hyde_plays := (15 if his else 2) + rng.randi_range(0, 3)
		for p in 20:
			moves.append(_move("hyde" if p < hyde_plays else "jekyll", "play", "mania" if p < hyde_plays else "lucid"))
		for p in (0 if his else 5) + rng.randi_range(0, 2):
			moves.append(_move("jekyll", "drink"))
		for p in rng.randi_range(0, 4):
			moves.append(_move("hyde", "salt"))
		out.append(SimStrategies.line_of(_run(i, "his" if his else "mine", true, moves, {
			"inst": ["hcane"] if his else ["balance"], "deck": (30 if his else 40) + rng.randi_range(0, 3),
			"paper": (6 if his else 25) + rng.randi_range(0, 4),
		})))
	for i in 12:
		out.append(SimStrategies.line_of(_run(100 + i, "mine", false, [_move("jekyll", "play", "lucid")], {
			"by": "short" if i < 9 else "line", "night": 1 if i < 11 else 0, "round": 2,
		})))
	return out


func test_line() -> void:
	var line := SimStrategies.line_of(_run(3, "x", true, [
		_move("hyde", "play", "mania"), _move("jekyll", "play", "lucid"), _move("jekyll", "play", "lucid"), _move("jekyll", "play", "dogma"),
		_move("jekyll", "drink"), _move("hyde", "salt"), _move("hyde", "salt"), _move("hyde", "discard"), _move("hyde", "pass"),
	], {"inst": ["spirit"]}))
	eq([line.seed, line.player, line.won, line.night, line.round, line.by], [3, "x", true, 4, 2, "scene"], "whose run, and how it ended")
	eq(line.v, {
		"hyde": 0.25, "drinks": 1.0, "salts": 2.0, "temper": 6.0, "habit": 1.0, "deck": 20.0, "lead": 7.0,
		"inst:spirit": 1.0, "hand:mania": 0.25, "hand:lucid": 0.5, "hand:dogma": 0.25,
	}, "its numbers")
	var bare := SimStrategies.line_of({"seed": 1})
	eq([bare.won, bare.v.hyde, bare.v.temper, bare.v.lead], [false, 0.0, 0.0, 0.0], "a line with nothing in it reads as noughts")
	eq(SimStrategies.names_of([line, bare]), ["hyde", "drinks", "salts", "temper", "habit", "deck", "lead", "inst:spirit", "hand:dogma", "hand:lucid", "hand:mania"] as Array[String], "the names: plain, instruments, hands")
	eq(SimStrategies.lost_label({"night": 1, "round": 2, "by": "short"}), "n2 r3 short", "a lost run's group")


func test_kmeans() -> void:
	var data := PackedFloat64Array([0, 0, 0.1, 0, 0, 0.1, 5, 5, 5.1, 5, 5, 5.1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var fit := SimStrategies.kmeans(data, 6, 2, 2, rng)
	var of: PackedInt32Array = fit.assign
	ok(of[0] == of[1] and of[1] == of[2] and of[3] == of[4] and of[4] == of[5] and of[0] != of[3], "two far heaps are two groups")
	ok(absf(float(fit.w) - 4.0 * 0.02 / 3.0) < 0.000001, "the spread left is the squares of the distances to the centres")
	var one := SimStrategies.kmeans(data, 6, 2, 1, rng)
	ok(float(one.w) > 70.0, "one group leaves the spread of the whole")


func test_groups() -> void:
	var lines := _lines()
	var made := SimStrategies.report(lines)
	var g: Dictionary = made.grouping
	var k: int = g.k
	ok(k >= SimStrategies.K_MIN and k <= SimStrategies.K_MAX, "the won runs fall into groups: %d" % k)
	var whose := {}
	var mixed := false
	for i in 30:
		var group_name: String = made.groups[i]
		mixed = mixed or whose.get(group_name, lines[i].player) != lines[i].player
		whose[group_name] = lines[i].player
	eq([whose.size(), mixed], [k, false], "and no group holds runs of both kinds")
	eq((made.groups as Array).slice(30, 33), ["n2 r3 short", "n2 r3 short", "n2 r3 short"], "a lost run's group is its round and way")
	eq([absf(g.gaps[1]) < 0.000001, float(g.gaps[k]) > float(g.noise[k])], [true, true], "the split has a gap over one group's, beyond its noise")
	ok(not (g.used as Array).has("temper") and (g.left as Array).has("temper"), "a number the same in every run is not grouped on")
	eq(SimStrategies.report(lines).groups, made.groups, "the same runs give the same groups")
	var by_name := {}
	for t: Dictionary in made.tables:
		by_name[t.name] = t
	eq(by_name.keys(), ["strategies_won", "strategies_won_hands", "strategies_won_instruments", "strategies_marks", "strategies_lost", "strategies_lost_hands", "strategies_lost_instruments", "strategies_runs"], "the tables")
	var rows: Array = by_name.strategies_won.rows
	eq([rows.size(), str(rows[0].label).left(7), rows[k].label, rows[k + 1].label], [k + 2, "group A", "all won", "all lost"], "a row for each group, the won and the lost")
	eq([rows[k].cells[0].t, rows[k + 1].cells[0].t], ["30", "12"], "with their runs")
	var in_groups := 0
	for c in k:
		in_groups += int(rows[c].cells[0].t)
		ok(int(rows[c].cells[0].t) <= int(rows[maxi(0, c - 1)].cells[0].t), "the largest group first")
		eq(str(rows[c].label).ends_with(" *"), int(rows[c].cells[0].t) < SimStrategies.FEW, "a group too small to mean anything is marked")
	eq(in_groups, 30, "every won run is in a group")
	var first: Dictionary = by_name.strategies_marks.rows[0]
	eq(first.cells[2].t, "%s %s" % [whose["A"], first.cells[0].t], "the players a group came from")
	# What marks out one kind of run from the other.
	var his: Array = lines.slice(0, 30).filter(func(l: Dictionary) -> bool: return l.player == "his")
	var mine: Array = lines.slice(0, 30).filter(func(l: Dictionary) -> bool: return l.player == "mine")
	var found := SimStrategies.marks(his, mine, g.used)
	eq(found.size(), SimStrategies.MARKS, "no more marks than asked")
	var cane: Dictionary = found.filter(func(m: Dictionary) -> bool: return m.name == "inst:hcane")[0]
	eq([cane.in, cane.out, cane.by], [1.0, 0.0, 2.0], "a mark: the mean inside, outside, and how many spreads apart")
	eq(SimStrategies.marks(his, his, g.used), [], "runs like the rest have no marks")
	eq([SimStrategies.label("inst:hcane"), SimStrategies.label("hand:mania"), SimStrategies.label("lead")], ["holds hcane", "plays of mania", "lead on the line"], "a number's name in plain words")
	var lost: Array = by_name.strategies_lost.rows
	eq([lost[0].label, lost[1].label, lost[2].label], ["n1 r3 line *", "n2 r3 line *", "n2 r3 short *"], "lost runs by round and way, small groups marked")
	eq([lost[2].cells[0].t, SimReport.show(lost[2].cells[1])], ["9", "75.0%"], "and how many of the lost")
	eq((by_name.strategies_runs.rows as Array).size(), 42, "every run's line")
	# Too few won runs are not grouped.
	var few := SimStrategies.report(lines.slice(0, 5) + lines.slice(30))
	eq([few.grouping.k, few.grouping.why != "", (few.groups as Array).slice(0, 5)], [1, true, ["A", "A", "A", "A", "A"]], "too few won runs stay one group, and it says so")


func test_text() -> void:
	var saved := SimStore.root
	SimStore.root = "user://test_sim_strategies"
	var dir := SimStore.batch_dir("a")
	SimStore.make_dir(dir)
	var runs: Array = [
		_run(0, "x", true, [_move("hyde", "play", "mania")]), _run(1, "x", false, [_move("jekyll", "play", "lucid")]),
	]
	SimStore.write_lines(dir + "/runs.jsonl", runs)
	SimStore.write_manifest(dir, SimStore.new_manifest("x", {}, [], 0, 2))
	var dirs: Array[String] = [dir]
	var out := SimStrategies.text(dirs)
	ok(out.contains("2 runs of 1 batches: a"), "the batches read")
	ok(out.contains("Won runs: 1 of 2") and out.contains("too few to group"), "one won run is not grouped")
	ok(out.contains("n2 r3 short *"), "the lost run's round and way")
	ok(not out.contains("Every run's line"), "every run's line is left to the files")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)
	SimStore.root = saved
