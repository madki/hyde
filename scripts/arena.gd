extends Control
## The arena, where every round is played: a page of Dr Jekyll's night journal, its ruled
## border, and Hyde's ink coming in from the right.
##
## The ink is set through three things (see scripts/arena_ink.gd): who has the table, how much
## of the page the ink covers, and how restless it is. For a screenshot they can be given as
## `--ink=<0..100>`, `--volatility=<0..100>` and `--jekyll`.

@onready var _ink: ArenaInk = $Ink


func _ready() -> void:
	if Shot.has_arg("ink"):
		set_ink_percent(float(Shot.arg("ink")))
	if Shot.has_arg("volatility"):
		set_ink_volatility(float(Shot.arg("volatility")))
	if Shot.has_arg("jekyll"):
		set_jekyll(true)
		_ink.snap_to_stance()
	Shot.run_if_requested(self)


## Sets all of the ink at once: the share of the page it covers (0 to 100), how restless it is
## in Hyde's stance (0 to 100), and whether Jekyll has the table.
func set_ink(percent: float, volatility: float, is_jekyll: bool) -> void:
	_ink.set_ink(percent, volatility, is_jekyll)


## True while Jekyll has the table: the ink stands still and its dark layers draw back.
func set_jekyll(is_jekyll: bool) -> void:
	_ink.is_jekyll = is_jekyll


## How much of the page the ink covers, 0 to 100.
func set_ink_percent(percent: float) -> void:
	_ink.percent = percent


## How restless the ink is in Hyde's stance, 0 to 100.
func set_ink_volatility(volatility: float) -> void:
	_ink.volatility = volatility
