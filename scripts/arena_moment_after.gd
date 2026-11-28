class_name ArenaMomentAfter
## What a play does once its score has reached the round's, one beat for each of the engine's
## events, before the played cards leave:
##
## - `restraint`: the next step of the restraint track is inked.
## - `craving`: a Craving pip of that symbol fills (or the pips are left as a rollover left them).
## - `breed`: the rollover. The three pips join into a Habit tally, the sketch pulses, and
##   'Habit 2' stands beside the gauge under a caption that says why (`grown`); then a copy of that Ink Root rises from the sketch and joins the deck, before
##   the refill, because it can be drawn at once. The line gains a mark on his side.
## - `turn`: Tame the Other turns an Ink Root. The symbol's Craving pips travel into Temper,
##   'Temper 3' stands beside the gauge under a caption that says why, the Root changes side
##   where it lies in the centre, and the line moves a mark across.
## - `cheque`: the Cheque book glints and a sovereign flies from it into the purse.
##
## After a symbol's gauges change, the chips on every card of that symbol on the table count
## to their new value (`recount`). The locks of Truth and Deceit, which landed while the
## play scored, open and fall away (`unlock`).


## Seconds the Cheque book's sovereign takes to reach the purse.
const COIN_TIME := 0.3
## Seconds a gauge that grew holds its new value beside it, with the caption, and the words'
## fade after (laid over the next beat).
const GROWN_HOLD := 1.4
const GROWN_FADE := 0.15

## Adds the beats of one of the events above. False for any other event. `order` is the
## played cards' ids as they lie in the centre.
static func add_event(t: ArenaTable, e: Dictionary, order: Array = []) -> bool:
	match e.t:
		"restraint":
			t.add_mark("restraint/meter", e.n)
		"craving":
			_craving(t, e)
		"breed":
			_breed(t, e)
		"turn":
			_turn(t, e, order)
		"cheque":
			t.beats.add(func() -> void:
				# The light crosses the Cheque book while a sovereign leaves its middle for the purse.
				t.play(t.means.glint.bind("cheque"))
				await ArenaPop.coin(t.beats, t.travel, t.means.spot("cheque"), t.numbers.sov_place(), COIN_TIME)
				t.mark("sov", e.sov)
				await t.beats.wait(ArenaMeans.GLINT_TIME - COIN_TIME))
		_:
			return false
	return true


## The lock of Truth (on the track) or of Deceit (on the sketches) opens and falls away.
static func unlock(t: ArenaTable, on_track: bool) -> void:
	t.beats.add(func() -> void:
		t.beats.sound("lock", 0.75, 0.8) # lower and slower than it landed: a small release
		if on_track:
			t.follow(t.numbers.restraint.set_lock(false))
		else:
			t.symbols.set_lock(false)
		await t.beats.wait(ArenaPace.MARK))


## A gauge of `sym` has grown: its name and new value ("Habit 2") stand beside it, in its
## colour, while `caption` says why, for GROWN_HOLD. The caption is left for the next
## moment's to replace; the words fade as that moment begins.
static func grown(t: ArenaTable, sym: String, row: String, caption: String) -> void:
	t.beats.add(func() -> void:
		t.stage.show_caption(caption)
		t.symbols.set_pay(sym, row, 1.0, 0.0)
		await t.beats.wait(GROWN_HOLD)
		var fade := t.beats.tween()
		fade.tween_method(func(a: float) -> void: t.symbols.set_pay(sym, row, a, 0.0), 1.0, 0.0, GROWN_FADE))


## The chips on every Root of `sym` on the table count to what the engine now gives them.
static func recount(t: ArenaTable, sym: String) -> void:
	t.beats.add(func() -> void:
		var worth: Dictionary = t.after.symbols[sym]
		var any := false
		var cards: Array = t.travel.get_children()
		for id: int in t.hand.ids():
			cards.append(t.hand.card_of(id))
		for card: Variant in cards:
			if not card is ArenaCard or card.key != sym or card.face_down:
				continue
			var to: int = worth.ink_chips if card.ink else worth.paper_chips
			if card.chips == to:
				continue
			any = true
			var count := t.beats.tween()
			count.tween_method(func(n: float) -> void:
				if is_instance_valid(card):
					card.set_chips(roundi(n)), float(card.chips), float(to), ArenaPace.MARK)
		if any:
			t.tick_run(ArenaPace.MARK, 0.6)
			await t.beats.wait(ArenaPace.MARK))


# A Craving pip fills. After a rollover the pips already stand as they should.
static func _craving(t: ArenaTable, e: Dictionary) -> void:
	var key := "symbols/%s/craving" % e.sym
	t.beats.add(func() -> void:
		if int(t.shown.value(key, 0)) == int(e.n):
			return
		t.shown.set_value(key, e.n)
		t.beats.sound("ink_drop", Sfx.semitones(-4.0 + 2.0 * int(e.n)), 0.6)
		await t.play(t.symbols.set_craving.bind(e.sym, e.n)))


# The rollover, and the copy it leaves.
static func _breed(t: ArenaTable, e: Dictionary) -> void:
	var sym: String = e.sym
	t.beats.add(func() -> void:
		t.shown.set_value("symbols/%s/craving" % sym, 0)
		t.shown.set_value("symbols/%s/habit" % sym, e.habit)
		t.beats.sound("rollover")
		await t.play(t.symbols.rollover.bind(sym, e.habit)))
	grown(t, sym, "habit", ArenaCaptions.grows("rollover", RulesConfig.ROOT[sym].label))
	var copy := t.card_data(e.id)
	ArenaMomentShift.hyde_joins(t)
	t.moments.join_deck([copy], ArenaCaptions.joins("rollover", [copy.name]), t.symbols.sketch_place(sym), true,
			ArenaMomentShift.joins_notice.bind(t, "rollover", 1, RulesConfig.ROOT[sym].label))
	t.beats.add(func() -> void:
		t.shown.add("line/ink", 1)
		t.line_sound(true)
		await t.play(t.symbols.line_gain.bind(true)))


# Tame the Other turns an Ink Root that lies in the centre.
static func _turn(t: ArenaTable, e: Dictionary, order: Array) -> void:
	var sym: String = e.sym
	t.beats.add(func() -> void:
		t.shown.set_value("symbols/%s/craving" % sym, 0)
		t.shown.set_value("symbols/%s/temper" % sym, e.temper)
		t.beats.sound("temper")
		await t.play(t.symbols.turn.bind(sym, e.temper)))
	grown(t, sym, "temper", ArenaCaptions.grows("turn", RulesConfig.ROOT[sym].label))
	var card := t.hand.card_of(e.id)
	var after := t.card_data(e.id)
	var before := after.duplicate()
	before.ink = true
	before.name = RulesConfig.ROOT[sym].ink
	if card:
		before.chips = card.chips
	var slot := t.stage.slot(maxi(order.find(e.id), 0), maxi(order.size(), 1))
	var said := func() -> Dictionary:
		return ArenaCaptions.changes_notice("turn", before.name, after.name,
				int(t.shown.value("line/paper", 0)), int(t.shown.value("line/ink", 0)),
				RulesConfig.ROOT[sym].label, int(e.gain), int(e.temper))
	t.moments.change_side(before, after, "hand", ArenaCaptions.changes("turn", before.name, after.name),
			card, slot, 0.0, Callable(), said)
	t.beats.add(func() -> void:
		t.shown.add("line/ink", -1)
		t.shown.add("line/paper", 1)
		t.line_sound(false)
		await t.play(t.symbols.line_across.bind(false)))
