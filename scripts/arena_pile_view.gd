class_name ArenaPileView
extends Control
## The view of the two piles, opened by a click on either: the draw pile's cards in a section
## at the left and the discards' at the right, as the piles lie on the table, with a rule
## between them. Each section has its heading and count; the one that was clicked is lit, and
## the arrow keys and Page Up and Down scroll it (Left and Right light the other).
##
## The draw pile's cards are shuffled anew each time the view opens: its own order is never
## shown. The discards lie newest first.
##
## Every card is CARD_SCALE of its size. A section that does not fit scrolls by itself: the
## wheel or a trackpad over it, a drag on it, or the keys. A slim bar at its edge shows where
## it stands, and its cards fade at an edge where more lie beyond. Scrolling eases and stops
## firmly at both ends.
##
## Coming in, the shade falls and each section's cards fly out of their own pile to their
## places, face up; going out, they fly back. Only the cards in view fly. With
## ArenaPace.reduce_flashes on, the view fades in and out instead.
##
## The view reads the run and the table; it decides nothing. Open it with `open`, close it
## with `close`; `closed` is emitted when it begins to go.

signal closed

## The size of a card in the view, of its full size.
const CARD_SCALE := 0.85
## The room between two cards, across and down.
const GAP := Vector2(9.0, 12.0)
## The time the shade takes to fall, and to lift again.
const SHADE_IN := 0.15
const SHADE_OUT := 0.2
## One card's flight out of its pile, the gap between two cards setting off, and the longest
## the lot of them may take.
const FLY_IN := 0.26
const FLY_STAGGER := 0.02
const FLY_ALL := 0.45
const FLY_OUT := 0.2
## How far a notch of the wheel, an arrow key and a trackpad's unit scroll.
const WHEEL_STEP := 64.0
const KEY_STEP := 72.0
const PAN_STEP := 24.0
## How deep the fade is at an edge where more cards lie beyond.
const FADE := 56.0
## How fast the scroll catches up with where it is sent (per second, the larger the quicker).
const EASE := 16.0
## A press that moves less than this is a click, not a drag.
const DRAG_SLOP := 6.0
## The keys that scroll the view, and so do not close it.
const SCROLL_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN,
		KEY_HOME, KEY_END]

const CREAM := Palette.CHALK
const DIM := Palette.CHALK_3

var t: ArenaTable

var _shade := ColorRect.new()
## Headings, rule and close mark: they come and go with the shade.
var _chrome := Control.new()
var _rule := ColorRect.new()
var _close_mark := Button.new()
var _flight := Control.new()
var _sections: Array[_Section] = []
var _active := 0
var _going := false
var _tween: Tween
var _press_at := Vector2.ZERO
var _pressed := false
var _dragging := false
var _drag_section: _Section


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.5
	_shade.color = Color(Palette.NIGHT_1, 0.93)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.color = Color(Palette.RULE, 0.9)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_mark.text = "×"
	_close_mark.focus_mode = Control.FOCUS_NONE
	_close_mark.tooltip_text = "Close (Esc)"
	_close_mark.add_theme_font_override("font", font)
	_close_mark.add_theme_font_size_override("font_size", 26)
	_close_mark.add_theme_color_override("font_color", Palette.CHALK_2)
	_close_mark.add_theme_color_override("font_hover_color", CREAM)
	_close_mark.add_theme_color_override("font_pressed_color", CREAM)
	_close_mark.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.9))
	_close_mark.add_theme_constant_override("outline_size", 5)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_close_mark.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_close_mark.pressed.connect(close)
	_flight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	add_child(_chrome)
	_chrome.add_child(_rule)
	for which: String in ["draw", "discards"]:
		var section := _Section.new(which, font)
		_sections.append(section)
		add_child(section)
		_chrome.add_child(section.heading)
		_chrome.add_child(section.empty_words)
	add_child(_flight)
	add_child(_close_mark)
	resized.connect(_lay_out)


## True from the moment the view opens until it has gone.
func is_open() -> bool:
	return visible


## Opens the view on both piles, the section of `which` ("draw" or "discards") lit.
func open(which: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_going = false
	_clear_flight()
	_active = 1 if which == "discards" else 0
	var run := t.run
	# Shuffled anew each time it is looked at: the pile's own order is never shown. The
	# shuffle is the view's, not the run's.
	var draw: Array = run.draw.duplicate()
	draw.shuffle()
	# The engine adds each discard at the end of its list: newest first is that list reversed.
	var discards: Array = run.discard.duplicate()
	discards.reverse()
	_sections[0].fill(draw, t)
	_sections[1].fill(discards, t)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_lay_out()
	_light()
	Sfx.play("riffle", 1.15, 0.8) # the piles fanned out
	_tween = create_tween().set_parallel()
	if ArenaPace.reduce_flashes:
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, SHADE_IN)
		return
	modulate.a = 1.0
	_shade.modulate.a = 0.0
	_chrome.modulate.a = 0.0
	_tween.tween_property(_shade, "modulate:a", 1.0, SHADE_IN)
	_tween.tween_property(_chrome, "modulate:a", 1.0, SHADE_IN)
	# Only the cards that will be in view fly; the rest are in place when scrolled to.
	var flying: Array = []
	for section in _sections:
		for card in section.cards_in_view():
			flying.append([section, card])
	var gap := FLY_STAGGER
	if flying.size() > 1:
		gap = minf(FLY_STAGGER, (FLY_ALL - FLY_IN) / (flying.size() - 1))
	# The two piles give out their cards at once, each its own in turn.
	var nth := [0, 0]
	for pair: Array in flying:
		var section: _Section = pair[0]
		var card: ArenaCard = pair[1]
		var i: int = nth[section.index]
		nth[section.index] += 1
		_fly_in(section, card, i * gap)


## Closes the view: the cards fly back to their piles and the shade lifts.
func close() -> void:
	if not visible or _going:
		return
	_going = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pressed = false
	_dragging = false
	Sfx.play("riffle", 0.9, 0.5)
	closed.emit()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel()
	if ArenaPace.reduce_flashes:
		_tween.tween_property(self, "modulate:a", 0.0, SHADE_IN)
	else:
		_tween.tween_property(_shade, "modulate:a", 0.0, SHADE_OUT)
		_tween.tween_property(_chrome, "modulate:a", 0.0, SHADE_OUT * 0.6)
		for section in _sections:
			var home := _pile_centre(section.which)
			for card in section.cards_in_view():
				var at := card.get_global_transform() * card.pivot_offset
				var alpha := card.modulate.a
				card.get_parent().remove_child(card)
				_flight.add_child(card)
				card.position = _local(at) - card.pivot_offset
				card.modulate.a = alpha
				_tween.tween_property(card, "position", home - card.pivot_offset, FLY_OUT) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_tween.tween_property(card, "scale", Vector2.ONE * ArenaPile.SCALE, FLY_OUT)
				if section.which == "draw":
					# Face down again as it goes into the stack.
					_tween.tween_callback(func() -> void: card.face_down = true).set_delay(FLY_OUT * 0.5)
			section.body.visible = false
	_tween.chain().tween_callback(_gone)


## Takes a key while the view is open: true if it scrolls the view (and so must not close it).
func scroll_key(key: InputEventKey) -> bool:
	if not key.keycode in SCROLL_KEYS:
		return false
	if not key.pressed or _going:
		return true
	var section := _sections[_active]
	match key.keycode:
		KEY_UP:
			section.scroll_by(-KEY_STEP)
		KEY_DOWN:
			section.scroll_by(KEY_STEP)
		KEY_PAGEUP:
			section.scroll_by(-section.size.y * 0.85)
		KEY_PAGEDOWN:
			section.scroll_by(section.size.y * 0.85)
		KEY_HOME:
			section.scroll_by(-INF)
		KEY_END:
			section.scroll_by(INF)
		KEY_LEFT, KEY_RIGHT:
			var next := 0 if key.keycode == KEY_LEFT else 1
			if next != _active:
				_active = next
				_light()
				Sfx.play("hover_j", Sfx.vary(), 0.3)
	return true


func _gui_input(event: InputEvent) -> void:
	if _going:
		return
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var pan := event as InputEventPanGesture
	if button:
		accept_event()
		var under := _section_at(button.position)
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if under and button.pressed:
				var notch := button.factor if button.factor > 0.0 else 1.0
				under.scroll_by(WHEEL_STEP * notch * (-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
			return
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_pressed = true
			_dragging = false
			_press_at = button.position
			_drag_section = under
		elif _pressed:
			_pressed = false
			if _dragging:
				_dragging = false
				if _drag_section:
					_drag_section.drag_end()
			else:
				# A click, not a drag: anywhere on the view, as on the shade, closes it.
				close()
	elif motion and _pressed:
		accept_event()
		if not _dragging and motion.position.distance_to(_press_at) >= DRAG_SLOP:
			_dragging = true
		if _dragging and _drag_section:
			_drag_section.drag_by(-motion.relative.y)
	elif pan:
		accept_event()
		var under := _section_at(pan.position)
		if under:
			under.scroll_by(pan.delta.y * PAN_STEP)


func _section_at(point: Vector2) -> _Section:
	for section in _sections:
		if section.get_rect().has_point(point):
			return section
	return null


func _fly_in(section: _Section, card: ArenaCard, delay: float) -> void:
	var place := card.position
	card.get_parent().remove_child(card)
	_flight.add_child(card)
	var from := _pile_centre(section.which)
	var to := _local(section.body.get_global_transform() * (place + card.pivot_offset))
	card.position = from - card.pivot_offset
	card.scale = Vector2.ONE * ArenaPile.SCALE
	card.modulate.a = 0.0 if delay > 0.0 else 1.0
	# Out of the draw pile it comes face down, and turns over on the way.
	card.face_down = section.which == "draw"
	var go := create_tween().set_parallel()
	if delay > 0.0:
		go.tween_interval(delay)
		go.chain()
	go.tween_callback(func() -> void: card.modulate.a = 1.0)
	go.tween_property(card, "position", to - card.pivot_offset, FLY_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	go.tween_property(card, "scale", Vector2.ONE * CARD_SCALE, FLY_IN)
	go.tween_callback(func() -> void: card.face_down = false).set_delay(FLY_IN * 0.4)
	go.chain().tween_callback(func() -> void:
		if _going or not is_instance_valid(card) or card.get_parent() != _flight:
			return
		_flight.remove_child(card)
		section.body.add_child(card)
		card.position = place)


func _gone() -> void:
	visible = false
	_going = false
	modulate.a = 1.0
	_clear_flight()
	for section in _sections:
		section.empty()


func _clear_flight() -> void:
	for child in _flight.get_children():
		child.queue_free()


## The centre of a pile's top, in this view's coordinates.
func _pile_centre(which: String) -> Vector2:
	return _local(t.piles.pile(which).top_centre())


func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _light() -> void:
	for section in _sections:
		section.lit = section.index == _active


# Two halves of the page, the draw pile's at the left; the headings over them, the rule
# between, and the close mark at the top right.
func _lay_out() -> void:
	var margin := ArenaLayout.MARGIN
	var width := minf(size.x, ArenaLayout.FRAME_MAX) - margin * 2.0
	var left := (size.x - width) * 0.5
	var between := 48.0
	var half := (width - between) * 0.5
	var top := 64.0
	var foot := size.y - 28.0
	for section in _sections:
		var x := left + section.index * (half + between)
		section.heading.position = Vector2(x, top - 38.0)
		section.heading.size = Vector2(half, 26.0)
		section.position = Vector2(x, top)
		section.size = Vector2(half, maxf(80.0, foot - top))
		section.empty_words.position = section.position + Vector2(0.0, 40.0)
		section.empty_words.size = Vector2(half, 26.0)
		section.lay_out()
	_rule.position = Vector2(left + half + between * 0.5 - 1.0, top - 34.0)
	_rule.size = Vector2(2.0, foot - top + 34.0)
	_close_mark.size = Vector2(40.0, 40.0)
	_close_mark.position = Vector2(size.x - margin * 0.5 - 40.0, 10.0)


func _process(delta: float) -> void:
	if not visible:
		return
	for section in _sections:
		section.ease_scroll(delta)


## One pile's section: its heading, the clipped room its cards lie in, their scroll and bar.
class _Section extends Control:
	var which := ""
	var index := 0
	var heading := Label.new()
	var empty_words := Label.new()
	var body := Control.new()
	## Over the cards: the fades at the edges and the bar.
	var veil := Control.new()
	var lit := false:
		set(value):
			lit = value
			heading.add_theme_color_override("font_color", CREAM if value else DIM)
			veil.queue_redraw()
	var _entries: Array = []
	var _hyde := false
	var _scroll := 0.0
	var _target := 0.0
	var _content := 0.0

	func _init(pile: String, font: Font) -> void:
		which = pile
		index = 1 if pile == "discards" else 0
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(body)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.draw.connect(_draw_veil)
		add_child(veil)
		for label: Label in [heading, empty_words]:
			label.add_theme_font_override("font", font)
			label.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.9))
			label.add_theme_constant_override("outline_size", 6)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_font_size_override("font_size", 17)
		empty_words.add_theme_font_size_override("font_size", 15)
		empty_words.add_theme_color_override("font_color", DIM)

	## Lays out the cards `ids`, in that order, at the top.
	func fill(ids: Array, table: ArenaTable) -> void:
		empty()
		_hyde = table.hyde()
		_entries = []
		for id: int in ids:
			_entries.append(table.entry(id))
		for entry: Dictionary in _entries:
			var card := ArenaCard.new()
			card.show_entry(entry, _hyde)
			card.scale = Vector2.ONE * CARD_SCALE
			body.add_child(card)
		var n := _entries.size()
		var plural := "" if n == 1 else "s"
		if which == "draw":
			heading.text = "Draw pile, %d card%s, in no order" % [n, plural]
			empty_words.text = "The draw pile is empty."
		else:
			heading.text = "Discards, %d card%s" % [n, plural]
			empty_words.text = "Nothing has been discarded yet."
		empty_words.visible = n == 0
		body.visible = true
		_scroll = 0.0
		_target = 0.0

	func empty() -> void:
		for card in body.get_children():
			body.remove_child(card)
			card.queue_free()

	## Places the cards in rows, centred, the bar's room kept at the right.
	func lay_out() -> void:
		var card := ArenaCard.SIZE * CARD_SCALE
		var pitch := card + GAP
		var room := size.x - 14.0
		var a_row := maxi(1, int((room + GAP.x) / pitch.x))
		var cards := body.get_children()
		var in_first := mini(a_row, cards.size())
		var left := (room - (in_first * pitch.x - GAP.x)) * 0.5
		for i in cards.size():
			var c := cards[i] as ArenaCard
			@warning_ignore("integer_division")
			var row := i / a_row
			var centre := Vector2(left + (i % a_row) * pitch.x + card.x * 0.5, 10.0 + row * pitch.y + card.y * 0.5)
			c.position = centre - c.pivot_offset
		@warning_ignore("integer_division")
		var rows := (cards.size() + a_row - 1) / a_row
		_content = 10.0 + rows * pitch.y - GAP.y + 10.0
		_target = clampf(_target, 0.0, max_scroll())
		_scroll = clampf(_scroll, 0.0, max_scroll())
		veil.size = size
		_moved()

	func max_scroll() -> float:
		return maxf(0.0, _content - size.y)

	## The cards that lie, wholly or in part, in the section's room as it is scrolled now.
	func cards_in_view() -> Array[ArenaCard]:
		var out: Array[ArenaCard] = []
		var room := Rect2(Vector2(0.0, _scroll), size)
		for c in body.get_children():
			var card := c as ArenaCard
			if card and Rect2(card.position + card.pivot_offset * (1.0 - CARD_SCALE), ArenaCard.SIZE * CARD_SCALE).intersects(room):
				out.append(card)
		return out

	## Sends the scroll on by `amount` (INF and -INF to an end); it stops at both ends.
	func scroll_by(amount: float) -> void:
		_target = clampf(_target + amount, 0.0, max_scroll())

	func drag_by(amount: float) -> void:
		_target = clampf(_target + amount, 0.0, max_scroll())
		_scroll = _target
		_moved()

	func drag_end() -> void:
		pass

	func ease_scroll(delta: float) -> void:
		if is_equal_approx(_scroll, _target):
			return
		_scroll = lerpf(_scroll, _target, 1.0 - exp(-EASE * delta))
		if absf(_scroll - _target) < 0.5:
			_scroll = _target
		_moved()

	func _moved() -> void:
		body.position.y = -_scroll
		veil.queue_redraw()

	# A fade into the shade at an edge where more cards lie beyond it (stronger the more lies
	# there, up to FADE's worth), and the bar at the right edge when the section scrolls.
	func _draw_veil() -> void:
		var most := max_scroll()
		if most <= 0.0:
			return
		var shade := Palette.NIGHT_1
		var clear := Color(shade, 0.0)
		var top := clampf(_scroll / FADE, 0.0, 1.0)
		var foot := clampf((most - _scroll) / FADE, 0.0, 1.0)
		var w := size.x
		if top > 0.0:
			veil.draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, FADE), Vector2(0.0, FADE)]),
					PackedColorArray([Color(shade, top), Color(shade, top), clear, clear]))
		if foot > 0.0:
			var y := size.y
			veil.draw_polygon(PackedVector2Array([Vector2(0.0, y - FADE), Vector2(w, y - FADE), Vector2(w, y), Vector2(0.0, y)]),
					PackedColorArray([clear, clear, Color(shade, foot), Color(shade, foot)]))
		var track := Rect2(size.x - 5.0, 6.0, 3.0, size.y - 12.0)
		veil.draw_rect(track, Color(Palette.RULE, 0.5))
		var length := maxf(24.0, track.size.y * size.y / _content)
		var at := track.position.y + (track.size.y - length) * (_scroll / most)
		veil.draw_rect(Rect2(track.position.x, at, track.size.x, length), Color(CREAM if lit else Palette.CHALK_2, 0.85))
