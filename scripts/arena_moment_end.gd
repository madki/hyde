class_name ArenaMomentEnd
## A round's end, from its `round_end` event: won, rescued (ArenaMomentRescue has shown him
## taking his Roots), or lost. Every round that is covered ends with the line's check, which
## can end the run; so can night 5's scene, and a rescue that falls short. A round that is won:
##
## 1. The hand and both piles gather into the deck, at the bottom left.
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


## `first` is the `joined` event of his first four Roots when a rescue is his first arrival
## (they join the gathered deck), else empty.
static func add(t: ArenaTable, e: Dictionary, first: Dictionary = {}) -> void:
	match e.how:
		"won":
			gather(t)
			_pay(t, e)
		"rescued":
			_rescued(t, e, first)
		_:
			# The pool ran out and the round is still short: the run ends there.
			t.add_caption("He could not cover it.")
			_ending(t, e)
			return
	line(t, e)
	if e.ending != null:
		_ending(t, e)
	elif e.offers_card:
		_reward(t)
	elif e.how == "won" and not t.after.night.scene and (e.stance == "hyde" or e.broke_out):
		t.add_caption("He takes no card.")


## The size of "Round won.", the one caption written larger than the rest.
const WON_SIZE := 27
## The names of the run's three endings.
const ENDINGS := {"hyde": "Mr Hyde", "double": "The Double Life", "myself": "This, Too, Was Myself"}


# The round is covered by him: the target is struck in his ink, he has the table, the track
# is wiped with nothing stored, and on his first arrival his four Roots join the deck.
static func _rescued(t: ArenaTable, e: Dictionary, first: Dictionary) -> void:
	var took := ArenaMomentRescue.summary(t)
	t.beats.add(func() -> void:
		t.beats.sound("target_struck", 0.8)
		t.hand.lift(false)
		t.numbers.clear_readout()
		await t.follow(t.numbers.strike_target()).finished)
	# One notice sums the rescue up: what he took, the score he covered, and no pay.
	t.beats.add_choice(func() -> void:
		var what := ArenaCaptions.rescued_notice(
				took.get("before", []).map(func(c: Dictionary) -> String: return c.name),
				int(took.get("short", 0)),
				int(t.shown.value("line/paper", 0)), int(t.shown.value("line/ink", 0)))
		what.cards = took.get("before", [])
		what.after = took.get("after", [])
		what.tone = "hyde"
		t.freshen()
		await t.moments.notice.show_notice(what))
	if e.was == "jekyll":
		# The shift's sound starts when the notice has left, and the page shifts as it lands.
		var lead := ArenaPace.CAPTION_MIN + ArenaPace.CAPTION_FADE
		ArenaMomentShift.cue_to_hyde(t, lead)
		t.beats.add_wait(lead)
		ArenaMomentShift.page(t, true)
	t.beats.add(func() -> void:
		if int(t.shown.value("restraint/meter", 0)) != 0:
			t.mark("restraint/meter", 0)
			await t.beats.wait(ArenaPace.MARK))
	gather(t)
	if not first.is_empty():
		ArenaMomentShift.joined(t, first)


# The run ends: the table shows how, and hands over to the ending by its name.
static func _ending(t: ArenaTable, e: Dictionary) -> void:
	var ending: String = e.ending
	t.beats.add(func() -> void:
		if ending == "hyde":
			# He has the page for good: the run is lost.
			t.beats.sound("run_lost")
		t.hand.lift(false)
		t.numbers.clear_readout()
		if ending == "hyde":
			# The ink takes the whole page, and the cards sink into it.
			t.ink.is_jekyll = false
			var flood := t.beats.tween().set_parallel()
			flood.tween_property(t.ink, "percent", 100.0, 1.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			for node: Node in t.hand.get_children() + t.travel.get_children():
				if node is ArenaCard:
					flood.tween_property(node, "modulate", Color(Palette.INK_WASH, 0.0), 1.6)
			await flood.finished
		else:
			# The page stills.
			t.beats.sound("run_end")
			await t.beats.wait(ArenaPace.HOLD)
		# The round's cards are the deck's again.
		t.shown.set_value("draw_count", 0)
		t.shown.set_value("discard_count", 0))
	t.beats.add_choice(func() -> void:
		t.freshen()
		if SceneFlow.show_ending(ending):
			return
		# No ending screen yet: the table names the ending and waits.
		t.stage.show_caption("%s.  The run is over: press a key for a new one." % ENDINGS.get(ending, ending))
		t.waiting_press = true
		await t.pressed
		t.waiting_press = false
		await t.stage.clear_caption())


## The hand and both piles gather into the deck, at the bottom left.
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
		t.shown.set_value("deck_count", int(t.shown.value("draw_count", 0)))
		t.piles.deck_mode = true
		t.shown.set_value("draw_count", 0))


## The line is checked: `e` is the `round_end` event, with the line as it then stands.
static func line(t: ArenaTable, e: Dictionary) -> void:
	t.beats.add(func() -> void:
		var words := "His Roots outnumber yours."
		if not e.over:
			words = "The line holds%s: %d against %d." % [", even" if e.ink == e.paper else "", e.paper, e.ink]
		t.stage.show_caption(words)
		t.beats.sound("line_floods" if e.over else "line_holds")
		var centre: Vector2 = t.symbols.get_global_transform().affine_inverse() * t.stage.slot(0, 1)
		await t.play(t.symbols.line_check.bind(centre))
		await t.stage.clear_caption())


# The pay, a sovereign at a time.
static func _pay(t: ArenaTable, e: Dictionary) -> void:
	var dials := t.run.dials
	var unused: int = e.plays_left
	var for_round: int = int(e.pay) - unused * dials.unused_play_pay
	t.beats.add_call(func() -> void:
		t.stage.show_caption("Round won.", WON_SIZE)
		t.beats.sound("round_won"))
	for i in for_round:
		t.beats.add(func() -> void:
			await ArenaPop.coin(t.beats, t.travel, t.stage.slot(0, 1), t.numbers.sov_place())
			t.mark("sov", int(t.shown.value("sov", 0)) + 1))
	for i in unused:
		t.beats.add(func() -> void:
			# The tally is only drawn down: the plays left are the engine's to the round's end.
			t.follow(t.numbers.set_plays(unused - i - 1))
			await ArenaPop.coin(t.beats, t.travel, t.numbers.plays_place(), t.numbers.sov_place())
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
			# Laid larger than its own size: its words are drawn sharp.
			card.sharp = true
			t.travel.place(card, from, 0.0, 0.5)
			card.modulate.a = 0.0
			nodes.append(card)
			t.beats.tween().tween_property(card, "modulate:a", 1.0, ArenaPace.TRAVEL * 0.5)
		t.stage.show_caption("Take a card for the deck, or none.")
		var lays := t.beats.tween()
		for i in nodes.size():
			lays.tween_callback(t.beats.sound.bind("lay", Sfx.vary() * 1.1, 0.7))
			lays.tween_interval(0.09)
		await t.stage.lay(t.travel, nodes, ArenaStage.REWARD_SCALE, ArenaStage.REWARD_GAP))
	t.beats.add_choice(func() -> void:
		t.freshen()
		t.reward.offer(nodes)
		t.picked = await t.reward.chosen
		t.offered = nodes)
	t.beats.add(func() -> void: await t.stage.clear_caption())
