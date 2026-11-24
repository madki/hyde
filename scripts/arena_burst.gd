class_name ArenaBurst
extends Control
## The breakout's burst: Hyde's ink bursts from the end of the restraint track and crosses
## the whole page, fast, from the left; then it thins away over the page it has changed.
## Its leading edge is the round's one full-strength flare, cyan-white at its front and
## magenta behind: it rises quickly and falls slowly (ArenaPace.FLARE_RISE, FLARE_FALL). With
## "reduce flashes" on there is no flare: the ink alone crosses, a little slower.

const INK := Palette.INK_BODY
const FLARE := Palette.HYDE
const FRONT := Palette.SALT
const CROSS_TIME := 0.45
const CROSS_TIME_CALM := 0.8
const THIN_TIME := 0.6

var _from := Vector2.ZERO
var _reach := 0.0:
	set(value):
		_reach = value
		queue_redraw()
var _cover := 0.0:
	set(value):
		_cover = value
		queue_redraw()
var _flare := 0.0:
	set(value):
		_flare = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## The ink bursts from `from` (a point on the page) across the page. `changed` is called when
## it covers the page: the page under it is then given to Hyde. Await it.
func play(beats: ArenaBeats, from: Vector2, changed: Callable) -> void:
	_from = get_global_transform().affine_inverse() * from
	var far := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		far = maxf(far, _from.distance_to(corner))
	var calm := ArenaPace.reduce_flashes
	_reach = 0.0
	_cover = 0.92
	_flare = 0.0
	var cross := beats.tween()
	cross.tween_property(self, "_reach", far + 40.0, CROSS_TIME_CALM if calm else CROSS_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if not calm:
		var flare := beats.tween()
		flare.tween_property(self, "_flare", 1.0, ArenaPace.FLARE_RISE)
		flare.tween_property(self, "_flare", 0.0, ArenaPace.FLARE_FALL + 0.1)
	await cross.finished
	changed.call()
	var thin := beats.tween()
	thin.tween_property(self, "_cover", 0.0, THIN_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await thin.finished


func _draw() -> void:
	if _cover <= 0.0 or _reach <= 0.0:
		return
	draw_circle(_from, _reach, Color(INK, _cover))
	if _flare > 0.0:
		draw_arc(_from, maxf(_reach - 9.0, 1.0), 0.0, TAU, 96, Color(FLARE, _flare * 0.8), 18.0)
		draw_arc(_from, _reach, 0.0, TAU, 96, Color(FRONT, _flare), 5.0)
