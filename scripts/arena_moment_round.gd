class_name ArenaMomentRound
## A round begins: the heading in the centre, with the target, and on a night's first round
## the night's title and its scene's twist; the numbers settle in the left column; the deck
## shuffles in its corner; and the hand is dealt from the draw pile, card by card.
##
## `result.events` are those of Rules.start_round (after Rules.new_run they are the run's
## `events`), or of the move that began the round: continue_result, leave_lab, alley_leave.


static func add(t: ArenaTable, result: Dictionary) -> void:
	for e: Dictionary in result.events:
		match e.t:
			"shuffle":
				_begin(t, e.ids.size())
			_:
				if not ArenaMomentCards.add_event(t, e):
					t.unhandled = true


# Everything up to the deal: `deck` is how many cards the deck holds.
static func _begin(t: ArenaTable, deck: int) -> void:
	var table := t.after
	var night: Dictionary = table.night
	# The table is cleared for the round: an empty hand, the whole deck in the draw pile, and
	# the round's numbers at nothing. What happened between rounds was shown on other pages,
	# so the rest is taken from the engine as it stands.
	t.beats.add_call(func() -> void:
		t.hand.clear()
		for card in t.piles.discard_pile.take_all():
			card.queue_free()
		t.snap_shown()
		var blank := table.duplicate()
		for key: String in ["score", "target", "plays", "discards"]:
			blank[key] = 0
			t.shown.set_value(key, 0)
		blank.play = null
		t.column.show_table(blank)
		t.shown.set_value("draw_count", deck)
		t.shown.set_value("discard_count", 0))
	var words := {
		"head": "Night %d — %s" % [night.no, "The Scene" if night.scene else "Round %d" % night.round],
		"target": "Target %s" % thousands(table.target),
	}
	if night.scene:
		words.twist = "Scene: %s" % night.twist_text
		words.large = true
	elif night.round == 1:
		words.title = night.title
		words.twist = "Its scene: %s" % night.twist_text
	t.beats.add(func() -> void:
		await t.heading.play(words, t.column.get_global_transform() * Vector2(70.0, 24.0)))
	# The numbers settle.
	t.add_mark("target", table.target, ArenaColumn.COUNT_TIME)
	t.add_mark("plays", table.plays)
	t.add_mark("discards", table.discards)
	# The deck shuffles.
	t.beats.add(func() -> void: await t.piles.draw_pile.riffle(t.beats, true))


## A whole number with its thousands parted: 1,500.
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
