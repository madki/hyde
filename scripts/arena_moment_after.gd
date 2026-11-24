class_name ArenaMomentAfter
## What a play does once its score has reached the round's, one beat for each of the engine's
## events, before the played cards leave:
##
## - `restraint`: the next step of the restraint track is inked.
## - `craving`: a Craving pip of that symbol fills (or the pips are left as a rollover left them).
## - `breed`: the rollover. The three pips join into a Habit tally, the sketch pulses with
##   its number, and a copy of that Ink Root rises from the sketch and joins the deck, before
##   the refill, because it can be drawn at once. The line gains a mark on his side.
## - `turn`: a Sublimation turns an Ink Root. The symbol's Craving pips travel into Temper,
##   the Root changes side where it lies in the centre, and the line moves a mark across.
## - `cheque`: the Cheque book glints and a sovereign drops into the purse.
##
## After a symbol's gauges change, the chips on every card of that symbol on the table count
## to their new value (`recount`). The locks of Resolve and Cunning, which landed while the
## play scored, open and fall away (`unlock`).


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
				t.mark("sov", e.sov)
				await t.play(t.means.glint.bind("cheque")))
		_:
			return false
	return true


## The lock of Resolve (on the track) or of Cunning (on the sketches) opens and falls away.
static func unlock(t: ArenaTable, on_track: bool) -> void:
	t.beats.add(func() -> void:
		if on_track:
			t.follow(t.column.restraint.set_lock(false))
		else:
			t.symbols.set_lock(false)
		await t.beats.wait(ArenaPace.MARK))


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
			await t.beats.wait(ArenaPace.MARK))


# A Craving pip fills. After a rollover the pips already stand as they should.
static func _craving(t: ArenaTable, e: Dictionary) -> void:
	var key := "symbols/%s/craving" % e.sym
	t.beats.add(func() -> void:
		if int(t.shown.value(key, 0)) == int(e.n):
			return
		t.shown.set_value(key, e.n)
		await t.play(t.symbols.set_craving.bind(e.sym, e.n)))


# The rollover, and the copy it leaves.
static func _breed(t: ArenaTable, e: Dictionary) -> void:
	var sym: String = e.sym
	t.beats.add(func() -> void:
		t.shown.set_value("symbols/%s/craving" % sym, 0)
		t.shown.set_value("symbols/%s/habit" % sym, e.habit)
		await t.play(t.symbols.rollover.bind(sym, e.habit)))
	var copy := t.card_data(e.id)
	t.moments.join_deck([copy], ArenaCaptions.joins("rollover", [copy.name]), t.symbols.sketch_place(sym))
	t.beats.add(func() -> void:
		t.shown.add("line/ink", 1)
		await t.play(t.symbols.line_gain.bind(true)))


# A Sublimation turns an Ink Root that lies in the centre.
static func _turn(t: ArenaTable, e: Dictionary, order: Array) -> void:
	var sym: String = e.sym
	t.beats.add(func() -> void:
		t.shown.set_value("symbols/%s/craving" % sym, 0)
		t.shown.set_value("symbols/%s/temper" % sym, e.temper)
		await t.play(t.symbols.turn.bind(sym, e.temper)))
	var card := t.hand.card_of(e.id)
	var after := t.card_data(e.id)
	var before := after.duplicate()
	before.ink = true
	before.name = RulesConfig.ROOT[sym].ink
	if card:
		before.chips = card.chips
	var slot := t.stage.slot(maxi(order.find(e.id), 0), maxi(order.size(), 1))
	t.moments.change_side(before, after, "hand", ArenaCaptions.changes("turn", before.name, after.name),
			card, slot, 0.0)
	t.beats.add(func() -> void:
		t.shown.add("line/ink", -1)
		t.shown.add("line/paper", 1)
		await t.play(t.symbols.line_across.bind(false)))
