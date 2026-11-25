class_name ArenaMomentCards
## The plain movements of cards that several moves share: chosen cards leave the hand for the
## discards, cards are drawn from the draw pile to the hand, and the discards turn over into
## a new draw pile. Each adds one beat from one of a move's events.
##
## Cards drawn in the ordinary way are not announced: they travel face down from the draw
## pile and turn over as they reach the hand, each sliding into its place in the row.


## Adds the beat of a `discarded`, `drawn` or `reshuffle` event. False for any other event.
static func add_event(t: ArenaTable, e: Dictionary) -> bool:
	match e.t:
		"discarded":
			leave(t, e.ids)
		"drawn":
			draw(t, e.ids)
		"reshuffle":
			reshuffle(t)
		_:
			return false
	return true


## The cards with these ids leave the hand for the discards, and the row closes up.
static func leave(t: ArenaTable, ids: Array) -> void:
	t.beats.add(func() -> void:
		var cards: Array = []
		for id: int in ids:
			var card := t.hand.give(id)
			if card == null:
				continue
			card.set_meta("data", t.card_data(id))
			t.travel.take(card)
			cards.append(card)
		if not cards.is_empty():
			on_each_start(t, cards.size(), discard_sound.bind(t))
			await t.piles.put("discards", cards))


## The cards with these ids are drawn, one after another, from the draw pile to the hand.
static func draw(t: ArenaTable, ids: Array) -> void:
	t.beats.add(func() -> void:
		var last: Signal
		for i in ids.size():
			var card := t.piles.take("draw", t.card_data(ids[i]))
			var to: Dictionary = t.hand.take_in(card, t.entry(ids[i]), t.hyde())
			draw_sound(t)
			last = t.travel.fly(card, to.centre, to.turn, to.size, ArenaTravel.UP)
			last.connect(t.hand.settle.bind(card), CONNECT_ONE_SHOT)
			if i < ids.size() - 1:
				await t.beats.wait(ArenaPace.TRAVEL_GAP)
		if not ids.is_empty():
			await last)


## The draw pile ran out: the discards turn over and become the new draw pile.
static func reshuffle(t: ArenaTable) -> void:
	t.beats.add(func() -> void: await t.piles.reshuffle())


## The sound of a card drawn to the hand, as it sets off: one of three, a little off pitch.
static func draw_sound(t: ArenaTable) -> void:
	t.beats.sound("draw_%d" % randi_range(1, 3), Sfx.vary(), 0.6)


## The sound of a card thrown away: a drawn card's, lower.
static func discard_sound(t: ArenaTable) -> void:
	t.beats.sound("draw_%d" % randi_range(1, 3), Sfx.vary() * 0.8, 0.6)


## Calls `call` once for each of `n` cards that set off ArenaPace.TRAVEL_GAP apart (a group
## laid or put on a pile), as each sets off: the first at once. From inside a beat.
static func on_each_start(t: ArenaTable, n: int, call: Callable) -> void:
	for i in n:
		if i == 0:
			call.call()
			continue
		var at := t.beats.tween()
		at.tween_interval(ArenaPace.travel_start(i))
		at.tween_callback(call)
