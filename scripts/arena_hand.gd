class_name ArenaHand
extends Control
## The hand of cards on the arena's table: a row in a shallow arc along the foot of the page
## (ArenaLayout.hand), centred, every card whole on the page at its own size (CARD_SCALE),
## each lying over the one before it. A card that is partly covered has its title written in
## the part that shows, and every card its chips on a disc at its top left, where the next
## card does not cover them. The card under the pointer rises, straightens and lies on top
## of the others; a chosen card rises further. While Hyde has the table the row is a little
## out of true: each card is pushed and turned a little its own way.
##
## A card under the pointer keeps its size: it only rises and straightens, and no other card
## moves. Every card keeps the pointer by its place at rest, so the row does not shift under
## the pointer.
##
## The hand is drawn from the rules: give `show_table` what RulesView.table() returns, when
## nothing is moving and after every change of the chosen cards. It keeps one card for each
## id, in a fixed order whatever order they were drawn in: Paper Roots, Ink Roots, Factors,
## each by symbol. A card new to the hand appears, one that has gone leaves, and a Root whose
## side has changed changes face where it lies. A click chooses a card or lets it go, up to
## `max_chosen`; one more is refused with a small shake. `chosen_changed` then asks for the
## table again, with `chosen()`, so that the marks of the play it would make can be shown:
##
## - cannot be played now: printed dark;
## - can be turned: "turns +N", N being the Craving it would move;
## - chosen: lifted;
## - in the chosen play: "best" on its best Root, "turning +N" on each Root being turned.
##
## Nothing that follows from the play's score is marked: the score is hidden until the play
## is made.
##
## While a move is played back the cards travel instead (ArenaTravel): `give` hands a card's
## node over and the row closes up; `take_in` makes room for a card on its way and says where
## it is to land, and `settle` puts it in the row when it has arrived. A place in the row is
## {centre (on the page), turn (degrees), size (the card's scale there)}.

## The chosen cards changed: their ids, in the hand's order.
signal chosen_changed(ids: Array)

## A card in the hand is drawn at this scale of its own size.
const CARD_SCALE := 1.0
## Distance between one card's centre and the next, in pixels, while the row has the room.
const PITCH := 90.0
## How far the row's ends turn, in degrees, and how far they drop, in pixels.
const FAN_TURN := 3.0
const FAN_DROP := 8.0
## How far out of true a card may be while Hyde has the table: across, up or down (in pixels)
## and turned (in degrees). And the time the row takes to go out of true or back.
const UNRULY := Vector3(3.0, 6.0, 3.0)
const UNRULY_TIME := 0.25
## How far a card rises under the pointer and when chosen, in pixels, and the time it takes.
const RISE := 16.0
const CHOSEN_RISE := 30.0
const RISE_TIME := 0.12
## How far a refused card turns each way, in degrees.
const SHAKE := 4.0
## The time the row takes to close up or to make room.
const SLIDE_TIME := 0.2
## The fixed order of the symbols and kinds within each group of cards.
const KEY_ORDER: Array[String] = ["lamp", "heart", "mirror", "cup", "eye", "lock", "pen", "cane"]

## Where the row lies, for a hand that is not the arena's: the cards' tops along its top, the
## row no wider than it. Left empty, the place is ArenaLayout's.
var place := Rect2():
	set(value):
		place = value
		snap()

## Who has the table: the row is out of true for Hyde.
var is_jekyll := true:
	set(value):
		if value == is_jekyll:
			return
		is_jekyll = value
		for card in _cards:
			_move(card, UNRULY_TIME)
## How many cards can be chosen at once: the rules' dial `max_play`.
var max_chosen := 5
## False while clicks are not taken.
var enabled := true

## While true every card stands raised, as under the pointer: he is looking the hand over.
var _lifted := false
var _cards: Array[ArenaCard] = []
var _rng := RandomNumberGenerator.new()
## False while the pointer is outside the window.
var _pointer_here := true
## The card the pointer is on.
var _resting: ArenaCard
## A screenshot must not depend on where the pointer happens to rest, nor catch a card midway.
var _still := Shot.has_arg("shot")


func _ready() -> void:
	_rng.seed = 11
	resized.connect(snap)
	set_process(not _still)


## Shows the hand of RulesView.table(): see the top of this script.
func show_table(table: Dictionary) -> void:
	var hyde: bool = table.stance == "hyde"
	var entries := _sorted(table.hand)
	var by_id := {}
	for card in _cards:
		settle(card)
		by_id[card.card_id] = card
	var next: Array[ArenaCard] = []
	var fresh: Array[ArenaCard] = []
	for entry: Dictionary in entries:
		var card: ArenaCard = by_id.get(entry.id)
		if card == null:
			card = _new_card()
			card.show_entry(entry, hyde)
			fresh.append(card)
		elif card.ink != (entry.ink or (entry.t == "factor" and hyde)):
			card.change_face(card.show_entry.bind(entry, hyde), not _still)
		else:
			card.show_entry(entry, hyde)
		card.face_down = false
		card.set_meta("rank", _rank(entry))
		by_id.erase(entry.id)
		next.append(card)
	var let_go := false
	for card: ArenaCard in by_id.values():
		let_go = let_go or card.chosen
		card.leave(not _still)
	_cards = next
	_restack()
	_fit_titles()
	_mark(table, entries)
	for card in _cards:
		if card in fresh:
			card.position = _place(card)
			card.rotation_degrees = _turn(card)
			card.appear(not _still)
		else:
			_move(card, UNRULY_TIME)
	if let_go:
		chosen_changed.emit(chosen())


## The ids of the cards in the hand, in the row's order.
func ids() -> Array:
	var out: Array = []
	for card in _cards:
		out.append(card.card_id)
	return out


## The node of the card with this id, or null.
func card_of(id: int) -> ArenaCard:
	for card in _cards:
		if card.card_id == id:
			return card
	return null


## Where the card with this id rests in the row: {centre (on the page), turn (degrees)}.
func rest_of(id: int) -> Dictionary:
	var card := card_of(id)
	if card == null:
		return {"centre": Vector2.ZERO, "turn": 0.0, "size": CARD_SCALE}
	return _rest_place(card)


## Hands over the node of the card with this id, which leaves the hand: the row closes up.
## The node is still where it lay; whoever takes it moves it (ArenaTravel.take). Null if the
## hand has no such card.
func give(id: int) -> ArenaCard:
	var card := card_of(id)
	if card == null:
		return null
	_stop(card)
	_cards.erase(card)
	card.chosen = false
	card.dimmed = false
	card.set_tag("")
	card.strip = 0.0
	card.foot_strip = 0.0
	card.set_meta("away", true)
	_fit_titles()
	for other in _cards:
		_move(other, SLIDE_TIME)
	return card


## Makes room in the row for a card on its way to the hand: `card` is its node, wherever it
## is, and `entry` its entry of RulesView.table().hand. The row opens at its place. Returns
## where it is to land: {centre (on the page), turn (degrees), size}. Call `settle` when it is
## there.
func take_in(card: ArenaCard, entry: Dictionary, hyde_has_table: bool) -> Dictionary:
	var lies_face_down := card.face_down
	card.show_entry(entry, hyde_has_table)
	card.face_down = lies_face_down
	card.dimmed = not entry.get("playable", true)
	card.chosen = false
	_give_metas(card)
	card.set_meta("rank", _rank(entry))
	card.set_meta("away", true)
	var at := 0
	while at < _cards.size() and int(_cards[at].get_meta("rank")) < int(card.get_meta("rank")):
		at += 1
	_cards.insert(at, card)
	_fit_titles()
	for other in _cards:
		if other != card:
			_move(other, SLIDE_TIME)
	return _rest_place(card)


## A card that `take_in` made room for has arrived: it lies in the row from now on.
func settle(card: ArenaCard) -> void:
	if not is_instance_valid(card) or not _away(card) or not card in _cards:
		return
	card.set_meta("away", false)
	if card.get_parent() != self:
		if card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)
	card.scale = Vector2(CARD_SCALE, CARD_SCALE)
	card.face_down = false
	card.position = _place(card)
	card.rotation_degrees = _turn(card)
	_restack()
	_fit_titles()


## The table changes hands while the cards lie in the row: each takes the face `entry_of`
## (called with a card's id, returning its entry of RulesView.table().hand) gives it, a
## Factor turning over to the other man's, and the cards he cannot play are printed dark.
func turn_to(entry_of: Callable, hyde_has_table: bool) -> void:
	is_jekyll = not hyde_has_table
	for card in _cards:
		var entry: Dictionary = entry_of.call(card.card_id)
		if card.ink != (entry.ink or (entry.t == "factor" and hyde_has_table)):
			card.change_face(card.show_entry.bind(entry, hyde_has_table), not _still)
		else:
			card.show_entry(entry, hyde_has_table)
		card.dimmed = not entry.get("playable", true)
		card.set_tag("")


## Raises every card of the hand, or lets them down again.
func lift(on: bool) -> void:
	_lifted = on
	for card in _cards:
		_move(card, RISE_TIME)


## Empties the hand at once.
func clear() -> void:
	_lifted = false
	for card in _cards:
		_stop(card)
		card.queue_free()
	_cards.clear()


## The ids of the chosen cards, in the hand's order.
func chosen() -> Array:
	var ids: Array = []
	for card in _cards:
		if card.chosen:
			ids.append(card.card_id)
	return ids


## Lets every chosen card go.
func clear_chosen() -> void:
	var any := false
	for card in _cards:
		any = any or card.chosen
		card.chosen = false
		_move(card, RISE_TIME)
	_fit_titles()
	if any:
		chosen_changed.emit(chosen())


## Puts every card where it belongs at once, without the move there.
func snap() -> void:
	_fit_titles()
	for card in _cards:
		if _away(card):
			continue
		_stop(card)
		card.position = _place(card)
		card.rotation_degrees = _turn(card)
		card.scale = Vector2.ONE * _size(card)


## Marks each card with what the table says of it.
func _mark(table: Dictionary, entries: Array) -> void:
	var play: Variant = table.play
	var turning := {}
	var best := -1
	if play != null and play.ok:
		best = play.best_root
		for turn: Dictionary in play.turns:
			turning[turn.id] = turn.gain
	for i in _cards.size():
		var card := _cards[i]
		var entry: Dictionary = entries[i]
		card.dimmed = not entry.playable
		if turning.has(card.card_id):
			card.set_tag("turning +%d" % turning[card.card_id], true)
		elif card.card_id == best:
			card.set_tag("best")
		elif entry.turnable:
			card.set_tag("turns +%d" % table.symbols[entry.key].craving)
		else:
			card.set_tag("")


func _new_card() -> ArenaCard:
	var card := ArenaCard.new()
	card.scale = Vector2(CARD_SCALE, CARD_SCALE)
	_give_metas(card)
	add_child(card)
	return card


## What the hand keeps on each of its cards: how it lies askew, how far out of true it goes
## for Hyde, whether the pointer has raised it, and whether it is away (travelling).
func _give_metas(card: ArenaCard) -> void:
	card.set_meta("askew", Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.5, 1.5)))
	card.set_meta("unruly", Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)) * UNRULY)
	card.set_meta("raised", false)
	card.set_meta("away", false)


func _away(card: ArenaCard) -> bool:
	return card.get_meta("away", false)


## A card's place in the fixed order: Paper Roots, Ink Roots, Factors, each by symbol or
## kind, then by id.
static func _rank(entry: Dictionary) -> int:
	var group := 2 if entry.t == "factor" else (1 if entry.ink else 0)
	return (group * 16 + KEY_ORDER.find(entry.key)) * 100000 + int(entry.id)


func _sorted(entries: Array) -> Array:
	var out := entries.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank(a) < _rank(b))
	return out


## Puts the nodes of the cards that lie in the row in the row's order, so that each overlaps
## the one before it, and the one under the pointer on top of them all.
func _restack() -> void:
	var at := 0
	for card in _cards:
		if card.get_parent() == self:
			move_child(card, at)
			at += 1
	for card in _cards:
		if card.get_parent() == self and card.get_meta("raised"):
			move_child(card, at - 1)


## Tells each card how much of it shows: all of the last card of the row and of the one under
## the pointer, and of every other as much as the next card leaves uncovered. A chosen card
## has risen clear of the cards that are not by its title: that title has the room up to the
## next chosen card.
func _fit_titles() -> void:
	var a_card := _pitch() / CARD_SCALE
	for i in _cards.size():
		var card := _cards[i]
		var next := i + 1
		if card.chosen:
			while next < _cards.size() and not _cards[next].chosen and not _cards[next].get_meta("raised"):
				next += 1
		var shows := (next - i) * a_card - 2.0
		var whole: bool = next >= _cards.size() or card.get_meta("raised") or shows >= ArenaCard.SIZE.x
		card.strip = 0.0 if whole else shows
		var covered: bool = i < _cards.size() - 1 and not card.get_meta("raised") and a_card < ArenaCard.SIZE.x
		card.foot_strip = a_card - 2.0 if covered else 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer_here = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_here = false


func _process(_delta: float) -> void:
	var under := _card_under(get_local_mouse_position()) if _pointer_here else null
	if under != _resting:
		_resting = under
		if under and enabled:
			Sfx.play_sided("hover", Sfx.vary(), 0.35)
	var changed := false
	for card in _cards:
		if _away(card):
			continue
		if card.get_meta("raised") != (card == under):
			card.set_meta("raised", card == under)
			changed = true
			_move(card, RISE_TIME)
	if changed:
		_restack()
		_fit_titles()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if not enabled or not button or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var card := _card_under(get_local_mouse_position())
	if card == null:
		return
	get_viewport().set_input_as_handled()
	_sound(toggle(card.card_id))


## Chooses the card with this id, or lets it go if it is chosen. One more than `max_chosen`
## is refused: the card shakes and nothing changes. Silent: says what came of it, "chosen",
## "put_back" or "refused", or "" if the hand has no such card.
func toggle(id: int) -> String:
	for card in _cards:
		if card.card_id != id or _away(card):
			continue
		if not card.chosen and chosen().size() >= max_chosen:
			_shake(card)
			return "refused"
		card.chosen = not card.chosen
		_fit_titles()
		_move(card, RISE_TIME)
		chosen_changed.emit(chosen())
		return "chosen" if card.chosen else "put_back"
	return ""


## Chooses the card at this place in the row (from 0), or lets it go: for the number keys.
func toggle_at(place: int) -> void:
	if enabled and place >= 0 and place < _cards.size():
		toggle(_cards[place].card_id)


## The player pressed the number key for this place in the row (from 0): as `toggle_at`, with
## its sound, and refused when no card is there.
func press_at(place: int) -> void:
	if not enabled:
		return
	_sound(toggle(_cards[place].card_id) if place >= 0 and place < _cards.size() else "refused")


## The player lets every chosen card go (Esc): as `clear_chosen`, put back with one sound.
func put_back_all() -> void:
	if enabled and not chosen().is_empty():
		Sfx.play_sided("put_back", Sfx.vary(0.04), 0.7)
	clear_chosen()


# The sound of what a toggle by the player came to.
func _sound(outcome: String) -> void:
	match outcome:
		"chosen":
			Sfx.play_sided("choose", Sfx.vary(0.04), 0.7)
		"put_back":
			Sfx.play_sided("put_back", Sfx.vary(0.04), 0.7)
		"refused", "":
			Sfx.play("refuse")


## The card the pointer is on, or null: the topmost one whose place in the row holds the
## point. A card's place stays where it is, turned as the card lies, while the card rises, so
## a card cannot rise away from the pointer and drop again. A raised or chosen card also keeps the pointer for as far as it has risen, where no card's place is.
func _card_under(point: Vector2) -> ArenaCard:
	var half := ArenaCard.SIZE * CARD_SCALE * 0.5
	# First the places at rest, the topmost first: they alone decide between two cards.
	for i in range(_cards.size() - 1, -1, -1):
		var card := _cards[i]
		if _away(card):
			continue
		var rest := _covers(_rest(card))
		# The point as the card at rest sees it: the card is turned about its middle.
		var seen := (point - rest.get_center()).rotated(-deg_to_rad(_rest_turn(card)))
		if absf(seen.x) <= half.x and absf(seen.y) <= half.y:
			return card
	# Then the room a raised or chosen card has risen into, over no card's place.
	for i in range(_cards.size() - 1, -1, -1):
		var card := _cards[i]
		if _away(card) or not (_raised(card) or card.chosen):
			continue
		if _covers(_rest(card)).merge(_covers(_place(card))).has_point(point):
			return card
	return null


## What a card whose top left corner is at `at` covers, lying straight: it is drawn larger
## than its own size, about its middle.
func _covers(at: Vector2) -> Rect2:
	var extent := ArenaCard.SIZE * CARD_SCALE
	return Rect2(at + ArenaCard.SIZE * 0.5 - extent * 0.5, extent)


## The hand's place on the page.
func _zone() -> Rect2:
	return place if place.has_area() else ArenaLayout.hand(size)


## Where a card rests in the row, as ArenaTravel takes a place.
func _rest_place(card: ArenaCard) -> Dictionary:
	return {"centre": get_global_transform() * (_rest(card) + card.pivot_offset), "turn": _rest_turn(card),
			"size": CARD_SCALE}


func _raised(card: ArenaCard) -> bool:
	return _lifted or card.get_meta("raised")


## The distance between one card's centre and the next: the row tightens when it holds more
## cards than fit.
func _pitch() -> float:
	var room := _zone().size.x - ArenaCard.SIZE.x * CARD_SCALE
	return minf(PITCH, room / maxf(1.0, _cards.size() - 1))


## How far a card is from the middle of the row: -1 at the left end, 1 at the right.
func _outward(card: ArenaCard) -> float:
	return (_cards.find(card) - (_cards.size() - 1) * 0.5) / maxf(1.0, (_cards.size() - 1) * 0.5)


## Where a card's top left corner lies.
func _place(card: ArenaCard) -> Vector2:
	if card.chosen:
		return _slot(card) - Vector2(0.0, CHOSEN_RISE + (RISE * 0.25 if _raised(card) else 0.0))
	return _slot(card) - Vector2(0.0, RISE) if _raised(card) else _rest(card)


## How large a card is drawn, against its own size.
func _size(card: ArenaCard) -> float:
	return CARD_SCALE


## A card's place in a row that is level and true: its top, as it is drawn, along the zone's.
func _slot(card: ArenaCard) -> Vector2:
	var zone := _zone()
	var middle := Vector2(zone.get_center().x + (_cards.find(card) - (_cards.size() - 1) * 0.5) * _pitch(),
			zone.position.y + ArenaCard.SIZE.y * CARD_SCALE * 0.5)
	return middle - ArenaCard.SIZE * 0.5


## Where a card's top left corner lies while the card is neither raised nor chosen.
func _rest(card: ArenaCard) -> Vector2:
	var askew: Vector2 = card.get_meta("askew")
	var outward := _outward(card)
	var place := _slot(card) + Vector2(0.0, outward * outward * FAN_DROP + askew.x)
	if not is_jekyll:
		var unruly: Vector3 = card.get_meta("unruly")
		place += Vector2(unruly.x, unruly.y)
	return place


func _turn(card: ArenaCard) -> float:
	return 0.0 if _raised(card) or card.chosen else _rest_turn(card)


## How far a card is turned while it is neither raised nor chosen, in degrees.
func _rest_turn(card: ArenaCard) -> float:
	var askew: Vector2 = card.get_meta("askew")
	var turn := _outward(card) * FAN_TURN + askew.y
	if not is_jekyll:
		turn += (card.get_meta("unruly") as Vector3).z
	return turn


func _stop(card: ArenaCard) -> void:
	var move: Tween = card.get_meta("move") if card.has_meta("move") else null
	if move:
		move.kill()


## Moves a card to where it belongs now, over `time` seconds.
func _move(card: ArenaCard, time: float) -> void:
	if _away(card):
		return
	_stop(card)
	var scaled := Vector2.ONE * _size(card)
	if _still or not is_inside_tree():
		card.position = _place(card)
		card.rotation_degrees = _turn(card)
		card.scale = scaled
		return
	var move := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	move.tween_property(card, "position", _place(card), time)
	move.tween_property(card, "rotation_degrees", _turn(card), time)
	# Its size is moved only when it is to change: a card that changes face closes and opens
	# meanwhile (ArenaCard.change_face), and its width is then that change's to move.
	if not card.scale.is_equal_approx(scaled):
		move.tween_property(card, "scale", scaled, time)
	card.set_meta("move", move)


## A card that cannot be chosen turns a little each way and settles.
func _shake(card: ArenaCard) -> void:
	_stop(card)
	var turn := _turn(card)
	var move := create_tween()
	for way: float in [1.0, -1.0, 0.5, 0.0]:
		move.tween_property(card, "rotation_degrees", turn + SHAKE * way, 0.05)
	card.set_meta("move", move)
