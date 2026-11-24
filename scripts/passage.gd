class_name Passage
extends CanvasLayer
## The way from one screen to the next: the screen goes to night, a line may name where the
## player is going, in that place's light, the new screen is put in place while all is
## covered, and the night lifts off it. SceneFlow owns one and keeps it across changes of
## screen. A key or a click while it runs ends the stage under way at once (the change of
## screen itself is always made), and goes no further: the screens under it never see it.

## How long the night takes to fall, to stay with a line on it, and to lift, in seconds.
const FALLS := 0.22
const STAYS := 0.42
const STAYS_BARE := 0.04 # without a line: just long enough to read as one movement
const LIFTS := 0.3
## How long the line takes to come up once the night is down.
const LINE_RISES := 0.14
## Frames waited after the new screen is in the tree before the night lifts, so its first
## laid-out frame is the first one seen.
const SETTLE_FRAMES := 2
## The most one frame moves a stage on, in seconds.
const MAX_STEP := 0.1

const NIGHT := Palette.NIGHT_1
const LINE_SIZE := 34

var _cover := 0.0
var _line_alpha := 0.0
var _line := ""
var _light := Palette.CHALK
var _running := false
var _hurry := false
var _font: Font = ThemeDB.fallback_font
var _sheet: Control


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)
	visible = false


func is_running() -> bool:
	return _running


## Covers the screen, changes it to `scene` and uncovers it. `line`, when given, is shown on
## the night in `light`. Returns when the night has lifted.
func run(scene: String, line: String = "", light: Color = Palette.CHALK) -> void:
	_running = true
	_hurry = false
	_close_input(true)
	_line = line
	_light = light
	_cover = 0.0
	_line_alpha = 0.0
	visible = true
	_sheet.queue_redraw()

	await _stage(FALLS, func(k: float) -> void: _cover = _ease_in_out(k))
	if _line != "":
		await _stage(STAYS, func(k: float) -> void:
			_line_alpha = clampf(k * STAYS / LINE_RISES, 0.0, 1.0))
	else:
		await _stage(STAYS_BARE, func(_k: float) -> void: pass)

	var tree := get_tree()
	tree.change_scene_to_file(scene)
	await tree.scene_changed
	for i in SETTLE_FRAMES:
		await tree.process_frame

	_hurry = false # a key pressed while the screen changed ends the lifting, not more
	await _stage(LIFTS, func(k: float) -> void: _cover = 1.0 - _ease_in_out(k))
	visible = false
	_running = false
	_close_input(false)


# Runs one stage: `apply` is called each frame with how far it has come, from 0 to 1, over
# `duration` seconds; a key or a click ends it at once.
func _stage(duration: float, apply: Callable) -> void:
	_hurry = false
	var time := 0.0
	while true:
		var k := 1.0 if _hurry or duration <= 0.0 else clampf(time / duration, 0.0, 1.0)
		apply.call(k)
		_sheet.queue_redraw()
		if k >= 1.0:
			break
		await get_tree().process_frame
		# A long frame (the new screen being loaded and laid out) moves it on by a step only.
		time += minf(get_process_delta_time(), MAX_STEP)
	_hurry = false


# While the passage runs, the window takes no input at all (the screens under it would have
# it in their `_input` before this node, which comes earlier in the tree): a key or a click
# is seen here only, from the window's signal, which comes before the window passes it on.
func _close_input(closed: bool) -> void:
	var window := get_window()
	window.set_disable_input(closed)
	if closed and not window.window_input.is_connected(_on_window_input):
		window.window_input.connect(_on_window_input)
	elif not closed and window.window_input.is_connected(_on_window_input):
		window.window_input.disconnect(_on_window_input)


func _on_window_input(event: InputEvent) -> void:
	if _running and _is_press(event):
		_hurry = true


static func _is_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key:
		return key.pressed and not key.echo
	var button := event as InputEventMouseButton
	if button:
		return button.pressed
	var touch := event as InputEventScreenTouch
	if touch:
		return touch.pressed
	return false


static func _ease_in_out(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func _draw_sheet() -> void:
	if _cover <= 0.0:
		return
	var size := _sheet.size
	_sheet.draw_rect(Rect2(Vector2.ZERO, size), Color(NIGHT, _cover))
	if _line == "" or _line_alpha <= 0.0:
		return
	var alpha := _line_alpha * _cover
	var width := _font.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x
	var base := Vector2((size.x - width) * 0.5,
			size.y * 0.5 + (_font.get_ascent(LINE_SIZE) - _font.get_descent(LINE_SIZE)) * 0.5)
	_sheet.draw_string_outline(_font, base, _line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE,
			6, Color(Palette.OUTLINE, alpha))
	_sheet.draw_string(_font, base, _line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE,
			Color(_light, alpha))
