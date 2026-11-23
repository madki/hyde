class_name ArenaMomentPlay
## A play, performed one step at a time (the engine's `ev.steps`):
##
## 1. The chosen cards leave the hand and are laid in the centre, in the order they score:
##    Roots first, then Factors. A play is taken off the tally.
## 2. The readout names the hand and shows its base, and both numbers pulse.
## 3. Each Root hops and gives its chips; its gauge bonus follows it: Temper's and Habit's
##    mult travel from the symbol's sketch to the mult, a Sublimation's burst rises from the
##    Ink Root.
## 4. Each Factor hops, gives its chips, and then its effect. Vigour and Restlessness make
##    the best Root hop again; Reason and Alibi make each Root they count hop.
## 5. Stored restraint flies into the mult a drop at a time, and The Cane hops.
## 6. Chips and mult become one total, which travels to the round's score; a score that
##    reaches the target strikes it through.
## 7. What the play does to the gauges (ArenaMomentAfter).
## 8. The laid cards go to the discards and the hand refills, the card drawn for Curiosity or
##    Impulse under an eye mark. A play that ends the round is not refilled.
##
## The first ticks of a play are slow and the later ones quicker (ArenaPace.tick).

## The time of a step that moves no number (a lock, an eye), as a share of a tick's.
const QUIET := 0.7


static func add(t: ArenaTable, result: Dictionary) -> void:
	var ev: Dictionary = result.ev
	var steps: Array = ev.steps
	var events: Array = result.events
	var hyde: bool = result.stance == "hyde"
	var colour := ArenaPop.man(hyde)
	var ends := events.any(func(e: Dictionary) -> bool: return e.t == "round_end")
	# The cards in the order they score.
	var order: Array = []
	for step: Dictionary in steps:
		if step.kind in ["root", "factor"] and not order.has(step.id):
			order.append(step.id)
	var laid := {}
	var eyes: Array = []
	_lay(t, order, laid)
	_score(t, steps, laid, eyes, colour)
	var score_to := 0
	# The symbols whose gauges the play changes: their cards' chips are counted anew.
	var changed: Array = []
	for e: Dictionary in events:
		match e.t:
			"scored":
				score_to = e.to
				_total(t, score_to)
				for step: Dictionary in steps:
					if step.kind == "effect" and step.label in ["no restraint", "no Craving"]:
						ArenaMomentAfter.unlock(t, step.label == "no restraint")
			"stored_spent":
				pass # performed with the score, a drop at a time
			"restraint", "craving", "breed", "turn", "cheque":
				ArenaMomentAfter.add_event(t, e, order)
				if e.has("sym") and not changed.has(e.sym):
					changed.append(e.sym)
			"discarded":
				for sym: String in changed:
					ArenaMomentAfter.recount(t, sym)
				_leave(t, order, laid)
			"drawn", "reshuffle":
				# A play that ends the round is not refilled: the cards go back to the deck.
				if ends:
					continue
				if e.t == "drawn" and e.why == "draws":
					_draw_with_eyes(t, e.ids, eyes)
				else:
					ArenaMomentCards.add_event(t, e)
			"breakout":
				ArenaMomentBreakout.add(t, e)
			"joined", "brought":
				ArenaMomentShift.add_event(t, e)
			"round_end":
				ArenaMomentEnd.add(t, e)
			_:
				t.unhandled = true
	t.beats.add_call(func() -> void:
		for mark: ArenaPop in eyes:
			if is_instance_valid(mark):
				mark.fade(t.beats))


# Beat 1: the cards are laid in the centre and a play is taken off the tally.
static func _lay(t: ArenaTable, order: Array, laid: Dictionary) -> void:
	t.beats.add(func() -> void:
		t.mark("plays", t.shown.value("plays", 1) - 1)
		var cards: Array = []
		for id: int in order:
			var card := t.hand.give(id)
			if card == null:
				continue
			card.set_meta("data", t.card_data(id))
			t.travel.take(card)
			laid[id] = card
			cards.append(card)
		if not cards.is_empty():
			await t.stage.lay(t.travel, cards))


# Beats 2 to 5: the hand is named, then each step of the score.
static func _score(t: ArenaTable, steps: Array, laid: Dictionary, eyes: Array, colour: Color) -> void:
	var base: Dictionary = steps[0]
	var note := "(hunted)" if str(base.label).ends_with(", hunted") else ""
	var hand_name := str(base.label).trim_suffix(", hunted")
	t.beats.add(func() -> void:
		await t.follow(t.column.name_hand(hand_name, base.chips, base.mult, note)).finished
		if Shot.has_arg("trace"):
			print("  %s %s  %d x %d" % [hand_name, note, base.chips, base.mult]))
	var tick := 0
	for i in range(1, steps.size()):
		var step: Dictionary = steps[i]
		var n := tick
		if step.chips != 0 or step.mult != 0:
			tick += 1
		t.beats.add(func() -> void: await _step(t, step, n, laid, eyes, colour))


# One step: the card that acts hops, what it gives rises from it, and the readout ticks.
static func _step(t: ArenaTable, step: Dictionary, n: int, laid: Dictionary, eyes: Array, colour: Color) -> void:
	var card: ArenaCard = laid.get(step.id)
	var at := _above(card) if card else Vector2.ZERO
	var words := ""
	if step.chips != 0:
		words = "+%d" % step.chips
	elif step.mult != 0:
		words = "+%d mult" % step.mult
	match step.kind:
		"root", "factor":
			ArenaPop.hop(t.beats, card)
		"gauge":
			if step.gauge in ["temper", "habit"]:
				# The gauge pays from its sketch: its tallies flash and the mult travels.
				t.play(t.symbols.flash.bind(step.sym))
				ArenaPop.fly_text(t.beats, t.travel, t.symbols.sketch_place(step.sym), t.column.mult_place(),
						words, colour, ArenaPace.tick(n))
				words = ""
			else:
				words = "%s %s" % [str(step.label).capitalize(), words]
		"again":
			var again: ArenaCard = laid.get(step.of)
			ArenaPop.hop(t.beats, card)
			ArenaPop.hop(t.beats, again)
			if again:
				at = _above(again)
		"effect":
			if step.of >= 0:
				ArenaPop.hop(t.beats, laid.get(step.of))
			if step.chips == 0 and step.mult == 0:
				words = step.label
				if step.label == "no restraint":
					t.follow(t.column.restraint.set_lock(true))
				elif step.label == "no Craving":
					t.play(t.symbols.set_lock.bind(true))
				if str(step.label).begins_with("draws") and card:
					var mark := ArenaPop.eye(t.travel, ArenaTravel.centre_of(card))
					eyes.append(mark)
					mark.fly_to(t.beats, t.piles.draw_pile.top_centre() + Vector2(-34.0, -40.0))
		"stored":
			t.shown.set_value("restraint/stored", maxi(0, int(t.shown.value("restraint/stored", 0)) - 1))
			await t.follow(t.column.fly_drop(step.mult)).finished
			return
		"instrument":
			t.play(t.means.hop.bind("hcane"))
			at = t.means.get_global_transform() * Vector2(ArenaMeans.SIZE.x * 0.5, 40.0)
	if words != "" and at != Vector2.ZERO:
		ArenaPop.text(t.beats, t.travel, at, words, colour, 20 if step.chips != 0 or step.mult != 0 else 15)
	if step.chips != 0:
		await t.follow(t.column.tick_chips(step.chips)).finished
	elif step.mult != 0:
		await t.follow(t.column.tick_mult(step.mult)).finished
	else:
		await t.beats.wait(ArenaPace.tick(n) * QUIET)
	if Shot.has_arg("trace"):
		print("  %-9s %-18s %d x %d" % [step.kind, step.label, roundi(t.column.get("_chips")), roundi(t.column.get("_mult"))])


# Beats 6 and 7: the total lands, travels to the round's score, and may strike the target.
static func _total(t: ArenaTable, score_to: int) -> void:
	t.beats.add(func() -> void:
		await t.follow(t.column.land_total()).finished
		if Shot.has_arg("trace"):
			print("  total     %d, the round's score to %d" % [t.column.get("_total"), score_to]))
	t.beats.add(func() -> void:
		t.shown.set_value("score", score_to)
		await t.follow(t.column.send_total(score_to)).finished)
	if score_to >= int(t.after.target):
		t.beats.add(func() -> void: await t.follow(t.column.strike_target()).finished)


# The laid cards go to the discards.
static func _leave(t: ArenaTable, order: Array, laid: Dictionary) -> void:
	t.beats.add(func() -> void:
		var cards: Array = []
		for id: int in order:
			if laid.has(id):
				cards.append(laid[id])
		if not cards.is_empty():
			await t.piles.put("discards", cards))


# The cards drawn for Curiosity or Impulse: each comes to the hand under an eye mark.
static func _draw_with_eyes(t: ArenaTable, ids: Array, eyes: Array) -> void:
	for id: int in ids:
		t.beats.add(func() -> void:
			var mark: ArenaPop = eyes.pop_front() if not eyes.is_empty() else null
			var card := t.piles.take("draw", t.card_data(id))
			var to: Dictionary = t.hand.take_in(card, t.entry(id), t.hyde())
			if mark:
				mark.fly_to(t.beats, to.centre + Vector2(0.0, -ArenaCard.SIZE.y * 0.5 - 6.0), ArenaPace.TRAVEL)
			await t.travel.fly(card, to.centre, to.turn, 1.0, ArenaTravel.UP)
			t.hand.settle(card)
			await t.beats.wait(ArenaPace.MARK)
			if mark:
				mark.fade(t.beats))


# The point just above a card's middle, on the page: where what it gives rises from.
static func _above(card: ArenaCard) -> Vector2:
	return ArenaTravel.centre_of(card) + Vector2(0.0, -ArenaCard.SIZE.y * 0.5 + 6.0)
