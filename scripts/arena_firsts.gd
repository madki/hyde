class_name ArenaFirsts
## The first night's notes: the first time each thing of the game happens, the table stops on
## a plain notice (ArenaNotice) that rings the thing and says in two lines what it is and what
## to do about it. Each is shown once to a player and kept in `path`; `clear` forgets them all.
## A note counts as shown once it has been on the page for READ seconds: one dismissed sooner
## (by a click meant to hurry the move before it) is owed once more, and is then kept as shown
## however soon it is dismissed. It is not shown again at the very next move.
##
## The words are in NOTES, one entry for each note, in the order they are weighed:
##
## - `key`: the name it is remembered by. Two entries with one key are two wordings of one
##   note (the dawn's, by its place): the first to be shown is the only one.
## - `when`: which of the conditions of `_holds` makes it owed.
## - `title`, `lines`: the words. A name in braces is filled in from the run (see `values`),
##   so a number is never written here.
## - `rings`: the zone of the page (ArenaLayout.zones) the notice rings.
## - `urgent`: the player cannot play on well without it. See the pacing below.
##
## The arena calls `show_due` when a move has been played back. Pacing, so that a first round
## is not all reading:
##
## - At most one note a move. The others are owed again at the next move while their
##   condition holds.
## - At most MOST_A_ROUND while a round is played. The note at a round's end and the dawn's
##   stand apart from that count, and so does a note dismissed before it could be read.
## - Never the note of the move before, urgent or not.
## - None in a move that has already stopped on a notice of its own (Roots of his joining, a
##   Root changing side): it waits for the next move.
## - An urgent note is shown first, whatever the count and the move's own notice say.
##
## A table driven from the command line (ArenaBench) has no player: its notes are passed with
## its other notices, remembered for that run only, and nothing is read from or written to
## `path`. For a still of one note, `--note=<key>` leaves that note alone unseen:
##
##   tools/shot.sh /abs/out.png res://scenes/arena.tscn --seed=5 --note=draught --at=7

## The most notes shown while one round is played.
const MOST_A_ROUND := 3
## A note dismissed before it has been on the page this long, in seconds, was not read.
const READ := 1.0
## The events of a move that has stopped on a notice of its own.
const STOPPING := ["breed", "stained", "converted", "turn"]

const NOTES: Array[Dictionary] = [
	{
		"key": "goal", "when": "deal", "rings": "goal",
		"title": "The round",
		"lines": [
			"Choose up to {max_play} cards that make a hand, and press PLAY.",
			"Reach the target of {target} before your {plays} plays run out.",
		],
	},
	{
		"key": "score", "when": "scored", "rings": "goal",
		"title": "The score",
		"lines": [
			"A play scores chips times mult. The hand gives some of each, and every card adds its chips.",
			"Jekyll's best hand is {best}: one Root of each symbol, {symbols}.",
		],
	},
	{
		"key": "restraint", "when": "restraint", "rings": "restraint",
		"title": "Restraint",
		"lines": [
			"Every play of Jekyll's fills one step.",
			"Fill all {limit} and Hyde breaks out: he takes the table, and Roots of his join your deck.",
		],
	},
	{
		"key": "draught", "when": "draught", "rings": "draught",
		"title": "The draught",
		"lines": [
			"Press the flask, and Hyde has the table. He scores more, but each drink leaves more Ink Roots in your deck.",
			"It is never forced. But a drink empties the restraint, and a breakout brings more of them.",
		],
	},
	{
		"key": "hyde", "when": "hyde", "rings": "hand", "urgent": true,
		"title": "Hyde plays",
		"lines": [
			"Hyde cannot play your Paper Roots: only his Ink Roots, and the Factors, which both men play.",
			"His hands want Roots alike: two of one symbol make {pair}, three make {three}.",
		],
	},
	{
		"key": "craving", "when": "craving", "rings": "symbols",
		"title": "Craving",
		"lines": [
			"Hyde's hands add Craving to the symbols he plays. Each pip makes his Roots of that symbol worth more.",
			"At {cap} pips it becomes a Habit, which stays for good, and a copy of that Ink Root joins your deck.",
		],
	},
	{
		"key": "stored", "when": "stored", "rings": "readout",
		"title": "Restraint in store",
		"lines": [
			"The drink put Jekyll's restraint in store: these drops.",
			"Hyde's first hand with a Root spends them, for {pay} mult a drop. Salt throws them away.",
		],
	},
	{
		"key": "salt", "when": "salt", "rings": "salt",
		"title": "Salt",
		"lines": [
			"Press the salt, and Jekyll has the table again, with the restraint empty.",
			"It costs one dose of the {doses} you hold. More are bought only at dawn.",
		],
	},
	{
		"key": "won", "when": "won", "rings": "sovereigns",
		"title": "The pay",
		"lines": [
			"A round won pays {round_pay} sovereigns, and {unused_pay} more for each play left over.",
			"The first two rounds of a night, won as Jekyll, also offer a card for your deck.",
		],
	},
	{
		"key": "dawn", "when": "lab", "rings": "sovereigns",
		"title": "The laboratory",
		"lines": [
			"Jekyll has the table at dawn, so the laboratory opens before the next night.",
			"Your sovereigns buy cards, instruments and salt there, or strike a card out of the deck.",
		],
	},
	{
		"key": "dawn", "when": "alley", "rings": "sovereigns",
		"title": "The back alley",
		"lines": [
			"Hyde has the table at dawn, so it is the back alley, not the laboratory.",
			"He is given a Habit and an instrument there. Sovereigns buy only salt, at a higher price.",
		],
	},
	{
		"key": "line", "when": "line", "rings": "balance", "urgent": true,
		"title": "The line",
		"lines": [
			"Ink is within {near} of Paper, and the page's edges beat to say so. Ink must not be ahead when a round ends.",
			"Push it back with {sublimation}: Jekyll plays a Paper Root with the Ink Root of its symbol, which turns to paper.",
		],
	},
]

## Where the notes that have been shown are kept.
static var path := "user://firsts.cfg"

## The keys of the notes shown, each to true. Null until first asked for.
static var _seen: Variant = null
## How many notes have been shown while this round was played.
static var _in_round := 0
## The key of the note shown at the move before, or "".
static var _last := ""
## Whether the note last offered was counted in its round.
static var _counted := false
## The keys of the notes dismissed once before they could be read, each to true: for this
## sitting only.
static var _unread := {}
## The key of the note last offered, when that was its second showing; else "".
static var _again := ""


## Shows the note owed now, if there is one, and returns when the player has dismissed it.
## `events` are those of the move that has just been played back on `t`. Await it.
static func show_due(t: ArenaTable, events: Array) -> void:
	var table := RulesView.table(t.run)
	var notice := t.moments.notice
	if notice == null or ArenaNotice.pass_at_once:
		# No player is there to read it: it is passed, and remembered.
		take(table, events)
		return
	var note := offer(table, events)
	if note.is_empty():
		return
	if table.phase == "play":
		# The table as the engine has it, so that the hand under the note shows what can be played.
		t.sync()
	var what := sheet(note, table, t.run.dials, t.arena.size)
	t.beats.add_choice(func() -> void: await notice.show_notice(what))
	await t.beats.run()
	dismissed(note.key, notice.shown_for)


## The note to show after a move with these `events` has left `table` as it is, or an empty
## dictionary. It is counted in its round, and remembered as shown only by `dismissed`.
## Call it once for each move: the note of one move is not offered at the next.
static func offer(table: Dictionary, events: Array) -> Dictionary:
	if _has(events, "shuffle"):
		_in_round = 0
	var note := pick(table, events, seen(), _in_round, _last)
	_last = note.get("key", "")
	_again = _last if _unread.has(_last) else ""
	_counted = not note.is_empty() and table.phase == "play"
	if _counted:
		_in_round += 1
	return note


## The note `key` has left after `shown` seconds on the page: it is remembered as shown if
## that was long enough to read it (READ), or if this was its second showing. Else it stays
## owed once more, and its showing is not counted in the round.
static func dismissed(key: String, shown: float) -> void:
	if shown >= READ or key == _again:
		_unread.erase(key)
		mark(key)
		return
	_unread[key] = true
	if _counted and key == _last:
		_counted = false
		_in_round = maxi(0, _in_round - 1)


## `offer`, with the note remembered as shown at once: for a table with no player.
static func take(table: Dictionary, events: Array) -> Dictionary:
	var note := offer(table, events)
	if not note.is_empty():
		mark(note.key)
	return note


## The entries of NOTES whose condition holds on `table` (RulesView.table) after a move with
## these `events`, in NOTES' order. It knows nothing of which have been shown.
static func due(table: Dictionary, events: Array) -> Array:
	var out: Array = []
	for note: Dictionary in NOTES:
		if _holds(note.when, table, events):
			out.append(note)
	return out


## The one note to show now, or an empty dictionary: the first of `due` that is not in `seen`
## ({key: true}) and that the pacing lets through, an urgent one before the others.
## `in_round` is how many have been shown while this round was played, and `last` the key of
## the note shown at the move before, which is passed over.
static func pick(table: Dictionary, events: Array, seen_keys: Dictionary, in_round: int, last: String = "") -> Dictionary:
	var playing: bool = table.phase == "play"
	var held: bool = playing and (in_round >= MOST_A_ROUND or stops(events))
	var first := {}
	for note: Dictionary in due(table, events):
		if seen_keys.has(note.key) or note.key == last:
			continue
		if note.get("urgent", false):
			return note
		if first.is_empty() and not held:
			first = note
	return first


## True when a move with these events has stopped on a notice of its own: Roots of his
## joined the deck by a rule, or a Root changed side.
static func stops(events: Array) -> bool:
	for e: Dictionary in events:
		if e.t in STOPPING or (e.t == "joined" and e.get("why", "") != "reward"):
			return true
	return false


## What ArenaNotice.show_notice takes for `note`: its words with the run's numbers in them,
## and the place of its ring on a page of this size.
static func sheet(note: Dictionary, table: Dictionary, dials: RulesDials, page: Vector2) -> Dictionary:
	var filled := values(table, dials)
	var lines: Array = []
	for line: String in note.lines:
		lines.append(line.format(filled))
	var what := {"title": (note.title as String).format(filled), "lines": lines, "tone": "plain"}
	var zones := ArenaLayout.zones(page)
	if zones.has(note.get("rings", "")):
		what.at = zones[note.rings]
	return what


## What the names in braces stand for: the round's and the run's numbers, and the names of
## the hands the words speak of.
static func values(table: Dictionary, dials: RulesDials) -> Dictionary:
	var hands: Dictionary = RulesConfig.HANDS
	var labels: Array = []
	for sym: String in RulesConfig.ROOTS:
		labels.append(RulesConfig.ROOT[sym].label)
	return {
		"target": ArenaMomentRound.thousands(int(table.target)),
		"plays": dials.plays,
		"max_play": dials.max_play,
		"limit": int(table.restraint.limit),
		"cap": dials.craving_cap,
		"pay": dials.restraint_pay,
		"doses": int(table.salt.doses),
		"round_pay": dials.round_pay,
		"unused_pay": dials.unused_play_pay,
		"near": ArenaExtraSound.NEAR,
		"best": hands.jekyll.lucid.name,
		"symbols": "%s, %s and %s" % labels,
		"sublimation": hands.jekyll.sublimation.name,
		"pair": hands.hyde.fixation.name,
		"three": hands.hyde.mania.name,
	}


## The keys of the notes that have been shown, each to true.
static func seen() -> Dictionary:
	if _seen == null:
		_seen = {}
		if _driven():
			# A still of one note: every other counts as shown.
			var only := Shot.arg("note")
			for note: Dictionary in NOTES:
				if only != "" and note.key != only:
					_seen[note.key] = true
		else:
			var file := ConfigFile.new()
			if file.load(path) == OK and file.has_section("seen"):
				for key in file.get_section_keys("seen"):
					_seen[key] = true
	return _seen


## Remembers that the note `key` has been shown.
static func mark(key: String) -> void:
	seen()[key] = true
	_save()


## Forgets every note shown, so that each is shown again the next time its thing happens.
static func clear() -> void:
	_seen = {}
	_forget_sitting()
	_save()


## Reads what is kept again at the next question: for a test that has changed `path`.
static func forget_loaded() -> void:
	_seen = null
	_forget_sitting()


# Forgets what is kept for this sitting only: the round's count, the move before, and the
# notes dismissed unread.
static func _forget_sitting() -> void:
	_in_round = 0
	_last = ""
	_counted = false
	_unread = {}
	_again = ""


# Writes the keys shown to `path`. Not for a table driven from the command line.
static func _save() -> void:
	if _driven():
		return
	var file := ConfigFile.new()
	for key: String in seen():
		file.set_value("seen", key, true)
	file.save(path)


# True when the bench drives the table from the command line: no player is there to be
# taught, and nothing kept on this machine is read or changed.
static func _driven() -> bool:
	for name: String in ["shot", "keys", "quit", "selftest"]:
		if Shot.has_arg(name):
			return true
	return false


# Whether the condition `when` holds: the names NOTES uses.
static func _holds(when: String, table: Dictionary, events: Array) -> bool:
	var phase: String = table.phase
	if when == "won":
		# A round's end that goes on: the run's last round is its ending's.
		for e: Dictionary in events:
			if e.t == "round_end" and e.how == "won":
				return phase == "result"
		return false
	if when in ["lab", "alley"]:
		return phase == when
	if phase != "play":
		return false
	var jekyll: bool = table.stance == "jekyll"
	match when:
		"deal":
			return true
		"scored":
			return _has(events, "scored")
		"restraint":
			return jekyll and int(table.restraint.meter) > 0
		"draught":
			return bool(table.draught.ok)
		"hyde":
			return not jekyll
		"craving":
			for sym: String in table.symbols:
				if int(table.symbols[sym].craving) > 0:
					return true
			return false
		"stored":
			return int(table.restraint.stored) > 0
		"salt":
			return bool(table.salt.ok)
		"line":
			return int(table.line.ink) > 0 and int(table.line.cushion) <= ArenaExtraSound.NEAR
	return false


static func _has(events: Array, type: String) -> bool:
	for e: Dictionary in events:
		if e.t == type:
			return true
	return false
