class_name SimStrategies
## Groups the runs of batches on disk into the strategies that win and the ways runs are
## lost, for `tools/sim_report.sh --strategies`.
##
## Each run is read as a line of what it was: {seed, player, won, night, round, by, v}, where
## `v` holds its numbers by name:
##
##   hyde            the share of its plays made as Hyde
##   drinks, salts   how many of each it made
##   temper, habit   Temper and Habit at the end, each added up over the three Roots
##   deck            the cards of its deck at the end
##   lead            the lead on the line at the end: Paper Roots less Ink Roots
##   inst:<key>      1 when it held the instrument at the end
##   hand:<key>      the share of its plays that were this hand
##
## The won runs are grouped by a plain k-means on these numbers, each scaled to a mean of 0
## and a spread of 1, for k from K_MIN to K_MAX. A k's gap is how far the spread left inside
## its groups falls below what the same k leaves when each number is dealt out among the
## runs again by itself, so that the numbers no longer go together. The k kept is the first that one more group does not better by more than the
## noise of that measure. The lost runs are grouped by the round and the way
## they ended.

const K_MIN := 2
const K_MAX := 6
## A group of fewer runs than this is too few to mean anything.
const FEW := 10
## Fewer won runs than this are not grouped at all.
const LEAST := 20
## A number that is not 0 in under this share of the won runs is left out of the grouping:
## scaled, the few runs that have it would stand far from all the rest.
const RARE := 0.05
## Starts of each k-means; the one that leaves the least spread is kept.
const STARTS := 12
## Sets of numbers dealt out again that a gap is measured against.
const REFS := 8
## A group is marked by a number whose mean is this many spreads from the other groups'.
const MARK := 0.5
## The most marks named for a group.
const MARKS := 6
## The seed of the grouping's own generator: the same runs give the same groups.
const SEED := 4721

const BASE: Array[String] = ["hyde", "drinks", "salts", "temper", "habit", "deck", "lead"]
const LABELS := {
	"hyde": "plays as Hyde", "drinks": "drinks", "salts": "salts", "temper": "Temper",
	"habit": "Habit", "deck": "deck", "lead": "lead on the line",
}


# ---------- a run's line ----------

## What a run was, from its line in runs.jsonl.
static func line_of(run: Dictionary) -> Dictionary:
	var v := {}
	var plays := 0
	var as_hyde := 0
	var drinks := 0
	var salts := 0
	var hands := {}
	for mv: Dictionary in run.get("moves", []):
		match str(mv.get("t", "")):
			"play":
				plays += 1
				as_hyde += int(mv.get("who", "") == "hyde")
				var key := str(mv.get("key", ""))
				hands[key] = int(hands.get(key, 0)) + 1
			"drink": drinks += 1
			"salt": salts += 1
	v["hyde"] = float(as_hyde) / maxi(1, plays)
	v["drinks"] = float(drinks)
	v["salts"] = float(salts)
	v["temper"] = _sum(run.get("temper", {}))
	v["habit"] = _sum(run.get("habit", {}))
	v["deck"] = float(run.get("deck", 0))
	v["lead"] = float(run.get("paper", 0)) - float(run.get("ink", 0))
	for key: Variant in run.get("inst", []):
		v["inst:%s" % key] = 1.0
	for key: String in hands:
		v["hand:" + key] = float(hands[key]) / plays
	return {
		"seed": int(run.get("seed", 0)), "player": str(run.get("player", "")), "won": SimGame.won(run),
		"night": int(run.get("night", 0)), "round": int(run.get("round", 0)), "by": str(run.get("by", "")), "v": v,
	}


static func _sum(d: Variant) -> float:
	var total := 0.0
	if d is Dictionary:
		for k: Variant in d:
			total += float(d[k])
	return total


## The lines of every run of these batches' folders.
static func read(dirs: Array[String]) -> Array:
	var out: Array = []
	for dir in dirs:
		for run: Dictionary in SimStore.read_lines(dir + "/runs.jsonl"):
			out.append(line_of(run))
	return out


## The names of the numbers these lines hold: the plain ones, then each instrument, then
## each hand.
static func names_of(lines: Array) -> Array[String]:
	var inst := {}
	var hands := {}
	for line: Dictionary in lines:
		for name: String in line.v:
			if name.begins_with("inst:"):
				inst[name] = true
			elif name.begins_with("hand:"):
				hands[name] = true
	var out: Array[String] = BASE.duplicate()
	for part: Dictionary in [inst, hands]:
		var keys: Array = part.keys()
		keys.sort()
		for k: String in keys:
			out.append(k)
	return out


## Whether a number is a share (of plays, or of runs) and not a count.
static func is_share(name: String) -> bool:
	return name == "hyde" or name.contains(":")


## A number's name in plain words.
static func label(name: String) -> String:
	if name.begins_with("inst:"):
		return "holds " + name.trim_prefix("inst:")
	if name.begins_with("hand:"):
		return "plays of " + name.trim_prefix("hand:")
	return str(LABELS.get(name, name))


# ---------- the grouping ----------

## Groups lines by their numbers. Returns {k, of: [the group of each line, from 0, the
## largest group first], gaps: {k: gap} and noise: {k: the noise of that gap} from 1 to K_MAX, used: [names grouped on],
## left: [names left out as rare or all the same], why: "" or why nothing was grouped}.
static func group(lines: Array, names: Array[String]) -> Dictionary:
	var n := lines.size()
	var out := {"k": 1, "of": [], "gaps": {}, "noise": {}, "used": [], "left": [], "why": ""}
	for i in n:
		out.of.append(0)
	if n < LEAST:
		out.why = "%d runs are too few to group (under %d)." % [n, LEAST]
		return out
	# Scale each number that tells runs apart.
	var cols: Array = []
	for name in names:
		var col := PackedFloat64Array()
		col.resize(n)
		var total := 0.0
		var not_nought := 0
		for i in n:
			var x := float(lines[i].v.get(name, 0.0))
			col[i] = x
			total += x
			not_nought += int(x != 0.0)
		var mean := total / n
		var sq := 0.0
		for i in n:
			sq += (col[i] - mean) * (col[i] - mean)
		var sd := sqrt(sq / n)
		if sd < 0.000001 or not_nought < RARE * n:
			out.left.append(name)
			continue
		for i in n:
			col[i] = (col[i] - mean) / sd
		out.used.append(name)
		cols.append(col)
	var d := cols.size()
	if d == 0:
		out.why = "The runs do not differ in any number."
		return out
	var data := PackedFloat64Array()
	data.resize(n * d)
	for j in d:
		var col: PackedFloat64Array = cols[j]
		for i in n:
			data[i * d + j] = col[i]

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var k_max := mini(K_MAX, n)
	var fits: Array = [{}]
	var logs := PackedFloat64Array()
	for k in range(1, k_max + 1):
		fits.append(kmeans(data, n, d, k, rng))
		logs.append(log(maxf(fits[k].w, 0.000001)))
	# What the same k leaves when each number is dealt out among the runs again by itself.
	var ref_logs: Array = []
	for k in k_max:
		ref_logs.append(PackedFloat64Array())
	var ref := PackedFloat64Array()
	ref.resize(n * d)
	var order_of: Array = range(n)
	for b in REFS:
		for j in d:
			# Shuffled with the grouping's own generator.
			for i in range(n - 1, 0, -1):
				var other := rng.randi_range(0, i)
				var held: int = order_of[i]
				order_of[i] = order_of[other]
				order_of[other] = held
			for i in n:
				ref[i * d + j] = data[int(order_of[i]) * d + j]
		for k in range(1, k_max + 1):
			ref_logs[k - 1].append(log(maxf(kmeans(ref, n, d, k, rng).w, 0.000001)))
	for k in range(1, k_max + 1):
		var of_ref: PackedFloat64Array = ref_logs[k - 1]
		var mean := 0.0
		for x in of_ref:
			mean += x / REFS
		var sq := 0.0
		for x in of_ref:
			sq += (x - mean) * (x - mean)
		out.gaps[k] = mean - logs[k - 1]
		out.noise[k] = sqrt(sq / REFS) * sqrt(1.0 + 1.0 / REFS)
	# The best gap: the first k that one more group does not better by more than the noise.
	var best := k_max
	for k in range(mini(K_MIN, k_max), k_max):
		if float(out.gaps[k]) >= float(out.gaps[k + 1]) - float(out.noise[k + 1]):
			best = k
			break
	out.k = best
	# The largest group first.
	var assign: PackedInt32Array = fits[best].assign
	var sizes: Array[int] = []
	sizes.resize(best)
	sizes.fill(0)
	for i in n:
		sizes[assign[i]] += 1
	var order: Array = range(best)
	order.sort_custom(func(a: int, b: int) -> bool:
		return sizes[a] > sizes[b] if sizes[a] != sizes[b] else a < b)
	for i in n:
		out.of[i] = order.find(assign[i])
	return out


## A plain k-means of `n` points of `d` numbers each, laid end to end in `data`. The first
## centres are points drawn far from each other; the best of STARTS starts is kept. Returns
## {assign: the centre of each point, w: the squares of the points' distances to their
## centres, added up}.
static func kmeans(data: PackedFloat64Array, n: int, d: int, k: int, rng: RandomNumberGenerator) -> Dictionary:
	var best := {"assign": PackedInt32Array(), "w": INF}
	var centres := PackedFloat64Array()
	centres.resize(k * d)
	var assign := PackedInt32Array()
	assign.resize(n)
	var near := PackedFloat64Array()
	near.resize(n)
	var counts := PackedInt32Array()
	counts.resize(k)
	for start in (STARTS if k > 1 else 1):
		# The first centre is any point; each next is drawn by the square of its distance
		# to the nearest centre so far.
		var first := rng.randi_range(0, n - 1)
		for j in d:
			centres[j] = data[first * d + j]
		near.fill(INF)
		for c in range(1, k):
			var total := 0.0
			for i in n:
				var dist := _dist(data, i, centres, c - 1, d)
				if dist < near[i]:
					near[i] = dist
				total += near[i]
			var at := rng.randf() * total
			var pick := n - 1
			for i in n:
				at -= near[i]
				if at <= 0.0:
					pick = i
					break
			for j in d:
				centres[c * d + j] = data[pick * d + j]
		assign.fill(-1)
		var w := 0.0
		for step in 100:
			var moved := false
			w = 0.0
			for i in n:
				var at := 0
				var least := INF
				for c in k:
					var dist := _dist(data, i, centres, c, d)
					if dist < least:
						least = dist
						at = c
				if assign[i] != at:
					assign[i] = at
					moved = true
				near[i] = least
				w += least
			if not moved:
				break
			centres.fill(0.0)
			counts.fill(0)
			for i in n:
				var c := assign[i]
				counts[c] += 1
				for j in d:
					centres[c * d + j] += data[i * d + j]
			for c in k:
				if counts[c] > 0:
					for j in d:
						centres[c * d + j] /= counts[c]
				else:
					# A centre left with no point takes the point farthest from its own.
					var far := 0
					for i in n:
						if near[i] > near[far]:
							far = i
					near[far] = 0.0
					for j in d:
						centres[c * d + j] = data[far * d + j]
		if w < float(best.w):
			best = {"assign": assign.duplicate(), "w": w}
	return best


static func _dist(data: PackedFloat64Array, i: int, centres: PackedFloat64Array, c: int, d: int) -> float:
	var total := 0.0
	var a := i * d
	var b := c * d
	for j in d:
		var x := data[a + j] - centres[b + j]
		total += x * x
	return total


## What marks a group out: the numbers whose mean among `inside` is furthest from their mean
## among `outside`, measured in the spread of both together, furthest first. Each is
## {name, in, out, by}; only those at least MARK spreads apart, and no more than MARKS.
static func marks(inside: Array, outside: Array, names: Array) -> Array:
	var found: Array = []
	if inside.is_empty() or outside.is_empty():
		return found
	for name: String in names:
		var a := _mean(inside, name)
		var b := _mean(outside, name)
		var all_mean := (a * inside.size() + b * outside.size()) / (inside.size() + outside.size())
		var sq := 0.0
		for part: Array in [inside, outside]:
			for line: Dictionary in part:
				var x := float(line.v.get(name, 0.0)) - all_mean
				sq += x * x
		var sd := sqrt(sq / (inside.size() + outside.size()))
		if sd < 0.000001:
			continue
		var by := (a - b) / sd
		if absf(by) >= MARK:
			found.append({"name": name, "in": a, "out": b, "by": by})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return absf(x.by) > absf(y.by) if absf(x.by) != absf(y.by) else str(x.name) < str(y.name))
	return found.slice(0, MARKS)


static func _mean(lines: Array, name: String) -> float:
	var total := 0.0
	for line: Dictionary in lines:
		total += float(line.v.get(name, 0.0))
	return total / maxi(1, lines.size())


# ---------- the report ----------

## A lost run's group: the round it ended in and the way, as "n2 r3 short".
static func lost_label(line: Dictionary) -> String:
	return "%s %s" % [SimReport.round_label(line.night, line.round), line.by if line.by != "" else "nothing"]


## The report of these lines: {tables, groups, grouping}. `tables` are as SimReport's:
## "strategies_won", "strategies_won_hands" and "strategies_won_instruments" (a row for each
## group of the won runs, for all the won and for all the lost), "strategies_marks" (what
## marks each group out and the players it came from), "strategies_lost",
## "strategies_lost_hands" and "strategies_lost_instruments" (a row for each round and way
## lost runs ended), and
## "strategies_runs" (every run's line, with its group). `groups` is the group of each line
## (a letter for a won run, the round and the way for a lost one) and `grouping` is what
## `group` gave for the won runs.
static func report(lines: Array) -> Dictionary:
	var names := names_of(lines)
	var won: Array = []
	var lost: Array = []
	for line: Dictionary in lines:
		if line.won:
			won.append(line)
		else:
			lost.append(line)
	var g := group(won, names)
	var k: int = g.k
	var parts: Array = []
	for c in k:
		parts.append([])
	for i in won.size():
		parts[g.of[i]].append(won[i])

	var hand_names: Array = names.filter(func(x: String) -> bool: return x.begins_with("hand:"))
	var inst_names: Array = names.filter(func(x: String) -> bool: return x.begins_with("inst:"))
	var base: Array = Array(BASE)
	var base_cols: Array = ["runs", "as Hyde", "drinks", "salts", "Temper", "Habit", "deck", "lead"]

	var rows: Array = []
	var hand_rows: Array = []
	var inst_rows: Array = []
	var mark_rows: Array = []
	var small: Array[String] = []
	var sets: Array = []
	for c in k:
		var name := "group %s" % letter(c)
		if (parts[c] as Array).size() < FEW:
			name += " *"
			small.append(letter(c))
		sets.append([name, parts[c]])
	sets.append(["all won", won])
	sets.append(["all lost", lost])
	for s: Array in sets:
		rows.append({"label": s[0], "cells": _cells(s[1], base, true)})
		hand_rows.append({"label": s[0], "cells": _cells(s[1], hand_names, true)})
		inst_rows.append({"label": s[0], "cells": _cells(s[1], inst_names, true)})
	for c in k:
		var rest: Array = []
		for o in k:
			if o != c:
				rest.append_array(parts[o])
		var words: Array[String] = []
		for m: Dictionary in marks(parts[c], rest, g.used):
			words.append("%s %s (others %s)" % [label(m.name), _shown(m.name, m.in), _shown(m.name, m.out)])
		mark_rows.append({"label": sets[c][0], "cells": [
			_text(str((parts[c] as Array).size())), _text("; ".join(words) if not words.is_empty() else "nothing"), _text(_players(parts[c], 99)),
		]})

	var few_note := ""
	if not small.is_empty():
		few_note = " * under %d runs: too few to mean anything." % FEW
	var won_title := "Won runs: %d of %d" % [won.size(), lines.size()]
	var won_note := str(g.why)
	if g.why == "":
		won_title += ", in %d groups" % k
		var gaps: Array[String] = []
		for kk: int in g.gaps:
			gaps.append("%d: %.3f +-%.3f" % [kk, g.gaps[kk], g.noise[kk]])
		won_note = "Grouped by k-means for k from %d to %d. The gap of each k and its noise: %s. Kept: the first k that one more group does not better by more than its noise." % [K_MIN, K_MAX, ", ".join(gaps)]
		if float(g.gaps[1]) >= float(g.gaps[k]) - float(g.noise[k]):
			won_note += " One group is no worse than this split by more than the noise: the runs do not fall into plain groups, so read these as a rough cut."
		elif k == K_MAX and K_MAX < won.size():
			won_note += " The gap still rises at the largest k: no count of groups stands out, so read these as one cut among several."
		won_note += few_note
	var tables: Array = []
	tables.append({
		"name": "strategies_won", "title": won_title, "cols": base_cols, "rows": rows,
		"note": won_note + "\n  as Hyde: of a run's plays. Temper, Habit: added over the three Roots. lead: Paper Roots less Ink Roots. All at the run's end; means of the group's runs.",
	})
	tables.append({
		"name": "strategies_won_hands", "title": "Won runs: the share of each hand among a run's plays",
		"cols": ["runs"] + hand_names.map(func(x: String) -> String: return x.trim_prefix("hand:")), "rows": hand_rows, "note": "",
	})
	tables.append({
		"name": "strategies_won_instruments", "title": "Won runs: the instruments held at the end, of the group's runs",
		"cols": ["runs"] + inst_names.map(func(x: String) -> String: return x.trim_prefix("inst:")), "rows": inst_rows, "note": "",
	})
	var left: Array[String] = []
	for name: String in g.left:
		left.append(label(name))
	var mark_note := "A mark is a number whose mean in the group is at least %.1f spreads from the other won runs'; the furthest first." % MARK
	if not left.is_empty():
		mark_note += " Not grouped on (rare or the same in all): %s." % ", ".join(left)
	tables.append({
		"name": "strategies_marks", "title": "Won runs: what marks each group out, and the players it came from",
		"cols": ["runs", "marks", "from"], "rows": mark_rows if g.why == "" else [], "note": mark_note if g.why == "" else str(g.why),
	})

	# The lost runs, by the round and the way they ended.
	var ends := {}
	for line: Dictionary in lost:
		var key := [line.night * SimReport.ROUNDS + line.round, line.by]
		if not ends.has(key):
			ends[key] = []
		ends[key].append(line)
	var keys: Array = ends.keys()
	keys.sort()
	rows = []
	hand_rows = []
	inst_rows = []
	var any_small := false
	for key: Array in keys:
		var part: Array = ends[key]
		var name := lost_label(part[0])
		if part.size() < FEW:
			name += " *"
			any_small = true
		var cells: Array = [_text(str(part.size())), _share_of(part.size(), lost.size())]
		cells.append_array(_cells(part, base, false))
		cells.append(_text(_players(part, 3)))
		rows.append({"label": name, "cells": cells})
		hand_rows.append({"label": name, "cells": _cells(part, hand_names, true)})
		inst_rows.append({"label": name, "cells": _cells(part, inst_names, true)})
	tables.append({
		"name": "strategies_lost", "title": "Lost runs: %d of %d, by the round and the way they ended" % [lost.size(), lines.size()],
		"cols": ["runs", "of lost"] + base_cols.slice(1) + ["most from"], "rows": rows,
		"note": "short: the round's target was not reached. line: the Ink Roots outnumbered the Paper." + (" * under %d runs: too few to mean anything." % FEW if any_small else ""),
	})
	tables.append({
		"name": "strategies_lost_hands", "title": "Lost runs: the share of each hand among a run's plays",
		"cols": ["runs"] + hand_names.map(func(x: String) -> String: return x.trim_prefix("hand:")), "rows": hand_rows, "note": "",
	})

	tables.append({
		"name": "strategies_lost_instruments", "title": "Lost runs: the instruments held at the end, of the group's runs",
		"cols": ["runs"] + inst_names.map(func(x: String) -> String: return x.trim_prefix("inst:")), "rows": inst_rows, "note": "",
	})

	# Every run's line.
	var groups: Array[String] = []
	var at := 0
	rows = []
	for line: Dictionary in lines:
		var name := lost_label(line)
		if line.won:
			name = letter(g.of[at])
			at += 1
		groups.append(name)
		var cells: Array = [_text(line.player), _text(str(line.seed)), _text("won" if line.won else "lost"), _text(name)]
		for n: String in names:
			cells.append(_text(("%.4f" % float(line.v.get(n, 0.0))).rstrip("0").rstrip(".")))
		rows.append({"label": str(rows.size()), "cells": cells})
	tables.append({
		"name": "strategies_runs", "title": "Every run's line", "cols": ["player", "seed", "ended", "group"] + Array(names), "rows": rows, "note": "",
	})
	return {"tables": tables, "groups": groups, "grouping": g}


## The report of these batches' folders, as text. Every run's line is left to the files.
static func text(dirs: Array[String], made: Dictionary = {}) -> String:
	var hashes := {}
	var batches: Array[String] = []
	for dir in dirs:
		var m := SimStore.manifest(dir)
		hashes[m.get("rules_hash", "?")] = m.get("rules_version", "?")
		batches.append(dir.get_file())
	if made.is_empty():
		made = report(read(dirs))
	var out := "== Strategies: %d runs of %d batches: %s\n" % [(made.groups as Array).size(), dirs.size(), ", ".join(batches)]
	if hashes.size() == 1:
		out += "rules %s, hash %s\n" % [hashes.values()[0], hashes.keys()[0]]
	else:
		out += "THE RULES DIFFER among these batches (%s): a group may be the rules', not a way of playing.\n" % ", ".join(PackedStringArray(hashes.keys()))
	for t: Dictionary in made.tables:
		if t.name == "strategies_runs":
			continue
		if t.name == "strategies_marks":
			out += "\n" + str(t.title) + "\n"
			for row: Dictionary in t.rows:
				out += "  %s, %s runs\n    marks: %s\n    from: %s\n" % [row.label, row.cells[0].t, row.cells[1].t, row.cells[2].t]
			out += "  " + str(t.note) + "\n"
			continue
		var rows: Array = []
		for row: Dictionary in t.rows:
			var cells: Array = [row.label]
			for c: Dictionary in row.cells:
				cells.append(SimReport.show(c))
			rows.append(cells)
		out += "\n" + SimReport._table_text(t, rows)
	return out


## Prints the report of these batches' folders, and with `csv` writes each table (and every
## run's line) as `report_strategies_*.csv` in the folder that holds the first batch.
static func run(dirs: Array[String], csv: bool) -> void:
	var made := report(read(dirs))
	print(text(dirs, made))
	if csv and not dirs.is_empty():
		for path in SimReport.write_csv(dirs[0].get_base_dir(), made.tables):
			print("wrote " + path.trim_prefix("res://"))


## A group's letter, from 0.
static func letter(group_no: int) -> String:
	return char(65 + group_no)


# The cells of a row: how many runs (if asked), then the mean of each number among them.
static func _cells(lines: Array, names: Array, count: bool) -> Array:
	var cells: Array = []
	if count:
		cells.append(_text(str(lines.size())))
	for name: String in names:
		var cell := {"k": "share" if is_share(name) else "mean", "s": 0.0, "q": 0.0, "n": 0}
		for line: Dictionary in lines:
			var x := float(line.v.get(name, 0.0))
			cell.s += x
			cell.q += x * x
			cell.n += 1
		cells.append(cell)
	return cells


static func _text(t: String) -> Dictionary:
	return {"k": "text", "t": t}


static func _share_of(hits: int, n: int) -> Dictionary:
	return {"k": "share", "s": float(hits), "q": float(hits), "n": n}


# A number as a mark shows it.
static func _shown(name: String, x: float) -> String:
	return "%.0f%%" % (100.0 * x) if is_share(name) else "%.1f" % x


# The players these lines came from, the most runs first: "a 12, b 3". No more than `most`.
static func _players(lines: Array, most: int) -> String:
	var counts := {}
	for line: Dictionary in lines:
		counts[line.player] = int(counts.get(line.player, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return counts[a] > counts[b] if counts[a] != counts[b] else a < b)
	var words: Array[String] = []
	for key: String in keys.slice(0, most):
		words.append("%s %d" % [key, counts[key]])
	return ", ".join(words)
