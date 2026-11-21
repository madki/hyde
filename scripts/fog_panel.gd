class_name FogPanel
extends PanelContainer
## Sliders for a background's fog and how its brightest light is held back, for finding a setting by eye while the game runs. A tool for
## working on a picture, not part of the game: it only exists in debug builds, starts hidden,
## and F shows and hides it (`--fog` starts with it shown).
##
## It changes the material of the node at `target` as the sliders move. "Save" writes the fog
## settings, and nothing else, into that material's file; "Reset" goes back to how they were
## when the scene opened.

## Each setting: its name on the panel, the shader parameter, which part of a vec2 it is
## (-1 = the parameter is a plain number), lowest and highest value.
const SETTINGS := [
	["Fog everywhere", "mist", -1, 0.0, 1.0],
	["Lamp light in the fog", "mist_light", -1, 0.0, 3.0],
	["Fog's own glow", "mist_glow", -1, 0.0, 2.0],
	["Fog pool: strength", "mist_pool", -1, 0.0, 1.0],
	["Fog pool: across", "mist_pool_at", 0, 0.0, 1.0],
	["Fog pool: down", "mist_pool_at", 1, 0.0, 1.0],
	["Fog pool: width", "mist_pool_size", 0, 0.05, 1.0],
	["Fog pool: height", "mist_pool_size", 1, 0.05, 1.0],
	["Highlight roll-off", "highlight_rolloff", -1, 0.0, 2.0],
]

## The background whose material the sliders change.
@export var target: NodePath

var _material: ShaderMaterial
var _start := {} # parameter -> its value when the scene opened
var _sliders: Array[HSlider] = []
var _values: Array[Label] = []
var _status: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_material = (get_node(target) as CanvasItem).material as ShaderMaterial
	visible = Shot.has_arg("fog")
	var rows := VBoxContainer.new()
	add_child(rows)
	var title := Label.new()
	title.text = "Fog and light  (F hides this)"
	rows.add_child(title)
	for i in SETTINGS.size():
		var setting: Array = SETTINGS[i]
		_start[setting[1]] = _read(setting[1])
		var row := HBoxContainer.new()
		rows.add_child(row)
		var name_label := Label.new()
		name_label.text = setting[0]
		name_label.custom_minimum_size.x = 190.0
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = setting[3]
		slider.max_value = setting[4]
		slider.step = 0.01
		slider.custom_minimum_size.x = 220.0
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE # so keys still reach the scene
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 44.0
		row.add_child(value)
		_sliders.append(slider)
		_values.append(value)
		slider.value_changed.connect(_changed.bind(i))
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for action: Array in [["Save", _save], ["Reset", _reset]]:
		var button := Button.new()
		button.text = action[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		buttons.add_child(button)
	_status = Label.new()
	buttons.add_child(_status)
	_show_values()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F:
		visible = not visible


## A parameter's value on the material, or the shader's own if the material leaves it alone.
func _read(param: String) -> Variant:
	var value: Variant = _material.get_shader_parameter(param)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), param)
	return value


func _changed(value: float, index: int) -> void:
	var setting: Array = SETTINGS[index]
	if setting[2] < 0:
		_material.set_shader_parameter(setting[1], value)
	else:
		var pair: Vector2 = _read(setting[1])
		pair[setting[2]] = value
		_material.set_shader_parameter(setting[1], pair)
	_values[index].text = "%.2f" % value
	_status.text = ""


## Puts every slider where its setting now is.
func _show_values() -> void:
	for i in SETTINGS.size():
		var setting: Array = SETTINGS[i]
		var value: Variant = _read(setting[1])
		var number: float = value if setting[2] < 0 else (value as Vector2)[setting[2]]
		_sliders[i].set_value_no_signal(number)
		_values[i].text = "%.2f" % number


func _reset() -> void:
	for param: String in _start:
		_material.set_shader_parameter(param, _start[param])
	_show_values()
	_status.text = "as it was"


## Writes the fog settings into the material's file. The file is read afresh for it, so what
## the scene itself sets on the material while it runs is not saved with them.
func _save() -> void:
	var path := _material.resource_path
	var on_disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	if on_disk == null:
		_status.text = "cannot save: the material has no file"
		return
	for param: String in _start:
		on_disk.set_shader_parameter(param, _read(param))
	var err := ResourceSaver.save(on_disk, path)
	_status.text = "saved" if err == OK else "could not save (%d)" % err
