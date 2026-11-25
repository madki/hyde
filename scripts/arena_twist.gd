class_name ArenaTwist
extends Control
## The scene's twist, stated in its zone (ArenaLayout.twist) for the whole round.
##
## - In the night's first rounds: one quiet line at the zone's right, naming the twist the
##   scene will bring ("IN THE SCENE · HUNTED"). No box.
## - In the scene: a box over the zone in the twist's own colour, its name at the head and
##   its whole wording under it. Never cut: a long wording is written smaller, and the box
##   grows down to hold it.
## - A night with no twist: nothing.
##
## It reads RulesView.table().night and works out no rule. `pulse()` flashes the box once.

const HEAD_SIZE := 11
const TEXT_SIZE := 11
const SMALL_TEXT_SIZE := 10
const LINE_GAP := 13.0
const SMALL_LINE_GAP := 11.0
const TEXT_WIDTH := 188.0
const MAX_LINES := 3
const EDGE := 1.5
const EDGE_PULSE := 3.0
const FILL := 0.10
const FILL_PULSE := 0.30
const PULSE_TIME := 0.5
## Inside the box: the head's baseline, the first line's, and the room under the last.
const HEAD_BASELINE := 14.0
const FIRST_BASELINE := 28.0
const PAD := 4.0

var _heavy := FontVariation.new()
var _plain: Font = ThemeDB.fallback_font
## The night as RulesView.table().night gives it, or empty.
var _night: Dictionary = {}
## 0 at rest, 1 at the height of a pulse.
var _flash := 0.0:
	set(value):
		_flash = value
		queue_redraw()
var _pulse: Tween


func _init() -> void:
	name = "Twist"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1


func _ready() -> void:
	resized.connect(queue_redraw)


## Shows this night's twist: `night` is RulesView.table().night.
func show_night(night: Dictionary) -> void:
	if night == _night:
		return
	_night = night.duplicate()
	queue_redraw()


## True while there is a twist to state.
func has_twist() -> bool:
	return not _night.is_empty() and String(_night.get("twist", "")) != ""


## The box's outline thickens and its fill deepens, and both go back: once, in half a second.
## With reduced flashes only the outline moves.
func pulse() -> void:
	if not has_twist() or not _night.get("scene", false):
		return
	if _pulse:
		_pulse.kill()
	_flash = 0.0
	_pulse = create_tween()
	_pulse.tween_property(self, "_flash", 1.0, PULSE_TIME * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "_flash", 0.0, PULSE_TIME * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _draw() -> void:
	if not has_twist():
		return
	var zone := ArenaLayout.twist(size)
	var twist_name := String(_night.twist).to_upper()
	if not _night.get("scene", false):
		var line := "IN THE SCENE · %s" % twist_name
		draw_string(_heavy, Vector2(zone.position.x, zone.position.y + 12.0), line,
				HORIZONTAL_ALIGNMENT_RIGHT, zone.size.x, HEAD_SIZE, Palette.CHALK_2)
		return
	# The wording, at 11 px if three lines hold it, else at 10 px: never cut.
	var words := _wrapped(String(_night.twist_text), TEXT_SIZE)
	var gap := LINE_GAP
	if words.get_line_count() > MAX_LINES:
		words = _wrapped(String(_night.twist_text), SMALL_TEXT_SIZE)
		gap = SMALL_LINE_GAP
	var lines := words.get_line_count()
	var box := zone
	box.size.y = maxf(zone.size.y, FIRST_BASELINE + gap * (lines - 1) + PAD)
	var fill := FILL if ArenaPace.reduce_flashes else lerpf(FILL, FILL_PULSE, _flash)
	draw_rect(box, Color(Palette.TWIST, fill))
	draw_rect(box, Palette.TWIST, false, lerpf(EDGE, EDGE_PULSE, _flash))
	var inner_left := box.position.x + (box.size.x - TEXT_WIDTH) * 0.5
	draw_string(_heavy, Vector2(inner_left, box.position.y + HEAD_BASELINE), "TWIST · %s" % twist_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, HEAD_SIZE, Palette.TWIST)
	for i in lines:
		var baseline := box.position.y + FIRST_BASELINE + gap * i
		words.draw_line(get_canvas_item(), Vector2(inner_left, baseline - words.get_line_ascent(i)), i, Palette.CHALK)


func _wrapped(text: String, font_size: int) -> TextParagraph:
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, _plain, font_size)
	paragraph.width = TEXT_WIDTH
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	return paragraph
