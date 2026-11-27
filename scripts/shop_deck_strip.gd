class_name ShopDeckStrip
extends Control
## The deck as a place's page shows it: a strip with the deck's pile and its count ("Deck · 12
## cards"), then the Paper:Ink gauge: "Paper 8", one tick for each card, "4 Ink". A Paper Root's
## tick stands upright in chalk and an Ink Root's leans in Hyde's colour, so the two read apart
## without their colour; a card that is neither (a Factor) is a short faint tick between them.
##
## The strip counts nothing. Give it the counts with `set_counts` and the cards with
## `set_cards`, or both at once from the run with `show_run`, which reads the rules' own count
## (Rules.line_info) and the cards' faces (RulesView.entry).
##
## A click, Enter or Space while it has the focus, or `hot_key` from anywhere on the page,
## opens the deck: a ShopDeckView over the whole window, the cards laid in a grid. Escape or a
## click closes it. `open_picker` opens the same grid to choose a card from: a click on a
## card, or the arrow keys and Enter, closes the view and sends `card_picked` with that card's
## dictionary.
##
##   strip.show_run(run)
##   strip.card_picked.connect(_on_struck)
##   strip.open_picker(faces, "Strike a card", "It leaves the deck for good.")
##
## (`faces`: a RulesView.entry for each card, with the `price`, `ok` and `why` of its offer in
## `place.strike`, which has no face of its own.)
##
## The caller sets the strip's width; its height is HEIGHT. It takes the focus like any
## control, so a page's keys can move to it and away with the focus neighbours.

## The deck was opened, and closed again.
signal opened
signal closed
## A card was chosen in the picker: its dictionary, as it was given.
signal card_picked(card: Dictionary)

const HEIGHT := 44.0
## The least width the strip's writing and a few ticks need.
const LEAST_WIDTH := 330.0
const PAD := 10.0
const TEXT_SIZE := 15
## The pile's cards: how large they are drawn, and how many lie on it at the most.
const PILE_SCALE := 0.24
const PILE_CARDS := 3
const PILE_STEP := Vector2(2.5, -1.5)
## A tick: its height, the most room one takes, and its width as a part of that room.
const TICK_HEIGHT := 18.0
const TICK_PITCH := 11.0
const TICK_LEAST_PITCH := 3.0
const TICK_PART := 0.4
## How far an Ink Root's tick leans, as a part of its height.
const TICK_LEAN := 0.3
## How far the strip rises under the pointer or with the focus.
const LIFT := 2.0

## The key that opens the deck from anywhere on the page, and closes it again. KEY_NONE for
## none.
@export var hot_key: Key = KEY_D

var _paper := 0
var _ink := 0
var _others := 0
var _cards: Array = []
var _hyde := false
var _hover := false
var _pile: Array[ArenaCard] = []
var _view: ShopDeckView
var _heavy := FontVariation.new()
var _light := FontVariation.new()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(LEAST_WIDTH, HEIGHT)
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.6
	_light.base_font = ThemeDB.fallback_font
	_light.variation_embolden = 0.1
	for i in PILE_CARDS:
		var card := ArenaCard.new()
		card.rng_seed = 5 + i * 11
		card.face_down = true
		card.scale = Vector2.ONE * PILE_SCALE
		add_child(card)
		_pile.append(card)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_lay_out)
	focus_exited.connect(_lay_out)
	resized.connect(_lay_out)


func _ready() -> void:
	_set_tooltip()
	_lay_out()


## Sets what the strip shows: how many Paper Roots and Ink Roots the deck holds, and how many
## cards that are neither (Factors). The deck's count is the three together.
func set_counts(paper: int, ink: int, others: int = 0) -> void:
	_paper = maxi(0, paper)
	_ink = maxi(0, ink)
	_others = maxi(0, others)
	_lay_out()


## Sets the cards the opened deck shows, in this order: each the data of a card's face,
## {id, t, key, ink, name, chips, text} (RulesView.entry). With `hyde_has_table` a Factor
## has Hyde's look.
func set_cards(cards: Array, hyde_has_table: bool = false) -> void:
	_cards = cards
	_hyde = hyde_has_table


## Sets the counts and the cards from the run as it stands: the rules' own count of the two
## sides, and every card of the deck as the man at the table reads it.
func show_run(run: RulesRun) -> void:
	var line := Rules.line_info(run)
	var cards: Array = []
	for c: RulesCard in run.cards:
		cards.append(RulesView.entry(run, c, run.stance))
	set_cards(cards, run.stance == "hyde")
	set_counts(int(line.paper), int(line.ink), int(line.total) - int(line.paper) - int(line.ink))


## How many cards the strip says the deck holds.
func deck_count() -> int:
	return _paper + _ink + _others


## The middle of the pile on the strip, in the page's coordinates: where a card that joins
## the deck should travel to.
func pile_centre() -> Vector2:
	return get_global_transform() * _pile_middle()


## True from the moment the deck opens until it has gone.
func is_open() -> bool:
	return _view != null and _view.is_open()


## Opens the deck to look at.
func open() -> void:
	_open_view(_cards, false, _deck_heading(), "")


## Opens the deck to choose a card from. `cards` are the cards to choose among (the strip's
## own when left empty): the data of a card's face, and any of `ok` (false for a card that
## cannot be chosen: it is dimmed), `why` (the reason, shown while it is pointed at) and
## `price` (written on the card's foot). `heading` and `lead` say what the choice is for.
func open_picker(cards: Array = [], heading: String = "Choose a card", lead: String = "") -> void:
	_open_view(cards if not cards.is_empty() else _cards, true, heading, lead)


## Closes the deck if it is open.
func close() -> void:
	if _view != null:
		_view.close()


func _open_view(cards: Array, picker: bool, heading: String, lead: String) -> void:
	if not is_inside_tree():
		return
	if _view == null:
		_view = ShopDeckView.new()
		_view.close_key = hot_key
		add_child(_view)
		_view.closed.connect(_on_view_closed)
		_view.card_picked.connect(func(card: Dictionary) -> void: card_picked.emit(card))
	_view.open(cards, _hyde, picker, heading, lead)
	opened.emit()


func _on_view_closed() -> void:
	closed.emit()


func _deck_heading() -> String:
	var n := deck_count()
	var words := "Deck, %d card%s" % [n, "" if n == 1 else "s"]
	if n > 0:
		words += "  ·  Paper %d : %d Ink" % [_paper, _ink]
	return words


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		accept_event()
		open()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		open()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if hot_key == KEY_NONE or key == null or not key.pressed or key.echo or key.keycode != hot_key:
		return
	if is_open() or not is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	open()


func _on_hover(over: bool) -> void:
	_hover = over
	if over and not is_open():
		ShopKeys.hover(_hyde)
	_lay_out()


func _set_tooltip() -> void:
	tooltip_text = "See the deck" + (" (%s)" % OS.get_keycode_string(hot_key) if hot_key != KEY_NONE else "")


func _lit() -> bool:
	return _hover or has_focus()


func _rise() -> Vector2:
	return Vector2(0.0, -LIFT) if _lit() else Vector2.ZERO


func _pile_middle() -> Vector2:
	return Vector2(PAD + ArenaCard.SIZE.x * PILE_SCALE * 0.5, HEIGHT * 0.5 + 1.0)


# The pile's cards, as many as the deck's size asks for (none for an empty deck).
func _lay_out() -> void:
	var n := deck_count()
	var want := 0 if n == 0 else (1 if n < 4 else (2 if n < 9 else PILE_CARDS))
	for i in _pile.size():
		var card := _pile[i]
		card.visible = i < want
		card.position = _pile_middle() + _rise() + PILE_STEP * i - card.pivot_offset
	queue_redraw()


func _draw() -> void:
	var lit := _lit()
	var rise := _rise()
	var box := Rect2(rise, Vector2(size.x, HEIGHT))
	draw_rect(box, Color(Palette.NIGHT_1, 0.55 if lit else 0.35))
	if lit:
		# The ring: chalk over a dark line, so that it shows on either sheet.
		draw_rect(box.grow(1.0), Palette.OUTLINE, false, 4.0)
		draw_rect(box.grow(1.0), Palette.CHALK, false, 2.0)
	else:
		draw_rect(box.grow(-0.5), Color(Palette.CHALK_3, 0.7), false, 1.0)
	var n := deck_count()
	var pile_width := ArenaCard.SIZE.x * PILE_SCALE + PILE_STEP.x * (PILE_CARDS - 1)
	if n == 0:
		# An empty deck: a dashed outline where its pile would lie.
		var empty := Rect2(_pile_middle() + rise - ArenaCard.SIZE * PILE_SCALE * 0.5, ArenaCard.SIZE * PILE_SCALE)
		var corners := [empty.position, Vector2(empty.end.x, empty.position.y), empty.end,
				Vector2(empty.position.x, empty.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Palette.CHALK_3, 1.0, 3.0)
	var base := rise.y + HEIGHT * 0.5 + TEXT_SIZE * 0.36
	var x := PAD + pile_width + 9.0
	x = _write(x, base, "Deck", _heavy, Palette.CHALK)
	x = _write(x, base, " · %d card%s" % [n, "" if n == 1 else "s"], _light,
			Palette.CHALK if lit else Palette.CHALK_2)
	# The gauge, at the strip's right end: "Paper n", the ticks, "n Ink".
	var paper_words := "Paper %d" % _paper
	var ink_words := "%d Ink" % _ink
	var paper_width := _width(paper_words, _heavy)
	var ink_width := _width(ink_words, _heavy)
	var between := 8.0
	var room := size.x - PAD - ink_width - between * 2.0 - paper_width - (x + 14.0)
	var gaps := (1 if _paper > 0 and _others > 0 else 0) + (1 if _ink > 0 and _paper + _others > 0 else 0)
	var pitch := TICK_PITCH
	if n > 0:
		pitch = clampf(room / (n + gaps * 0.5), TICK_LEAST_PITCH, TICK_PITCH)
	var ticks_width := maxf(0.0, (n + gaps * 0.5) * pitch)
	var left := size.x - PAD - ink_width - between - ticks_width - between - paper_width
	# A rule between the count and the gauge.
	var rule_x := left - 10.0
	if rule_x > x + 2.0:
		draw_line(Vector2(rule_x, rise.y + 9.0), Vector2(rule_x, rise.y + HEIGHT - 9.0), Color(Palette.CHALK_3, 0.7), 1.0)
	var at := _write(left, base, paper_words, _heavy, Palette.CHALK if _paper > 0 else Palette.CHALK_3) + between
	var top := rise.y + (HEIGHT - TICK_HEIGHT) * 0.5
	var width := clampf(pitch * TICK_PART, 1.5, 4.0)
	for i in n:
		if (i == _paper and _paper > 0 and _others > 0) or (i == _paper + _others and _ink > 0 and i > 0):
			at += pitch * 0.5
		var mid := at + pitch * 0.5
		if i < _paper:
			draw_rect(Rect2(mid - width * 0.5, top, width, TICK_HEIGHT), Palette.CHALK)
		elif i < _paper + _others:
			draw_rect(Rect2(mid - width * 0.5, top + TICK_HEIGHT * 0.5 - 2.5, width, 5.0), Palette.CHALK_3)
		else:
			var lean := TICK_HEIGHT * TICK_LEAN * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(mid - width * 0.5 + lean, top), Vector2(mid + width * 0.5 + lean, top),
				Vector2(mid + width * 0.5 - lean, top + TICK_HEIGHT), Vector2(mid - width * 0.5 - lean, top + TICK_HEIGHT),
			]), Palette.HYDE)
		at += pitch
	_write(size.x - PAD - ink_width, base, ink_words, _heavy, Palette.HYDE if _ink > 0 else Palette.CHALK_3)


# Writes `words` from `x` on the baseline `y`, and returns where they end.
func _write(x: float, y: float, words: String, font: Font, colour: Color) -> float:
	draw_string_outline(font, Vector2(x, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, 4, Color(Palette.OUTLINE, 0.8))
	draw_string(font, Vector2(x, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, colour)
	return x + _width(words, font)


func _width(words: String, font: Font) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE).x
