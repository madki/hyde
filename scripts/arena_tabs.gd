class_name ArenaTabs
extends Control
## The tab on the arena's right edge (ArenaLayout.tab_right): a slip of night stock that
## sticks in from outside the border, with a few words written down it, saying which key to
## hold for every number. It only shows its words and says where it is: ArenaViews answers
## the pointer.

## Border width at rest and lit: a lit tab is raised, with a brighter, heavier edge.
const EDGE := 1.5
const EDGE_LIT := 2.0
const FONT_SIZE := 12

## The words on the tab. A tab with no words is not drawn.
var right := "":
	set(value):
		right = value
		queue_redraw()
## Which tab the pointer is on, "right" or "": that one is drawn lit.
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


## Where the tab lies, in this element's own coordinates: "right".
func rect_of(_which: String) -> Rect2:
	return ArenaLayout.tab_right(size)


## The tab that holds `point`, "" for none. A tab with no words holds nothing.
func tab_at(point: Vector2) -> String:
	if right != "" and rect_of("right").has_point(point):
		return "right"
	return ""


func _draw() -> void:
	if right == "":
		return
	var r := rect_of("right")
	# A square slip whose outer side runs off the page.
	var inner := r.position.x
	var outer := r.end.x + 4.0
	var slip := PackedVector2Array([Vector2(outer, r.position.y), Vector2(inner, r.position.y),
			Vector2(inner, r.end.y), Vector2(outer, r.end.y)])
	var is_lit := lit == "right"
	draw_colored_polygon(slip, Palette.NIGHT_3 if is_lit else Palette.NIGHT_2)
	draw_polyline(slip, Palette.CHALK if is_lit else Palette.RULE, EDGE_LIT if is_lit else EDGE)
	# The words run down the tab, as on a book's spine.
	var width := _font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	draw_set_transform(r.get_center() + Vector2(-4.0, -width * 0.5), PI * 0.5)
	draw_string(_font, Vector2.ZERO, right, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE,
			Palette.CHALK if is_lit else Palette.CHALK_2)
	draw_set_transform(Vector2.ZERO)
