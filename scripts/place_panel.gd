class_name PlacePanel
extends Control
## The panel the place screens (title, alley, laboratory) show their menu or their wares on,
## drawn by code: a night surface ruled at the edge, sitting in a soft dark that fades into
## the picture behind it. A heading (with the purse beside it), an opening line, then rows to
## choose from under section headings, each with an optional price; the chosen one is lit by
## the light the caller gives (Jekyll's or Hyde's), and its second line of small writing
## stands under the rows.
##
##   panel.set_heading("The laboratory")
##   panel.set_purse(12, 2)
##   panel.lead = "The dawn brought two sovereigns."
##   panel.set_rows([
##       {section = "Cards"},
##       {text = "Night Walk", price = 4, detail = "Hyde: 2 Craving on the Lamp."},
##       {text = "Black tonic", price = 12, enabled = false, why = "Not enough sovereigns"},
##       {text = "Old Debt", sold = "sold"},
##       {text = "Leave"},
##   ])
##   panel.row_chosen.connect(_on_row_chosen)
##   panel.back.connect(_on_back)
##
## A row is a Dictionary; every key but `text` may be left out:
## - `text: String`: the row's writing.
## - `price: int`: shown in gold at the right, with a coin; 0 is written "free"; left out (or
##   below 0) there is no price.
## - `enabled: bool` (true): false for a row that cannot be taken now (too dear, nothing to
##   strike...): it is dimmed, its price still shown.
## - `sold: String` (""): a word ("sold", "taken"; `true` gives "sold") for a row that is
##   gone: it is dimmed and struck through, the word stands where the price was, and it
##   cannot be taken.
## - `why: String`: why the row cannot be taken, shown in the note line while the selection
##   (or the pointer, which moves the selection) is on it.
## - `detail: String`: a second line of small writing (what the ware does), shown under the
##   rows while the row is selected; a sentence long is fine, it wraps. (It has its own
##   place at the foot, kept for the longest one, so that no row moves as the selection
##   does.)
## - `section: String`: makes the row a section heading ("Cards") instead; it takes no other
##   key and the selection skips it. It still counts in the indices.
##
## Properties: `accent` (Palette.JEKYLL or Palette.HYDE), `note` (the small line at the foot),
## `lead` (the opening line under the heading), `active` (takes keys and clicks),
## `dense` (closer rows, for a page of wares), `max_height` (see below).
##
## Methods: `set_heading(text)`, `set_purse(sovereigns, salt = -1)`,
## `set_rows(rows, keep_selection = true)`, `selected()`, `select(index)`,
## `move_selection(step)`, `choose()`.
##
## Signals: `row_chosen(index)` (a row that can be taken was taken; the index is the row's
## place in the rows given to set_rows), `back()` (Escape).
##
## Up and Down (or the pointer) move the selection over every row but the section headings,
## also over the ones that cannot be taken, so that their `why` can be read; Enter, Space or
## a click take the row if it can be taken. Giving the rows again (after a purchase) keeps
## the selection on the same index, or on the nearest row to it. To show another list on the
## same panel and come back: `set_rows(other, false)`, and later
## `set_rows(wares, false)` then `select(index_of_the_row_that_opened_it)`.
##
## The caller places the panel's top left corner and may set a larger width. The panel sets
## its own height from what it holds and widens itself if the writing needs it. It grows
## down to `max_height`, or, when that is 0, to a little above the bottom of the window;
## past that the rows scroll under the heading: the keys keep the selection in view and the
## mouse wheel scrolls.

## A row that can be taken was taken: its index in the rows given to set_rows.
signal row_chosen(index: int)
## Escape was pressed: leave the panel, or the list opened from a row.
signal back

const PAD := 22.0 # from the edge to the writing
const HEADING_SIZE := 30
const ROW_SIZE := 20
const DENSE_ROW_SIZE := 18
const NOTE_SIZE := 13
const LEAD_SIZE := 15
const DETAIL_SIZE := 14
const SECTION_SIZE := 13
const SOLD_SIZE := 15
const ROW_HEIGHT := 38.0
const DENSE_ROW_HEIGHT := 32.0
const SECTION_HEIGHT := 30.0
const DENSE_SECTION_HEIGHT := 26.0
const HEADING_GAP := 14.0 # between the heading's rule and the first row
const LEAD_GAP := 10.0 # under the opening line
const DETAIL_GAP := 8.0 # over and under the rule between the rows and the second line
const MARKER := 7.0 # half the width of the chosen row's marker
const SCRIM := 72 # how far the dark around the panel reaches into the picture
const SURFACE_ALPHA := 0.9
const SCRIM_ALPHA := 0.85
const WRAP_WIDTH := 360.0 # the least room a panel with wrapped writing gives it
const WINDOW_EDGE := 12.0 # kept clear under the panel when it grows to the window
const FADE := 16.0 # how far the rows fade at an edge they scroll past

## The light of the chosen row's marker and rim: Palette.JEKYLL or Palette.HYDE.
@export var accent := Palette.JEKYLL:
	set(value):
		accent = value
		_redraw()

## A line of small writing under the rows (how to use the panel), or "" for none. While the
## selection is on a row that cannot be taken, that row's `why` stands here instead.
@export var note := "":
	set(value):
		note = value
		_fit()

## The opening line, in small writing under the heading (it wraps), or "" for none.
@export var lead := "":
	set(value):
		lead = value
		_fit()

## While false the panel shows but does not take keys or clicks.
@export var active := true

## The most the panel's height may be before its rows scroll; 0 lets it grow to a little
## above the bottom of the window.
@export var max_height := 0.0:
	set(value):
		max_height = value
		_fit()

## Closer rows in slightly smaller writing, for a page with many wares: more of them show
## before the list has to scroll.
@export var dense := false:
	set(value):
		dense = value
		_row_size = DENSE_ROW_SIZE if dense else ROW_SIZE
		_row_height = DENSE_ROW_HEIGHT if dense else ROW_HEIGHT
		_section_height = DENSE_SECTION_HEIGHT if dense else SECTION_HEIGHT
		_fit()

var _row_size := ROW_SIZE
var _row_height := ROW_HEIGHT
var _section_height := SECTION_HEIGHT
var _heading := ""
var _sovereigns := -1
var _salt := -1
var _rows: Array[Dictionary] = []
var _selected := -1
var _font: Font = ThemeDB.fallback_font
var _surface := StyleBoxFlat.new()
## The rows are drawn on this child, which cuts them off where they scroll out of view.
var _list := Control.new()
## Each row's top in the list (before scrolling) and its height.
var _tops := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _content_height := 0.0
var _view_height := 0.0
var _scroll := 0.0
var _foot_height := 0.0
## The room kept under the rows for the selected row's second line: the longest one's.
var _detail_height := 0.0
var _fitting := false


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
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	_list.draw.connect(_draw_list)
	add_child(_list, false, Node.INTERNAL_MODE_FRONT)
	item_rect_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit()


## The writing at the top of the panel.
func set_heading(text: String) -> void:
	_heading = text
	_fit()


## What is held, shown to the right of the heading: sovereigns (with a coin) and doses of
## salt. A number below 0 is not shown.
func set_purse(sovereigns: int, salt: int = -1) -> void:
	_sovereigns = sovereigns
	_salt = salt
	_fit()


## Gives the panel its rows (see the top of this file for a row's keys). The first time, or
## with `keep_selection` false, the selection goes to the first row that can be taken and
## the list to its top; otherwise the selection stays on the same index, or the nearest row
## to it that is not a section heading.
func set_rows(rows: Array, keep_selection: bool = true) -> void:
	var was := _selected
	_rows.clear()
	for given: Dictionary in rows:
		var sold: Variant = given.get("sold", "")
		var row := {
			text = String(given.get("text", "")),
			price = int(given.get("price", -1)),
			enabled = bool(given.get("enabled", true)),
			sold = ("sold" if sold else "") if sold is bool else String(sold),
			why = String(given.get("why", "")),
			detail = String(given.get("detail", "")),
			section = given.has("section"),
		}
		if row.section:
			row.text = String(given.section)
		_rows.append(row)
	if keep_selection and was >= 0:
		_selected = _nearest(was)
	else:
		_selected = _first()
		_scroll = 0.0
	_fit()
	_reveal(_selected)


## The selected row's index, -1 if there is no row to select.
func selected() -> int:
	return _selected


## Selects a row by its index and brings it into view. A section heading, or an index that
## is not a row's, is ignored.
func select(index: int) -> void:
	_select(index, true)


## Moves the selection by `step` rows (negative is up), skipping section headings and going
## round at the ends.
func move_selection(step: int) -> void:
	for i in absi(step):
		select(_step_from(_selected, signi(step)))


## Takes the selected row, as Enter does. Nothing happens if it cannot be taken.
func choose() -> void:
	if _can_take(_selected):
		row_chosen.emit(_selected)


func _can_take(index: int) -> bool:
	if index < 0 or index >= _rows.size():
		return false
	var row := _rows[index]
	return not row.section and row.enabled and row.sold.is_empty()


func _can_select(index: int) -> bool:
	return index >= 0 and index < _rows.size() and not _rows[index].section


func _select(index: int, reveal: bool) -> void:
	if not _can_select(index):
		return
	_selected = index
	if reveal:
		_reveal(index)
	_redraw()


## The first row that can be taken; if none can, the first that is not a section heading.
func _first() -> int:
	for i in _rows.size():
		if _can_take(i):
			return i
	return _step_from(-1, 1)


## The row at `index` if it can be selected, or the nearest one to it, looking down first.
func _nearest(index: int) -> int:
	var count := _rows.size()
	if count == 0:
		return -1
	var at := clampi(index, 0, count - 1)
	for distance in count:
		if _can_select(at + distance):
			return at + distance
		if _can_select(at - distance):
			return at - distance
	return -1


func _step_from(from: int, direction: int) -> int:
	var count := _rows.size()
	if count == 0:
		return -1
	var at := from
	for i in count:
		at = posmod(at + direction, count)
		if _can_select(at):
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
			# Handled first: what the row does may change the screen, and take this panel
			# out of the tree.
			get_viewport().set_input_as_handled()
			choose()
			return
		KEY_ESCAPE:
			# Left to the screen when nothing listens for it here.
			if key.echo or back.get_connections().is_empty():
				return
			get_viewport().set_input_as_handled()
			back.emit()
			return
		_:
			return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		var hovered := _row_at(motion.position)
		if hovered != _selected:
			# Not brought into view: the list must not run away under the pointer.
			_select(hovered, false)
		return
	var button := event as InputEventMouseButton
	if not button or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			var clicked := _row_at(button.position)
			if _can_select(clicked):
				_select(clicked, false)
				choose()
				accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-_row_height)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(_row_height)
			accept_event()


## The row under a point of the panel, -1 if none or if it is scrolled out of view.
func _row_at(point: Vector2) -> int:
	var top := _list_top()
	if point.y < top or point.y > top + _view_height:
		return -1
	if point.x < 0.0 or point.x > size.x:
		return -1
	# By the rows' full heights: there is no dead line between two rows.
	var y := point.y - top + _scroll
	for i in _rows.size():
		if y >= _tops[i] and y < _tops[i] + _heights[i]:
			return i
	return -1


func _heading_bottom() -> float:
	if _heading.is_empty() and _purse_width() <= 0.0:
		return PAD * 0.5
	return PAD + _font.get_height(HEADING_SIZE) + 8.0


## Where the rows begin, under the heading and the opening line.
func _list_top() -> float:
	var top := _heading_bottom() + HEADING_GAP
	if not lead.is_empty():
		top += _wrapped_height(lead, LEAD_SIZE) + LEAD_GAP
	return top


## A row's place in the panel, as it is scrolled.
func _row_rect(index: int) -> Rect2:
	var top := _list_top() + _tops[index] - _scroll
	return Rect2(6.0, top, size.x - 12.0, _heights[index] - 4.0)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The height of small writing wrapped to the panel's width.
func _wrapped_height(text: String, font_size: int) -> float:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 2.0 * PAD, font_size).y


## What stands at the right of a row: its price, "free", or the word of a row that is gone.
func _price_text(row: Dictionary) -> String:
	if not row.sold.is_empty():
		return row.sold
	if row.price == 0:
		return "free"
	return str(row.price) if row.price > 0 else ""


func _purse_width() -> float:
	var width := 0.0
	if _sovereigns >= 0:
		width += 16.0 + _text_width(str(_sovereigns), _row_size)
	if _salt >= 0:
		if width > 0.0:
			width += 18.0
		width += 16.0 + _text_width(str(_salt), _row_size) + 5.0 + _text_width("salt", NOTE_SIZE)
	return width


## Each row's top and height in the list.
func _layout() -> void:
	_tops.resize(_rows.size())
	_heights.resize(_rows.size())
	var at := 0.0
	for i in _rows.size():
		var row := _rows[i]
		var height := _section_height if row.section else _row_height
		_tops[i] = at
		_heights[i] = height
		at += height
	_content_height = at
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_height - _view_height))


## Scrolls the list so that a row shows whole, with the section heading over it if it is
## the first under one.
func _reveal(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var top := _tops[index]
	var bottom := _tops[index] + _heights[index]
	var first := index
	while first > 0 and _rows[first - 1].section:
		first -= 1
	if bottom - _tops[first] <= _view_height:
		top = _tops[first]
	# Clear of the fade at an edge the list goes on past.
	if top - FADE < _scroll:
		_scroll = top - FADE
	elif bottom + FADE > _scroll + _view_height:
		_scroll = bottom + FADE - _view_height
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_height - _view_height))
	_redraw()


func _scroll_by(amount: float) -> void:
	_scroll = clampf(_scroll + amount, 0.0, maxf(0.0, _content_height - _view_height))
	_redraw()


## The most the panel's height may be.
func _height_limit() -> float:
	if max_height > 0.0:
		return max_height
	if not is_inside_tree():
		return INF
	return get_viewport_rect().size.y - global_position.y - WINDOW_EDGE


## Sets the height to what the panel holds (up to the limit, past which the rows scroll),
## and the width to at least what it needs.
func _fit() -> void:
	if _fitting:
		return
	_fitting = true
	# Wide enough for every line of writing that does not wrap.
	var width := _text_width(_heading, HEADING_SIZE)
	if _purse_width() > 0.0:
		width += _purse_width() + (24.0 if not _heading.is_empty() else 0.0)
	width = maxf(width, _text_width(note, NOTE_SIZE))
	var wraps := not lead.is_empty()
	for row in _rows:
		if row.section:
			width = maxf(width, _text_width(row.text.to_upper(), SECTION_SIZE) + 30.0)
			continue
		var price_width := 0.0
		if not _price_text(row).is_empty():
			var price_size := SOLD_SIZE if not row.sold.is_empty() else _row_size
			price_width = _text_width(_price_text(row), price_size) + 30.0
		width = maxf(width, _text_width(row.text, _row_size) + 10.0 + price_width)
		wraps = wraps or not row.detail.is_empty() or not row.why.is_empty()
	if wraps:
		width = maxf(width, WRAP_WIDTH)
	var least_width := ceilf(width + 2.0 * PAD)
	if size.x < least_width:
		size.x = least_width

	# The writing that wraps, at that width. Room is kept for the longest second line, so
	# that the panel keeps its height as the selection moves.
	var rows_height := 0.0
	_detail_height = 0.0
	var foot_lines := 0.0 if note.is_empty() else _font.get_height(NOTE_SIZE)
	for row in _rows:
		rows_height += _section_height if row.section else _row_height
		if not row.detail.is_empty():
			_detail_height = maxf(_detail_height, _wrapped_height(row.detail, DETAIL_SIZE))
		if not row.why.is_empty():
			foot_lines = maxf(foot_lines, _wrapped_height(row.why, NOTE_SIZE))
	_foot_height = 6.0 + foot_lines if foot_lines > 0.0 else 0.0
	var around := _list_top() + _foot_height + PAD * 0.75
	if _detail_height > 0.0:
		around += 2.0 * DETAIL_GAP + _detail_height
	var list_height := rows_height
	var limit := maxf(_height_limit(), around + 3.0 * _row_height)
	var height := minf(around + list_height, limit)
	_view_height = height - around
	_layout()

	custom_minimum_size = Vector2(least_width, height)
	size = Vector2(maxf(size.x, least_width), height)
	# The child's place is kept on whole pixels; the rest is added where the rows are drawn.
	_list.position = Vector2(0.0, floorf(_list_top()))
	_list.size = Vector2(size.x, _view_height + _list_top() - _list.position.y)
	_fitting = false
	_redraw()


func _redraw() -> void:
	queue_redraw()
	_list.queue_redraw()


func _draw() -> void:
	draw_style_box(_surface, Rect2(Vector2.ZERO, size))

	var x := PAD
	if _heading_bottom() > PAD:
		var base := PAD + _font.get_ascent(HEADING_SIZE)
		var purse := _purse_width()
		draw_string(_font, Vector2(x, base), _heading, HORIZONTAL_ALIGNMENT_LEFT,
				size.x - 2.0 * PAD - purse, HEADING_SIZE, Palette.CHALK)
		if purse > 0.0:
			_draw_purse(Vector2(size.x - PAD - purse, base))
		var rule_y := _heading_bottom()
		draw_line(Vector2(x, rule_y), Vector2(size.x - PAD, rule_y), Palette.RULE, 1.0)

	if not lead.is_empty():
		var top := _heading_bottom() + HEADING_GAP
		draw_multiline_string(_font, Vector2(x, top + _font.get_ascent(LEAD_SIZE)), lead,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, LEAD_SIZE, -1, Palette.CHALK_2)

	# Under the rows, past a rule: the selected row's second line.
	if _detail_height > 0.0:
		var rule_y := _list_top() + _view_height + DETAIL_GAP
		draw_line(Vector2(x, rule_y), Vector2(size.x - PAD, rule_y), Palette.RULE, 1.0)
		if _can_select(_selected) and not _rows[_selected].detail.is_empty():
			draw_multiline_string(_font,
					Vector2(x, rule_y + DETAIL_GAP + _font.get_ascent(DETAIL_SIZE)),
					_rows[_selected].detail, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD,
					DETAIL_SIZE, -1, Palette.CHALK_2)

	# The foot: why the selected row cannot be taken, or else the note.
	var foot_top := size.y - PAD * 0.75 - _foot_height + 6.0
	var why := ""
	if _can_select(_selected) and not _can_take(_selected):
		why = _rows[_selected].why
	if not why.is_empty():
		draw_multiline_string(_font, Vector2(x, foot_top + _font.get_ascent(NOTE_SIZE)), why,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, NOTE_SIZE, -1, Palette.WARN)
	elif not note.is_empty():
		draw_string(_font, Vector2(x, foot_top + _font.get_ascent(NOTE_SIZE)), note,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, NOTE_SIZE, Palette.CHALK_3)


## What is held, from `at` (the left end, on the heading's baseline) to the right.
func _draw_purse(at: Vector2) -> void:
	var x := at.x
	var mid := at.y - _font.get_ascent(_row_size) * 0.35
	if _sovereigns >= 0:
		draw_circle(Vector2(x + 5.0, mid), 5.0, Palette.GOLD)
		x += 16.0
		draw_string(_font, Vector2(x, at.y), str(_sovereigns), HORIZONTAL_ALIGNMENT_LEFT, -1,
				_row_size, Palette.GOLD)
		x += _text_width(str(_sovereigns), _row_size) + 18.0
	if _salt >= 0:
		# A crystal of salt.
		var c := Vector2(x + 5.0, mid)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, -2.5),
				c + Vector2(4.5, 2.5), c + Vector2(0, 6), c + Vector2(-4.5, 2.5),
				c + Vector2(-4.5, -2.5)]), Palette.SALT)
		x += 16.0
		draw_string(_font, Vector2(x, at.y), str(_salt), HORIZONTAL_ALIGNMENT_LEFT, -1,
				_row_size, Palette.SALT)
		x += _text_width(str(_salt), _row_size) + 5.0
		draw_string(_font, Vector2(x, at.y), "salt", HORIZONTAL_ALIGNMENT_LEFT, -1,
				NOTE_SIZE, Palette.CHALK_2)


## The rows, drawn on the child that cuts them off at the list's edges.
func _draw_list() -> void:
	# From the panel's coordinates to the child's.
	var shift := Vector2(0.0, -_list.position.y)
	for i in _rows.size():
		var rect := _row_rect(i)
		rect.position += shift
		if rect.end.y < 0.0 or rect.position.y > _list.size.y:
			continue
		if _rows[i].section:
			_draw_section(i, rect)
		else:
			_draw_row(i, rect)

	var hidden := _content_height - _view_height
	if hidden <= 0.5:
		return
	# More rows than show: they fade at an edge they go on past, and a thumb at the right
	# shows how far down the list is.
	var top := _list_top() + shift.y
	var surface := Palette.NIGHT_2
	var clear := Color(surface, 0.0)
	if _scroll > 0.5:
		_list.draw_polygon(_quad(Rect2(1.0, top, size.x - 2.0, FADE)),
				PackedColorArray([surface, surface, clear, clear]))
	if _scroll < hidden - 0.5:
		_list.draw_polygon(_quad(Rect2(1.0, top + _view_height - FADE, size.x - 2.0, FADE)),
				PackedColorArray([clear, clear, surface, surface]))
	var thumb := maxf(24.0, _view_height * _view_height / _content_height)
	var thumb_top := top + (_view_height - thumb) * _scroll / hidden
	_list.draw_rect(Rect2(size.x - 5.0, top, 2.0, _view_height), Palette.NIGHT_3)
	_list.draw_rect(Rect2(size.x - 5.0, thumb_top, 2.0, thumb), Palette.CHALK_3)


func _quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])


func _draw_section(index: int, rect: Rect2) -> void:
	var text: String = _rows[index].text.to_upper()
	var base := rect.end.y - 5.0
	_list.draw_string(_font, Vector2(PAD, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			SECTION_SIZE, Palette.CHALK_3)
	# A rule from the writing to the panel's edge.
	var y := base - _font.get_ascent(SECTION_SIZE) * 0.35
	var from := PAD + _text_width(text, SECTION_SIZE) + 10.0
	if from < size.x - PAD:
		_list.draw_line(Vector2(from, y), Vector2(size.x - PAD, y), Palette.RULE, 1.0)


func _draw_row(index: int, rect: Rect2) -> void:
	var row := _rows[index]
	var chosen := index == _selected
	var can_take := _can_take(index)
	var line := rect
	if chosen:
		# A row that cannot be taken is chosen without the light.
		var light := accent if can_take else Palette.CHALK_3
		_list.draw_rect(rect, Palette.NIGHT_3)
		# The rim: a line of the light down the row's left edge.
		_list.draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), light)
		# The marker: a small diamond in the light, before the writing.
		var c := Vector2(line.position.x + 12.0, line.get_center().y)
		_list.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -MARKER),
				c + Vector2(MARKER * 0.7, 0), c + Vector2(0, MARKER),
				c + Vector2(-MARKER * 0.7, 0)]), light)
	var text_x := PAD + 10.0
	var base := line.get_center().y + (_font.get_ascent(_row_size) - _font.get_descent(_row_size)) * 0.5
	var colour := Palette.CHALK_3
	if can_take:
		colour = Palette.CHALK if chosen else Palette.CHALK_2
	var price := _price_text(row)
	var price_width := 0.0
	var price_right := line.end.x - PAD + 6.0
	if not row.sold.is_empty():
		# Gone: the word stands where the price was.
		price_width = _text_width(price, SOLD_SIZE)
		_list.draw_string(_font, Vector2(price_right - price_width, base), price,
				HORIZONTAL_ALIGNMENT_LEFT, -1, SOLD_SIZE, Palette.CHALK_3)
		price_width += 8.0
	elif not price.is_empty():
		price_width = _font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, _row_size).x
		var price_colour := Palette.GOLD
		if not row.enabled:
			price_colour.a = 0.5
		_list.draw_string(_font, Vector2(price_right - price_width, base), price,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _row_size, price_colour)
		if row.price > 0:
			# A small coin before the price.
			_list.draw_circle(Vector2(line.end.x - PAD - price_width - 4.0,
					base - _font.get_ascent(_row_size) * 0.35), 4.0, price_colour)
			price_width += 18.0
		else:
			price_width += 8.0
	var text_width := line.end.x - PAD - price_width - text_x
	_list.draw_string(_font, Vector2(text_x, base), row.text, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, _row_size, colour)
	if not row.sold.is_empty():
		# The second cue for a row that is gone: the writing is struck through.
		var width := minf(_font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _row_size).x,
				text_width)
		var y := base - _font.get_ascent(_row_size) * 0.32
		_list.draw_line(Vector2(text_x - 2.0, y), Vector2(text_x + width + 2.0, y),
				Palette.CHALK_3, 1.5)
