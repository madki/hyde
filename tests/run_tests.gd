extends SceneTree
## Headless test runner, started by tools/test.sh. Runs every `test_*` method of every
## `tests/test_*.gd` (each extends tests/case.gd) and quits with 1 if any check failed.
## A user argument keeps only the tests whose "file:method" name holds that text.


func _initialize() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		filter = a
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var checks := 0
	var fails := 0
	var ran := 0
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("FAIL: %s did not load" % f)
			fails += 1
			continue
		var case: Object = script.new()
		for m in script.get_script_method_list():
			var method: String = m.name
			if not method.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + method).contains(filter):
				continue
			var fails_before: int = case.fails
			var t0 := Time.get_ticks_msec()
			case.call(method)
			ran += 1
			print("%s %s:%s (%d ms)" % ["ok  " if case.fails == fails_before else "FAIL", f, method, Time.get_ticks_msec() - t0])
		checks += case.checks
		fails += case.fails
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	if ran == 0:
		print("TESTS FAILED: no test ran")
		quit(1)
	elif fails > 0:
		print("TESTS FAILED: %d of %d checks, %d tests, %.1f s" % [fails, checks, ran, secs])
		quit(1)
	else:
		print("TESTS PASSED: %d checks, %d tests, %.1f s" % [checks, ran, secs])
		quit(0)
