extends Control
## A bench for the flask, the salt and the instruments (scripts/arena_means.gd): the element
## alone on the arena's page, each part in its place, with keys that run each of its movements. The
## states here are the bench's own, made up to drive the element; the arena takes them from
## the rules.
##
## Keys: Q drinks (the flask tips and empties, then is filled and corked: he has the table, and
## the next drink stains). W takes a dose (a paper is opened and spent). E turns the draught
## refused or not, R the salt. T switches the next drink's cost. A lays the next instrument,
## Z takes the last away. H makes The Cane hop, G the Cheque book glint. B switches the page
## between Jekyll's and Hyde's.
##
## For a screenshot: `tools/shot.sh /abs/out.png res://scenes/arena_means_bench.tscn`, with
## `--state=<start|jekyll|hyde|empty>` (start: the first round, both refused; jekyll: the draught
## can be drunk, salt shut; hyde: corked, salt open; empty: no doses left), `--hyde` for his
## ink, `--ink=<percent>` for how much of the page it takes, `--inst=<key,key,...>`
## (as many as given, past the rules' three),
## `--hover=<flask|salt|key>`, and `--keys=<letters>` with `--wait=<seconds>` to catch a movement
## (and `--freeze` to hold it there for the still).

## Sent when the keys of `--keys` have all been pressed.
signal _pressed

const ALL_INSTRUMENTS: Array[String] = ["spirit", "notebook", "balance", "saucers", "hcane", "cheque"]

@onready var _ink: ArenaInk = $Ink
@onready var _means: ArenaMeans = $Means
@onready var _keys: Label = $Keys

var _run: RulesRun
var _table: Dictionary
var _busy := false
var _jekyll := true
var _said := "-"


func _ready() -> void:
	_jekyll = not Shot.has_arg("hyde")
	_ink.set_ink(_ink_percent(), 50.0, _jekyll)
	_ink.snap_to_stance()
	_run = Rules.new_run()
	_table = RulesView.table(_run)
	match Shot.arg("state"):
		"jekyll":
			_table.draught = {"ok": true, "why": "", "cost": "first"}
			_table.salt = {"doses": 3, "ok": false, "why": "You are yourself."}
			_table.instruments = ["spirit", "notebook"]
		"hyde":
			_table.draught = {"ok": false, "why": "He already has the table.", "cost": "stain"}
			_table.salt = {"doses": 2, "ok": true, "why": ""}
			_table.instruments = ["balance", "hcane", "cheque"]
		"empty":
			_table.draught = {"ok": false, "why": "He already has the table.", "cost": "stain"}
			_table.salt = {"doses": 0, "ok": false, "why": "No doses left."}
			_table.instruments = ["hcane"]
	if Shot.has_arg("inst"):
		_table.instruments = Array(Shot.arg("inst").split(","))
		# More than the rules hold, to show the grid's rows wrap; a key may come twice.
		_means.max_held = maxi(RulesConfig.MAX_INSTRUMENTS, _table.instruments.size())
	_means.show_table(_table, _run.dials)
	_means.preview_changed.connect(func(kind: String) -> void: _say("preview: %s" % (kind if kind != "" else "none")))
	_means.drink_pressed.connect(func() -> void: _say("drink pressed"))
	_means.salt_pressed.connect(func() -> void: _say("salt pressed"))
	if Shot.has_arg("hover"):
		_means.hover(Shot.arg("hover"))
	_show_keys()
	# `--keys=<letters>` presses those keys one after another; the shot is taken when they are
	# done, or `--wait=<seconds>` after they start, to catch one in motion.
	if Shot.has_arg("keys"):
		var done := _press(Shot.arg("keys"))
		if Shot.has_arg("wait"):
			await get_tree().create_timer(float(Shot.arg("wait"))).timeout
			# `--freeze` stops time there, so that the still, taken a few frames later, holds it.
			if Shot.has_arg("freeze"):
				Engine.time_scale = 0.0
		else:
			await done
	Shot.run_if_requested(self)


func _press(keys: String) -> Signal:
	_pressing(keys)
	return _pressed


func _pressing(keys: String) -> void:
	await get_tree().process_frame
	for letter in keys:
		_busy = true
		await _run_key(OS.find_keycode_from_string(letter))
		_busy = false
	_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo or _busy:
		return
	_busy = true
	await _run_key(key.keycode)
	_busy = false


func _run_key(code: Key) -> void:
	var draught: Dictionary = _table.draught
	var salt: Dictionary = _table.salt
	match code:
		KEY_Q:
			await _means.tip_flask()
			draught.ok = false
			draught.why = "He already has the table."
			draught.cost = "stain"
			await _means.set_draught(draught)
		KEY_W:
			await _means.open_paper()
			salt.doses = maxi(int(salt.doses) - 1, 0)
			if salt.doses == 0:
				salt.ok = false
				salt.why = "No doses left."
			await _means.set_salt(salt)
		KEY_E:
			draught.ok = not draught.ok
			draught.why = "" if draught.ok else "No draught works in this scene."
			await _means.set_draught(draught)
		KEY_R:
			salt.ok = not salt.ok and int(salt.doses) > 0
			salt.why = "" if salt.ok else ("No doses left." if int(salt.doses) == 0 else "You are yourself.")
			await _means.set_salt(salt)
		KEY_T:
			draught.cost = "stain" if draught.cost == "first" else "first"
			await _means.set_draught(draught)
		KEY_A:
			var held: Array = _table.instruments
			for key: String in ALL_INSTRUMENTS:
				if not held.has(key) and held.size() < _means.max_held:
					held.append(key)
					break
			await _means.set_instruments(held)
		KEY_Z:
			var held: Array = _table.instruments
			if not held.is_empty():
				held.pop_back()
			await _means.set_instruments(held)
		KEY_H:
			await _means.hop("hcane")
		KEY_G:
			await _means.glint("cheque")
		KEY_B:
			_jekyll = not _jekyll
			_ink.set_ink(_ink_percent(), 50.0, _jekyll)
	_show_keys()


## How much of the page the ink takes: `--ink=<percent>`, 50 by default.
func _ink_percent() -> float:
	return float(Shot.arg("ink")) if Shot.has_arg("ink") else 50.0


func _say(what: String) -> void:
	_said = what
	_show_keys()


func _show_keys() -> void:
	_keys.text = "Q drink   W dose   E draught refused   R salt refused   T cost   A lay instrument   Z take one   H hop   G glint   B page" \
			+ "\nheld: %s   last signal: %s" % [", ".join(_table.instruments), _said]
