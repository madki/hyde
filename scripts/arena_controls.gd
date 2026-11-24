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
## The one control to press first is filled with the light of whoever has the table (Jekyll's
## or Hyde's), its word and tally in outline dark, and it breathes a glow round its edge: PLAY
## (or PASS) when it can be pressed, else DISCARD. The other, when it can be pressed too, rests
## on a raised night fill with a ruled edge and chalk words. Off, either is a dark well with a
## dashed edge and faint words, in place. Under the pointer the edge turns chalk; pressed, a
## button is drawn 2 px lower. A play that would make him break out fills PLAY with the warning
## colour and writes "he breaks out" left of it (ArenaLayout.warning).
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
## The buttons' edge, in pixels; the edge of PLAY when it warns. Corners are square.
const EDGE := 2
const WARNING_EDGE := 3
const WORD_SIZE := 20
## An off button's dashed edge: dash length and width, in pixels.
const DASH := 6.0
const DASH_WIDTH := 2.0
## The ready control's glow: how far it reaches out, in pixels, and the strength it breathes
## between over PULSE seconds. With ArenaPace.reduce_flashes it holds at STEADY.
const GLOW_REACH := 10
const GLOW_LOW := 0.45
const GLOW_HIGH := 0.7
const PULSE := 1.6
const STEADY := 0.6

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
## The light of whoever has the table.
var _accent := Palette.JEKYLL
## The control drawn ready (filled and glowing), or null.
var _ready_button: Button = null


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
		button.add_theme_color_override("font_disabled_color", Palette.CHALK_3)
		button.add_theme_stylebox_override("disabled", _box(Palette.NIGHT_2, Color.TRANSPARENT, EDGE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.draw.connect(_draw_dashes.bind(button))
		button.gui_input.connect(_refuse_if_off.bind(button))
		add_child(button)
	_play.text = "PLAY"
	_discard.text = "DISCARD"
	_warning.text = "he breaks out"
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 13)
	_warning.add_theme_color_override("font_color", Palette.WARN)
	_warning.add_theme_color_override("font_outline_color", Palette.OUTLINE)
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
	_accent = Palette.HYDE if table.get("stance", "jekyll") == "hyde" else Palette.JEKYLL
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
	_ready_button = null
	if not _play.disabled:
		_ready_button = _play
	elif not _discard.disabled:
		_ready_button = _discard
	for button: Button in [_play, _discard]:
		if button == _ready_button:
			var fill := Palette.WARN if warns and button == _play else _accent
			var edge := WARNING_EDGE if warns and button == _play else EDGE
			_dress(button, fill, fill, Palette.OUTLINE, Palette.OUTLINE, edge)
		else:
			dress_dark(button)
		button.queue_redraw()
	_warning.visible = warns
	_show_tallies()
	queue_redraw()


## Gives a button the look of a control at rest: a raised night fill with a ruled edge and
## chalk word, its edge chalk under the pointer, drawn lower while pressed. For any button of
## the page that can be pressed but is not the one to press first.
static func dress_dark(button: Button) -> void:
	_dress(button, Palette.NIGHT_3, Palette.RULE, Palette.CHALK, Palette.CHALK, EDGE)


## Sets a button's boxes and word colours: `fill` inside an edge `rule` wide `width`, the edge
## `lit` under the pointer and pressed, the word `word`.
static func _dress(button: Button, fill: Color, rule: Color, lit: Color, word: Color, width: int) -> void:
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(state, word)
	button.add_theme_stylebox_override("normal", _box(fill, rule, width))
	button.add_theme_stylebox_override("hover", _box(fill, lit, width))
	button.add_theme_stylebox_override("pressed", _box(fill, lit, width, true))
	button.add_theme_stylebox_override("hover_pressed", _box(fill, lit, width, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A button's box: `fill` inside an edge `width` wide, drawn PRESS_DROP lower when `pressed`,
## the word inset at the left and centred on the height.
static func _box(fill: Color, edge: Color, width: int, pressed: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
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
	if _ready_button != null and not ArenaPace.reduce_flashes:
		queue_redraw()


## The ready control's glow: rings of its fill fading outward round its box, under it.
func _draw() -> void:
	if _ready_button == null:
		return
	var glow := STEADY
	if not ArenaPace.reduce_flashes:
		var t := Time.get_ticks_msec() / 1000.0
		glow = lerpf(GLOW_LOW, GLOW_HIGH, 0.5 - 0.5 * cos(TAU * t / PULSE))
	var box := _ready_button.get_theme_stylebox("normal") as StyleBoxFlat
	var rect := Rect2(_ready_button.position, _ready_button.size)
	rect.position.y += _drop(_ready_button)
	for i: int in range(1, GLOW_REACH + 1):
		var fade := 1.0 - float(i - 1) / GLOW_REACH
		draw_rect(rect.grow(i), Color(box.bg_color, glow * 0.35 * fade * fade), false, 1.0)


## A click on a button that is off, while input is open, is refused. (While a move is played
## back the buttons take no clicks.)
func _refuse_if_off(event: InputEvent, button: Button) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and button.disabled and _up:
		Sfx.play("refuse")


## Draws an off button's dashed edge over its box.
func _draw_dashes(button: Button) -> void:
	if not button.disabled:
		return
	var r := Rect2(Vector2.ONE * DASH_WIDTH * 0.5, button.size - Vector2.ONE * DASH_WIDTH)
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]
	for i: int in 4:
		button.draw_dashed_line(corners[i], corners[(i + 1) % 4], Palette.CHALK_3, DASH_WIDTH, DASH)


## Tells the tallies how to be drawn: each in its button's word colour, lower while pressed.
func _show_tallies() -> void:
	if _numbers == null:
		return
	_numbers.set_tally_look(0, _word(_play), _drop(_play))
	_numbers.set_tally_look(1, _word(_discard), _drop(_discard))


func _word(button: Button) -> Color:
	if button.disabled:
		return Palette.CHALK_3
	return button.get_theme_color("font_color")


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
