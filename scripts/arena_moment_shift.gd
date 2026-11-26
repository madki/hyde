class_name ArenaMomentShift
## The table changes hands, and what comes with it. The beats shared by a drink, a dose of
## salt, night 4's window, a breakout and a rescue, each from one of the engine's events:
##
## - `store`: the ink on the restraint track lifts off step by step and settles as stored
##   drops beside the mult, under a caption of what they will pay.
## - `page`: the page shifts to the other man. The Factors in the hand turn to his faces, and
##   the Roots he cannot play are printed dark.
## - `joined`: his Roots join the deck, shown first (his first four, a breakout's two, or
##   one when a drink finds nothing left to stain). The line gains their marks.
## - `stained`: the draught stains a Paper Root where it lies, and the line moves a mark.
## - `brought`: whoever arrived brings up to two of his Roots to the hand.

## How long the page's shift is waited for before the next beat: the ink goes on moving.
const PAGE_WAIT := 0.6
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
	t.beats.add(func() -> void:
		if not to_hyde:
			t.beats.sound("shift_to_jekyll")
		t.shown.set_value("stance", "hyde" if to_hyde else "jekyll")
		t.ink.is_jekyll = not to_hyde
		t.numbers.is_jekyll = not to_hyde
		t.hand.turn_to(t.entry, to_hyde)
		await t.beats.wait(PAGE_WAIT))


## His Roots join the deck.
static func joined(t: ArenaTable, e: Dictionary) -> void:
	var cards: Array = []
	var names: Array = []
	for c: Dictionary in e.cards:
		cards.append(t.card_data(c.id))
		names.append(cards[-1].name)
	var cause: String = {"first": "arrival", "breakout": "breakout", "stain": "no_paper"}.get(e.why, "reward")
	# His first four come by a breakout as well as by a drink; the engine's record of the
	# arrival says which.
	if cause == "arrival":
		for ev: Dictionary in t.run.log:
			if ev.get("t") == "shift" and ev.get("first", false) and ev.how in ["breakout", "walkedin"]:
				cause = "first_breakout"
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
