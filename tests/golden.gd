extends RefCounted
## Recorded runs of the card game, for the tests that replay them.
##
## tests/golden/rules_runs.json was recorded from the reference implementation of the rules.
## For each run it holds the seed, the changed numbers (`dials`), the night it starts on
## (`start`, or null for a whole run), every move (`moves`), whether each was accepted (`oks`,
## a 1 or a 0 a move), a hash of the state's digest after each move (`hashes`), and the digest
## itself before the first move and after the last (`first`, `last`).

const PATH := "res://tests/golden/rules_runs.json"
const FACTOR_CODE := {"cup": "c", "eye": "e", "lock": "k", "pen": "p", "cane": "n"}

static var _runs: Array = []


static func runs() -> Array:
	if _runs.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary and data.has("runs"):
			_runs = Rules._whole_numbers(data.runs)
	return _runs


## The run a record starts from.
static func begin(record: Dictionary) -> RulesRun:
	var run := Rules.new_run(record.dials, record.seed)
	if record.start != null:
		start_on(run, record.start.night, record.start.round)
	return run


## Drops a new run into a later night, with what the dawns before it would have unlocked and
## brought.
static func start_on(run: RulesRun, night: int, round_no: int) -> void:
	run.unlocked.pen = true
	run.unlocked.cane = night >= 2
	run.hyde_arrived = true
	for sym in RulesConfig.FIRST_ARRIVAL:
		run.cards.append(Rules.make_card(run, sym, true))
	for i in 2 + night:
		run.cards.append(Rules.make_card(run, RulesConfig.ROOTS[i % 3], false))
	run.cards.append(Rules.make_card(run, "pen", false))
	if night >= 2:
		run.cards.append(Rules.make_card(run, "cane", false))
	run.sov = 12
	run.night = night
	run.round = round_no
	Rules.start_round(run)


## Makes one recorded move. Returns whether the rules accepted it.
static func apply(run: RulesRun, move: Array) -> bool:
	var res: Dictionary
	match move[0]:
		"play": res = Rules.play(run, move[1])
		"discard": res = Rules.discard(run, move[1])
		"drink": res = Rules.drink(run)
		"salt": res = Rules.take_salt(run)
		"pass": res = Rules.pass_play(run)
		"giveup": res = Rules.give_up(run)
		"continue": res = Rules.continue_result(run, null if move[1] < 0 else move[1])
		"habit": res = Rules.alley_habit(run, move[1])
		"inst": res = Rules.alley_instrument(run, move[1])
		"asalt": res = Rules.alley_salt(run)
		"aleave": res = Rules.alley_leave(run)
		"card": res = Rules.buy_card(run, move[1])
		"tool": res = Rules.buy_instrument(run, move[1])
		"lsalt": res = Rules.buy_salt(run)
		"strike": res = Rules.strike(run, move[1])
		"drop": res = Rules.drop_instrument(run, move[1])
		"lleave": res = Rules.leave_lab(run)
		_: return false
	return res.ok


## The state as one line of text, built the same way by the recorder.
static func digest(run: RulesRun) -> String:
	var shop := "-"
	if run.shop != null:
		shop = _join(run.shop.cards.map(_shelf)) + ";" + _join(run.shop.instruments.map(_shelf))
	var alley := "-"
	if run.alley != null:
		var a: Dictionary = run.alley
		alley = "%s;%s;%s;%d" % [a.habit if a.habit != null else "", a.inst if a.inst != null else "", _join(a.options), a.bought]
	var cards: Array = []
	for c: RulesCard in run.cards:
		var code: String = FACTOR_CODE[c.kind] if c.t == "factor" else (str(c.sym)[0].to_upper() if c.ink else str(c.sym)[0])
		cards.append(str(c.id) + code)
	var parts: Array = [
		run.phase, run.night, run.round, run.stance, run.score, run.plays, run.discards,
		run.restraint, run.stored, run.salt, run.doses_bought, run.sov,
		int(run.hyde_arrived), "%d%d" % [int(run.unlocked.pen), int(run.unlocked.cane)], _join(run.instruments),
		_gauge(run.craving), _gauge(run.habit), _gauge(run.temper), run.seed,
		_join(run.draw), _join(run.hand), _join(run.discard), _join(cards),
		_join(run.offer) if run.offer != null else "-", shop, alley,
		run.ending if run.ending != null else "-", run.ended_by if run.ended_by != null else "-",
		run.last.how if run.last != null else "-",
	]
	return _join(parts, "|")


## FNV-1a, 32 bits, over the text's characters.
static func fnv(text: String) -> int:
	var h := 0x811c9dc5
	for b in text.to_ascii_buffer():
		h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
	return h


static func _shelf(o: Dictionary) -> String:
	return str(o.key) + ("!" if o.sold else "")


static func _gauge(g: Dictionary) -> String:
	return "%d,%d,%d" % [g.lamp, g.heart, g.mirror]


static func _join(items: Array, with: String = ",") -> String:
	var texts := PackedStringArray()
	for item: Variant in items:
		texts.append(str(item))
	return with.join(texts)
