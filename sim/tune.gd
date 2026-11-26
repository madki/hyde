extends SceneTree
## Searches the numbers of a persona (sim/personas.gd) for a way of playing that clears more
## rounds than a named one, started by tools/sim_tune.sh. User arguments:
##
##   start=<name>      the named persona the search starts from
##   rounds=<n>        rounds of the search (8 if not given)
##   tries=<n>         candidates of each round (6)
##   seeds=<n>         seeds a candidate is played on (150)
##   from=<n>          the first seed of the search (1000)
##   show=<a>-<b>      the seeds the persona found is shown on (0-300)
##   seed=<n>          the search's own generator (1): another seed is another search
##   z=<x> z2=<x>      how far over the noise a gain must be, first and second time (2, 1)
##
## A round changes one to three numbers of the persona held, `tries` times over, and plays
## each candidate on the seeds `from` to `from + seeds`. The gain of a candidate is the mean,
## seed by seed, of the rounds it cleared less the rounds the persona held cleared on that
## seed; the noise is that mean's standard error. The candidate of the greatest gain over
## `z` standard errors is played again on the next `seeds` seeds, and is held from then on if
## its gain there is over `z2` standard errors. Picking the best of several is itself a lift,
## which is why one set of seeds is not enough to keep a change.
##
## The persona held at the end is written to sim/personas_found.json as `found-<start>` and
## played on the seeds of `show`, which the search never plays, beside the one it started from.
##
## This script plays nothing. Each time it is run it walks the search from its beginning,
## reading the batches on disk; at the first batch that is missing it prints the batches to
## play as `TUNE PLAY` lines and stops, and tools/sim_tune.sh plays them and runs it again.
## A candidate is the player `persona.<start>?<number>=<value>&...`: the numbers that differ
## from the start's, in order of name. That text is the batch's player, so a candidate that
## was ever played, by this search or another, is found on disk and not played again.

## The numbers the search moves, and how. A whole number goes a rung or two along its list,
## a truth is turned over, a list loses, gains or swaps one of its names. A weight goes
## `step` or twice `step` up or down between `least` and `most`.
## `samples` is left alone because it is what a run costs, and `no_turn`, `no_discard` and
## `buys` because they are flaws given on purpose.
const RUNGS := {
	"drink_at": [1, 2, 3, 4, 5, 6, 8, 99],
	"hyde_stay": [1, 2, 3, 4, 5, 6, 8, 99],
	"drink_min_cushion": [0, 1, 2, 3],
	"salt_cushion": [-9, 0, 1, 2, 3, 4],
	"salt_reserve": [0, 1, 2],
	"min_cushion": [-99, 0, 1, 2, 3, 4],
	"salt_target": [0, 1, 2, 3, 4, 5, 6],
	"strike_cushion": [0, 1, 2, 3, 4, 5, 99],
}
const TRUTHS: Array[String] = ["drink_asap", "forced_drink", "scene_aware", "strike_ink"]
const WEIGHTS := {
	"w_turn": {"step": 0.05, "least": 0.0, "most": 0.6},
	"w_temper": {"step": 0.04, "least": 0.0, "most": 0.4},
	"w_break": {"step": 0.2, "least": 0.0, "most": 1.6},
	"w_habit": {"step": 0.04, "least": 0.0, "most": 0.4},
	"discard_gain": {"step": 0.06, "least": 0.9, "most": 1.5},
	"paper_w": {"step": 0.3, "least": 0.0, "most": 2.4},
}
## Every `card_<kind>` is a weight of this step.
const CARD_WEIGHT := {"step": 0.4, "least": 0.0, "most": 2.8}
const LISTS: Array[String] = ["inst_pref", "alley_inst", "strike_kinds"]

const PERSONA := "persona"
const FOUND_PREFIX := "found-"
const SCORES_FILE := "tune_scores.json"

var start := ""
var rounds := 8
var tries := 6
var seeds := 150
var from := 1000
var show_from := 0
var show_to := 300
var search_seed := 1
var z := 2.0
var z2 := 1.0

# The batches on disk of the rules of now, by player and seeds.
var _index: Dictionary = {}
# Rounds cleared and wins of each batch read, seed by seed, kept between runs of this script.
var _kept: Dictionary = {}
var _kept_changed := false
# The batches to play before the search can go on.
var _wanted: Array[String] = []
var _log: Array[String] = []


func _initialize() -> void:
	var problem := _read_args()
	if problem == "":
		problem = _search()
	if _kept_changed:
		_write_json(_scores_path(), _kept, "")
	if problem != "":
		print("TUNE FAILED: " + problem)
		quit(1)
	else:
		quit(0)


func _read_args() -> String:
	for a in OS.get_cmdline_user_args():
		var eq := a.find("=")
		var key := a if eq < 0 else a.substr(0, eq)
		var value := "" if eq < 0 else a.substr(eq + 1)
		if key in ["rounds", "tries", "seeds", "from", "seed"] and not value.is_valid_int():
			return "%s is a whole number: %s" % [key, value]
		if key in ["z", "z2"] and not value.is_valid_float():
			return "%s is a number: %s" % [key, value]
		match key:
			"start": start = value
			"rounds": rounds = int(value)
			"tries": tries = int(value)
			"seeds": seeds = int(value)
			"from": from = int(value)
			"seed": search_seed = int(value)
			"z": z = float(value)
			"z2": z2 = float(value)
			"show":
				var ends := value.split("-")
				if ends.size() != 2:
					return "show is two seeds, as 0-300: %s" % value
				show_from = int(ends[0])
				show_to = int(ends[1])
			_: return "Unknown argument: %s" % a
	if not SimPersonas.NAMED.has(start):
		return "start is a named persona (%s): %s" % [", ".join(PackedStringArray(SimPersonas.names())), start]
	if rounds < 0 or tries < 1 or seeds < 2 or show_to <= show_from:
		return "Nothing to search with rounds=%d tries=%d seeds=%d show=%d-%d" % [rounds, tries, seeds, show_from, show_to]
	if show_from < from + 2 * seeds and from < show_to:
		return "The seeds shown (%d-%d) are seeds of the search (%d-%d)" % [show_from, show_to, from, from + 2 * seeds]
	return ""


# ---------- the search ----------

func _search() -> String:
	_read_index()
	var base := SimPersonas.numbers(start)
	var held: Dictionary = base.duplicate(true)
	var a := from
	var b := from + seeds
	var c := from + 2 * seeds
	var held_first := _scores(player_of(start, base, held), a, b)
	var held_second := _scores(player_of(start, base, held), b, c)
	if _stop_to_play("the start, %s" % start):
		return ""
	_log.append("%s: %.2f rounds cleared a run on seeds %d-%d, %.2f on %d-%d" % [
		start, mean(held_first.cleared), a, b, mean(held_second.cleared), b, c,
	])
	var seen := {player_of(start, base, held): true}
	var kept := 0
	for r in rounds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([start, search_seed, r])
		var cands: Array = []
		var guard := 0
		while cands.size() < tries and guard < tries * 20:
			guard += 1
			var numbers := mutate(held, rng)
			var player := player_of(start, base, numbers)
			if seen.has(player):
				continue
			seen[player] = true
			cands.append({"numbers": numbers, "player": player, "first": _scores(player, a, b)})
		if _stop_to_play("round %d of %d" % [r + 1, rounds]):
			return ""
		for cand: Dictionary in cands:
			cand.gain = gain(cand.first.cleared, held_first.cleared)
		cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.gain.mean > y.gain.mean)
		var was := held
		var taken := false
		for cand: Dictionary in cands:
			var g: Dictionary = cand.gain
			var line := "  round %d  %+.2f +-%.2f  %s" % [r + 1, g.mean, g.se, changed_text(was, cand.numbers)]
			if taken or not over(g, z):
				_log.append(line)
				continue
			var second := _scores(cand.player, b, c)
			if _stop_to_play("round %d of %d, the second seeds" % [r + 1, rounds]):
				return ""
			var g2 := gain(second.cleared, held_second.cleared)
			line += "  again %+.2f +-%.2f" % [g2.mean, g2.se]
			if over(g2, z2):
				taken = true
				kept += 1
				held = cand.numbers
				held_first = cand.first
				held_second = second
				line += "  KEPT"
			_log.append(line)
	return _show(base, held, kept)


# The end of the search: the persona found, written by name and shown beside its start on
# the seeds the search did not play.
func _show(base: Dictionary, held: Dictionary, kept: int) -> String:
	var found_name := FOUND_PREFIX + start
	var entry := entry_of(start, base, held)
	var none := kept == 0
	var before := _scores("%s.%s" % [PERSONA, start], show_from, show_to)
	var after := {}
	if not none:
		if not write_found(found_name, entry):
			return "Cannot write %s" % SimPersonas.FOUND_PATH
		# The batch of a found persona is known by its numbers as well as its name: the name
		# stays when a later search finds other numbers.
		var batch := "tune.show.%s.%s__%d-%d" % [found_name, JSON.stringify(entry).md5_text().substr(0, 10), show_from, show_to]
		var dir := SimStore.batch_dir(batch)
		var player := "%s.%s" % [PERSONA, found_name]
		var m := SimStore.manifest(dir)
		if m.get("player", "") == player and m.get("rules_hash", "") == SimStore.rules_hash() and m.get("player_hash", "") == SimStore.player_hash(player) and m.get("seeds", []) == [show_from, show_to]:
			after = _read_scores(dir)
		else:
			_wanted.append("TUNE PLAY|%s|%d|%d|%s|force" % [batch, show_from, show_to, player])
	if _stop_to_play("the persona found, on the seeds not searched"):
		return ""
	for line in _log:
		print(line)
	var n: int = before.cleared.size()
	var searched := "searched on seeds %d-%d with %d rounds of %d, seed %d" % [from, from + 2 * seeds, rounds, tries, search_seed]
	if none:
		print("TUNE %s: none found that clears more rounds (%s)" % [start, searched])
		if SimPersonas.read_found().has(found_name):
			print("  %s is kept in %s as it was" % [found_name, SimPersonas.FOUND_PATH])
		print("  seeds %d-%d  %s  %d wins of %d (%.1f%%), %.2f rounds cleared a run" % [
			show_from, show_to, start, total(before.won), n, 100.0 * total(before.won) / n, mean(before.cleared),
		])
		return ""
	var g := gain(after.cleared, before.cleared)
	print("TUNE %s: %s.%s, %d changes kept (%s)" % [start, PERSONA, found_name, kept, searched])
	print("  changed: %s" % changed_text(base, held))
	print("  seeds %d-%d, not searched:" % [show_from, show_to])
	print("    %-14s %3d wins of %d (%.1f%%), %.2f rounds cleared a run" % [
		start, total(before.won), n, 100.0 * total(before.won) / n, mean(before.cleared),
	])
	print("    %-14s %3d wins of %d (%.1f%%), %.2f rounds cleared a run" % [
		found_name, total(after.won), n, 100.0 * total(after.won) / n, mean(after.cleared),
	])
	print("    gain %+.2f rounds a run, +-%.2f%s" % [g.mean, g.se, "" if over(g, z) else "  (within the noise)"])
	return ""


# Prints the batches wanted, if there are any, and says so.
func _stop_to_play(where: String) -> bool:
	if _wanted.is_empty():
		return false
	print("TUNE AT %s: %s, %d to play" % [start, where, _wanted.size()])
	for line in _wanted:
		print(line)
	return true


# ---------- the numbers ----------

## How each number the search moves is moved: a list of rungs, true for a truth, a
## {step, least, most} for a weight, or the names a list may hold.
static func moves() -> Dictionary:
	var out: Dictionary = RUNGS.duplicate()
	for key in TRUTHS:
		out[key] = true
	for key: String in WEIGHTS:
		out[key] = WEIGHTS[key]
	for key: String in SimPersonas.DEFAULTS:
		if key.begins_with("card_"):
			out[key] = CARD_WEIGHT
	out["inst_pref"] = Array(RulesConfig.LAB_INSTRUMENTS)
	out["alley_inst"] = Array(RulesConfig.HIS_INSTRUMENTS)
	# Only a Factor is struck by its kind.
	out["strike_kinds"] = Array(RulesConfig.FACTORS)
	return out


## A persona's numbers with one to three of them changed.
static func mutate(numbers: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = numbers.duplicate(true)
	var how := moves()
	var keys: Array = how.keys()
	var roll := rng.randf()
	var count := 1 if roll < 0.4 else (2 if roll < 0.8 else 3)
	var done := {}
	var guard := 0
	while done.size() < count and guard < 60:
		guard += 1
		var key: String = keys[rng.randi_range(0, keys.size() - 1)]
		if done.has(key):
			continue
		var v: Variant = moved(out[key], how[key], rng)
		if text(v) == text(out[key]):
			continue
		out[key] = v
		done[key] = true
	return out


## One number, moved as `how` says (see `moves`). It may come back as it was.
static func moved(v: Variant, how: Variant, rng: RandomNumberGenerator) -> Variant:
	var far := 2 if rng.randf() < 0.25 else 1
	var way := far if rng.randf() < 0.5 else -far
	match typeof(v):
		TYPE_BOOL:
			return not v
		TYPE_INT:
			var rungs: Array = how
			var at := 0
			for i in rungs.size():
				if absi(int(rungs[i]) - int(v)) < absi(int(rungs[at]) - int(v)):
					at = i
			return int(rungs[clampi(at + way, 0, rungs.size() - 1)])
		TYPE_FLOAT:
			var w: Dictionary = how
			# The value its text reads back as: a candidate is played from its name.
			return text(clampf(float(v) + way * float(w.step), w.least, w.most)).to_float()
		TYPE_ARRAY:
			var list: Array = (v as Array).duplicate()
			var absent: Array = []
			for name: Variant in how:
				if not list.has(name):
					absent.append(name)
			match rng.randi_range(0, 2):
				0:
					if list.size() >= 2:
						var i := rng.randi_range(0, list.size() - 2)
						var held: Variant = list[i]
						list[i] = list[i + 1]
						list[i + 1] = held
				1:
					if not list.is_empty():
						list.remove_at(rng.randi_range(0, list.size() - 1))
				2:
					if not absent.is_empty():
						list.insert(rng.randi_range(0, list.size()), absent[rng.randi_range(0, absent.size() - 1)])
			return list
	return v


## A number as it is written in a player's name: 3, 0.25, true, a+b.
static func text(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL: return "true" if v else "false"
		TYPE_INT: return str(v)
		TYPE_FLOAT: return String.num(snappedf(v, 0.01), 2)
		TYPE_ARRAY: return "+".join(PackedStringArray(v as Array))
	return str(v)


## The names of the numbers that differ between two personas, in order of name.
static func differing(base: Dictionary, numbers: Dictionary) -> Array:
	var keys: Array = []
	for key: String in numbers:
		if text(numbers[key]) != text(base.get(key)):
			keys.append(key)
	keys.sort()
	return keys


## The player that plays these numbers: the start, with the numbers that differ from it.
static func player_of(start_name: String, base: Dictionary, numbers: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in differing(base, numbers):
		parts.append("%s=%s" % [key, text(numbers[key])])
	var head := "%s.%s" % [PERSONA, start_name]
	return head if parts.is_empty() else head + "?" + "&".join(PackedStringArray(parts))


## The persona as sim/personas_found.json holds it: its start and the numbers that differ.
static func entry_of(start_name: String, base: Dictionary, numbers: Dictionary) -> Dictionary:
	var out := {"based_on": start_name}
	for key: String in differing(base, numbers):
		out[key] = numbers[key]
	return out


## What differs between two personas, for a reader: "hyde_stay 3 -> 2, w_turn 0.15 -> 0.2".
static func changed_text(base: Dictionary, numbers: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in differing(base, numbers):
		parts.append("%s %s -> %s" % [key, _shown(base[key]), _shown(numbers[key])])
	return ", ".join(PackedStringArray(parts))


static func _shown(v: Variant) -> String:
	var t := text(v)
	return "(none)" if t == "" else t


# ---------- the noise ----------

## How much more `a` is than `b`, seed by seed: {mean, se}, the mean of the differences and
## its standard error.
static func gain(a: Array, b: Array) -> Dictionary:
	var n := mini(a.size(), b.size())
	if n < 2:
		return {"mean": 0.0, "se": 0.0}
	var sum := 0.0
	for i in n:
		sum += float(a[i]) - float(b[i])
	var m := sum / n
	var sq := 0.0
	for i in n:
		var d := float(a[i]) - float(b[i]) - m
		sq += d * d
	return {"mean": m, "se": sqrt(sq / (n - 1) / n)}


## Whether a gain is more than `by` standard errors over nothing.
static func over(g: Dictionary, by: float) -> bool:
	return g.mean > 0.0 and g.mean > by * float(g.se)


static func mean(a: Array) -> float:
	return float(total(a)) / maxi(1, a.size())


static func total(a: Array) -> int:
	var sum := 0
	for v: Variant in a:
		sum += int(v)
	return sum


# ---------- the batches on disk ----------

func _read_index() -> void:
	var now := SimStore.rules_hash()
	for dir: String in SimStore.batches(RulesConfig.RULES_VERSION):
		var m := SimStore.manifest(dir)
		if m.get("rules_hash", "") != now or m.get("player_hash", "") != SimStore.player_hash(str(m.get("player", ""))) or not (m.get("dials", {}) as Dictionary).is_empty() or not (m.get("give", []) as Array).is_empty():
			continue
		var s: Array = m.get("seeds", [0, 0])
		_index[_key(str(m.get("player", "")), int(s[0]), int(s[1]))] = dir
	var kept: Variant = null
	if FileAccess.file_exists(_scores_path()):
		kept = JSON.parse_string(FileAccess.get_file_as_string(_scores_path()))
	if kept is Dictionary:
		_kept = kept


static func _key(player: String, a: int, b: int) -> String:
	return "%s %d %d" % [player, a, b]


func _scores_path() -> String:
	return "%s/%s/%s" % [SimStore.root, RulesConfig.RULES_VERSION, SCORES_FILE]


# The rounds cleared and the wins of a player on these seeds, seed by seed: {cleared, won}.
# With no such batch on disk it is wanted, and both are empty.
func _scores(player: String, a: int, b: int) -> Dictionary:
	var dir: String = _index.get(_key(player, a, b), "")
	if dir == "":
		var batch := "tune.%s.%s__%d-%d" % [start, player.md5_text().substr(0, 10), a, b]
		_wanted.append("TUNE PLAY|%s|%d|%d|%s" % ["" if player.find("?") < 0 else batch, a, b, player])
		return {"cleared": [], "won": []}
	return _read_scores(dir)


func _read_scores(dir: String) -> Dictionary:
	var started := str(SimStore.manifest(dir).get("started", ""))
	var have: Variant = _kept.get(dir)
	if have is Dictionary and have.get("started", "") == started:
		return have
	var out := {"started": started, "cleared": [], "won": []}
	for line: Dictionary in SimStore.read_lines(dir + "/runs.jsonl"):
		out.cleared.append(SimGame.cleared(line))
		out.won.append(int(SimGame.won(line)))
	_kept[dir] = out
	_kept_changed = true
	return out


# Puts a persona into the file of found ones. Returns whether the file is as wanted. A file
# that is there and cannot be read is left alone: writing over it would lose every other
# persona in it.
static func write_found(found_name: String, entry: Dictionary, path: String = SimPersonas.FOUND_PATH) -> bool:
	if FileAccess.file_exists(path) and not JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary:
		return false
	# Read with its whole numbers whole, so that they are written back as they were.
	var all: Dictionary = SimStore.whole(SimPersonas.read_found(path))
	if JSON.stringify(all.get(found_name)) == JSON.stringify(entry):
		return true
	all[found_name] = entry
	return _write_json(path, all, "\t")


# Written whole beside the file and then put in its place, so that a search stopped while it
# writes leaves the file as it was.
static func _write_json(path: String, data: Dictionary, indent: String) -> bool:
	var beside := path + ".tmp"
	var f := FileAccess.open(beside, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, indent, true) + "\n")
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(beside), ProjectSettings.globalize_path(path)) == OK
