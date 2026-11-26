class_name ArenaDanger
extends ColorRect
## Danger seen as well as heard: a mist at the edges of the whole screen that beats with the
## table's heartbeat (ArenaExtraSound, which it follows: `level`, `cause`, `beat`, `changed`).
##
## - The line near, or a last play: the mist reaches NEAR_REACH of the page in from each edge
##   (of its width from the sides, of its height from the top and the bottom, so that it
##   stays off the hand and the ribbon), at NEAR_REST alpha, and swells to NEAR_BEAT on each
##   beat.
## - Ink ahead: AHEAD_REACH in, AHEAD_REST and AHEAD_BEAT, and the swell reaches further in.
## - For the line it is Hyde's pink. For a last play alone it is colder and fainter, so the two
##   dangers are not taken for one another; with both, the line's.
##
## It comes and goes over FADE seconds, lies over the table and under the views, takes no
## input, and is neither drawn nor run while there is no danger. With "reduce flashes" it
## stands at its rest alpha and does not beat.
##
## For a still: `--mist=<swell>` holds the swell there (0 at rest, 1 at the top of a beat) and
## shows the mist at once, without the fade.

const SHADER := preload("res://shaders/arena_danger.gdshader")

const NEAR_REACH := 0.08
const NEAR_REST := 0.18
const NEAR_BEAT := 0.30
const AHEAD_REACH := 0.14
const AHEAD_REST := 0.30
const AHEAD_BEAT := 0.50
## How much further in the swell reaches at the top of a beat when Ink is ahead, as a share
## of the reach.
const AHEAD_FURTHER := 0.2
## The last play's own tone, pale and cold, and how much of the alphas it keeps.
const LAST_PLAY_TINT := Palette.SALT
const LAST_PLAY_FAINT := 0.75
## How long the mist takes to come, to go and to change from one danger to another.
const FADE := 0.6
## A beat's swell: how long it rises and how long it takes to fall back.
const RISE := 0.08
const FALL := 0.45

var _sound: ArenaExtraSound
var _mat := ShaderMaterial.new()
## What is shown now; a change of danger tweens these.
var _amount := 0.0
var _reach := NEAR_REACH
var _rest := NEAR_REST
var _top := NEAR_BEAT
var _further := 0.0
var _tint := Palette.HYDE
## The swell, 0 to 1, and what a beat is still raising it to.
var _swell := 0.0
var _rising_to := 0.0
## The swell held for a still, or -1.
var _held := -1.0
var _tween: Tween


func _init() -> void:
	name = "Danger"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat.shader = SHADER
	material = _mat
	visible = false
	set_process(false)


func _ready() -> void:
	if Shot.has_arg("mist"):
		_held = clampf(float(Shot.arg("mist")), 0.0, 1.0)
	resized.connect(_on_resized)
	_on_resized()
	# The heartbeat and the page's noise are made after the table is built.
	_follow.call_deferred()


func _process(delta: float) -> void:
	if _held >= 0.0 or ArenaPace.reduce_flashes:
		_swell = maxf(_held, 0.0)
	elif _rising_to > _swell:
		_swell = move_toward(_swell, _rising_to, delta / RISE)
		if _swell >= _rising_to:
			_rising_to = 0.0
	else:
		_rising_to = 0.0
		_swell = move_toward(_swell, 0.0, delta / FALL)
	_mat.set_shader_parameter("strength", _amount * lerpf(_rest, _top, _swell))
	_mat.set_shader_parameter("reach", _reach * (1.0 + _further * _swell))
	_mat.set_shader_parameter("tint", _tint)


func _follow() -> void:
	var paper := get_parent().get_node_or_null("Paper") as CanvasItem
	if paper and paper.material is ShaderMaterial:
		_mat.set_shader_parameter("noise", (paper.material as ShaderMaterial).get_shader_parameter("noise_a"))
	for child in get_parent().get_children():
		if child is ArenaExtraSound:
			_sound = child
	if _sound == null:
		return
	_sound.beat.connect(_on_beat)
	_sound.changed.connect(_on_changed)
	_on_changed()


func _on_resized() -> void:
	_mat.set_shader_parameter("page_size", size)


func _on_beat(weight: float) -> void:
	_rising_to = maxf(_rising_to, weight)


# The danger changed: the mist comes, goes, or turns into the other danger's.
func _on_changed() -> void:
	var level := _sound.level()
	var to := {"_amount": 1.0 if level > 0 else 0.0}
	if level > 0:
		var faint := 1.0 if "line" in _sound.cause() else LAST_PLAY_FAINT
		to["_tint"] = Palette.HYDE if faint == 1.0 else LAST_PLAY_TINT
		to["_reach"] = AHEAD_REACH if level == 2 else NEAR_REACH
		to["_rest"] = (AHEAD_REST if level == 2 else NEAR_REST) * faint
		to["_top"] = (AHEAD_BEAT if level == 2 else NEAR_BEAT) * faint
		to["_further"] = AHEAD_FURTHER if level == 2 else 0.0
	if _tween:
		_tween.kill()
	_tween = null
	# From nothing, it comes as what it is; a still shows it whole.
	var at_once := _held >= 0.0
	for key: String in to:
		if at_once or (_amount == 0.0 and key != "_amount"):
			set(key, to[key])
	if level > 0:
		visible = true
		set_process(true)
	if at_once:
		_rested()
		return
	_tween = create_tween().set_parallel()
	for key: String in to:
		_tween.tween_property(self, key, to[key], FADE)
	_tween.chain().tween_callback(_rested)


# The fade is over: with no danger left, nothing is drawn or run.
func _rested() -> void:
	if _amount == 0.0:
		_swell = 0.0
		_rising_to = 0.0
		visible = false
		set_process(false)
