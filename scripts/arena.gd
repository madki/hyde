extends Control
## The arena, where every round is played: a page of Dr Jekyll's night journal, its ruled
## border, Hyde's ink coming in from the right, and the hand of cards on the table.
##
## The ink is set through three things (see scripts/arena_ink.gd): who has the table, how much
## of the page the ink covers, and how restless it is. Jekyll has the table to begin with, and
## Shift gives it to the other man. For a screenshot they can be given as `--ink=<0..100>`,
## `--volatility=<0..100>` and `--hyde` (`tools/shot.sh /abs/out.png res://scenes/arena.tscn --ink=30`).
##
## The restraint gauge (scripts/arena_restraint.gd) shows the run's table as RulesView gives it.
## Until rounds are played here the run is a new one, and its meter can be set to look at the
## gauge: with `--restraint=<0..5>` for a screenshot, or with the keys 0 to 5.

## Who has the table. These three may be set before the arena is in the tree: they reach the
## ink and the hand when those are ready.
var is_jekyll := true:
	set(value):
		is_jekyll = value
		if _ink:
			_ink.is_jekyll = value
		if _hand:
			_hand.is_jekyll = value
## How much of the page the ink covers, 0 to 100.
var ink_percent := 50.0:
	set(value):
		ink_percent = clampf(value, 0.0, 100.0)
		if _ink:
			_ink.percent = ink_percent
## How restless the ink is in Hyde's stance, 0 to 100.
var ink_volatility := 50.0:
	set(value):
		ink_volatility = clampf(value, 0.0, 100.0)
		if _ink:
			_ink.volatility = ink_volatility

@onready var _ink: ArenaInk = $Ink
@onready var _hand: ArenaHand = $Hand
@onready var _restraint: ArenaRestraint = $Restraint

var _run := Rules.new_run()


func _ready() -> void:
	if Shot.has_arg("ink"):
		ink_percent = float(Shot.arg("ink"))
	if Shot.has_arg("volatility"):
		ink_volatility = float(Shot.arg("volatility"))
	if Shot.has_arg("hyde"):
		is_jekyll = false
	_ink.set_ink(ink_percent, ink_volatility, is_jekyll)
	_ink.snap_to_stance()
	_hand.is_jekyll = is_jekyll
	_hand.snap()
	if Shot.has_arg("restraint"):
		_run.restraint = int(Shot.arg("restraint"))
	_restraint.show_table(RulesView.table(_run))
	_restraint.snap()
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SHIFT:
		set_jekyll(not is_jekyll)
	# To look at the gauge, until rounds are played here: a number key sets the meter.
	if key and key.pressed and not key.echo and key.keycode >= KEY_0 and key.keycode <= KEY_5:
		_run.restraint = key.keycode - KEY_0
		_restraint.show_table(RulesView.table(_run))


## Sets all of the ink at once: the share of the page it covers (0 to 100), how restless it is
## in Hyde's stance (0 to 100), and whether Jekyll has the table.
func set_ink(percent: float, volatility: float, jekyll: bool) -> void:
	ink_percent = percent
	ink_volatility = volatility
	is_jekyll = jekyll


## True while Jekyll has the table: the ink stands still and its dark layers draw back.
func set_jekyll(jekyll: bool) -> void:
	is_jekyll = jekyll


## How much of the page the ink covers, 0 to 100.
func set_ink_percent(percent: float) -> void:
	ink_percent = percent


## How restless the ink is in Hyde's stance, 0 to 100.
func set_ink_volatility(volatility: float) -> void:
	ink_volatility = volatility
