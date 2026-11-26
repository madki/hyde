class_name SimValue
## What a run is worth to a player that looks ahead: a hand-written guess, from 0 to 1, at how
## well it stands. A searching player reads it at the end of a round it has played out.

## The numbers of the guess, by name, so that they can be tuned.
##
## The first six are shares of the whole and add up to 1: `alive` is what a run that goes on
## is worth whatever else is true of it, and each of the others is given in the measure its
## part of the guess (0 to 1) is met.
## A `*_full` number is where a part counts as fully met: the lead of Paper Roots over Ink
## Roots on the line, the round's plays at their likely best against the next target, the
## doses of salt and the sovereigns held.
## An `at_*` number is how well a man stands who has the table before the round to come:
## an ordinary round, or a scene with that twist. `at_plain_full` is what Jekyll loses before
## an ordinary round with his meter at its limit, and `at_plain_hyde_dry` is Hyde's place
## with no salt to come back by.
## `craving` is the share of a point of Craving that is counted as Temper to come.
static var weights := {
	"alive": 0.3,
	"line": 0.2,
	"power": 0.3,
	"salt": 0.08,
	"sov": 0.04,
	"table": 0.08,
	"line_full": 8.0,
	"power_full": 2.0,
	"salt_full": 3.0,
	"sov_full": 12.0,
	"craving": 0.5,
	"at_plain_jekyll": 1.0,
	"at_plain_full": 0.5,
	"at_plain_hyde": 0.5,
	"at_plain_hyde_dry": 0.2,
	"at_hunted_jekyll": 1.0,
	"at_hunted_hyde": 0.2,
	"at_tight_jekyll": 0.5,
	"at_tight_hyde": 1.0,
	"at_window_jekyll": 1.0,
	"at_window_hyde": 0.6,
	"at_last_jekyll": 0.5,
	"at_last_hyde": 0.5,
}


## What the run is worth, from 0 to 1: 0 for a lost run, 1 for a won one, and for a run that
## goes on the guess of `parts`, each part by its share. A run in the middle of a round is
## worth less by how far its score is from the round's target. `w` is the numbers to guess
## by, `weights` when none are given.
static func of(run: RulesRun, w: Dictionary = weights) -> float:
	if run.phase == "end":
		return 1.0 if run.ending == "myself" or run.ending == "double" else 0.0
	var p := parts(run, w)
	var value: float = w.alive + w.line * p.line + w.power * p.power + w.salt * p.salt + w.sov * p.sov + w.table * p.table
	if run.phase == "play":
		value *= 0.5 + 0.5 * clampf(float(run.score) / maxf(1.0, Rules.target(run)), 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


## The parts of the guess for a run that goes on, each from 0 to 1: {line, power, salt, sov,
## table}.
static func parts(run: RulesRun, w: Dictionary = weights) -> Dictionary:
	var next := next_round(run)
	var line := Rules.line_info(run)
	var target: int = RulesConfig.targets(run.dials, next.night)[next.round]
	var scene: bool = next.round == 2
	var twist: String = RulesConfig.NIGHTS[next.night].twist if scene else ""
	var best := maxf(jekyll_play(run, w), hyde_play(run, twist == "hunted"))
	return {
		"line": clampf((int(line.paper) - int(line.ink)) / float(w.line_full), 0.0, 1.0),
		"power": clampf(best * run.dials.plays / maxf(1.0, target) / float(w.power_full), 0.0, 1.0),
		"salt": clampf(run.salt / float(w.salt_full), 0.0, 1.0),
		"sov": clampf(run.sov / float(w.sov_full), 0.0, 1.0),
		"table": _table(run, twist, w),
	}


## The round to come, as {night, round}: the one being played in phase "play", and otherwise
## the one after the round that has ended.
static func next_round(run: RulesRun) -> Dictionary:
	if run.phase == "play":
		return {"night": run.night, "round": run.round}
	var last: int = Rules.night_count() - 1
	if run.phase == "result" and run.round < 2:
		return {"night": run.night, "round": run.round + 1}
	return {"night": mini(run.night + 1, last), "round": 0}


## About what a good play of Jekyll's scores as the gauges stand: a Lucid Mind of his three
## symbols with a Good Cheer, his Temper counted, and a share of the Craving he may yet turn.
static func jekyll_play(run: RulesRun, w: Dictionary = weights) -> float:
	var d := run.dials
	var hand: Dictionary = RulesConfig.HANDS.jekyll.lucid
	var temper := 0.0
	for sym in RulesConfig.ROOTS:
		temper += run.temper[sym] + float(w.craving) * run.craving[sym]
	var chips: float = hand.chips + 3 * d.root_chips + d.factor_chips + d.temper_chips * temper
	var mult: float = hand.mult + d.cheer_mult + d.temper_mult * temper
	return chips * mult


## About what a good play of Hyde's scores as the gauges stand: a Mania of his best symbol
## with a Glee, its Craving and Habit counted. `hunted`: the base mult of his hands is halved.
static func hyde_play(run: RulesRun, hunted: bool = false) -> float:
	var d := run.dials
	var hand: Dictionary = RulesConfig.HANDS.hyde.mania
	var base: float = ceilf(hand.mult / 2.0) if hunted else float(hand.mult)
	if Rules.has_inst(run, "hcane"):
		base += d.hcane_mult
	var best := 0.0
	for sym in RulesConfig.ROOTS:
		var craving: int = run.craving[sym]
		var habit: int = run.habit[sym]
		var chips: float = hand.chips + 3 * (d.root_chips + d.craving_chips * craving + d.habit_chips * habit) + d.factor_chips + d.glee_chips
		var mult: float = base + 3 * d.habit_mult * habit
		best = maxf(best, chips * mult)
	return best


# How well the man who has the table stands before the round to come.
static func _table(run: RulesRun, twist: String, w: Dictionary) -> float:
	var hyde: bool = run.stance == "hyde"
	if twist != "":
		return float(w["at_%s_%s" % [twist, run.stance]])
	if hyde:
		return float(w.at_plain_hyde if run.salt > 0 else w.at_plain_hyde_dry)
	var full: float = clampf(run.restraint / float(maxi(1, Rules.limit_for(run, false))), 0.0, 1.0)
	return float(w.at_plain_jekyll) - float(w.at_plain_full) * full
