class_name ArenaPop
extends Control
## The small things that rise from a card while a play scores: a number ("+15", "+2 mult")
## or a few words that lift off the card that gives them and fade, a card's hop as it
## scores, and the eye mark of Curiosity and Impulse, which flies to the draw pile and waits
## there for the card it draws.
##
## Everything here plays through the beat queue, so it is hurried with the rest. Nothing is
## awaited: a pop is seen alongside the tick it belongs to.

const CREAM := Color(0.95, 0.9, 0.78)
const CYAN := Color(0.36, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.34, 0.78)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)
## How far a number rises, in pixels, and how long it is on the page.
const RISE := 30.0
const TIME := 0.55
## How far a card hops, in pixels, and how long the hop takes.
const HOP := 14.0
const HOP_TIME := 0.2

static var _font: FontVariation


## The colour of the man who scores.
static func man(hyde: bool) -> Color:
	return MAGENTA if hyde else CYAN


## `text` rises from `at` (a point on the page) on `layer` and fades.
static func text(beats: ArenaBeats, layer: Control, at: Vector2, words: String, colour: Color,
		font_size: int = 20) -> void:
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
	var t := beats.tween()
	t.tween_property(label, "position:y", label.position.y - RISE, TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(label, "modulate", Color(CREAM, 0.0), TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(label.queue_free)


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
	draw_set_transform(middle, 0.0, Vector2(1.0, 0.72))
	draw_circle(Vector2.ZERO, 15.0, Color(0.08, 0.05, 0.04))
	draw_circle(Vector2.ZERO, 13.4, Color(0.93, 0.88, 0.75))
	draw_set_transform(middle, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 24, Color(0.08, 0.05, 0.04), 1.6)
	draw_set_transform(middle, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 3.2, Color(0.08, 0.05, 0.04))
