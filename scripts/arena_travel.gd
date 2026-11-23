class_name ArenaTravel
extends Control
## The layer cards travel on, above everything else on the table, and the travel itself: a
## card moves from where it lies to any other place (a pile, the hand, the centre), turning
## over on the way when asked.
##
## A place is given by the card's centre in the page's coordinates, how far it is turned (in
## degrees) and its size (1 is a card in the hand). Every move plays through the beat queue
## (`beats`), so it is hurried with the rest. A move returns the Signal of its end: `await` it,
## or start several and await the last.

## For `fly`'s `face`: leave the card as it is, or have it end face down or face up.
enum { KEEP = -1, DOWN = 0, UP = 1 }

var beats: ArenaBeats


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## A new card node showing `data`: {id, name, ink, chips}, the shape of a card in
## RulesView.table().hand. Not yet in the tree.
static func make_card(data: Dictionary) -> ArenaCard:
	var card := ArenaCard.new()
	var id: int = data.get("id", 0)
	card.show_data(data, id * 7 + 3)
	card.set_meta("data", data)
	return card


## Moves `card` onto this layer, on top of the others, without moving it on the page.
func take(card: ArenaCard) -> void:
	if card.get_parent() == self:
		move_child(card, -1)
		return
	var at := card.get_global_transform()
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	# The card turns and grows about its middle (its pivot), so only its middle need be kept.
	var centre := at * card.pivot_offset
	card.rotation = at.get_rotation()
	card.scale = at.get_scale()
	card.position = _local(centre) - card.pivot_offset


## Puts a card that is not in the tree onto this layer, its centre at `centre`.
func place(card: ArenaCard, centre: Vector2, turn: float = 0.0, size_scale: float = 1.0) -> void:
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	card.position = _local(centre) - card.pivot_offset
	card.rotation_degrees = turn
	card.scale = Vector2(size_scale, size_scale)


## A point of the page in this layer's own coordinates.
func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


## The centre of a card on the page.
static func centre_of(card: ArenaCard) -> Vector2:
	return card.get_global_transform() * card.pivot_offset


## Sends `card` to the place centred at `centre`, turned `turn` degrees, at `size_scale`, over
## `time` after `delay`. With `face` UP or DOWN it turns over on the way if it has to.
func fly(card: ArenaCard, centre: Vector2, turn: float = 0.0, size_scale: float = 1.0,
		face: int = KEEP, time: float = ArenaPace.TRAVEL, delay: float = 0.0) -> Signal:
	take(card)
	var t := beats.tween()
	if delay > 0.0:
		t.tween_interval(delay)
	# Read where it starts only when it sets off: another move may have it until then.
	var from := {}
	t.tween_callback(func() -> void:
		take(card)
		from.position = card.position
		from.turn = card.rotation_degrees
		from.size = card.scale.y
		from.face = card.face_up)
	var to := _local(centre) - card.pivot_offset
	var step := func(u: float) -> void:
		if not is_instance_valid(card) or from.is_empty():
			return
		var e := 1.0 - pow(1.0 - u, 3.0)
		card.position = (from.position as Vector2).lerp(to, e)
		card.rotation_degrees = lerpf(from.turn, turn, e)
		var s := lerpf(from.size, size_scale, e)
		var flip: bool = face != KEEP and from.face != (face == UP)
		card.scale = Vector2(s * (absf(cos(PI * u)) if flip else 1.0), s)
		if flip and u >= 0.5:
			card.face_up = face == UP
	t.tween_method(step, 0.0, 1.0, time)
	return t.finished


## Sends several cards, each to its own place, one setting off ArenaPace.TRAVEL_GAP after the
## other. `turns` may be empty (none turned). Returns the end of the last.
func fly_group(cards: Array, centres: Array, turns: Array = [], size_scale: float = 1.0,
		face: int = KEEP, time: float = ArenaPace.TRAVEL) -> Signal:
	var last: Signal
	for i in cards.size():
		last = fly(cards[i], centres[i], turns[i] if i < turns.size() else 0.0, size_scale, face,
				time, ArenaPace.travel_start(i))
	return last


## Turns a card over where it lies.
func turn_over(card: ArenaCard, up: bool, time: float = ArenaPace.TRAVEL) -> Signal:
	return fly(card, centre_of(card), card.rotation_degrees, card.scale.y, UP if up else DOWN, time)
