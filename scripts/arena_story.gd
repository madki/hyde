class_name ArenaStory
## The story's entries on the table: at a few moments of a run the table stops on a page of
## the journal (StoryPage) that writes the moment's line from StoryLines and waits for the
## player.
##
## - The opening's pages, on the first run since the game was started, and each night's line,
##   before the heading of the night's first round (`night_begins`).
## - The run's first draught, his first arrival, its first breakout, and the first time he
##   comes by the window, each after its own showing (`add`).
## - Each dawn's line, at the laboratory or in the back alley, before the table hands the run
##   over to that place (`dawn`).
##
## Each key is told once a run at most. An entry inside a move is a beat of the queue that
## waits for the player (ArenaBeats.add_choice), so a hurry or a held skip stops before it and
## cannot move it on; one outside a move is awaited directly. The page is laid over the whole
## table, as the arena's last child: it draws over every part of the table and has every press
## before them, and the presses that move it on are its own.
##
## Driven from the command line (SceneFlow.CUT_ARGS: the bench, the self-test, a still) the
## table tells no entry, since no player is there to move one on; `--story` tells them there,
## for a still of one:
##
##   tools/shot.sh /abs/out.png res://scenes/arena.tscn --story --at=4

const OPENING: Array[String] = ["opening.1", "opening.2", "opening.3"]

## True once the opening's pages have been told in this sitting: later runs begin at night 1's
## line.
static var opened := false

## The run the keys in `_told` were told in. A new run starts clean.
static var _run: WeakRef = null
static var _told := {}


## True when the table tells its entries.
static func on() -> bool:
	if Shot.has_arg("story"):
		return true
	for name: String in SceneFlow.CUT_ARGS:
		if Shot.has_arg(name):
			return false
	return true


## Night `no` begins: before the heading of its first round, its line, after the opening's
## pages on the sitting's first run.
static func night_begins(t: ArenaTable, no: int) -> void:
	var keys: Array[String] = []
	if no == 1 and not opened and on():
		opened = true
		keys.append_array(OPENING)
	keys.append("night.%d" % no)
	add(t, keys)


## Queues `keys` not yet told this run as a beat that waits for the player.
static func add(t: ArenaTable, keys: Array[String]) -> void:
	var due := _due(t.run, keys)
	if due.is_empty():
		return
	t.beats.add_choice(func() -> void: await StoryPage.tell_over(t.arena, due))


## Tells `keys` not yet told this run at once, and returns when the player has moved on.
static func tell(t: ArenaTable, keys: Array[String]) -> void:
	var due := _due(t.run, keys)
	if due.is_empty():
		return
	await StoryPage.tell_over(t.arena, due)


## Dawn: its line, by its number and the place the run goes to ("lab" or "alley").
static func dawn(t: ArenaTable) -> void:
	if t.run.dawn == null:
		return
	await tell(t, ["dawn.%d.%s" % [int(t.run.dawn.no), t.run.phase]])


# The keys of `keys` that have a line and are not yet told in `run`, marked told. None while
# the table tells no entries.
static func _due(run: RulesRun, keys: Array[String]) -> Array:
	if not on() or run == null:
		return []
	if _run == null or _run.get_ref() != run:
		_run = weakref(run)
		_told = {}
	var due: Array = []
	for key in keys:
		if _told.has(key):
			continue
		_told[key] = true
		if not StoryLines.line(key).is_empty():
			due.append(key)
	return due
