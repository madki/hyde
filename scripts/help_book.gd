class_name HelpBook
extends Control
## The help book: how the game is played, in a few pages (HelpPages) laid over the screen. It
## lies open at two leaves: the page's words on the left, and on the right a picture made
## from the table's own parts (its cards, the restraint, the gauges, the line, the night's
## road), in the colours of the man who has the table.
##
## Add one HelpBook to a screen, above everything else; it fills the screen and is hidden
## until `open(page, hyde, dials)`. While it is open the screen under it is shaded and takes
## no key, click or hover. The left and right keys, or a click on a leaf's outer edge, turn
## the page; Esc, F1 or a click outside the book close it, and `closed` is sent.
##
## Run on its own (scenes/help_book.tscn) it shows one page, for a still:
##
##   tools/shot.sh /abs/out.png res://scenes/help_book.tscn --page=3 --hyde
##
## It works out no rule: every name and number comes from RulesConfig and the run's numbers.

## The book has been closed.
signal closed

## The open book, and each leaf's margins: at its outer edge and the spine, and at the top.
const SHEET := Vector2(1056.0, 552.0)
const SIDE := 40.0
const TOP := 34.0
## Where the picture lies, on the right leaf.
const PIC := Rect2(568.0, 40.0, 448.0, 452.0)
## The strip at a leaf's outer edge that turns the page when clicked.
const EDGE := 40.0
const TITLE_SIZE := 28
const WORD_SIZE := 19
const NOTE_SIZE := 16
## The room between two paragraphs.
const PARAGRAPH_GAP := 12.0
const SHADE := Color(Palette.NIGHT_1, 0.78)
const CLOSE_KEYS: Array[Key] = [KEY_ESCAPE, KEY_F1]
const BACK_KEYS: Array[Key] = [KEY_LEFT, KEY_PAGEUP]
const ON_KEYS: Array[Key] = [KEY_RIGHT, KEY_PAGEDOWN]
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/pencil_line_material.tres")
## How a card's picture that is a drawing is printed: its lines, in the colour it is drawn with.
const DRAWING_MATERIAL: ShaderMaterial = preload("res://shaders/card_drawing_material.tres")
## The size of the table's page whose zones the table's parts are laid out for (ArenaLayout).
const TABLE_PAGE := Vector2(1152.0, 648.0)
## Each man's colours: the leaves, their edge, and his light.
const TONES := {
	false: {"fill": Palette.PAGE_DARK, "edge": Palette.JEKYLL_DEEP, "light": Palette.JEKYLL},
	true: {"fill": Palette.INK_DEEP, "edge": Palette.HYDE_DEEP, "light": Palette.HYDE},
}

## What the pictures show beside the rules' own numbers: a table in the middle of a night.
## The gauges of the three symbols, {habit, craving, temper}.
const SAMPLE_GAUGES := {
	"lamp": [1, 2, 2],
	"heart": [0, 1, 0],
	"mirror": [2, 0, 1],
}
## The steps of restraint filled.
const SAMPLE_RESTRAINT := 3
## The line when Ink is ahead: so many Paper Roots fewer than a run starts with, and so many
## Ink Roots more than his first arrival brings.
const SAMPLE_BEHIND := Vector2i(2, 3)

var _page := 1
var _hyde := false
var _dials := RulesDials.new()
## Which edge the pointer is on: -1 the left leaf's, 1 the right leaf's, 0 neither.
var _lit := 0

var _sheet := Control.new()
## The picture's parts, the pencil lines and drawings over them, and the writing over those.
var _picture := Control.new()
var _pencil := Control.new()
var _drawn := Control.new()
var _labels := Control.new()
## What the picture's layers draw, in the sheet's coordinates: {path, colour, width} or
## {sketch, box, colour} for the pencil; {picture, box, colour} for a picture that is a
## drawing; {text, at, size, colour, heavy, align, width} for the
## writing; {rect, colour} under the parts.
var _strokes: Array[Dictionary] = []
var _drawings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _rects: Array[Dictionary] = []
var _heavy := FontVariation.new()
var _light := FontVariation.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_heavy.spacing_glyph = 1
	_light.base_font = ThemeDB.fallback_font
	_light.variation_embolden = 0.35
	_sheet.size = SHEET
	_sheet.draw.connect(_draw_sheet)
	_pencil.material = LINE_MATERIAL
	_pencil.draw.connect(_draw_pencil)
	_drawn.material = DRAWING_MATERIAL
	_drawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_drawn.draw.connect(_draw_drawings)
	_labels.draw.connect(_draw_labels)
	add_child(_sheet)
	for layer: Control in [_sheet, _picture, _pencil, _drawn, _labels]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if layer != _sheet:
			layer.size = SHEET
			_sheet.add_child(layer)


func _ready() -> void:
	resized.connect(_lay_out)
	_lay_out()
	if get_tree().current_scene == self:
		# Run on its own: one page, for a still.
		open(int(Shot.arg("page")) if Shot.has_arg("page") else 1, Shot.has_arg("hyde"))
		if Shot.has_arg("words"):
			print_pages()
		Shot.run_if_requested(self)


## True while the book lies open.
func is_open() -> bool:
	return visible


## The number of the page it is open at, from 1.
func page() -> int:
	return _page


## Opens the book at page `number` (from 1), in Hyde's colours when `hyde` has the table, with
## the numbers the run plays by (the game's own when none are given).
func open(number: int = 1, hyde: bool = false, dials: RulesDials = null) -> void:
	_hyde = hyde
	_dials = dials if dials != null else RulesDials.new()
	_page = clampi(number, 1, HelpPages.count())
	_lit = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_lay_out()
	_show_page()
	Sfx.play("paper", 1.0, 0.8)


## Closes the book. Nothing when it is not open.
func close() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_picture()
	Sfx.play("paper", 0.85, 0.45)
	closed.emit()


## Turns `step` pages on (or back, below 0). Nothing past the first or the last page.
func turn(step: int) -> void:
	var to := clampi(_page + step, 1, HelpPages.count())
	if to == _page:
		return
	_page = to
	_show_page()
	Sfx.play("paper", 1.1, 0.6)


## Prints every page's words with how many they are: for a check of the pages' length.
func print_pages() -> void:
	for number in range(1, HelpPages.count() + 1):
		print("Page %d: %s (%d words)" % [number, HelpPages.PAGES[number - 1].title,
				HelpPages.word_count(number, _dials)])
		for paragraph in HelpPages.words(number, _dials):
			print("  ", paragraph)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if event is InputEventMouseMotion:
		_light_edge(_edge_at((_sheet.make_input_local(event) as InputEventMouseMotion).position))
		return
	if key:
		# A key let go is let through, so that what was held before the book is not left held.
		if not key.pressed:
			return
		get_viewport().set_input_as_handled()
		if key.keycode in BACK_KEYS:
			turn(-1)
		elif key.keycode in ON_KEYS:
			turn(1)
		elif key.keycode in CLOSE_KEYS and not key.echo:
			close()
	elif button:
		if not button.pressed:
			return
		get_viewport().set_input_as_handled()
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		var at := (_sheet.make_input_local(button) as InputEventMouseButton).position
		if not Rect2(Vector2.ZERO, SHEET).has_point(at):
			close()
		elif _edge_at(at) != 0:
			turn(_edge_at(at))


# Which leaf's outer edge holds `point` of the sheet, as the step a click there turns: -1, 1,
# or 0 for neither, and for an edge with no page beyond it.
func _edge_at(point: Vector2) -> int:
	if point.y < 0.0 or point.y > SHEET.y:
		return 0
	if point.x >= 0.0 and point.x < EDGE and _page > 1:
		return -1
	if point.x > SHEET.x - EDGE and point.x <= SHEET.x and _page < HelpPages.count():
		return 1
	return 0


func _light_edge(edge: int) -> void:
	if edge != _lit:
		_lit = edge
		_sheet.queue_redraw()


func _lay_out() -> void:
	_sheet.position = ((size - SHEET) * 0.5).round()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(Palette.OUTLINE, 0.0)
	shadow.shadow_color = Color(Palette.OUTLINE, 0.55)
	shadow.shadow_size = 14
	shadow.shadow_offset = Vector2(0.0, 5.0)
	shadow.set_corner_radius_all(4)
	draw_style_box(shadow, Rect2(_sheet.position, SHEET))


# ---------- the page ----------

func _stance() -> String:
	return "hyde" if _hyde else "jekyll"


func _light_colour() -> Color:
	return TONES[_hyde].light


# Lays the page's picture out anew and has every layer drawn again.
func _show_page() -> void:
	_clear_picture()
	match String(HelpPages.PAGES[_page - 1].picture):
		"round":
			_build_round()
		"men":
			_build_men()
		"hands":
			_build_hands()
		"gauges":
			_build_gauges()
		"line":
			_build_line()
	for layer: Control in [_sheet, _pencil, _drawn, _labels]:
		layer.queue_redraw()


func _clear_picture() -> void:
	for part in _picture.get_children():
		_picture.remove_child(part)
		part.queue_free()
	_strokes.clear()
	_drawings.clear()
	_texts.clear()
	_rects.clear()


# The two leaves, the left one's words, and what turns the page.
func _draw_sheet() -> void:
	var tone: Dictionary = TONES[_hyde]
	var rect := Rect2(Vector2.ZERO, SHEET)
	var paper := StyleBoxFlat.new()
	paper.bg_color = tone.fill
	paper.set_corner_radius_all(4)
	_sheet.draw_style_box(paper, rect)
	# The fold between the leaves: a shade that deepens towards it.
	var fold := SHEET.x * 0.5
	for i in 6:
		var reach := 26.0 - i * 4.0
		_sheet.draw_rect(Rect2(fold - reach, 2.0, reach * 2.0, SHEET.y - 4.0), Color(Palette.OUTLINE, 0.07))
	_sheet.draw_line(Vector2(fold, 2.0), Vector2(fold, SHEET.y - 2.0), Color(tone.edge, 0.8), 1.0)
	for mark: Dictionary in _rects:
		_sheet.draw_rect(mark.rect, mark.colour)
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = tone.edge
	edge.set_border_width_all(2)
	edge.set_corner_radius_all(4)
	_sheet.draw_style_box(edge, rect)
	# The words.
	var width := fold - SIDE * 2.0
	var y := TOP
	_sheet.draw_string(_heavy, Vector2(SIDE, y + _heavy.get_ascent(TITLE_SIZE)), HelpPages.PAGES[_page - 1].title,
			HORIZONTAL_ALIGNMENT_LEFT, width, TITLE_SIZE, tone.light)
	y += TITLE_SIZE + 16.0
	_sheet.draw_line(Vector2(SIDE, y), Vector2(SIDE + width, y), Color(tone.light, 0.35), 1.0)
	y += 20.0
	for paragraph in HelpPages.words(_page, _dials):
		_sheet.draw_multiline_string(_light, Vector2(SIDE, y + _light.get_ascent(WORD_SIZE)), paragraph,
				HORIZONTAL_ALIGNMENT_LEFT, width, WORD_SIZE, -1, Palette.CHALK)
		y += _light.get_multiline_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, width, WORD_SIZE).y + PARAGRAPH_GAP
	# The foot: which page this is, and how to go on.
	var foot := SHEET.y - 24.0
	_sheet.draw_string(_light, Vector2(SIDE, foot), "Page %d of %d" % [_page, HelpPages.count()],
			HORIZONTAL_ALIGNMENT_LEFT, width, NOTE_SIZE, Palette.CHALK_2)
	_sheet.draw_string(_light, Vector2(fold + SIDE, foot), "The arrow keys turn the page. Esc closes.",
			HORIZONTAL_ALIGNMENT_RIGHT, width, NOTE_SIZE, Palette.CHALK_3)
	for side: int in [-1, 1]:
		if (side < 0 and _page == 1) or (side > 0 and _page == HelpPages.count()):
			continue
		var tip := Vector2(fold + side * (fold - 14.0), SHEET.y * 0.5)
		var back := tip - Vector2(side * 9.0, 0.0)
		_sheet.draw_polyline(PackedVector2Array([back + Vector2(0.0, -14.0), tip, back + Vector2(0.0, 14.0)]),
				Palette.CHALK if _lit == side else Palette.CHALK_3, 3.0, true)


func _draw_pencil() -> void:
	for i in _strokes.size():
		var mark: Dictionary = _strokes[i]
		var pencil := Pencil.new(40 + i)
		pencil.colour = mark.colour
		if mark.has("sketch"):
			ArenaCardPictures.add(pencil, mark.sketch, mark.box, 1.6)
		else:
			pencil.stroke(mark.path, mark.width, 0.3)
		pencil.draw(_pencil)


func _draw_drawings() -> void:
	for mark: Dictionary in _drawings:
		var drawing := ArenaCardPictures.drawing(mark.picture)
		_drawn.draw_texture_rect(drawing, ArenaCardPictures.drawing_box(drawing, mark.box), false, mark.colour)


func _draw_labels() -> void:
	for mark: Dictionary in _texts:
		var font: Font = _heavy if mark.heavy else _light
		var px: int = mark.size
		var at: Vector2 = mark.at
		_labels.draw_multiline_string(font, at + Vector2(0.0, font.get_ascent(px)), mark.text, mark.align,
				mark.width, px, -1, mark.colour)


# ---------- what a picture is made of ----------

# Writing on the picture: its top left corner at `at`. With a `width` it is set in a column
# that wide from there, as `align` says, and wraps in it.
func _say(text: String, at: Vector2, px: int, colour: Color, heavy: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	_texts.append({"text": text, "at": at, "size": px, "colour": colour, "heavy": heavy, "align": align,
			"width": width})


# A card's picture fitted in `box`, in `colour`: drawn if it is a drawing, else in pencil.
func _card_picture(picture: String, box: Rect2, colour: Color) -> void:
	if ArenaCardPictures.drawing(picture):
		_drawings.append({"picture": picture, "box": box, "colour": colour})
	else:
		_strokes.append({"sketch": picture, "box": box, "colour": colour})


# A pencil line through `path`.
func _stroke(path: PackedVector2Array, colour: Color, width: float = 1.8) -> void:
	_strokes.append({"path": path, "colour": colour, "width": width})


# A pencil arrow from one point to another.
func _arrow(from: Vector2, to: Vector2, colour: Color) -> void:
	var way := (to - from).normalized()
	var side := Vector2(-way.y, way.x)
	_stroke(PackedVector2Array([from, to]), colour, 2.2)
	_stroke(PackedVector2Array([to - way * 11.0 + side * 7.0, to, to - way * 11.0 - side * 7.0]), colour, 2.2)


# A card of the table, its middle at `centre`.
func _card(data: Dictionary, centre: Vector2, zoom: float = 1.0, degrees: float = 0.0) -> void:
	var card := ArenaTravel.make_card(data)
	card.scale = Vector2(zoom, zoom)
	card.rotation_degrees = degrees
	card.position = centre - card.pivot_offset
	_picture.add_child(card)


# A part of the table that lays itself out in a zone of the table's page (ArenaLayout): that
# zone alone, `grow` wider all round, enlarged by `zoom`, its top left corner at `at`.
func _zoomed(part: Control, zone: Rect2, grow: Vector2, zoom: float, at: Vector2) -> void:
	var window := Control.new()
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = at
	window.size = (zone.size + grow * 2.0) * zoom
	_picture.add_child(window)
	window.add_child(part)
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.set_anchors_preset(Control.PRESET_TOP_LEFT)
	part.size = TABLE_PAGE
	part.scale = Vector2(zoom, zoom)
	part.position = (grow - zone.position) * zoom


# The gauges and the line as the table draws them, showing `gauges` ({symbol: [habit,
# craving, temper]}) and a line of `paper` Paper Roots against `ink` Ink Roots.
func _symbols(gauges: Dictionary, paper: int, ink: int) -> ArenaSymbols:
	var symbols := {}
	for sym: String in RulesConfig.ROOTS:
		var g: Array = gauges.get(sym, [0, 0, 0])
		symbols[sym] = {"habit": g[0], "craving": g[1], "temper": g[2], "paper": 0, "ink": 0,
				"paper_chips": _dials.root_chips, "ink_chips": _dials.root_chips}
	var part := ArenaSymbols.new()
	part.set_dials(_dials)
	part.show_table({"symbols": symbols, "line": {"paper": paper, "ink": ink}})
	return part


# ---------- the five pictures ----------

# A round: the man's best hand laid out, and the sum of what it scores.
func _build_round() -> void:
	var key := HelpPages.best_hand(_stance())
	var hand: Dictionary = RulesConfig.HANDS[_stance()][key]
	var cards := HelpPages.cards_of(_stance(), key, _dials)
	var mid := PIC.position.x + PIC.size.x * 0.5
	var chips := int(hand.chips)
	var sum := str(chips)
	for i in cards.size():
		var place := i - (cards.size() - 1) * 0.5
		_card(cards[i], Vector2(mid + place * 126.0, PIC.position.y + 104.0 + absf(place) * 6.0), 1.15, place * 4.0)
		chips += int(cards[i].chips)
		sum += " + %d" % cards[i].chips
	var y := PIC.position.y + 222.0
	var column := Vector2(PIC.position.x, 0.0)
	_say(hand.name, column + Vector2(0.0, y), 24, _light_colour(), true, HORIZONTAL_ALIGNMENT_CENTER, PIC.size.x)
	_say("%s = %d chips" % [sum, chips], column + Vector2(0.0, y + 44.0), WORD_SIZE, Palette.CHALK, false,
			HORIZONTAL_ALIGNMENT_CENTER, PIC.size.x)
	_say("%d chips × %d mult = %s" % [chips, hand.mult, ArenaMomentRound.thousands(chips * int(hand.mult))],
			column + Vector2(0.0, y + 76.0), WORD_SIZE, Palette.CHALK, true, HORIZONTAL_ALIGNMENT_CENTER, PIC.size.x)
	_say("The first round's target is %s." % ArenaMomentRound.thousands(int(RulesConfig.targets(_dials, 0)[0])),
			column + Vector2(0.0, y + 124.0), NOTE_SIZE, Palette.CHALK_2, false, HORIZONTAL_ALIGNMENT_CENTER, PIC.size.x)


# Two men: a Paper Root and its Ink twin, what hands the table from one man to the other, and
# the restraint part filled.
func _build_men() -> void:
	var sym: String = RulesConfig.ROOTS[0]
	var left := PIC.position.x + 84.0
	var right := PIC.end.x - 84.0
	var top := PIC.position.y + 30.0
	var men := [["Jekyll", "Paper Roots", left, false], ["Hyde", "Ink Roots", right, true]]
	for man: Array in men:
		var x: float = man[2]
		_card(HelpPages.root(sym, man[3], _dials), Vector2(x, top + 70.0))
		_say(man[0], Vector2(x - 84.0, top + 150.0), 20, TONES[man[3]].light, true, HORIZONTAL_ALIGNMENT_CENTER, 168.0)
		_say(man[1], Vector2(x - 84.0, top + 178.0), NOTE_SIZE, Palette.CHALK, false, HORIZONTAL_ALIGNMENT_CENTER, 168.0)
	# Between them, who the table goes to: the draught one way, salt the other.
	var from := left + 66.0
	var to := right - 66.0
	_say("the draught", Vector2(from, top + 22.0), NOTE_SIZE, Palette.HYDE, false, HORIZONTAL_ALIGNMENT_CENTER, to - from)
	_arrow(Vector2(from + 6.0, top + 54.0), Vector2(to - 6.0, top + 54.0), Palette.HYDE)
	_arrow(Vector2(to - 6.0, top + 92.0), Vector2(from + 6.0, top + 92.0), Palette.SALT)
	_say("salt", Vector2(from, top + 100.0), NOTE_SIZE, Palette.SALT, false, HORIZONTAL_ALIGNMENT_CENTER, to - from)
	# The restraint, as the table shows it.
	var zoom := 1.4
	var zone := ArenaLayout.restraint(TABLE_PAGE)
	var restraint := ArenaRestraint.new()
	restraint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restraint.limit = _dials.restraint_limit
	restraint.meter = mini(SAMPLE_RESTRAINT, restraint.limit - 1)
	restraint.size = zone.size
	restraint.scale = Vector2(zoom, zoom)
	# Its steps are what is centred: the first lies a step's width in from its left edge.
	var steps := ArenaRestraint.PITCH * (restraint.limit + 1) * zoom
	restraint.position = Vector2(PIC.position.x + (PIC.size.x - steps) * 0.5, top + 252.0)
	_picture.add_child(restraint)
	restraint.snap()


# The table of hands: each pattern of Roots, and the hand each man makes of it with its
# chips and mult. The column of the man at the table is lit.
func _build_hands() -> void:
	var x := PIC.position.x
	var columns := {"jekyll": x + 190.0, "hyde": x + 324.0}
	var column_w := 124.0
	# A hand's name wraps in its column; a row whose names take two lines sets its numbers lower.
	var name_w := column_w - 10.0
	var name_size := 15
	var top := PIC.position.y
	var pitch := 64.0
	_rects.append({"rect": Rect2(columns[_stance()] - 8.0, top - 6.0, column_w, 32.0 + pitch * RulesConfig.ROWS.size()),
			"colour": Color(_light_colour(), 0.09)})
	_say("Roots in the play", Vector2(x, top + 2.0), NOTE_SIZE, Palette.CHALK_2)
	_say("Jekyll", Vector2(columns.jekyll, top), 18, Palette.JEKYLL, true)
	_say("Hyde", Vector2(columns.hyde, top), 18, Palette.HYDE, true)
	var y := top + 32.0
	for row: Dictionary in RulesConfig.ROWS:
		_rects.append({"rect": Rect2(x, y - 4.0, PIC.size.x, 1.0), "colour": Color(Palette.RULE, 0.8)})
		var marks: Array = HelpPages.PATTERNS[row.key]
		for i in marks.size():
			var mark: String = marks[i]
			var ink := mark.ends_with("*")
			_card_picture(ArenaCardPictures.picture_of(mark.trim_suffix("*"), ink),
					Rect2(x + i * 36.0, y - 1.0, 32.0, 32.0), Palette.HYDE if ink else Palette.CHALK)
		_say(row.label, Vector2(x, y + 33.0), NOTE_SIZE, Palette.CHALK)
		var wraps := false
		for stance: String in columns:
			if String(row[stance]) != "":
				var named: String = RulesConfig.HANDS[stance][row[stance]].name
				wraps = wraps or _heavy.get_string_size(named, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x > name_w
		for stance: String in columns:
			var at := Vector2(columns[stance], y + (-2.0 if wraps else 3.0))
			if String(row[stance]) == "":
				_say("none", at, NOTE_SIZE, Palette.CHALK_3)
				continue
			var hand: Dictionary = RulesConfig.HANDS[stance][row[stance]]
			_say(hand.name, at, name_size, Palette.JEKYLL if stance == "jekyll" else Palette.HYDE, true,
					HORIZONTAL_ALIGNMENT_LEFT, name_w)
			_say("%d × %d" % [hand.chips, hand.mult], at + Vector2(0.0, 39.0 if wraps else 24.0), NOTE_SIZE,
					Palette.CHALK)
		y += pitch
	_say("Each hand gives chips × mult.", Vector2(x, y + 2.0), NOTE_SIZE, Palette.CHALK_2)


# The gauges as the table draws them, with each of a gauge's three counts named.
func _build_gauges() -> void:
	var zoom := 1.6
	var grow := Vector2(8.0, 8.0)
	var zone := ArenaLayout.symbols(TABLE_PAGE)
	var at := PIC.position + Vector2(0.0, 116.0)
	var part := _symbols(SAMPLE_GAUGES, 0, 0)
	_zoomed(part, zone, grow, zoom, at)
	# Over the first gauge, the names of its counts, each joined to its marks.
	var first: String = RulesConfig.ROOTS[0]
	var to_sheet := _sheet.get_global_transform().affine_inverse()
	var habit := to_sheet * part.pay_place(first, "habit")
	var temper := to_sheet * part.pay_place(first, "temper")
	# The pips lie between the symbol's sketch and the bar before Temper.
	var craving := Vector2(temper.x - 37.0 * zoom, temper.y)
	var gauge_top := at.y + grow.y * zoom - 2.0
	var names := [["Habit", habit.x, 44.0, ArenaSymbols.HABIT], ["Craving", craving.x, 78.0, ArenaSymbols.INK],
			["Temper", temper.x, 44.0, ArenaSymbols.TEMPER]]
	for count: Array in names:
		var x: float = count[1]
		var label_top: float = gauge_top - float(count[2])
		_say(count[0], Vector2(x - 60.0, label_top), 18, count[3], true, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		_stroke(PackedVector2Array([Vector2(x, label_top + 26.0), Vector2(x, gauge_top)]), count[3], 1.6)
	# Beside each gauge, its symbol's name.
	var names_x := at.x + (grow.x + 172.0) * zoom
	for i in RulesConfig.ROOTS.size():
		var middle := at.y + (grow.y + ArenaSymbols.GAUGE_H * 0.5 + i * ArenaSymbols.GAUGE_STEP) * zoom
		_say(RulesConfig.ROOT[RulesConfig.ROOTS[i]].label, Vector2(names_x, middle - 12.0), 18, Palette.CHALK, true)
	_say("One gauge for each symbol, for the Roots of that symbol. What a count pays, it pays for each of its marks.",
			Vector2(PIC.position.x, at.y + (zone.size.y + grow.y * 2.0) * zoom + 22.0), NOTE_SIZE, Palette.CHALK_2,
			false, HORIZONTAL_ALIGNMENT_LEFT, PIC.size.x)


# The line as the table draws it, holding and with Ink ahead, and the night's road to dawn.
func _build_line() -> void:
	var zoom := 1.24
	var grow := Vector2(0.5, 6.0)
	var zone := ArenaLayout.balance(TABLE_PAGE)
	var paper := 0
	for key: String in RulesConfig.STARTING_DECK:
		if RulesConfig.ROOT.has(key):
			paper += 1
	var ink := RulesConfig.FIRST_ARRIVAL.size()
	var lines := [
		["Paper ahead: the line holds.", paper, ink, Palette.CHALK],
		["Ink ahead when a round ends: the run is lost.", paper - SAMPLE_BEHIND.x, ink + SAMPLE_BEHIND.y, Palette.HYDE],
	]
	var y := PIC.position.y + 8.0
	for line: Array in lines:
		_say(line[0], Vector2(PIC.position.x, y), NOTE_SIZE, line[3])
		_zoomed(_symbols({}, line[1], line[2]), zone, grow, zoom, Vector2(PIC.position.x, y + 28.0))
		y += 28.0 + (zone.size.y + grow.y * 2.0) * zoom + 28.0
	# The night's road, as the table's heading has it.
	y += 16.0
	_say("A night: rounds 1 and 2, the scene, and dawn in the place of the man at the table.",
			Vector2(PIC.position.x, y), NOTE_SIZE, Palette.CHALK, false, HORIZONTAL_ALIGNMENT_LEFT, PIC.size.x)
	var road_zoom := 1.6
	var road_grow := Vector2(10.0, 8.0)
	var road := ArenaRoad.new()
	_zoomed(road, ArenaLayout.road(TABLE_PAGE), road_grow, road_zoom, Vector2(PIC.position.x, y + 56.0))
	road.show_night({"round": 1, "scene": false, "twist": "", "dawn": {"ends": false}}, not _hyde)
