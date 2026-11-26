class_name ArenaMomentRound
## A round begins: the heading in the centre, with the target, and on a night's first round
## the night's title and its scene's twist; the numbers settle in their places; the deck
## shuffles at the bottom left; and the hand is dealt from it, card by card.
##
## `result.events` are those of Rules.start_round (after Rules.new_run they are the run's
## `events`), or of the move that began the round: continue_result, leave_lab, alley_leave.


static func add(t: ArenaTable, result: Dictionary) -> void:
	var taken: Dictionary = {}
	for e: Dictionary in result.events:
		if e.t == "joined" and e.why == "reward":
			taken = e.cards[0]
	_reward_goes(t, taken)
	# What the table shows as the round begins, where a shift before the first play (night
	# 4's window, walking in full) has already changed the engine: Jekyll still has the
	# table, the track holds what he walked in with, and his Roots have not yet joined.
	var before := {}
	for e: Dictionary in result.events:
		if e.t in ["shift", "breakout"]:
			before = {"meter": int(e.ev.stored) + int(e.ev.lost_restraint), "joined": 0}
		elif e.t == "joined" and e.why in ["first", "breakout", "stain"] and not before.is_empty():
			before.joined += e.cards.size()
	for e: Dictionary in result.events:
		match e.t:
			"joined":
				if e.why == "dawn":
					_dawn(t, e)
				elif e.why != "reward":
					ArenaMomentShift.add_event(t, e)
			"brought":
				ArenaMomentShift.add_event(t, e)
			"shift":
				# Night 4's scene: the drink's shift without the flask.
				ArenaMomentShift.cue_to_hyde(t, ArenaPace.CAPTION_MIN + int(e.ev.stored) * ArenaMomentShift.STORE_STEP)
				t.beats.add_call(func() -> void: t.stage.show_caption("The window. He comes unasked."))
				t.beats.add_call(func() -> void: (t.arena.get_node("Twist") as ArenaTwist).pulse())
				t.beats.add_wait(ArenaPace.CAPTION_MIN)
				ArenaMomentShift.store(t, e.ev.stored)
				ArenaMomentShift.page(t, true)
			"breakout":
				ArenaMomentBreakout.add(t, e)
			"shuffle":
				_begin(t, e.ids.size(), before)
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
		t.beats.sound("card_flip", Sfx.vary())
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


# The two Roots of his that the dawn brings join the deck. They are shown here, on the
# table, before the dawn's place opens.
static func _dawn(t: ArenaTable, e: Dictionary) -> void:
	var cards: Array = []
	var names: Array = []
	for c: Dictionary in e.cards:
		cards.append(t.card_data(c.id))
		names.append(cards[-1].name)
	ArenaMomentShift.hyde_joins(t)
	t.moments.join_deck(cards, ArenaCaptions.joins("dawn", names),
			Vector2(t.arena.size.x - 80.0, t.arena.size.y * 0.45), false,
			ArenaMomentShift.joins_notice.bind(t, "dawn", cards.size()))


# Everything up to the deal: `deck` is how many cards the deck holds.
static func _begin(t: ArenaTable, deck: int, before: Dictionary) -> void:
	var table := t.after.duplicate()
	if not before.is_empty():
		table.stance = "jekyll"
		table.restraint = table.restraint.duplicate()
		table.restraint.meter = before.meter
		table.restraint.stored = 0
		table.line = table.line.duplicate()
		table.line.ink = int(table.line.ink) - int(before.joined)
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
		t.shown.snap_to(table, ArenaTable.KEYS)
		t.ink.is_jekyll = table.stance == "jekyll"
		t.hand.is_jekyll = table.stance == "jekyll"
		var blank := table.duplicate()
		for key: String in ["target", "plays", "discards"]:
			blank[key] = 0
			t.shown.set_value(key, 0)
		blank.play = null
		t.numbers.show_table(blank)
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
		await t.heading.play(words, t.numbers.heading_place()))
	# The numbers settle.
	t.add_mark("target", table.target, ArenaNumbers.COUNT_TIME)
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
