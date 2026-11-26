class_name EndingLetter
extends Control
## The letter shown at an ending, written part by part from the top, each part in its own hand:
## the greeting, the body, and the signature set to the right.
##
##   letter.write("succumbed")
##   await letter.completed
##
## A press (a click, Space or Enter) while it is being written puts the rest on the page at
## once. Once it is whole it takes no press: the screen that holds it moves on. It follows
## `StoryEntry.written` and `StoryEntry.easy_read`, as every entry does.

## All of the letter is on the page.
signal completed

const WIDTH := 440.0
## The hand at a letter's size: smaller than an entry's, as a letter holds more on its sheet.
const SCALE := 0.8
## The room between the greeting, the body and the signature, and between two parts of one.
const ROLE_GAP := 22.0
const PART_GAP := 4.0

## How long the pen rests before the next part: after a part, after a part broken off, and
## before the letter's next role.
const REST_PART := 0.35
const REST_BROKEN := 1.4
const REST_ROLE := 0.6

## A struck name's stroke: how long it takes to draw, how thick, and how far it climbs.
const STRIKE_TIME := 0.22
const STRIKE_WIDTH := 3.0
const STRIKE_RISE := 5.0
## The stroke is drawn after a short pause, once the name is dry enough to read.
const STRIKE_DELAY := 0.5

enum State { IDLE, WRITING, WHOLE }

var _state := State.IDLE
var _parts: Array[Dictionary] = []
var _labels: Array[RichTextLabel] = []
var _inks: Array[StoryInk] = []
var _texts: Array[String] = []
## The part being written, the letters of it shown, and the time to the next letter.
var _at := 0
var _shown := 0
var _wait := 0.0
var _clock := 0.0
## When each struck part's stroke began, by its index; INF before it is due.
var _struck_at := {}
## Drawn over the parts, for the strokes through struck names.
var _strokes := Control.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size.x = WIDTH
	custom_minimum_size.x = WIDTH
	_strokes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strokes.draw.connect(_draw_strokes)
	add_child(_strokes)


## The height of the letter for ending `id` once it is whole, before it is written: so a sheet
## can be cut to fit. The letter must be in the tree.
func height_of(id: String) -> float:
	# A label lays itself out only inside the tree, so a hidden copy is laid out under this one.
	var probe := EndingLetter.new()
	probe.visible = false
	add_child(probe)
	probe._lay_out(StoryLines.letter(id))
	var h := probe.size.y
	remove_child(probe)
	probe.free()
	return h


## Writes the letter for ending `id` ("jekyll", "hyde", "succumbed" or "unmet") from the top.
## Returns at once; `completed` is emitted when all of it is on the page.
func write(id: String) -> void:
	_lay_out(StoryLines.letter(id))
	_at = 0
	_shown = 0
	_wait = 0.0
	_state = State.WRITING
	if _parts.is_empty() or not StoryEntry.written:
		_finish()


## True once all of the letter is on the page.
func is_complete() -> bool:
	return _state == State.WHOLE


## Moves the letter's clock on by `seconds`, as if that much time had passed: for a still taken
## part-way through.
func pass_time(seconds: float, step: float = 1.0 / 60.0) -> void:
	var left := seconds
	while left > 0.0:
		_step(minf(step, left))
		left -= step


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	_clock += delta
	for ink in _inks:
		ink.now = _clock
	if not _struck_at.is_empty():
		_strokes.queue_redraw()
	if _state != State.WRITING:
		return
	_wait -= delta
	var pen := true
	while _wait <= 0.0 and _state == State.WRITING:
		var text := _texts[_at]
		if _shown >= text.length():
			# The part is whole: its stroke, if struck, then the pen rests before the next.
			_part_done(_at)
			var rest := _rest_after(_at)
			_at += 1
			_shown = 0
			if _at >= _parts.size():
				_finish()
				return
			_wait += rest
			pen = false
			break
		_inks[_at].born[_shown] = _clock + _wait
		var letter := text[_shown]
		_shown += 1
		_labels[_at].visible_characters = _shown
		var pause := _pause_after(text, letter, _shown)
		_wait += 1.0 / _speed(_at) + pause
		if pause > 0.0:
			pen = false
			break
	_pen(pen and _state == State.WRITING, _at)


func _input(event: InputEvent) -> void:
	if _state != State.WRITING:
		return
	var pressed := event.is_action_pressed("ui_accept")
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_finish()


# Every part as it will stand once whole, each hidden until it is written.
func _lay_out(parts: Array) -> void:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_inks.clear()
	_texts.clear()
	_parts.clear()
	_struck_at.clear()
	var y := 0.0
	var role := ""
	for i in parts.size():
		var part: Dictionary = parts[i]
		_parts.append(part)
		if i > 0:
			y += ROLE_GAP if part.role != role else PART_GAP
		role = part.role
		var ink := StoryInk.new()
		var label := _label(part, ink)
		label.position = Vector2(0.0, y)
		add_child(label)
		_labels.append(label)
		_inks.append(ink)
		_texts.append(label.get_parsed_text())
		ink.born = PackedFloat32Array()
		ink.born.resize(_texts[i].length())
		ink.born.fill(INF)
		label.visible_characters = 0
		y += label.get_content_height()
	size.y = y
	custom_minimum_size.y = y
	move_child(_strokes, -1)
	_strokes.queue_redraw()


func _label(part: Dictionary, ink: StoryInk) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	# A letter sloped backward reaches out past the left edge.
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if part.role == "signature" else HORIZONTAL_ALIGNMENT_LEFT
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.size.x = WIDTH
	label.custom_minimum_size.x = WIDTH
	label.install_effect(ink)
	_dress(label, ink, part.hand)
	label.text = "[ink]" + String(part.text).replace("[", "[lb]") + "[/ink]"
	return label


# The face, size, spacing and colours of the hand, as a story entry has them.
func _dress(label: RichTextLabel, ink: StoryInk, hand: String) -> void:
	var font := _font(hand)
	var font_size := _size(hand)
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	var spacing := roundi(font_size * StoryEntry.LINE_SPACING - font.get_height(font_size))
	label.add_theme_constant_override("line_separation", spacing)
	ink.wet = Palette.HOT
	ink.dry = _dry(hand)
	ink.lift = 0.0 if StoryEntry.easy_read else StoryInk.LIFT


static func _font(hand: String) -> Font:
	var hyde := hand == "hyde"
	if StoryEntry.easy_read:
		return _sloped(ThemeDB.fallback_font, StoryEntry.PLAIN_SLOPE, 0.0) if hyde else ThemeDB.fallback_font
	if hyde:
		return _sloped(StoryEntry.FACE, StoryEntry.HYDE_SLOPE, StoryEntry.HYDE_WEIGHT)
	return _sloped(StoryEntry.FACE, 0.0, StoryEntry.JEKYLL_WEIGHT)


static func _size(hand: String) -> int:
	if StoryEntry.easy_read:
		return roundi(StoryEntry.PLAIN_SIZE * SCALE)
	return roundi((StoryEntry.HYDE_SIZE if hand == "hyde" else StoryEntry.JEKYLL_SIZE) * SCALE)


static func _dry(hand: String) -> Color:
	return Palette.HYDE if hand == "hyde" else Palette.JEKYLL.lerp(Palette.CHALK, 0.35)


static func _sloped(base: Font, slope: float, weight: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_embolden = weight
	font.variation_transform = Transform2D(Vector2(1.0, -slope), Vector2(0.0, 1.0), Vector2.ZERO)
	return font


# The rest of the letter at once.
func _finish() -> void:
	for i in range(_at, _parts.size()):
		var from := _shown if i == _at else 0
		for c in range(from, _texts[i].length()):
			_inks[i].born[c] = _clock
		_labels[i].visible_characters = -1
		_part_done(i)
	_at = _parts.size()
	_pen(false, 0)
	_state = State.WHOLE
	completed.emit()


func _part_done(i: int) -> void:
	if _parts[i].get("struck", false) and not _struck_at.has(i):
		_struck_at[i] = _clock + STRIKE_DELAY
		_strokes.queue_redraw()


func _rest_after(i: int) -> float:
	if _parts[i].get("broken", false):
		return REST_BROKEN
	if i + 1 < _parts.size() and _parts[i + 1].role != _parts[i].role:
		return REST_ROLE
	return REST_PART


func _pause_after(text: String, letter: String, next: int) -> float:
	if letter == ",":
		return StoryEntry.PAUSE_COMMA
	if letter == "-":
		var before := text[next - 2] if next >= 2 else " "
		var after := text[next] if next < text.length() else " "
		return StoryEntry.PAUSE_STOP if before == " " or after == " " else 0.0
	if letter in StoryEntry.STOPS:
		return StoryEntry.PAUSE_STOP
	return 0.0


func _speed(i: int) -> float:
	return StoryEntry.HYDE_SPEED if _parts[i].hand == "hyde" else StoryEntry.JEKYLL_SPEED


func _pen(on: bool, i: int) -> void:
	var hyde: bool = i < _parts.size() and _parts[i].hand == "hyde"
	if on and not Sfx.is_looping(StoryEntry.PEN):
		Sfx.loop(StoryEntry.PEN, StoryEntry.HYDE_PEN_PITCH if hyde else 1.0, StoryEntry.HYDE_PEN_VOLUME if hyde else 1.0)
	elif not on and Sfx.is_looping(StoryEntry.PEN):
		Sfx.stop_loop(StoryEntry.PEN, 0.04)


# A struck name's stroke, in Hyde's ink, drawn left to right across the name, rising a little.
func _draw_strokes() -> void:
	for i: int in _struck_at:
		var t := clampf((_clock - float(_struck_at[i])) / STRIKE_TIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		var label := _labels[i]
		var part := _parts[i]
		var font := _font(part.hand)
		var font_size := _size(part.hand)
		var w := font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x1 := WIDTH + 4.0
		var x0 := WIDTH - w - 6.0
		var y := label.position.y + label.get_content_height() * 0.45
		var a := Vector2(x0, y + STRIKE_RISE * 0.5)
		var b := Vector2(x1, y - STRIKE_RISE * 0.5)
		_strokes.draw_line(a, a.lerp(b, t), _dry("hyde"), STRIKE_WIDTH, true)
