extends "res://tests/case.gd"
## The log of a sim's choices (a move's gap and lead) and the report that reads runs back.


## Plays as the greedy player does, and says nothing of what it weighed.
class Silent extends SimPlayer:
	var inner := SimPlayer.make("greedy")

	func choose(run: RulesRun) -> Dictionary:
		var move := inner.choose(run)
		move.erase("options")
		return move

	func between(run: RulesRun) -> void:
		inner.between(run)


func _opt(t: String, ids: Array, key: String, value: float) -> Dictionary:
	return {"t": t, "ids": ids, "key": key, "value": value}


func test_gap() -> void:
	var options: Array = [_opt("play", [1, 2], "pair", 100), _opt("play", [1, 2, 3], "pair", 90), _opt("play", [4], "single", 40)]
	eq(SimReport.gap({"t": "play", "ids": [1, 2], "options": options}), 0.6, "ahead of the best of another key, as a share of the chosen")
	eq(SimReport.gap({"t": "play", "ids": [2, 1], "options": options}), 0.6, "whatever the order of the cards")
	eq(SimReport.gap({"t": "play", "ids": [4], "options": options}), -1, "behind, and never under -1")
	eq(SimReport.gap({"t": "play", "ids": [1, 2]}), null, "no options, no gap")
	eq(SimReport.gap({"t": "play", "ids": [9], "options": options}), null, "nor when the move is not among them")
	eq(SimReport.gap({"t": "pass", "ids": [], "options": []}), 1, "nothing else to weigh")
	eq(SimReport.gap({"t": "play", "ids": [1, 2], "options": options.slice(0, 2)}), 1, "no move of another key")
	# A discard goes by what it is, against the plays.
	var with_discard: Array = [_opt("discard", [7], "", 50), _opt("play", [1], "pair", 50)]
	eq(SimReport.gap({"t": "discard", "ids": [7], "options": with_discard}), 0, "a discard level with the best play")
	eq(SimReport.gap({"t": "play", "ids": [1], "options": [_opt("play", [1], "a", 0), _opt("play", [2], "b", 0)]}), 0, "nothing against nothing")
	eq(SimReport.gap({"t": "play", "ids": [1], "options": [_opt("play", [1], "a", 0.5), _opt("play", [2], "b", 0.25)]}), 0.5, "values that are shares")


func test_lead() -> void:
	eq(SimReport.lead(0, 100, 0, 4), 0, "level at the start")
	eq(SimReport.lead(50, 100, 1, 4), 0.25, "ahead of the pace")
	eq(SimReport.lead(10, 100, 2, 4), -0.4, "behind it")
	eq(SimReport.lead(100, 100, 4, 4), 0, "won on the last play")


func test_moves_hold_gap_and_lead() -> void:
	var line := SimGame.play_run(SimPlayer.make("greedy"), 7)
	var gaps := 0
	var leads := 0
	var in_range := true
	for mv: Dictionary in line.moves:
		gaps += int(mv.has("gap"))
		leads += int(mv.has("lead"))
		in_range = in_range and (not mv.has("gap") or (float(mv.gap) >= -1.0 and float(mv.gap) <= 1.0))
	eq(leads, line.moves.size(), "every move has its lead")
	eq(gaps, line.moves.size(), "and, from a player that gives its options, its gap")
	ok(in_range, "a gap lies from -1 to 1")
	# The last move of a round that was won is not behind the pace.
	var last := {}
	for mv: Dictionary in line.moves:
		last[int(mv.n) * 3 + int(mv.r)] = mv
	for r: Dictionary in line.rounds:
		if r.how == "won":
			ok(float(last[int(r.n) * 3 + int(r.r)].lead) >= 0.0, "a round won ends at the pace or ahead")
	var silent := Silent.new()
	silent.name = "greedy"
	var bare := SimGame.play_run(silent, 7)
	gaps = 0
	for mv: Dictionary in bare.moves:
		gaps += int(mv.has("gap"))
	eq(gaps, 0, "a player that gives no options leaves no gap")
	ok(bare.moves[0].has("lead"), "and still has its lead")
	eq([bare.rounds, bare.ending], [line.rounds, line.ending], "the run itself is the same")


func _move(n: int, r: int, key: String, gap: Variant, lead: Variant) -> Dictionary:
	var mv := {"n": n, "r": r, "who": "jekyll", "t": "play", "key": key, "score": 10}
	if gap != null:
		mv.gap = gap
	if lead != null:
		mv.lead = lead
	return mv


func _round(n: int, r: int, how: String, used: int, stance: String) -> Dictionary:
	return {"n": n, "r": r, "how": how, "used": used, "score": 1, "target": 1, "stance": stance, "ink": 0, "paper": 0, "sov": 0}


# Two runs: one dies in the second round, one is given as won.
func _batch() -> Dictionary:
	var lost := {
		"seed": 0, "player": "x", "ending": "hyde", "by": "short", "night": 0, "round": 1, "inst": [],
		"rounds": [_round(0, 0, "won", 2, "jekyll"), _round(0, 1, "lost", 4, "hyde")],
		"moves": [_move(0, 0, "pair", 0.8, 0.1), _move(0, 0, "pair", 0.2, 0.5), _move(0, 1, "run", 0.9, -0.2)],
	}
	var won := {
		"seed": 1, "player": "x", "ending": "myself", "by": "scene", "night": Rules.night_count() - 1, "round": 2, "inst": ["spirit"],
		"rounds": [_round(0, 0, "won", 4, "jekyll"), _round(0, 1, "rescued", 4, "jekyll")],
		"moves": [_move(0, 0, "pair", 0.6, -0.1), _move(0, 0, "pair", 0.7, 0), _move(0, 1, "flush", null, -0.5)],
	}
	return {"manifest": {"player": "x", "dials": {}, "seeds": [0, 2], "rules_hash": "abc", "rules_version": "v"}, "runs": [lost, won]}


func _at(report: Array, table: String, label: String, col: String) -> Dictionary:
	for t: Dictionary in report:
		if t.name != table:
			continue
		for row: Dictionary in t.rows:
			if row.label == label:
				return row.cells[(t.cols as Array).find(col)]
	return {}


func _shown(report: Array, table: String, label: String, col: String) -> String:
	var cell := _at(report, table, label, col)
	return "(no such cell)" if cell.is_empty() else SimReport.show(cell)


func test_tables() -> void:
	var report := SimReport.tables(_batch())
	var names: Array = []
	for t: Dictionary in report:
		names.append(t.name)
	eq(names, ["runs", "rounds", "hands", "instruments", "lulls", "swings"], "the tables")
	eq(_shown(report, "runs", "won", "of runs"), "50.0%", "wins")
	eq([_shown(report, "runs", "ending myself", "of runs"), _shown(report, "runs", "ending double", "of runs"), _shown(report, "runs", "ending hyde", "of runs")],
			["50.0%", "0.0%", "50.0%"], "the endings")
	eq(_shown(report, "runs", "rounds cleared", "of runs"), "1.50", "rounds cleared a run")
	eq([_shown(report, "runs", "ended by short", "of runs"), _shown(report, "runs", "ended by scene", "of runs")], ["50.0%", "50.0%"], "how runs ended")
	eq([_shown(report, "rounds", "n1 r1", "reach"), _shown(report, "rounds", "n1 r1", "die"), _shown(report, "rounds", "n1 r1", "used"), _shown(report, "rounds", "n1 r1", "in<=2"), _shown(report, "rounds", "n1 r1", "hyde")],
			["100.0%", "0.0%", "3.00", "50.0%", "0.0%"], "the first round")
	eq([_shown(report, "rounds", "n1 r2", "die"), _shown(report, "rounds", "n1 r2", "how"), _shown(report, "rounds", "n1 r2", "hyde")],
			["50.0%", "short 1", "50.0%"], "who dies in the second, and how")
	eq([_shown(report, "rounds", "n1 r3", "reach"), _shown(report, "rounds", "n1 r3", "used")], ["0.0%", "-"], "a round nobody reaches")
	var rounds: Dictionary = report[1]
	eq((rounds.rows as Array).size(), Rules.night_count() * 3, "a row for every round of the run")
	eq([_shown(report, "hands", "pair", "night 1"), _shown(report, "hands", "run", "night 1"), _shown(report, "hands", "pair", "all")], ["66.7%", "16.7%", "66.7%"], "the share of each hand by night")
	eq(_shown(report, "instruments", "spirit", "of runs"), "50.0%", "the instruments held at the end")
	eq([_shown(report, "lulls", "n1 r1", "choices"), _shown(report, "lulls", "n1 r1", "plain"), _shown(report, "lulls", "n1 r1", "lull")], ["4", "75.0%", "lull"], "a lull: over two thirds of choices plain")
	eq([_shown(report, "lulls", "n1 r2", "choices"), _shown(report, "lulls", "n1 r3", "plain"), _shown(report, "lulls", "n1 r3", "lull")], ["1", "-", ""], "only moves with a gap are counted")
	var lulls: Dictionary = report[4]
	ok(str(lulls.note).contains("n1 r1, n1 r2"), "the lulls are named")
	eq([_shown(report, "swings", "won on the last play", "of rounds"), _shown(report, "swings", "won after being behind the pace", "of rounds"), _shown(report, "swings", "rescued", "of rounds")],
			["25.0%", "25.0%", "25.0%"], "the swings")
	# More plays a round: the round won in four is no longer won on the last.
	var roomy := _batch()
	roomy.manifest.dials = {"plays": 5}
	eq(_shown(SimReport.tables(roomy), "swings", "won on the last play", "of rounds"), "0.0%", "the last play is the dials'")
	var words := SimReport.text(_batch(), "res://sim_data/v/some_batch")
	ok(words.begins_with("== some_batch: x, seeds 0-2, 2 runs"), "the report names its batch")
	ok(words.contains("Lulls") and words.contains("Swings") and words.contains("n5 r3"), "and prints its tables")


func test_old_batches() -> void:
	# Runs from before a move had a gap or a lead, and a batch with nothing in it.
	var old := _batch()
	for line: Dictionary in old.runs:
		for mv: Dictionary in line.moves:
			mv.erase("gap")
			mv.erase("lead")
	var report := SimReport.tables(old)
	eq(_shown(report, "runs", "won", "of runs"), "50.0%", "an old batch is read")
	eq([_shown(report, "lulls", "n1 r1", "plain"), _shown(report, "swings", "won after being behind the pace", "of rounds"), _shown(report, "swings", "rescued", "of rounds")],
			["-", "-", "25.0%"], "what needs the log shows as not measured")
	ok(SimReport.text(old, "x").contains("No move in these runs has a gap"), "and the report says so")
	var empty := SimReport.tables({"manifest": {}, "runs": []})
	eq(_shown(empty, "runs", "won", "of runs"), "-", "no runs, no shares")
	ok(SimReport.text({"manifest": {}, "runs": []}, "x") != "", "and still a report")
	ok(SimReport.compare_text(old, _batch(), "a", "b") != "", "an old batch beside a new one")


func _share(hits: int, n: int) -> Dictionary:
	return {"k": "share", "s": float(hits), "q": float(hits), "n": n}


func test_compare() -> void:
	eq(SimReport.mark(_share(50, 100), _share(50, 100)), "=", "the same")
	eq(SimReport.mark(_share(50, 100), _share(55, 100)), "~", "a difference under the noise")
	eq(SimReport.mark(_share(50, 100), _share(90, 100)), "!", "a difference over it")
	eq(SimReport.mark(_share(500, 1000), _share(550, 1000)), "!", "the same shares, of more runs")
	eq(SimReport.mark(_share(0, 100), _share(100, 100)), "!", "all against none")
	eq(SimReport.mark(_share(5, 10), _share(0, 0)), "", "nothing measured, no mark")
	eq(SimReport.mark({"k": "text", "t": "a"}, {"k": "text", "t": "b"}), "", "text has no mark")
	var a := {"k": "mean", "s": 0.0, "q": 0.0, "n": 0}
	var b := a.duplicate()
	var c := a.duplicate()
	for i in 50:
		SimReport._put(a, 2.0 + (i % 5))
		SimReport._put(b, 2.2 + (i % 5))
		SimReport._put(c, 4.0 + (i % 5))
	eq([SimReport.mark(a, b), SimReport.mark(a, c)], ["~", "!"], "means go by their spread")
	var same := SimReport.compare_text(_batch(), _batch(), "res://x/a", "res://x/b")
	ok(same.contains("== A  a:") and same.contains("== B  b:"), "both batches are named")
	ok(same.contains("50.0% / 50.0% ="), "side by side, with the mark")
	ok(not same.contains("THE RULES DIFFER"), "the same rules: nothing said")
	var other := _batch()
	other.manifest.rules_hash = "def"
	other.runs[0].inst = ["balance"]
	var differ := SimReport.compare_text(_batch(), other, "a", "b")
	ok(differ.contains("THE RULES DIFFER") and differ.contains("abc") and differ.contains("def"), "other rules: it says so")
	ok(differ.contains("balance") and differ.contains("- / 50.0%"), "a row only one batch has")


func test_csv_and_batch_names() -> void:
	var kept := SimStore.root
	SimStore.root = "user://sim_report_test_%d" % Time.get_ticks_usec()
	var dir := SimStore.batch_dir("some")
	SimStore.make_dir(dir)
	eq(SimReport.find_batch("some"), "", "a folder with no manifest is no batch")
	SimStore.write_manifest(dir, _batch().manifest)
	eq([SimReport.find_batch("some"), SimReport.find_batch(dir), SimReport.find_batch("none")], [dir, dir, ""], "a batch by its name or its folder")
	var report := SimReport.tables(_batch())
	var files := SimReport.write_csv(dir, report)
	eq(files.size(), report.size(), "a file for each table")
	var runs := FileAccess.get_file_as_string(dir + "/report_runs.csv").split("\n")
	eq([runs[0], runs[1]], ["row,of runs", "won,0.5000"], "the table as a file")
	ok(FileAccess.get_file_as_string(dir + "/report_lulls.csv").contains("n1 r1,4,0.7500,lull"), "text and numbers")
	var both := SimReport.write_compare_csv(dir, "other", report, report)
	eq(both.size(), report.size(), "and for each table of a compare")
	ok(FileAccess.get_file_as_string(dir + "/compare_other_runs.csv").contains("won,0.5000,0.5000,="), "with both batches and the mark")
	# Tidy up.
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(dir.get_base_dir())
	DirAccess.remove_absolute(SimStore.root + "/.gdignore")
	DirAccess.remove_absolute(SimStore.root)
	ok(not DirAccess.dir_exists_absolute(SimStore.root), "the test leaves nothing behind")
	SimStore.root = kept
