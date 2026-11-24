class_name ArenaControls
extends Control
## The two controls under the hand: Play and Discard. Pass takes Play's place when the play
## can be passed. Each is on when the rules allow it, and says why not when the pointer rests
## on it. They work out no rule: `show_table` takes RulesView.table() with the chosen cards.
##
## While a move is played back they lie low (`lower`), and rise when input opens (`rise`).

signal play_pressed
signal discard_pressed
signal pass_pressed

const BUTTON_SIZE := Vector2(118.0, 34.0)
const GAP := 18.0
## How far the controls drop while they lie low, and the time they take to rise.
const DROP := 14.0
const RISE_TIME := 0.2
const CREAM := Color(0.93, 0.88, 0.75)
const CREAM_LIT := Color(0.99, 0.95, 0.84)
const PENCIL := Color(0.08, 0.05, 0.04)

## The table's span, as in ArenaHand, and how far above the page's foot the controls lie.
@export var table_left := 295.0
@export var room_right := 190.0
@export var from_foot := 86.0

var _row := Control.new()
var _play := Button.new()
var _discard := Button.new()
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
	font.spacing_glyph = 1
	for button: Button in [_play, _discard]:
		button.size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 15)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, PENCIL)
		button.add_theme_color_override("font_disabled_color", Color(PENCIL, 0.45))
		button.add_theme_stylebox_override("normal", _box(CREAM, 1.0))
		button.add_theme_stylebox_override("hover", _box(CREAM_LIT, 1.0))
		button.add_theme_stylebox_override("pressed", _box(CREAM_LIT, 1.0))
		button.add_theme_stylebox_override("disabled", _box(CREAM, 0.4))
		_row.add_child(button)
	_play.text = "Play"
	_discard.text = "Discard"
	_discard.position.x = BUTTON_SIZE.x + GAP
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
	_play.text = "Pass" if _passing else "Play"
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


## Writes the warning of a play that would make him break out on the Play control, or takes
## it off. `show_table` takes it off too.
func warn_breakout(on: bool) -> void:
	if _passing:
		return
	_play.text = "Play: he breaks out" if on else "Play"
	_play.size.x = BUTTON_SIZE.x + (74.0 if on else 0.0)
	_discard.position.x = _play.size.x + GAP
	_row.position.x = _rest().x - (37.0 if on else 0.0)


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
	var to := _rest() + (Vector2.ZERO if up else Vector2(0.0, DROP))
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


func _rest() -> Vector2:
	var middle := (table_left + size.x - room_right) * 0.5
	return Vector2(middle - (BUTTON_SIZE.x * 2.0 + GAP) * 0.5, size.y - from_foot)


func _lay_out() -> void:
	_row.position = _rest() + (Vector2.ZERO if _up else Vector2(0.0, DROP))


static func _box(colour: Color, alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(colour, alpha)
	box.border_color = Color(PENCIL, alpha)
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.28 * alpha)
	box.shadow_size = 3
	box.shadow_offset = Vector2(1.0, 2.0)
	return box
