class_name ArenaRestraint
extends Control
## The restraint gauge on the arena's page: a track of numbered steps lying across the page,
## from 1 at the left to the limit at the right, headed RESTRAINT, with tick marks along both
## its sides. Under each number the page's slate has come off in a round patch like old paint,
## each patch touching the next, and the cream of the paper shows
## (shaders/arena_restraint_strip.gdshader). Hyde's ink lies over every step that has been
## reached, so the amount of ink is the reading, and a clean track reads nothing. The last
## step is marked as Hyde's. One step short of it the ink looks threatening (see
## shaders/arena_restraint.gdshader).
##
## The gauge works out no rule. Give it what RulesView.table() returns with `show_table`: it
## shows that table's meter against that table's limit.

const INK_SHADER: Shader = preload("res://shaders/arena_restraint.gdshader")
const STRIP_SHADER: Shader = preload("res://shaders/arena_restraint_strip.gdshader")
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

## Distance from one step to the next, in pixels, where the gauge is wide enough for it.
const PITCH := 34.0
## Where the track's middle lies, from the gauge's top, and half its height.
const TRACK_Y := 58.0
const TRACK_HALF := 19.0
## Tick marks to a step, and the lengths of a short one and of the one at a step's middle.
const TICKS := 4
const TICK_SHORT := 4.5
const TICK_LONG := 9.0
## Room around the gauge that the ink may be thrown into, in pixels.
const SPILL := 30.0
## The strip under the numbers: the usual radius of the patch under each number, half the
## pitch so that each touches the next.
const BEAD := 17.0
## Seconds the ink takes to cover a step, and to turn threatening or calm again.
const INK_TIME := 0.6
const THREAT_TIME := 1.2
## The most one frame moves the ink's clock, in seconds: a long frame (a hidden browser tab
## coming back) does not make the ink jump.
const MAX_FRAME := 0.1

const PENCIL := Color(0.015, 0.025, 0.035)
const PAPER_TEXT := Color(0.16, 0.13, 0.15)
## A number under the ink: the ink's own pale wash, a little lighter, to be read without standing out.
const INKED_TEXT := Color(0.56, 0.46, 0.58)

## Changes the lines and the blots a little while keeping the look.
@export var rng_seed := 5

## What is shown: the meter, and the limit it is read against.
var meter := 0
var limit := 5

var _marks := Control.new()
var _strip := Control.new()
var _ink := ColorRect.new()
var _text := Control.new()
var _ink_material := ShaderMaterial.new()
var _strip_material := ShaderMaterial.new()
var _heavy := FontVariation.new()
var _slanted := FontVariation.new()
var _change: Tween
## How many steps are inked, and how threatening the ink looks (0 to 1): both eased.
var _level := 0.0:
	set(value):
		_level = value
		_text.queue_redraw()
		_ink_material.set_shader_parameter("level", value)
var _threat := 0.0:
	set(value):
		_threat = value
		_ink_material.set_shader_parameter("threat", value)
		set_process(value > 0.0)
var _clock := 0.0
## The lock of a play that adds no restraint: how present it is, and how far it has fallen.
var _lock := 0.0:
	set(value):
		_lock = value
		_text.queue_redraw()
var _lock_fall := 0.0:
	set(value):
		_lock_fall = value
		_text.queue_redraw()
var _lock_move: Tween
## The still mark of what the chosen play would do: "" for none, "step" (the next step is
## outlined: it adds restraint), "breakout" (the outline is on the HYDE! end: he breaks out)
## or "lock" (it adds none).
var ghost := "":
	set(value):
		ghost = value
		_text.queue_redraw()


func _init() -> void:
	# The engine's own font, as on the cards, until the game has its two faces.
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1
	_slanted.base_font = ThemeDB.fallback_font
	_slanted.variation_embolden = 0.5
	_slanted.variation_transform = Transform2D(Vector2(1.0, 0.22), Vector2(0.0, 1.0), Vector2.ZERO)

	_marks.material = LINE_MATERIAL
	_marks.draw.connect(_draw_marks)
	_strip_material.shader = STRIP_SHADER
	_strip.material = _strip_material
	_strip.draw.connect(_draw_strip)
	_ink_material.shader = INK_SHADER
	_ink.material = _ink_material
	_text.draw.connect(_draw_text)
	# The ink lies over the marks and the strip, and the numbers are read through it.
	for child: Control in [_marks, _strip, _ink, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


func _process(delta: float) -> void:
	_clock += minf(delta, MAX_FRAME)
	_ink_material.set_shader_parameter("clock", _clock)


## Shows the restraint of a table, as RulesView.table() gives it.
func show_table(table: Dictionary) -> void:
	var restraint: Dictionary = table.restraint
	show_meter(restraint.meter, restraint.limit)


## Shows `new_meter` on a track that ends at `new_limit`: the ink comes over the steps, or
## draws back from them, in its own time.
func show_meter(new_meter: int, new_limit: int) -> void:
	if new_limit != limit:
		limit = maxi(new_limit, 1)
		_lay_out()
	meter = clampi(new_meter, 0, limit)
	if _change:
		_change.kill()
	_change = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_change.tween_property(self, "_level", float(meter), INK_TIME)
	_change.tween_property(self, "_threat", _threat_of(), THREAT_TIME)


## A small lock on the next step of the track: the play adds no restraint. With `on` it
## lands there; without, it opens and falls away. Returns the tween doing it.
func set_lock(on: bool) -> Tween:
	if _lock_move:
		_lock_move.kill()
	_lock_move = create_tween()
	if on:
		_lock_fall = -1.0
		_lock_move.tween_property(self, "_lock", 1.0, 0.12)
		_lock_move.parallel().tween_property(self, "_lock_fall", 0.0, 0.2).set_ease(Tween.EASE_IN)
	else:
		_lock_move.tween_property(self, "_lock_fall", 1.0, 0.35).set_ease(Tween.EASE_IN)
		_lock_move.parallel().tween_property(self, "_lock", 0.0, 0.35).set_ease(Tween.EASE_IN)
	return _lock_move


## The middle of the track's last step, the HYDE! end, on the page.
func end_place() -> Vector2:
	return get_global_transform() * _step(limit)


## Puts the ink where it belongs at once, without the change there.
func snap() -> void:
	if _lock_move:
		_lock_move.kill()
	_lock = 0.0
	if _change:
		_change.kill()
	_level = float(meter)
	_threat = _threat_of()


## The ink is threatening while the meter stands one step short of the track's end.
func _threat_of() -> float:
	return 1.0 if meter > 0 and meter == limit - 1 else 0.0


func _pitch() -> float:
	return minf(PITCH, size.x / limit)


## The middle of the i-th step, 1 to `limit`.
func _step(i: int) -> Vector2:
	var left := (size.x - _pitch() * limit) * 0.5
	return Vector2(left + (i - 0.5) * _pitch(), TRACK_Y)


func _lay_out() -> void:
	var spill := Vector2(SPILL, SPILL)
	_ink.position = -spill
	_ink.size = size + spill * 2.0
	for child: Control in [_marks, _strip, _text]:
		child.size = size
	_ink_material.set_shader_parameter("first", _step(1) + spill)
	_ink_material.set_shader_parameter("pitch", _pitch())
	_ink_material.set_shader_parameter("rect_size", _ink.size)
	_ink_material.set_shader_parameter("seed", float(rng_seed))
	_strip_material.set_shader_parameter("first", _step(1))
	_strip_material.set_shader_parameter("pitch", _pitch())
	_strip_material.set_shader_parameter("steps", float(limit))
	_strip_material.set_shader_parameter("radius", minf(BEAD, _pitch() * 0.5))
	_strip_material.set_shader_parameter("seed", float(rng_seed))
	for child: Control in [_marks, _strip, _text]:
		child.queue_redraw()


## The heading's underline and the tick marks along both sides of the track.
func _draw_marks() -> void:
	var pencil := Pencil.new(rng_seed)
	pencil.colour = PENCIL
	var heading := _heavy.get_string_size("RESTRAINT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	var left := _step(1).x - _pitch() * 0.5
	pencil.stroke(PackedVector2Array([Vector2(left + 1.0, 21.0), Vector2(left + heading + 9.0, 20.0)]), 1.5, 0.6, 0.2)
	var count := limit * TICKS
	for side: float in [-1.0, 1.0]:
		for k in count:
			var x := left + (k + 0.5) * _pitch() / TICKS + pencil.randf_range(-0.5, 0.5)
			# The mark at a step's middle is the long one.
			var long := k % TICKS == TICKS / 2
			var length := (TICK_LONG if long else TICK_SHORT) + pencil.randf_range(-0.8, 0.8)
			var from := Vector2(x, TRACK_Y + side * TRACK_HALF)
			var to := from + Vector2(pencil.randf_range(-0.6, 0.6), side * length)
			pencil.stroke(PackedVector2Array([from, to]), 2.3 if long else 1.7, 0.3, 0.0)
	pencil.draw(_marks)


## The strip under the numbers is drawn by its shader: this gives it the gauge to draw over.
func _draw_strip() -> void:
	_strip.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


## The heading, the numbers, and whose the end of the track is.
func _draw_text() -> void:
	var left := _step(1).x - _pitch() * 0.5
	_text.draw_string(_heavy, Vector2(left + 3.0, 16.0), "RESTRAINT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PENCIL)
	var number_size := 17
	var drop := (_heavy.get_ascent(number_size) - _heavy.get_descent(number_size)) * 0.5
	# A number is dark on the bared paper, and a dull mauve once the ink has its step.
	for i in range(1, limit + 1):
		var at := _step(i)
		_text.draw_string(_heavy, Vector2(at.x - _pitch() * 0.5, at.y + drop), str(i), HORIZONTAL_ALIGNMENT_CENTER,
				_pitch(), number_size, INKED_TEXT if _level >= i - 0.5 else PAPER_TEXT)
	# Written by hand above the last step, slanting up and away from it.
	var whose := "HYDE!"
	var width := _slanted.get_string_size(whose, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	# On a short track it keeps clear of the heading, and stands a little past the last step.
	var heading_end := left + 3.0 + _heavy.get_string_size("RESTRAINT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	var whose_x := maxf(_step(limit).x - width * 0.5 - 2.0, heading_end + 8.0)
	_text.draw_set_transform(Vector2(whose_x, TRACK_Y - TRACK_HALF - TICK_LONG - 4.0), deg_to_rad(-9.0))
	_text.draw_string(_slanted, Vector2.ZERO, whose, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PENCIL)
	_text.draw_set_transform(Vector2.ZERO, 0.0)
	if _lock > 0.0:
		_draw_lock(_lock, _lock_fall)
	elif ghost == "lock":
		_draw_lock(0.7, 0.0)
	elif ghost == "step" or ghost == "breakout":
		var at := _step(limit if ghost == "breakout" else mini(meter + 1, limit))
		var heavy := ghost == "breakout"
		_text.draw_arc(at, minf(BEAD, _pitch() * 0.5) + (2.0 if heavy else 0.0), 0.0, TAU, 32,
				Color(0.42, 0.1, 0.4, 0.95) if heavy else Color(0.42, 0.13, 0.44, 0.75), 3.2 if heavy else 2.0)


# The lock: on a cream tag over the next step. Landing, it drops onto the step; opened, its
# shackle swings up and it falls away below the track.
func _draw_lock(alpha: float, fall: float) -> void:
	var _lock := alpha
	var _lock_fall := fall
	var at := _step(mini(meter + 1, limit)) + Vector2(0.0, 14.0 * _lock_fall if _lock_fall < 0.0 else 26.0 * _lock_fall)
	var ink := Color(PENCIL, _lock)
	_text.draw_circle(at, 13.0, Color(0.93, 0.88, 0.75, _lock * 0.95))
	_text.draw_arc(at, 13.0, 0.0, TAU, 24, ink, 1.4)
	_text.draw_rect(Rect2(at + Vector2(-6.0, -1.0), Vector2(12.0, 9.0)), ink)
	# The shackle: shut while the lock holds, swung open as it falls.
	var open := clampf(_lock_fall, 0.0, 1.0)
	_text.draw_set_transform(at + Vector2(4.0, -1.0), -open * 1.1)
	_text.draw_arc(Vector2(-4.0, 0.0), 4.0, PI, TAU, 10, ink, 2.0)
	_text.draw_set_transform(Vector2.ZERO, 0.0)
