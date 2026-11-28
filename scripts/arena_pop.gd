class_name ArenaPop
extends Control
## The small things that rise from a card while a play scores: a number ("+15", "+2 mult")
## or a few words that lift off the card that gives them and fade, a card's hop as it
## scores, the tally mark that leaves a Root for its gauge as the gauge pays, and the eye mark
## of Patience and Impulse, which flies to the draw pile and waits there for the card it draws.
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
## A gauge's tally mark: its height and its stroke, in pixels.
const TALLY_H := 10.0
const TALLY_W := 2.4
## How far a card hops, in pixels, and how long the hop takes.
const HOP := 14.0
const HOP_TIME := 0.2
## A score's bloom: at its brightest this long after the score lands, chalk again by BLOOM_TIME.
const BLOOM_PEAK := 0.1
const BLOOM_TIME := 0.5
## The bloom's halo: how far each of its rings reaches past the dark outline, and how strong
## each is at the peak, widest and faintest first.
const HALO_REACH: Array[int] = [28, 16, 7]
const HALO_STRENGTH: Array[float] = [0.18, 0.35, 0.7]
## With "reduce flashes" on, how far a blooming number leans to the scorer's light.
const CALM_TINT := 0.6

static var _font: FontVariation

## True for a mark that is a sovereign, not an eye.
var _coin := false
## For a tally mark, its colour (else clear), and whether it leans (Habit's) or stands (Temper's).
var _tally := Color(0.0, 0.0, 0.0, 0.0)
var _slant := false


## The colour of the man who scores.
static func man(hyde: bool) -> Color:
	return MAGENTA if hyde else CYAN


## `text` rises from `at` (a point on the page) on `layer` and fades: `font_size` tall, `rise`
## pixels in the same time, so that a larger one rises further.
static func text(beats: ArenaBeats, layer: Control, at: Vector2, words: String, colour: Color,
		font_size: int = 20, rise: float = RISE) -> void:
	var label := _label(layer, at, words, colour, font_size)
	var t := beats.tween()
	t.tween_property(label, "position:y", label.position.y - rise, TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(label, "modulate", Color(CREAM, 0.0), TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(label.queue_free)


## `words` travel from `from` to `to` (points on the page) over `time` and are gone: what a
## gauge pays, from the gauge into the mult. Returns the end of the flight.
static func fly_text(beats: ArenaBeats, layer: Control, from: Vector2, to: Vector2, words: String,
		colour: Color, time: float) -> Signal:
	var label := _label(layer, from, words, colour, 20)
	var end: Vector2 = layer.get_global_transform().affine_inverse() * to - label.size * 0.5
	var t := beats.tween()
	t.tween_property(label, "position", end, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(label.queue_free)
	return t.finished


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


## A card hops where it lies, as it scores: `height` pixels, in the same time however high.
static func hop(beats: ArenaBeats, card: Control, height: float = HOP) -> void:
	if not is_instance_valid(card):
		return
	var rest: float = card.get_meta("hop_rest") if card.has_meta("hop_rest") else card.position.y
	card.set_meta("hop_rest", rest)
	card.position.y = rest
	var t := beats.tween()
	t.tween_property(card, "position:y", rest - height, HOP_TIME * 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(card, "position:y", rest, HOP_TIME * 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## A score blooms: `property` of `target` (0 to 1, the bloom's strength) rises to 1 by
## BLOOM_PEAK and falls back to 0 by BLOOM_TIME, on `t`. With "reduce flashes" on it starts at
## 1 and only fades.
static func bloom(t: Tween, target: Object, property: String) -> void:
	if ArenaPace.reduce_flashes:
		t.tween_property(target, property, 0.0, BLOOM_TIME).from(1.0) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		return
	t.tween_property(target, property, 1.0, BLOOM_PEAK).from(0.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(target, property, 0.0, BLOOM_TIME - BLOOM_PEAK) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## `words` drawn on `c` at `at` (the baseline's left end) in chalk with a dark outline of
## `outline_size`, blooming by `amount` (0 to 1): a hot core, haloed in `light`, the scorer's
## colour. With "reduce flashes" on there is no core and no halo: the chalk leans to `light`.
static func draw_bloom(c: CanvasItem, font: Font, at: Vector2, words: String, font_size: int,
		outline_size: int, light: Color, amount: float) -> void:
	var calm := ArenaPace.reduce_flashes
	if amount > 0.0 and not calm:
		for i in HALO_REACH.size():
			c.draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
					outline_size + HALO_REACH[i], Color(light, HALO_STRENGTH[i] * amount))
	c.draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_size, OUTLINE)
	var core := CREAM.lerp(light, CALM_TINT * amount) if calm else CREAM.lerp(Palette.HOT, amount)
	c.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, core)


## A sovereign travels from `from` to `to` (points on the page) and is gone. Await it. It
## lands `step` semitones up: the coins of one pay climb.
static func coin(beats: ArenaBeats, layer: Control, from: Vector2, to: Vector2,
		time: float = 0.28, step: float = 0.0) -> void:
	var mark := eye(layer, from)
	mark._coin = true
	mark.queue_redraw()
	await mark.fly_to(beats, to, time)
	beats.sound("coin", Sfx.semitones(step) * Sfx.vary(0.03))
	mark.queue_free()


## A gauge's tally mark leaves `from` for `to` (points on the page) over `time` and is gone:
## upright for Temper, leaning for Habit (`slant`), in `colour`. Await it.
static func tally(beats: ArenaBeats, layer: Control, from: Vector2, to: Vector2, colour: Color,
		slant: bool, time: float) -> void:
	var mark := eye(layer, from)
	mark._tally = colour
	mark._slant = slant
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


# The eye: a cream tag with an eye drawn on it in pencil. A tally: one stroke, outlined.
func _draw() -> void:
	var middle := size * 0.5
	if _tally.a > 0.0:
		var lean := TALLY_H * 0.3 if _slant else 0.0
		var top := middle + Vector2(lean * 0.5, -TALLY_H * 0.5)
		var bottom := middle + Vector2(-lean * 0.5, TALLY_H * 0.5)
		draw_line(top, bottom, OUTLINE, TALLY_W + 3.0)
		draw_line(top, bottom, _tally, TALLY_W)
		return
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
