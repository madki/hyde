class_name StoryPage
extends Control
## A sheet of the journal laid over whatever screen it is added to, on which lines of the story
## are written one after another:
##
##   await StoryPage.tell_over(self, ["opening.1", "opening.2"])
##
## Each key's line is taken from `StoryLines` and written in that line's hand by a `StoryEntry`,
## each taking the place of the last; a key with no line is passed over. The presses are the
## entry's own: the first writes the rest of a line, the next moves on. While the page is up
## nothing under it sees a press, a key or a touch going down; one let go is let through, so
## that what was held before the page is not left held.
##
## The page is deaf while it comes up and for DEAF seconds after: a press that was hurrying
## what came before it is swallowed, and loses no line.

## What is under the page dims to this.
const DIM := Color(Palette.NIGHT_1, 0.6)
## How long the page takes to come and to go, in seconds.
const FADE := 0.2
## How long after the page is up a press is not yet heard, in seconds.
const DEAF := 0.5
const SHEET := Vector2(640.0, 360.0)
## From the sheet's edge to the entry.
const MARGIN := 40.0

var _dim := ColorRect.new()
var _sheet := Panel.new()
var _entry := StoryEntry.new()
var _tween: Tween
## True while a line is being written or waits: its presses are left to the entry.
var _writing := false
## What is left of the deaf time, in seconds; the entry hears no press until it is over.
var _deaf := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0

	_dim.color = DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_theme_stylebox_override("panel", _paper())
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.offset_left = -SHEET.x * 0.5
	_sheet.offset_right = SHEET.x * 0.5
	_sheet.offset_top = -SHEET.y * 0.5
	_sheet.offset_bottom = SHEET.y * 0.5
	add_child(_sheet)

	_entry.position = Vector2(MARGIN, MARGIN)
	_sheet.add_child(_entry)


## Makes a page, adds it to `host`, tells `keys` on it and frees it.
static func tell_over(host: Node, keys: Array) -> void:
	var page := StoryPage.new()
	host.add_child(page)
	await page.tell(keys)
	page.queue_free()


## Shows the page, writes each key's line on it in turn, and returns when the last has been
## moved on and the page has gone. With no key that has a line, no page is shown.
func tell(keys: Array) -> void:
	var lines: Array[Dictionary] = []
	for key: Variant in keys:
		var line := StoryLines.line(str(key))
		if not line.is_empty():
			lines.append(line)
	if lines.is_empty():
		return
	visible = true
	_deaf = DEAF
	_entry.set_process_input(false)
	await _fade(1.0)
	for line in lines:
		_writing = true
		await _entry.write(line["text"], line.get("hand", "jekyll"))
		_writing = false
	await _fade(0.0)
	visible = false


## Moves the page on by `seconds`, as if that much time had passed: the page's coming is
## finished at once and the line's writing moved on by `seconds`. For a still part-way.
func pass_time(seconds: float) -> void:
	if _tween and _tween.is_valid() and _tween.is_running():
		_tween.custom_step(FADE)
	_hear_after(seconds)
	_entry.pass_time(seconds)


## True while a whole line is on the page and waits for a press.
func is_waiting() -> bool:
	return _entry.is_waiting()


## A press made for the player, deaf time or not: writes the rest of the line, or moves on
## from a whole one. For a page with no player before it.
func press() -> void:
	_entry.press()


func _process(delta: float) -> void:
	# The deaf time is counted from when the page is up.
	if visible and modulate.a >= 1.0:
		_hear_after(delta)


# Counts `seconds` off the deaf time; when it is over the entry hears its presses.
func _hear_after(seconds: float) -> void:
	if _deaf <= 0.0:
		return
	_deaf -= seconds
	if _deaf <= 0.0:
		_entry.set_process_input(true)


func _fade(to: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to, FADE)
	await _tween.finished


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch
			or event is InputEventJoypadButton or event is InputEventAction):
		return
	# What is let go is let through: a key held before the page is not left held under it.
	if not event.is_pressed():
		return
	# The entry's own presses are its to take, once it hears them.
	if _writing and _deaf <= 0.0 and _is_press(event):
		return
	get_viewport().set_input_as_handled()


func _is_press(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


# The journal's paper: the page's blue, lit at its edge, with a shadow under it.
func _paper() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAGE
	box.border_color = Palette.PAGE_LIGHT
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.shadow_color = Color(Palette.OUTLINE, 0.6)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0.0, 6.0)
	return box
