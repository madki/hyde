extends Control
## The title screen: the street, with Jekyll waiting in it. A tap of Shift shows Hyde for a
## moment, all in one go: Jekyll parts into a cyan ghost of himself on the left and a magenta
## one on the right; when they are apart the magenta one turns into Hyde under magenta lamps,
## and in that moment the screen shakes and splits a little way into three colours; then
## Hyde turns back into Jekyll's magenta ghost and the two ghosts close into Jekyll. Tab goes
## over to the older change, in which Shift turns one man into the other through the dark,
## and back. A visit starts from Jekyll: while Hyde stands there, Shift turns him back through
## the dark whichever change is chosen. The panel on the dark side of the street holds one
## row to go on by: Press SHIFT at first, and Begin (as Enter) once Shift has shown Hyde. Until
## then Enter and a click on the row do what Shift does. Under it a second row, How to play,
## opens the help book (HelpBook) over the street. With a run kept on this machine (RunSave),
## the rows after Shift are Resume (selected), Begin and How to play, and Enter resumes.
## `--begun` starts with Begin showing; with `--saved` too, as with a kept run (nothing read).
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
const ROW_RESUME := "Resume"
const ROW_HELP := "How to play"
const RAIN := "amb_title" ## the street's loop

var _visit: Tween
## True once Shift has been pressed and its change has played: the panel then offers Begin.
var _begun := false
## True while a kept run is offered as Resume once Shift has been pressed.
var _saved := false
## The panel's rows by what they are, in the panel's order.
var _rows: Array[String] = []

@onready var _bg: TitleBackground = $Background
@onready var _split: SplitTransition = $SplitTransition
@onready var _panel: PlacePanel = $Panel
## The help book, laid over the street while it is open. It takes every key and click then.
var _help := HelpBook.new()


func _ready() -> void:
	Music.enter("title")
	# The street's rain, under the music; it ends with the screen.
	Sfx.loop(RAIN)
	tree_exiting.connect(Sfx.stop_loop.bind(RAIN, 0.0))
	_panel.accent = Palette.JEKYLL
	_panel.set_heading(GAME_NAME)
	_saved = Shot.has_arg("saved") or RunSave.has()
	_show_rows([ROW_SHIFT, ROW_HELP])
	_panel.row_chosen.connect(_on_row_chosen)
	add_child(_help)
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
		if not _begun:
			Sfx.play("button") # the press the panel asks for
		_shift()


func _on_row_chosen(index: int) -> void:
	var row := _rows[index] if index >= 0 and index < _rows.size() else ""
	if row == ROW_HELP:
		Sfx.play("button")
		_help.open()
	elif row == ROW_RESUME:
		if SceneFlow.is_changing():
			return
		Sfx.play("button")
		if SceneFlow.resume():
			Sfx.stop_loop(RAIN, 0.5)
		else: # the kept run went bad meanwhile
			_saved = false
			_show_rows([ROW_BEGIN, ROW_HELP])
	elif _begun:
		Sfx.play("button")
		Sfx.stop_loop(RAIN, 0.5)
		SceneFlow.next() # as Enter does anywhere
	elif not _is_busy():
		Sfx.play("button")
		_shift()


## Puts Begin on the panel in place of the prompt.
func _offer_begin() -> void:
	if _begun:
		return
	_begun = true
	if _saved:
		_show_rows([ROW_RESUME, ROW_BEGIN, ROW_HELP], false)
	else:
		_show_rows([ROW_BEGIN, ROW_HELP])


## Sets the panel's rows, keeping the selected place or (`keep` false) selecting the first.
func _show_rows(rows: Array[String], keep: bool = true) -> void:
	_rows = rows
	var given: Array = []
	for text in rows:
		given.append({text = text})
	_panel.set_rows(given, keep)


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
	Sfx.play("title_visit")
	# The rain drops away while he is here, and comes back as he goes.
	if Sfx.is_looping(RAIN):
		Sfx.loop(RAIN, 1.0, 0.15)
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
	_visit.tween_callback(func() -> void:
		if Sfx.is_looping(RAIN):
			Sfx.loop(RAIN))
	_visit.tween_callback(_offer_begin)
