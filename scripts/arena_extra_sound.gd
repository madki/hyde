class_name ArenaExtraSound
extends Node
## The table's heartbeat. It beats for two dangers, as the table shows them:
##
## - The last play ("last_play"): while one play is left in the round (from the play that
##   leaves one, or a round dealt with one), until the total of that last play lands in the
##   score. Full volume, and `Music.set_dread("last_play", 0.7)`.
## - The line ("line"), from the shown "line/paper" and "line/ink". Near when Ink is within 2
##   of Paper or level with it: soft, and `Music.set_dread("line", 0.4)`. Ahead when Ink
##   outnumbers Paper, so the run ends if the round ends now: full volume, a little faster,
##   and `Music.set_dread("line", 1.0)`. It carries on across rounds and through moves while
##   the danger stands, and stops when the line is safe again.
##
## When both ask, the stronger is heard. Both stop when the run ends (from the start of the
## move that ends it), when a new run begins and when the arena is left. With no heartbeat
## file there is no loop, but the dread in the music and everything below still follow.
##
## For a part of the page that follows the heartbeat (it is the arena's child of this class):
## - `level() -> int`: 0 for none, 1 for the line near or a last play, 2 for Ink ahead.
## - `cause() -> Array[String]`: what asks for it now: [], ["line"], ["last_play"] or
##   ["line", "last_play"].
## - `beat(weight: float)`: sent on each beat of the heartbeat while `level()` is above 0,
##   with or without the file: weight 1.0 for the first beat of a pair, 0.75 for the second.
##   The beats lie at `BEATS` within a loop of `LENGTH` seconds, quicker by the pitch (1.12
##   when Ink is ahead). The first is sent on the frame after the loop starts. With the file,
##   each loop's beats are counted from when the sound begins again (Sfx.loop_restarted), so
##   that they stay with what is heard; without it, from `LENGTH`.
## - `changed()`: sent when `level()` or `cause()` changes.
##
## Two functions look at what is shown: `_read_line` when the line moves (once the frame is
## over, so that a table set key by key is read when it is whole), and `_update`, which starts,
## tunes or stops the loop, when the shown plays move, when a move begins, when a play's total
## lands and when a move is over (so a skipped move leaves the loop right too). The other
## sounds of a move are played by the moments' beats. With `--trace`, each change is printed.

## Sent on each beat of the heartbeat: `weight` 1.0 for the first of a pair, 0.75 for the second.
signal beat(weight: float)
## Sent when `level()` or `cause()` changes.
signal changed

const LOOP := "heartbeat"
## The heartbeat file's length and the times of its beats within it, in seconds at pitch 1,
## measured from the file: a lub at its start and a softer dub after it.
const LENGTH := 1.15
const BEATS: Array[float] = [0.0, 0.30]
const BEAT_WEIGHTS: Array[float] = [1.0, 0.75]

## Ink within this many of Paper, or level with it, is near.
const NEAR := 2
## The loop's volume and pitch for each danger, and the dread asked of the music.
const LAST_PLAY_VOLUME := 1.0
const LAST_PLAY_DREAD := 0.7
const NEAR_VOLUME := 0.45
const NEAR_DREAD := 0.4
const AHEAD_VOLUME := 1.0
const AHEAD_PITCH := 1.12
const AHEAD_DREAD := 1.0
## How long the loop takes to fade out when it stops.
const FADE := 0.6

var _t: ArenaTable
## True while the plays shown are those of a round being played that the move being played
## back does not end. Not while a move that ends the round or the run plays, nor from a new
## round's start until its table is cleared.
var _live := false
## True from the start of the round's last play until its total lands.
var _landing := false
var _move := ""
## The line as last read: 0 safe, 1 near, 2 ahead.
var _line := 0
var _line_queued := false
## True from the start of the move that ends the run until the next run's first move.
var _ended := false
## The loop asked of Sfx: its volume (0 for none) and pitch.
var _volume := 0.0
var _pitch := 1.0
var _level := 0
var _cause: Array[String] = []
## Where the heartbeat is within its loop, in seconds of the file, and the next beat's index.
var _pos := 0.0
var _next_beat := 0


static func setup(t: ArenaTable) -> void:
	var sound := ArenaExtraSound.new()
	sound._t = t
	t.arena.add_child(sound)
	t.move_begun.connect(sound._on_move_begun)
	t.shown.changed.connect(sound._on_shown)
	t.landed.connect(sound._on_landed)
	t.beats.emptied.connect(sound._on_emptied)
	Sfx.loop_restarted.connect(sound._on_loop_restarted)


## 0 for none, 1 for the line near or a last play, 2 for Ink ahead of Paper.
func level() -> int:
	return _level


## What asks for the heartbeat now: "line", "last_play", both, or none.
func cause() -> Array[String]:
	return _cause.duplicate()


func _exit_tree() -> void:
	Sfx.stop_loop(LOOP, 0.0)


func _process(delta: float) -> void:
	if _volume <= 0.0:
		return
	_pos += delta * _pitch
	# Every beat passed is sent, however long the frame.
	while true:
		if _next_beat >= BEATS.size():
			# While the sound loops, the next pair waits for it to begin again.
			if _pos < LENGTH or Sfx.is_looping(LOOP):
				return
			_pos -= LENGTH
			_next_beat = 0
		if _pos < BEATS[_next_beat]:
			return
		beat.emit(BEAT_WEIGHTS[_next_beat])
		_next_beat += 1


# The heartbeat's sound has begun again: so does the count of its beats.
func _on_loop_restarted(sound: String) -> void:
	if sound == LOOP and _volume > 0.0:
		_pos = 0.0
		_next_beat = 0


func _plays() -> int:
	return int(_t.shown.value("plays", 0))


# Reads the line as shown: 0 safe (or not shown yet), 1 near, 2 ahead.
func _read_line() -> void:
	_line_queued = false
	_line = 0
	if _t.shown.has("line/paper") and _t.shown.has("line/ink"):
		var paper := int(_t.shown.value("line/paper", 0))
		var ink := int(_t.shown.value("line/ink", 0))
		if ink > paper:
			_line = 2
		elif paper + ink > 0 and paper - ink <= NEAR:
			_line = 1
	_update()


# Starts, tunes or stops the heartbeat by what is shown now.
func _update() -> void:
	var last_play := _landing or (_live and _plays() == 1)
	var line := 0 if _ended else _line
	var cause: Array[String] = []
	if line > 0:
		cause.append("line")
	if last_play:
		cause.append("last_play")
	var level := 2 if line == 2 else (0 if cause.is_empty() else 1)
	var volume := LAST_PLAY_VOLUME if last_play else 0.0
	var pitch := 1.0
	if line == 1:
		volume = maxf(volume, NEAR_VOLUME)
	elif line == 2:
		volume = maxf(volume, AHEAD_VOLUME)
		pitch = AHEAD_PITCH
	# The dread is kept here, not asked of Sfx: with no heartbeat file there is no loop, and
	# the dread must still follow.
	Music.set_dread("last_play", LAST_PLAY_DREAD if last_play else 0.0)
	Music.set_dread("line", [0.0, NEAR_DREAD, AHEAD_DREAD][line])
	if volume != _volume or pitch != _pitch:
		if volume <= 0.0:
			Sfx.stop_loop(LOOP, FADE)
		else:
			if _volume <= 0.0:
				_pos = 0.0
				_next_beat = 0
			Sfx.loop(LOOP, pitch, volume)
		_volume = volume
		_pitch = pitch
	if level == _level and cause == _cause:
		return
	_level = level
	_cause = cause
	if Shot.has_arg("trace"):
		print("heartbeat: level %d, cause %s, volume %.2f, pitch %.2f (paper %d, ink %d, plays %d, move %s)" % [
			level, "+".join(cause) if not cause.is_empty() else "none", volume, pitch,
			int(_t.shown.value("line/paper", 0)), int(_t.shown.value("line/ink", 0)), _plays(), _move])
	changed.emit()


func _on_move_begun(move: String) -> void:
	_move = move
	_landing = move == "play" and _plays() == 1
	# The engine has already made the move: a round that is over is not to be counted down,
	# and a run that is over is not to be warned of.
	if move == "round" or _t.run.phase != "play":
		_live = false
	var ended := _t.run.phase == "end"
	if _ended and not ended:
		# A new run: the line shown is the last run's until its first round sets it.
		_line = 0
	_ended = ended
	_update()


func _on_shown(key: String, value: Variant) -> void:
	if key.begins_with("line/"):
		if not _line_queued:
			_line_queued = true
			_read_line.call_deferred()
		return
	if key != "plays":
		return
	# A new round's table is cleared (its plays at nothing) before its numbers are set.
	if _move == "round" and int(value) == 0:
		_live = true
	_update()


func _on_landed() -> void:
	_landing = false
	_update()


func _on_emptied() -> void:
	_landing = false
	_live = _t.run.phase == "play"
	_update()
