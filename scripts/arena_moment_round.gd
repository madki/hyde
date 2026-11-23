class_name ArenaMomentRound
## A round begins: the heading in the centre, with the target, and on a night's first round
## the night's title and its scene's twist; the numbers settle in the left column; the deck
## shuffles in its corner; and the hand is dealt from the draw pile, card by card.
##
## `result.events` are those of Rules.start_round (after Rules.new_run they are the run's
## `events`), or of the move that began the round: continue_result, leave_lab, alley_leave.


static func add(t: ArenaTable, result: Dictionary) -> void:
	var taken: Dictionary = {}
	for e: Dictionary in result.events:
		if e.t == "joined" and e.why == "reward":
			taken = e.cards[0]
	_reward_goes(t, taken)
	for e: Dictionary in result.events:
		match e.t:
			"joined":
				if e.why == "dawn":
					_dawn(t, e)
				elif e.why != "reward":
					t.unhandled = true
			"shuffle":
				_begin(t, e.ids.size())
			_:
				if not ArenaMomentCards.add_event(t, e):
					t.unhandled = true


# The reward that was offered after the last round: the card taken (`taken` is its entry in
# the `joined` event, empty for none) turns face down and goes onto the deck, whose count
# rises; the others turn over and go.
static func _reward_goes(t: ArenaTable, taken: Dictionary) -> void:
	if t.offered.is_empty():
		return
	var nodes := t.offered
	var index: int = t.picked if t.picked != null else -1
	t.offered = []
	t.picked = null
	var words := ""
	if not taken.is_empty() and index >= 0:
		words = ArenaCaptions.joins("reward", [t.card_data(taken.id).name])
	t.beats.add(func() -> void:
		if words != "":
			t.stage.show_caption(words)
		var last: Signal
		for i in nodes.size():
			last = t.travel.turn_over(nodes[i], false)
			if i != index or words == "":
				t.beats.tween().tween_property(nodes[i], "modulate:a", 0.0, ArenaPace.TRAVEL)
		await last
		for i in nodes.size():
			if i != index or words == "":
				nodes[i].queue_free()
		if words != "":
			await t.piles.put("draw", [nodes[index]])
			await t.stage.clear_caption())


# The two Roots of his that the dawn brings join the deck. Until the dawn has pages of its
# own they are shown here, on the table, before the next night's first round.
static func _dawn(t: ArenaTable, e: Dictionary) -> void:
	var cards: Array = []
	var names: Array = []
	for c: Dictionary in e.cards:
		cards.append(t.card_data(c.id))
		names.append(cards[-1].name)
	t.moments.join_deck(cards, ArenaCaptions.joins("dawn", names),
			Vector2(t.arena.size.x - 80.0, t.arena.size.y * 0.45), false)


# Everything up to the deal: `deck` is how many cards the deck holds.
static func _begin(t: ArenaTable, deck: int) -> void:
	var table := t.after
	var night: Dictionary = table.night
	# The table is cleared for the round: an empty hand, the whole deck in the draw pile, and
	# the round's numbers at nothing. What happened between rounds was shown on other pages,
	# so the rest is taken from the engine as it stands.
	t.beats.add_call(func() -> void:
		t.hand.clear()
		t.piles.deck_mode = false
		t.symbols.show_table(table)
		t.means.show_table(table, t.run.dials)
		for card in t.piles.discard_pile.take_all():
			card.queue_free()
		t.snap_shown()
		var blank := table.duplicate()
		for key: String in ["target", "plays", "discards"]:
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
