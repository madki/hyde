class_name ArenaHeading
extends Control
## A round's heading, written in the centre of the table as a journal heading when the round
## begins: the night and the round, the target, and on a night's first round the night's
## title and its scene's twist. In a scene the twist is written large. It is held for a
## moment, then shrinks away towards its place at the top of the left column.
##
## It is given its words; it works out nothing. It plays through the beat queue (`beats`).

const TEXT := Color(0.95, 0.9, 0.78)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)
const WIDTH := 600.0
const FADE := 0.25
const SHRINK := 0.35

## The table's span, as in ArenaHand, and the height of the heading's middle from the top.
@export var table_left := 295.0
@export var room_right := 190.0
@export var middle_y := 300.0

var beats: ArenaBeats

var _block := Control.new()
var _head := Label.new()
var _target := Label.new()
var _title := Label.new()
var _twist := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.modulate.a = 0.0
	add_child(_block)
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.9
	heavy.spacing_glyph = 1
	var slanted := FontVariation.new()
	slanted.base_font = ThemeDB.fallback_font
	slanted.variation_embolden = 0.4
	slanted.variation_transform = Transform2D(Vector2(1.0, 0.22), Vector2(0.0, 1.0), Vector2.ZERO)
	for label: Label in [_head, _target, _title, _twist]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", TEXT)
		label.add_theme_color_override("font_outline_color", OUTLINE)
		label.add_theme_constant_override("outline_size", 7)
		label.add_theme_font_override("font", slanted if label in [_title, _twist] else heavy)
		label.size.x = WIDTH
		label.position.x = -WIDTH * 0.5
		_block.add_child(label)
	_head.add_theme_font_size_override("font_size", 34)
	_target.add_theme_font_size_override("font_size", 24)
	_title.add_theme_font_size_override("font_size", 22)


## Writes the heading and holds it, then sends it off towards `to` (a point on the page: the
## top of the left column). `words` is {head, target, title, twist, large}: `title` and
## `twist` may be "", and `large` writes the twist large. Await it.
func play(words: Dictionary, to: Vector2) -> void:
	_head.text = words.head
	_target.text = words.target
	_title.text = words.get("title", "")
	_twist.text = words.get("twist", "")
	_twist.add_theme_font_size_override("font_size", 26 if words.get("large", false) else 16)
	# Laid out from the top down, each under the one before, then centred on the middle.
	var y := 0.0
	for label: Label in [_head, _target, _title, _twist]:
		label.visible = label.text != ""
		if not label.visible:
			continue
		label.size = Vector2(WIDTH, 0.0)
		label.size.y = label.get_minimum_size().y
		label.position.y = y
		y += label.size.y + (10.0 if label == _target else 4.0)
	for label: Label in [_head, _target, _title, _twist]:
		label.position.y -= y * 0.5
	var middle := Vector2((table_left + size.x - room_right) * 0.5, middle_y)
	_block.position = middle
	_block.scale = Vector2.ONE
	_block.modulate.a = 0.0
	var t := beats.tween()
	t.tween_property(_block, "modulate:a", 1.0, FADE)
	t.tween_interval(ArenaPace.HOLD + (0.6 if _twist.text != "" else 0.0))
	t.tween_property(_block, "position", get_global_transform().affine_inverse() * to, SHRINK) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(_block, "scale", Vector2(0.3, 0.3), SHRINK) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(_block, "modulate:a", 0.0, SHRINK).set_ease(Tween.EASE_IN)
	await t.finished
