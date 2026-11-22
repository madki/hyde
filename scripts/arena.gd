extends Control
## The arena, where every round is played: a page of Dr Jekyll's night journal, its ruled
## border, Hyde's ink coming in from the right, and the hand of cards on the table.
##
## The ink is set through three things (see scripts/arena_ink.gd): who has the table, how much
## of the page the ink covers, and how restless it is. Jekyll has the table to begin with, and
## Shift gives it to the other man. For a screenshot they can be given as `--ink=<0..100>`,
## `--volatility=<0..100>` and `--hyde`.

## Who has the table.
var is_jekyll := true:
	set(value):
		is_jekyll = value
		if _ink:
			_ink.is_jekyll = value
		if _hand:
			_hand.is_jekyll = value

@onready var _ink: ArenaInk = $Ink
@onready var _hand: ArenaHand = $Hand


func _ready() -> void:
	if Shot.has_arg("ink"):
		set_ink_percent(float(Shot.arg("ink")))
	if Shot.has_arg("volatility"):
		set_ink_volatility(float(Shot.arg("volatility")))
	set_jekyll(not Shot.has_arg("hyde"))
	_ink.snap_to_stance()
	_hand.snap()
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SHIFT:
		set_jekyll(not is_jekyll)


## Sets all of the ink at once: the share of the page it covers (0 to 100), how restless it is
## in Hyde's stance (0 to 100), and whether Jekyll has the table.
func set_ink(percent: float, volatility: float, jekyll: bool) -> void:
	is_jekyll = jekyll
	_ink.set_ink(percent, volatility, jekyll)


## True while Jekyll has the table: the ink stands still and its dark layers draw back.
func set_jekyll(jekyll: bool) -> void:
	is_jekyll = jekyll


## How much of the page the ink covers, 0 to 100.
func set_ink_percent(percent: float) -> void:
	_ink.percent = percent


## How restless the ink is in Hyde's stance, 0 to 100.
func set_ink_volatility(volatility: float) -> void:
	_ink.volatility = volatility
