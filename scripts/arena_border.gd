class_name ArenaBorder
extends Control
## The page's ruled border, drawn by hand: an outer heavier line and an inner light one. Each
## side is its own stroke, a little off true and running past the corner, fading where the
## pencil lifted, and gone over again for part of the way. More ruled lines can cross the
## page (`rules`): the arena has one under its top band and one over the hand.
##
## `flare` lights the outer ruling once in a man's light, as the table changes hands.

## Distance of the two rulings from the edge of the page, in pixels.
@export var insets := PackedFloat32Array([28.0, 36.0])
## Usual width of each ruling, in pixels.
@export var widths := PackedFloat32Array([2.6, 1.3])
## How far the hand wavers, in pixels.
@export var wobble := 1.3
## How fully a line fades out where the pencil lifts.
@export_range(0.0, 1.0) var fade := 0.45
@export var colour := Palette.OUTLINE
## Changes every line a little while keeping the look.
@export var rng_seed := 7

## A flare's glow about the outer ruling: each band's width in pixels and its share of the
## flare's strength, the widest and faintest first.
const FLARE_BANDS: Array[Vector2] = [Vector2(26.0, 0.12), Vector2(12.0, 0.28), Vector2(4.0, 0.9)]

## The ruled lines that cross the page, each as its two ends, one after the other.
var rules := PackedVector2Array():
	set(value):
		rules = value
		queue_redraw()


var _glow := Control.new()
var _flare_tint := Color.WHITE
var _flare := 0.0:
	set(value):
		_flare = value
		_glow.visible = value > 0.0
		_glow.queue_redraw()
var _flare_tween: Tween


func _ready() -> void:
	resized.connect(queue_redraw)
	# The glow is drawn on a layer of its own: the hand-drawn lines are not drawn again for it.
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.visible = false
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## Lights the outer ruling once in `tint`, to `strength` (0 to 1): it rises in `rise` seconds
## and falls in `fall`, never quicker than a flare may (ArenaPace.FLARE_RISE, FLARE_FALL).
## Returns the tween doing it, for the beat queue to keep at its rate. The caller leaves it
## out with "reduce flashes" on.
func flare(tint: Color, strength: float = 1.0, rise: float = ArenaPace.FLARE_RISE,
		fall: float = ArenaPace.FLARE_FALL) -> Tween:
	if _flare_tween:
		_flare_tween.kill()
	_flare_tint = tint
	_flare_tween = create_tween()
	_flare_tween.tween_property(self, "_flare", clampf(strength, 0.0, 1.0), maxf(rise, ArenaPace.FLARE_RISE)) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_flare_tween.tween_property(self, "_flare", 0.0, maxf(fall, ArenaPace.FLARE_FALL)) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return _flare_tween


func _draw_glow() -> void:
	if _flare <= 0.0 or insets.is_empty():
		return
	var inset := Vector2(insets[0], insets[0])
	var rect := Rect2(inset, size - inset * 2.0)
	for band in FLARE_BANDS:
		_glow.draw_rect(rect, Color(_flare_tint, _flare * band.y), false, band.x)


func _draw() -> void:
	var pencil := Pencil.new(rng_seed)
	pencil.colour = colour
	for ruling in mini(insets.size(), widths.size()):
		var inset := Vector2(insets[ruling], insets[ruling])
		var rect := Rect2(inset, size - inset * 2.0)
		var width := widths[ruling]
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			var from: Vector2 = corners[i]
			var to: Vector2 = corners[(i + 1) % 4]
			var along := (to - from).normalized()
			var across := Vector2(-along.y, along.x)
			from += -along * pencil.randf_range(3.0, 11.0) + across * pencil.randf_range(-1.6, 1.6)
			to += along * pencil.randf_range(3.0, 11.0) + across * pencil.randf_range(-1.6, 1.6)
			pencil.stroke(PackedVector2Array([from, to]), width, wobble, fade)
			if pencil.randf_range(0.0, 1.0) < 0.6:
				var start := pencil.randf_range(0.0, 0.5)
				var end := start + pencil.randf_range(0.2, 0.45)
				pencil.stroke(PackedVector2Array([from.lerp(to, start) + across * 0.9,
						from.lerp(to, end) + across * 0.5]), width * 0.7, wobble * 0.8, 0.4)
	if not widths.is_empty():
		for i in range(0, rules.size() - 1, 2):
			var along := (rules[i + 1] - rules[i]).normalized()
			var across := Vector2(-along.y, along.x)
			var from := rules[i] - along * pencil.randf_range(2.0, 7.0) + across * pencil.randf_range(-1.5, 1.5)
			var to := rules[i + 1] + along * pencil.randf_range(2.0, 7.0) + across * pencil.randf_range(-1.5, 1.5)
			pencil.stroke(PackedVector2Array([from, to]), widths[0], wobble, fade)
			pencil.stroke(PackedVector2Array([from.lerp(to, 0.08) + across * 4.5, from.lerp(to, 0.97) + across * 5.0]),
					widths[widths.size() - 1], wobble, fade)
	pencil.draw(self)
