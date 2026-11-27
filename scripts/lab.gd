extends Control
## The laboratory, where a run comes at dawn when Jekyll has the table: his table, window and
## chair, bottom left, and in the clear of the room a sheet (ShopSheet, Jekyll's tone) with
## what the laboratory sells laid out as a shelf:
##
## - the header: the place's name, the purse and the salt;
## - what the dawn brought, and at its right the instruments held, each of which can be
##   dropped, and the rack's free places;
## - the deck's strip (ShopDeckStrip), which opens the deck;
## - "Cards": the shelf's cards, each a slot (ShopWare) with its price under it;
## - "Instruments & salt" and, past a rule, "Service": the shelf's instruments, a dose of
##   salt, and "Strike a card", which opens the deck as a picker: the card chosen there is
##   struck for its own price;
## - Leave, across the foot, which goes back to the table; there the next night begins.
##
## The page holds no rules. Everything it shows is read from RulesView.place: the prices,
## what is sold, what can be taken and why not. Taking a slot calls the rules' own function,
## and every slot is then set again from a fresh record: a ware that was bought leaves its
## slot empty, and the purse, the deck's count and gauge and the rack change with it.
##
## The arrow keys go from slot to slot (ShopKeys.wire gives each its neighbours, row by row),
## Enter or Space takes the one lit, D opens the deck and Escape goes to Leave. The pointer
## does the same: it lights the slot it is on, and a click takes it. The instruments held are
## slots too (ShopWare.show_racked), and so are the rack's free places.
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/lab.tscn --seed=3` (see SceneFlow.run_for_place).
## Only then, never in a run that came from the table, it also takes:
##
## - `--full-deck`: one card of every kind the deck lacks joins it (every Ink Root and every
##   Factor), for the fullest deck a run can open.
## - `--deck`: the deck is open. `--strike`: it is open as the picker of a card to strike.
## - `--purse`, `--held`, `--select`, `--press`, `--point` and `--click`, as ShopKeys says.

const WHERE := "lab"
const HEADING := "The Laboratory"
const STRIKE_HEADING := "Strike a card"
const STRIKE_LEAD := "A card struck here leaves his deck for good."
const LINE_SIZE := 12
## Under the row of the dawn's line and the rack.
const RACK_GAP := 6.0
## The room the rack's words take, at the rack's left.
const HELD_WORDS := 84.0
## Under the deck's strip, and under the row of cards.
const STRIP_GAP := 12.0
const ROW_GAP := 22.0
## The room kept between the instruments' group and the service's, for the rule.
const DIVIDER_ROOM := 20.0
## The most room between two small slots.
const SMALL_GAP := 8.0
## How long a bought card takes to reach the deck's pile.
const FLY_TIME := 0.3

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun
var _cards: Array[ShopWare] = []
var _instruments: Array[ShopWare] = []
var _salt: ShopWare
var _service: ShopWare
var _strip: ShopDeckStrip
## The rack's places, made again whenever the rack changes: the instruments held, then its
## free places.
var _held: Array[ShopWare] = []
var _held_keys: Array = []
## True while the page sets itself up or shows a move: a slot lit then makes no sound.
var _quiet := true
## The rack's size, and where its row lies on the sheet.
var _slots := 0
var _held_at := Vector2.ZERO
var _dawn := ""
var _dawn_at := Vector2.ZERO
## The page's own writing on the sheet: the dawn's line and the rack's words.
var _writing := Control.new()

@onready var _sheet: ShopSheet = $Sheet


func _ready() -> void:
	Music.enter("lab")
	var held: RulesRun = SceneFlow.run
	var own := held == null or held.phase != WHERE
	_run = SceneFlow.run_for_place(WHERE)
	if own and _run != null:
		_set_up_still()
	_sheet.tone = "jekyll"
	_sheet.set_place(HEADING)
	_sheet.leave.connect(_leave)
	var place: Variant = RulesView.place(_run) if _run != null else null
	if place == null:
		_sheet.leave_button.grab_focus()
	else:
		_build(place)
		_refresh()
		_focus_first()
	if own and place != null:
		ShopKeys.select(_stops())
		if Shot.has_arg("strike"):
			_open_strike()
		elif Shot.has_arg("deck"):
			_strip.open()
		_quiet = false
		await ShopKeys.play(self)
	_quiet = false
	Shot.run_if_requested(self)


func _unhandled_key_input(event: InputEvent) -> void:
	# Escape: the keys go to Leave. (An open deck takes Escape first, to close.)
	if event.is_action_pressed("ui_cancel") and not _strip.is_open():
		get_viewport().set_input_as_handled()
		ShopKeys.hover(false)
		_sheet.leave_button.grab_focus()


# ---------- the shelf ----------

## Makes the shelf's slots and lays them on the sheet, from the record of the place. The
## shelf keeps its slots for the whole visit: `_refresh` sets what each shows.
func _build(place: Dictionary) -> void:
	var room := _sheet.room()
	var y := room.position.y
	_dawn = _dawn_line(place.dawn)
	_dawn_at = Vector2(room.position.x, y)
	_slots = int(place.slots)
	_held_at = Vector2(room.end.x - _slots * ShopWare.RACK_SLOT.x, y)
	y += ShopWare.RACK_SLOT.y + RACK_GAP

	_strip = ShopDeckStrip.new()
	_sheet.add_child(_strip)
	_strip.position = Vector2(room.position.x, y)
	_strip.size = Vector2(room.size.x, ShopDeckStrip.HEIGHT)
	_strip.card_picked.connect(_on_struck)
	y += ShopDeckStrip.HEIGHT + STRIP_GAP

	var headings: Array = [{text = "Cards", at = Vector2(room.position.x, y), width = room.size.x}]
	y += ShopSheet.HEADING_HEIGHT
	var count: int = place.cards.size()
	var gap := (room.size.x - count * ShopWare.CARD_SLOT.x) / maxi(count, 1)
	for i in count:
		var card: Dictionary = place.cards[i]
		var face := RulesView.offer_entry(_run, card.key, _run.stance)
		var ware := _ware(Vector2(room.position.x + gap * 0.5 + i * (ShopWare.CARD_SLOT.x + gap), y))
		ware.show_card(face, 31 + i * 17)
		ware.chosen.connect(_buy_card.bind(ware, int(card.index), face))
		_cards.append(ware)
	_sheet.wares = Rect2(room.position.x, y, room.size.x, ShopWare.CARD_SLOT.y)
	y += ShopWare.CARD_SLOT.y + ROW_GAP

	# The lower row: the instruments and the salt from the left, the service at the right end.
	var small := ShopWare.SMALL_SLOT
	var service_x := room.end.x - small.x
	var group := service_x - DIVIDER_ROOM - room.position.x
	headings.append({text = "Instruments & salt", at = Vector2(room.position.x, y), width = group})
	headings.append({text = "Service", at = Vector2(service_x, y), width = small.x})
	_sheet.set_headings(headings)
	y += ShopSheet.HEADING_HEIGHT
	_sheet.set_dividers([[Vector2(service_x - DIVIDER_ROOM * 0.5, y - ShopSheet.HEADING_HEIGHT),
			Vector2(service_x - DIVIDER_ROOM * 0.5, y + small.y)]])
	var in_group: int = place.instruments.size() + 1
	var pitch := minf(small.x + SMALL_GAP, (group - small.x) / maxi(in_group - 1, 1))
	for i in place.instruments.size():
		var instrument: Dictionary = place.instruments[i]
		var ware := _ware(Vector2(room.position.x + i * pitch, y))
		ware.show_instrument(instrument.key, instrument.name, instrument.text)
		ware.chosen.connect(_deal.bind(Rules.buy_instrument.bind(_run, int(instrument.index))))
		_instruments.append(ware)
	_salt = _ware(Vector2(room.position.x + (in_group - 1) * pitch, y))
	_salt.show_salt("A dose of salt", "One more dose for the nights ahead.")
	_salt.chosen.connect(_deal.bind(Rules.buy_salt.bind(_run)))
	_service = _ware(Vector2(service_x, y))
	_service.show_service("Strike a card", "Take a card out of his deck for good, for that card's price.")
	_service.chosen.connect(_open_strike)

	_writing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_writing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_writing.draw.connect(_draw_writing)
	_sheet.add_child(_writing)


## A new slot of the shelf, at this place on the sheet.
func _ware(at: Vector2) -> ShopWare:
	var ware := ShopWare.new()
	ware.accent = Palette.JEKYLL
	_sheet.add_child(ware)
	ware.position = at
	ware.refused.connect(_on_refused)
	ware.lit_changed.connect(_on_lit)
	return ware


## Sets the header, the strip and every slot from the run as it stands now.
func _refresh() -> void:
	var place: Variant = RulesView.place(_run)
	if place == null:
		return
	var purse := int(place.sov)
	_sheet.set_purse(purse, int(place.salt.doses))
	_sheet.set_leave("Night %d: %s" % [int(place.night.no), place.night.title])
	_strip.show_run(_run)
	for i in _cards.size():
		_cards[i].set_offer(place.cards[i], purse)
	for i in _instruments.size():
		_instruments[i].set_offer(place.instruments[i], purse)
	_salt.set_offer(place.salt, purse)
	_set_service(place.strike)
	_show_held(place.held)
	ShopKeys.wire(_key_rows())


## The service's slot, from the record's list of cards to strike: its price is the least any
## of them costs, and it is open while one of them can be struck.
func _set_service(strike: Array) -> void:
	if strike.is_empty():
		_service.set_price(0)
		_service.set_state(ShopWare.State.NOT_ALLOWED, "No card is left in his deck.")
		return
	var least := int(strike[0].price)
	var open := false
	var why := ""
	for card: Dictionary in strike:
		least = mini(least, int(card.price))
		open = open or bool(card.ok)
		if why == "" and not card.ok:
			why = card.why
	_service.set_price(least)
	if open:
		_service.set_state(ShopWare.State.AVAILABLE)
	else:
		_service.set_state(ShopWare.State.TOO_DEAR, why)


## The rack's row: the instruments held, each to drop, then its free places. The places are
## made again only when the rack changed.
func _show_held(held: Array) -> void:
	var keys: Array = []
	for instrument: Dictionary in held:
		keys.append(instrument.key)
	if keys == _held_keys and _held.size() == _slots:
		return
	for place in _held:
		_sheet.remove_child(place)
		place.queue_free()
	_held.clear()
	_held_keys = keys
	for i in _slots:
		var place := _ware(_held_place(i))
		if i < held.size():
			var instrument: Dictionary = held[i]
			place.show_racked(instrument.key, instrument.name, "%s Enter or a click drops it." % instrument.text)
			place.chosen.connect(_drop.bind(String(instrument.key)))
		else:
			place.show_racked("")
			place.set_state(ShopWare.State.BOUGHT)
		_held.append(place)
	_writing.queue_redraw()


## Where the rack's place number `i` lies on the sheet.
func _held_place(i: int) -> Vector2:
	return _held_at + Vector2(i * ShopWare.RACK_SLOT.x, 0.0)


# The dawn's line, on two lines if it must be, and at the rack's left how many instruments
# are held.
func _draw_writing() -> void:
	var font := ThemeDB.fallback_font
	var faint: Color = ArenaNotice.TONES[_sheet.tone].faint
	var words_at := _held_at.x - HELD_WORDS
	var width := words_at - 12.0 - _dawn_at.x
	var lines := font.get_multiline_string_size(_dawn, HORIZONTAL_ALIGNMENT_LEFT, width, LINE_SIZE).y
	var top := _dawn_at.y + maxf(0.0, (ShopWare.RACK_SLOT.y - lines) * 0.5)
	_writing.draw_multiline_string(font, Vector2(_dawn_at.x, top + font.get_ascent(LINE_SIZE)), _dawn,
			HORIZONTAL_ALIGNMENT_LEFT, width, LINE_SIZE, 2, faint)
	var base := _held_at.y + ShopWare.RACK_SLOT.y * 0.5 + (font.get_ascent(LINE_SIZE) - font.get_descent(LINE_SIZE)) * 0.5
	_writing.draw_string(font, Vector2(words_at, base), "Held: %d of %d" % [_held_keys.size(), _slots],
			HORIZONTAL_ALIGNMENT_RIGHT, HELD_WORDS - 8.0, LINE_SIZE, faint)


## What the dawn brought, as the page's opening line.
func _dawn_line(dawn: Dictionary) -> String:
	var brought: Array[String] = []
	if dawn.brings_name != "":
		brought.append("two of his %s" % dawn.brings_name)
	if dawn.unlocks_name != "":
		brought.append("%s to buy" % dawn.unlocks_name)
	if brought.is_empty():
		return "Dawn %d brought nothing new." % int(dawn.no)
	return "Dawn %d brought %s." % [int(dawn.no), ", and ".join(brought)]


# ---------- the keys ----------

## Every control the keys can be on, in rows from the top, each row from the left.
func _key_rows() -> Array:
	return ShopKeys.rows([_held, [_strip], _cards, _instruments + [_salt, _service], [_sheet.leave_button]])


## The slots the keys can be on and then Leave, without the deck's strip: what `--select`
## counts, and where the focus may go on to from a slot that was emptied.
func _stops() -> Array[Control]:
	var stops := ShopKeys.stops(_key_rows())
	stops.erase(_strip)
	return stops


## The keys begin on the first ware that can be bought, or on Leave if none can.
func _focus_first() -> void:
	ShopKeys.focus_first(_cards + _instruments + [_salt, _service], _sheet.leave_button)


# ---------- taking a slot ----------

## Makes a move in the rules (`move` returns their answer) and shows the shelf as it then
## stands. True if the rules made it.
func _deal(move: Callable) -> bool:
	var from := get_viewport().gui_get_focus_owner()
	var spot := ShopKeys.middle(from)
	var result: Dictionary = move.call()
	if not result.ok:
		Sfx.play("refuse")
	else:
		match String(move.get_method()):
			"strike":
				Sfx.play("target_struck", 0.85) # a firm pen strike: final
			"drop_instrument":
				Sfx.play("lock", 0.7) # brass set down on wood
			_:
				Sfx.play("buy")
	# The slots are set again and the focus put where it belongs, once, with no slot's sound
	# over the move's own.
	_quiet = true
	_refresh()
	if not _strip.is_open():
		ShopKeys.keep_focus(self, from, spot, _stops(), _sheet.leave_button)
	_quiet = false
	return bool(result.ok)


## Buys the shelf's card at `index`; it then goes from its slot to the deck's pile.
func _buy_card(ware: ShopWare, index: int, face: Dictionary) -> void:
	var from := ware.spot()
	if not _deal(Rules.buy_card.bind(_run, index)) or ArenaPace.reduce_flashes:
		return
	var card := ArenaCard.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	card.show_data(face, 31 + index * 17)
	var half := ArenaCard.SIZE * 0.5
	card.global_position = from - half
	var flight := create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	flight.tween_property(card, "global_position", _strip.pile_centre() - half, FLY_TIME)
	flight.tween_property(card, "scale", Vector2.ONE * ShopDeckStrip.PILE_SCALE, FLY_TIME)
	flight.chain().tween_callback(card.queue_free)


func _drop(key: String) -> void:
	_deal(Rules.drop_instrument.bind(_run, key))


func _on_refused(_why: String) -> void:
	Sfx.play("refuse")


func _on_lit(lit: bool) -> void:
	if lit and not _quiet and not _strip.is_open():
		ShopKeys.hover(false)


## Opens the deck as a picker of the card to strike: every card with the rules' price to
## strike it, and one that cannot be struck shut with the rules' reason.
func _open_strike() -> void:
	var place: Variant = RulesView.place(_run)
	if place == null:
		return
	Sfx.play("button")
	var offers := {}
	for offer: Dictionary in place.strike:
		offers[int(offer.id)] = offer
	var cards: Array = []
	for c: RulesCard in _run.cards:
		var face := RulesView.entry(_run, c, _run.stance)
		var offer: Dictionary = offers.get(c.id, {})
		face.price = int(offer.get("price", 0))
		face.ok = bool(offer.get("ok", false))
		face.why = String(offer.get("why", ""))
		cards.append(face)
	_strip.open_picker(cards, STRIKE_HEADING, STRIKE_LEAD)


func _on_struck(card: Dictionary) -> void:
	_deal(Rules.strike.bind(_run, int(card.id)))


## Back to the table, which leaves the laboratory in the rules and begins the next night.
func _leave() -> void:
	Sfx.play("button")
	SceneFlow.back_to_table()


# ---------- run on its own ----------

## The purse, the rack and the deck asked for on the command line, for a still.
func _set_up_still() -> void:
	ShopKeys.dress(_run)
	if Shot.has_arg("full-deck"):
		var kinds := {}
		for c: RulesCard in _run.cards:
			kinds[[c.key(), c.is_ink()]] = true
		for sym: String in RulesConfig.ROOTS:
			for ink: bool in [false, true]:
				if not kinds.has([sym, ink]):
					Rules.add_card(_run, sym, ink, false)
		for kind: String in RulesConfig.FACTORS:
			if not kinds.has([kind, false]):
				Rules.add_card(_run, kind, false, false)
