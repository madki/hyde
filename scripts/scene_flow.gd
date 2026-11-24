extends Node
## The game's screens, and what outlives a change of screen: the run being played. The title
## goes on to the table; at dawn the table hands over to the laboratory or the back alley
## (`go_to_place`), and the place hands back (`back_to_table`). Every change of screen is made
## here. Loaded with the game (an autoload), so it works whichever screen is run.

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
## How many seeds `run_at_dawn` tries, one after another, before it gives up.
const DAWN_TRIES := 200

## The run being played, null until one begins. The table makes it, and replaces it when a
## new run begins; the places read and change it.
var run: RulesRun

## True between a change of screen being asked for and its being made.
var _changing := false

## The screen that shows how a run ended, and the ending it is to show: "hyde", "double" or
## "myself" (the rules' names).
const ENDING_SCENE := "res://scenes/ending.tscn"
var ending := ""


## Hands a run's end over to the ending screen. False if there is no such screen yet: the
## caller then shows the ending itself.
func show_ending(ending_key: String) -> bool:
	ending = ending_key
	if not ResourceLoader.exists(ENDING_SCENE):
		return false
	get_tree().change_scene_to_file(ENDING_SCENE)
	return true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo or not key.pressed:
		return
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return
	var current := get_tree().current_scene
	if current and current.scene_file_path == TITLE_SCENE:
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
	_change_to(PLACE_SCENES[run.phase])
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
## warning, when none of DAWN_TRIES seeds does.
static func run_at_dawn(where: String, seed_value: int, dawn: int = 1) -> RulesRun:
	for attempt in DAWN_TRIES:
		var made := Rules.new_run({}, seed_value + attempt)
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
	return Rules.discard(made, dead.slice(0, made.dials.max_play))


# Every change of screen between the title, the table and a place is made here. The change
# waits for the end of the frame: the screen that asks for it, often from inside its handling
# of a key, is still whole until then. A second change asked for meanwhile is dropped.
func _change_to(scene: String) -> void:
	if _changing or get_tree().current_scene == null:
		return
	_changing = true
	_change_now.call_deferred(scene)


func _change_now(scene: String) -> void:
	_changing = false
	get_tree().change_scene_to_file(scene)
