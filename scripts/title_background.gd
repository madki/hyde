@tool
class_name TitleBackground
extends ColorRect
## Full-screen picture for the title screen: the street, with the man standing further off than
## in the game, so that he is seen down to his feet. Jekyll waits with his head bowed and both
## hands on his stick, under bluer lamps than the game's street has, which waver and gutter
## as Hyde's do.
##
## `change_to` turns one man into the other out of sight: the lamps go out, the picture falls
## dark, and the lamps of the other face catch with the same flicker, the other man standing
## there.
##
## Drawn by the street's shader (shaders/background.gdshader) with a material of its own,
## shaders/title_material.tres: edit the look there, or open scenes/title_background.tscn and
## drag `shift`, `lamps` and `darkness` to see it in the editor. The streets are the game's own
## with the shadow of the man who stands in them, and the two men are a figure layer over them,
## all from tools/bake_title.sh.

## Sent in the dark, when one man has just taken the other's place.
signal face_changed(face: float)

const BAKE_ASPECT := 16.0 / 9.0

# The figure layer, art/bg/title_figures.png: Jekyll and then Hyde, side by side (baked by
# studio/title_figure_bake.gd, which reads these too: re-bake after changing any of them).
const FIGURE_PX := 512 # FIGURE_RECT in pixels of the 1920 x 1080 bake
## The part of the baked picture the figure layer covers: x, y, width, height in 0..1.
const FIGURE_RECT := Rect2(397.0 / 1920.0, 528.0 / 1080.0, 512.0 / 1920.0, 512.0 / 1080.0)
## Where the men's feet are on the baked picture (studio/title_figure_bake.gd prints it), and
## how far the dark patch under them reaches to each side and up and down, all in 0..1. How
## dark the patch is, is the material's `feet_patch`.
const FEET := Vector2(638.0 / 1920.0, 996.0 / 1080.0)
const FEET_PATCH := Vector2(95.0 / 1920.0, 20.0 / 1080.0)
## Distances from the camera, in metres, that the depth sheet's 0 and 1 stand for.
const FIGURE_DEPTH_RANGE := Vector2(3.0, 9.0)

# Jekyll coming apart (`apart`). Distances are fractions of the baked picture.
const PART_SECONDS := 0.7 # the whole of it, either way
const HYDE_ASIDE := 0.03 # how far right of Jekyll's place the magenta ghost goes: Hyde's place
const GHOST_ASIDE := 0.05 # how far left of it the cyan ghost goes
const GHOST_FRESH := 1.5 # how strongly the ghosts show when Jekyll has just come apart
const GHOST_LEFT := 0.0 # how strongly the cyan one shows once Hyde is there: 0 = gone
# When things happen, as shares of the whole: from the first to the second of each pair.
const LIGHT_TURNS := Vector2(0.0, 0.6) # the lamps go from cyan to magenta
const JEKYLL_THINS := Vector2(0.0, 0.12) # the solid man gives way to his two ghosts
const GHOSTS_GO := Vector2(0.0, 0.6) # the ghosts move out to their places
const HYDE_SETS := Vector2(0.14, 0.7) # the magenta ghost, Hyde's shape, sets into Hyde himself
const LEFT_FADES := Vector2(0.3, 1.0) # the cyan ghost fades to GHOST_LEFT

# The change, in seconds.
const LAMPS_OUT := 0.5 # the lamps gutter and die
const FALL_DARK := 0.3 # what light is left goes too
const DARK := 0.225 # nothing to see: the men change places

## 0 = Jekyll, 1 = Hyde.
@export_range(0.0, 1.0) var shift := 0.0:
	set(value):
		shift = clampf(value, 0.0, 1.0)
		_set_param("shift", shift)

## How brightly the lamps and lit windows burn: 0 = all of them out.
@export_range(0.0, 1.0) var lamps := 1.0:
	set(value):
		lamps = clampf(value, 0.0, 1.0)
		_set_param("lamps", lamps)

## 1 = the whole picture is black.
@export_range(0.0, 1.0) var darkness := 0.0:
	set(value):
		darkness = clampf(value, 0.0, 1.0)
		_set_param("blackout", darkness)

## Jekyll coming apart into Hyde: 0 = Jekyll alone under his cyan lamps, 1 = the lamps
## magenta and Hyde standing a little to the right.
## On the way Jekyll parts into two ghosts: the cyan one goes left and fades, and the magenta one, which
## is Hyde's shape from the start, goes right and sets into Hyde himself. Also sets `shift`.
@export_range(0.0, 1.0) var apart := 0.0:
	set(value):
		apart = clampf(value, 0.0, 1.0)
		_pose_apart()

## How far the view leans towards the mouse while the game runs. 0 turns the parallax off.
@export_range(0.0, 1.0) var parallax := 1.0

var _tween: Tween
var _part_tween: Tween


func _ready() -> void:
	_set_param("shift", shift)
	_set_param("lamps", lamps)
	_set_param("blackout", darkness)
	# Each street shows its own man, standing still: the sheet holds nothing else.
	_set_param("figure_face", -1.0)
	_set_param("figure_wobble", 0.0)
	_set_param("morph_mix", 0.0)
	_set_param("morph_frame", 0.0)
	_set_param("morph_frames", 1.0)
	_set_param("morph_grid", Vector2(1.0, 0.0))
	_set_param("morph_frame_px", float(FIGURE_PX))
	_set_param("figure_still_px", float(FIGURE_PX))
	_set_param("figure_rect", Vector4(FIGURE_RECT.position.x, FIGURE_RECT.position.y,
			FIGURE_RECT.size.x, FIGURE_RECT.size.y))
	_set_param("figure_depth_range", FIGURE_DEPTH_RANGE)
	_set_param("feet", FEET)
	_set_param("feet_patch_size", FEET_PATCH)
	_set_param("sway", Vector2.ZERO)
	if apart > 0.0:
		_pose_apart()
	resized.connect(_fit)
	_fit()


## Whether a change is under way.
func is_changing() -> bool:
	return _tween != null and _tween.is_running()


## Changes to a face (0 = Jekyll, 1 = Hyde) through the dark. Does nothing while a change is
## already under way.
func change_to(face: float) -> void:
	if is_changing() or apart > 0.0:
		return
	_tween = create_tween()
	_tween.tween_method(_gutter, 0.0, 1.0, LAMPS_OUT)
	_tween.tween_property(self, "darkness", 1.0, FALL_DARK).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(DARK * 0.5)
	_tween.tween_callback(_swap.bind(face))
	_tween.tween_interval(DARK * 0.5)
	# The way back is the way out, run backwards: the dark lifts, then the other face's lamps
	# flare, sink and catch.
	_tween.tween_property(self, "darkness", 0.0, FALL_DARK).set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_gutter, 1.0, 0.0, LAMPS_OUT)


## The lamps dying, `t` = 0..1: they sink, flare up once and go out. Run from 1 to 0 it is
## the lamps catching.
func _gutter(t: float) -> void:
	lamps = (1.0 - smoothstep(0.0, 0.55, t)) + 0.45 * smoothstep(0.5, 0.62, t) * (1.0 - smoothstep(0.7, 1.0, t))


## Puts the other man there at once, for a change that hides the moment some other way.
func show_face(face: float) -> void:
	_swap(face)


## Plays Jekyll coming apart (1) or coming back together (0) from wherever it has got to.
func part_to(target: float) -> void:
	if is_changing():
		return
	if _part_tween:
		_part_tween.kill()
	_part_tween = create_tween()
	_part_tween.tween_property(self, "apart", target, PART_SECONDS * absf(target - apart))


## Sets the men and the street for the current `apart`.
func _pose_apart() -> void:
	if apart <= 0.0:
		_set_param("figure_face", -1.0)
		_set_param("figure_aside", Vector2.ZERO)
		_set_param("figure_solid", 1.0)
		_set_param("ghosts", Vector2.ZERO)
		shift = 0.0
		return
	shift = _between(LIGHT_TURNS, apart)
	var out := ease(_between(GHOSTS_GO, apart), 0.35) # quick away, slowing as they arrive
	_set_param("ghost_spread", Vector2(GHOST_ASIDE, HYDE_ASIDE) * out)
	_set_param("ghost_turned", 1.0) # the magenta ghost is Hyde's shape from the start
	var thinned := _between(JEKYLL_THINS, apart)
	var hyde := _between(HYDE_SETS, apart)
	_set_param("ghosts", Vector2(
			thinned * lerpf(GHOST_FRESH, GHOST_LEFT, _between(LEFT_FADES, apart)),
			thinned * GHOST_FRESH * (1.0 - hyde)))
	# The solid man is Jekyll in his place until he has thinned away, then Hyde in his.
	if apart < HYDE_SETS.x:
		_set_param("figure_face", 0.0)
		_set_param("figure_aside", Vector2.ZERO)
		_set_param("figure_solid", 1.0 - thinned)
	else:
		_set_param("figure_face", 1.0)
		_set_param("figure_aside", Vector2(HYDE_ASIDE * out, 0.0))
		_set_param("figure_solid", hyde)


func _between(times: Vector2, t: float) -> float:
	return smoothstep(times.x, times.y, t)


func _swap(face: float) -> void:
	shift = face
	face_changed.emit(face)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or parallax <= 0.0 or size.x <= 0.0:
		return
	var m := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
	_set_param("sway", m.clamp(-Vector2.ONE, Vector2.ONE) * parallax)


func _fit() -> void:
	if size.y <= 0.0:
		return
	var aspect := size.x / size.y
	var s := Vector2.ONE
	if aspect > BAKE_ASPECT:
		s.y = BAKE_ASPECT / aspect
	else:
		s.x = aspect / BAKE_ASPECT
	_set_param("uv_scale", s)


func _set_param(param: StringName, value: Variant) -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param, value)
