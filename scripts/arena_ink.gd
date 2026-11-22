class_name ArenaInk
extends Node
## Hyde's ink on the arena's page. Three things are set from outside, one by one or all at
## once with `set_ink`; everything else about the ink follows from them:
##
## - `is_jekyll`: who has the table. In Jekyll's stance the ink stands still and its two dark
##   layers draw back; in Hyde's it moves, and they swell and shrink.
## - `percent`: how much of the page the ink covers, 0 to 100. It comes in from the right.
## - `volatility`: how restless the ink is in Hyde's stance, 0 to 100: its speed, and how far
##   it sways and is stirred. It has no effect in Jekyll's stance.
##
## The ink is drawn by the page's own shader (shaders/arena_paper.gdshader). This node keeps
## the wet layer that shader cuts the ink's layers from: a small picture of paint that is
## redrawn from itself every frame (shaders/arena_wet.gdshader), by two viewports, one drawing
## it from the other's copy of the last frame.

const WET_SHADER := preload("res://shaders/arena_wet.gdshader")
const WET_SIZE := Vector2i(576, 324)
## How long the change from one stance's look to the other takes, in seconds.
const STANCE_SECONDS := 1.4
## Jekyll's stance: the dark layer and the deeper one inside it cover these shares of the inked
## area and stand still, and a pink mid tone takes the next `MID_SHARE` outside them.
const DARK_SHARE_JEKYLL := 0.6
const DEEP_SHARE_JEKYLL := 0.5
const MID_SHARE := 0.2
const MID_COVER_JEKYLL := 0.6
## Hyde's stance: each of the two swells and shrinks between two shares, the deeper one a
## little behind the other so that it stays inside it.
const DARK_SHARE_HYDE := Vector2(0.6, 0.8)
const DEEP_SHARE_HYDE := Vector2(0.5, 0.7)
## How fast they go back and forth, on the ink's own clock.
const SHARE_BEAT := 0.25
## The longest frame the ink is moved by, in sixtieths of a second.
const MAX_FRAME := 3.0
## After this long with nothing changing in Jekyll's stance the wet layer is no longer redrawn.
const REST_AFTER := 4.0

## The page: a canvas item whose material is shaders/arena_paper_material.tres.
@export var paper: Control

var is_jekyll := false:
	set(value):
		if value != is_jekyll:
			_wake()
		is_jekyll = value
var percent := 50.0:
	set(value):
		value = clampf(value, 0.0, 100.0)
		if value != percent:
			_wake()
		percent = value
var volatility := 50.0:
	set(value):
		volatility = clampf(value, 0.0, 100.0)

var _page: ShaderMaterial
var _wet: ShaderMaterial
var _views: Array[SubViewport] = []
var _hyde := 1.0 # 0 = Jekyll's look, 1 = Hyde's; eased from one to the other
var _clock := 0.0 # the ink's own time: it stops in Jekyll's stance
var _frames := 0
var _rested := 0.0


func set_ink(new_percent: float, new_volatility: float, jekyll: bool) -> void:
	percent = new_percent
	volatility = new_volatility
	is_jekyll = jekyll


## Puts the ink in the given stance's look at once, without the eased change.
func snap_to_stance() -> void:
	_hyde = 0.0 if is_jekyll else 1.0
	_wake()


func _ready() -> void:
	# The page gets its own copy of the saved material: what is set here is this arena's alone.
	_page = paper.material.duplicate() as ShaderMaterial
	paper.material = _page
	_wet = ShaderMaterial.new()
	_wet.shader = WET_SHADER
	# One viewport draws the wet layer from the other's picture of the last frame; the other
	# copies it back.
	for i in 2:
		var view := SubViewport.new()
		view.size = WET_SIZE
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		_views.append(view)
	var draw := ColorRect.new()
	draw.size = WET_SIZE
	draw.material = _wet
	_views[0].add_child(draw)
	var copy := TextureRect.new()
	copy.texture = _views[0].get_texture()
	copy.size = WET_SIZE
	_views[1].add_child(copy)
	_wet.set_shader_parameter("previous", _views[1].get_texture())
	_wet.set_shader_parameter("texel", Vector2.ONE / Vector2(WET_SIZE))
	_page.set_shader_parameter("wet", _views[0].get_texture())
	var names := ["noise_a", "noise_b"]
	for i in names.size():
		var noise := FastNoiseLite.new()
		noise.seed = 31 + i * 7
		noise.frequency = 0.012
		var picture := ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
		_wet.set_shader_parameter(names[i], picture)
		_page.set_shader_parameter(names[i], picture)
	paper.resized.connect(_on_paper_resized)
	_on_paper_resized()
	_hyde = 0.0 if is_jekyll else 1.0
	_apply(0.0)


func _on_paper_resized() -> void:
	_page.set_shader_parameter("page_size", paper.size)
	# Both shaders lay their noise over the page's own shape, whatever the window's is.
	var shape := Vector2(paper.size.x / maxf(paper.size.y, 1.0), 1.0)
	for mat: ShaderMaterial in [_page, _wet]:
		mat.set_shader_parameter("page_shape", shape)
	_wake()


func _process(delta: float) -> void:
	_apply(delta)


## Turns the three settings into the shaders' numbers.
func _apply(delta: float) -> void:
	var stance := 0.0 if is_jekyll else 1.0
	if _hyde != stance:
		_wake()
	_hyde = move_toward(_hyde, stance, delta / STANCE_SECONDS)
	var wild := volatility / 100.0
	# A long frame (a hidden browser tab coming back) moves the clock no further than the wet
	# layer is moved: with all of it, the ink's edge and clouds would jump.
	_clock += minf(delta, MAX_FRAME / 60.0) * _hyde * lerpf(0.25, 3.0, wild)
	for mat: ShaderMaterial in [_page, _wet]:
		mat.set_shader_parameter("presence", percent / 100.0)
		mat.set_shader_parameter("ink_time", _clock)
		mat.set_shader_parameter("ink_drift", _hyde * lerpf(0.015, 0.07, wild))
		mat.set_shader_parameter("ink_breathe", _hyde * lerpf(0.01, 0.06, wild))
	_wet.set_shader_parameter("unrest", _hyde * lerpf(0.2, 1.8, wild))
	# Standing still, the paint goes quickly to its level; stirred, it is let wander.
	_wet.set_shader_parameter("settle", lerpf(3.0, 0.3, _hyde))
	_wet.set_shader_parameter("frame", clampf(delta * 60.0, 0.25, MAX_FRAME))
	# The first frames have no last frame to draw from.
	_wet.set_shader_parameter("prime", 1.0 if _frames < 3 else 0.0)
	_frames += 1
	var dark := lerpf(DARK_SHARE_HYDE.x, DARK_SHARE_HYDE.y, 0.5 + 0.5 * sin(_clock * SHARE_BEAT))
	var deep := lerpf(DEEP_SHARE_HYDE.x, DEEP_SHARE_HYDE.y, 0.5 + 0.5 * sin(_clock * SHARE_BEAT - 0.8))
	_page.set_shader_parameter("dark_share", lerpf(DARK_SHARE_JEKYLL, dark, _hyde))
	_page.set_shader_parameter("deep_share", lerpf(DEEP_SHARE_JEKYLL, deep, _hyde))
	_page.set_shader_parameter("mid_share", MID_SHARE)
	_page.set_shader_parameter("mid_cover", MID_COVER_JEKYLL * (1.0 - _hyde))
	# In Jekyll's stance nothing moves, so once the paint has come to rest the wet layer need
	# not be drawn again until something changes.
	_rested = _rested + delta if _hyde == 0.0 else 0.0
	var mode := SubViewport.UPDATE_DISABLED if _rested > REST_AFTER else SubViewport.UPDATE_ALWAYS
	for view in _views:
		if view.render_target_update_mode != mode:
			view.render_target_update_mode = mode


func _wake() -> void:
	_rested = 0.0
