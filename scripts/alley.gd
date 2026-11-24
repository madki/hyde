extends Control
## The back alley, where a run comes at dawn when Hyde has the table: Hyde letting himself in
## by the door, bottom right, and in the clear of the street a panel with what the alley
## offers him. Everything on it is read from RulesView.place and read again after each move;
## the page asks the rules for every move and has none of its own:
##
## - a Habit, free, once, on one of the symbols he has a Root of (Rules.alley_habit);
## - one of his instruments, free, once, if there is room for it (Rules.alley_instrument);
## - salt from the street chemist, at the alley's price (Rules.alley_salt);
## - the instruments held, each to drop (Rules.drop_instrument), listed after his;
## - Leave, back to the table (SceneFlow.back_to_table): the table leaves the alley in the
##   rules and begins the next night.
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/alley.tscn --seed=3` (see SceneFlow.run_for_place).
## That run, and never one that came from the table, can be dressed for a still:
##
## - `--purse=<n>`: the sovereigns held.
## - `--held=<n>`: that many instruments held (the laboratory's first, then his), up to a
##   full rack.
## - `--taken`: the free offers already taken, as far as the rules allow: the first Habit and
##   the first instrument.
## - `--select=<n>`: the selection on that row of the panel.

const WHERE := "alley"
const HEADING := "The Back Alley"
const NOTE := "Up and Down to choose, Enter to take"
const TOP := 8.0 # the highest the panel is put, and the room kept under it

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun
## What each row of the panel does when taken, by the row's index: {} for a row that does
## nothing (a section heading), else {act: String, arg: String}.
var _acts: Array[Dictionary] = []

@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	var own := SceneFlow.run == null or SceneFlow.run.phase != WHERE
	_run = SceneFlow.run_for_place(WHERE)
	if own and _run != null:
		_dress_for_still()
	_panel.accent = Palette.HYDE
	_panel.dense = true
	_panel.set_heading(HEADING)
	_panel.note = NOTE
	_panel.row_chosen.connect(_on_row_chosen)
	_panel.back.connect(_on_back)
	get_viewport().size_changed.connect(_place_panel)
	_show(false)
	if own and Shot.has_arg("select"):
		_panel.select(int(Shot.arg("select")))
	Shot.run_if_requested(self)


# Reads the alley's record and gives the panel its rows from it.
func _show(keep_selection: bool = true) -> void:
	var place: Variant = RulesView.place(_run) if _run != null else null
	var rows: Array[Dictionary] = []
	_acts.clear()
	if place == null or place.where != WHERE:
		_panel.lead = ""
		_add(rows, {text = "Leave"}, "leave")
	else:
		_panel.set_purse(place.sov, place.salt.doses)
		_panel.lead = _lead(place)
		_add_habit(rows, place)
		_add_instruments(rows, place)
		_add_held(rows, place)
		_add(rows, {section = "The street chemist"})
		_add(rows, {text = "A dose of salt", price = place.salt.price, enabled = place.salt.ok,
				why = place.salt.why, detail = "You hold %s." % _count(place.salt.doses, "dose")},
				"salt")
		_add(rows, {text = "Leave", detail = "On to night %d: %s." % [place.night.no,
				place.night.title]}, "leave")
	_place_panel()
	_panel.set_rows(rows, keep_selection)
	_place_panel()


func _add(rows: Array[Dictionary], row: Dictionary, act: String = "", arg: String = "") -> void:
	rows.append(row)
	_acts.append({act = act, arg = arg} if act != "" else {})


# What the dawn brought, as the panel's opening line.
func _lead(place: Dictionary) -> String:
	var dawn: Dictionary = place.dawn
	var lines := "Dawn %d." % dawn.no
	if dawn.brings_name != "":
		lines = "Dawn %d brought two more %s." % [dawn.no, dawn.brings_name]
	if dawn.unlocks_name != "":
		lines += " The laboratory may sell %s now." % dawn.unlocks_name
	return lines


# His free Habit: a row for each symbol it can go on.
func _add_habit(rows: Array[Dictionary], place: Dictionary) -> void:
	_add(rows, {section = "A Habit, on one of his Roots"})
	if place.habit.is_empty():
		_add(rows, {text = "No Habit to take", enabled = false,
				why = "None of his Roots is in the deck."})
		return
	var dials := _run.dials
	var settled: bool = place.taken.habit != ""
	for o: Dictionary in place.habit:
		var label: String = RulesConfig.ROOT[o.sym].label
		var row := _offer_row("%s, on the %s" % [o.name, label], o, settled)
		var gauge := "%d now" % o.habit if settled else "%d now, %d more here" % [o.habit, o.adds]
		row.detail = ("Habit on the %s: %s. Each point makes every %s worth %d more chips, "
				+ "and gives %d mult for each one he plays.") % [label, gauge, o.name,
				dials.habit_chips, dials.habit_mult]
		_add(rows, row, "habit", o.sym)


# The instruments: his on offer, one of them only, under a heading that also counts the rack.
func _add_instruments(rows: Array[Dictionary], place: Dictionary) -> void:
	var rack := "held: %d of %d" % [place.held.size(), place.slots]
	if place.instruments.is_empty():
		_add(rows, {section = "Instruments (%s)" % rack})
	else:
		_add(rows, {section = "One of his instruments (%s)" % rack})
	for o: Dictionary in place.instruments:
		var row := _offer_row(o.name, o, place.taken.instrument != "")
		row.detail = o.text
		_add(rows, row, "instrument", o.key)


# A free offer's row. Once one of its kind is taken (`settled`), the one taken shows as
# taken and the others as gone.
func _offer_row(text: String, o: Dictionary, settled: bool) -> Dictionary:
	var row := {text = text, price = 0, enabled = o.ok, why = o.why}
	if o.taken:
		row.sold = "taken"
	elif settled:
		row.sold = "gone"
	return row


# The instruments held, each to drop, under the instruments' heading.
func _add_held(rows: Array[Dictionary], place: Dictionary) -> void:
	if place.held.is_empty() and place.instruments.is_empty():
		_add(rows, {text = "None held", enabled = false, why = "No instrument is held."})
	for o: Dictionary in place.held:
		_add(rows, {text = "Drop the %s" % _plain(o.name), detail = "%s Dropped, it is gone."
				% o.text}, "drop", o.key)


# An instrument's name as it reads after "the".
func _plain(text: String) -> String:
	return text.trim_prefix("The ")


func _count(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]


func _on_row_chosen(index: int) -> void:
	if index < 0 or index >= _acts.size() or _acts[index].is_empty():
		return
	var act: Dictionary = _acts[index]
	var result := {"ok": true}
	match act.act:
		"leave":
			SceneFlow.back_to_table()
			return
		"habit":
			result = Rules.alley_habit(_run, act.arg)
		"instrument":
			result = Rules.alley_instrument(_run, act.arg)
		"salt":
			result = Rules.alley_salt(_run)
		"drop":
			result = Rules.drop_instrument(_run, act.arg)
	# A move the rules refuse although its row could be taken: their reason is shown.
	_panel.note = NOTE if result.ok else String(result.get("reason", "Not now."))
	_show()


# Escape: the selection goes to Leave.
func _on_back() -> void:
	_panel.select(_acts.size() - 1)


# The panel in the clear of the street, left of the door: in the middle of the window's
# height, and no taller than the window.
func _place_panel() -> void:
	var height := get_viewport_rect().size.y
	_panel.max_height = height - 2.0 * TOP
	_panel.position.y = maxf(TOP, (height - _panel.size.y) * 0.5)


# Dresses a run the page made for itself as the command line asks, for a still.
func _dress_for_still() -> void:
	if Shot.has_arg("purse"):
		_run.sov = maxi(0, int(Shot.arg("purse")))
	if Shot.has_arg("held"):
		var keys: Array = RulesConfig.LAB_INSTRUMENTS + RulesConfig.HIS_INSTRUMENTS
		var count := clampi(int(Shot.arg("held")), 0, RulesConfig.MAX_INSTRUMENTS)
		_run.instruments.clear()
		for key: String in keys.slice(0, count):
			_run.instruments.append(key)
	if Shot.has_arg("taken"):
		var place: Dictionary = RulesView.place(_run)
		if not place.habit.is_empty():
			Rules.alley_habit(_run, place.habit[0].sym)
		if not place.instruments.is_empty():
			Rules.alley_instrument(_run, place.instruments[0].key)
