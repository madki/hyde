class_name SplitTransition
extends ColorRect
## The colour split, a change of scene for the whole screen: the picture comes apart into
## three coloured pictures (Jekyll's colour, Hyde's colour and a third), they slide away from
## each other, and snap back together as the new scene.
##
## Put scenes/split_transition.tscn last in a screen, over everything it should cover, and
## call `play` with the face being changed to and what makes the change:
##
##     _split.play(1.0, func() -> void: _bg.shift = 1.0)
##
## The change itself is made at once, under a kept copy of the screen as it was. Each of the
## three pictures then goes over from the copy to the live screen at its own moment, the new
## face's colour first and the old face's colour last, so that for a moment both men stand
## there, each in his own colour, pulled apart.
##
## Given a `linger` and a `place`, the pictures do not quite come together again round that
## place: the rest of the screen is whole, and what stands there stays split until the next
## `play`.
##
## The look (how far, which ways, the tearing) is on the material,
## shaders/split_material.tres. The colours and the timing are here.

signal finished

# The change, in seconds.
const APART := 0.1 # the pictures fly apart
const HELD := 0.09 # they hang there, still drifting outwards
const SNAP := 0.16 # they snap back, swing a little past each other and settle
const SECONDS := APART + HELD + SNAP

## How much further apart the pictures drift while they hang.
const DRIFT := 0.12
## When the first, second and third picture go over to the new scene, as a share of the
## whole change, and how long each takes over it. The second is the third colour.
const ARRIVALS := Vector3(0.24, 0.42, 0.6)
const ARRIVAL_TIME := 0.04
## How often the torn bands move, per second.
const TEAR_RATE := 22.0

# The split that lingers.
## How far its pictures breathe in and out, and how many times a second.
const LINGER_BREATH := 0.2
const LINGER_BREATH_RATE := 0.5
## How often its torn bands move, per second.
const LINGER_TEAR_RATE := 7.0

## The three colours the screen splits into. Any three will do as long as no one of them can
## be mixed from the other two.
@export var colour_jekyll := Color(0.03, 0.95, 0.92):
	set(value):
		colour_jekyll = value
		_set_colours()
@export var colour_hyde := Color(0.88, 0.06, 0.46):
	set(value):
		colour_hyde = value
		_set_colours()
@export var colour_third := Color(0.9, 1.0, 0.1):
	set(value):
		colour_third = value
		_set_colours()

var _tween: Tween
var _before: ImageTexture
var _towards := 1.0
# How far apart the pictures stay round the place once this change is over, and for how long
# they have stayed so.
var _linger := 0.0
var _lingered := 0.0
# Whether the split is over the live screen alone (`glitch`), with no kept picture under it.
var _live := false
var _size := 1.0
var _shake := 0.0


func _ready() -> void:
	hide()
	_set_colours()


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## Changes the scene inside a split. `face` is the face being changed to (0 = Jekyll,
## 1 = Hyde) and `change` is called at once to make the change. With a `linger` (on the scale
## of the split itself: 1 = as far apart as the pictures fly) the split stays open round
## `place`, whose position is its middle and whose size is how far it reaches each way, in
## 0..1 of the screen. Called while a split is under way, that one ends at once (its
## `finished` is sent) and this one starts.
func play(face: float, change: Callable, linger := 0.0, place := Rect2()) -> void:
	_cut_short()
	begin(face, change, linger, place)
	_tween = create_tween()
	_tween.tween_method(pose, 0.0, 1.0, SECONDS)
	_tween.tween_callback(_end)


## The split alone, over whatever the screen is doing: the pictures fly apart and snap back,
## all three showing the live screen, so a change that plays under it is seen through it.
## `size` scales how far apart they go (1 = as in a change of scene) and `shake` is how far
## the screen is also shaken at the start, as a fraction of its height, dying away.
## `seconds` is how long it takes. Called while a split is under way, that one ends at once
## (its `finished` is sent) and this one starts.
func glitch(size := 1.0, shake := 0.0, seconds := SECONDS) -> void:
	_cut_short()
	begin_glitch(size, shake)
	_tween = create_tween()
	_tween.tween_method(pose, 0.0, 1.0, seconds)
	_tween.tween_callback(_end)


## Shows the split over the live screen at its start, without playing it: `pose` then sets
## a moment of it.
func begin_glitch(size := 1.0, shake := 0.0) -> void:
	_live = true
	_size = size
	_shake = shake
	_linger = 0.0
	_set_param("linger", 0.0)
	pose(0.0)
	show()


## Keeps the screen as it is, makes the change and shows the split at its start, without
## playing it: `pose` then sets a moment of it.
func begin(face: float, change: Callable, linger := 0.0, place := Rect2()) -> void:
	_towards = face
	_live = false
	_size = 1.0
	_shake = 0.0
	# A split that lingered until now is in the kept picture already.
	_keep_screen()
	_linger = linger
	_lingered = 0.0
	_set_param("linger", 0.0)
	_set_param("linger_at", place.position)
	_set_param("linger_size", place.size.max(Vector2(0.001, 0.001)))
	change.call()
	pose(0.0)
	show()


## Sets the split to a moment of the change, `t` = 0..1.
func pose(t: float) -> void:
	var seconds := t * SECONDS
	var split: float
	if seconds < APART:
		split = ease(seconds / APART, 0.3) # fast out of the gate, slowing as it arrives
	elif seconds < APART + HELD:
		split = 1.0 + DRIFT * (seconds - APART) / HELD
	else:
		split = (1.0 + DRIFT) * (1.0 - _back_out((seconds - APART - HELD) / SNAP))
	_set_param("split", split * _size)
	# The shake jumps to a new place every frame and dies away over the first half.
	var shaking := _shake * (1.0 - smoothstep(0.0, 0.5, t))
	_set_param("shake", Vector2.from_angle(randf() * TAU) * shaking)
	# What lingers comes in as the rest snaps back, so the place never closes.
	_set_param("linger", _linger * smoothstep(APART + HELD, SECONDS, seconds))

	# The new face's colour goes over first, the old face's colour last.
	var first := smoothstep(ARRIVALS.x, ARRIVALS.x + ARRIVAL_TIME, t)
	var second := smoothstep(ARRIVALS.y, ARRIVALS.y + ARRIVAL_TIME, t)
	var third := smoothstep(ARRIVALS.z, ARRIVALS.z + ARRIVAL_TIME, t)
	if _live:
		_set_param("arrived", Vector3.ONE)
	elif _towards > 0.5:
		_set_param("arrived", Vector3(third, first, second))
	else:
		_set_param("arrived", Vector3(first, third, second))
	_set_param("tear_seed", floorf(seconds * TEAR_RATE))


func _process(delta: float) -> void:
	if not visible or is_playing() or _linger <= 0.0:
		return
	_lingered += delta
	_set_param("linger", _linger * (1.0 + LINGER_BREATH * sin(_lingered * TAU * LINGER_BREATH_RATE)))
	_set_param("tear_seed", floorf(_lingered * LINGER_TEAR_RATE))


## 0 to 1, going a little past 1 and coming back.
func _back_out(u: float) -> float:
	const PAST := 1.70158
	var v := u - 1.0
	return 1.0 + (PAST + 1.0) * v * v * v + PAST * v * v


## Ends a split that is under way, so that whoever waits for its `finished` is not left
## waiting. Its change of scene was made when it began.
func _cut_short() -> void:
	if is_playing():
		_tween.kill()
		_end()


func _end() -> void:
	if _linger <= 0.0:
		hide()
	finished.emit()


func _keep_screen() -> void:
	var image := get_viewport().get_texture().get_image()
	if _before and _before.get_size() == Vector2(image.get_size()) \
			and _before.get_format() == image.get_format():
		_before.update(image)
	else:
		_before = ImageTexture.create_from_image(image)
	_set_param("before", _before)


func _set_colours() -> void:
	var colours := Basis(_vec(colour_jekyll), _vec(colour_hyde), _vec(colour_third))
	if is_zero_approx(colours.determinant()):
		push_warning("SplitTransition: one of the three colours is a mix of the other two.")
		return
	_set_param("colour_jekyll", colours.x)
	_set_param("colour_hyde", colours.y)
	_set_param("colour_third", colours.z)
	_set_param("to_parts", colours.inverse())


func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _set_param(param: StringName, value: Variant) -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param, value)
