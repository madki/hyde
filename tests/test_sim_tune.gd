extends "res://tests/case.gd"
## The search of a persona's numbers: how a candidate is named, moved and judged.

const Tune := preload("res://sim/tune.gd")


func test_a_candidate_is_named_by_what_differs() -> void:
	var base := SimPersonas.numbers("dance")
	eq(Tune.player_of("dance", base, base), "persona.dance", "the start is itself")
	var numbers: Dictionary = base.duplicate(true)
	numbers.w_turn = 0.2
	numbers.hyde_stay = 2
	numbers.strike_ink = false
	numbers.inst_pref = ["spirit", "balance"]
	numbers.alley_inst = []
	var player := Tune.player_of("dance", base, numbers)
	eq(player, "persona.dance?alley_inst=&hyde_stay=2&inst_pref=spirit+balance&strike_ink=false&w_turn=0.2", "the changed numbers, in order of name")
	# The name gives the numbers back.
	var parts := SimPlayer.parse(player)
	var read := SimPersonas.numbers(parts.variant)
	eq(SimPersonas.change(read, parts.params), [], "every part of the name is a number of a persona")
	eq(read, numbers, "the player of that name plays those numbers")
	# So does the persona as the file of found ones holds it.
	var entry := Tune.entry_of("dance", base, numbers)
	eq(entry.keys(), ["based_on", "alley_inst", "hyde_stay", "inst_pref", "strike_ink", "w_turn"], "an entry: the start and what differs")
	var again := SimPersonas.numbers(str(entry.based_on))
	SimPersonas.change(again, entry)
	eq(again, numbers, "an entry gives the numbers back")
	eq(Tune.changed_text(base, numbers), "alley_inst hcane+cheque -> (none), hyde_stay 3 -> 2, inst_pref saucers+balance+spirit -> spirit+balance, strike_ink true -> false, w_turn 0.15 -> 0.2", "what changed, for a reader")


func test_moves() -> void:
	var how := Tune.moves()
	for key: String in ["samples", "no_turn", "no_discard", "buys"]:
		ok(not how.has(key), "%s is not moved" % key)
	eq(how.size(), SimPersonas.DEFAULTS.size() - 4, "every other number is")
	for name: String in ["jekyll", "dance", "pendulum", "wide", "thin", "edge", "hyde"]:
		var base := SimPersonas.numbers(name)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var twin := RandomNumberGenerator.new()
		twin.seed = 3
		for i in 40:
			var numbers := Tune.mutate(base, rng)
			var changed := Tune.differing(base, numbers)
			ok(changed.size() >= 1 and changed.size() <= 3, "%s: one to three numbers change" % name)
			eq(Tune.mutate(base, twin), numbers, "%s: one generator, one change" % name)
			for key: String in changed:
				ok(how.has(key), "%s: %s may be moved" % [name, key])
				eq(typeof(numbers[key]), typeof(base[key]), "%s: %s stays of its kind" % [name, key])
				if numbers[key] is float:
					ok(numbers[key] >= how[key].least and numbers[key] <= how[key].most, "%s: %s stays in its bounds" % [name, key])
				elif numbers[key] is int:
					ok((how[key] as Array).has(numbers[key]), "%s: %s is a rung" % [name, key])
				elif numbers[key] is Array:
					for part: Variant in numbers[key]:
						ok((how[key] as Array).has(part) and (numbers[key] as Array).count(part) == 1, "%s: %s holds known names, once each" % [name, key])
			# The name of a candidate gives its numbers back.
			var parts := SimPlayer.parse(Tune.player_of(name, base, numbers))
			var read := SimPersonas.numbers(parts.variant)
			SimPersonas.change(read, parts.params)
			eq(read, numbers, "%s: the candidate's name gives its numbers" % name)
	eq(SimPersonas.numbers("dance"), SimPersonas.numbers("dance"), "the start is as it was")


func test_the_file_of_found_personas_is_kept() -> void:
	var path := "user://test_tune_found.json"
	var whole_path := ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(whole_path)
	ok(Tune.write_found("found-a", {"based_on": "dance", "drink_at": 2}, path), "a persona is written to a new file")
	ok(Tune.write_found("found-b", {"based_on": "edge", "w_turn": 0.5}, path), "and a second beside it")
	eq(SimPersonas.read_found(path).keys(), ["found-a", "found-b"], "both are in the file")
	eq(SimPersonas.numbers("found-a", path).drink_at, 2, "as they were written")
	ok(not FileAccess.file_exists(path + ".tmp"), "nothing is left beside it")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"found-a\": {\"based_on\": ")
	f.close()
	var broken := FileAccess.get_file_as_string(path)
	ok(not Tune.write_found("found-c", {"based_on": "dance"}, path), "a file that cannot be read is not written over")
	eq(FileAccess.get_file_as_string(path), broken, "and is left as it was")
	DirAccess.remove_absolute(whole_path)


func test_gain_and_noise() -> void:
	var g := Tune.gain([3, 5, 4, 6], [2, 4, 4, 4])
	eq(g.mean, 1.0, "the mean of the differences, seed by seed")
	ok(absf(g.se - sqrt(2.0 / 3.0 / 4.0)) < 1e-9, "and its standard error")
	ok(Tune.over(g, 2.0), "a gain of more than two standard errors")
	ok(not Tune.over(g, 3.0), "is not one of three")
	ok(not Tune.over(Tune.gain([1, 2, 3], [1, 2, 3]), 0.0), "no gain is not over the noise")
	ok(not Tune.over(Tune.gain([1, 2, 3], [2, 3, 4]), 2.0), "nor is a loss")
	eq([Tune.total([1, 0, 1]), Tune.mean([1, 2, 3])], [2, 2.0], "totals and means")
