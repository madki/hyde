class_name EndingScreen
extends Control
## The screen a run ends on, one shape for each of its four endings:
##
## - Behind, a still the game already draws, dimmed: the laboratory for "jekyll", the back
##   alley for "hyde", the journal's page under a full flood of ink for "succumbed", and the
##   title's street, dark, its lamps low, for "unmet".
## - Left, a sheet of the journal's paper cut to the ending's letter (EndingLetter), written
##   as the screen opens.
## - Right, the ending's name in the light of the man who is left, the book's line for it,
##   and once the letter is whole the run's facts, counted out one line at a time; under them
##   the road, a mark for each round played in the colour of the man who held it; and last a
##   button that closes the journal: the game goes back to its title.
##
## The letter begins when the passage that brought the screen has lifted. The first press
## while anything is still being written or counted puts all of it on the screen, and begins
## nothing more. Only the button leaves the screen (a click on it, or Enter or Space), for the
## title, and only once it has been showing for BUTTON_CALM seconds and the screen has been
## seen for CALM: a press that was hurrying the screen never leaves it.
##
## The music is the piece of the man who is left, with no dread under it.
##
## It shows the run SceneFlow kept when the table handed it over (`SceneFlow.ended`). Run on
## its own it plays a run of the ending asked for by the rules alone:
##
##   tools/shot.sh /abs/out.png res://scenes/ending.tscn --ending=jekyll|hyde|succumbed|unmet
##       [--seed=<n>] [--at=<seconds>]
##
## With `--at` the still is taken that many seconds into the letter; without it, with all of
## the screen out.

const IDS := ["jekyll", "hyde", "succumbed", "unmet"]
## The man who is left at each ending, by his light.
const SURVIVOR := {
	"jekyll": Palette.JEKYLL,
	"hyde": Palette.HYDE,
	"succumbed": Palette.HYDE,
	"unmet": Palette.JEKYLL,
}
## How far the still behind is dimmed, by ending: the wins stay lit, the losses go dark.
const DIM := {"jekyll": 0.45, "hyde": 0.45, "succumbed": 0.3, "unmet": 0.55}
## The title's street at "unmet": its lamps low, and the dark over it.
const UNMET_LAMPS := 0.15
const UNMET_DARK := 0.35

const LAB_BACKGROUND := preload("res://scenes/lab_background.tscn")
const ALLEY_BACKGROUND := preload("res://scenes/alley_background.tscn")
const TITLE_BACKGROUND := preload("res://scenes/title_background.tscn")
const PAPER_MATERIAL := preload("res://shaders/arena_paper_material.tres")
const PAPER_MASK := preload("res://art/arena/paper_mask.png")

## The sheet: the room around the letter, and how far it is turned off square, in degrees.
const SHEET_PAD := 26.0
const SHEET_TURN := -1.2
## The screen's margins, and the room between the sheet and the column on its right.
const MARGIN := 56.0
const GUTTER := 52.0
## The column's least height, so that the button stays clear of the facts.
const COLUMN_MIN := 470.0

const NAME_SIZE := 40
const LINE_SIZE := 16
const FACT_SIZE := 17
const BUTTON_SIZE := 18
const BUTTON_TEXT := "Close the journal"

## The facts: how long after the letter is whole the first comes, and the time between two.
const FACTS_AFTER := 0.4
const FACT_GAP := 0.25
const FADE := 0.2
## The screen is not left before it has been seen this long, in seconds, nor before the
## button has been showing this long.
const CALM := 1.0
const BUTTON_CALM := 0.6

## How many seeds are tried for a run of the ending asked for, when run on its own, and the
## share of the game's targets a run that is to reach the last night plays to.
const TRIES := 60
const EASED := 0.05

## The run shown, and its ending's id (a key of ArenaMomentEnd.ENDINGS).
var run: RulesRun
var id := "jekyll"

## How long the screen has been seen, in seconds: counted from when the passage has lifted.
var _age := 0.0
## False until the passage has lifted and the letter has begun.
var _begun := false
## The screen's age when the button came out; -1 before.
var _button_at := -1.0
## Counting the facts out: the time since it began, and how many are out; -1 before.
var _count_clock := 0.0
var _out := -1
## Everything that is counted out after the letter, in order: the facts, then the road.
var _reveals: Array[CanvasItem] = []
var _letter: EndingLetter
var _sheet: Control
var _column: VBoxContainer
var _road: Control
var _button: Button
## A press came while the letter was being written: when it is whole, all the rest follows.
var _hurry := false
var _leaving := false


## Catches every press before the letter does: a node's `_input` comes before its parent's
## and its elder siblings', so this one is added last.
class Presses:
	extends Node
	var on_press: Callable

	func _input(event: InputEvent) -> void:
		if on_press.call(event):
			get_viewport().set_input_as_handled()


func _ready() -> void:
	run = SceneFlow.ended
	if run == null:
		var asked := Shot.arg("ending") if Shot.arg("ending") in IDS else "jekyll"
		run = played_run(asked, int(Shot.arg("seed")) if Shot.has_arg("seed") else 1)
		id = asked
	if run != null and run.ending != null:
		id = ending_of(run)
	Music.enter("ending_hyde" if SURVIVOR[id] == Palette.HYDE else "ending_jekyll")
	_build()
	resized.connect(_lay_out)
	var presses := Presses.new()
	presses.on_press = _on_press
	add_child(presses)
	_letter.completed.connect(_on_letter_whole)
	if Shot.has_arg("shot"):
		_begin()
		_set_up_still()
	Shot.run_if_requested(self)


# The passage has lifted: the letter is written, and the screen's time begins.
func _begin() -> void:
	_begun = true
	_letter.write(id)


## The four-way id of a finished run's ending, from the rules' name and what ended it.
static func ending_of(ended: RulesRun) -> String:
	return ArenaMomentEnd.ending_of({"ending": ended.ending, "ended_by": ended.ended_by})


func _process(delta: float) -> void:
	if not _begun:
		if SceneFlow.is_changing():
			return
		_begin()
	_age += delta
	if _out < 0 or _out >= _reveals.size() + 1:
		return
	_count_clock += delta
	while _out < _reveals.size() + 1 and _count_clock >= FACTS_AFTER + FACT_GAP * _out:
		_reveal(_out, true)
		_out += 1


# ---------- presses ----------

# A press: true if it is taken here. While the letter is being written it is left to the
# letter, which puts its rest down, and the facts then follow at once.
func _on_press(event: InputEvent) -> bool:
	var key := event.is_action_pressed("ui_accept")
	var mouse := event as InputEventMouseButton
	var click := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if not key and not click:
		return false
	if not _begun:
		return true
	if not _letter.is_complete():
		_hurry = true
		return false
	if not _all_out():
		_show_all()
		return true
	if key:
		_close()
		return true
	return false # a click goes on to the button, if it is on it


func _on_letter_whole() -> void:
	if _hurry:
		_show_all()
	elif _out < 0:
		_out = 0
		_count_clock = 0.0


func _all_out() -> bool:
	return _out >= _reveals.size() + 1


# Everything that is still to come, at once.
func _show_all() -> void:
	for i in _reveals.size() + 1:
		if _out < 0 or i >= _out:
			_reveal(i, false)
	_out = _reveals.size() + 1


# Brings out the `i`th of the facts and the road; one past them is the button.
func _reveal(i: int, fade: bool) -> void:
	var item: CanvasItem = _reveals[i] if i < _reveals.size() else _button
	if item == _button and _button_at < 0.0:
		_button_at = _age
	item.visible = true
	if fade:
		item.modulate.a = 0.0
		create_tween().tween_property(item, "modulate:a", 1.0, FADE)
	else:
		item.modulate.a = 1.0


# Closes the journal: on to the title, where the next run begins.
func _close() -> void:
	if _leaving or _button_at < 0.0 or _age < CALM or _age - _button_at < BUTTON_CALM:
		return
	_leaving = true
	SceneFlow.close_ending()


# ---------- the screen ----------

func _build() -> void:
	_background()
	var light: Color = SURVIVOR[id]
	var won := id == "jekyll" or id == "hyde"

	# The sheet, with the letter on it, cut to the letter's height.
	_letter = EndingLetter.new()
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.add_child(_letter)
	var h := _letter.height_of(id)
	_sheet.size = Vector2(EndingLetter.WIDTH, h) + Vector2.ONE * SHEET_PAD * 2.0
	_sheet.pivot_offset = _sheet.size * 0.5
	_sheet.rotation_degrees = SHEET_TURN
	_letter.position = Vector2.ONE * SHEET_PAD
	var edge := Color(light, 0.75) if won else Color(Palette.RULE, 0.8)
	_sheet.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _sheet.size)
		_sheet.draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.45))
		_sheet.draw_rect(r, Palette.PAGE)
		_sheet.draw_rect(r.grow(-6.0), Color(Palette.PAGE_LIGHT, 0.35), false, 1.0)
		# Turned off square, the edge is drawn smooth over the fill's stepped one.
		var corners := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y), r.position])
		_sheet.draw_polyline(corners, edge, 2.0 if won else 1.5, true))

	# The column on the right: the name, the book's line, the facts and the road.
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)

	var title := _label(ArenaMomentEnd.ENDINGS[id], NAME_SIZE, light)
	_column.add_child(title)
	var said: Dictionary = StoryLines.line("ending." + id)
	if not said.is_empty():
		var quote := _label("“%s”" % said.text, LINE_SIZE, Palette.CHALK_2)
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_column.add_child(quote)
	_column.add_child(_gap(18.0))
	for fact in facts(run):
		var line := _label(fact, FACT_SIZE, Palette.CHALK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.visible = false
		_column.add_child(line)
		_reveals.append(line)
	_column.add_child(_gap(14.0))
	_road = Control.new()
	_road.custom_minimum_size = Vector2(0.0, 24.0)
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_road.visible = false
	_road.draw.connect(_draw_road)
	_column.add_child(_road)
	if run != null and not run.history.is_empty():
		_reveals.append(_road)

	# The button, bottom right, level with the foot of the column.
	_button = Button.new()
	_button.text = BUTTON_TEXT
	_button.focus_mode = Control.FOCUS_NONE
	_button.visible = false
	_button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_button.add_theme_color_override(state, Palette.CHALK if state == "font_color" else Palette.HOT)
	_button.add_theme_stylebox_override("normal", _box(Color(Palette.NIGHT_2, 0.92), Color(light, 0.7)))
	_button.add_theme_stylebox_override("hover", _box(Palette.NIGHT_3, light))
	_button.add_theme_stylebox_override("pressed", _box(Palette.NIGHT_1, light))
	_button.pressed.connect(_close)
	add_child(_button)
	_button.reset_size()
	_lay_out()


# Places the sheet, the column and the button on a page of the screen's size: when the screen
# is built, and again whenever its size changes.
func _lay_out() -> void:
	if _button == null:
		return
	var page := get_viewport_rect().size
	_sheet.position = Vector2(MARGIN, ((page.y - _sheet.size.y) * 0.5)).round()
	var left := _sheet.position.x + _sheet.size.x + GUTTER
	var column_h := maxf(_sheet.size.y, COLUMN_MIN)
	var top := ((page.y - column_h) * 0.5)
	_column.position = Vector2(left, top).round()
	_column.size = Vector2(page.x - MARGIN - left, 0.0)
	_button.position = (Vector2(page.x - MARGIN, top + column_h) - _button.size).round()


# The still behind the sheet, and the dark laid over it.
func _background() -> void:
	match id:
		"jekyll":
			add_child(LAB_BACKGROUND.instantiate())
		"hyde":
			add_child(ALLEY_BACKGROUND.instantiate())
		"succumbed":
			var paper := TextureRect.new()
			paper.material = PAPER_MATERIAL
			paper.texture = PAPER_MASK
			paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			paper.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(paper)
			var ink := ArenaInk.new()
			ink.paper = paper
			add_child(ink)
			ink.set_ink(100.0, 50.0, false)
			ink.snap_to_stance()
		_:
			var street: TitleBackground = TITLE_BACKGROUND.instantiate()
			add_child(street)
			street.lamps = UNMET_LAMPS
			street.darkness = UNMET_DARK
	var dim := ColorRect.new()
	dim.color = Color(Palette.NIGHT_1, DIM[id])
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


# ---------- the facts and the road ----------

## The facts of a finished run, a line each: where it ended, the best hand, the hands played
## as each man, the draughts and salts, the line at the end, and for a loss what ended it.
static func facts(ended: RulesRun) -> Array[String]:
	var lines: Array[String] = []
	if ended == null:
		return lines
	var last: Dictionary = ended.last if ended.last is Dictionary else {}
	var night := int(last.get("night", ended.night))
	var round_no := int(last.get("round", ended.round))
	lines.append("Night %d of %d, %s" % [night + 1, Rules.night_count(),
			"the Scene" if round_no == 2 else "round %d" % (round_no + 1)])
	var stats := ended.stats
	if String(stats.best_name) != "":
		lines.append("Best hand: %s, %d" % [stats.best_name, int(stats.best)])
	lines.append("Hands played: %d as Jekyll, %d as Hyde" % [int(stats.jekyll_hands), int(stats.hyde_hands)])
	lines.append("Draughts: %d, salts: %d" % [int(stats.drinks), int(stats.salts)])
	if last.has("paper"):
		lines.append("The line at the end: %d Paper against %d Ink" % [int(last.paper), int(last.ink)])
	if ended.ending == "hyde":
		match ended.ended_by:
			"line":
				lines.append("His Roots outnumbered yours: %d against %d" % [int(last.get("ink", 0)), int(last.get("paper", 0))])
			"short":
				lines.append("Short of the target: %d against %d" % [int(last.get("score", 0)), int(last.get("target", 0))])
			"gaveup":
				lines.append("Given up")
	return lines


# A mark for each round in the history, in the colour of the man who held it: a dot for a
# round, a diamond for a scene, a little room between the nights; the last ringed on a loss.
func _draw_road() -> void:
	if run == null:
		return
	const PITCH := 20.0
	const NIGHT_GAP := 10.0
	const R := 5.5
	var y := _road.size.y * 0.5
	var at: Array[Vector2] = []
	var x := R + 2.0
	for i in run.history.size():
		var h: Dictionary = run.history[i]
		if i > 0 and int(h.night) != int(run.history[i - 1].night):
			x += NIGHT_GAP
		at.append(Vector2(x, y))
		x += PITCH
	if at.size() > 1:
		_road.draw_line(at[0], at[-1], Color(Palette.CHALK_3, 0.6), 1.0)
	for i in at.size():
		var h: Dictionary = run.history[i]
		var colour: Color = Palette.HYDE if h.stance == "hyde" else Palette.JEKYLL
		var p := at[i]
		if int(h.round) == 2:
			var d := R + 1.5
			_road.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0),
					p + Vector2(0, d), p + Vector2(-d, 0)]), colour)
		else:
			_road.draw_circle(p, R, colour)
	if run.ending == "hyde" and not at.is_empty():
		_road.draw_arc(at[-1], R + 5.0, 0.0, TAU, 32, Palette.CHALK, 1.5, true)


# ---------- run on its own ----------

# For a still: the letter as far as `--at` asks, or whole with everything out.
func _set_up_still() -> void:
	StoryEntry.easy_read = Shot.has_arg("plain")
	if Shot.has_arg("at"):
		_letter.pass_time(float(Shot.arg("at")))
		if _letter.is_complete():
			_show_all()
	else:
		while not _letter.is_complete():
			_letter.pass_time(0.5)
		_letter.pass_time(EndingLetter.STRIKE_DELAY + EndingLetter.STRIKE_TIME + StoryInk.APPEAR + StoryInk.DRY)
		_show_all()
	_letter.set_process(false)
	_age = CALM + BUTTON_CALM
	Sfx.stop_all()


## A run played by the rules alone to the ending `want`, from seed `seed_value` on: the first
## of TRIES seeds whose run ends that way. Null, with a warning, when none does.
##
## Plain play falls short long before the last night, so a run that is to end at night 5's
## scene ("jekyll", "hyde") is set by hand: its targets are eased to EASED of the game's,
## and for "jekyll" his restraint is held at nothing, so that Hyde never breaks out.
static func played_run(want: String, seed_value: int) -> RulesRun:
	var at_scene := want == "jekyll" or want == "hyde"
	var dials := {"first_night_scale": EASED, "target_scale": EASED} if at_scene else {"first_night_scale": 1.0}
	for attempt in TRIES:
		var made := Rules.new_run(dials, seed_value + attempt)
		_play_out(made, want)
		if made.phase == "end" and ending_of(made) == want:
			return made
	push_warning("No run from seed %d on ended as %s." % [seed_value, want])
	return null


# Plays `made` to its end, leaning the way the ending `want` lies: back to Jekyll with salt
# whenever it can be taken, but for "succumbed", which takes the draught whenever it can.
static func _play_out(made: RulesRun, want: String) -> void:
	for move in 5000:
		var result := {"ok": true}
		match made.phase:
			"end":
				return
			"lab":
				result = Rules.leave_lab(made)
			"alley":
				result = Rules.alley_leave(made)
			"result":
				result = Rules.continue_result(made)
			_:
				if want == "jekyll":
					made.restraint = 0
				result = _play_on(made, want)
		if not result.ok:
			return


static func _play_on(made: RulesRun, want: String) -> Dictionary:
	if want == "succumbed" and Rules.can_drink(made).ok:
		return Rules.drink(made)
	if want != "succumbed" and Rules.can_salt(made).ok:
		return Rules.take_salt(made)
	if Rules.can_pass(made).ok:
		return Rules.pass_play(made)
	var ids: Array = Rules.best(made).get("ids", [])
	if not ids.is_empty():
		return Rules.play(made, ids)
	var ink: bool = made.stance == "hyde"
	var dead: Array = []
	for card_id: int in made.hand:
		var c := Rules.card(made, card_id)
		if not c.is_factor() and c.ink != ink:
			dead.append(card_id)
	return Rules.discard(made, dead.slice(0, made.dials.max_discard))
