class_name ArenaStage
extends Control
## The stage for the laid play and for every moment that shows cards: the band between the
## readout and the lower rule (ArenaLayout.stage). It lays up to five cards there in a row,
## small (LAID_SCALE), and holds them still face up; the caption line over them
## (ArenaLayout.caption) says what is happening.
##
## A caption stays on the page for ArenaPace.CAPTION_MIN at least, counted at the queue's rate
## (a hurried caption goes sooner): `clear_caption` waits for what is left of it.

## The most cards laid in the row, the room between two of them, in pixels, and how large a
## laid card is (1 is a card at its own size).
const MOST := 5
const GAP := 10.0
const LAID_SCALE := 0.7
## The caption's box: it may run to a second line, which then spreads above and below its zone.
const CAPTION_SIZE := Vector2(600.0, 48.0)
const CAPTION_COLOUR := Color(0.95, 0.9, 0.78)
const CAPTION_OUTLINE := Color(0.05, 0.035, 0.06, 0.9)

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
	_caption.add_theme_font_size_override("font_size", 19)
	_caption.add_theme_constant_override("line_spacing", -2)
	_caption.modulate.a = 0.0
	add_child(_caption)
	set_process(false)


func _ready() -> void:
	resized.connect(_place_caption)
	_place_caption()


## The centre, on the page, of the i-th of n cards laid in the row.
func slot(i: int, n: int) -> Vector2:
	n = clampi(n, 1, MOST)
	var middle := ArenaLayout.stage(size).get_center()
	var x := middle.x + (i - (n - 1) * 0.5) * (ArenaCard.SIZE.x * LAID_SCALE + GAP)
	return get_global_transform() * Vector2(x, middle.y)


## The centres of a row of n cards.
func slots(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		out.append(slot(i, n))
	return out


## Lays `cards` in the row, face up, each from where it lies. Returns the end of the last.
func lay(travel: ArenaTravel, cards: Array) -> Signal:
	return travel.fly_group(cards, slots(cards.size()), [], LAID_SCALE, ArenaTravel.UP)


## Puts a caption over the row. It replaces the one there, which is then cut short.
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
	_caption.position = ArenaLayout.caption(size).get_center() - CAPTION_SIZE * 0.5
	_caption.size = CAPTION_SIZE
