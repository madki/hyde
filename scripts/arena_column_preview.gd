extends Control
## The round's numbers alone on the page, to look at them and their calls without the rest of
## the arena (scripts/arena_column.gd). C runs every call once in a debug build.
##
## For a screenshot, `--column=<moment>` stops the demo at one moment: rest, reason, choice,
## scoring, total, or end (`tools/shot.sh /abs/out.png res://scenes/arena_column_preview.tscn --column=total`).
## `--hyde` gives Hyde the table.

@onready var _ink: ArenaInk = $Ink
@onready var _column: ArenaColumn = $Column


func _ready() -> void:
	var jekyll := not Shot.has_arg("hyde")
	_ink.set_ink(30.0, 40.0, jekyll)
	_ink.snap_to_stance()
	_column.show_table(RulesView.table(Rules.new_run({}, 1)))
	var moment := Shot.arg("column")
	if moment != "":
		_column.speed = 40.0
		await _column.demo("" if moment == "end" else moment)
		_column.is_jekyll = jekyll
	Shot.run_if_requested(self)
