class_name ShopWare
extends Control
## One slot of a place's shelf: a ware with its price under it. The ware is a card, drawn by
## the table's own ArenaCard at the table's size, an instrument as its emblem from the table
## (ArenaMeans), a dose of salt as its paper, or a service (a card struck through). The price
## is a number of sovereigns with a coin, "free", or for a service how many times it is left
## ("1×").
##
##   var ware := ShopWare.new()
##   ware.accent = Palette.JEKYLL
##   ware.show_card({key = "lamp", name = "Composure", chips = 15})
##   ware.set_price(3)
##   ware.set_state(ShopWare.State.TOO_DEAR, "It costs 3 sovereigns: you hold 1.")
##   ware.chosen.connect(_on_bought)
##
## What it shows: `show_card(data, seed)`, `show_instrument(key, name, detail)`,
## `show_salt(name, detail)` or `show_service(name, detail)`; then `set_price(sovereigns)`
## (0 is written "free") or `set_uses(times)`. `detail` is what the ware does, in a sentence.
##
## The slot is in one of four states (`set_state(state, why, word)`), each of which reads
## without colour:
##
## - AVAILABLE: full chalk, the price in gold.
## - TOO_DEAR: the ware dimmed, the price struck through and in the warning colour.
## - NOT_ALLOWED: the ware dimmed, a small barred ring on its corner.
## - BOUGHT: the slot left empty, a faint dashed outline with `word` ("sold", "taken")
##   where the price was. It takes neither the pointer nor the keys: if it had the focus it
##   lets it go, and the page says where the focus goes next (ShopKeys.keep_focus).
##
## `set_offer(offer, purse)` picks the state from one offer of RulesView.place.
##
## Over all of these, the slot is lit while the pointer is on it or it has the keys' focus:
## the ware is lifted and ringed, in `accent` if it can be taken and in plain chalk if not. A
## lit slot shows a note beside it: what the ware does and, when it cannot be taken, `why`.
##
## The pointer gives the slot the focus, so that one slot is lit at a time whichever of the
## two the player uses, and the arrows go from slot to slot as they do between any controls
## (set `focus_neighbor_*` to choose the way). A click, Enter or Space takes the ware:
## `chosen` if it is available, `refused(why)` if not. Nothing here buys anything or makes a
## sound: the page does, then sets the slot's new state.
##
## The slot has one of three fixed sizes, set by what it shows: CARD_SLOT, SMALL_SLOT, or
## RACK_SLOT for `show_racked(key, name, detail)`: an instrument held, in a rack with no room
## for whole slots. That one is the emblem alone, at the table's size, ringed while it is
## lit; its name is in its note, and it has no price.

## The ware was taken, and it can be: for the page to buy it.
signal chosen
## The ware was taken, and it cannot be: `why` is the reason it gave.
signal refused(why: String)
## The slot became lit (the pointer or the focus came to it) or stopped being so.
signal lit_changed(lit: bool)

enum State { AVAILABLE, TOO_DEAR, NOT_ALLOWED, BOUGHT }

## The size of a slot that shows a card, and of one that shows anything else.
const CARD_SLOT := Vector2(112.0, 178.0)
const SMALL_SLOT := Vector2(104.0, 124.0)
## The size of a place of a rack (`show_racked`).
const RACK_SLOT := Vector2(44.0, 44.0)

const CARD_AT := Vector2(8.0, 8.0)
const TILE := Rect2(20.0, 29.0, 64.0, 64.0)
const NAME_BASE := 12.0 # the baseline of a small ware's name
const TAG_GAP := 8.0 # from the ware's foot to the price's top
const LIFT := 5.0 # how far a lit ware rises
const LIFT_TIME := 0.1
const RING_GROW := 4.0
const EMBLEM_SCALE := 1.5 # an emblem here, by its size on the table
const NAME_SIZE := 11
const PRICE_SIZE := 18
const WORD_SIZE := 13
const COIN := 6.5
const NOTE_W := 200.0
const NOTE_SIZE := 12
const NOTE_PAD := 7.0
const DIM := 0.45 # how much of a ware that cannot be taken shows

## The light a lit slot is ringed in: Palette.JEKYLL or Palette.HYDE.
var accent := Palette.JEKYLL:
	set(value):
		accent = value
		_redraw()

var _kind := ""
var _key := ""
## True for a place of a rack: the emblem alone.
var _racked := false
var _name := ""
var _detail := ""
var _state := State.AVAILABLE
var _why := ""
var _word := ""
var _price := -1
var _uses := -1
var _hover := false
var _forced := false
var _lit := false
var _lift := 0.0
var _lift_tween: Tween
var _card: ArenaCard
## A table's ArenaMeans that is never shown: its emblems are drawn from it.
var _means: ArenaMeans
var _back := Control.new()
var _lines := Control.new()
var _over := Control.new()
var _note := Control.new()
var _heavy := FontVariation.new()
var _plain: Font = ThemeDB.fallback_font


func _init() -> void:
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.7
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_slot(SMALL_SLOT)
	_lines.material = ArenaMeans.LINE_MATERIAL
	_back.draw.connect(_draw_back)
	_lines.draw.connect(_draw_lines)
	_over.draw.connect(_draw_over)
	_note.draw.connect(_draw_note)
	for child: Control in [_back, _lines, _over, _note]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	# The note lies over the page, wherever the slot is in it.
	_note.top_level = true
	_note.z_index = 100
	_note.visible = false
	mouse_entered.connect(_on_pointer.bind(true))
	mouse_exited.connect(_on_pointer.bind(false))
	focus_entered.connect(_relight)
	focus_exited.connect(_relight)
	item_rect_changed.connect(_place_note)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_means):
		_means.free()


# --- What it shows --------------------------------------------------------------------------


## Shows a card: `data` is shaped like a card of RulesView ({key, ink, name, chips, text},
## any of them left out), and `seed` picks its stain.
func show_card(data: Dictionary, card_seed: int = 1) -> void:
	_kind = "card"
	_name = data.get("name", "")
	_detail = ""
	if _card == null:
		_card = ArenaCard.new()
		add_child(_card)
		move_child(_card, 0)
	_card.show_data(data, card_seed)
	_set_slot(CARD_SLOT)
	_refresh()


## Shows an instrument as its emblem: `key` is its key in the rules.
func show_instrument(key: String, ware_name: String = "", detail: String = "") -> void:
	_show_small("instrument", key, ware_name, detail)


## Shows an instrument held as a place of a rack (RACK_SLOT): its emblem alone, as the table
## draws it. With "" for `key` it is a free place, to be set BOUGHT.
func show_racked(key: String, ware_name: String = "", detail: String = "") -> void:
	_show_small("instrument", key, ware_name, detail, true)


## Shows a dose of salt as its folded paper.
func show_salt(ware_name: String = "A dose of salt", detail: String = "") -> void:
	_show_small("salt", "", ware_name, detail)


## Shows a service done to a card (striking one): a card with a stroke across it.
func show_service(ware_name: String, detail: String = "") -> void:
	_show_small("service", "", ware_name, detail)


## The price in sovereigns, written with a coin; 0 is written "free".
func set_price(sovereigns: int) -> void:
	_price = maxi(sovereigns, 0)
	_uses = -1
	_redraw()


## How many times a service is left, written "1×", in place of a price.
func set_uses(times: int) -> void:
	_uses = maxi(times, 0)
	_price = -1
	_redraw()


## Puts the slot in a state. `why` is the reason a ware cannot be taken, shown while the
## slot is lit; `word` is what a bought slot says where the price was.
func set_state(new_state: State, why: String = "", word: String = "") -> void:
	_state = new_state
	_why = why
	_word = word
	if _state == State.BOUGHT:
		# The slot lets the focus go, and does not pass it on: the page knows where it belongs.
		if has_focus():
			release_focus()
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hover = false
	else:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_relight()


## Sets the price and the state from one offer of RulesView.place ({price, ok, why}, with
## `sold` or `taken` for one that is gone) and the sovereigns held: an offer that is refused
## is too dear if its price is more than the purse, and not allowed otherwise.
func set_offer(offer: Dictionary, purse: int) -> void:
	var price := int(offer.get("price", 0))
	set_price(price)
	if offer.get("sold", false):
		set_state(State.BOUGHT, "", "sold")
	elif offer.get("taken", false):
		set_state(State.BOUGHT, "", "taken")
	elif offer.get("ok", true):
		set_state(State.AVAILABLE)
	else:
		set_state(State.TOO_DEAR if price > purse else State.NOT_ALLOWED, offer.get("why", ""))


func state() -> State:
	return _state


## Why the ware cannot be taken, "" if it can.
func why() -> String:
	return _why


## True while the pointer is on the slot or it has the focus.
func is_lit() -> bool:
	return _lit


## Lights the slot whatever the pointer and the focus do, or stops doing so: for a still.
func force_lit(on: bool) -> void:
	_forced = on
	_relight()


## The middle of the ware in the window: where a bought ware leaves from.
func spot() -> Vector2:
	return get_global_transform() * _ware_rect().get_center()


## Takes the ware, as a click or Enter does.
func take() -> void:
	if _state == State.AVAILABLE:
		chosen.emit()
	elif _state != State.BOUGHT:
		refused.emit(_why)


# --- Pointer and keys -----------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		take()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		take()


func _on_pointer(inside: bool) -> void:
	_hover = inside
	if inside and focus_mode != Control.FOCUS_NONE and not has_focus():
		grab_focus()
	_relight()


func _relight() -> void:
	var lit := _state != State.BOUGHT and (_hover or _forced or has_focus())
	if _card != null:
		_card.chosen = lit and _state == State.AVAILABLE
	_show_note(lit)
	if lit == _lit:
		_redraw()
		return
	_lit = lit
	if _lift_tween != null:
		_lift_tween.kill()
	if is_inside_tree():
		_lift_tween = create_tween()
		_lift_tween.tween_method(_set_lift, _lift, 1.0 if lit else 0.0, LIFT_TIME)
	else:
		_set_lift(1.0 if lit else 0.0)
	lit_changed.emit(lit)


func _set_lift(value: float) -> void:
	_lift = value
	if _card != null:
		_card.position = CARD_AT + _rise()
	_redraw()


# --- Where things are -----------------------------------------------------------------------


func _show_small(kind: String, key: String, ware_name: String, detail: String, racked: bool = false) -> void:
	_kind = kind
	_key = key
	_racked = racked
	_name = ware_name
	_detail = detail
	if _card != null:
		_card.queue_free()
		_card = null
	# Only a ware whose drawing is the table's needs the table's emblems.
	if _means == null and (kind == "salt" or (kind == "instrument" and key != "")):
		_means = ArenaMeans.new()
	_set_slot(RACK_SLOT if racked else SMALL_SLOT)
	_refresh()


func _set_slot(slot: Vector2) -> void:
	custom_minimum_size = slot
	size = slot
	for child: Control in [_back, _lines, _over]:
		child.size = slot


func _rise() -> Vector2:
	return Vector2.ZERO if _racked else Vector2(0.0, -LIFT * _lift)


## How large an emblem is drawn, by its size on the table.
func _emblem_scale() -> float:
	return 1.0 if _racked else EMBLEM_SCALE


## The ware's own rectangle in the slot, as it stands now: the card, or the small ware's tile.
func _ware_rect() -> Rect2:
	if _racked:
		return Rect2(Vector2.ZERO, RACK_SLOT)
	var rect := Rect2(CARD_AT, ArenaCard.SIZE) if _kind == "card" else TILE
	rect.position += _rise()
	return rect


func _takeable() -> bool:
	return _state == State.AVAILABLE


func _refresh() -> void:
	var gone := _state == State.BOUGHT
	var dim := _state == State.TOO_DEAR or _state == State.NOT_ALLOWED
	if _card != null:
		_card.visible = not gone
		_card.dimmed = dim
		_card.modulate.a = 0.6 if dim else 1.0
		_card.position = CARD_AT + _rise()
	_back.visible = not gone
	_lines.visible = not gone
	_back.modulate.a = DIM if dim else 1.0
	_lines.modulate.a = DIM if dim else 1.0
	_redraw()


func _redraw() -> void:
	for child: Control in [_back, _lines, _over, _note]:
		child.queue_redraw()


# --- Drawing --------------------------------------------------------------------------------


## A small ware's tile, and under an instrument's sketch its stock or its wax.
func _draw_back() -> void:
	if _kind == "card" or _kind == "":
		return
	var rect := _ware_rect()
	if not _racked:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Palette.NIGHT_1, 0.45)
		box.border_color = Palette.RULE
		box.set_border_width_all(2)
		box.set_corner_radius_all(ArenaMeans.SLOT_CORNER)
		box.anti_aliasing = true
		_back.draw_style_box(box, rect)
	if _kind != "instrument" or _key == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_key)
	_back.draw_set_transform(rect.get_center(), 0.0, Vector2.ONE * _emblem_scale())
	if ArenaMeans._his(_key):
		var edge := ArenaMeans._blob(rng, ArenaMeans.ROUND_R, 1.2, 5)
		_means._card(_back, edge, ArenaMeans.WAX)
		_back.draw_colored_polygon(ArenaMeans._blob(rng, ArenaMeans.ROUND_R - 4.5, 0.4, 3), ArenaMeans.WAX_PRESSED)
		edge.append(edge[0])
		_back.draw_polyline(edge, ArenaMeans.WAX_LINE, ArenaMeans.RIM_WIDTH, true)
	else:
		_means._card(_back, ArenaMeans._blob(rng, ArenaMeans.ROUND_R, 0.5, 3), ArenaMeans.CREAM)
	_back.draw_set_transform_matrix(Transform2D.IDENTITY)


## The pencil's part of a small ware: the instrument's sketch, the paper of salt, or the
## struck card.
func _draw_lines() -> void:
	if _kind == "card" or _kind == "":
		return
	var centre := _ware_rect().get_center()
	var base := 23000 + hash(_key) % 97
	match _kind:
		"instrument":
			if _key == "":
				return
			var his := ArenaMeans._his(_key)
			var colour := ArenaMeans.WAX_LINE if his else ArenaMeans.PENCIL
			_lines.draw_set_transform(centre, 0.0, Vector2.ONE * _emblem_scale())
			if not his:
				var ring := Pencil.new(base + 400)
				ring.colour = colour
				ring.min_width = ArenaMeans.MIN_STROKE
				ring.stroke(ArenaMeans._circle(Vector2.ZERO, ArenaMeans.ROUND_R - 2.5, 30), 1.6, 0.2)
				ring.draw(_lines)
			var sketch := Pencil.new(base + 600)
			sketch.colour = colour
			sketch.min_width = ArenaMeans.MIN_STROKE * (1.3 if his else 1.0) / ArenaMeans.SKETCH_SCALE
			_lines.draw_set_transform(centre, 0.0, Vector2.ONE * _emblem_scale() * ArenaMeans.SKETCH_SCALE)
			_means._instrument(sketch, _key)
			sketch.draw(_lines)
		"salt":
			var paper := Pencil.new(base + 100)
			paper.colour = ArenaMeans.GLASS_LIGHT
			_lines.draw_set_transform(centre, 0.0, Vector2.ONE * _emblem_scale())
			_means._paper_path(paper, Vector2.ZERO, 0.0)
			paper.draw(_lines)
		"service":
			# A card, and one stroke across it.
			var card := Pencil.new(base + 200)
			card.colour = Palette.CHALK_2
			var half := Vector2(15.0, 22.0)
			card.stroke(ArenaMeans._rect_path(Rect2(centre - half, half * 2.0)), 1.8, 0.3)
			card.draw(_lines)
			var cut := Pencil.new(base + 300)
			cut.colour = Palette.CHALK
			cut.stroke(PackedVector2Array([centre + Vector2(-21.0, 20.0), centre + Vector2(21.0, -20.0)]), 3.0, 0.4)
			cut.draw(_lines)
	_lines.draw_set_transform_matrix(Transform2D.IDENTITY)


## What lies over the ware: its name, the ring of a lit slot, the mark of one that is not
## allowed, the outline of one that is gone, and the price.
func _draw_over() -> void:
	if _kind == "":
		return
	var rect := _ware_rect()
	if _racked:
		_draw_racked(rect.get_center())
		return
	var rest := Rect2(CARD_AT, ArenaCard.SIZE) if _kind == "card" else TILE
	if _state == State.BOUGHT:
		_dashed_outline(rest.grow(-1.0), Color(Palette.CHALK_3, 0.6))
	else:
		if _kind != "card" and _name != "":
			var colour := Palette.CHALK_3 if not _takeable() else (Palette.CHALK if _lit else Palette.CHALK_2)
			_over.draw_string(_plain, Vector2(0.0, NAME_BASE), _name, HORIZONTAL_ALIGNMENT_CENTER,
					size.x, NAME_SIZE, colour)
		if _lit:
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(accent, 0.0)
			ring.set_border_width_all(2)
			ring.set_corner_radius_all(7)
			ring.anti_aliasing = true
			if _takeable():
				ring.border_color = accent
				ring.shadow_color = Color(accent, 0.3)
				ring.shadow_size = 8
			else:
				ring.border_color = Palette.CHALK_2
			_over.draw_style_box(ring, rect.grow(RING_GROW))
		if _state == State.NOT_ALLOWED:
			_draw_bar(Vector2(rect.end.x - 5.0, rect.position.y + 5.0))
	_draw_tag(rest.end.y + TAG_GAP)


## What lies over a place of a rack, about `c`: a broken ring if it is free, the ring of a
## lit one if not.
func _draw_racked(c: Vector2) -> void:
	if _state == State.BOUGHT:
		for k in 8:
			_over.draw_arc(c, ArenaMeans.ROUND_R - 2.0, k * TAU / 8.0, (k + 0.6) * TAU / 8.0, 6,
					Color(Palette.CHALK_3, 0.6), 1.5, true)
	elif _lit:
		_over.draw_arc(c, ArenaMeans.ROUND_R + 3.0, 0.0, TAU, 40, accent if _takeable() else Palette.CHALK_2,
				2.0, true)


## The price, its top at `top`, in the middle of the slot's width.
func _draw_tag(top: float) -> void:
	var mid := size.x * 0.5
	if _state == State.BOUGHT:
		_over.draw_string(_plain, Vector2(0.0, top + _plain.get_ascent(WORD_SIZE) + 2.0), _word,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, WORD_SIZE, Palette.CHALK_3)
		return
	var base := top + _heavy.get_ascent(PRICE_SIZE) - 2.0
	var faint := 1.0 if _takeable() else 0.6
	if _uses >= 0:
		# A service: how many times it is left, in a dashed box.
		var words := "%d×" % _uses
		var width := _heavy.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
		_over.draw_string(_heavy, Vector2(mid - width * 0.5, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1,
				PRICE_SIZE, Color(Palette.CHALK, faint))
		_dashed_outline(Rect2(mid - width * 0.5 - 8.0, top - 2.0, width + 16.0, 24.0),
				Color(Palette.CHALK_3, faint))
		return
	if _price < 0:
		return
	var dear := _state == State.TOO_DEAR
	var colour := Palette.WARN if dear else Color(Palette.GOLD, faint)
	var words := "free" if _price == 0 else str(_price)
	var width := _heavy.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
	var coin := 0.0 if _price == 0 else COIN * 2.0 + 5.0
	var left := mid - (coin + width) * 0.5
	var line := base - _heavy.get_ascent(PRICE_SIZE) * 0.34
	if _price > 0:
		# The coin: a gold round with a ring pressed in it.
		var c := Vector2(left + COIN, line)
		_over.draw_circle(c, COIN, colour)
		_over.draw_arc(c, COIN - 2.2, 0.0, TAU, 20, Color(Palette.OUTLINE, 0.55), 1.0, true)
	_over.draw_string(_heavy, Vector2(left + coin, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1,
			PRICE_SIZE, colour)
	if dear:
		# The second cue of a price that is too high: it is struck through.
		_over.draw_line(Vector2(left - 3.0, line + 1.0), Vector2(left + coin + width + 3.0, line - 1.0),
				Palette.WARN, 2.0, true)


## The mark of a ware that is not allowed: a small barred ring, about `c`.
func _draw_bar(c: Vector2) -> void:
	const R := 8.0
	_over.draw_circle(c, R + 1.5, Palette.NIGHT_1)
	_over.draw_arc(c, R, 0.0, TAU, 24, Palette.CHALK, 1.8, true)
	var reach := Vector2(R, R) * 0.7
	_over.draw_line(c - reach, c + reach, Palette.CHALK, 1.8, true)


func _dashed_outline(rect: Rect2, colour: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		_over.draw_dashed_line(corners[k], corners[(k + 1) % 4], colour, 1.5, 4.0)


# --- The note -------------------------------------------------------------------------------


## The note's lines, each [words, font, colour]: what the ware does, then why it cannot be
## taken. A place of a rack has its name first, which is written nowhere else.
func _note_lines() -> Array:
	var lines := []
	if _racked and _name != "":
		lines.append([_name, _heavy, ArenaMeans.INK])
	if _detail != "":
		lines.append([_detail, _plain, ArenaMeans.PENCIL])
	if not _takeable() and _why != "":
		lines.append([_why, _heavy, ArenaMeans.INK])
	return lines


func _line_height(line: Array) -> float:
	var font: Font = line[1]
	return font.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - NOTE_PAD * 2.0,
			NOTE_SIZE).y


func _show_note(lit: bool) -> void:
	_note.visible = lit and not _note_lines().is_empty()
	_place_note()


## Puts the note under the slot, or over it where there is no room under, kept in the window.
func _place_note() -> void:
	if not _note.visible or not is_inside_tree():
		return
	var height := NOTE_PAD * 2.0
	for line: Array in _note_lines():
		height += _line_height(line) + 2.0
	_note.size = Vector2(NOTE_W, height)
	var window := get_viewport_rect().size
	var at := global_position + Vector2((size.x - NOTE_W) * 0.5, size.y + 2.0)
	if at.y + height > window.y - 4.0:
		at.y = global_position.y - height - 2.0
	at.x = clampf(at.x, 4.0, maxf(4.0, window.x - NOTE_W - 4.0))
	_note.global_position = at
	_note.queue_redraw()


func _draw_note() -> void:
	var box := Rect2(Vector2.ZERO, _note.size)
	_note.draw_rect(Rect2(box.position + Vector2(3.0, 4.0), box.size), ArenaMeans.SHADOW)
	_note.draw_rect(box, ArenaMeans.NOTE_CREAM)
	var y := NOTE_PAD
	for line: Array in _note_lines():
		var font: Font = line[1]
		_note.draw_multiline_string(font, Vector2(NOTE_PAD, y + font.get_ascent(NOTE_SIZE)), line[0],
				HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - NOTE_PAD * 2.0, NOTE_SIZE, -1, line[2])
		y += _line_height(line) + 2.0
