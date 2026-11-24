extends Control
## The round's numbers alone on the page, to look at them and their calls without the rest of
## the arena (scripts/arena_numbers.gd), with PLAY and DISCARD to hold the tallies. C runs every call once in a debug build.
##
## For a screenshot, `--numbers=<moment>` stops the demo at one moment: rest, reason, choice,
## scoring, total, or end (`tools/shot.sh /abs/out.png res://scenes/arena_numbers_preview.tscn --numbers=total`).
## `--hyde` gives Hyde the table. `--bloom=<seconds>` sends a total to the score and holds the
## page that long after it lands, to see the score's bloom (with `--calm`, reduce flashes on).

@onready var _ink: ArenaInk = $Ink
@onready var _numbers: ArenaNumbers = $Numbers
## PLAY and DISCARD, which hold the tallies of the plays and discards left, as in the arena.
var _controls := ArenaControls.new()


func _ready() -> void:
	var jekyll := not Shot.has_arg("hyde")
	_ink.set_ink(30.0, 40.0, jekyll)
	_ink.snap_to_stance()
	var table := RulesView.table(Rules.new_run({}, 1))
	_numbers.show_table(table)
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_controls)
	_controls.hold_tallies(_numbers)
	_controls.show_table(table, 0)
	var moment := Shot.arg("numbers")
	if Shot.has_arg("bloom"):
		await _bloom(jekyll, float(Shot.arg("bloom")))
	elif moment != "":
		_numbers.speed = 40.0
		await _numbers.demo("" if moment == "end" else moment)
		_numbers.is_jekyll = jekyll
	Shot.run_if_requested(self)


# A total of 60 lands in the score; the page is frozen `after` seconds later.
func _bloom(jekyll: bool, after: float) -> void:
	ArenaPace.reduce_flashes = Shot.has_arg("calm")
	_numbers.is_jekyll = jekyll
	_numbers.show_hand("Pair", 20, 3)
	_numbers.send_total(60)
	await get_tree().create_timer(ArenaNumbers.TRAVEL_TIME + after).timeout
	Engine.time_scale = 0.0
