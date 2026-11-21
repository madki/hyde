@tool
class_name Background
extends ColorRect
## Full-screen street background. Set `shift` (0 = Jekyll, 1 = Hyde) or call `shift_to` to
## change the mood alone, or `transformation` / `transform_to` for the full change, in which
## the man himself turns into the other while the street shifts round him.
##
## Runs in the editor too: open scenes/background.tscn and drag `shift` to preview. The look
## (colours, glow, outlines, motion, transition) is edited on the node's material,
## shaders/background_material.tres. The street textures come from studio/bake.gd and the
## figure layer drawn over them from studio/figure_bake.gd.

const BAKE_ASPECT := 16.0 / 9.0

# The figure layer, art/bg/figures.png and figures_depth.png (baked by studio/figure_bake.gd,
# which reads these too: re-bake after changing any of them). The sheet holds the flipbook of
# Jekyll flowing into Hyde (played backwards for the change back) and, in a row under it, the
# two men standing still.
## The part of the baked picture the figure layer covers: x, y, width, height in 0..1.
const FIGURE_RECT := Rect2(536.0 / 1920.0, 312.0 / 1080.0, 768.0 / 1920.0, 768.0 / 1080.0)
const FIGURE_STILL_PX := 768 # FIGURE_RECT in pixels of the 1920 x 1080 bake
const MORPH_GRID := Vector2i(6, 6) # flipbook frames across and down
const MORPH_FRAMES := 36
const MORPH_FPS := 24.0
const MORPH_FRAME_PX := 512
## Distances from the camera, in metres, that the depth sheet's 0 and 1 stand for.
const FIGURE_DEPTH_RANGE := Vector2(1.0, 6.0)

# The full change, in seconds: the still figure fades into the flipbook's first frame, the
# flipbook plays, and its last frame fades into the still figure of the other man.
const BLEND := 0.1
const TRANSFORM_SECONDS := BLEND + MORPH_FRAMES / MORPH_FPS + BLEND
# The street's colours cross over between these times.
const SHIFT_FROM := BLEND + 0.3
const SHIFT_TO := BLEND + 1.2

## 0 = Jekyll, 1 = Hyde.
@export_range(0.0, 1.0) var shift := 0.0:
	set(value):
		shift = clampf(value, 0.0, 1.0)
		_set_param("shift", shift)

## The full change: 0 = Jekyll, 1 = Hyde, in between the man is part-way through turning into
## the other. Also sets `shift`, so the street changes with him.
@export_range(0.0, 1.0) var transformation := 0.0:
	set(value):
		transformation = clampf(value, 0.0, 1.0)
		_pose_transformation()

## How far the figure's outline trembles in the middle of the change, as a fraction of the
## picture. 0 = a clean, smooth change.
@export_range(0.0, 0.05) var wobble := 0.0

## How far the view leans towards the mouse while the game runs. 0 turns the parallax off.
@export_range(0.0, 1.0) var parallax := 1.0

var _mouse_seen := false

var _tween: Tween


func _ready() -> void:
	# In the game each picture has a material of its own, so that two of them do not share
	# one face. In the editor it stays the saved one, to be edited there.
	if material and not Engine.is_editor_hint():
		material = material.duplicate()
	_set_param("shift", shift)
	_set_param("morph_grid", Vector2(MORPH_GRID))
	_set_param("morph_frames", float(MORPH_FRAMES))
	_set_param("morph_frame_px", float(MORPH_FRAME_PX))
	_set_param("figure_still_px", float(FIGURE_STILL_PX))
	_set_param("figure_rect", Vector4(FIGURE_RECT.position.x, FIGURE_RECT.position.y,
			FIGURE_RECT.size.x, FIGURE_RECT.size.y))
	_set_param("figure_depth_range", FIGURE_DEPTH_RANGE)
	# With no change part-way or done, the street keeps the `shift` it was given.
	var given := shift
	_pose_transformation()
	if transformation <= 0.0:
		shift = given
	_set_param("sway", Vector2.ZERO)
	resized.connect(_fit)
	_fit()


## Tween to a face over `seconds`.
func shift_to(target: float, seconds := 1.2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "shift", target, seconds)


## Play the full change to a face (0 = Jekyll, 1 = Hyde). `seconds` is for the whole way; a
## change from part-way takes its share of it.
func transform_to(target: float, seconds := TRANSFORM_SECONDS) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "transformation", target,
			seconds * absf(target - transformation))


## Sets the figure and the street for the current `transformation`.
func _pose_transformation() -> void:
	if transformation <= 0.0 or transformation >= 1.0:
		_set_param("figure_face", -1.0)
		_set_param("figure_wobble", 0.0)
		_set_param("morph_mix", 0.0)
		shift = transformation
		return
	var t := transformation * TRANSFORM_SECONDS
	var play := t - BLEND # seconds into the flipbook
	var length := MORPH_FRAMES / MORPH_FPS
	# The shader blends each frame into the next, so the change is smooth at any speed.
	_set_param("morph_frame", clampf(play / length, 0.0, 1.0) * (MORPH_FRAMES - 1.0))
	_set_param("morph_mix", smoothstep(-BLEND, 0.0, play) * (1.0 - smoothstep(length, length + BLEND, play)))
	_set_param("figure_face", 0.0 if play < length * 0.5 else 1.0)
	_set_param("figure_wobble", wobble * sin(clampf(play / length, 0.0, 1.0) * PI))
	shift = smoothstep(SHIFT_FROM, SHIFT_TO, t)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true


func _process(_delta: float) -> void:
	# Until the mouse has moved nobody knows where it is (on the Web it reads as the top left
	# corner), so the view stays level.
	if Engine.is_editor_hint() or parallax <= 0.0 or size.x <= 0.0 or not _mouse_seen:
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
