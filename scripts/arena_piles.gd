class_name ArenaPiles
extends Control
## The two piles, one in each corner at the foot of the page: the draw pile on the left and
## the discards on the right (ArenaLayout.pile_draw and pile_discard). Between rounds
## (`deck_mode`) the draw pile's corner holds the whole deck as one pile.
##
## The counts are shown values (ArenaShown "draw_count" and "discard_count", and "deck_count"
## between rounds), so they move only in beats: a card leaving a pile takes one off as it
## lifts, and a card arriving adds one as it lands. Cards travel on an ArenaTravel layer.
##
## Call `bind` once with the queue and the travel layer.

## True between rounds: the discards are not shown and the draw pile is the deck.
var deck_mode := false:
	set(value):
		deck_mode = value
		if discard_pile:
			discard_pile.visible = not value
			draw_pile.title = "Deck" if value else "Draw"
			draw_pile.count = int(_shown_count("deck_count" if value else "draw_count"))

var draw_pile := ArenaPile.new()
var discard_pile := ArenaPile.new()
var beats: ArenaBeats
var travel: ArenaTravel


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_pile.title = "Draw"
	discard_pile.title = "Discards"
	discard_pile.messy = true
	discard_pile.rng_seed = 8
	add_child(discard_pile)
	add_child(draw_pile)


func _ready() -> void:
	resized.connect(_place_piles)
	_place_piles()


## Ties the piles to the queue (their counts follow its shown values) and to the layer cards
## travel on.
func bind(queue: ArenaBeats, layer: ArenaTravel) -> void:
	beats = queue
	travel = layer
	beats.shown.changed.connect(_on_shown)
	for key in ["draw_count", "discard_count", "deck_count"]:
		if beats.shown.has(key):
			_on_shown(key, beats.shown.value(key))


## The pile called "draw" or "discards".
func pile(which: String) -> ArenaPile:
	return discard_pile if which == "discards" else draw_pile


## Lifts the card `data` off a pile onto the travel layer, and takes one off its count. The
## card lies where the pile's top is: send it on with `travel.fly`.
func take(which: String, data: Dictionary) -> ArenaCard:
	var from := pile(which)
	var card := from.lift(data)
	if card.is_inside_tree():
		travel.take(card)
	else:
		travel.place(card, from.top_centre(), from.top_turn(), from.card_scale())
	beats.shown.add(_count_key(which), -1)
	return card


## Sends cards to a pile, ArenaPace.TRAVEL_GAP apart; each adds one to the count as it lands.
## On the draw pile they arrive face down; on the discards face up. With `into_middle` (a
## card joining the deck during a round) each goes in beside the pile, slides into its middle,
## and the pile riffles. Await it.
func put(which: String, cards: Array, into_middle: bool = false) -> void:
	var to := pile(which)
	var face := ArenaTravel.UP if to == discard_pile else ArenaTravel.DOWN
	var left := [cards.size()]
	for i in cards.size():
		_put_one(which, to, cards[i], face, into_middle, ArenaPace.travel_start(i), left)
	while left[0] > 0:
		await get_tree().process_frame


func _put_one(which: String, to: ArenaPile, card: ArenaCard, face: int, into_middle: bool,
		delay: float, left: Array) -> void:
	if into_middle:
		# Beside the pile, half over it, then in: on the side of the page's middle, since the
		# pile lies in a corner and its other side is the page's edge.
		var inward := 1.0 if to.top_centre().x < get_global_rect().get_center().x else -1.0
		var beside := to.top_centre() + Vector2(inward * ArenaCard.SIZE.x * ArenaPile.SCALE * 0.55, 8.0)
		await travel.fly(card, beside, inward * 6.0, ArenaPile.SCALE, face, ArenaPace.TRAVEL, delay)
		to.riffle(beats)
		await travel.fly(card, to.top_centre() + Vector2(0.0, 4.0), 0.0, ArenaPile.SCALE, face,
				ArenaPace.SLIDE_IN)
		# It goes in under the top: hide it as it reaches the pile.
		card.visible = false
	else:
		await travel.fly(card, to.top_centre(), to.top_turn(), ArenaPile.SCALE, face,
				ArenaPace.TRAVEL, delay)
	to.land(card)
	beats.shown.add(_count_key(which), 1)
	left[0] -= 1


## The discards turn over into a new draw pile: the whole stack lifts, turns face down on its
## way across, lands on the draw pile, and the new pile is given a long riffle. Unlike a deal,
## the cards go together as one stack, across the foot of the page and into the draw pile.
## Await it.
func reshuffle() -> void:
	var n := int(beats.shown.value("discard_count", 0))
	if n == 0:
		return
	var stack := discard_pile.take_all()
	beats.shown.set_value("discard_count", 0)
	var last: Signal
	for i in stack.size():
		var card := stack[i]
		travel.take(card)
		# The stack goes as one: a hair apart, the top last.
		last = travel.fly(card, draw_pile.top_centre() + ArenaPile.LAYER_STEP * i, 0.0, ArenaPile.SCALE,
				ArenaTravel.DOWN, ArenaPace.TRAVEL * 1.5, i * 0.02)
	await last
	for card in stack:
		card.queue_free()
	beats.shown.add("draw_count", n)
	await draw_pile.riffle(beats, true)


func _on_shown(key: String, value: Variant) -> void:
	match key:
		"draw_count":
			if not deck_mode:
				draw_pile.count = int(value)
		"deck_count":
			if deck_mode:
				draw_pile.count = int(value)
		"discard_count":
			discard_pile.count = int(value)


func _count_key(which: String) -> String:
	if which == "discards":
		return "discard_count"
	return "deck_count" if deck_mode else "draw_count"


func _shown_count(key: String) -> Variant:
	return beats.shown.value(key, 0) if beats else 0


func _place_piles() -> void:
	draw_pile.position = ArenaLayout.pile_draw(size).get_center() - draw_pile.size * 0.5
	discard_pile.position = ArenaLayout.pile_discard(size).get_center() - discard_pile.size * 0.5
