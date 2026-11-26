class_name ArenaNotice
extends Control
## The notice: a sheet laid over the table that says what has just happened, and stays until
## the player acknowledges it. The table under it is shaded and takes no click, key or hover
## meanwhile.
##
## Add one ArenaNotice to the page, above the layer cards travel on; it fills the page and is
## hidden until asked. Then, from a beat that waits for the player (ArenaBeats.add_choice,
## which stops hurrying and skipping before it and lets input through):
##
##   beats.add_choice(func() -> void:
##       await notice.show_notice({
##           "title": "Hyde arrives",
##           "lines": ["His four Roots join your deck."],
##           "cards": [data, data, data, data],
##           "tone": "hyde",
##       }))
##
## `show_notice` returns when the notice has been dismissed and has left. (It is not named
## `show`: every Control has a `show()` already, which only makes it visible.) Every key of
## the dictionary may be left out:
##
## - `title` (String): one line at 26 px.
## - `lines` (Array of String): up to MOST_LINES lines at 17 px under it. Each may wrap.
## - `cards` (Array of Dictionary): up to MOST_CARDS cards in a row, each the data a travelling
##   card is made from (ArenaTravel.make_card, ArenaTable.card_data): {id, key, ink, name,
##   chips, text}. They are the notice's own copies, laid at CARD_SCALE.
## - `after` (Array of Dictionary): a second row of the same, for a 'before' (`cards`) and an
##   'after' with an arrow from one to the other. It lies beside the first row while both fit
##   the page, else under it, with both rows laid smaller if they must be.
## - `tone` (String): "hyde" (his ink and light, a blot of ink behind the cards), "jekyll"
##   (lamp light on clean paper) or "plain" (a margin note in pencil on cream; the default).
## - `at` (Rect2): a part of the page, in the page's coordinates (`node.get_global_rect()`).
##   It is left unshaded with a ring round it, the sheet moves aside so as not to cover it, and
##   a line runs from the sheet to the ring. Meant for a plain note; it works with any tone.
##
## While a notice is shown `showing` is true. After it, `centres` still holds where the middle
## of each card lay, in the page's coordinates (the `cards` first, then the `after`), for a
## card that is then to travel from there; `dismissed` is sent when it has left.
## `shown_cards()` gives the card nodes on the sheet while it is shown (the `cards` first, then
## the `after`), for a moment to play on; they are freed when it leaves.
##
## It comes in over IN seconds with the 'paper' sound. Presses do nothing until it has been
## drawn and for DEAF seconds after, so that a click which was hurrying the move before it
## cannot dismiss it, however long its first frame takes. `shown_for` is how long the last
## notice was there to be read. A left
## click anywhere (the button is there to say so), Space or Enter dismiss it; the look keys
## (ArenaBeats.LOOK_KEYS) and every other key do not. It leaves in OUT seconds.
##
## With ArenaPace.wait_for_me off it holds HOLD seconds and leaves by itself (a press still
## dismisses it sooner). With `pass_at_once` on, `show_notice` shows nothing and returns at
## once: the command line's bench sets it, so that a run with no player is not held.

## The notice has been dismissed and has left.
signal dismissed

## The sheet's width when its cards need no more, and the room inside its edge.
const WIDTH := 640.0
const PAD := 28.0
## The least room kept between the sheet and the page's edge.
const PAGE_MARGIN := 24.0
const TITLE_SIZE := 26
const LINE_SIZE := 17
const HINT_SIZE := 13
const MOST_LINES := 3
const MOST_CARDS := 5
## How large the cards are laid, the room between two of a row, and the room between the two
## rows: for the arrow when they lie side by side, and when one lies under the other.
const CARD_SCALE := ArenaStage.REWARD_SCALE
const CARD_GAP := 14.0
const ARROW_ROOM := 64.0
const ARROW_ROOM_UNDER := 30.0
## No card is laid smaller than this, however many there are.
const LEAST_SCALE := 0.6
const BUTTON := Vector2(168.0, 40.0)
## The times, in seconds: to come in, to leave, how long presses do nothing after it has first
## been drawn, and how long it holds when it leaves by itself.
const IN := 0.2
const OUT := 0.15
const DEAF := 0.35
const HOLD := 1.6
## How far under its place the sheet starts when it comes in, in pixels.
const RISE := 10.0
const SHADE := Color(Palette.NIGHT_1, 0.78)
## The ring round `at`: how far outside the rect it runs, and its width.
const RING_GROW := 8.0
const RING_WIDTH := 3.0
const DISMISS_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
## Each tone's colours: the sheet's fill and edge, the title, the lines, the hint under the
## button, the button's fill, edge and word, and the arrow between two rows of cards.
const TONES := {
	"hyde": {
		"fill": Palette.INK_DEEP, "edge": Palette.HYDE_DEEP, "title": Palette.HYDE,
		"words": Palette.CHALK, "faint": Palette.CHALK_2, "button": Palette.HYDE,
		"button_edge": Palette.HOT, "button_word": Palette.OUTLINE, "arrow": Palette.HYDE,
	},
	"jekyll": {
		"fill": Palette.PAGE_DARK, "edge": Palette.JEKYLL_DEEP, "title": Palette.JEKYLL,
		"words": Palette.CHALK, "faint": Palette.CHALK_2, "button": Palette.JEKYLL,
		"button_edge": Palette.HOT, "button_word": Palette.OUTLINE, "arrow": Palette.JEKYLL,
	},
	"plain": {
		"fill": Palette.CHALK, "edge": Palette.OUTLINE, "title": Palette.OUTLINE,
		"words": Palette.NIGHT_2, "faint": Palette.RULE, "button": Palette.NIGHT_3,
		"button_edge": Palette.CHALK_3, "button_word": Palette.CHALK, "arrow": Palette.NIGHT_3,
	},
}

## On: `show_notice` shows nothing and returns at once. For a run with no player (the bench).
static var pass_at_once := false

## True from the call of `show_notice` until the notice has left.
var showing := false
## Where the middle of each card of the last notice lay, in the page's coordinates.
var centres: Array[Vector2] = []
## How long the last notice was on the page, in seconds, from the frame after it was first
## drawn until it was dismissed: 0 while one is shown, and for one that was never drawn.
var shown_for := 0.0

var _what: Dictionary = {}
var _tone: Dictionary = TONES.plain
var _tone_name := "plain"
## The sheet's shadow, and the sheet inside it, which keeps the blot inside its edge.
var _holder := Control.new()
var _sheet := Control.new()
var _title := Label.new()
var _lines: Array[Label] = []
var _cards: Array[ArenaCard] = []
var _after: Array[ArenaCard] = []
var _button := Button.new()
var _hint := Label.new()
var _heavy := FontVariation.new()
var _light := FontVariation.new()
## Where the sheet lies at rest, on this layer, and the part of the page ringed (no area: none).
var _rest := Rect2()
var _ring := Rect2()
## The box the cards lie in, on the sheet, and the arrow from the first row to the second.
var _cards_box := Rect2()
var _arrow := PackedVector2Array()
## When the notice shown was first on the page, in ticks (ms): -1 until then. It is taken on
## the frame after the sheet's first drawing, when that frame, however long, is over.
var _began := -1
var _drawn := false
var _leaving := false
var _move: Tween
var _leave_alone: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.9
	_light.base_font = ThemeDB.fallback_font
	_light.variation_embolden = 0.4
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.draw.connect(_draw_shadow)
	add_child(_holder)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.clip_contents = true
	_sheet.draw.connect(_draw_sheet)
	_holder.add_child(_sheet)
	_title.add_theme_font_override("font", _heavy)
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_hint.text = "click or press Space"
	_hint.add_theme_font_override("font", _light)
	_hint.add_theme_font_size_override("font_size", HINT_SIZE)
	for label: Label in [_title, _hint]:
		_dress_label(label)
		_sheet.add_child(label)
	_button.text = "Continue"
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_override("font", _heavy)
	_button.add_theme_font_size_override("font_size", LINE_SIZE)
	_sheet.add_child(_button)


func _ready() -> void:
	resized.connect(_lay_out)
	set_process(false)


func _process(_delta: float) -> void:
	if _drawn:
		_began = Time.get_ticks_msec()
		set_process(false)


## Shows the notice `what` describes (see the top of this script) and returns when the player
## has dismissed it and it has left. Await it. Called while another notice is shown, it waits
## for that one first.
func show_notice(what: Dictionary) -> void:
	if pass_at_once:
		return
	while showing:
		await dismissed
	showing = true
	_leaving = false
	_what = what
	_build()
	_began = -1
	_drawn = false
	shown_for = 0.0
	set_process(true)
	_lay_out()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("paper")
	modulate.a = 0.0
	_holder.position = _rest.position + Vector2(0.0, RISE)
	_move = create_tween().set_parallel()
	_move.tween_property(self, "modulate:a", 1.0, IN)
	_move.tween_property(_holder, "position", _rest.position, IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not ArenaPace.wait_for_me:
		_leave_alone = create_tween()
		_leave_alone.tween_interval(HOLD)
		_leave_alone.tween_callback(dismiss)
	await dismissed


## Has the notice leave, as the player's press does. Nothing when none is shown.
func dismiss() -> void:
	if not showing or _leaving:
		return
	_leaving = true
	set_process(false)
	if _began >= 0:
		shown_for = (Time.get_ticks_msec() - _began) / 1000.0
	for tween: Tween in [_move, _leave_alone]:
		if tween and tween.is_valid():
			tween.kill()
	_move = create_tween()
	_move.tween_property(self, "modulate:a", 0.0, OUT)
	await _move.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear()
	showing = false
	dismissed.emit()


## The card nodes on the sheet while a notice is shown: the `cards` first, then the `after`.
## Empty when none is shown.
func shown_cards() -> Array[ArenaCard]:
	return _cards + _after


## The sheet's place on the page while a notice is shown, in the page's coordinates.
func sheet_rect() -> Rect2:
	return get_global_transform() * _rest


func _input(event: InputEvent) -> void:
	if not showing:
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var pressed := false
	if key:
		# A key let go is let through, so that what was held before the notice is not left held.
		if not key.pressed:
			return
		pressed = not key.echo and key.keycode in DISMISS_KEYS
	elif button:
		if not button.pressed:
			return
		pressed = button.button_index == MOUSE_BUTTON_LEFT
	elif touch:
		if not touch.pressed:
			return
		pressed = true
	else:
		return # the pointer may move: the button under it lights
	get_viewport().set_input_as_handled()
	if pressed and not _leaving and _began >= 0 and Time.get_ticks_msec() - _began >= int(DEAF * 1000.0):
		Sfx.play("button", 1.0, 0.7)
		dismiss()


# ---------- building ----------

func _build() -> void:
	_clear()
	_tone_name = _what.get("tone", "plain")
	if not TONES.has(_tone_name):
		push_warning("A notice has no tone '%s': it is shown plain." % _tone_name)
		_tone_name = "plain"
	_tone = TONES[_tone_name]
	_title.text = _what.get("title", "")
	_title.add_theme_color_override("font_color", _tone.title)
	_hint.add_theme_color_override("font_color", _tone.faint)
	var lines: Array = _what.get("lines", [])
	for text: String in lines.slice(0, MOST_LINES):
		var label := Label.new()
		label.text = text
		label.add_theme_font_override("font", _light)
		label.add_theme_font_size_override("font_size", LINE_SIZE)
		label.add_theme_color_override("font_color", _tone.words)
		_dress_label(label)
		_sheet.add_child(label)
		_lines.append(label)
	_cards = _make_cards(_what.get("cards", []))
	_after = _make_cards(_what.get("after", []))
	_dress_button()
	_ring = _what.get("at", Rect2())


func _make_cards(datas: Array) -> Array[ArenaCard]:
	var made: Array[ArenaCard] = []
	for data: Dictionary in datas.slice(0, MOST_CARDS):
		var card := ArenaTravel.make_card(data)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sheet.add_child(card)
		made.append(card)
	return made


func _clear() -> void:
	for label in _lines:
		label.queue_free()
	for card: ArenaCard in _cards + _after:
		card.queue_free()
	_lines.clear()
	_cards.clear()
	_after.clear()


func _dress_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _dress_button() -> void:
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		_button.add_theme_color_override(state, _tone.button_word)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _tone.button
		box.border_color = _tone.button_edge if state != "normal" else Color(_tone.button_edge, 0.0)
		box.set_border_width_all(2)
		_button.add_theme_stylebox_override(state, box)
	_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ---------- laying out ----------

# Places everything on the sheet from the top down, then the sheet on the page.
func _lay_out() -> void:
	if not showing:
		return
	var page := size
	var n := _cards.size()
	var m := _after.size()
	var widest := page.x - 2.0 * PAGE_MARGIN - 2.0 * PAD
	var card_scale := CARD_SCALE
	var beside := true
	if m > 0 and _row_width(n, card_scale) + ARROW_ROOM + _row_width(m, card_scale) > widest:
		beside = false
	# The cards' box, at this scale.
	var box := Vector2.ZERO
	if n + m > 0:
		if m == 0:
			box = Vector2(_row_width(n, card_scale), ArenaCard.SIZE.y * card_scale)
		elif beside:
			box = Vector2(_row_width(n, card_scale) + ARROW_ROOM + _row_width(m, card_scale), ArenaCard.SIZE.y * card_scale)
	var inner := clampf(maxf(WIDTH - 2.0 * PAD, box.x), 200.0, widest)
	# The writing's heights at that width.
	var title_height := _height(_title, _heavy, TITLE_SIZE, inner) if _title.text != "" else 0.0
	var line_heights: Array[float] = []
	var written := title_height
	for label in _lines:
		line_heights.append(_height(label, _light, LINE_SIZE, inner))
		written += line_heights[-1] + 4.0
	if not _lines.is_empty():
		written += 6.0
	var hint_height := _height(_hint, _light, HINT_SIZE, inner)
	var foot := BUTTON.y + 6.0 + hint_height
	if n + m > 0 and (m > 0 and not beside or box.x > widest):
		# Two rows, one under the other (or one row too wide): as large as the page leaves room for.
		var rows := 2 if m > 0 else 1
		var room := page.y - 2.0 * PAGE_MARGIN - 2.0 * PAD - written - foot - 36.0 - (rows - 1) * ARROW_ROOM_UNDER
		card_scale = minf(card_scale, room / (rows * ArenaCard.SIZE.y))
		while card_scale > LEAST_SCALE and _row_width(maxi(n, m), card_scale) > widest:
			card_scale -= 0.05
		card_scale = maxf(card_scale, LEAST_SCALE)
		box = Vector2(maxf(_row_width(n, card_scale), _row_width(m, card_scale)),
				rows * ArenaCard.SIZE.y * card_scale + (rows - 1) * ARROW_ROOM_UNDER)
		inner = clampf(maxf(inner, box.x), 200.0, widest)
	# From the top down.
	var width := inner + 2.0 * PAD
	var y := PAD
	_title.visible = _title.text != ""
	_title.position = Vector2(PAD, y)
	_title.size = Vector2(inner, title_height)
	y += title_height + (10.0 if title_height > 0.0 else 0.0)
	for i in _lines.size():
		_lines[i].position = Vector2(PAD, y)
		_lines[i].size = Vector2(inner, line_heights[i])
		y += line_heights[i] + 4.0
	_cards_box = Rect2()
	_arrow = PackedVector2Array()
	if n + m > 0:
		y += 14.0
		_cards_box = Rect2(Vector2((width - box.x) * 0.5, y), box)
		var extent := ArenaCard.SIZE * card_scale
		var first_width := _row_width(n, card_scale)
		var second_width := _row_width(m, card_scale)
		if m == 0 or beside:
			_lay_row(_cards, Vector2(_cards_box.position.x, y), card_scale)
			_lay_row(_after, Vector2(_cards_box.position.x + first_width + ARROW_ROOM, y), card_scale)
			if m > 0:
				var middle := Vector2(_cards_box.position.x + first_width + ARROW_ROOM * 0.5, y + extent.y * 0.5)
				_arrow = PackedVector2Array([middle - Vector2(16.0, 0.0), middle + Vector2(16.0, 0.0)])
		else:
			_lay_row(_cards, Vector2((width - first_width) * 0.5, y), card_scale)
			_lay_row(_after, Vector2((width - second_width) * 0.5, y + extent.y + ARROW_ROOM_UNDER), card_scale)
			var middle := Vector2(width * 0.5, y + extent.y + ARROW_ROOM_UNDER * 0.5)
			_arrow = PackedVector2Array([middle - Vector2(0.0, 9.0), middle + Vector2(0.0, 9.0)])
		y += box.y + 8.0
	y += 14.0
	_button.position = Vector2((width - BUTTON.x) * 0.5, y)
	_button.size = BUTTON
	y += BUTTON.y + 6.0
	_hint.position = Vector2(PAD, y)
	_hint.size = Vector2(inner, hint_height)
	y += hint_height + PAD - 8.0
	_rest = _place(Vector2(width, y))
	_holder.position = _rest.position
	_holder.size = _rest.size
	_sheet.position = Vector2.ZERO
	_sheet.size = _rest.size
	centres.clear()
	for card: ArenaCard in _cards + _after:
		centres.append(get_global_transform() * (_rest.position + card.position + card.pivot_offset))
	_holder.queue_redraw()
	_sheet.queue_redraw()
	queue_redraw()


func _row_width(count: int, card_scale: float) -> float:
	return count * ArenaCard.SIZE.x * card_scale + maxi(0, count - 1) * CARD_GAP


# Lays a row of cards from its top left corner.
func _lay_row(cards: Array[ArenaCard], from: Vector2, card_scale: float) -> void:
	var extent := ArenaCard.SIZE * card_scale
	for i in cards.size():
		var middle := from + Vector2(i * (extent.x + CARD_GAP) + extent.x * 0.5, extent.y * 0.5)
		cards[i].scale = Vector2(card_scale, card_scale)
		cards[i].position = middle - cards[i].pivot_offset


func _height(label: Label, font: Font, font_size: int, width: float) -> float:
	return ceilf(font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y)


# Where a sheet of this size lies: at the centre, or moved aside so as not to cover the ringed
# part of the page, on the side with the most room.
func _place(extent: Vector2) -> Rect2:
	var page := Rect2(Vector2.ZERO, size)
	var centred := Rect2((size - extent) * 0.5, extent)
	var ring := _ring_here()
	if not ring.has_area():
		return centred
	var keep_off := ring.grow(RING_GROW + 28.0)
	if not centred.intersects(keep_off):
		return centred
	var inside := page.grow(-PAGE_MARGIN)
	# Each way the sheet can go to clear the ring, and how far it then lies from the centre.
	var ways: Array[Rect2] = [
		Rect2(Vector2(centred.position.x, keep_off.end.y), extent),
		Rect2(Vector2(centred.position.x, keep_off.position.y - extent.y), extent),
		Rect2(Vector2(keep_off.end.x, centred.position.y), extent),
		Rect2(Vector2(keep_off.position.x - extent.x, centred.position.y), extent),
	]
	var best := centred
	var best_shift := INF
	for way in ways:
		if not inside.encloses(way):
			continue
		var shift := way.position.distance_to(centred.position)
		if shift < best_shift:
			best = way
			best_shift = shift
	return best


# The ringed part of the page on this layer, or a rect of no area.
func _ring_here() -> Rect2:
	if not _ring.has_area():
		return Rect2()
	return get_global_transform().affine_inverse() * _ring


# ---------- drawing ----------

# The shade over the table, open over the ringed part; the ring; the line from the sheet to it.
func _draw() -> void:
	_drawn = showing
	var ring := _ring_here()
	if not ring.has_area():
		draw_rect(Rect2(Vector2.ZERO, size), SHADE)
		return
	var open := ring.grow(RING_GROW)
	draw_rect(Rect2(0.0, 0.0, size.x, open.position.y), SHADE)
	draw_rect(Rect2(0.0, open.end.y, size.x, size.y - open.end.y), SHADE)
	draw_rect(Rect2(0.0, open.position.y, open.position.x, open.size.y), SHADE)
	draw_rect(Rect2(open.end.x, open.position.y, size.x - open.end.x, open.size.y), SHADE)
	# The line, from the sheet's edge to the ring's, each at the point nearest the other.
	var from := _nearest(_rest, open.get_center())
	var to := _nearest(open, from)
	from = _nearest(_rest, to)
	if from.distance_to(to) > 4.0:
		draw_line(from, to, Palette.OUTLINE, RING_WIDTH + 3.0, true)
		draw_line(from, to, _tone.fill, RING_WIDTH - 1.0, true)
		draw_circle(to, 5.0, Palette.OUTLINE, true, -1.0, true)
		draw_circle(to, 3.5, _tone.fill, true, -1.0, true)
	for pass_: Array in [[RING_WIDTH + 4.0, Palette.OUTLINE, 2.0], [RING_WIDTH, _tone.fill, 0.0]]:
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = pass_[1]
		box.set_border_width_all(int(pass_[0]))
		box.set_corner_radius_all(10)
		box.anti_aliasing = true
		draw_style_box(box, open.grow(pass_[2]))


# The point of `rect` nearest to `point`.
func _nearest(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))


func _draw_shadow() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.OUTLINE, 0.0)
	box.shadow_color = Color(Palette.OUTLINE, 0.55)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0.0, 5.0)
	box.set_corner_radius_all(4)
	_holder.draw_style_box(box, Rect2(Vector2.ZERO, _holder.size))


# The sheet: its paper, what its tone lays behind the cards, the arrow, and its edge on top.
func _draw_sheet() -> void:
	var rect := Rect2(Vector2.ZERO, _sheet.size)
	var paper := StyleBoxFlat.new()
	paper.bg_color = _tone.fill
	paper.set_corner_radius_all(4)
	_sheet.draw_style_box(paper, rect)
	match _tone_name:
		"hyde":
			_draw_blot(rect)
		"jekyll":
			_draw_lamp_light(rect)
	if _arrow.size() == 2:
		var way := (_arrow[1] - _arrow[0]).normalized()
		var side := Vector2(-way.y, way.x)
		for pass_: Array in [[7.0, Palette.OUTLINE, 3.0], [3.0, _tone.arrow, 0.0]]:
			var colour: Color = pass_[1]
			var grow: float = pass_[2]
			_sheet.draw_line(_arrow[0] - way * grow * 0.5, _arrow[1], colour, pass_[0], true)
			_sheet.draw_colored_polygon(PackedVector2Array([
				_arrow[1] + way * (10.0 + grow), _arrow[1] + side * (8.0 + grow) - way * grow * 0.4,
				_arrow[1] - side * (8.0 + grow) - way * grow * 0.4]), colour)
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = _tone.edge
	edge.set_border_width_all(2)
	edge.set_corner_radius_all(4)
	_sheet.draw_style_box(edge, rect)
	if _tone_name != "plain":
		# A hairline of the owner's light inside the edge.
		var hair := StyleBoxFlat.new()
		hair.draw_center = false
		hair.border_color = Color(_tone.title, 0.35)
		hair.set_border_width_all(1)
		hair.set_corner_radius_all(2)
		_sheet.draw_style_box(hair, rect.grow(-5.0))


# Hyde's: a blot of ink behind the cards (or behind the writing, without cards), with drops
# thrown off it, and his light low in it. The same notice always has the same blot.
func _draw_blot(rect: Rect2) -> void:
	var box := _cards_box if _cards_box.has_area() else Rect2(rect.size.x * 0.25, rect.size.y * 0.3, rect.size.x * 0.5, rect.size.y * 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_title.text) + _cards.size() * 31 + _after.size() * 7
	var middle := box.get_center()
	var reach := Vector2(box.size.x * 0.5 + 34.0, box.size.y * 0.5 + 6.0)
	# The body, then a deeper bloom inside it: each an oval with an uneven edge of small lobes.
	for layer: Array in [[Palette.INK_BODY, 1.0, 30], [Palette.INK_BLOOM, 0.7, 20]]:
		var colour: Color = layer[0]
		var share: float = layer[1]
		var oval := reach * share
		_sheet.draw_set_transform(middle, 0.0, Vector2(oval.x / oval.y, 1.0))
		_sheet.draw_circle(Vector2.ZERO, oval.y, colour, true, -1.0, true)
		_sheet.draw_set_transform(Vector2.ZERO)
		for i: int in layer[2]:
			var angle := (i + rng.randf_range(-0.4, 0.4)) * TAU / float(layer[2])
			var radius := rng.randf_range(9.0, 24.0) * share
			var at := middle + Vector2(cos(angle) * oval.x, sin(angle) * oval.y) * rng.randf_range(0.9, 1.0)
			_sheet.draw_circle(at, radius, colour, true, -1.0, true)
	# His light, low in the blot.
	for i in 6:
		_sheet.draw_set_transform(middle + Vector2(0.0, reach.y * 0.25), 0.0, Vector2(reach.x / reach.y, 1.0))
		_sheet.draw_circle(Vector2.ZERO, reach.y * (0.95 - i * 0.13), Color(Palette.HYDE, 0.035), true, -1.0, true)
	_sheet.draw_set_transform(Vector2.ZERO)
	# Drops thrown off it.
	for i in 14:
		var angle := rng.randf() * TAU
		var far := rng.randf_range(1.02, 1.3)
		var at := middle + Vector2(cos(angle) * reach.x * far, sin(angle) * reach.y * far)
		_sheet.draw_circle(at, rng.randf_range(2.0, 6.5), Palette.INK_BODY if i % 3 else Palette.INK_BLOOM, true, -1.0, true)


# Jekyll's: a lamp's light falling from over the cards onto clean paper.
func _draw_lamp_light(rect: Rect2) -> void:
	var box := _cards_box if _cards_box.has_area() else Rect2(rect.size.x * 0.25, rect.size.y * 0.3, rect.size.x * 0.5, rect.size.y * 0.3)
	var middle := Vector2(rect.size.x * 0.5, box.position.y + box.size.y * 0.4)
	var reach := Vector2(maxf(box.size.x * 0.5 + 90.0, rect.size.x * 0.42), box.size.y * 0.5 + 60.0)
	_sheet.draw_set_transform(middle, 0.0, Vector2(reach.x / reach.y, 1.0))
	for i in 40:
		_sheet.draw_circle(Vector2.ZERO, reach.y * (1.0 - i / 40.0), Color(Palette.JEKYLL, 0.007), true, -1.0, true)
	_sheet.draw_set_transform(Vector2.ZERO)
