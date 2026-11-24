class_name PlacePanel
extends Control
## The panel the place screens (title, alley, laboratory) show their menu on, drawn by code:
## a night surface ruled at the edge, sitting in a soft dark that fades into the picture
## behind it. A heading, then rows to choose from, each with an optional price; the chosen
## one is lit by the light the caller gives (Jekyll's or Hyde's). Up and Down (or the mouse)
## move the selection, Enter, Space or a click take the row.
##
##   panel.set_heading("Hyde")
##   panel.set_rows([{text = "Begin"}, {text = "Tonic", price = 3, enabled = false}])
##   panel.row_chosen.connect(_on_row_chosen)
##
## The panel sets its own height from what it holds, and widens itself if the writing needs
## it; the caller places it and may set a larger width.

## A row was taken: its index in the rows given to set_rows.
signal row_chosen(index: int)

const PAD := 22.0 # from the edge to the writing
const HEADING_SIZE := 30
const ROW_SIZE := 20
const NOTE_SIZE := 13
const ROW_HEIGHT := 38.0
const HEADING_GAP := 14.0 # between the heading's rule and the first row
const MARKER := 7.0 # half the width of the chosen row's marker
const SCRIM := 72 # how far the dark around the panel reaches into the picture
const SURFACE_ALPHA := 0.9
const SCRIM_ALPHA := 0.85

## The light of the chosen row's marker and rim: Palette.JEKYLL or Palette.HYDE.
@export var accent := Palette.JEKYLL:
	set(value):
		accent = value
		queue_redraw()

## A line of small writing under the rows (how to use the panel), or "" for none.
@export var note := "":
	set(value):
		note = value
		_fit()

## While false the panel shows but does not take keys or clicks.
@export var active := true

var _heading := ""
var _rows: Array[Dictionary] = []
var _selected := -1
var _font: Font = ThemeDB.fallback_font
var _surface := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_surface.bg_color = Palette.NIGHT_2
	_surface.bg_color.a = SURFACE_ALPHA
	_surface.border_color = Palette.RULE
	_surface.set_border_width_all(1)
	_surface.set_corner_radius_all(2)
	# The dark the panel sits in, thinning out as it reaches into the picture.
	_surface.shadow_color = Palette.NIGHT_1
	_surface.shadow_color.a = SCRIM_ALPHA
	_surface.shadow_size = SCRIM
	_fit()


## The writing at the top of the panel.
func set_heading(text: String) -> void:
	_heading = text
	_fit()


## Each row is {text: String, price: int (optional, shown in gold when >= 0),
## enabled: bool (optional, true)}. The selection goes to the first row that can be taken.
func set_rows(rows: Array) -> void:
	_rows.clear()
	for row: Dictionary in rows:
		_rows.append({
			text = String(row.get("text", "")),
			price = int(row.get("price", -1)),
			enabled = bool(row.get("enabled", true)),
		})
	_selected = -1
	select(_step_from(-1, 1))
	_fit()


## The selected row's index, -1 if none can be taken.
func selected() -> int:
	return _selected


## Selects a row that can be taken; anything else is ignored.
func select(index: int) -> void:
	if index < 0 or index >= _rows.size() or not _rows[index].enabled:
		return
	_selected = index
	queue_redraw()


## Moves the selection by `step` rows (negative is up), skipping rows that cannot be taken
## and going round at the ends.
func move_selection(step: int) -> void:
	for i in absi(step):
		select(_step_from(_selected, signi(step)))


## Takes the selected row, as Enter does.
func choose() -> void:
	if _selected >= 0 and _rows[_selected].enabled:
		row_chosen.emit(_selected)


func _step_from(from: int, direction: int) -> int:
	var count := _rows.size()
	if count == 0:
		return -1
	var at := from
	for i in count:
		at = posmod(at + direction, count)
		if _rows[at].enabled:
			return at
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if not key or not key.pressed:
		return
	match key.keycode:
		KEY_UP:
			move_selection(-1)
		KEY_DOWN:
			move_selection(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if key.echo:
				return
			choose()
		_:
			return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		var hovered := _row_at(motion.position)
		if hovered >= 0 and hovered != _selected:
			select(hovered)
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _row_at(button.position)
		if clicked >= 0 and _rows[clicked].enabled:
			select(clicked)
			choose()
			accept_event()


func _row_at(point: Vector2) -> int:
	for i in _rows.size():
		if _row_rect(i).has_point(point):
			return i
	return -1


func _heading_bottom() -> float:
	if _heading.is_empty():
		return PAD * 0.5
	return PAD + _font.get_height(HEADING_SIZE) + 8.0


func _row_rect(index: int) -> Rect2:
	var top := _heading_bottom() + HEADING_GAP + index * ROW_HEIGHT
	return Rect2(6.0, top, size.x - 12.0, ROW_HEIGHT - 4.0)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Sets the height to what the panel holds, and the width to at least what it needs.
func _fit() -> void:
	var height := _heading_bottom() + HEADING_GAP + _rows.size() * ROW_HEIGHT
	if not note.is_empty():
		height += 6.0 + _font.get_height(NOTE_SIZE)
	height += PAD * 0.75
	# Wide enough for every line of writing.
	var width := _text_width(_heading, HEADING_SIZE)
	width = maxf(width, _text_width(note, NOTE_SIZE))
	for row in _rows:
		var price_width := 0.0
		if row.price >= 0:
			price_width = _text_width(str(row.price), ROW_SIZE) + 30.0
		width = maxf(width, _text_width(row.text, ROW_SIZE) + 10.0 + price_width)
	custom_minimum_size = Vector2(ceilf(width + 2.0 * PAD), height)
	size = Vector2(maxf(size.x, custom_minimum_size.x), height)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_surface, Rect2(Vector2.ZERO, size))

	var x := PAD
	if not _heading.is_empty():
		var base := PAD + _font.get_ascent(HEADING_SIZE)
		draw_string(_font, Vector2(x, base), _heading, HORIZONTAL_ALIGNMENT_LEFT,
				size.x - 2.0 * PAD, HEADING_SIZE, Palette.CHALK)
		var rule_y := _heading_bottom()
		draw_line(Vector2(x, rule_y), Vector2(size.x - PAD, rule_y), Palette.RULE, 1.0)

	for i in _rows.size():
		_draw_row(i)

	if not note.is_empty():
		var top := _heading_bottom() + HEADING_GAP + _rows.size() * ROW_HEIGHT + 6.0
		draw_string(_font, Vector2(x, top + _font.get_ascent(NOTE_SIZE)), note,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, NOTE_SIZE, Palette.CHALK_3)


func _draw_row(index: int) -> void:
	var row := _rows[index]
	var rect := _row_rect(index)
	var chosen := index == _selected
	if chosen:
		draw_rect(rect, Palette.NIGHT_3)
		# The rim: a line of the light down the row's left edge.
		draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), accent)
		# The marker: a small diamond in the light, before the writing.
		var c := Vector2(rect.position.x + 12.0, rect.get_center().y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -MARKER), c + Vector2(MARKER * 0.7, 0),
				c + Vector2(0, MARKER), c + Vector2(-MARKER * 0.7, 0)]), accent)
	var text_x := PAD + 10.0
	var base := rect.get_center().y + (_font.get_ascent(ROW_SIZE) - _font.get_descent(ROW_SIZE)) * 0.5
	var colour := Palette.CHALK if chosen else (Palette.CHALK_2 if row.enabled else Palette.CHALK_3)
	var price_width := 0.0
	if row.price >= 0:
		var price := str(row.price)
		price_width = _font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE).x
		var price_colour := Palette.GOLD
		if not row.enabled:
			price_colour.a = 0.45
		draw_string(_font, Vector2(rect.end.x - PAD + 6.0 - price_width, base), price,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE, price_colour)
		# A small coin before the price.
		draw_circle(Vector2(rect.end.x - PAD - price_width - 4.0, base - _font.get_ascent(ROW_SIZE) * 0.35),
				4.0, price_colour)
		price_width += 18.0
	var text_width := rect.end.x - PAD - price_width - text_x
	draw_string(_font, Vector2(text_x, base), row.text, HORIZONTAL_ALIGNMENT_LEFT, text_width,
			ROW_SIZE, colour)
	if not row.enabled:
		# The second cue for a row that cannot be taken: the writing is struck through.
		var width := minf(_font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE).x,
				text_width)
		var y := base - _font.get_ascent(ROW_SIZE) * 0.32
		draw_line(Vector2(text_x - 2.0, y), Vector2(text_x + width + 2.0, y), Palette.CHALK_3, 1.5)
