@tool
class_name AlleyBackground
extends ColorRect
## Full-screen picture of the back alley: Hyde letting himself in by the door, in the bottom
## right corner, and fog over the rest, which is left free for whatever is laid over it.
##
## Drawn by the street's shader (shaders/background.gdshader) with a material of its own,
## shaders/alley_material.tres: edit the look (colours, fog, glow, outlines) there, or open
## scenes/alley_background.tscn to see it in the editor. The textures come from
## tools/bake_alley.sh.

const BAKE_ASPECT := 16.0 / 9.0
## The corner the picture is pinned to when the screen is not 16:9, so the man is never cut off.
const ANCHOR := Vector2(1.0, 1.0)

# The figure layer, art/bg/alley_figure.png (baked by studio/alley_figure_bake.gd, which reads
# these too: re-bake after changing any of them).
const FIGURE_PX := 640 # FIGURE_RECT in pixels of the 1920 x 1080 bake
## The part of the baked picture the figure layer covers: x, y, width, height in 0..1.
const FIGURE_RECT := Rect2(1220.0 / 1920.0, 440.0 / 1080.0, 640.0 / 1920.0, 640.0 / 1080.0)
## Distances from the camera, in metres, that the depth sheet's 0 and 1 stand for.
const FIGURE_DEPTH_RANGE := Vector2(2.0, 8.0)

## How far the view leans towards the mouse while the game runs. 0 turns the parallax off.
@export_range(0.0, 1.0) var parallax := 1.0

var _mouse_seen := false


func _ready() -> void:
	# In the game each picture has a material of its own, so that two of them do not share
	# one face. In the editor it stays the saved one, to be edited there.
	if material and not Engine.is_editor_hint():
		material = material.duplicate()
	# The shader's Hyde face, showing the one man on the figure sheet.
	_set_param("shift", 1.0)
	_set_param("figure_face", 0.0)
	_set_param("figure_px", float(FIGURE_PX))
	_set_param("figure_rect", Vector4(FIGURE_RECT.position.x, FIGURE_RECT.position.y,
			FIGURE_RECT.size.x, FIGURE_RECT.size.y))
	_set_param("figure_depth_range", FIGURE_DEPTH_RANGE)
	_set_param("uv_anchor", ANCHOR)
	_set_param("sway", Vector2.ZERO)
	resized.connect(_fit)
	_fit()


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
