class_name ArenaMomentPlay
## A play, performed one step at a time (the engine's `ev.steps`):
##
## 1. The chosen cards leave the hand and are laid in the centre, in the order they score:
##    Roots first, then Factors. A play is taken off the tally.
## 2. The readout names the hand and shows its base, and both numbers pulse.
## 3. Each Root hops and gives its chips; what its gauge gives of them rises under its own,
##    in the gauge's colour. Its gauge's mult follows it, a beat of its own: the Root hops, a
##    tally mark leaves it for the gauge, the gauge pulses and says its name and value, and
##    the mult travels from it to the mult. A Sublimation's burst rises from the Ink Root.
## 4. Each Factor hops, gives its chips, and then its effect. Vigour and Restlessness make
##    the best Root hop again; Reason and Alibi make each Root they count hop.
## 5. Stored restraint flies into the mult a drop at a time, and The Cane hops.
## 6. Chips and mult become one total, which travels to the round's score; a score that
##    reaches the target strikes it through.
## 7. What the play does to the gauges (ArenaMomentAfter).
## 8. The laid cards go to the discards and the hand refills, the card drawn for Curiosity or
##    Impulse under an eye mark. A play that ends the round is not refilled.
##
## The first ticks of a play are slow and the later ones quicker (ArenaPace.tick).

## The time of a step that moves no number (a lock, an eye), as a share of a tick's.
const QUIET := 0.7
## How strong each hand sounds as it is named, 1 to 3 (the stingers `hand_j_<n>` and
## `hand_h_<n>`): mostly by its base chips × mult among its man's hands; a Sublimation, rare
## and turning his Roots, is a middle one.
const HAND_TIERS := {
	"thought": 1, "spark": 1, "rumination": 1, "goodwork": 2, "sublimation": 2, "dogma": 2, "lucid": 3,
	"stirring": 1, "lapse": 1, "turmoil": 2, "fixation": 2, "mania": 3,
}
## The most semitones the chips and mult of one play climb, so that a long play does not squeak.
const RAMP_TOP := 12
## As the ramp climbs to RAMP_TOP, how much larger a step's pop grows (and how much further it
## rises) and how much higher its card hops, at the top. The readout's pulse grows with it
## (ArenaNumbers.climb).
const RAMP_POP := 1.5
const RAMP_RISE := 1.35
const RAMP_HOP := 1.6
## From this step of the ramp on (0 the first), each tick hits the picture, very lightly.
const RAMP_HIT_FROM := 7
const RAMP_HIT := 0.1
## The beat of a gauge that pays, by how many times that symbol's gauge has paid in the play
## (the first, the second, the third and later), before its mult ticks; and the shares of it
## that the mark's flight, the gauge's pulse and the mult's flight take.
const PAY_BEATS: Array[float] = [0.60, 0.35, 0.25]
const PAY_MARK := 0.20 / 0.60
const PAY_PULSE := 0.15 / 0.60
const PAY_FLIGHT := 0.25 / 0.60
## The words of a gauge that pays fade this long once its mult has ticked.
const PAY_FADE := 0.15

## How hard the picture is hit as a total lands, by the play's weight (`_weight`), and the
## sound of each blow. A sound plays once Sfx knows its name and has its file.
const LAND_HITS: Array[float] = [0.0, 0.3, 0.6, 1.0]
const LAND_SOUNDS: Array[String] = ["", "impact_1", "impact_2", "impact_3"]
## The hit as a target is struck through, and when one play took the whole of it.
const STRIKE_HIT := 0.3
const STRIKE_HIT_ALONE := 0.6

## For `--trace`: when the play's score began to be shown, in milliseconds.
static var _began_ms := 0


static func add(t: ArenaTable, result: Dictionary) -> void:
	var ev: Dictionary = result.ev
	var steps: Array = ev.steps
	var events: Array = result.events
	var hyde: bool = result.stance == "hyde"
	var colour := ArenaPop.man(hyde)
	var ends := events.any(func(e: Dictionary) -> bool: return e.t == "round_end")
	# The cards in the order they score.
	var order: Array = []
	for step: Dictionary in steps:
		if step.kind in ["root", "factor"] and not order.has(step.id):
			order.append(step.id)
	var laid := {}
	var eyes: Array = []
	_lay(t, order, laid)
	_score(t, steps, laid, eyes, colour, _stinger(str(ev.key), hyde))
	var score_to := 0
	# The symbols whose gauges the play changes: their cards' chips are counted anew.
	var changed: Array = []
	var rescue := {}
	for e: Dictionary in events:
		match e.t:
			"scored":
				score_to = e.to
				_total(t, score_to)
				for step: Dictionary in steps:
					if step.kind == "effect" and step.label in ["no restraint", "no Craving"]:
						ArenaMomentAfter.unlock(t, step.label == "no restraint")
			"stored_spent":
				pass # performed with the score, a drop at a time
			"restraint", "craving", "breed", "turn", "cheque":
				ArenaMomentAfter.add_event(t, e, order)
				if e.has("sym") and not changed.has(e.sym):
					changed.append(e.sym)
			"discarded":
				for sym: String in changed:
					ArenaMomentAfter.recount(t, sym)
				_leave(t, order, laid)
			"drawn", "reshuffle":
				# A play that ends the round is not refilled: the cards go back to the deck.
				if ends:
					continue
				if e.t == "drawn" and e.why == "draws":
					_draw_with_eyes(t, e.ids, eyes)
				else:
					ArenaMomentCards.add_event(t, e)
			"breakout":
				ArenaMomentBreakout.add(t, e)
			"joined", "brought":
				# In a rescue his first four Roots join the gathered deck, at the round's end.
				if e.t == "joined" and rescue.has("last"):
					rescue.first = e
				else:
					ArenaMomentShift.add_event(t, e)
			"rescue", "converted":
				ArenaMomentRescue.add_event(t, e, rescue)
			"round_end":
				ArenaMomentEnd.add(t, e, rescue.get("first", {}))
			_:
				t.unhandled = true
	t.beats.add_call(func() -> void:
		for mark: ArenaPop in eyes:
			if is_instance_valid(mark):
				mark.fade(t.beats))


# Beat 1: the cards are laid in the centre and a play is taken off the tally.
static func _lay(t: ArenaTable, order: Array, laid: Dictionary) -> void:
	t.beats.add(func() -> void:
		t.mark("plays", t.shown.value("plays", 1) - 1)
		var cards: Array = []
		for id: int in order:
			var card := t.hand.give(id)
			if card == null:
				continue
			card.set_meta("data", t.card_data(id))
			t.travel.take(card)
			laid[id] = card
			cards.append(card)
		if not cards.is_empty():
			ArenaMomentCards.on_each_start(t, cards.size(), func() -> void:
				t.beats.sound("lay", Sfx.vary(), 0.8))
			await t.stage.lay(t.travel, cards))


# Beats 2 to 5: the hand is named, then each step of the score.
static func _score(t: ArenaTable, steps: Array, laid: Dictionary, eyes: Array, colour: Color,
		stinger: String) -> void:
	var base: Dictionary = steps[0]
	var note := "(hunted)" if str(base.label).ends_with(", hunted") else ""
	var hand_name := str(base.label).trim_suffix(", hunted")
	t.beats.add_call(func() -> void: _began_ms = Time.get_ticks_msec())
	t.beats.add(func() -> void:
		t.beats.sound(stinger, 1.0, 0.8)
		await t.follow(t.numbers.name_hand(hand_name, base.chips, base.mult, note)).finished
		if Shot.has_arg("trace"):
			print("  %s %s  %d x %d" % [hand_name, note, base.chips, base.mult]))
	var tick := 0
	# Each step that raises the chips or the mult sounds a semitone above the one before.
	var ramp := [0]
	# How many times each symbol's gauge has paid in this play.
	var paid := {}
	for i in range(1, steps.size()):
		var step: Dictionary = steps[i]
		var n := tick
		if step.chips != 0 or step.mult != 0:
			tick += 1
		t.beats.add(func() -> void: await _step(t, step, n, laid, eyes, colour, ramp, paid))


# The stinger played as the hand is named: its man's, louder for a stronger hand. A hand of
# neither man's (a Passing Thought) is the man's at the table.
static func _stinger(key: String, hyde: bool) -> String:
	var side := "h" if hyde else "j"
	if RulesConfig.HANDS.hyde.has(key):
		side = "h"
	elif RulesConfig.HANDS.jekyll.has(key):
		side = "j"
	return "hand_%s_%d" % [side, int(HAND_TIERS.get(key, 1))]


# A step raised the chips (or the mult): their sound, a semitone above the last of the play,
# and late in a long play a very light hit.
static func _ramp(t: ArenaTable, sound_name: String, ramp: Array) -> void:
	t.beats.sound_sided(sound_name, Sfx.semitones(mini(ramp[0], RAMP_TOP)))
	if ramp[0] >= RAMP_HIT_FROM:
		_shake(t, RAMP_HIT)
	ramp[0] += 1


# How far the ramp has climbed, 0 at the play's first step to 1 at RAMP_TOP.
static func _climb(ramp: Array) -> float:
	return float(mini(ramp[0], RAMP_TOP)) / RAMP_TOP


# One step: the card that acts hops, what it gives rises from it, and the readout ticks; all
# of it larger the further the play's ramp has climbed. A gauge that pays keeps its own sizes.
static func _step(t: ArenaTable, step: Dictionary, n: int, laid: Dictionary, eyes: Array, colour: Color,
		ramp: Array, paid: Dictionary) -> void:
	var card: ArenaCard = laid.get(step.id)
	var climb := _climb(ramp)
	var hop := ArenaPop.HOP * lerpf(1.0, RAMP_HOP, climb)
	t.numbers.climb = climb
	var at := _above(card) if card else Vector2.ZERO
	var words := ""
	if step.chips != 0:
		words = "+%d" % step.chips
	elif step.mult != 0:
		words = "+%d mult" % step.mult
	var pays: bool = step.kind == "gauge" and step.gauge in ["temper", "habit"]
	match step.kind:
		"root", "factor":
			ArenaPop.hop(t.beats, card, hop)
			if step.kind == "root" and _gauge_chips(t, step, card, colour, climb):
				words = ""
		"gauge":
			if pays:
				await _pay(t, step, card, paid)
				words = ""
			else:
				words = "%s %s" % [str(step.label).capitalize(), words]
		"again":
			var again: ArenaCard = laid.get(step.of)
			ArenaPop.hop(t.beats, card, hop)
			ArenaPop.hop(t.beats, again, hop)
			if again:
				at = _above(again)
		"effect":
			if step.of >= 0:
				ArenaPop.hop(t.beats, laid.get(step.of), hop)
			if step.chips == 0 and step.mult == 0:
				words = step.label
				if step.label == "no restraint":
					t.beats.sound("lock")
					t.follow(t.numbers.restraint.set_lock(true))
				elif step.label == "no Craving":
					t.beats.sound("lock")
					t.play(t.symbols.set_lock.bind(true))
				if str(step.label).begins_with("draws") and card:
					t.beats.sound("eye")
					var mark := ArenaPop.eye(t.travel, ArenaTravel.centre_of(card))
					eyes.append(mark)
					mark.fly_to(t.beats, t.piles.draw_pile.top_centre() + Vector2(-34.0, -40.0))
		"stored":
			t.shown.set_value("restraint/stored", maxi(0, int(t.shown.value("restraint/stored", 0)) - 1))
			if step.mult > 0:
				_ramp(t, "mult", ramp)
			await t.follow(t.numbers.fly_drop(step.mult)).finished
			return
		"instrument":
			t.play(t.means.hop.bind("hcane"))
			# What it gives rises from just over its emblem, not across it.
			at = t.means.spot("hcane") + Vector2(0.0, -ArenaMeans.ROUND_R - 6.0)
	if words != "" and at != Vector2.ZERO:
		ArenaPop.text(t.beats, t.travel, at, words, colour,
				_pop_size(20 if step.chips != 0 or step.mult != 0 else 15, climb), _pop_rise(climb))
	if step.chips != 0:
		if step.chips > 0:
			_ramp(t, "chips", ramp)
		await t.follow(t.numbers.tick_chips(step.chips)).finished
	elif step.mult != 0:
		if step.mult > 0:
			_ramp(t, "mult", ramp)
		await t.follow(t.numbers.tick_mult(step.mult)).finished
	else:
		await t.beats.wait(ArenaPace.tick(n) * QUIET)
	if pays:
		var fade := t.beats.tween()
		fade.tween_method(func(a: float) -> void: t.symbols.set_pay(step.sym, step.gauge, a, 0.0), 1.0, 0.0, PAY_FADE)
	if Shot.has_arg("trace"):
		print("  %-9s %-18s %d x %d   %.2f s" % [step.kind, step.label, roundi(t.numbers.get("_chips")),
				roundi(t.numbers.get("_mult")), (Time.get_ticks_msec() - _began_ms) / 1000.0])


# A pop's size and how far it rises, by how far the ramp has climbed (`_climb`).
static func _pop_size(size: int, climb: float) -> int:
	return roundi(size * lerpf(1.0, RAMP_POP, climb))


static func _pop_rise(climb: float) -> float:
	return ArenaPop.RISE * lerpf(1.0, RAMP_RISE, climb)


# A Root whose gauge gives some of its chips (15 a point, from the run's dials): its own chips
# rise in the man's colour and, under them, the gauge's in the gauge's colour, both as large as
# the ramp has climbed to (`climb`). True if it did.
static func _gauge_chips(t: ArenaTable, step: Dictionary, card: ArenaCard, colour: Color, climb: float) -> bool:
	if card == null or step.sym == "" or step.chips <= 0:
		return false
	var data: Dictionary = card.get_meta("data", {})
	var row := "habit" if data.get("ink", false) else "temper"
	var each: int = t.run.dials.habit_chips if row == "habit" else t.run.dials.temper_chips
	var given := each * int(t.shown.value("symbols/%s/%s" % [step.sym, row], 0))
	if given <= 0 or given >= step.chips:
		return false
	var at := _above(card)
	var big := _pop_size(20, climb)
	ArenaPop.text(t.beats, t.travel, at, "+%d" % (step.chips - given), colour, big, _pop_rise(climb))
	ArenaPop.text(t.beats, t.travel, at + Vector2(0.0, big), "+%d %s" % [given, row.capitalize()],
			_gauge_colour(row), _pop_size(15, climb), _pop_rise(climb))
	return true


# A gauge that pays, up to its mult's tick: the Root hops, its mark leaves it for the gauge,
# the gauge pulses and stands its name and value beside it, and the mult leaves it for the
# mult. The first time a symbol's gauge pays in a play is the slowest.
static func _pay(t: ArenaTable, step: Dictionary, card: ArenaCard, paid: Dictionary) -> void:
	var sym: String = step.sym
	var row: String = step.gauge
	var k: int = paid.get(sym, 0)
	paid[sym] = k + 1
	var beat: float = PAY_BEATS[mini(k, PAY_BEATS.size() - 1)]
	var tint := _gauge_colour(row)
	var gauge := t.symbols.pay_place(sym, row)
	ArenaPop.hop(t.beats, card)
	if card:
		await ArenaPop.tally(t.beats, t.travel, _above(card), gauge, tint, row == "habit", beat * PAY_MARK)
	var pulse := t.beats.tween()
	pulse.tween_method(func(a: float) -> void: t.symbols.set_pay(sym, row, 1.0, sin(a * PI)), 0.0, 1.0,
			beat * PAY_PULSE)
	await pulse.finished
	await ArenaPop.fly_text(t.beats, t.travel, t.symbols.pay_from(sym), t.numbers.mult_place(), "+%d mult" % step.mult, tint,
			beat * PAY_FLIGHT)


static func _gauge_colour(row: String) -> Color:
	return Palette.TEMPER if row == "temper" else Palette.HABIT


# Beats 6 and 7: the total lands, travels to the round's score, and may strike the target.
# The more of the target the play takes alone, the harder it lands (`_weight`).
static func _total(t: ArenaTable, score_to: int) -> void:
	var play := {"weight": 0}
	t.beats.add(func() -> void:
		var weight := _weight(score_to - int(t.shown.value("score", 0)), int(t.after.target))
		play.weight = weight
		# The ticks gather into one landing; Hyde's is lower and heavier.
		t.beats.sound("total", 0.84 if t.hyde() else 1.0)
		var land := t.follow(t.numbers.land_total(weight))
		if weight > 0:
			# The blow falls as the total is at its fullest.
			var blow := t.beats.tween()
			blow.tween_interval(ArenaNumbers.land_peak(weight))
			blow.tween_callback(func() -> void:
				_shake(t, LAND_HITS[weight])
				if LAND_SOUNDS[weight] in Sfx.NAMES:
					t.beats.sound(LAND_SOUNDS[weight]))
		await land.finished
		if Shot.has_arg("trace"):
			print("  total     %d, the round's score to %d   %.2f s" % [t.numbers.get("_total"), score_to,
					(Time.get_ticks_msec() - _began_ms) / 1000.0]))
	t.beats.add(func() -> void:
		t.shown.set_value("score", score_to)
		var send := t.follow(t.numbers.send_total(score_to))
		# The score blooms as the total reaches it.
		var bloom := t.beats.tween()
		bloom.tween_interval(ArenaNumbers.TRAVEL_TIME)
		bloom.tween_callback(func() -> void:
			t.beats.sound_sided("bloom")
			t.landed.emit())
		await send.finished)
	if score_to >= int(t.after.target):
		t.beats.add(func() -> void:
			t.beats.sound("target_struck")
			# A play that took the whole target alone: the score bleeds ink, or flares in light.
			var alone: bool = play.weight >= 3
			_shake(t, STRIKE_HIT_ALONE if alone else STRIKE_HIT)
			if alone:
				t.follow(t.numbers.spill_score())
			await t.follow(t.numbers.strike_target()).finished)


# How hard a play lands, 0 to 3, by how much of the round's target its total is: under a
# quarter, under a half, under the whole, and the whole target or more.
static func _weight(total: int, target: int) -> int:
	if target <= 0:
		return 0
	var share := float(total) / target
	return 3 if share >= 1.0 else 2 if share >= 0.5 else 1 if share >= 0.25 else 0


# The picture shakes, unless the move is being skipped.
static func _shake(t: ArenaTable, strength: float) -> void:
	if not t.beats.is_skipping():
		ArenaShake.hit(strength)


# The laid cards go to the discards.
static func _leave(t: ArenaTable, order: Array, laid: Dictionary) -> void:
	t.beats.add(func() -> void:
		var cards: Array = []
		for id: int in order:
			if laid.has(id):
				cards.append(laid[id])
		if not cards.is_empty():
			ArenaMomentCards.on_each_start(t, cards.size(), ArenaMomentCards.discard_sound.bind(t))
			await t.piles.put("discards", cards))


# The cards drawn for Curiosity or Impulse: each comes to the hand under an eye mark.
static func _draw_with_eyes(t: ArenaTable, ids: Array, eyes: Array) -> void:
	for id: int in ids:
		t.beats.add(func() -> void:
			var mark: ArenaPop = eyes.pop_front() if not eyes.is_empty() else null
			var card := t.piles.take("draw", t.card_data(id))
			var to: Dictionary = t.hand.take_in(card, t.entry(id), t.hyde())
			if mark:
				mark.fly_to(t.beats, to.centre + Vector2(0.0, -ArenaCard.SIZE.y * to.size * 0.5 - 6.0), ArenaPace.TRAVEL)
			ArenaMomentCards.draw_sound(t)
			await t.travel.fly(card, to.centre, to.turn, to.size, ArenaTravel.UP)
			t.hand.settle(card)
			await t.beats.wait(ArenaPace.MARK)
			if mark:
				mark.fade(t.beats))


# The point just above a card's middle, on the page: where what it gives rises from.
static func _above(card: ArenaCard) -> Vector2:
	return ArenaTravel.centre_of(card) + Vector2(0.0, -ArenaCard.SIZE.y * card.scale.y * 0.5 + 6.0)
