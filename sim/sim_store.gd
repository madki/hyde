class_name SimStore
## What the sims keep on disk. A batch is a folder `<root>/<RULES_VERSION>/<batch>/` with
## `manifest.json` ({rules_version, rules_hash, player_hash, commit, dirty, player, dials, give,
## seeds: [from, to], runs, started, seconds, godot}; `dials` is the changed numbers only,
## `to` is the first seed not played) and `runs.jsonl`, one run a line (SimGame.play_run).

const RULES_DIR := "res://scripts/rules"
## What makes two batches the same runs.
const SAME: Array[String] = ["player", "dials", "give", "seeds", "rules_hash", "player_hash"]
## The scripts a run is played by, beside the rules: every player, and what players and the
## run loop are made of. The reports are not among them: they play nothing.
const PLAYERS_DIR := "res://sim/players"
const PLAY_SCRIPTS: Array[String] = [
	"res://sim/personas.gd", "res://sim/sim_game.gd", "res://sim/sim_moves.gd",
	"res://sim/sim_player.gd", "res://sim/sim_value.gd",
]
## A player whose name holds this plays numbers of the file of found personas.
const FOUND_MARK := "found-"

## Where batches are kept. A test points it somewhere else.
static var root := "res://sim_data"

static var _hash := ""
static var _play_hash := ""


## A hash of the text of every script of the rules, by file name.
static func rules_hash() -> String:
	if _hash != "":
		return _hash
	var names: Array[String] = []
	for f in DirAccess.get_files_at(RULES_DIR):
		if f.ends_with(".gd"):
			names.append(f)
	names.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for f in names:
		ctx.update((f + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(RULES_DIR + "/" + f))
		ctx.update("\n".to_utf8_buffer())
	_hash = ctx.finish().hex_encode().substr(0, 16)
	return _hash


## A hash of the text of every script a player's runs are played by, and, for a player of
## the file of found personas, of that file: a batch played before one of them changed is
## not the runs the player would play now.
static func player_hash(player: String) -> String:
	if _play_hash == "":
		var paths: Array[String] = PLAY_SCRIPTS.duplicate()
		for f in DirAccess.get_files_at(PLAYERS_DIR):
			if f.ends_with(".gd"):
				paths.append(PLAYERS_DIR + "/" + f)
		paths.sort()
		_play_hash = _hash_of(paths)
	if not player.contains(FOUND_MARK):
		return _play_hash
	return (_play_hash + _hash_of([SimPersonas.FOUND_PATH])).sha256_text().substr(0, 16)


static func _hash_of(paths: Array[String]) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in paths:
		ctx.update((path + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(path))
		ctx.update("\n".to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


## Whether a batch on disk is this one played before the player's scripts (or the found
## personas) changed: the same runs but for the player's hash.
static func is_stale(on_disk: Dictionary, wanted: Dictionary) -> bool:
	if on_disk.is_empty() or same_runs(on_disk, wanted):
		return false
	var as_now := on_disk.duplicate()
	as_now["player_hash"] = wanted.get("player_hash")
	return same_runs(as_now, wanted)


## The folder of the batch of this name, under the rules' version of now.
static func batch_dir(name: String) -> String:
	return "%s/%s/%s" % [root, RulesConfig.RULES_VERSION, name]


## A name for a batch, made from its player, changed numbers, instruments and seeds.
static func batch_name(player: String, dials: Dictionary, give: Array, from: int, to: int) -> String:
	var parts: Array[String] = [player]
	var keys: Array = dials.keys()
	keys.sort()
	for k: String in keys:
		parts.append("%s-%s" % [k, dials[k]])
	if not give.is_empty():
		parts.append("give-" + "+".join(PackedStringArray(give)))
	parts.append("%d-%d" % [from, to])
	var safe := ""
	for ch in "__".join(parts):
		safe += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in ".-_+" else "_"
	return safe


## The folder of a batch on disk whose manifest is the same runs as this one (player, dials,
## give, seeds, and the hashes of the rules and of the player), under any version, or "" if
## there is none.
static func find(manifest_wanted: Dictionary) -> String:
	for dir: String in batches():
		if same_runs(manifest(dir), manifest_wanted):
			return dir
	return ""


## Whether two manifests are the same runs.
static func same_runs(a: Dictionary, b: Dictionary) -> bool:
	for k in SAME:
		var default: Variant = [] if k == "give" else null
		if JSON.stringify(whole(a.get(k, default)), "", true) != JSON.stringify(whole(b.get(k, default)), "", true):
			return false
	return true


## A batch read back: {manifest, runs}. `runs` is the lines of runs.jsonl, in order.
@warning_ignore("shadowed_global_identifier")
static func load(dir: String) -> Dictionary:
	return {"manifest": manifest(dir), "runs": read_lines(dir + "/runs.jsonl")}


## A batch's manifest, or {} if the folder has none.
static func manifest(dir: String) -> Dictionary:
	var path := dir + "/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return whole(data) if data is Dictionary else {}


## The folders of the batches on disk (those with a manifest), in order of name: of one
## version of the rules, or ("") of every version.
static func batches(rules_version: String = "") -> Array[String]:
	var out: Array[String] = []
	var versions: Array = [rules_version]
	if not DirAccess.dir_exists_absolute(root):
		return out
	if rules_version == "":
		versions = Array(DirAccess.get_directories_at(root))
		versions.sort()
	for v: String in versions:
		if not DirAccess.dir_exists_absolute(root + "/" + v):
			continue
		var names := Array(DirAccess.get_directories_at(root + "/" + v))
		names.sort()
		for n: String in names:
			var dir := "%s/%s/%s" % [root, v, n]
			if FileAccess.file_exists(dir + "/manifest.json"):
				out.append(dir)
	return out


## The manifest of a batch about to be played, without what is known only afterwards.
static func new_manifest(player: String, dials: Dictionary, give: Array, from: int, to: int) -> Dictionary:
	return {
		"rules_version": RulesConfig.RULES_VERSION, "rules_hash": rules_hash(), "player_hash": player_hash(player),
		"commit": "", "dirty": false, "player": player, "dials": dials, "give": give,
		"seeds": [from, to], "runs": 0, "started": "", "seconds": 0.0,
		"godot": Engine.get_version_info().string,
	}


## Makes a batch's folder (and the root's .gdignore, which keeps the editor out of it).
static func make_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(root + "/.gdignore"):
		FileAccess.open(root + "/.gdignore", FileAccess.WRITE).close()


## Writes lines of data to a file, one a line. Returns whether it could.
static func write_lines(path: String, lines: Array) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	for line: Variant in lines:
		f.store_line(JSON.stringify(line, "", false))
	f.close()
	return true


## The lines of data of a file, each read back with its whole numbers as ints.
static func read_lines(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var text := f.get_line()
		if text.strip_edges() == "":
			continue
		var data: Variant = JSON.parse_string(text)
		if data != null:
			out.append(whole(data))
	f.close()
	return out


## Writes a batch's manifest. Returns whether it could.
static func write_manifest(dir: String, data: Dictionary) -> bool:
	var f := FileAccess.open(dir + "/manifest.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	return true


## A value given as text: JSON if it is JSON (with whole numbers as ints), else the text.
static func read_value(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return text
	return whole(json.data)


## Data read from JSON, which has one kind of number, with every whole number an int again.
static func whole(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if f == floor(f) and absf(f) < 9.0e15 else f
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				a[i] = whole(a[i])
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k: Variant in d:
				d[k] = whole(d[k])
	return v
