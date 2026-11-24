class_name ArenaTabs
extends Control
## The two tabs on the arena's page, one on each edge (ArenaLayout.tab_left and tab_right):
## slips of cream stock that stick in from outside the border, each with a few words written
## along it. The left one names the scene's twist; the right one says which key to hold for
## every number. They only show their words and say where they are: ArenaViews answers the
## pointer.

const CREAM := Color(0.87, 0.81, 0.67)
const CREAM_LIT := Color(0.97, 0.93, 0.82)
const PENCIL := Color(0.08, 0.05, 0.04)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
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
		# Its inner corners are cut; the outer side runs off the page.
		var inner := r.end.x if which == "left" else r.position.x
		var outer := r.position.x - 4.0 if which == "left" else r.end.x + 4.0
		var cut := 7.0 if which == "left" else -7.0
		var slip := PackedVector2Array([Vector2(outer, r.position.y), Vector2(inner - cut, r.position.y),
				Vector2(inner, r.position.y + 7.0), Vector2(inner, r.end.y - 7.0),
				Vector2(inner - cut, r.end.y), Vector2(outer, r.end.y)])
		var under := PackedVector2Array()
		for p in slip:
			under.append(p + Vector2(2.0 if which == "left" else -2.0, 3.0))
		draw_colored_polygon(under, SHADOW)
		draw_colored_polygon(slip, CREAM_LIT if lit == which else CREAM)
		var edge := slip.duplicate()
		draw_polyline(edge, Color(PENCIL, 0.8), 1.2, true)
		# The words run up the left tab and down the right one, as on a book's spine.
		var width := _font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
		var middle := r.get_center()
		if which == "left":
			draw_set_transform(middle + Vector2(4.0, width * 0.5), -PI * 0.5)
		else:
			draw_set_transform(middle + Vector2(-4.0, -width * 0.5), PI * 0.5)
		draw_string(_font, Vector2.ZERO, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, PENCIL)
		draw_set_transform(Vector2.ZERO)
