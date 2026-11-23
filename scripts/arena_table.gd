class_name ArenaTable
extends RefCounted
## What a moment's script is handed: the run, the beat queue, and every part of the arena's
## table. A moment adds beats to `beats` from a move's events; it works out no rule.
##
## A moment is a script named `scripts/arena_moment_<move>.gd` with
## `static func add(t: ArenaTable, result: Dictionary) -> void`, where `result` is what the
## engine's move returned ({ok, events, ...}). The arena finds it by its name: the moves are
## "round" (a round's start), "play", "discard", "pass", "drink" and "salt". An event a moment
## does not show is reported with `unhandled = true`: the table then snaps to the engine at
## the end of the move, so nothing is ever left wrong.
##
## A script named `scripts/arena_extra_<name>.gd` ("ghosts", "previews", "views") with
## `static func setup(t: ArenaTable) -> void` is called once when the arena is ready, and may
## listen to `choice_changed`, `synced` and `move_begun` here, and to the parts' own signals.

## The chosen cards changed: `play` is RulesView.table().play for them, null for none.
signal choice_changed(play: Variant)
## Nothing is moving and every part shows `table` (RulesView.table() with the chosen cards).
signal synced(table: Dictionary)
## A move is about to be played back: the marks of a choice are to go.
signal move_begun(move: String)

## Every shown value the table keeps (see ArenaShown): the paths in RulesView.table().
const KEYS: Array[String] = [
	"stance", "score", "target", "plays", "discards", "sov", "draw_count", "discard_count",
	"restraint/meter", "restraint/limit", "restraint/stored", "salt/doses",
	"line/ink", "line/paper",
	"symbols/lamp/craving", "symbols/lamp/habit", "symbols/lamp/temper",
	"symbols/heart/craving", "symbols/heart/habit", "symbols/heart/temper",
	"symbols/mirror/craving", "symbols/mirror/habit", "symbols/mirror/temper",
]

var run: RulesRun
## The page, for places on it.
var arena: Control
var beats: ArenaBeats
var shown: ArenaShown
var travel: ArenaTravel
var piles: ArenaPiles
var stage: ArenaStage
var moments: ArenaCardMoments
var hand: ArenaHand
var column: ArenaColumn
var symbols: ArenaSymbols
var means: ArenaMeans
var ink: ArenaInk
var controls: ArenaControls
var heading: ArenaHeading

## RulesView.table() as it stands after the move being played back.
var after: Dictionary = {}
## Set by a moment that leaves an event unshown: the table snaps to the engine at the end.
var unhandled := false

var _followed: Array[Tween] = []


## Call once, when every part is set.
func bind() -> void:
	shown = beats.shown
	beats.hurried.connect(_set_rate)
	beats.skipped.connect(_set_rate)
	beats.started.connect(_set_rate)


## True while Hyde has the table after the move being played back.
func hyde() -> bool:
	return after.get("stance", "jekyll") == "hyde"


## A card as an entry of RulesView.table().hand, {id, t, key, ink, name, chips, text, ...},
## as it stands after the move, whichever pile it is in.
func entry(id: int) -> Dictionary:
	for e: Dictionary in after.get("hand", []):
		if e.id == id:
			return e
	var c := Rules.card(run, id)
	if c == null:
		return {"id": id, "t": "root", "key": "", "ink": false, "name": "", "chips": 0, "text": ""}
	return {
		"id": id, "t": c.t, "key": c.key(), "ink": c.is_ink(),
		"name": Rules.name_of(c, run.stance), "chips": Rules.chips_of(run, c),
		"text": RulesConfig.factor_text(c.kind, run.stance, run.dials) if c.is_factor() else "",
	}


## The same card as the data a travelling card is made from (ArenaTravel.make_card): its
## `ink` is how the card looks, so a Factor is on ink while Hyde has the table.
func card_data(id: int) -> Dictionary:
	var data := entry(id).duplicate()
	data.ink = data.ink or (data.t == "factor" and hyde())
	return data


## Has a tween made by one of the parts (the column's calls return theirs) play at the
## queue's rate, and keep up with it when the player hurries. Returns the tween.
func follow(tween: Tween) -> Tween:
	_followed = _followed.filter(func(old: Tween) -> bool: return old.is_valid())
	if tween and tween.is_valid():
		tween.set_speed_scale(beats.rate())
		_followed.append(tween)
	return tween


## Starts a movement of a part that keeps its own time (the symbols' and the flask's calls
## are coroutines) and waits `seconds` for it at the queue's rate. Hurried, the wait ends
## before the movement does; the part is put right at the end of the move.
func play(movement: Callable, seconds: float) -> void:
	movement.call()
	await beats.wait(seconds)


## Moves one shown number and the part that draws it, without waiting: follow it with
## `await t.beats.wait(ArenaPace.MARK)`, or use `add_mark`.
func mark(key: String, value: Variant) -> void:
	shown.set_value(key, value)
	match key:
		"plays":
			follow(column.set_plays(value))
		"discards":
			follow(column.set_discards(value))
		"sov":
			follow(column.count_sov(value))
		"target":
			follow(column.count_target(value))
		"score":
			follow(column.count_score(value))
		"restraint/stored":
			follow(column.set_stored(value))
		"restraint/meter":
			column.restraint.show_meter(value, shown.value("restraint/limit", column.restraint.limit))
		"restraint/limit":
			column.restraint.show_meter(shown.value("restraint/meter", 0), value)


## Adds a beat that moves one shown number, with the part that draws it, and waits.
func add_mark(key: String, value: Variant, seconds: float = ArenaPace.MARK) -> void:
	beats.add(func() -> void:
		mark(key, value)
		await beats.wait(seconds))


## Adds a beat that puts a caption on the page for its second.
func add_caption(text: String) -> void:
	beats.add(func() -> void:
		stage.show_caption(text)
		await stage.clear_caption())


## Every shown value at once, as the engine has it.
func snap_shown() -> void:
	shown.snap_to(RulesView.table(run), KEYS)


## Every part at once, as the engine has it, with the cards chosen in the hand.
func sync() -> void:
	var table := RulesView.table(run, hand.chosen())
	after = table
	ink.is_jekyll = table.stance == "jekyll"
	hand.is_jekyll = table.stance == "jekyll"
	column.show_table(table)
	symbols.show_table(table)
	means.show_table(table, run.dials)
	hand.show_table(table)
	controls.show_table(table, hand.chosen().size())
	synced.emit(table)


## The table as the engine has it, at once: the end of a move some of which was not shown.
func catch_up() -> void:
	snap_shown()
	sync()


func _set_rate() -> void:
	var rate := beats.rate()
	column.speed = rate
	for tween in _followed:
		if tween.is_valid():
			tween.set_speed_scale(rate)
