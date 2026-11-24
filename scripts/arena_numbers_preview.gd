extends Control
## The round's numbers alone on the page, to look at them and their calls without the rest of
## the arena (scripts/arena_numbers.gd). C runs every call once in a debug build.
##
## For a screenshot, `--numbers=<moment>` stops the demo at one moment: rest, reason, choice,
## scoring, total, or end (`tools/shot.sh /abs/out.png res://scenes/arena_numbers_preview.tscn --numbers=total`).
## `--hyde` gives Hyde the table.

@onready var _ink: ArenaInk = $Ink
@onready var _numbers: ArenaNumbers = $Numbers


func _ready() -> void:
	var jekyll := not Shot.has_arg("hyde")
	_ink.set_ink(30.0, 40.0, jekyll)
	_ink.snap_to_stance()
	_numbers.show_table(RulesView.table(Rules.new_run({}, 1)))
	var moment := Shot.arg("numbers")
	if moment != "":
		_numbers.speed = 40.0
		await _numbers.demo("" if moment == "end" else moment)
		_numbers.is_jekyll = jekyll
	Shot.run_if_requested(self)
