class_name ArenaCardMoments
extends RefCounted
## The three card moments the rest of the flow uses each a run of beats
## added to the queue from card data and a caption:
##
## - `join_deck`: a card or a group joins the deck. By a rule, it is shown on the notice and
##   waits for the player; else it appears face up in the centre from where it belongs, the
##   caption names it and it is held still. Then it turns face down and goes into the draw
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
## The sheet a joining group is shown on, set by the page that holds it; with none, the stage.
var notice: ArenaNotice
## Called before a notice shows, to put right what a skipped stretch left behind
## (ArenaTable.freshen): set by the page with the notice.
var freshen := Callable()

## A pour's first blob lands this long after the last joining card is in its pile, so that the
## moment's last beat is there to meet it.
const POUR_AFTER := 0.04


func _init(queue: ArenaBeats, layer: ArenaTravel, the_piles: ArenaPiles, the_stage: ArenaStage) -> void:
	beats = queue
	travel = layer
	piles = the_piles
	stage = the_stage


## 6.1. `cards` join the deck, shown as one group (up to five), coming from `from` (a point on
## the page: the ink for his Roots, a sketch for a bred copy, the reward). `into_middle` during
## a round; between rounds, with the piles in deck mode, they go onto the deck.
##
## With `said` (a Callable returning {title, lines}, called as its beat begins so that it can
## read the table as it then stands) the group is shown on the notice instead, in his tone, and
## waits for the player; on Continue the cards turn face down where they lay on it and go to
## the pile. Without it, they are laid on the stage under `caption` and held.
func join_deck(cards: Array, caption: String, from: Vector2, into_middle: bool = true,
		said: Callable = Callable()) -> void:
	var nodes: Array = []
	# The ink that runs from the notice's blot to the pool, when there is one.
	var pour: Array[ArenaPour] = [null]
	if said.is_valid() and notice:
		beats.add_choice(func() -> void:
			var what: Dictionary = said.call()
			what.cards = cards
			what.tone = "hyde"
			notice.centres.clear()
			if freshen.is_valid(): freshen.call()
			var stream := _pour_watching()
			await notice.show_notice(what)
			# Continue: the blot runs to the pool, its first blob landing as the last card is in.
			var middle := into_middle and not piles.deck_mode
			pour[0] = _pour_runs(stream, ArenaPace.TRAVEL * 2.0 + ArenaPace.travel_start(cards.size() - 1)
					+ (ArenaPace.SLIDE_IN if middle else 0.0) + POUR_AFTER)
			# The notice's own cards left with it: travelling ones take their places. With no
			# notice shown (passed at once) they start from `from`.
			var shown := notice.centres.size() == cards.size()
			for i in cards.size():
				var card := ArenaTravel.make_card(cards[i])
				if shown:
					travel.place(card, notice.centres[i], 0.0, ArenaNotice.CARD_SCALE)
				else:
					travel.place(card, from, 0.0, 0.5)
				nodes.append(card))
	else:
		_lay_joining(cards, caption, from, nodes)
	beats.add(func() -> void:
		var last: Signal
		beats.sound("card_flip", Sfx.vary() * 0.9)
		for card: ArenaCard in nodes:
			last = travel.turn_over(card, false)
		await last)
	beats.add(func() -> void:
		await piles.put("draw", nodes, into_middle and not piles.deck_mode))
	beats.add(func() -> void:
		await stage.clear_caption()
		await _pour_lands(pour[0])
		joined.emit(cards))


# The stage's way of showing a joining group: laid face up in the centre under `caption`, held.
func _lay_joining(cards: Array, caption: String, from: Vector2, nodes: Array) -> void:
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
		# Hyde's cards come out lower and thicker than Jekyll's.
		beats.sound("draw_%d" % randi_range(1, 3), Sfx.vary() * (0.8 if man == "Hyde" else 1.0), 0.6)
		await stage.lay(travel, nodes))
	beats.add_wait(ArenaPace.HOLD)
	beats.add(func() -> void:
		beats.sound("draw_%d" % randi_range(1, 3), Sfx.vary() * (0.8 if man == "Hyde" else 1.0), 0.6)
		await to_hand.call(nodes))
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
##
## With `said` (a Callable returning {title, lines}, called as its beat begins) the change is
## shown on the notice instead and waits for the player: the card as it was, the crack played
## on it there, and its twin; in his tone when it turns to Ink, else in Jekyll's. On Continue
## the card goes back from where it lay on the sheet to its place. Without it (or with the
## notice passed at once) the card lifts where it lies, cracks under `caption` and settles.
func change_side(before: Dictionary, after: Dictionary, where: String, caption: String,
		card: ArenaCard = null, rest_centre: Vector2 = Vector2.ZERO, rest_turn: float = 0.0,
		rest: Callable = Callable(), said: Callable = Callable()) -> void:
	var held := [card]
	var place := [rest_centre, rest_turn, 1.0]
	# Where the card lay on the sheet; empty when no notice was shown.
	var shown: Array[Vector2] = []
	var time := ArenaPace.CHANGE_SIDE
	# The ink that runs from the notice's blot to the pool, when the Root turns to Ink.
	var pour: Array[ArenaPour] = [null]
	if said.is_valid() and notice:
		beats.add_choice(func() -> void:
			var what: Dictionary = said.call()
			what.cards = [before]
			what.tone = "hyde" if after.get("ink", false) else "jekyll"
			if freshen.is_valid(): freshen.call()
			var stream := _pour_watching() if what.tone == "hyde" else null
			await _crack_on_notice(what, after)
			shown.assign(notice.centres)
			# Continue: the blot runs to the pool.
			pour[0] = _pour_runs(stream, ArenaPour.FLIGHT))
	beats.add(func() -> void:
		if where == "hand":
			place[2] = held[0].scale.y
			if rest.is_valid():
				var now: Dictionary = rest.call()
				place[0] = now.centre
				place[1] = now.turn
				place[2] = now.get("size", place[2])
		else:
			held[0] = piles.take(where, before)
		if not shown.is_empty():
			# It has changed on the sheet: the card takes its twin's face where the sheet's lay.
			held[0].show_data(after, held[0].rng_seed)
			held[0].set_meta("data", after)
			held[0].face_down = false
			travel.place(held[0], shown[0], 0.0, ArenaNotice.CARD_SCALE)
			return
		stage.show_caption(caption)
		var lifted: Vector2
		if where == "hand":
			# A card of the hand lifts well clear of the row; one laid on the stage is held up
			# where it lies, to stay under the caption and over the lower rule.
			lifted = place[0] + Vector2(0.0, 0.0 if stage.holds(place[0]) else -34.0)
		else:
			# Drawn out of the pile, face up, to the centre of the table.
			lifted = stage.slot(0, 1)
		# It lifts: a fifth of the change. Drawn out of a pile, it travels at a card's pace.
		await travel.fly(held[0], lifted, 0.0, 1.12 * (float(place[2]) if where == "hand" else ArenaStage.LAID_SCALE),
				ArenaTravel.UP,
				time * 0.19 if where == "hand" else ArenaPace.TRAVEL))
	beats.add(func() -> void:
		if not shown.is_empty():
			return
		beats.sound("crack_ink" if after.get("ink", false) else "crack_paper")
		await _crack(held[0], after, time * 0.62))
	beats.add(func() -> void:
		# It settles back: the rest of the change. From the sheet, at a card's pace.
		var back := time * 0.19 if shown.is_empty() else ArenaPace.TRAVEL
		if where == "hand":
			await travel.fly(held[0], place[0], place[1], place[2], ArenaTravel.KEEP, back)
		else:
			await piles.put(where, [held[0]], where == "draw"))
	beats.add(func() -> void:
		await stage.clear_caption()
		await _pour_lands(pour[0])
		if not shown.is_empty() and not after.get("ink", false) and _pours():
			# Turned to Paper on the sheet: a pale wash leaves the pool for it as the pool draws back.
			ArenaPour.under(travel, beats).wash(
					ArenaTravel.centre_of(held[0]) if where == "hand" else piles.pile(where).top_centre())
		side_changed.emit(before, after, held[0] if where == "hand" else null))


# True when ink may be seen to run: not with "reduce flashes" on, nor in a move that is skipped.
func _pours() -> bool:
	return not ArenaPace.reduce_flashes and beats.rate() < ArenaPace.SKIP


# A pour that watches the notice about to be shown in his tone, so that its blot stays on the
# page as the sheet leaves; none when no ink is to run, or no notice will be shown.
func _pour_watching() -> ArenaPour:
	if not _pours() or ArenaNotice.pass_at_once:
		return null
	var stream := ArenaPour.under(travel, beats)
	stream.watch(notice)
	return stream


# At the notice's Continue: `stream` runs from where the notice's cards lay, its first blob
# landing in `first_lands` seconds. Returns it, or null when nothing runs (no notice was
# shown, or the move is now skipped).
func _pour_runs(stream: ArenaPour, first_lands: float) -> ArenaPour:
	if not stream:
		return null
	if notice.centres.is_empty() or not _pours():
		stream.drop()
		return null
	stream.run(notice.centres, first_lands)
	return stream


# Waits for the first blob of `stream` to reach the pool, then has the page surge there. The
# beat this ends is the moment's last: the line's marks are given in the beat after it, in the
# same frame, so that the blob, the surge and the marks come together.
func _pour_lands(stream: ArenaPour) -> void:
	if not is_instance_valid(stream):
		return
	if not stream.has_landed:
		await stream.landed
	stream.reach_pool()


# Shows `what` on the notice and, once the sheet has come in, plays the crack on its card,
# which becomes `after`. Returns when the notice has left. `notice.centres` then holds where
# the card lay (empty when it was passed at once).
func _crack_on_notice(what: Dictionary, after: Dictionary) -> void:
	notice.centres.clear()
	var left := [false]
	var leaves := func() -> void:
		await notice.show_notice(what)
		left[0] = true
	leaves.call()
	if not left[0]:
		await notice.get_tree().create_timer(ArenaNotice.IN + 0.1).timeout
		var cards := notice.shown_cards()
		if notice.showing and not cards.is_empty():
			beats.sound("crack_ink" if after.get("ink", false) else "crack_paper")
			_crack_tween(cards[0], after, ArenaPace.CHANGE_SIDE)
	# Its card's crack runs on the card's own tweens: when the notice leaves, passed by a press
	# or by itself, they end with the card and nothing waits on them.
	while not left[0] and notice.showing:
		await notice.dismissed


## The crack runs across the card, the twin floods out from it, and the card becomes the twin.
func _crack(card: ArenaCard, after: Dictionary, time: float) -> void:
	await _crack_tween(card, after, time, beats.tween(), beats.tween()).finished


# The crack's run on `card` over `time`: the tween that ends with it become `after`. The tweens
# are the card's own unless given, so that they end with it when it leaves (a notice's card).
func _crack_tween(card: ArenaCard, after: Dictionary, time: float, t: Tween = null,
		shake: Tween = null) -> Tween:
	if not t:
		t = card.create_tween()
	var twin := ArenaTravel.make_card(after)
	twin.rng_seed = card.rng_seed
	twin.show_data(after, card.rng_seed)
	# The twin floods in clean: the ink stain creeps over the card once it has become the twin.
	twin.stain = 0.0
	var crack := ArenaCrack.new(twin, card.rng_seed)
	card.add_child(crack)
	t.tween_property(crack, "run", 1.0, time * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(crack, "glow", 1.0, ArenaPace.FLARE_RISE)
	if not ArenaPace.reduce_flashes:
		# A short shake as it cracks.
		if not shake:
			shake = card.create_tween()
		var turn := card.rotation_degrees
		for i in 4:
			shake.tween_property(card, "rotation_degrees", turn + (2.0 if i % 2 == 0 else -2.0), time * 0.04)
		shake.tween_property(card, "rotation_degrees", turn, time * 0.04)
	elif shake:
		shake.kill()
	t.tween_property(crack, "flood", 1.0, time * 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(crack, "glow", 0.0, maxf(ArenaPace.FLARE_FALL, time * 0.65))
	t.tween_callback(func() -> void:
		card.show_data(after, card.rng_seed)
		card.set_meta("data", after)
		crack.queue_free())
	return t
