class_name ArenaPile
extends Control
## One pile of cards on the table, the draw pile or the discards: a small stack, as high as
## the pile is big, with its name and its count written on a dark label on the pile itself,
## so that they read on a card's back, on a face and on an empty place alike. An empty pile
## is a dashed outline.
##
## The draw pile lies square and face down. The discards lie a little askew, and keep the last
## few cards that landed on them face up on top. The pile shows `count`; it works out nothing.
## ArenaPiles moves cards on and off it.

## A card on a pile is this much smaller than in the hand.
const SCALE := 0.8
## The most layers drawn, and how many cards a layer stands for.
const LAYERS := 5
const PER_LAYER := 6
## How far each layer lies up and to the left of the one under it, in pixels.
const LAYER_STEP := Vector2(-2.0, -2.6)
## How many cards that landed face up stay on top of the discards.
const TOPS := 3
## The label on the pile.
const LABEL_SIZE := Vector2(56.0, 38.0)
## The label's border width.
const TAG_EDGE := 1.5

## Written on the label over the count.
@export var title := "Draw"
## True for the discards: askew, and the cards that land stay face up on top.
@export var messy := false
## Changes how the discards lie askew.
@export var rng_seed := 3

var count := 0:
	set(value):
		count = maxi(0, value)
		_lay_out()

var _layers: Array[ArenaCard] = []
var _tops: Array[ArenaCard] = []
var _tag := Control.new()
var _tag_label := Label.new()
var _tag_count := Label.new()
var _riffle: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ArenaCard.SIZE * SCALE
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.draw.connect(_draw_tag)
	_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_label.add_theme_color_override("font_color", Palette.CHALK_2)
	_tag_label.add_theme_font_size_override("font_size", 10)
	_tag_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_count.add_theme_color_override("font_color", Palette.CHALK)
	_tag_count.add_theme_font_size_override("font_size", 19)
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.8
	_tag_count.add_theme_font_override("font", heavy)
	_tag.add_child(_tag_label)
	_tag.add_child(_tag_count)
	add_child(_tag)


func _ready() -> void:
	_lay_out()


## The centre, on the page, of a card lying on top of the pile.
func top_centre() -> Vector2:
	return get_global_transform() * (size * 0.5 + LAYER_STEP * maxi(0, _layers.size() - 1))


## How far a card on top of the pile is turned, in degrees.
## On the discards each card lands a little askew its own way.
func top_turn() -> float:
	return _turn_of(count + 1) if messy else 0.0


## The card size on the pile, for ArenaTravel.
func card_scale() -> float:
	return SCALE


## A card node for the card `data` leaving the top of the pile: the face-up one that lies
## there if it is that card, else a new one, face down on the draw pile and face up on the
## discards. It is not yet in the tree, unless it was one of the tops: ArenaTravel takes it.
## The count is not changed here.
func lift(data: Dictionary) -> ArenaCard:
	for i in range(_tops.size() - 1, -1, -1):
		var top := _tops[i]
		if top.has_meta("data") and top.get_meta("data").get("id", -1) == data.get("id", -2):
			_tops.remove_at(i)
			return top
	var card := ArenaTravel.make_card(data)
	card.face_up = messy
	card.scale = Vector2(SCALE, SCALE)
	card.rotation_degrees = top_turn()
	card.position = top_centre() - card.pivot_offset # the page's coordinates, for `place`
	return card


## A card arrives on the pile. On the discards it stays face up on top; on the draw pile it
## is gone into the stack. The count is not changed here.
func land(card: ArenaCard) -> void:
	if not messy:
		card.queue_free()
		return
	var at := ArenaTravel.centre_of(card)
	card.get_parent().remove_child(card)
	add_child(card)
	move_child(card, _tag.get_index())
	card.scale = Vector2(SCALE, SCALE)
	card.position = get_global_transform().affine_inverse() * at - card.pivot_offset
	_tops.append(card)
	while _tops.size() > TOPS:
		_tops.pop_front().queue_free()


## Every card node the pile shows, taken off it (for the discards turning into a new draw
## pile): the caller moves them and frees them.
func take_all() -> Array[ArenaCard]:
	var out: Array[ArenaCard] = []
	out.append_array(_layers)
	out.append_array(_tops)
	_layers.clear()
	_tops.clear()
	return out


## A short riffle: the layers slip sideways and back one after another. `deep` is the longer
## one of a new draw pile. With reduce flashes on, a single small slip.
func riffle(beats: ArenaBeats, deep: bool = false) -> Signal:
	if _riffle and _riffle.is_valid():
		_riffle.kill()
	beats.sound("shuffle" if deep else "riffle", Sfx.vary(0.04))
	var t := beats.tween().set_parallel()
	var time := ArenaPace.RESHUFFLE_RIFFLE if deep else ArenaPace.RIFFLE
	var reach := 1.5 if ArenaPace.reduce_flashes else (6.0 if deep else 3.5)
	var passes := 1 if ArenaPace.reduce_flashes or not deep else 2
	# Each layer slips `passes` times, the next a little after the one under it, all within `time`.
	var each := time / (passes + 1.0)
	for i in _layers.size():
		var layer := _layers[i]
		var rest := _rest_of(i)
		var side := 1.0 if i % 2 == 0 else -1.0
		var delay := each * 0.5 * float(i) / maxf(1.0, _layers.size() - 1.0)
		var seq := beats.tween()
		seq.tween_interval(delay + 0.001)
		for p in passes:
			seq.tween_property(layer, "position", rest + Vector2(reach * side, 0.0), each * 0.5)
			seq.tween_property(layer, "position", rest - Vector2(reach * side * 0.4, 0.0), each * 0.5)
		seq.tween_property(layer, "position", rest, each * 0.5)
	t.tween_interval(time)
	_riffle = t
	return t.finished


func _lay_out() -> void:
	if not is_inside_tree():
		return
	var want := 0 if count == 0 else clampi(ceili(count / float(PER_LAYER)), 1, LAYERS)
	# The face-up tops stand for cards of the count too.
	want = maxi(0, want - (1 if _tops.size() > 0 and want > 1 else 0))
	while _tops.size() > count:
		_tops.pop_front().queue_free()
	while _layers.size() > want:
		_layers.pop_back().queue_free()
	while _layers.size() < want:
		var layer := ArenaCard.new()
		layer.rng_seed = rng_seed * 31 + _layers.size() * 5
		layer.face_up = false
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		move_child(layer, _layers.size())
		_layers.append(layer)
	for i in _layers.size():
		_layers[i].scale = Vector2(SCALE, SCALE)
		_layers[i].position = _rest_of(i)
		_layers[i].rotation_degrees = _turn_of(i)
	# The label lies on the lower part of the pile: the name, and under it the count.
	_tag_label.text = title
	_tag_count.text = str(count)
	_tag.size = LABEL_SIZE
	_tag.position = Vector2((size.x - LABEL_SIZE.x) * 0.5, size.y - LABEL_SIZE.y - 12.0)
	_tag_label.position = Vector2(0.0, 2.0)
	_tag_label.size = Vector2(LABEL_SIZE.x, 14.0)
	_tag_count.position = Vector2(0.0, 13.0)
	_tag_count.size = Vector2(LABEL_SIZE.x, LABEL_SIZE.y - 14.0)
	queue_redraw()
	_tag.queue_redraw()


## Where the i-th layer's top left corner lies, in the pile's own coordinates.
func _rest_of(i: int) -> Vector2:
	return size * 0.5 - ArenaCard.SIZE * 0.5 + LAYER_STEP * i


func _turn_of(i: int) -> float:
	if not messy:
		return 0.0
	return sin(float(rng_seed * 13 + i * 7)) * 6.0


func _draw() -> void:
	if count > 0:
		return
	# An empty pile: a dashed outline where it lies.
	var rect := Rect2(Vector2.ZERO, size).grow(-2.0)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], Palette.CHALK_3, 1.5, 6.0)


func _draw_tag() -> void:
	var rect := Rect2(Vector2.ZERO, _tag.size)
	_tag.draw_rect(rect, Palette.NIGHT_2)
	_tag.draw_rect(rect.grow(-TAG_EDGE * 0.5), Palette.RULE, false, TAG_EDGE)
