extends Control
## The laboratory, where a run comes at dawn when Jekyll has the table: his table, window and
## chair, bottom left, and in the clear of the room a sheet (ShopSheet, Jekyll's tone) with
## what the laboratory sells laid out as a shelf:
##
## - the header: the place's name, the purse and the salt;
## - what the dawn brought, and the deck's strip (ShopDeckStrip), which opens the deck; at
##   the strip's right the instruments held, each of which can be dropped, and the rack's
##   free places;
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
## The arrow keys go from slot to slot (`_wire` gives each its neighbours, row by row), Enter
## or Space takes the one lit, and D opens the deck. The pointer does the same: it lights the
## slot it is on, and a click takes it.
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/lab.tscn --seed=3` (see SceneFlow.run_for_place).
## Only then, never in a run that came from the table, it also takes:
##
## - `--purse=<n>`: the purse holds that many sovereigns.
## - `--held=<n>`: that many instruments are held (ones the shelf does not sell).
## - `--full-deck`: one card of every kind the deck lacks joins it (every Ink Root and every
##   Factor), for the fullest deck a run can open.
## - `--deck`: the deck is open. `--strike`: it is open as the picker of a card to strike.
## - `--keys=rde`: keys pressed as a player would, in turn: l Left, r Right, u Up, d Down,
##   e Enter, x Escape.
## - `--point=700,300`: the pointer moved there, and `--click` a click there.

const WHERE := "lab"
const HEADING := "The Laboratory"
const STRIKE_HEADING := "Strike a card"
const STRIKE_LEAD := "A card struck here leaves his deck for good."
const LINE_SIZE := 12
## The dawn's line, and the room under it.
const DAWN_HEIGHT := 18.0
## Under the deck's strip, and under the row of cards.
const STRIP_GAP := 12.0
const ROW_GAP := 22.0
## The room kept between the instruments' group and the service's, for the rule.
const DIVIDER_ROOM := 20.0
## The most room between two small slots.
const SMALL_GAP := 8.0
## The room between the deck's strip and the rack of the instruments held.
const RACK_GAP := 12.0
## How long a bought card takes to reach the deck's pile.
const FLY_TIME := 0.3

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun
var _cards: Array[ShopWare] = []
var _instruments: Array[ShopWare] = []
var _salt: ShopWare
var _service: ShopWare
var _strip: ShopDeckStrip
## The instruments held, made again whenever the rack changes.
var _held: Array[HeldSlot] = []
var _held_keys: Array = []
## The rack's size, and where its row lies on the sheet.
var _slots := 0
var _held_at := Vector2.ZERO
var _dawn := ""
var _dawn_at := Vector2.ZERO
## The page's own writing on the sheet: the dawn's line and the rack's words and free places.
var _writing := Control.new()
## One table's worth of emblems, which draws those of the instruments held.
var _means := ArenaMeans.new()

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
		if Shot.has_arg("strike"):
			_open_strike()
		elif Shot.has_arg("deck"):
			_strip.open()
		if Shot.has_arg("shot"):
			await _play_input()
			await get_tree().create_timer(0.6).timeout
	Shot.run_if_requested(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_means):
		_means.free()


# ---------- the shelf ----------

## Makes the shelf's slots and lays them on the sheet, from the record of the place. The
## shelf keeps its slots for the whole visit: `_refresh` sets what each shows.
func _build(place: Dictionary) -> void:
	var room := _sheet.room()
	var y := room.position.y
	_dawn = _dawn_line(place.dawn)
	_dawn_at = Vector2(room.position.x, y)
	y += DAWN_HEIGHT

	_strip = ShopDeckStrip.new()
	_sheet.add_child(_strip)
	# The rack stands at the strip's right, in the room the strip can spare.
	_slots = int(place.slots)
	var rack := minf(_slots * HeldSlot.SIZE.x + RACK_GAP, room.size.x - ShopDeckStrip.LEAST_WIDTH)
	_strip.position = Vector2(room.position.x, y)
	_strip.size = Vector2(room.size.x - rack, ShopDeckStrip.HEIGHT)
	_held_at = Vector2(room.end.x - rack + RACK_GAP, y)
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
	_wire()


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


## The instruments held, in the rack's row. They are made again only when the rack changed;
## the keys' focus stays in the row if it was there.
func _show_held(held: Array) -> void:
	var keys: Array = []
	for instrument: Dictionary in held:
		keys.append(instrument.key)
	if keys == _held_keys and _held.size() == keys.size():
		return
	var at := -1
	for i in _held.size():
		if _held[i].has_focus():
			at = i
		_held[i].queue_free()
	_held.clear()
	_held_keys = keys
	for i in held.size():
		var instrument: Dictionary = held[i]
		var slot := HeldSlot.new(_means, instrument.key, instrument.name, instrument.text)
		_sheet.add_child(slot)
		slot.position = _held_place(i)
		slot.chosen.connect(_drop.bind(String(instrument.key)))
		slot.lit_changed.connect(_on_lit)
		_held.append(slot)
	if at >= 0:
		if _held.is_empty():
			_focus_first()
		else:
			_held[mini(at, _held.size() - 1)].grab_focus()
	_writing.queue_redraw()


## Where the rack's place number `i` lies on the sheet.
func _held_place(i: int) -> Vector2:
	return _held_at + Vector2(i * HeldSlot.SIZE.x, 0.0)


# The dawn's line, and over the rack how many instruments are held; the rack's free places.
func _draw_writing() -> void:
	var font := ThemeDB.fallback_font
	var faint: Color = ArenaNotice.TONES[_sheet.tone].faint
	var base := _dawn_at.y + font.get_ascent(LINE_SIZE)
	_writing.draw_string(font, Vector2(_dawn_at.x, base), _dawn, HORIZONTAL_ALIGNMENT_LEFT,
			_held_at.x - RACK_GAP - _dawn_at.x, LINE_SIZE, faint)
	_writing.draw_string(font, Vector2(_held_at.x, base), "Held: %d of %d" % [_held.size(), _slots],
			HORIZONTAL_ALIGNMENT_RIGHT, _sheet.size.x - _dawn_at.x - _held_at.x, LINE_SIZE, faint)
	for i in range(_held.size(), _slots):
		# A free place: a broken ring, empty.
		var c := _held_place(i) + HeldSlot.SIZE * 0.5
		for k in 8:
			_writing.draw_arc(c, ArenaMeans.ROUND_R - 2.0, k * TAU / 8.0, (k + 0.6) * TAU / 8.0, 6,
					Color(faint, 0.55), 1.5, true)


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

## Gives every slot its neighbours for the arrow keys: Left and Right along its row, Up and
## Down to the slot nearest above and under it. A slot that is gone is passed over; at an
## end of a row or of the page the focus stays where it is.
func _wire() -> void:
	var rows: Array = []
	var top: Array = [_strip]
	for row: Array in [top + _held, _cards, _instruments + [_salt, _service], [_sheet.leave_button]]:
		var open: Array = row.filter(func(c: Control) -> bool: return c.focus_mode != Control.FOCUS_NONE)
		if not open.is_empty():
			rows.append(open)
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var slot: Control = row[i]
			var itself := slot.get_path_to(slot)
			slot.focus_neighbor_left = slot.get_path_to(row[i - 1]) if i > 0 else itself
			slot.focus_neighbor_right = slot.get_path_to(row[i + 1]) if i < row.size() - 1 else itself
			slot.focus_neighbor_top = slot.get_path_to(_nearest(rows[r - 1], slot)) if r > 0 else itself
			slot.focus_neighbor_bottom = slot.get_path_to(_nearest(rows[r + 1], slot)) if r < rows.size() - 1 else itself


## The slot of `row` whose middle is nearest that of `slot`, across the page.
func _nearest(row: Array, slot: Control) -> Control:
	var x := slot.get_global_rect().get_center().x
	var best: Control = row[0]
	for other: Control in row:
		if absf(other.get_global_rect().get_center().x - x) < absf(best.get_global_rect().get_center().x - x):
			best = other
	return best


## The keys begin on the first ware that can be bought, or on Leave if none can.
func _focus_first() -> void:
	for ware: ShopWare in _cards + _instruments + [_salt, _service]:
		if ware.state() == ShopWare.State.AVAILABLE:
			ware.grab_focus()
			return
	_sheet.leave_button.grab_focus()


# ---------- taking a slot ----------

## Makes a move in the rules (`move` returns their answer) and shows the shelf as it then
## stands. True if the rules made it.
func _deal(move: Callable) -> bool:
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
	_refresh()
	if get_viewport().gui_get_focus_owner() == null and not _strip.is_open():
		_focus_first()
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
	if lit and not _strip.is_open():
		Sfx.play("hover_j", Sfx.vary(), 0.3)


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
	if Shot.has_arg("purse"):
		_run.sov = maxi(0, int(Shot.arg("purse")))
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
	var on_shelf: Array = []
	if _run.shop != null:
		for offer: Dictionary in _run.shop.instruments:
			on_shelf.append(offer.key)
	var wanted := mini(int(Shot.arg("held")), RulesConfig.MAX_INSTRUMENTS)
	for key: String in RulesConfig.INSTRUMENTS:
		if _run.instruments.size() >= wanted:
			break
		if not on_shelf.has(key) and not _run.instruments.has(key):
			_run.instruments.append(key)


## Plays the input asked for on the command line through the game's own input, a key at a
## time, as a player would.
func _play_input() -> void:
	const KEYS := {"l": KEY_LEFT, "r": KEY_RIGHT, "u": KEY_UP, "d": KEY_DOWN, "e": KEY_ENTER,
			"x": KEY_ESCAPE}
	for letter in Shot.arg("keys"):
		if not KEYS.has(letter):
			continue
		var key := InputEventKey.new()
		key.keycode = KEYS[letter]
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame
	var given := Shot.arg("point").split(",")
	if given.size() != 2:
		return
	var point := Vector2(float(given[0]), float(given[1]))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	if not Shot.has_arg("click"):
		return
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = point
		button.global_position = point
		get_viewport().push_input(button, true)
		await get_tree().process_frame
		await get_tree().process_frame


## One instrument held, in the rack: its emblem as the table draws it. With the
## pointer on it or the keys' focus it is ringed, and a note under it names it, says what it
## does and that it can be dropped. A click, Enter or Space sends `chosen`.
class HeldSlot:
	extends Control

	signal chosen
	signal lit_changed(lit: bool)

	const SIZE := Vector2(44.0, 44.0)
	const NOTE_W := 200.0
	const NOTE_SIZE := 12
	const NOTE_PAD := 7.0

	var _means: ArenaMeans
	var _key := ""
	var _title := ""
	var _detail := ""
	var _lines := Control.new()
	var _note := Control.new()
	var _heavy := FontVariation.new()
	var _plain: Font = ThemeDB.fallback_font

	func _init(means: ArenaMeans, key: String, title: String, detail: String) -> void:
		_means = means
		_key = key
		_title = title
		_detail = detail
		_heavy.base_font = ThemeDB.fallback_font
		_heavy.variation_embolden = 0.7
		custom_minimum_size = SIZE
		size = SIZE
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_lines.material = ArenaMeans.LINE_MATERIAL
		_lines.draw.connect(_draw_lines)
		_note.draw.connect(_draw_note)
		for child: Control in [_lines, _note]:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(child)
		_note.top_level = true
		_note.z_index = 100
		_note.visible = false
		mouse_entered.connect(grab_focus)
		focus_entered.connect(_relight)
		focus_exited.connect(_relight)

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if (button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT) \
				or event.is_action_pressed("ui_accept"):
			accept_event()
			chosen.emit()

	func _relight() -> void:
		_note.visible = has_focus()
		if _note.visible:
			var height := NOTE_PAD * 2.0
			for line: Array in _note_lines():
				height += _line_height(line) + 2.0
			_note.size = Vector2(NOTE_W, height)
			var at := global_position + Vector2((size.x - NOTE_W) * 0.5, size.y + 4.0)
			at.x = clampf(at.x, 4.0, maxf(4.0, get_viewport_rect().size.x - NOTE_W - 4.0))
			_note.global_position = at
			_note.queue_redraw()
		queue_redraw()
		lit_changed.emit(has_focus())

	# The stock or the wax under the sketch, and the ring of a lit slot.
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(_key)
		draw_set_transform(SIZE * 0.5)
		if ArenaMeans._his(_key):
			var edge := ArenaMeans._blob(rng, ArenaMeans.ROUND_R, 1.2, 5)
			_means._card(self, edge, ArenaMeans.WAX)
			draw_colored_polygon(ArenaMeans._blob(rng, ArenaMeans.ROUND_R - 4.5, 0.4, 3), ArenaMeans.WAX_PRESSED)
			edge.append(edge[0])
			draw_polyline(edge, ArenaMeans.WAX_LINE, ArenaMeans.RIM_WIDTH, true)
		else:
			_means._card(self, ArenaMeans._blob(rng, ArenaMeans.ROUND_R, 0.5, 3), ArenaMeans.CREAM)
		if has_focus():
			draw_arc(Vector2.ZERO, ArenaMeans.ROUND_R + 3.0, 0.0, TAU, 40, Palette.JEKYLL, 2.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# The instrument's sketch, in pencil.
	func _draw_lines() -> void:
		var his := ArenaMeans._his(_key)
		var colour := ArenaMeans.WAX_LINE if his else ArenaMeans.PENCIL
		var base := 23000 + hash(_key) % 97
		_lines.draw_set_transform(SIZE * 0.5)
		if not his:
			var ring := Pencil.new(base + 400)
			ring.colour = colour
			ring.min_width = ArenaMeans.MIN_STROKE
			ring.stroke(ArenaMeans._circle(Vector2.ZERO, ArenaMeans.ROUND_R - 2.5, 30), 1.6, 0.2)
			ring.draw(_lines)
		var sketch := Pencil.new(base + 600)
		sketch.colour = colour
		sketch.min_width = ArenaMeans.MIN_STROKE * (1.3 if his else 1.0) / ArenaMeans.SKETCH_SCALE
		_lines.draw_set_transform(SIZE * 0.5, 0.0, Vector2.ONE * ArenaMeans.SKETCH_SCALE)
		_means._instrument(sketch, _key)
		sketch.draw(_lines)
		_lines.draw_set_transform_matrix(Transform2D.IDENTITY)

	# The note's lines, each [words, font, colour].
	func _note_lines() -> Array:
		return [[_title, _heavy, ArenaMeans.INK], [_detail, _plain, ArenaMeans.PENCIL],
				["Enter or a click drops it.", _heavy, ArenaMeans.INK]]

	func _line_height(line: Array) -> float:
		var font: Font = line[1]
		return font.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, NOTE_W - NOTE_PAD * 2.0,
				NOTE_SIZE).y

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
