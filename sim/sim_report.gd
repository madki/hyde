class_name SimReport
extends SceneTree
## Reads batches of runs back from disk and prints what happened in them, started by
## tools/sim_report.sh. It also holds how a move's `gap` and `lead` are worked out, which
## SimGame writes in each move. User arguments:
##
##   <batch> ...       the batches to read: a name under the rules' version of now (or of any
##                     version, if there is none), or a folder. Every batch of the version of
##                     now when none is named.
##   --compare a b     two batches side by side, each difference marked against the noise
##   --csv             also writes each table as a file beside the batch
##   --strategies      instead of each batch's tables, the named batches' runs together: the
##                     won runs grouped into the strategies that win, the lost runs by the
##                     round and the way they ended (SimStrategies)
##
## A report is a list of tables, each {name, title, cols, rows: [{label, cells}], note}. A
## cell is {k: "share" | "mean", s, q, n} (the sum, the sum of squares and the count of what
## was measured: a share is the mean of ones and noughts) or {k: "text", t}.

## A choice whose gap is over this has one move plainly best.
const LULL_GAP := 0.5
## A round is a lull when this share of its choices has one move plainly best.
const LULL_SHARE := 2.0 / 3.0
## A difference under this many standard errors is under the noise.
const NOISE := 2.0
## The rounds of a night.
const ROUNDS := 3


func _initialize() -> void:
	var problem := _run(OS.get_cmdline_user_args())
	if problem != "":
		print("REPORT FAILED: " + problem)
		quit(1)
	else:
		quit(0)


func _run(args: PackedStringArray) -> String:
	var names: Array[String] = []
	var compare := false
	var csv := false
	var strategies := false
	for a in args:
		match a:
			"--strategies", "strategies": strategies = true
			"--compare", "compare": compare = true
			"--csv", "csv": csv = true
			_:
				if a.begins_with("--"):
					return "Unknown argument: %s" % a
				names.append(a)
	var dirs: Array[String] = []
	for n in names:
		var dir := find_batch(n)
		if dir == "":
			return "No such batch: %s" % n
		dirs.append(dir)
	if compare:
		if dirs.size() != 2:
			return "--compare takes two batches"
		var a := SimStore.load(dirs[0])
		var b := SimStore.load(dirs[1])
		print(compare_text(a, b, dirs[0], dirs[1]))
		if csv:
			for path in write_compare_csv(dirs[0], dirs[1].get_file(), tables(a), tables(b)):
				print("wrote " + path.trim_prefix("res://"))
		return ""
	if dirs.is_empty():
		dirs = SimStore.batches(RulesConfig.RULES_VERSION)
		if dirs.is_empty():
			return "No batches under %s/%s. Make one with tools/sim.sh." % [SimStore.root.trim_prefix("res://"), RulesConfig.RULES_VERSION]
	if strategies:
		SimStrategies.run(dirs, csv)
		return ""
	for i in dirs.size():
		var data := SimStore.load(dirs[i])
		if i > 0:
			print("")
		print(text(data, dirs[i]))
		if csv:
			for path in write_csv(dirs[i], tables(data)):
				print("wrote " + path.trim_prefix("res://"))
	return ""


## The folder of a batch named on the command line, or "" if there is none: a folder with a
## manifest, or a batch's name under the rules' version of now, or under any version.
static func find_batch(batch: String) -> String:
	if batch.contains("/"):
		var dir := batch.trim_suffix("/")
		if not dir.contains("://") and not dir.is_absolute_path():
			dir = "res://" + dir
		return dir if not SimStore.manifest(dir).is_empty() else ""
	var now := SimStore.batch_dir(batch)
	if not SimStore.manifest(now).is_empty():
		return now
	var found := ""
	for dir: String in SimStore.batches():
		if dir.get_file() == batch:
			found = dir
	return found


# ---------- what SimGame writes in a move ----------

## How far the chosen move's value is ahead of the best move of another key among the
## `options` a player gave with its move, as a share of the chosen one's, from -1 to 1.
## 1 when the player weighed no move of another key. Null (no gap is written) when the
## player gave no options, or did not name its move among them. Moves with no key of their
## own (a discard, a drink) go by what they are.
static func gap(move: Dictionary) -> Variant:
	if not move.get("options") is Array:
		return null
	var options: Array = move.options
	var ids: Array = (move.get("ids", []) as Array).duplicate()
	ids.sort()
	var chosen: Dictionary = {}
	for o: Variant in options:
		if not o is Dictionary or o.get("t", "") != move.get("t", ""):
			continue
		var theirs: Array = (o.get("ids", []) as Array).duplicate()
		theirs.sort()
		if theirs == ids:
			chosen = o
			break
	if chosen.is_empty():
		return 1 if options.is_empty() else null
	var kind := _kind(chosen)
	var value_of := float(chosen.get("value", 0))
	var found := false
	var other := 0.0
	for o: Variant in options:
		if o is Dictionary and _kind(o) != kind:
			var v := float(o.get("value", 0))
			if not found or v > other:
				other = v
			found = true
	if not found:
		return 1
	var ahead := value_of - other
	if absf(value_of) < 0.000001:
		return _number(signf(ahead))
	return _number(clampf(ahead / absf(value_of), -1.0, 1.0))


## The round's score against the pace its target asks, once a move is made: the share of
## the target scored, less the share of the plays used. Under 0 is behind the pace.
static func lead(score: int, target: int, used: int, plays: int) -> Variant:
	return _number(float(score) / maxi(1, target) - float(used) / maxi(1, plays))


static func _kind(option: Dictionary) -> String:
	var key := str(option.get("key", ""))
	return key if key != "" else str(option.get("t", ""))


# A number as it reads back from a run's line: three places, and a whole one an int.
static func _number(x: float) -> Variant:
	return SimStore.whole(roundf(x * 1000.0) / 1000.0)


# ---------- cells ----------

static func _cell(kind: String) -> Dictionary:
	return {"k": kind, "s": 0.0, "q": 0.0, "n": 0}


static func _put(cell: Dictionary, x: float) -> void:
	cell.s += x
	cell.q += x * x
	cell.n += 1


static func _share(hits: int, n: int) -> Dictionary:
	return {"k": "share", "s": float(hits), "q": float(hits), "n": n}


static func _text(t: String) -> Dictionary:
	return {"k": "text", "t": t}


## A cell's number: its share (0 to 1) or mean. 0 when nothing was measured.
static func value(cell: Dictionary) -> float:
	return float(cell.s) / int(cell.n) if int(cell.get("n", 0)) > 0 else 0.0


## A cell as it is printed.
static func show(cell: Dictionary) -> String:
	match cell.get("k", ""):
		"text":
			return str(cell.t)
		"share":
			return "%.1f%%" % (100.0 * value(cell)) if int(cell.n) > 0 else "-"
		"mean":
			return "%.2f" % value(cell) if int(cell.n) > 0 else "-"
	return ""


## How two cells differ: "=" not at all, "~" by less than the noise of their sizes, "!" by
## more. "" when one of them measured nothing, or they are text.
static func mark(a: Dictionary, b: Dictionary) -> String:
	if a.get("k", "text") == "text" or b.get("k", "text") == "text":
		return ""
	if int(a.n) == 0 or int(b.n) == 0:
		return ""
	var diff := absf(value(a) - value(b))
	if diff < 0.0000001:
		return "="
	if int(a.n) < 2 or int(b.n) < 2:
		return "~"
	return "~" if diff < NOISE * sqrt(_var_of_mean(a) + _var_of_mean(b)) else "!"


static func _var_of_mean(cell: Dictionary) -> float:
	var n := int(cell.n)
	var m := value(cell)
	return maxf(0.0, float(cell.q) / n - m * m) / (n - 1)


# ---------- the tables ----------

## A round's name in the tables, from a night and a round counted from 0.
static func round_label(night: int, round_no: int) -> String:
	return "n%d r%d" % [night + 1, round_no + 1]


## The tables of one batch ({manifest, runs}, as SimStore.load gives it): "runs", "rounds",
## "hands", "instruments", "lulls" and "swings". Runs written before a move had `gap` and
## `lead` are read as they are: what needs those shows as not measured.
static func tables(data: Dictionary) -> Array:
	var m: Dictionary = data.get("manifest", {})
	var runs: Array = data.get("runs", [])
	var n_runs := runs.size()
	var dials: Dictionary = m.get("dials", {}) if m.get("dials") is Dictionary else {}
	var plays := int(dials.get("plays", RulesDials.make({}).plays))
	var nights: int = Rules.night_count()
	for line: Dictionary in runs:
		nights = maxi(nights, int(line.get("night", 0)) + 1)
	var slots := nights * ROUNDS

	var wins := 0
	var endings := {"myself": 0, "double": 0, "hyde": 0}
	var by := {}
	var cleared := _cell("mean")
	var reached: Array[int] = []
	var ended: Array = []
	var ends: Array = []
	var used: Array = []
	var quick: Array = []
	var hyde: Array = []
	var plain: Array = []
	for i in slots:
		reached.append(0)
		ended.append({})
		ends.append(_cell("share"))
		used.append(_cell("mean"))
		quick.append(_cell("share"))
		hyde.append(_cell("share"))
		plain.append(_cell("share"))
	var last := _cell("share")
	var behind := _cell("share")
	var rescued := _cell("share")
	var hands := {}
	var hand_plays: Array[int] = []
	for i in nights + 1:
		hand_plays.append(0)
	var held := {}

	for line: Dictionary in runs:
		var won := SimGame.won(line)
		wins += int(won)
		var ending := str(line.get("ending", ""))
		endings[ending] = int(endings.get(ending, 0)) + 1
		var word := str(line.get("by", ""))
		by[word] = int(by.get(word, 0)) + 1
		_put(cleared, SimGame.cleared(line))
		for key: Variant in line.get("inst", []):
			held[key] = int(held.get(key, 0)) + 1
		# Whether each round of the run was ever behind the pace, where its moves say.
		var was_behind := {}
		for mv: Dictionary in line.get("moves", []):
			var slot := int(mv.n) * ROUNDS + int(mv.r)
			if slot >= slots:
				continue
			if mv.has("gap"):
				_put(plain[slot], float(float(mv.gap) > LULL_GAP))
			if mv.has("lead"):
				was_behind[slot] = was_behind.get(slot, false) or float(mv.lead) < 0.0
			if mv.t == "play":
				var key := str(mv.key)
				if not hands.has(key):
					var counts: Array[int] = []
					counts.resize(nights + 1)
					counts.fill(0)
					hands[key] = counts
				hands[key][int(mv.n)] += 1
				hands[key][nights] += 1
				hand_plays[int(mv.n)] += 1
				hand_plays[nights] += 1
		var end_slot := int(line.get("night", 0)) * ROUNDS + int(line.get("round", 0))
		for r: Dictionary in line.get("rounds", []):
			var slot := int(r.n) * ROUNDS + int(r.r)
			if slot >= slots:
				continue
			reached[slot] += 1
			var here := not won and slot == end_slot
			_put(ends[slot], float(here))
			if here:
				ended[slot][word] = int(ended[slot].get(word, 0)) + 1
			var round_won: bool = r.how == "won"
			_put(used[slot], float(r.used))
			_put(quick[slot], float(round_won and int(r.used) <= 2))
			_put(hyde[slot], float(r.stance == "hyde"))
			_put(last, float(round_won and int(r.used) >= plays))
			_put(rescued, float(r.how == "rescued"))
			if was_behind.has(slot):
				_put(behind, float(round_won and was_behind[slot]))

	var out: Array = []

	var rows: Array = [
		{"label": "won", "cells": [_share(wins, n_runs)]},
		{"label": "ending myself", "cells": [_share(endings.myself, n_runs)]},
		{"label": "ending double", "cells": [_share(endings.double, n_runs)]},
		{"label": "ending hyde", "cells": [_share(endings.hyde, n_runs)]},
		{"label": "rounds cleared", "cells": [cleared]},
	]
	for word: String in _sorted_keys(by):
		rows.append({"label": "ended by %s" % (word if word != "" else "nothing"), "cells": [_share(by[word], n_runs)]})
	out.append({"name": "runs", "title": "Runs: wins, endings, rounds cleared, how runs ended", "cols": ["of runs"], "rows": rows, "note": ""})

	rows = []
	var lull_rows: Array = []
	var lulls: Array[String] = []
	var any_gap := false
	for slot in slots:
		@warning_ignore("integer_division")
		var label := round_label(slot / ROUNDS, slot % ROUNDS)
		var how: Array[String] = []
		for word: String in _sorted_keys(ended[slot]):
			how.append("%s %d" % [word if word != "" else "nothing", ended[slot][word]])
		rows.append({"label": label, "cells": [
			_share(reached[slot], n_runs), ends[slot], _text(", ".join(how)), used[slot], quick[slot], hyde[slot],
		]})
		var is_lull: bool = int(plain[slot].n) > 0 and value(plain[slot]) > LULL_SHARE
		any_gap = any_gap or int(plain[slot].n) > 0
		if is_lull:
			lulls.append(label)
		lull_rows.append({"label": label, "cells": [_text(str(int(plain[slot].n))), plain[slot], _text("lull" if is_lull else "")]})
	out.append({
		"name": "rounds", "title": "Rounds: who reaches each, who dies there and how, plays used, won in two plays or fewer, the stance",
		"cols": ["reach", "die", "how", "used", "in<=2", "hyde"], "rows": rows,
		"note": "reach: of runs. die, in<=2, hyde (the stance at the round's end): of the runs that reach it. used: plays and passes.",
	})

	rows = []
	var keys: Array = hands.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return hands[a][nights] > hands[b][nights] if hands[a][nights] != hands[b][nights] else a < b)
	var cols: Array = []
	for n in nights:
		cols.append("night %d" % (n + 1))
	cols.append("all")
	for key: String in keys:
		var cells: Array = []
		for n in nights + 1:
			cells.append(_share(hands[key][n], hand_plays[n]))
		rows.append({"label": key, "cells": cells})
	out.append({"name": "hands", "title": "Hands: the share of each among a night's plays", "cols": cols, "rows": rows, "note": "" if not rows.is_empty() else "No plays."})

	rows = []
	keys = held.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return held[a] > held[b] if held[a] != held[b] else a < b)
	for key: String in keys:
		rows.append({"label": key, "cells": [_share(held[key], n_runs)]})
	out.append({"name": "instruments", "title": "Instruments held at the end", "cols": ["of runs"], "rows": rows, "note": "" if not rows.is_empty() else "None held."})

	var lull_note := "No move in these runs has a gap: the player gave no options, or the runs are from before the log of choices."
	if any_gap:
		lull_note = "Lulls (plain in over %.0f%% of choices): %s." % [100.0 * LULL_SHARE, ", ".join(lulls) if not lulls.is_empty() else "none"]
	out.append({
		"name": "lulls", "title": "Lulls: choices with one move plainly best (a gap over %.0f%%)" % (100.0 * LULL_GAP),
		"cols": ["choices", "plain", "lull"], "rows": lull_rows, "note": lull_note,
	})

	out.append({
		"name": "swings", "title": "Swings: of the rounds played", "cols": ["of rounds"],
		"rows": [
			{"label": "won on the last play", "cells": [last]},
			{"label": "won after being behind the pace", "cells": [behind]},
			{"label": "rescued", "cells": [rescued]},
		],
		"note": "" if int(behind.n) > 0 or int(last.n) == 0 else "No move in these runs has a lead: the runs are from before the log of choices.",
	})
	return out


static func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


# ---------- text ----------

## A batch in a line or two: its name, player, seeds, changed numbers and rules.
static func head(data: Dictionary, dir: String) -> String:
	var m: Dictionary = data.get("manifest", {})
	var seeds: Array = m.get("seeds", [0, 0]) if m.get("seeds") is Array else [0, 0]
	var out := "%s: %s, seeds %s-%s, %d runs" % [dir.get_file(), m.get("player", "?"), seeds[0], seeds[-1], (data.get("runs", []) as Array).size()]
	if m.get("dials") is Dictionary and not (m.dials as Dictionary).is_empty():
		out += ", dials %s" % JSON.stringify(m.dials, "", true)
	if m.get("give") is Array and not (m.give as Array).is_empty():
		out += ", given %s" % "+".join(PackedStringArray(m.give))
	out += "\nrules %s, hash %s, commit %s%s" % [
		m.get("rules_version", "?"), m.get("rules_hash", "?"), str(m.get("commit", "")).substr(0, 8),
		" (with changes not committed)" if m.get("dirty", false) else "",
	]
	return out


## The report of one batch, as text.
static func text(data: Dictionary, dir: String) -> String:
	var out := "== " + head(data, dir) + "\n"
	for t: Dictionary in tables(data):
		var lines: Array = []
		for row: Dictionary in t.rows:
			var cells: Array = [row.label]
			for c: Dictionary in row.cells:
				cells.append(show(c))
			lines.append(cells)
		out += "\n" + _table_text(t, lines)
	return out


## Two batches side by side: each cell is the first batch's, the second's, and the mark of
## how they differ (see `mark`).
static func compare_text(a: Dictionary, b: Dictionary, dir_a: String, dir_b: String) -> String:
	var out := "== A  " + head(a, dir_a) + "\n== B  " + head(b, dir_b) + "\n"
	var ma: Dictionary = a.get("manifest", {})
	var mb: Dictionary = b.get("manifest", {})
	if ma.get("rules_hash", "") != mb.get("rules_hash", ""):
		out += "\nTHE RULES DIFFER: A was played on rules %s (%s), B on %s (%s). A difference may be the rules', not the players' or the dials'.\n" % [
			ma.get("rules_hash", "?"), ma.get("rules_version", "?"), mb.get("rules_hash", "?"), mb.get("rules_version", "?"),
		]
	out += "\nEach cell: A / B and a mark. = the same, ~ a difference under the noise of the batches' sizes (%.0f standard errors), ! a difference over it.\n" % NOISE
	var tb := tables(b)
	for t: Dictionary in tables(a):
		var other: Dictionary = {}
		for x: Dictionary in tb:
			if x.name == t.name:
				other = x
		var lines: Array = []
		for pair: Array in _pairs(t, other):
			var cells: Array = [pair[0]]
			for i in (t.cols as Array).size():
				cells.append(_pair_text(pair[1], pair[2], i))
			lines.append(cells)
		var both := t.duplicate()
		both.note = ""
		out += "\n" + _table_text(both, lines)
	return out


# The rows of two tables of one name, by label: [label, cells of a or [], cells of b or []],
# in the first table's order, then what only the second has.
static func _pairs(a: Dictionary, b: Dictionary) -> Array:
	var theirs := {}
	for row: Dictionary in b.get("rows", []):
		theirs[row.label] = row.cells
	var out: Array = []
	var seen := {}
	for row: Dictionary in a.get("rows", []):
		seen[row.label] = true
		out.append([row.label, row.cells, theirs.get(row.label, [])])
	for row: Dictionary in b.get("rows", []):
		if not seen.has(row.label):
			out.append([row.label, [], row.cells])
	return out


static func _pair_text(a: Array, b: Array, i: int) -> String:
	var ca: Dictionary = a[i] if i < a.size() else _text("-")
	var cb: Dictionary = b[i] if i < b.size() else _text("-")
	var sa := show(ca)
	var sb := show(cb)
	if sa == "" and sb == "":
		return ""
	return "%s / %s %s" % [sa if sa != "" else "-", sb if sb != "" else "-", mark(ca, cb)]


# A table as text: its title, its columns in line (the first to the left, numbers to the
# right), and its note.
static func _table_text(t: Dictionary, lines: Array) -> String:
	var out := str(t.title) + "\n"
	if not lines.is_empty():
		var all: Array = [[""] + (t.cols as Array)] + lines
		var widths: Array[int] = []
		for cells: Array in all:
			for i in cells.size():
				if i >= widths.size():
					widths.append(0)
				widths[i] = maxi(widths[i], str(cells[i]).length())
		for cells: Array in all:
			var parts: Array[String] = []
			for i in cells.size():
				var cell := str(cells[i])
				parts.append(cell.rpad(widths[i]) if i == 0 else cell.lpad(widths[i]))
			out += ("  " + "  ".join(parts)).rstrip(" ") + "\n"
	if str(t.get("note", "")) != "":
		out += "  " + str(t.note) + "\n"
	return out


# ---------- files ----------

## Writes each table as `report_<name>.csv` in the batch's folder: shares from 0 to 1, a cell
## that measured nothing empty. Returns the files written.
static func write_csv(dir: String, report: Array) -> Array[String]:
	var written: Array[String] = []
	for t: Dictionary in report:
		var lines: Array[String] = [_csv_line(["row"] + (t.cols as Array))]
		for row: Dictionary in t.rows:
			var cells: Array = [row.label]
			for c: Dictionary in row.cells:
				cells.append(_csv_cell(c))
			lines.append(_csv_line(cells))
		var path := "%s/report_%s.csv" % [dir, t.name]
		if _write_text(path, "\n".join(lines) + "\n"):
			written.append(path)
	return written


## Writes each table of two batches as `compare_<other>_<name>.csv` in the first batch's
## folder: for each column the first batch's cell, the second's and the mark. Returns the
## files written.
static func write_compare_csv(dir: String, other: String, a: Array, b: Array) -> Array[String]:
	var written: Array[String] = []
	for t: Dictionary in a:
		var tb: Dictionary = {}
		for x: Dictionary in b:
			if x.name == t.name:
				tb = x
		var top: Array = ["row"]
		for c: String in t.cols:
			top.append_array([c + " a", c + " b", c + " mark"])
		var lines: Array[String] = [_csv_line(top)]
		for pair: Array in _pairs(t, tb):
			var cells: Array = [pair[0]]
			for i in (t.cols as Array).size():
				var ca: Dictionary = pair[1][i] if i < (pair[1] as Array).size() else _text("")
				var cb: Dictionary = pair[2][i] if i < (pair[2] as Array).size() else _text("")
				cells.append_array([_csv_cell(ca), _csv_cell(cb), mark(ca, cb)])
			lines.append(_csv_line(cells))
		var path := "%s/compare_%s_%s.csv" % [dir, other, t.name]
		if _write_text(path, "\n".join(lines) + "\n"):
			written.append(path)
	return written


static func _csv_cell(cell: Dictionary) -> String:
	if cell.get("k", "text") == "text":
		return str(cell.get("t", ""))
	return "%.4f" % value(cell) if int(cell.n) > 0 else ""


static func _csv_line(cells: Array) -> String:
	var parts: Array[String] = []
	for c: Variant in cells:
		var s := str(c)
		if s.contains(",") or s.contains("\"") or s.contains("\n"):
			s = "\"" + s.replace("\"", "\"\"") + "\""
		parts.append(s)
	return ",".join(parts)


static func _write_text(path: String, content: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % path)
		return false
	f.store_string(content)
	f.close()
	return true
