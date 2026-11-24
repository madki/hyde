class_name ArenaReward
extends Control
## The reward after a round won as Jekyll: three cards lie face up in the centre band, small
## as every card laid there, and the player takes one, or none. The card under the pointer
## grows to its own size, over the others, to be read; a click takes it. The keys 1 to 3 take
## a card too, and 0 or Esc takes none.
##
## It only asks: `offer` the card nodes (they stay where they lie, on the layer cards travel
## on) and await `chosen`, which gives the place of the card taken, or -1 for none.

signal chosen(index: int)

## How large the card under the pointer is shown.
const READ_SCALE := 1.0
const CREAM := Color(0.93, 0.88, 0.75)
const PENCIL := Color(0.08, 0.05, 0.04)

## True while the player is choosing.
var waiting := false

var _cards: Array = []
## Where each card lies at rest: its position and its scale.
var _rest: Array[Vector3] = []
var _shown := -1
var _none := Button.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	_none.text = "Take none"
	_none.size = Vector2(124.0, 34.0)
	_none.focus_mode = Control.FOCUS_NONE
	_none.visible = false
	_none.add_theme_font_override("font", font)
	_none.add_theme_font_size_override("font_size", 15)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_none.add_theme_color_override(state, PENCIL)
	for state: String in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = CREAM if state == "normal" else CREAM.lightened(0.3)
		box.border_color = PENCIL
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		_none.add_theme_stylebox_override(state, box)
	_none.pressed.connect(pick.bind(-1))
	add_child(_none)
	set_process(false)


## Offers these card nodes, which already lie face up in a row. `under` is the point on the
## page under the row's middle, where "Take none" is put.
func offer(cards: Array, under: Vector2) -> void:
	_cards = cards
	_rest.clear()
	_shown = -1
	for card: ArenaCard in cards:
		_rest.append(Vector3(card.position.x, card.position.y, card.scale.y))
	_none.position = get_global_transform().affine_inverse() * under - Vector2(_none.size.x * 0.5, 0.0)
	_none.visible = true
	waiting = true
	set_process(true)


## Takes the card at `index`, or none with -1.
func pick(index: int) -> void:
	if not waiting or index >= _cards.size():
		return
	waiting = false
	set_process(false)
	_none.visible = false
	_show(-1)
	_cards = []
	chosen.emit(index)


func _process(_delta: float) -> void:
	_show(_under())


# Shows the card at `index` large, its foot where it was, and the others as they lie.
func _show(index: int) -> void:
	if index == _shown:
		return
	_shown = index
	for i in _cards.size():
		var card: ArenaCard = _cards[i]
		var size_now := READ_SCALE if i == index else _rest[i].z
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
			pick(under)
	elif key and key.pressed and not key.echo:
		if key.keycode >= KEY_1 and key.keycode <= KEY_3:
			get_viewport().set_input_as_handled()
			pick(key.keycode - KEY_1)
		elif key.keycode in [KEY_0, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			pick(-1)


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
