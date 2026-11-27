class_name ShopDeckView
extends Control
## The deck laid open over a place's page: a shade over the whole window, a heading, and the
## deck's cards in a grid at the table's size. A grid that does not fit scrolls: the wheel or
## a trackpad, or the keys. ShopDeckStrip makes one and opens it; it covers the window
## whatever its parent's place is.
##
## To look at: Escape, Enter, Space, `close_key` or a click closes it; Up, Down, Page Up and
## Down, Home and End scroll.
##
## As a picker (`open` with `picker`): one card is lit and lifted, the arrow keys or the
## pointer move to another, and Enter, Space or a click on a card chooses it: the view closes
## and `card_picked` is sent with that card's dictionary. A card with `ok` false is dimmed
## and cannot be chosen; its `why` stands at the foot while it is lit. A `price` is written
## on the card's foot, after a coin. Escape, or a click beside the cards, closes the view with nothing
## chosen.
##
## While it is open the view takes every key and click, so the page under it does nothing.
## The cards come in one after another; with ArenaPace.reduce_flashes on, the view only fades.

## The view begins to go.
signal closed
## A card was chosen in the picker.
signal card_picked(card: Dictionary)

## The room between two cards, across and down.
const GAP := Vector2(12.0, 16.0)
## Where the cards' room begins under the heading, and the room kept for the foot's line.
const TOP := 96.0
const FOOT := 52.0
const MARGIN := 40.0
## The widest the grid gets, in cards.
const MOST_IN_A_ROW := 9
const SHADE_IN := 0.15
const SHADE_OUT := 0.15
## A card's coming in: its time, the gap between two, and the longest the lot may take to
## set off.
const CARD_IN := 0.2
const STAGGER := 0.018
const STAGGER_ALL := 0.3
## How far the lit card of a picker is lifted.
const LIFT := 8.0
const WHEEL_STEP := 64.0
const KEY_STEP := 80.0
const PAN_STEP := 24.0
## How fast the scroll catches up with where it is sent (per second).
const EASE := 16.0
## How deep the fade is at an edge where more cards lie beyond.
const FADE := 40.0

## A key that closes the view as Escape does: the key that opened it.
var close_key: Key = KEY_NONE

var _shade := ColorRect.new()
var _heading := Label.new()
var _lead := Label.new()
var _foot := Label.new()
var _room := Control.new()
var _body := Control.new()
var _veil := Control.new()
var _entries: Array = []
var _cards: Array[ArenaCard] = []
## Each card's place in the body, its top left corner, before any lift.
var _places: Array[Vector2] = []
var _picker := false
var _lead_words := ""
var _at := -1
var _a_row := 1
var _content := 0.0
var _scroll := 0.0
var _target := 0.0
var _going := false
var _tween: Tween
var _focus_before: Control


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = 100
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.6
	_shade.color = Color(Palette.NIGHT_1, 0.94)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_room.clip_contents = true
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(_draw_veil)
	add_child(_room)
	_room.add_child(_body)
	_room.add_child(_veil)
	for label: Label in [_heading, _lead, _foot]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.9))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_heading.add_theme_font_override("font", heavy)
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Palette.CHALK)
	_lead.add_theme_font_size_override("font_size", 15)
	_lead.add_theme_color_override("font_color", Palette.CHALK_2)
	_foot.add_theme_font_size_override("font_size", 15)
	_foot.add_theme_color_override("font_color", Palette.CHALK_2)
	set_process(false)
	set_process_input(false)


func _ready() -> void:
	get_viewport().size_changed.connect(_lay_out)


## True from the moment the view opens until it has gone.
func is_open() -> bool:
	return visible


## Opens the view on `cards`, each the data of a card's face ({id, t, key, ink, name, chips,
## text}, and for a picker any of `ok`, `why` and `price`). With `hyde_has_table` a Factor has
## Hyde's look. `heading` stands over the cards and `lead` under it.
func open(cards: Array, hyde_has_table: bool, picker: bool, heading: String, lead: String = "") -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_going = false
	_empty()
	_entries = cards
	_picker = picker
	_lead_words = lead
	_heading.text = heading
	_lead.text = lead
	for entry: Dictionary in cards:
		var card := ArenaCard.new()
		card.rng_seed = int(entry.get("id", 0)) * 7 + 3
		card.show_face(entry.get("key", ""), entry.get("ink", false) or (entry.get("t", "") == "factor" and hyde_has_table),
				entry.get("name", ""), int(entry.get("chips", 0)), entry.get("text", ""))
		if picker:
			var can := bool(entry.get("ok", true))
			card.dimmed = not can
			var price := int(entry.get("price", 0))
			if price > 0:
				# The number, with room before it for its coin.
				card.set_tag("     %d" % price, not can)
				var coin := Control.new()
				coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				coin.draw.connect(_draw_coin.bind(coin, card, not can))
				card.add_child(coin)
			elif not can:
				card.set_tag("not now", true)
		_body.add_child(card)
		_cards.append(card)
	_scroll = 0.0
	_target = 0.0
	_at = -1
	if picker:
		# The keys start on the first card that can be chosen, or on the first card.
		_at = 0 if not cards.is_empty() else -1
		for i in cards.size():
			if bool(cards[i].get("ok", true)):
				_at = i
				break
	_focus_before = get_viewport().gui_get_focus_owner()
	if _focus_before:
		_focus_before.release_focus()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(true)
	_lay_out()
	_show_lit()
	Sfx.play("riffle", 1.15, 0.8)
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, SHADE_IN)
	if ArenaPace.reduce_flashes:
		return
	var seen := _cards_in_view()
	var gap := STAGGER
	if seen.size() > 1:
		gap = minf(STAGGER, STAGGER_ALL / (seen.size() - 1))
	# Only the fade: a card's place is the picker's to change while it comes in.
	for n in seen.size():
		var card := _cards[seen[n]]
		card.modulate.a = 0.0
		_tween.tween_property(card, "modulate:a", 1.0, CARD_IN).set_delay(n * gap)


## Closes the view: it fades, and its cards are freed.
func close() -> void:
	if not visible or _going:
		return
	_going = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	Sfx.play("riffle", 0.9, 0.5)
	if _focus_before and is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, SHADE_OUT)
	_tween.tween_callback(_gone)


func _gone() -> void:
	visible = false
	_going = false
	set_process(false)
	_empty()


func _empty() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_places.clear()
	_entries = []


# ---------- input ----------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not visible or _going:
		return
	# Every key is the view's while it is open: the page under it hears none.
	get_viewport().set_input_as_handled()
	if not key.pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			if not key.echo:
				close()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if key.echo:
				return
			if _picker:
				_pick(_at)
			else:
				close()
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		KEY_UP:
			_step(-_a_row)
		KEY_DOWN:
			_step(_a_row)
		KEY_PAGEUP:
			_scroll_by(-_room.size.y * 0.85)
		KEY_PAGEDOWN:
			_scroll_by(_room.size.y * 0.85)
		KEY_HOME:
			_scroll_by(-INF)
		KEY_END:
			_scroll_by(INF)
		_:
			if close_key != KEY_NONE and key.keycode == close_key and not key.echo:
				close()


func _gui_input(event: InputEvent) -> void:
	if _going:
		return
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var pan := event as InputEventPanGesture
	if button:
		accept_event()
		if not button.pressed:
			return
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var notch := button.factor if button.factor > 0.0 else 1.0
				_scroll_by(WHEEL_STEP * notch * (-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
			MOUSE_BUTTON_LEFT:
				var under := _card_at(button.position)
				if _picker and under >= 0:
					_pick(under)
				else:
					close()
	elif motion:
		accept_event()
		if _picker:
			var under := _card_at(motion.position)
			if under >= 0 and under != _at:
				_at = under
				Sfx.play("hover_j", Sfx.vary(), 0.3)
				_show_lit()
	elif pan:
		accept_event()
		_scroll_by(pan.delta.y * PAN_STEP)


# Moves the picker's light by `by` cards, and keeps it in view; with nothing to choose, the
# keys up and down scroll.
func _step(by: int) -> void:
	if not _picker or _cards.is_empty():
		if absi(by) > 1 or by == _a_row or by == -_a_row:
			_scroll_by(KEY_STEP * signf(by))
		return
	var next := _at + by
	if next < 0 or next >= _cards.size():
		# Down from the last full row goes to the last card.
		if by > 1 and _at / _a_row < (_cards.size() - 1) / _a_row: # whole rows
			next = _cards.size() - 1
		else:
			return
	_at = next
	Sfx.play("hover_j", Sfx.vary(), 0.3)
	_show_lit()
	var top := _places[_at].y - 14.0
	var foot := _places[_at].y + ArenaCard.SIZE.y + 14.0
	if top < _target:
		_target = maxf(0.0, top)
	elif foot > _target + _room.size.y:
		_target = minf(_max_scroll(), foot - _room.size.y)


func _pick(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry: Dictionary = _entries[index]
	if not bool(entry.get("ok", true)):
		_at = index
		_show_lit()
		Sfx.play("refuse")
		return
	close()
	card_picked.emit(entry)


# The card whose face lies under `point` (in the view's coordinates), or -1.
func _card_at(point: Vector2) -> int:
	if not _room.get_rect().has_point(point):
		return -1
	var in_body := point - _room.position + Vector2(0.0, _scroll)
	for i in _places.size():
		if Rect2(_places[i], ArenaCard.SIZE).has_point(in_body):
			return i
	return -1


# ---------- the look ----------

# Lights and lifts the picker's card, and writes the foot's line for it.
func _show_lit() -> void:
	for i in _cards.size():
		var lit := _picker and i == _at
		_cards[i].chosen = lit
		_cards[i].position = _places[i] - Vector2(0.0, LIFT if lit else 0.0)
	_foot.add_theme_color_override("font_color", Palette.CHALK_2)
	if not _picker:
		_foot.text = "Nothing is in the deck." if _cards.is_empty() else "Escape or a click to close"
		return
	if _at < 0:
		_foot.text = "There is no card to choose.  Escape to go back"
		return
	var entry: Dictionary = _entries[_at]
	if not bool(entry.get("ok", true)):
		_foot.text = String(entry.get("why", "It cannot be chosen now."))
		_foot.add_theme_color_override("font_color", Palette.WARN)
		return
	var price := int(entry.get("price", 0))
	var cost := ""
	if price > 0:
		cost = " for %d sovereign%s" % [price, "" if price == 1 else "s"]
	_foot.text = "%s%s  ·  Enter or a click to choose, Escape to go back" % [entry.get("name", "This card"), cost]


# The coin before a price in a card's foot: at the left end of the tag's words, where the tag
# left room for it.
func _draw_coin(on: Control, card: ArenaCard, warns: bool) -> void:
	const R := 4.5
	var tag := card._tag
	var font_size := tag.get_theme_font_size("font_size")
	var width := ArenaCard._width(tag.text, card._plain, font_size)
	var c := tag.position + Vector2((tag.size.x - width) * 0.5 + R + 1.0, tag.size.y * 0.5)
	on.draw_circle(c, R, Palette.WARN if warns else Palette.GOLD, true, -1.0, true)
	on.draw_arc(c, R - 1.8, 0.0, TAU, 16, Color(Palette.OUTLINE, 0.55), 1.0, true)


func _lay_out() -> void:
	if not is_inside_tree():
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_shade.position = Vector2.ZERO
	_shade.size = size
	_heading.position = Vector2(MARGIN, 22.0)
	_heading.size = Vector2(size.x - MARGIN * 2.0, 30.0)
	_lead.position = Vector2(MARGIN, 54.0)
	_lead.size = Vector2(size.x - MARGIN * 2.0, 24.0)
	_foot.position = Vector2(MARGIN, size.y - FOOT + 10.0)
	_foot.size = Vector2(size.x - MARGIN * 2.0, 28.0)
	_room.position = Vector2(MARGIN, TOP)
	_room.size = Vector2(size.x - MARGIN * 2.0, maxf(80.0, size.y - TOP - FOOT))
	_veil.size = _room.size
	var pitch := ArenaCard.SIZE + GAP
	var width := _room.size.x - 14.0
	_a_row = clampi(int((width + GAP.x) / pitch.x), 1, MOST_IN_A_ROW)
	var n := _cards.size()
	@warning_ignore("integer_division")
	var rows := (n + _a_row - 1) / _a_row
	# The lit card's lift and rim need room over the first row.
	var head := 16.0
	_places.clear()
	for i in n:
		@warning_ignore("integer_division")
		var row := i / _a_row
		var in_row := mini(_a_row, n - row * _a_row)
		var left := (width - (in_row * pitch.x - GAP.x)) * 0.5
		_places.append(Vector2(left + (i % _a_row) * pitch.x, head + row * pitch.y))
		_cards[i].position = _places[i]
	_content = head + rows * pitch.y - GAP.y + 16.0 if n > 0 else 0.0
	_target = clampf(_target, 0.0, _max_scroll())
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_moved()
	if visible:
		_show_lit()


func _max_scroll() -> float:
	return maxf(0.0, _content - _room.size.y)


func _scroll_by(amount: float) -> void:
	_target = clampf(_target + amount, 0.0, _max_scroll())


# The indices of the cards that lie, wholly or in part, in the room as it is scrolled now.
func _cards_in_view() -> Array[int]:
	var out: Array[int] = []
	var seen := Rect2(Vector2(0.0, _scroll), _room.size)
	for i in _places.size():
		if Rect2(_places[i], ArenaCard.SIZE).intersects(seen):
			out.append(i)
	return out


func _process(delta: float) -> void:
	if is_equal_approx(_scroll, _target):
		return
	_scroll = lerpf(_scroll, _target, 1.0 - exp(-EASE * delta))
	if absf(_scroll - _target) < 0.5:
		_scroll = _target
	_moved()


func _moved() -> void:
	_body.position.y = -_scroll
	_veil.queue_redraw()


# A fade into the shade at an edge where more cards lie beyond it, and a bar at the right
# edge when the grid scrolls.
func _draw_veil() -> void:
	var most := _max_scroll()
	if most <= 0.0:
		return
	var shade := Palette.NIGHT_1
	var clear := Color(shade, 0.0)
	var top := clampf(_scroll / FADE, 0.0, 1.0)
	var foot := clampf((most - _scroll) / FADE, 0.0, 1.0)
	var w := _veil.size.x
	var h := _veil.size.y
	if top > 0.0:
		_veil.draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, FADE), Vector2(0.0, FADE)]),
				PackedColorArray([Color(shade, top), Color(shade, top), clear, clear]))
	if foot > 0.0:
		_veil.draw_polygon(PackedVector2Array([Vector2(0.0, h - FADE), Vector2(w, h - FADE), Vector2(w, h), Vector2(0.0, h)]),
				PackedColorArray([clear, clear, Color(shade, foot), Color(shade, foot)]))
	var track := Rect2(w - 5.0, 6.0, 3.0, h - 12.0)
	_veil.draw_rect(track, Color(Palette.RULE, 0.5))
	var length := maxf(24.0, track.size.y * h / _content)
	var at := track.position.y + (track.size.y - length) * (_scroll / most)
	_veil.draw_rect(Rect2(track.position.x, at, track.size.x, length), Color(Palette.CHALK, 0.85))
