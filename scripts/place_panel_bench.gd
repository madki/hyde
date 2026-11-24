extends Control
## Shows the place panel with every kind of row, to check it in a still or by hand:
## `tools/shot.sh /abs/panel.png res://scenes/place_panel_bench.tscn [args]`, or run the
## scene and use it: taking a priced row buys it (the rows are given again), "See the deck"
## opens a second, long list and Escape comes back from it.
##
## - (no argument): the alley's page, in Hyde's light: a purse, an opening line, section
##   headings, rows plain, priced, free, too dear, sold and taken, second lines, a note.
## - `--lab`: the laboratory's picture and Jekyll's light, the panel on its clear side.
## - `--long`: the longest page there will be (the laboratory with three instruments held),
##   to see it fit or scroll.
## - `--jekyll`: Jekyll's light whatever the page.
## - `--select=7`: the selection on that row (as `select` does), `--deck` the second list.
## - `--again`: the rows are given a second time, as after a purchase.
## - `--keys=ddue`: keys pressed as a player would, in turn: d Down, u Up, e Enter,
##   x Escape. `--wheel=3`: the mouse wheel turned that many steps down (negative: up) over
##   the panel. `--point=200,300`: the pointer moved there, and `--click` a click there.
## - `--narrow`: the panel at its least width; `--loose`: rows as far apart as the title's.

const NOTE := "Up and Down to choose, Enter to take"
const TOP := 16.0 # the highest the panel is put
const DECK_NOTE := "Escape to go back"

var _sovereigns := 7
var _salt := 2
var _wares: Array[Dictionary] = []
var _in_deck := false
var _opened_from := -1

@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	var lab := Shot.has_arg("lab")
	$Lab.visible = lab
	$Alley.visible = not lab
	_panel.accent = Palette.JEKYLL if lab or Shot.has_arg("jekyll") else Palette.HYDE
	# The clear side of each picture: left of Hyde's door, right of Jekyll's table.
	_panel.position = Vector2(620.0 if lab else 72.0, TOP)
	_panel.dense = not Shot.has_arg("loose")
	if not Shot.has_arg("narrow"):
		_panel.size.x = 440.0
	_wares = _long_wares() if Shot.has_arg("long") else _alley_wares()
	_panel.set_heading("The laboratory" if Shot.has_arg("long") else "The back door")
	_panel.lead = "The dawn brought seven sovereigns and a letter that asks after the doctor."
	_panel.note = NOTE
	_show_wares()
	if Shot.has_arg("deck"):
		_open_deck(_panel.selected())
	if Shot.has_arg("select"):
		_panel.select(int(Shot.arg("select")))
	if Shot.has_arg("again"):
		_show_wares()
	# A short list sits in the middle of the window's height.
	_panel.position.y = maxf(TOP, (get_viewport_rect().size.y - _panel.size.y) * 0.5)
	_panel.row_chosen.connect(_on_row_chosen)
	_panel.back.connect(_on_back)
	_play_input()
	Shot.run_if_requested(self)


func _alley_wares() -> Array[Dictionary]:
	return [
		{section = "Cards"},
		{text = "Night Walk", price = 4,
				detail = "Hyde walks until the lamps go out: two Craving on the Lamp, and draw a card."},
		{text = "Black tonic", price = 12, detail = "The next dose of salt costs nothing."},
		{text = "Old Debt", sold = "sold", why = "Sold to another caller before you came.",
				detail = "Pay a sovereign, or take one Temper on the Heart."},
		{text = "A torn page", price = 0, detail = "Left on the step. Nobody is asking for it."},
		{section = "Instruments"},
		{text = "Brass scales", price = 6,
				detail = "At dawn, if both sides are level, a sovereign more."},
		{text = "Cracked lens", sold = "taken", why = "You hold it already."},
		{section = "The door"},
		{text = "See the deck", deck = true},
		{text = "Strike a card", enabled = false, why = "There is no card in the deck to strike."},
		{text = "Back to the street"},
	]


func _long_wares() -> Array[Dictionary]:
	return [
		{section = "Cards"},
		{text = "Night Walk", price = 4,
				detail = "Hyde walks until the lamps go out: two Craving on the Lamp, and draw a card."},
		{text = "A Steady Hand", price = 5, detail = "Jekyll: one Temper off the Mirror."},
		{text = "Black tonic", price = 12, detail = "The next dose of salt costs nothing."},
		{section = "Instruments"},
		{text = "Brass scales", price = 6,
				detail = "At dawn, if both sides are level, a sovereign more."},
		{text = "Spirit lamp", price = 9, detail = "The first card of a night is played twice."},
		{section = "The still"},
		{text = "A dose of salt", price = 3, detail = "One more dose for the night ahead."},
		{text = "Strike a card", price = 2, deck = true,
				detail = "Take one card out of the deck for good."},
		{section = "Held"},
		{text = "Drop the cracked lens", detail = "Makes room for another instrument."},
		{text = "Drop the bone saw", detail = "Makes room for another instrument."},
		{text = "Drop the retort", detail = "Makes room for another instrument."},
		{text = "Leave"},
	]


## The wares as they stand with this purse: what costs more than is held is too dear.
func _show_wares() -> void:
	var rows: Array[Dictionary] = []
	for ware in _wares:
		var row := ware.duplicate()
		if int(row.get("price", -1)) > _sovereigns and not row.has("sold"):
			row.enabled = false
			row.why = "It costs %d sovereigns: you hold %d." % [row.price, _sovereigns]
		rows.append(row)
	_panel.set_purse(_sovereigns, _salt)
	_panel.set_rows(rows)


## A second list on the same panel: the whole deck, grouped.
func _open_deck(from: int) -> void:
	_in_deck = true
	_opened_from = from
	var rows: Array[Dictionary] = []
	for group: String in ["Lamp", "Heart", "Mirror"]:
		rows.append({section = group})
		for i in 8:
			rows.append({text = "%s card %d" % [group, i + 1],
					detail = "What the card does, in a line of small writing."})
	_panel.note = DECK_NOTE
	_panel.set_rows(rows, false)


func _on_back() -> void:
	if not _in_deck:
		print("Back")
		return
	_in_deck = false
	_panel.note = NOTE
	_panel.set_rows([], false)
	_show_wares()
	_panel.select(_opened_from)


func _on_row_chosen(index: int) -> void:
	print("Chosen: ", index)
	if _in_deck:
		_on_back()
		return
	var ware := _wares[index]
	if ware.has("deck"):
		_open_deck(index)
	elif ware.has("price"):
		_sovereigns -= int(ware.price)
		if String(ware.text).contains("salt"):
			_salt += 1
		else:
			ware.sold = "sold"
			ware.why = "You have bought it."
		_show_wares()


## Plays the input asked for on the command line through the game's own input, to check
## the keys and the mouse in a still.
func _play_input() -> void:
	const KEYS := {"d": KEY_DOWN, "u": KEY_UP, "e": KEY_ENTER, "x": KEY_ESCAPE}
	for letter in Shot.arg("keys"):
		if not KEYS.has(letter):
			continue
		var key := InputEventKey.new()
		key.keycode = KEYS[letter]
		key.pressed = true
		Input.parse_input_event(key)
	var point := _panel.position + Vector2(_panel.size.x * 0.5, _panel.size.y * 0.6)
	var given := Shot.arg("point").split(",")
	if given.size() == 2:
		point = Vector2(float(given[0]), float(given[1]))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		Input.parse_input_event(motion)
	var presses: Array[MouseButton] = []
	if Shot.has_arg("click"):
		presses.append(MOUSE_BUTTON_LEFT)
	var steps := int(Shot.arg("wheel"))
	for i in absi(steps):
		presses.append(MOUSE_BUTTON_WHEEL_DOWN if steps > 0 else MOUSE_BUTTON_WHEEL_UP)
	for pressed in presses:
		var button := InputEventMouseButton.new()
		button.button_index = pressed
		button.pressed = true
		button.position = point
		button.global_position = point
		Input.parse_input_event(button)
