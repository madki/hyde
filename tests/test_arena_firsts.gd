extends "res://tests/case.gd"
## The first night's notes (ArenaFirsts): which are owed, which one is shown, that each is
## shown once and kept, and how often a first round stops.

const KEYS := ["goal", "score", "restraint", "draught", "hyde", "craving", "stored", "salt", "won", "dawn", "line"]


func _keys(notes: Array) -> Array:
	return notes.map(func(n: Dictionary) -> String: return n.key)


# A run with the game's own numbers, and the table and events of its first deal.
func _first_deal(seed_value: int = 5) -> RulesRun:
	return Rules.new_run({}, seed_value)


# Keeps the notes in a file of this test's own while `body` runs, and removes it after.
func _with_own_file(body: Callable) -> void:
	var kept := ArenaFirsts.path
	ArenaFirsts.path = "user://test_firsts_%d.cfg" % Time.get_ticks_usec()
	ArenaFirsts.forget_loaded()
	body.call()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ArenaFirsts.path))
	ArenaFirsts.path = kept
	ArenaFirsts.forget_loaded()


func test_the_table_of_notes_is_well_formed() -> void:
	var zones := ArenaLayout.zones(Vector2(1152.0, 648.0))
	var run := _first_deal()
	var table := RulesView.table(run)
	var keys := {}
	for note: Dictionary in ArenaFirsts.NOTES:
		keys[note.key] = true
		ok(zones.has(note.rings), "%s rings a zone of the page" % note.key)
		ok(note.lines.size() <= 2, "%s has two lines at most" % note.key)
		var what := ArenaFirsts.sheet(note, table, run.dials, Vector2(1152.0, 648.0))
		eq(what.tone, "plain", "%s is a plain notice" % note.key)
		ok(what.at == zones[note.rings], "%s is rung where its zone lies" % note.key)
		for text: String in [what.title] + what.lines:
			ok(not text.strip_edges().is_empty(), "%s: no empty line" % note.key)
			ok(not "{" in text and not "}" in text, "%s: every name in braces is filled in: %s" % [note.key, text])
			ok(text.length() <= 150, "%s: a line of %d letters is too long" % [note.key, text.length()])
	eq(keys.keys(), KEYS, "the notes, in their order")


func test_the_numbers_in_the_words_are_the_runs() -> void:
	var run := Rules.new_run({"plays": 6, "restraint_limit": 7, "restraint_pay": 3}, 5)
	var table := RulesView.table(run)
	var by_key := {}
	for note: Dictionary in ArenaFirsts.NOTES:
		by_key[note.key] = ArenaFirsts.sheet(note, table, run.dials, Vector2(1152.0, 648.0))
	ok("your 6 plays" in by_key.goal.lines[1], "the goal's note counts the run's plays")
	ok(ArenaMomentRound.thousands(int(table.target)) in by_key.goal.lines[1], "and names the round's target")
	ok("Fill all 7" in by_key.restraint.lines[1], "restraint's note has the run's limit")
	ok("3 mult a drop" in by_key.stored.lines[1], "the stored restraint's note has its pay")


func test_what_is_owed_at_the_first_deal_and_the_first_plays() -> void:
	var run := _first_deal()
	eq(_keys(ArenaFirsts.due(RulesView.table(run), run.events)), ["goal", "draught"], "the first deal: the goal, and the draught that can be drunk")
	var best: Dictionary = Rules.best(run)
	var played: Dictionary = Rules.play(run, best.ids)
	eq(_keys(ArenaFirsts.due(RulesView.table(run), played.events)), ["goal", "score", "restraint", "draught"], "the first play: its score and a step of restraint")
	var thrown: Dictionary = Rules.discard(run, [run.hand[0]])
	eq(_keys(ArenaFirsts.due(RulesView.table(run), thrown.events)), ["goal", "restraint", "draught"], "a discard scores nothing")


func test_what_is_owed_when_hyde_has_the_table() -> void:
	var run := _first_deal()
	run.restraint = 2
	var drunk: Dictionary = Rules.drink(run)
	ok(drunk.ok, "the draught is drunk")
	var owed := _keys(ArenaFirsts.due(RulesView.table(run), drunk.events))
	eq(owed, ["goal", "hyde", "stored", "salt"], "after a drink: Hyde's table, the restraint stored, and the salt that brings Jekyll back")
	ok(ArenaFirsts.stops(drunk.events), "his arrival has stopped the table already")
	var h := deal(run, "I:lamp I:lamp P:heart P:mirror F:cup F:eye P:lamp P:heart")
	var his: Dictionary = Rules.play(run, [h[0].id, h[1].id])
	eq(run.phase, "play", "his first hand does not end the round")
	owed = _keys(ArenaFirsts.due(RulesView.table(run), his.events))
	ok("craving" in owed and not "stored" in owed, "his first hand: Craving, and the store is spent")
	var salted: Dictionary = Rules.take_salt(run)
	ok(salted.ok, "salt is taken")
	owed = _keys(ArenaFirsts.due(RulesView.table(run), salted.events))
	ok(not "hyde" in owed and not "salt" in owed and "craving" in owed, "after salt: Jekyll's table, the Craving still there")


func test_what_is_owed_at_a_rounds_end_and_at_dawn() -> void:
	var run := _first_deal()
	run.score = Rules.target(run) - 1
	var won: Dictionary = Rules.play(run, Rules.best(run).ids)
	eq(run.phase, "result", "the round is won")
	eq(_keys(ArenaFirsts.due(RulesView.table(run), won.events)), ["won"], "a round won: the pay, and nothing else")
	var next: Dictionary = Rules.continue_result(run, null)
	ok(not "won" in _keys(ArenaFirsts.due(RulesView.table(run), next.events)), "the next deal owes no pay")
	# The scene, won as Jekyll and as Hyde: the dawn's note by its place.
	for stance: String in ["jekyll", "hyde"]:
		var night := at(Rules.new_run({}, 5), 0, 2)
		if stance == "hyde":
			as_hyde(night)
			first_arrival(night)
		win_scene(night)
		var dawn: Dictionary = Rules.continue_result(night, null)
		var where := "lab" if stance == "jekyll" else "alley"
		eq(night.phase, where, "dawn as %s" % stance)
		var owed := ArenaFirsts.due(RulesView.table(night), dawn.events)
		eq(_keys(owed), ["dawn"], "at dawn: the dawn's note alone")
		eq(owed[0].when, where, "worded for its place")
	# A round rescued pays nothing: no note of the pay.
	var table := RulesView.table(run)
	table.phase = "result"
	eq(_keys(ArenaFirsts.due(table, [{"t": "round_end", "how": "rescued"}])), [], "a rescued round owes no note of the pay")


func test_the_line_is_owed_when_ink_is_near() -> void:
	var run := _first_deal()
	var table := RulesView.table(run)
	ok(not "line" in _keys(ArenaFirsts.due(table, [])), "no Ink Root: the line is not near")
	table.line = {"ink": 4, "paper": 8, "total": 16, "cushion": 4, "over": false}
	ok(not "line" in _keys(ArenaFirsts.due(table, [])), "Ink 4 behind: not near")
	table.line = {"ink": 6, "paper": 8, "total": 18, "cushion": 2, "over": false}
	ok("line" in _keys(ArenaFirsts.due(table, [])), "Ink within 2: near")
	table.line = {"ink": 9, "paper": 8, "total": 21, "cushion": -1, "over": true}
	ok("line" in _keys(ArenaFirsts.due(table, [])), "Ink ahead: near")


func test_one_note_is_picked_by_the_pacing() -> void:
	var run := _first_deal()
	var table := RulesView.table(run)
	eq(ArenaFirsts.pick(table, run.events, {}, 0).key, "goal", "the first owed is shown")
	eq(ArenaFirsts.pick(table, run.events, {"goal": true}, 1).key, "draught", "then the next not yet shown")
	eq(ArenaFirsts.pick(table, run.events, {"goal": true, "draught": true}, 2), {}, "none when all owed are shown")
	eq(ArenaFirsts.pick(table, run.events, {"goal": true}, ArenaFirsts.MOST_A_ROUND), {}, "none past the round's count")
	var joined := [{"t": "joined", "why": "first", "cards": []}]
	eq(ArenaFirsts.pick(table, joined, {"goal": true}, 1), {}, "none in a move that stopped on a notice of its own")
	ok(not ArenaFirsts.stops([{"t": "joined", "why": "reward", "cards": []}]), "a reward taken stops on no notice")
	for type: String in ["breed", "stained", "converted", "turn"]:
		ok(ArenaFirsts.stops([{"t": type}]), "%s stops on a notice" % type)
	# An urgent note comes first, past the count and after another notice.
	table.stance = "hyde"
	eq(ArenaFirsts.pick(table, joined, {}, ArenaFirsts.MOST_A_ROUND).key, "hyde", "Hyde's table is said at once")
	table.line = {"ink": 6, "paper": 8, "total": 18, "cushion": 2, "over": false}
	eq(ArenaFirsts.pick(table, joined, {"hyde": true}, ArenaFirsts.MOST_A_ROUND).key, "line", "and so is the line")
	# The round's end stands apart from the count.
	table.phase = "result"
	eq(ArenaFirsts.pick(table, [{"t": "round_end", "how": "won"}], {}, ArenaFirsts.MOST_A_ROUND).key, "won", "the pay is said at the round's end whatever was shown in it")


func test_a_note_is_shown_once_kept_and_can_be_cleared() -> void:
	_with_own_file(func() -> void:
		var run := _first_deal()
		var table := RulesView.table(run)
		eq(ArenaFirsts.seen(), {}, "nothing shown to a new player")
		eq(ArenaFirsts.take(table, run.events).key, "goal", "the goal is shown")
		eq(ArenaFirsts.take(table, []).key, "draught", "then not again: the next")
		ok(FileAccess.file_exists(ArenaFirsts.path), "what was shown is written down")
		# Another day: what is kept is read again.
		ArenaFirsts.forget_loaded()
		eq(ArenaFirsts.seen(), {"goal": true, "draught": true}, "and read again by a later run")
		eq(ArenaFirsts.take(table, run.events), {}, "so neither is shown twice")
		ArenaFirsts.clear()
		ArenaFirsts.forget_loaded()
		eq(ArenaFirsts.seen(), {}, "cleared: nothing is kept")
		eq(ArenaFirsts.take(table, run.events).key, "goal", "and the goal is shown again"))


func test_a_note_dismissed_unread_is_owed_again() -> void:
	_with_own_file(func() -> void:
		var run := _first_deal()
		var table := RulesView.table(run)
		eq(ArenaFirsts.offer(table, run.events).key, "goal", "the goal is offered")
		eq(ArenaFirsts.seen(), {}, "offered is not yet shown")
		ArenaFirsts.dismissed("goal", 0.0)
		ArenaFirsts.dismissed("goal", ArenaFirsts.READ - 0.4)
		eq(ArenaFirsts.seen(), {}, "dismissed before it could be read: not remembered")
		ok(not FileAccess.file_exists(ArenaFirsts.path), "and nothing is written down")
		eq(ArenaFirsts.offer(table, []).key, "draught", "not at the very next move, where another is offered")
		eq(ArenaFirsts.offer(table, []).key, "goal", "so it is offered again at its next occasion")
		ArenaFirsts.dismissed("goal", ArenaFirsts.READ + 0.5)
		eq(ArenaFirsts.seen(), {"goal": true}, "dismissed after it was read: remembered")
		ArenaFirsts.forget_loaded()
		eq(ArenaFirsts.seen(), {"goal": true}, "and kept for a later run")
		eq(ArenaFirsts.offer(table, []).key, "draught", "the next is offered in its place"))


# Plays a new player's first round and returns the key of the note shown at the deal and
# after each play ("" for none). `best`: the best hand each time; else one card at a time for
# three plays, and the round is won by the fourth.
func _first_round(run: RulesRun, best: bool) -> Array:
	var shown: Array = [ArenaFirsts.take(RulesView.table(run), run.events).get("key", "")]
	while run.phase == "play":
		var ids: Array = Rules.best(run).ids
		if not best:
			ids = ids.slice(0, 1)
			if run.plays == 1:
				run.score = Rules.target(run) - 1
		var played: Dictionary = Rules.play(run, ids)
		shown.append(ArenaFirsts.take(RulesView.table(run), played.events).get("key", ""))
	return shown


func test_a_first_round_stops_three_times_and_once_at_its_end() -> void:
	_with_own_file(func() -> void:
		# Played slowly, a card at a time: every play of the four is used.
		var run := _first_deal()
		var shown := _first_round(run, false)
		eq([run.phase, run.stance], ["result", "jekyll"], "the slow round is won as Jekyll")
		eq(shown, ["goal", "score", "restraint", "", "won"], "three stops while it is played, and one at its end for the pay")
		var next: Dictionary = Rules.continue_result(run, null)
		eq(ArenaFirsts.take(RulesView.table(run), next.events).key, "draught", "the draught is said at the second round's deal"))
	_with_own_file(func() -> void:
		# Played well: the round is over sooner, and what was not said waits for the next.
		var run := _first_deal()
		var shown := _first_round(run, true)
		eq(run.phase, "result", "the quick round is won")
		eq(shown.slice(0, 2), ["goal", "score"], "the deal and the first play each stop once")
		eq(shown[-1], "won", "and its end, for the pay")
		ok(shown.size() - shown.count("") <= ArenaFirsts.MOST_A_ROUND + 1, "no more stops than the slow round's")
		print("     a first round played well stops at: %s" % ", ".join(shown)))


func test_a_note_dismissed_unread_twice_is_kept_as_shown() -> void:
	_with_own_file(func() -> void:
		var run := _first_deal()
		var table := RulesView.table(run)
		# A player who clicks every note away in half a second.
		var shown: Array = []
		for move in 6:
			var note := ArenaFirsts.offer(table, run.events if move == 0 else [])
			shown.append(note.get("key", ""))
			if not note.is_empty():
				ArenaFirsts.dismissed(note.key, 0.5)
		eq(shown, ["goal", "draught", "goal", "draught", "", ""], "each is shown twice, never on two moves running, and then no more")
		eq(ArenaFirsts.seen(), {"goal": true, "draught": true}, "the second showing is kept, however soon it was dismissed")
		ArenaFirsts.forget_loaded()
		eq(ArenaFirsts.seen(), {"goal": true, "draught": true}, "and written down"))


func test_an_unread_showing_is_not_counted_in_the_round() -> void:
	_with_own_file(func() -> void:
		var run := _first_deal()
		var table := RulesView.table(run)
		ArenaFirsts.dismissed(ArenaFirsts.offer(table, run.events).key, 0.3)
		eq(ArenaFirsts._in_round, 0, "the goal, dismissed unread, uses up none of the round's three")
		ArenaFirsts.dismissed(ArenaFirsts.offer(table, []).key, 0.3)
		eq(ArenaFirsts._in_round, 0, "nor does the draught")
		eq(ArenaFirsts.offer(table, []).key, "goal", "the goal comes back")
		ArenaFirsts.dismissed("goal", 0.3)
		eq(ArenaFirsts._in_round, 1, "its second showing is one of the three")
		# The first play's own notes are still shown in this round.
		var played: Dictionary = Rules.play(run, Rules.best(run).ids)
		eq(run.phase, "play", "the first play does not end the round")
		var after := RulesView.table(run)
		var next := ArenaFirsts.offer(after, played.events)
		eq(next.key, "score", "the first play's score is said, not the goal again")
		ArenaFirsts.dismissed(next.key, 2.0)
		eq(ArenaFirsts._in_round, 2, "a note that was read is counted"))


func test_an_urgent_note_is_not_shown_on_two_moves_running() -> void:
	_with_own_file(func() -> void:
		var run := _first_deal()
		var table := RulesView.table(run)
		table.stance = "hyde"
		eq(ArenaFirsts.pick(table, [], {}, 0, "hyde").get("key", ""), "goal", "the note of the move before is passed over, urgent or not")
		for key: String in ["goal", "draught", "salt"]:
			ArenaFirsts.mark(key)
		var shown: Array = []
		for move in 5:
			var note := ArenaFirsts.offer(table, [])
			shown.append(note.get("key", ""))
			if not note.is_empty():
				ArenaFirsts.dismissed(note.key, 0.2)
		eq(shown, ["hyde", "", "hyde", "", ""], "Hyde's table, clicked away at once: said once more after a move without it, then no more")
		ok(ArenaFirsts.seen().has("hyde"), "and kept as shown"))
