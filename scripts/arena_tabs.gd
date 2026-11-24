class_name ArenaTabs
extends Control
## The two tabs on the arena's page, one on each edge (ArenaLayout.tab_left and tab_right):
## slips of night stock that stick in from outside the border, each with a few words written
## along it. The left one names the scene's twist; the right one says which key to hold for
## every number. They only show their words and say where they are: ArenaViews answers the
## pointer.

## Border width at rest and lit: a lit tab is raised, with a brighter, heavier edge.
const EDGE := 1.5
const EDGE_LIT := 2.0
const FONT_SIZE := 12

## The words on the left and on the right tab. A tab with no words is not drawn.
var left := "":
	set(value):
		left = value
		queue_redraw()
var right := "":
	set(value):
		right = value
		queue_redraw()
## Which tab the pointer is on, "left", "right" or "": that one is drawn lit.
var lit := "":
	set(value):
		if value != lit:
			lit = value
			queue_redraw()

var _font := FontVariation.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.6
	_font.spacing_glyph = 1


func _ready() -> void:
	resized.connect(queue_redraw)


## Where a tab lies, in this element's own coordinates: "left" or "right".
func rect_of(which: String) -> Rect2:
	return ArenaLayout.tab_left(size) if which == "left" else ArenaLayout.tab_right(size)


## The tab that holds `point`, "" for neither. A tab with no words holds nothing.
func tab_at(point: Vector2) -> String:
	if left != "" and rect_of("left").has_point(point):
		return "left"
	if right != "" and rect_of("right").has_point(point):
		return "right"
	return ""


func _draw() -> void:
	for which: String in ["left", "right"]:
		var words := left if which == "left" else right
		if words == "":
			continue
		var r := rect_of(which)
		# A square slip whose outer side runs off the page.
		var inner := r.end.x if which == "left" else r.position.x
		var outer := r.position.x - 4.0 if which == "left" else r.end.x + 4.0
		var slip := PackedVector2Array([Vector2(outer, r.position.y), Vector2(inner, r.position.y),
				Vector2(inner, r.end.y), Vector2(outer, r.end.y)])
		var is_lit := lit == which
		draw_colored_polygon(slip, Palette.NIGHT_3 if is_lit else Palette.NIGHT_2)
		draw_polyline(slip, Palette.CHALK if is_lit else Palette.RULE, EDGE_LIT if is_lit else EDGE)
		# The words run up the left tab and down the right one, as on a book's spine.
		var width := _font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
		var middle := r.get_center()
		if which == "left":
			draw_set_transform(middle + Vector2(4.0, width * 0.5), -PI * 0.5)
		else:
			draw_set_transform(middle + Vector2(-4.0, -width * 0.5), PI * 0.5)
		draw_string(_font, Vector2.ZERO, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE,
				Palette.CHALK if is_lit else Palette.CHALK_2)
		draw_set_transform(Vector2.ZERO)
