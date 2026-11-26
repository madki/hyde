class_name ArenaPour
extends Control
## Ink poured between a notice and the pool at the back of the page, so that the one is seen to
## cause the other. Drawn by code, in the ink's own colours.
##
## - A pour: when Roots of his have been shown on a notice in his tone, the blot that lay
##   behind them stays on the page as the sheet leaves and runs to the ink's edge as a stream
##   of blobs along a shallow curve, each FLIGHT seconds on its way. `landed` is sent as the
##   first reaches the pool; `reach_pool` then has the page surge where it came in.
## - A wash: when a Root of his is turned, pale blobs leave the ink's edge for the card, the
##   other way, while the pool draws back.
##
## Make one with `ArenaPour.under(layer, beats)`: it lies on the page just under `layer` (the
## layer cards travel on), fills the page, and frees itself when it is done.
##
##   var pour := ArenaPour.under(travel, beats)
##   pour.watch(notice)                       # before the notice is shown
##   await notice.show_notice(what)
##   pour.run(notice.centres, first_lands)    # or pour.drop() when nothing is to pour
##   ...
##   if not pour.has_landed:
##       await pour.landed
##   pour.reach_pool()                        # after the line's marks have been given
##
##   ArenaPour.under(travel, beats).wash(card_centre)
##
## It plays at the beat queue's rate. Whoever makes one leaves it out with "reduce flashes" on
## and in a move that is skipped: the pool and the line then change as they would without it.

## The first blob of a pour has reached the pool.
signal landed

const BODY := Palette.INK_BODY
const LIGHT := Palette.INK_BLOOM
const GLINT := Palette.HYDE
const PALE := Palette.INK_WASH
## How long one blob is on its way, and how long after the first the last sets off.
const FLIGHT := 0.5
const SPREAD := 0.25
## Blobs of a pour: this many a Root and a few more, and never more than MOST.
const PER_ROOT := 6
const FEW := 4
const MOST := 30
const WASH_BLOBS := 11
## How far the blot reaches beyond the row of cards it lies behind, as the notice draws it.
const BLOT_GROW := Vector2(34.0, 6.0)
## How far inside the ink's edge a blob comes to rest.
const INSIDE := 16.0

enum { IDLE, WATCHING, GATHERING, POURING, WASHING }

## True once the first blob of a pour has reached the pool.
var has_landed := false

var _beats: ArenaBeats
var _notice: ArenaNotice
var _state := IDLE
## The highest the watched notice's opacity has been: it is leaving once it falls under it.
var _seen := 0.0
## How much of the blot shows, 0 to 1, while the sheet over it leaves.
var _gather := 0.0
## The blot, in this layer's coordinates, and the number it is drawn from.
var _middle := Vector2.ZERO
var _reach := Vector2.ZERO
var _seed := 0
## Each blob: {from, to, lift, radius, starts, light}.
var _blobs: Array[Dictionary] = []
## How long the blot rests before its first blob sets off.
var _lead := 0.0
## Where the stream comes in, on the page.
var _mouth := Vector2.ZERO
var _released := false
var _finished := false
var _clock := 0.0:
	set(value):
		_clock = value
		queue_redraw()
		if _state == POURING and not has_landed and _clock >= _lead + FLIGHT:
			has_landed = true
			landed.emit()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## A new pour on the page that holds `layer`, lying just under it.
static func under(layer: Control, queue: ArenaBeats) -> ArenaPour:
	var pour := ArenaPour.new()
	pour._beats = queue
	var page := layer.get_parent()
	page.add_child(pour)
	page.move_child(pour, layer.get_index())
	return pour


## Watches `notice`, which is about to be shown: as its sheet leaves, the blot behind its cards
## comes up on the page under it, so that the ink is never gone.
func watch(notice: ArenaNotice) -> void:
	_notice = notice
	_seen = 0.0
	_state = WATCHING
	set_process(true)


## The blot behind the cards that lay at `centres` (on the page, as the notice left them) runs
## to the ink's edge. Its first blob lands `first_lands` seconds from now, and no sooner than
## one blob's flight.
func run(centres: Array[Vector2], first_lands: float = FLIGHT) -> void:
	if centres.is_empty():
		drop()
		return
	set_process(false)
	_blot_behind(centres)
	_gather = 1.0
	_lead = maxf(first_lands - FLIGHT, 0.0)
	var edge := _ink_edge()
	var page := get_global_rect()
	# The pool's edge, or a place in the pool beside the blot when the ink already lies under it.
	var to_x := maxf(edge + INSIDE, to_page(_middle).x + _reach.x + 40.0)
	_mouth = Vector2(minf(to_x, page.end.x - 24.0), to_page(_middle).y)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var count := mini(PER_ROOT * centres.size() + FEW, MOST)
	_blobs.clear()
	for i in count:
		var angle := rng.randf() * TAU
		var out := sqrt(rng.randf()) * 0.85
		var from := _middle + Vector2(cos(angle) * _reach.x, sin(angle) * _reach.y) * out
		var to := _local(_mouth) + Vector2(rng.randf_range(0.0, 26.0), rng.randf_range(-38.0, 38.0))
		_blobs.append({
			"from": from, "to": to,
			"lift": clampf(from.distance_to(to) * rng.randf_range(0.1, 0.22), 14.0, 80.0),
			"radius": rng.randf_range(6.0, 12.0), "starts": 0.0, "light": i % 3 == 0,
		})
	# The stream is drawn out of the blot's near side: the blobs nearest the pool go first.
	_blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from.x > b.from.x)
	for i in count:
		_blobs[i].starts = SPREAD * i / float(maxi(count - 1, 1))
	_state = POURING
	if _beats:
		_beats.sound("pour", Sfx.vary(0.04))
	_play(_lead + SPREAD + FLIGHT)


## The ink has come in: the page surges where the stream reached it. Call it once the line's
## marks have been given, so that the page, which also surges by itself when the shown line
## grows, makes one surge of the two.
func reach_pool() -> void:
	var page := get_parent()
	if page.has_method("surge_from"):
		page.call_deferred("surge_from", _mouth)
	_released = true
	_leave()


## A pale wash leaves the ink's edge for the card at `to` (on the page).
func wash(to: Vector2) -> void:
	set_process(false)
	var from := Vector2(_ink_edge() + INSIDE, to.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(to)
	_blobs.clear()
	for i in WASH_BLOBS:
		var start := _local(from) + Vector2(rng.randf_range(0.0, 46.0), rng.randf_range(-70.0, 70.0))
		var end := _local(to) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-30.0, 30.0))
		_blobs.append({
			"from": start, "to": end,
			"lift": clampf(start.distance_to(end) * rng.randf_range(0.1, 0.22), 14.0, 80.0),
			"radius": rng.randf_range(7.0, 13.0), "starts": SPREAD * i / float(WASH_BLOBS - 1),
			"light": i % 2 == 0,
		})
	_lead = 0.0
	_released = true
	_state = WASHING
	_play(SPREAD + FLIGHT)


## Nothing is to pour after all: it leaves.
func drop() -> void:
	_released = true
	_finished = true
	_leave()


## A point of this layer on the page.
func to_page(point: Vector2) -> Vector2:
	return get_global_transform() * point


func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _play(seconds: float) -> void:
	_clock = 0.0
	var t := _beats.tween() if _beats else create_tween()
	t.tween_property(self, "_clock", seconds, seconds)
	t.tween_callback(func() -> void:
		_finished = true
		_leave())


func _leave() -> void:
	if _released and _finished:
		queue_free()


# The blot as the notice drew it behind the row of cards whose middles lay at `centres`.
func _blot_behind(centres: Array[Vector2]) -> void:
	var half := ArenaCard.SIZE * ArenaNotice.CARD_SCALE * 0.5
	var box := Rect2(_local(centres[0]) - half, half * 2.0)
	for centre: Vector2 in centres:
		box = box.merge(Rect2(_local(centre) - half, half * 2.0))
	_middle = box.get_center()
	_reach = box.size * 0.5 + BLOT_GROW
	_seed = hash(centres)


# Where the ink's edge stands across the page (its x on the page): the ink comes in from the
# right and covers its share of the page's width.
func _ink_edge() -> float:
	var page := get_global_rect()
	var share := 0.5
	var inks := get_parent().find_children("*", "ArenaInk", false, false)
	if not inks.is_empty():
		var ink := inks[0] as ArenaInk
		share = ink.percent / 100.0
		if ink.paper:
			page = ink.paper.get_global_rect()
	return page.end.x - page.size.x * share


func _process(_delta: float) -> void:
	if not is_instance_valid(_notice):
		return
	var shows := _notice.modulate.a
	if _state == WATCHING and _notice.showing:
		if shows < _seen - 0.001 and not _notice.centres.is_empty():
			_blot_behind(_notice.centres)
			_state = GATHERING
		_seen = maxf(_seen, shows)
	if _state == GATHERING:
		_gather = clampf(1.0 - shows, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	match _state:
		GATHERING:
			_draw_blot(1.0, _gather)
		POURING:
			var gone := clampf((_clock - _lead) / SPREAD, 0.0, 1.0)
			if gone < 1.0:
				_draw_blot(sqrt(1.0 - gone), 1.0)
			for blob: Dictionary in _blobs:
				var done := (_clock - _lead - float(blob.starts)) / FLIGHT
				if done <= 0.0:
					draw_circle(blob.from, float(blob.radius) * 1.5, LIGHT if blob.light else BODY, true, -1.0, true)
				elif done < 1.0:
					_draw_blob(blob, done, LIGHT if blob.light else BODY, 1.0, true)
		WASHING:
			for blob: Dictionary in _blobs:
				var done := (_clock - float(blob.starts)) / FLIGHT
				if done > 0.0 and done < 1.0:
					var comes := smoothstep(0.0, 0.2, done)
					_draw_blob(blob, done, PALE.lightened(0.18 if blob.light else 0.0), 0.8 * comes, false)


# The blot at rest, `grown` of its size and `shows` opaque: an oval with an uneven edge of
# small lobes, and a deeper bloom inside it.
func _draw_blot(grown: float, shows: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for layer: Array in [[BODY, 1.0, 30], [LIGHT, 0.7, 20]]:
		var colour := Color(layer[0] as Color, shows)
		var oval: Vector2 = _reach * float(layer[1]) * grown
		draw_set_transform(_middle, 0.0, Vector2(oval.x / maxf(oval.y, 1.0), 1.0))
		draw_circle(Vector2.ZERO, oval.y, colour, true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		for i: int in layer[2]:
			var angle := (i + rng.randf_range(-0.4, 0.4)) * TAU / float(layer[2])
			var radius := rng.randf_range(9.0, 24.0) * float(layer[1]) * grown
			var at := _middle + Vector2(cos(angle) * oval.x, sin(angle) * oval.y) * rng.randf_range(0.9, 1.0)
			draw_circle(at, radius, colour, true, -1.0, true)


# One blob `done` of its way along its curve: a round head with a tail thinning behind it. A
# blob of ink sinks as it reaches the pool, and carries a glint of his light.
func _draw_blob(blob: Dictionary, done: float, colour: Color, shows: float, ink: bool) -> void:
	var sinks := smoothstep(0.86, 1.0, done)
	var radius := float(blob.radius) * lerpf(1.0, 0.55, sinks)
	var tint := Color(colour, colour.a * shows * (1.0 - sinks * (0.6 if ink else 1.0)))
	for k in range(5, -1, -1):
		var behind := done - 0.02 * k
		if behind <= 0.0:
			continue
		draw_circle(_along(blob, behind), radius * (1.0 - 0.15 * k), tint, true, -1.0, true)
	if ink:
		var head := _along(blob, done)
		draw_circle(head - Vector2(radius, radius) * 0.3, radius * 0.26, Color(GLINT, 0.4 * (1.0 - sinks)), true, -1.0, true)


# The place `done` of the way along a blob's curve: slow off the mark, then running, over a
# shallow rise between its two ends.
func _along(blob: Dictionary, done: float) -> Vector2:
	var u := lerpf(done, done * done, 0.6)
	var from: Vector2 = blob.from
	var to: Vector2 = blob.to
	var top := (from + to) * 0.5 - Vector2(0.0, float(blob.lift) * 2.0)
	return from.lerp(top, u).lerp(top.lerp(to, u), u)
