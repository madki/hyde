@tool
class_name LabBackground
extends ColorRect
## Full-screen picture of Dr Jekyll's laboratory at night: his table of glassware, the window
## and Jekyll in the chair beside it, in the bottom left corner, and the dark of the room over the rest,
## which is left free for whatever is laid over it. The back alley's opposite number
## (scripts/alley_background.gd), in Jekyll's colours.
##
## Drawn by the street's shader (shaders/background.gdshader) with a material of its own,
## shaders/lab_material.tres: edit the look (colours, fog, glow, outlines) there, or open
## scenes/lab_background.tscn to see it in the editor. The textures come from tools/bake_lab.sh.
##
## Jekyll sits still, so he is baked into the picture with the chair he sits in and there is no
## figure layer (the man in the alley has one, studio/alley_figure_bake.gd).

const BAKE_ASPECT := 16.0 / 9.0
## The corner the picture is pinned to when the screen is not 16:9, so the table is never cut off.
const ANCHOR := Vector2(0.0, 1.0)
## Where the figure layer is: off the picture, as there is none.
const NO_FIGURE := Vector4(2.0, 2.0, 1.0, 1.0)

## How far the view leans towards the mouse while the game runs. 0 turns the parallax off.
@export_range(0.0, 1.0) var parallax := 1.0

var _mouse_seen := false


func _ready() -> void:
	# In the game each picture has a material of its own, so that two of them do not share
	# one face. In the editor it stays the saved one, to be edited there.
	if material and not Engine.is_editor_hint():
		material = material.duplicate()
	_set_param("shift", 0.0) # the shader's Jekyll face
	_set_param("figure_rect", NO_FIGURE)
	_set_param("figure_wobble", 0.0)
	_set_param("morph_mix", 0.0)
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
