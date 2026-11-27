extends Node
## The game's screens, and what outlives a change of screen: the run being played. The title
## goes on to the table; at dawn the table hands over to the laboratory or the back alley
## (`go_to_place`), and the place hands back (`back_to_table`); a run's end goes to the ending
## screen (`show_ending`), and from there back to the title (`close_ending`). Every change of
## screen is made here. Loaded with the game (an autoload), so it works whichever screen is run.

## The screens Enter goes through in turn, from the last back to the first. Enter goes on
## from the title only: on the table and in the two places it is theirs.
const SCENES: Array[String] = [
	"res://scenes/title.tscn",
	"res://scenes/arena.tscn",
]
const TITLE_SCENE := "res://scenes/title.tscn"
const TABLE_SCENE := "res://scenes/arena.tscn"
## The dawn's places, by the phase of the run that opens them.
const PLACE_SCENES := {
	"lab": "res://scenes/lab.tscn",
	"alley": "res://scenes/alley.tscn",
}
## The line the passage to a place shows, in that place's light.
const PLACE_LINES := {
	"lab": "Dawn. Jekyll held the table: the laboratory.",
	"alley": "Dawn. Hyde held the table: the back alley.",
}
## The command-line arguments that drive a screen for a still or a check (Shot, ArenaBench):
## with any of them a change of screen is a plain cut, at once.
const CUT_ARGS: Array[String] = ["shot", "keys", "quit", "selftest", "fast"]
## How many seeds `run_at_dawn` tries, one after another, before it gives up.
const DAWN_TRIES := 200

## The run being played, null until one begins. The table makes it, and replaces it when a
## new run begins; the places read and change it.
var run: RulesRun

## True from a run read from a file being handed over (`resume`, or `--run=<path>`) until a
## screen has taken it: the screen then sets it false.
var resumed := false
## The keys of the story told in the run handed over, for the table to take.
var resumed_story: Array = []

## True from a change of screen being asked for until its passage is over: a second change
## asked for meanwhile is dropped.
var _changing := false

## The cover over a change of screen. A child of this autoload, so it outlives the screens.
var _passage: Passage


func _ready() -> void:
	_passage = Passage.new()
	_passage.name = "Passage"
	add_child(_passage)
	_take_run_argument()


## Takes up the run kept on this machine (RunSave): it becomes the run being played, and the
## screen changes to the table for a round, or to the place for a dawn. False, and nothing
## changes, when no run is kept.
func resume() -> bool:
	# A change of screen is under way: this one would be dropped, so nothing is handed over.
	if _changing:
		return true
	var kept := RunSave.read()
	if kept.is_empty():
		return false
	_hand_over(kept)
	if run.phase == "play":
		_change_to(TABLE_SCENE)
	else:
		go_to_place()
	return true


# With `--run=<path>` (absolute, or res://), the run in that file is handed over to whichever
# screen the command line starts; a run at its end is kept for the ending screen too. A file
# that does not read leaves the game as without the argument.
func _take_run_argument() -> void:
	if not Shot.has_arg("run"):
		return
	var file_path := Shot.arg("run")
	var kept := RunSave.read_file(file_path)
	if kept.is_empty():
		push_warning("No run could be read from %s; the game starts without it." % file_path)
		return
	_hand_over(kept)
	if run.phase == "end":
		ended = run
		ending = str(run.ending) if run.ending != null else ""


func _hand_over(kept: Dictionary) -> void:
	run = kept.run
	resumed_story = kept.story
	resumed = true

## The screen that shows how a run ended, and the ending it is to show: "hyde", "double" or
## "myself" (the rules' names).
const ENDING_SCENE := "res://scenes/ending.tscn"
var ending := ""
## The run that ended, kept for the ending screen; null when no ending is showing. While it
## is the table's run, the table begins no new run under the ending (see the table's `_go_on`).
## Closing the ending forgets it, and the run.
var ended: RulesRun


## Hands a run's end over to the ending screen, which shows the run being played: it is kept
## in `ended`, and the screen changes under the passage. False, and nothing changes, if there
## is no such screen or a change of screen would be a plain cut (CUT_ARGS): the caller then
## shows the ending itself, and the table plays on with a new run. (Under the bench it plays
## on at dawn too; with `--fast` alone a dawn still goes to its place.) The run kept on this
## machine (RunSave) is forgotten either way.
func show_ending(ending_key: String) -> bool:
	ending = ending_key
	RunSave.clear()
	if not ResourceLoader.exists(ENDING_SCENE) or _cuts():
		return false
	ended = run
	_change_to(ENDING_SCENE)
	return true


## True from a change of screen being asked for until its passage has lifted off the new
## screen.
func is_changing() -> bool:
	return _changing


## From the ending: the journal is closed, and the game is at its title again as when it was
## started. No run is held, and none that ended: the next begins from the title.
func close_ending() -> void:
	RunSave.clear()
	ended = null
	ending = ""
	run = null
	resumed = false
	resumed_story = []
	_change_to(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo or not key.pressed:
		return
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return
	var current := get_tree().current_scene
	if current and current.scene_file_path == TITLE_SCENE and not resume():
		next()


## Goes to the screen after the one that is showing. A screen that is not in the list goes to
## the first, unless it is one of the studio's: Enter must not cut a bake short.
func next() -> void:
	var current := get_tree().current_scene
	if not current: # a change of screen is already under way
		return
	var at := SCENES.find(current.scene_file_path)
	if at == -1 and current.scene_file_path.begins_with("res://studio/"):
		return
	_change_to(SCENES[(at + 1) % SCENES.size()])


# ---------- the dawn's places ----------

## At dawn: leaves the table for the place the run's phase names, the laboratory ("lab") or
## the back alley ("alley"). False, and nothing happens, when the run is at neither.
func go_to_place() -> bool:
	if run == null or not PLACE_SCENES.has(run.phase):
		return false
	var light: Color = Palette.JEKYLL if run.phase == "lab" else Palette.HYDE
	_change_to(PLACE_SCENES[run.phase], PLACE_LINES[run.phase], light)
	return true


## Leaves a place for the table. The run is still at the place: the table leaves it in the
## rules (Rules.leave_lab, Rules.alley_leave) and plays the next night's first round.
func back_to_table() -> void:
	_change_to(TABLE_SCENE)


## The run a place ("lab" or "alley") shows: the one being played when it is at that place,
## and otherwise (the place run on its own, for a still or from the editor) a new one played
## to a dawn there, which becomes the run being played. `--seed=<n>` is that run's seed.
func run_for_place(where: String) -> RulesRun:
	if run == null or run.phase != where:
		run = run_at_dawn(where, int(Shot.arg("seed")) if Shot.has_arg("seed") else 1)
	return run


## A new run played by the rules alone to its dawn number `dawn` (from 1; the last night has
## none), ending at `where`: "lab" (Jekyll has the table) or "alley" (Hyde has it). The run's
## seed is `seed_value`, or the first after it whose run gets there: one that ends before
## that dawn, or comes to it at the other place, is left for the next seed. Null, with a
## warning, when none of DAWN_TRIES seeds does. The first night asks its plain targets here:
## the plain play below seldom clears what the game asks of a player.
static func run_at_dawn(where: String, seed_value: int, dawn: int = 1) -> RulesRun:
	for attempt in DAWN_TRIES:
		var made := Rules.new_run({"first_night_scale": 1.0}, seed_value + attempt)
		if _play_to_dawn(made, where, dawn):
			return made
	push_warning("No run from seed %d on came to dawn %d at the %s." % [seed_value, dawn, where])
	return null


# Plays `made` until it stands at dawn number `dawn`. True when that dawn is at `where`.
static func _play_to_dawn(made: RulesRun, where: String, dawn: int) -> bool:
	for move in 5000:
		var result := {"ok": true}
		match made.phase:
			"end":
				return false
			"lab", "alley":
				if int(made.dawn.no) == dawn:
					return made.phase == where
				result = Rules.leave_lab(made) if made.phase == "lab" else Rules.alley_leave(made)
			"result":
				result = Rules.continue_result(made)
			_:
				result = _play_on(made, where if made.night == dawn - 1 and Rules.is_scene(made) else "")
		if not result.ok:
			return false
	return false


# Makes one move of a round: the best play the rules find; with nothing to play, a pass, or
# a discard of what cannot be played. In the scene before the wanted dawn (`where` is then
# "lab" or "alley") the man that place needs is first brought to the table, when he can be.
static func _play_on(made: RulesRun, where: String) -> Dictionary:
	if where == "alley" and Rules.can_drink(made).ok:
		return Rules.drink(made)
	if where == "lab" and Rules.can_salt(made).ok:
		return Rules.take_salt(made)
	if Rules.can_pass(made).ok:
		return Rules.pass_play(made)
	var ids: Array = Rules.best(made).get("ids", [])
	if not ids.is_empty():
		return Rules.play(made, ids)
	var ink: bool = made.stance == "hyde"
	var dead: Array = []
	for id: int in made.hand:
		var c := Rules.card(made, id)
		if not c.is_factor() and c.ink != ink:
			dead.append(id)
	return Rules.discard(made, dead.slice(0, made.dials.max_discard))


# Every change of screen between the title, the table and a place is made here, under the
# passage: the screen goes to night (with `line` on it, in `light`, when one is given), is
# changed while covered, and the night lifts off the new one. It starts at the end of the
# frame: the screen that asks for it, often from inside its handling of a key, is still whole
# until then. A second change asked for while one is under way is dropped. Driven from the
# command line (CUT_ARGS), the change is a plain cut.
func _change_to(scene: String, line: String = "", light: Color = Palette.CHALK) -> void:
	if _changing or get_tree().current_scene == null:
		return
	_changing = true
	_change_now.call_deferred(scene, line, light)


func _change_now(scene: String, line: String, light: Color) -> void:
	if _cuts():
		_changing = false
		get_tree().change_scene_to_file(scene)
		return
	await _passage.run(scene, line, light)
	_changing = false


static func _cuts() -> bool:
	for name in CUT_ARGS:
		if Shot.has_arg(name):
			return true
	return false
