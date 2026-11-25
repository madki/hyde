class_name Pencil
extends RefCounted
## Builds hand-drawn lines as ribbons for shaders/pencil_line.gdshader.
##
## Add strokes with `stroke`, then `draw` them all onto a canvas item whose material is
## shaders/pencil_line_material.tres. Each stroke wavers a little, tapers at both ends, and is
## pressed harder and lighter along its length; the shader turns that pressure into width. The
## same `rng_seed` always draws the same lines.

const HALF_WIDTH := 2.4 ## Half the ribbon's width in pixels: no line gets wider than twice this.
const STEP := 3.0 ## Distance between the points a stroke is cut into, in pixels.

var colour := Palette.OUTLINE
## No stroke is drawn thinner than this, in the pencil's own units, whatever width it is given.
var min_width := 0.0
## Half the ribbon's width in pixels, for a shader that draws past the line (a glow around it).
var half_width := HALF_WIDTH
## A steady hand: strokes neither waver, nor taper, nor change their pressure.
var steady := false

var _rng := RandomNumberGenerator.new()
var _points := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colours := PackedColorArray()
var _indices := PackedInt32Array()


func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed


## A random number from the pencil's own sequence, for laying strokes out.
func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Adds one stroke through `path`. `width` is the line's usual width in pixels. `wobble` is how
## far the hand wavers, in pixels. `fade` (0..1) is how fully the line fades out where the pencil
## lifts. `down` adds weight to downward strokes, as in handwriting.
func stroke(path: PackedVector2Array, width: float, wobble: float = 0.8, fade: float = 0.0,
		down: float = 0.0) -> void:
	if path.size() < 2:
		return
	width = maxf(width, min_width)
	var points := PackedVector2Array()
	for i in path.size() - 1:
		var pieces := maxi(1, int(path[i].distance_to(path[i + 1]) / STEP))
		for k in pieces:
			points.append(path[i].lerp(path[i + 1], float(k) / pieces))
	points.append(path[path.size() - 1])

	var offset := _rng.randf() * 1000.0
	var length := 0.0
	for i in points.size() - 1:
		length += points[i].distance_to(points[i + 1])
	if not steady:
		for i in points.size():
			points[i] += Vector2(_noise(offset + i * 0.05), _noise(offset + 40.0 + i * 0.05)) * wobble

	var first := _points.size()
	var along := 0.0
	for i in points.size():
		var direction := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-direction.y, direction.x)
		if i > 0:
			along += points[i].distance_to(points[i - 1])
		var taper := smoothstep(0.0, minf(14.0, length * 0.3), along) \
				* smoothstep(0.0, minf(20.0, length * 0.3), length - along)
		var pressure := 0.75 + 0.35 * _noise(offset + 90.0 + along * 0.035) \
				+ 0.2 * _noise(offset + 130.0 + along * 0.21)
		pressure += down * maxf(direction.y, -0.35)
		if fade > 0.0:
			var lift := _noise(offset + 170.0 + along * 0.012) * 0.5 + 0.5
			pressure *= lerpf(1.0, smoothstep(0.18, 0.5, lift), fade)
		if steady:
			pressure = 1.0
		else:
			pressure = clampf(pressure * (0.25 + 0.75 * taper), 0.0, 1.6)
		pressure *= width / (half_width * 2.0)
		_points.append(points[i] + side * half_width)
		_points.append(points[i] - side * half_width)
		_uvs.append(Vector2(along, 1.0))
		_uvs.append(Vector2(along, -1.0))
		_colours.append(Color(colour, pressure))
		_colours.append(Color(colour, pressure))
		if i > 0:
			var k := first + i * 2
			_indices.append_array([k - 2, k - 1, k, k - 1, k + 1, k])


## Draws every stroke added so far onto `item`. Call from its `_draw`.
func draw(item: CanvasItem) -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), _indices, _points, _colours, _uvs)


## Smooth noise in -1..1 along a line.
func _noise(t: float) -> float:
	var i := floorf(t)
	var f := t - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i), _hash(i + 1.0), f) * 2.0 - 1.0


func _hash(i: float) -> float:
	return fposmod(sin(i * 127.1) * 43758.5453, 1.0)
