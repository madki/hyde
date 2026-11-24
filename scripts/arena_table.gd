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
## A script named `scripts/arena_extra_<name>.gd` ("ghosts", "previews", "views", "sound") with
## `static func setup(t: ArenaTable) -> void` is called once when the arena is ready, and may
## listen to `choice_changed`, `synced` and `move_begun` here, and to the parts' own signals.

## The chosen cards changed: `play` is RulesView.table().play for them, null for none.
signal choice_changed(play: Variant)
## Nothing is moving and every part shows `table` (RulesView.table() with the chosen cards).
signal synced(table: Dictionary)
## The player pressed a key or clicked while the table waited for it (`waiting_press`).
signal pressed
## A move is about to be played back: the marks of a choice are to go.
signal move_begun(move: String)
## A play's total has reached the round's score, which blooms.
signal landed

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
var numbers: ArenaNumbers
var symbols: ArenaSymbols
var means: ArenaMeans
var ink: ArenaInk
var controls: ArenaControls
var heading: ArenaHeading
var reward: ArenaReward

## The reward's choice, between the round that offered it and the next: the place of the
## card taken (-1 or null for none), and the nodes of the cards that were offered.
## True while a beat waits for any key or click (the run's end).
var waiting_press := false
var picked: Variant = null
var offered: Array = []

## RulesView.table() as it stands after the move being played back.
var after: Dictionary = {}
## Set by a moment that leaves an event unshown: the table snaps to the engine at the end.
var unhandled := false

var _followed: Array[Tween] = []
## True while the flask and the papers are in a movement of their own: they are then left
## alone, and set to what the engine holds when it is over.
var _means_settling := false
## True when a skipped move left a movement of the symbols out: they show an older table.
var _stale := false


## Call once, when every part is set.
func bind() -> void:
	shown = beats.shown
	controls.hold_tallies(numbers)
	beats.hurried.connect(_set_rate)
	beats.skipped.connect(_set_rate)
	beats.started.connect(_set_rate)
	# Who has the table, for the sounds: Hyde while the table shows his stance.
	Sfx.hyde = run.stance == "hyde"
	shown.changed.connect(_follow_stance)
	# Leaving the page leaves no sound behind, and the next screen is no one's.
	arena.tree_exiting.connect(func() -> void:
		Sfx.stop_all()
		Sfx.hyde = false)


## True while the table shows Hyde at it: during a move, until the page's shift is played.
func hyde() -> bool:
	return shown.value("stance", after.get("stance", "jekyll")) == "hyde"


## A card as an entry of RulesView.table().hand, {id, t, key, ink, name, chips, text,
## playable}, whichever pile it is in. A Factor's name and words are those of the man the
## table shows now; `playable` is as RulesView has it once the move is over.
func entry(id: int) -> Dictionary:
	var stance := "hyde" if hyde() else "jekyll"
	var playable := true
	for e: Dictionary in after.get("hand", []):
		if e.id == id:
			playable = e.playable
	var c := Rules.card(run, id)
	if c == null:
		return {"id": id, "t": "root", "key": "", "ink": false, "name": "", "chips": 0, "text": "", "playable": true}
	return {
		"id": id, "t": c.t, "key": c.key(), "ink": c.is_ink(),
		"name": Rules.name_of(c, stance), "chips": Rules.chips_of(run, c),
		"text": RulesConfig.factor_text(c.kind, stance, run.dials) if c.is_factor() else "",
		"playable": playable,
	}


## The same card as the data a travelling card is made from (ArenaTravel.make_card): its
## `ink` is how the card looks, so a Factor is on ink while Hyde has the table.
func card_data(id: int) -> Dictionary:
	var data := entry(id)
	data.ink = data.ink or (data.t == "factor" and hyde())
	return data


## Has a tween made by one of the parts (the numbers' calls return theirs) play at the
## queue's rate, and keep up with it when the player hurries. Returns the tween.
func follow(tween: Tween) -> Tween:
	_followed = _followed.filter(func(old: Tween) -> bool: return old.is_valid())
	if tween and tween.is_valid():
		tween.set_speed_scale(beats.rate())
		_followed.append(tween)
	return tween


## Plays a movement of a part that keeps its own time (the symbols' and the flask's calls
## are coroutines) and waits for it. Such a part cannot be hurried; when the move is skipped
## the movement is left out, and the part is put right at the end of the move.
func play(movement: Callable) -> void:
	if beats.rate() >= 100.0:
		_stale = true
		return
	await movement.call()


## Plays a movement of the flask or the papers that nothing waits for (the flask tipping, or
## both settling for what comes next). Until it is over they are not set from the engine, so
## that a move ending meanwhile cannot be overrun by it; then they are, as it then stands.
func play_means(movement: Callable) -> void:
	if beats.rate() >= 100.0 or _means_settling:
		return
	_means_settling = true
	await movement.call()
	_means_settling = false
	means.show_table(RulesView.table(run), run.dials)


## At a pause inside a move (a choice, a round's end) everything the round did has been
## shown: the parts a skip left behind are set from the engine, and whoever listens to
## `synced` is told the table as it stands.
func freshen() -> void:
	var table := RulesView.table(run)
	if _stale:
		symbols.show_table(table)
		_stale = false
	synced.emit(table)


## Moves one shown number and the part that draws it, without waiting: follow it with
## `await t.beats.wait(ArenaPace.MARK)`, or use `add_mark`.
func mark(key: String, value: Variant) -> void:
	shown.set_value(key, value)
	match key:
		"plays":
			follow(numbers.set_plays(value))
		"discards":
			follow(numbers.set_discards(value))
		"sov":
			follow(numbers.count_sov(value))
		"target":
			follow(numbers.count_target(value))
		"score":
			follow(numbers.count_score(value))
		"restraint/stored":
			follow(numbers.set_stored(value))
		"restraint/meter":
			numbers.restraint.show_meter(value, shown.value("restraint/limit", numbers.restraint.limit))
		"restraint/limit":
			numbers.restraint.show_meter(shown.value("restraint/meter", 0), value)


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
	Sfx.hyde = table.stance == "hyde"
	numbers.show_table(table)
	symbols.show_table(table)
	_stale = false
	if not _means_settling:
		means.show_table(table, run.dials)
	hand.show_table(table)
	controls.show_table(table, hand.chosen().size())
	synced.emit(table)


## The flask is filled and corked or uncorked, and the papers fold or unfold, as the engine
## now has them, in their own time: nothing waits for it. When the move is skipped they are
## set at once at its end.
func settle_means() -> void:
	play_means(func() -> void:
		await means.set_draught(after.draught)
		await means.set_salt(after.salt))


## The table as the engine has it, at once: the end of a move some of which was not shown.
func catch_up() -> void:
	snap_shown()
	sync()


# The shown stance changed: the sounds follow who has the table.
func _follow_stance(key: String, value: Variant) -> void:
	if key == "stance":
		Sfx.hyde = value == "hyde"


func _set_rate() -> void:
	var rate := beats.rate()
	numbers.speed = rate
	for tween in _followed:
		if tween.is_valid():
			tween.set_speed_scale(rate)
