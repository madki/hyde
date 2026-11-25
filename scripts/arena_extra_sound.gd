class_name ArenaExtraSound
extends Node
## The table's heartbeat: it beats while one play is left in the round, as the table shows it
## (from the play that leaves one, or a round dealt with one), until the total of that last
## play lands in the score. It stops in every other way out: the round or the run ends, a new
## one begins, the plays go back above one, the arena is left.
##
## One function (`_update`) looks at what is shown and starts or stops the loop; it is called
## when the shown plays move, when a move begins, when a play's total lands and when a move is
## over (so a skipped move leaves the loop right too). The other sounds of a move are played
## by the moments' beats.

const LOOP := "heartbeat"

var _t: ArenaTable
## True while the plays shown are those of a round being played that the move being played
## back does not end. Not while a move that ends the round or the run plays, nor from a new
## round's start until its table is cleared.
var _live := false
## True from the start of the round's last play until its total lands.
var _landing := false
var _move := ""
## True while the heartbeat is asked for.
var _beating := false


static func setup(t: ArenaTable) -> void:
	var sound := ArenaExtraSound.new()
	sound._t = t
	t.arena.add_child(sound)
	t.move_begun.connect(sound._on_move_begun)
	t.shown.changed.connect(sound._on_shown)
	t.landed.connect(sound._on_landed)
	t.beats.emptied.connect(sound._on_emptied)


func _exit_tree() -> void:
	Sfx.stop_loop(LOOP, 0.0)


func _plays() -> int:
	return int(_t.shown.value("plays", 0))


# Starts or stops the heartbeat by what is shown now.
func _update() -> void:
	var on := _landing or (_live and _plays() == 1)
	if on == _beating:
		return
	# Kept here, not asked of Sfx: with no heartbeat file there is no loop, and the dread
	# must still end.
	_beating = on
	if on:
		Sfx.loop(LOOP, 1.0, 0.9)
		Music.set_dread("last_play", 0.7)
	else:
		Sfx.stop_loop(LOOP, 0.6)
		Music.set_dread("last_play", 0.0)


func _on_move_begun(move: String) -> void:
	_move = move
	_landing = move == "play" and _plays() == 1
	# The engine has already made the move: a round that is over is not to be counted down.
	if move == "round" or _t.run.phase != "play":
		_live = false
	_update()


func _on_shown(key: String, value: Variant) -> void:
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
