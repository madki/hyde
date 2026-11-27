extends "res://tests/case.gd"
## The run kept on this machine (RunSave): kept and read back the same, kept only at rest, and
## a file that is not a run that can be played on read as no save.

const Flow := preload("res://scripts/scene_flow.gd")

const STORY := ["first_night", "the_door"]


# Runs `body` with RunSave.path pointed at a file of its own, removed afterwards.
func _with_test_file(body: Callable) -> void:
	var kept := RunSave.path
	RunSave.path = "user://test_run_%d.json" % Time.get_ticks_usec()
	body.call()
	for p: String in [RunSave.path, RunSave.path + ".new"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	RunSave.path = kept


func _write(text: String) -> void:
	var file := FileAccess.open(RunSave.path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_run_at_rest_is_kept_and_read_back_the_same() -> void:
	var runs := {
		"play": fresh(),
		"lab": Flow.run_at_dawn("lab", 1),
		"alley": Flow.run_at_dawn("alley", 1),
	}
	_with_test_file(func() -> void:
		for phase: String in runs:
			var run: RulesRun = runs[phase]
			eq(run.phase, phase, "the run made for %s stands there" % phase)
			RunSave.keep(run, STORY)
			ok(RunSave.has(), "a run in %s is kept" % phase)
			var back := RunSave.read()
			ok(not back.is_empty() and same(back.run, run), "a run in %s reads back the same" % phase)
			eq(back.get("story"), STORY, "the story told reads back with the run in %s" % phase)
			ok(not FileAccess.file_exists(RunSave.path + ".new"), "nothing is left beside the save")
	)


func test_a_run_not_at_rest_is_not_kept() -> void:
	_with_test_file(func() -> void:
		for phase: String in ["result", "end"]:
			var run := fresh()
			run.phase = phase
			RunSave.keep(run)
			ok(not FileAccess.file_exists(RunSave.path), "nothing is written in %s" % phase)
		# A run already kept stays as it was.
		var play := fresh()
		RunSave.keep(play)
		var later := fresh()
		later.phase = "result"
		later.score = 99
		RunSave.keep(later)
		ok(same(RunSave.read().run, play), "a run kept is not replaced by one in result")
	)


func test_a_file_that_is_not_a_run_reads_as_no_save() -> void:
	var refused := fresh().to_dict()
	refused.phase = "dancing"
	var good := fresh().to_dict()
	var files := {
		"garbage": "not json {{",
		"other JSON": JSON.stringify({"name": "a list", "items": [1, 2]}),
		"a list": "[1, 2, 3]",
		"version 2": JSON.stringify({"v": 2, "run": good, "story": []}),
		"no version": JSON.stringify({"run": good, "story": []}),
		"a run refused": JSON.stringify({"v": 1, "run": refused, "story": []}),
		"an empty file": "",
	}
	_with_test_file(func() -> void:
		for name: String in files:
			_write(files[name])
			eq(RunSave.read(), {}, "%s reads as no save" % name)
			ok(not RunSave.has(), "%s is not a save" % name)
	)


func test_clear_forgets_the_run() -> void:
	_with_test_file(func() -> void:
		RunSave.keep(fresh())
		ok(RunSave.has(), "a run is kept")
		RunSave.clear()
		ok(not RunSave.has(), "and is forgotten when cleared")
		ok(not FileAccess.file_exists(RunSave.path), "its file is gone")
		RunSave.clear()
		ok(not RunSave.has(), "clearing with no save is no error")
	)


func test_read_file_takes_a_bare_run() -> void:
	var run := Flow.run_at_dawn("lab", 1)
	_with_test_file(func() -> void:
		_write(Rules.to_json(run))
		var back := RunSave.read_file(RunSave.path)
		ok(not back.is_empty() and same(back.run, run), "a bare run reads back the same")
		eq(back.get("story"), [], "with no story told")
		eq(RunSave.read_file("user://test_run_none.json"), {}, "a file that is not there reads as {}")
	)
