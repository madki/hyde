class_name ArenaMomentRescue
## The rescue: the round's last play is done and the score is short. From the engine's
## `rescue` and `converted` events:
##
## 1. Short: the gap between the score and the target is written in the centre. A hold.
## 2. He steps in: the cards left in the hand rise. The Paper Roots among them keep their
##    numbered at-risk marks; the rest are printed dark. "He covers the rest." The readout
##    shows the last play's total, which he is about to double.
## 3. For each Root he takes, in order: it changes side where it lies, the last play's total
##    doubles in the readout, the round's score counts to its new value, and the line moves
##    a mark across.
##
## Whether that covered the round is the `round_end` event's to show (ArenaMomentEnd), which
## sums the rescue up on the notice.


## The table's meta holding what the rescue of this move took, for the round end's notice:
## {short, before, after}, the cards as data. Taken off by `summary`.
const SUMMARY := &"rescue_summary"


## What the last rescue took ({short, before, after}), taken off the table; empty with none.
static func summary(t: ArenaTable) -> Dictionary:
	var said: Dictionary = t.get_meta(SUMMARY, {})
	t.remove_meta(SUMMARY)
	return said


## Adds the beats of a `rescue` or `converted` event. False for any other. `state` is kept
## by the caller across the events of one move.
static func add_event(t: ArenaTable, e: Dictionary, state: Dictionary) -> bool:
	match e.t:
		"rescue":
			_steps_in(t, e, state)
		"converted":
			_takes(t, e, state)
		_:
			return false
	return true


static func _steps_in(t: ArenaTable, e: Dictionary, state: Dictionary) -> void:
	state.last = int(e.last)
	state.taken = 0
	var gap: int = int(e.target) - int(e.prior) - int(e.last)
	# What the round end's notice sums up: the gap he covers and the Roots he takes.
	t.set_meta(SUMMARY, {"short": gap, "before": [], "after": []})
	t.beats.add(func() -> void:
		t.stage.show_caption("%s short." % ArenaMomentRound.thousands(gap))
		t.beats.sound("low_note")
		await t.beats.wait(ArenaPace.HOLD)
		await t.stage.clear_caption())
	t.beats.add(func() -> void:
		t.stage.show_caption("He covers the rest.")
		t.beats.sound("rescue")
		t.hand.lift(true)
		for id: int in t.hand.ids():
			var card := t.hand.card_of(id)
			card.dimmed = card.ink or not RulesConfig.ROOT.has(card.key)
		t.numbers.is_jekyll = false
		await t.follow(t.numbers.name_hand("The last play", state.last, 1)).finished
		await t.stage.clear_caption())


static func _takes(t: ArenaTable, e: Dictionary, state: Dictionary) -> void:
	var after := t.card_data(e.id)
	var before := after.duplicate()
	before.ink = false
	before.name = RulesConfig.ROOT[e.sym].paper
	var card := t.hand.card_of(e.id)
	if card:
		before.chips = card.chips
	state.taken += 1
	var summary: Dictionary = t.get_meta(SUMMARY, {"short": 0, "before": [], "after": []})
	summary.before.append(before)
	summary.after.append(after)
	t.set_meta(SUMMARY, summary)
	var doubled: int = 1 << int(state.taken)
	# Where the card lies is asked for as it lifts: the played cards have left the row by then.
	var rest := func() -> Dictionary:
		var at := t.hand.rest_of(e.id)
		if card:
			card.set_meta("away", true)
		return {"centre": at.centre + Vector2(0.0, -ArenaHand.RISE), "turn": at.turn, "size": at.size}
	t.moments.change_side(before, after, "hand", ArenaCaptions.changes("convert", before.name, after.name),
			card, Vector2.ZERO, 0.0, rest)
	t.beats.add_call(func() -> void:
		if card:
			card.dimmed = false
			card.set_tag("")
			t.hand.settle(card))
	# The last play's total doubles, and the round's score follows.
	@warning_ignore("integer_division")
	var taken: int = state.taken
	t.beats.add(func() -> void:
		# Each doubling sounds higher and heavier than the last.
		t.beats.sound("double", Sfx.semitones(2.0 * (taken - 1)), minf(1.0, 0.7 + 0.1 * taken))
		await t.follow(t.numbers.tick_mult(doubled - doubled / 2)).finished)
	t.add_mark("score", e.score, ArenaNumbers.COUNT_TIME)
	t.beats.add(func() -> void:
		t.shown.add("line/paper", -1)
		t.shown.add("line/ink", 1)
		t.line_sound(true)
		await t.play(t.symbols.line_across.bind(true)))
