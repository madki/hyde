@tool
class_name Background
extends ColorRect
## Full-screen street background. Set `shift` (0 = Jekyll, 1 = Hyde) or call `shift_to`.
##
## Runs in the editor too: open scenes/background.tscn and drag `shift` to preview. The look
## (colours, glow, outlines, motion, transition) is edited on the node's material,
## shaders/background_material.tres. The textures come from studio/bake.gd.

const BAKE_ASPECT := 16.0 / 9.0

## 0 = Jekyll, 1 = Hyde.
@export_range(0.0, 1.0) var shift := 0.0:
	set(value):
		shift = clampf(value, 0.0, 1.0)
		_set_param("shift", shift)

## How far the view leans towards the mouse while the game runs. 0 turns the parallax off.
@export_range(0.0, 1.0) var parallax := 1.0

var _tween: Tween


func _ready() -> void:
	_set_param("shift", shift)
	_set_param("sway", Vector2.ZERO)
	resized.connect(_fit)
	_fit()


## Tween to a face over `seconds`.
func shift_to(target: float, seconds := 1.2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "shift", target, seconds)


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
