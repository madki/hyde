extends SceneTree
## A measure of the rules' speed, started by tools/bench.sh. It plays whole runs with one
## fixed player and prints a hash of the state after every move, which must not change when
## the rules are only made faster, and the time a run takes. It also times the reading of a
## play, the search for the best play and the copy of a run, alone.
##
## User arguments: `runs=<n>` (200), `calls=<n>` (10000), and `check`, which also compares
## the quick functions with the full ones at every move (slower: its times mean nothing).

const Golden := preload("res://tests/golden.gd")
const MOVE_GUARD := 5000

# Numbers that let the fixed player reach the later nights.
const EASED := {"target_scale": 0.05, "plays": 6, "restraint_limit": 9}
# The hands that are timed: [symbol or kind, ink] for each card.
const HANDS := {
	"jekyll": [["lamp", false], ["lamp", false], ["heart", false], ["mirror", false], ["lamp", true], ["cup", false], ["pen", false], ["eye", false]],
	"hyde": [["lamp", true], ["lamp", true], ["heart", true], ["mirror", true], ["heart", false], ["cup", false], ["pen", false], ["cane", false]],
}

var _problems := 0
var _check := false
var _moves_seen := 0
var _read_kinds := {}


func _initialize() -> void:
	var runs := 200
	var calls := 10000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("runs="):
			runs = int(a.trim_prefix("runs="))
		elif a.begins_with("calls="):
			calls = int(a.trim_prefix("calls="))
		elif a == "check":
			_check = true
		else:
			print("BENCH FAILED: no such argument: %s" % a)
			quit(1)
			return

	var played := _play(runs, {}, 0)
	print("BENCH hash %s" % played.hash)
	print("BENCH runs %d, moves %d, rounds %d, wins %d" % [runs, played.moves, played.rounds, played.wins])
	print("BENCH run %.3f ms" % played.ms)
	# The fixed player seldom sees the later nights. With the targets eased, and begun on each
	# night in turn, it plays them too, so their rules are in a hash.
	@warning_ignore("integer_division")
	var far := _play(maxi(1, runs / 4), EASED, 1000)
	print("BENCH eased hash %s" % far.hash)
	print("BENCH eased runs %d, moves %d, rounds %d, wins %d" % [maxi(1, runs / 4), far.moves, far.rounds, far.wins])
	var moves: int = played.moves + far.moves
	var guard_hit: bool = played.guard or far.guard

	# A hand of night 3, read as each of the two men.
	for stance: String in ["jekyll", "hyde"]:
		var run := Rules.new_run({}, 7)
		Golden.start_on(run, 2, 0)
		run.stance = stance
		run.craving = {"lamp": 2, "heart": 1, "mirror": 0}
		run.habit = {"lamp": 1, "heart": 0, "mirror": 1}
		run.temper = {"lamp": 1, "heart": 2, "mirror": 0}
		_hold(run, HANDS[stance])
		var top := RulesHands.best(run)
		var cards: Array = []
		for id: int in top.ids:
			cards.append(Rules.card(run, id))
		print("BENCH %s hand of %d, deck of %d, best play %s of %d cards" % [stance, run.hand.size(), run.cards.size(), top.ev.key, cards.size()])
		_time("evaluate", stance, calls, func() -> void: RulesHands.evaluate(run, cards))
		_time("best", stance, calls, func() -> void: RulesHands.best(run))
		_time("copy", stance, calls, func() -> void: run.copy())
		_time("read", stance, calls, func() -> void: RulesHands.read(run, cards))
		_time("best_read", stance, calls, func() -> void: RulesHands.best_read(run))
		_time("copy_fast", stance, calls, func() -> void: run.copy_fast())
		_time("copy_fast and play", stance, calls, func() -> void: Rules.play(run.copy_fast(), top.ids))
		_time("copy_fast and play_fast", stance, calls, func() -> void: Rules.play_fast(run.copy_fast(), top.ids))

	if _check:
		print("BENCH check: %d differences, allowed plays read %s" % [_problems, _read_kinds])
	if moves == 0 or guard_hit or _problems > 0:
		print("BENCH FAILED")
		quit(1)
	else:
		print("BENCH DONE")
		quit(0)


# Plays `runs` runs from the seeds `from` on with these changed numbers (with changed numbers,
# four runs in five begin on a later night). Returns the hash of
# every state passed through, the counts, and the milliseconds a run took.
func _play(runs: int, dials: Dictionary, from: int) -> Dictionary:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	var out := {"moves": 0, "wins": 0, "rounds": 0, "guard": false, "hash": "", "ms": 0.0}
	var started := Time.get_ticks_usec()
	for i in runs:
		var run := Rules.new_run(dials, from + i)
		if not dials.is_empty() and i % 5 > 0:
			Golden.start_on(run, i % 5, 0)
		hasher.update((Golden.digest(run) + "\n").to_utf8_buffer())
		var n := 0
		while run.phase != "end" and n < MOVE_GUARD:
			if _check:
				_compare(run)
			_move(run)
			hasher.update((Golden.digest(run) + "\n").to_utf8_buffer())
			n += 1
		out.moves += n
		out.rounds += run.history.size()
		out.guard = out.guard or n >= MOVE_GUARD
		if run.ending != "hyde":
			out.wins += 1
	out.ms = (Time.get_ticks_usec() - started) / 1000.0 / runs
	out.hash = hasher.finish().hex_encode()
	return out


# Puts these cards in the hand and every other card in the draw pile.
func _hold(run: RulesRun, wanted: Array) -> void:
	var rest: Array = []
	for c: RulesCard in run.cards:
		rest.append(c.id)
	run.hand = []
	run.discard = []
	for w: Array in wanted:
		for id: int in rest:
			var c := Rules.card(run, id)
			if c.key() == w[0] and c.ink == w[1]:
				run.hand.append(id)
				rest.erase(id)
				break
	run.draw = rest


func _time(what: String, stance: String, calls: int, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for i in calls:
		f.call()
	print("BENCH %s %s %.2f us" % [what, stance, float(Time.get_ticks_usec() - t0) / calls])


# The fixed player: the best play; a discard of the Roots the man at the table cannot play
# when the best play does not win the round; the first reward; nothing bought.
func _move(run: RulesRun) -> void:
	match run.phase:
		"play":
			var top := RulesHands.best(run)
			var enough: bool = not top.is_empty() and run.score + int(top.ev.score) >= Rules.target(run)
			if not enough and run.discards > 0:
				var dead := _dead(run)
				if not dead.is_empty():
					Rules.discard(run, dead)
					return
			if not top.is_empty():
				Rules.play(run, top.ids)
			elif not Rules.pass_play(run).ok:
				if not Rules.discard(run, run.hand.slice(0, run.dials.max_play)).ok:
					Rules.give_up(run)
		"result":
			Rules.continue_result(run, 0 if run.offer != null else null)
		"lab":
			Rules.leave_lab(run)
		"alley":
			Rules.alley_leave(run)


# The hand's Roots of the other man, as many as one discard takes.
func _dead(run: RulesRun) -> Array:
	var ink: bool = run.stance == "hyde"
	var out: Array = []
	for id: int in run.hand:
		var c := Rules.card(run, id)
		if c.is_root() and c.ink != ink and out.size() < run.dials.max_play:
			out.append(id)
	return out


# Compares the quick functions with the full ones on this state, and on the same state with
# the other man at the table, instruments held and the gauges moved.
func _compare(run: RulesRun) -> void:
	_moves_seen += 1
	var quick := run.copy_fast()
	if JSON.stringify(quick.to_dict()) != JSON.stringify(run.copy().to_dict()) or Golden.digest(quick) != Golden.digest(run):
		_differs("copy_fast", run)
	if run.phase != "play":
		# The copy leaves the place as the run does.
		var twin := run.copy()
		_move(quick)
		_move(twin)
		if Golden.digest(quick) != Golden.digest(twin):
			_differs("copy_fast, moved on", run)
		return
	_compare_reads(run)
	for i in 2:
		var other := run.copy()
		var n: int = _moves_seen + i
		if i == 0:
			other.stance = "hyde" if run.stance == "jekyll" else "jekyll"
		other.instruments = ["saucers", "hcane", "cheque"] if n % 3 > 0 else ["saucers"]
		other.stored = n % 4
		other.craving = {"lamp": n % 3, "heart": (n / 3) % 3, "mirror": (n / 9) % 3}
		other.habit = {"lamp": (n / 2) % 3, "heart": (n / 5) % 2, "mirror": (n / 7) % 4}
		other.temper = {"lamp": (n / 4) % 3, "heart": (n / 11) % 4, "mirror": (n / 13) % 2}
		# Some of the hand's Roots change sides, so that twins lie together.
		for j in other.hand.size():
			var c := Rules.card(other, other.hand[j])
			if c.is_root() and (n + j) % 3 == 0:
				c.ink = not c.ink
		_compare_reads(other)
	# The copy plays on as the run does, and leaves the run alone.
	var top := RulesHands.best(run)
	if not top.is_empty():
		var before := Golden.digest(run)
		var twin := run.copy()
		var res_quick := Rules.play_fast(quick, top.ids)
		var res := Rules.play(twin, top.ids)
		if Golden.digest(quick) != Golden.digest(twin) or Golden.digest(run) != before:
			_differs("copy_fast, played on", run)
		_same_reading(run, res.ev, res_quick.ev)
		if JSON.stringify(quick.to_dict()) != JSON.stringify(twin.to_dict()) or JSON.stringify(res_quick.events) != JSON.stringify(res.events) \
				or res_quick.stance != res.stance or res_quick.phase != res.phase:
			_differs("play_fast", run)


func _compare_reads(run: RulesRun) -> void:
	var before := JSON.stringify(run.to_dict())
	var top := RulesHands.best(run)
	var top_read := RulesHands.best_read(run)
	if top.is_empty() != top_read.is_empty():
		_differs("best_read, none", run)
	elif not top.is_empty():
		if top.ids != top_read.ids or top.key != top_read.key:
			_differs("best_read", run)
		_same_reading(run, top.ev, top_read.ev)
	var hand: Array = []
	for id: int in run.hand:
		hand.append(Rules.card(run, id))
	# Every set of cards of the hand, allowed or not, of up to one card more than a play
	# holds: all of them one move in eight, and those of its first six cards otherwise.
	var whole: bool = _moves_seen % 8 == 0 and hand.size() <= 12
	var n: int = hand.size() if whole else mini(6, hand.size())
	# What `plays` should give: the first allowed set of each different set of kinds.
	var want := {}
	for m in range(1, 1 << n):
		var sel: Array = []
		var code := 0
		for i in n:
			if m & (1 << i):
				sel.append(hand[i])
				code += RulesHands._kind_code(hand[i])
		if sel.size() > run.dials.max_play + 1:
			continue
		var ev := RulesHands.evaluate(run, sel)
		_same_reading(run, ev, RulesHands.read(run, sel))
		if whole and sel.size() <= run.dials.max_play and not want.has(code):
			want[code] = [-int(ev.score), sel.size(), m, sel.map(func(c: RulesCard) -> int: return c.id), ev.key] if ev.ok else []
	if whole:
		var wanted: Array = want.values().filter(func(e: Array) -> bool: return not e.is_empty())
		wanted.sort()
		var got := RulesHands.plays(run)
		if got.size() != wanted.size():
			_differs("plays, how many", run)
		else:
			for i in got.size():
				if got[i].ids != wanted[i][3] or got[i].score != -wanted[i][0] or got[i].key != wanted[i][4]:
					_differs("plays", run)
					break
		if not got.is_empty() and got[0].ids != top.ids:
			_differs("plays, the first", run)
	if JSON.stringify(run.to_dict()) != before:
		_differs("a reading changed the run", run)


func _same_reading(run: RulesRun, ev: Dictionary, r: Dictionary) -> void:
	if ev.ok != r.ok:
		_differs("read, ok", run)
		return
	if not ev.ok:
		return
	_read_kinds[ev.kind] = int(_read_kinds.get(ev.kind, 0)) + 1
	if ev.turns.size() > 1:
		_read_kinds["two turns"] = int(_read_kinds.get("two turns", 0)) + 1
	if ev.key != r.key or ev.name != r.name or ev.kind != r.kind or ev.score != r.score or ev.chips != r.chips or ev.mult != r.mult \
			or ev.adds_restraint != r.adds_restraint or ev.no_craving != r.no_craving or ev.temper_gain != r.temper_gain or ev.spends_stored != r.spends_stored or ev.cheque != r.cheque or ev.craving_on != r.craving_on or ev.breeds != r.breeds \
			or ev.turns != r.turns or ev.draws != r.draws:
		_differs("read", run)


func _differs(what: String, run: RulesRun) -> void:
	_problems += 1
	if _problems <= 10:
		print("BENCH DIFFERS: %s, seed %d, night %d, round %d" % [what, run.seed0, run.night, run.round])
