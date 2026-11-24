class_name ArenaControls
extends Control
## The two buttons at the foot of the page, side by side under the hand: PLAY and DISCARD
## (ArenaLayout.controls_play and controls_discard), each a framed box with its word at the
## left and its tally at the right. The tallies are ArenaNumbers's, drawn on a layer of their
## own that the controls lay over their buttons (`hold_tallies`); the controls tell it how
## each tally is drawn. PASS takes PLAY's place when the play can be passed. Each is on when
## the rules allow it, and says why not when the pointer rests on it. They work out no rule:
## `show_table` takes RulesView.table() with the chosen cards.
##
## PLAY on is the one filled shape in the foot: cream, its word and tally in dark pencil.
## DISCARD on is a cream edge round a dark fill, its word and tally in cream. Off, either is
## the same shape with its word and tally faint, in place. Under the pointer PLAY's fill and
## DISCARD's edge light up; pressed, a button is drawn 2 px lower. A play that would make him
## break out turns PLAY amber and writes "he breaks out" left of it (ArenaLayout.warning).
##
## While a move is played back both are off in place and take no clicks (`lower`); they come
## on again when input opens (`rise`).

signal play_pressed
signal discard_pressed
signal pass_pressed

## How far in from a button's left edge its word starts.
const WORD_INSET := 14.0
## How far a pressed button is drawn lower.
const PRESS_DROP := 2.0
## The buttons' edge and corners, in pixels; the edge of PLAY when it warns.
const EDGE := 2
const WARNING_EDGE := 3
const CORNER := 3
const WORD_SIZE := 20

const CREAM := Color(0.93, 0.88, 0.75)
const CREAM_LIT := Color(1.0, 0.97, 0.88)
const PENCIL := Color(0.015, 0.025, 0.035)
const DARK_FILL := Color(0.05, 0.035, 0.06, 0.55)
const WARNING := Color(1.0, 0.72, 0.35)
const WARNING_LIT := Color(1.0, 0.8, 0.5)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)
## How strongly an off button's edge, word and tally are drawn.
const OFF := 0.4

var _play := Button.new()
var _discard := Button.new()
var _warning := Label.new()
var _numbers: ArenaNumbers
## What the rules say: Pass is offered; why PLAY and DISCARD cannot be pressed ("" if they can).
var _passing := false
var _play_why := "Not now."
var _discard_why := "Not now."
## The chosen play would make him break out.
var _breaks := false
## False while a move is played back.
var _up := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	font.spacing_glyph = 2
	for button: Button in [_play, _discard]:
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", WORD_SIZE)
		button.add_theme_constant_override("outline_size", 0)
		button.add_theme_color_override("font_disabled_color", Color(CREAM, OFF))
		button.add_theme_stylebox_override("disabled", _box(DARK_FILL, Color(CREAM, OFF), EDGE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_child(button)
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		_play.add_theme_color_override(state, PENCIL)
	dress_dark(_discard)
	_play.text = "PLAY"
	_discard.text = "DISCARD"
	_warning.text = "he breaks out"
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 13)
	_warning.add_theme_color_override("font_color", WARNING)
	_warning.add_theme_color_override("font_outline_color", OUTLINE)
	_warning.add_theme_constant_override("outline_size", 5)
	add_child(_warning)
	_play.pressed.connect(func() -> void:
		if _passing:
			pass_pressed.emit()
		else:
			play_pressed.emit())
	_discard.pressed.connect(func() -> void: discard_pressed.emit())
	_apply()


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


## Lays the tallies of `numbers` over the buttons, and from now on tells it how each tally is
## drawn: in its button's word colour, faint when off, lower when pressed.
func hold_tallies(numbers: ArenaNumbers) -> void:
	_numbers = numbers
	numbers.tallies.reparent(self, false)
	_show_tallies()


## Sets both controls from RulesView.table() and the number of cards chosen in the hand.
func show_table(table: Dictionary, chosen: int) -> void:
	var playing: bool = table.phase == "play"
	var play: Variant = table.play
	_breaks = false
	_passing = playing and table.can_pass.ok
	_play.text = "PASS" if _passing else "PLAY"
	_play_why = ""
	if _passing:
		_play.tooltip_text = "Nothing can be played and no discard is left: the play is passed."
	else:
		if not playing:
			_play_why = "Not now."
		elif table.plays <= 0:
			_play_why = "No plays left."
		elif play == null:
			_play_why = "Choose cards for a hand."
		elif not play.ok:
			_play_why = play.reason
		_play.tooltip_text = _play_why
	_discard_why = ""
	if not playing:
		_discard_why = "Not now."
	elif table.discards <= 0:
		_discard_why = "No discards left."
	elif chosen < 1:
		_discard_why = "Choose cards to discard."
	_discard.tooltip_text = _discard_why
	_apply()


## The chosen play would make him break out: PLAY turns amber and the warning is written left
## of it. Or the warning is taken off. `show_table` takes it off too.
func warn_breakout(on: bool) -> void:
	_breaks = on
	_apply()


## True if Play (or Pass) can be pressed now.
func can_play() -> bool:
	return _up and _play_why == "" and not _passing


func can_pass() -> bool:
	return _up and _passing


func can_discard() -> bool:
	return _up and _discard_why == ""


## Input is open: the buttons come on, as the rules allow. (`animate` is kept for the
## callers: nothing moves.)
func rise(_animate: bool = true) -> void:
	_up = true
	_apply()


## A move is played back: both buttons are off in place and take no clicks.
func lower(_animate: bool = true) -> void:
	_up = false
	_apply()


## Puts every part in the look the state asks for.
func _apply() -> void:
	_play.disabled = not _up or _play_why != ""
	_discard.disabled = not _up or _discard_why != ""
	for button: Button in [_play, _discard]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if _up else Control.MOUSE_FILTER_IGNORE
	var warns := _breaks and not _passing and not _play.disabled
	_set_play_look(warns)
	_warning.visible = warns
	_show_tallies()


## PLAY's fill: cream, or amber with a heavier edge while it warns.
func _set_play_look(warns: bool) -> void:
	var fill := WARNING if warns else CREAM
	var lit := WARNING_LIT if warns else CREAM_LIT
	var edge := WARNING_EDGE if warns else EDGE
	_play.add_theme_stylebox_override("normal", _box(fill, PENCIL, edge))
	_play.add_theme_stylebox_override("hover", _box(lit, PENCIL, edge))
	_play.add_theme_stylebox_override("pressed", _box(lit, PENCIL, edge, true))
	_play.add_theme_stylebox_override("hover_pressed", _box(lit, PENCIL, edge, true))


## Gives a button DISCARD's look while it can be pressed: a cream edge and word on a dark
## fill, both lit under the pointer, drawn lower while pressed. For any button of the page
## that is not the one to press first.
static func dress_dark(button: Button) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)
	for state: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, CREAM_LIT)
	button.add_theme_stylebox_override("normal", _box(DARK_FILL, CREAM, EDGE))
	button.add_theme_stylebox_override("hover", _box(DARK_FILL, CREAM_LIT, EDGE))
	button.add_theme_stylebox_override("pressed", _box(DARK_FILL, CREAM_LIT, EDGE, true))
	button.add_theme_stylebox_override("hover_pressed", _box(DARK_FILL, CREAM_LIT, EDGE, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A button's box: `fill` inside an edge `width` wide, drawn PRESS_DROP lower when `pressed`,
## the word inset at the left and centred on the height.
static func _box(fill: Color, edge: Color, width: int, pressed: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = WORD_INSET
	box.content_margin_right = WORD_INSET
	box.content_margin_top = PRESS_DROP * 2.0 if pressed else 0.0
	box.content_margin_bottom = 0.0
	if pressed:
		box.expand_margin_top = -PRESS_DROP
		box.expand_margin_bottom = PRESS_DROP
	return box


func _process(_delta: float) -> void:
	_show_tallies()


## Tells the tallies how to be drawn: each in its button's word colour, lower while pressed.
func _show_tallies() -> void:
	if _numbers == null:
		return
	var play_colour := Color(CREAM, OFF) if _play.disabled else PENCIL
	var discard_colour := Color(CREAM, OFF) if _discard.disabled else CREAM
	_numbers.set_tally_look(0, play_colour, _drop(_play))
	_numbers.set_tally_look(1, discard_colour, _drop(_discard))


func _drop(button: Button) -> float:
	var mode := button.get_draw_mode()
	return PRESS_DROP if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED else 0.0


func _lay_out() -> void:
	var play := ArenaLayout.controls_play(size)
	var discard := ArenaLayout.controls_discard(size)
	_play.position = play.position
	_play.size = play.size
	_discard.position = discard.position
	_discard.size = discard.size
	var warning := ArenaLayout.warning(size)
	_warning.position = warning.position
	_warning.size = warning.size
