class_name StoryEntry
extends Control
## A line of the story, written into the journal letter by letter, in Jekyll's hand or in
## Hyde's, and left on the page until the player moves on:
##
##   await entry.write("Between these two, I now felt I had to choose.", "jekyll")
##
## A press (a click, Space or Enter) while it is being written writes the rest at once; the
## next press moves on. Nothing leaves by itself. While it waits, a small nib stands after
## the last letter.

## The player's settings, for every entry. `written`: false shows each line whole at once,
## and one press moves on. `easy_read`: both hands in the plain face.
static var written := true
static var easy_read := false

## All of the line is on the page.
signal completed
## The player has moved on.
signal advanced

const FACE: Font = preload("res://fonts/HomemadeApple-Regular.ttf")
const WIDTH := 560.0
const LINE_SPACING := 1.75

const JEKYLL_SIZE := 26
const HYDE_SIZE := 26
const PLAIN_SIZE := 20
## Hyde's hand: the same letters sloped backward, and heavier. The face leans forward of
## itself by about a half, so the shear is that and more: his slope is a little under Jekyll's.
const HYDE_SLOPE := 0.82
## The plain face stands upright, so its slope is the one seen.
const PLAIN_SLOPE := 0.28
const HYDE_WEIGHT := 0.6
## Jekyll's hand is the face a little heavier, so its thin strokes hold at this size.
const JEKYLL_WEIGHT := 0.3

## Letters a second.
const JEKYLL_SPEED := 45.0
const HYDE_SPEED := 55.0
const PAUSE_COMMA := 0.12
const PAUSE_STOP := 0.3
const PAUSE_PARAGRAPH := 0.5
const STOPS := ".:;!?–—"

const PEN := "pen"
const HYDE_PEN_PITCH := 0.8
const HYDE_PEN_VOLUME := 1.2

enum State { IDLE, WRITING, WAITING }

var _label := RichTextLabel.new()
var _ink := StoryInk.new()
var _state := State.IDLE
var _hand := "jekyll"
var _parsed := ""
var _shown := 0
var _wait := 0.0
var _pausing := false
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	# A letter sloped backward reaches out past the left edge.
	_label.clip_contents = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Letters are hidden after the line is laid out, so a word does not jump to the next line
	# as it is written.
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.size.x = WIDTH
	_label.custom_minimum_size.x = WIDTH
	_label.install_effect(_ink)
	add_child(_label)
	size.x = WIDTH


## Writes `text` in `hand` ("jekyll" or "hyde") and returns when the player has moved on.
## A blank line between paragraphs is written as a pause.
func write(text: String, hand: String = "jekyll") -> void:
	_hand = hand
	_dress()
	_label.text = "[ink]" + text.replace("[", "[lb]") + "[/ink]"
	_parsed = _label.get_parsed_text()
	_ink.born = PackedFloat32Array()
	_ink.born.resize(_parsed.length())
	_ink.born.fill(INF)
	_shown = 0
	_wait = 0.0
	_pausing = false
	_label.visible_characters = 0
	size.y = _label.get_content_height()
	_state = State.WRITING
	if not written:
		_finish()
	await advanced


## True while the whole line is on the page and waits for a press.
func is_waiting() -> bool:
	return _state == State.WAITING


## Moves the entry's clock on by `seconds`, as if that much time had passed: for a still taken
## part-way through a line.
func pass_time(seconds: float, step: float = 1.0 / 60.0) -> void:
	var left := seconds
	while left > 0.0:
		_step(minf(step, left))
		left -= step


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	_clock += delta
	_ink.now = _clock
	if _state != State.WRITING:
		return
	_wait -= delta
	while _wait <= 0.0 and _shown < _parsed.length():
		# A letter due part-way through the frame is dated to then, so its ink comes up in step.
		_ink.born[_shown] = _clock + _wait
		var letter := _parsed[_shown]
		_shown += 1
		var pause := _pause_after(letter, _shown)
		_wait += 1.0 / _speed() + pause
		_pausing = pause > 0.0
		if _pausing:
			break
	_label.visible_characters = _shown
	if _shown >= _parsed.length():
		_finish()
	else:
		_pen(not _pausing)


func _input(event: InputEvent) -> void:
	if _state == State.IDLE:
		return
	var pressed := event.is_action_pressed("ui_accept")
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	press()


## A press, as the player's: writes the rest of the line, or moves on from a whole one.
## Nothing while no line is on the page.
func press() -> void:
	if _state == State.WRITING:
		_finish()
	elif _state == State.WAITING:
		_state = State.IDLE
		_pen(false)
		advanced.emit()


# The rest of the line at once, and the nib after it.
func _finish() -> void:
	for i in range(_shown, _parsed.length()):
		_ink.born[i] = _clock
	_shown = _parsed.length()
	_pen(false)
	_label.visible_characters = -1
	_label.add_text(" ")
	_label.add_image(_nib(), 0, 0, Color.WHITE, INLINE_ALIGNMENT_CENTER)
	_state = State.WAITING
	completed.emit()


func _pause_after(letter: String, next: int) -> float:
	if letter == "\n":
		# A blank line is one paragraph's pause, not two.
		return PAUSE_PARAGRAPH if next >= _parsed.length() or _parsed[next] != "\n" else 0.0
	if letter == ",":
		return PAUSE_COMMA
	if letter == "-":
		# A dash, not the hyphen inside a word.
		var before := _parsed[next - 2] if next >= 2 else " "
		var after := _parsed[next] if next < _parsed.length() else " "
		return PAUSE_STOP if before == " " or after == " " else 0.0
	if letter in STOPS:
		return PAUSE_STOP
	return 0.0


func _speed() -> float:
	return HYDE_SPEED if _hand == "hyde" else JEKYLL_SPEED


func _pen(on: bool) -> void:
	if on and not Sfx.is_looping(PEN):
		var hyde := _hand == "hyde"
		Sfx.loop(PEN, HYDE_PEN_PITCH if hyde else 1.0, HYDE_PEN_VOLUME if hyde else 1.0)
	elif not on and Sfx.is_looping(PEN):
		Sfx.stop_loop(PEN, 0.04)


# The face, size, spacing and colours of the hand.
func _dress() -> void:
	var hyde := _hand == "hyde"
	var font: Font
	var font_size: int
	if easy_read:
		font_size = PLAIN_SIZE
		font = _sloped(ThemeDB.fallback_font, PLAIN_SLOPE, 0.0) if hyde else ThemeDB.fallback_font
	else:
		font_size = HYDE_SIZE if hyde else JEKYLL_SIZE
		font = _sloped(FACE, HYDE_SLOPE, HYDE_WEIGHT) if hyde else _sloped(FACE, 0.0, JEKYLL_WEIGHT)
	_label.add_theme_font_override("normal_font", font)
	_label.add_theme_font_size_override("normal_font_size", font_size)
	var spacing := roundi(font_size * LINE_SPACING - font.get_height(font_size))
	_label.add_theme_constant_override("line_separation", spacing)
	_ink.wet = Palette.HOT
	_ink.dry = Palette.HYDE if hyde else Palette.JEKYLL.lerp(Palette.CHALK, 0.35)
	_ink.lift = 0.0 if easy_read else StoryInk.LIFT


func _sloped(base: Font, slope: float, weight: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_embolden = weight
	font.variation_transform = Transform2D(Vector2(1.0, -slope), Vector2(0.0, 1.0), Vector2.ZERO)
	return font


# A small pen nib, point down, in the hand's dry ink.
func _nib() -> Texture2D:
	var w := 7
	var h := 12
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var half := (float(h - y) / h) * (w * 0.5)
		for x in w:
			var dx := absf(x + 0.5 - w * 0.5)
			var a := clampf(half - dx + 0.5, 0.0, 1.0)
			# The slit down the middle of the nib, and the hole at its top.
			if dx < 0.6 and y > 3 and y < h - 2:
				a *= 0.15
			if a > 0.0:
				image.set_pixel(x, y, Color(_ink.dry, a))
	return ImageTexture.create_from_image(image)
