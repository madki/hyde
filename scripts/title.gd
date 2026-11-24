extends Control
## The title screen: the street, with Jekyll waiting in it. A tap of Shift shows Hyde for a
## moment, all in one go: Jekyll parts into a cyan ghost of himself on the left and a magenta
## one on the right; when they are apart the magenta one turns into Hyde under magenta lamps,
## and in that moment the screen shakes and splits a little way into three colours; then
## Hyde turns back into Jekyll's magenta ghost and the two ghosts close into Jekyll. Tab goes
## over to the older change, in which Shift turns one man into the other through the dark,
## and back. A visit starts from Jekyll: while Hyde stands there, Shift turns him back through
## the dark whichever change is chosen. The panel on the dark side of the street holds one
## row: Press SHIFT at first, and Begin (as Enter) once Shift has shown Hyde. Until then Enter
## and a click on the row do what Shift does. `--begun` starts with Begin showing.
## For screenshots: `--apart=0.5` shows a moment of Jekyll coming apart, `--hyde=1` (with
## `--apart=1`) the magenta ghost turned into Hyde, `--glitch=0.3` a moment of the split of
## the screen, `--shift=1` starts on Hyde, and `--lamps=0.3` and `--dark=0.5` show a moment
## of the change through the dark.

enum Change { VISIT, DARK }

# The visit to Hyde, in seconds.
const PARTS := 0.22 # Jekyll comes apart
const TURNS := 0.16 # the magenta ghost turns into Hyde, and Hyde back into it
const HYDE_STAYS := 0.3 # Hyde is there
const SPLITS := 0.55 # the screen shakes and splits, from when the ghost begins to turn
const MERGES := 0.22 # the ghosts close into Jekyll
## How far the screen's pictures go in that split, where 1 is a full change of scene's, and
## how far the screen is shaken, as a fraction of its height.
const SPLIT_SIZE := 0.35
const SHAKE := 0.006

## What Shift does: VISIT = Jekyll comes apart into Hyde and back, DARK = it turns one man
## into the other through the dark.
@export var change := Change.VISIT

const GAME_NAME := "Versura"
const ROW_SHIFT := "Press SHIFT"
const ROW_BEGIN := "Begin"

var _visit: Tween
## True once Shift has been pressed and its change has played: the panel then offers Begin.
var _begun := false

@onready var _bg: TitleBackground = $Background
@onready var _split: SplitTransition = $SplitTransition
@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	_panel.accent = Palette.JEKYLL
	_panel.set_heading(GAME_NAME)
	_panel.set_rows([{text = ROW_SHIFT}])
	_panel.row_chosen.connect(_on_row_chosen)
	if Shot.has_arg("begun"):
		_offer_begin()
	if Shot.has_arg("shift"):
		_bg.shift = float(Shot.arg("shift"))
	if Shot.has_arg("lamps"):
		_bg.lamps = float(Shot.arg("lamps"))
	if Shot.has_arg("dark"):
		_bg.darkness = float(Shot.arg("dark"))
	if Shot.has_arg("apart"):
		_bg.apart = float(Shot.arg("apart"))
	if Shot.has_arg("hyde"):
		_bg.hyde = float(Shot.arg("hyde"))
	if Shot.has_arg("glitch"):
		_split.begin_glitch(SPLIT_SIZE, SHAKE)
		_split.pose(float(Shot.arg("glitch")))
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo or not key.pressed:
		return
	if _is_busy():
		return
	if key.keycode == KEY_TAB:
		change = Change.DARK if change == Change.VISIT else Change.VISIT
		print("Change: ", Change.find_key(change))
	elif key.keycode == KEY_SHIFT:
		_shift()


func _on_row_chosen(_index: int) -> void:
	if _begun:
		SceneFlow.next() # as Enter does anywhere
	elif not _is_busy():
		_shift()


## Puts Begin on the panel in place of the prompt.
func _offer_begin() -> void:
	if _begun:
		return
	_begun = true
	_panel.set_rows([{text = ROW_BEGIN}])


func _is_busy() -> bool:
	return _bg.is_changing() or (_visit and _visit.is_running())


func _shift() -> void:
	if change == Change.VISIT and _bg.shift <= 0.0:
		_visit_hyde()
	else:
		# Also the way back for a Hyde left standing by the other change: a visit starts
		# from Jekyll.
		_bg.change_to(0.0 if _bg.shift > 0.5 else 1.0)
		_offer_begin()


## Jekyll comes apart, his magenta ghost turns into Hyde as the screen shakes and splits,
## Hyde turns back into the ghost and the ghosts close into Jekyll.
func _visit_hyde() -> void:
	_visit = create_tween()
	_visit.tween_property(_bg, "apart", 1.0, PARTS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_visit.tween_callback(_split.glitch.bind(SPLIT_SIZE, SHAKE, SPLITS))
	_visit.tween_property(_bg, "hyde", 1.0, TURNS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visit.tween_interval(HYDE_STAYS)
	_visit.tween_property(_bg, "hyde", 0.0, TURNS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visit.tween_property(_bg, "apart", 0.0, MERGES) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_visit.tween_callback(_offer_begin)
