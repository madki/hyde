class_name ArenaMomentEnd
## A round's end, from its `round_end` event. A round that is won:
##
## 1. The hand and both piles gather into the deck in the corner.
## 2. The pay: "Round won." in the centre, the round's sovereigns drop into the purse one by
##    one, then each unused play mark turns into a sovereign and follows.
## 3. The line: its tally grows to the centre. It holds, with a line of words, and shrinks
##    back; or his side floods Jekyll's, and the run ends.
## 4. The reward, after an ordinary round won as Jekyll: three cards lie face up in the
##    centre and the player takes one or none. The choice is left in `t.picked`, and the card
##    nodes in `t.offered`: the next round's moment sends the taken card into the deck.
##    Otherwise one line, "He takes no card.", and after a scene nothing.
##
## The next round's heading follows as its own move (ArenaMomentRound).


static func add(t: ArenaTable, e: Dictionary) -> void:
	if e.how != "won":
		# The rescue and the run's end are not shown yet.
		t.unhandled = true
		return
	gather(t)
	_pay(t, e)
	line(t, e)
	if e.over:
		return
	if e.offers_card:
		_reward(t)
	elif not t.after.night.scene and (e.stance == "hyde" or e.broke_out):
		t.add_caption("He takes no card.")


## The hand and both piles gather into the deck in the corner.
static func gather(t: ArenaTable) -> void:
	t.beats.add(func() -> void:
		var cards: Array = []
		for id: int in t.hand.ids():
			var card := t.hand.give(id)
			t.travel.take(card)
			cards.append(card)
		if not cards.is_empty():
			await t.piles.put("draw", cards)
		await t.piles.reshuffle()
		t.shown.set_value("deck_count", t.run.cards.size())
		t.piles.deck_mode = true
		t.shown.set_value("draw_count", 0))


## The line is checked: `e` is the `round_end` event, with the line as it then stands.
static func line(t: ArenaTable, e: Dictionary) -> void:
	t.beats.add(func() -> void:
		var words := "His Roots outnumber yours."
		if not e.over:
			words = "The line holds%s: %d against %d." % [", even" if e.ink == e.paper else "", e.paper, e.ink]
		t.stage.show_caption(words)
		var centre: Vector2 = t.symbols.get_global_transform().affine_inverse() * t.stage.slot(0, 1)
		await t.play(t.symbols.line_check.bind(centre))
		await t.stage.clear_caption())


# The pay, a sovereign at a time.
static func _pay(t: ArenaTable, e: Dictionary) -> void:
	var dials := t.run.dials
	var unused: int = e.plays_left
	var for_round: int = int(e.pay) - unused * dials.unused_play_pay
	t.beats.add_call(func() -> void: t.stage.show_caption("Round won."))
	for i in for_round:
		t.beats.add(func() -> void:
			await ArenaPop.coin(t.beats, t.travel, t.stage.slot(0, 1), t.column.sov_place())
			t.mark("sov", int(t.shown.value("sov", 0)) + 1))
	for i in unused:
		t.beats.add(func() -> void:
			# The tally is only drawn down: the plays left are the engine's to the round's end.
			t.follow(t.column.set_plays(unused - i - 1))
			await ArenaPop.coin(t.beats, t.travel, t.column.plays_place(), t.column.sov_place())
			t.mark("sov", int(t.shown.value("sov", 0)) + dials.unused_play_pay))
	t.beats.add(func() -> void: await t.stage.clear_caption())


# Three cards to choose from, or none.
static func _reward(t: ArenaTable) -> void:
	var keys: Array = t.run.offer
	var nodes: Array = []
	t.beats.add(func() -> void:
		var from := t.stage.slot(0, 1) + Vector2(0.0, -90.0)
		for key: String in keys:
			var factor := RulesConfig.FACTOR.has(key)
			var card := ArenaTravel.make_card({
				"key": key, "ink": false, "name": Rules.key_name(key, false),
				"chips": t.run.dials.factor_chips if factor else int(t.after.symbols[key].paper_chips),
				"text": RulesConfig.factor_text(key, "jekyll", t.run.dials) if factor else "",
			})
			t.travel.place(card, from, 0.0, 0.5)
			card.modulate.a = 0.0
			nodes.append(card)
			t.beats.tween().tween_property(card, "modulate:a", 1.0, ArenaPace.TRAVEL * 0.5)
		t.stage.show_caption("Take a card for the deck, or none.")
		await t.stage.lay(t.travel, nodes))
	t.beats.add_choice(func() -> void:
		t.reward.offer(nodes, t.stage.slot(0, 1) + Vector2(0.0, ArenaCard.SIZE.y * 0.5 + 14.0))
		t.picked = await t.reward.chosen
		t.offered = nodes)
	t.beats.add(func() -> void: await t.stage.clear_caption())
