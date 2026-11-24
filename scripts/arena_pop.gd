class_name ArenaPop
extends Control
## The small things that rise from a card while a play scores: a number ("+15", "+2 mult")
## or a few words that lift off the card that gives them and fade, a card's hop as it
## scores, and the eye mark of Curiosity and Impulse, which flies to the draw pile and waits
## there for the card it draws.
##
## Everything here plays through the beat queue, so it is hurried with the rest. Nothing is
## awaited: a pop is seen alongside the tick it belongs to.

const CREAM := Palette.CHALK
const CYAN := Palette.JEKYLL
const MAGENTA := Palette.HYDE
const OUTLINE := Color(Palette.OUTLINE, 0.9)
## How far a number rises, in pixels, and how long it is on the page.
const RISE := 30.0
const TIME := 0.55
## How far a card hops, in pixels, and how long the hop takes.
const HOP := 14.0
const HOP_TIME := 0.2

static var _font: FontVariation

## True for a mark that is a sovereign, not an eye.
var _coin := false


## The colour of the man who scores.
static func man(hyde: bool) -> Color:
	return MAGENTA if hyde else CYAN


## `text` rises from `at` (a point on the page) on `layer` and fades.
static func text(beats: ArenaBeats, layer: Control, at: Vector2, words: String, colour: Color,
		font_size: int = 20) -> void:
	var label := _label(layer, at, words, colour, font_size)
	var t := beats.tween()
	t.tween_property(label, "position:y", label.position.y - RISE, TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(label, "modulate", Color(CREAM, 0.0), TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(label.queue_free)


## `words` travel from `from` to `to` (points on the page) over `time` and are gone: what a
## gauge pays, from its sketch into the mult.
static func fly_text(beats: ArenaBeats, layer: Control, from: Vector2, to: Vector2, words: String,
		colour: Color, time: float) -> void:
	var label := _label(layer, from, words, colour, 20)
	var end: Vector2 = layer.get_global_transform().affine_inverse() * to - label.size * 0.5
	var t := beats.tween()
	t.tween_interval(time * 0.25)
	t.tween_property(label, "position", end, time * 0.75).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(label.queue_free)


static func _label(layer: Control, at: Vector2, words: String, colour: Color, font_size: int) -> Label:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	label.size = label.get_minimum_size()
	label.position = layer.get_global_transform().affine_inverse() * at - label.size * 0.5
	return label


## A card hops where it lies, as it scores.
static func hop(beats: ArenaBeats, card: Control) -> void:
	if not is_instance_valid(card):
		return
	var rest: float = card.get_meta("hop_rest") if card.has_meta("hop_rest") else card.position.y
	card.set_meta("hop_rest", rest)
	card.position.y = rest
	var t := beats.tween()
	t.tween_property(card, "position:y", rest - HOP, HOP_TIME * 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(card, "position:y", rest, HOP_TIME * 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## A sovereign travels from `from` to `to` (points on the page) and is gone. Await it.
static func coin(beats: ArenaBeats, layer: Control, from: Vector2, to: Vector2,
		time: float = 0.28) -> void:
	var mark := eye(layer, from)
	mark._coin = true
	mark.queue_redraw()
	await mark.fly_to(beats, to, time)
	mark.queue_free()


## A new eye mark on `layer`, its middle at `at` (a point on the page).
static func eye(layer: Control, at: Vector2) -> ArenaPop:
	var mark := ArenaPop.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(30.0, 22.0)
	mark.pivot_offset = mark.size * 0.5
	layer.add_child(mark)
	mark.position = layer.get_global_transform().affine_inverse() * at - mark.size * 0.5
	return mark


## Sends this mark to `at` (a point on the page). Returns the end of the move.
func fly_to(beats: ArenaBeats, at: Vector2, time: float = ArenaPace.TRAVEL * 1.5) -> Signal:
	var to: Vector2 = (get_parent() as Control).get_global_transform().affine_inverse() * at - size * 0.5
	var t := beats.tween()
	t.tween_property(self, "position", to, time).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	return t.finished


## The mark fades and is gone.
func fade(beats: ArenaBeats) -> void:
	var t := beats.tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


# The eye: a cream tag with an eye drawn on it in pencil.
func _draw() -> void:
	var middle := size * 0.5
	if _coin:
		draw_circle(middle, 8.5, Palette.OUTLINE)
		draw_circle(middle, 7.0, Palette.GOLD)
		draw_arc(middle, 4.6, 0.0, TAU, 16, Palette.GOLD.darkened(0.35), 1.0)
		return
	draw_set_transform(middle, 0.0, Vector2(1.0, 0.72))
	draw_circle(Vector2.ZERO, 15.0, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, 13.4, Palette.CHALK)
	draw_set_transform(middle, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 24, Palette.OUTLINE, 1.6)
	draw_set_transform(middle, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 3.2, Palette.OUTLINE)
