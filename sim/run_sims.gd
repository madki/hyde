extends SceneTree
## Plays a batch of runs headless, started by tools/sim.sh. User arguments:
##
##   player=<name>     "greedy", "file.variant" or "file.variant?key=value&key=value"
##   from=<n> to=<n>   the seeds: `from` up to, and not with, `to` (0 and 100 if not given)
##   name=<batch>      the batch's name (made from the player, dials and seeds if not given)
##   give=a+b          instruments held from the start
##   d.<dial>=<json>   a changed number of RulesDials
##   force             play a batch again that is already on disk
##   step=plan|play|join   what this process does ("play" if not given):
##     plan   checks the arguments, says whether the batch is on disk, and makes its folder
##     play   plays the seeds and writes them as a part file in the batch's folder
##     join   joins the part files into runs.jsonl, writes the manifest and prints the line
##   commit=<hash> dirty=<0|1> started=<unix time>   for the manifest, at the join

var player_name := "greedy"
var from := 0
var to := 100
var batch := ""
var give: Array = []
var dials: Dictionary = {}
var force := false
var step := "play"
var commit := ""
var dirty := false
var started := 0.0


func _initialize() -> void:
	var problem := _read_args()
	if problem == "":
		match step:
			"plan": problem = _plan()
			"play": problem = _play()
			"join": problem = _join()
			_: problem = "No such step: %s" % step
	if problem != "":
		print("SIM FAILED: " + problem)
		quit(1)
	else:
		quit(0)


func _read_args() -> String:
	for a in OS.get_cmdline_user_args():
		var eq := a.find("=")
		var key := a if eq < 0 else a.substr(0, eq)
		var value := "" if eq < 0 else a.substr(eq + 1)
		match key:
			"player": player_name = value
			"from": from = int(value)
			"to": to = int(value)
			"name": batch = value
			"give": give = Array(value.split("+", false))
			"force": force = true
			"step": step = value
			"commit": commit = value
			"dirty": dirty = value == "1"
			"started": started = float(value)
			_:
				if not key.begins_with("d.") or eq < 0:
					return "Unknown argument: %s" % a
				dials[key.substr(2)] = SimStore.read_value(value)
	if to <= from:
		return "No seeds: from=%d to=%d" % [from, to]
	var wrong := RulesDials.problems(dials)
	for k: Variant in wrong:
		return str(wrong[k])
	for key: Variant in give:
		if not RulesConfig.INSTRUMENTS.has(key):
			return "No such instrument: %s" % key
	if batch == "":
		batch = SimStore.batch_name(player_name, dials, give, from, to)
	if not batch.is_valid_filename():
		return "Not a batch's name: %s" % batch
	return ""


func _plan() -> String:
	if SimPlayer.make(player_name) == null:
		return "No such player: %s" % player_name
	var wanted := SimStore.new_manifest(player_name, dials, give, from, to)
	var dir := SimStore.batch_dir(batch)
	if not force:
		var found := SimStore.find(wanted)
		if found != "":
			print("SIM HAVE")
			print(summary(SimStore.load(found), found) + " (on disk, not played again)")
			return ""
		if not SimStore.manifest(dir).is_empty():
			return "The batch %s holds other runs. Give another name, or force." % batch
	SimStore.make_dir(dir)
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("part_") or f == "manifest.json" or f == "runs.jsonl":
			DirAccess.remove_absolute(dir + "/" + f)
	print("SIM NAME %s" % batch)
	print("SIM SEEDS %d %d" % [from, to])
	print("SIM START %.3f" % Time.get_unix_time_from_system())
	return ""


func _play() -> String:
	var player := SimPlayer.make(player_name)
	if player == null:
		return "No such player: %s" % player_name
	var dir := SimStore.batch_dir(batch)
	SimStore.make_dir(dir)
	var f := FileAccess.open("%s/part_%010d.jsonl" % [dir, from], FileAccess.WRITE)
	if f == null:
		return "Cannot write in %s" % dir
	for s in range(from, to):
		f.store_line(JSON.stringify(SimGame.play_run(player, s, dials, give), "", false))
	f.close()
	print("SIM PART %d %d" % [from, to])
	return ""


func _join() -> String:
	var dir := SimStore.batch_dir(batch)
	var parts: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("part_"):
			parts.append(f)
	parts.sort()
	var out := FileAccess.open(dir + "/runs.jsonl", FileAccess.WRITE)
	if out == null:
		return "Cannot write in %s" % dir
	for p in parts:
		out.store_string(FileAccess.get_file_as_string(dir + "/" + p))
	out.close()
	var runs := SimStore.read_lines(dir + "/runs.jsonl")
	if runs.size() != to - from:
		return "%d runs of %d were played" % [runs.size(), to - from]
	for i in runs.size():
		if runs[i].seed != from + i:
			return "The run of seed %d is missing" % (from + i)
	var m := SimStore.new_manifest(player_name, dials, give, from, to)
	m.commit = commit
	m.dirty = dirty
	m.runs = runs.size()
	m.started = Time.get_datetime_string_from_unix_time(int(started)) + "Z"
	m.seconds = snappedf(Time.get_unix_time_from_system() - started, 0.01)
	if not SimStore.write_manifest(dir, m):
		return "Cannot write the manifest in %s" % dir
	for p in parts:
		DirAccess.remove_absolute(dir + "/" + p)
	print(summary({"manifest": m, "runs": runs}, dir))
	return ""


## A batch in one line: wins, rounds cleared, seconds.
static func summary(data: Dictionary, dir: String) -> String:
	var m: Dictionary = data.manifest
	var runs: Array = data.runs
	var wins := 0
	var cleared := 0
	var ms := 0.0
	var odd := 0
	for line: Dictionary in runs:
		wins += int(SimGame.won(line))
		cleared += SimGame.cleared(line)
		ms += float(line.ms)
		odd += int(line.by == "guard" or line.by == "illegal")
	var n := maxi(1, runs.size())
	var text := "SIM %s seeds %d-%d: %d wins of %d (%.1f%%), %d rounds cleared (%.2f a run), %.1f s, %.1f ms a run, in %s" % [
		m.player, m.seeds[0], m.seeds[1], wins, runs.size(), 100.0 * wins / n,
		cleared, float(cleared) / n, float(m.seconds), ms / n, dir.trim_prefix("res://"),
	]
	if odd > 0:
		text += ", %d runs ended by the guard or a refused move" % odd
	return text
