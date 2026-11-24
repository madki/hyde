class_name ArenaGhostMarks
extends Control
## The marks of a chosen play that have no part of their own to lie on: the outline of each
## card more it would draw (Curiosity, Impulse), beside the draw pile, and the one line said
## on a round's last play. They are still: nothing here moves.

const CREAM := Color(0.95, 0.9, 0.78)
const OUTLINE := Color(0.05, 0.035, 0.06, 0.9)

var _draws := 0
var _pile := Vector2.ZERO
var _words := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.add_theme_color_override("font_color", CREAM)
	_words.add_theme_color_override("font_outline_color", OUTLINE)
	_words.add_theme_constant_override("outline_size", 6)
	_words.add_theme_font_size_override("font_size", 17)
	add_child(_words)


## `draws` card outlines by the draw pile, whose top lies at `pile` (a point on the page).
func show_draws(draws: int, pile: Vector2) -> void:
	_draws = draws
	_pile = get_global_transform().affine_inverse() * pile
	queue_redraw()


## One line of words, its middle at `at` (a point on the page), "" for none.
func say(words: String, at: Vector2 = Vector2.ZERO) -> void:
	_words.text = words
	_words.visible = words != ""
	_words.size = Vector2(620.0, 26.0)
	_words.position = get_global_transform().affine_inverse() * at - _words.size * 0.5


func _draw() -> void:
	var card := ArenaCard.SIZE * ArenaPile.SCALE
	for i in _draws:
		var corner := _pile - card * 0.5 + Vector2(16.0 + 12.0 * i, -14.0 - 8.0 * i)
		var points := [corner, corner + Vector2(card.x, 0.0), corner + card, corner + Vector2(0.0, card.y), corner]
		for k in 4:
			draw_dashed_line(points[k], points[k + 1], Color(CREAM, 0.85), 2.0, 7.0)
