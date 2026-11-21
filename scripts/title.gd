extends Control
## The title screen: the street, with Jekyll waiting in it. A tap of Shift shows Hyde and
## brings Jekyll back, all in one go. The whole screen splits into three colours and snaps
## back while the lamps turn from cyan to magenta and Jekyll parts into two ghosts: the cyan
## one goes left and fades away, and the magenta one, Hyde's shape from the start, goes right and
## sets into Hyde. Hyde stands there for a moment, and then it all runs backwards, without the
## split of the screen. Tab goes over to the older change, in which Shift turns one man into
## the other through the dark, and back.
## For screenshots: `--apart=0.3` shows a moment of Jekyll coming apart (`--hold` the end of
## it), `--glitch=0.3` a moment of the split of the screen, `--shift=1` starts on Hyde, and
## `--lamps=0.3` and `--dark=0.5` show a moment of the change through the dark.

enum Change { HOLD, DARK }

## How long Hyde stands there before it all goes back, in seconds.
const HYDE_STAYS := 1.0

## What Shift does: HOLD = Jekyll comes apart into Hyde and back, DARK = it turns one man
## into the other through the dark.
@export var change := Change.HOLD

var _visit: Tween

@onready var _bg: TitleBackground = $Background
@onready var _split: SplitTransition = $SplitTransition


func _ready() -> void:
	if Shot.has_arg("shift"):
		_bg.shift = float(Shot.arg("shift"))
	if Shot.has_arg("lamps"):
		_bg.lamps = float(Shot.arg("lamps"))
	if Shot.has_arg("dark"):
		_bg.darkness = float(Shot.arg("dark"))
	if Shot.has_arg("apart"):
		_bg.apart = float(Shot.arg("apart"))
	if Shot.has_arg("hold"):
		_bg.apart = 1.0
	if Shot.has_arg("glitch"):
		_split.begin_glitch()
		_split.pose(float(Shot.arg("glitch")))
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo:
		return
	if not key.pressed or _bg.is_changing() or _bg.apart > 0.0:
		return
	if key.keycode == KEY_SHIFT and change == Change.HOLD:
		_visit_hyde()
	elif key.keycode == KEY_TAB:
		change = Change.DARK if change == Change.HOLD else Change.HOLD
		print("Change: ", Change.find_key(change))
	elif key.keycode == KEY_SHIFT:
		_bg.change_to(0.0 if _bg.shift > 0.5 else 1.0)


## Jekyll comes apart into Hyde inside a split of the whole screen, Hyde stands there, and
## it all goes back, with no split this time.
func _visit_hyde() -> void:
	if _visit and _visit.is_running():
		return
	_visit = create_tween()
	_visit.tween_callback(_split.glitch)
	_visit.tween_callback(_bg.part_to.bind(1.0))
	_visit.tween_interval(TitleBackground.PART_SECONDS + HYDE_STAYS)
	_visit.tween_callback(_bg.part_to.bind(0.0))
	_visit.tween_interval(TitleBackground.PART_SECONDS)
