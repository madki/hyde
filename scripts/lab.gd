extends Control
## The laboratory, where a run comes at dawn when Jekyll has the table: his table, window and
## chair, bottom left, and in the clear of the room a panel with what the laboratory sells:
## the shelf's cards and instruments, a dose of salt, the instruments held (each can be
## dropped), and Leave, which goes back to the table; there the next night begins.
##
## The page holds no rules. Everything it shows is read from RulesView.place: the prices,
## what is sold, what can be taken and why not. Taking a row calls the rules' own function,
## and the rows are then made again from a fresh record.
##
## The rows are made by `_wares` from the record, and each carries what taking it does in
## `act` (a Callable; the panel does not read it). Another row is one more entry there; a
## row that opens a second list gives the panel that list with `_show(rows, false)` and
## comes back with `_show_wares(false)` (see PlacePanel on showing another list).
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/lab.tscn --seed=3` (see SceneFlow.run_for_place).
## Only then, never in a run that came from the table, it also takes:
##
## - `--purse=<n>`: the purse holds that many sovereigns.
## - `--held=<n>`: that many instruments are held (ones the shelf does not sell).
## - `--keys=ddue`: keys pressed as a player would, in turn: d Down, u Up, e Enter.
## - `--point=700,300`: the pointer moved there, and `--click` a click there.

const WHERE := "lab"
const HEADING := "The Laboratory"
const NOTE := "Up and Down to choose, Enter to take"

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun
## The rows the panel shows, in its order, each with its `act`.
var _rows: Array[Dictionary] = []

@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	var held: RulesRun = SceneFlow.run
	var own := held == null or held.phase != WHERE
	_run = SceneFlow.run_for_place(WHERE)
	if own and _run != null:
		_set_up_still()
	_panel.accent = Palette.JEKYLL
	_panel.dense = true
	_panel.set_heading(HEADING)
	_panel.note = NOTE
	_show_wares(false)
	_panel.row_chosen.connect(_on_row_chosen)
	if own:
		_play_input()
	Shot.run_if_requested(self)


# ---------- the rows ----------

## Shows the laboratory's wares as the run stands now. With `keep` the selection stays where
## it is (after a purchase); without, it goes to the first row.
func _show_wares(keep: bool = true) -> void:
	var place: Variant = RulesView.place(_run) if _run != null else null
	if place == null:
		_show([_leave_row("")], keep)
		return
	_panel.set_purse(int(place.sov), int(place.salt.doses))
	_panel.lead = _dawn_line(place.dawn)
	_show(_wares(place), keep)


## Gives the panel these rows; taking one calls its `act`.
func _show(rows: Array[Dictionary], keep: bool) -> void:
	_rows = rows
	_panel.set_rows(rows, keep)


## The rows of the laboratory's page, from the record of the place (RulesView.place).
func _wares(place: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({section = "Cards"})
	for card: Dictionary in place.cards:
		var detail: String = card.text
		if card.t == "root":
			detail = "A Root of the %s, on paper." % String(card.key).capitalize()
		rows.append(_ware(card, card.name, detail, Rules.buy_card.bind(_run, int(card.index))))
	rows.append({section = "Instruments"})
	for instrument: Dictionary in place.instruments:
		rows.append(_ware(instrument, instrument.name, instrument.text,
				Rules.buy_instrument.bind(_run, int(instrument.index))))
	rows.append({section = "Salt"})
	rows.append(_ware(place.salt, "A dose of salt", "One more dose for the nights ahead.",
			Rules.buy_salt.bind(_run)))
	if not place.held.is_empty():
		rows.append({section = "Held: %d of %d" % [place.held.size(), int(place.slots)]})
		for instrument: Dictionary in place.held:
			rows.append({
				text = "Drop the %s" % _in_a_sentence(instrument.name),
				detail = instrument.text,
				act = _deal.bind(Rules.drop_instrument.bind(_run, String(instrument.key))),
			})
	rows.append(_leave_row("Night %d: %s." % [int(place.night.no), place.night.title]))
	return rows


## A row for something on offer: the rules' price, whether it is sold, whether it can be
## taken and why not, all from the record. `move` is the rules' function that takes it.
func _ware(offer: Dictionary, text: String, detail: String, move: Callable) -> Dictionary:
	return {
		text = text,
		price = int(offer.price),
		enabled = bool(offer.ok),
		sold = bool(offer.get("sold", false)),
		why = String(offer.why),
		detail = detail,
		act = _deal.bind(move),
	}


func _leave_row(detail: String) -> Dictionary:
	return {text = "Leave", detail = detail, act = _leave}


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


## A name as it stands inside a sentence: "the notebook", but "the Cane" stays as it is
## when the name brings its own article.
func _in_a_sentence(item: String) -> String:
	if item.begins_with("The "):
		return item.trim_prefix("The ")
	return item.to_lower()


# ---------- taking a row ----------

func _on_row_chosen(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var act: Callable = _rows[index].get("act", Callable())
	if act.is_valid():
		act.call()


## Makes a move in the rules (`move` returns their answer) and shows the wares as they then
## stand. A refusal's reason is shown in the note.
func _deal(move: Callable) -> void:
	var result: Dictionary = move.call()
	_panel.note = NOTE if result.ok else String(result.get("reason", NOTE))
	_show_wares()


## Back to the table, which leaves the laboratory in the rules and begins the next night.
func _leave() -> void:
	SceneFlow.back_to_table()


# ---------- run on its own ----------

## The purse and the rack asked for on the command line, for a still.
func _set_up_still() -> void:
	if Shot.has_arg("purse"):
		_run.sov = maxi(0, int(Shot.arg("purse")))
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


## Plays the input asked for on the command line through the game's own input.
func _play_input() -> void:
	const KEYS := {"d": KEY_DOWN, "u": KEY_UP, "e": KEY_ENTER}
	for letter in Shot.arg("keys"):
		if not KEYS.has(letter):
			continue
		var key := InputEventKey.new()
		key.keycode = KEYS[letter]
		key.pressed = true
		Input.parse_input_event(key)
	var given := Shot.arg("point").split(",")
	if given.size() != 2:
		return
	var point := Vector2(float(given[0]), float(given[1]))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	if Shot.has_arg("click"):
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = true
		button.position = point
		button.global_position = point
		Input.parse_input_event(button)
