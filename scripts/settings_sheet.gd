class_name SettingsSheet
extends CanvasLayer
## The settings sheet: the player's settings (Settings) on a panel like the places' (PlacePanel),
## laid over whatever screen opened it, above everything on that screen.
##
##   var sheet := SettingsSheet.open(self)
##   sheet.closed.connect(_on_settings_closed)
##
## Rows: Music and Effects (sliders, 0 to 100 by 10), Full screen and Reduce flashes
## (switches), Close. Up and Down choose a row, Left and Right move a slider or flip a switch,
## Enter (or Space) flips a switch or closes on Close, Escape closes. The mouse works on every
## row: a click flips a switch, a click or a drag on a slider sets it. A click outside the panel
## closes the sheet. The sheet takes the pointer in its own `_input`, before any screen's, so
## no click goes through it. Every change is applied and kept at once (Settings.set_*). Letting go of
## the Effects slider, or a step of it by key, plays one short sound at the new level.
##
## While it is open the screen under it takes no key and no click: a key pressed goes to the
## sheet alone (a key let go is let through, so nothing under it is left held). A screen that
## takes Escape itself asks `SettingsSheet.is_open()` first.

## The sheet has been closed (it is freed after).
signal closed

enum Row { MUSIC, EFFECTS, FULL_SCREEN, REDUCE_FLASHES, CLOSE }

## Above every layer a screen has of its own.
const LAYER := 100
const HEADING := "Settings"
const ROWS: Array[String] = ["Music", "Effects", "Full screen", "Reduce flashes", "Close"]
const NOTE := "Up and Down choose, Left and Right change, Esc closes"
## The panel's width; it widens itself if its writing needs more.
const WIDTH := 460.0
## A slider's step, and its ends.
const STEP := 10
const MOST := 100
## The sound a change of the Effects level is heard by: short and quiet.
const EFFECTS_SOUND := "button"

## How many sheets are open now.
static var _open_count := 0

## The settings shown and changed: the Settings autoload, or another (a test's).
var settings: Node
var _shade := ColorRect.new()
var _panel := _Panel.new()
var _is_open := false


## Opens a sheet over `parent`'s screen (added under `parent`, drawn above all of it) and
## returns it. `accent` is the light of the chosen row, as on that screen's panel.
static func open(parent: Node, accent: Color = Palette.JEKYLL) -> SettingsSheet:
	var sheet := SettingsSheet.new()
	if parent.is_inside_tree():
		sheet.settings = parent.get_node_or_null("/root/Settings")
	sheet._panel.accent = accent
	parent.add_child(sheet)
	return sheet


## True while any settings sheet is open.
static func is_open() -> bool:
	return _open_count > 0


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade.color = HelpBook.SHADE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	_panel.sheet = self
	add_child(_panel)
	_panel.set_heading(HEADING)
	_panel.note = NOTE
	var rows: Array = []
	for text in ROWS:
		rows.append({text = text})
	_panel.size.x = WIDTH
	_panel.set_rows(rows, false)
	_is_open = true
	_open_count += 1


func _ready() -> void:
	_read_window()
	_panel.resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	_place()
	_play("paper", 1.0, 0.8)


func _exit_tree() -> void:
	_forget()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_forget()


# No longer counted as open.
func _forget() -> void:
	if _is_open:
		_is_open = false
		_open_count -= 1


## Closes the sheet: `closed` is sent and the sheet is freed.
func close() -> void:
	if not _is_open:
		return
	_forget()
	_play("paper", 0.85, 0.45)
	closed.emit()
	queue_free()


## The selected row (a Row).
func selected() -> int:
	return _panel.selected()


## Selects a row (a Row).
func select(row: int) -> void:
	_panel.select(row)


## A key pressed, as the sheet takes it. True if it was one of the sheet's keys.
func press(keycode: Key, echo: bool = false) -> bool:
	match keycode:
		KEY_UP:
			_panel.move_selection(-1)
		KEY_DOWN:
			_panel.move_selection(1)
		KEY_LEFT:
			_change(selected(), -1)
		KEY_RIGHT:
			_change(selected(), 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not echo:
				_take(selected())
		KEY_ESCAPE:
			if not echo:
				close()
		_:
			return false
	return true


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		# The pointer is the sheet's too: a screen's own `_input` (which comes before the GUI)
		# must not take a click meant for the sheet. Touch reaches it as the mouse.
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		if event is InputEventMouse:
			point(event)
		return
	var key := event as InputEventKey
	if not key or not key.pressed:
		return
	# Every key pressed is the sheet's while it is open.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	press(key.keycode, key.echo)


## A mouse event, in the window's coordinates, as the sheet takes it: on the panel (or while a
## slider is dragged) it goes to the panel; a left press outside the panel closes the sheet.
func point(event: InputEventMouse) -> void:
	var local := _panel.get_global_transform_with_canvas().affine_inverse() * event.position
	var button := event as InputEventMouseButton
	if _panel._dragging < 0 and not Rect2(Vector2.ZERO, _panel.size).has_point(local):
		if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			close()
		return
	var moved := event.duplicate() as InputEventMouse
	moved.position = local
	_panel._gui_input(moved)


func _on_shade_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		close()
	_shade.accept_event()


## The window's real mode: on the Web, the browser's Escape leaves full screen unasked.
func _read_window() -> void:
	if settings == null:
		return
	var mode := DisplayServer.window_get_mode()
	settings.full_screen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	_panel.position = ((view - _panel.size) * 0.5).floor()


## The row's level, 0 to 100 (a slider), 1 or 0 (a switch), or -1.
func level(row: int) -> int:
	if settings == null:
		return -1
	match row:
		Row.MUSIC:
			return settings.music
		Row.EFFECTS:
			return settings.effects
		Row.FULL_SCREEN:
			return 1 if settings.full_screen else 0
		Row.REDUCE_FLASHES:
			return 1 if settings.reduce_flashes else 0
	return -1


static func is_slider(row: int) -> bool:
	return row == Row.MUSIC or row == Row.EFFECTS


static func is_switch(row: int) -> bool:
	return row == Row.FULL_SCREEN or row == Row.REDUCE_FLASHES


## Left or Right on a row: a slider by a step, a switch flipped.
func _change(row: int, direction: int) -> void:
	if is_slider(row):
		if set_level(row, level(row) + direction * STEP):
			_heard(row)
		else:
			_play("refuse")
	elif is_switch(row):
		_flip(row)


## Enter or a click on a row.
func _take(row: int) -> void:
	if is_switch(row):
		_flip(row)
	elif row == Row.CLOSE:
		_play("button")
		close()


## Sets a slider to `value` (to the nearest step, within 0 and 100). True if it changed.
func set_level(row: int, value: int) -> bool:
	if settings == null:
		return false
	var to := clampi(roundi(value / float(STEP)) * STEP, 0, MOST)
	if to == level(row):
		return false
	if row == Row.MUSIC:
		settings.set_music(to)
	elif row == Row.EFFECTS:
		settings.set_effects(to)
	_panel.queue_redraw_rows()
	return true


## The sound a slider's new level is heard by: Effects plays a short sound at that level;
## Music is heard as it plays, so it only ticks.
func _heard(row: int) -> void:
	if row == Row.EFFECTS:
		_play(EFFECTS_SOUND)
	elif is_inside_tree():
		_panel.tick()


# A sound, when the sheet is on a screen (not in a test).
func _play(sound: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	if is_inside_tree():
		Sfx.play(sound, pitch, volume)


# Called from the click or the key itself: on the Web, full screen is let in only from there.
func _flip(row: int) -> void:
	if settings == null:
		return
	if row == Row.FULL_SCREEN:
		settings.set_full_screen(not settings.full_screen)
	elif row == Row.REDUCE_FLASHES:
		settings.set_reduce_flashes(not settings.reduce_flashes)
	_play("button")
	_panel.queue_redraw_rows()


## The place panel, with each row's slider or switch drawn at its right.
class _Panel extends PlacePanel:
	const SLIDER := 150.0 # a slider's track
	const NUMBER := 40.0 # room for a slider's number, right of its track
	const SWITCH := Vector2(36.0, 18.0)
	const SWITCH_WORD := 34.0 # room for "On" or "Off", right of the switch
	const KNOB := 6.0
	const SMALL := 15

	var sheet: SettingsSheet
	## The slider being dragged, -1 if none.
	var _dragging := -1

	func tick() -> void:
		_tick()

	func _notification(what: int) -> void:
		# A panel freed without ever being on a screen (a test's) has not taken its list in.
		if what == NOTIFICATION_PREDELETE and is_instance_valid(_list) and not _list.get_parent():
			_list.free()

	func queue_redraw_rows() -> void:
		_redraw()

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		var motion := event as InputEventMouseMotion
		if _dragging >= 0:
			if motion:
				sheet.set_level(_dragging, _level_at(motion.position.x))
			elif button and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
				if _dragging == SettingsSheet.Row.EFFECTS:
					sheet._heard(_dragging)
				_dragging = -1
			accept_event()
			return
		if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(button.position)
			if SettingsSheet.is_slider(row):
				select(row)
				_dragging = row
				if sheet.set_level(row, _level_at(button.position.x)) and row == SettingsSheet.Row.MUSIC:
					tick()
				accept_event()
				return
			if row >= 0:
				select(row)
				sheet._take(row)
			accept_event()
			return
		super._gui_input(event)
		accept_event()

	## The slider's track, in the panel's coordinates: x from and to.
	func _track() -> Vector2:
		var right := size.x - PAD - NUMBER
		return Vector2(right - SLIDER, right)

	func _level_at(x: float) -> int:
		var track := _track()
		return roundi(clampf((x - track.x) / (track.y - track.x), 0.0, 1.0) * SettingsSheet.MOST)

	func _draw_row(index: int, rect: Rect2) -> void:
		super._draw_row(index, rect)
		var level := sheet.level(index) if sheet else -1
		if level < 0:
			return
		var chosen := index == selected()
		var light := accent if chosen else Palette.CHALK_2
		var mid := rect.get_center().y
		var base := mid + (_font.get_ascent(SMALL) - _font.get_descent(SMALL)) * 0.5
		if SettingsSheet.is_slider(index):
			var track := _track()
			var at := lerpf(track.x, track.y, level / float(SettingsSheet.MOST))
			_list.draw_line(Vector2(track.x, mid), Vector2(track.y, mid), Palette.RULE, 2.0)
			# A notch at each step.
			for step in range(0, SettingsSheet.MOST + 1, SettingsSheet.STEP):
				var x := lerpf(track.x, track.y, step / float(SettingsSheet.MOST))
				_list.draw_line(Vector2(x, mid - 3.0), Vector2(x, mid + 3.0), Palette.RULE, 1.0)
			if at > track.x:
				_list.draw_line(Vector2(track.x, mid), Vector2(at, mid), light, 2.0)
			_list.draw_circle(Vector2(at, mid), KNOB, light)
			var number := str(level)
			var width := _text_width(number, SMALL)
			_list.draw_string(_font, Vector2(size.x - PAD + 4.0 - width, base), number,
					HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Palette.CHALK if chosen else Palette.CHALK_2)
		else:
			var on := level > 0
			var box := Rect2(Vector2(size.x - PAD - SWITCH_WORD - SWITCH.x, mid - SWITCH.y * 0.5),
					SWITCH)
			_list.draw_rect(box, light if on else Palette.NIGHT_1)
			_list.draw_rect(box, light if on or chosen else Palette.RULE, false, 1.0)
			var knob_x := box.end.x - SWITCH.y * 0.5 if on else box.position.x + SWITCH.y * 0.5
			_list.draw_circle(Vector2(knob_x, mid), KNOB, Palette.NIGHT_1 if on else Palette.CHALK_3)
			var word := "On" if on else "Off"
			var width := _text_width(word, SMALL)
			_list.draw_string(_font, Vector2(size.x - PAD + 4.0 - width, base), word,
					HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Palette.CHALK if chosen else Palette.CHALK_2)
