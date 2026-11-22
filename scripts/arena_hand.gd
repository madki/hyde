class_name ArenaHand
extends Control
## The hand of cards on the arena's table: a row in a shallow arc across the lower part of
## the table, each card overlapping the next a little, with room left under it and at the
## right. The card under the pointer rises and straightens. While Hyde has the table the row
## is a little out of true: each card is pushed and turned a little its own way.
##
## For now it holds sample cards, to settle their look: the three paper Roots, the three ink
## Roots, and a Factor, which takes the name and the look of the man at the table.

## Each sample: [paper title, ink title, picture, chips, side], where side is "paper", "ink",
## or "table" for a Factor. The picture is the name of a line drawing in PICTURES; a card
## whose drawing is not there yet is shown without one.
const SAMPLES := [
	["Composure", "Fog", "lamp", 1, "paper"],
	["Kindness", "Appetite", "heart", 1, "paper"],
	["Composure", "Fog", "fog", 2, "ink"],
	["Scruple", "Pride", "mirror", 2, "paper"],
	["Kindness", "Appetite", "apple", 3, "ink"],
	["Scruple", "Pride", "mirror", 3, "ink"],
	["Good Cheer", "Glee", "cup", 4, "table"],
]
const PICTURES := "res://art/cards/placeholder_%s.svg"
## Distance between one card's centre and the next, in pixels.
const PITCH := 90.0
## How far the row's ends turn, in degrees, and how far they drop, in pixels.
const FAN_TURN := 5.0
const FAN_DROP := 12.0
## How far out of true a card may be while Hyde has the table: across, up or down (in pixels)
## and turned (in degrees). And the time the row takes to go out of true or back.
const UNRULY := Vector3(3.0, 6.0, 3.0)
const UNRULY_TIME := 0.25
## How far a card rises under the pointer, in pixels, and the time it takes.
const RISE := 16.0
const RISE_TIME := 0.12

## Where the table begins, from the page's left edge, and the room kept free at its right and
## under the hand, all in pixels.
@export var table_left := 0.0
@export var room_right := 190.0
@export var room_under := 120.0

## Who has the table: a Factor follows it.
var is_jekyll := true:
	set(value):
		if value == is_jekyll:
			return
		is_jekyll = value
		_show_samples()
		for i in _cards.size():
			_move(i, UNRULY_TIME)

var _cards: Array[ArenaCard] = []
var _raised: Array[bool] = []
var _moves: Array[Tween] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in SAMPLES.size():
		var card := ArenaCard.new()
		card.rng_seed = i * 7 + 3
		card.set_meta("askew", Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-1.5, 1.5)))
		card.set_meta("unruly", Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)) * UNRULY)
		card.mouse_entered.connect(_raise.bind(i, true))
		card.mouse_exited.connect(_raise.bind(i, false))
		add_child(card)
		_cards.append(card)
		_raised.append(false)
		_moves.append(null)
	_show_samples()
	resized.connect(snap)
	snap()


func _show_samples() -> void:
	for i in _cards.size():
		var sample: Array = SAMPLES[i]
		var on_ink: bool = sample[4] == "ink" or (sample[4] == "table" and not is_jekyll)
		var path: String = PICTURES % sample[2]
		var picture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		_cards[i].show_card(sample[1] if on_ink else sample[0], on_ink, picture, sample[3])


## Puts every card where it belongs at once, without the move there.
func snap() -> void:
	for i in _cards.size():
		if _moves[i]:
			_moves[i].kill()
		_cards[i].position = _place(i)
		_cards[i].rotation_degrees = _turn(i)


## How far the i-th card is from the middle of the row: -1 at the left end, 1 at the right.
func _outward(i: int) -> float:
	return (i - (_cards.size() - 1) * 0.5) / maxf(1.0, (_cards.size() - 1) * 0.5)


## Where the i-th card's top left corner lies.
func _place(i: int) -> Vector2:
	var askew: Vector2 = _cards[i].get_meta("askew")
	var middle := (table_left + size.x - room_right) * 0.5
	var x := middle + (i - (_cards.size() - 1) * 0.5) * PITCH - ArenaCard.SIZE.x * 0.5
	var y := size.y - room_under - ArenaCard.SIZE.y
	if _raised[i]:
		return Vector2(x, y - RISE)
	var place := Vector2(x, y + _outward(i) * _outward(i) * FAN_DROP + askew.x)
	if not is_jekyll:
		var unruly: Vector3 = _cards[i].get_meta("unruly")
		place += Vector2(unruly.x, unruly.y)
	return place


func _turn(i: int) -> float:
	if _raised[i]:
		return 0.0
	var askew: Vector2 = _cards[i].get_meta("askew")
	var turn := _outward(i) * FAN_TURN + askew.y
	if not is_jekyll:
		turn += (_cards[i].get_meta("unruly") as Vector3).z
	return turn


func _raise(i: int, up: bool) -> void:
	_raised[i] = up
	_move(i, RISE_TIME)


## Moves the i-th card to where it belongs now, over `time` seconds.
func _move(i: int, time: float) -> void:
	if _moves[i]:
		_moves[i].kill()
	_moves[i] = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_moves[i].tween_property(_cards[i], "position", _place(i), time)
	_moves[i].tween_property(_cards[i], "rotation_degrees", _turn(i), time)
