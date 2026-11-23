class_name ArenaStage
extends Control
## The centre of the table, kept empty: the stage for the laid play and for every moment that
## shows cards. It lays up to five cards in a row in the middle and holds them still face up,
## with one caption line above them that says what is happening.
##
## A caption stays on the page for ArenaPace.CAPTION_MIN at least, counted at the queue's rate
## (a hurried caption goes sooner): `clear_caption` waits for what is left of it.

## The most cards laid in the row, and the room between two of them, in pixels.
const MOST := 5
const GAP := 14.0
const CAPTION_COLOUR := Color(0.95, 0.9, 0.78)
const CAPTION_OUTLINE := Color(0.05, 0.035, 0.06, 0.9)

## The table's span: where it begins from the page's left edge, the room kept free at its
## right, and the height of the row's middle from the top. As in ArenaHand.
@export var table_left := 295.0
@export var room_right := 190.0
@export var row_y := 262.0

var beats: ArenaBeats

var _caption := Label.new()
var _caption_age := -1.0
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color", CAPTION_COLOUR)
	_caption.add_theme_color_override("font_outline_color", CAPTION_OUTLINE)
	_caption.add_theme_constant_override("outline_size", 7)
	_caption.add_theme_font_size_override("font_size", 21)
	_caption.modulate.a = 0.0
	add_child(_caption)
	set_process(false)


func _ready() -> void:
	resized.connect(_place_caption)
	_place_caption()


## The centre, on the page, of the i-th of n cards laid in the row.
func slot(i: int, n: int) -> Vector2:
	n = clampi(n, 1, MOST)
	var middle := (table_left + size.x - room_right) * 0.5
	var x := middle + (i - (n - 1) * 0.5) * (ArenaCard.SIZE.x + GAP)
	return get_global_transform() * Vector2(x, row_y)


## The centres of a row of n cards.
func slots(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		out.append(slot(i, n))
	return out


## Lays `cards` in the row, face up, each from where it lies. Returns the end of the last.
func lay(travel: ArenaTravel, cards: Array) -> Signal:
	return travel.fly_group(cards, slots(cards.size()), [], 1.0, ArenaTravel.UP)


## Puts a caption above the row. It replaces the one there, which is then cut short.
func show_caption(text: String) -> void:
	_caption.text = text
	_caption_age = 0.0
	set_process(true)
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = beats.tween()
	_fade.tween_property(_caption, "modulate:a", 1.0, ArenaPace.CAPTION_FADE)


## Takes the caption away, once it has been on the page for ArenaPace.CAPTION_MIN. Await it.
func clear_caption() -> void:
	if _caption_age < 0.0:
		return
	var left := ArenaPace.CAPTION_MIN - _caption_age
	if left > 0.0:
		await beats.wait(left)
	_caption_age = -1.0
	set_process(false)
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = beats.tween()
	_fade.tween_property(_caption, "modulate:a", 0.0, ArenaPace.CAPTION_FADE)
	await _fade.finished


## The caption on the page now, "" when there is none.
func caption() -> String:
	return _caption.text if _caption_age >= 0.0 else ""


func _process(delta: float) -> void:
	if _caption_age >= 0.0:
		_caption_age += delta * (beats.rate() if beats else 1.0)


func _place_caption() -> void:
	var left := table_left + 20.0
	var width := size.x - room_right - 20.0 - left
	_caption.position = Vector2(left, row_y - ArenaCard.SIZE.y * 0.5 - 64.0)
	_caption.size = Vector2(width, 48.0)
