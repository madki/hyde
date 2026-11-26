extends Control
## A bench for the story page, over plain bars in the table's colours:
##
##   tools/shot.sh /abs/out.png res://scenes/story_page_bench.tscn [--keys=<key>,<key>]
##       [--at=<seconds>]
##
## `--keys` are keys of `StoryLines`. With `--at` the still is taken that many seconds into the
## first line; without it, once that line is whole and dry. Run without `--shot`, it tells the
## keys over and over; a press on a bar while the page is up would print, and should not.
## `--selftest` (headless, under a time limit) presses its way through two keys and a missing
## one, checks that nothing under the page saw a key, and quits.

var _fails: Array[String] = []

const BARS: Array[Color] = [
	Palette.NIGHT_2, Palette.J_STOCK, Palette.PAGE, Palette.JEKYLL_DEEP,
	Palette.NIGHT_3, Palette.HYDE_DEEP, Palette.H_STOCK, Palette.RULE,
]


func _ready() -> void:
	var keys := Array(Shot.arg("keys").split(",", false)) if Shot.arg("keys") else ["opening.1", "opening.2"]
	gui_input.connect(_on_press)
	if Shot.has_arg("selftest"):
		await _selftest()
		get_tree().quit(1 if _fails else 0)
		return
	if Shot.has_arg("shot"):
		var page := StoryPage.new()
		add_child(page)
		page.tell(keys)
		if Shot.has_arg("at"):
			page.pass_time(float(Shot.arg("at")))
		else:
			page.pass_time(0.0)
			while not page.is_waiting():
				page.pass_time(0.5)
			page.pass_time(StoryInk.APPEAR + StoryInk.DRY)
		# Hold the page as it is for the still.
		page.process_mode = Node.PROCESS_MODE_DISABLED
		Sfx.stop_all()
		Shot.run_if_requested(self)
		return
	while true:
		await StoryPage.tell_over(self, keys)
		await get_tree().create_timer(1.0).timeout


func _draw() -> void:
	var w := size.x / BARS.size()
	for i in BARS.size():
		draw_rect(Rect2(i * w, 0.0, w + 1.0, size.y), BARS[i])


func _on_press(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed:
		print("the bars saw a press")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		printerr("SELFTEST FAIL: ", what)


func _selftest() -> void:
	var under := _Catcher.new()
	add_child(under)
	var done := [false]
	var tell := func() -> void:
		# The long line first: it is still being written when the deaf time is over.
		await StoryPage.tell_over(self, ["opening.2", "no.such.key", "opening.1"])
		done[0] = true
	tell.call()
	var page: StoryPage = get_child(get_child_count() - 1)
	await _frames(20)
	_expect(page.visible, "the page is up")
	_press(KEY_A)
	await _frames(2)
	_expect(under.seen == 0, "a key under the page is not seen")
	# A press while the page is still deaf is swallowed: the line goes on being written.
	_press(KEY_SPACE)
	await _frames(2)
	_expect(not page.is_waiting(), "a press in the deaf time writes nothing")
	_expect(under.seen == 0, "a press in the deaf time is not seen under the page")
	await get_tree().create_timer(StoryPage.FADE + StoryPage.DEAF).timeout
	# One press writes the rest of the first line, the next moves on to the second; two more
	# for the second, and the missing key is passed over without a page.
	_press(KEY_SPACE)
	await _frames(5)
	_expect(page.is_waiting(), "the first press writes the line whole")
	_press(KEY_SPACE)
	await _frames(5)
	_expect(not page.is_waiting() and not done[0], "the next press moves on to the second line")
	_press(KEY_SPACE)
	await _frames(5)
	_press(KEY_SPACE)
	await _frames(40)
	_expect(done[0], "the page has gone after the last line, got done=%s" % done[0])
	_expect(not is_instance_valid(page), "the page is freed")
	_expect(under.seen == 0, "nothing under the page saw a key, got %d" % under.seen)
	_press(KEY_A)
	await _frames(2)
	_expect(under.seen == 1, "a key is seen again once the page has gone")
	var none := [false]
	var nothing := func() -> void:
		await StoryPage.tell_over(self, ["no.such.key"])
		none[0] = true
	nothing.call()
	await _frames(2)
	_expect(none[0], "keys with no line show no page")
	Sfx.stop_all()
	print("selftest: %s" % ("ok" if _fails.is_empty() else "%d failed" % _fails.size()))


func _press(code: Key) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


class _Catcher:
	extends Node
	var seen := 0

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key and key.pressed:
			seen += 1
