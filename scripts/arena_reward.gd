class_name ArenaReward
extends Control
## The reward after a round won as Jekyll: three cards lie face up on the stage, laid larger
## than their own size so that each is read where it lies, and the player takes one, or none.
## A click takes the card under the pointer; "Take none" is a button under the lower rule
## (ArenaLayout.reward_none). The keys 1 to 3 take a card too, and 0 or Esc takes none.
##
## A card the pointer rests on (ArenaViews.REST seconds, still) has its note, the hand's
## (ArenaCardNote): what it is and what it is worth now. The caption lies on the row's top,
## so the note opens under "Take none", in the hand's zone, which is empty then, at the page's
## middle whichever card it is of. With `--shot`, `--reward_note=<place>` (from 0) holds the
## note of that card open, for the still.
##
## It only asks: `offer` the card nodes (they stay where they lie, on the layer cards travel
## on) with their notes' words, and await `chosen`, which gives the place of the card taken,
## or -1 for none.

signal chosen(index: int)

## How large the card under the pointer is shown: as large as a reward's cards are laid, so
## that none grows.
const READ_SCALE := ArenaStage.REWARD_SCALE
## The gap between the note and "Take none" above it, and the page's edges.
const NOTE_GAP := 8.0

## True while the player is choosing.
var waiting := false
## True while a notice, the help book or the piles' view lies over the page (ArenaViews):
## no note opens, and one that is open closes. The pointer must rest anew once it lifts.
var covered := false:
	set(value):
		covered = value
		if covered:
			_note_wait = -1
			_close_note()

var _cards: Array = []
## Where each card lies at rest: its position and its scale.
var _rest: Array[Vector3] = []
var _shown := -1
var _none := Button.new()
## Each card's note's words, in the cards' order.
var _notes: Array = []
var _note := ArenaCardNote.new()
## The place of the card whose note is open, the card the pointer rests on, and for how
## much longer it must rest before the note opens.
var _noted := -1
var _note_wait := -1
var _note_left := 0.0
var _note_point := Vector2.INF
## The place of the card whose note `--reward_note` holds open, or -1.
var _forced_note := int(Shot.arg("reward_note")) if Shot.has_arg("shot") and Shot.has_arg("reward_note") else -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	_none.text = "Take none"
	_none.focus_mode = Control.FOCUS_NONE
	_none.visible = false
	_none.add_theme_font_override("font", font)
	_none.add_theme_font_size_override("font_size", 17)
	ArenaControls.dress_dark(_none)
	_none.pressed.connect(_pick_by_player.bind(-1))
	add_child(_none)
	add_child(_note)
	set_process(false)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


## Offers these card nodes, which already lie face up in a row, with each one's note.
func offer(cards: Array, notes: Array = []) -> void:
	_cards = cards
	_notes = notes
	_rest.clear()
	_shown = -1
	_close_note()
	for card: ArenaCard in cards:
		_rest.append(Vector3(card.position.x, card.position.y, card.scale.y))
	_lay_out()
	_none.visible = true
	waiting = true
	set_process(true)


## Takes the card at `index`, or none with -1. False if it cannot be taken.
func pick(index: int) -> bool:
	if not waiting or index >= _cards.size():
		return false
	waiting = false
	set_process(false)
	_none.visible = false
	_show(-1)
	_close_note()
	_note_wait = -1
	_cards = []
	chosen.emit(index)
	return true


func _process(delta: float) -> void:
	if _forced_note >= 0 and _forced_note < _cards.size():
		_show(_forced_note)
		_open_note(_forced_note)
		return
	var under := _under()
	_show(under)
	_follow_note(under, delta)


func _lay_out() -> void:
	var zone := ArenaLayout.reward_none(size)
	_none.position = zone.position
	_none.size = zone.size
	_place_note()


# Shows the card at `index` at READ_SCALE, its foot where it was, and the others as they lie.
func _show(index: int) -> void:
	if index == _shown:
		return
	if index >= 0:
		Sfx.play("hover_j", Sfx.vary(), 0.35)
	_shown = index
	for i in _cards.size():
		var card: ArenaCard = _cards[i]
		var size_now := maxf(READ_SCALE, _rest[i].z) if i == index else _rest[i].z
		card.scale = Vector2(size_now, size_now)
		card.position = Vector2(_rest[i].x, _rest[i].y - (size_now - _rest[i].z) * ArenaCard.SIZE.y * 0.5)
		if i == index:
			card.get_parent().move_child(card, -1)


func _unhandled_input(event: InputEvent) -> void:
	if not waiting:
		return
	var button := event as InputEventMouseButton
	var key := event as InputEventKey
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var under := _under()
		if under >= 0:
			get_viewport().set_input_as_handled()
			_pick_by_player(under)
	elif key and key.pressed and not key.echo:
		if key.keycode >= KEY_1 and key.keycode <= KEY_3:
			get_viewport().set_input_as_handled()
			_pick_by_player(key.keycode - KEY_1)
		elif key.keycode in [KEY_0, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			_pick_by_player(-1)


# The player picks: `pick`, with the button's sound, or refused when there is no such card.
func _pick_by_player(index: int) -> void:
	Sfx.play("button" if pick(index) else "refuse")


# The place of the card under the pointer, or -1.
func _under() -> int:
	var point := get_global_mouse_position()
	# The card shown large keeps the pointer over all it covers; else the card whose place
	# at rest holds the point.
	for i in [_shown] + range(_cards.size()):
		if i < 0:
			continue
		var card: ArenaCard = _cards[i]
		var extent := ArenaCard.SIZE * (card.scale.y if i == _shown else _rest[i].z)
		var middle: Vector2 = card.get_parent().get_global_transform() * (card.position + card.pivot_offset)
		if i != _shown:
			middle = card.get_parent().get_global_transform() * (Vector2(_rest[i].x, _rest[i].y) + card.pivot_offset)
		if Rect2(middle - extent * 0.5, extent).has_point(point):
			return i
	return -1


# Each frame: the note of the card under the pointer opens once the pointer has rested on it,
# and closes when the pointer leaves it, a key is held to look or the page is covered.
func _follow_note(under: int, delta: float) -> void:
	var point := get_global_mouse_position()
	var looking := false
	for key: Key in ArenaBeats.LOOK_KEYS:
		looking = looking or Input.is_key_pressed(key)
	if under < 0 or looking or covered:
		_note_wait = -1
		_close_note()
	elif under != _noted:
		_close_note()
		if under != _note_wait or point.distance_squared_to(_note_point) > 0.25:
			_note_wait = under
			_note_left = ArenaViews.REST
		_note_left -= delta
		if _note_left <= 0.0:
			_open_note(under)
	_note_point = point


func _open_note(index: int) -> void:
	if index == _noted:
		return
	var words: String = _notes[index] if index < _notes.size() else ""
	if words == "":
		_close_note()
		return
	_noted = index
	_note.say(words)
	move_child(_note, -1)
	_note.visible = true
	_place_note()


func _close_note() -> void:
	_noted = -1
	_note.visible = false


# Under "Take none", at the page's middle wherever the card is, clear of the caption and of
# every card's title; kept on the page.
func _place_note() -> void:
	if _noted < 0:
		return
	var none := ArenaLayout.reward_none(size)
	var extent := _note.size
	var x := clampf(none.get_center().x - extent.x * 0.5, NOTE_GAP, maxf(NOTE_GAP, size.x - extent.x - NOTE_GAP))
	var y := minf(none.end.y + NOTE_GAP, size.y - NOTE_GAP - extent.y)
	_note.position = Vector2(x, y)
