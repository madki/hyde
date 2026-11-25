extends "res://tests/case.gd"
## The personas: their numbers by name, and the one policy that plays them.

const NAMES := [
	"jekyll", "dance", "pendulum", "wide", "thin", "edge", "hyde",
	"nodrink", "noturn", "bighand", "hoarder", "spender", "nodiscard",
]


func _line(spec: String, seed_value: int) -> Dictionary:
	var line := SimGame.play_run(SimPlayer.make(spec), seed_value)
	line.erase("ms")
	return line


func test_numbers_by_name() -> void:
	eq(SimPersonas.names(), NAMES, "the personas, in order")
	for name: String in NAMES:
		var numbers := SimPersonas.numbers(name)
		eq(numbers.keys(), SimPersonas.DEFAULTS.keys(), "%s has every number" % name)
		for key: String in numbers:
			eq(typeof(numbers[key]), typeof(SimPersonas.DEFAULTS[key]), "%s.%s is of its default's kind" % [name, key])
		for key: String in ["inst_pref", "alley_inst"]:
			for inst: String in numbers[key]:
				ok(RulesConfig.INSTRUMENTS.has(inst), "%s.%s names an instrument of the rules: %s" % [name, key, inst])
	eq(SimPersonas.numbers(""), SimPersonas.DEFAULTS, "no name: the default numbers")
	eq(SimPersonas.numbers("nobody", "user://no_such_file.json"), {}, "an unknown name: nothing")
	# A habit is the dance with one thing changed.
	var dance := SimPersonas.numbers("dance")
	var noturn := SimPersonas.numbers("noturn")
	eq(noturn.no_turn, true, "noturn never turns")
	noturn.no_turn = false
	eq(noturn, dance, "and is the dance in all else")


func test_changes() -> void:
	var numbers := SimPersonas.numbers("dance")
	var unknown := SimPersonas.change(numbers, {
		"drink_at": 2.0, "w_turn": 1, "strike_ink": "false", "inst_pref": "spirit+balance", "buys": "salt", "nothing": 3,
	})
	eq(unknown, ["nothing"], "a key that is no number is named")
	eq([numbers.drink_at, numbers.w_turn, numbers.strike_ink, numbers.inst_pref, numbers.buys],
			[2, 1.0, false, ["spirit", "balance"], "salt"], "each change is of its default's kind")
	var player := SimPlayer.make("persona.jekyll?drink_at=2&samples=1")
	eq([player.p.drink_at, player.p.samples, player.p.hyde_stay], [2, 1, 1], "a player's name changes its numbers")


func test_found_file() -> void:
	var path := "user://test_personas_found.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"found": {"drink_at": 2, "w_habit": 0.5}, "after": {"based_on": "hyde", "samples": 3}, "dance": {"drink_at": 1}}))
	f.close()
	var found := SimPersonas.numbers("found", path)
	eq([found.drink_at, found.w_habit, found.hyde_stay], [2, 0.5, 99], "a persona of the file, over the defaults")
	var after := SimPersonas.numbers("after", path)
	eq([after.drink_asap, after.samples], [true, 3], "or over a persona it names")
	eq(SimPersonas.numbers("dance", path).drink_at, 4, "a name of the script is the script's")
	eq(SimPersonas.numbers("other", path), {}, "a name the file lacks: nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_every_persona_plays_a_run() -> void:
	for name: String in NAMES:
		var line := _line("persona." + name, 3)
		ok(line.by != "guard" and line.by != "illegal" and line.ending != "", "%s: the run ends by the rules" % name)
		ok(not line.rounds.is_empty(), "%s: with its rounds" % name)


func test_one_seed_one_run() -> void:
	var a := _line("persona.dance", 11)
	eq(_line("persona.dance", 11), a, "one seed gives the same run twice")
	ok(JSON.stringify(a) != JSON.stringify(_line("persona.dance", 12)), "and another seed another run")


func test_choose_leaves_the_run_and_gives_options() -> void:
	var player := SimPlayer.make("persona.edge")
	var run := fresh({}, 4)
	player.begin(run, 4)
	var seen := 0
	for step in 400:
		if run.phase == "end":
			break
		if run.phase != "play":
			player.between(run)
			continue
		# The quick reading of the best play's worth is the full one's.
		var worths: Array[float] = player._worths(run, player._plays(run))
		var most := 0.0
		for w in worths:
			most = maxf(most, w)
		eq(player._best_worth(run), most, "the best worth, read from the plays that can be best")
		var before := Rules.to_json(run)
		var move := player.choose(run)
		eq(Rules.to_json(run), before, "choose does not change the run")
		var options: Array = move.options
		if move.t == "play":
			seen += 1
			eq([options[0].t, options[0].ids], ["play", move.ids], "the play made is the first option")
			for i in range(1, options.size()):
				ok(options[i].value <= options[i - 1].value, "the options are best first")
		elif move.t == "discard":
			eq([options[0].t, options[0].ids], ["discard", move.ids], "a discard is the first option")
		ok(SimMoves.apply(run, move).ok, "the rules take the move")
	ok(seen > 5, "plays were made")


func test_habits() -> void:
	for s in 2:
		eq(_line("persona.noturn", s).stats.turns, 0, "noturn turns nothing")
		var hoarder := _line("persona.hoarder", s)
		eq(hoarder.stats.struck, 0, "hoarder strikes nothing")
		for inst: String in hoarder.inst:
			ok(RulesConfig.HIS_INSTRUMENTS.has(inst), "hoarder buys no instrument")
	# With a play in hand, nodiscard keeps its cards; bighand makes the highest score.
	var nodiscard := SimPlayer.make("persona.nodiscard")
	var bighand := SimPlayer.make("persona.bighand?no_discard=true")
	var run := fresh({}, 6)
	nodiscard.begin(run, 6)
	bighand.begin(run, 6)
	for step in 12:
		if run.phase != "play":
			break
		var move := nodiscard.choose(run)
		var top := RulesHands.best_read(run)
		ok(move.t != "discard" or top.is_empty(), "nodiscard discards only with nothing to play")
		var big := bighand.choose(run)
		if big.t == "play":
			var cards: Array = []
			for id: int in big.ids:
				cards.append(run.card_of(id))
			eq(RulesHands.read(run, cards).score, top.ev.score, "bighand plays the highest score")
		SimMoves.apply(run, move)
