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


## The pay: how long a sovereign takes to reach the purse, and the most semitones the coins
## of one pay climb, each landing one above the last.
const COIN_TIME := 0.28
const COIN_CLIMB := 9.0
## The size of "Round won.", the one caption written larger than the rest.
const WON_SIZE := 27
## The run's four endings by their names. The rules name three ("myself", "double", "hyde");
## theirs of "hyde" is two, by what ended the run: see `ending_of`.
const ENDINGS := {
	"jekyll": "This, Too, Was Myself",
	"hyde": "The Double Life",
	"succumbed": "Succumbed to Hyde",
	"unmet": "Unmet Desires",
}
## How far the table goes toward the night's colour when the lamps go out: it can still be
## made out.
const LAMPS_OUT := 0.6
## The name of the sheet that darkens the page.
const NIGHT_SHEET := "LampsOut"


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


## Which of the four endings a `round_end` event ends the run on: a key of ENDINGS.
static func ending_of(e: Dictionary) -> String:
	match e.ending:
		"myself":
			return "jekyll"
		"double":
			return "hyde"
	return "succumbed" if e.ended_by == "line" else "unmet"


# The run ends: the table shows how, and hands over to the ending by its name.
static func _ending(t: ArenaTable, e: Dictionary) -> void:
	var ending: String = e.ending
	var id := ending_of(e)
	# The parts of the table the lamps' going out has darkened, each to the colour it had.
	var lit := {}
	t.beats.add(func() -> void:
		t.hand.lift(false)
		t.numbers.clear_readout()
		match id:
			"succumbed":
				# He has the page for good: the ink takes all of it, and the cards sink into it.
				t.beats.sound("run_lost")
				t.ink.is_jekyll = false
				var flood := t.beats.tween().set_parallel()
				flood.tween_property(t.ink, "percent", 100.0, 1.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				for card: ArenaCard in _cards(t):
					flood.tween_property(card, "modulate", Color(Palette.INK_WASH, 0.0), 1.6)
				await flood.finished
			"unmet":
				# The ink stays where it is; the whole table goes dark, as lamps going out: every
				# part of it but the caption's (the stage).
				t.beats.sound("run_lost")
				# The page's shader takes no modulate: the night is a sheet laid over it.
				var night := ColorRect.new()
				night.name = NIGHT_SHEET
				night.color = Color(Palette.NIGHT_1, 0.0)
				night.mouse_filter = Control.MOUSE_FILTER_IGNORE
				night.set_anchors_preset(Control.PRESET_FULL_RECT)
				t.ink.paper.add_child(night)
				var dark := Color.WHITE.lerp(Palette.NIGHT_1, LAMPS_OUT)
				var out := t.beats.tween().set_parallel()
				out.tween_property(night, "color:a", LAMPS_OUT, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				for node: Node in t.arena.get_children():
					var part := node as CanvasItem
					if part == null or part == t.stage or part == t.ink.paper or part is StoryPage:
						continue
					lit[part] = part.modulate
					# Its own alpha is kept: a part that is hidden stays hidden.
					out.tween_property(part, "modulate", Color(dark * part.modulate, part.modulate.a), 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				await out.finished
			"jekyll":
				# The ink draws back off the page, and the page stills.
				t.beats.sound("run_end")
				await t.beats.tween().tween_property(t.ink, "percent", 0.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).finished
				await t.beats.wait(ArenaPace.HOLD)
			_:
				# The ink settles at half the page, and the page stills.
				t.beats.sound("run_end", 0.8)
				await t.beats.tween().tween_property(t.ink, "percent", 50.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).finished
				await t.beats.wait(ArenaPace.HOLD)
		# The round's cards are the deck's again.
		t.shown.set_value("draw_count", 0)
		t.shown.set_value("discard_count", 0))
	t.beats.add_choice(func() -> void:
		t.freshen()
		if SceneFlow.show_ending(ending):
			return
		# No ending screen yet: the table names the ending and waits.
		t.stage.show_caption("%s.  The run is over: press a key for a new one." % ENDINGS[id])
		t.waiting_press = true
		await t.pressed
		t.waiting_press = false
		await t.stage.clear_caption()
		# The next run begins on this table: the lamps come up again.
		var night := t.ink.paper.get_node_or_null(NIGHT_SHEET)
		if night:
			night.free()
		for part: CanvasItem in lit:
			if is_instance_valid(part):
				part.modulate = lit[part])


# The cards on the table: in the hand and on their way.
static func _cards(t: ArenaTable) -> Array[ArenaCard]:
	var cards: Array[ArenaCard] = []
	for node: Node in t.hand.get_children() + t.travel.get_children():
		if node is ArenaCard:
			cards.append(node)
	return cards


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
			await ArenaPop.coin(t.beats, t.travel, t.stage.slot(0, 1), t.numbers.sov_place(), COIN_TIME,
					minf(i, COIN_CLIMB))
			t.mark("sov", int(t.shown.value("sov", 0)) + 1))
	for i in unused:
		t.beats.add(func() -> void:
			# The tally is only drawn down: the plays left are the engine's to the round's end.
			t.follow(t.numbers.set_plays(unused - i - 1))
			await ArenaPop.coin(t.beats, t.travel, t.numbers.plays_place(), t.numbers.sov_place(), COIN_TIME,
					minf(for_round + i, COIN_CLIMB))
			t.mark("sov", int(t.shown.value("sov", 0)) + dials.unused_play_pay))
	t.beats.add(func() -> void: await t.stage.clear_caption())


# Three cards to choose from, or none.
static func _reward(t: ArenaTable) -> void:
	var keys: Array = t.run.offer
	var nodes: Array = []
	# Each card's face, as the hand would show it now: a reward follows a round won as Jekyll.
	var entries: Array = []
	t.beats.add(func() -> void:
		var from := t.stage.slot(0, 1) + Vector2(0.0, -90.0)
		for key: String in keys:
			var entry := RulesView.offer_entry(t.run, key, "jekyll")
			entries.append(entry)
			var card := ArenaTravel.make_card(entry)
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
		# Each card's note, as the hand's, from the faces the cards were made with.
		var symbols: Dictionary = RulesView.table(t.run).symbols
		var notes: Array = entries.map(func(entry: Dictionary) -> String:
			return ArenaCardNote.words(entry, symbols, t.run.dials, "jekyll"))
		t.reward.offer(nodes, notes)
		t.picked = await t.reward.chosen
		t.offered = nodes)
	t.beats.add(func() -> void: await t.stage.clear_caption())
