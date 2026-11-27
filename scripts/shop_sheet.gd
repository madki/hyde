class_name ShopSheet
extends Control
## The sheet a place lays its wares on: the notice's paper (ArenaNotice.draw_sheet) in the
## room's tone, with a header (the place's name, the purse and the salt), section headings
## with a rule, and a Leave button fixed across the foot that names the night to come.
##
## The page gives the sheet its place and size, and lays its own wares on it as children:
## they lie over the paper and the writing. The sheet draws nothing of the wares.
##
##   sheet.tone = "jekyll"
##   sheet.set_place("The laboratory")
##   sheet.set_purse(13, 2)
##   sheet.set_leave("Night 2: Search for Mr Hyde")
##   var room := sheet.room()                    # between the header and Leave
##   sheet.set_headings([
##       {text = "Cards", at = room.position, width = room.size.x},
##       {text = "Service", at = Vector2(380.0, 300.0), width = 132.0},
##   ])
##   sheet.set_dividers([[Vector2(366.0, 300.0), Vector2(366.0, 420.0)]])
##   sheet.wares = Rect2(...)                    # what the blot or the lamp light lies behind
##   sheet.leave.connect(_on_leave)
##
## Every place and rect given or returned is in the sheet's own coordinates.
##
## - `tone`: "jekyll" (lamp light on clean paper) or "hyde" (his ink, a blot behind the wares).
## - `set_place(name)`: the name at the header's left, in the heading face.
## - `set_purse(sovereigns, salt)`: at the header's right, a coin and the sovereigns, a crystal
##   and the doses of salt. A number below 0 is not shown.
## - `set_leave(next)`: the night to come, written after "Leave" on the button ("" for none).
##   It is written smaller if it must be to fit.
## - `set_headings(headings)`: each {text, at, width}: the heading's top left corner and how far
##   its rule runs. A heading is HEADING_HEIGHT high; what it heads begins under that.
## - `set_dividers(lines)`: thin rules, each [from, to], to split two groups of a row.
## - `wares`: the box the tone's blot or lamp light lies behind. With no area it lies at the
##   middle of the sheet.
## - `room()`: the part of the sheet between the header's rule and the Leave button, inside
##   the sheet's padding.
## - `leave_button`: the button, to give it the focus or its neighbours for the keys. It takes
##   the focus, Enter, Space and a click, and sends `leave`.

## The Leave button was pressed.
signal leave

## From the sheet's edge to its writing.
const PAD := 18.0
const NAME_SIZE := 26
const PURSE_SIZE := 18
const SMALL_SIZE := 13
const HEADING_SIZE := 13
const LEAVE_SIZE := 17
## The least size the Leave button's writing is brought down to, to fit a long night's name.
const LEAVE_LEAST_SIZE := 12
## How high a heading is: what it heads begins this far under the heading's top.
const HEADING_HEIGHT := 22.0
const LEAVE_HEIGHT := 40.0
## Under the header's rule, and over the Leave button.
const GAP := 10.0

## Whose sheet it is: "jekyll" or "hyde" (a key of ArenaNotice.TONES).
@export var tone := "jekyll":
	set(value):
		if not ArenaNotice.TONES.has(value):
			push_warning("A shop sheet has no tone '%s': it is shown as Jekyll's." % value)
			value = "jekyll"
		tone = value
		_redraw()

## The box the tone's blot or lamp light lies behind, on the sheet.
var wares := Rect2():
	set(value):
		wares = value
		_redraw()

## The Leave button, for the focus and its neighbours.
var leave_button := Button.new()

var _place := ""
var _sovereigns := -1
var _salt := -1
var _next := ""
var _headings: Array = []
var _dividers: Array = []
## The paper, which keeps the blot inside its edge, and the writing over it.
var _paper := Control.new()
var _writing := Control.new()
var _heavy := FontVariation.new()
var _light := FontVariation.new()


func _init() -> void:
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1
	_light.base_font = ThemeDB.fallback_font
	_light.variation_embolden = 0.4
	for layer: Control in [_paper, _writing]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
	_paper.clip_contents = true
	_paper.draw.connect(_draw_paper)
	_writing.draw.connect(_draw_writing)
	leave_button.focus_mode = Control.FOCUS_ALL
	leave_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		leave_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	leave_button.draw.connect(_draw_leave)
	leave_button.pressed.connect(func() -> void: leave.emit())
	for sent: Signal in [leave_button.focus_entered, leave_button.focus_exited,
			leave_button.mouse_entered, leave_button.mouse_exited]:
		sent.connect(leave_button.queue_redraw)
	add_child(leave_button)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


## The place's name, written at the header's left.
func set_place(place_name: String) -> void:
	_place = place_name
	_redraw()


## What is held, written at the header's right: sovereigns and doses of salt. A number below
## 0 is not shown.
func set_purse(sovereigns: int, salt: int = -1) -> void:
	_sovereigns = sovereigns
	_salt = salt
	_redraw()


## The night to come, written after "Leave" on the button, or "" for none.
func set_leave(next: String) -> void:
	_next = next
	leave_button.queue_redraw()


## The section headings: each {text, at, width}, on the sheet.
func set_headings(headings: Array) -> void:
	_headings = headings
	_redraw()


## Thin rules between two groups: each [from, to], on the sheet.
func set_dividers(lines: Array) -> void:
	_dividers = lines
	_redraw()


## The part of the sheet the page lays out: under the header's rule and over the Leave button.
func room() -> Rect2:
	var top := _header_bottom() + GAP
	return Rect2(PAD, top, size.x - 2.0 * PAD, _leave_rect().position.y - GAP - top)


func _header_bottom() -> float:
	return PAD + _heavy.get_height(NAME_SIZE) + 6.0


func _leave_rect() -> Rect2:
	return Rect2(PAD, size.y - PAD - LEAVE_HEIGHT, size.x - 2.0 * PAD, LEAVE_HEIGHT)


func _lay_out() -> void:
	var rect := _leave_rect()
	leave_button.position = rect.position
	leave_button.size = rect.size
	_redraw()


func _redraw() -> void:
	queue_redraw()
	_paper.queue_redraw()
	_writing.queue_redraw()
	leave_button.queue_redraw()


func _colours() -> Dictionary:
	return ArenaNotice.TONES[tone]


# The sheet's shadow on the picture behind it.
func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.OUTLINE, 0.0)
	box.shadow_color = Color(Palette.OUTLINE, 0.55)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0.0, 5.0)
	box.set_corner_radius_all(4)
	draw_style_box(box, Rect2(Vector2.ZERO, size))


func _draw_paper() -> void:
	ArenaNotice.draw_sheet(_paper, Rect2(Vector2.ZERO, size), tone, wares, hash(_place))


# The header, its rule, the headings and the dividers.
func _draw_writing() -> void:
	var colours := _colours()
	var base := PAD + _heavy.get_ascent(NAME_SIZE)
	var purse := _purse_width()
	_writing.draw_string(_heavy, Vector2(PAD, base), _place, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 2.0 * PAD - purse - 16.0, NAME_SIZE, colours.title)
	_draw_purse(Vector2(size.x - PAD - purse, base))
	var rule_y := _header_bottom()
	_writing.draw_line(Vector2(PAD, rule_y), Vector2(size.x - PAD, rule_y), Color(colours.title, 0.35), 1.0)
	var faint: Color = colours.faint
	for heading: Dictionary in _headings:
		var text: String = heading.text.to_upper()
		var at: Vector2 = heading.at
		var text_base := at.y + _heavy.get_ascent(HEADING_SIZE)
		_writing.draw_string(_heavy, Vector2(at.x, text_base), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				HEADING_SIZE, faint)
		# A rule from the writing to the end of what it heads.
		var y := text_base - _heavy.get_ascent(HEADING_SIZE) * 0.35
		var from := at.x + _width(_heavy, text, HEADING_SIZE) + 10.0
		var to: float = at.x + heading.width
		if from < to:
			_writing.draw_line(Vector2(from, y), Vector2(to, y), Color(faint, 0.4), 1.0)
	for line: Array in _dividers:
		_writing.draw_line(line[0], line[1], Color(faint, 0.4), 1.0)


func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# How wide the purse and the salt are written, for their place at the header's right.
func _purse_width() -> float:
	var width := 0.0
	if _sovereigns >= 0:
		width += 18.0 + _width(_heavy, str(_sovereigns), PURSE_SIZE)
	if _salt >= 0:
		if width > 0.0:
			width += 20.0
		width += 16.0 + _width(_heavy, str(_salt), PURSE_SIZE) + 5.0 + _width(_light, "salt", SMALL_SIZE)
	return width


# What is held, from `at` (the left end, on the name's baseline) to the right.
func _draw_purse(at: Vector2) -> void:
	var x := at.x
	var mid := at.y - _heavy.get_ascent(PURSE_SIZE) * 0.36
	if _sovereigns >= 0:
		_writing.draw_circle(Vector2(x + 6.0, mid), 6.0, Palette.GOLD, true, -1.0, true)
		x += 18.0
		_writing.draw_string(_heavy, Vector2(x, at.y), str(_sovereigns), HORIZONTAL_ALIGNMENT_LEFT, -1,
				PURSE_SIZE, Palette.GOLD)
		x += _width(_heavy, str(_sovereigns), PURSE_SIZE) + 20.0
	if _salt >= 0:
		# A crystal of salt.
		var c := Vector2(x + 5.0, mid)
		_writing.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, -2.5),
				c + Vector2(4.5, 2.5), c + Vector2(0, 6), c + Vector2(-4.5, 2.5),
				c + Vector2(-4.5, -2.5)]), Palette.SALT)
		x += 16.0
		_writing.draw_string(_heavy, Vector2(x, at.y), str(_salt), HORIZONTAL_ALIGNMENT_LEFT, -1,
				PURSE_SIZE, Palette.SALT)
		x += _width(_heavy, str(_salt), PURSE_SIZE) + 5.0
		_writing.draw_string(_light, Vector2(x, at.y), "salt", HORIZONTAL_ALIGNMENT_LEFT, -1,
				SMALL_SIZE, _colours().faint)


# The Leave button: an outlined box at rest; under the pointer or with the focus it is filled
# with its owner's light, ringed, and marked with a diamond before its word.
func _draw_leave() -> void:
	var colours := _colours()
	var lit := leave_button.has_focus() or leave_button.is_hovered()
	var rect := Rect2(Vector2.ZERO, leave_button.size)
	var box := StyleBoxFlat.new()
	box.bg_color = colours.button if lit else Color(Palette.OUTLINE, 0.45)
	box.border_color = colours.button_edge if lit else colours.edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	leave_button.draw_style_box(box, rect)
	var word: Color = colours.button_word if lit else colours.words
	var rest: Color = colours.button_word if lit else colours.faint
	var after := "" if _next.is_empty() else "  ·  " + _next
	var marker := 20.0
	var room_for_words := rect.size.x - 2.0 * 12.0 - marker
	var font_size := LEAVE_SIZE
	while font_size > LEAVE_LEAST_SIZE and _width(_heavy, "Leave", font_size) + _width(_light, after, font_size) > room_for_words:
		font_size -= 1
	var leave_width := _width(_heavy, "Leave", font_size)
	var width := minf(leave_width + _width(_light, after, font_size), room_for_words)
	var x := (rect.size.x - width - marker) * 0.5 + marker
	var base := rect.get_center().y + (_heavy.get_ascent(font_size) - _heavy.get_descent(font_size)) * 0.5
	if lit:
		var c := Vector2(x - marker + 6.0, rect.get_center().y)
		leave_button.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0),
				c + Vector2(0, 6), c + Vector2(-6, 0)]), word)
	leave_button.draw_string(_heavy, Vector2(x, base), "Leave", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word)
	if not after.is_empty():
		leave_button.draw_string(_light, Vector2(x + leave_width, base), after, HORIZONTAL_ALIGNMENT_LEFT,
				width - leave_width, font_size, rest)
