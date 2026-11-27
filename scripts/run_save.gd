class_name RunSave
## The run kept on this machine, so that a game closed in the middle of a run can be taken up
## again: one file at `path`, {v: 1, run: <the run's data>, story: [<keys of the lines told>]}.
## A run is kept only at rest: in a round ("play") or at a dawn's place ("lab", "alley"). A file
## that does not read back as a run that can be played on counts as no save. Nothing is read or
## written when the bench drives (as ArenaFirsts).

## Where the run is kept. A test points it elsewhere.
static var path := "user://run.json"

## The version of the file's envelope.
const VERSION := 1
## The phases of a run at rest: the ones kept.
const KEPT_PHASES: Array[String] = ["play", "lab", "alley"]


## Keeps `run` and the keys of the story told so far, when the run is at rest; otherwise does
## nothing. Written beside `path` and renamed over it, so a write cut short leaves the save
## before it.
static func keep(run: RulesRun, story: Array = []) -> void:
	if _driven() or run == null or not KEPT_PHASES.has(run.phase):
		return
	var text := JSON.stringify({"v": VERSION, "run": run.to_dict(), "story": story})
	var aside := path + ".new"
	var file := FileAccess.open(aside, FileAccess.WRITE)
	if file == null:
		push_warning("The run could not be kept: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(aside, path) != OK:
		# Where a rename over a file is refused, the save is written in place instead.
		DirAccess.remove_absolute(aside)
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_warning("The run could not be kept: %s" % error_string(FileAccess.get_open_error()))
			return
		file.store_string(text)
		file.close()


## The kept run, as {run: RulesRun, story: Array}; {} when there is none that can be played on.
static func read() -> Dictionary:
	if _driven():
		return {}
	var kept := read_file(path)
	# Only a run at rest can be taken up: one in any other phase was not kept by the game.
	if kept.is_empty() or not KEPT_PHASES.has(kept.run.phase):
		return {}
	return kept


## The run in the file at `file_path`, as read() gives it. The file may also hold a bare run
## (Rules.to_json's text), as one written by hand or by a test for a still.
static func read_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var text := FileAccess.get_file_as_string(file_path)
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	var story: Array = []
	var run_text := text
	if data.has("run"):
		if not data.get("v") is float or int(data.v) != VERSION or not data.run is Dictionary:
			return {}
		run_text = JSON.stringify(data.run, "", true, true)
		var told: Variant = data.get("story", [])
		if not told is Array:
			return {}
		for key: Variant in told:
			if key is String:
				story.append(key)
	var run := Rules.from_json(run_text)
	if run == null:
		return {}
	return {"run": run, "story": story}


## Whether a run is kept that can be played on: a file that does not read counts as none.
static func has() -> bool:
	return not read().is_empty()


## Forgets the kept run.
static func clear() -> void:
	if _driven():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# True when the bench drives the game from the command line, or the run comes from a file
# named there (`--run`): nothing kept on this machine is read or changed.
static func _driven() -> bool:
	for name: String in ["shot", "keys", "quit", "selftest", "run"]:
		if Shot.has_arg(name):
			return true
	return false
