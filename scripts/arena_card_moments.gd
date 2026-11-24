class_name ArenaCardMoments
extends RefCounted
## The three card moments the rest of the flow uses each a run of beats
## added to the queue from card data and a caption:
##
## - `join_deck`: a card or a group joins the deck. It appears face up in the centre from where
##   it belongs, the caption names it, it is held still, turns face down and goes into the draw
##   pile (into its middle during a round), whose count rises a card at a time.
## - `bring_to_hand`: a man brings Roots. The cards come out of the pile they were found in,
##   turn face up in the centre under a caption, are held, then go to the hand. With none
##   found, the caption says so.
## - `change_side`: a Root changes side. The card lifts where it lies (a card in a pile is
##   first drawn out face up), a crack runs across it, ink floods or drains, the title and
##   picture become the twin's, and it settles back.
##
## Card data is the shape of a card in RulesView.table().hand: {id, name, ink, chips}. The
## moments move cards, counts and captions only; the line and the symbols are left to whoever
## answers the signal each moment sends at its end, from inside its last beat (use
## ArenaBeats.add_next there to play the answer straight after).

## Cards joined the deck (each a data dictionary), after the last has landed.
signal joined(cards: Array)
## Cards were brought to the hand (empty when none were found), after they arrived.
signal brought(cards: Array)
## A Root changed side and has settled back: `card` is the node when it lies in the hand.
signal side_changed(before: Dictionary, after: Dictionary, card: ArenaCard)

var beats: ArenaBeats
var travel: ArenaTravel
var piles: ArenaPiles
var stage: ArenaStage


func _init(queue: ArenaBeats, layer: ArenaTravel, the_piles: ArenaPiles, the_stage: ArenaStage) -> void:
	beats = queue
	travel = layer
	piles = the_piles
	stage = the_stage


## 6.1. `cards` join the deck, shown as one group (up to five), coming from `from` (a point on
## the page: the ink for his Roots, a sketch for a bred copy, the reward). `into_middle` during
## a round; between rounds, with the piles in deck mode, they go onto the deck.
func join_deck(cards: Array, caption: String, from: Vector2, into_middle: bool = true) -> void:
	var nodes: Array = []
	beats.add(func() -> void:
		for data: Dictionary in cards:
			var card := ArenaTravel.make_card(data)
			travel.place(card, from, 0.0, 0.5)
			card.modulate.a = 0.0
			nodes.append(card)
			var fade := beats.tween()
			fade.tween_property(card, "modulate:a", 1.0, ArenaPace.TRAVEL * 0.5)
		stage.show_caption(caption)
		await stage.lay(travel, nodes))
	beats.add_wait(ArenaPace.HOLD)
	beats.add(func() -> void:
		var last: Signal
		for card: ArenaCard in nodes:
			last = travel.turn_over(card, false)
		await last)
	beats.add(func() -> void:
		await piles.put("draw", nodes, into_middle and not piles.deck_mode))
	beats.add(func() -> void:
		await stage.clear_caption()
		joined.emit(cards))


## 6.2. `man` ("Jekyll" or "Hyde") brings `cards`, found in `pile` ("draw" or "discards").
## `to_hand` is the hand's own move, awaited with the card nodes: it takes them into the hand
## and closes the fan. With no cards, only the caption is shown.
func bring_to_hand(man: String, cards: Array, pile: String, to_hand: Callable,
		caption: String = "") -> void:
	if caption == "":
		caption = ArenaCaptions.brings(man, cards.map(func(c: Dictionary) -> String: return c.name))
	if cards.is_empty():
		beats.add(func() -> void:
			stage.show_caption(caption)
			await stage.clear_caption()
			brought.emit(cards))
		return
	var nodes: Array = []
	beats.add(func() -> void:
		for data: Dictionary in cards:
			nodes.append(piles.take(pile, data))
		stage.show_caption(caption)
		await stage.lay(travel, nodes))
	beats.add_wait(ArenaPace.HOLD)
	beats.add(func() -> void: await to_hand.call(nodes))
	beats.add(func() -> void:
		await stage.clear_caption()
		brought.emit(cards))


## 6.3. The Root `before` becomes `after`, its twin. `where` is "hand", "draw" or "discards".
## In the hand give its node as `card` and the place it goes back to (`rest_centre`, `rest_turn`,
## at the size it has now);
## it is lifted off the hand onto the travel layer and left there: the hand takes it back when
## `side_changed` is sent. In a pile it is drawn out face up and put back. When the hand may
## change before these beats play (cards leave it first), give `rest` instead: it is called
## as the card lifts and returns {centre, turn, size}, the place as it then is.
func change_side(before: Dictionary, after: Dictionary, where: String, caption: String,
		card: ArenaCard = null, rest_centre: Vector2 = Vector2.ZERO, rest_turn: float = 0.0,
		rest: Callable = Callable()) -> void:
	var held := [card]
	var place := [rest_centre, rest_turn, 1.0]
	var time := ArenaPace.CHANGE_SIDE
	beats.add(func() -> void:
		stage.show_caption(caption)
		var lifted: Vector2
		if where == "hand":
			place[2] = held[0].scale.y
			if rest.is_valid():
				var now: Dictionary = rest.call()
				place[0] = now.centre
				place[1] = now.turn
				place[2] = now.get("size", place[2])
			# A card of the hand lifts well clear of the row; one laid on the stage is held up
			# where it lies, to stay under the caption and over the lower rule.
			lifted = place[0] + Vector2(0.0, 0.0 if stage.holds(place[0]) else -34.0)
		else:
			# Drawn out of the pile, face up, to the centre of the table.
			held[0] = piles.take(where, before)
			lifted = stage.slot(0, 1)
		# It lifts: a fifth of the change. Drawn out of a pile, it travels at a card's pace.
		await travel.fly(held[0], lifted, 0.0, 1.12 * (float(place[2]) if where == "hand" else ArenaStage.LAID_SCALE),
				ArenaTravel.UP,
				time * 0.19 if where == "hand" else ArenaPace.TRAVEL))
	beats.add(func() -> void:
		await _crack(held[0], after, time * 0.62))
	beats.add(func() -> void:
		# It settles back: the rest of the change.
		if where == "hand":
			await travel.fly(held[0], place[0], place[1], place[2], ArenaTravel.KEEP, time * 0.19)
		else:
			await piles.put(where, [held[0]], where == "draw"))
	beats.add(func() -> void:
		await stage.clear_caption()
		side_changed.emit(before, after, held[0] if where == "hand" else null))


## The crack runs across the card, the twin floods out from it, and the card becomes the twin.
func _crack(card: ArenaCard, after: Dictionary, time: float) -> void:
	var twin := ArenaTravel.make_card(after)
	twin.rng_seed = card.rng_seed
	twin.show_data(after, card.rng_seed)
	var crack := ArenaCrack.new(twin, card.rng_seed)
	card.add_child(crack)
	var t := beats.tween()
	t.tween_property(crack, "run", 1.0, time * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(crack, "glow", 1.0, ArenaPace.FLARE_RISE)
	if not ArenaPace.reduce_flashes:
		# A short shake as it cracks.
		var turn := card.rotation_degrees
		var shake := beats.tween()
		for i in 4:
			shake.tween_property(card, "rotation_degrees", turn + (2.0 if i % 2 == 0 else -2.0), time * 0.04)
		shake.tween_property(card, "rotation_degrees", turn, time * 0.04)
	t.tween_property(crack, "flood", 1.0, time * 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(crack, "glow", 0.0, maxf(ArenaPace.FLARE_FALL, time * 0.65))
	await t.finished
	card.show_data(after, card.rng_seed)
	card.set_meta("data", after)
	crack.queue_free()
