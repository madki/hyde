extends Control
## The back alley, where a run comes at dawn when Hyde has the table: Hyde letting himself in
## by the door, bottom right, and in the clear of the street a sheet of his own (ShopSheet,
## "hyde" tone) with what the alley offers him laid on it as a shelf. Everything on it is
## read from RulesView.place and read again after each move; the page asks the rules for
## every move and has none of its own. From the top:
##
## - the header: the place, the purse and the salt;
## - the deck's strip (ShopDeckStrip): its count and its Paper:Ink gauge; a click, Enter or D
##   opens the deck;
## - "Cards": his free Habit, once, as one slot for each symbol he has a Root of, the Root
##   drawn as the table draws it (Rules.alley_habit). Beside the row is written what the dawn
##   brought and what the Habit under the pointer or the keys does;
## - "Instruments & salt": his instruments, one of them free, once, if there is room for it
##   (Rules.alley_instrument), and salt from the street chemist at the alley's price
##   (Rules.alley_salt);
## - "Held": the instruments held, each to drop (Rules.drop_instrument), and the free places
##   of the rack as empty outlines;
## - Leave, back to the table (SceneFlow.back_to_table): the table leaves the alley in the
##   rules and begins the next night.
##
## A ware that is taken leaves its slot empty, and so do the others of its kind, since one of
## a kind is given. The arrows go from slot to slot (ShopKeys.wire), Enter or a click takes,
## and Escape goes to Leave.
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/alley.tscn --seed=3` (see SceneFlow.run_for_place).
## That run, and never one that came from the table, can be dressed for a still:
##
## - `--taken`: the free offers already taken, as far as the rules allow: the first Habit and
##   the first instrument.
## - `--deck`: the deck opened.
## - `--purse`, `--held`, `--select`, `--press`, `--point` and `--click`, as ShopKeys says.

const WHERE := "alley"
const HEADING := "The back alley"
const HINT := "Arrows to choose, Enter to take. D opens the deck."
## The sheet, in the part of the page the picture leaves free: from the window's left edge,
## and from its top and its bottom.
const LEFT := 48.0
const WIDTH := 628.0
const EDGE := 8.0
const CARD_GAP := 10.0
## From a group of the lower row to the rule that splits it from the next.
const GROUP_GAP := 14.0
## The least and the most room left between the rows.
const ROW_GAP_LEAST := 4.0
const ROW_GAP_MOST := 30.0
const TEXT_SIZE := 13
const HINT_SIZE := 12
const HINT_ROOM := 26.0

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun
## The alley's record as it was last read, {} with no run at the alley.
var _place := {}
## The slots by what they hold: "habit:<symbol>", "instrument:<key>", "salt", "held:<key>",
## "free:<n>".
var _wares := {}
## The slots of the cards' row, of the lower row's first group and of the held group, as
## they lie from the left.
var _cards: Array[ShopWare] = []
var _goods: Array[ShopWare] = []
var _held: Array[ShopWare] = []
## The slot the pointer or the keys are on, "" for none.
var _lit := ""
## Why the rules refused the last move, "" if they did not.
var _refusal := ""
## Where the writing beside the cards goes, and the hint under the lower row, on the sheet.
var _text_box := Rect2()
var _hint_at := Vector2.ZERO
## True while the page sets itself up or shows a move: a slot lit then makes no sound.
var _quiet := true
var _strip := ShopDeckStrip.new()
## The page's own writing on the sheet.
var _words := Control.new()
var _heavy := FontVariation.new()
var _plain: Font = ThemeDB.fallback_font

@onready var _sheet: ShopSheet = $Sheet


func _ready() -> void:
	Music.enter("alley")
	var own := SceneFlow.run == null or SceneFlow.run.phase != WHERE
	_run = SceneFlow.run_for_place(WHERE)
	if own and _run != null:
		_dress_for_still()
	_heavy.base_font = ThemeDB.fallback_font
	_heavy.variation_embolden = 0.6
	_sheet.tone = "hyde"
	_sheet.set_place(HEADING)
	_sheet.leave.connect(_on_leave)
	_sheet.add_child(_strip)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.draw.connect(_draw_words)
	_sheet.add_child(_words)
	get_viewport().size_changed.connect(_lay_out)
	_show()
	_focus_first()
	if own:
		ShopKeys.select(_stops())
		if Shot.has_arg("deck"):
			_strip.open()
		_quiet = false
		await ShopKeys.play(self)
	_quiet = false
	Shot.run_if_requested(self)


func _unhandled_key_input(event: InputEvent) -> void:
	# Escape: the keys go to Leave. (An open deck takes Escape first, to close.)
	if event.is_action_pressed("ui_cancel") and not _strip.is_open():
		get_viewport().set_input_as_handled()
		ShopKeys.hover(true)
		_sheet.leave_button.grab_focus()


# --- The shelf ------------------------------------------------------------------------------


# Reads the alley's record and sets every slot from it.
func _show() -> void:
	var place: Variant = RulesView.place(_run) if _run != null else null
	var seen := {}
	_cards.clear()
	_goods.clear()
	_held.clear()
	if place == null or place.where != WHERE:
		_place = {}
		_sheet.set_leave("")
	else:
		_place = place
		_sheet.set_purse(place.sov, place.salt.doses)
		_sheet.set_leave("Night %d: %s" % [place.night.no, place.night.title])
		_strip.show_run(_run)
		_show_habits(seen)
		_show_goods(seen)
		_show_held(seen)
	for id: String in _wares.keys():
		if not seen.has(id):
			var gone: ShopWare = _wares[id]
			_wares.erase(id)
			_sheet.remove_child(gone)
			gone.queue_free()
			if _lit == id:
				_lit = ""
	_lay_out()


# His free Habit: a slot for each symbol it can go on, showing his Root of that symbol.
func _show_habits(seen: Dictionary) -> void:
	var settled: bool = _place.taken.habit != ""
	for o: Dictionary in _place.habit:
		var id := "habit:%s" % o.sym
		var fresh := not _wares.has(id)
		var ware := _ware(id, seen, "habit", o.sym)
		if fresh:
			var root := RulesCard.make(0, o.sym, true)
			ware.show_card(RulesView.entry(_run, root, "hyde"), 3 + _cards.size() * 7)
		_set_free(ware, o, settled)
		_cards.append(ware)


# His instruments, one of them to take, and the street chemist's salt.
func _show_goods(seen: Dictionary) -> void:
	var settled: bool = _place.taken.instrument != ""
	for o: Dictionary in _place.instruments:
		var id := "instrument:%s" % o.key
		var fresh := not _wares.has(id)
		var ware := _ware(id, seen, "instrument", o.key)
		if fresh:
			ware.show_instrument(o.key, o.name, o.text)
		_set_free(ware, o, settled)
		_goods.append(ware)
	var salt := _ware("salt", seen, "salt", "")
	salt.show_salt("A dose of salt", "You hold %d dose%s." % [_place.salt.doses,
			"" if _place.salt.doses == 1 else "s"])
	salt.set_offer(_place.salt, _place.sov)
	_goods.append(salt)


# The rack: the instruments held, each to drop, then its free places.
func _show_held(seen: Dictionary) -> void:
	for o: Dictionary in _place.held:
		var id := "held:%s" % o.key
		var fresh := not _wares.has(id)
		var ware := _ware(id, seen, "drop", o.key)
		if fresh:
			ware.show_instrument(o.key, o.name, "%s Dropped, it is gone." % o.text)
		_held.append(ware)
	for i: int in _place.slots_free:
		var id := "free:%d" % i
		var fresh := not _wares.has(id)
		var ware := _ware(id, seen, "", "")
		if fresh:
			ware.show_instrument("")
			ware.set_state(ShopWare.State.BOUGHT, "", "empty")
		_held.append(ware)


# The slot that holds `id`, made if it is not there yet. Taken, it asks the rules for `act`
# with `arg`.
func _ware(id: String, seen: Dictionary, act: String, arg: String) -> ShopWare:
	seen[id] = true
	if _wares.has(id):
		return _wares[id]
	var ware := ShopWare.new()
	ware.accent = Palette.HYDE
	ware.chosen.connect(_on_chosen.bind(act, arg))
	ware.refused.connect(_on_refused)
	ware.lit_changed.connect(_on_lit.bind(id))
	_sheet.add_child(ware)
	_wares[id] = ware
	return ware


# A free offer's slot. Once one of its kind is taken (`settled`), the one taken is left
# empty as taken and the others as gone.
func _set_free(ware: ShopWare, o: Dictionary, settled: bool) -> void:
	ware.set_price(0)
	if o.taken:
		ware.set_state(ShopWare.State.BOUGHT, "", "taken")
	elif settled:
		ware.set_state(ShopWare.State.BOUGHT, "", "gone")
	elif o.ok:
		ware.set_state(ShopWare.State.AVAILABLE)
	else:
		ware.set_state(ShopWare.State.NOT_ALLOWED, o.why)


# --- Where things are -----------------------------------------------------------------------


# Puts the sheet in the clear of the street and lays the strip, the rows and their headings
# on it.
func _lay_out() -> void:
	var window := get_viewport_rect().size
	_sheet.position = Vector2(LEFT, EDGE)
	_sheet.size = Vector2(minf(WIDTH, window.x - LEFT - EDGE), window.y - 2.0 * EDGE)
	_words.size = _sheet.size
	var room := _sheet.room()
	_strip.position = room.position
	_strip.size = Vector2(room.size.x, ShopDeckStrip.HEIGHT)
	var rows := ShopDeckStrip.HEIGHT + 2.0 * ShopSheet.HEADING_HEIGHT + ShopWare.CARD_SLOT.y \
			+ ShopWare.SMALL_SLOT.y + HINT_ROOM
	var gap := clampf((room.size.y - rows) / 3.0, ROW_GAP_LEAST, ROW_GAP_MOST)
	var headings: Array = []
	var dividers: Array = []

	# The cards, from the left, and the writing in the room they leave.
	var y := room.position.y + ShopDeckStrip.HEIGHT + gap
	headings.append({text = "Cards", at = Vector2(room.position.x, y), width = room.size.x})
	y += ShopSheet.HEADING_HEIGHT
	var x := room.position.x
	for ware in _cards:
		ware.position = Vector2(x, y)
		x += ShopWare.CARD_SLOT.x + CARD_GAP
	var cards_box := Rect2(room.position.x, y, maxf(x - CARD_GAP - room.position.x, 0.0), ArenaCard.SIZE.y)
	_sheet.wares = cards_box.grow_individual(0.0, 0.0, 0.0, ShopWare.CARD_AT.y)
	if not _cards.is_empty():
		x += 8.0
	_text_box = Rect2(x, y + ShopWare.CARD_AT.y, room.end.x - x, ArenaCard.SIZE.y)

	# The lower row: what he may take from the left, the rack against the right edge.
	y += ShopWare.CARD_SLOT.y + gap
	var count := _goods.size() + _held.size()
	var pitch := minf(ShopWare.SMALL_SLOT.x, (room.size.x - 2.0 * GROUP_GAP) / maxf(count, 1.0))
	var inset := (pitch - ShopWare.SMALL_SLOT.x) * 0.5
	var held_left := room.end.x - _held.size() * pitch
	var slots_top := y + ShopSheet.HEADING_HEIGHT
	for i in _goods.size():
		_goods[i].position = Vector2(room.position.x + i * pitch + inset, slots_top)
	for i in _held.size():
		_held[i].position = Vector2(held_left + i * pitch + inset, slots_top)
	if _held.is_empty():
		headings.append({text = "Instruments & salt", at = Vector2(room.position.x, y), width = room.size.x})
	else:
		var split := held_left - GROUP_GAP
		headings.append({text = "Instruments & salt", at = Vector2(room.position.x, y),
				width = split - GROUP_GAP - room.position.x})
		headings.append({text = "Held · %d of %d" % [_place.held.size(), _place.slots],
				at = Vector2(held_left, y), width = room.end.x - held_left})
		dividers.append([Vector2(split, y), Vector2(split, slots_top + ShopWare.SMALL_SLOT.y)])
	_hint_at = Vector2(room.position.x, slots_top + ShopWare.SMALL_SLOT.y + 8.0)
	_sheet.set_headings(headings)
	_sheet.set_dividers(dividers)
	_words.queue_redraw()
	ShopKeys.wire(_key_rows())


# The page's writing: beside the cards what the dawn brought and what the Habit does, "drop"
# under each instrument held, and at the foot of the row the keys or the rules' refusal.
func _draw_words() -> void:
	if _place.is_empty():
		return
	var y := _text_box.position.y
	if _text_box.size.x >= 120.0:
		y = _write(_lead(), _plain, Palette.CHALK_2, y) + 8.0
		y = _write(_habit_heading(), _heavy, Palette.HYDE, y) + 2.0
		_write(_habit_text(), _plain, Palette.CHALK, y)
	var tile := ShopWare.TILE
	for ware in _held:
		if ware.state() == ShopWare.State.BOUGHT:
			continue
		var base := ware.position.y + tile.end.y + ShopWare.TAG_GAP + _plain.get_ascent(TEXT_SIZE) + 2.0
		_words.draw_string(_plain, Vector2(ware.position.x, base), "drop", HORIZONTAL_ALIGNMENT_CENTER,
				ware.size.x, TEXT_SIZE, Palette.CHALK if ware.is_lit() else Palette.CHALK_2)
	var foot := _refusal if _refusal != "" else HINT
	_words.draw_string(_heavy if _refusal != "" else _plain, _hint_at + Vector2(0.0, _plain.get_ascent(HINT_SIZE)),
			foot, HORIZONTAL_ALIGNMENT_LEFT, _sheet.room().size.x, HINT_SIZE,
			Palette.WARN if _refusal != "" else Palette.CHALK_3)


# Writes `text` in the box beside the cards, its top at `top`. Returns where it ends.
func _write(text: String, font: Font, colour: Color, top: float) -> float:
	if text == "":
		return top
	var width := _text_box.size.x
	_words.draw_multiline_string(font, Vector2(_text_box.position.x, top + font.get_ascent(TEXT_SIZE)), text,
			HORIZONTAL_ALIGNMENT_LEFT, width, TEXT_SIZE, -1, colour)
	return top + font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, TEXT_SIZE).y


# What the dawn brought.
func _lead() -> String:
	var dawn: Dictionary = _place.dawn
	var lines := "Dawn %d." % dawn.no
	if dawn.brings_name != "":
		lines = "Dawn %d brought two more %s." % [dawn.no, dawn.brings_name]
	if dawn.unlocks_name != "":
		lines += " The laboratory may sell %s now." % dawn.unlocks_name
	return lines


# The Habit the pointer or the keys are on, {} for none.
func _lit_habit() -> Dictionary:
	for o: Dictionary in _place.habit:
		if _lit == "habit:%s" % o.sym:
			return o
	return {}


func _habit_heading() -> String:
	var o := _lit_habit()
	if o.is_empty():
		return "A Habit, free"
	return "Habit on the %s" % RulesConfig.ROOT[o.sym].label


func _habit_text() -> String:
	if _place.habit.is_empty():
		return "No Habit to take: none of his Roots is in the deck."
	var dials := _run.dials
	var o := _lit_habit()
	if o.is_empty():
		if _place.taken.habit != "":
			return "Taken, on the %s." % RulesConfig.ROOT[_place.taken.habit].label
		return ("One, on one of his Roots. Each point of Habit makes every Root of that symbol "
				+ "worth %d more chips, and gives %d mult for each one he plays.") % [
				dials.habit_chips, dials.habit_mult]
	return ("%d now, %d more here. Each point makes every %s worth %d more chips, and gives "
			+ "%d mult for each one he plays.") % [o.habit, o.adds, o.name, dials.habit_chips,
			dials.habit_mult]


# --- The keys -------------------------------------------------------------------------------


# Every control the keys can be on, in rows from the top, each row from the left.
func _key_rows() -> Array:
	return ShopKeys.rows([[_strip], _cards, _goods + _held, [_sheet.leave_button]])


# The slots the keys can be on and then Leave, without the deck's strip: what `--select`
# counts, and where the focus may go on to from a slot that was emptied.
func _stops() -> Array[Control]:
	return ShopKeys.stops(_key_rows().slice(1))


# The keys begin on the first ware he can take, or on Leave when there is none.
func _focus_first() -> void:
	ShopKeys.focus_first(_cards + _goods, _sheet.leave_button)


# --- Moves ----------------------------------------------------------------------------------


func _on_chosen(act: String, arg: String) -> void:
	var result := {"ok": true}
	match act:
		"habit":
			result = Rules.alley_habit(_run, arg)
		"instrument":
			result = Rules.alley_instrument(_run, arg)
		"salt":
			result = Rules.alley_salt(_run)
		"drop":
			result = Rules.drop_instrument(_run, arg)
	if not result.ok:
		Sfx.play("refuse")
	else:
		# Taken, not bought: a hand sliding it off a ledge. The chemist's salt is paid for.
		Sfx.play({"salt": "buy", "drop": "lock"}.get(act, "take"), 0.7 if act == "drop" else 1.0)
	# A move the rules refuse although its slot could be taken: their reason is shown.
	_refusal = "" if result.ok else String(result.get("reason", "Not now."))
	# The slots are set again and the focus put where it belongs, once, with no slot's sound
	# over the move's own.
	var from := get_viewport().gui_get_focus_owner()
	var spot := ShopKeys.middle(from)
	_quiet = true
	_show()
	ShopKeys.keep_focus(self, from, spot, _stops(), _sheet.leave_button)
	_quiet = false


# A slot that cannot be taken was pressed: its own note says why.
func _on_refused(_why: String) -> void:
	Sfx.play("refuse")


func _on_lit(lit: bool, id: String) -> void:
	if lit:
		_lit = id
		if not _quiet:
			ShopKeys.hover(true)
	elif _lit == id:
		_lit = ""
	_words.queue_redraw()


func _on_leave() -> void:
	Sfx.play("button")
	SceneFlow.back_to_table()


# Dresses a run the page made for itself as the command line asks, for a still.
func _dress_for_still() -> void:
	ShopKeys.dress(_run)
	if Shot.has_arg("taken"):
		var place: Dictionary = RulesView.place(_run)
		if not place.habit.is_empty():
			Rules.alley_habit(_run, place.habit[0].sym)
		if not place.instruments.is_empty():
			Rules.alley_instrument(_run, place.instruments[0].key)
