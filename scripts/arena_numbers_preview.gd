extends Control
## The round's numbers alone on the page, to look at them and their calls without the rest of
## the arena (scripts/arena_numbers.gd), with PLAY and DISCARD to hold the tallies. C runs every call once in a debug build.
##
## For a screenshot, `--numbers=<moment>` stops the demo at one moment: rest, reason, choice,
## scoring, total, or end (`tools/shot.sh /abs/out.png res://scenes/arena_numbers_preview.tscn --numbers=total`).
## `--hyde` gives Hyde the table.

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
	if moment != "":
		_numbers.speed = 40.0
		await _numbers.demo("" if moment == "end" else moment)
		_numbers.is_jekyll = jekyll
	Shot.run_if_requested(self)
