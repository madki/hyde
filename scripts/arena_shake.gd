class_name ArenaShake
## A shake of the whole picture, for a blow that lands: one call from anywhere,
##
##   ArenaShake.hit(0.3)   # light: about 3 px, gone in 0.17 s
##   ArenaShake.hit(0.6)   # medium
##   ArenaShake.hit(1.0)   # heavy: 10 px, gone in 0.3 s
##
## `strength` runs from 0 (nothing) to 1. The picture jumps that far to one side at once and
## swings back to rest, each swing smaller than the last. It needs no node and nothing to be
## set up or put back: it moves the canvas of the game's window and leaves it as it found it.
##
## - One shake at a time. A hit while another is still felt replaces it if it is stronger than
##   what is left of that one, and is dropped if it is not: call it freely, hits do not pile up.
## - `amount` (0 to 1, 0.5 as the game starts) scales every shake, for a setting; 0 is none.
## - Nothing shakes with "reduce flashes" on (ArenaPace.reduce_flashes), in a still (`--shot`),
##   in the self-test (`--selftest`), or while moves are played back at once (ArenaPace.SKIP).
## - It keeps the clock's time, not the beat queue's. A beat that the player is skipping should
##   not call it: `if not t.beats.is_skipping(): ArenaShake.hit(0.6)`.

## How far a hit of strength 1 throws the picture, in pixels, with `amount` at 1.
const REACH := 10.0
## How long a shake lasts, in seconds: the weakest and the strongest.
const TIME_LEAST := 0.12
const TIME_MOST := 0.3
## How many times it swings from side to side before it is at rest.
const SWINGS := 3.0
## How much of the throw goes across the swing, so that it is not a straight line.
const ACROSS := 0.3

## Scales every shake: 0 for none, 1 for the most.
static var amount := 0.5

static var _tween: Tween
static var _viewport: Viewport
static var _rest := Transform2D.IDENTITY
static var _along := Vector2.ZERO
static var _reach := 0.0
static var _left := 0.0


## Shakes the picture: `strength` from 0 to 1. See the top of this script.
static func hit(strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	var reach := REACH * strength * clampf(amount, 0.0, 1.0)
	if reach <= 0.0 or not _allowed():
		return
	var running := _tween != null and _tween.is_valid() and _tween.is_running()
	if running and _reach * _left >= reach:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if running:
		_tween.kill()
	else:
		_viewport = tree.root
		_rest = _viewport.canvas_transform
	_reach = reach
	_left = 1.0
	# Mostly up and down: a blow from above lands on the table.
	_along = Vector2.DOWN.rotated(randf_range(-0.9, 0.9)) * (1.0 if randf() < 0.5 else -1.0)
	_tween = tree.create_tween()
	_tween.tween_method(_move, 0.0, 1.0, lerpf(TIME_LEAST, TIME_MOST, strength))
	_tween.tween_callback(_settle)
	_move(0.0)


## True while the picture is off its place.
static func is_shaking() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


static func _allowed() -> bool:
	return not ArenaPace.reduce_flashes and ArenaPace.speed < ArenaPace.SKIP \
			and not Shot.has_arg("shot") and not Shot.has_arg("selftest")


# The picture `at` (0 to 1) of the way through the shake.
static func _move(at: float) -> void:
	if not is_instance_valid(_viewport):
		return
	_left = (1.0 - at) * (1.0 - at)
	var swing := at * SWINGS * PI
	var offset := (_along * cos(swing) + _along.orthogonal() * sin(swing * 1.3) * ACROSS) * _reach * _left
	_viewport.canvas_transform = _rest.translated(offset)


static func _settle() -> void:
	_left = 0.0
	if is_instance_valid(_viewport):
		_viewport.canvas_transform = _rest
