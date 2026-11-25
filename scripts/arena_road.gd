class_name ArenaRoad
extends Control
## The night's road, under the heading: its two rounds, its scene and the dawn after it, as
## four marks joined by a pencil line, each with a word under it. The round being played is
## filled in the colour of the man at the table, those passed in chalk, those to come drawn
## in outline. The dawn is a glyph for where it will be spent: a flask for the laboratory, a
## lantern for the back alley, a closed book for the run's end.
##
## A child of ArenaNumbers that covers it, laid in ArenaLayout's `road` zone. `show_night`
## puts up the night as RulesView.table() gives it; the dawn's place then follows the stance
## of the numbers (`is_jekyll`) the moment it changes, as a shift turns the page.

const PITCH := 58.0 ## from one mark's centre to the next
const FIRST := 8.0 ## the first mark's centre, from the zone's left
const MIDDLE := 8.0 ## the marks' centres, from the zone's top
const LABEL_BASE := 26.0 ## the words' baseline, from the zone's top
const LABEL_SIZE := 10
const RING := 6.0
const DIAMOND := 7.0
const GLYPH := 14.0 ## the dawn's glyph, high
const LINE_WIDTH := 1.5
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")

var _lines := Control.new()
var _font := FontVariation.new()
## 0 and 1 for the rounds, 2 for the scene.
var _at := 0
var _twist := ""
var _ends := false
var _jekyll := true


func _init() -> void:
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.5
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.material = LINE_MATERIAL
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.draw.connect(_draw_lines)
	add_child(_lines)


## The night from RulesView.table(): {no, round, scene, twist, dawn: {ends, ...}}, and the
## stance at the table.
func show_night(night: Dictionary, jekyll: bool) -> void:
	_at = 2 if night.scene else clampi(int(night.round) - 1, 0, 1)
	_twist = str(night.twist)
	_ends = bool(night.dawn.ends)
	_jekyll = jekyll
	_redraw()


func _process(_delta: float) -> void:
	var numbers := get_parent() as ArenaNumbers
	if numbers and numbers.is_jekyll != _jekyll:
		_jekyll = numbers.is_jekyll
		_redraw()


func _redraw() -> void:
	queue_redraw()
	_lines.queue_redraw()


func _zone() -> Rect2:
	return ArenaLayout.road(size)


func _centre(i: int) -> Vector2:
	var zone := _zone()
	return zone.position + Vector2(FIRST + PITCH * i, MIDDLE)


func _man() -> Color:
	return Palette.JEKYLL if _jekyll else Palette.HYDE


func _dawn_colour() -> Color:
	if _ends:
		return Palette.CHALK
	return Palette.JEKYLL if _jekyll else Palette.HYDE


func _dawn_word() -> String:
	if _ends:
		return "The end"
	return "Laboratory" if _jekyll else "Back alley"


## What fills mark `i` (a round or the scene), clear for one to come.
func _fill(i: int) -> Color:
	if i < _at:
		return Palette.CHALK_3
	if i == _at:
		return _man()
	return Color(0, 0, 0, 0)


## The fills and the words.
func _draw() -> void:
	for i in 3:
		var fill := _fill(i)
		if fill.a <= 0.0:
			continue
		var c := _centre(i)
		if i < 2:
			draw_circle(c, RING, fill)
		else:
			draw_colored_polygon(_diamond(c), fill)
	var base := _zone().position.y + LABEL_BASE
	var words: Array[String] = ["1", "2", "Scene" if _twist == "" else _twist.capitalize(), _dawn_word()]
	var colours: Array[Color] = [Palette.CHALK_2, Palette.CHALK_2,
			Palette.CHALK_2 if _twist == "" else Palette.TWIST, _dawn_colour()]
	for i in 4:
		var w := _font.get_string_size(words[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE).x
		var x := _centre(i).x - w * 0.5
		if i == 3:
			# The last word may run right of its mark, but not left past the scene's.
			x = maxf(x, _centre(2).x + 24.0)
		draw_string(_font, Vector2(x, base), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, colours[i])


## The pencil: the line that joins the marks, the outlines, and the dawn's glyph.
func _draw_lines() -> void:
	var pencil := Pencil.new(23)
	pencil.colour = Palette.CHALK_3
	var gaps: Array[float] = [RING + 2.0, RING + 2.0, DIAMOND + 2.0, GLYPH * 0.5 + 2.0]
	for i in 3:
		var from := _centre(i) + Vector2(gaps[i], 0.0)
		var to := _centre(i + 1) - Vector2(gaps[i + 1], 0.0)
		pencil.stroke(PackedVector2Array([from, to]), LINE_WIDTH, 0.4)
	for i in 3:
		var c := _centre(i)
		pencil.colour = Palette.CHALK_2 if i > _at else _fill(i)
		if i < 2:
			pencil.stroke(_circle(c, RING), LINE_WIDTH, 0.2)
		else:
			var d := _diamond(c)
			d.append(d[0])
			pencil.stroke(d, LINE_WIDTH, 0.2)
	pencil.colour = _dawn_colour()
	var c3 := _centre(3)
	if _ends:
		_book(pencil, c3)
	elif _jekyll:
		_flask(pencil, c3)
	else:
		_lantern(pencil, c3)
	pencil.draw(_lines)


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 17:
		points.append(c + Vector2.from_angle(TAU * k / 16.0 - PI * 0.5) * r)
	return points


static func _diamond(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -DIAMOND), c + Vector2(DIAMOND, 0), c + Vector2(0, DIAMOND),
			c + Vector2(-DIAMOND, 0)])


## A flask: a neck with a lip, and a body that widens to a flat foot.
static func _flask(pencil: Pencil, c: Vector2) -> void:
	var h := GLYPH * 0.5
	var top := c.y - h
	var foot := c.y + h
	pencil.stroke(PackedVector2Array([Vector2(c.x - 3.5, top), Vector2(c.x + 3.5, top)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x - 2.0, top), Vector2(c.x - 2.0, c.y - 1.5),
			Vector2(c.x - 6.0, foot), Vector2(c.x + 6.0, foot), Vector2(c.x + 2.0, c.y - 1.5),
			Vector2(c.x + 2.0, top)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x - 4.0, c.y + 3.0), Vector2(c.x + 4.0, c.y + 3.0)]), LINE_WIDTH * 0.8, 0.1)


## A lantern: a ring to hang it by, a cap, a glass between two posts, a base, and its flame.
static func _lantern(pencil: Pencil, c: Vector2) -> void:
	var h := GLYPH * 0.5
	var top := c.y - h
	var foot := c.y + h
	pencil.stroke(_circle(Vector2(c.x, top + 1.5), 1.5), LINE_WIDTH * 0.8, 0.05)
	pencil.stroke(PackedVector2Array([Vector2(c.x - 5.0, top + 5.0), Vector2(c.x, top + 3.0),
			Vector2(c.x + 5.0, top + 5.0)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x - 4.0, top + 5.0), Vector2(c.x - 4.0, foot - 2.0)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x + 4.0, top + 5.0), Vector2(c.x + 4.0, foot - 2.0)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x - 5.5, foot - 1.0), Vector2(c.x + 5.5, foot - 1.0)]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(c.x, c.y + 3.0), Vector2(c.x - 1.2, c.y + 1.0),
			Vector2(c.x, c.y - 1.5), Vector2(c.x + 1.2, c.y + 1.0), Vector2(c.x, c.y + 3.0)]), LINE_WIDTH * 0.8, 0.05)


## A closed book: its cover, its spine on the left, and the pages' edge.
static func _book(pencil: Pencil, c: Vector2) -> void:
	var h := GLYPH * 0.5
	var r := Rect2(c.x - 5.5, c.y - h, 11.0, GLYPH)
	pencil.stroke(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y), r.position]), LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(r.position.x + 2.5, r.position.y), Vector2(r.position.x + 2.5, r.end.y)]),
			LINE_WIDTH, 0.1)
	pencil.stroke(PackedVector2Array([Vector2(r.end.x - 1.5, r.position.y + 2.0), Vector2(r.end.x - 1.5, r.end.y - 2.0)]),
			LINE_WIDTH * 0.7, 0.05)
