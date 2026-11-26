class_name ArenaMomentShift
## The table changes hands, and what comes with it. The beats shared by a drink, a dose of
## salt, night 4's window, a breakout and a rescue, each from one of the engine's events:
##
## - `store`: the ink on the restraint track lifts off step by step and settles as stored
##   drops beside the mult, under a caption of what they will pay.
## - `page`: the page shifts to the other man. The Factors in the hand turn to his faces, and
##   the Roots he cannot play are printed dark. To Hyde it is a blow: a short stop as the
##   sound's hit lands, then the picture shakes, the border flares in his light, the cards
##   turn one after another from the left and his name crosses the page in his hand. To
##   Jekyll it is the calm reverse: the ink draws back first and the lamp's light rises, then
##   the cards turn from the right under his name. With "reduce flashes" on nothing shakes or
##   flares; a move played back at once shows none of the staging.
## - `joined`: his Roots join the deck, shown first (his first four, a breakout's two, or
##   one when a drink finds nothing left to stain). The line gains their marks.
## - `stained`: the draught stains a Paper Root where it lies, and the line moves a mark.
## - `brought`: whoever arrived brings up to two of his Roots to the hand.

## The shift to Hyde: how long the table stops as the sound's hit lands, and how hard the
## picture is then shaken (ArenaShake).
const HIT_STOP := 0.12
const HIT := 0.6
## The shift to Jekyll: how long the ink draws back before the cards turn, and how brightly
## and slowly the border takes his light.
const DRAW_BACK := 0.3
const LAMP_LIGHT := 0.5
const LAMP_RISE := 0.4
const LAMP_FALL := 0.7
## The cards of the hand turn this long one after another.
const TURN_GAP := 0.05
## The name that crosses the page: its size, how long it stays before it fades, how long the
## fade takes and how much of it the next beat waits for, how far it travels meanwhile (from
## the ink's side for Hyde, and half as far the other way for Jekyll), and how much too large
## his lands before it settles.
const NAME_SIZE := 104
const NAME_TIME := 0.8
const NAME_FADE := 0.2
const NAME_FADE_WAIT := 0.1
const NAME_DRIFT := 44.0
const NAME_PUNCH := 1.18
## The widest a line in the name's hand may be, as a share of the page: a longer one is
## written smaller.
const NAME_WIDTH := 0.54
## How far down the page the name's middle lies: a little over the page's own, clear of the hand.
const NAME_HEIGHT := 0.46
## The time one step of the track takes to lift off and settle as a stored drop.
const STORE_STEP := 0.22
## How far into the change to Hyde's sound its hit comes: started this long before the page
## shifts, it lands on the shift.
const TO_HYDE_HIT := 1.6
## The two sounds one of which greets a card of his joining the deck, and how loud.
const HYDE_CARD_SOUNDS: Array[String] = ["hyde_card_whisper", "hyde_card_wail"]
const HYDE_CARD_VOLUME := 0.9


## Adds the beats of a `joined`, `stained` or `brought` event. False for any other.
static func add_event(t: ArenaTable, e: Dictionary) -> bool:
	match e.t:
		"joined":
			if e.why == "reward" or e.why == "dawn":
				return false
			joined(t, e)
		"stained":
			stained(t, e)
		"brought":
			brought(t, e)
		_:
			return false
	return true


## `n` steps of restraint become stored drops.
static func store(t: ArenaTable, n: int) -> void:
	if n <= 0:
		return
	var pay := n * t.run.dials.restraint_pay
	t.beats.add_call(func() -> void:
		t.stage.show_caption("%s restraint stored: +%d mult on his first hand."
				% [ArenaCaptions.NUMBERS[mini(n, ArenaCaptions.NUMBERS.size() - 1)].capitalize(), pay]))
	for i in n:
		t.beats.add(func() -> void:
			t.mark("restraint/meter", n - i - 1)
			t.mark("restraint/stored", int(t.shown.value("restraint/stored", 0)) + 1)
			await t.beats.wait(STORE_STEP))
	# The caption stays while the page shifts: the next one takes its place.


## The change to Hyde's sound, for a page shift to Hyde that comes `lead` seconds of the
## queue's time after this beat: it starts so that its hit lands on the shift, or at once
## when the lead is shorter. Nothing plays if Hyde has the table already.
static func cue_to_hyde(t: ArenaTable, lead: float) -> void:
	t.beats.add_call(func() -> void:
		if t.hyde():
			return
		var delay := lead - TO_HYDE_HIT
		if delay <= 0.0:
			t.beats.sound("shift_to_hyde")
			return
		t.beats.wait(delay).connect(func() -> void: t.beats.sound("shift_to_hyde"), CONNECT_ONE_SHOT))


## A sound as cards of his join the deck, before they appear: once, however many there are.
static func hyde_joins(t: ArenaTable) -> void:
	t.beats.add_call(func() -> void:
		t.beats.sound(HYDE_CARD_SOUNDS.pick_random(), 1.0, HYDE_CARD_VOLUME))


## The page shifts to Hyde (`to_hyde`) or back to Jekyll.
static func page(t: ArenaTable, to_hyde: bool) -> void:
	if to_hyde:
		t.beats.add(func() -> void:
			# The stop: nothing moves while the sound's hit lands.
			if staged(t):
				await t.beats.wait(HIT_STOP)
			t.shown.set_value("stance", "hyde")
			t.ink.is_jekyll = false
			t.numbers.is_jekyll = false
			if staged(t) and not ArenaPace.reduce_flashes:
				ArenaShake.hit(HIT)
				t.follow(_border(t).flare(Palette.HYDE))
			t.follow(t.hand.turn_to(t.entry, true, TURN_GAP if staged(t) else 0.0))
			name_across(t, "Hyde", true)
			await t.beats.wait(NAME_TIME + NAME_FADE_WAIT))
		return
	t.beats.add(func() -> void:
		t.beats.sound("shift_to_jekyll")
		# The ink draws back first and the lamp's light rises; then the table is his.
		t.ink.is_jekyll = true
		if staged(t):
			if not ArenaPace.reduce_flashes:
				t.follow(_border(t).flare(Palette.JEKYLL, LAMP_LIGHT, LAMP_RISE, LAMP_FALL))
			await t.beats.wait(DRAW_BACK)
		t.shown.set_value("stance", "jekyll")
		t.numbers.is_jekyll = true
		t.follow(t.hand.turn_to(t.entry, false, TURN_GAP if staged(t) else 0.0))
		name_across(t, "Jekyll", false)
		await t.beats.wait(NAME_TIME + NAME_FADE_WAIT))


## False while the move is played back at once (skipped, or the speed of a still or a check):
## a change of hands then has no staging.
static func staged(t: ArenaTable) -> bool:
	return t.beats.rate() < ArenaPace.SKIP


## Writes `words` large across the middle of the page, in Hyde's backward-sloped hand
## (`hyde`) or Jekyll's upright one: they stay for NAME_TIME, drifting, and fade. Nothing is
## waited for, and nothing is written in a move played back at once.
static func name_across(t: ArenaTable, words: String, hyde: bool) -> void:
	if not staged(t):
		return
	var font := FontVariation.new()
	var plain := StoryEntry.easy_read
	font.base_font = ThemeDB.fallback_font if plain else StoryEntry.FACE
	var slope := 0.0
	if hyde:
		slope = StoryEntry.PLAIN_SLOPE if plain else StoryEntry.HYDE_SLOPE
	if not plain:
		font.variation_embolden = StoryEntry.HYDE_WEIGHT if hyde else StoryEntry.JEKYLL_WEIGHT
	font.variation_transform = Transform2D(Vector2(1.0, -slope), Vector2(0.0, 1.0), Vector2.ZERO)
	var page := t.arena.size
	var font_size := NAME_SIZE
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if width > page.x * NAME_WIDTH:
		font_size = int(font_size * page.x * NAME_WIDTH / width)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = words
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.HYDE if hyde else Palette.JEKYLL.lerp(Palette.CHALK, 0.35))
	label.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.92))
	label.add_theme_constant_override("outline_size", 16)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	# Under the notice's sheet, over everything else of the table.
	t.arena.add_child(label)
	t.arena.move_child(label, t.moments.notice.get_index())
	var drift := NAME_DRIFT if hyde else -NAME_DRIFT * 0.5
	var rest := Vector2(page.x * 0.5, page.y * NAME_HEIGHT) - label.size * 0.5
	label.position = rest + Vector2(drift * 0.5, 0.0)
	label.modulate.a = 0.0
	var cross := t.beats.tween()
	cross.tween_property(label, "position:x", rest.x - drift * 0.5, NAME_TIME + NAME_FADE)
	var show := t.beats.tween()
	show.tween_property(label, "modulate:a", 1.0, 0.08 if hyde else 0.3)
	show.tween_interval(NAME_TIME - (0.08 if hyde else 0.3))
	show.tween_property(label, "modulate:a", 0.0, NAME_FADE)
	show.tween_callback(label.queue_free)
	if hyde:
		# His lands: too large for a moment, as the blow does.
		label.scale = Vector2.ONE * NAME_PUNCH
		t.beats.tween().tween_property(label, "scale", Vector2.ONE, 0.16) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


static func _border(t: ArenaTable) -> ArenaBorder:
	return t.arena.get_node("Border") as ArenaBorder


## His Roots join the deck.
static func joined(t: ArenaTable, e: Dictionary) -> void:
	var cards: Array = []
	var names: Array = []
	for c: Dictionary in e.cards:
		cards.append(t.card_data(c.id))
		names.append(cards[-1].name)
	var cause: String = {"first": "arrival", "breakout": "breakout", "stain": "no_paper"}.get(e.why, "reward")
	# They come out of his ink, at the right of the page.
	var from := Vector2(t.arena.size.x - 60.0, t.arena.size.y * 0.42)
	hyde_joins(t)
	t.moments.join_deck(cards, ArenaCaptions.joins(cause, names), from, true, joins_notice.bind(t, cause, cards.size()))
	t.beats.add(func() -> void:
		# The line's marks are drawn while the table goes on.
		var ink: int = t.shown.add("line/ink", cards.size())
		t.line_sound(true)
		t.play(t.symbols.set_line.bind(int(t.shown.value("line/paper", 0)), ink)))


## The notice's words for `count` of his Roots joining by `cause`, with the line as it will
## stand once they have joined. `symbol` is the rolled-over symbol's label, for "rollover".
static func joins_notice(t: ArenaTable, cause: String, count: int, symbol: String = "") -> Dictionary:
	return ArenaCaptions.joins_notice(cause, int(t.shown.value("line/paper", 0)),
			int(t.shown.value("line/ink", 0)) + count, symbol)


## A Paper Root is stained where it lies: in the draw pile, the discards or the hand.
static func stained(t: ArenaTable, e: Dictionary) -> void:
	var after := t.card_data(e.id)
	var before := after.duplicate()
	before.ink = false
	before.name = RulesConfig.ROOT[e.sym].paper
	before.chips = int(t.after.symbols[e.sym].paper_chips)
	var words := ArenaCaptions.changes("stain", before.name, after.name)
	var said := func() -> Dictionary:
		return ArenaCaptions.changes_notice("stain", before.name, after.name,
				int(t.shown.value("line/paper", 0)), int(t.shown.value("line/ink", 0)))
	if e.from == "hand":
		var card := t.hand.card_of(e.id)
		var rest := func() -> Dictionary:
			var at := t.hand.rest_of(e.id)
			card.set_meta("away", true)
			return at
		t.moments.change_side(before, after, "hand", words, card, Vector2.ZERO, 0.0, rest, said)
		t.beats.add_call(func() -> void:
			card.card_id = e.id
			card.dimmed = false
			t.hand.settle(card))
	else:
		t.moments.change_side(before, after, "discards" if e.from == "discard" else "draw", words,
				null, Vector2.ZERO, 0.0, Callable(), said)
	t.beats.add(func() -> void:
		t.shown.add("line/paper", -1)
		t.shown.add("line/ink", 1)
		t.line_sound(true)
		await t.play(t.symbols.line_across.bind(true)))


## Whoever arrived brings his Roots to the hand, from the pile each was found in.
static func brought(t: ArenaTable, e: Dictionary) -> void:
	var man := "Hyde" if e.who == "hyde" else "Jekyll"
	var by_pile := {}
	for c: Dictionary in e.cards:
		var pile := "discards" if c.from == "discard" else "draw"
		if not by_pile.has(pile):
			by_pile[pile] = []
		by_pile[pile].append(t.card_data(c.id))
	if by_pile.is_empty():
		t.moments.bring_to_hand(man, [], "draw", Callable())
		return
	for pile: String in by_pile:
		t.moments.bring_to_hand(man, by_pile[pile], pile, func(nodes: Array) -> void:
			var last: Signal
			for node: ArenaCard in nodes:
				var id: int = node.get_meta("data").id
				var to: Dictionary = t.hand.take_in(node, t.entry(id), t.hyde())
				last = t.travel.fly(node, to.centre, to.turn, to.size, ArenaTravel.UP)
				last.connect(t.hand.settle.bind(node), CONNECT_ONE_SHOT)
			if not nodes.is_empty():
				await last)


## The flask and the salt are set for what comes next: corked or open, folded or unfolded,
## and the flask's tag names the next drink's cost.
static func means(t: ArenaTable) -> void:
	t.beats.add(func() -> void:
		t.shown.set_value("salt/doses", t.after.salt.doses)
		# Input opens while the flask fills and the papers fold or unfold.
		t.settle_means())
