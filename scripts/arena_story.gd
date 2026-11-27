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
## cannot move it on; one outside a move is awaited directly. Entries that fall in one move
## are told on one page, where the first of them was due, in the book's order (ORDER): the
## draught before his arrival, the breakout before it. The page is laid over the whole
## table, as the arena's last child: it draws over every part of the table and has every press
## before them, and the presses that move it on are its own. While it is up the table's
## `story_up` is true.
##
## Driven from the command line (SceneFlow.CUT_ARGS: the bench, the self-test, a still) the
## table tells no entry, since no player is there to move one on; `--story` tells them there,
## and the bench then presses each page on (ArenaBench), but for the one a still with `--at`
## is taken of:
##
##   tools/shot.sh /abs/out.png res://scenes/arena.tscn --story --at=4

const OPENING: Array[String] = ["opening.1", "opening.2", "opening.3"]
## The order of the keys on one page, each by how it begins: as the book has them.
const ORDER: Array[String] = ["opening.", "night.", "first_draught", "breakout", "window", "arrival", "dawn."]

## True once the opening's pages have been told in this sitting: later runs begin at night 1's
## line.
static var opened := false

## The run the keys in `_told` were told in. A new run starts clean.
static var _run: WeakRef = null
static var _told := {}

## The keys of the entry that is queued and not yet begun, and the queue it is in: an entry
## added to that queue meanwhile joins it.
static var _queued: Array = []
static var _queued_in: ArenaBeats = null


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


## Queues `keys` not yet told this run as a beat that waits for the player. If an entry of this
## move is still waiting in the queue, they are told with it, on its page.
static func add(t: ArenaTable, keys: Array[String]) -> void:
	var due := _due(t.run, keys)
	if due.is_empty():
		return
	if is_instance_valid(_queued_in) and _queued_in == t.beats and not _queued.is_empty():
		due.append_array(_queued)
		_queued.assign(_in_order(due))
		return
	var entry := _in_order(due)
	_queued = entry
	_queued_in = t.beats
	t.beats.add_choice(func() -> void:
		# From here on a new entry is a page of its own.
		if is_same(_queued, entry):
			_queued = []
			_queued_in = null
		t.freshen()
		await _tell_over(t, entry))


## Tells `keys` not yet told this run at once, and returns when the player has moved on.
static func tell(t: ArenaTable, keys: Array[String]) -> void:
	var due := _due(t.run, keys)
	if due.is_empty():
		return
	await _tell_over(t, _in_order(due))


## The keys told in the run being played (kept with the run, see RunSave); with `run`, none
## unless it is that run.
static func told(run: RulesRun = null) -> Array:
	if _run == null or _run.get_ref() == null or (run != null and _run.get_ref() != run):
		return []
	return _told.keys()


## A run taken up again: `keys` were told in it before, and are not told again. The opening's
## pages were told in that sitting or an earlier one.
static func take(run: RulesRun, keys: Array) -> void:
	opened = true
	_run = weakref(run)
	_told = {}
	for key: Variant in keys:
		_told[str(key)] = true


## Dawn: its line, by its number and the place the run goes to ("lab" or "alley").
static func dawn(t: ArenaTable) -> void:
	if t.run.dawn == null:
		return
	await tell(t, ["dawn.%d.%s" % [int(t.run.dawn.no), t.run.phase]])


# The page over `t`'s table, with `keys` on it.
static func _tell_over(t: ArenaTable, keys: Array) -> void:
	t.story_up = true
	await StoryPage.tell_over(t.arena, keys)
	t.story_up = false


# `keys` in the order of one page (ORDER); keys that begin alike keep their own order.
static func _in_order(keys: Array) -> Array:
	var out: Array = []
	for head in ORDER:
		for key: String in keys:
			if key.begins_with(head) and not out.has(key):
				out.append(key)
	for key: String in keys:
		if not out.has(key):
			out.append(key)
	return out


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
