class_name ArenaControls
extends Control
## The two controls at the foot of the page, each a written word: PLAY beside the draw pile
## and DISCARD beside the discards (ArenaLayout.controls_play and controls_discard). A word
## takes clicks over its whole zone, the tally under it included; the tallies themselves are
## ArenaColumn's. PASS takes PLAY's place when the play can be passed. Each is on when the
## rules allow it, and says why not when the pointer rests on it. They work out no rule:
## `show_table` takes RulesView.table() with the chosen cards.
##
## While a move is played back they lie low (`lower`), and rise when input opens (`rise`).

signal play_pressed
signal discard_pressed
signal pass_pressed

## The room kept under a word for its tally, in pixels.
const TALLY_ROOM := 30.0
## How far the controls drop while they lie low, and the time they take to rise.
const DROP := 14.0
const RISE_TIME := 0.2
const CREAM := Color(0.93, 0.88, 0.75)
const CREAM_LIT := Color(1.0, 0.97, 0.88)
const WARNING := Color(1.0, 0.72, 0.35)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)

var _row := Control.new()
var _play := Button.new()
var _discard := Button.new()
var _warning := Label.new()
var _passing := false
var _up := true
var _move: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	font.spacing_glyph = 2
	# The word stands in the upper part of its zone: the tally lies under it.
	var box := StyleBoxEmpty.new()
	box.content_margin_bottom = TALLY_ROOM
	for button: Button in [_play, _discard]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_focus_color", CREAM)
		button.add_theme_color_override("font_hover_color", CREAM_LIT)
		button.add_theme_color_override("font_pressed_color", CREAM_LIT)
		button.add_theme_color_override("font_disabled_color", Color(CREAM, 0.4))
		button.add_theme_color_override("font_outline_color", OUTLINE)
		button.add_theme_constant_override("outline_size", 6)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, box)
		_row.add_child(button)
	_play.text = "PLAY"
	_discard.text = "DISCARD"
	_warning.text = "he breaks out"
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 13)
	_warning.add_theme_color_override("font_color", WARNING)
	_warning.add_theme_color_override("font_outline_color", OUTLINE)
	_warning.add_theme_constant_override("outline_size", 5)
	_row.add_child(_warning)
	_play.pressed.connect(func() -> void:
		if _passing:
			pass_pressed.emit()
		else:
			play_pressed.emit())
	_discard.pressed.connect(func() -> void: discard_pressed.emit())


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()


## Sets both controls from RulesView.table() and the number of cards chosen in the hand.
func show_table(table: Dictionary, chosen: int) -> void:
	var playing: bool = table.phase == "play"
	var play: Variant = table.play
	_passing = false
	warn_breakout(false)
	_passing = playing and table.can_pass.ok
	_play.text = "PASS" if _passing else "PLAY"
	if _passing:
		_play.disabled = false
		_play.tooltip_text = "Nothing can be played and no discard is left: the play is passed."
	else:
		var why := ""
		if not playing:
			why = "Not now."
		elif table.plays <= 0:
			why = "No plays left."
		elif play == null:
			why = "Choose cards for a hand."
		elif not play.ok:
			why = play.reason
		_play.disabled = why != ""
		_play.tooltip_text = why
	var why_not := ""
	if not playing:
		why_not = "Not now."
	elif table.discards <= 0:
		why_not = "No discards left."
	elif chosen < 1:
		why_not = "Choose cards to discard."
	_discard.disabled = why_not != ""
	_discard.tooltip_text = why_not


## Writes the warning of a play that would make him break out over the word PLAY, or takes
## it off. `show_table` takes it off too.
func warn_breakout(on: bool) -> void:
	_warning.visible = on and not _passing


## True if Play (or Pass) can be pressed now.
func can_play() -> bool:
	return _up and not _play.disabled and not _passing


func can_pass() -> bool:
	return _up and _passing


func can_discard() -> bool:
	return _up and not _discard.disabled


## The controls rise into place: input is open.
func rise(animate: bool = true) -> void:
	_set_up(true, animate)


## The controls lie low while a move is played back.
func lower(animate: bool = true) -> void:
	_set_up(false, animate)


func _set_up(up: bool, animate: bool) -> void:
	if up == _up and animate:
		return
	_up = up
	if _move:
		_move.kill()
	var to := Vector2.ZERO if up else Vector2(0.0, DROP)
	var alpha := 1.0 if up else 0.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button: Button in [_play, _discard]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if up else Control.MOUSE_FILTER_IGNORE
	if not animate or not is_inside_tree():
		_row.position = to
		_row.modulate.a = alpha
		return
	_move = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move.tween_property(_row, "position", to, RISE_TIME)
	_move.tween_property(_row, "modulate:a", alpha, RISE_TIME)


func _lay_out() -> void:
	var play := ArenaLayout.controls_play(size)
	var discard := ArenaLayout.controls_discard(size)
	_play.position = play.position
	_play.size = play.size
	_discard.position = discard.position
	_discard.size = discard.size
	_warning.position = play.position + Vector2(-20.0, -20.0)
	_warning.size = Vector2(play.size.x + 40.0, 18.0)
