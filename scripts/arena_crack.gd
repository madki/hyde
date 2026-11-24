class_name ArenaCrack
extends Control
## The crack that runs across a Root as it changes side, laid over the card: a jagged line from
## one edge to the other, split by cyan light on one side and magenta on the other (the
## reference's cracked pair). Under it the twin's face spreads out from the crack, ink flooding
## the paper or draining from it, until it covers the card.
##
## Driven from outside: `run` (0 to 1) is how far the crack has run across, `flood` (0 to 1)
## how far the twin has spread, `glow` (0 to 1) the flare of the light. With reduce flashes on
## the flare is not drawn: the crack is a plain hairline of the two colours.

const CYAN := Color(0.45, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.4, 0.85)
const DARK := Color(0.05, 0.03, 0.06)

var run := 0.0:
	set(value):
		run = value
		_light.queue_redraw()
var flood := 0.0:
	set(value):
		flood = value
		_spread()
		_light.queue_redraw()
var glow := 0.0:
	set(value):
		glow = value
		_light.queue_redraw()

var _points := PackedVector2Array()
var _wipe := Control.new()
## The crack's lines, drawn over the twin as it spreads.
var _light := Control.new()
var _twin: ArenaCard


## Lays the crack over `card`, with `twin` (a card showing the other side) under it, hidden
## until it floods. The crack's path comes from `rng_seed`.
func _init(twin: ArenaCard = null, rng_seed: int = 1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ArenaCard.SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# From the left edge to the right, a little above or below the middle, in jagged steps.
	var y := ArenaCard.SIZE.y * rng.randf_range(0.4, 0.55)
	var tilt := rng.randf_range(-0.25, 0.25)
	var x := 1.0
	while x < ArenaCard.SIZE.x - 8.0:
		_points.append(Vector2(x, y))
		x += rng.randf_range(7.0, 13.0)
		y += tilt * 10.0 + rng.randf_range(-6.0, 6.0)
		y = clampf(y, ArenaCard.SIZE.y * 0.3, ArenaCard.SIZE.y * 0.7)
	_points.append(Vector2(ArenaCard.SIZE.x - 1.0, y))
	_wipe.clip_contents = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wipe)
	if twin:
		_twin = twin
		_twin.position = Vector2.ZERO
		_twin.rotation = 0.0
		_twin.scale = Vector2.ONE
		_wipe.add_child(_twin)
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.size = size
	_light.draw.connect(_draw_light)
	add_child(_light)
	_spread()


## Where the crack meets the card's middle, from the top.
func middle_y() -> float:
	var sum := 0.0
	for p in _points:
		sum += p.y
	return sum / maxf(1.0, _points.size())


func _spread() -> void:
	# The twin shows in a band that opens from the crack up and down.
	var mid := middle_y()
	var top := lerpf(mid, -ArenaCard.MARGIN, flood)
	var bottom := lerpf(mid, ArenaCard.SIZE.y + ArenaCard.MARGIN, flood)
	_wipe.position = Vector2(-ArenaCard.MARGIN, top)
	_wipe.size = Vector2(ArenaCard.SIZE.x + ArenaCard.MARGIN * 2.0, maxf(0.0, bottom - top))
	if _twin:
		_twin.position = Vector2(ArenaCard.MARGIN, -top)
	_wipe.visible = flood > 0.0


func _draw_light() -> void:
	if run <= 0.0 or _points.size() < 2:
		return
	# The part of the path the crack has run along.
	var total := 0.0
	for i in _points.size() - 1:
		total += _points[i].distance_to(_points[i + 1])
	var reach := total * run
	var path := PackedVector2Array([_points[0]])
	var along := 0.0
	for i in _points.size() - 1:
		var step := _points[i].distance_to(_points[i + 1])
		if along + step >= reach:
			path.append(_points[i].lerp(_points[i + 1], (reach - along) / step))
			break
		along += step
		path.append(_points[i + 1])
	if path.size() < 2:
		return
	var fade := 1.0 - flood * 0.6
	if glow > 0.0 and not ArenaPace.reduce_flashes:
		_light.draw_polyline(_offset(path, -2.0), Color(CYAN, 0.25 * glow * fade), 9.0, true)
		_light.draw_polyline(_offset(path, 2.0), Color(MAGENTA, 0.25 * glow * fade), 9.0, true)
	_light.draw_polyline(path, Color(DARK, 0.9 * fade), 2.4, true)
	_light.draw_polyline(_offset(path, -1.4), Color(CYAN, fade), 1.2, true)
	_light.draw_polyline(_offset(path, 1.4), Color(MAGENTA, fade), 1.2, true)


static func _offset(path: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in path:
		out.append(p + Vector2(0.0, by))
	return out
