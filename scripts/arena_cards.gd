extends Control
## A sample page to look at every card and every state a card can be in, without playing a
## run to reach them. Left and Right go from one page to the next; `--page=<0..5>` opens one
## for a screenshot (`tools/shot.sh /abs/out.png res://scenes/arena_cards.tscn --page=2`).
##
## Each page stages a run by hand and then shows it only through the rules: a card's name,
## chips and text, what can be played or turned, and the marks of a chosen play all come
## from RulesView and Rules. On a page with a hand the cards can be chosen with a click.
##
## 0. The 16 faces. G raises every gauge by one (the chips follow), U unlocks the Pen and the Cane.
## 1. Jekyll's hand, with a Sublimation chosen.
## 2. Jekyll's last play, falling short: the Roots he would take.
## 3. Hyde's hand, with a Fixation chosen.
## 4. Where a card lies: the draw pile, the discards, on offer, on top of the draw pile.
## 5. What happens to a card. S stains a Paper Root in the hand, T turns an Ink Root back,
##    D draws a card, P plays the first card away, X strikes the first card from the deck.
##    `--do=sdp` does the same for a screenshot.

const PAGES := 6
const TITLES := [
	"The 16 faces  (G: raise the gauges, U: unlock)",
	"Jekyll's hand: can be played, cannot, can be turned, chosen, best Root, being turned",
	"Jekyll's last play, falling short: he would take it",
	"Hyde's hand",
	"Where a card lies",
	"What happens to a card  (S: stain, T: turn, D: draw, P: play away, X: strike)",
]
const PAPER := Color(0.16, 0.2, 0.24)
const WRITING := Color(0.86, 0.82, 0.72)

var _page := 0
var _run: RulesRun
var _hand: ArenaHand
var _stage: Control
var _title := Label.new()


func _ready() -> void:
	var back := ColorRect.new()
	back.color = PAPER
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_title.position = Vector2(40.0, 18.0)
	_title.add_theme_color_override("font_color", WRITING)
	add_child(_title)
	_show_page(int(Shot.arg("page")) if Shot.has_arg("page") else 0)
	for letter in Shot.arg("do"):
		_change(letter)
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT, KEY_ENTER:
			_show_page((_page + 1) % PAGES)
		KEY_LEFT:
			_show_page((_page + PAGES - 1) % PAGES)
		KEY_G:
			if _page == 0:
				for sym in RulesConfig.ROOTS:
					_run.craving[sym] = (_run.craving[sym] + 1) % 4
					_run.habit[sym] = (_run.habit[sym] + 1) % 4
					_run.temper[sym] = (_run.temper[sym] + 1) % 4
				_show_faces()
		KEY_U:
			if _page == 0:
				_run.unlocked = {"pen": not _run.unlocked.pen, "cane": not _run.unlocked.cane}
				_show_faces()
		_:
			if _page == 5:
				_change(OS.get_keycode_string(key.keycode).to_lower())


func _show_page(page: int) -> void:
	_page = clampi(page, 0, PAGES - 1)
	_title.text = "%d / %d   %s   (Left, Right)" % [_page + 1, PAGES, TITLES[_page]]
	_run = Rules.new_run({}, 7)
	_hand = null
	match _page:
		0:
			_show_faces()
		1:
			_run.craving.lamp = 2
			_run.craving.mirror = 1
			_run.temper.mirror = 1
			_show_hand(_deal("P:lamp I:lamp I:heart P:mirror I:mirror F:cup F:eye P:mirror"), [0, 1])
		2:
			_run.night = 1
			_run.hyde_arrived = true
			Rules.start_round(_run)
			_run.plays = 1
			_run.score = 2800
			_show_hand(_deal("P:heart P:heart P:lamp P:mirror F:cup I:lamp I:heart F:eye"), [0, 1])
		3:
			_run.stance = "hyde"
			_run.hyde_arrived = true
			_run.craving.lamp = 1
			_run.habit.heart = 1
			_show_hand(_deal("I:lamp I:lamp I:heart P:heart P:mirror F:cup F:lock F:pen"), [0, 1])
		4:
			_show_places()
		5:
			_show_hand(_deal("P:lamp P:heart I:mirror P:mirror F:cup I:lamp"), [])


# ---------- staging a run ----------

## Puts the hand back on the draw pile and deals exactly these cards, each a new one.
## "P:lamp" is a Paper Root, "I:lamp" an Ink Root, "F:cup" a Factor. Returns their ids.
func _deal(list: String) -> Array:
	_run.draw.append_array(_run.hand)
	_run.hand = []
	for spec in list.split(" "):
		var c := Rules.make_card(_run, spec.substr(2), spec[0] == "I")
		_run.cards.append(c)
		_run.hand.append(c.id)
	return _run.hand.duplicate()


## One change of section 8 of the cards' list, made to the run by hand; the hand then shows
## the run again and finds out for itself what changed.
func _change(letter: String) -> void:
	if _hand == null:
		return
	match letter:
		"s", "t":
			for id: int in _run.hand:
				var c := Rules.card(_run, id)
				if c.is_root() and c.ink == (letter == "t"):
					c.ink = not c.ink
					break
		"d":
			Rules.draw_one(_run)
		"p":
			if not _run.hand.is_empty():
				_run.discard.append(_run.hand.pop_front())
		"x":
			if not _run.hand.is_empty():
				var id: int = _run.hand.pop_front()
				_run.cards = _run.cards.filter(func(c: RulesCard) -> bool: return c.id != id)
	_hand.show_table(RulesView.table(_run, _hand.chosen()))


# ---------- the pages ----------

func _clear() -> Control:
	if _stage:
		_stage.queue_free()
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	return _stage


func _show_hand(ids: Array, chosen: Array) -> void:
	_clear()
	_hand = ArenaHand.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.place = Rect2(40.0, 250.0, size.x - 80.0, 210.0)
	_hand.is_jekyll = _run.stance == "jekyll"
	_hand.max_chosen = _run.dials.max_play
	_stage.add_child(_hand)
	_hand.show_table(RulesView.table(_run))
	for i: int in chosen:
		_hand.toggle(ids[i])
	var note := _note("", Vector2(40.0, 480.0))
	var show := func(_ids: Array = []) -> void:
		var table := RulesView.table(_run, _hand.chosen())
		_hand.show_table(table)
		note.text = _reading(table)
	_hand.chosen_changed.connect(show)
	show.call()
	_hand.snap()


## What the table says of the chosen play, in a line or two.
func _reading(table: Dictionary) -> String:
	var play: Variant = table.play
	if play == null:
		return "Nothing chosen."
	if not play.ok:
		return "Not allowed: %s" % play.reason
	var text := "%s: %d x %d.  Result: %s." % [play.ev.name, play.ev.chips, play.ev.mult, play.result]
	if play.rescue != null:
		text += "\nShort of the target on the last play: he would take %d." % play.rescue.k
	return text


func _show_faces() -> void:
	_clear()
	var open := Rules.unlocked_factors(_run)
	for row in 3:
		var stance := "hyde" if row == 2 else "jekyll"
		for i in (6 if row == 0 else 5):
			var c: RulesCard
			if row == 0:
				c = RulesCard.make(0, RulesConfig.ROOTS[i >> 1], i % 2 == 1)
			else:
				c = RulesCard.make(0, RulesConfig.FACTORS[i])
			var card := _card(c, stance, Vector2(60.0 + i * 112.0, 60.0 + row * 160.0))
			card.rng_seed = row * 10 + i
			if c.is_factor() and not c.kind in open:
				card.set_tag("locked", true)
	_note("Roots: Paper and Ink of each symbol", Vector2(760.0, 110.0))
	_note("Factors, with Jekyll at the table", Vector2(760.0, 270.0))
	_note("Factors, with Hyde at the table", Vector2(760.0, 430.0))
	_note("Craving %s\nHabit %s\nTemper %s" % [_run.craving, _run.habit, _run.temper], Vector2(60.0, 560.0))


func _show_places() -> void:
	_clear()
	_run.instruments.append("notebook")
	_run.discard.append(_run.hand.pop_back())
	var table := RulesView.table(_run)
	# The draw pile: face down.
	var down := _card(Rules.card(_run, _run.draw[-1]), _run.stance, Vector2(60.0, 80.0))
	down.face_down = true
	_note("Draw pile: %d, face down" % table.draw_count, Vector2(60.0, 230.0))
	# The discards: the last card thrown away, face up.
	_card(Rules.card(_run, _run.discard[-1]), _run.stance, Vector2(260.0, 80.0))
	_note("Discards: %d" % table.discard_count, Vector2(260.0, 230.0))
	# On offer: cards that are in no deck yet.
	var offer: Array = ["heart", "cup", "eye"]
	for i in offer.size():
		_card(RulesCard.make(0, offer[i]), _run.stance, Vector2(520.0 + i * 112.0, 80.0))
	_note("On offer: face up, not to be chosen", Vector2(520.0, 230.0))
	# With the Notebook: the top of the draw pile, next first.
	for i in table.notebook.size():
		_card(Rules.card(_run, table.notebook[i].id), _run.stance, Vector2(60.0 + i * 112.0, 320.0))
	_note("The Notebook: the next cards of the draw pile, the next one first", Vector2(60.0, 470.0))


## A card that is in no hand, shown with the name, chips and text the rules give it.
func _card(c: RulesCard, stance: String, at: Vector2) -> ArenaCard:
	var card := ArenaCard.new()
	card.position = at
	card.show_face(c.key(), c.is_ink() or (c.is_factor() and stance == "hyde"), Rules.name_of(c, stance),
			Rules.chips_of(_run, c),
			RulesConfig.factor_text(c.kind, stance, _run.dials) if c.is_factor() else "")
	_stage.add_child(card)
	return card


func _note(text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", WRITING)
	label.add_theme_font_size_override("font_size", 14)
	_stage.add_child(label)
	return label
